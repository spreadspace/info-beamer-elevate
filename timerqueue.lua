-------------------------------------------------------------------------------
--- Class

local TimerQueue = {}
TimerQueue.__index = TimerQueue


-------------------------------------------------------------------------------
--- Constructor

function TimerQueue.new()
    local self = {
        _tq_lock = 0,
        _jobs = 0
    }
    return setmetatable(self, TimerQueue)
end


-------------------------------------------------------------------------------
--- Member Functions

function TimerQueue:push(delay, func, ...)
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
    table.insert(targ, {f = func, t = delay, n = select("#", ...), ... } )
    self._jobs = self._jobs + 1
end

-- compact tq[1...X] into tq[1]
function TimerQueue:_compact()
    if self._tq_lock == 0 and #self > 1 then
        local targ = self[1] -- must exist
        for qi, tq in pairs(self) do
            if type(qi) == "number" and qi > 1 then -- skip tq[1]
                for _,e in pairs(tq) do
                    table.insert(targ, e)
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
function TimerQueue:update(dt)
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


-------------------------------------------------------------------------------

return TimerQueue
