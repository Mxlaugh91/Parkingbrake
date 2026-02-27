lib.locale()

local lastVehicle = nil
local lastToggleTime = 0
local rollingByNetId = {}


local function isVehicleDisabled(veh)
    if not veh or not DoesEntityExist(veh) then return true end
    if not Config.EnableStateChecks then return false end
    
    return GetEntitySubmergedLevel(veh) >= Config.WaterThreshold or IsEntityAttached(veh)
end

local function startRollingPhysics(vehToRelease)
    if not DoesEntityExist(vehToRelease) then return end
    
    local netId = NetworkGetNetworkIdFromEntity(vehToRelease)
    if not netId or netId == 0 then return end 

    if rollingByNetId[netId] then return end
    rollingByNetId[netId] = true

    CreateThread(function()
        if not NetworkHasControlOfEntity(vehToRelease) then
            NetworkRequestControlOfEntity(vehToRelease)
            lib.waitFor(function()
                if NetworkHasControlOfEntity(vehToRelease) then return true end
            end, 'Could not get network control of vehicle', 2000)
        end

        local hasBeenMoving = false
        local stuckTimer = 0
        local hardLimit = Config.Physics.MaxRollTime
        
        while hardLimit > 0 and DoesEntityExist(vehToRelease) do
            if Entity(vehToRelease).state.parkingbrake then break end
            if not NetworkHasControlOfEntity(vehToRelease) then break end
            if not IsVehicleSeatFree(vehToRelease, -1) then break end

            local speed = GetEntitySpeed(vehToRelease)
            local pitch = GetEntityPitch(vehToRelease)
            
            SetVehicleHandbrake(vehToRelease, false)
            SetVehicleBrake(vehToRelease, false)

            if speed > Config.Physics.MinSpeed then hasBeenMoving = true end


            if math.abs(pitch) > Config.Physics.MinPitch and speed < 15.0 then
                local forceAmount = math.min(Config.Physics.BaseForce + (math.abs(pitch) * Config.Physics.PitchMultiplier), Config.Physics.MaxForce)
                local force = (pitch > 0 and -forceAmount or forceAmount)
                ApplyForceToEntity(vehToRelease, 1, 0.0, force, 0.0, 0.0, 0.0, 0.0, 0, true, true, true, false, true)
            end

            if hasBeenMoving and speed < Config.Physics.MinSpeed and math.abs(pitch) < 1.0 then break end
            
            if speed < 0.8 then 
                stuckTimer = stuckTimer + 1
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

local function handleLeavingDriverSeat(veh)
    if not veh or not DoesEntityExist(veh) then return end
    if Config.ExcludedClasses[GetVehicleClass(veh)] or isVehicleDisabled(veh) then return end

    local isOn = Entity(veh).state.parkingbrake
    if isOn then

        SetVehicleHandbrake(veh, true)
    else

        startRollingPhysics(veh)
    end
end

lib.onCache('vehicle', function(veh, oldVeh)
    if veh then
        lastVehicle = veh

        local state = Entity(veh).state.parkingbrake or false
        SetVehicleHandbrake(veh, state)
    else

        if cache.seat == -1 then
            handleLeavingDriverSeat(lastVehicle)
        end
        lastVehicle = nil
    end
end)

lib.onCache('seat', function(seat, oldSeat)

    if oldSeat == -1 and seat and seat ~= -1 then
        handleLeavingDriverSeat(cache.vehicle)
    end
end)

AddStateBagChangeHandler('parkingbrake', nil, function(bagName, key, value, _reserved, replicated)
    local entity = GetEntityFromStateBagName(bagName)
    if not entity or entity == 0 or GetEntityType(entity) ~= 2 then return end

    if NetworkGetEntityOwner(entity) == cache.playerId then
        SetVehicleHandbrake(entity, value)
    end

    if entity == cache.vehicle and cache.seat == -1 then
        qbx.loadAudioBank('audiodirectory/custom_sounds')
        qbx.playAudio({
            audioName   = value and 'handbrake_sound_pull' or 'handbrake_sound_rele',
            audioRef    = 'special_soundset',
            audioSource = entity,
        })
        ReleaseNamedScriptAudioBank('audiodirectory/custom_sounds')

        lib.notify({
            description = locale('info.parking_brake_' .. (value and 'on' or 'off')),
            type = Config.NotifyType,
        })
    end
end)

lib.addKeybind({
    name = 'toggleParkingbrake',
    description = 'Toggle Parking Brake',
    defaultKey = Config.DefaultKey,
    onPressed = function()
        local currentTime = GetGameTimer()
        if (currentTime - lastToggleTime) < Config.CommandCooldown then return end
        lastToggleTime = currentTime

        local veh = cache.vehicle
        if not veh or cache.seat ~= -1 then return end
        if Config.ExcludedClasses[GetVehicleClass(veh)] then return end
        if isVehicleDisabled(veh) then return end

        TriggerServerEvent('qbx_parkingbrake:server:toggle')
    end
})
