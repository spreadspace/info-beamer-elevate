-------------------------------------------------------------------------------
--- Classes

local Background = {}
Background.__index = Background


-------------------------------------------------------------------------------
--- Helper Functions

local function drawBGSimple(res)
    -- we assume the background has the correct aspect ratio
    res:draw(0, 0, NATIVE_WIDTH, NATIVE_HEIGHT)
end

local function setupDraw(self, style)
    local fancymode = style:match("^fancy%-(.*)$")
    if style == "static" then
        self._draw = function()
            local res = CONFIG.background_static.ensure_loaded()
            drawBGSimple(res)
        end
    elseif style == "video" then
        self._draw = function()
            local res = CONFIG.background_video.ensure_loaded({looped=true})
            drawBGSimple(res)
        end
    elseif fancymode then
        local fancy = require "fancy"
        fancy.fixaspect = tools.fixAspect
        self._draw = function()
            fancy.render(fancymode)
        end
    else
        tools.debugPrint(1, "WARNING: invalid background style: " .. style)
        self._draw = nil
        return
    end

    tools.debugPrint(1, "background style is now: " .. style)
end

-------------------------------------------------------------------------------
--- Constructor

function Background.new(style)
    local self = {
        style = style,
        _draw = nil
    }
    setupDraw(self, style)
    return setmetatable(self, Background)
end


-------------------------------------------------------------------------------
--- Member Functions

function Background:update(style)
    if style ~= self.style then
        setupDraw(self, style)
        self.style = style
    end
end

function Background:draw()
    gl.ortho()
    if self._draw then
        self._draw()
    end
end


-------------------------------------------------------------------------------

print("background.lua loaded completely")
return Background
