--[[
  Offsets — offset database + remote fetch + schema validation.
  Endpoint: https://offsets.ntgetwritewatch.workers.dev/offsets.hpp
  Accepts JSON ({ "buildId": "...", "datamodel": "0x.." , ... }) or .hpp-style
  C++ text ("datamodel = 0x1F40;", "#define datamodel 0x1F40").
  Values are float64-exact below 2^53. `known=false` until validated load.
]]
local Util = require(script.Parent.Util)
local Offsets = {}

local URL = "https://offsets.ntgetwritewatch.workers.dev/offsets.hpp"

local SCHEMA = {
  -- name             meaning (see docs/REVERSE.md for the full RE writeup)
  datamodel        = "qword", -- absolute DataModel pointer
  scriptContext    = "dword", -- DataModel + off -> ScriptContext*
  vmInScript       = "qword", -- script instance -> its VM script object
  bytecodeInVM     = "qword", -- VM script -> CompiledFunction*
  thisInVM         = "qword", -- VM script -> this-pointer (script instance)
  requireBypass    = "qword", -- absolute address of 1-byte RequireBypass flag
  threadList       = "qword", -- ScriptContext + off -> thread list head
  threadStride     = "dword", -- thread entry stride
  bytecodeInThread = "qword", -- thread entry -> bytecode slot
  ipInThread       = "dword", -- thread entry -> instruction pointer
  threadName       = "dword", -- thread entry -> name string
}

local db = { known = false, buildId = "", values = {} }
local storage = nil

function Offsets.init(storageTable)
  storage = storageTable
  local g = getgenv and getgenv() or nil
  if type(g) == "table" and type(g.__LX_OFFSETS__) == "table" then
    local ok, r = pcall(function()
      local cand = g.__LX_OFFSETS__
      local values = {}
      for k, v in pairs(cand) do
        if SCHEMA[k] then values[k] = v end
      end
      local missing = Offsets.verify(values)
      if #missing == 0 then
        db = { known = true, buildId = cand.buildId or "", values = values }
      end
    end)
  end
end

-- @return number of missing/invalid keys, list
function Offsets.verify(values)
  values = values or {}
  local missing = {}
  for k in pairs(SCHEMA) do
    local v = values[k]
    if type(v) ~= "number" or v == 0 or math.abs(v) > 2 ^ 53 then
      table.insert(missing, k)
    end
  end
  return #missing, missing
end

function Offsets.applyCandidate(cand)
  local values = {}
  for k, v in pairs(cand) do
    if SCHEMA[k] then values[k] = Util.parseHex(v) end
  end
  local okc = Offsets.verify(values)
  okc = #okc == 0
  if okc then
    db = { known = true, buildId = tostring(cand.buildId or cand.build or ""), values = values }
    if type(storage) == "table" and type(getgenv()) == "table" then
      getgenv().__LX_OFFSETS__ = { buildId = db.buildId }
      for k, v in pairs(values) do getgenv().__LX_OFFSETS__[k] = v end
    end
  end
  return okc
end

-- parse C++/.hpp style: `name = 0xHEX;` / `#define name 0xHEX` / `name: 0xHEX`
function Offsets.fromHpp(text)
  local out = {}
  for name, hex in string.gmatch(text, "([%a_][%w_]*)%s*=?%s*0x([%x]+)") do
    out[name] = hex
  end
  for name, hex in string.gmatch(text, "#define%s+([%a_][%w_]*)%s+0x([%x]+)") do
    out[name] = hex
  end
  local b = string.match(text:lower(), "buildid%s*=?%s*[\"']?([%d%w%.%-]+)")
    or string.match(text:lower(), '"?build"?%s*[%=%"]+%s*([%d%w%.%-]+)')
  out.buildId = b
  return out
end

function Offsets.fromJson(str)
  local ok, t = pcall(function()
    return game:GetService("HttpService"):JSONDecode(str)
  end)
  if ok and type(t) == "table" then
    local out = {}
    for k, v in pairs(t) do
      if type(v) == "string" or type(v) == "number" then out[k] = tostring(v) end
    end
    if type(t.offsets) == "table" then
      for k, v in pairs(t.offsets) do
        if type(v) == "string" or type(v) == "number" then out[k] = tostring(v) end
      end
    end
    return out
  end
  return Offsets.fromHpp(str)
end

function Offsets.loadText(text)
  local out = nil
  local first = string.match(text:sub(1, 4096):lower(), "^%s*[{\[]")
  if first then out = Offsets.fromJson(text) else out = Offsets.fromHpp(text) end
  return Offsets.applyCandidate(out) and true or false
end

function Offsets.fetch()
  local ok, res = pcall(function()
    return game:GetService("HttpService"):GetAsync(URL, true)
  end)
  if ok and type(res) == "string" and #res > 0 then
    local good = Offsets.loadText(res)
    return good, good and "fetched" or "parse failed"
  end
  return false, ok and "parse failed" or ("fetch failed: " .. tostring(res))
end

function Offsets.current() return db end

function Offsets.buildInfo()
  local ok, v = pcall(function() return game:GetService("VersionPlaceId") end)
  if ok and type(v) == "number" then return v end
  if VersionInfo and type(VersionInfo) == "table" then
    return (VersionInfo.Version or {}) .BuildId or nil
  end
  return nil
end

return Offsets
