local SlideEvent = {}
util.file_watch("slideevent.lua", function(content)
    print("Reloading slideevent.lua...")
    x = assert(loadstring(content, "slideevent.lua"))()
    SlideEvent = x
    if _DEBUG_ then regenerateSlideDeck() end
end)




local Slide = {}
Slide.__index = Slide

local NO_EVENT = {
    start = "404",
    title = "Event not found",
    subtitle = "There is currently no event to display.\nMove along.",

    -- title = "Event not found blah rofl lolo omg wtf long title right let's see where this goes or otherwise things might break",
    -- subtitle = "There is currently no event to display. Move along. There is currently no event to display. Move along. There is currently no event to display. Move along. There is currently no event to display. Move along. There is currently no event to display. Move along.",
}

local SPONSORS_TITLE = "SPONSORS"
-- in relative [0..1] screen coords
local SPONSORSLIDE_X = 0.2
local SPONSORSLIDE_Y = 0.3
local SPONSORSLIDE_W = 0.8
local SPONSORSLIDE_H = 0.9

local SLIDE_SPACE_X = 0.845
local SLIDE_SPACE_Y = 0.745

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
        title = SPONSORS_TITLE
        titlesize = 0.1
    elseif self.here then
        title = (self.location and self.location.name) or device.getLocation().name
        titlesize = 0.1
    else
        title = ("%s / %s"):format(self.location.name, self.track.name)
        titlesize = 0.08
    end

    -- TODO: this not nice...
    self.titleoffset = titlesize + 0.03

    AddDrawAbs(self, function(slide, sx, sy)
        tools.drawFont(font, sx, sy, title, titlesize, fgcol, bgcol)
    end)
end

local function setupGradient(self)
    local beginy = 0.15
    local thickness = 0.006

    AddDrawAbs(self, function(slide, sx, sy)
        local gx = sx - 0.035
        tools.drawResource(Resources.gradient, gx - thickness/2, beginy, gx + thickness/2, 1)
    end)
end


local function setupEvents(self, protos, getconfig, ...)
    local evs = {}
    for i, p in ipairs(protos) do
        local cfg = assert(getconfig(i))
        evs[i] = SlideEvent.new(p, cfg, ...)
    end
    SlideEvent.Align(evs, SLIDE_SPACE_X, SLIDE_SPACE_Y) -- FIXME: proper screen size?
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
            local gx = sx - 0.035
            local fgcol = CONFIG.foreground_color
            for i, ev in ipairs(evs) do
                ev:drawtick(fgcol, gx, sy+self.titleoffset)
            end
        end)
    end
end

-- TODO: for layouting, pass remaining space
-- use functions to:
---- draw BEFORE translating space
---- draw AFTER translating space

local cfgDefault = { sizemult = 1, linespacing = 0.01, ypadding = 0.03, timexoffs = 0.05, titlexoffs = 0.02, }
local cfgLocalTop = { sizemult = 1.3, linespacing = 0.01, ypadding = 0.03, timexoffs = 0.05, titlexoffs = 0.02, }
local function fLocal(i)
    if i == 1 then
        return cfgLocalTop
    else
        return cfgDefault
    end
end
local function fDefault(i)
    return cfgDefault
end


local function layoutlocal(self)
    setupGradient(self)
    setupTitle(self)
    setupEvents(self, self.events, fLocal)
end

local function layoutremote(self, sx, sy)
    setupTitle(self)
    setupEvents(self, self.events, fDefault)
end



local function _drawsponsor(self)
    local img = self.image.ensure_loaded()
    tools.drawResource(img, SPONSORSLIDE_X, SPONSORSLIDE_Y, SPONSORSLIDE_W, SPONSORSLIDE_H)
end

local function layoutsponsor(self)
    setupTitle(self)
    AddDrawAbs(self, _drawsponsor)
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
        --abspos = true, -- don't translate before drawing content
    }
    return setmetatable(commonInit(self), Slide)
end

-- local function printevent(ev)
--     print(("[%s] %s - %s: %s [%s]")
--         :format(tostring(ev.status), tostring(ev.start), tostring(ev["end"]),
--                 tostring(ev.title), tostring(ev.track))
--     )
-- end
-- function Slide:print()
--     print("  ** [SLIDE] **")
--     print(" - Location: ", self.location.name, "[" .. tostring(self.location.id) .. "]")
--     print(" - Events (" .. #self.events .. " shown):")
--     for i, ev in ipairs(self.events) do
--         printevent(ev)
--     end
-- end

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
