util.init_hosted()
node.set_flag("no_clear")

NATIVE_ASPECT = NATIVE_WIDTH / NATIVE_HEIGHT
gl.setup(NATIVE_WIDTH, NATIVE_HEIGHT)

DISPLAY_ASPECT = 16 / 9
DISPLAY_HEIGHT = HEIGHT
DISPLAY_WIDTH = DISPLAY_HEIGHT * DISPLAY_ASPECT
rawset(_G, "_DEBUG_", 2) -- <5 will only print to stdout, >= 5 also adds visual changes to the screen


-- persistent state, survives file reloads
local state = rawget(_G, "._state")
if not state then
    state = {}
    state.background = nil
    state.slidedeck = nil
    state.slidedeckIteration = 0
    state.current_schedule = nil
    state.lastnow = nil
    rawset(_G, "._state", state)
end

local function regenerateSlideDeck()
    state.slidedeck = nil
end
rawset(_G, "regenerateSlideDeck", regenerateSlideDeck)

Resources = util.auto_loader()

-- this will install itself onto _G
util.file_watch("tools.lua", function(content)
    print("Reloading tools.lua...")
    assert(loadstring(content, "tools.lua"))()
end)

-- this will install itself onto _G
util.file_watch("device.lua", function(content)
    print("Reloading device.lua...")
    assert(loadstring(content, "device.lua"))()
end)


local json = require "json"
util.file_watch("schedule.json", function(content)
    state.current_schedule = json.decode(content)
    -- uncomment this for changes to take effect immediatly
    -- regenerateSlideDeck()
end)

util.data_mapper{
    ["clock/set"] = function(tm)
        device.updateTime(tm)
    end,
}


local Background = {}
util.file_watch("background.lua", function(content)
    print("Reloading background.lua...")
    local x = assert(loadstring(content, "background.lua"))()
    Background = x
    state.background = Background.new(device.getBackgroundStyle())
end)


local SlideDeck = {}
util.file_watch("slidedeck.lua", function(content)
    print("Reloading slidedeck.lua...")
    local x = assert(loadstring(content, "slidedeck.lua"))()
    SlideDeck = x
    if _DEBUG_ or not state.slidedeck then
       state.slidedeck = SlideDeck.new(state.current_schedule, state.slidedeckIteration)
       state.slidedeckIteration = state.slidedeckIteration + 1
    end
end)


node.event("config_update", function()
    config = assert(CONFIG, "ERROR: no CONFIG found")
    device.updateConfig()
    tools.clearColorTex()
    state.background = Background.new(device.getBackgroundStyle())
end)


function node.render()
    -- for debug purposes
    NATIVE_ASPECT = NATIVE_WIDTH / NATIVE_HEIGHT
    DISPLAY_HEIGHT = HEIGHT
    DISPLAY_WIDTH = DISPLAY_HEIGHT * DISPLAY_ASPECT

    local now = sys.now()
    local dt = (state.lastnow and now - state.lastnow) or 0
    state.lastnow = now

    -- slidedeck.update() might set state.slidedeck to nil if we reached the end of the slides
    if state.slidedeck then state.slidedeck:update(dt) end
    if not state.slidedeck then
       state.slidedeck = SlideDeck.new(state.current_schedule, state.slidedeckIteration)
       state.slidedeckIteration = state.slidedeckIteration + 1
    end

    state.background:draw()
    state.slidedeck:draw()
end
