--[[
  Widgets — TextInput (caret, focus, keys), Button, Menu (popup list).
  Focus model: Widgets.focus.current ∈ { "editor", inputWidgetId, nil }
]]
local Widgets = {}
local Util = require(script.Parent.Util)

Widgets.focus = { current = nil }
local inputs = {}   -- id -> widget record
local uid = 0

local function nextInputId()
  uid += 1
  return uid
end

function Widgets.button(parent, text, opts)
  opts = opts or {}
  local t = opts.theme or Color3.fromRGB(20, 23, 29)
  local b = Instance.new("TextButton", parent)
  b.Name = opts.name or ("btn" .. nextInputId())
  b.Text = text
  b.AutoButtonColor = false
  b.BackgroundColor3 = t.panelAlt
  b.TextColor3 = t.text
  b.Font = Enum.Font.GothamMedium
  b.TextSize = 12
  if opts.pos then b.Position = opts.pos end
  if opts.size then b.Size = opts.size end
  b.CornerRadius = 4
  local corner = Instance.new("UICorner", b)
  corner.CornerRadius = UDim.new(Enum.NumberScale, 4)
  b.MouseEnter:Connect(function() b.BackgroundColor3 = t.panelAlt:lerp(t.accent, 0.25) end)
  b.MouseLeave:Connect(function() b.BackgroundColor3 = t.panelAlt end)
  return b
end

-- opts: {placeholder, value, onChange(text), onEnter(text), theme, size, pos, font="Code"}
function Widgets.input(parent, opts)
  opts = opts or {}
  local t = opts.theme or Color3.fromRGB(20, 23, 29)
  local id = nextInputId()
  local box = Instance.new("Frame", parent)
  box.Name = "input_" .. id
  box.BackgroundColor3 = t.base
  box.BorderSizePixel = 0
  if opts.size then box.Size = opts.size end
  if opts.pos then box.Position = opts.pos end
  local label = Instance.new("TextLabel", box)
  label.Name = "lbl"
  label.BackgroundTransparency = 1
  label.Position = UDim2.new(0, 6, 0, 0); label.Size = UDim2.new(1, -12, 1, 0)
  label.TextXAlignment = Enum.TextXAlignment.Left
  label.Font = Enum.Font.Code
  label.TextSize = 12
  label.TextColor3 = t.text
  box.MouseFilter = Enum.MouseFilterType.Ignore
  label.MouseFilter = Enum.MouseFilterType.Ignore

  local state = { value = opts.value or "", caret = #(opts.value or ""), id = id }
  local rec = {
    id = id, box = box,
    focus = function() Widgets.focus.current = id end,
    blur = function() if Widgets.focus.current == id then Widgets.focus.current = nil end end,
    setText = function(v)
      state.value = tostring(v or "")
      state.caret = #state.value
      _render()
    end,
    getText = function() return state.value end,
    handleKey = function(k, shift)
      -- returns true if consumed
      if k == "Backspace" then
        if state.caret > 0 then
          state.value = state.value:sub(1, state.caret - 1) .. state.value:sub(state.caret + 1)
          state.caret -= 1
        end
      elseif k == "Delete" then
        state.value = state.value:sub(1, state.caret) .. state.value:sub(state.caret + 2)
      elseif k == "Left" then
        state.caret = math.max(0, state.caret - 1)
      elseif k == "Right" then
        state.caret = math.min(#state.value, state.caret + 1)
      elseif k == "Home" then state.caret = 0
      elseif k == "End" then state.caret = #state.value
      elseif k == "Enter" then
        if opts.onEnter then opts.onEnter(state.value) end
      elseif k == "Escape" then
        rec.blur()
      else
        if CHAR_MAP[k] then
          state.value = state.value:sub(1, state.caret) .. CHAR_MAP[k] .. state.value:sub(state.caret + 1)
          state.caret += 1
        end
      end
      if opts.onChange then opts.onChange(state.value) end
      _render()
      return true
    end,
  }

  local function _render()
    local caret = "▏"
    label.Text = state.value:sub(1, state.caret) .. caret .. state.value:sub(state.caret + 1)
    if state.value == "" then label.Text = "▏" end
    if state.value == "" and opts.placeholder then
      label.Text = "▏" .. opts.placeholder
      label.TextColor3 = t.muted
    else
      label.TextColor3 = t.text
    end
  end
  _render()
  box.MouseButton1Click:Connect(function() rec.focus() end)
  inputs[id] = rec
  return rec
end

function Widgets.consumeKey(k, shift)
  local cur = Widgets.focus.current
  if type(cur) == "number" and inputs[cur] then
    return inputs[cur].handleKey(k, shift)
  end
  return false
end

-- CHAR_MAP: KeyCode -> char (no shift) / (shift)
local CHAR_MAP = {
  A="a", B="b", C="c", D="d", E="e", F="f", G="g", H="h", I="i", J="j",
  K="k", L="l", M="m", N="n", O="o", P="p", Q="q", R="r", S="s", T="t",
  U="u", V="v", W="w", X="x", Y="y", Z="z",
  Zero="0", One="1", Two="2", Three="3", Four="4", Five="5",
  Six="6", Seven="7", Eight="8", Nine="9",
  Comma=",", Period=".", Minus="-", Equals="=",
  LeftBracket="[", RightBracket="]", BackSlash="\\",
  Semicolon=";", Slash="/", Grave="`",
}
local SHIFT_MAP = {
  Comma="<", Period=">", Minus="_", Equals="+",
  LeftBracket="{", RightBracket="}", BackSlash="|",
  Grave="'",
}
Widgets.CHAR_MAP = CHAR_MAP
Widgets.SHIFT_MAP = SHIFT_MAP

-- Menu: popup list of {label, action, selected}
function Widgets.menu(anchor, items, theme)
  local t = theme
  local h = #items * 22 + 8
  local m = Instance.new("Frame", anchor)
  m.Name = "menu"
  m.BackgroundColor3 = t.panel
  m.BorderSizePixel = 0
  m.Position = UDim2.fromOffset(0, anchor.AbsoluteSize.Y)
  m.Size = UDim2.new(0, math.max(120, 140), 0, h)
  m.Visible = true
  local corner = Instance.new("UICorner", m)
  corner.CornerRadius = UDim.new(Enum.NumberScale, 4)
  for i, item in items do
    local b = Instance.new("TextButton", m)
    b.Position = UDim2.fromOffset(4, 4 + (i - 1) * 22)
    b.Size = UDim2.new(1, -8, 0, 22)
    b.BackgroundTransparency = 1
    b.Text = (item.selected and "● " or "") .. item.label
    b.TextColor3 = item.selected and t.accent or t.text
    b.Font = Enum.Font.Gotham
    b.TextSize = 12
    b.TextXAlignment = Enum.TextXAlignment.Left
    b.MouseButton1Click:Connect(function()
      m:Destroy()
      if item.action then item.action() end
    end)
  end
  -- click-away catcher
  local catch = Instance.new("TextButton", anchor)
  catch.Name = "menuCatch"
  catch.BackgroundTransparency = 1
  catch.BorderSizePixel = 0
  catch.Position = UDim2.fromScale(0, -10); catch.Size = UDim2.fromScale(1, 12)
  catch.Text = ""
  catch.MouseButton1Click:Connect(function() m:Destroy() end)
  m.MouseLeave:Connect(function() end)
  return m
end
