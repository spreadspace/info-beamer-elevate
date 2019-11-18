local SlideEvent = {}
SlideEvent.__index = SlideEvent


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
            subh = #ev.subtitleparts * ev.fontsizeSub
        end
        ev.heightNoPadding = (ev.fontsize + ev.linespacing) * #ev.titleparts
            + subh

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


-- returns w, h, colonOffset as relative sizes (center of colon = w + colonOffs)
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

function SlideEvent.new(proto, cfg) -- proto is an event def from json
    local self = table.shallowcopy(proto)
    setmetatable(self, SlideEvent)

    self.font = assert(cfg.font)
    self.fontsize = assert(cfg.fontsize)
    self.fontSub = assert(cfg.fontSub)
    self.fontsizeSub = assert(cfg.fontsizeSub)
    self.linespacing = assert(cfg.linespacing)
    self.ypadding = assert(cfg.ypadding)
    self.timexoffs = assert(cfg.timexoffs)
    self.titlexoffs = assert(cfg.titlexoffs)
    _layoutTime(self)
    return self
end

-- this ensures that all colons are aligned
function SlideEvent:draw(fgcol, bgcol)

    local timex = self.tco + self.timexoffs
    local ty = self.ybegin
    local textx = self.maxtw + self.titlexoffs
    local relLineDist = self.linespacing + self.fontsize
    local relSubLineDist = self.fontsizeSub

    -- time text
    tools.drawFont(self.font, timex, ty, self.start, self.fontsize, fgcol, bgcol)

    -- title
    for _, s in ipairs(self.titleparts) do
        tools.drawFont(self.font, textx, ty, s, self.fontsize, fgcol, bgcol)
        ty = ty + relLineDist
    end

    -- subtitle
    if self.subtitleparts then
        for _, s in ipairs(self.subtitleparts) do
            tools.drawFont(self.fontSub, textx, ty, s, self.fontsizeSub, fgcol, bgcol)
            ty = ty + relSubLineDist
        end
    end
end


print("slideevent.lua loaded completely")
return SlideEvent
