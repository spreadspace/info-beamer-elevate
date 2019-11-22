-------------------------------------------------------------------------------
--- Classes

local SlideEvent = {}
SlideEvent.__index = SlideEvent


-------------------------------------------------------------------------------
--- Helper Functions

-- linewrapping must happen here
function SlideEvent.Arrange(evs, textW, maxH)
    local sumH = 0
    local sumPadding = 0
    local lastPadding = 0
    for i, ev in ipairs(evs) do
        ev.titleparts = ev.title:fwrap(ev.font, ev.fontsize, textW)
        local subh = 0
        if ev.subtitle and #ev.subtitle > 0 then
            ev.subtitleparts = ev.subtitle:fwrap(ev.fontSub, ev.fontsizeSub, textW)
            subh = #ev.subtitleparts * (ev.fontsizeSub + ev.linespacingSub) - ev.linespacingSub
        end
        ev.height = #ev.titleparts * (ev.fontsize + ev.linespacing) - ev.linespacing + subh

        if (sumH + ev.height) >= maxH then
            for k = i, #evs do
                evs[k] = nil
            end
            break
        end
        sumH = sumH + ev.height + ev.ypadding
        sumPadding = sumPadding + ev.ypadding
        lastPadding = ev.ypadding
    end

    return sumH - lastPadding, sumPadding - lastPadding
end

local function _calcTimeCenterOffset(self)
    local h, m = self.start:match("(%d+):(%d+)")
    if not h then h = '--' end
    if not m then m = '--' end

    local font, sz = self.font, self.fontsize
    local wh = tools.textWidth(font, h, sz)
    local wc = tools.textWidth(font, ":", sz)
    -- local wm = tools.textWidth(font, m, sz)
    self.timeco = - wh - (wc * 0.5)
end


-------------------------------------------------------------------------------
--- Constructor

function SlideEvent.new(proto, cfg) -- proto is an event def from json
    local self = table.shallowcopy(proto)
    setmetatable(self, SlideEvent)

    self.font = assert(cfg.font)
    self.fontsize = assert(cfg.fontsize)
    self.linespacing = assert(cfg.linespacing)
    self.border = cfg.border -- allow this to be nil

    self.fontSub = assert(cfg.fontSub)
    self.fontsizeSub = assert(cfg.fontsizeSub)
    self.linespacingSub = assert(cfg.linespacingSub)
    self.borderSub = cfg.borderSub -- allow this to be nil

    self.ypadding = assert(cfg.ypadding)
    _calcTimeCenterOffset(self)
    return self
end


-------------------------------------------------------------------------------
--- Member Functions

-- timecx means center of time, textx means start of text
function SlideEvent:draw(timecx, textx, y, fgcol, bgcol)
    local timex = timecx + self.timeco
    local lineh = self.fontsize + self.linespacing
    local linehSub = self.fontsizeSub + self.linespacingSub

    -- fix ugly gap between time and title borders
    if bgcol and bgcol.a > 0 and self.border then
        local bgtex = tools.getColorTex(bgcol)
        local titlew = tools.textWidth(self.font, self.titleparts[1], self.fontsize)
        tools.drawResource(bgtex, timex - self.border, y - self.border, textx + titlew + self.border, y + self.fontsize + self.border)
    end

    -- time text
    tools.drawText(self.font, timex, y, self.start, self.fontsize, fgcol)

    -- title
    local b = nil
    for idx, part in ipairs(self.titleparts) do
        if idx > 1 then b = self.border end
        tools.drawText(self.font, textx, y, part, self.fontsize, fgcol, bgcol, b)
        y = y + lineh
    end

    -- subtitle
    if self.subtitleparts then
        for _, part in ipairs(self.subtitleparts) do
            tools.drawText(self.fontSub, textx, y, part, self.fontsizeSub, fgcol, bgcol, self.borderSub)
            y = y + linehSub
        end
    end
end


-------------------------------------------------------------------------------

print("slideevent.lua loaded completely")
return SlideEvent
