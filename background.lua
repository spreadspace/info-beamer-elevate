local Background = {}
Background.__index = Background

local fancy = require "fancy"
--fancy.fixaspect = tools.fixAspect


local function drawbgstatic()
    gl.pushMatrix()
        gl.scale(WIDTH, HEIGHT)
        CONFIG.background_static.ensure_loaded():draw(0, 0, 1, 1)
    gl.popMatrix()
end


function Background.new()
    local self = {
        -- style = "static"
    }
    return setmetatable(self, Background)
end

function Background:draw(aspect)
    local bgstyle = fg.getbgstyle()
    local fancymode = bgstyle:match("^fancy%-(.*)$")
    gl.ortho()
    if bgstyle == "static" then
        drawbgstatic()
    elseif fancymode then
        fancy.render(fancymode, aspect) -- resets the matrix
        gl.ortho()
    end
    tools.fixAspect(aspect)
end

print("background.lua loaded completely")
return Background
