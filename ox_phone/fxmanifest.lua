-- "ox_phone\fxmanifest.lua"

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'ox_phone'
author 'Claude AI'
version '1.0.0'
description 'Un script de téléphone complet pour FiveM avec ESX Legacy'

shared_scripts {
    '@es_extended/imports.lua',
    '@ox_lib/init.lua',
    'shared/*.lua'
}

client_scripts {
    'client/*.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/*.lua'
}

ui_page 'web/dist/index.html'

files {
    -- Fichiers de base
    'web/dist/*',
    'web/dist/**/*',
    
    -- Fonds d'écran
    'web/dist/images/wallpapers/*.jpg',
    'web/dist/images/wallpapers/*.png',
    
    -- Sons
    'web/dist/sounds/*.ogg',
    'web/dist/sounds/*.mp3',
    
    -- Icônes
    'web/dist/icons/*.png'
}

dependencies {
    'es_extended',
    'ox_inventory',
    'ox_lib',
    'ox_target',
    'oxmysql',
    'screenshot-basic'
}