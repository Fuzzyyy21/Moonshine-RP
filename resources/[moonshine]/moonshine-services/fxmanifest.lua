fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'moonshine-services'
author 'Moonshine RP'
description 'Tankstellen, Werkstaetten, Bank, Geldautomaten und Schwarzmarkt'
version '1.0.0'

dependency 'moonshine-core'

shared_scripts {
    'shared/config.lua',
    'shared/locations.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/bank.lua',
    'server/fuel.lua',
    'server/repair.lua',
    'server/blackmarket.lua',
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
    'client/fuel.lua',
    'client/repair.lua',
}

ui_page 'nui/index.html'

files {
    'nui/index.html',
    'nui/style.css',
    'nui/app.js',
}
