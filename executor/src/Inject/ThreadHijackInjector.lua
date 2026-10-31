--[[
  ThreadHijackInjector — fallback attachment (Xeno-style).
  datamodel -> ScriptContext -> thread list; pick first eligible script-context
  thread (skip core-thread denylist + own thread), write compiled bootstrap into
  its bytecode slot, restore after capture. NEVER creates a new thread.
]]
local TH = {}

local BOOT_SRC = (require(script.Parent.CoreScriptInjector).shared ~= nil) and [[
local shared = shared or (getrenv and getrenv() or {})
shared.__LX_SHARED__ = shared.__LX_SHARED__ or {}
shared.__LX_SHARED__.coreEnv = getfenv(0)
local ok, cs = pcall(function() return getrenv().CoreScripts end)
shared.__LX_SHARED__.coreScripts = ok and cs or nil
shared.__LX_SHARED__.attached = os.time()
]] or nil

function TH.perform(log, cfg, mem, offsets)
  local dm = mem.datamodel() or offsets.values.datamodel
  if not dm then return false, "no datamodel address" end
  local o = offsets.values
  local sc = mem.readPointer(dm + o.scriptContext)
  if not sc or sc == 0 then return false, "ScriptContext pointer unreadable" end

  local head = mem.readPointer(sc + o.threadList)
  if not head or head == 0 then return false, "thread list unreadable" end

  local selfId = mem.currentThreadId and mem.currentThreadId()
  local deny = {}
  for _, n in ipairs(cfg.inject.coreThreadDenylist) do deny[n] = true end

  local candidate = nil
  for i = 1, cfg.inject.maxThreadsToScan do
    local t = head + (i - 1) * o.threadStride
    local name = mem.readString and mem.readString(t + o.threadName, 64)
    local id = mem.readPointer(t) -- first qword: thread id/handle
    if deny and deny[tostring(name):gsub("%c$.*$", ""):sub(1, 64)] then
      -- name match (strip NUL tail)
      local clean = tostring(name):gsub("\0.*$", "")
      if deny[clean] or deny[name] then
        continue?
      end
    end
    if (type(id) == "number" and id == selfId) then
      continue
    end
    candidate = t
    break
  end
  if not candidate then return false, "no eligible script-context thread" end

  local orig = mem.readPointer(candidate + o.bytecodeInThread)
  local bootAddr = mem.compile(BOOT_SRC)
  if not bootAddr then return false, "no bytecode compile path" end

  log("system", string.format("hijack thread %x (orig bc %x)", candidate, orig))
  mem.writePointer(candidate + o.bytecodeInThread, bootAddr)
  mem.writeDword(candidate + o.ipInThread, 0)
  if mem.resumeThread then pcall(mem.resumeThread, candidate) end

  local shared = (getgenv()[CS_SHARED()]) or {}
  local waited = 0
  while waited < cfg.inject.envPollTimeoutMs do
    task.wait(cfg.inject.envPollMs / 1000)
    waited += cfg.inject.envPollMs
    if shared.attached then break end
  end

  if cfg.inject.restoreAfterCapture then
    mem.writePointer(candidate + o.bytecodeInThread, orig)
  end
  if shared.attached then
    log("system", "core-env captured via thread hijack")
    return true
  end
  return false, "thread hijack: env not captured"
end

return TH
