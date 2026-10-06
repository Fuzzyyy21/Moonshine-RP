-- V0016 – Chat, Freunde, Moderation (Phase 7, Iteration 1)
-- Chat des Originals: Kanäle und Regeln UNKNOWN; GDD 19 legt die Kanäle fest. chat_log ist zugleich der Verteiler zwischen den
-- Zonen-Servern: Jeder Server holt neue Nachrichten (WORLD, TRADE, SYSTEM, WHISPER an seine Spieler) über die message_id ab.

ALTER TABLE chat_log ADD COLUMN target_character_id BIGINT;   -- Empfänger einer WHISPER-Nachricht
CREATE INDEX ix_chat_log_id ON chat_log (message_id);
CREATE INDEX ix_chat_log_sender ON chat_log (sender_character_id, created_at);
CREATE INDEX ix_chat_mutes_active ON chat_mutes (character_id) INCLUDE (channel, muted_until);
CREATE INDEX ix_player_reports_open ON player_reports (status, created_at);
