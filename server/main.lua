local lastToggle = {}
local COOLDOWN_MS = 800

local function isVehicleDisabled(veh)
    if not veh or not DoesEntityExist(veh) then return true end
    if not Config.EnableStateChecks then return false end

    local submergedLevel = 0.0
    if GetEntitySubmergedLevel then
        submergedLevel = GetEntitySubmergedLevel(veh)
    end

    local isAttached = false
    if IsEntityAttached then
        isAttached = IsEntityAttached(veh)
    end

    return submergedLevel >= Config.WaterThreshold or isAttached
end

lib.callback.register('qbx_parkingbrake:server:toggle', function(source)
    local src = source
    local now = GetGameTimer()

    -- Server-side rate limit — client cooldown alone is not exploit-proof
    if lastToggle[src] and (now - lastToggle[src]) < COOLDOWN_MS then return end
    lastToggle[src] = now

    local ped = GetPlayerPed(src)
    local veh = GetVehiclePedIsIn(ped, false)

    -- Validation: Is player actually the driver?
    if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= ped then return end

    -- Validation: Check player health/death state
    if IsPedDeadOrDying(ped, true) then return end

    -- Validation: Check excluded classes
    if Config.ExcludedClasses[GetVehicleClass(veh)] then return end

    -- Validation: Check if disabled (water/tow)
    if isVehicleDisabled(veh) then return end

    -- Validation: Speed check
    if GetEntitySpeed(veh) > 1 then return end

    -- Toggle state
    local currentState = Entity(veh).state.parkingbrake
    Entity(veh).state:set('parkingbrake', not currentState, true)
end)

-- Clean up cooldown table when a player drops to avoid memory leak
AddEventHandler('playerDropped', function()
    lastToggle[source] = nil
end)
