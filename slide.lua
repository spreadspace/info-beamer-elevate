local SlideEvent = {}
util.file_watch("slideevent.lua", function(content)
    print("Reloading slideevent.lua...")
    x = assert(loadstring(content, "slideevent.lua"))()
    SlideEvent = x
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
local SPONSORSLIDE_START_X = 0.2
local SPONSORSLIDE_END_X = 0.8
local SPONSORSLIDE_START_Y = 0.3
local SPONSORSLIDE_END_Y = 0.9

local SLIDE_SPACE_X = 0.845
local SLIDE_SPACE_Y = 0.745

local function AddDrawRel(self, f)
    table.insert(self._drawrel, f)
end

local function AddDrawAbs(self, f)
    table.insert(self._drawabs, f)
end


local function setupGradient(self)
    local beginy = 0.15 * HEIGHT
    local thickness = WIDTH*0.006

    AddDrawAbs(self, function(slide, sx, sy)
        local gx = sx - 0.035 * FAKEWIDTH
        RES.gradient:draw(gx - thickness/2, beginy, gx + thickness/2, HEIGHT)
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
        local fgcolor = CONFIG.foreground_color
        local bgcolor = CONFIG.background_color
        for i, ev in ipairs(evs) do
            ev:draw(fgcolor, bgcolor)
        end
    end)

    -- draw ticks
    local beginy = 0.15 * HEIGHT

    if self.type == "local" then
        AddDrawAbs(self, function(slide, sx, sy)
            local HACK_FACTOR = 0.3 -- no time to explain
            local gx = sx - 0.035 * FAKEWIDTH
            local fgcolor = CONFIG.foreground_color
            for i, ev in ipairs(evs) do
                ev:drawtick(fgcolor, sx-gx*HACK_FACTOR,sy)
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
    setupEvents(self, self.events, fLocal)
end

local function layoutremote(self, sx, sy)
    setupEvents(self, self.events, fDefault)
end



local function _drawsponsor(self)
    gl.scale(FAKEWIDTH, HEIGHT)
    local img = self.image.ensure_loaded()
    img:draw(SPONSORSLIDE_START_X, SPONSORSLIDE_START_Y, SPONSORSLIDE_END_X, SPONSORSLIDE_END_Y)
end

local function layoutsponsor(self)
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

function Slide:drawRel(...)
    if _DEBUG_ >= 5 then
        TESTBG:draw(0,0, FAKEWIDTH * SLIDE_SPACE_X, HEIGHT * SLIDE_SPACE_Y)
    end

    for _, f in ipairs(self._drawrel) do
        f(self, ...)
    end
end

function Slide:drawAbs(...)
    for _, f in ipairs(self._drawabs) do
        f(self, ...)
    end
end

print("slide.lua loaded completely")
return Slide
