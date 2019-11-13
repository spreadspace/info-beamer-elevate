local Slide = {}
util.file_watch("slide.lua", function(content)
    print("Reloading slide.lua...")
    x = assert(loadstring(content, "slide.lua"))()
    Slide = x
    rawset(_G, "Slide", x) -- remove this once slide generator is moved in here...
    if _DEBUG_ then regenerateSlideDeck() end
end)


local TimerQueue = require "timerqueue"


local function drawLogo(aspect)
    gl.pushMatrix()
        gl.scale(WIDTH, HEIGHT)
        local logosz = 0.23
        CONFIG.logo.ensure_loaded():draw(-0.01, 0.01, logosz/aspect, logosz)
    gl.popMatrix()
end

local function drawHeader(aspect)
    local font = CONFIG.font
    local fontbold = CONFIG.font_bold
    local fgcol = CONFIG.foreground_color
    local bgcol = CONFIG.background_color
    local hy = 0.05

    -- logo
    drawLogo(aspect)

    -- time
    local timesize = 0.08
    local timestr = fg.gettimestr()
    local timew = fontbold:width(timestr .. "     ", timesize*HEIGHT) / FAKEWIDTH
    local timex = 1.0 - timew
    tools.drawFont(fontbold, timex, hy, timestr, timesize, fgcol, bgcol)

    -- top title
    local titlesize = 0.06
    local titlestr = "ELEVATE INFOSCREEN"
    local titlex = 0.15
    tools.drawFont(font, titlex, hy, titlestr, titlesize, fgcol, bgcol)

    return FAKEWIDTH*titlex,  HEIGHT*(hy + titlesize + 0.02)
end



local SlideDeck = {}
SlideDeck.__index = SlideDeck


local function _slideiter(slides)
    coroutine.yield()
    n = #slides
    for i, slide in ipairs(slides) do
       tools.debugPrint(3, "showing slide " .. i .. " of " .. n)
       coroutine.yield(slide)
    end
end


function SlideDeck.new(schedule)
    tools.debugPrint(2, "generating new slide deck")
    local self = {
        tq = TimerQueue.new(),
        iter = nil,
        current = nil
    }
    setmetatable(self, SlideDeck)

    local slides = nil
    if schedule then
       slides = fg.scheduleToSlides(schedule)
    end
    if not slides or #slides == 0 then
       slides = {fg.makebackupslide()}
    end
    tools.debugPrint(2, "generated slide deck cotaining " .. #slides .. " slides")

    local it = coroutine.wrap(_slideiter)
    it(slides)
    self.iter = it
    self:next()
    return self
end

function SlideDeck:next()
    local it = self.iter
    self.current = it()
    if not self.current then
       tools.debugPrint(2, "slide deck reached the end")
       regenerateSlideDeck()
       return
    end

    local t = 1
    if self.current then
        t = self.current.time or t
    end

    -- schedule next slide
    self.tq:push(t, function() self:next() end)
end

function SlideDeck:update(dt)
    self.tq:update(dt)
end

function SlideDeck:draw(aspect)
    local hx, hy = drawHeader(aspect) -- returns where header ends
    self.current:draw(hx, hy)
end

print("slidedeck.lua loaded completely")
return SlideDeck
