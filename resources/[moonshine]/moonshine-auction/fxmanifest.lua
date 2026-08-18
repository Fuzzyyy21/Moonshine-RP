fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'moonshine-auction'
author 'Moonshine RP'
description 'Auktionshaus mit Geboten, Sofortkauf und Abholfach'
version '1.0.0'

dependency 'moonshine-core'

shared_scripts {
    'shared/config.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/database.lua',
    'server/auction.lua',
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
