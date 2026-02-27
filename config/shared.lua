Config = {}

Config.DefaultKey = 'N'
Config.NotifyType = 'inform' -- 'success', 'error', 'inform', 'warning'
Config.CommandCooldown = 1000 -- Milliseconds between toggles to prevent spam
Config.HoldTime = 1000 -- Milliseconds to hold the key before toggling

-- Physics settings for rolling logic
Config.Physics = {
    MaxRollTime = 3600,       -- Max time (in frames) the car forces rolling logic (safety limit)
    StuckTime = 60,           -- Frames to wait before stopping if car is "stuck" (speed < MinSpeed)
    MinSpeed = 0.6,           -- Minimum speed to consider the car "moving"
    MinPitch = 0.5,           -- Minimum angle (pitch) required to start rolling
    BaseForce = 0.18,         -- Base force applied to push the car
    MaxForce = 0.75,          -- Maximum force cap
    PitchMultiplier = 0.05,   -- How much pitch affects the force
}

-- Water submersion detection: submersion level at which parking brake auto-releases (0.0 = surface, 1.0 = fully submerged)
Config.WaterThreshold = 0.5

-- Enable/disable environment state checks (water submersion, tow/attachment auto-release)
Config.EnableStateChecks = true

-- Milliseconds between water/tow checks (lower = more responsive, higher = less CPU usage)
Config.MonitorInterval = 500

-- Vehicle classes that do not support the parking brake
Config.ExcludedClasses = {
    [8] = true, -- Motorcycles
    [13] = true, -- Bicycles
    [14] = true, -- Boats
    [15] = true, -- Helicopters
    [16] = true, -- Planes
    [21] = true, -- Trains
}
