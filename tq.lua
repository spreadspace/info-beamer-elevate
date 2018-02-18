-- timerqueue module
-- for delayed function calls

local tins = table.insert
local type = type
local error = error
local pairs = pairs
local ipairs = ipairs
local unpack = unpack
local setmetatable = setmetatable
local cowrap = coroutine.wrap
local costatus = coroutine.status

local M = {}
M.__index = M

function M:push(delay, func, ...)
    if type(delay) ~= "number" then
        error("TQ: param 1: expected number, got " .. type(delay))
    end
    if type(func) ~= "function" then
        error("TQ: param 2: expected function, got " .. type(func))
    end
    
    local targ = self[self._tq_lock+1]
    if not targ then
        targ = {}
        self[self._tq_lock+1] = targ
    end
    tins(targ, {f = func, t = delay, n = select("#", ...), ... } )
    self._jobs = self._jobs + 1
end

-- compact tq[1...X] into tq[1]
function M:_compact()
    if self._tq_lock == 0 and #self > 1 then
        local targ = self[1] -- must exist
        for qi, tq in pairs(self) do
            if type(qi) == "number" and qi > 1 then -- skip tq[1]
                for _,e in pairs(tq) do
                    tins(targ, e)
                end
                self[qi] = nil
            end
        end
    end
end


-- re-entrant update function
-- that means calling wait()/watch() in a TQ callback is allowed,
-- and calling pushTQ() from a callback is no problem either.
-- (taking care of not adding entries to any table that is currently iterated over)
-- Lua docs say removing elems while iterating is okay.
function M:update(dt)
    if not self[1] then return end
    
    self._tq_lock = self._tq_lock + 1
    
    for qi, tq in pairs(self) do
        if type(qi) == "number" then
            for i,e in pairs(tq) do
                if e.t < dt then
                    tq[i] = nil
                    self._jobs = self._jobs - 1
                    e.f(unpack(e, 1, e.n))
                else
                    e.t = e.t - dt
                end
            end
        end
    end 
    
    self._tq_lock = self._tq_lock - 1
    
    self:_compact()
end

function M:isEmpty()
    return self._jobs <= 0
end

function M:clear()
    for i = 1, #self do
        self[i] = nil
    end
end

local function _coroTick(tq, co, timepassed, ...)
    local wait
    if not timepassed then -- first call?
        wait = co(...)
        timepassed = 0
    else
        wait = co(timepassed)
    end
    
    if not wait then
        -- done here
    elseif type(wait) == "number" then
        tq:push(wait, _coroTick,
            tq, co, timepassed + wait)
    else
        error("TQ:launch: Unable to deal with return type (" .. type(wait).. "), value [" 
            .. tostring(wait) .. "]. Return/yield nil, false, or a number!")
    end
end

function M:launch(delay, f, ...)
    assert(type(delay) == "number", "param #1 must be number")
    
    local co = cowrap(f)
    self:push(delay, _coroTick,
        self, co, false, ...)
end

local function tq_create()
    return setmetatable({ _tq_lock = 0, _jobs = 0 }, M)
end

return tq_create
