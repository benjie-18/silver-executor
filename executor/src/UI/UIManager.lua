--[[
  UIManager — layout, resizable panels, toolbar, explorer, properties,
  console wiring, theme reskin, and all button/shortcut bindings.
  Left: editor. Bottom: console. Right: explorer (top) + properties (bottom).
]]
local Util = require(script.Parent.Util)
local Config = require(script.Parent.Config)
local ThemeManager = require(script.Parent.ThemeManager)
local Console = require(script.Parent.Console)
local Execution = require(script.Parent.Execution)
local Inject = require(script.Parent.Inject)
local Clipboard = require(script.Parent.Clipboot)
local EditorModel = require(script.Parent.Editor.EditorModel)
local EditorView = require(script.Parent.Editor.EditorView)
local TabsBar = require(script.Parent.Editor.TabsBar)
local Api = require(script.Parent.RobloxApi)
local Widgets = require(script.Parent.Widgets)

local UIManager = {}
local CFG = Config.get()

local function makeFrame(parent, name, color)
  local f = Instance.new("Frame", parent)
  f.Name = name
  f.BackgroundColor3 = color
  f.BorderSizePixel = 0
  return f
end

local function makeDivider(parent, vertical)
  local d = Instance.new("Frame", parent)
  d.Name = "divider"
  d.BackgroundColor3 = ThemeManager.get().border
  d.BorderSizePixel = 0
  d.Active = true
  return d
end

function UIManager.build(parent)
  local t = ThemeManager.get()
  local ui = { theme = t }

  parent.BackgroundColor3 = t.base

  -- panel frames (positions set by layout)
  ui.toolbar = makeFrame(parent, "toolbar", t.panel)
  ui.editorPanel = makeFrame(parent, "editorPanel", t.editor.bg)
  ui.rightPanel = makeFrame(parent, "rightPanel", t.panel)
  ui.consolePanel = makeFrame(parent, "consolePanel", t.panel)

  -- editor: tabs + editor surface
  ui.tabs = TabsBar.build(ui.editorPanel, EditorModel, t)
  ui.editorHost = makeFrame(ui.editorPanel, "editorHost", t.editor.bg)
  EditorView.init(ui.editorHost, EditorModel, t)
  EditorView.focus()

  -- right: explorer (top) + properties (bottom)
  ui.explorerPanel = makeFrame(ui.rightPanel, "explorerPanel", t.panel)
  ui.propsPanel = makeFrame(ui.rightPanel, "propsPanel", t.panelAlt)

  -- console
  ui.consoleHost = makeFrame(ui.consolePanel, "consoleHost", t.editor.bg)
  Console.init(ui.consoleHost, CFG)
  Console.setTheme(t)

  -- toolbar contents
  ui:makeToolbar()
  ui:makeExplorer()
  ui:makeProps()

  -- resizers
  ui.divV = makeDivider(parent, true)
  ui.divH = makeDivider(parent, false)
  ui.divRight = makeDivider(ui.rightPanel, false)
  ui:wireResizers()

  -- initial layout
  ui.layout = ui.layout  -- assigned below
  ui.applyLayout()

  -- theme reskin
  ThemeManager.onChanged(function(newTheme)
    ui.theme = newTheme
    ui.reskin()
  end)

  -- status poll
  game:GetService("RunService").Heartbeat:Connect(function()
    Execution.tickFrames()
    local es = Execution.getState()
    ui.statusLabel.Text = es.statusText .. "  •  " .. (es.elapsed and Util.fmtMs(es.elapsed) or "")
    ui.injectLabel.Text = "attach: " .. Inject.getState().status
    Console.updatePerf(Execution.perfString())
  end)

  return ui
end

function UIManager:makeToolbar()
  local t = self.theme
  local function btn(text, name, x)
    local b = Widgets.button(self.toolbar, text, { theme = t, name = name,
      pos = UDim2.fromOffset(x, 5), size = UDim2.new(0, 64, 0, 22) })
    self["btn_" .. name] = b
    return b, x + 70
  end
  local x = 8
  local ex, x = btn("Execute", "execute", x); ex.MouseButton1Click:Connect(function() self:execute() end)
  local st, x = btn("Stop", "stop", x); st.MouseButton1Click:Connect(function() self:stop() end)
  local cl, x = btn("Clear", "clear", x); cl.MouseButton1Click:Connect(function() self:clear() end)
  local rs, x = btn("Reset", "reset", x); rs.MouseButton1Click:Connect(function() self:reset() end)
  local nt, x = btn("+ Tab", "newtab", x); nt.MouseButton1Click:Connect(function() self:newTab() end)

  self.injectLabel = Instance.new("TextLabel", self.toolbar)
  self.injectLabel.BackgroundTransparency = 1
  self.injectLabel.Position = UDim2.fromOffset(x + 4, 5)
  self.injectLabel.Size = UDim2.new(0, 140, 0, 22)
  self.injectLabel.Text = "attach: idle"
  self.injectLabel.TextColor3 = t.muted
  self.injectLabel.Font = Enum.Font.Code; self.injectLabel.TextSize = 11
  self.injectLabel.TextXAlignment = Enum.TextXAlignment.Left

  self.statusLabel = Instance.new("TextLabel", self.toolbar)
  self.statusLabel.BackgroundTransparency = 1
  self.statusLabel.Position = UDim2.new(1, -150, 5, 0)
  self.statusLabel.Size = UDim2.new(0, 145, 0, 22)
  self.statusLabel.Text = "Idle"
  self.statusLabel.TextColor3 = t.text
  self.statusLabel.Font = Enum.Font.Code; self.statusLabel.TextSize = 11
  self.statusLabel.TextXAlignment = Enum.TextXAlignment.Right

  -- theme menu
  self.themeBtn = Widgets.button(self.toolbar, "Theme", { theme = t,
    pos = UDim2.new(1, -320, 5, 0), size = UDim2.new(0, 70, 0, 22) })
  self.themeBtn.MouseButton1Click:Connect(function()
    local items = {}
    for _, name in ThemeManager.list() do
      table.insert(items, { label = name, selected = (name == ThemeManager.get() and true),
        action = (function(n) return function() ThemeManager.set(n) end end)(name) })
    end
    Widgets.menu(self.toolbar, items, self.theme)
  end)
end

local function getProps(inst)
  if type(getrawprops) == "function" then
    local ok, res = pcall(getrawprops, inst)
    if ok and type(res) == "table" then
      local out = {}
      for i, v in pairs(res) do
        if type(v) == "table" and v.name then out[v.name] = v.value
        else out[tostring(i)] = v end
      end
      return out
    end
  end
  local out, names = {}, {}
  local cls = Api.Classes[inst.ClassName]
  if cls and cls.props then
    for k in pairs(cls.props) do names[#names + 1] = k end
  end
  for _, name in names do
    local ok, val = pcall(function() return inst[name] end)
    if ok then out[name] = val end
  end
  return out
end

function UIManager:makeProps()
  self.selected = nil
  self.propsScroll = Instance.new("ScrollingFrame", self.propsPanel)
  self.propsScroll.Name = "scroll"
  self.propsScroll.BackgroundTransparency = 1
  self.propsScroll.Position = UDim2.new(0, 0, 0, 22)
  self.propsScroll.Size = UDim2.new(1, 0, 1, -22)
  self.propsScroll.ScrollBarThickness = 8
  self.propsTitle = Instance.new("TextLabel", self.propsPanel)
  self.propsTitle.BackgroundTransparency = 1
  self.propsTitle.Position = UDim2.new(0, 8, 0, 0)
  self.propsTitle.Size = UDim2.new(1, -16, 0, 20)
  self.propsTitle.Text = "Properties"
  self.propsTitle.TextColor3 = self.theme.muted
  self.propsTitle.Font = Enum.Font.GothamBold; self.propsTitle.TextSize = 12

  self._propsTimer = 0
  game:GetService("RunService").Heartbeat:Connect(function()
    self._propsTimer += 1
    if self._propsTimer % 30 == 0 then self:renderProps() end
  end)
end

function UIManager:renderProps()
  local scroll = self.propsScroll
  for _, c in scroll:GetChildren() do c:Destroy() end
  local inst = self.selected
  if not inst or not inst:IsA("Instance") then
    self.propsTitle.Text = "Properties — (none)"
    return
  end
  self.propsTitle.Text = "Properties — " .. inst.ClassName .. " : " .. inst.Name
  local props = getProps(inst)
  local y = 4
  local names = {}
  for k in pairs(props) do names[#names + 1] = k end
  table.sort(names)
  for _, name in names do
    local val = props[name]
    local row = Instance.new("Frame", scroll)
    row.BackgroundTransparency = 1
    row.Position = UDim2.fromOffset(0, y)
    row.Size = UDim2.new(1, -12, 0, 18)
    local nm = Instance.new("TextLabel", row)
    nm.BackgroundTransparency = 1
    nm.Position = UDim2.fromOffset(0, 0); nm.Size = UDim2.new(0, 110, 1, 0)
    nm.Text = name; nm.TextColor3 = self.theme.muted
    nm.Font = Enum.Font.Code; nm.TextSize = 11
    nm.TextXAlignment = Enum.TextXAlignment.Left
    local inp = Widgets.input(row, {
      placeholder = "value", theme = self.theme,
      pos = UDim2.fromOffset(112, 0), size = UDim2.new(1, -116, 1, 0),
    })
    inp.setText(Util.dump(val):gsub('"', ""):sub(1, 40))
    inp.onEnter = function(text)
      local cur = val
      local v = text
      if typeof then
        local ty = typeof(cur)
        if ty == "number" then v = tonumber(text)
        elseif ty == "boolean" then v = (text == "true" or text == "1")
        elseif ty == "Vector3" then
          local a, b, c = text:match("([%-]?%d+%.?%d*)[ ,]+([%-]?%d+%.?%d*)[ ,]+([%-]?%d+%.?%d*)")
          v = a and Vector3.new(tonumber(a), tonumber(b), tonumber(c)) or cur
        elseif ty == "Color3" then
          local r, g, b = text:match("([%-]?%d+%.?%d*)[ ,]+([%-]?%d+%.?%d*)[ ,]+([%-]?%d+%.?%d*)")
          v = r and Color3.fromRGB(r, g, b) or cur
        end
      end
      local ok, err = pcall(function() inst[name] = v end)
      if not ok then Console.logSystem("set " .. name .. " failed: " .. tostring(err)) end
    end
    y += 20
    scroll.CanvasSize = UDim2.new(0, 0, 0, y + 8)
  end
end

function UIManager:makeExplorer()
  self.expanded = {}
  self.expScroll = Instance.new("ScrollingFrame", self.explorerPanel)
  self.expScroll.BackgroundTransparency = 1
  self.expScroll.Position = UDim2.new(0, 0, 0, 22)
  self.expScroll.Size = UDim2.new(1, 0, 1, -22)
  self.expScroll.ScrollBarThickness = 8
  self.expTitle = Instance.new("TextLabel", self.explorerPanel)
  self.expTitle.BackgroundTransparency = 1
  self.expTitle.Position = UDim2.new(0, 8, 0, 0)
  self.expTitle.Size = UDim2.new(1, -16, 0, 20)
  self.expTitle.Text = "Explorer"
  self.expTitle.TextColor3 = self.theme.muted
  self.expTitle.Font = Enum.Font.GothamBold; self.expTitle.TextSize = 12

  self._explorerDirty = true
  game:GetService("RunService").Heartbeat:Connect(function()
    if self._explorerDirty then
      self._explorerDirty = false
      self:renderExplorer()
    end
  end)
end

function UIManager:renderExplorer()
  local scroll = self.expScroll
  for _, c in scroll:GetChildren() do c:Destroy() end
  local y = 4
  local MAXD = 4
  local function walk(inst, depth, path)
    local label = inst.ClassName .. " : " .. inst.Name
    local b = Instance.new("TextButton", scroll)
    b.BackgroundTransparency = 1
    b.Position = UDim2.fromOffset(0, y); b.Size = UDim2.new(1, -12, 0, 18)
    b.Text = ("   "):rep(depth) .. (self.expanded[path] and "▾ " or "▸ ") .. label
    b.TextXAlignment = Enum.TextXAlignment.Left
    b.TextColor3 = (self.selected == inst) and self.theme.accent or self.theme.text
    b.Font = Enum.Font.Code; b.TextSize = 11
    b.MouseButton1Click:Connect(function()
      self.selected = inst
      local kids = {}
      for _, c in inst:GetChildren() do kids[#kids + 1] = c end
      if #kids > 0 then
        if self.expanded[path] then self.expanded[path] = nil else self.expanded[path] = true end
      end
      self._explorerDirty = true
      self:renderProps()
    end)
    y += 18
    if self.expanded[path] and depth < MAXD then
      local kids = {}
      for _, c in inst:GetChildren() do kids[#kids + 1] = c end
      table.sort(kids, function(a, b) return a.Name < b.Name end)
      for _, child in kids do walk(child, depth + 1, path .. "." .. child.Name) end
    end
  end
  walk(game, 0, "game")
  scroll.CanvasSize = UDim2.new(0, 0, 0, y + 8)
end

function UIManager:wireResizers()
  local UIS = game:GetService("UserInputService")
  local parent = self.editorPanel.Parent

  local function makeDrag(div, onDelta)
    local dragging = false
    div.MouseButton1Down:Connect(function() dragging = true end)
    UIS.InputEnded:Connect(function(input)
      if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    UIS.InputChanged:Connect(function(input)
      if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        onDelta(input.Delta, input)
      end
    end)
  end

  makeDrag(self.divV, function(delta)
    local cur = Config.get().layout.rightWidth
    Config.update({ layout = { rightWidth = Util.clamp(cur + delta.X, 160, parent.AbsoluteSize.X - 300) } })
    self.applyLayout()
  end)
  makeDrag(self.divH, function(delta)
    local cur = Config.get().layout.consoleHeight
    Config.update({ layout = { consoleHeight = Util.clamp(cur - delta.Y, 64, parent.AbsoluteSize.Y - 120) } })
    self.applyLayout()
  end)
  makeDrag(self.divRight, function(delta)
    local cur = Config.get().layout.rightSplit
    Config.update({ layout = { rightSplit = Util.clamp(cur + delta.Y / 400, 0.15, 0.85) } })
    self.applyLayout()
  end)
end

function UIManager:applyLayout()
  local w, h = self.editorPanel.Parent.AbsoluteSize.X, self.editorPanel.Parent.AbsoluteSize.Y
  if w == 0 then w, h = 1200, 700 end
  local L = Config.get().layout
  local toolH = 32
  local rightW = L.rightWidth
  local consoleH = L.consoleHeight
  local leftW = w - rightW
  local bodyH = h - toolH - consoleH

  self.toolbar.Position = UDim2.fromScale(0, 0)
  self.toolbar.Size = UDim2.new(1, 0, 0, toolH)
  self.editorPanel.Position = UDim2.fromOffset(0, toolH)
  self.editorPanel.Size = UDim2.new(0, leftW, 0, bodyH)
  self.rightPanel.Position = UDim2.fromOffset(leftW, toolH)
  self.rightPanel.Size = UDim2.new(0, rightW, 0, bodyH)
  self.consolePanel.Position = UDim2.fromOffset(0, h - consoleH)
  self.consolePanel.Size = UDim2.new(1, 0, 0, consoleH)

  -- editor internals
  self.tabs.Position = UDim2.fromScale(0, 0)
  self.tabs.Size = UDim2.new(1, 0, 0, 28)
  self.editorHost.Position = UDim2.fromOffset(0, 28)
  self.editorHost.Size = UDim2.new(1, 0, 1, -28)

  -- right split
  local expH = math.floor(bodyH * L.rightSplit)
  self.explorerPanel.Position = UDim2.fromOffset(0, 0)
  self.explorerPanel.Size = UDim2.new(1, 0, 0, expH)
  self.propsPanel.Position = UDim2.fromOffset(0, expH + 6)
  self.propsPanel.Size = UDim2.new(1, 0, 1, -expH - 6)

  -- dividers
  self.divV.Position = UDim2.fromOffset(leftW - 3, toolH)
  self.divV.Size = UDim2.new(0, 6, 0, bodyH)
  self.divH.Position = UDim2.fromOffset(0, h - consoleH - 3)
  self.divH.Size = UDim2.new(1, 0, 0, 6)
  self.divRight.Position = UDim2.fromOffset(0, expH)
  self.divRight.Size = UDim2.new(1, 0, 0, 6)

  self._explorerDirty = true
end

function UIManager:reskin()
  local t = self.theme
  self.editorPanel.Parent.BackgroundColor3 = t.base
  self.toolbar.BackgroundColor3 = t.panel
  self.editorPanel.BackgroundColor3 = t.editor.bg
  self.rightPanel.BackgroundColor3 = t.panel
  self.consolePanel.BackgroundColor3 = t.panel
  self.explorerPanel.BackgroundColor3 = t.panel
  self.propsPanel.BackgroundColor3 = t.panelAlt
  self.statusLabel.TextColor3 = t.text
  self.injectLabel.TextColor3 = t.muted
  self.propsTitle.TextColor3 = t.muted
  self.expTitle.TextColor3 = t.muted
  EditorView.setTheme(t)
  Console.setTheme(t)
  self._explorerDirty = true
  self:renderProps()
end

function UIManager:execute()
  local tab = EditorModel.getActive()
  if Execution.getState().running then return end
  if Inject.getState().status ~= "attached" then
    Console.logSystem("attaching…")
    local ok = Inject.perform()
    if not ok then
      Console.error_("attach failed: " .. tostring(Inject.getState().detail))
      return
    end
  end
  EditorView.closeAuto and nil
  Execution.run(tab.doc.getText(), tab.name)
end

function UIManager:stop() Execution.stop() end
function UIManager:clear() Console.clear() end
function UIManager:reset() Execution.reset() end
function UIManager:newTab() EditorModel.addTab("script_" .. EditorModel.nextId - 1) end
function UIManager:closeTab() local t = EditorModel.getActive(); EditorModel.close(t.id) end
function UIManager:cycleTab(dir) EditorModel.cycle(dir) end

return UIManager
