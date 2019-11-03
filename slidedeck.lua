local Slide = {}
util.file_watch("slide.lua", function(content)
    print("Reloading slide.lua...")
    x = assert(loadstring(content, "slide.lua"))()
    Slide = x
    rawset(_G, "Slide", x) -- remove this once slide generator is moved in here...
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

-- takes x, y, sz in resolution-independent coords
-- (0, 0) = upper left corner, (1, 1) = lower right corner
-- sz == 0.5 -> half as high as the screen
local function drawfont(font, x, y, text, sz, fgcol, bgcol)
    local xx = x * FAKEWIDTH
    local yy = y * HEIGHT
    local zz = sz * HEIGHT
    local yborder = 0.01 * HEIGHT
    local xborder = 0.02 * HEIGHT -- intentionally HEIGHT, not a typo
    local w = font:write(xx, yy, text, zz, fgcol:rgba())
    local bgtex = tools.getColorTex(bgcol)
    bgtex:draw(xx-xborder, yy-yborder, xx+w+xborder, yy+zz+yborder)
    font:write(xx, yy, text, zz, fgcol:rgba())
    return xx, yy+zz, w
end

local function drawheader(slide) -- slide possibly nil (unlikely)
    local font = CONFIG.font
    local fontbold = CONFIG.font_bold
    local fgcol = CONFIG.foreground_color
    local bgcol = CONFIG.background_color
    local hy = 0.05

    local timesize = 0.08
    local timestr = fg.gettimestr()
    local timew = fontbold:width(timestr .. "     ", timesize*HEIGHT) / FAKEWIDTH
    local timex = 1.0 - timew

    -- time
    drawfont(fontbold, timex, hy, timestr, timesize, fgcol, bgcol)

    local xpos = 0.15
    local titlesize = 0.06
    drawfont(font, xpos, hy, TOP_TITLE, titlesize, fgcol, bgcol)

    hy = hy + titlesize + 0.02


    local wheresize
    if slide then
        local font = CONFIG.font_bold
        local where
        local fgcol2 = fgcol
        local bgcol2 = bgcol
        if slide.sponsor then
            where = SPONSORS_TITLE
            wheresize = 0.1

        elseif slide.here then
            where = slide.location.name
            wheresize = 0.1
        else
            wheresize = 0.08
            where = ("%s / %s"):format(slide.location.name, slide.track.name)
            fgcol2 = slide.track.foreground_color
            bgcol2 = slide.track.background_color
        end
        drawfont(font, xpos, hy, where, wheresize, fgcol2, bgcol2)
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


function SlideDeck.new()
    local self = {
        last_schedule = nil,
        slides = nil,

        current = nil,
        iter = nil,
        tq = TimerQueue.new()
    }
    return setmetatable(self, SlideDeck)
end


function SlideDeck:updateSchedule(schedule)
    self.last_schedule = schedule
    local locations = assert(CONFIG.locations, "CONFIG.locations missing")
    local tracks = assert(CONFIG.tracks, "CONFIG.tracks missing")
    local slides = fg.scheduleToSlides(locations, tracks, schedule)
    self.slides = slides
end


local function _slideiter(slides)
    coroutine.yield()
    for _, slide in ipairs(slides) do
        coroutine.yield(slide)
    end
end


function SlideDeck:_newSlideIter()
    -- HACK: always regenerate slides. slides shown may be different each time.
    if self.last_schedule then
        self:updateSchedule(self.last_schedule)
    end

    local slides
    if self.slides and #self.slides > 0 then
        slides = self.slides
    else
        slides = {fg.makebackupslide()}
    end

    local co = coroutine.wrap(_slideiter)
    co(slides)
    return co, #slides
end


function SlideDeck:_next()
    local it = self.iter
    if it then
        self.current = it()
        if not self.current then
            tools.debugPrint(2, "Slide iterator finished")
            it = nil
        end
    end
    if not it then
        local n
        it, n = self:_newSlideIter()
        self.iter = it
        tools.debugPrint(2, "Reloaded slide iter (" .. n .. " slides)")
    end
    if not self.current then
        self.current = it()
    end

    local t = 1
    if self.current then
        t = self.current.time or t
    end

    -- schedule next slide
    self.tq:push(t, function()
         self:_next()
      end)
end

function SlideDeck:draw(aspect)
    if not self.current then
        self:_next()
    end

    drawlogo(aspect)
    local hx, hy = drawheader(self.current) -- returns where header ends
    if self.current then
        drawslide(self.current, hx, hy)
    end
end

print("slidedeck.lua loaded completely")
return SlideDeck
