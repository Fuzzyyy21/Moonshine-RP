fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'moonshine-vehicles'
author 'Moonshine RP'
description 'Autohaeuser, eigene Fahrzeuge, Garagen, Schluessel und Verwahrstelle'
version '1.0.0'

dependency 'moonshine-core'

shared_scripts {
    'shared/config.lua',
    'shared/catalogue.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/database.lua',
    'server/vehicles.lua',
    'server/keys.lua',
    'server/garage.lua',
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
    'client/garage.lua',
    'client/keys.lua',
}

ui_page 'nui/index.html'

files {
    'nui/index.html',
    'nui/style.css',
    'nui/app.js',
}
