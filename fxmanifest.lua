fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'obfuscore'
description 'ATL (Auftragslieferung) Szenario - 17v17 Pounder Delivery'
version '1.0.0'

shared_scripts {
    '@es_extended/imports.lua',
    'config.lua'
}

server_scripts {
    'server.lua'
}

client_scripts {
    'client.lua'
}

dependencies {
    'es_extended',
    'ox_inventory'
}
