local min, max = math.min, math.max


local E = {}
E.__index = E

local BOX = {}
BOX.__index = BOX


local function RelPosToScreen(x, y)
    return x * FAKEWIDTH, y * HEIGHT
end
local function RelSizeToScreen(sz)
    return sz * HEIGHT
end
local function ScreenPosToRel(x, y)
    return x / FAKEWIDTH, y / HEIGHT
end
local function ScreenSizeToRel(sz)
    return sz * HEIGHT
end

function BOX.new(x, y, w, h)
    local yborder = 0.01 * HEIGHT
    local xborder = 0.02 * HEIGHT -- intentionally HEIGHT, not a typo
    local self = { x-xborder, y-yborder, x+w+xborder, y+sz+yborder }
    return setmetatable(self, BOX)
end

function BOX:draw(col) -- abs. coords/size
    local bgtex = fg.getcolortex(bgcol)
    bgtex:draw(unpack(self))
end


-- an event-to-display is a timestamp with a title and subtitle
-- track is not handled here.

--[[
things added:
  .width -- total width in relative coords
  .height -- total height in relative coords
]]
local config =
{
    fontscale1 = 0.07, -- fontscale is in total screen height
    fontscale2 = 0.045,
    font = CONFIG.font,
}




-- returns w, h, colonOffset as relative sizes (center of colon = w + colonOffs)
local function layouttime(self, mul)
    local h, m = self.start:match("(%d+):(%d+)")
    local relscale = config.fontscale1 * mul
    local font, scale = config.font, RelSizeToScreen(relscale)
    local wh = font:width(h, scale)
    local wc = font:width(":", scale)
    local wm = font:width(m, scale)
    local offs = -wh - (wc * 0.5)
    self.tw, self.th = ScreenPosToRel(wh + wc + wm, scale)
    self.tco = offs / FAKEWIDTH
    self.tscale = relscale
end

local function layout(self, cfg)
    local mul = cfg.sizemult
    layouttime(self, mul)
end

-- final alignment step for all events generated for a single slide
-- align to relative screen size (w, h) (w == 0.9 means fill up to 90% of the screen width)
-- linewrapping must happen here
function E.Align(evs, w, h)
    local maxtw = 0
    local ybegin = 0
    for i, ev in ipairs(evs) do
        ev.height = ev.th
        maxtw = max(maxtw, ev.tw)
    end

    for i, ev in ipairs(evs) do
        ev.maxtw = maxtw
        ev.ybegin = ybegin
        ybegin = ybegin + ev.height
    end
end

function E.new(proto, cfg) -- proto is an event def from json
    local self = table.shallowcopy(proto)
    setmetatable(self, E)

    layout(self, cfg)
    return self
end

-- x is the position of the colon (eg. 20:00) in relative screen coords
-- this ensures that all colons are aligned
function E:drawts(fgcol, bgcol)
    local scale = RelSizeToScreen(self.tscale)
    local xstart, ystart = RelPosToScreen(self.tco, self.ybegin)
    config.font:write(xstart, ystart, self.start, scale, fgcol:rgba())

end

function E:draw(fgcol, bgcol)
    self:drawts(fgcol, bgcol)
end




print("slideevent.lua loaded completely")
return E, BOX
