#!/usr/bin/env python3
"""
Prueft das Framework, ohne dass ein FXServer laufen muss.

Was geprueft wird:

  1. Syntax      - jede .lua durch luac, jede .js durch node --check
  2. Manifeste   - jede Datei im Ordner steht im fxmanifest und umgekehrt
  3. Exporte     - jeder exports['x']:y() Aufruf hat drueben ein exports('y')
  4. Netz-Events - jedes TriggerServerEvent hat serverseitig ein RegisterNetEvent
  5. Callbacks   - jedes TriggerServerCallback hat ein RegisterServerCallback
  6. NUI         - jeder post()/ask() Name hat ein RegisterNUICallback
  7. Seiten      - keine reinen Client-Natives auf dem Server (und umgekehrt)
  8. Commands    - kein Command-Name doppelt ueber Resources hinweg
  9. Abhaengig   - kein ungeschuetzter Export auf eine Resource ohne dependency
 10. Schema      - sql/moonshine.sql deckt sich mit dem, was die Resources anlegen
 11. Aufrufe     - keine Aufrufe auf Funktionen, die es nirgends gibt
 12. Config      - keine Zugriffe auf Config-Felder, die nie gesetzt werden
 13. Namensraum  - keine Globals aus einer Resource, die gar nicht geladen ist
 14. Ratenlimit  - kein Netz-Event bewegt Geld oder Items ungebremst

Aufruf:   python3 tools/pruefen.py [--nur-syntax]
Rueckgabe: 0 wenn sauber, 1 bei Funden.
"""

import os
import re
import subprocess
import sys
import tempfile
from collections import defaultdict

ROOT = os.path.join('resources', '[moonshine]')

# CfxLua kennt Hash-Literale (`prop_name`), luac nicht. Fuer die Pruefung ersetzen.
HASH_LITERAL = re.compile(r"`[A-Za-z_][A-Za-z0-9_]*`")

# Natives, die es nur auf einer Seite gibt.
CLIENT_ONLY = [
    'PlayerPedId', 'SetNuiFocus', 'SendNUIMessage', 'DrawMarker', 'RequestModel',
    'AddBlipForCoord', 'PlaySoundFrontend', 'DoScreenFadeOut', 'CreateCam',
    'IsControlJustReleased', 'IsControlPressed', 'DisableControlAction',
    'SetPedComponentVariation', 'RegisterNUICallback', 'RegisterKeyMapping',
    'NetworkOverrideClockTime', 'SetWeatherTypePersist', 'AddTextComponentString',
]

SERVER_ONLY = ['DropPlayer', 'GetPlayerPing', 'GetPlayerIdentifiers', 'MySQL']

# Wie eine Resource pruefen kann, dass der Aufrufer geladen ist.
PLAYER_GUARDS = [
    'MS.GetPlayer(source)', 'GetPlayer(source)', 'MS.Players[source]',
    'MS.Sessions[source]', 'Profiles[source]', 'GetProfile(source)',
    'GetByPlayer(source)', 'Shifts[source]',
]

findings = []


def note(kind, where, what):
    findings.append((kind, where, what))


def read(path):
    try:
        with open(path, encoding='utf-8') as handle:
            return handle.read()
    except OSError:
        return ''


def resources():
    if not os.path.isdir(ROOT):
        return []
    return sorted(d for d in os.listdir(ROOT) if d.startswith('moonshine-'))


def manifest_sides(res):
    """Welche Datei laeuft auf welcher Seite."""
    man = read(os.path.join(ROOT, res, 'fxmanifest.lua'))
    out = {'server': set(), 'client': set(), 'shared': set()}

    for key, block in (('server', 'server_scripts'), ('client', 'client_scripts'),
                       ('shared', 'shared_scripts')):
        match = re.search(block + r"\s*\{(.*?)\}", man, re.S)
        if match:
            out[key] |= set(re.findall(r"'([^']+\.lua)'", match.group(1)))

    for key, single in (('server', 'server_script'), ('client', 'client_script'),
                        ('shared', 'shared_script')):
        out[key] |= set(re.findall(single + r"\s+'([^']+\.lua)'", man))

    return out


def files_for(res, side):
    """Alle Dateien, die auf dieser Seite laufen (inklusive shared)."""
    sides = manifest_sides(res)
    picked = sides['shared'] | sides[side]

    out = []
    for name in sorted(picked):
        if name.startswith('@'):
            continue
        path = os.path.join(ROOT, res, name)
        if os.path.exists(path):
            out.append(path)

    return out


# --- 1. Syntax ---------------------------------------------------------------

def check_syntax():
    luac = None
    for candidate in ('luac5.4', 'luac5.3', 'luac'):
        if subprocess.run(['which', candidate], capture_output=True).returncode == 0:
            luac = candidate
            break

    for root, _, files in os.walk(ROOT):
        for name in files:
            path = os.path.join(root, name)

            if name.endswith('.lua') and luac:
                cleaned = HASH_LITERAL.sub('0', read(path))

                with tempfile.NamedTemporaryFile('w', suffix='.lua',
                                                 delete=False, encoding='utf-8') as tmp:
                    tmp.write(cleaned)
                    tmp_path = tmp.name

                result = subprocess.run([luac, '-p', tmp_path], capture_output=True, text=True)
                os.unlink(tmp_path)

                if result.returncode != 0:
                    message = result.stderr.strip().replace(tmp_path, path)
                    note('SYNTAX', path, message)

            elif name.endswith('.js'):
                result = subprocess.run(['node', '--check', path],
                                        capture_output=True, text=True)
                if result.returncode != 0:
                    note('SYNTAX', path, result.stderr.strip().split('\n')[0])


# --- 2. Manifeste ------------------------------------------------------------

def check_manifests():
    for res in resources():
        man_path = os.path.join(ROOT, res, 'fxmanifest.lua')
        man = read(man_path)
        sides = manifest_sides(res)
        listed = sides['server'] | sides['client'] | sides['shared']
        listed |= set(re.findall(r"'(nui/[^']+)'", man))

        base = os.path.join(ROOT, res)
        for root, _, files in os.walk(base):
            for name in files:
                if name == 'fxmanifest.lua':
                    continue
                if not name.endswith(('.lua', '.js', '.css', '.html')):
                    continue

                rel = os.path.relpath(os.path.join(root, name), base).replace(os.sep, '/')
                if rel not in listed:
                    note('MANIFEST-FEHLT', res, rel)

        for entry in sorted(listed):
            if entry.startswith('@'):
                continue
            if not os.path.exists(os.path.join(base, entry)):
                note('MANIFEST-TOT', res, entry)


# --- 3. Exporte --------------------------------------------------------------

def check_exports():
    defined = defaultdict(lambda: defaultdict(set))

    for res in resources():
        for side in ('server', 'client'):
            for path in files_for(res, side):
                for name in re.findall(r"exports\(\s*'([^']+)'", read(path)):
                    defined[res][side].add(name)

    known = set(resources())

    for res in resources():
        for side in ('server', 'client'):
            for path in files_for(res, side):
                for target, fn in re.findall(
                        r"exports\[\s*'(moonshine-[a-z]+)'\s*\]:(\w+)", read(path)):
                    if target not in known:
                        note('EXPORT-RESOURCE', path, f"{target}:{fn}")
                    elif fn not in defined[target][side]:
                        other = 'client' if side == 'server' else 'server'
                        if fn in defined[target][other]:
                            note('EXPORT-SEITE', path,
                                 f"{target}:{fn} gibt es nur auf der {other}-Seite")
                        else:
                            note('EXPORT-FEHLT', path, f"{target}:{fn}")


# --- 4. und 5. Events und Callbacks -----------------------------------------

def check_events():
    registered = defaultdict(set)
    callbacks = set()

    for res in resources():
        for side in ('server', 'client'):
            for path in files_for(res, side):
                body = read(path)
                registered[side] |= set(re.findall(r"RegisterNetEvent\(\s*'([^']+)'", body))

                if side == 'server':
                    callbacks |= set(re.findall(
                        r"RegisterServerCallback\(\s*'([^']+)'", body))

    # Events aus Basis-Resources, die nicht uns gehoeren.
    external = {'chat:addSuggestion', 'chat:addMessage'}

    for res in resources():
        for path in files_for(res, 'client'):
            body = read(path)

            for name in re.findall(r"TriggerServerEvent\(\s*'([^']+)'", body):
                if name not in registered['server'] and name not in external:
                    note('EVENT-OHNE-SERVER', path, name)

            for name in re.findall(r"TriggerServerCallback\(\s*'([^']+)'", body):
                if name not in callbacks:
                    note('CALLBACK-FEHLT', path, name)

        for path in files_for(res, 'server'):
            for name in re.findall(r"TriggerClientEvent\(\s*'([^']+)'", read(path)):
                if name not in registered['client'] and name not in external:
                    note('EVENT-OHNE-CLIENT', path, name)


# --- 6. NUI ------------------------------------------------------------------

def check_nui():
    for res in resources():
        js_path = os.path.join(ROOT, res, 'nui', 'app.js')
        js = read(js_path)
        if not js:
            continue

        lua_callbacks = set()
        loop_registered = False

        for path in files_for(res, 'client'):
            body = read(path)
            lua_callbacks |= set(re.findall(r"RegisterNUICallback\(\s*'([^']+)'", body))

            # In einer Schleife registriert - dann laesst sich nichts vergleichen.
            if re.search(r"RegisterNUICallback\(\s*\w+\s*,", body):
                loop_registered = True

        if loop_registered:
            continue

        # Nur direkte, eindeutige Aufrufe pruefen.
        called = set(re.findall(r"(?:^|[^\w.])(?:post|ask)\(\s*'([a-zA-Z]\w*)'", js))

        for name in sorted(called - lua_callbacks):
            note('NUI-CALLBACK-FEHLT', js_path, name)


# --- 7. Seiten ---------------------------------------------------------------

def check_sides():
    for res in resources():
        sides = manifest_sides(res)

        for name in sorted(sides['server']):
            path = os.path.join(ROOT, res, name)
            if not os.path.exists(path):
                continue

            body = read(path)
            for native in CLIENT_ONLY:
                match = re.search(r"(?<![\w.:])" + native + r"\s*\(", body)
                if match:
                    line = body[:match.start()].count('\n') + 1
                    note('CLIENT-NATIVE-SERVERSEITIG', f"{path}:{line}", native)

        for name in sorted(sides['client']):
            path = os.path.join(ROOT, res, name)
            if not os.path.exists(path):
                continue

            body = read(path)
            for native in SERVER_ONLY:
                match = re.search(r"(?<![\w.:])" + native + r"[\s.(]", body)
                if match:
                    line = body[:match.start()].count('\n') + 1
                    note('SERVER-NATIVE-CLIENTSEITIG', f"{path}:{line}", native)


# --- 8. Commands -------------------------------------------------------------

def check_commands():
    owner = defaultdict(set)

    for res in resources():
        for side in ('server', 'client'):
            for path in files_for(res, side):
                body = read(path)

                for name in re.findall(r"RegisterCommand\(\s*'([^']+)'", body):
                    owner[name].add(res)

                # Commands aus einer Config
                for name in re.findall(r"RegisterCommand\(\s*(\w+Config\.\w+)", body):
                    owner['(aus ' + name + ')'].add(res)

    for name, where in sorted(owner.items()):
        if len(where) > 1:
            note('COMMAND-DOPPELT', ', '.join(sorted(where)), f"/{name}")


# --- 9. Abhaengigkeiten ------------------------------------------------------

def check_dependencies():
    for res in resources():
        man = read(os.path.join(ROOT, res, 'fxmanifest.lua'))
        deps = set(re.findall(r"dependency\s+'([^']+)'", man))

        block = re.search(r"dependencies\s*\{(.*?)\}", man, re.S)
        if block:
            deps |= set(re.findall(r"'([^']+)'", block.group(1)))

        base = os.path.join(ROOT, res)
        for root, _, files in os.walk(base):
            for name in files:
                if not name.endswith('.lua'):
                    continue

                path = os.path.join(root, name)
                lines = read(path).split('\n')

                for index, line in enumerate(lines):
                    for target in re.findall(r"exports\[\s*'(moonshine-[a-z]+)'\s*\]", line):
                        if target == res or target in deps:
                            continue

                        # pcall in den drei Zeilen davor gilt als abgesichert.
                        window = '\n'.join(lines[max(0, index - 3):index + 1])
                        if 'pcall' not in window:
                            note('DEPENDENCY-FEHLT', f"{path}:{index + 1}",
                                 f"{target} ungeschuetzt, ohne dependency")


# --- 10. Schema: Lua gegen sql/moonshine.sql --------------------------------

def tables_in(text):
    """Tabellenname -> Menge der Spaltennamen."""
    out = {}

    for match in re.finditer(
            r"CREATE TABLE IF NOT EXISTS\s+`(\w+)`\s*\((.*?)\)\s*ENGINE",
            text, re.S):
        name, body = match.group(1), match.group(2)

        columns = set()
        for line in body.split('\n'):
            column = re.match(r"\s*`(\w+)`\s+\w", line)
            if column:
                columns.add(column.group(1))

        out[name] = columns

    return out


def check_schema():
    """
    Das Schema steht zweimal da: die Resources legen ihre Tabellen selbst an,
    und sql/moonshine.sql ist die Referenz zum Handimportieren. Beides muss
    uebereinstimmen, sonst hat wer manuell importiert ein kaputtes System.
    """
    reference = 'sql/moonshine.sql'
    if not os.path.exists(reference):
        note('SCHEMA', reference, 'Datei fehlt')
        return

    from_sql = tables_in(read(reference))
    from_lua = {}

    for res in resources():
        for side in ('server',):
            for path in files_for(res, side):
                for name, columns in tables_in(read(path)).items():
                    from_lua[name] = (columns, path)

    for name in sorted(set(from_lua) - set(from_sql)):
        note('SCHEMA-FEHLT-IM-SQL', from_lua[name][1],
             f"{name} wird angelegt, steht aber nicht in {reference}")

    for name in sorted(set(from_sql) - set(from_lua)):
        note('SCHEMA-VERWAIST', reference,
             f"{name} steht im SQL, aber keine Resource legt sie an")

    for name in sorted(set(from_lua) & set(from_sql)):
        lua_columns, path = from_lua[name]
        sql_columns = from_sql[name]

        only_lua = sorted(lua_columns - sql_columns)
        only_sql = sorted(sql_columns - lua_columns)

        if only_lua:
            note('SCHEMA-SPALTEN', path,
                 f"{name}: {only_lua} fehlen in {reference}")

        if only_sql:
            note('SCHEMA-SPALTEN', reference,
                 f"{name}: {only_sql} kennt keine Resource")


# --- 11. Aufrufe auf Funktionen, die es nicht gibt --------------------------

NAMESPACES = {
    'MS', 'Mystic', 'Progress', 'Factions', 'Auction', 'Vehicles', 'Services',
    'Work', 'Admin', 'World', 'Appearance', 'Death', 'Boss', 'RitualWar',
}

CONFIG_TABLES = {
    'Config', 'MysticConfig', 'ProgressConfig', 'FactionConfig', 'AuctionConfig',
    'VehicleConfig', 'ServiceConfig', 'WorkConfig', 'AdminConfig', 'WorldConfig',
    'AppearanceConfig', 'DeathConfig', 'BossConfig', 'ShopConfig',
    'WarConfig',
}


def _side_files(res, side):
    """Dateien einer Resource auf einer Seite, ohne @-Verweise."""
    sides = manifest_sides(res)
    out = []

    for name in sorted(sides['shared'] | sides[side]):
        if name.startswith('@'):
            continue
        path = os.path.join(ROOT, res, name)
        if os.path.exists(path):
            out.append(path)

    return out


def _collect_names(side):
    """Alles, was auf dieser Seite als Namensraum-Feld definiert wird."""
    found = set()

    for res in resources():
        for path in _side_files(res, side):
            body = read(path)

            for pattern in (
                    r"function\s+(\w+)\.(\w+)\s*\(",
                    r"function\s+(\w+)\.(\w+)\.\w+\s*\(",
                    r"(\w+)\.(\w+)\s*=\s*function",
                    r"^\s*(\w+)\.(\w+)\s*=",
                    r"^\s*(\w+)\.(\w+)\.\w+\s*=",
                    r"^\s*(\w+)\.(\w+)\s*\[",
            ):
                for namespace, field in re.findall(pattern, body, re.M):
                    found.add((namespace, field))

            # In einer Tabellenliteral-Zuweisung: X = { y = ..., z = ... }
            for match in re.finditer(r"^(\w+)\s*=\s*\{(.*?)^\}", body, re.S | re.M):
                namespace = match.group(1)
                for field in re.findall(r"^\s*(\w+)\s*=", match.group(2), re.M):
                    found.add((namespace, field))

    return found


def check_unknown_calls():
    for side in ('server', 'client'):
        known = _collect_names(side)

        for res in resources():
            for path in _side_files(res, side):
                body = read(path)

                for index, line in enumerate(body.split('\n'), 1):
                    if line.strip().startswith('--'):
                        continue

                    for namespace, field in re.findall(
                            r"(?<![\w.])(\w+)\.(\w+)\s*\(", line):
                        if namespace not in NAMESPACES:
                            continue
                        if (namespace, field) in known:
                            continue

                        note('AUFRUF-UNBEKANNT', f"{path}:{index}",
                             f"{namespace}.{field}() ist nirgends definiert ({side})")


# --- 12. Zugriffe auf Config-Felder, die es nicht gibt ----------------------

def check_config_access():
    for side in ('server', 'client'):
        known = _collect_names(side)

        for res in resources():
            for path in _side_files(res, side):
                body = read(path)

                for index, line in enumerate(body.split('\n'), 1):
                    if line.strip().startswith('--'):
                        continue

                    for table, field in re.findall(
                            r"(?<![\w.])(\w+Config|Config)\.(\w+)", line):
                        if table not in CONFIG_TABLES:
                            continue
                        if (table, field) in known:
                            continue

                        note('CONFIG-UNBEKANNT', f"{path}:{index}",
                             f"{table}.{field} ist nirgends gesetzt ({side})")


# --- 13. Globals aus einer Resource, die gar nicht geladen ist ---------------
#
# In FiveM hat jede Resource ihren eigenen Lua-Zustand. `MysticConfig` aus
# moonshine-mystic ist in einer anderen Resource schlicht nil, solange die
# Datei nicht per '@moonshine-mystic/shared/config.lua' mitgeladen wird.
# Genau so lief eine Resource hier eine Weile ins Leere, ohne dass es
# auffiel: der Code hatte einen nil-Schutz und tat einfach nichts.

def _reachable_files(res, side):
    """Eigene Dateien plus alles, was per @resource/datei mitgeladen wird."""
    sides = manifest_sides(res)
    out = []

    for name in sorted(sides['shared'] | sides[side]):
        if name.startswith('@'):
            # '@moonshine-mystic/shared/config.lua' -> Pfad im Repo.
            target = os.path.join(ROOT, name[1:])
            if os.path.exists(target):
                out.append(target)
            continue

        path = os.path.join(ROOT, res, name)
        if os.path.exists(path):
            out.append(path)

    return out


def _names_in(paths):
    """Namensraum-Felder, die diese Dateien definieren."""
    found = set()

    for path in paths:
        body = read(path)

        for pattern in (
                r"function\s+(\w+)\.(\w+)\s*\(",
                r"function\s+(\w+)\.(\w+)\.\w+\s*\(",
                r"(\w+)\.(\w+)\s*=\s*function",
                r"^\s*(\w+)\.(\w+)\s*=",
                r"^\s*(\w+)\.(\w+)\.\w+\s*=",
                r"^\s*(\w+)\.(\w+)\s*\[",
        ):
            for namespace, field in re.findall(pattern, body, re.M):
                found.add((namespace, field))

        for match in re.finditer(r"^(\w+)\s*=\s*\{(.*?)^\}", body, re.S | re.M):
            namespace = match.group(1)
            for field in re.findall(r"^\s*(\w+)\s*=", match.group(2), re.M):
                found.add((namespace, field))

    return found


def check_foreign_globals():
    for side in ('server', 'client'):
        for res in resources():
            own = _side_files(res, side)
            if not own:
                continue

            reachable = _names_in(_reachable_files(res, side))

            # Namensraeume, die sich diese Resource per Export holt, reisen
            # legitim ueber die Grenze (MS = exports[...]:GetCoreObject()).
            via_export = set()
            for path in own:
                for name in re.findall(r"^\s*(?:local\s+)?(\w+)\s*=\s*(?:\w+\s+or\s+)?exports\[",
                                       read(path), re.M):
                    via_export.add(name)

            for path in own:
                body = read(path)

                for index, line in enumerate(body.split('\n'), 1):
                    if line.strip().startswith('--'):
                        continue

                    for table, field in re.findall(
                            r"(?<![\w.])(\w+)\.(\w+)", line):
                        if table not in NAMESPACES and table not in CONFIG_TABLES:
                            continue
                        if table in via_export:
                            continue
                        if (table, field) in reachable:
                            continue

                        note('NAMENSRAUM-FREMD', f"{path}:{index}",
                             f"{table}.{field} kommt aus einer anderen Resource "
                             f"und wird hier nicht mitgeladen ({side})")


# --- 14. Netz-Events, die Werte bewegen, ohne Ratenbegrenzung ---------------
#
# Ein Netz-Event ist eine offene Tuer: der Client entscheidet, wann und wie
# oft er sie aufmacht. Die Handler pruefen zwar Besitz, Naehe und Kontostand -
# aber ohne Begrenzung laesst sich jeder davon im Dauerfeuer aufrufen, und
# genau daran haengen die meisten Dupe-Luecken in FiveM.
#
# Zwanzig Handler hatten hier keine, darunter factions:server:vaultPut,
# waehrend vaultTake daneben eine hatte.

WERTBEWEGEND = re.compile(
    r"\b(AddMoney|RemoveMoney|SetMoney|AddItem|RemoveItem|AddKasse|RemoveKasse"
    r"|AddToVault|AddFactionXp|AddMeditationPoints|GiveVehicle|SetMods)\b")


def check_ratelimits():
    for res in resources():
        for path in _side_files(res, 'server'):
            lines = read(path).split('\n')

            index = 0
            while index < len(lines):
                match = re.match(r"RegisterNetEvent\('([^']+)'", lines[index])

                if not match:
                    index += 1
                    continue

                start = index
                index += 1

                # Der Handler endet am ersten 'end)' in Spalte 0. Sonst
                # zaehlte eine Begrenzung aus dem naechsten Handler mit.
                while index < len(lines) and not lines[index].startswith('end)'):
                    index += 1

                body = '\n'.join(lines[start:index + 1])
                moved = sorted(set(WERTBEWEGEND.findall(body)))

                if moved and 'RateLimit' not in body:
                    note('OHNE-RATENBEGRENZUNG', f"{path}:{start + 1}",
                         f"{match.group(1)} bewegt {', '.join(moved)} "
                         f"ohne MS.RateLimit")

                index += 1


# Welche Wachhund-Pruefung geht gegen welchen Native los?
#
# Diese drei Ereignisse feuert FiveM, sobald *irgendein* Client den Native
# aufruft - auch der eigene. Steht die Pruefung scharf und ruft der Server
# den Native trotzdem auf, bricht der Wachhund die eigene Funktion ab und
# verteilt dafuer Strafpunkte an unbeteiligte Spieler.
SELBSTBESCHUSS = {
    'clearPedTasks':    r'\bClearPedTasks(?:Immediately)?\s*\(',
    'giveWeapon':       r'\bGiveWeaponToPed\s*\(',
    'removeAllWeapons': r'\bRemoveAllPedWeapons\s*\(',
}


def check_selfshot():
    config = read(os.path.join(ROOT, 'moonshine-admin', 'shared', 'config.lua'))

    for schalter, muster in SELBSTBESCHUSS.items():
        aktiv = re.search(rf'{schalter}\s*=\s*true', config)
        if not aktiv:
            continue

        regex = re.compile(muster)

        for res in resources():
            if res == 'moonshine-admin':
                continue

            for path in _side_files(res, 'client') + _side_files(res, 'server'):
                for number, line in enumerate(read(path).split('\n'), 1):
                    if line.lstrip().startswith('--'):
                        continue

                    if regex.search(line):
                        note('WACHHUND-SELBSTBESCHUSS', f"{path}:{number}",
                             f"{schalter} steht scharf, hier laeuft der "
                             f"passende Aufruf - der Wachhund bricht ihn ab")


# --- 16. Wertbewegung nach einem Warten -------------------------------------
#
# Die gefaehrlichste Fehlerklasse in diesem Framework, und die am
# schwersten zu sehende: zwischen einer Pruefung und der Auszahlung liegt ein
# Warten auf die Datenbank. Waehrend dieser Zeit laeuft der naechste Aufruf
# durch dieselbe Pruefung - beide bestehen sie, beide zahlen aus.
#
# Schwer zu sehen ist sie, weil das Warten hinter einem Namen steckt, der
# synchron aussieht: Vehicles.DB.GetById() wartet, Auction.DB.AddMail()
# wartet. Deshalb baut diese Pruefung erst die Menge aller wartenden
# Funktionen auf - auch ueber mehrere Ebenen -, und sucht dann nach
# Wertbewegungen dahinter.
#
# Sie kann nicht erkennen, ob ein Fall abgesichert ist. Deshalb wird jeder
# gepruefte Fall in der Funktion selbst mit "@rennen <Begruendung>"
# markiert - dann bleibt die Liste endlich und jeder neue Fall faellt auf.

DEF_LUA = re.compile(r'^\s*(?:local\s+)?function\s+([\w.:]+)\s*\(')
AWAIT_LUA = re.compile(r'\.await\s*\(')
CALL_LUA = re.compile(r'([\w.]+[.:]\w+|\b[a-z]\w+)\s*\(')
WERT_LUA = re.compile(r'[:.](AddItem|AddMoney|RemoveItem|RemoveMoney)\s*\(')


def _lua_functions():
    """name -> (pfad, startzeile, zeilen, vorspann)"""
    out = {}

    for res in resources():
        for path in _side_files(res, 'server'):
            lines = read(path).split('\n')
            index = 0

            while index < len(lines):
                match = DEF_LUA.match(lines[index])

                if not match:
                    index += 1
                    continue

                start = index

                # Einzeiler schliessen sich selbst. Ohne diesen Fall
                # verschluckt die Suche alles bis zum naechsten 'end' in
                # Spalte 0 - und meldet den falschen Namen.
                if re.search(r'\bend\s*$', lines[index]):
                    index += 1
                else:
                    index += 1

                    while index < len(lines) \
                            and not re.match(r'^end\b', lines[index]):
                        index += 1

                    index += 1

                vorspann = '\n'.join(lines[max(0, start - 8):start])
                out[match.group(1)] = (path, start + 1, lines[start:index],
                                       vorspann)

    return out


def _aufgerufene(zeile, funcs, kurznamen):
    """Welche bekannten Funktionen ruft diese Zeile auf?"""
    for name in CALL_LUA.findall(zeile):
        if name in funcs:
            yield name
            continue

        for voll in kurznamen.get(name.split('.')[-1].split(':')[-1], ()):
            yield voll


def check_awaitraces():
    funcs = _lua_functions()

    kurznamen = defaultdict(set)
    for name in funcs:
        kurznamen[name.split('.')[-1].split(':')[-1]].add(name)

    # Welche Funktionen warten? Erst die direkten, dann bis zum Fixpunkt.
    wartend = {name for name, (_, _, body, _) in funcs.items()
               if any(AWAIT_LUA.search(line) for line in body
                      if not line.lstrip().startswith('--'))}

    while True:
        neu = set()

        for name, (_, _, body, _) in funcs.items():
            if name in wartend:
                continue

            for line in body:
                if line.lstrip().startswith('--'):
                    continue
                if any(ziel in wartend
                       for ziel in _aufgerufene(line, funcs, kurznamen)):
                    neu.add(name)
                    break

        if not neu:
            break

        wartend |= neu

    for name, (path, start, body, vorspann) in funcs.items():
        if '@rennen' in vorspann or any('@rennen' in line for line in body):
            continue

        erstesWarten = None
        letzteBewegung = None

        for offset, line in enumerate(body):
            if line.lstrip().startswith('--'):
                continue

            if erstesWarten is None:
                for ziel in _aufgerufene(line, funcs, kurznamen):
                    if ziel in wartend and ziel != name:
                        erstesWarten = (offset, ziel)
                        break

            if WERT_LUA.search(line):
                letzteBewegung = offset

        if erstesWarten and letzteBewegung is not None \
                and letzteBewegung > erstesWarten[0]:
            note('WERTBEWEGUNG-NACH-WARTEN',
                 f"{path}:{start + letzteBewegung}",
                 f"{name} wartet in Zeile {start + erstesWarten[0]} auf "
                 f"{erstesWarten[1]} und bewegt danach Werte. Absichern und "
                 f"mit \"@rennen <Begruendung>\" markieren.")


# --- 17. Element-Namen im NUI ------------------------------------------------
#
# Sucht das JavaScript ein Element, das es im HTML nicht gibt, liefert
# document.getElementById null zurueck - und die naechste Zuweissung darauf
# wirft. In einer Zeichenfunktion bricht damit alles ab, was danach kommt.
#
# Genau das ist im Skilltree passiert: vier Zuweisungen auf Namen von vor
# einem Umbau standen mitten in renderTreeScreen. Die Funktion brach dort ab
# - und ihre letzte Zeile war die, die den Bildschirm sichtbar macht. Der
# Baum ging ueberhaupt nicht auf.
#
# Das JavaScript holt Elemente ueber $(...), getElementById(...) oder
# querySelector('#...'). Erzeugte Namen zaehlen mit: steht id="x" irgendwo im
# JavaScript (Vorlagen, Zeichenketten), gilt x als vorhanden.

ID_IM_HTML = re.compile(r'\bid\s*=\s*["\']([\w-]+)["\']')
ID_DOLLAR = re.compile(r"\$\(\s*['\"`]([\w-]+)['\"`]\s*\)")
ID_GETELEM = re.compile(r"getElementById\(\s*['\"`]([\w-]+)['\"`]\s*\)")
ID_QUERY = re.compile(r"querySelector(?:All)?\(\s*['\"`]#([\w-]+)")

DOLLAR_HELFER = 'const $ = (id) => document.getElementById(id)'


def _ohne_kommentare(text):
    """Kommentare raus, damit erklaerender Text nicht als Zugriff zaehlt.

    Grob, aber in die sichere Richtung: ein // in einer Zeichenkette
    schneidet den Rest der Zeile weg. Das kann einen Zugriff uebersehen,
    aber nie einen erfinden.
    """
    text = re.sub(r'/\*.*?\*/', '', text, flags=re.S)
    return re.sub(r'//[^\n]*', '', text)


def check_nui_ids():
    for res in resources():
        nui = os.path.join(ROOT, res, 'nui')
        if not os.path.isdir(nui):
            continue

        html, js = '', ''
        quelle = {}

        for root, _, files in os.walk(nui):
            for name in sorted(files):
                path = os.path.join(root, name)

                if name.endswith('.html'):
                    html += read(path)
                elif name.endswith('.js'):
                    text = _ohne_kommentare(read(path))
                    js += '\n' + text

                    for treffer in (set(ID_GETELEM.findall(text))
                                    | set(ID_QUERY.findall(text))
                                    | set(ID_DOLLAR.findall(text))):
                        quelle.setdefault(treffer, path)

        if not js:
            continue

        # Namen, die das JavaScript selbst erzeugt, gelten als vorhanden.
        vorhanden = set(ID_IM_HTML.findall(html)) | set(ID_IM_HTML.findall(js))

        gesucht = set(ID_GETELEM.findall(js)) | set(ID_QUERY.findall(js))

        # $(...) nur, wo es wirklich getElementById ist.
        if DOLLAR_HELFER in js:
            gesucht |= set(ID_DOLLAR.findall(js))

        for name in sorted(gesucht - vorhanden):
            note('NUI-ELEMENT-FEHLT', quelle.get(name, nui),
                 f"#{name} wird geholt, steht aber in keinem HTML - "
                 f"der Zugriff darauf wirft und bricht die Funktion ab")


def main():
    only_syntax = '--nur-syntax' in sys.argv

    check_syntax()

    if not only_syntax:
        check_manifests()
        check_exports()
        check_events()
        check_nui()
        check_sides()
        check_commands()
        check_dependencies()
        check_schema()
        check_unknown_calls()
        check_config_access()
        check_foreign_globals()
        check_ratelimits()
        check_selfshot()
        check_awaitraces()
        check_nui_ids()

    if not findings:
        print('Alles sauber.')
        return 0

    groups = defaultdict(list)
    for kind, where, what in findings:
        groups[kind].append((where, what))

    total = 0
    for kind in sorted(groups):
        rows = sorted(set(groups[kind]))
        total += len(rows)

        print(f'\n=== {kind} ({len(rows)}) ===')
        for where, what in rows:
            print(f'  {where}\n      {what}')

    print(f'\n{total} Funde.')
    return 1


if __name__ == '__main__':
    sys.exit(main())
