fx_version 'cerulean'
game 'gta5'

author 'you'
description 'ESX Infection RP (propagation, incubation, symptomes, items, BDD)'
version '1.0.0'

shared_scripts {
  '@es_extended/imports.lua',
  'shared/config.lua'
}

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server/main.lua'
}

client_scripts {
  'client/main.lua'
}