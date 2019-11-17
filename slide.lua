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
    --title = "Event not found blah rofl lolo omg wtf long title right let's see where this goes or otherwise things might break",
    title = "Event not found",
    --subtitle = "There is currently no event to display. Move along. There is currently no event to display. Move along. There is currently no event to display. Move along. There is currently no event to display. Move along. There is currently no event to display. Move along.",
    subtitle = "There is currently no event to display.\nMove along.",
}

-- in relative [0..1] screen coords
local SPONSORS_TITLE = "SPONSORS"
-- TODO this values need to fixed for aspect ratio
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
        title = self.location.name
        titlesize = 0.1
    else
        title = ("%s / %s"):format(self.location.name, self.track.name)
        titlesize = 0.08
    end

    -- TODO: this not nice...
    self.titleoffset = titlesize + 0.03

    AddDrawAbs(self, function(slide, sx, sy)
        local x, y = tools.ScreenPosToRel(sx, sy)
        tools.drawFont(font, x, y, title, titlesize, fgcol, bgcol)
    end)
end

local function setupGradient(self)
    local beginy = 0.15 * DISPLAY_HEIGHT
    local thickness = 0.006 * DISPLAY_WIDTH

    AddDrawAbs(self, function(slide, sx, sy)
        local gx = sx - 0.035 * DISPLAY_WIDTH
        Resources.gradient:draw(gx - thickness/2, beginy, gx + thickness/2, DISPLAY_HEIGHT)
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
    local beginy = 0.15 * DISPLAY_HEIGHT

    if self.type == "local" then
        AddDrawAbs(self, function(slide, sx, sy)
            local HACK_FACTOR = 0.3 -- no time to explain
            local gx = sx - 0.035 * DISPLAY_WIDTH
            local fgcolor = CONFIG.foreground_color
            for i, ev in ipairs(evs) do
                ev:drawtick(fgcolor, sx-gx*HACK_FACTOR,sy+(self.titleoffset*DISPLAY_HEIGHT))
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
    tools.drawImage(img, SPONSORSLIDE_X, SPONSORSLIDE_Y, SPONSORSLIDE_W, SPONSORSLIDE_H)
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

function Slide.newLocal(id, locdef, events)
    local empty
    local time = CONFIG.current_location
    if not events or #events == 0 then
        events = {NO_EVENT}
        empty = true
        time = CONFIG.empty_slide_time or 3
    end
    local self = { id = id, here = true,
        location = assert(locdef),
        events = assert(events),
        empty = empty,
        type = "local",
        time = time,
    }
    return setmetatable(commonInit(self), Slide)
end

function Slide.newRemote(id, trackdef, locdef, events)
    local self = { id = id,
        track = assert(trackdef),
        location = assert(locdef),
        events = assert(events),
        type = "remote",
        time = CONFIG.other_locations,
    }
    return setmetatable(commonInit(self), Slide)
end

function Slide.newSponsor(id, spon)
    local self = { id = id,
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

local TESTBG = resource.create_colored_texture(0, 0.5, 1, 0.15)
local function drawTestBG()
    local x, y = tools.RelPosToScreen(SLIDE_SPACE_X, SLIDE_SPACE_Y)
    TESTBG:draw(0, 0, x, y)
end

function Slide:drawRel(...)
    tools.debugDraw(5, drawTestBG)

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
    -- start positions after header
    gl.pushMatrix()
        self:drawAbs(sx, sy)
        sy = sy + self.titleoffset*DISPLAY_HEIGHT
        gl.translate(sx, sy)
        self:drawRel()
    gl.popMatrix()
end

print("slide.lua loaded completely")
return Slide
