fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'moonshine-refuge'
author 'Moonshine RP'
description 'Zufluchtsorte: Lager, sicherer Respawn und Rast nach Klasse'
version '1.0.0'

dependency 'moonshine-core'

shared_scripts {
    'shared/config.lua',
    'shared/places.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/database.lua',
    'server/main.lua',
    'server/stash.lua',
    'server/rest.lua',
}

client_scripts {
    'client/main.lua',
    'client/rest.lua',
}

ui_page 'nui/index.html'

files {
    'nui/index.html',
    'nui/style.css',
    'nui/app.js',
}
