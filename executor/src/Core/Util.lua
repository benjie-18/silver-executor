--[[
  Util — shared helpers. No hard Roblox dependency (typeof/os guarded).
]]
local Util = {}

function Util.clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

function Util.deepCopy(v)
  if type(v) ~= "table" then return v end
  local out = {}
  for k, val in pairs(v) do out[Util.deepCopy(k)] = Util.deepCopy(val) end
  return out
end

-- deep merge src into dst (tables only), returns dst
function Util.merge(dst, src)
  for k, v in pairs(src) do
    if type(v) == "table" and type(dst[k]) == "table" then Util.merge(dst[k], v)
    else dst[k] = Util.deepCopy(v) end
  end
  return dst
end

function Util.splitLines(s)
  return (s:gsub("\r\n", "\n"):gsub("\r", "\n"):split("\n"))
end

local function tableDump(v, depth, seen)
  if seen[v] or depth >= 3 then return "{…}" end
  seen[v] = true
  local parts, n = {}, 0
  for k, val in pairs(v) do
    n += 1
    if n > 5 then break end
    parts[#parts + 1] = (type(k) == "string" and ('"' .. k .. '"') or tostring(k)) .. "=" .. Util.dump(val)
  end
  if n > 5 then parts[#parts + 1] = "…" end
  seen[v] = nil
  return "{" .. table.concat(parts, " ") .. "}"
end

-- pretty-print any value for console output (cycle-safe, depth-limited)
function Util.dump(v)
  local tv = type(v)
  if tv == "table" then return tableDump(v, 1, {}) end
  if tv == "string" then return '"' .. v .. '"' end
  if tv == "function" then return "function" end
  if typeof then
    local ok, t2 = pcall(typeof, v)
    if ok and type(t2) == "string" then
      if t2 == "Vector2"  then return string.format("V2(%.1f, %.1f)", v.X, v.Y) end
      if t2 == "Vector3"  then return string.format("V3(%.1f, %.1f, %.1f)", v.X, v.Y, v.Z) end
      if t2 == "Color3"   then return string.format("C3(%d, %d, %d)",
        math.floor(v.R * 255), math.floor(v.G * 255), math.floor(v.B * 255)) end
    end
  end
  return tostring(v)
end

-- datamodel path of an instance (walk parents; name-collision caveat documented)
function Util.instancePath(inst)
  local parts, cur, guard = {}, inst, 0
  while cur and guard < 40 do
    parts[1] = (cur.Name and cur.Name ~= "" and cur.Name) or cur.ClassName or "Instance"
    cur = cur.Parent
    guard += 1
  end
  return table.concat(parts, ".")
end

function Util.parseHex(s)
  local h = string.match(tostring(s):lower(), "^0x([%x]+)$")
    or string.match(tostring(s):lower(), "^([%x]+)$")
  return h and tonumber(h, 16) or nil
end

function Util.escRich(s)
  return (tostring(s):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

function Util.timestamp()
  return os.date and os.date("%H:%M:%S") or ""
end

function Util.fmtBytes(b)
  if not b then return "0 B" end
  if b < 1024 then return b .. " B" end
  if b < 1024 * 1024 then return string.format("%.1f KB", b / 1024) end
  return string.format("%.2f MB", b / (1024 * 1024))
end

function Util.fmtMs(ms)
  if not ms then return "0 ms" end
  if ms < 1000 then return string.format("%.0f ms", ms) end
  return string.format("%.1f s", ms / 1000)
end

return Util
