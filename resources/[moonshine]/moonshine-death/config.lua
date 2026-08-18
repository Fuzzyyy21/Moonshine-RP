--- Konfiguration des Sterbe- und Wiederbelebungssystems.

DeathConfig = {}

-- Zeiten (Sekunden) ----------------------------------------------------------
DeathConfig.BleedoutTime = 300   -- bis zum endgueltigen Tod
DeathConfig.RespawnAfter = 120   -- ab wann der Spieler selbst aufgeben darf
DeathConfig.ReviveTime   = 8     -- Dauer der Wiederbelebung durch einen Spieler

-- Wiederbelebung -------------------------------------------------------------
DeathConfig.Revive = {
    -- Jobs, die ohne Klassenskill wiederbeleben duerfen.
    jobs        = { 'ambulance' },
    -- Item, das dabei verbraucht wird (nil = keins).
    item        = 'medikit',
    -- Auch ohne passenden Job mit Item wiederbeleben lassen?
    anyoneWithItem = false,
    health      = 130,
    range       = 2.5,
}

-- Respawn --------------------------------------------------------------------
DeathConfig.Hospitals = {
    { label = 'Pillbox Hill',   coords = vector4(298.6, -584.6, 43.3, 70.0) },
    { label = 'Sandy Shores',   coords = vector4(1839.6, 3672.9, 34.3, 210.0) },
    { label = 'Paleto Bay',     coords = vector4(-247.8, 6331.2, 32.4, 220.0) },
}

--- Kosten beim Aufgeben (Behandlungskosten).
DeathConfig.RespawnCost = { account = 'bank', amount = 750 }

--- Schwaeche nach dem Respawn.
DeathConfig.Weakness = {
    duration   = 120,   -- Sekunden
    healthCap  = 140,   -- maximales Leben in dieser Zeit
    speedMult  = 0.92,
    essenceCut = 0.5,   -- Anteil der Essenz, der beim Respawn bleibt
}

-- Notruf ---------------------------------------------------------------------
DeathConfig.Call = {
    -- Diese Jobs bekommen den Notruf.
    jobs    = { 'ambulance' },
    -- Diese Klassen bekommen ihn ebenfalls (Heiler des Servers).
    classes = { 'fee', 'nekromant' },
    cooldown = 30,
    blipTime = 120,
}

-- Sonstiges ------------------------------------------------------------------
DeathConfig.DisableCombatLog = true   -- Bewusstlosigkeit ueberlebt den Relog
DeathConfig.Keys = {
    call    = 'E',   -- Notruf absetzen
    respawn = 'G',   -- Aufgeben
}
