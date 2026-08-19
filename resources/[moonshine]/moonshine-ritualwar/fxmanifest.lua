fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'moonshine-ritualwar'
author 'Moonshine RP'
description 'Ritualpunkte als umkaempfte Gebiete: Bindung, Ertrag, Wegzoll, Stoerung'
version '1.0.0'

dependency 'moonshine-core'
dependency 'moonshine-mystic'
dependency 'moonshine-factions'

shared_scripts {
    -- Ritualpunkte kommen aus der Mystik; Resourcen teilen keine Globals.
    '@moonshine-mystic/shared/config.lua',
    'shared/config.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/database.lua',
    'server/claims.lua',
    'server/binding.lua',
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
    'client/binding.lua',
}

ui_page 'nui/index.html'

files {
    'nui/index.html',
    'nui/style.css',
    'nui/app.js',
}
