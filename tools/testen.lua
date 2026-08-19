--- Testet die reine Rechenlogik der shared-Dateien mit echtem Lua.
---
--- Nichts hiervon braucht einen FXServer. Geprueft wird, was sich ohne
--- Spielzustand pruefen laesst: Konsistenz der Datentabellen, Grenzwerte,
--- Umkehrbarkeit von Rechnungen.
---
--- Aufruf:   lua5.4 tools/testen.lua
--- Rueckgabe: 0 wenn alles besteht, 1 bei Fehlschlaegen.

dofile('tools/attrappe.lua')

local BASE = 'resources/[moonshine]/'

local bestanden, fehlgeschlagen = 0, 0
local aktuell = '?'

--- Laedt eine shared-Datei.
local function laden(pfad)
    local chunk, err = loadfile(BASE .. pfad)
    if not chunk then error(('%s laesst sich nicht laden: %s'):format(pfad, err)) end

    local ok, err2 = pcall(chunk)
    if not ok then error(('%s bricht beim Laden ab: %s'):format(pfad, err2)) end
end

local function gruppe(name)
    aktuell = name
    print(('\n-- %s'):format(name))
end

local function pruefe(beschreibung, bedingung, zusatz)
    if bedingung then
        bestanden = bestanden + 1
    else
        fehlgeschlagen = fehlgeschlagen + 1
        print(('   FEHLER  %s%s'):format(beschreibung,
            zusatz and ('  [' .. tostring(zusatz) .. ']') or ''))
    end
end

--- Alle Werte einer Tabelle muessen eindeutig sein.
local function eindeutig(liste, feld)
    local gesehen, doppelt = {}, {}

    for _, eintrag in ipairs(liste) do
        local wert = feld and eintrag[feld] or eintrag

        if gesehen[wert] then doppelt[#doppelt + 1] = tostring(wert) end
        gesehen[wert] = true
    end

    return #doppelt == 0, table.concat(doppelt, ', ')
end

-- ===========================================================================
-- Mystik
-- ===========================================================================

laden('moonshine-mystic/shared/config.lua')
laden('moonshine-mystic/shared/races.lua')
laden('moonshine-mystic/shared/skills.lua')
laden('moonshine-mystic/shared/personal.lua')
laden('moonshine-mystic/shared/items.lua')

gruppe('Mystik: Klassen')

local klassen = 0
for name, race in pairs(Mystic.Races) do
    klassen = klassen + 1

    pruefe(('%s hat Bezeichnung und Beschreibung'):format(name),
        type(race.label) == 'string' and type(race.description) == 'string')

    pruefe(('%s hat vollstaendige Werte'):format(name),
        race.stats and race.stats.healthBonus and race.stats.damageMult
        and race.stats.meleeMult and race.stats.speedMult)

    pruefe(('%s hat eine Essenz mit Maximum'):format(name),
        race.essence and type(race.essence.max) == 'number' and race.essence.max > 0)
end

pruefe('Es gibt mindestens acht Klassen', klassen >= 8, klassen)

gruppe('Mystik: Klassenbaeume')

for rasse in pairs(Mystic.Races) do
    local skills = Mystic.GetSkillsForRace(rasse)
    pruefe(('%s hat Faehigkeiten'):format(rasse), #skills > 0)

    local ids = {}
    for _, skill in ipairs(skills) do ids[skill.id] = true end

    for _, skill in ipairs(skills) do
        for _, benoetigt in ipairs(skill.requires or {}) do
            pruefe(('%s/%s: Voraussetzung "%s" gibt es'):format(rasse, skill.id, benoetigt),
                ids[benoetigt] == true)
        end

        pruefe(('%s/%s hat maxRank > 0'):format(rasse, skill.id),
            (skill.maxRank or 0) > 0)

        -- Steinkosten muessen fuer jede Stufe da sein
        for stufe = 1, skill.maxRank do
            local kosten = Mystic.GetRankCost(skill, stufe)
            pruefe(('%s/%s Stufe %d kostet etwas'):format(rasse, skill.id, stufe),
                type(kosten) == 'number' and kosten > 0, kosten)
        end
    end
end

gruppe('Mystik: erste Faehigkeit kostet fuenf Steine')

for rasse in pairs(Mystic.Races) do
    for _, skill in ipairs(Mystic.GetSkillsForRace(rasse)) do
        if not skill.requires or #skill.requires == 0 then
            pruefe(('%s: Wurzel "%s" kostet 5'):format(rasse, skill.id),
                Mystic.GetRankCost(skill, 1) == 5, Mystic.GetRankCost(skill, 1))
        end
    end
end

gruppe('Mystik: Stufenwerte')

local beispiel = { 10, 20, 30 }
pruefe('PickRankValue Stufe 1', Mystic.PickRankValue(beispiel, 1) == 10)
pruefe('PickRankValue Stufe 3', Mystic.PickRankValue(beispiel, 3) == 30)
pruefe('PickRankValue ueber dem Ende bleibt beim letzten',
    Mystic.PickRankValue(beispiel, 9) == 30)
pruefe('PickRankValue mit einfacher Zahl', Mystic.PickRankValue(7, 2) == 7)

gruppe('Mystik: persoenlicher Baum')

-- PersonalCategories ist eine Liste, kein Nachschlagewerk.
pruefe('Es gibt sechs Kategorien',
    #Mystic.PersonalCategories == 6, #Mystic.PersonalCategories)

for _, kategorie in ipairs(Mystic.PersonalCategories) do
    local knoten = Mystic.GetPersonalNodesFor(kategorie.id)

    pruefe(('Kategorie %s hat Knoten'):format(kategorie.id), #knoten > 0)
    pruefe(('Kategorie %s hat Farbe und Symbol'):format(kategorie.id),
        kategorie.color ~= nil and kategorie.icon ~= nil)

    for _, k in ipairs(knoten) do
        for _, benoetigt in ipairs(k.requires or {}) do
            pruefe(('%s/%s: Voraussetzung "%s" gibt es'):format(
                kategorie.id, k.id, benoetigt),
                Mystic.GetPersonalNode(benoetigt) ~= nil)
        end

        for stufe = 1, k.maxRank do
            pruefe(('%s/%s Stufe %d kostet Punkte'):format(kategorie.id, k.id, stufe),
                (Mystic.GetPersonalCost(k, stufe) or 0) > 0)
        end

        -- Ausserhalb des Bereichs muss nil kommen
        pruefe(('%s/%s: Stufe 0 gibt es nicht'):format(kategorie.id, k.id),
            Mystic.GetPersonalCost(k, 0) == nil)
        pruefe(('%s/%s: Stufe ueber dem Maximum gibt es nicht'):format(
            kategorie.id, k.id),
            Mystic.GetPersonalCost(k, k.maxRank + 1) == nil)
    end
end

gruppe('Mystik: Summen des persoenlichen Baums')

local voll = {}
for _, kategorie in ipairs(Mystic.PersonalCategories) do
    for _, k in ipairs(Mystic.GetPersonalNodesFor(kategorie.id)) do
        voll[k.id] = k.maxRank
    end
end

pruefe('Der volle Baum hat Knoten', next(voll) ~= nil)

local summe = Mystic.SumPersonal(voll)
pruefe('Voller Baum gibt Leben', (summe.healthBonus or 0) > 0, summe.healthBonus)
pruefe('Kritische Chance bleibt unter 100 %',
    (summe.critChance or 0) <= 1.0, summe.critChance)
pruefe('Schadensreduktion bleibt unter 100 %',
    (summe.damageReduction or 0) < 1.0, summe.damageReduction)
pruefe('Lebensentzug bleibt unter 100 %',
    (summe.lifesteal or 0) <= 1.0, summe.lifesteal)

local leer = Mystic.SumPersonal({})
pruefe('Leerer Baum gibt kein Leben', (leer.healthBonus or 0) == 0)

-- Mystic.GetSpentPoints nimmt einen Knoten und eine Stufe,
-- nicht die ganze Tabelle wie das gleichnamige in Fraktionen.
local gesamtpunkte = 0
for id, rang in pairs(voll) do
    local knoten = Mystic.GetPersonalNode(id)
    gesamtpunkte = gesamtpunkte + Mystic.GetSpentPoints(knoten, rang)
end

pruefe('Der volle Baum kostet Punkte', gesamtpunkte > 0, gesamtpunkte)

-- Die Summe muss den Einzelkosten entsprechen
local ersterKnoten = Mystic.GetPersonalNodesFor(Mystic.PersonalCategories[1].id)[1]
local handSumme = 0
for stufe = 1, ersterKnoten.maxRank do
    handSumme = handSumme + Mystic.GetPersonalCost(ersterKnoten, stufe)
end

pruefe('GetSpentPoints entspricht der Summe der Einzelstufen',
    Mystic.GetSpentPoints(ersterKnoten, ersterKnoten.maxRank) == handSumme,
    ('%d statt %d'):format(
        Mystic.GetSpentPoints(ersterKnoten, ersterKnoten.maxRank), handSumme))

-- ===========================================================================
-- Fortschritt
-- ===========================================================================

laden('moonshine-progress/shared/config.lua')
laden('moonshine-progress/shared/missions.lua')
laden('moonshine-progress/shared/battlepass.lua')
laden('moonshine-progress/shared/cases.lua')

gruppe('Fortschritt: Battle Pass')

pruefe('Stufe 1 bei null XP', Progress.GetBattlePassLevel(0) == 1)

-- Von Hand gerechnet: base + stufe * step, mit base 800 und step 120.
-- Bewusst nicht mit derselben Formel geprueft - sonst prueft sich die
-- Funktion nur gegen sich selbst und jede Aenderung bleibt unbemerkt.
pruefe('xpBase ist 800', ProgressConfig.BattlePass.xpBase == 800,
    ProgressConfig.BattlePass.xpBase)
pruefe('xpStep ist 120', ProgressConfig.BattlePass.xpStep == 120,
    ProgressConfig.BattlePass.xpStep)

local erwartet = { [1] = 920, [2] = 1040, [3] = 1160, [10] = 2000, [25] = 3800 }
for stufe, soll in pairs(erwartet) do
    pruefe(('Stufe %d braucht %d XP'):format(stufe, soll),
        Progress.GetTierXp(stufe) == soll, Progress.GetTierXp(stufe))
end

-- Schwellen ebenfalls von Hand: 920 fuer Stufe 2, 920+1040 fuer Stufe 3
pruefe('919 XP bleibt Stufe 1', Progress.GetBattlePassLevel(919) == 1)
pruefe('920 XP ergibt Stufe 2', Progress.GetBattlePassLevel(920) == 2)
pruefe('1959 XP bleibt Stufe 2', Progress.GetBattlePassLevel(1959) == 2)
pruefe('1960 XP ergibt Stufe 3', Progress.GetBattlePassLevel(1960) == 3)

local _, rest, noetig = Progress.GetBattlePassLevel(1000)
pruefe('Bei 1000 XP sind 80 in Stufe 2 gesammelt', rest == 80, rest)
pruefe('Bei 1000 XP fehlen noch bis 1040', noetig == 1040, noetig)

-- Und zusaetzlich die Umkehrbarkeit ueber die ganze Kurve
local gesamt = 0
for stufe = 1, 20 do
    gesamt = gesamt + Progress.GetTierXp(stufe)

    local erreicht = Progress.GetBattlePassLevel(gesamt)
    pruefe(('Summe bis Stufe %d ergibt Stufe %d'):format(stufe, stufe + 1),
        erreicht == stufe + 1, erreicht)
end

local maxLevel = ProgressConfig.BattlePass.maxLevel
pruefe('Sehr viel XP bleibt beim Maximum',
    Progress.GetBattlePassLevel(99999999) == maxLevel)

local _, into, needed = Progress.GetBattlePassLevel(99999999)
pruefe('Am Maximum gibt es keinen Restfortschritt', into == 0 and needed == 0)

for stufe = 1, maxLevel do
    local frei, premium = Progress.GetTierReward(stufe)
    pruefe(('Stufe %d hat beide Spuren'):format(stufe),
        type(frei) == 'table' and type(premium) == 'table')
end

gruppe('Fortschritt: Missionen')

local ok, doppelt = eindeutig(Progress.Missions, 'id')
pruefe('Missions-Ids sind eindeutig', ok, doppelt)

for _, mission in ipairs(Progress.Missions) do
    pruefe(('%s hat ein Ziel > 0'):format(mission.id), (mission.goal or 0) > 0)
    pruefe(('%s hat eine Belohnung'):format(mission.id),
        type(mission.reward) == 'table' and next(mission.reward) ~= nil)
    pruefe(('%s ist taeglich oder woechentlich'):format(mission.id),
        mission.kind == 'daily' or mission.kind == 'weekly')
    pruefe(('%s hat ein Ereignis'):format(mission.id),
        type(mission.event) == 'string')
end

pruefe('Genug taegliche Missionen fuer die Auswahl',
    #Progress.GetMissionPool('daily') >= ProgressConfig.Missions.dailyCount,
    #Progress.GetMissionPool('daily'))
pruefe('Genug woechentliche Missionen fuer die Auswahl',
    #Progress.GetMissionPool('weekly') >= ProgressConfig.Missions.weeklyCount,
    #Progress.GetMissionPool('weekly'))

gruppe('Fortschritt: Kisten')

for name, kiste in pairs(Progress.Cases) do
    pruefe(('%s hat Lose'):format(name), #kiste.loot > 0)

    local gewicht = 0
    for _, los in ipairs(kiste.loot) do
        pruefe(('%s: jedes Los hat Gewicht > 0'):format(name), los.weight > 0)
        pruefe(('%s: jedes Los hat eine Belohnung'):format(name),
            type(los.reward) == 'table' and next(los.reward) ~= nil)
        gewicht = gewicht + los.weight
    end

    pruefe(('%s: Gesamtgewicht > 0'):format(name), gewicht > 0)
end

for _, name in ipairs(Progress.CaseOrder) do
    pruefe(('Reihenfolge kennt "%s"'):format(name), Progress.GetCase(name) ~= nil)
end

gruppe('Fortschritt: Spielzeit')

local vorher = 0
for _, stufe in ipairs(ProgressConfig.Playtime.milestones) do
    pruefe(('Meilenstein %d liegt hinter dem vorigen'):format(stufe.minutes),
        stufe.minutes > vorher, stufe.minutes)
    pruefe(('Meilenstein %d hat eine Belohnung'):format(stufe.minutes),
        type(stufe.reward) == 'table' and next(stufe.reward) ~= nil)
    vorher = stufe.minutes
end

-- ===========================================================================
-- Fraktionen
-- ===========================================================================

laden('moonshine-factions/shared/config.lua')
laden('moonshine-factions/shared/emblems.lua')
laden('moonshine-factions/shared/ranks.lua')
laden('moonshine-factions/shared/skills.lua')
laden('moonshine-factions/shared/territories.lua')

gruppe('Fraktionen: Raenge')

local raenge = Factions.CopyDefaultRanks()
pruefe('Standardraenge haben mindestens zwei Stufen', #raenge >= 2, #raenge)

local oben = Factions.TopGrade(raenge)
for _, recht in ipairs(Factions.Permissions) do
    pruefe(('Oberster Rang darf "%s"'):format(recht.id),
        Factions.RankHas(raenge, oben, recht.id))
end

pruefe('Anwaerter darf die Fraktion nicht verwalten',
    not Factions.RankHas(raenge, 0, 'manage'))
pruefe('Anwaerter darf die Kasse nicht leeren',
    not Factions.RankHas(raenge, 0, 'kasseTake'))

-- Kopie darf das Original nicht veraendern
local zweite = Factions.CopyDefaultRanks()
zweite[1].label = 'Veraendert'
pruefe('CopyDefaultRanks liefert echte Kopien',
    Factions.CopyDefaultRanks()[1].label ~= 'Veraendert')

gruppe('Fraktionen: Rangbereinigung')

local muell = Factions.SanitizeRanks({ 'kaputt' }, raenge)
pruefe('Muell faellt auf die Vorgabe zurueck', #muell >= 2)

local zuviele = {}
for i = 1, 20 do zuviele[i] = { label = 'R' .. i, icon = '?', permissions = {} } end
local begrenzt = Factions.SanitizeRanks(zuviele, raenge)
pruefe('Mehr als acht Raenge werden gekappt',
    #begrenzt <= Factions.MaxRanks, #begrenzt)
pruefe('Oberster Rang bekommt alle Rechte',
    begrenzt[#begrenzt].permissions == 'all')

gruppe('Fraktionen: Wappen')

local wappen = Factions.DefaultEmblem()
pruefe('Standardwappen hat eine Form', wappen.shape ~= nil)
pruefe('Standardwappen hat gueltige Farbe',
    wappen.primary:match('^#%x%x%x%x%x%x$') ~= nil)

local boese = Factions.SanitizeEmblem({
    shape = 'gibtesnicht', primary = 'javascript:alert(1)',
    motto = string.rep('x', 500),
}, wappen)

pruefe('Unbekannte Form faellt zurueck', boese.shape == wappen.shape)
pruefe('Ungueltige Farbe faellt zurueck', boese.primary == wappen.primary)
pruefe('Zu langes Motto wird gekuerzt', #boese.motto <= 64, #boese.motto)

gruppe('Fraktionen: Skilltree')

local baumIds = {}
for _, knoten in ipairs(Factions.SkillTree) do baumIds[knoten.id] = true end

for _, knoten in ipairs(Factions.SkillTree) do
    for _, benoetigt in ipairs(knoten.requires or {}) do
        pruefe(('%s: Voraussetzung "%s" gibt es'):format(knoten.id, benoetigt),
            baumIds[benoetigt] == true)
    end

    for stufe = 1, knoten.maxRank do
        pruefe(('%s Stufe %d kostet Punkte'):format(knoten.id, stufe),
            Factions.GetSkillCost(knoten, stufe) > 0)
    end
end

local vollerBaum = {}
for _, knoten in ipairs(Factions.SkillTree) do vollerBaum[knoten.id] = knoten.maxRank end

local boni = Factions.SumSkills(vollerBaum)

-- Genaue Sollwerte, damit eine Aenderung am Baum auffaellt. Reine
-- Obergrenzen wuerden das nicht merken - die Kappungen bei Shop- und
-- Fahrzeugrabatt greifen bei diesem Baum ohnehin nicht.
local function nahe(a, b) return math.abs(a - b) < 0.0001 end

pruefe('Shoprabatt des vollen Baums ist 18 %',
    nahe(boni.shopDiscount, 0.18), boni.shopDiscount)
pruefe('Fahrzeugrabatt des vollen Baums ist 20 %',
    nahe(boni.vehicleDiscount, 0.20), boni.vehicleDiscount)
pruefe('Einnahmetempo des vollen Baums ist 60 %',
    nahe(boni.captureSpeed, 0.60), boni.captureSpeed)
pruefe('Voller Baum gibt Mitgliederplaetze', boni.memberSlots > 0)

-- Die Kappungen selbst pruefen. Ueber den echten Baum geht das nicht - er
-- bleibt unter allen Grenzen. Also einen kuenstlichen Knoten einschleusen,
-- der weit darueber liegt, und danach wieder entfernen.
local schummel = {
    id = '__test__', label = 'Test', icon = '?', row = 0, col = 0,
    maxRank = 1, cost = 1,
    effect = { shopDiscount = 5.0, vehicleDiscount = 5.0, captureSpeed = 5.0 },
}

Factions.SkillTree[#Factions.SkillTree + 1] = schummel
Factions.SkillById[schummel.id] = schummel

local gekappt = Factions.SumSkills({ __test__ = 1 })

pruefe('Shoprabatt wird bei 40 % gekappt',
    gekappt.shopDiscount == 0.40, gekappt.shopDiscount)
pruefe('Fahrzeugrabatt wird bei 40 % gekappt',
    gekappt.vehicleDiscount == 0.40, gekappt.vehicleDiscount)
pruefe('Einnahmetempo wird bei 60 % gekappt',
    gekappt.captureSpeed == 0.60, gekappt.captureSpeed)

Factions.SkillTree[#Factions.SkillTree] = nil
Factions.SkillById[schummel.id] = nil

pruefe('Der Testknoten ist wieder weg', Factions.GetSkill('__test__') == nil)

gruppe('Fraktionen: Gebiete')

local ok2, doppelt2 = eindeutig(Factions.Territories, 'id')
pruefe('Gebiets-Ids sind eindeutig', ok2, doppelt2)

for _, gebiet in ipairs(Factions.Territories) do
    pruefe(('%s hat Radius > 0'):format(gebiet.id), gebiet.radius > 0)
    pruefe(('%s wirft etwas ab'):format(gebiet.id), gebiet.income > 0)
end

-- ===========================================================================
-- Welt
-- ===========================================================================

laden('moonshine-world/shared/config.lua')
laden('moonshine-world/shared/phases.lua')
laden('moonshine-world/shared/events.lua')

gruppe('Welt: Mondphasen')

pruefe('Es gibt acht Phasen', #World.Phases == 8, #World.Phases)

local ok3, doppelt3 = eindeutig(World.Phases, 'id')
pruefe('Phasen-Ids sind eindeutig', ok3, doppelt3)

-- Der Zyklus muss sich schliessen
for tag = 0, 23 do
    local phase = World.GetPhaseForDay(tag)
    local spaeter = World.GetPhaseForDay(tag + 8)

    pruefe(('Tag %d und Tag %d haben dieselbe Phase'):format(tag, tag + 8),
        phase.id == spaeter.id)
end

pruefe('Vollmond kommt im Zyklus vor', (function()
    for tag = 0, 7 do
        if World.GetPhaseForDay(tag).id == 'vollmond' then return true end
    end
    return false
end)())

gruppe('Welt: Ereignisse')

local ok4, doppelt4 = eindeutig(World.Events, 'id')
pruefe('Ereignis-Ids sind eindeutig', ok4, doppelt4)

for _, ereignis in ipairs(World.Events) do
    pruefe(('%s dauert laenger als null'):format(ereignis.id), ereignis.duration > 0)
    pruefe(('%s hat ein Gewicht'):format(ereignis.id), ereignis.weight > 0)
    pruefe(('%s hat einen Farbwert'):format(ereignis.id),
        ereignis.tint and ereignis.tint:match('^#%x%x%x%x%x%x$') ~= nil)

    if ereignis.forceHour then
        pruefe(('%s erzwingt eine gueltige Stunde'):format(ereignis.id),
            ereignis.forceHour >= 0 and ereignis.forceHour < 24, ereignis.forceHour)
    end

    -- Jede Klasse, die ein Ereignis nennt, muss es geben
    for rasse in pairs(ereignis.races or {}) do
        pruefe(('%s nennt die bekannte Klasse "%s"'):format(ereignis.id, rasse),
            Mystic.Races[rasse] ~= nil)
    end
end

gruppe('Welt: Modifikatoren')

local ohne = World.BuildModifiers(nil, nil, nil)
pruefe('Ohne Phase und Ereignis gibt es nichts', next(ohne) == nil)

local blutmond = World.BuildModifiers('vampir', nil, 'blutmond')
pruefe('Blutmond staerkt Vampire', (blutmond.damageMult or 0) > 0, blutmond.damageMult)

local fee = World.BuildModifiers('fee', nil, 'blutmond')
pruefe('Blutmond staerkt Feen nicht besonders',
    (fee.damageMult or 0) < (blutmond.damageMult or 0))

-- Phase und Ereignis addieren sich
local nurPhase = World.BuildModifiers('werwolf', 'vollmond', nil)
local nurEvent = World.BuildModifiers('werwolf', nil, 'blutmond')
local beides   = World.BuildModifiers('werwolf', 'vollmond', 'blutmond')

pruefe('Phase und Ereignis addieren sich',
    math.abs((beides.damageMult or 0)
        - ((nurPhase.damageMult or 0) + (nurEvent.damageMult or 0))) < 0.0001,
    beides.damageMult)

gruppe('Welt: Eingriffe')

local standard = World.BuildWorldEffects(nil)
pruefe('Ohne Ereignis bleibt das Bossintervall unveraendert',
    standard.bossInterval == 1.0)
pruefe('Ohne Ereignis gibt es keine Zusatzsteine', standard.stoneBonus == 0)

local jagd = World.BuildWorldEffects('wilde_jagd')
pruefe('Wilde Jagd verkuerzt das Bossintervall', jagd.bossInterval < 1.0, jagd.bossInterval)

local finsternis = World.BuildWorldEffects('sonnenfinsternis')
pruefe('Sonnenfinsternis nimmt dem Sonnenlicht die Kraft',
    finsternis.sunlightDamage == 0.0)

-- ===========================================================================
-- Arbeit
-- ===========================================================================

laden('moonshine-jobs/shared/config.lua')
laden('moonshine-jobs/shared/jobs.lua')

gruppe('Arbeit: Auftraege')

for _, id in ipairs(Work.Order) do
    local job = Work.GetJob(id)
    pruefe(('Auftrag "%s" gibt es'):format(id), job ~= nil)

    if job then
        pruefe(('%s hat genug Stationen'):format(id),
            #job.stops >= WorkConfig.Shift.stops,
            ('%d von %d'):format(#job.stops, WorkConfig.Shift.stops))

        pruefe(('%s zahlt je Station'):format(id), job.pay > 0)
        pruefe(('%s zahlt zum Abschluss'):format(id), job.finalPay > 0)
        pruefe(('%s hat einen Anmeldepunkt'):format(id), job.start and job.start.coords)

        local ok5, doppelt5 = eindeutig(job.stops, 'label')
        pruefe(('%s: Stationsnamen sind eindeutig'):format(id), ok5, doppelt5)
    end
end

gruppe('Arbeit: Stationsauswahl')

for _, id in ipairs(Work.Order) do
    local job = Work.GetJob(id)
    local gezogen = Work.PickStops(job, WorkConfig.Shift.stops)

    pruefe(('%s zieht die richtige Anzahl'):format(id),
        #gezogen == WorkConfig.Shift.stops, #gezogen)

    local ok6, doppelt6 = eindeutig(gezogen, 'label')
    pruefe(('%s zieht ohne Wiederholung'):format(id), ok6, doppelt6)
end

-- Mehr anfordern als es gibt, darf nicht mehr liefern
local job = Work.GetJob(Work.Order[1])
pruefe('Mehr Stationen anfordern als vorhanden liefert hoechstens alle',
    #Work.PickStops(job, 999) == #job.stops)

gruppe('Arbeit: Lohn')

for _ = 1, 200 do
    local lohn = Work.RollPay(1000)
    pruefe('Lohn bleibt in der Streuung', lohn >= 800 and lohn <= 1200, lohn)
end

-- ===========================================================================
-- Fahrzeuge, Dienste, Auktion, Aussehen
-- ===========================================================================

laden('moonshine-vehicles/shared/config.lua')
laden('moonshine-vehicles/shared/catalogue.lua')

gruppe('Fahrzeuge: Katalog')

local ok7, doppelt7 = eindeutig(Vehicles.Catalogue, 'model')
pruefe('Fahrzeugmodelle sind eindeutig', ok7, doppelt7)

local kategorienIds = {}
for _, k in ipairs(Vehicles.Categories) do kategorienIds[k.id] = true end

for _, fahrzeug in ipairs(Vehicles.Catalogue) do
    pruefe(('%s hat eine bekannte Kategorie'):format(fahrzeug.model),
        kategorienIds[fahrzeug.category] == true, fahrzeug.category)
    pruefe(('%s kostet etwas'):format(fahrzeug.model), fahrzeug.price > 0)
    pruefe(('%s hat 1 bis 5 Leistung'):format(fahrzeug.model),
        fahrzeug.speed >= 1 and fahrzeug.speed <= 5)
end

for _, haendler in ipairs(VehicleConfig.Dealers) do
    pruefe(('Haendler %s fuehrt etwas'):format(haendler.id),
        #Vehicles.GetForDealer(haendler) > 0)

    for _, kategorie in ipairs(haendler.categories) do
        pruefe(('Haendler %s nennt die bekannte Kategorie "%s"'):format(
            haendler.id, kategorie), kategorienIds[kategorie] == true)
    end
end

local ok8, doppelt8 = eindeutig(VehicleConfig.Garages, 'id')
pruefe('Garagen-Ids sind eindeutig', ok8, doppelt8)

laden('moonshine-services/shared/config.lua')
laden('moonshine-services/shared/locations.lua')

gruppe('Dienste: Reparaturpreis')

pruefe('Heiles Fahrzeug kostet nur die Grundgebuehr',
    Services.RepairPrice(100, 100, 0) == ServiceConfig.Repair.baseFee)

pruefe('Kaputtes Fahrzeug kostet mehr als ein heiles',
    Services.RepairPrice(0, 0, 0) > Services.RepairPrice(100, 100, 0))

pruefe('Rabatt macht es guenstiger',
    Services.RepairPrice(50, 50, 0.5) < Services.RepairPrice(50, 50, 0))

-- Je kaputter, desto teurer
local vorheriger = -1
for zustand = 100, 0, -10 do
    local preis = Services.RepairPrice(zustand, zustand, 0)
    pruefe(('Zustand %d kostet mehr als der bessere'):format(zustand),
        preis > vorheriger, preis)
    vorheriger = preis
end

gruppe('Dienste: Orte')

for _, station in ipairs(Services.FuelStations) do
    pruefe(('%s hat Zapfsaeulen'):format(station.label), #station.pumps > 0)
end

pruefe('Es gibt Geldautomaten', #Services.Atms > 0, #Services.Atms)

local ok9, doppelt9 = eindeutig(Services.BlackMarkets, 'id')
pruefe('Schwarzmarkt-Orte sind eindeutig', ok9, doppelt9)
pruefe('Mehr als ein Schwarzmarkt-Ort', #Services.BlackMarkets > 1)

laden('moonshine-auction/shared/config.lua')

gruppe('Auktion')

pruefe('Mindestgebot liegt ueber dem Stand', Auction.MinimumBid(1000) > 1000)
pruefe('Mindestschritt greift bei kleinen Betraegen',
    Auction.MinimumBid(100) >= 100 + AuctionConfig.MinIncrement)
pruefe('Anteiliger Schritt greift bei grossen Betraegen',
    Auction.MinimumBid(1000000) >= 1000000 * (1 + AuctionConfig.MinIncrementRatio))

pruefe('Gesperrte Gegenstaende bleiben gesperrt', Auction.IsBlocked('id_card'))
pruefe('Alles andere ist handelbar', not Auction.IsBlocked('runenstein'))

pruefe('Kisten landen in ihrer Kategorie',
    Auction.GetCategory('kiste_gold') == 'kisten')
pruefe('Steine landen in ihrer Kategorie',
    Auction.GetCategory('runenstein') == 'steine')
pruefe('Unbekanntes landet unter sonstiges',
    Auction.GetCategory('irgendwas') == 'sonstiges')

pruefe('Sofortkauf braucht eine Laufzeit', #AuctionConfig.Durations > 0)

laden('moonshine-appearance/shared/config.lua')
laden('moonshine-appearance/shared/data.lua')

gruppe('Aussehen')

for _, geschlecht in ipairs({ 'm', 'w' }) do
    local standard = Appearance.Default(geschlecht)

    pruefe(('Standard fuer "%s" hat ein Modell'):format(geschlecht),
        type(standard.model) == 'string')

    for _, teil in ipairs(Appearance.Components) do
        pruefe(('Standard "%s" kennt Teil %d'):format(geschlecht, teil.id),
            standard.components[tostring(teil.id)] ~= nil)
    end

    for _, auflage in ipairs(Appearance.Overlays) do
        pruefe(('Standard "%s" kennt Auflage %d'):format(geschlecht, auflage.id),
            standard.overlays[tostring(auflage.id)] ~= nil)
    end

    for _, zug in ipairs(Appearance.Features) do
        pruefe(('Standard "%s" kennt Zug %d'):format(geschlecht, zug.id),
            standard.features[tostring(zug.id)] ~= nil)
    end

    -- Niemand soll nackt starten
    pruefe(('Standard "%s" traegt ein Oberteil'):format(geschlecht),
        standard.components['11'].drawable > 0)
    pruefe(('Standard "%s" traegt eine Hose'):format(geschlecht),
        standard.components['4'].drawable > 0)
end

local ok10, doppelt10 = eindeutig(Appearance.Components, 'id')
pruefe('Kleidungs-Ids sind eindeutig', ok10, doppelt10)

local ok11, doppelt11 = eindeutig(Appearance.Overlays, 'id')
pruefe('Auflagen-Ids sind eindeutig', ok11, doppelt11)

pruefe('Es gibt 20 Gesichtszuege', #Appearance.Features == 20, #Appearance.Features)
pruefe('Vater und Mutter haben gleich viele Vorlagen',
    #Appearance.Parents.male == #Appearance.Parents.female)


-- ===========================================================================
-- Klassenbeduerfnisse
-- ===========================================================================

laden('moonshine-needs/shared/config.lua')
laden('moonshine-needs/shared/needs.lua')

gruppe('Beduerfnisse: jede Klasse hat eines')

for rasse in pairs(Mystic.Races) do
    local beduerfnis = Needs.Get(rasse)
    pruefe(('%s hat ein Beduerfnis'):format(rasse), beduerfnis ~= nil)

    if beduerfnis then
        pruefe(('%s: Verfall groesser null'):format(rasse),
            beduerfnis.decayPerTick > 0, beduerfnis.decayPerTick)
        pruefe(('%s: mindestens zwei Quellen'):format(rasse),
            #beduerfnis.sources >= 2, #beduerfnis.sources)
        pruefe(('%s: hat Farbe und Symbol'):format(rasse),
            beduerfnis.colour ~= nil and beduerfnis.icon ~= nil)
        pruefe(('%s: Farbe ist gueltig'):format(rasse),
            beduerfnis.colour:match('^#%x%x%x%x%x%x$') ~= nil, beduerfnis.colour)

        for _, quelle in ipairs(beduerfnis.sources) do
            pruefe(('%s/%s: Menge groesser null'):format(rasse, quelle.kind),
                (quelle.amount or 0) > 0)

            if quelle.kind == 'item' then
                pruefe(('%s: Item "%s" ist definiert'):format(rasse, quelle.item),
                    Needs.Items[quelle.item] ~= nil)
            elseif quelle.kind == 'zone' then
                pruefe(('%s: Zone "%s" gibt es'):format(rasse, quelle.zone),
                    Needs.Zones[quelle.zone] ~= nil)
            elseif quelle.kind == 'npc' or quelle.kind == 'downed' then
                pruefe(('%s/%s: hat eine Beschriftung'):format(rasse, quelle.kind),
                    type(quelle.label) == 'string')
                pruefe(('%s/%s: hat eine Dauer'):format(rasse, quelle.kind),
                    (quelle.duration or 0) > 0)
            end
        end
    end
end

gruppe('Beduerfnisse: keine Klasse haengt an einer einzigen Quellart')

for rasse in pairs(Mystic.Races) do
    local beduerfnis = Needs.Get(rasse)

    if beduerfnis then
        local arten = {}
        for _, quelle in ipairs(beduerfnis.sources) do arten[quelle.kind] = true end

        local anzahl = 0
        for _ in pairs(arten) do anzahl = anzahl + 1 end

        pruefe(('%s hat mehr als eine Quellart'):format(rasse), anzahl >= 2, anzahl)
    end
end

gruppe('Beduerfnisse: Bereiche')

pruefe('100 ist satt', Needs.GetBand(100) == 'satt')
pruefe('60 ist normal', Needs.GetBand(60) == 'normal')
pruefe('30 ist Warnung', Needs.GetBand(30) == 'warnung')
pruefe('10 ist schwach', Needs.GetBand(10) == 'schwach')
pruefe('0 ist leer', Needs.GetBand(0) == 'leer')

-- Die Schwellen muessen absteigend und ohne Luecke sein
local schwellen = NeedsConfig.Thresholds
pruefe('Schwellen sind absteigend',
    schwellen.satt > schwellen.warnung
    and schwellen.warnung > schwellen.schwach
    and schwellen.schwach > schwellen.leer)

-- Jeder Wert von 0 bis 100 muss in genau einem Bereich landen
for wert = 0, 100 do
    local band = Needs.GetBand(wert)
    pruefe(('Wert %d hat einen Bereich'):format(wert),
        NeedsConfig.Effects[band] ~= nil, band)
end

gruppe('Beduerfnisse: Wirkung')

local satt = Needs.GetEffects(100)
pruefe('Satt gibt Essenzregeneration', (satt.essenceRegen or 0) > 0)

local leer = Needs.GetEffects(0)
pruefe('Leer nimmt Essenzregeneration', (leer.essenceRegen or 0) < 0)
pruefe('Leer bremst', (leer.speedMult or 0) < 0)

-- Je schlechter, desto schlimmer
pruefe('Leer ist schlimmer als schwach',
    (Needs.GetEffects(0).essenceRegen or 0) < (Needs.GetEffects(10).essenceRegen or 0))
pruefe('Schwach ist schlimmer als Warnung',
    (Needs.GetEffects(10).essenceRegen or 0) < (Needs.GetEffects(30).essenceRegen or 0))

-- Die Wirkung darf nicht durchschlagen
local kopie = Needs.GetEffects(0)
kopie.essenceRegen = 999
pruefe('GetEffects liefert eine Kopie',
    (Needs.GetEffects(0).essenceRegen or 0) ~= 999)

gruppe('Beduerfnisse: Zonen')

for art, zone in pairs(Needs.Zones) do
    pruefe(('Zone %s hat Orte'):format(art), #zone.orte > 0)
    pruefe(('Zone %s hat Symbol und Bezeichnung'):format(art),
        zone.icon ~= nil and zone.label ~= nil)

    for _, ort in ipairs(zone.orte) do
        pruefe(('%s/%s hat Radius groesser null'):format(art, ort.label),
            ort.radius > 0)
    end
end

-- Ein Punkt mitten in einer Zone muss gefunden werden
local naturOrt = Needs.Zones.natur.orte[1]
local gefunden = Needs.ZoneAt(naturOrt.coords)
pruefe('Mitten in einer Zone wird sie erkannt', gefunden == 'natur', tostring(gefunden))

-- Weit ausserhalb darf nichts gefunden werden
pruefe('Weit draussen ist keine Zone',
    Needs.ZoneAt(vector3(9000.0, 9000.0, 9000.0)) == nil)

gruppe('Beduerfnisse: Zuordnung der Gegenstaende')

for name in pairs(Needs.Items) do
    local rasse = Needs.RaceForItem(name)
    pruefe(('Item "%s" gehoert zu einer Klasse'):format(name),
        rasse ~= nil and Mystic.Races[rasse] ~= nil, tostring(rasse))
end

pruefe('Unbekanntes Item gehoert zu niemandem',
    Needs.RaceForItem('gibtesnicht') == nil)

-- Feenstaub fuellt sich an der Natur, nicht am Friedhof
pruefe('Fee fuellt sich in der Natur', Needs.ZoneAmount('fee', 'natur') > 0)
pruefe('Fee fuellt sich nicht auf dem Friedhof',
    Needs.ZoneAmount('fee', 'friedhof') == 0)
pruefe('Nekromant fuellt sich auf dem Friedhof',
    Needs.ZoneAmount('nekromant', 'friedhof') > 0)

-- ===========================================================================
-- Ritualkrieg
-- ===========================================================================

laden('moonshine-ritualwar/shared/config.lua')

gruppe('Ritualkrieg: Ritualpunkte')

-- Die Ids sind der Schluessel in der Datenbank. Doppelte wuerden sich
-- gegenseitig ueberschreiben.
local idsOk, doppelte = eindeutig(MysticConfig.RitualPoints, 'id')
pruefe('Ritualpunkt-Ids sind eindeutig', idsOk, doppelte)

for _, punkt in ipairs(MysticConfig.RitualPoints) do
    pruefe(('Punkt %s laesst sich ueber die Id finden'):format(punkt.id),
        Mystic.GetRitualPoint(punkt.id) == punkt)

    pruefe(('Punkt %s wird an seinen eigenen Koordinaten erkannt'):format(punkt.id),
        Mystic.IsNearRitualPoint(punkt.coords) ~= nil)

    pruefe(('Punkt %s passt in VARCHAR(32)'):format(punkt.id), #punkt.id <= 32)
end

pruefe('Unbekannte Id liefert nichts', Mystic.GetRitualPoint('gibtesnicht') == nil)
pruefe('Weit draussen ist kein Ritualpunkt',
    Mystic.IsNearRitualPoint(vector3(9000.0, 9000.0, 9000.0)) == nil)

gruppe('Ritualkrieg: Bindung')

-- 180 Sekunden Ritual, alle 2 Sekunden ein Durchlauf: der Balken muss nach
-- genau 90 Durchlaeufen voll sein.
local proSekunde = RitualWar.ProgressPerSecond()
local durchlaeufe = WarConfig.Binding.duration / WarConfig.TickInterval
local balken = 0.0
for _ = 1, durchlaeufe do balken = balken + proSekunde * WarConfig.TickInterval end

pruefe('Der Balken ist nach der vollen Dauer voll',
    math.abs(balken - 100.0) < 0.001, balken)

pruefe('Nach der halben Dauer ist er halb voll',
    math.abs(proSekunde * (WarConfig.Binding.duration / 2) - 50.0) < 0.001)

-- Ein verlassenes Ritual darf nicht ewig stehen bleiben: der Verfall muss
-- einen vollen Balken schneller leeren, als eine frische Bindung dauert.
pruefe('Ein verlassener Balken leert sich schneller als eine neue Bindung',
    RitualWar.DecayTime() < WarConfig.Binding.duration,
    ('%.0f s Verfall gegen %d s Bindung'):format(
        RitualWar.DecayTime(), WarConfig.Binding.duration))

pruefe('Der Verfall ist mit 50 Sekunden angesetzt',
    math.abs(RitualWar.DecayTime() - 50.0) < 0.001, RitualWar.DecayTime())

pruefe('Eine Bindung braucht mehr als eine Person', WarConfig.Binding.minMembers >= 2)

-- Ein gestoertes Ritual steht still. Die Obergrenze muss laenger sein als
-- eine ungestoerte Bindung, sonst laeuft sie schon im Normalfall ab.
pruefe('Die Obergrenze liegt ueber der normalen Bindungsdauer',
    WarConfig.Binding.maxDuration > WarConfig.Binding.duration,
    ('%d gegen %d Sekunden'):format(WarConfig.Binding.maxDuration,
        WarConfig.Binding.duration))

pruefe('Die Obergrenze laesst Raum fuer eine echte Auseinandersetzung',
    WarConfig.Binding.maxDuration >= WarConfig.Binding.duration * 2)

pruefe('Die Reichweite ist groesser als jeder Punktradius', (function()
    for _, punkt in ipairs(MysticConfig.RitualPoints) do
        if WarConfig.Binding.range <= punkt.radius then return false end
    end
    return true
end)())

pruefe('Der Skill fuer die Einzelbindung heisst wie im Fraktionsbaum',
    Factions.SumSkills({}).soloCapture ~= nil)

pruefe('Das Recht fuer die Bindung gibt es im Rangsystem',
    Factions.PermissionById[WarConfig.Binding.permission] ~= nil,
    WarConfig.Binding.permission)

gruppe('Ritualkrieg: Wegzoll')

-- Handgerechnet: 1000 $ Ritualertrag, 25 % Zoll, 20 % Mitgliederbonus.
local fremdBetrag, fremdZoll = RitualWar.Split(1000, 'fremd')
pruefe('Fremde zahlen 250 von 1000', fremdZoll == 250, fremdZoll)
pruefe('Fremden bleiben 750 von 1000', fremdBetrag == 750, fremdBetrag)

local eigenBetrag, eigenZoll = RitualWar.Split(1000, 'eigen')
pruefe('Mitglieder bekommen 1200 von 1000', eigenBetrag == 1200, eigenBetrag)
pruefe('Mitglieder zahlen keinen Zoll', eigenZoll == 0, eigenZoll)

local freiBetrag, freiZoll = RitualWar.Split(1000, 'frei')
pruefe('Am ungebundenen Punkt bleibt alles beim Spieler', freiBetrag == 1000)
pruefe('Am ungebundenen Punkt faellt kein Zoll an', freiZoll == 0)

-- Nichts darf aus dem Nichts entstehen: was der Fremde verliert, landet in
-- der Kasse, keinen Cent mehr.
pruefe('Betrag und Zoll ergeben zusammen wieder den Ertrag',
    fremdBetrag + fremdZoll == 1000)

pruefe('Ein Ertrag von null bleibt null', (RitualWar.Split(0, 'fremd')) == 0)
pruefe('Ein negativer Ertrag bleibt bei null', (RitualWar.Split(-50, 'fremd')) == 0)

-- Der Punkt muss sich fuer Mitglieder lohnen und fuer Fremde weh tun.
pruefe('Mitglieder stehen besser da als Fremde', eigenBetrag > fremdBetrag)
pruefe('Fremde stehen schlechter da als am freien Punkt', fremdBetrag < freiBetrag)

gruppe('Ritualkrieg: Meditation')

pruefe('Mitglieder meditieren mit Faktor 1.2',
    math.abs(RitualWar.MeditationFactorFor('eigen') - 1.2) < 0.0001,
    RitualWar.MeditationFactorFor('eigen'))

pruefe('Fremde meditieren mit Faktor 0.7',
    math.abs(RitualWar.MeditationFactorFor('fremd') - 0.7) < 0.0001,
    RitualWar.MeditationFactorFor('fremd'))

pruefe('Am freien Punkt bleibt es bei 1.0',
    RitualWar.MeditationFactorFor('frei') == 1.0)

-- Ein Fremder darf nie ganz leer ausgehen, sonst ist der Punkt fuer alle
-- anderen tot statt teuer.
pruefe('Die Strafe fuer Fremde frisst nicht alles',
    RitualWar.MeditationFactorFor('fremd') > 0.0)

gruppe('Ritualkrieg: Wirtschaft')

-- Der Punkt muss sich einspielen, sonst bindet ihn niemand. Bewertet mit
-- dem Preis, zu dem der Steinhaendler Grundsteine verkauft.
local proAusschuettung = 0
for _, eintrag in ipairs(WarConfig.Income.stones) do
    proAusschuettung = proAusschuettung
        + ((eintrag.min + eintrag.max) / 2) * MysticConfig.Merchant.price
end

local ausschuettungen = math.ceil(WarConfig.Binding.cost / proAusschuettung)
local stunden = (ausschuettungen * WarConfig.Income.interval) / 60

pruefe('Ein Punkt spielt seine Kosten in unter zehn Stunden ein',
    stunden < 10, ('%.1f Stunden'):format(stunden))

pruefe('Ein Punkt ist nicht binnen einer Stunde bezahlt',
    stunden > 1, ('%.1f Stunden'):format(stunden))

-- Die Schutzzeit muss mindestens eine Ausschuettung abdecken, sonst kann
-- eine Fraktion den Punkt halten, ohne je etwas davon zu haben.
pruefe('Die Schutzzeit deckt mindestens eine Ausschuettung',
    WarConfig.Binding.protection >= WarConfig.Income.interval,
    ('%d gegen %d Minuten'):format(WarConfig.Binding.protection,
        WarConfig.Income.interval))

pruefe('Die Rueckzahlung liegt zwischen null und voll',
    WarConfig.Binding.refund >= 0 and WarConfig.Binding.refund <= 1)

pruefe('Ein Abbruch kostet etwas', WarConfig.Binding.refund < 1)

for _, eintrag in ipairs(WarConfig.Income.stones) do
    pruefe(('Ertragsstein %s ist ein Grundstein'):format(eintrag.item),
        Mystic.Stones[eintrag.item] ~= nil)

    pruefe(('Ertrag %s hat sinnvolle Grenzen'):format(eintrag.item),
        eintrag.min >= 1 and eintrag.max >= eintrag.min)
end

gruppe('Ritualkrieg: Stoerung und Segen')

-- Wer stoeren will, muss das innerhalb eines laufenden Rituals schaffen.
pruefe('Eine Stoerung greift, bevor ein Ritual fertig ist',
    WarConfig.Disruption.delay < MysticConfig.Ritual.duration,
    ('%d gegen %d Sekunden'):format(WarConfig.Disruption.delay,
        MysticConfig.Ritual.duration))

pruefe('Eine Stoerung greift auch waehrend einer Meditation',
    WarConfig.Disruption.delay < MysticConfig.Meditation.duration)

-- Der Stoerradius darf nicht groesser sein als der Bindungsradius, sonst
-- kann jemand eine Bindung von ausserhalb blockieren, ohne selbst zu zaehlen.
pruefe('Der Stoerradius liegt innerhalb des Bindungsradius',
    WarConfig.Disruption.range <= WarConfig.Binding.range)

pruefe('Der Segen reicht weiter als der Stoerradius',
    WarConfig.Blessing.range > WarConfig.Disruption.range)

for schluessel, wert in pairs(WarConfig.Blessing.effects) do
    pruefe(('Der Segen %s ist ein Vorteil'):format(schluessel), wert > 0, wert)
end

-- ===========================================================================

print(('\n%d bestanden, %d fehlgeschlagen.'):format(bestanden, fehlgeschlagen))
os.exit(fehlgeschlagen == 0 and 0 or 1)
