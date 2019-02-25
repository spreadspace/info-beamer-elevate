util.init_hosted()

-- this is only supported on the Raspi....
--util.noglobals()

node.set_flag("no_clear")

gl.setup(NATIVE_WIDTH, NATIVE_HEIGHT)

local TOP_TITLE = "ELEVATE INFOSCREEN"
local SPONSORS_TITLE = "SPONSORS"

local SCREEN_ASPECT = 16 / 9
FAKEWIDTH = HEIGHT * SCREEN_ASPECT

rawset(_G, "DEBUG_THINGS", true)


-- persistent state, survives file reloads
local state = rawget(_G, "._state")
if not state then
    state = {}
    rawset(_G, "._state", state)
end

local tqnew = require "tq"

local function ResetState()
    state.slideiter = nil
    state.slide = nil
    state.tq = tqnew()
end
rawset(_G, "ResetState", ResetState)


local json = require "json"
local fg = require "fg"
local SLIDE = require "slide"
local res = util.auto_loader()
RES = res

local fancy = require"fancy"
fancy.res = res

local min = math.min
local max = math.max

if not state.tq then
    state.tq = tqnew()
end

util.file_watch("fg.lua", function(content)
    print("Reload fg.lua...")
    local x = assert(loadstring(content, "fg.lua"))()
    fg = x
    ResetState()
end)

util.file_watch("slide.lua", function(content)
    print("Reload slide.lua...")
    local x = assert(loadstring(content, "slide.lua"))()
    SLIDE = x
    rawset(_G, "SLIDE", x)
    ResetState()
end)

node.event("config_update", function()
    fg.onUpdateConfig()
    table.clear(_tmptex)
end)

util.file_watch("schedule.json", function(content)
    local schedule = json.decode(content)
    fg.onUpdateSchedule(schedule)
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
            print("Slide iterator finished")
            it = nil
        end
    end
    if not it then
        local n
        it, n = fg.newSlideIter()
        state.slideiter = it
        print("Reloaded slide iter, to show:  " .. n)
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
local function drawfontrel(font, x, y, text, sz, fgcol, bgcol)
    local xx = x * FAKEWIDTH
    local yy = y * HEIGHT
    local zz = sz * HEIGHT
    local yborder = 0.01 * HEIGHT
    local xborder = 0.02 * HEIGHT -- intentionally HEIGHT, not a typo
    local w = font:write(xx, yy, text, zz, fgcol:rgba())
    local bgtex = fg.getcolortex(bgcol)
    bgtex:draw(xx-xborder, yy-yborder, xx+w+xborder, yy+zz+yborder)
    font:write(xx, yy, text, zz, fgcol:rgba())
    return xx, yy+zz, w
end

local function drawfont(font, x, y, text, sz, fgcol, bgcol)
    local yborder = 0.01 * HEIGHT
    local xborder = 0.02 * HEIGHT -- intentionally HEIGHT, not a typo
    local w = font:write(x, y, text, sz, fgcol:rgba())
    local bgtex = fg.getcolortex(bgcol)
    bgtex:draw(x-xborder, y-yborder, x+w+xborder, y+sz+yborder)
    font:write(x, y, text, sz, fgcol:rgba())
    return x+w, y+sz
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
    drawfontrel(fontbold, timex, hy, timestr, timesize, fgcol, bgcol)

    local xpos = 0.15
    local titlesize = 0.06
    drawfontrel(font, xpos, hy, TOP_TITLE, titlesize, fgcol, bgcol)

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
        drawfontrel(font, xpos, hy, where, wheresize, fgcol2, bgcol2)
    end

    return FAKEWIDTH*xpos, hy + wheresize + HEIGHT*0.25
end

-- absolute positions
--[=[
local function draweventabs(x, titlestartx, y, event, islocal, fontscale1, fontscale2, gradx)
    local font = CONFIG.font
    local fontbold = CONFIG.font_bold
    local track = fg.gettrack(event.track)
    local fgcol = assert((track and track.foreground_color) or CONFIG.foreground_color)
    local bgcol = assert((track and track.background_color) or CONFIG.background_color)
    local fgtex = fg.getcolortex(fgcol)


    local h = HEIGHT*fontscale1 -- font size time + title
    local h2 = fontscale2 and HEIGHT*fontscale2 -- font size subtitle
    local yo = h / 2 -- center font on line
    local liney = y-yo -- always line y pos
    local extraspace = yo -- extra space at bottom of line (increased a bit when subtitle is present
    local linespacing = HEIGHT*0.01
    local timelen = fontbold:width(event.start, h)
    local fxt = x+timelen + 0.02*WIDTH -- leave some space after the time
    local fx = titlestartx or max(fxt, x+0.1*WIDTH)   -- x start of title

    local titlea = event.title:fwrap(font, h, fx, FAKEWIDTH) -- figure out how to wrap
    local suba = event.subtitle and event.subtitle:fwrap(font, h2, fx, FAKEWIDTH)

    local maxy = liney -- here right now
               + (#titlea * (h + linespacing)) -- height of title
               + ((suba and (#suba * (h2 + linespacing))) or 0) -- height of subtitle

    if maxy > HEIGHT+linespacing then
        return
    end

    -- DRAW TICK
    if islocal then
        local gxo = 0.04 * WIDTH
        local gyo = HEIGHT * 0.004
        fgtex:draw(gradx-gxo*0.5, y-gyo, gradx+gxo*0.5, y+gyo)
    end

    -- DRAW TIME
    local _, fy = drawfont(fontbold, x, liney, event.start .. "        ", h, fgcol, bgcol) -- HACK: kill gaps

    -- DRAW TITLE
    for i = 1, #titlea do -- draw each line after wrapping
        _, liney = drawfont(font, fx, liney, titlea[i], h, fgcol, bgcol)
        liney = liney + linespacing
    end

    -- DRAW SUBTITLE
    if islocal and suba then
        for i = 1, #suba do
            _, liney = drawfont(font, fx, liney, suba[i], h2, fgcol, bgcol)
            liney = liney + linespacing
        end
        extraspace = extraspace + HEIGHT*0.04 -- leave some more extra space
    end

    return liney -- where we are
        + extraspace,
        fx -- where title starts
end

-- ry = position relative to [sy..HEIGHT]
local function draweventrel(sx, titlestartx, sy, ry, ...)
    local y = math.rescale(ry, 0, 1, sy, HEIGHT)
    local yabs, titlestartx = draweventabs(sx, titlestartx, y, ...)
    return yabs and math.rescale(yabs, sy, HEIGHT, 0, 1), titlestartx
end

local function drawlocalslide(slide, sx, sy)
    local evs = slide.events
    --local beginy = sy+HEIGHT*0.02
    local beginy = 0.15 * HEIGHT
    local thickness = WIDTH*0.006
    local empty = slide.empty
    local gx = sx - 0.035 * FAKEWIDTH
    --res.gradient:draw(gx - thickness/2, beginy, gx + thickness/2, HEIGHT)

    local MAXEVENTS = 3

    local N = min(MAXEVENTS, #evs)-- draw up to this many events
    local ystart = math.rescale(N, 1, MAXEVENTS, 0.35, 0.15) -- more events -> start higher (guesstimate)

    local yrel = ystart
    local titlestartx -- initially nil is fine
    for i = 1, N do
        local ev = evs[i]

        local fontscale1 = 0.065
        local fontscale2 = 0.042
        if empty then -- draw empty slide (usually has 1 dummy event really large)
            fontscale1 = fontscale1 * 1.5
            fontscale2 = fontscale2 * 1.5
        elseif i == 1 then -- draw first event a bit larger
            fontscale1 = fontscale1 * 1.2
            fontscale2 = fontscale2 * 1.2
        end

        yrel, titlestartx = draweventrel(sx, titlestartx, sy, yrel, evs[i], true, fontscale1, fontscale2, gx)
        if not yrel then -- nil if space is full
            break
        end
        yrel = yrel + 0.04 -- some more space
    end
end

local function drawremoteslide(slide, sx, sy)
    sy = sy - 0.15*HEIGHT -- HACK: move up a bit more
    local evs = slide.events
    local font = CONFIG.font
    local fgcol = CONFIG.foreground_color
    local bgcol = CONFIG.background_color

    local MAXEVENTS = 5
    local N = min(MAXEVENTS, evs and #evs or 0)
    local ystart = 0.3
    local yrel = ystart
    local titlestartx
    for i = 1, N do -- draw up to this many events
        local fontscale1 = 0.07
        local fontscale2 = 0.045
        yrel, titlestartx = draweventrel(sx, titlestartx, sy, yrel, evs[i], false, fontscale1, fontscale2)
        if not yrel then
            break
        end
        yrel = yrel + 0.04 -- some more space
    end
end
]=]

local function drawslide(slide, sx, sy)
    -- start positions after header
    gl.pushMatrix()
        slide:drawAbs(sx, sy)
        gl.translate(sx, sy)
        slide:draw()
    gl.popMatrix()

    -- TODO KILL THIS
    --[[if slide.here then
        return drawlocalslide(slide, sx, sy)
    else
        return drawremoteslide(slide, sx, sy)
    end]]
end

local function fixaspect(aspect)
    gl.scale(1 / (SCREEN_ASPECT / aspect), 1)
end
fancy.fixaspect = fixaspect

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
    local aspect = WIDTH / HEIGHT
    local bgstyle = fg.getbgstyle()

    FAKEWIDTH = HEIGHT * SCREEN_ASPECT

    gl.ortho()

    if bgstyle == "static" then
        drawbgstatic()
    else
        fancy.render(bgstyle, aspect) -- resets the matrix
        gl.ortho()
    end

    fixaspect(aspect)
    drawlogo(aspect)



    local now = sys.now()
    local dt = (state.lastnow and now - state.lastnow) or 0
    state.lastnow = now

    state.tq:update(dt)

    if not state.slide then
        nextslide()
    end

    local hx, hy = drawheader(state.slide) -- returns where header ends
    if state.slide then
        drawslide(state.slide, hx, hy)
    end
end
