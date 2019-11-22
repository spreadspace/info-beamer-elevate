-------------------------------------------------------------------------------
--- Constants (configuration)

local DEFAULT_BG_COLOR = {rgba = function() return 0.5, 0.5, 0.5, 1 end}
local DEFAULT_FG_COLOR = {rgba = function() return 1, 0, 0, 1 end}
local DEFAULT_FONT = CONFIG.font
local DEFAULT_TEXT = "UNKNOWN BACKGROUND STYLE"
local DEFAULT_TEXTSIZE = 0.1


-------------------------------------------------------------------------------
--- Classes

local Background = {}
Background.__index = Background


-------------------------------------------------------------------------------
--- Helper Functions

local defaultBGcolTex = resource.create_colored_texture(DEFAULT_BG_COLOR.rgba())
local defaultTextWidth = tools.textWidth(DEFAULT_FONT, DEFAULT_TEXT, DEFAULT_TEXTSIZE)
local function drawBGDefault()
    defaultBGcolTex:draw(0, 0, NATIVE_WIDTH, NATIVE_HEIGHT)
    tools.drawText(DEFAULT_FONT, 0.5 - defaultTextWidth/2, 0.5 - DEFAULT_TEXTSIZE/2, DEFAULT_TEXT, DEFAULT_TEXTSIZE, DEFAULT_FG_COLOR)
end


local function setupDraw(self, style)
    local fancymode = style:match("^fancy%-(.*)$")
    if style == "static" then
        self._draw = function()
            local image = CONFIG.background_static.ensure_loaded()
            image:draw(0, 0, NATIVE_WIDTH, NATIVE_HEIGHT) -- we assume the background has the correct aspect ratio
        end
    elseif style == "video" then
        local opts = { loop=true }
        self._draw = function()
            local video = CONFIG.background_video.ensure_loaded(opts)
            -- video place only works on the raspi...
            if video.place then
                video:place(0, 0, NATIVE_WIDTH, NATIVE_HEIGHT)
            else
                video:draw(0, 0, NATIVE_WIDTH, NATIVE_HEIGHT)
            end
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
    if style then setupDraw(self, style) end
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
    else
        drawBGDefault()
    end
end


-------------------------------------------------------------------------------

print("background.lua loaded completely")
return Background
