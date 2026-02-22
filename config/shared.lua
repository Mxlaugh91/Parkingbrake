Config = {}

Config.DefaultKey = 'N'
Config.NotifyType = 'inform' -- 'success', 'error', 'inform', 'warning'

-- Water submersion detection: submersion level at which parking brake auto-releases (0.0 = surface, 1.0 = fully submerged)
Config.WaterThreshold = 0.5

-- Enable/disable water submersion auto-release
Config.EnableWaterCheck = true

-- Enable/disable tow/attachment auto-release (covers flatbed trucks, cargobob, etc.)
Config.EnableTowCheck = true

-- Milliseconds between water/tow checks (lower = more responsive, higher = less CPU usage)
Config.MonitorInterval = 500
