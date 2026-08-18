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
