fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'moonshine-death'
author 'Moonshine RP'
description 'Bewusstlosigkeit, Wiederbelebung und Respawn fuer Moonshine RP'
version '1.0.0'

dependency 'moonshine-core'

shared_script 'config.lua'

server_scripts {
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
    'client/ui.lua',
}

ui_page 'nui/index.html'

files {
    'nui/index.html',
    'nui/app.js',
}
