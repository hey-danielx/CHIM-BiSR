<?php

require_once __DIR__ . DIRECTORY_SEPARATOR . 'lib' . DIRECTORY_SEPARATOR . 'chim_bisr.php';

if (!chimBisrIsEnabled()) {
    return;
}

$turn = chimBisrTurnInstruction();
if ($turn === '') {
    return;
}

if (function_exists('chimRegisterPromptInjection')) {
    chimRegisterPromptInjection('prompt_bottom', 'chim_bisr.turn_instruction', $turn, 70);
    return;
}

if (!isset($GLOBALS['HERIKA_PERS'])) {
    $GLOBALS['HERIKA_PERS'] = '';
}
$GLOBALS['HERIKA_PERS'] .= "\n" . $turn;
