lib.locale()
local lastVehicle = nil
local monitorActive = false
local previousSeat = nil

-- Vehicle classes that do not support the parking brake
local excludedClasses = {
    [8] = true, -- Motorcycles
    [13] = true, -- Bicycles
    [14] = true, -- Boats
    [15] = true, -- Helicopters
    [16] = true, -- Planes
    [21] = true, -- Trains
}

-- Returns true if the vehicle is in a state where the parking brake should be blocked or released
local function isVehicleDisabled(veh)
    if Config.EnableWaterCheck and GetEntitySubmergedLevel(veh) >= Config.WaterThreshold then
        return true
    end
    if Config.EnableTowCheck and IsEntityAttached(veh) then
        return true
    end
    return false
end

-- Rolling physics: keeps handbrake released while the vehicle rolls on a slope.
-- stuckTimer exits after 20s of no movement (truly stuck).
-- hardLimit is a 3-minute absolute safety stop.
local function startRollingPhysics(vehToRelease)
    CreateThread(function()
        if not NetworkHasControlOfEntity(vehToRelease) then
            NetworkRequestControlOfEntity(vehToRelease)
            Wait(500)
        end

        -- 1. Skru av bremsene for å forhindre risting/ABS-hakking i førsteperson (Old Logic Restoration)
        local originalBrakeForce = GetVehicleHandlingFloat(vehToRelease, 'CHandlingData', 'fBrakeForce')
        SetVehicleHandlingFloat(vehToRelease, 'CHandlingData', 'fBrakeForce', 0.0)
        
        local hasBeenMoving = false
        local stuckTimer = 0
        local hardLimit  = 3600
        
        while hardLimit > 0 and DoesEntityExist(vehToRelease) do
            -- Drep rulle-loopen umiddelbart hvis noen setter på brekket
            if Entity(vehToRelease).state.parkingbrake then break end
            
            -- If another player took control, stop immediately
            if not NetworkHasControlOfEntity(vehToRelease) then break end

            local speed = GetEntitySpeed(vehToRelease)
            local pitch = GetEntityPitch(vehToRelease)

            -- Ensure brakes are physically OFF (Old Logic)
            SetVehicleHandbrake(vehToRelease, false)
            SetVehicleBrake(vehToRelease, false)

            if speed > 0.6 then hasBeenMoving = true end -- Adjusted threshold from Old Logic

            -- 2. Vi MÅ fortsatt dytte bilen for å overvinne GTA sitt "lim" på tomme biler!
            if math.abs(pitch) > 0.5 and speed < 15.0 then
                -- Extra base force when starting from rest
                local startBoost = speed < 0.8 and 0.15 or 0.0
                local calculatedForce = 0.18 + startBoost + (math.abs(pitch) * 0.08)
                if calculatedForce > 0.75 then calculatedForce = 0.75 end
                local force = (pitch > 0 and -calculatedForce or calculatedForce)
                ApplyForceToEntity(vehToRelease, 1, 0.0, force, 0.0, 0.0, 0.0, 0.0, 0, true, true, true, false, true)
            end

            if not IsVehicleSeatFree(vehToRelease, -1) then break end
            
            -- Exit once settled on flat ground
            if hasBeenMoving and speed < 0.6 and math.abs(pitch) < 1.0 then break end

            -- FIKS: "Stuck Timer" for krasj (som når du rygger inn i en annen bil)
            if speed < 0.8 then -- Adjusted threshold from Old Logic
                stuckTimer = stuckTimer + 1
                -- 60 iterasjoner * 50ms = 3 sekunder.
                if stuckTimer >= 60 then break end 
            else
                -- Hvis den triller fritt, nullstiller vi timeren
                stuckTimer = 0
            end

            hardLimit = hardLimit - 1
            Wait(50)
        end

        -- 3. Gi tilbake bremsene når bilen stopper eller noen tar på håndbrekket (Old Logic Restoration)
        if DoesEntityExist(vehToRelease) then
            SetVehicleHandlingFloat(vehToRelease, 'CHandlingData', 'fBrakeForce', originalBrakeForce)
        end
    end)
end

CreateThread(function()
    RequestScriptAudioBank('audiodirectory/custom_sounds', false)
end)

-- Sync state bag on entry/exit
lib.onCache('vehicle', function(veh)
    -- Handle exit physics
    if not veh and lastVehicle and DoesEntityExist(lastVehicle) then
        local wasDriver = previousSeat == -1
        previousSeat = nil  -- reset after use

        -- Only the driver controls rolling physics
        if wasDriver then
            local isOn = Entity(lastVehicle).state.parkingbrake or false
            local vehToRelease = lastVehicle

            if isOn then
                SetVehicleHandbrake(vehToRelease, true)
            else
                startRollingPhysics(vehToRelease)
            end
        end

        -- Reset state on vehicle exit
        monitorActive = false
        LocalPlayer.state:set('parkingbrake', false, false)
        lastVehicle = nil
        return
    end

    previousSeat = nil  -- reset on entry too

    -- Update reference and sync state on entry
    if veh then
        -- Skip excluded vehicle classes and ensure HUD is off
        if excludedClasses[GetVehicleClass(veh)] then
            LocalPlayer.state:set('parkingbrake', false, false)
            return
        end

        lastVehicle = veh

        local vehicleState = Entity(veh).state.parkingbrake
        if vehicleState == nil then
            -- Statebag ikke lastet ennå – sett kun HUD lokalt, ikke repliker
            LocalPlayer.state:set('parkingbrake', false, false)
        else
            -- State bag already exists: sync HUD locally only
            LocalPlayer.state:set('parkingbrake', vehicleState, false)
            SetVehicleHandbrake(veh, vehicleState)
        end
    end
end)

-- Rolling when driver switches to a different seat without exiting
lib.onCache('seat', function(seat)
    if not seat then return end -- FIX: Keep previous seat on exit
    local wasDriving = previousSeat == -1
    previousSeat = seat

    -- Only trigger when switching FROM driver seat TO another seat (not full exit)
    if not wasDriving then return end

    local veh = cache.vehicle
    if not veh or not DoesEntityExist(veh) then return end
    if excludedClasses[GetVehicleClass(veh)] then return end
    if isVehicleDisabled(veh) then return end

    local isOn = Entity(veh).state.parkingbrake or false
    if isOn then return end

    startRollingPhysics(veh)
end)

-- Toggle Command
RegisterCommand('+toggleParkingbrake', function()
    local veh = cache.vehicle
    -- Validation: Must be in vehicle and driver
    if not veh or GetPedInVehicleSeat(veh, -1) ~= cache.ped then return end
    if excludedClasses[GetVehicleClass(veh)] then return end

    -- Block toggle if vehicle is in water or being towed (silent, no notification)
    if isVehicleDisabled(veh) then return end

    -- Request toggle from server
    TriggerServerEvent('qbx_parkingbrake:server:toggle')
end, false)

-- Required counterpart for +toggleParkingbrake key binding
RegisterCommand('-toggleParkingbrake', function() end, false)

-- Register KeyMapping
RegisterKeyMapping('+toggleParkingbrake', 'Toggle Parking Brake', 'keyboard', Config.DefaultKey)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        ReleaseNamedScriptAudioBank('audiodirectory/custom_sounds')
    end
end)

AddStateBagChangeHandler('parkingbrake', nil, function(bagName, key, value, _reserved, replicated)
    local entity = GetEntityFromStateBagName(bagName)
    if entity == 0 or not DoesEntityExist(entity) then return end
    if GetEntityType(entity) ~= 2 then return end -- ignore LocalPlayer.state (ped, not vehicle)

    CreateThread(function()
        -- Wait for collision to load before applying handbrake (per FiveM docs)
        while not HasCollisionLoadedAroundEntity(entity) do
            if not DoesEntityExist(entity) then return end
            Wait(250)
        end

        -- Apply handbrake physically for all clients
        SetVehicleHandbrake(entity, value)

        -- Play sound for nearby clients (network-synced via state bag)
        local snd = GetSoundId()
        local soundName = value and 'handbrake_sound_pull' or 'handbrake_sound_rele'

        PlaySoundFromEntity(snd, soundName, entity, 'special_soundset', false, 0)

        local timeout = 100
        while not HasSoundFinished(snd) and timeout > 0 do
            Wait(50)
            timeout = timeout - 1
        end
        ReleaseSoundId(snd)
    end)

    -- Logic for the current driver (Notification & Monitoring)
    if entity == cache.vehicle and cache.seat == -1 then
        -- Sync local HUD state
        LocalPlayer.state:set('parkingbrake', value, false)

        -- Notification
        lib.notify({
            title = 'Vehicle',
            description = value and (locale('info.parking_brake_on') or 'Parking brake engaged') or (locale('info.parking_brake_off') or 'Parking brake released'),
            type = Config.NotifyType or 'inform',
        })

        -- Start monitoring thread to auto-release if vehicle enters water or gets towed
        if value then
            if not monitorActive then
                monitorActive = true
                CreateThread(function()
                    local monVeh = entity
                    while monitorActive and DoesEntityExist(monVeh) do
                        if cache.vehicle ~= monVeh then break end
                        
                        -- If brake is turned off externally, stop monitoring
                        if not Entity(monVeh).state.parkingbrake then break end

                        if isVehicleDisabled(monVeh) then
                            -- If disabled (water/tow), request server to toggle OFF
                            if Entity(monVeh).state.parkingbrake then
                                TriggerServerEvent('qbx_parkingbrake:server:toggle')
                            end
                            break
                        end

                        Wait(Config.MonitorInterval or 1000)
                    end
                    monitorActive = false
                end)
            end
        else
            monitorActive = false
        end
    end
end)
