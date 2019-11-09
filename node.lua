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
    state.background = nil
    state.slidedeck = nil
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
util.file_watch("fg.lua", function(content)
    print("Reloading fg.lua...")
    assert(loadstring(content, "fg.lua"))()
end)


local json = require "json"
util.file_watch("schedule.json", function(content)
    state.current_schedule = json.decode(content)
    -- uncomment this for changes to take effect immediatly
    -- regenerateSlideDeck()
end)

util.data_mapper{
    ["clock/set"] = function(tm)
        fg.onUpdateTime(tm)
    end,
}


local Background = {}
util.file_watch("background.lua", function(content)
    print("Reloading background.lua...")
    local x = assert(loadstring(content, "background.lua"))()
    Background = x
    state.background = Background.new(fg.getbgstyle())
end)


local SlideDeck = {}
util.file_watch("slidedeck.lua", function(content)
    print("Reloading slidedeck.lua...")
    local x = assert(loadstring(content, "slidedeck.lua"))()
    SlideDeck = x
    if _DEBUG_ or not state.slidedeck then
       state.slidedeck = SlideDeck.new(state.current_schedule)
    end
end)


node.event("config_update", function()
    fg.onUpdateConfig()
    tools.clearColorTex()
    state.background = Background.new(fg.getbgstyle())
end)


function node.render()
    local now = sys.now()
    local dt = (state.lastnow and now - state.lastnow) or 0
    state.lastnow = now

    -- slidedeck.update() might set state.slidedeck to nil if we reached the end of the slides
    if state.slidedeck then state.slidedeck:update(dt) end
    if not state.slidedeck then
       state.slidedeck  = SlideDeck.new(state.current_schedule)
    end

    local aspect = WIDTH / HEIGHT
    FAKEWIDTH = HEIGHT * SCREEN_ASPECT
    state.background:draw(aspect)
    state.slidedeck:draw(aspect)
end
