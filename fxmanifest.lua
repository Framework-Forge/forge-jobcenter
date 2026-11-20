fx_version 'cerulean'
game 'gta5'
name 'Forge - Job Center'
description 'Central de empregos e contatos, com editor administrativo'
version '1.2.2'

dependencies { 'pr_bridge', '/onesync' }
shared_scripts { '@pr_bridge/init.lua', 'shared/config.lua', 'shared/schema.lua' }
server_scripts { 'server/storage.lua', 'server/media.lua', 'server/main.lua' }
client_script 'client/main.lua'

ui_page 'web/dist/index.html'
files { 'web/dist/index.html', 'web/dist/assets/*' }

server_script 'server/version.lua'
