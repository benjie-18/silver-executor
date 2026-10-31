--[[
  Clipboard — ladder: setclipboard/readclipboard (executor) → internal buffer.
  Roblox readclipboard has a ~1.5s cooldown; we honor it and retry once.
]]
local Clipboard = {}
local internal = { text = nil }
local lastRead = 0

function Clipboard.init()
  internal.text = nil
end

function Clipboard.copy(text)
  internal.text = text
  if type(setclipboard) == "function" then
    pcall(setclipboard, text)
  end
end

function Clipboard.paste()
  if type(readclipboard) == "function" then
    local function try()
      local ok, v = pcall(readclipboard)
      return ok and v or nil
    end
    local now = os.clock()
    if now - lastRead < 1.5 then
      task.wait(1.55 - (now - lastRead))
    end
    lastRead = os.clock()
    local v = try()
    if v and v ~= "" then return v end
    task.wait(0.15)
    v = try()
    if v and v ~= "" then return v end
  end
  return internal.text
end

function Clipboard.get() return internal.text end
function Clipboard.set(text) Clipboard.copy(text) end

return Clipboard
