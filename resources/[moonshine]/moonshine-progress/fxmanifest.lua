fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'moonshine-progress'
author 'Moonshine RP'
description 'Playtime-Belohnungen, Missionen, Battle Pass und Kisten'
version '1.0.0'

dependency 'moonshine-core'

shared_scripts {
    'shared/config.lua',
    'shared/missions.lua',
    'shared/battlepass.lua',
    'shared/cases.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/database.lua',
    'server/profile.lua',
    'server/rewards.lua',
    'server/playtime.lua',
    'server/missions.lua',
    'server/battlepass.lua',
    'server/cases.lua',
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
}

ui_page 'nui/index.html'

files {
    'nui/index.html',
    'nui/style.css',
    'nui/app.js',
}
