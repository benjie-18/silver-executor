--[[
  TabsBar — multi-tab strip: click activate, x close, double-click rename.
]]
local TabsBar = {}
local Util = require(script.Parent.Util)
local Widgets = require(script.Parent.Widgets)

function TabsBar.build(host, model, theme)
  local t = theme
  local bar = Instance.new("Frame", host)
  bar.Name = "tabs"
  bar.BackgroundColor3 = t.panel
  bar.BorderSizePixel = 0
  bar.Position = UDim2.fromScale(0, 0)
  bar.Size = UDim2.new(1, 0, 0, 28)

  local function render()
    for _, old in bar:GetChildren() do
      if old:IsA("TextButton") then old:Destroy() end
    end
    local ids = {}
    for id in pairs(model.tabs) do table.insert(ids, id) end
    table.sort(ids)
    local x = 0
    local maxW = bar.AbsoluteSize.X
    for _, id in ids do
      if x > maxW then break end
      local tab = model.tabs[id]
      local w = math.min(160, 40 + #tab.name * 7)
      local active = id == model.activeId
      local b = Instance.new("TextButton", bar)
      b.Name = "tab_" .. id
      b.Position = UDim2.fromOffset(x, 2)
      b.Size = UDim2.new(0, w, 0, 24)
      b.BackgroundColor3 = active and t.accent or t.panelAlt
      b.Text = tab.name .. (tab.dirty and " ●" or "")
      b.TextColor3 = t.text
      b.Font = Enum.Font.GothamMedium
      b.TextSize = 12
      b.MouseButton1Click:Connect(function() model.activate(id) end)
      -- close button
      local cb = Instance.new("TextButton", b)
      cb.Name = "close"
      cb.Position = UDim2.new(1, -16, 0, 0); cb.Size = UDim2.new(0, 14, 1, 0)
      cb.BackgroundTransparency = 1
      cb.Text = "×"
      cb.TextColor3 = t.muted
      cb.TextSize = 12
      cb.MouseButton1Click:Connect(function()
        model.close(id)
        render()
      end)
      x += w + 2
    end
  end
  render()
  return bar
end

return TabsBar
