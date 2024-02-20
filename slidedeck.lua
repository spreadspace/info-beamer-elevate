-------------------------------------------------------------------------------
--- Constants (configuration)

local HEADER_Y_BEGIN = 0.07

local HEADER_TEXT_PADDING = 0.01

local HEADER_LOGO_X = 0.007
local HEADER_LOGO_Y = 0.04
local HEADER_LOGO_H = 0.18
local HEADER_LOGO_W = HEADER_LOGO_H/DISPLAY_ASPECT  -- the logo texture is square

local HEADER_TIME_SIZE = 0.05
local HEADER_TIME_CENTER_X = 0.89

local HEADER_TITLE_SIZE = 0.05
local HEADER_TITLE_TEXT = "ELEVATE INFOSCREEN"
local HEADER_TITLE_X = 0.15

local THEME_LOGOS = {
    ["light"] = resource.load_image("logo_black.png"),
    ["dark"] = resource.load_image("logo_white.png"),
    ["custom"] = resource.load_image("logo_custom.png")
}

-- FOR TESTING --
local SHOW_LOCAL_EVENTS = true
local SHOW_REMOTE_EVENTS = true
local SHOW_SPONSORS = true
local SHOW_EMPTY_WHEN_NO_LOCAL = false
-----------------
-- events on this location will be skipped in remote slides
local PSEUDO_LOCATION_ID = "emc"


-------------------------------------------------------------------------------
--- Classes

local Slide = {}
util.file_watch("slide.lua", function(content)
    print("Reloading slide.lua...")
    x = assert(loadstring(content, "slide.lua"))()
    Slide = x
    if _DEBUG_ then regenerateSlideDeck() end
end)

local SlideDeck = {}
SlideDeck.__index = SlideDeck


-------------------------------------------------------------------------------
--- Helper Functions

-- returns nil when event is not to be shown
local function _sanitizeEvent(ev, ts)
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
        evc.startts = tonumber(evc.startts)
        evc.endts = tonumber(evc.endts)
        return evc
    end
end

local function _orderEvent(a, b)
    return a.prio > b.prio or (a.prio == b.prio and a.startts < b.startts)
end

local function _generateEmptyLocalSlide()
    tools.debugPrint(3, "generating empty local slide")
    return Slide.newLocal(nil, false)
end

local function _generateLocalSlide(slides, localEvents, here)
    if SHOW_LOCAL_EVENTS and here then
        tools.debugPrint(3, "generating local slide: location[" .. here.id .. "] = " .. #localEvents .. " events")
        table.sort(localEvents, _orderEvent)
        local slide = Slide.newLocal(here, localEvents)
        table.insert(slides, slide)
        return
    end

    if SHOW_EMPTY_WHEN_NO_LOCAL then
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

local function _generateSponsorSlides(slides, iteration)
    if not SHOW_SPONSORS or not CONFIG.sponsors then return end

    if iteration % (CONFIG.slide_sponsor_skip + 1) > 0 then
        tools.debugPrint(3, "..skipping sponsor slides for iteration " .. iteration)
        return
    end

    for _, sponsor in ipairs(CONFIG.sponsors) do
        if tools.isScheduleActive(sponsor.schedule) then
            tools.debugPrint(3, "generating sponsor slide: " .. sponsor.image.filename)
            local slide = Slide.newSponsor(sponsor)
            table.insert(slides, slide)
        else
            tools.debugPrint(3, "..skipping currently inactive sponsor slide: " .. sponsor.image.filename)
        end
    end
end

local function _scheduleToSlides(schedule, iteration)
    local slides = {}
    local localEvents = {}
    local ts = math.floor(device.getWallClockTime())
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
                local event = _sanitizeEvent(lev, ts)
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
    _generateSponsorSlides(slides, iteration)
    tools.debugPrint(2, "generated " .. #slides .. " slides")
    return slides
end

local function setupHeader(self)
    local logo = THEME_LOGOS[CONFIG.theme]

    local font = CONFIG.font
    local fontbold = CONFIG.font_bold
    local fgcol = CONFIG.foreground_color
    local bgcol = CONFIG.background_color

    self.drawHeader = function()
        local logox, logoy = HEADER_LOGO_X, HEADER_LOGO_Y
        local logoh, logow = HEADER_LOGO_H, HEADER_LOGO_W

        local timesize = HEADER_TIME_SIZE
        local timestr = device.getWallClockTimeString()
        local timeco = tools.timeColonOffset(font, timestr, timesize)
        local timex, timey = HEADER_TIME_CENTER_X - timeco, HEADER_Y_BEGIN
        local timepadding = HEADER_TEXT_PADDING

        local titlesize = HEADER_TITLE_SIZE
        local titlestr = HEADER_TITLE_TEXT
        local titlex, titley = HEADER_TITLE_X, HEADER_Y_BEGIN
        local titlepadding = HEADER_TEXT_PADDING

        tools.drawResource(logo, logox, logoy, logox+logow, logoy+logoh)
        tools.drawText(font, timex, timey, timestr, timesize, fgcol, bgcol, timepadding)
        tools.drawText(font, titlex, titley, titlestr, titlesize, fgcol, bgcol, titlepadding)
    end
end

local function _slideiter(slides)
    coroutine.yield()
    local n = #slides
    for i, slide in ipairs(slides) do
       tools.debugPrint(3, "showing slide " .. i .. " of " .. n)
       coroutine.yield(slide)
    end
end


-------------------------------------------------------------------------------
--- Constructor

local TimerQueue = require "timerqueue"

function SlideDeck.new(schedule, iteration)
    tools.debugPrint(2, "generating new slide deck (iteration " .. iteration .. ")")
    local self = {
        tq = TimerQueue.new(),
        iter = nil,
        current = nil
    }
    setmetatable(self, SlideDeck)
    setupHeader(self)

    local slides
    if schedule then
       slides = _scheduleToSlides(schedule, iteration)
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


-------------------------------------------------------------------------------
--- Member Functions

function SlideDeck:next()
    local it = self.iter
    self.current = it()
    if not self.current then
       tools.debugPrint(2, "slide deck reached the end")
       regenerateSlideDeck()
       return
    end

    -- schedule next slide
    local t = self.current.time or 1
    self.tq:push(t, function() self:next() end)
end

function SlideDeck:update(dt)
    self.tq:update(dt)
end

function SlideDeck:draw()
    gl.ortho()
    tools.fixAspect()
    self.drawHeader()
    self.current:draw()
end


-------------------------------------------------------------------------------

print("slidedeck.lua loaded completely")
return SlideDeck
