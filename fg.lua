local yield = coroutine.yield
local tqnew = require "tq"
local json = require "json"
local floor = math.floor

-- FOR TESTING --
local NO_REMOTE_EVENTS = false
local NO_LOCAL_EVENTS = false
local NO_SPONSOR_SLIDES = false
local EMPTY_WHEN_NO_LOCAL = true
local ALWAYS_PUSH_EMPTY = false
-----------------

local NO_LOCATION = { id = "unk", name = "Unknown location" }

local NO_EVENT = {
    start = "404",
    --title = "Event not found blah rofl lolo omg wtf long title right let's see where this goes or otherwise things might break",
    title = "Event not found",
    --subtitle = "There is currently no event to display. Move along. There is currently no event to display. Move along. There is currently no event to display. Move along. There is currently no event to display. Move along. There is currently no event to display. Move along.",
    subtitle = "There is currently no event to display.\nMove along.",
}


-- register self
local fg = rawget(_G, "fg") 
if not fg then
    fg = {}
    rawset(_G, "fg", fg)
    fg.base_time = 0
    fg.locname = NO_LOCATION.name
    fg.locdef = NO_LOCATION
    fg.lasttimeupdate = 0
    fg.slides = {}
end

local SERIAL = assert(sys.get_env("SERIAL"), "SERIAL not set! Please set INFOBEAMER_ENV_SERIAL")
print("SERIAL = " .. tostring(SERIAL))
print("CONFIG = " .. tostring(CONFIG))



local function printevent(ev)
    print(("[%s] %s - %s: %s [%s]")
        :format(tostring(ev.status), tostring(ev.start), tostring(ev["end"]),
                tostring(ev.title), tostring(ev.track))
    )
end



local SLIDE = {}
SLIDE.__index = SLIDE

function SLIDE.newLocal(id, locdef, events)
    local empty
    if not events or #events == 0 then
        events = {NO_EVENT}
        empty = true
    end
    local self = { id = id, here = true,
        location = assert(locdef),
        events = assert(events),
        empty = empty
    }
    return setmetatable(self, SLIDE)
end

function SLIDE.newRemote(id, trackdef, locdef, events)
    local self = { id = id,
        track = assert(trackdef),
        location = assert(locdef),
        events = assert(events)
    }
    return setmetatable(self, SLIDE)
end

function SLIDE.newSponsor(id, spon)
    local self = { id = id,
        image = spon.image,
        sponsor = spon,
    }
    return setmetatable(self, SLIDE)
end



function SLIDE:print()
    print"  ** [SLIDE] **"
    print(" - Location: ", self.location.name, "[" .. tostring(self.location.id) .. "]")
    print(" - Events (" .. #self.events .. " shown):")
    for i, ev in ipairs(self.events) do
        printevent(ev)
    end
end


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
    ds = floor(((s + off) % 60))
    rem = (s + off) / 60
    dm = floor((m + rem) % 60)
    rem = (m + rem) / 60
    dh = floor((h + rem) % 24)
    
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
    print("Reloading config...")
    fg.DEVICE = nil
    fg.locname = "Unknown location"
    
    for _, dev in pairs(config.devices) do
        if SERIAL == tostring(dev.serial) then
            print("I'm located in [" .. tostring(dev.location) .. "]")
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
        print("Warning: I'm device [" .. tostring(SERIAL) .. "] but am not listed in config")
    end
end
if CONFIG then
    fg.onUpdateConfig(config)
end

local function shallowcopy(t)
    local tt = {}
    for k, v in pairs(t) do
        tt[k] = v
    end
    return tt
end

-- returns nil when event is not to be shown
local function mangleEvent(ev, ts, locid)
    local startts = math.floor(tonumber(ev.startts))
    local endts = math.floor(tonumber(ev.endts))
    local status = "UNK"
    local show
    local prio = 0
    if not (startts and endts) then
        print("WARNING: Event " .. tostring(ev.title) .. " has no valid timestamp")
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
        local evc = shallowcopy(ev)
        evc.prio = prio
        evc.status = status
        evc.locid = locid
        evc.startts = tonumber(evc.startts)
        evc.endts = tonumber(evc.endts)
        return evc
    end
end

local function _makebackupslide()
    print("Generating backup slide")
    local location = fg.locdef or NO_LOCATION
    return SLIDE.newLocal(1, location, {})
end


local _autoextendmeta0 =
{
    __index = function(t, k)
        local ret = {}
        t[k] = ret
        return ret
    end
}

local _autoextendmeta1 =
{
    __index = function(t, k)
        local ret = setmetatable({}, _autoextendmeta0)
        t[k] = ret
        return ret
    end
}

local function _eventorder(a, b)
    return a.prio > b.prio or (a.prio == b.prio and a.startts < b.startts)
end

local function _scheduleToSlides(locations, tracks, tab)
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
    local trackloc = setmetatable({}, _autoextendmeta1) -- "name" => { "locA" => events..., "locB" => events... }
    for _, locdef in ipairs(locations) do
        local events = tab[locdef.id]
        local ishere = myloc == locdef.id
        if events then
            for _, ev in pairs(events) do
                local evx = mangleEvent(ev, ts, locdef.id)
                if evx then
                    if ishere then
                        table.insert(localevents, evx)
                    end
                    if tracklut[evx.track] then
                        print("track[" .. evx.track .. "] loc[" .. locdef.id .. "] = " .. tostring(evx.title))
                        table.insert(trackloc[evx.track][locdef.id], evx)
                    else
                        print("WARNING: Unknown track [" .. tostring(evx.track) .. "] for event " .. tostring(evx.title))
                    end
                    nevents = nevents + 1
                end
            end
        else
            print("  (Location " .. locdef.id .. " has no schedule)")
        end
    end
    
    print("Found " .. nevents .. " events, generating slides...")
    
    local haslocal
    local slideid = 0
    if not NO_LOCAL_EVENTS then
        if myloc then
            print("I have " .. #localevents .. " events upcoming here [" .. myloc .. "]")
            table.sort(localevents, _eventorder)
            slideid = slideid + 1
            local slide = SLIDE.newLocal(slideid, loclut[myloc], localevents)
            table.insert(slides, slide)
            haslocal = true
        end
    end
    if (not haslocal and EMPTY_WHEN_NO_LOCAL) or ALWAYS_PUSH_EMPTY then
        table.insert(slides, _makebackupslide())
    end
    if not NO_REMOTE_EVENTS then
        for _, tr in ipairs(tracks) do
            for _, loc in ipairs(locations) do
                local evs = trackloc[tr.id][loc.id]
                if evs and #evs > 0 then
                    table.sort(evs, _eventorder)
                    slideid = slideid + 1
                    print("GEN SLIDE[" .. slideid .. "]: track[" .. tr.id .. "] loc[" .. loc.id .. "] = " .. #evs .. " events")
                    local slide = SLIDE.newRemote(slideid, tr, loc, evs)
                    table.insert(slides, slide)
                end
            end
        end
    end
    if not NO_SPONSOR_SLIDES and CONFIG.sponsors then
        print("Check sponsors... skip counter = " .. tostring(fg._sponsorSkipCounter))
        if fg._sponsorSkipCounter and fg._sponsorSkipCounter > 0 then
            fg._sponsorSkipCounter = fg._sponsorSkipCounter - 1
        else
            print("-> Generate sponsor slides...")
            for _, spon in ipairs(CONFIG.sponsors) do
                slideid = slideid + 1
                local slide = SLIDE.newSponsor(slideid, spon)
                table.insert(slides, slide)
            end
            fg._sponsorSkipCounter = CONFIG.sponsor_slides_skip or 0
        end
    end
    
    
    print("Generated " .. #slides .. " slides")
    

    return slides
end

function fg.onUpdateSchedule(sch)
    fg.last_schedule = sch
    local locations = assert(CONFIG.locations, "CONFIG.locations missing")
    local tracks = assert(CONFIG.tracks, "CONFIG.tracks missing")
    local slides = _scheduleToSlides(locations, tracks, sch)
    fg.slides = slides
end

function fg.onUpdateTime(tm)
    local now = sys.now()
    fg.lasttimeupdate = now
    local u,h,m,s =tm:match("([%d%.]+),(%d+),(%d+),([%d%.]+)")
    fg.timeh = tonumber(h)
    fg.timem = tonumber(m)
    fg.times = tonumber(s)
    fg.base_time = tonumber(u) - now
    print("UPDATED TIME", fg.base_time, "; NOW: ", fg.getts(), fg.gettimestr())
end

local function _slideiter(slides)
    yield()
    for _, slide in ipairs(slides) do
        yield(slide)
    end
end

function fg.newSlideIter()
    -- HACK: always regenerate slides. slides shown may be different each time.
    if fg.last_schedule then
        fg.onUpdateSchedule(fg.last_schedule)
    end
    
    local slides
    if fg.slides and #fg.slides > 0 then
        slides = fg.slides
    else
        slides = {_makebackupslide()}
    end

    local co = coroutine.wrap(_slideiter)
    co(slides)
    return co, #slides
end


function string.fwrap(str, font, h, xpos, width)
    width = width or WIDTH
    xpos = xpos or 0
    local xstart = xpos
    -- always allow wrapping after punctuation chars
    local wrapped = str:gsub("(%s*)([^%s%-%,%.%;%:%/]*[%-%,%.%;%:%/]*)", function(sp, word)
        local ws = font:width(sp, h)
        local ww = font:width(word, h)
        xpos = xpos + ws + ww
        if xpos > width or sp:find("\n", 1, true) then -- always wrap when there's a newline
            xpos = xstart
            return "\n"..word
        end
    end)
    local splitted = {}
    for token in string.gmatch(wrapped, "[^\n]+") do
        splitted[#splitted + 1] = token
    end
    return splitted
end

-- scale t from [lower, upper] into [rangeMin, rangeMax]
function math.rescale(t, lower, upper, rangeMin, rangeMax)
    if upper == lower then
        return rangeMin
    end

    return (((t - lower) / (upper - lower)) * (rangeMax - rangeMin)) + rangeMin
end

function table.clear(t)
    for k in pairs(t) do
        t[k] = nil
    end
    return t
end



print("fg.lua loaded completely")
return fg
