-------------------------------------------------------------------------------
--- Constants (configuration)

local SLIDE_Y_BEGIN = 0.13
local SLIDE_TITLE_X_OFFSET = 0.15
local SLIDE_X_MAX = 0.9
local SLIDE_BODY_MINSPACE_TOP = 0.07
local SLIDE_BODY_MINSPACE_BOTTOM = 0.12

local SLIDE_TEXT_SIZE = 0.05
local SLIDE_TEXT_LINESPACING = 0
local SLIDE_TEXT_PADDING = 0.01
local SLIDE_SUBTITLE_RATIO = 1/1.5
local SLIDE_TOP_TITLE_RATIO = 1.7

local LOCAL_TITLE_SIZE = 0.09
local LOCAL_TIMEBAR_X_OFFSET = 0.115
local LOCAL_TIMEBAR_Y_BEGIN = SLIDE_Y_BEGIN + 0.02
local LOCAL_TIMEBAR_Y_END = 0.98
local LOCAL_TIMEBAR_WIDTH = 0.004
local LOCAL_TIMEBAR_TICK_HEIGHT = 0.012
local LOCAL_TIMEBAR_TICK_WIDTH = LOCAL_TIMEBAR_TICK_HEIGHT/DISPLAY_ASPECT
local LOCAL_TIMEBAR_TOP_TICK_RATIO = 1.42
local LOCAL_EVENT_TIME_X_OFFSET = 0.21
local LOCAL_EVENT_TEXT_X_OFFSET = 0.3

local REMOTE_TITLE_SIZE = 0.08
local REMOTE_SUB_TITLE_SIZE = 0.08
local REMOTE_EVENT_TIME_X_OFFSET = 0.21
local REMOTE_EVENT_TEXT_X_OFFSET = 0.28

local TOPIC_X_CENTER = 0.5
local TOPIC_Y_CENTER = 0.55
local TOPIC_MAX_W = 0.8
local TOPIC_MAX_H = 0.7

local SPONSOR_TITLE = "SPONSOR"
local SPONSOR_TITLE_SIZE = 0.1
local SPONSOR_X_CENTER = 0.5
local SPONSOR_Y_CENTER = 0.6
local SPONSOR_MAX_W = 0.8
local SPONSOR_MAX_H = 0.6

local EVENT_FORMAT_DEFAULT = {
    font = CONFIG.font,
    fontsize = SLIDE_TEXT_SIZE,
    linespacing = SLIDE_TEXT_LINESPACING,
    padding = SLIDE_TEXT_PADDING,

    fontSub = CONFIG.font,
    fontsizeSub = SLIDE_TEXT_SIZE * SLIDE_SUBTITLE_RATIO,
    linespacingSub = SLIDE_TEXT_LINESPACING * SLIDE_SUBTITLE_RATIO,
    paddingSub = SLIDE_TEXT_PADDING * SLIDE_SUBTITLE_RATIO,

    ymargin = 0.03,
}

local EVENT_FORMAT_LOCAL_TOP = {
    font = CONFIG.font_bold,
    fontsize = SLIDE_TEXT_SIZE * SLIDE_TOP_TITLE_RATIO,
    linespacing = SLIDE_TEXT_LINESPACING * SLIDE_TOP_TITLE_RATIO,
    padding = SLIDE_TEXT_PADDING * SLIDE_TOP_TITLE_RATIO,

    fontSub = CONFIG.font,
    fontsizeSub = SLIDE_TEXT_SIZE * SLIDE_TOP_TITLE_RATIO * SLIDE_SUBTITLE_RATIO,
    linespacingSub = SLIDE_TEXT_LINESPACING * SLIDE_TOP_TITLE_RATIO * SLIDE_SUBTITLE_RATIO,
    paddingSub = SLIDE_TEXT_PADDING * SLIDE_TOP_TITLE_RATIO * SLIDE_SUBTITLE_RATIO,

    ymargin = 0.035,
}

local THEME_TIMEBARS = {
    ["light"] = resource.load_image("timebar_black.png"),
    ["dark"] = resource.load_image("timebar_white.png"),
    ["custom"] = resource.load_image("timebar_custom.png")
}

local THEME_TIMEBAR_TICKS = {
    ["light"] = resource.load_image("timebar-tick_black.png"),
    ["dark"] = resource.load_image("timebar-tick_white.png"),
    ["custom"] = resource.load_image("timebar-tick_custom.png")
}


local NO_EVENT = {
    start = "4:04",
    title = "Event not found",
    subtitle = "There is currently no event to display.\nMove along.",
    -- title = "Event not found blah rofl lolo omg wtf long title right let's see where this goes or otherwise things might break",
    -- subtitle = "There is currently no event to display. Move along. There is currently no event to display. Move along. There is currently no event to display. Move along. There is currently no event to display. Move along. There is currently no event to display. Move along.",
}


-------------------------------------------------------------------------------
--- Classes

local SlideEvent = {}
util.file_watch("slideevent.lua", function(content)
    print("Reloading slideevent.lua...")
    x = assert(loadstring(content, "slideevent.lua"))()
    SlideEvent = x
    if _DEBUG_ then regenerateSlideDeck() end
end)

local Slide = {}
Slide.__index = Slide


-------------------------------------------------------------------------------
--- Helper Functions

local RED = resource.create_colored_texture(0.7, 0, 0, 1)
local GREEN = resource.create_colored_texture(0, 0.7, 0, 1)
local BLUE = resource.create_colored_texture(0, 0, 0.7, 1)
local function drawLineH(col, y)
    tools.drawResource(col, 0, y, 1, y+(1/DISPLAY_HEIGHT))
end

local function drawLineV(col, x)
    tools.drawResource(col, x, 0, x+(1/DISPLAY_WIDTH), 1)
end

local function drawGrid(type)
    drawLineH(BLUE, SLIDE_Y_BEGIN)
    drawLineV(BLUE, SLIDE_TITLE_X_OFFSET)

    if type == "topic" then
        drawLineV(RED, TOPIC_X_CENTER - TOPIC_MAX_W/2)
        drawLineV(RED, TOPIC_X_CENTER + TOPIC_MAX_W/2)
        drawLineH(RED, TOPIC_Y_CENTER - TOPIC_MAX_H/2)
        drawLineH(RED, TOPIC_Y_CENTER + TOPIC_MAX_H/2)

        drawLineV(GREEN, TOPIC_X_CENTER)
        drawLineH(GREEN, TOPIC_Y_CENTER)
    elseif type == "sponsor" then
        drawLineV(RED, SPONSOR_X_CENTER - SPONSOR_MAX_W/2)
        drawLineV(RED, SPONSOR_X_CENTER + SPONSOR_MAX_W/2)
        drawLineH(RED, SPONSOR_Y_CENTER - SPONSOR_MAX_H/2)
        drawLineH(RED, SPONSOR_Y_CENTER + SPONSOR_MAX_H/2)

        drawLineV(GREEN, SPONSOR_X_CENTER)
        drawLineH(GREEN, SPONSOR_Y_CENTER)
    elseif type == "local" then
        drawLineV(RED, SLIDE_X_MAX)
        drawLineH(RED, SLIDE_Y_BEGIN + LOCAL_TITLE_SIZE + SLIDE_BODY_MINSPACE_TOP)
        drawLineH(RED, 1-SLIDE_BODY_MINSPACE_BOTTOM)
        drawLineV(RED, LOCAL_TIMEBAR_X_OFFSET)
        drawLineV(RED, LOCAL_EVENT_TIME_X_OFFSET)
        drawLineV(RED, LOCAL_EVENT_TEXT_X_OFFSET)

        local bodyBegin = SLIDE_Y_BEGIN + LOCAL_TITLE_SIZE + SLIDE_BODY_MINSPACE_TOP
        drawLineH(GREEN, bodyBegin + (1 - bodyBegin - SLIDE_BODY_MINSPACE_BOTTOM) / 2)
    else
        drawLineV(RED, SLIDE_X_MAX)
        drawLineH(RED, SLIDE_Y_BEGIN + REMOTE_TITLE_SIZE + SLIDE_BODY_MINSPACE_TOP)
        drawLineH(RED, 1-SLIDE_BODY_MINSPACE_BOTTOM)
        drawLineV(RED, REMOTE_EVENT_TIME_X_OFFSET)
        drawLineV(RED, REMOTE_EVENT_TEXT_X_OFFSET)

        local bodyBegin = SLIDE_Y_BEGIN + LOCAL_TITLE_SIZE + SLIDE_BODY_MINSPACE_TOP
        drawLineH(GREEN, bodyBegin + (1 - bodyBegin - SLIDE_BODY_MINSPACE_BOTTOM) / 2)
    end
end

local function AddDrawCB(self, f)
    table.insert(self._drawCBs, f)
end

local function setupTitle(self)
    local font = CONFIG.font_bold
    local fontSub = CONFIG.font_italic
    local fgcol = (self.track and self.track.foreground_color) or CONFIG.foreground_color
    local bgcol = (self.track and self.track.background_color) or CONFIG.background_color

    local title
    local titlesize
    local subtitle = ""
    local subtitlesize = 0
    if self.type == "sponsor" then
        title = SPONSOR_TITLE
        titlesize = SPONSOR_TITLE_SIZE
    elseif self.type == "local" then
        title = (self.location and self.location.name) or device.getLocation().name
        titlesize = LOCAL_TITLE_SIZE
    else
        title = self.location.name
        titlesize = REMOTE_TITLE_SIZE
        subtitle = self.track.name
        subtitlesize = REMOTE_SUB_TITLE_SIZE
    end

    local subtitle_x
    local subtitle_y
    if subtitle ~= "" then
        subtitle_x = SLIDE_TITLE_X_OFFSET + tools.textWidth(font, title .. " ", titlesize)
        subtitle_y = SLIDE_Y_BEGIN + titlesize/2 - subtitlesize/2
    end

    AddDrawCB(self, function(slide)
        tools.drawText(font, SLIDE_TITLE_X_OFFSET, SLIDE_Y_BEGIN, title, titlesize, fgcol, bgcol, SLIDE_TEXT_PADDING)
        if subtitle ~= "" then
            tools.drawText(fontSub, subtitle_x, subtitle_y, subtitle, subtitlesize, fgcol, bgcol, SLIDE_TEXT_PADDING)
        end
    end)
end

local function setupTimebar(self)
    local timebar = THEME_TIMEBARS[CONFIG.theme]

    AddDrawCB(self, function(slide)
        local x = LOCAL_TIMEBAR_X_OFFSET
        local y1, y2 = LOCAL_TIMEBAR_Y_BEGIN, LOCAL_TIMEBAR_Y_END
        local w = LOCAL_TIMEBAR_WIDTH
        tools.drawResource(timebar, x-w/2, y1, x+w/2, y2)
    end)
end

local function setupEvents(self, events, getFormatConfig)
    local evs = {}
    for i, event in ipairs(events) do
        local cfg = assert(getFormatConfig(i))
        evs[i] = SlideEvent.new(event, cfg)
    end

    local y0 = SLIDE_Y_BEGIN
    local timex, textx
    if self.type == "local" then
        y0 = y0 + LOCAL_TITLE_SIZE
        timex, textx = LOCAL_EVENT_TIME_X_OFFSET, LOCAL_EVENT_TEXT_X_OFFSET
    else
        y0 = y0 + REMOTE_TITLE_SIZE
        timex, textx = REMOTE_EVENT_TIME_X_OFFSET, REMOTE_EVENT_TEXT_X_OFFSET
    end
    local maxH = 1 - y0 - SLIDE_BODY_MINSPACE_TOP - SLIDE_BODY_MINSPACE_BOTTOM
    local sumH, sumMargin = SlideEvent.Arrange(evs, SLIDE_X_MAX-textx, maxH)

    local expand = 1 + (maxH - sumH)/sumMargin
    expand = math.min(expand, 2)
    y0 = y0 + SLIDE_BODY_MINSPACE_TOP + (maxH - sumH - sumMargin * (expand-1))/2

    AddDrawCB(self, function(slide)
        local fgcol = (slide.track and slide.track.foreground_color) or CONFIG.foreground_color
        local bgcol = (slide.track and slide.track.background_color) or CONFIG.background_color
        local y = y0
        for _, ev in ipairs(evs) do
            fgcol = (ev.track and ev.track.foreground_color) or fgcol
            bgcol = (ev.track and ev.track.background_color) or bgcol
            ev:draw(timex, textx, y, fgcol, bgcol)
            y = y + ev.height + ev.ymargin * expand
        end
    end)

    if self.type == "local" then
        local x = LOCAL_TIMEBAR_X_OFFSET
        local timebarTick = THEME_TIMEBAR_TICKS[CONFIG.theme]
        AddDrawCB(self, function(slide)
            local y = y0
            for i, ev in ipairs(evs) do
                local dx = LOCAL_TIMEBAR_TICK_WIDTH
                local dy = LOCAL_TIMEBAR_TICK_HEIGHT
                if i == 1 then
                    dx = dx * LOCAL_TIMEBAR_TOP_TICK_RATIO
                    dy = dy * LOCAL_TIMEBAR_TOP_TICK_RATIO
                end
                local yt = y + (ev.fontsize*0.5)
                tools.drawResource(timebarTick, x-dx, yt-dy, x+dx, yt+dy)
                y = y + ev.height + ev.ymargin * expand
            end
        end)
    end
end

local function setupTopic(self)
    AddDrawCB(self, function(slide)
        local img = slide.image.ensure_loaded()
        local w, h = tools.ScreenPosToRel(img:size())
        local scale = math.min(TOPIC_MAX_W / w, TOPIC_MAX_H / h)
        w, h = w*scale, h*scale
        tools.drawResource(img, TOPIC_X_CENTER - w/2, TOPIC_Y_CENTER - h/2, TOPIC_X_CENTER + w/2, TOPIC_Y_CENTER + h/2)
    end)
end

local function setupSponsor(self)
    AddDrawCB(self, function(slide)
        local img = slide.image.ensure_loaded()
        local w, h = tools.ScreenPosToRel(img:size())
        local scale = math.min(SPONSOR_MAX_W / w, SPONSOR_MAX_H / h)
        w, h = w*scale, h*scale
        tools.drawResource(img, SPONSOR_X_CENTER - w/2, SPONSOR_Y_CENTER - h/2, SPONSOR_X_CENTER + w/2, SPONSOR_Y_CENTER + h/2)
    end)
end

local function formatLocal(i)
    if i == 1 then
        return EVENT_FORMAT_LOCAL_TOP
    else
        return EVENT_FORMAT_DEFAULT
    end

end

local function formatDefault(i)
    return EVENT_FORMAT_DEFAULT
end


local function layoutlocal(self)
    setupTitle(self)
    setupTimebar(self)
    setupEvents(self, self.events, formatLocal)
end

local function layoutremote(self)
    setupTitle(self)
    setupEvents(self, self.events, formatDefault)
end

local function layouttopic(self)
    setupTopic(self)
end

local function layoutsponsor(self)
    setupTitle(self)
    setupSponsor(self)
end

local layouts = {
    ["local"] = layoutlocal,
    ["remote"] = layoutremote,
    ["topic"] = layouttopic,
    ["sponsor"] = layoutsponsor,
}

local function commonInit(self)
    self._drawCBs = {}
    layouts[self.type](self)
    return self
end


-------------------------------------------------------------------------------
--- Constructors

function Slide.newLocal(location, events)
    local empty
    local time = CONFIG.slide_time_local
    if not events or #events == 0 then
        events = {NO_EVENT}
        empty = true
        time = CONFIG.slide_time_empty
    else
        assert(location)
    end
    local self = {
        here = true,
        location = location,
        events = assert(events),
        empty = empty,
        type = "local",
        time = time,
    }
    return setmetatable(commonInit(self), Slide)
end

function Slide.newRemote(track, location, events)
    local self = {
        track = assert(track),
        location = assert(location),
        events = assert(events),
        type = "remote",
        time = CONFIG.slide_time_remote,
    }
    return setmetatable(commonInit(self), Slide)
end

function Slide.newTopic(topic)
    assert(topic)
    local self = {
        image = topic,
        type = "topic",
        time = CONFIG.slide_time_topic,
    }
    return setmetatable(commonInit(self), Slide)
end

function Slide.newSponsor(sponsor)
    assert(sponsor)
    local self = {
        image = sponsor.image,
        type = "sponsor",
        time = CONFIG.slide_time_sponsor,
    }
    return setmetatable(commonInit(self), Slide)
end


-------------------------------------------------------------------------------
--- Member Functions

function Slide:draw()
    for _, cb in ipairs(self._drawCBs) do
        cb(self)
    end
    tools.debugDraw(6, drawGrid, self.type)
end


-------------------------------------------------------------------------------

print("slide.lua loaded completely")
return Slide
