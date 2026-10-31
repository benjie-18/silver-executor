-- Execution uses a host-provided compiler. It does not inject or bypass Roblox permissions.
local Execution = {}
Execution.__index = Execution
function Execution.new(console, compiler, scheduler)
    return setmetatable({console = console, compiler = compiler, scheduler = scheduler,
        state = "idle", generation = 0}, Execution)
end
function Execution:run(source, name)
    if self.state == "running" then return false, "already running" end
    if type(self.compiler) ~= "function" then return false, "loadstring unavailable in this host" end
    local ok, fn, err = pcall(self.compiler, source, name or "silver")
    if not ok then err = fn end
    if not ok or type(fn) ~= "function" then
        self.state = "error"
        self.console:log("error", "compile: " .. tostring(err))
        return false, err
    end
    self.generation += 1
    local generation = self.generation
    self.state = "running"
    local function work()
        local success, message = pcall(fn)
        if self.generation ~= generation then return end
        self.state = success and "finished" or "error"
        if not success then self.console:log("error", "runtime: " .. tostring(message))
        else self.console:log("system", "finished") end
    end
    if self.scheduler then
        local scheduled, worker = pcall(self.scheduler, work)
        if not scheduled then
            self.state = "error"
            self.console:log("error", "schedule: " .. tostring(worker))
            return false, worker
        end
        self.worker = worker
    else
        work()
    end
    return true
end
function Execution:stop()
    if self.state ~= "running" then return false end
    self.generation += 1
    if self.worker and task and task.cancel then pcall(task.cancel, self.worker) end
    self.worker = nil
    self.state = "stopped"
    self.console:log("system", "stopped (spawned work and external side effects may continue)")
    return true
end
return Execution
