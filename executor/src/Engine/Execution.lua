--[[
  Execution — compile, sandbox, run, cancel, reset, timeout, perf.
  Isolation: loadstring(src, name, "t", env) where env is a private table with
  __index = base env (read fallthrough) and __newindex = rawset into env, so
  user globals never leak into the script env (unless isolate = false).
  Cancellation: env wait/task.wait shims check a flag; stop() also task.cancel's
  the worker and every spawned child.
]]
local Util = require(script.Parent.Util)
local Console = require(script.Parent.Console)
local Execution = {}

local S = {
  status = "idle", statusText = "Idle", running = false,
  started = 0, elapsed = 0, frames = 0, gcBase = 0,
  worker = nil, watchdog = nil, children = {}, cancelled = false,
  timeoutMs = 30000, isolate = true,
}
local deps = nil

function Execution.init(cfg)
  deps = { cfg = cfg }
  S.timeoutMs = cfg.timeoutMs
  S.isolate = cfg.isolate
end

function Execution.buildEnv()
  local base = getfenv(0)
  local env
  if S.isolate then
    env = setmetatable({}, {
      __index = function(_, k) return base[k] end,
      __newindex = function(t, k, v) rawset(t, k, v) end,
    })
    -- seed commonly-expected globals explicitly
    for k, v in pairs(base) do
      rawset(env, k, v)
    end
    -- drop the seeds that shadowing would fight: nothing special; __index covers it
  else
    env = base
  end

  local g = env
  g.print = function(...) Console.print_(...) end
  g.warn = function(...) Console.warn_(...) end
  g.error = function(msg, level)
    Console.error_(msg)
    return error(msg, level and level + 1 or 2)
  end

  local function waitShim(...)
    local r = { task.wait(...) }
    if S.cancelled then
      S.cancelled = false
      return error("ExecutorCancelled", 0)
    end
    if #r == 0 then return end
    if #r == 1 then return r[1] end
    return table.unpack(r)
  end
  g.wait = waitShim
  local t = {}
  for k, v in pairs(task) do t[k] = v end
  t.wait = waitShim
  t.delay = function(n, fn)
    local co = task.spawn(function() task.wait(n) fn() end)
    table.insert(S.children, co)
    return co
  end
  t.spawn = function(fn)
    local co = task.spawn(fn)
    table.insert(S.children, co)
    return co
  end
  g.task = t
  g.spawn = t.spawn
  g.delay = t.delay
  return env
end

function Execution.run(source, name)
  if S.running then return false, "already running" end
  local env = Execution.buildEnv()
  local fn, err = loadstring(source, name or "executor_user", "t", env)
  if not fn then
    Console.error_("compile: " .. tostring(err))
    S.status = "error"; S.statusText = "Compile error"
    return false, err
  end
  S.running = true
  S.cancelled = false
  S.status = "running"; S.statusText = "Running"
  S.started = os.clock()
  S.frames = 0
  S.gcBase = gcinfo and gcinfo("count") or 0
  S.children = {}

  S.worker = task.spawn(function()
    local ok, r = pcall(fn)
    if S.running then
      S.running = false
      S.elapsed = (os.clock() - S.started) * 1000
      if ok then
        S.status = "finished"; S.statusText = "Done"
        Console.logSystem(string.format("finished in %s — %d frames",
          Util.fmtMs(S.elapsed), S.frames))
      else
        S.status = "error"; S.statusText = "Runtime error"
        Console.error_("runtime: " .. tostring(r))
      end
      for _, co in S.children do pcall(task.cancel, co) end
      S.children = {}
    end
  end)

  if S.timeoutMs > 0 then
    S.watchdog = task.spawn(function()
      while S.running do
        task.wait(0.1)
        if S.running and (os.clock() - S.started) * 1000 > S.timeoutMs then
          Execution.stop()
          S.status = "timeout"; S.statusText = "Timeout"
          Console.logSystem(string.format("timeout after %d ms", S.timeoutMs))
        end
      end
    end)
  end
  return true
end

function Execution.stop()
  if not S.running then return end
  S.cancelled = true
  if S.worker then pcall(task.cancel, S.worker) end
  for _, co in S.children do pcall(task.cancel, co) end
  if S.watchdog then pcall(task.cancel, S.watchdog) end
  if S.status == "running" then
    S.status = "cancelled"; S.statusText = "Stopped"
    Console.logSystem("stopped by user")
  end
  S.running = false
end

function Execution.reset()
  Execution.stop()
  Console.clear()
  if gc and gc then pcall(gc, "collect") end
  S.status = "idle"; S.statusText = "Idle"
end

function Execution.tickFrames()
  if S.running then S.frames += 1 end
end

function Execution.perfString()
  if not S.running then
    return S.elapsed and Util.fmtMs(S.elapsed) or ""
  end
  local gcNow = gcinfo and gcinfo("count") or 0
  return string.format("%s | %d fr | %s gc",
    Util.fmtMs((os.clock() - S.started) * 1000), S.frames,
    Util.fmtBytes(math.max(0, gcNow - S.gcBase) * 1024))
end

function Execution.getState() return S end

return Execution
