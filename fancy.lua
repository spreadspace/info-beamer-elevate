local max = math.max
local min = math.min
local cos = math.cos
local sin = math.sin
local exp = math.exp
local PUSH = gl.pushMatrix
local POP = gl.popMatrix
local PI = math.pi
local RADTODEG = 180.0 / 3.14159265359
local DEGTORAD = 3.14159265359 / 180.0
local ROT1 = RADTODEG * PI

local QSIZE = 0.10
local QPOSX, QPOSY = 0.4, 0.3   -- querulant base position [(0,0) = center, (1,1) = bottom right corner]
local QMOVESCALE = 0.20
local QROTSPEED = 1.0

local PILLAR_TOP_GRANULARITY = 0.03   -- top looks better with larger rows (smaller model scale!)
local PILLAR_SIDE_GRANULARITY = 0.002 -- sides are better with smaller rows


local fancy = {}


local function chaos(t)
  return (exp(sin(t*0.22))*exp(cos(t*0.39))*sin(t*0.3));
end

local function queruPos(t)
  local dx = chaos(t * PI)
  local dy = chaos(t * -1.3)
  return QPOSX + QMOVESCALE * dx, QPOSY + QMOVESCALE * dy
end

local function rotaterad(a, ...)
    gl.rotate(RADTODEG * a, ...)
end
local function rotate1(a, ...) -- 0.5 = half rotation, 1 = full rotation
    gl.rotate(ROT1 * a, ...)
end

local function drawqueru(now)
    local ox, oy, x, y = 0.012, 0.01, queruPos(now)
    local s = 1.05
    -- shadow
    -- PUSH()
    --     gl.translate(x+ox, y+oy)
    --     rotate1(QROTSPEED *now, 0, 0, 1)
    --     gl.scale(s, s, s)
    --     gl.translate(QSIZE/-2, QSIZE/-2) -- center rotation point
    --     fancy.res.shadow:draw(0,0,QSIZE,QSIZE)
    -- POP()
    -- querulant
    PUSH()
        gl.translate(x,y)
        rotate1(QROTSPEED * now, 0, 0, 1)
        gl.translate(QSIZE/-2, QSIZE/-2) -- center rotation point
        fancy.res.fancy_bgcolor:draw(0,0,QSIZE,QSIZE)
    POP()
end

local function drawside(tex, ...)
    tex:draw(-0.5,-0.5,0.5,0.5,1, ...)
end


local function drawpillar(tex)
    PUSH()
    gl.scale(0.18, 0.8, 0.18)

        --[[
        PUSH() -- top
            rotate1(0.5, 0, 1, 0)
            rotate1(0.5, 1, 0, 0)
            gl.translate(0, 0, 0.5) -- -0.5 to draw bottom
            drawside(tex)
        POP()
        ]]

        PUSH() -- front
            gl.scale(-1, 1, 1) -- this makes sure the textures line up and corner transition goes nicely
            gl.translate(0, 0, 0.5)
            drawside(tex, 0, 0, 0.5, 1) -- first half of X-axis UV-coord space
        POP()

        PUSH() -- side
            rotate1(0.5, 0, 1, 0)
            gl.translate(0, 0, -0.5)
            drawside(tex, 0.5, 0, 1, 1)  -- second half of X-axis UV-coord space
        POP()
    POP()
end

local function stripe(tex, rot, cx, cy, ox, oy, sx, sy)
    PUSH()
        gl.translate(cx, cy)
        rotate1(rot, 0, 0, 1)
        gl.translate(ox, oy)
        gl.scale(sx or 0.13, sy or 0.5)
        drawside(tex, 0.5, 0, 1, 1)  -- second half of X-axis UV-coord space
    POP()
end

-- test function to try good looking rotation parameters...
local function lolpillar(tex, now, xo, yo, twist)
    twist = twist or 0.2
    local onow = now + xo
    local s, s2, c = sin(onow), sin(onow*0.5), cos(onow*0.66)
    local sslow = sin(now*0.2 + xo*5)
    local stw = cos(onow*0.66 + xo*3.3)*0.03 + twist + 0.03*sin(now*0.13 + 5*xo)
    PUSH()
        gl.translate(xo, yo, 0)
        gl.translate(0, 0.06*sslow + 0.42 + 0.031*chaos((now+(10*yo))*0.4), 0)
        rotate1(-0.05, 0, 0, 1)       -- tilt left/right / roll
        rotate1(0.01*c-0.1, -1, 1, 0) -- tilt to viewer / pitch
        rotate1(stw, 0, 1, 0)  -- twist / yaw
        local ss = s * 0.01 + 1.5
        gl.scale(ss, ss, ss)
        drawpillar(tex)
    POP()
end

local function drawpillars(now)
    local res = fancy.res
    res.fancy_pillar:use{time=now}

    lolpillar(res.fancy_noise, now,  -0.45,   0.6,  0.33)
    --lolpillar(res.noise6, now,  0.4,   -0.12,  0.33)
    lolpillar(res.fancy_noise1, now,  0.3,   0.08,  0.2)
    --lolpillar(res.noise, now,  0.0,   -0.05,  0.5)
    lolpillar(res.fancy_noise3, now, -0.28,   0.35,  0.47)
    lolpillar(res.fancy_noise2, now,  0.1,  0.2,   0.3)
    lolpillar(res.fancy_noise, now,  0.78,  0.1,   0.2)
    lolpillar(res.fancy_noise5d, now,  0.26,   0.6,  0.17)

    lolpillar(res.fancy_noise3, now,  0.63,   0.3,   0.25)
    --lolpillar(res.fancy_noise4, now,  0.7,   0.15,  0.15)
    --lolpillar(res.fancy_noise7, now, -0.15,  0.45,  0.13)
    --lolpillar(res.fancy_noise8a, now,  0.8,   0.3,  0.22)
    --lolpillar(res.fancy_noise1, now,  0.42,   0.5,  0.42)



    local slownow = 0.3*now

    --stripe(res.noise8a, -0.05, -0.25, 0.3, 0, 0.03*sin(slownow))
    stripe(res.fancy_noise8a, -0.05, -0.25, 0.5, 0, 0.03*sin(slownow+0.7))
    stripe(res.fancy_noise8a, -0.05, -0.45, 0.7, 0, 0.03*sin(slownow+1.4))

    stripe(res.fancy_noise8a, -0.05, 0.18, 0.4, 0, 0.03*sin(slownow))
    stripe(res.fancy_noise8a, -0.05, 0.4, 0.45, 0, 0.03*sin(slownow+0.7))
    stripe(res.fancy_noise8a, -0.05, 0.62, 0.5, 0, 0.03*sin(slownow+1.4))


    res.fancy_pillar:deactivate()
end


-- modes: "minimal", fancy".
function fancy.render(mode)
    local aspect = WIDTH / HEIGHT
    local now = sys.now()
    
    if mode == "fancy" then
        local fov = math.atan2(HEIGHT, WIDTH*2) * 360 / math.pi
        gl.perspective(fov, WIDTH/2, HEIGHT/2, -WIDTH,
                        WIDTH/2, HEIGHT/2, 0)

        gl.translate(WIDTH/2, HEIGHT/2)
        gl.scale(WIDTH * (1/aspect), HEIGHT)
        drawpillars(now)
    end

    if mode == "fancy" or mode == "minimal" then
        gl.ortho()
        gl.translate(WIDTH/2, HEIGHT/2)
        gl.scale(WIDTH * (1/aspect), HEIGHT)
        drawqueru(now)
    end
end

return fancy
