fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'moonshine-jobs'
author 'Moonshine RP'
description 'Jobcenter und Arbeitsauftraege mit echtem Ablauf'
version '1.0.0'

dependency 'moonshine-core'

shared_scripts {
    'shared/config.lua',
    'shared/jobs.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/database.lua',
    'server/shift.lua',
    'server/jobcenter.lua',
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
    'client/shift.lua',
}

ui_page 'nui/index.html'

files {
    'nui/index.html',
    'nui/style.css',
    'nui/app.js',
}
