lib.locale()
local lastVehicle = nil
local monitorActive = false
local previousSeat = nil
local lastToggleTime = 0
local rollingByNetId = {}  -- guard: prevents concurrent startRollingPhysics threads per vehicle

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
    if not DoesEntityExist(vehToRelease) then return end
    
    local netId = NetworkGetNetworkIdFromEntity(vehToRelease)
    -- Fallback for å unngå nil-index feil hvis entiteten ikke har et gyldig Network ID
    if not netId or netId == 0 then return end 

    -- Prevent two concurrent rolling threads on the same vehicle
    if rollingByNetId[netId] then return end
    rollingByNetId[netId] = true

    CreateThread(function()
        -- Retry control request until granted or timeout (50ms * 40 = 2s max)
        if not NetworkHasControlOfEntity(vehToRelease) then
            NetworkRequestControlOfEntity(vehToRelease)
            local controlTimeout = 40
            while not NetworkHasControlOfEntity(vehToRelease) and controlTimeout > 0 do
                Wait(50)
                controlTimeout = controlTimeout - 1
            end
        end

        local hasBeenMoving = false
        local stuckTimer = 0
        local hardLimit  = Config.Physics.MaxRollTime
        
        while hardLimit > 0 and DoesEntityExist(vehToRelease) do
            -- Exit checks first, before touching anything
            if Entity(vehToRelease).state.parkingbrake then break end
            if not NetworkHasControlOfEntity(vehToRelease) then break end
            if not IsVehicleSeatFree(vehToRelease, -1) then break end
            local speed = GetEntitySpeed(vehToRelease)
            local pitch = GetEntityPitch(vehToRelease)
            SetVehicleHandbrake(vehToRelease, false)
            SetVehicleBrake(vehToRelease, false)

            if speed > Config.Physics.MinSpeed then hasBeenMoving = true end

            if math.abs(pitch) > Config.Physics.MinPitch and speed < 15.0 then
                local calculatedForce = Config.Physics.BaseForce + (math.abs(pitch) * Config.Physics.PitchMultiplier)
                if calculatedForce > Config.Physics.MaxForce then calculatedForce = Config.Physics.MaxForce end
                local force = (pitch > 0 and -calculatedForce or calculatedForce)
                ApplyForceToEntity(vehToRelease, 1, 0.0, force, 0.0, 0.0, 0.0, 0.0, 0, true, true, true, false, true)
            end

            if hasBeenMoving and speed < Config.Physics.MinSpeed and math.abs(pitch) < 1.0 then break end
            if speed < 0.8 then 
                stuckTimer = stuckTimer + 1
                -- 60 iterasjoner * 50ms = 3 sekunder.
                if stuckTimer >= Config.Physics.StuckTime then break end
            else
                stuckTimer = 0
            end
            hardLimit = hardLimit - 1
            Wait(50)
        end

        rollingByNetId[netId] = nil
    end)
end

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
        if Config.ExcludedClasses[GetVehicleClass(veh)] then
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
    if Config.ExcludedClasses[GetVehicleClass(veh)] then return end
    if isVehicleDisabled(veh) then return end

    local isOn = Entity(veh).state.parkingbrake or false
    if isOn then return end

    startRollingPhysics(veh)
end)

-- Toggle Command
RegisterCommand('+toggleParkingbrake', function()
    -- Cooldown check
    local currentTime = GetGameTimer()
    if (currentTime - lastToggleTime) < Config.CommandCooldown then return end
    lastToggleTime = currentTime

    local veh = cache.vehicle
    -- Validation: Must be in vehicle and driver
    if not veh or GetPedInVehicleSeat(veh, -1) ~= cache.ped then return end
    if Config.ExcludedClasses[GetVehicleClass(veh)] then return end

    -- Block toggle if vehicle is in water or being towed (silent, no notification)
    if isVehicleDisabled(veh) then return end

    -- Request toggle from server
    TriggerServerEvent('qbx_parkingbrake:server:toggle')
end, false)

-- Required counterpart for +toggleParkingbrake key binding
RegisterCommand('-toggleParkingbrake', function() end, false)

-- Register KeyMapping
RegisterKeyMapping('+toggleParkingbrake', 'Toggle Parking Brake', 'keyboard', Config.DefaultKey)


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

        -- Apply handbrake physically only for entity owner
        if NetworkGetEntityOwner(entity) == PlayerId() then
            SetVehicleHandbrake(entity, value)
        end

        -- Play sound for nearby clients (network-synced via state bag)
        qbx.loadAudioBank('audiodirectory/custom_sounds')
        local snd = GetSoundId()
        local soundName = value and 'handbrake_sound_pull' or 'handbrake_sound_rele'

        PlaySoundFromEntity(snd, soundName, entity, 'special_soundset', false, 0)
        Wait(0)

        local timeout = 100
        while not HasSoundFinished(snd) and timeout > 0 do
            Wait(50)
            timeout = timeout - 1
        end
        ReleaseSoundId(snd)
        ReleaseNamedScriptAudioBank('audiodirectory/custom_sounds')
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
                        if not DoesEntityExist(monVeh) then
                            monitorActive = false
                            break
                        end

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
