<?php

require_once __DIR__ . DIRECTORY_SEPARATOR . 'lib' . DIRECTORY_SEPARATOR . 'chim_bisr.php';

if (function_exists('chimBisrRegisterPromptHooks')) {
    chimBisrRegisterPromptHooks();
}
