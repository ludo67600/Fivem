-- fxmanifest.lua - Modifications à apporter
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Police Nationale'
description 'Script Police Nationale pour FiveM avec ESX'
version '1.1.0'

shared_scripts {
    '@es_extended/imports.lua',
    '@ox_lib/init.lua',
    'shared/config.lua'
}

client_scripts {
    'client/main.lua',
    'client/interactions.lua',
    'client/vehicles.lua',
    'client/props.lua',
    'client/k9.lua',
    'client/appointments.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/vehicles.lua',
    'server/props.lua',
    'server/k9.lua',
    'server/appointments.lua',
    'server/discord.lua'
}

dependencies {
    'es_extended',
    'oxmysql',
    'ox_inventory',
    'ox_target',
    'ox_lib',
    'rp-identity'
}