-- Server-side for qbx_parkingbrake
--
-- The previous MySQL callback 'qbx-parkingbrake:server:isOwnedVehicle'
-- was removed because SetVehicleHasBeenOwnedByPlayer() has no effect
-- on vehicle persistence in FiveM/OneSync. Persistence is handled by
-- qbx_core via SetEntityOrphanMode + statebag 'persisted'.
--
-- References:
--   https://docs.fivem.net/docs/cookbook/2020/07/10/a-quick-note-about-onesync-server-side-persistence/
--   https://forum.cfx.re/t/is-this-native-working-correctly/727247

RegisterNetEvent('qbx_parkingbrake:server:toggle', function()
    local src = source
    local ped = GetPlayerPed(src)
    local veh = GetVehiclePedIsIn(ped, false)

    -- Validation: Is player actually the driver?
    if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= ped then return end

    -- Toggle state
    local currentState = Entity(veh).state.parkingbrake
    Entity(veh).state:set('parkingbrake', not currentState, true)
end)
