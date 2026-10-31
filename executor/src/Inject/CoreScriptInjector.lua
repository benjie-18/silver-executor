--[[
  CoreScriptInjector — primary attachment method (2026 core-script bytecode swap).

  Flow (per RE notes, see docs/REVERSE.md):
   1. datamodel -> CoreGui -> CoreScripts -> PlayerListManager (PLM)
   2. datamodel -> CoreGui -> Jest
   3. compile bootstrap bytecode, obtain its address (Memory.compile)
   4. write  Jest.bytecodeInVM     <- bootstrap address
   5. write  PLM.thisInVM          <- Jest instance address
      (PLM's VM "this" now resolves bytecode from Jest — the require of the
       PlayerListManager corescript actually executes OUR bytecode in a core
       script context)
   6. RequireBypass flag <- 1
   7. press ESC twice (opens player-list menu -> triggers the PLM require)
   8. poll shared table for coreEnv capture; restore originals (stealth)
]]
local CS = {}
local SHARED_KEY = "__LX_SHARED__"
local ctx = nil

function CS.shared()
  local g = getgenv()
  if not g[SHARED_KEY] then g[SHARED_KEY] = {} end
  return g[SHARED_KEY]
end

-- bootstrap runs inside the hijacked require; captures the core env + core scripts
local BOOT_SRC = [[
local shared = shared or (getrenv and getrenv() or {})
shared.__LX_SHARED__ = shared.__LX_SHARED__ or {}
shared.__LX_SHARED__.coreEnv = getfenv(0)
local ok, cs = pcall(function() return getrenv().CoreScripts end)
shared.__LX_SHARED__.coreScripts = ok and cs or nil
shared.__LX_SHARED__.attached = os.time()
]]

function CS.resolveJestAndPlm()
  local cg = game and game:FindFirstChildOfClass("CoreGui")
  local jest = nil
  if type(getjest) == "function" then
    local ok, v = pcall(getjest)
    if ok then jest = v end
  end
  if not jest and cg then jest = cg:FindFirstChild("Jest") end
  local coreScripts = cg and cg:FindFirstChild("CoreScripts")
  local plm = coreScripts and coreScripts:FindFirstChild("PlayerListManager")
  return jest, plm
end

function CS.pressEscTwice(cfg)
  local ok = pcall(function()
    local UIS = game:GetService("UserInputService")
    local K = Enum.KeyCode.Escape
    UIS:KeyDown(K)
    UIS:KeyUp(K)
    task.wait((cfg.escIntervalMs or 450) / 1000)
    UIS:KeyDown(K)
    UIS:KeyUp(K)
  end)
  if not ok then
    ctx.log("system", "ESC simulation failed — open the player list menu (ESC x2) manually")
  end
end

function CS.perform(log, cfg, mem, offsets)
  ctx = { log = log, cfg = cfg, mem = mem, off = offsets }
  local jest, plm = CS.resolveJestAndPlm()
  if not (jest and plm) then
    return false, "CoreGui/CoreScripts/PlayerListManager/Jest not found in this datamodel"
  end
  if mem.supports() == "none" then
    return false, "no memory bridge available (injector required)"
  end
  local bootAddr = mem.compile(BOOT_SRC)
  if not bootAddr then
    return false, "no bytecode compile path (toaddress/getaddress/bridge)"
  end
  local plmAddr, jestAddr = mem.instanceAddress(plm), mem.instanceAddress(jest)
  if not (plmAddr and jestAddr) then
    return false, "could not resolve instance addresses (PLM/Jest)"
  end
  local o = offsets.values

  local origBC = mem.readPointer(jestAddr + o.bytecodeInVM)
  local origThis = mem.readPointer(plmAddr + o.thisInVM)
  local flagAddr = o.requireBypass
  local origFlag = mem.readDword(flagAddr)

  ctx.log("system", string.format("swap: PLM.this=%x -> Jest=%x, Jest.bytecode=%x (orig %x)",
    plmAddr, jestAddr, bootAddr, origBC))
  mem.writePointer(jestAddr + o.bytecodeInVM, bootAddr)
  mem.writePointer(plmAddr + o.thisInVM, jestAddr)
  mem.writeDword(flagAddr, 1) -- RequireBypass = 1

  CS.pressEscTwice(cfg.inject)

  local pollMs, timeoutMs = cfg.inject.envPollMs, cfg.inject.envPollTimeoutMs
  local waited = 0
  while waited < timeoutMs do
    task.wait(pollMs / 1000)
    waited += pollMs
    if CS.shared().attached then break end
  end

  local ok = cfg.inject.restoreAfterCapture
  if ok then
    mem.writePointer(jestAddr + o.bytecodeInVM, origBC)
    mem.writePointer(plmAddr + o.thisInVM, origThis)
    mem.writeDword(flagAddr, origFlag)
  end

  if CS.shared().attached then
    ctx.log("system", "core-env captured (level-3 attached)"
      .. (ok and " — originals restored (stealth)" or ""))
    return true
  end
  return false, "core-env not captured within " .. timeoutMs .. "ms (ESC x2 / menu?)"
end

return CS
