local yield = coroutine.yield
local tqnew = require "tq"
local json = require "json"
local floor = math.floor

local NO_LOCATION = { id = "unk", name = "Unknown location" }

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
    local self = { id = id, here = true,
        location = assert(locdef),
        events = assert(events)
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


function SLIDE:print()
    print"  ** [SLIDE] **"
    print(" - Location: ", self.location.name, "[" .. tostring(self.location.id) .. "]")
    print(" - Events (" .. #self.events .. " shown):")
    for i, ev in ipairs(self.events) do
        printevent(ev)
    end
end

function SLIDE:draw()
    --CONFIG.font:write(30, 30, self.location.name, 50, CONFIG.foreground_color.rgb_with_a(alpha))
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
    
    return ("%d:%d"):format(dh, dm)
end



function fg.location()
    return fg.DEVICE and fg.DEVICE.location
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
        return evc
    end
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
    
    local slideid = 0
    if myloc then
        print("I have " .. #localevents .. " events upcoming here [" .. myloc .. "]")
        table.sort(localevents, _eventorder)
        slideid = slideid + 1
        local slide = SLIDE.newLocal(slideid, loclut[myloc], localevents)
        table.insert(slides, slide)
    end
    
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
    
    print("Generated " .. #slides .. " slides")
    

    return slides
end

function fg.onUpdateSchedule(sch)
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

local function _makebacksupslides()
    print("Generating backup slide")
    local location = fg.locdef or NO_LOCATION
    local slide = SLIDE.newLocal(1, location, {})
    return {slide}
end


local function _slideiter(slides)
    yield()
    for _, slide in ipairs(slides) do
        yield(slide)
    end
end

function fg.newSlideIter()
    local slides
    if fg.slides and #fg.slides > 0 then
        slides = fg.slides
    else
        slides = _makebackupslides()
    end

    local co = coroutine.wrap(_slideiter)
    co(slides)
    return co
end




function string.wrap(str, limit, indent, indent1)
    limit = limit or 72
    local here = 1
    local wrapped = str:gsub("(%s+)()(%S+)()", function(sp, st, word, fi)
        if fi-here > limit then
            here = st
            return "\n"..word
        end
    end)
    local splitted = {}
    for token in string.gmatch(wrapped, "[^\n]+") do
        splitted[#splitted + 1] = token
    end
    return splitted
end



print("fg.lua loaded completely")
return fg
