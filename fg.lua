local UNKNOWN_LOCATION = { id = "unk", name = "Unknown location" }


-- register self
local fg = rawget(_G, "fg")
if not fg then
    fg = {}
    rawset(_G, "fg", fg)
    fg.base_time = 0
    fg.lasttimeupdate = 0

    fg.device = nil
end

local SERIAL = assert(sys.get_env("SERIAL"), "SERIAL not set! Please set INFOBEAMER_ENV_SERIAL")

-- current time, time passed since last update was received
function fg.getts()
    local now = sys.now()
    return fg.base_time + now, now - fg.lasttimeupdate
end

-- interpolates since last update received
function fg.gettimestr()
    local off = sys.now() - fg.lasttimeupdate
    local h, m, s = fg.timeh, fg.timem, fg.times
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



function fg.location()
    return (fg.device and fg.device.location)
end

function fg.getbgstyle()
    return (fg.device and fg.device.bg_style)
end


function fg.onUpdateConfig(config)
    config = assert(config or CONFIG, "no CONFIG passed or found")
    tools.debugPrint(2, "Updating config...")

    local locations = assert(CONFIG.locations, "CONFIG.locations missing")
    local lutLocations = tools.createLookupTable(locations)
    lutLocations[UNKNOWN_LOCATION.id] = UNKNOWN_LOCATION

    fg.device = nil
    for _, device in pairs(config.devices) do
        if SERIAL == tostring(device.serial) then
            fg.device = device
            fg.device.location = lutLocations[device.location]
            if not fg.device.location then
                fg.device.location = UNKNOWN_LOCATION
            end
            tools.debugPrint(2, "I'm device '" .. tostring(SERIAL) .. "' and located at: " .. tostring(device.location.id))
            break
        end
    end

    if not fg.device then
        tools.debugPrint(1, "WARNING: I'm device '" .. tostring(SERIAL) .. "' but am not listed in config")
    end
end
if CONFIG then
    fg.onUpdateConfig(config)
end


function fg.onUpdateTime(tm)
    local now = sys.now()
    fg.lasttimeupdate = now
    local u,h,m,s =tm:match("([%d%.]+),(%d+),(%d+),([%d%.]+)")
    fg.timeh = tonumber(h)
    fg.timem = tonumber(m)
    fg.times = tonumber(s)
    fg.base_time = tonumber(u) - now
    tools.debugPrint(4, "UPDATED TIME", fg.base_time, "; NOW: ", fg.getts(), fg.gettimestr())
end



print("fg.lua loaded completely")
return fg
