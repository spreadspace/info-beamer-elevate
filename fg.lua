-- FOR TESTING --
local NO_REMOTE_EVENTS = false
local NO_LOCAL_EVENTS = false
local NO_SPONSOR_SLIDES = false
local EMPTY_WHEN_NO_LOCAL = false
local ALWAYS_PUSH_EMPTY = false
-----------------

local NO_LOCATION = { id = "unk", name = "Unknown location" }
local EMC_LOCATION_ID = "emc"


-- register self
local fg = rawget(_G, "fg")
if not fg then
    fg = {}
    rawset(_G, "fg", fg)
    fg.base_time = 0
    fg.locname = NO_LOCATION.name
    fg.locdef = NO_LOCATION
    fg.lasttimeupdate = 0
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
    return fg.DEVICE and fg.DEVICE.location
end

function fg.getbgstyle()
    return (fg.DEVICE and fg.DEVICE.bg_style)
end

function fg.gettrack(id)
    return fg._trackLUT[id]
end


function fg.onUpdateConfig(config)
    config = assert(config or CONFIG, "no CONFIG passed or found")
    tools.debugPrint(2, "Updating config...")
    fg.DEVICE = nil
    fg.locname = NO_LOCATION.name

    for _, dev in pairs(config.devices) do
        if SERIAL == tostring(dev.serial) then
            tools.debugPrint(2, "I'm device '" .. tostring(SERIAL) .. "' and located at: " .. tostring(dev.location))
            fg.DEVICE = dev
            break
        end
    end

    fg._trackLUT = {}
    for i, track in pairs(config.tracks) do
        fg._trackLUT[track.id] = track
    end

    if fg.DEVICE then
        local myloc = fg.location()
        for _, loc in pairs(config.locations) do
            if loc.id == myloc then
                fg.locname = loc.name
                fg.locdef = loc
                break
            end
        end
    else
        tools.debugPrint(1, "WARNING: I'm device '" .. tostring(SERIAL) .. "' but am not listed in config")
    end
end
if CONFIG then
    fg.onUpdateConfig(config)
end


-- returns nil when event is not to be shown
local function mangleEvent(ev, ts, locid)
    local startts = math.floor(tonumber(ev.startts))
    local endts = math.floor(tonumber(ev.endts))
    local status = "unknown"
    local show
    local prio = 0
    if not (startts and endts) then
        tools.debugPrint(1, "WARNING: Event " .. tostring(ev.title) .. " has no valid timestamp")
        status = "invalid"
    elseif ts > endts then
        status = "finished"
    elseif ts < startts then
        status = "future"
        show = true
    elseif ts < endts then
        status = "running"
        show = true
        prio = 100
    end

    if show then
        local evc = table.shallowcopy(ev)
        evc.prio = prio
        evc.status = status
        evc.locid = locid
        evc.startts = tonumber(evc.startts)
        evc.endts = tonumber(evc.endts)
        return evc
    end
end

function fg.makebackupslide()
    tools.debugPrint(3, "Generating backup slide")
    local location = fg.locdef or NO_LOCATION
    return Slide.newLocal(1, location, false)
end

local function _eventorder(a, b)
    return a.prio > b.prio or (a.prio == b.prio and a.startts < b.startts)
end

function fg.scheduleToSlides(schedule)
    local locations = assert(CONFIG.locations, "CONFIG.locations missing")
    local tracks = assert(CONFIG.tracks, "CONFIG.tracks missing")

    local myloc = fg.location()
    local slides = {}
    local localevents = {}
    local ts = math.floor(fg.getts())


    local tracklut = {}
    for _, track in pairs(tracks) do
        tracklut[track.id] = track
    end
    local loclut = {}
    for _, loc in pairs(locations) do
        loclut[loc.id] = loc
    end

    local nevents = 0
    local trackloc = tools.newAutoExtendTable() -- "name" => { "locA" => events..., "locB" => events... }
    for _, locdef in ipairs(locations) do
        local events = schedule[locdef.id]
        local ishere = myloc == locdef.id
        if events then
            for _, ev in pairs(events) do
                local evx = mangleEvent(ev, ts, locdef.id)
                if evx then
                    if ishere then
                        table.insert(localevents, evx)
                    end
                    local trackname = evx.track
                    if tracklut[trackname] then
                        evx.track = tracklut[trackname]
                        tools.debugPrint(4, "track[" .. trackname .. "] loc[" .. locdef.id .. "] = " .. tostring(evx.title))
                        table.insert(trackloc[trackname][locdef.id], evx)
                    else
                        evx.track = nil
                        tools.debugPrint(1, "WARNING: Unknown track [" .. tostring(trackname) .. "] for event " .. tostring(evx.title))
                    end
                    nevents = nevents + 1
                end
            end
        else
            tools.debugPrint(3, "  (Location " .. locdef.id .. " has no schedule)")
        end
    end

    tools.debugPrint(2, "found " .. nevents .. " events, generating slides...")

    local haslocal
    local slideid = 0
    if not NO_LOCAL_EVENTS then
        if myloc then
            tools.debugPrint(3, "I have " .. #localevents .. " events upcoming here [" .. myloc .. "]")
            table.sort(localevents, _eventorder)
            slideid = slideid + 1
            local slide = Slide.newLocal(slideid, loclut[myloc], localevents)
            table.insert(slides, slide)
            haslocal = true
        end
    end
    if (not haslocal and EMPTY_WHEN_NO_LOCAL) or ALWAYS_PUSH_EMPTY then
        table.insert(slides, fg.makebackupslide())
    end
    if not NO_REMOTE_EVENTS then
        for _, tr in ipairs(tracks) do
            for _, loc in ipairs(locations) do
                local evs = trackloc[tr.id][loc.id]
                if evs and #evs > 0 and not (loc.id == EMC_LOCATION_ID) then
                    table.sort(evs, _eventorder)
                    slideid = slideid + 1
                    tools.debugPrint(3, "GEN SLIDE[" .. slideid .. "]: track[" .. tr.id .. "] loc[" .. loc.id .. "] = " .. #evs .. " events")
                    local slide = Slide.newRemote(slideid, tr, loc, evs)
                    table.insert(slides, slide)
                end
            end
        end
    end
    if not NO_SPONSOR_SLIDES and CONFIG.sponsors then
        tools.debugPrint(3, "Check sponsors... skip counter = " .. tostring(fg._sponsorSkipCounter))
        if fg._sponsorSkipCounter and fg._sponsorSkipCounter > 0 then
            fg._sponsorSkipCounter = fg._sponsorSkipCounter - 1
        else
            tools.debugPrint(3, "-> Generate sponsor slides...")
            for _, spon in ipairs(CONFIG.sponsors) do
                slideid = slideid + 1
                local slide = Slide.newSponsor(slideid, spon)
                table.insert(slides, slide)
            end
            fg._sponsorSkipCounter = CONFIG.sponsor_slides_skip or 0
        end
    end
    return slides
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
