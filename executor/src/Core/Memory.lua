--[[
  Memory — low-level memory bridge for the injector.
  Implementation ladder (first available wins):
   1. bridge  — injector exposes a table at getrenv().LX_MEM (or getgenv):
                { read(addr,size)->num, write(addr,val,size), readString(addr,len),
                  instanceAddress(inst)->num, compile(src)->addr, datamodel()->num,
                  currentThreadId(), resumeThread(t) }
   2. native  — executor globals: getint/getdword/getqword, writeint/writeflag,
                toaddress(str)->fn,addr, getaddress(fn)
   3. none    — UI-only mode (in-game fallback)
  Luau numbers are float64; all addresses < 2^53 are exact.
]]
local Memory = {}
local impl = nil

local function wrapBridge(b)
  return {
    kind = "bridge",
    read = function(a, s) return b.read(a, s or 8) end,
    write = function(a, v, s) b.write(a, v, s or 8) end,
    readString = b.readString,
    instanceAddress = b.instanceAddress,
    compile = b.compile,
    datamodel = b.datamodel,
    currentThreadId = b.currentThreadId,
    resumeThread = b.resumeThread,
  }
end

local function wrapNative()
  local readN = { [8] = (getqword and function(a) return getqword(a) end) or (getint and function(a) return
getint(a, 8) end),
                  [4] = getdword and function(a) return getdword(a) end }
  local writeN = { [8] = (writeint and function(a, v) writeint(a, v) end),
                   [4] = (writedword and function(a, v) writedword(a, v) end) or (writeint and function(a, v)
writeint(a, v) end) }
  return {
    kind = "native",
    read = function(a, s) local f = readN[s or 8] return f and f(a) end end,
    write = function(a, v, s) local f = writeN[s or 8] if f then f(a, v) end end,
    readString = getstring and function(a, n) return getstring(a, n) end,
    instanceAddress = function(inst)
      local ok, f, addr = pcall(toaddress, inst)
      if ok and type(addr) == "number" then return addr end
      return nil
    end,
    compile = function(src)
      local ok, f, addr = pcall(function()
        local f2, a2 = toaddress(src)
        return f2, a2
      end)
      if ok and type(addr) == "number" then return addr end
      if getaddress then
        local f2 = loadstring(src)
        local ok2, a2 = pcall(getaddress, f2)
        if ok2 then return a2 end
      end
      return nil
    end,
    datamodel = function() return sharedatamodel end,
    currentThreadId = nil,
    resumeThread = nil,
  }
end

function Memory.init()
  impl = nil
  local env = getrenv and getrenv() or {}
  local g = getgenv and getgenv() or {}
  local bridge = (type(env) == "table" and env.LX_MEM) or (type(g) == "table" and g.LX_MEM)
  if type(bridge) == "table" and bridge.read and bridge.write then
    impl = wrapBridge(bridge)
  elseif type(getint) == "function" or type(getdword) == "function" or writeflag then
    impl = wrapNative()
  else
    impl = { kind = "none", read = function() end, write = function() end }
  end
end

function Memory.supports() return impl and impl.kind or "none" end
function Memory.read(addr, size) return impl.read(addr, size) end
function Memory.write(addr, value, size) impl.write(addr, value, size) end
function Memory.readPointer(a) return impl.read(a, 8) end
function Memory.writePointer(a, v) impl.write(a, v, 8) end
function Memory.readDword(a) return impl.read(a, 4) end
function Memory.writeDword(a, v) impl.write(a, v, 4) end
function Memory.writeFlag(a, v)
  if impl.kind == "bridge" then impl.write(a, v and 1 or 0, 1)
  elseif writeflag then writeflag(a, v and 1 or 0)
  else impl.write(a, v and 1 or 0, 4) end
end
function Memory.compile(src) return impl.compile and impl.compile(src) end
function Memory.datamodel() return impl.datamodel and impl.datamodel() end
function Memory.instanceAddress(inst)
  if impl.instanceAddress then return impl.instanceAddress(inst) end
end
function Memory.readString(addr, len)
  return impl.readString and impl.readString(addr, len)
end

return Memory
