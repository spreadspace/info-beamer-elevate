util.init_hosted()

node.set_flag("no_clear")

gl.setup(NATIVE_WIDTH, NATIVE_HEIGHT)

SCREEN_ASPECT = 16 / 9
FAKEWIDTH = HEIGHT * SCREEN_ASPECT
rawset(_G, "_DEBUG_", 2) -- <5 will only print to stdout, >= 5 also adds visual changes to the screen


-- persistent state, survives file reloads
local state = rawget(_G, "._state")
if not state then
    state = {}
    state.slidedeck = nil
    state.lastnow = nil
    rawset(_G, "._state", state)
end

-- this will install itself onto _G
util.file_watch("tools.lua", function(content)
    print("Reloading tools.lua...")
    assert(loadstring(content, "tools.lua"))()
end)

-- this will install itself onto _G
util.file_watch("fg.lua", function(content)
    print("Reloading fg.lua...")
    assert(loadstring(content, "fg.lua"))()
end)

local SlideDeck = {}
util.file_watch("slidedeck.lua", function(content)
    print("Reloading slidedeck.lua...")
    local x = assert(loadstring(content, "slidedeck.lua"))()
    SlideDeck = x
    local last_schedule = state.slidedeck and state.slidedeck.last_schedule
    state.slidedeck  = SlideDeck.new(last_schedule)
end)


local res = util.auto_loader()
RES = res -- TODO: find a better way than this global... only needed by slide.lua to load the gradient

-- TODO: auto-reload??
local fancy = require "fancy"
fancy.res = res
fancy.fixaspect = tools.fixAspect

local json = require "json"
util.file_watch("schedule.json", function(content)
    local schedule = json.decode(content)
    state.slidedeck:updateSchedule(schedule)
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


local function drawbgstatic()
    gl.pushMatrix()
        gl.scale(WIDTH, HEIGHT)
        CONFIG.background.ensure_loaded():draw(0, 0, 1, 1)
    gl.popMatrix()
end

function node.render()
    -- TODO: should this be moved to slidedeck??
    local now = sys.now()
    local dt = (state.lastnow and now - state.lastnow) or 0
    state.lastnow = now
    state.slidedeck.tq:update(dt)


    local aspect = WIDTH / HEIGHT
    FAKEWIDTH = HEIGHT * SCREEN_ASPECT

    -- draw the background
    local bgstyle = fg.getbgstyle()
    gl.ortho()
    if bgstyle == "static" then
        drawbgstatic()
    else
        fancy.render(bgstyle, aspect) -- resets the matrix
        gl.ortho()
    end
    tools.fixAspect(aspect)

    -- draw the slides
    state.slidedeck:draw(aspect)
end
