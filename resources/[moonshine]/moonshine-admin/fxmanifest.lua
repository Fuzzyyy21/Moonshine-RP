fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'moonshine-admin'
author 'Moonshine RP'
description 'Adminpanel, Werkzeuge und ein sechsschichtiger Wachhund'
version '1.0.0'

dependency 'moonshine-core'

shared_scripts {
    'shared/config.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/allow.lua',
    'server/evidence.lua',
    'server/guard.lua',
    'server/watch.lua',
    'server/events.lua',
    'server/heartbeat.lua',
    'server/panel.lua',
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
    'client/tools.lua',
    'client/guard.lua',
    'client/heartbeat.lua',
}

ui_page 'nui/index.html'

files {
    'nui/index.html',
    'nui/style.css',
    'nui/app.js',
}
