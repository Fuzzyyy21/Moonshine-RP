fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'moonshine-core'
author 'Moonshine RP'
description 'Custom Framework fuer den Moonshine RP FiveM Server'
version '1.0.0'

dependency 'oxmysql'

shared_scripts {
    'shared/config.lua',
    'shared/utils.lua',
    'shared/jobs.lua',
    'shared/items.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/database.lua',
    'server/logger.lua',
    'server/player.lua',
    'server/main.lua',
    'server/callbacks.lua',
    'server/characters.lua',
    'server/inventory.lua',
    'server/drops.lua',
    'server/status.lua',
    'server/paycheck.lua',
    'server/commands.lua',
    'server/exports.lua',
}

client_scripts {
    'client/main.lua',
    'client/callbacks.lua',
    'client/character.lua',
    'client/status.lua',
    'client/inventory.lua',
    'client/exports.lua',
}

ui_page 'nui/index.html'

files {
    'nui/index.html',
    'nui/style.css',
    'nui/app.js',
}
