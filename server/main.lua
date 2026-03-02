local lastToggle = {}
local COOLDOWN_MS = 800

local function isVehicleDisabled(veh)
    if not veh or not DoesEntityExist(veh) then return true end
    if not Config.EnableStateChecks then return false end

    local isSubmerged = GetEntitySubmergedLevel and GetEntitySubmergedLevel(veh) >= Config.WaterThreshold or false
    local isAttached = IsEntityAttached and IsEntityAttached(veh) or false

    return isSubmerged or isAttached
end

lib.callback.register('qbx_parkingbrake:server:toggle', function(source)
    local src = source
    local now = GetGameTimer()

    -- Server-side rate limit — client cooldown alone is not exploit-proof
    if lastToggle[src] and (now - lastToggle[src]) < COOLDOWN_MS then return false end
    lastToggle[src] = now

    local ped = GetPlayerPed(src)
    local veh = GetVehiclePedIsIn(ped, false)

    -- Validation: Is player actually the driver?
    if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= ped then return false end

    -- Validation: Is player dead or dying?
    if IsPedDeadOrDying(ped, true) then return false end

    -- Validation: Is vehicle class excluded?
    if Config.ExcludedClasses and Config.ExcludedClasses[GetVehicleClass(veh)] then return false end

    -- Validation: Is vehicle disabled?
    if isVehicleDisabled(veh) then return false end

    -- Validation: Is vehicle moving too fast?
    if GetEntitySpeed(veh) > 1 then return false end

    -- Toggle state
    local currentState = Entity(veh).state.parkingbrake
    Entity(veh).state:set('parkingbrake', not currentState, true)
    return true
end)

-- Clean up cooldown table when a player drops to avoid memory leak
AddEventHandler('playerDropped', function()
    lastToggle[source] = nil
end)
