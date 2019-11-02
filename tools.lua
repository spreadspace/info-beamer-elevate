function string.fwrap(str, font, h, xpos, width)
    width = width or WIDTH
    xpos = xpos or 0
    local xstart = xpos
    -- always allow wrapping after punctuation chars
    str = str:match("(.-)%\n*$") -- kill trailing newlines
    local wrapped = str:gsub("(%s*)([^%s%-%,%.%;%:%/]*[%-%,%.%;%:%/]*)", function(sp, word)
        local ws = font:width(sp, h)
        local ww = font:width(word, h)
        xpos = xpos + ws + ww
        if xpos > width or sp:find("\n", 1, true) then -- always wrap when there's a newline
            xpos = xstart + ww
            return "\n"..word
        end
    end)
    local splitted = {}
    for token in string.gmatch(wrapped, "[^\n]+") do
        splitted[#splitted + 1] = token
    end
    return splitted
end

-- scale t from [lower, upper] into [rangeMin, rangeMax]
function math.rescale(t, lower, upper, rangeMin, rangeMax)
    if upper == lower then
        return rangeMin
    end

    return (((t - lower) / (upper - lower)) * (rangeMax - rangeMin)) + rangeMin
end

function table.clear(t)
    for k in pairs(t) do
        t[k] = nil
    end
    return t
end


-- register self
local tools = rawget(_G, "tools")
if not tools then
    tools = {}
    rawset(_G, "tools", tools)
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

print("tools.lua loaded completely")
return tools
