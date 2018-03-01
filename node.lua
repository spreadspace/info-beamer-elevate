local TOP_TITLE = "ELEVATE INFOSCREEN"
local SPONSORS_TITLE = "SPONSORS"

local SCREEN_ASPECT = 16 / 9

-- in relative [0..1] screen coords
local SPONSORSLIDE_START_X = 0.2
local SPONSORSLIDE_END_X = 0.8
local SPONSORSLIDE_START_Y = 0.3
local SPONSORSLIDE_END_Y = 0.9

local TEXT_WRAP_FACTOR = 0.94

util.init_hosted()

NATIVE_WIDTH = NATIVE_WIDTH or 1920
NATIVE_HEIGHT = NATIVE_HEIGHT or 1080

local FAKEWIDTH

sys.set_flag("no_clear")

gl.setup(NATIVE_WIDTH, NATIVE_HEIGHT)


local json = require "json"
local tqnew = require "tq"
local fg = require "fg"
local res = util.auto_loader()

local fancy = require"fancy"
fancy.res = res

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
        elseif state.slide.sponsor then
            t = CONFIG.sponsor_slides
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
    local xx = x * FAKEWIDTH
    local yy = y * HEIGHT
    local zz = sz * HEIGHT
    local yborder = 0.01 * HEIGHT
    local xborder = 0.02 * HEIGHT -- intentionally HEIGHT, not a typo
    local w = font:write(xx, yy, text, zz, fgcol:rgba())
    local bgtex = getcolortex(bgcol)
    bgtex:draw(xx-xborder, yy-yborder, xx+w+xborder, yy+zz+yborder)
    font:write(xx, yy, text, zz, fgcol:rgba())
    return xx, yy+zz, w
end

local function drawfont(font, x, y, text, sz, fgcol, bgcol)
    local yborder = 0.01 * HEIGHT
    local xborder = 0.02 * HEIGHT -- intentionally HEIGHT, not a typo
    local w = font:write(x, y, text, sz, fgcol:rgba())
    local bgtex = getcolortex(bgcol)
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

--[[local function wrapfactor(yspace, h) -- how many chars until wrap
    return math.floor(2.15 * yspace / h) -- i don't even
end]]


-- absolute positions
local function draweventabs(x, titlestartx, y, event, islocal, fontscale1, fontscale2, gradx)
    local font = CONFIG.font
    local fontbold = CONFIG.font_bold
    local track = fg.gettrack(event.track)
    local fgcol = assert((track and track.foreground_color) or CONFIG.foreground_color)
    local bgcol = assert((track and track.background_color) or CONFIG.background_color)
    local fgtex = getcolortex(fgcol)


    local h = HEIGHT*fontscale1 -- font size time + title
    local h2 = fontscale2 and HEIGHT*fontscale2 -- font size subtitle
    local yo = h / 2 -- center font on line
    local liney = y-yo -- always line y pos
    local extraspace = yo -- extra space at bottom of line (increased a bit when subtitle is present
    local linespacing = HEIGHT*0.01
    local timelen = fontbold:width(event.start, h)
    local fxt = x+timelen + 0.02*WIDTH -- leave some space after the time
    local fx = titlestartx or max(fxt, x+0.1*WIDTH)   -- x start of title
    
    local titlea = event.title:fwrap(font, h, fx, FAKEWIDTH*TEXT_WRAP_FACTOR) -- somehow figure out how to wrap    
    local suba = event.subtitle and event.subtitle:fwrap(font, h2, fx, FAKEWIDTH*TEXT_WRAP_FACTOR)
    
    local maxy = liney -- here right now
               + (#titlea * (h + linespacing)) -- height of title
               + (suba and (#suba * (h2 + linespacing))) -- height of subtitle

    if maxy > HEIGHT then
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
    res.gradient:draw(gx - thickness/2, beginy, gx + thickness/2, HEIGHT)

    local MAXEVENTS = 3

    local N = min(MAXEVENTS, #evs)-- draw up to this many events
    local ystart = math.rescale(N, 1, MAXEVENTS, 0.35, 0.15) -- more events -> start higher (guesstimate)
    local yend = 0.77 -- hopefully safe

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

    local MAXEVENTS = 6
    local N = min(MAXEVENTS, #evs)
    local ystart = 0.3
    local yend = 0.88 -- hopefully safe
    local yrel = ystart
    local titlestartx
    for i = 1, N do -- draw up to this many events
        local fontscale1 = 0.07
        local fontscale2 = 0.045
        yrel, titlestartx = draweventrel(sx, titlestartx, sy, yrel, evs[i], false, fontscale1, fontscale2)
        yrel = yrel + 0.04 -- some more space
        if yrel > yend+0.01 then -- safeguard -- bail out if it likely won't fit
            break
        end
    end
end

local function drawsponsorslide(slide, sx, sy)
    gl.pushMatrix()
        gl.scale(FAKEWIDTH, HEIGHT)
        local img = slide.image.ensure_loaded()
        img:draw(SPONSORSLIDE_START_X, SPONSORSLIDE_START_Y, SPONSORSLIDE_END_X, SPONSORSLIDE_END_Y)
    gl.popMatrix()
end

local function drawslide(slide, sx, sy) -- start positions after header
    if slide.image then
        return drawsponsorslide(slide, sx, sy)
    elseif slide.here then
        return drawlocalslide(slide, sx, sy)
    else
        return drawremoteslide(slide, sx, sy)
    end
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

