Config = {}

-- =====================================================================
-- GENERAL
-- =====================================================================

-- Commands. You can set OffDutyCommand = OnDutyCommand to make a single
-- toggle command (e.g. both set to 'duty'). If they differ, each command
-- does only its own action.
Config.OnDutyCommand     = 'onduty'    -- /onduty <deptId>  (goes on duty)
Config.OffDutyCommand    = 'offduty'   -- /offduty          (goes off duty)
Config.RosterCommand     = 'cops'      -- /cops shows on-duty roster (rename to taste)

Config.BlipUpdateRate    = 2500        -- ms between blip position updates
Config.AllowMultiDept    = false       -- if true, players can be on duty for multiple depts at once
Config.NotifyOnDuty      = true        -- client chat/notify when going on/off duty
Config.StaffAcePerm      = 'deptstatus.admin' -- ace perm that bypasses all permission checks

-- =====================================================================
-- PERMISSION BACKEND
-- Choose ONE of: 'discordaceperms' | 'badgerdiscordapi'
--
--   'discordaceperms' : Uses ACE permissions set by the DiscordAcePerms
--                       resource (or any resource that maps Discord roles
--                       to ACE groups). Each department declares `acePerms`.
--
--   'badgerdiscordapi': Uses the badger_discord_api resource exports to
--                       read a player's Discord role IDs directly. Each
--                       department declares `discordRoles`.
-- =====================================================================
Config.PermissionBackend = 'discordaceperms'

-- =====================================================================
-- DEPARTMENTS
-- For each department, provide whichever permission list matches the
-- backend you chose. The other list can be left empty or omitted.
--
--   acePerms     -> used when PermissionBackend = 'discordaceperms'
--   discordRoles -> used when PermissionBackend = 'badgerdiscordapi'
-- =====================================================================
Config.Departments = {
    ['lspd'] = {
        label        = 'Los Santos Police Department',
        short        = 'LSPD',
        acePerms     = { 'deptstatus.lspd' },
        discordRoles = { '000000000000000000' },
        blip = {
            sprite  = 60,
            color   = 38,   -- blue
            scale   = 0.9,
            display = 4,
            shortRange = false,
        },
        webhook = '', -- leave blank to fall back to Config.DefaultWebhook
    },

    ['bcso'] = {
        label        = 'Blaine County Sheriff\'s Office',
        short        = 'BCSO',
        acePerms     = { 'deptstatus.bcso' },
        discordRoles = { '000000000000000000' },
        blip = {
            sprite  = 60,
            color   = 46,   -- gold
            scale   = 0.9,
            display = 4,
            shortRange = false,
        },
        webhook = '',
    },

    ['sahp'] = {
        label        = 'San Andreas Highway Patrol',
        short        = 'SAHP',
        acePerms     = { 'deptstatus.sahp' },
        discordRoles = { '000000000000000000' },
        blip = {
            sprite  = 56,
            color   = 5,    -- yellow
            scale   = 0.9,
            display = 4,
            shortRange = false,
        },
        webhook = '',
    },

    ['fire'] = {
        label        = 'Fire / EMS',
        short        = 'FD',
        acePerms     = { 'deptstatus.fire' },
        discordRoles = { '000000000000000000' },
        blip = {
            sprite  = 436,
            color   = 1,    -- red
            scale   = 0.9,
            display = 4,
            shortRange = false,
        },
        webhook = '',
    },

    ['sang'] = {
        label        = 'San Andreas National Guard',
        short        = 'SANG',
        acePerms     = { 'deptstatus.sang' },
        discordRoles = { '000000000000000000' },
        blip = {
            sprite  = 310,
            color   = 52,   -- dark green
            scale   = 0.9,
            display = 4,
            shortRange = false,
        },
        webhook = '',
    },
}

-- =====================================================================
-- WEBHOOKS
-- Default webhook used if a department does not define its own.
-- Leave blank to disable logging entirely.
-- =====================================================================
Config.DefaultWebhook = ''
Config.WebhookUsername = 'Department Status'
Config.WebhookAvatar   = ''

Config.EmbedColors = {
    onDuty  = 3066993,  -- green
    offDuty = 15158332, -- red
    info    = 3447003,  -- blue
}

-- =====================================================================
-- LOCALE / MESSAGES
-- =====================================================================
Config.Messages = {
    noPerm        = 'You do not have permission for that department.',
    onDuty        = 'You are now ON DUTY as %s.',
    offDuty       = 'You are now OFF DUTY (%s). Shift time: %s.',
    alreadyOn     = 'You are already on duty for %s.',
    notOnDuty     = 'You are not currently on duty.',
    pickDept      = 'Usage: /%s <%s>',
    unknownDept   = 'Unknown department: %s',
    rosterHeader  = '--- On-Duty Personnel (%d) ---',
    rosterLine    = '[%s] %s (ID %d) - %s',
    rosterEmpty   = 'No personnel currently on duty.',
}
