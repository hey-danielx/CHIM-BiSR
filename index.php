<?php

$enginePath = dirname(__DIR__, 2) . DIRECTORY_SEPARATOR;
if (file_exists($enginePath . 'conf.php')) {
    require_once $enginePath . 'conf.php';
}
if (file_exists($enginePath . 'lib' . DIRECTORY_SEPARATOR . 'core' . DIRECTORY_SEPARATOR . 'bootstrap.php')) {
    require_once $enginePath . 'lib' . DIRECTORY_SEPARATOR . 'core' . DIRECTORY_SEPARATOR . 'bootstrap.php';
}

require_once __DIR__ . DIRECTORY_SEPARATOR . 'lib' . DIRECTORY_SEPARATOR . 'chim_bisr.php';

$message = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    chimBisrSaveSettings([
        'enabled' => isset($_POST['enabled']),
        'inject_prompt' => isset($_POST['inject_prompt']),
        'comment_own_dirt' => isset($_POST['comment_own_dirt']),
        'comment_player_dirt' => isset($_POST['comment_player_dirt']),
        'allow_bathe_action' => isset($_POST['allow_bathe_action']),
        'talk_mention_chance' => $_POST['talk_mention_chance'] ?? 40,
    ]);
    $message = 'Settings saved.';
}

$settings = chimBisrGetSettings();

function chimBisrChecked($value): string
{
    return !empty($value) ? 'checked' : '';
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <title>CHIM-BiSR</title>
    <style>
        body { font-family: Segoe UI, sans-serif; background: #101418; color: #eee; margin: 2rem; max-width: 720px; }
        a { color: #8ec8ff; }
        .card { background: #1b2229; border: 1px solid #2c3640; border-radius: 8px; padding: 1.25rem 1.5rem; }
        label { display: block; margin: 0.75rem 0; }
        button { background: #2f6fed; color: #fff; border: 0; border-radius: 6px; padding: 0.55rem 1rem; cursor: pointer; }
        .ok { color: #9fd89f; }
        code { background: #0d1116; padding: 0.1rem 0.35rem; border-radius: 4px; }
        input[type=range] { width: 100%; }
        .hint { color: #9aa7b3; font-size: 0.9rem; }
    </style>
</head>
<body>
    <h1>CHIM-BiSR</h1>
    <p>Bathing in Skyrim - Renewed hygiene for CHIM. Followers keep a sticky dirt marker, can complain about their own filth, can comment on the player's smell, and can use <code>Take_Bath</code> when water or a wash basin is nearby.</p>
    <?php if ($message !== ''): ?>
        <p class="ok"><?php echo htmlspecialchars($message, ENT_QUOTES, 'UTF-8'); ?></p>
    <?php endif; ?>
    <form method="post" class="card">
        <label>
            <input type="checkbox" name="enabled" value="1" <?php echo chimBisrChecked($settings['enabled']); ?>>
            Enable CHIM-BiSR
        </label>
        <label>
            <input type="checkbox" name="inject_prompt" value="1" <?php echo chimBisrChecked($settings['inject_prompt']); ?>>
            Inject hygiene instructions into CHIM prompts
        </label>
        <label>
            <input type="checkbox" name="comment_own_dirt" value="1" <?php echo chimBisrChecked($settings['comment_own_dirt']); ?>>
            Followers may comment on their own dirt
            <span class="hint">Comments follow Bathing in Skyrim feeling-dirty stages, not the raw percent. Light dirt is a brief complaint. Heavy dirt should sound uncomfortable. Filth should sound urgent. Below BiSR's slightly-dirty threshold they should not complain.</span>
        </label>
        <label>
            <input type="checkbox" name="comment_player_dirt" value="1" <?php echo chimBisrChecked($settings['comment_player_dirt']); ?>>
            Followers may comment on the player's dirt
            <span class="hint">Early dirt is a small remark. When the player is filthy, they should mention a bad smell and that a bath is overdue.</span>
        </label>
        <label>
            Player-talk mention chance: <strong id="chanceLabel"><?php echo (int) $settings['talk_mention_chance']; ?></strong>%
            <input type="range" name="talk_mention_chance" id="talkChance" min="0" max="100" step="5" value="<?php echo (int) $settings['talk_mention_chance']; ?>">
            <span class="hint">When you start a conversation while someone is still dirty, this is the chance they bring hygiene up in that reply. 0 = never on talk, 100 = always. Bored idle comments are separate.</span>
        </label>
        <label>
            <input type="checkbox" name="allow_bathe_action" value="1" <?php echo chimBisrChecked($settings['allow_bathe_action']); ?>>
            Allow Take_Bath when a follower has soap or a wash rag and is at water or a basin
        </label>
        <p>
            <button type="submit">Save</button>
        </p>
    </form>
    <div class="card" style="margin-top:1rem;">
        <h2>Game side</h2>
        <p>Load the Skyrim patch <strong>below</strong> Bathing in Skyrim - Renewed and <code>AIAgent</code>. Bathing in Skyrim must be enabled in its MCM.</p>
        <p>Papyrus reads BiSR's <code>BiS_Dirtiness</code> value on the player and followers. Tier-ups send a sticky <code>infoaction</code> plus one spoken line. Bathing clears that marker.</p>
        <p>Optional action <code>Take_Bath</code> is shipped as <code>CHIM/bisr_actions.csv</code>. The NPC must have soap or a wash rag, and must be in water, under a waterfall, or next to a wash basin.</p>
    </div>
    <script>
        const slider = document.getElementById('talkChance');
        const label = document.getElementById('chanceLabel');
        slider.addEventListener('input', function () { label.textContent = slider.value; });
    </script>
</body>
</html>
