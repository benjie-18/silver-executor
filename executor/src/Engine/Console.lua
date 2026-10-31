--[[
  Console — real-time output: ring buffer, levels, filters, auto-scroll,
  perf display hook. UI-optional (init with host == nil in tests).
]]
local Util = require(script.Parent.Util)
local Console = {}

local state = {
  lines = {}, maxLines = 1500, autoScroll = true,
  filters = { output = true, warn = true, error = true, system = true, info = true },
  dirty = true, scrollBottom = 0, host = nil, widgets = {}, colW = 7,
  capLast = os.time and os.time() or 0,
}
local LEVEL_COLOR = { output = "text", warn = "warn", error = "err", system = "muted", info = "accent" }
local LEVEL_TAG = { output = "OUT ", warn = "WARN", error = "ERR!", system = "SYS ", info = "INFO" }

local theme = nil
function Console.setTheme(t) theme = t end

function Console.init(host, cfg)
  state.host = host
  state.maxLines = (cfg and cfg.console.maxLines) or state.maxLines
  if not host then return end
  host.Name = "console"
  host.BackgroundColor3 = theme and theme.editor.bg or Color3.fromRGB(15, 17, 21)
  -- header
  local header = Instance.new("Frame", host)
  header.Name = "header"; header.BackgroundColor3 = theme.panel
  header.Position = UDim2.fromScale(0, 0); header.Size = UDim2.new(1, 0, 0, 24)
  local title = Instance.new("TextLabel", header)
  title.Name = "title"; title.BackgroundTransparency = 1
  title.Text = "CONSOLE"; title.TextColor3 = theme.muted
  title.Font = Enum.Font.GothamBold; title.TextSize = 12
  title.Position = UDim2.new(0, 8, 0, 0); title.Size = UDim2.new(0, 120, 1, 0)
  title.TextXAlignment = Enum.TextXAlignment.Left
  local vp = Instance.new("Frame", host)
  vp.Name = "vp"; vp.BackgroundColor3 = host.BackgroundColor3
  vp.Position = UDim2.new(0, 0, 0, 24); vp.Size = UDim2.new(1, 0, 1, -24)
  vp.ClipContents = true
  state.vp = vp
  local perf = Instance.new("TextLabel", host)
  perf.Name = "perf"; perf.BackgroundTransparency = 1
  perf.Position = UDim2.new(1, -160, 0, 0); perf.Size = UDim2.new(0, 150, 0, 24)
  perf.Text = ""; perf.TextColor3 = theme.muted
  perf.Font = Enum.Font.Code; perf.TextSize = 11
  perf.TextXAlignment = Enum.TextXAlignment.Right
  state.perfLabel = perf
  game:GetService("RunService").Heartbeat:Connect(function()
    if state.dirty and state.vp then Console.render() end
  end)
end

local function visible(level) return state.filters[level] end

function Console.log(level, text)
  if not visible(level) then return end
  table.insert(state.lines, { ts = Util.timestamp(), level = level, text = tostring(text) })
  while #state.lines > state.maxLines do table.remove(state.lines, 1) end
  state.dirty = true
end

function Console.print_(...)
  local args = { ... }
  local parts = {}
  for i = 1, #args do parts[i] = Util.dump(args[i]) end
  Console.log("output", table.concat(parts, " "))
end

function Console.warn_(...)
  local args = { ... }
  local parts = {}
  for i = 1, #args do parts[i] = Util.dump(args[i]) end
  Console.log("warn", table.concat(parts, " "))
end

function Console.error_(msg) Console.log("error", tostring(msg)) end
function Console.logSystem(...) Console.log("system", table.concat({ ... }, " ")) end
function Console.clear() state.lines = {}; state.dirty = true end
function Console.setAutoScroll(v) state.autoScroll = v end
function Console.setFilter(level, on) state.filters[level] = on; state.dirty = true end

function Console.allText()
  local out = {}
  for _, l in state.lines do
    table.insert(out, string.format("[%s] %s %s", l.ts, LEVEL_TAG[l.level], l.text))
  end
  return table.concat(out, "\n")
end

function Console.render()
  state.dirty = false
  local vp = state.vp
  if not vp then return end
  local h = 18
  local n = #state.lines
  local cap = math.floor(vp.AbsoluteSize.Y / h)
  local start = n - cap + 1
  if not state.autoScroll then
    start = n - state.scrollBottom - cap + 1
  end
  start = Util.clamp(start, 1, math.max(1, n - cap + 1))
  local old = state.widgets
  state.widgets = {}
  for i = 1, n do
    if i >= start and i < start + cap then
      local l = state.lines[i]
      local w = old[i] or Instance.new("TextLabel", vp)
      old[i] = nil; state.widgets[i] = w
      w.Position = UDim2.fromOffset(6, (i - start) * h)
      w.Size = UDim2.new(0, vp.AbsoluteSize.X - 12, 0, h)
      w.BackgroundTransparency = 1
      w.TextXAlignment = Enum.TextXAlignment.Left
      w.Font = Enum.Font.Code; w.TextSize = 12
      local colKey = LEVEL_COLOR[l.level]
      w.Text = string.format('<font size="12"><color=%s>%s</color>  <color=%s>%s</color>  %s</font>',
        theme.muted, l.ts, theme[colKey], LEVEL_TAG[l.level],
        Util.escRich(l.text):sub(1, 400))
    end
  end
  for _, w in old do w:Destroy() end
end

function Console.updatePerf(text)
  if state.perfLabel then state.perfLabel.Text = text end
end

return Console
