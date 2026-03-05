local lastToggle = {}
local COOLDOWN_MS = 800

RegisterNetEvent('qbx_parkingbrake:server:toggle', function()
    local src = source
    local now = GetGameTimer()

    -- Server-side rate limit — client cooldown alone is not exploit-proof
    if lastToggle[src] and (now - lastToggle[src]) < COOLDOWN_MS then return end
    lastToggle[src] = now

    local ped = GetPlayerPed(src)
    local veh = GetVehiclePedIsIn(ped, false)

    -- Validation: Is player actually the driver?
    if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= ped then return end

    -- Security Validation: Mirror client-side checks to prevent exploits
    if GetEntityHealth(ped) <= 0 then return end

    local vehClass = GetVehicleClass(veh)
    if Config.ExcludedClasses[vehClass] then return end

    if GetEntitySpeed(veh) > 1 then return end

    if Config.EnableStateChecks then
        if GetEntitySubmergedLevel and GetEntitySubmergedLevel(veh) >= Config.WaterThreshold then return end
        if IsEntityAttached and IsEntityAttached(veh) then return end
    end

    -- Toggle state
    local currentState = Entity(veh).state.parkingbrake
    Entity(veh).state:set('parkingbrake', not currentState, true)
end)

-- Clean up cooldown table when a player drops to avoid memory leak
AddEventHandler('playerDropped', function()
    lastToggle[source] = nil
end)
