fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'moonshine-world'
author 'Moonshine RP'
description 'Serverzeit, Wetter, Mondphasen und mystische Weltereignisse'
version '1.0.0'

dependency 'moonshine-core'

shared_scripts {
    'shared/config.lua',
    'shared/phases.lua',
    'shared/events.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/database.lua',
    'server/time.lua',
    'server/events.lua',
    'server/main.lua',
}

client_scripts {
    'client/time.lua',
    'client/effects.lua',
    'client/hud.lua',
}

ui_page 'nui/index.html'

files {
    'nui/index.html',
    'nui/style.css',
    'nui/app.js',
}
