-- =====================================================================
-- C8N_DeptStatus  |  Server
-- Handles duty state, permission checks, webhook logging.
-- Permission backends: 'discordaceperms' | 'badgerdiscordapi'
-- =====================================================================

local OnDuty = {}  -- [src] = { dept = 'lspd', startedAt = os.time(), name = '...' }

-- ---------------------------------------------------------------------
-- Utility
-- ---------------------------------------------------------------------
local function log(msg)
    print(('[C8N_DeptStatus] %s'):format(msg))
end

local function formatDuration(seconds)
    if seconds < 60 then return ('%ds'):format(seconds) end
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    if h > 0 then return ('%dh %dm %ds'):format(h, m, s) end
    return ('%dm %ds'):format(m, s)
end

local function getDiscordId(src)
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if id:sub(1, 8) == 'discord:' then
            return id:sub(9)
        end
    end
    return nil
end

local function hasAcePerm(src)
    return Config.StaffAcePerm ~= '' and IsPlayerAceAllowed(src, Config.StaffAcePerm)
end

-- ---------------------------------------------------------------------
-- Permission backends
-- ---------------------------------------------------------------------

-- Backend 1: DiscordAcePerms (or any resource that maps Discord roles to ACE)
local function checkAcePerms(src, dept, cb)
    local perms = dept.acePerms
    if type(perms) ~= 'table' or #perms == 0 then cb(false, 'no acePerms configured') return end
    for _, perm in ipairs(perms) do
        if IsPlayerAceAllowed(src, perm) then cb(true) return end
    end
    cb(false)
end

-- Backend 2: badger_discord_api
--   exports.badger_discord_api:GetDiscordRoles(source)      -> table of role IDs
--   exports.badger_discord_api:UserHasRole(source, roleId)  -> boolean
local function checkBadgerDiscord(src, dept, cb)
    local roles = dept.discordRoles
    if type(roles) ~= 'table' or #roles == 0 then cb(false, 'no discordRoles configured') return end

    local badger
    local ok = pcall(function() badger = exports.badger_discord_api end)
    if not ok or not badger then cb(false, 'badger_discord_api not started') return end

    -- Try UserHasRole per role
    for _, roleId in ipairs(roles) do
        local hasRole = false
        local success = pcall(function()
            hasRole = badger:UserHasRole(src, roleId)
        end)
        if success and hasRole then cb(true) return end
    end

    -- Fallback: GetDiscordRoles and compare
    local playerRoles
    local success = pcall(function()
        playerRoles = badger:GetDiscordRoles(src)
    end)
    if success and type(playerRoles) == 'table' then
        local set = {}
        for _, r in ipairs(playerRoles) do set[tostring(r)] = true end
        for _, r in ipairs(roles) do
            if set[tostring(r)] then cb(true) return end
        end
    end

    cb(false)
end

local function checkPermission(src, dept, cb)
    if hasAcePerm(src) then cb(true) return end

    local backend = (Config.PermissionBackend or ''):lower()
    if backend == 'discordaceperms' then
        checkAcePerms(src, dept, cb)
    elseif backend == 'badgerdiscordapi' then
        checkBadgerDiscord(src, dept, cb)
    else
        cb(false, ('unknown PermissionBackend: %s'):format(tostring(Config.PermissionBackend)))
    end
end

-- ---------------------------------------------------------------------
-- Webhook logging
-- ---------------------------------------------------------------------
local function sendWebhook(deptId, embed)
    local dept = Config.Departments[deptId]
    local url  = (dept and dept.webhook ~= '' and dept.webhook) or Config.DefaultWebhook
    if not url or url == '' then return end

    local payload = {
        username   = Config.WebhookUsername,
        avatar_url = Config.WebhookAvatar ~= '' and Config.WebhookAvatar or nil,
        embeds     = { embed },
    }

    PerformHttpRequest(url, function() end, 'POST', json.encode(payload), {
        ['Content-Type'] = 'application/json',
    })
end

local function logDutyChange(src, deptId, goingOn, shiftSeconds)
    local dept = Config.Departments[deptId]
    if not dept then return end

    local name      = GetPlayerName(src) or ('Player ' .. src)
    local discordId = getDiscordId(src) or 'unknown'

    local fields = {
        { name = 'Player',     value = ('%s (ID %d)'):format(name, src), inline = true },
        { name = 'Discord',    value = ('<@%s>'):format(discordId),      inline = true },
        { name = 'Department', value = dept.label,                        inline = false },
    }
    if not goingOn and shiftSeconds then
        table.insert(fields, { name = 'Shift Time', value = formatDuration(shiftSeconds), inline = true })
    end

    sendWebhook(deptId, {
        title       = goingOn and 'On Duty' or 'Off Duty',
        color       = goingOn and Config.EmbedColors.onDuty or Config.EmbedColors.offDuty,
        fields      = fields,
        timestamp   = os.date('!%Y-%m-%dT%H:%M:%SZ'),
    })
end

-- ---------------------------------------------------------------------
-- Duty state helpers
-- ---------------------------------------------------------------------
local function isOnDuty(src)
    return OnDuty[src] ~= nil
end

local function buildRosterPayload()
    local list = {}
    for src, info in pairs(OnDuty) do
        local dept = Config.Departments[info.dept]
        list[#list + 1] = {
            src   = src,
            name  = info.name,
            dept  = info.dept,
            short = dept and dept.short or info.dept,
            since = info.startedAt,
        }
    end
    return list
end

local function broadcastRoster()
    local roster = {}
    for src, info in pairs(OnDuty) do
        roster[tostring(src)] = {
            dept = info.dept,
        }
    end
    TriggerClientEvent('c8n_deptstatus:syncRoster', -1, roster)
end

local function goOnDuty(src, deptId)
    local dept = Config.Departments[deptId]
    if not dept then return false end

    if not Config.AllowMultiDept and isOnDuty(src) then
        -- switch departments: log off first
        local prev = OnDuty[src]
        local elapsed = os.time() - prev.startedAt
        logDutyChange(src, prev.dept, false, elapsed)
    end

    OnDuty[src] = {
        dept      = deptId,
        startedAt = os.time(),
        name      = GetPlayerName(src) or ('Player ' .. src),
    }

    TriggerClientEvent('c8n_deptstatus:setState', src, true, deptId, dept)
    logDutyChange(src, deptId, true)
    broadcastRoster()
    return true
end

local function goOffDuty(src)
    local info = OnDuty[src]
    if not info then return nil end

    local elapsed = os.time() - info.startedAt
    OnDuty[src] = nil

    TriggerClientEvent('c8n_deptstatus:setState', src, false, info.dept, nil)
    logDutyChange(src, info.dept, false, elapsed)
    broadcastRoster()
    return info.dept, elapsed
end

-- ---------------------------------------------------------------------
-- Command handlers
-- ---------------------------------------------------------------------
local function chat(src, tag, msg, color)
    TriggerClientEvent('chat:addMessage', src, {
        color = color or { 200, 200, 200 },
        args  = { tag, msg },
    })
end

local function handleOnDuty(src, args)
    local deptId = args[1] and args[1]:lower() or nil

    if not deptId then
        local available = {}
        for id, _ in pairs(Config.Departments) do available[#available + 1] = id end
        chat(src, 'Duty',
            Config.Messages.pickDept:format(Config.OnDutyCommand, table.concat(available, '|')),
            { 200, 200, 0 })
        return
    end

    local dept = Config.Departments[deptId]
    if not dept then
        chat(src, 'Duty', Config.Messages.unknownDept:format(deptId), { 200, 80, 80 })
        return
    end

    if not Config.AllowMultiDept and isOnDuty(src) and OnDuty[src].dept == deptId then
        chat(src, 'Duty', Config.Messages.alreadyOn:format(dept.short), { 200, 200, 0 })
        return
    end

    checkPermission(src, dept, function(allowed, err)
        if not allowed then
            if err then log(('Permission check failed for %s: %s'):format(src, err)) end
            chat(src, 'Duty', Config.Messages.noPerm, { 200, 80, 80 })
            return
        end
        goOnDuty(src, deptId)
        chat(src, 'Duty', Config.Messages.onDuty:format(dept.short), { 80, 200, 120 })
    end)
end

local function handleOffDuty(src)
    if not isOnDuty(src) then
        chat(src, 'Duty', Config.Messages.notOnDuty, { 200, 200, 0 })
        return
    end
    local deptId, elapsed = goOffDuty(src)
    local dept = Config.Departments[deptId]
    chat(src, 'Duty',
        Config.Messages.offDuty:format(dept and dept.short or deptId, formatDuration(elapsed)),
        { 200, 200, 200 })
end

-- ---------------------------------------------------------------------
-- Register commands. If OnDutyCommand == OffDutyCommand, the shared
-- command behaves as a toggle: no args + already on duty -> off duty.
-- ---------------------------------------------------------------------
local sameCmd = Config.OnDutyCommand == Config.OffDutyCommand

RegisterCommand(Config.OnDutyCommand, function(src, args)
    if src == 0 then log('This command must be run by a player.') return end
    if sameCmd and #args == 0 and isOnDuty(src) then
        handleOffDuty(src)
        return
    end
    handleOnDuty(src, args)
end, false)

if not sameCmd then
    RegisterCommand(Config.OffDutyCommand, function(src)
        if src == 0 then log('This command must be run by a player.') return end
        handleOffDuty(src)
    end, false)
end

RegisterCommand(Config.RosterCommand, function(src)
    if src == 0 then
        log('This command must be run by a player.')
        return
    end
    if not isOnDuty(src) and not hasAcePerm(src) then
        chat(src, 'Roster', Config.Messages.noPerm, { 200, 80, 80 })
        return
    end

    local list = buildRosterPayload()
    if #list == 0 then
        chat(src, 'Roster', Config.Messages.rosterEmpty)
        return
    end

    chat(src, 'Roster', Config.Messages.rosterHeader:format(#list), { 180, 220, 255 })
    for _, entry in ipairs(list) do
        local elapsed = formatDuration(os.time() - entry.since)
        chat(src, 'Roster',
            Config.Messages.rosterLine:format(entry.short, entry.name, entry.src, elapsed),
            { 220, 220, 220 })
    end
end, false)

-- ---------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------
AddEventHandler('playerDropped', function()
    local src = source
    if OnDuty[src] then
        local info    = OnDuty[src]
        local elapsed = os.time() - info.startedAt
        OnDuty[src]   = nil
        logDutyChange(src, info.dept, false, elapsed)
        broadcastRoster()
    end
end)

RegisterNetEvent('c8n_deptstatus:requestRoster', function()
    local src = source
    if not isOnDuty(src) then return end
    local roster = {}
    for s, info in pairs(OnDuty) do
        roster[tostring(s)] = { dept = info.dept }
    end
    TriggerClientEvent('c8n_deptstatus:syncRoster', src, roster)
end)

-- Export so other resources can check duty state
exports('IsOnDuty', function(src)
    return isOnDuty(src)
end)

exports('GetDuty', function(src)
    local info = OnDuty[src]
    if not info then return nil end
    return { dept = info.dept, startedAt = info.startedAt }
end)
