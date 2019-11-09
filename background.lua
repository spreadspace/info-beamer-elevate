local Background = {}
Background.__index = Background

local function drawBGSimple(res, aspect)
    gl.ortho()
    gl.pushMatrix()
        gl.scale(WIDTH, HEIGHT)
        res:draw(0, 0, 1, 1)
    gl.popMatrix()
    tools.fixAspect(aspect)
end

function Background.new(style)
    local self = {
        _draw = nil
    }

    local fancymode = style:match("^fancy%-(.*)$")
    if style == "static" then
        tools.debugPrint(1, "background style: " .. style)

        self._draw = function(aspect)
            local res = CONFIG.background_static.ensure_loaded()
            drawBGSimple(res, aspect)
        end
    elseif style == "video" then
        tools.debugPrint(1, "background style: " .. style)

        self._draw = function(aspect)
            local res = CONFIG.background_video.ensure_loaded({looped=true})
            drawBGSimple(res, aspect)
        end
    elseif fancymode then
        tools.debugPrint(1, "background style: " .. style)

        local fancy = require "fancy"
        fancy.fixaspect = tools.fixAspect
        self._draw = function(aspect)
            gl.ortho()
            fancy.render(fancymode, aspect) -- resets the matrix
            gl.ortho()
            tools.fixAspect(aspect)
        end
    else
        tools.debugPrint(1, "WARNING: invalid background style: " .. style)
    end

    return setmetatable(self, Background)
end

function Background:draw(aspect)
    if self._draw then
        self._draw(aspect)
    end
end

print("background.lua loaded completely")
return Background
