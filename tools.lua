-------------------------------------------------------------------------------
--- generic tools

-- register self
local tools = rawget(_G, "tools")
if not tools then
    tools = {}
    rawset(_G, "tools", tools)
end


local _autoextendmeta0 =
{
    __index = function(t, k)
        local ret = {}
        t[k] = ret
        return ret
    end
}
local _autoextendmeta1 =
{
    __index = function(t, k)
        local ret = setmetatable({}, _autoextendmeta0)
        t[k] = ret
        return ret
    end
}

function tools.newAutoExtendTable()
    return setmetatable({}, _autoextendmeta1)
end

function tools.createLookupTable(list)
    local lut = {}
    for _, element in pairs(list) do
        lut[element.id] = element
    end
    return lut
end


function tools.fixAspect()
    gl.scale(1 / (DISPLAY_ASPECT / NATIVE_ASPECT), 1)
end

function tools.RelPosToScreen(x, y)
    return x * DISPLAY_WIDTH, y and y * DISPLAY_HEIGHT
end

function tools.RelSizeToScreen(sz)
    return sz * DISPLAY_HEIGHT
end

function tools.ScreenPosToRel(x, y)
    return x / DISPLAY_WIDTH, y and y / DISPLAY_HEIGHT
end

function tools.ScreenSizeToRel(sz)
    return sz / DISPLAY_HEIGHT
end

-- takes sz in resolution-independent coords
-- sz == 0.5 -> half as high as the screen
function tools.textWidth(font, text, sz)
    local h = tools.RelSizeToScreen(sz)
    local w = font:width(text, h)
    return tools.ScreenPosToRel(w)
end

function tools.timeColonOffset(font, time, sz)
    local hours, _ = time:match("(%d+):(%d+)")
    if not hours then h = '--' end

    local wh = tools.textWidth(font, hours, sz)
    local wc = tools.textWidth(font, ":", sz)
    return wh + (wc * 0.5)
end

-- takes x, y, sz in resolution-independent coords
-- (0, 0) = upper left corner, (1, 1) = lower right corner
-- sz == 0.5 -> half as high as the screen
function tools.drawText(font, x, y, text, sz, fgcol, bgcol, padding)
    local xS, yS  = tools.RelPosToScreen(x, y)
    local h = tools.RelSizeToScreen(sz)

    if bgcol and bgcol.a > 0 and padding then
        local w = font:width(text, h)
        local b = tools.RelSizeToScreen(padding)
        local bgtex = tools.getColorTex(bgcol)
        bgtex:draw(xS-b, yS-b, xS+w+b, yS+h+b)
    end
    font:write(xS, yS, text, h, fgcol:rgba())
end

local SHADOW = resource.create_colored_texture(0,0,0, 0.1)

-- takes x1, y1, x2, y2 in resolution-independent coords
-- (0, 0) = upper left corner, (1, 1) = lower right corner
function tools.drawResource(res, x1, y1, x2, y2)
    gl.pushMatrix()
        gl.scale(DISPLAY_WIDTH, DISPLAY_HEIGHT)
        -- SHADOW:draw(x1, y1, x2, y2)
        res:draw(x1, y1, x2, y2)
    gl.popMatrix()
end


function tools.debugPrint(lvl, ...)
   if _DEBUG_ and _DEBUG_ >= lvl then
      print(...)
   end
end

function tools.debugDraw(lvl, draw, ...)
   if _DEBUG_ and _DEBUG_ >= lvl then
      draw(...)
   end
end


-- return colored single-pixel texture with caching
local _colorTex = setmetatable({}, { __mode = "kv" })

function tools.getColorTex(col)
    assert(col, "COLOR MISSING")
    local tex = _colorTex[col]
    if not tex then
        tex = resource.create_colored_texture(col.rgba())
        _colorTex[col] = tex
    end
    assert(tex, "OOPS - TEX MISSING")
    return tex
end

function tools.clearColorTex()
    table.clear(_colorTex)
end


-------------------------------------------------------------------------------
--- extend string class

function string.fwrap(str, font, sz, max)
    local h = tools.RelSizeToScreen(sz)
    local wAvail = tools.RelPosToScreen(max)
    str = str:match("(.-)%\n*$") -- kill trailing newlines

    local x = 0
    local x0 = x
    -- always allow wrapping after punctuation chars
    local wrapped = str:gsub("(%s*)([^%s%-%,%.%;%:%/]*[%-%,%.%;%:%/]*)", function(sp, word)
        local ws = font:width(sp, h)
        local ww = font:width(word, h)
        x = x + ws + ww
        if x > wAvail or sp:find("\n", 1, true) then -- always wrap when there's a newline
            x = x0 + ww
            return "\n"..word
        end
    end)
    local splitted = {}
    for token in string.gmatch(wrapped, "[^\n]+") do
        splitted[#splitted + 1] = token
    end
    return splitted
end


-------------------------------------------------------------------------------
--- extend table class

function table.shallowcopy(t)
    local tt = {}
    for k, v in pairs(t) do
        tt[k] = v
    end
    return tt
end

function table.clear(t)
    for k in pairs(t) do
        t[k] = nil
    end
    return t
end


-------------------------------------------------------------------------------

print("tools.lua loaded completely")
return tools
