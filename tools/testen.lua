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

gruppe('Arbeit: besondere Ablaeufe')

-- Eine Linie faehrt man der Reihe nach. Gewuerfelt waere es keine Linie.
local bus = Work.GetJob('bus')
pruefe('Den Bus gibt es', bus ~= nil)
pruefe('Der Bus faehrt eine feste Route', bus.fixedRoute == true)

local route = Work.PickStops(bus, WorkConfig.Shift.stops)
for index, halt in ipairs(route) do
    pruefe(('Haltestelle %d steht an ihrer Stelle'):format(index),
        halt.label == bus.stops[index].label, halt.label)
end

-- Zweimal ziehen muss dieselbe Route ergeben.
local zweite = Work.PickStops(bus, WorkConfig.Shift.stops)
local gleich = true
for index, halt in ipairs(route) do
    if zweite[index].label ~= halt.label then gleich = false end
end
pruefe('Die Linie ist bei jeder Schicht dieselbe', gleich)

-- Die anderen Auftraege duerfen gerade nicht fest sein, sonst faehrt jeder
-- immer dieselbe Runde.
for _, id in ipairs(Work.Order) do
    if id ~= 'bus' then
        pruefe(('%s hat keine feste Route'):format(id),
            Work.GetJob(id).fixedRoute ~= true)
    end
end

-- Abschleppdienst: was verladen wird, muss auch abgeliefert werden.
local tow = Work.GetJob('tow')
pruefe('Den Abschleppdienst gibt es', tow ~= nil)
pruefe('Der Abschlepper liefert ab', tow.abliefern == true)
pruefe('Das Abliefern hat eine Beschriftung',
    type(tow.ablieferLabel) == 'string' and tow.ablieferLabel ~= '')
pruefe('Der Abschlepper hat ein Fahrzeug', tow.vehicle ~= nil)

-- Nachtwache: nur nachts, und sie zahlt dafuer besser als der Durchschnitt.
local wache = Work.GetJob('nachtwache')
pruefe('Die Nachtwache gibt es', wache ~= nil)
pruefe('Die Nachtwache geht nur nachts', wache.nurNachts == true)

local schnitt, anzahl = 0, 0
for _, id in ipairs(Work.Order) do
    if id ~= 'nachtwache' then
        schnitt = schnitt + Work.GetJob(id).pay
        anzahl = anzahl + 1
    end
end
schnitt = schnitt / anzahl

pruefe('Die Nachtwache zahlt ueber dem Schnitt',
    wache.pay > schnitt, ('%d gegen %.0f'):format(wache.pay, schnitt))

-- Genau ein Auftrag je Sonderregel - sonst ist es keine Besonderheit mehr.
local nachts, fest, liefert = 0, 0, 0
for _, id in ipairs(Work.Order) do
    local job = Work.GetJob(id)
    if job.nurNachts then nachts = nachts + 1 end
    if job.fixedRoute then fest = fest + 1 end
    if job.abliefern then liefert = liefert + 1 end
end

pruefe('Nur ein Auftrag laeuft nachts', nachts == 1, nachts)
pruefe('Nur ein Auftrag hat eine feste Route', fest == 1, fest)
pruefe('Nur ein Auftrag liefert ab', liefert == 1, liefert)

-- Jeder Auftrag braucht eine Handlung und eine Beschriftung dazu.
for _, id in ipairs(Work.Order) do
    local job = Work.GetJob(id)

    pruefe(('%s hat eine Handlung'):format(id),
        type(job.action) == 'string' and job.action ~= '')
    pruefe(('%s beschriftet seine Handlung'):format(id),
        type(job.actionLabel) == 'string' and job.actionLabel ~= '')
    pruefe(('%s hat eine Dauer ueber null'):format(id), (job.duration or 0) > 0)
    pruefe(('%s hat ein Zeichen'):format(id),
        type(job.icon) == 'string' and job.icon ~= '')
    pruefe(('%s hat eine Farbe'):format(id),
        type(job.colour) == 'string' and job.colour:match('^#%x%x%x%x%x%x$') ~= nil,
        job.colour)
end

-- Kein Anmeldepunkt darf zweimal vorkommen: sonst stehen zwei Marker
-- uebereinander und man meldet sich beim falschen an.
local plaetze, doppelt = {}, {}
for _, id in ipairs(Work.Order) do
    local start = Work.GetJob(id).start.coords

    for anderer, coords in pairs(plaetze) do
        if #(start - coords) < 10.0 then
            doppelt[#doppelt + 1] = ('%s/%s'):format(anderer, id)
        end
    end

    plaetze[id] = start
end
pruefe('Keine zwei Anmeldepunkte liegen uebereinander', #doppelt == 0,
    table.concat(doppelt, ', '))

pruefe('Es gibt sieben Auftraege', #Work.Order == 7, #Work.Order)

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
laden('moonshine-services/shared/tuning.lua')

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

gruppe('Dienste: Tuning-Katalog')

local okTeile, doppelteTeile = eindeutig(Services.Performance, 'id')
pruefe('Leistungsteile sind eindeutig', okTeile, doppelteTeile)

local okOptik, doppelteOptik = eindeutig(Services.Cosmetics, 'id')
pruefe('Anbauteile sind eindeutig', okOptik, doppelteOptik)

-- Zwei Teile duerfen nie dieselbe GTA-Modart belegen, sonst ueberschreibt
-- eins das andere.
local modarten, doppelteModarten = {}, {}
for _, liste in ipairs({ Services.Performance, Services.Cosmetics }) do
    for _, entry in ipairs(liste) do
        if modarten[entry.mod] then
            doppelteModarten[#doppelteModarten + 1] =
                ('%s/%s'):format(modarten[entry.mod], entry.id)
        end
        modarten[entry.mod] = entry.id
    end
end
pruefe('Keine Modart kommt zweimal vor', #doppelteModarten == 0,
    table.concat(doppelteModarten, ', '))

pruefe('Der Turbo belegt keine fremde Modart', modarten[Services.Turbo.mod] == nil)

for _, entry in ipairs(Services.Performance) do
    pruefe(('%s hat Stufenpreise'):format(entry.id), #entry.preise > 0)

    -- Jede weitere Stufe muss teurer sein als die davor, sonst lohnt sich
    -- die kleinere nie.
    local steigend = true
    for index = 2, #entry.preise do
        if entry.preise[index] <= entry.preise[index - 1] then steigend = false end
    end

    pruefe(('%s wird mit jeder Stufe teurer'):format(entry.id), steigend)
    pruefe(('%s laesst sich ueber die Id finden'):format(entry.id),
        Services.GetPerformance(entry.id) == entry)
end

for _, entry in ipairs(Services.Cosmetics) do
    pruefe(('%s kostet etwas'):format(entry.id), entry.preis > 0)
    pruefe(('%s laesst sich ueber die Id finden'):format(entry.id),
        Services.GetCosmetic(entry.id) == entry)
end

pruefe('Unbekanntes Teil liefert nichts', Services.GetPart('gibtesnicht') == nil)
pruefe('GetPart findet Leistungsteile', Services.GetPart('motor') ~= nil)
pruefe('GetPart findet Anbauteile', Services.GetPart('spoiler') ~= nil)
pruefe('GetPart findet den Turbo', Services.GetPart('turbo') == Services.Turbo)

gruppe('Dienste: Tuning-Preise')

-- Handgerechnet gegen den Katalog: Motorstufen 12.000 / 26.000 / 48.000 / 85.000.
pruefe('Motor Serie kostet nichts', Services.PerformancePrice('motor', -1) == 0)
pruefe('Motor Stufe 1 kostet 12.000',
    Services.PerformancePrice('motor', 0) == 12000,
    Services.PerformancePrice('motor', 0))
pruefe('Motor Stufe 4 kostet 85.000',
    Services.PerformancePrice('motor', 3) == 85000,
    Services.PerformancePrice('motor', 3))

-- Ueber die letzte Stufe hinaus darf der Preis nicht auf null fallen.
pruefe('Eine zu hohe Stufe kostet die letzte',
    Services.PerformancePrice('motor', 99) == 85000,
    Services.PerformancePrice('motor', 99))

pruefe('Der Turbo kostet 62.000', Services.PerformancePrice('turbo', 1) == 62000)
pruefe('Ein abgeschalteter Turbo kostet nichts',
    Services.PerformancePrice('turbo', 0) == 0)

pruefe('Anbauteile kosten je Stufe gleich viel',
    Services.CosmeticPrice('spoiler', 0) == Services.CosmeticPrice('spoiler', 5))
pruefe('Ein Anbauteil auf Serie kostet nichts',
    Services.CosmeticPrice('spoiler', -1) == 0)

pruefe('Unbekanntes Teil kostet nichts', Services.PartPrice('gibtesnicht', 3) == 0)

-- Die Panzerung ist das teuerste Einzelteil; ein Fahrzeug soll dadurch
-- nicht guenstiger zu haben sein als durch Kaufen.
local teuerste = 0
for _, entry in ipairs(Services.Performance) do
    teuerste = math.max(teuerste, entry.preise[#entry.preise])
end
pruefe('Kein Leistungsteil kostet ueber 200.000', teuerste <= 200000, teuerste)

gruppe('Dienste: Tuning-Farben')

local okLack, doppelterLack = eindeutig(Services.Paints, 'id')
pruefe('Lackfarben sind eindeutig', okLack, doppelterLack)

for _, farbe in ipairs(Services.Paints) do
    pruefe(('Lack %s hat eine Bezeichnung'):format(farbe.id),
        type(farbe.label) == 'string' and farbe.label ~= '')

    pruefe(('Lack %s hat einen Farbwert'):format(farbe.id),
        type(farbe.hex) == 'string' and farbe.hex:match('^#%x%x%x%x%x%x$') ~= nil,
        farbe.hex)

    pruefe(('Lack %s wird erkannt'):format(farbe.id), Services.IsPaint(farbe.id))
end

pruefe('Eine erfundene Lackfarbe wird abgelehnt', not Services.IsPaint(999))

local okNeon, doppeltesNeon = eindeutig(Services.Neon, 'id')
pruefe('Neonfarben sind eindeutig', okNeon, doppeltesNeon)

for _, farbe in ipairs(Services.Neon) do
    pruefe(('Neon %s hat drei Kanaele'):format(farbe.id),
        farbe.r ~= nil and farbe.g ~= nil and farbe.b ~= nil)

    for _, kanal in ipairs({ farbe.r, farbe.g, farbe.b }) do
        pruefe(('Neon %s bleibt im Bereich'):format(farbe.id),
            kanal >= 0 and kanal <= 255, kanal)
    end

    pruefe(('Neon %s laesst sich finden'):format(farbe.id),
        Services.GetNeon(farbe.id) == farbe)
end

pruefe('Eine erfundene Neonfarbe liefert nichts',
    Services.GetNeon('gibtesnicht') == nil)

local okXenon, doppeltesXenon = eindeutig(Services.Xenon, 'id')
pruefe('Xenonfarben sind eindeutig', okXenon, doppeltesXenon)
pruefe('Xenon kennt den Standard', Services.IsXenon(-1))
pruefe('Eine erfundene Xenonfarbe wird abgelehnt', not Services.IsXenon(99))

-- Fensterfolie: Stufe 0 ist "keine" und muss umsonst sein, danach steigt es.
local okFolie, doppelteFolie = eindeutig(Services.Tints, 'id')
pruefe('Folienstufen sind eindeutig', okFolie, doppelteFolie)
pruefe('Keine Folie kostet nichts', Services.GetTint(0).preis == 0)

local vorher = -1
local folieSteigt = true
for _, folie in ipairs(Services.Tints) do
    if folie.preis < vorher then folieSteigt = false end
    vorher = folie.preis
end
pruefe('Dunklere Folie kostet mehr', folieSteigt)

pruefe('Eine erfundene Folienstufe liefert nichts', Services.GetTint(9) == nil)

-- Jeder Preis in der Config muss auch wirklich gesetzt sein.
for _, feld in ipairs({ 'lack', 'perlmutt', 'felgenfarbe', 'neon', 'xenon',
                        'rauch', 'kennzeichen' }) do
    pruefe(('Preis fuer %s ist gesetzt'):format(feld),
        type(ServiceConfig.Tuning.preise[feld]) == 'number'
            and ServiceConfig.Tuning.preise[feld] > 0)
end

pruefe('Der Mechanikerrabatt liegt unter der Haelfte',
    ServiceConfig.Tuning.mechanicDiscount > 0
        and ServiceConfig.Tuning.mechanicDiscount < 0.5)

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
laden('moonshine-appearance/shared/tattoos.lua')

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

gruppe('Aussehen: Taetowierungen')

local okTat, doppelTat = eindeutig(Appearance.Tattoos, 'id')
pruefe('Motiv-Ids sind eindeutig', okTat, doppelTat)

-- Zwei Motive duerfen nie denselben Aufdruck haben - sonst kauft man
-- zweimal dasselbe Bild unter verschiedenen Namen.
local aufdrucke, doppelteAufdrucke = {}, {}
for _, motiv in ipairs(Appearance.Tattoos) do
    for _, name in ipairs({ motiv.male, motiv.female }) do
        local schluessel = motiv.collection .. '/' .. name
        if aufdrucke[schluessel] then
            doppelteAufdrucke[#doppelteAufdrucke + 1] = schluessel
        end
        aufdrucke[schluessel] = true
    end
end
pruefe('Kein Aufdruck kommt zweimal vor', #doppelteAufdrucke == 0,
    table.concat(doppelteAufdrucke, ', '))

local sammlungen = {}
for _, name in pairs(Appearance.TattooCollections) do sammlungen[name] = true end

for _, motiv in ipairs(Appearance.Tattoos) do
    pruefe(('Motiv %s liegt in einer bekannten Zone'):format(motiv.id),
        Appearance.GetTattooZone(motiv.zone) ~= nil, motiv.zone)

    pruefe(('Motiv %s kommt aus einer bekannten Sammlung'):format(motiv.id),
        sammlungen[motiv.collection] == true, motiv.collection)

    pruefe(('Motiv %s hat fuer beide Geschlechter einen Aufdruck'):format(motiv.id),
        type(motiv.male) == 'string' and type(motiv.female) == 'string')

    pruefe(('Motiv %s unterscheidet Mann und Frau'):format(motiv.id),
        motiv.male ~= motiv.female)

    pruefe(('Motiv %s laesst sich ueber die Id finden'):format(motiv.id),
        Appearance.GetTattoo(motiv.id) == motiv)
end

-- Jede Zone muss etwas anzubieten haben, sonst steht sie leer im Studio.
for _, zone in ipairs(Appearance.TattooZones) do
    pruefe(('Zone %s hat Motive'):format(zone.key),
        #Appearance.TattoosInZone(zone.key) > 0)

    pruefe(('Zone %s hat einen Preisbereich'):format(zone.key),
        AppearanceConfig.Prices.tattoo[zone.tier] ~= nil, zone.tier)
end

pruefe('Unbekanntes Motiv liefert nichts', Appearance.GetTattoo('gibtesnicht') == nil)
pruefe('Unbekannte Zone liefert nichts', Appearance.GetTattooZone('nirgends') == nil)

-- Klassenmale: genau eines je Klasse, keines doppelt.
local male = {}
for _, motiv in ipairs(Appearance.Tattoos) do
    if motiv.race then
        pruefe(('Mal %s gehoert zu einer echten Klasse'):format(motiv.id),
            Mystic.Races[motiv.race] ~= nil, motiv.race)

        pruefe(('Klasse %s hat nur ein Mal'):format(motiv.race),
            male[motiv.race] == nil)

        male[motiv.race] = motiv
    end
end

for rasse in pairs(Mystic.Races) do
    pruefe(('Klasse %s hat ein Mal'):format(rasse), male[rasse] ~= nil)
end

-- Ein Mal kostet den Aufschlag, ein gewoehnliches Motiv nicht.
local malPreis = Appearance.TattooPrice('mal_vampir')
local normalPreis = Appearance.TattooPrice('brust_schaedel')

pruefe('Beide liegen in derselben Zone',
    Appearance.GetTattoo('mal_vampir').zone
        == Appearance.GetTattoo('brust_schaedel').zone)

pruefe('Brust kostet 12.000', normalPreis == 12000, normalPreis)
pruefe('Ein Klassenmal kostet das Dreifache', malPreis == 36000, malPreis)

-- Handgerechnet gegen die Konfiguration: klein 2.500, mittel 6.000.
pruefe('Ein Bein kostet 2.500', Appearance.TattooPrice('beinl_dolch') == 2500,
    Appearance.TattooPrice('beinl_dolch'))
pruefe('Ein Arm kostet 6.000', Appearance.TattooPrice('arml_runen') == 6000,
    Appearance.TattooPrice('arml_runen'))

pruefe('Unbekanntes Motiv kostet nichts', Appearance.TattooPrice('gibtesnicht') == 0)

-- Wegmachen muss teurer sein als stechen, sonst ist es keine Entscheidung.
pruefe('Entfernen kostet mehr als stechen',
    AppearanceConfig.Prices.tattooEntfernen > 1.0)
pruefe('Ein Klassenmal kostet mehr als ein gewoehnliches Motiv',
    AppearanceConfig.Prices.tattooMal > 1.0)

gruppe('Aussehen: Taetowierungen bereinigen')

pruefe('Eine leere Liste bleibt leer', #Appearance.SanitizeTattoos({}) == 0)
pruefe('Kein Wert ergibt eine leere Liste', #Appearance.SanitizeTattoos(nil) == 0)

local erfunden = Appearance.SanitizeTattoos({ 'gibtesnicht', 'auchnicht' })
pruefe('Erfundene Motive fliegen raus', #erfunden == 0, #erfunden)

local doppelt = Appearance.SanitizeTattoos({ 'brust_anker', 'brust_anker' })
pruefe('Doppelte Motive werden zusammengefasst', #doppelt == 1, #doppelt)

local gemischt = Appearance.SanitizeTattoos({
    'brust_anker', 'gibtesnicht', 'ruecken_drache', 42, 'brust_anker' })
pruefe('Aus der Mischung bleiben zwei', #gemischt == 2, #gemischt)
pruefe('Die Reihenfolge bleibt erhalten',
    gemischt[1] == 'brust_anker' and gemischt[2] == 'ruecken_drache')

pruefe('HasTattoo findet ein getragenes Motiv',
    Appearance.HasTattoo(gemischt, 'ruecken_drache'))
pruefe('HasTattoo findet nichts Fremdes',
    not Appearance.HasTattoo(gemischt, 'kopf_kreuz'))
pruefe('HasTattoo kommt mit nil klar',
    not Appearance.HasTattoo(nil, 'kopf_kreuz'))

-- Der Standardcharakter startet ohne Taetowierung.
for _, geschlecht in ipairs({ 'm', 'w' }) do
    pruefe(('Standard "%s" startet ohne Taetowierung'):format(geschlecht),
        #Appearance.Default(geschlecht).tattoos == 0)
end

-- Mann und Frau bekommen denselben Aufdruck in ihrer Fassung.
local probe = Appearance.GetTattoo('ruecken_adler')
pruefe('Mann bekommt die M-Fassung',
    Appearance.TattooOverlay(probe, 'm') == probe.male)
pruefe('Frau bekommt die F-Fassung',
    Appearance.TattooOverlay(probe, 'w') == probe.female)
pruefe('Ohne Motiv gibt es keinen Aufdruck',
    Appearance.TattooOverlay(nil, 'm') == nil)


-- ===========================================================================
-- Zufluchtsorte
-- ===========================================================================

laden('moonshine-refuge/shared/config.lua')
laden('moonshine-refuge/shared/places.lua')

gruppe('Zuflucht: Plaetze')

local okOrte, doppelteOrte = eindeutig(Refuge.Places, 'id')
pruefe('Platz-Ids sind eindeutig', okOrte, doppelteOrte)

for _, place in ipairs(Refuge.Places) do
    pruefe(('Platz %s hat eine Bezeichnung'):format(place.id),
        type(place.label) == 'string' and place.label ~= '')
    pruefe(('Platz %s kostet etwas'):format(place.id), place.preis > 0)
    pruefe(('Platz %s hat einen Zutritt'):format(place.id), place.zutritt ~= nil)
    pruefe(('Platz %s hat einen Aufwachpunkt'):format(place.id), place.aufwachen ~= nil)
    pruefe(('Platz %s passt in VARCHAR(32)'):format(place.id), #place.id <= 32)

    pruefe(('Platz %s laesst sich ueber die Id finden'):format(place.id),
        Refuge.GetPlace(place.id) == place)

    -- Zutritt und Aufwachpunkt duerfen nicht weit auseinanderliegen: man
    -- soll vor seiner Tuer aufwachen, nicht im Meer.
    local weg = #(place.zutritt - vector3(place.aufwachen.x, place.aufwachen.y,
        place.aufwachen.z))
    pruefe(('Platz %s: Aufwachpunkt liegt beim Zutritt'):format(place.id),
        weg < 8.0, ('%.1f m'):format(weg))
end

pruefe('Unbekannter Platz liefert nichts', Refuge.GetPlace('gibtesnicht') == nil)

-- Zwei Plaetze duerfen nicht uebereinanderliegen.
local nah = {}
for index, a in ipairs(Refuge.Places) do
    for zweiter = index + 1, #Refuge.Places do
        local b = Refuge.Places[zweiter]
        if #(a.zutritt - b.zutritt) < 25.0 then
            nah[#nah + 1] = ('%s/%s'):format(a.id, b.id)
        end
    end
end
pruefe('Keine zwei Plaetze liegen uebereinander', #nah == 0, table.concat(nah, ', '))

gruppe('Zuflucht: Klassen und Arten')

-- Jede Klasse braucht einen Ort, der zu ihr passt - sonst ist eine Klasse
-- dauerhaft benachteiligt.
for rasse in pairs(Mystic.Races) do
    local kind = RefugeConfig.Kinds[rasse]
    pruefe(('Klasse %s hat eine Art'):format(rasse), kind ~= nil)

    if kind then
        pruefe(('Art von %s hat eine Bezeichnung'):format(rasse),
            type(kind.label) == 'string' and kind.label ~= '')
        pruefe(('Art von %s hat einen Ruhetext'):format(rasse),
            type(kind.ruhe) == 'string' and kind.ruhe ~= '')

        local passende = 0
        for _, place in ipairs(Refuge.Places) do
            if place.art == kind.ort then passende = passende + 1 end
        end

        pruefe(('Fuer %s gibt es einen passenden Platz'):format(rasse),
            passende > 0, kind.ort)
    end
end

-- Jede Ortsart, die es gibt, muss auch von einer Klasse gesucht werden.
local gesucht = {}
for _, kind in pairs(RefugeConfig.Kinds) do gesucht[kind.ort] = true end

for _, art in ipairs(Refuge.Arts()) do
    pruefe(('Die Art %s gehoert zu einer Klasse'):format(art), gesucht[art] == true)
end

pruefe('Ohne Klasse gibt es trotzdem eine Art',
    Refuge.GetKind(nil) == RefugeConfig.DefaultKind)
pruefe('Eine erfundene Klasse faellt auf den Standard zurueck',
    Refuge.GetKind('gibtesnicht') == RefugeConfig.DefaultKind)

pruefe('Der Vampir passt in die Gruft', Refuge.Fits('vampir', 'gruft'))
pruefe('Der Vampir passt nicht in die Huette', not Refuge.Fits('vampir', 'huette'))
pruefe('Ohne Klasse passt nichts', not Refuge.Fits(nil, 'gruft'))

gruppe('Zuflucht: Lager und Ausbau')

local basis = RefugeConfig.Stash.baseSlots
pruefe('Ohne Ausbau gibt es die Grundplaetze', Refuge.GetSlots(0) == basis, Refuge.GetSlots(0))

-- Handgerechnet gegen die Config: 40 + 20 + 20 + 30.
pruefe('Stufe 1 gibt 60 Plaetze', Refuge.GetSlots(1) == 60, Refuge.GetSlots(1))
pruefe('Stufe 2 gibt 80 Plaetze', Refuge.GetSlots(2) == 80, Refuge.GetSlots(2))
pruefe('Stufe 3 gibt 110 Plaetze', Refuge.GetSlots(3) == 110, Refuge.GetSlots(3))

-- Ueber die letzte Stufe hinaus darf nichts mehr dazukommen.
pruefe('Ueber die letzte Stufe hinaus bleibt es gleich',
    Refuge.GetSlots(99) == Refuge.GetSlots(#RefugeConfig.Stash.ausbau))

-- Jede Stufe muss mehr bringen als die davor.
local vorherSlots = 0
local steigend = true
for stufe = 0, #RefugeConfig.Stash.ausbau do
    local jetzt = Refuge.GetSlots(stufe)
    if stufe > 0 and jetzt <= vorherSlots then steigend = false end
    vorherSlots = jetzt
end
pruefe('Jeder Ausbau bringt mehr Plaetze', steigend)

-- Und jede Stufe muss teurer sein als die davor.
local vorherPreis, teurer = 0, true
for _, eintrag in ipairs(RefugeConfig.Stash.ausbau) do
    if eintrag.preis <= vorherPreis then teurer = false end
    vorherPreis = eintrag.preis
end
pruefe('Jeder Ausbau kostet mehr', teurer)

pruefe('Der erste Ausbau hat einen Preis', Refuge.GetUpgradePrice(0) ~= nil)
pruefe('Nach der letzten Stufe gibt es keinen Preis mehr',
    Refuge.GetUpgradePrice(#RefugeConfig.Stash.ausbau) == nil)

gruppe('Zuflucht: Rast')

local schwach = RefugeConfig.Rest.segen
local stark = RefugeConfig.Rest.segenPassend

for schluessel, wert in pairs(stark) do
    pruefe(('Der Segen %s ist ein Vorteil'):format(schluessel), wert > 0, wert)
    pruefe(('Am passenden Ort ist %s staerker'):format(schluessel),
        wert > (schwach[schluessel] or 0),
        ('%s gegen %s'):format(wert, schwach[schluessel]))
end

for schluessel, wert in pairs(schwach) do
    pruefe(('Auch am fremden Ort ist %s ein Vorteil'):format(schluessel), wert > 0)
    pruefe(('Der starke Segen kennt %s ebenfalls'):format(schluessel),
        stark[schluessel] ~= nil)
end

local passend, istPassend = Refuge.GetBlessing('vampir', 'gruft')
pruefe('Der Vampir in der Gruft bekommt den starken Segen', passend == stark)
pruefe('Und es wird auch so gemeldet', istPassend == true)

local fremd, istFremd = Refuge.GetBlessing('vampir', 'huette')
pruefe('Der Vampir in der Huette bekommt den schwachen Segen', fremd == schwach)
pruefe('Und auch das wird gemeldet', istFremd == false)

pruefe('Ohne Klasse gibt es den schwachen Segen',
    (Refuge.GetBlessing(nil, 'gruft')) == schwach)

-- Die Rast darf nicht laenger dauern als ihre eigene Abklingzeit.
pruefe('Die Rast ist kuerzer als ihre Abklingzeit',
    RefugeConfig.Rest.duration < RefugeConfig.Rest.cooldown * 60)

-- Der Segen soll nicht laenger halten, als bis die naechste Rast frei ist -
-- sonst laesst er sich stapeln.
pruefe('Der Segen haelt nicht bis zur naechsten Rast',
    RefugeConfig.Rest.segenDauer <= RefugeConfig.Rest.cooldown,
    ('%d gegen %d Minuten'):format(RefugeConfig.Rest.segenDauer,
        RefugeConfig.Rest.cooldown))

pruefe('Ein Charakter haelt hoechstens einen Ort',
    RefugeConfig.MaxPerCharacter == 1)

-- ===========================================================================
-- Anzeige
-- ===========================================================================

laden('moonshine-hud/shared/config.lua')

gruppe('Anzeige: Elemente')

local okHud, doppeltHud = eindeutig(HudConfig.Elements, 'key')
pruefe('Element-Schluessel sind eindeutig', okHud, doppeltHud)

for _, element in ipairs(HudConfig.Elements) do
    pruefe(('Element %s hat eine Bezeichnung'):format(element.key),
        type(element.label) == 'string' and element.label ~= '')

    pruefe(('Element %s gehoert zu einer Gruppe'):format(element.key),
        type(element.gruppe) == 'string' and element.gruppe ~= '')

    pruefe(('Element %s hat einen Standard'):format(element.key),
        type(element.standard) == 'boolean')

    pruefe(('Element %s laesst sich ueber den Schluessel finden'):format(element.key),
        Hud.GetElement(element.key) == element)
end

pruefe('Unbekanntes Element liefert nichts', Hud.GetElement('gibtesnicht') == nil)

-- Die Gruppen bauen das Einstellungsmenue auf. Jede muss auch vorkommen.
local gruppen = Hud.Groups()
pruefe('Es gibt mehr als eine Gruppe', #gruppen > 1, #gruppen)

for _, name in ipairs(gruppen) do
    local anzahl = 0
    for _, element in ipairs(HudConfig.Elements) do
        if element.gruppe == name then anzahl = anzahl + 1 end
    end

    pruefe(('Gruppe %s hat Elemente'):format(name), anzahl > 0)
end

local okGruppen = eindeutig(gruppen)
pruefe('Keine Gruppe kommt zweimal vor', okGruppen)

-- Jede Schwelle muss zu einem echten Element gehoeren, sonst blendet der
-- dynamische Modus etwas aus, das es gar nicht gibt.
for key in pairs(HudConfig.Schwellen) do
    pruefe(('Schwelle %s gehoert zu einem Element'):format(key),
        Hud.GetElement(key) ~= nil)
end

gruppe('Anzeige: Klasse und Varianten')

-- Blut, Mana und Hoellenfeuer standen erst als namenlose Ringe zwischen
-- Hunger und Durst. Sie haben jetzt eine eigene Gruppe.
local klasse = {}
for _, element in ipairs(HudConfig.Elements) do
    if element.gruppe == 'Klasse' then klasse[element.key] = element end
end

pruefe('Es gibt eine Gruppe fuer die Klasse', next(klasse) ~= nil)
pruefe('Die Essenz gehoert zur Klasse', klasse.essenz ~= nil)
pruefe('Der Klassenname ist abschaltbar', klasse.klassenname ~= nil)
pruefe('Die Essenzzahl ist abschaltbar', klasse.essenzzahl ~= nil)

-- Die Essenz darf nicht zusaetzlich im Zustand stehen, sonst steht sie doppelt da.
for _, element in ipairs(HudConfig.Elements) do
    if element.gruppe == 'Zustand' then
        pruefe(('Zustand fuehrt %s nicht doppelt'):format(element.key),
            element.key ~= 'essenz')
    end
end

pruefe('Die Essenz ist ab Werk an', klasse.essenz.standard == true)

-- Mehrere Varianten waren ausdruecklich gewuenscht.
pruefe('Es gibt mindestens fuenf Darstellungen',
    #HudConfig.Choices.stil >= 5, #HudConfig.Choices.stil)

local stile = {}
for _, eintrag in ipairs(HudConfig.Choices.stil) do stile[eintrag.value] = true end

for _, name in ipairs({ 'ringe', 'balken', 'segmente', 'bogen', 'zahlen', 'minimal' }) do
    pruefe(('Die Darstellung %s gibt es'):format(name), stile[name] == true)
end

-- Das Klassenband hat eine eigene Lage.
pruefe('Das Klassenband laesst sich setzen',
    #(HudConfig.Choices.klassenEcke or {}) > 1)
pruefe('Standardmaessig haengt es an der Statusgruppe',
    Hud.DefaultSettings().klassenEcke == 'status')
pruefe('Eine erfundene Lage faellt zurueck',
    Hud.Sanitize({ klassenEcke = 'irgendwo' }).klassenEcke == 'status')
pruefe('Eine gueltige Lage wird uebernommen',
    Hud.Sanitize({ klassenEcke = 'um' }).klassenEcke == 'um')

gruppe('Anzeige: Standardeinstellung')

local standardHud = Hud.DefaultSettings()

pruefe('Die Anzeige ist ab Werk an', standardHud.an == true)
pruefe('Der Standardstil ist eine gueltige Auswahl',
    Hud.IsChoice('stil', standardHud.stil), standardHud.stil)
pruefe('Die Standardecke ist eine gueltige Auswahl',
    Hud.IsChoice('ecke', standardHud.ecke), standardHud.ecke)
pruefe('Die Standardeinheit ist eine gueltige Auswahl',
    Hud.IsChoice('einheit', standardHud.einheit), standardHud.einheit)
pruefe('Die Standardfarbe ist eine gueltige Auswahl',
    Hud.IsChoice('akzent', standardHud.akzent), standardHud.akzent)

pruefe('Die Standardgroesse liegt im erlaubten Bereich',
    standardHud.groesse >= HudConfig.Limits.groesse.min
        and standardHud.groesse <= HudConfig.Limits.groesse.max)
pruefe('Die Standarddeckkraft liegt im erlaubten Bereich',
    standardHud.deckkraft >= HudConfig.Limits.deckkraft.min
        and standardHud.deckkraft <= HudConfig.Limits.deckkraft.max)

for _, element in ipairs(HudConfig.Elements) do
    pruefe(('Standard kennt Element %s'):format(element.key),
        standardHud.elemente[element.key] == element.standard)
end

-- Ab Werk muss etwas zu sehen sein, sonst startet jeder mit leerem Bildschirm.
local anZahl = 0
for _, an in pairs(standardHud.elemente) do
    if an then anZahl = anZahl + 1 end
end
pruefe('Ab Werk sind Elemente eingeschaltet', anZahl > 5, anZahl)

gruppe('Anzeige: Einstellungen bereinigen')

-- Nichts hineingeben ergibt den Standard.
pruefe('Ohne Eingabe kommt der Standard', Hud.Sanitize(nil).stil == standardHud.stil)
pruefe('Eine Zahl ergibt den Standard', Hud.Sanitize(42).ecke == standardHud.ecke)

-- Erfundene Werte werden ersetzt, gueltige uebernommen.
local verbogen = Hud.Sanitize({
    an = 'vielleicht', stil = 'wuerfel', ecke = 'ur',
    groesse = 99, deckkraft = -5, akzent = '#123456',
    einheit = 'mph', dynamisch = true,
    elemente = { leben = false, gibtesnicht = true, weste = 'ja' },
})

pruefe('Ein unsinniges "an" faellt auf den Standard zurueck', verbogen.an == true)
pruefe('Ein erfundener Stil faellt zurueck', verbogen.stil == standardHud.stil)
pruefe('Eine gueltige Ecke wird uebernommen', verbogen.ecke == 'ur')
pruefe('Eine gueltige Einheit wird uebernommen', verbogen.einheit == 'mph')
pruefe('Ein echter Schalter wird uebernommen', verbogen.dynamisch == true)
pruefe('Eine erfundene Farbe faellt zurueck', verbogen.akzent == standardHud.akzent)

pruefe('Zu grosse Groesse wird gekappt',
    verbogen.groesse == HudConfig.Limits.groesse.max, verbogen.groesse)
pruefe('Zu kleine Deckkraft wird gekappt',
    verbogen.deckkraft == HudConfig.Limits.deckkraft.min, verbogen.deckkraft)

pruefe('Ein abgeschaltetes Element bleibt abgeschaltet', verbogen.elemente.leben == false)
pruefe('Ein erfundenes Element taucht nicht auf', verbogen.elemente.gibtesnicht == nil)
pruefe('Ein unsinniger Elementwert faellt auf den Standard zurueck',
    verbogen.elemente.weste == Hud.GetElement('weste').standard)

-- Bereinigen darf sich nicht bei jedem Durchlauf weiter veraendern.
local einmal = Hud.Sanitize(standardHud)
local zweimal = Hud.Sanitize(einmal)
pruefe('Zweimal bereinigen aendert nichts mehr',
    einmal.stil == zweimal.stil and einmal.groesse == zweimal.groesse
        and einmal.elemente.leben == zweimal.elemente.leben)

-- Die Eingabe selbst darf dabei nicht verbogen werden.
local eingabe = { stil = 'balken' }
Hud.Sanitize(eingabe)
pruefe('Die Eingabe bleibt unangetastet',
    eingabe.stil == 'balken' and eingabe.elemente == nil)

gruppe('Anzeige: Grenzen und Auswahl')

pruefe('Zu klein wird angehoben',
    Hud.ClampLimit('groesse', 0.1) == HudConfig.Limits.groesse.min)
pruefe('Zu gross wird gekappt',
    Hud.ClampLimit('groesse', 9.0) == HudConfig.Limits.groesse.max)
pruefe('Ein Wert dazwischen bleibt stehen', Hud.ClampLimit('groesse', 1.0) == 1.0)
pruefe('Kein Wert ergibt das Minimum',
    Hud.ClampLimit('deckkraft', nil) == HudConfig.Limits.deckkraft.min)

for feld, liste in pairs(HudConfig.Choices) do
    pruefe(('Auswahl %s hat Eintraege'):format(feld), #liste > 0)

    local okAuswahl, doppelteAuswahl = eindeutig(liste, 'value')
    pruefe(('Auswahl %s ist eindeutig'):format(feld), okAuswahl, doppelteAuswahl)

    for _, eintrag in ipairs(liste) do
        pruefe(('Auswahl %s/%s hat eine Bezeichnung'):format(feld, eintrag.value),
            type(eintrag.label) == 'string' and eintrag.label ~= '')

        pruefe(('Auswahl %s/%s wird als gueltig erkannt'):format(feld, eintrag.value),
            Hud.IsChoice(feld, eintrag.value))
    end
end

pruefe('Ein erfundener Wert gilt nicht', not Hud.IsChoice('stil', 'wuerfel'))
pruefe('Ein erfundenes Feld gilt nicht', not Hud.IsChoice('gibtesnicht', 'egal'))

gruppe('Anzeige: Kompass')

-- Handgerechnet: acht Sektoren zu je 45 Grad, Norden liegt mittig auf 0.
local RICHTUNGEN = {
    [0] = 'N', [45] = 'NO', [90] = 'O', [135] = 'SO',
    [180] = 'S', [225] = 'SW', [270] = 'W', [315] = 'NW',
}

for grad, erwartet in pairs(RICHTUNGEN) do
    pruefe(('%d Grad ist %s'):format(grad, erwartet),
        Hud.Direction(grad) == erwartet, Hud.Direction(grad))
end

-- Die Sektorgrenzen: 22,4 Grad ist noch Norden, 22,6 schon Nordost.
pruefe('22 Grad ist noch Norden', Hud.Direction(22) == 'N', Hud.Direction(22))
pruefe('23 Grad ist schon Nordost', Hud.Direction(23) == 'NO', Hud.Direction(23))
pruefe('337 Grad ist noch Nordwest', Hud.Direction(337) == 'NW', Hud.Direction(337))
pruefe('338 Grad ist wieder Norden', Hud.Direction(338) == 'N', Hud.Direction(338))

-- Ueber 360 hinaus und darunter darf nichts brechen.
pruefe('360 Grad ist Norden', Hud.Direction(360) == 'N')
pruefe('720 Grad ist Norden', Hud.Direction(720) == 'N')
pruefe('-90 Grad ist Westen', Hud.Direction(-90) == 'W', Hud.Direction(-90))
pruefe('Kein Wert ist Norden', Hud.Direction(nil) == 'N')

-- Jede Richtung muss auch wirklich vorkommen.
for _, richtung in ipairs(Hud.Compass) do
    local gefunden = false
    for grad = 0, 359 do
        if Hud.Direction(grad) == richtung then gefunden = true break end
    end

    pruefe(('Die Richtung %s kommt vor'):format(richtung), gefunden)
end

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
