fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'moonshine-shops'
author 'Moonshine RP'
description 'Beispiel-Resource: 24/7 Shops auf Basis des Moonshine Frameworks'
version '1.0.0'

dependency 'moonshine-core'

shared_script 'config.lua'
client_script 'client.lua'
server_script 'server.lua'

ui_page 'nui/index.html'

files {
    'nui/index.html',
    'nui/app.js',
}
