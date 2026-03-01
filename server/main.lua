local lastToggle = {}
local COOLDOWN_MS = 800

lib.callback.register('qbx_parkingbrake:server:toggle', function(source)
    local now = GetGameTimer()

    -- Server-side rate limit — client cooldown alone is not exploit-proof
    if lastToggle[source] and (now - lastToggle[source]) < COOLDOWN_MS then return false end
    lastToggle[source] = now

    local ped = GetPlayerPed(source)
    local veh = GetVehiclePedIsIn(ped, false)

    -- Validation: Is player actually the driver?
    if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= ped then return false end

    -- Validation: Ensure the vehicle is not excluded
    if Config.ExcludedClasses[GetVehicleClass(veh)] then return false end

    -- Toggle state
    local currentState = Entity(veh).state.parkingbrake
    Entity(veh).state:set('parkingbrake', not currentState, true)
    return true
end)

-- Clean up cooldown table when a player drops to avoid memory leak
AddEventHandler('playerDropped', function()
    lastToggle[source] = nil
end)
