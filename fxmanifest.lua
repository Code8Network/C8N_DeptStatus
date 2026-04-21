fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'C8N_DeptStatus'
author 'C8N'
description 'Department on-duty system with Discord role permissions, blip visibility, and webhook logging.'
version '1.0.0'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}

-- Requires one of:
--   DiscordAcePerms  (Config.PermissionBackend = 'discordaceperms')
--   badger_discord_api  (Config.PermissionBackend = 'badgerdiscordapi')
