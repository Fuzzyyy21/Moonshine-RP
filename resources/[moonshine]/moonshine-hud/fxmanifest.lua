fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'moonshine-hud'
author 'Moonshine RP'
description 'Anzeige: Status, Geld, Fahrzeug, Uhr - vollstaendig einstellbar'
version '1.0.0'

dependency 'moonshine-core'

shared_scripts {
    'shared/config.lua',
}

client_scripts {
    'client/settings.lua',
    'client/data.lua',
    'client/vehicle.lua',
    'client/main.lua',
    'client/menu.lua',
}

ui_page 'nui/index.html'

files {
    'nui/index.html',
    'nui/style.css',
    'nui/app.js',
}
