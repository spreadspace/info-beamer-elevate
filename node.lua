util.init_hosted()

NATIVE_WIDTH = NATIVE_WIDTH or 1920
NATIVE_HEIGHT = NATIVE_HEIGHT or 1080

gl.setup(NATIVE_WIDTH, NATIVE_HEIGHT)

local json = require "json"
local tqnew = require "tq"
local fg = require "fg"
local res = util.auto_loader()

-- persistent state, survives file reloads
local state = rawget(_G, "._state")
if not state then
    state = {}
    rawset(_G, "._state", state)
end
if not state.tq then
    state.tq = tqnew()
end

local bgtex
local function makebgtex()
    bgtex = resource.create_colored_texture(CONFIG.background_color.rgb_with_a(1))
end


util.file_watch("fg.lua", function(content)
    print("Reload fg.lua...")
    local x = assert(loadstring(content, "fg.lua"))()
    fg = x
end)

node.event("config_update", function()
    fg.onUpdateConfig()
    makebgtex()
end)

util.file_watch("schedule.json", function(content)
    local schedule = json.decode(content)
    fg.onUpdateSchedule(schedule)
end)

util.data_mapper{
    ["clock/set"] = function(tm)
        fg.onUpdateTime(tm)
    end
}


makebgtex()


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
        it = fg.newSlideIter()
        state.slideiter = it
    end
    if not state.slide then
        state.slide = it()
    end
    
    -- schedule next slide
    state.tq:push(1, nextslide)
end

-- takes x, y, sz in resolution-independent coords
-- (0, 0) = upper left corner, (1, 1) = lower right corner
-- sz == 0.5 -> half as high as the screen
local function drawfont(font, x, y, text, sz, ...)
    local xx = x * WIDTH
    local yy = y * HEIGHT
    local zz = sz * HEIGHT
    local yborder = 0.01 * HEIGHT
    local xborder = 0.02 * HEIGHT -- intentionally HEIGHT, not a typo
    local w = font:write(xx, yy, text, zz, ...)
    bgtex:draw(xx-xborder, yy-yborder, xx+w+xborder, yy+zz+yborder)
    return font:write(xx, yy, text, sz*HEIGHT, ...)
end

local function drawbg(aspect)
    CONFIG.background_color.clear()
    CONFIG.background.ensure_loaded():draw(0, 0, 1, 1)
    local logosz = 0.3
    CONFIG.logo.ensure_loaded():draw(0, 0, logosz/aspect, logosz)
    local alpha = 1
end

local function drawheader(aspect)
    
    --CONFIG.font:write(0, 0, fg.locname, 50, CONFIG.foreground_color.rgb_with_a(alpha))
    --CONFIG.font:write(0, 0, "OBEN", 50, CONFIG.background_color.rgb_with_a(alpha))
    --CONFIG.font:write(0, 0.9, "UNTEN", 50, CONFIG.background_color.rgb_with_a(alpha))
    
    local fcol = CONFIG.foreground_color
    drawfont(CONFIG.font, 0.15, 0.05, fg.locname, 0.1, fcol.rgb_with_a(alpha))
    drawfont(CONFIG.font, 0.15, 0.55, fg.locname, 0.1, fcol.rgb_with_a(alpha))
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
    
    drawheader(aspect)
    
    
    if not state.slide then
        nextslide()
    end
    if state.slide then
        state.slide:draw()
    end
end
