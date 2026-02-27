-- Server-side for qbx_parkingbrake

local lastToggle = {}
local COOLDOWN_MS = 800

-- Using GetVehicleType/Class on server requires OneSync
RegisterNetEvent('qbx_parkingbrake:server:toggle', function()
    local src = source
    local now = GetGameTimer()

    -- Server-side rate limit
    if lastToggle[src] and (now - lastToggle[src]) < COOLDOWN_MS then return end
    lastToggle[src] = now

    local ped = GetPlayerPed(src)
    local veh = GetVehiclePedIsIn(ped, false)

    -- Validation: Is player actually the driver?
    if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= ped then return end

    -- Validation: Check for excluded classes
    local vehClass = GetVehicleClass(veh)
    if Config.ExcludedClasses[vehClass] then return end

    -- Toggle state
    local currentState = Entity(veh).state.parkingbrake
    Entity(veh).state:set('parkingbrake', not currentState, true)
end)

-- Clean up cooldown table
AddEventHandler('playerDropped', function()
    lastToggle[source] = nil
end)
