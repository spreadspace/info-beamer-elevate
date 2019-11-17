local Background = {}
Background.__index = Background

local function drawBGSimple(res)
    gl.ortho()
    -- we assume the background has the correct aspect ratio
    res:draw(0, 0, NATIVE_WIDTH, NATIVE_HEIGHT)
    tools.fixAspect()
end

function Background.new(style)
    local self = {
        _draw = nil
    }

    local fancymode = style:match("^fancy%-(.*)$")
    if style == "static" then
        tools.debugPrint(1, "background style: " .. style)

        self._draw = function()
            local res = CONFIG.background_static.ensure_loaded()
            drawBGSimple(res)
        end
    elseif style == "video" then
        tools.debugPrint(1, "background style: " .. style)

        self._draw = function()
            local res = CONFIG.background_video.ensure_loaded({looped=true})
            drawBGSimple(res)
        end
    elseif fancymode then
        tools.debugPrint(1, "background style: " .. style)

        local fancy = require "fancy"
        fancy.fixaspect = tools.fixAspect
        self._draw = function()
            gl.ortho()
            fancy.render(fancymode) -- resets the matrix
            gl.ortho()
            tools.fixAspect()
        end
    else
        tools.debugPrint(1, "WARNING: invalid background style: " .. style)
    end

    return setmetatable(self, Background)
end

function Background:draw()
    if self._draw then
        self._draw()
    end
end

print("background.lua loaded completely")
return Background
