-------------------------------------------------------------------------------
--- Constants (configuration)

local DEFAULT_BG_COLOR = {rgba = function() return 0.5, 0.5, 0.5, 1 end}
local DEFAULT_FG_COLOR = {rgba = function() return 1, 0, 0, 1 end}
local DEFAULT_FONT = CONFIG.font
local DEFAULT_TEXT = "UNKNOWN BACKGROUND STYLE"
local DEFAULT_TEXTSIZE = 0.1


-------------------------------------------------------------------------------
--- Class

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

local function setupStaticBackground(self)
    local image = CONFIG.background_static
    tools.debugPrint(2, "background: loading image " .. image.asset_name)
    image.load()

    self._draw = function()
        -- we assume the image already has the correct aspect ratio
        image.draw(0, 0, NATIVE_WIDTH, NATIVE_HEIGHT)
    end

    self._cleanup = function()
        tools.debugPrint(2, "background: unloading image " .. image.asset_name)
        image.unload()
    end

    self._updateNeeded = function()
        return image.asset_name ~= CONFIG.background_static.asset_name
    end
end

local function setupVideoBackground(self)
    local video = CONFIG.background_video
    tools.debugPrint(2, "background: loading video " .. video.asset_name)
    video.load({ loop=true, raw=true, layer=-1 })

    self._draw = function()
        -- we assume the video already has the correct aspect ratio
        video.draw(0, 0, NATIVE_WIDTH, NATIVE_HEIGHT)
    end

    self._cleanup = function()
        tools.debugPrint(2, "background: unloading video " .. video.asset_name)
        video.unload()
    end

    self._updateNeeded = function()
        return video.asset_name ~= CONFIG.background_video.asset_name
    end
end

local function setupBackground(self, style)
    self._draw = nil
    self._cleanup = nil
    self._updateNeeded = nil

    local fancymode = style:match("^fancy%-(.*)$")
    if style == "static" then
        setupStaticBackground(self)
    elseif style == "video" then
        setupVideoBackground(self)
    elseif fancymode then
        local fancy = require "fancy"
        fancy.fixaspect = tools.fixAspect
        self._draw = function()
            fancy.render(fancymode)
        end
    else
        tools.debugPrint(1, "WARNING: invalid background style: " .. style)
        return
    end

    tools.debugPrint(1, "background style is now: " .. style)
end


-------------------------------------------------------------------------------
--- Constructor

function Background.new(style)
    local self = {
        style = style,
        _draw = nil,
        _cleanup = nil,
        _check = nil
    }
    if style then setupBackground(self, style) end
    return setmetatable(self, Background)
end


-------------------------------------------------------------------------------
--- Member Functions

function Background:update(style)
    if style ~= self.style or (self._updateNeeded and self._updateNeeded()) then
        self:cleanup()
        setupBackground(self, style)
        self.style = style
    end
end

function Background:cleanup()
    if self._cleanup then
        self._cleanup()
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
