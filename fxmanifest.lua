fx_version 'bodacious'
game 'gta5'
lua54 'yes'

description 'elevator'
version '1.0.0'

dependencies {
  'ox_lib'
}

shared_scripts {
  '@ox_lib/init.lua',
  'config.lua'
}

client_scripts {
  'client.lua'
}

server_scripts {
  'server.lua'
}
