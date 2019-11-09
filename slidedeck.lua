local Slide = {}
util.file_watch("slide.lua", function(content)
    print("Reloading slide.lua...")
    x = assert(loadstring(content, "slide.lua"))()
    Slide = x
    rawset(_G, "Slide", x) -- remove this once slide generator is moved in here...
    if _DEBUG_ then regenerateSlideDeck() end
end)


local TOP_TITLE = "ELEVATE INFOSCREEN"
local SPONSORS_TITLE = "SPONSORS"

local TimerQueue = require "timerqueue"

local function drawlogo(aspect)
    gl.pushMatrix()
        gl.scale(WIDTH, HEIGHT)
        local logosz = 0.23
        CONFIG.logo.ensure_loaded():draw(-0.01, 0.01, logosz/aspect, logosz)
    gl.popMatrix()
end


local function drawheader(slide)
    local font = CONFIG.font
    local fontbold = CONFIG.font_bold
    local fgcol = (slide.track and slide.track.foreground_color) or CONFIG.foreground_color
    local bgcol = (slide.track and slide.track.background_color) or CONFIG.background_color
    local hy = 0.05

    local timesize = 0.08
    local timestr = fg.gettimestr()
    local timew = fontbold:width(timestr .. "     ", timesize*HEIGHT) / FAKEWIDTH
    local timex = 1.0 - timew

    -- time
    tools.drawFont(fontbold, timex, hy, timestr, timesize, fgcol, bgcol)

    local xpos = 0.15
    local titlesize = 0.06
    tools.drawFont(font, xpos, hy, TOP_TITLE, titlesize, fgcol, bgcol)

    hy = hy + titlesize + 0.02


    local wheresize
    if slide then
        local font = CONFIG.font_bold
        local where
        local fgcol2 = CONFIG.foreground_color
        local bgcol2 = CONFIG.background_color
        if slide.sponsor then
            where = SPONSORS_TITLE
            wheresize = 0.1
        elseif slide.here then
            where = slide.location.name
            wheresize = 0.1
        else
            where = ("%s / %s"):format(slide.location.name, slide.track.name)
            wheresize = 0.08
            fgcol2 = fgcol
            bgcol2 = bgcol
        end
        tools.drawFont(font, xpos, hy, where, wheresize, fgcol2, bgcol2)
    end

    return FAKEWIDTH*xpos, hy + wheresize + HEIGHT*0.25
end

local function drawslide(slide, sx, sy)
    -- start positions after header
    gl.pushMatrix()
        slide:drawAbs(sx, sy)
        gl.translate(sx, sy)
        slide:drawRel()
    gl.popMatrix()
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
    drawlogo(aspect)
    local hx, hy = drawheader(self.current) -- returns where header ends
    drawslide(self.current, hx, hy)
end

print("slidedeck.lua loaded completely")
return SlideDeck
