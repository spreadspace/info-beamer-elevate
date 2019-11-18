-------------------------------------------------------------------------------
--- Classes

local SlideEvent = {}
SlideEvent.__index = SlideEvent


-------------------------------------------------------------------------------
--- Helper Functions

-- final alignment step for all events generated for a single slide
-- align to relative screen size (w, h) (w == 0.9 means fill up to 90% of the screen width)
-- linewrapping must happen here
function SlideEvent.Align(evs, w, h)
    local maxtw = 0
    local maxtend = 0
    local ybegin = 0
    local totalAvailW, totalAvailH = tools.RelPosToScreen(w, h)

    for i, ev in ipairs(evs) do
        maxtw = math.max(maxtw, ev.tw)
        maxtend = math.max(maxtend, ev.tw + math.abs(ev.tco))
        --ev.subtitle = "Suppress normal output; instead print the name of each input file from which no output would normally have been printed. The scanning will stop on the first match."
    end

    local absTimeW = tools.RelPosToScreen(maxtend)
    local textAvailW = totalAvailW - absTimeW

    for i, ev in ipairs(evs) do
        local sz = tools.RelSizeToScreen(ev.fontsize)
        local szSub = tools.RelSizeToScreen(ev.fontsizeSub)

        ev.maxtw = maxtw
        ev.textx = 0

        ev.titleparts = ev.title:fwrap(ev.font, sz, 0, textAvailW)
        local subh = 0
        if ev.subtitle and #ev.subtitle > 0 then
            ev.subtitleparts = ev.subtitle:fwrap(ev.fontSub, szSub, 0, textAvailW)
            subh = #ev.subtitleparts * (ev.fontsizeSub + ev.linespacingSub)
        end
        ev.heightNoPadding = #ev.titleparts * (ev.fontsize + ev.linespacing) + subh

        ev.height = ev.heightNoPadding  + ev.ypadding
        ev.maxwidth = w
        ev.maxheight = h
        ev.ybegin = ybegin
        ybegin = ybegin + ev.height

        -- remove events that don't fit
        local endY = ev.ybegin + ev.heightNoPadding - ev.linespacing
        if endY >= ev.maxheight then
            for k = i, #evs do
                evs[k] = nil
            end
            return
        end
    end
end

local function _layoutTime(self)
    local h, m = self.start:match("(%d+):(%d+)")
    if not h then h = '--' end
    if not m then m = '--' end
    local font, sz = self.font, tools.RelSizeToScreen(self.fontsize)

    local wh = font:width(h, sz)
    local wc = font:width(":", sz)
    local wm = font:width(m, sz)
    local offs = -wh - (wc * 0.5)
    self.tw = tools.ScreenPosToRel(wh + wc + wm)
    self.tco = tools.ScreenPosToRel(offs)
end


-------------------------------------------------------------------------------
--- Constructors

function SlideEvent.new(proto, cfg) -- proto is an event def from json
    local self = table.shallowcopy(proto)
    setmetatable(self, SlideEvent)

    self.font = assert(cfg.font)
    self.fontsize = assert(cfg.fontsize)
    self.linespacing = assert(cfg.linespacing)

    self.fontSub = assert(cfg.fontSub)
    self.fontsizeSub = assert(cfg.fontsizeSub)
    self.linespacingSub = assert(cfg.linespacingSub)

    self.ypadding = assert(cfg.ypadding)
    self.timexoffs = assert(cfg.timexoffs)
    self.titlexoffs = assert(cfg.titlexoffs)
    _layoutTime(self)
    return self
end


-------------------------------------------------------------------------------
--- Member Functions

function SlideEvent:draw(sx, sy, fgcol, bgcol)

    local timex = sx + self.tco + self.timexoffs
    local ty = sy + self.ybegin
    local textx = sx + self.maxtw + self.titlexoffs
    local lineh = self.fontsize + self.linespacing
    local linehSub = self.fontsizeSub + self.linespacingSub

    -- time text
    tools.drawFont(self.font, timex, ty, self.start, self.fontsize, fgcol, bgcol)

    -- title
    for _, s in ipairs(self.titleparts) do
        tools.drawFont(self.font, textx, ty, s, self.fontsize, fgcol, bgcol)
        ty = ty + lineh
    end

    -- subtitle
    if self.subtitleparts then
        for _, s in ipairs(self.subtitleparts) do
            tools.drawFont(self.fontSub, textx, ty, s, self.fontsizeSub, fgcol, bgcol)
            ty = ty + linehSub
        end
    end
end


-------------------------------------------------------------------------------

print("slideevent.lua loaded completely")
return SlideEvent
