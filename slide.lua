local SlideEvent = {}
util.file_watch("slideevent.lua", function(content)
    print("Reloading slideevent.lua...")
    x = assert(loadstring(content, "slideevent.lua"))()
    SlideEvent = x
    if _DEBUG_ then regenerateSlideDeck() end
end)




local Slide = {}
Slide.__index = Slide

-- constants
local NO_EVENT = {
    start = "404",
    title = "Event not found",
    subtitle = "There is currently no event to display.\nMove along.",
    -- title = "Event not found blah rofl lolo omg wtf long title right let's see where this goes or otherwise things might break",
    -- subtitle = "There is currently no event to display. Move along. There is currently no event to display. Move along. There is currently no event to display. Move along. There is currently no event to display. Move along. There is currently no event to display. Move along.",
}

local LOCAL_TITLE_SIZE = 0.1
local LOCAL_TIMEBAR_X_OFFSET = -0.034
local LOCAL_TIMEBAR_Y_BEGIN = 0.15
local LOCAL_TIMEBAR_Y_END = 0.98
local LOCAL_TIMEBAR_WIDTH = 0.006
local LOCAL_TIMEBAR_TICK_WITH = 0.018
local LOCAL_TIMEBAR_TICK_HEIGHT = LOCAL_TIMEBAR_WIDTH/DISPLAY_ASPECT

local REMOTE_TITLE_SIZE = 0.08

local SPONSOR_TITLE = "SPONSOR"
local SPONSOR_TITLE_SIZE = 0.1
local SPONSOR_X1 = 0.2
local SPONSOR_Y1 = 0.3
local SPONSOR_X2 = 0.8
local SPONSOR_Y2 = 0.9

local FORMAT_CFG_DEFAULT = {
    font = CONFIG.font,
    fontsize = 0.07,

    fontSub = CONFIG.font,
    fontsizeSub = 0.045,

    linespacing = 0.01,
    ypadding = 0.03,

    timexoffs = 0.05,
    titlexoffs = 0.02
}

local FORMAT_CFG_LOCAL_TOP = {
    font = CONFIG.font,
    fontsize = 0.091,

    fontSub = CONFIG.font,
    fontsizeSub = 0.059,

    linespacing = 0.01,
    ypadding = 0.03,

    timexoffs = 0.05,
    titlexoffs = 0.02
}



local function AddDrawRel(self, f)
    table.insert(self._drawrel, f)
end

local function AddDrawAbs(self, f)
    table.insert(self._drawabs, f)
end

local function setupTitle(self)
    local font = CONFIG.font_bold
    local fgcol = (self.track and self.track.foreground_color) or CONFIG.foreground_color
    local bgcol = (self.track and self.track.background_color) or CONFIG.background_color

    local title
    local titlesize
    if self.sponsor then
        title = SPONSOR_TITLE
        titlesize = SPONSOR_TITLE_SIZE
    elseif self.here then
        title = (self.location and self.location.name) or device.getLocation().name
        titlesize = LOCAL_TITLE_SIZE
    else
        title = ("%s / %s"):format(self.location.name, self.track.name)
        titlesize = REMOTE_TITLE_SIZE
    end

    -- TODO: this is ugly
    self.titleoffset = titlesize + 0.03

    AddDrawAbs(self, function(slide, sx, sy)
        tools.drawFont(font, sx, sy, title, titlesize, fgcol, bgcol)
    end)
end

local function setupTimebar(self)
    AddDrawAbs(self, function(slide, sx, sy)
        local x = sx + LOCAL_TIMEBAR_X_OFFSET
        local y1, y2 = LOCAL_TIMEBAR_Y_BEGIN, LOCAL_TIMEBAR_Y_END
        local w = LOCAL_TIMEBAR_WIDTH
        tools.drawResource(Resources.timebar, x-w/2, y1, x+w/2, y2)
    end)
end


local function setupEvents(self, protos, getconfig, ...)
    local evs = {}
    for i, p in ipairs(protos) do
        local cfg = assert(getconfig(i))
        evs[i] = SlideEvent.new(p, cfg, ...)
    end

    -- TODO: refactor alignment
    local SLIDE_SPACE_X = 0.845
    local SLIDE_SPACE_Y = 0.745
    SlideEvent.Align(evs, SLIDE_SPACE_X, SLIDE_SPACE_Y)

    AddDrawRel(self, function(...)
        local fgcol = (self.track and self.track.foreground_color) or CONFIG.foreground_color
        local bgcol = (self.track and self.track.background_color) or CONFIG.background_color
        for i, ev in ipairs(evs) do
            fgcol = (ev.track and ev.track.foreground_color) or fgcol
            bgcol = (ev.track and ev.track.background_color) or bgcol
            ev:draw(fgcol, bgcol)
        end
    end)

    -- draw ticks
    if self.type == "local" then
        AddDrawAbs(self, function(slide, sx, sy)
            local x = sx + LOCAL_TIMEBAR_X_OFFSET
            local y0 = sy + self.titleoffset
            local dx = LOCAL_TIMEBAR_TICK_WITH
            local dy = LOCAL_TIMEBAR_TICK_HEIGHT
            local fgcol = tools.getColorTex(CONFIG.foreground_color)
            for i, ev in ipairs(evs) do
                local y = y0 + ev.ybegin + (ev.fontsize*0.5)
                tools.drawResource(fgcol, x-dx, y-dy, x+dx, y+dy)
            end
        end)
    end
end

local function setupSponsor(self)
    AddDrawAbs(self, function()
        local img = self.image.ensure_loaded()
        tools.drawResource(img, SPONSOR_X1, SPONSOR_Y1, SPONSOR_X2, SPONSOR_Y2)
    end)
end


local function fLocal(i)
    if i == 1 then
        return FORMAT_CFG_LOCAL_TOP
    else
        return FORMAT_CFG_DEFAULT
    end

end
local function fDefault(i)
    return FORMAT_CFG_DEFAULT
end

local function layoutlocal(self)
    setupTitle(self)
    setupTimebar(self)
    setupEvents(self, self.events, fLocal)
end

local function layoutremote(self, sx, sy)
    setupTitle(self)
    setupEvents(self, self.events, fDefault)
end

local function layoutsponsor(self)
    setupTitle(self)
    setupSponsor(self)
end

local layouts =
{
    ["local"] = layoutlocal,
    remote = layoutremote,
    sponsor = layoutsponsor,
}

local function commonInit(self)
    self._drawabs = {}
    self._drawrel = {}
    layouts[self.type](self)
    return self
end

function Slide.newLocal(locdef, events)
    local empty
    local time = CONFIG.current_location
    if not events or #events == 0 then
        events = {NO_EVENT}
        empty = true
        time = 3 -- TODO: make this configurable?
    end
    local self = {
        here = true,
        location = locdef,
        events = assert(events),
        empty = empty,
        type = "local",
        time = time,
    }
    return setmetatable(commonInit(self), Slide)
end

function Slide.newRemote(trackdef, locdef, events)
    local self = {
        track = assert(trackdef),
        location = assert(locdef),
        events = assert(events),
        type = "remote",
        time = CONFIG.other_locations,
    }
    return setmetatable(commonInit(self), Slide)
end

function Slide.newSponsor(spon)
    local self = {
        image = spon.image,
        sponsor = spon,
        type = "sponsor",
        time = CONFIG.sponsor_slides,
    }
    return setmetatable(commonInit(self), Slide)
end

local DEBUG_BG = resource.create_colored_texture(0, 0.5, 1, 0.15)
local function drawDebugBG(x1, y1, x2, y2)
    tools.drawResource(DEBUG_BG, x1, y1, x2, y2)
end

function Slide:drawRel(...)
    for _, f in ipairs(self._drawrel) do
        f(self, ...)
    end
end

function Slide:drawAbs(...)
    for _, f in ipairs(self._drawabs) do
        f(self, ...)
    end
end

function Slide:draw(sx, sy)
    gl.pushMatrix()
        tools.debugDraw(5, drawDebugBG, sx, sy, 1, 1)
        self:drawAbs(sx, sy)
        sy = sy + self.titleoffset
        gl.translate(tools.RelPosToScreen(sx, sy))
        self:drawRel()
    gl.popMatrix()
end

print("slide.lua loaded completely")
return Slide
