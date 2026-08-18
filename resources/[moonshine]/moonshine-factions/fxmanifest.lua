fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'moonshine-factions'
author 'Moonshine RP'
description 'Fraktionen mit Raengen, Skilltree, Shop, Garage, Kasse, Tresor und Gebieten'
version '1.0.0'

dependency 'moonshine-core'

shared_scripts {
    'shared/config.lua',
    'shared/emblems.lua',
    'shared/ranks.lua',
    'shared/skills.lua',
    'shared/territories.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/database.lua',
    'server/faction.lua',
    'server/members.lua',
    'server/manage.lua',
    'server/vault.lua',
    'server/shop.lua',
    'server/garage.lua',
    'server/missions.lua',
    'server/territory.lua',
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
    'client/territory.lua',
    'client/garage.lua',
}

ui_page 'nui/index.html'

files {
    'nui/index.html',
    'nui/style.css',
    'nui/app.js',
}
