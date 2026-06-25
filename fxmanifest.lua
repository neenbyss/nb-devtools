fx_version 'cerulean'
game 'gta5'
lua54 'yes'

description 'nb-devtools — Developer Utility Tools for FiveM'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

server_scripts {
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
    'client/coords.lua',
    'client/placer.lua',
    'client/camera.lua',
    'client/inspector.lua',
}

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

ui_page 'html/index.html'

dependency 'nb-bridge'
