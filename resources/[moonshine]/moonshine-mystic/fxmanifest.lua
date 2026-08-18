fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'moonshine-mystic'
author 'Moonshine RP'
description 'Mystisches Rassen-, Skilltree- und Perksystem fuer Moonshine RP'
version '1.0.0'

dependency 'moonshine-core'

shared_scripts {
    'shared/config.lua',
    'shared/races.lua',
    'shared/progression.lua',
    'shared/skills.lua',
    'shared/perks.lua',
    'shared/items.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/database.lua',
    'server/profile.lua',
    'server/main.lua',
    'server/skills.lua',
    'server/perks.lua',
    'server/ritual.lua',
    'server/commands.lua',
    'server/exports.lua',
}

client_scripts {
    'client/main.lua',
    'client/abilities.lua',
    'client/skillbar.lua',
    'client/ritual.lua',
    'client/merchant.lua',
    'client/perks.lua',
    'client/racial.lua',
}

ui_page 'nui/index.html'

files {
    'nui/index.html',
    'nui/style.css',
    'nui/app.js',
}
