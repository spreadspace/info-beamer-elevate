-------------------------------------------------------------------------------
--- device state

-- register self
local device = rawget(_G, "device")
if not device then
    device = {}
    rawset(_G, "device", device)
    device.baseTime = 0
    device.timeH = nil
    device.timeM = nil
    device.timeS = nil
    device.lastTimeUpdate = 0
    device.timestamps = {}

    device.config = nil
    device.location = nil
end


-------------------------------------------------------------------------------
--- wall-clock time

function device.getWallClockTime()
    local now = sys.now()
    return device.baseTime + now, now - device.lastTimeUpdate
end

-- interpolates since last update received
function device.getWallClockTimeString()
    local h, m, s = device.timeH, device.timeM, device.timeS
    if not (h and m and s) then
        return "--:--"
    end

    local overflow = sys.now() - device.lastTimeUpdate
    local si = math.floor(((s + overflow) % 60))
    overflow = (s + overflow) / 60
    local mi = math.floor((m + overflow) % 60)
    overflow = (m + overflow) / 60
    local hi = math.floor((h + overflow) % 24)

    return ("%02d:%02d"):format(hi, mi)
end

function device.getTimestampOfDate(date)
    return device.timestamps[date]
end

function device.updateTime(tm)
    local now = sys.now() -- this is relative to the start of info-beamer
    device.lastTimeUpdate = now

    local u, h, m, s = tm:match("([%d%.]+),(%d+),(%d+),([%d%.]+)")
    device.baseTime = tonumber(u) - now
    device.timeH = tonumber(h)
    device.timeM = tonumber(m)
    device.timeS = tonumber(s)

    tools.debugPrint(4, "updated base time: " .. device.baseTime .. ", it's now: " ..
                         device.getWallClockTimeString() .. " (" ..  device.getWallClockTime() .. ")")
end

function device.updateTimestamps(date, ts)
    device.timestamps[date] = tonumber(ts)
end


-------------------------------------------------------------------------------
--- device specific configuration

local UNKNOWN_LOCATION = { id = "unk", name = "Unknown location" }

function device.getLocation()
    return device.location or UNKNOWN_LOCATION
end

function device.getBackgroundStyle()
    return (device.config and device.config.bg_style)
end

function device.updateConfig()
    tools.debugPrint(2, "Updating device configuration...")

    local serial = assert(sys.get_env("SERIAL"), "SERIAL not set! Please set INFOBEAMER_ENV_SERIAL")
    local locations = assert(CONFIG.locations, "WARNING: CONFIG.locations missing")
    local lutLocations = tools.createLookupTable(locations)

    device.config = nil
    device.location = nil
    for _, cfgDevice in pairs(CONFIG.devices) do
        if serial == tostring(cfgDevice.serial) then
            device.config = cfgDevice
            device.location = lutLocations[cfgDevice.location]
            tools.debugPrint(2, "I'm device '" .. serial .. "' and located at: " .. device.getLocation().id)
            break
        end
    end

    if not device.config then
        tools.debugPrint(1, "WARNING: I'm device '" .. serial .. "' but am not listed in config")
    end
end
if CONFIG then
    device.updateConfig()
end


-------------------------------------------------------------------------------

print("device.lua loaded completely")
return device
