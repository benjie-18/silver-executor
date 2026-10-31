--[[
  Main — entry point (run as a LocalScript, or require() from one).
  Wires config, theme, memory, offsets, console, execution, inject, model,
  UI, and global keyboard shortcuts.

  Shortcuts:
    F5 / Ctrl+Enter   execute      F8   stop
    F9                clear        F10  reset
    Ctrl+T / Ctrl+W   new / close tab
    Ctrl+Tab          cycle tab
    (editor) Ctrl+F / Ctrl+H / Ctrl+Z / Ctrl+Shift+Z / Ctrl+A / Ctrl+C/X/V
              Ctrl+Space autocomplete, Tab/Enter accept, Arrows, Home/End
]]
local Config = require(script.Parent.Config)
local ThemeManager = require(script.Parent.ThemeManager)
local Memory = require(script.Parent.Memory)
local Offsets = require(script.Parent.Offsets)
local Execution = require(script.Parent.Execution)
local Inject = require(script.Parent.Inject)
local EditorModel = require(script.Parent.Editor.EditorModel)
local EditorView = require(script.Parent.Editor.EditorView)
local Widgets = require(script.Parent.Widgets)
local UIManager = require(script.Parent.UIManager)

-- ── host frame ────────────────────────────────────────────────────
local root
if type(gethui) == "function" then
  root = gethui()
else
  local Player = game:GetService("Players"):GetLocalPlayer()
  local pg = Player:FindFirstChildOfClass("PlayerGui")
  if not pg then
    pg = Instance.new("ScreenGui")
    pg.Name = "LXGui"
    pg.ResetOnCloser = false
    pg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pg.Parent = Player
  end
  root = Instance.new("Frame", pg)
  root.Name = "LXExecutor"
  root.Size = UDim2.fromScale(1, 1)
  root.BackgroundColor3 = Color3.fromRGB(13, 15, 19)
end

-- ── init stack ────────────────────────────────────────────────────
local gg = getgenv()
Config.init(gg)
local CFG = Config.get()
ThemeManager.init(CFG.theme)
Memory.init()
Offsets.init(gg)
Execution.init(CFG)
EditorModel.init("print(\"hello from LX-Executor\")", "main")

local ui = UIManager.build(root)

-- ── global keys ───────────────────────────────────────────────────
local UIS = game:GetService("UserInputService")
UIS.InputBegan:Connect(function(input, gameProcessed)
  if gameProcessed then return end
  local key = input.KeyCode
  if key == Enum.KeyCode.Unknown then return end
  local shift = UIS:IsKeyDown(Enum.KeyCode.LeftShift) or UIS:IsKeyDown(Enum.KeyCode.RightShift)
  local ctrl = UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.RightControl)

  if Widgets.focus.current == "editor" then
    if EditorView.handleKey(key, shift, ctrl) then return end
  end

  if key == Enum.KeyCode.F5 then ui:execute()
  elseif key == Enum.KeyCode.F8 then ui:stop()
  elseif key == Enum.KeyCode.F9 then ui:clear()
  elseif key == Enum.KeyCode.F10 then ui:reset()
  elseif ctrl and key == Enum.KeyCode.T then ui:newTab()
  elseif ctrl and key == Enum.KeyCode.W then ui:closeTab()
  elseif ctrl and key == Enum.KeyCode.Tab then ui:cycleTab(1)
  elseif ctrl and key == Enum.KeyCode.Return then ui:execute()
  end
end)

-- ── startup ───────────────────────────────────────────────────────
local function attachAndRun()
  Console_logSystem("LX-Executor ready.")
  if CFG.autoInject then
    ui:execute()
  end
end
task.delay(0.2, attachAndRun)

-- convenience global handle
_LX = _LX or {}
_LX.ui = ui
_LX.config = Config
_LX.run = function() ui:execute() end
_LX.stop = function() ui:stop() end

return ui
