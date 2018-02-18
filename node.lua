util.init_hosted()

NATIVE_WIDTH = NATIVE_WIDTH or 1920
NATIVE_HEIGHT = NATIVE_HEIGHT or 1080

local LOCAL_SLIDE_TIME = 3
local REMOTE_SLIDE_TIME = 1

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


local bgtex, fgtex
local function maketex()
    bgtex = resource.create_colored_texture(CONFIG.background_color.rgb_with_a(1))
    fgtex = resource.create_colored_texture(CONFIG.foreground_color.rgb_with_a(1))
end


util.file_watch("fg.lua", function(content)
    print("Reload fg.lua...")
    local x = assert(loadstring(content, "fg.lua"))()
    fg = x
end)

node.event("config_update", function()
    fg.onUpdateConfig()
    maketex()
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


maketex()


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
        if state.slide.here then
            t = LOCAL_SLIDE_TIME
        else
            t = REMOTE_SLIDE_TIME
        end
    end
    
    -- schedule next slide
    state.tq:push(t, nextslide)
end

-- takes x, y, sz in resolution-independent coords
-- (0, 0) = upper left corner, (1, 1) = lower right corner
-- sz == 0.5 -> half as high as the screen
local function drawfontrel(font, x, y, text, sz, ...)
    local xx = x * WIDTH
    local yy = y * HEIGHT
    local zz = sz * HEIGHT
    local yborder = 0.01 * HEIGHT
    local xborder = 0.02 * HEIGHT -- intentionally HEIGHT, not a typo
    local w = font:write(xx, yy, text, zz, ...)
    bgtex:draw(xx-xborder, yy-yborder, xx+w+xborder, yy+zz+yborder)
    font:write(xx, yy, text, zz, ...)
    return xx, yy+zz, w
end

local function drawfont(font, x, y, text, sz, ...)
    local yborder = 0.01 * HEIGHT
    local xborder = 0.02 * HEIGHT -- intentionally HEIGHT, not a typo
    local w = font:write(x, y, text, sz, ...)
    bgtex:draw(x-xborder, y-yborder, x+w+xborder, y+sz+yborder)
    font:write(x, y, text, sz, ...)
    return x+w, y+sz
end

local function drawbg(aspect)
    CONFIG.background_color.clear()
    CONFIG.background.ensure_loaded():draw(0, 0, 1, 1)
    local logosz = 0.3
    CONFIG.logo.ensure_loaded():draw(0, 0, logosz/aspect, logosz)
end

local function drawheader(aspect)
    local font = CONFIG.font
    local fcol = CONFIG.foreground_color
    local hy = 0.05
    
    -- time
    drawfontrel(CONFIG.font, 0.9, hy, fg.gettimestr(), 0.06, fcol.rgb_with_a(1))
    
    return drawfontrel(CONFIG.font, 0.15, hy, fg.locname, 0.1, fcol.rgb_with_a(1))
end

local function wrapfactor(yspace, h) -- how many chars until wrap
    return math.floor(2.2 * yspace / h) -- i don't even
end


-- absolute positions
local function draweventabs(x, y, event, islocal)
    local font = CONFIG.font
    local fgcol = CONFIG.foreground_color

    local h = HEIGHT*0.07 -- font size time + title
    local yo = h / 2 -- center font on line 
    local liney = y-yo -- always line y pos
    
    local xo = 0 
    if islocal then
        xo = 0.05 * WIDTH  
        fgtex:draw(x-xo*0.5, y-yo*0.15, x+xo*0.5, y+yo*0.15)
    end
    
    local fxt, fy = drawfont(font, x+xo, liney, event.start .. "   ", h, fgcol.rgba()) -- write time
    
    -- DRAW TITLE
    local fx = max(fxt, x+0.1*WIDTH)   -- x start of title
    local yspace = WIDTH - fx -- how much space is left on the right?
    local sa = event.title:wrap(wrapfactor(yspace, h)) -- somehow figure out how to wrap
    local linespacing = HEIGHT*0.01
    for i = 1, #sa do -- draw each line after wrapping
        _, liney = drawfont(font, fx, liney, sa[i], h, fgcol.rgba()) 
        liney = liney + linespacing
    end
    
    local extraspace = yo -- shift to bottom of line
    
    -- DRAW SUBTITLE
    if islocal and event.subtitle then
        local h2 = h * 0.6 -- font size subtitle
        local sa = event.subtitle:wrap(wrapfactor(yspace, h2))
        local linespacing = HEIGHT*0.01
        for i = 1, #sa do
            _, liney = drawfont(font, fx, liney, sa[i], h2, fgcol.rgba()) 
            liney = liney + linespacing
        end
        extraspace = extraspace + HEIGHT*0.04 -- leave some more extra space
    end
    
    return liney -- where we are
        + extraspace
end

-- ry = position relative to [sy..HEIGHT]
local function draweventrel(sx, sy, ry, ...)
    local y = math.rescale(ry, 0, 1, sy, HEIGHT)
    local yabs = draweventabs(sx, y, ...)
    return math.rescale(yabs, sy, HEIGHT, 0, 1)
end

local function drawlocalslide(slide, sx, sy)
    local evs = slide.events
    local beginy = sy+HEIGHT*0.02
    res.gradient:draw(sx, beginy, sx+WIDTH*0.008, HEIGHT)
    
    local MAXEVENTS = 4
    
    local N = min(MAXEVENTS, #evs)-- draw up to this many events
    local ystart = math.rescale(N, 1, MAXEVENTS, 0.38, 0.07) -- more events -> start higher (guesstimate)
    local yend = 0.85 -- hopefully safe
    
    local mints = evs[1].startts
    local maxts = evs[#evs].endts
    local span
    if mints and maxts then
        span = maxts - mints
    end
    
    local yrel = ystart
    for i = 1, N do
        local ev = evs[i]
        if span and i > 1 and ev.startts then
            --local pause = evs[i].startts - evs[i-1].endts
            local yfit = math.rescale(ev.startts, mints, maxts, ystart, yend)
            if yrel < yfit then
                yrel = yfit
            end
        end

        
        yrel = draweventrel(sx, sy, yrel, evs[i], true)
    end
end

local function drawremoteslide(slide, sx, sy)
    local evs = slide.events
    local font = CONFIG.font
    local beginy = sy+HEIGHT*0.02
    
    local wheresize = HEIGHT*0.06
    local where = ("%s / %s"):format(slide.track.name, slide.location.name)
    drawfont(font, sx, beginy, where, wheresize, CONFIG.foreground_color.rgb_with_a(alpha))
    
    local MAXEVENTS = 8
    local N = min(MAXEVENTS, #evs)
    local ystart = 0.3
    local yend = 0.92 -- hopefully safe
    local yrel = ystart
    for i = 1, N do -- draw up to this many events
        yrel = draweventrel(sx, sy, yrel, evs[i], false)
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
    
    local hx, hy, hw = drawheader(aspect)
    
    
    if not state.slide then
        nextslide()
    end
    if state.slide then
        gl.pushMatrix()
            drawslide(state.slide, hx, hy)
        gl.popMatrix()
    end
end
