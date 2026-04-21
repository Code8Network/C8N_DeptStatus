-- =====================================================================
-- C8N_DeptStatus  |  Client
-- Draws blips for other on-duty personnel in the same department.
-- =====================================================================

local selfOnDuty     = false
local selfDept       = nil
local selfDeptCfg    = nil
local roster         = {}   -- [serverId(string)] = { dept = '...' }
local blips          = {}   -- [serverId(number)] = blipHandle

-- ---------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------
local function notify(msg)
    if not Config.NotifyOnDuty then return end
    SetNotificationTextEntry('STRING')
    AddTextComponentSubstringPlayerName(msg)
    DrawNotification(false, true)
end

local function removeAllBlips()
    for id, blip in pairs(blips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
        blips[id] = nil
    end
end

local function removeBlip(serverId)
    local b = blips[serverId]
    if b and DoesBlipExist(b) then RemoveBlip(b) end
    blips[serverId] = nil
end

local function createOrUpdateBlip(serverId, ped, deptCfg, playerName)
    local blip = blips[serverId]
    if not blip or not DoesBlipExist(blip) then
        blip = AddBlipForEntity(ped)
        SetBlipSprite(blip, deptCfg.blip.sprite)
        SetBlipColour(blip, deptCfg.blip.color)
        SetBlipScale(blip, deptCfg.blip.scale + 0.0)
        SetBlipDisplay(blip, deptCfg.blip.display)
        SetBlipAsShortRange(blip, deptCfg.blip.shortRange and true or false)
        SetBlipCategory(blip, 7)
        ShowHeadingIndicatorOnBlip(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(('[%s] %s'):format(deptCfg.short, playerName or ''))
        EndTextCommandSetBlipName(blip)
        blips[serverId] = blip
    end
    return blip
end

-- ---------------------------------------------------------------------
-- Blip loop: only runs while self is on duty
-- ---------------------------------------------------------------------
local function blipLoop()
    CreateThread(function()
        while selfOnDuty do
            if selfDeptCfg then
                local myServerId = GetPlayerServerId(PlayerId())
                for sidStr, info in pairs(roster) do
                    local sid = tonumber(sidStr)
                    if sid and sid ~= myServerId and info.dept == selfDept then
                        local player = GetPlayerFromServerId(sid)
                        if player ~= -1 and NetworkIsPlayerActive(player) then
                            local ped = GetPlayerPed(player)
                            if ped and ped ~= 0 and DoesEntityExist(ped) then
                                createOrUpdateBlip(sid, ped, selfDeptCfg, GetPlayerName(player))
                            else
                                removeBlip(sid)
                            end
                        else
                            removeBlip(sid)
                        end
                    end
                end
                -- prune blips for players no longer in roster or no longer same dept
                for sid, _ in pairs(blips) do
                    local info = roster[tostring(sid)]
                    if not info or info.dept ~= selfDept then
                        removeBlip(sid)
                    end
                end
            end
            Wait(Config.BlipUpdateRate)
        end
        removeAllBlips()
    end)
end

-- ---------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------
RegisterNetEvent('c8n_deptstatus:setState', function(onDuty, deptId, deptCfg)
    selfOnDuty  = onDuty and true or false
    selfDept    = onDuty and deptId or nil
    selfDeptCfg = onDuty and deptCfg or nil

    if selfOnDuty then
        TriggerServerEvent('c8n_deptstatus:requestRoster')
        blipLoop()
        notify(('~g~ON DUTY~s~ - %s'):format(deptCfg and deptCfg.short or deptId))
    else
        removeAllBlips()
        notify('~r~OFF DUTY~s~')
    end
end)

RegisterNetEvent('c8n_deptstatus:syncRoster', function(newRoster)
    roster = newRoster or {}
    if not selfOnDuty then
        removeAllBlips()
    end
end)

AddEventHandler('onResourceStop', function(resName)
    if resName == GetCurrentResourceName() then
        removeAllBlips()
    end
end)
