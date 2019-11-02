util.init_hosted()

node.set_flag("no_clear")

gl.setup(NATIVE_WIDTH, NATIVE_HEIGHT)

local TOP_TITLE = "ELEVATE INFOSCREEN"
local SPONSORS_TITLE = "SPONSORS"

SCREEN_ASPECT = 16 / 9
FAKEWIDTH = HEIGHT * SCREEN_ASPECT
rawset(_G, "_DEBUG_", 2) -- <5 will only print to stdout, >= 5 also adds visual changes to the screen


local TimerQueue = require "timerqueue"

-- persistent state, survives file reloads
local state = rawget(_G, "._state")
if not state then
    state = {}
    rawset(_G, "._state", state)
end

local function ResetState()
    state.slideiter = nil
    state.slide = nil
    state.tq = TimerQueue.new()
end
rawset(_G, "ResetState", ResetState)

-- this will install itself onto _G
local tools = {}
util.file_watch("tools.lua", function(content)
    print("Reloading tools.lua...")
    local x = assert(loadstring(content, "tools.lua"))()
    tools = x
    ResetState()
end)

-- this will install itself onto _G
local fg = {}
util.file_watch("fg.lua", function(content)
    print("Reloading fg.lua...")
    local x = assert(loadstring(content, "fg.lua"))()
    fg = x
    ResetState()
end)


local res = util.auto_loader()

local Slide = {}
util.file_watch("slide.lua", function(content)
    print("Reloading slide.lua...")
    local x = assert(loadstring(content, "slide.lua"))()
    x.res = res
    Slide = x
    rawset(_G, "Slide", x)
    ResetState()
end)


local fancy = require "fancy"
fancy.res = res
-- TODO: auto-reload??


if not state.tq then
    state.tq = TimerQueue.new()
end



local json = require "json"
util.file_watch("schedule.json", function(content)
    local schedule = json.decode(content)
    fg.onUpdateSchedule(schedule)
end)

node.event("config_update", function()
    fg.onUpdateConfig()
    tools.clearColorText()
end)

util.data_mapper{
    ["clock/set"] = function(tm)
        fg.onUpdateTime(tm)
    end,
}


local function nextslide()
    local it = state.slideiter
    if it then
        state.slide = it()
        if not state.slide then
            tools.debugPrint(2, "Slide iterator finished")
            it = nil
        end
    end
    if not it then
        local n
        it, n = fg.newSlideIter()
        state.slideiter = it
        tools.debugPrint(2, "Reloaded slide iter, to show:  " .. n)
    end
    if not state.slide then
        state.slide = it()
    end

    local t = 1
    if state.slide then
        t = state.slide.time or t
    end

    -- schedule next slide
    state.tq:push(t, nextslide)
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

fancy.fixaspect = tools.fixAspect

local function drawbgstatic()
    gl.pushMatrix()
        gl.scale(WIDTH, HEIGHT)
        CONFIG.background.ensure_loaded():draw(0, 0, 1, 1)
    gl.popMatrix()
end

local function drawlogo(aspect)
    gl.pushMatrix()
        gl.scale(WIDTH, HEIGHT)
        local logosz = 0.23
        CONFIG.logo.ensure_loaded():draw(-0.01, 0.01, logosz/aspect, logosz)
    gl.popMatrix()
end

function node.render()
    local now = sys.now()
    local dt = (state.lastnow and now - state.lastnow) or 0
    state.lastnow = now
    state.tq:update(dt)

    if not state.slide then
        nextslide()
    end

    local aspect = WIDTH / HEIGHT
    local bgstyle = fg.getbgstyle()
    FAKEWIDTH = HEIGHT * SCREEN_ASPECT

    -- draw the background
    gl.ortho()
    if bgstyle == "static" then
        drawbgstatic()
    else
        fancy.render(bgstyle, aspect) -- resets the matrix
        gl.ortho()
    end
    tools.fixAspect(aspect)

    -- draw the header + slide
    drawlogo(aspect)
    local hx, hy = drawheader(state.slide) -- returns where header ends
    if state.slide then
        drawslide(state.slide, hx, hy)
    end
end
