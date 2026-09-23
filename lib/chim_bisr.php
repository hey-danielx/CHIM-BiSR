<?php

function chimBisrJsonEncode($value): string
{
    $json = json_encode($value, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    return is_string($json) && $json !== '' ? $json : '{}';
}

function chimBisrToBool($value): bool
{
    if (is_bool($value)) {
        return $value;
    }
    $value = strtolower(trim((string) $value));
    return in_array($value, ['1', 't', 'true', 'yes', 'y', 'on', 'enabled'], true);
}

function chimBisrTableExists(string $tableName): bool
{
    global $db;
    if (!isset($db)) {
        return false;
    }

    try {
        $escaped = $db->escape($tableName);
        $row = $db->fetchOne("SELECT to_regclass('{$escaped}') AS table_name");
        return is_array($row) && !empty($row['table_name']);
    } catch (Throwable $e) {
        return false;
    }
}

function chimBisrDbReady(): bool
{
    return chimBisrTableExists('plugins.chim_bisr_settings');
}

function chimBisrStateDbReady(): bool
{
    return chimBisrTableExists('plugins.chim_bisr_actor_state');
}

function chimBisrDefaultSettings(): array
{
    return [
        'enabled' => true,
        'inject_prompt' => true,
        'comment_own_dirt' => true,
        'comment_player_dirt' => true,
        'allow_bathe_action' => true,
        'talk_mention_chance' => 40,
    ];
}

function chimBisrCoerceSetting(string $key, $value)
{
    if ($key === 'talk_mention_chance') {
        return max(0, min(100, intval($value)));
    }
    return chimBisrToBool($value);
}

function chimBisrGetSettings(): array
{
    $settings = chimBisrDefaultSettings();
    if (!chimBisrDbReady()) {
        return $settings;
    }

    global $db;
    try {
        $rows = $db->fetchAll("SELECT setting_key, setting_value FROM plugins.chim_bisr_settings");
        if (!is_array($rows)) {
            return $settings;
        }
        foreach ($rows as $row) {
            $key = (string) ($row['setting_key'] ?? '');
            if ($key === '' || !array_key_exists($key, $settings)) {
                continue;
            }
            $settings[$key] = chimBisrCoerceSetting($key, $row['setting_value'] ?? '');
        }
    } catch (Throwable $e) {
        return $settings;
    }

    return $settings;
}

function chimBisrSaveSettings(array $settings): void
{
    if (!chimBisrDbReady()) {
        return;
    }

    global $db;
    $defaults = chimBisrDefaultSettings();
    foreach ($defaults as $key => $defaultValue) {
        if ($key === 'talk_mention_chance') {
            $value = (string) chimBisrCoerceSetting($key, $settings[$key] ?? $defaultValue);
        } else {
            $value = !empty($settings[$key]) ? 'true' : 'false';
        }
        $escapedKey = $db->escape($key);
        $escapedValue = $db->escape($value);
        $db->execQuery("
            INSERT INTO plugins.chim_bisr_settings (setting_key, setting_value, updated_at)
            VALUES ('{$escapedKey}', '{$escapedValue}', CURRENT_TIMESTAMP)
            ON CONFLICT (setting_key) DO UPDATE
            SET setting_value = EXCLUDED.setting_value,
                updated_at = CURRENT_TIMESTAMP
        ");
    }
}

function chimBisrIsEnabled(): bool
{
    $settings = chimBisrGetSettings();
    return !empty($settings['enabled']);
}

function chimBisrRequestType(): string
{
    $gameRequest = $GLOBALS['gameRequest'] ?? null;
    if (is_array($gameRequest)) {
        return strtolower(trim((string) ($gameRequest[0] ?? '')));
    }
    if (is_string($gameRequest) && $gameRequest !== '') {
        $parts = explode('|', $gameRequest, 2);
        return strtolower(trim($parts[0]));
    }
    return '';
}

function chimBisrRequestData(): string
{
    $gameRequest = $GLOBALS['gameRequest'] ?? null;
    if (is_array($gameRequest)) {
        return trim((string) ($gameRequest[3] ?? ''));
    }
    return is_string($gameRequest) ? $gameRequest : '';
}

function chimBisrCurrentNpcName(): string
{
    $name = trim((string) ($GLOBALS['HERIKA_NAME'] ?? ''));
    if ($name !== '' && strcasecmp($name, 'The Narrator') !== 0) {
        return $name;
    }
    return '';
}

function chimBisrPlayerName(): string
{
    $name = trim((string) ($GLOBALS['PLAYER_NAME'] ?? $GLOBALS['PLAYER_NAME_PRINT'] ?? ''));
    return $name;
}

function chimBisrIsPlayerTalkRequest(string $type): bool
{
    if ($type === '') {
        return false;
    }
    if (strpos($type, 'inputtext') === 0) {
        return true;
    }
    return in_array($type, ['talk', 'dialogue', 'playerinput', 'chatinput'], true);
}

function chimBisrIsBoredRequest(string $type): bool
{
    return $type === 'bored' || strpos($type, 'bored') === 0;
}

function chimBisrNormalizeTier($tier): int
{
    $tier = intval($tier);
    if ($tier < 0) {
        return 0;
    }
    if ($tier > 3) {
        return 3;
    }
    return $tier;
}

function chimBisrEmptyState(): array
{
    return [
        'dirt_tier' => 0,
        'dirt_percent' => 0.0,
        'is_player' => false,
        'known' => false,
    ];
}

function chimBisrGetActorState(string $actorName): array
{
    $empty = chimBisrEmptyState();
    $actorName = trim($actorName);
    if ($actorName === '' || !chimBisrStateDbReady()) {
        return $empty;
    }

    global $db;
    try {
        $nameSql = $db->escape($actorName);
        $row = $db->fetchOne("SELECT dirt_tier, dirt_percent, is_player FROM plugins.chim_bisr_actor_state WHERE actor_name = '{$nameSql}'");
        if (!is_array($row)) {
            return $empty;
        }
        return [
            'dirt_tier' => chimBisrNormalizeTier($row['dirt_tier'] ?? 0),
            'dirt_percent' => (float) ($row['dirt_percent'] ?? 0),
            'is_player' => chimBisrToBool($row['is_player'] ?? false),
            'known' => true,
        ];
    } catch (Throwable $e) {
        return $empty;
    }
}

// Copy persisted state to an existing NPC; the plugin table remains the live cache.
function chimBisrStoreNpcPluginState(string $actorName): void
{
    global $db;
    static $supported = null;
    try {
        if ($supported === null) {
            $supported = false;
            $enginePath = (string) ($GLOBALS['ENGINE_PATH'] ?? '');
            $classFile = rtrim($enginePath, '/\\') . '/lib/core/npc_master.class.php';
            if (!class_exists('NpcMaster', false) && $enginePath !== '' && is_file($classFile)) {
                require_once $classFile;
            }
            if (method_exists('NpcMaster', 'setPluginData')) {
                $column = $db->fetchOne("SELECT 1 AS supported FROM information_schema.columns
                    WHERE table_schema = 'public' AND table_name = 'core_npc_master'
                    AND column_name = 'plugin_extended_data'");
                $supported = !empty($column['supported']);
            }
        }
        if (!$supported) return;
        // Events carry names, not FormIDs. Never choose between ambiguous profiles.
        $match = $db->fetchOne("SELECT min(id) AS id, count(*) AS matches FROM
            (SELECT id FROM core_npc_master WHERE npc_name = $1 LIMIT 2) candidates", [$actorName]);
        if ((int) ($match['matches'] ?? 0) !== 1) return;
        $row = $db->fetchOne("SELECT to_jsonb(state) - 'actor_name' - 'updated_at' AS data
            FROM plugins.chim_bisr_actor_state state WHERE actor_name = $1", [$actorName]);
        if (empty($row['data'])) return;
        $state = json_decode($row['data'], true, 512, JSON_THROW_ON_ERROR);

        if (!(new NpcMaster())->setPluginData((int) $match['id'], 'chim_bisr', [
            'actor_name' => $actorName, 'state' => (object) $state, 'updated_at' => gmdate('c'),
        ])) {
            throw new RuntimeException('npc_plugin_state_not_saved');
        }
    } catch (Throwable $e) {
        error_log('[CHIM-BiSR] Could not store NPC plugin state; live cache retained.');
    }
}

function chimBisrUpsertActorDirt(string $actorName, int $tier, float $percent, bool $isPlayer, bool $clear): void
{
    if (!chimBisrStateDbReady()) {
        return;
    }

    $actorName = trim($actorName);
    if ($actorName === '') {
        return;
    }

    if ($clear) {
        $tier = 0;
        $percent = 0.0;
    }

    $tier = chimBisrNormalizeTier($tier);
    $percent = max(0.0, min(1.0, $percent));

    global $db;
    $nameSql = $db->escape($actorName);
    $tierSql = (string) $tier;
    $percentSql = (string) $percent;
    $playerSql = $isPlayer ? 'TRUE' : 'FALSE';

    $db->execQuery("
        INSERT INTO plugins.chim_bisr_actor_state (
            actor_name, dirt_tier, dirt_percent, is_player, updated_at
        ) VALUES (
            '{$nameSql}', {$tierSql}, {$percentSql}, {$playerSql}, CURRENT_TIMESTAMP
        )
        ON CONFLICT (actor_name) DO UPDATE
        SET dirt_tier = EXCLUDED.dirt_tier,
            dirt_percent = EXCLUDED.dirt_percent,
            is_player = EXCLUDED.is_player,
            updated_at = CURRENT_TIMESTAMP
    ");
    chimBisrStoreNpcPluginState($actorName);
}

function chimBisrDescribeTier(int $tier, bool $isSelf): string
{
    if ($isSelf) {
        if ($tier >= 3) {
            return 'filthy, uncomfortable, and in urgent need of a bath';
        }
        if ($tier === 2) {
            return 'noticeably dirty and uncomfortable about their hygiene';
        }
        if ($tier === 1) {
            return 'a bit dirty and aware they could use a wash';
        }
        return '';
    }

    if ($tier >= 3) {
        return 'completely filthy and smelling very bad; they should bathe as soon as possible';
    }
    if ($tier === 2) {
        return 'quite dirty and in need of a bath';
    }
    if ($tier === 1) {
        return 'a bit dirty';
    }
    return '';
}

function chimBisrParseDirtPayload(string $data, string $fallbackName): void
{
    $data = trim($data);
    if ($data === '') {
        return;
    }

    if (preg_match('/bisr_dirt@([^@]+)@([0-3])@(clear|[0-9]*\.?[0-9]+)/i', $data, $match)) {
        $clear = strtolower($match[3]) === 'clear';
        $percent = $clear ? 0.0 : (float) $match[3];
        $name = trim($match[1]);
        $playerName = chimBisrPlayerName();
        $isPlayer = ($playerName !== '' && strcasecmp($name, $playerName) === 0);
        chimBisrUpsertActorDirt($name, (int) $match[2], $percent, $isPlayer, $clear);
        return;
    }

    if (preg_match('/^(.+?) is clean again\.?$/i', $data, $match)) {
        $name = trim($match[1]);
        $playerName = chimBisrPlayerName();
        $isPlayer = ($playerName !== '' && strcasecmp($name, $playerName) === 0) || strcasecmp($name, 'the player') === 0;
        if (strcasecmp($name, 'the player') === 0 && $playerName !== '') {
            $name = $playerName;
        }
        chimBisrUpsertActorDirt($name, 0, 0.0, $isPlayer, true);
        return;
    }

    if (preg_match('/^(?:the player|(.+?)) is (a bit dirty|quite dirty|filthy)(?: and .+)?\.?$/i', $data, $match)) {
        $rawName = trim((string) ($match[1] ?? ''));
        $playerName = chimBisrPlayerName();
        $isPlayer = ($rawName === '') || ($playerName !== '' && strcasecmp($rawName, $playerName) === 0);
        $name = $isPlayer && $playerName !== '' ? $playerName : $rawName;
        $label = strtolower($match[2]);
        $tier = 1;
        if ($label === 'quite dirty') {
            $tier = 2;
        } elseif ($label === 'filthy') {
            $tier = 3;
        }
        chimBisrUpsertActorDirt($name, $tier, 0.0, $isPlayer, false);
        return;
    }

    if ($fallbackName !== '' && preg_match('/\bis (?:no longer )?(?:a bit dirty|quite dirty|filthy|clean again)\b/i', $data)) {
        $clear = stripos($data, 'clean again') !== false || stripos($data, 'no longer') !== false;
        chimBisrUpsertActorDirt($fallbackName, $clear ? 0 : 1, 0.0, false, $clear);
    }
}

function chimBisrIngestCurrentRequest(): void
{
    if (!chimBisrIsEnabled()) {
        return;
    }

    $type = chimBisrRequestType();
    $data = chimBisrRequestData();
    $npc = chimBisrCurrentNpcName();

    if ($type === 'infoaction' || strpos($data, 'bisr_dirt@') !== false || preg_match('/\bis (?:a bit dirty|quite dirty|filthy|clean again)\b/i', $data)) {
        chimBisrParseDirtPayload($data, $npc);
    }
}

function chimBisrPromptInstructions(): string
{
    $settings = chimBisrGetSettings();
    if (empty($settings['enabled']) || empty($settings['inject_prompt'])) {
        return '';
    }

    $own = !empty($settings['comment_own_dirt']);
    $player = !empty($settings['comment_player_dirt']);
    $bathe = !empty($settings['allow_bathe_action']);

    $lines = [
        'This speaker is an NPC. Hygiene comes only from Bathing in Skyrim. Never mention mods, meters, factions, or game menus.',
        'Do not invent dirt, grime, smell, or a need to wash for yourself or anyone else. Only describe dirt when that person has a Hygiene line that says they feel dirty. If there is no Hygiene line, or it says they do not feel dirty, they are not dirty. Being in an inn or bath house is not dirt.',
    ];

    if ($own) {
        $lines[] = 'If this NPC\'s Hygiene line says they are a bit dirty, they may briefly mention wanting to wash. If they are quite dirty, they should sound uncomfortable. If they are filthy, they should sound distressed about their own smell and needing a bath soon.';
    } else {
        $lines[] = 'Do not comment on this NPC\'s own dirt or hygiene.';
    }

    if ($player) {
        $lines[] = 'If the player\'s Hygiene line says they are a bit dirty, a follower may notice some dirt. If the player is filthy, they should comment on a really bad smell and that the player should bathe as soon as possible.';
    } else {
        $lines[] = 'Do not comment on the player\'s dirt, smell, or bathing habits.';
    }

    if ($bathe) {
        $lines[] = 'Take_Bath washes off Bathing in Skyrim dirt. Use it only when this NPC currently feels dirty, has soap or a wash rag, and is in water, under a waterfall, or next to a wash basin. A bath house is not a reason to claim they are filthy.';
    } else {
        $lines[] = 'Do not use Take_Bath.';
    }

    $lines[] = 'If someone is clean again or does not feel dirty, drop the hygiene topic.';
    return implode("\n", $lines);
}

function chimBisrActorProfileLine($actorName, $actorType = '', array $context = [])
{
    if (!chimBisrIsEnabled()) {
        return '';
    }

    $actorName = trim((string) $actorName);
    if ($actorName === '') {
        return '';
    }

    $state = chimBisrGetActorState($actorName);
    if (empty($state['known'])) {
        return '';
    }

    $description = chimBisrDescribeTier((int) $state['dirt_tier'], true);
    if ($description !== '') {
        return 'Hygiene: ' . $description . '.';
    }

    return 'Hygiene: does not feel dirty.';
}

function chimBisrTurnInstruction(): string
{
    if (!chimBisrIsEnabled()) {
        return '';
    }

    $npc = chimBisrCurrentNpcName();
    if ($npc === '') {
        return '';
    }

    $settings = chimBisrGetSettings();
    $type = chimBisrRequestType();
    $ownState = chimBisrGetActorState($npc);
    $playerName = chimBisrPlayerName();
    $playerState = $playerName !== '' ? chimBisrGetActorState($playerName) : chimBisrEmptyState();

    $ownTier = !empty($settings['comment_own_dirt']) ? (int) $ownState['dirt_tier'] : 0;
    $playerTier = !empty($settings['comment_player_dirt']) ? (int) $playerState['dirt_tier'] : 0;
    if ($ownTier <= 0 && $playerTier <= 0) {
        if (!empty($settings['inject_prompt']) && !empty($ownState['known']) && (chimBisrIsBoredRequest($type) || chimBisrIsPlayerTalkRequest($type))) {
            return 'You do not feel dirty. Do not talk as if you are dirty, smelly, or desperate for a bath. You may mention a bath as ordinary comfort if you are at one, but do not treat dirt as the reason. Do not mention mods, meters, or game menus.';
        }
        return '';
    }

    $parts = [];
    if ($ownTier > 0) {
        $parts[] = 'You are ' . chimBisrDescribeTier($ownTier, true);
    }
    if ($playerTier > 0 && $playerName !== '' && strcasecmp($playerName, $npc) !== 0) {
        $parts[] = $playerName . ' is ' . chimBisrDescribeTier($playerTier, false);
    }
    if ($parts === []) {
        return '';
    }

    $status = implode('. ', $parts) . '.';
    $batheHint = '';
    if (!empty($settings['allow_bathe_action']) && $ownTier > 0) {
        $batheHint = ' If you have soap or a wash rag and are in water or at a wash basin, you may use Take_Bath.';
    }

    if (chimBisrIsBoredRequest($type)) {
        if ($ownTier >= 2) {
            return "This is a quiet/bored moment. {$status} Make this idle line a short in-character comment about your own hygiene. Do not mention mods, meters, or game menus.";
        }
        if ($playerTier >= 3) {
            return "This is a quiet/bored moment. {$status} Make this idle line a short in-character comment about {$playerName}'s smell and that they should bathe soon. Do not mention mods, meters, or game menus.";
        }
        if ($playerTier > 0) {
            return "This is a quiet/bored moment. {$status} You may briefly notice some dirt on {$playerName}. Do not mention mods, meters, or game menus.";
        }
        return "This is a quiet/bored moment. {$status} Make one short in-character hygiene comment. Do not mention mods, meters, or game menus.";
    }

    if (chimBisrIsPlayerTalkRequest($type)) {
        $chance = (int) ($settings['talk_mention_chance'] ?? 40);
        if ($chance <= 0) {
            return '';
        }
        if ($chance < 100 && random_int(1, 100) > $chance) {
            return '';
        }
        return "{$status} In this reply, briefly bring that up in character.{$batheHint} Keep it short. Do not mention mods, meters, or game menus.";
    }

    return '';
}

function chimBisrRegisterPromptHooks(): void
{
    if (!chimBisrIsEnabled()) {
        return;
    }

    $instructions = chimBisrPromptInstructions();
    if ($instructions !== '' && function_exists('chimRegisterPromptInjection')) {
        chimRegisterPromptInjection('prompt_bottom', 'chim_bisr.hygiene_instructions', $instructions, 80);
    }

    if (function_exists('chimRegisterActorProfileEnricher')) {
        chimRegisterActorProfileEnricher('chim_bisr.actor_hygiene', 'chimBisrActorProfileLine', 60);
    }
}
