--- Welt: Zeit, Wetter, Mondphasen und Ereignisse.

World = World or {}

WorldConfig = {}

WorldConfig.Debug = false

-- Zeit -------------------------------------------------------------------------
WorldConfig.Time = {
    -- Der Server gibt die Uhrzeit vor. Aus lassen, wenn ein anderes Script das macht.
    enabled = true,
    -- So viele Millisekunden dauert eine Ingame-Minute.
    -- 2000 ms = ein Ingame-Tag in 48 Minuten Echtzeit.
    minuteLength = 2000,
    -- Startzeit beim allerersten Start.
    startHour = 20,
    startMinute = 0,
    -- Nachts kann die Zeit schneller laufen, damit niemand ewig im Dunkeln sitzt.
    -- 1.0 = kein Unterschied.
    nightMultiplier = 0.75,
    nightFrom = 1,
    nightTo   = 5,
    -- Wie oft die Zeit an die Clients geht (Sekunden).
    syncInterval = 20,
}

-- Wetter -----------------------------------------------------------------------
WorldConfig.Weather = {
    enabled = true,
    -- Wie lange ein Wetter mindestens und hoechstens haelt (Minuten Echtzeit).
    minDuration = 20,
    maxDuration = 45,
    -- Uebergang in Sekunden.
    transition = 45.0,
    -- Gewichtete Auswahl. Je hoeher, desto haeufiger.
    pool = {
        { type = 'EXTRASUNNY', weight = 20, label = 'Klarer Himmel' },
        { type = 'CLEAR',      weight = 22, label = 'Heiter' },
        { type = 'CLOUDS',     weight = 18, label = 'Bewoelkt' },
        { type = 'OVERCAST',   weight = 14, label = 'Bedeckt' },
        { type = 'FOGGY',      weight = 8,  label = 'Neblig' },
        { type = 'RAIN',       weight = 7,  label = 'Regen' },
        { type = 'THUNDER',    weight = 4,  label = 'Gewitter' },
        { type = 'SMOG',       weight = 4,  label = 'Dunst' },
        { type = 'CLEARING',   weight = 3,  label = 'Aufklarend' },
    },
    -- Wetter, das nicht von selbst kommt, sondern nur ueber Ereignisse.
    eventOnly = { 'XMAS', 'SNOWLIGHT', 'BLIZZARD', 'HALLOWEEN' },
}

-- Mondphasen ---------------------------------------------------------------------
WorldConfig.Moon = {
    enabled = true,
    -- So viele Ingame-Tage dauert ein voller Zyklus (acht Phasen).
    cycleDays = 8,
}

-- Weltereignisse -------------------------------------------------------------------
WorldConfig.Events = {
    enabled = true,
    -- Abstand zwischen zwei Ereignissen in Minuten Echtzeit.
    minGap = 45,
    maxGap = 90,
    -- Vorwarnung vor dem Start in Sekunden.
    warning = 120,
    -- Erstes Ereignis fruehestens nach so vielen Minuten Serverlaufzeit.
    firstDelay = 25,
    -- Ein Ereignis wiederholt sich nicht, solange es unter den letzten
    -- so vielen war.
    noRepeat = 3,
}

-- Anzeige ----------------------------------------------------------------------------
WorldConfig.Hud = {
    -- Aus: Uhrzeit, Mondphase und Ereignis stehen jetzt in moonshine-hud,
    -- zusammen mit allem anderen. Wer das alte Einzelwidget lieber mag,
    -- schaltet es hier wieder ein - dann steht beides da.
    enabled = false,
    -- Kleines Widget mit Uhrzeit, Mondphase und laufendem Ereignis.
    showClock = true,
    showMoon  = true,
    -- Command zum Ein- und Ausblenden.
    toggleCommand = 'welt',
}

--- Gewichtete Auswahl aus einer Liste mit `weight`.
function World.PickWeighted(pool)
    local total = 0
    for _, entry in ipairs(pool) do total = total + (entry.weight or 1) end
    if total <= 0 then return nil end

    local roll, sum = math.random() * total, 0

    for _, entry in ipairs(pool) do
        sum = sum + (entry.weight or 1)
        if roll <= sum then return entry end
    end

    return pool[#pool]
end

--- Uhrzeit als Text.
function World.FormatTime(hour, minute)
    return ('%02d:%02d'):format(hour or 0, minute or 0)
end

--- Ist es zur angegebenen Stunde Nacht?
function World.IsNight(hour)
    return hour >= 21 or hour < 6
end
