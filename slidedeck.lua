local Slide = {}
util.file_watch("slide.lua", function(content)
    print("Reloading slide.lua...")
    x = assert(loadstring(content, "slide.lua"))()
    Slide = x
    if _DEBUG_ then regenerateSlideDeck() end
end)


local TimerQueue = require "timerqueue"

-- FOR TESTING --
local SHOW_LOCAL_EVENTS = true
local SHOW_REMOTE_EVENTS = false
local SHOW_SPONSORS = false
local SHOW_EMPTY_WHEN_NO_LOCAL = true
-----------------
-- events on this location will be skipped in remote slides
local PSEUDO_LOCATION_ID = "emc"


-- returns nil when event is not to be shown
local function _sanitizeEvent(ev, ts, locid)
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

local function _orderEvent(a, b)
    return a.prio > b.prio or (a.prio == b.prio and a.startts < b.startts)
end

local function _generateEmptyLocalSlide()
    tools.debugPrint(3, "Generating Empty slide")
    return Slide.newLocal(nil, false)
end

local function _generateLocalSlide(slides, localEvents, here)
    local hasLocal
    if SHOW_LOCAL_EVENTS and here then
        tools.debugPrint(3, "generating local slide: location[" .. here.id .. "] = " .. #localEvents .. " events")
        table.sort(localEvents, _orderEvent)
        local slide = Slide.newLocal(here, localEvents)
        table.insert(slides, slide)
        hasLocal = true
    end

    if (not hasLocal and SHOW_EMPTY_WHEN_NO_LOCAL) then
        table.insert(slides, _generateEmptyLocalSlide())
    end
end

local function _generateRemoteSlides(slides, events, tracks, locations)
    if not SHOW_REMOTE_EVENTS then return end

    for _, track in ipairs(tracks) do
        for _, location in ipairs(locations) do
            local tlevs = events[track.id][location.id]
            if tlevs and #tlevs > 0 and not (location.id == PSEUDO_LOCATION_ID) then
                table.sort(tlevs, _orderEvent)
                tools.debugPrint(3, "generating remote slide: track[" .. track.id .. "] location[" .. location.id .. "] = " .. #tlevs .. " events")
                local slide = Slide.newRemote(track, location, tlevs)
                table.insert(slides, slide)
            end
        end
    end
end

local function _generateSponsorSlides(slides)
    if not SHOW_SPONSORS or not CONFIG.sponsors then return end

    -- TODO: implemnt sponsor skip counter!
    for _, sponsor in ipairs(CONFIG.sponsors) do
        tools.debugPrint(3, "generating sponsor slides: " .. sponsor.image.filename)
        local slide = Slide.newSponsor(sponsor)
        table.insert(slides, slide)
    end
end

local function _scheduleToSlides(schedule)
    local slides = {}
    local localEvents = {}
    local ts = math.floor(device.getTime())
    local here = device.getLocation()

    local tracks = assert(CONFIG.tracks, "CONFIG.tracks missing")
    local lutTracks = tools.createLookupTable(tracks)
    local locations = assert(CONFIG.locations, "CONFIG.locations missing")

    local nEvents = 0
    local events = tools.newAutoExtendTable() -- "track1" => { "locA" => events..., "locB" => events... }
    for _, location in ipairs(locations) do
        local levs = schedule[location.id]
        local isHere = (here.id == location.id)
        if levs then
            for _, lev in pairs(levs) do
                local event = _sanitizeEvent(lev, ts, location.id)
                if event then
                    if isHere then
                        table.insert(localEvents, event)
                    end
                    local trackName = event.track
                    if lutTracks[trackName] then
                        event.track = lutTracks[trackName]
                        tools.debugPrint(4, "track[" .. trackName .. "] location[" .. location.id .. "] = " .. tostring(event.title))
                        table.insert(events[trackName][location.id], event)
                    else
                        event.track = nil
                        tools.debugPrint(1, "WARNING: Unknown track [" .. tostring(trackName) .. "] for event " .. tostring(event.title))
                    end
                    nEvents = nEvents + 1
                end
            end
        else
            tools.debugPrint(3, "..skipping location[" .. location.id .. "] (no upcoming events)")
        end
    end
    tools.debugPrint(2, "found " .. nEvents .. " events, generating slides...")

    _generateLocalSlide(slides, localEvents, here)
    _generateRemoteSlides(slides, events, tracks, locations)
    _generateSponsorSlides(slides)
    tools.debugPrint(2, "generated " .. #slides .. " slides")
    return slides
end



local SlideDeck = {}
SlideDeck.__index = SlideDeck

local function _drawHeader()
    local logo = CONFIG.logo.ensure_loaded()
    local font = CONFIG.font
    local fontbold = CONFIG.font_bold
    local fgcol = CONFIG.foreground_color
    local bgcol = CONFIG.background_color
    local hy = 0.05

    -- logo
    local logosize = 0.23 -- the logo texture is square
    tools.drawResource(logo, -0.01, 0.01, logosize/DISPLAY_ASPECT, logosize)

    -- time
    local timesize = 0.08
    local timestr = device.getTimeString()
    local timew = tools.ScreenPosToRel(fontbold:width(timestr, tools.RelSizeToScreen(timesize)))
    local timex = 0.95 - timew
    tools.drawFont(fontbold, timex, hy, timestr, timesize, fgcol, bgcol)

    -- top title
    local titlesize = 0.06
    local titlestr = "ELEVATE INFOSCREEN"
    local titlex = 0.15
    tools.drawFont(font, titlex, hy, titlestr, titlesize, fgcol, bgcol)

    return titlex, hy + titlesize + 0.02
end

local function _slideiter(slides)
    coroutine.yield()
    n = #slides
    for i, slide in ipairs(slides) do
       tools.debugPrint(3, "showing slide " .. i .. " of " .. n)
       coroutine.yield(slide)
    end
end


function SlideDeck.new(schedule)
    tools.debugPrint(2, "generating new slide deck")
    local self = {
        tq = TimerQueue.new(),
        iter = nil,
        current = nil
    }
    setmetatable(self, SlideDeck)

    local slides = nil
    if schedule then
       slides = _scheduleToSlides(schedule)
    end
    if not slides or #slides == 0 then
       slides = {_generateEmptyLocalSlide()}
    end

    local it = coroutine.wrap(_slideiter)
    it(slides)
    self.iter = it
    self:next()
    return self
end

function SlideDeck:next()
    local it = self.iter
    self.current = it()
    if not self.current then
       tools.debugPrint(2, "slide deck reached the end")
       regenerateSlideDeck()
       return
    end

    local t = 1
    if self.current then
        t = self.current.time or t
    end

    -- schedule next slide
    self.tq:push(t, function() self:next() end)
end

function SlideDeck:update(dt)
    self.tq:update(dt)
end

function SlideDeck:draw()
    gl.ortho()
    tools.fixAspect()
    local hx, hy = _drawHeader() -- returns where header ends
    self.current:draw(hx, hy)
end

print("slidedeck.lua loaded completely")
return SlideDeck
