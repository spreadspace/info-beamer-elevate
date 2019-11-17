local UNKNOWN_LOCATION = { id = "unk", name = "Unknown location" }

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

    device.config = nil
    device.location = nil
end

-- returns current time and time passed since last update was received
function device.getTime()
    local now = sys.now()
    return device.baseTime + now, now - device.lastTimeUpdate
end

-- interpolates since last update received
function device.getTimeString()
    local off = sys.now() - device.lastTimeUpdate
    local h, m, s = device.timeH, device.timeM, device.timeS
    local ds, dm, dh
    if not (h and m and s) then
        return "--:--"
    end
    local rem
    ds = math.floor(((s + off) % 60))
    rem = (s + off) / 60
    dm = math.floor((m + rem) % 60)
    rem = (m + rem) / 60
    dh = math.floor((h + rem) % 24)

    return ("%02d:%02d"):format(dh, dm)
end

function device.updateTime(tm)
    local now = sys.now()
    device.lastTimeUpdate = now

    local u, h, m, s = tm:match("([%d%.]+),(%d+),(%d+),([%d%.]+)")
    device.baseTime = tonumber(u) - now
    device.timeH = tonumber(h)
    device.timeM = tonumber(m)
    device.timeS = tonumber(s)

    tools.debugPrint(4, "updated base time: " .. device.baseTime .. ", it's now: " .. device.getTimeString() .. " (" ..  device.getTime() .. ")")
end



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


print("device.lua loaded completely")
return device
