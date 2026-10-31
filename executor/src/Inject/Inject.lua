--[[
  Inject — attachment orchestrator: core-script swap first, thread-hijack fallback.
  Exposes shared core-env to the rest of the app after success.
]]
local CS = require(script.Parent.CoreScriptInjector)
local TH = require(script.Parent.ThreadHijackInjector)
local Memory = require(script.Parent.Memory)
local Offsets = require(script.Parent.Offsets)

-- bind the shared-key helper TH uses (avoids circular require)
TH.CS_SHARED = function() return "__LX_SHARED__" end

local Inject = {}
local state = { status = "idle", method = nil, detail = nil }
local deps = nil

function Inject.init(log, cfg)
  deps = { log = log, cfg = cfg }
end

function Inject.perform()
  state = { status = "running", method = nil, detail = nil }
  local log = deps.log
  local off = Offsets.current()

  if not off.known then
    log("warn", "offsets unknown — attempting fetch…")
    local ok, info = Offsets.fetch()
    if not ok then
      log("system", "offset fetch: " .. tostring(info))
    else
      log("system", "offsets fetched (build " .. Offsets.current().buildId .. ")")
    end
    off = Offsets.current()
  end
  if not off.known then
    log("warn", "continuing with bridge-supplied offsets (Memory must provide them)")
  end

  local ok, err = pcall(CS.perform, log, deps.cfg, Memory, off)
  if ok then
    state.method = "corescript"
    state.status = "attached"
  else
    log("warn", "core-script path failed: " .. tostring(err))
    local ok2, err2 = pcall(TH.perform, log, deps.cfg, Memory, off)
    if ok2 then
      state.method = "threadhijack"
      state.status = "attached"
    else
      log("error", "thread-hijack failed: " .. tostring(err2))
      state.status = "failed"
      state.detail = tostring(err2)
    end
  end
  return state.status == "attached"
end

function Inject.getCoreEnv()
  local g = getgenv()
  local s = g and g.__LX_SHARED__
  return s and s.coreEnv or nil
end

function Inject.getState() return state end

return Inject
