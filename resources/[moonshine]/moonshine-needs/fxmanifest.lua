fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'moonshine-needs'
author 'Moonshine RP'
description 'Klassenbeduerfnisse: jede Klasse braucht etwas zum Ueberleben'
version '1.0.0'

dependency 'moonshine-core'
dependency 'moonshine-mystic'

shared_scripts {
    'shared/config.lua',
    'shared/needs.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/sources.lua',
}

client_scripts {
    'client/main.lua',
    'client/sources.lua',
}

ui_page 'nui/index.html'

files {
    'nui/index.html',
    'nui/style.css',
    'nui/app.js',
}
