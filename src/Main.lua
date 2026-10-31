-- Application wiring. Called by Bootstrap.client.lua in a Roblox client context.
local Config = require(script.Parent.Core.Config)
local Model = require(script.Parent.UI.Editor.EditorModel)
local Console = require(script.Parent.Engine.Console)
local Execution = require(script.Parent.Engine.Execution)
local Inject = require(script.Parent.Inject.Inject)
local UI = require(script.Parent.UI.UIManager)
local Main = {}
function Main.start()
    local previous = _G.__SILVER_UI
    if previous then previous:Destroy() end
    Config.init(_G)
    local console = Console.new(Config.get("consoleLimit"))
    local compiler, detail = Inject.probe()
    local execution = Execution.new(console, compiler, task.spawn)
    local ui = UI.new(Model.new(), console, execution, Config)
    _G.__SILVER_UI = ui.gui
    console:log("system", detail)
    return ui
end
return Main
