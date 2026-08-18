fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'moonshine-appearance'
author 'Moonshine RP'
description 'Charaktereditor, Kleidungslaeden, Friseure und Outfits'
version '1.0.0'

dependency 'moonshine-core'

shared_scripts {
    'shared/config.lua',
    'shared/data.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/database.lua',
    'server/main.lua',
}

client_scripts {
    'client/appearance.lua',
    'client/editor.lua',
    'client/main.lua',
}

ui_page 'nui/index.html'

files {
    'nui/index.html',
    'nui/style.css',
    'nui/app.js',
}
