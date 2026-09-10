CREATE SCHEMA IF NOT EXISTS plugins;

CREATE TABLE IF NOT EXISTS plugins.chim_bisr_settings (
    setting_key TEXT PRIMARY KEY,
    setting_value TEXT NOT NULL DEFAULT '',
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS plugins.chim_bisr_actor_state (
    actor_name TEXT PRIMARY KEY,
    dirt_tier INTEGER NOT NULL DEFAULT 0,
    dirt_percent REAL NOT NULL DEFAULT 0,
    is_player BOOLEAN NOT NULL DEFAULT FALSE,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO plugins.chim_bisr_settings (setting_key, setting_value)
VALUES
    ('enabled', 'true'),
    ('inject_prompt', 'true'),
    ('comment_own_dirt', 'true'),
    ('comment_player_dirt', 'true'),
    ('allow_bathe_action', 'true'),
    ('talk_mention_chance', '40')
ON CONFLICT (setting_key) DO NOTHING;
