util.init_hosted()

NATIVE_WIDTH = NATIVE_WIDTH or 1920
NATIVE_HEIGHT = NATIVE_HEIGHT or 1080

gl.setup(NATIVE_WIDTH, NATIVE_HEIGHT)

local json = require "json"
local tqnew = require "tq"
local fg = require "fg"
local res = util.auto_loader()
local min = math.min
local max = math.max

-- persistent state, survives file reloads
local state = rawget(_G, "._state")
if not state then
    state = {}
    rawset(_G, "._state", state)
end
if not state.tq then
    state.tq = tqnew()
end


local _tmptex = setmetatable({}, { __mode = "kv" })
local function getcolortex(col)
    assert(col, "COLOR MISSING")
    local tex = _tmptex[col]
    if not tex then
        tex = resource.create_colored_texture(col.rgba())
        _tmptex[col] = tex
    end
    assert(tex, "OOPS - TEX MISSING")
    return tex
end


util.file_watch("fg.lua", function(content)
    print("Reload fg.lua...")
    local x = assert(loadstring(content, "fg.lua"))()
    fg = x
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
        if state.slide.empty then
            t = 3
        elseif state.slide.here then
            t = CONFIG.current_location
        else
            t = CONFIG.other_locations
        end
    end

    -- schedule next slide
    state.tq:push(t, nextslide)
end

-- takes x, y, sz in resolution-independent coords
-- (0, 0) = upper left corner, (1, 1) = lower right corner
-- sz == 0.5 -> half as high as the screen
local function drawfontrel(font, x, y, text, sz, fgcol, bgcol)
    local xx = x * WIDTH
    local yy = y * HEIGHT
    local zz = sz * HEIGHT
    local yborder = 0.01 * HEIGHT
    local xborder = 0.02 * HEIGHT -- intentionally HEIGHT, not a typo
    local w = font:write(xx, yy, text:upper(), zz, fgcol:rgba())
    local bgtex = getcolortex(bgcol)
    bgtex:draw(xx-xborder, yy-yborder, xx+w+xborder, yy+zz+yborder)
    font:write(xx, yy, text:upper(), zz, fgcol:rgba())
    return xx, yy+zz, w
end

local function drawfont(font, x, y, text, sz, fgcol, bgcol)
    local yborder = 0.01 * HEIGHT
    local xborder = 0.02 * HEIGHT -- intentionally HEIGHT, not a typo
    local w = font:write(x, y, text:upper(), sz, fgcol:rgba())
    local bgtex = getcolortex(bgcol)
    bgtex:draw(x-xborder, y-yborder, x+w+xborder, y+sz+yborder)
    font:write(x, y, text:upper(), sz, fgcol:rgba())
    return x+w, y+sz
end

local function drawbg(aspect)
    CONFIG.background_color.clear()
    CONFIG.background.ensure_loaded():draw(0, 0, 1, 1)
    local logosz = 0.3
    CONFIG.logo.ensure_loaded():draw(0, 0, logosz/aspect, logosz)
end

local function drawheader(aspect, slide) -- slide possibly nil (unlikely)
    local font = CONFIG.font
    local fontbold = CONFIG.font_bold
    local fgcol = CONFIG.foreground_color
    local bgcol = CONFIG.background_color
    local hy = 0.05

    -- time
    drawfontrel(fontbold, 0.83, hy, fg.gettimestr(), 0.08, fgcol, bgcol)

    local xpos = 0.15
    local titlesize = 0.06
    drawfontrel(font, xpos, hy, "Elevate Infoscreen", titlesize, fgcol, bgcol)

    hy = hy + titlesize + 0.02


    local wheresize
    if slide then
        local font = CONFIG.font_bold
        local where
        local fgcol2 = fgcol
        local bgcol2 = bgcol
        if slide.here then
            where = slide.location.name
            wheresize = 0.1
        else
            wheresize = 0.08
            where = ("%s / %s"):format(slide.track.name, slide.location.name)
            fgcol2 = slide.track.foreground_color
            bgcol2 = slide.track.background_color
        end
        drawfontrel(font, xpos, hy, where, wheresize, fgcol2, bgcol2)
    end

    return WIDTH*xpos, hy + wheresize + HEIGHT*0.25
end

local function wrapfactor(yspace, h) -- how many chars until wrap
    return math.floor(2.15 * yspace / h) -- i don't even
end


-- absolute positions
local function draweventabs(x, titlestartx, y, event, islocal, fontscale1, fontscale2)
    local font = CONFIG.font
    local fontbold = CONFIG.font_bold
    local track = fg.gettrack(event.track)
    local fgcol = assert((track and track.foreground_color) or CONFIG.foreground_color)
    local bgcol = assert((track and track.background_color) or CONFIG.background_color)
    local fgtex = getcolortex(fgcol)
    --local bgtex = getcolortex(bgcol)


    local h = HEIGHT*fontscale1 -- font size time + title
    local yo = h / 2 -- center font on line
    local liney = y-yo -- always line y pos


    local xo = 0

    -- DRAW TICK
    if islocal then
        xo = 0.05 * WIDTH
        fgtex:draw(x-xo*0.5, y-yo*0.15, x+xo*0.5, y+yo*0.15)
    end

    -- DRAW TIME
    local fxt, fy = drawfont(fontbold, x+xo, liney, event.start, h, fgcol, bgcol)
    fxt = fxt + 0.02*WIDTH -- leave some space after the time

    -- DRAW TITLE
    local fx = titlestartx or max(fxt, x+0.1*WIDTH)   -- x start of title
    local yspace = WIDTH - fx -- how much space is left on the right?
    local sa = event.title:wrap(wrapfactor(yspace, h)) -- somehow figure out how to wrap
    local linespacing = HEIGHT*0.01
    for i = 1, #sa do -- draw each line after wrapping
        _, liney = drawfont(font, fx, liney, sa[i], h, fgcol, bgcol)
        liney = liney + linespacing
    end

    local extraspace = yo -- shift to bottom of line

    -- DRAW SUBTITLE
    if islocal and event.subtitle then
        local h2 = HEIGHT*fontscale2 -- font size subtitle
        local sa = event.subtitle:wrap(wrapfactor(yspace, h2))
        local linespacing = HEIGHT*0.01
        for i = 1, #sa do
            _, liney = drawfont(font, fx, liney, sa[i], h2, fgcol, bgcol)
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
    return math.rescale(yabs, sy, HEIGHT, 0, 1), titlestartx
end

local function drawlocalslide(slide, sx, sy)
    local evs = slide.events
    local beginy = sy+HEIGHT*0.02
    local thickness = WIDTH*0.006
    local empty = slide.empty
    res.gradient:draw(sx - thickness/2, beginy, sx + thickness/2, HEIGHT)

    local MAXEVENTS = 3

    local N = min(MAXEVENTS, #evs)-- draw up to this many events
    local ystart = math.rescale(N, 1, MAXEVENTS, 0.35, 0.17) -- more events -> start higher (guesstimate)
    local yend = 0.85 -- hopefully safe

    local mints = evs[1].startts
    local maxts = evs[#evs].endts
    local span
    if mints and maxts then
        span = maxts - mints
    end

    local yrel = ystart
    local titlestartx -- initially nil is fine
    for i = 1, N do
        local ev = evs[i]
        if span and i > 1 and ev.startts then
            --[[local yfit = math.rescale(ev.startts, mints, maxts, ystart, yend)
            if yrel < yfit then
                yrel = yfit
            end]]
        end

        local fontscale1 = 0.065
        local fontscale2 = 0.042
        if empty then -- draw empty slide (usually has 1 dummy event really large)
            fontscale1 = fontscale1 * 1.5
            fontscale2 = fontscale2 * 1.5
        elseif i == 1 then -- draw first event a bit larger
            fontscale1 = fontscale1 * 1.2
            fontscale2 = fontscale2 * 1.2
        end

        yrel, titlestartx = draweventrel(sx, titlestartx, sy, yrel, evs[i], true, fontscale1, fontscale2)
        yrel = yrel + 0.04 -- some more space
    end
end

local function drawremoteslide(slide, sx, sy)
    sy = sy - 0.15*HEIGHT -- HACK: move up a bit more
    local evs = slide.events
    local font = CONFIG.font
    local fgcol = CONFIG.foreground_color
    local bgcol = CONFIG.background_color

    local MAXEVENTS = 6
    local N = min(MAXEVENTS, #evs)
    local ystart = 0.3
    local yend = 0.92 -- hopefully safe
    local yrel = ystart
    for i = 1, N do -- draw up to this many events
        local fontscale1 = 0.07
        local fontscale2 = 0.045
        yrel = draweventrel(sx, nil, sy, yrel, evs[i], false, fontscale1, fontscale2)
        yrel = yrel + 0.04 -- some more space
        if yrel > yend+0.01 then -- safeguard -- bail out if it likely won't fit
            break
        end
    end
end

local function drawslide(slide, sx, sy) -- start positions after header
    if slide.here then
        return drawlocalslide(slide, sx, sy)
    else
        return drawremoteslide(slide, sx, sy)
    end
end


function node.render()
    local now = sys.now()
    local dt = (state.lastnow and now - state.lastnow) or 0
    state.lastnow = now

    state.tq:update(dt)

    local aspect = WIDTH / HEIGHT
    gl.ortho()

    gl.pushMatrix()
        gl.scale(WIDTH, HEIGHT)
        drawbg(aspect)
    gl.popMatrix()

    if not state.slide then
        nextslide()
    end

    local hx, hy = drawheader(aspect, state.slide) -- returns where header ends

    if state.slide then
        gl.pushMatrix()
            drawslide(state.slide, hx, hy)
        gl.popMatrix()
    end
end
