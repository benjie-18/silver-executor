local EditorView = if script then require(script.Parent.Editor.EditorView) else require("./Editor/EditorView")
local Theme = if script then require(script.Parent.Parent.Core.ThemeManager) else require("../Core/ThemeManager")
local Search = if script then require(script.Parent.Editor.Search) else require("./Editor/Search")

local UI = {}
local function make(instances, class, parent, name)
    local object = instances.new(class)
    object.Name = name
    object.Parent = parent
    return object
end
local function button(instances, udim, enums, parent, title, width, action)
    local b = make(instances, "TextButton", parent, title)
    b.Size = udim.fromOffset(width, 32)
    b.Text = title
    b.Font = enums.Font.Gotham
    b.TextSize = 12
    b.MouseButton1Click:Connect(action)
    return b
end

function UI.new(model, console, execution, config, host)
    local instances = host and host.Instance or Instance
    local udim = host and host.UDim2 or UDim2
    local enums = host and host.Enum or Enum
    local dataModel = host and host.game or game
    local player = dataModel:GetService("Players").LocalPlayer
    assert(player, "Silver UI requires a client context")
    local gui = make(instances, "ScreenGui", player:WaitForChild("PlayerGui"), "SilverExecutor")
    gui.ResetOnSpawn = false
    -- A compact opener remains available on touch devices when the window is hidden.
    local opener = button(instances, udim, enums, gui, "Silver", 72, function() end)
    opener.Position = udim.fromOffset(8, 8)
    opener.Visible = false
    local t = Theme.get(config.get("theme"), host and host.Color3)
    local root = make(instances, "ScrollingFrame", gui, "Window")
    root.Size = udim.new(0.96, 0, 0.84, 0)
    root.Position = udim.new(0.02, 0, 0.08, 0)
    root.BackgroundColor3 = t.panel
    root.BorderSizePixel = 0
    root.ScrollingDirection = enums.ScrollingDirection.Y
    root.ScrollBarThickness = 5
    local function show(visible)
        root.Visible = visible
        opener.Visible = not visible
    end
    opener.MouseButton1Click:Connect(function() show(true) end)

    -- Scrolling toolbar so all actions remain reachable on small screens.
    local bar = make(instances, "ScrollingFrame", root, "Toolbar")
    bar.BackgroundTransparency = 1
    bar.Size = udim.new(1, -16, 0, 36)
    bar.Position = udim.fromOffset(8, 4)
    bar.ScrollBarThickness = 3
    bar.ScrollingDirection = enums.ScrollingDirection.X
    local toolbarWidth = 0
    local function command(name, width, action)
        local b = button(instances, udim, enums, bar, name, width, function()
            local ok, err = pcall(action)
            if not ok then console:log("error", err) end
        end)
        b.Position = udim.fromOffset(toolbarWidth, 0)
        toolbarWidth += width + 4
        bar.CanvasSize = udim.fromOffset(toolbarWidth, 0)
        return b
    end

    local tabs = make(instances, "ScrollingFrame", root, "Tabs")
    tabs.Position = udim.fromOffset(8, 42)
    tabs.Size = udim.new(1, -16, 0, 32)
    tabs.BackgroundTransparency = 1
    tabs.ScrollBarThickness = 2
    tabs.ScrollingDirection = enums.ScrollingDirection.X
    local editorHost = make(instances, "Frame", root, "Editor")
    editorHost.BackgroundTransparency = 1
    editorHost.Position = udim.fromOffset(8, 110)
    editorHost.Size = udim.new(1, -16, 0, 152)
    local view = EditorView.new(editorHost, model, t, host)
    local function refreshTabs()
        for _, child in ipairs(tabs:GetChildren()) do child:Destroy() end
        for index, tab in ipairs(model.tabs) do
            local label = tab.name .. (tab.doc.revision ~= tab.savedRevision and " *" or "")
            local item = button(instances, udim, enums, tabs, label, 112, function()
                model:select(tab.id)
                view:refresh()
                refreshTabs()
            end)
            item.Position = udim.fromOffset((index - 1) * 116, 0)
        end
        tabs.CanvasSize = udim.fromOffset(#model.tabs * 116, 0)
    end
    view.onEdit = refreshTabs

    local findBox = make(instances, "TextBox", root, "FindQuery")
    findBox.Position = udim.fromOffset(8, 78)
    findBox.Size = udim.new(1, -16, 0, 28)
    findBox.PlaceholderText = "Find literal text"
    findBox.Text = ""
    findBox.ClearTextOnFocus = false

    local consoleBox = make(instances, "TextBox", root, "Console")
    consoleBox.Position = udim.fromOffset(8, 270)
    consoleBox.Size = udim.new(1, -16, 0, 138)
    consoleBox.BackgroundColor3 = t.bg
    consoleBox.TextColor3 = t.text
    consoleBox.Font = enums.Font.Code
    consoleBox.TextSize = 13
    consoleBox.MultiLine = true
    consoleBox.ClearTextOnFocus = false
    consoleBox.TextEditable = false
    consoleBox.TextXAlignment = enums.TextXAlignment.Left
    consoleBox.TextYAlignment = enums.TextYAlignment.Top
    consoleBox.Text = ""
    local status = make(instances, "TextLabel", root, "Status")
    status.Position = udim.fromOffset(8, 414)
    status.Size = udim.new(1, -16, 0, 22)
    status.BackgroundTransparency = 1
    status.TextXAlignment = enums.TextXAlignment.Left
    status.TextColor3 = t.muted
    status.Text = "Ready"
    local function resize()
        local contentHeight = math.max(440, root.AbsoluteSize.Y)
        root.CanvasSize = udim.fromOffset(0, contentHeight)
        editorHost.Size = udim.new(1, -16, 0, contentHeight - 288)
        consoleBox.Position = udim.fromOffset(8, contentHeight - 170)
        status.Position = udim.fromOffset(8, contentHeight - 28)
    end
    local sizeConnection = root:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
    resize()
    local unsubscribe = console:onChange(function()
        consoleBox.Text = console:text()
        status.Text = execution.state
    end)
    local function act(name, width, action)
        command(name, width, function()
            action()
            status.Text = execution.state
            refreshTabs()
        end)
    end
    act("Run", 54, function()
        local tab = model:current()
        local source = tab.doc:text()
        if #source > config.get("maxSourceBytes") then
            console:log("error", "source exceeds configured limit")
            return
        end
        local ok, err = execution:run(source, tab.name)
        if not ok and execution.state ~= "error" then console:log("error", err) end
    end)
    act("Stop", 54, function() execution:stop() end)
    act("New tab", 74, function() model:add("tab " .. model.nextId, "") view:refresh() end)
    act("Close tab", 74, function() model:close(model.active) view:refresh() end)
    act("Undo", 54, function() if model:current().doc:undo() then view:refresh() end end)
    act("Redo", 54, function() if model:current().doc:redo() then view:refresh() end end)
    act("Clear log", 74, function() console:clear() end)
    act("Find", 54, function()
        local query = findBox.Text
        local matches = Search.findAll(model:current().doc.lines, query)
        console:log("info", tostring(#matches) .. " matches for " .. query)
        if #matches > 0 then
            local m = matches[1]
            local offset = m.startCol + 1
            for line = 1, m.line - 1 do offset += #model:current().doc.lines[line] + 1 end
            view.box:CaptureFocus()
            view.box.CursorPosition = offset
            view.box.SelectionStart = offset + m.endCol - m.startCol
        end
    end)
    act("Hide", 54, function() show(false) end)
    local input = dataModel:GetService("UserInputService")
    local toggle = input.InputBegan:Connect(function(key, processed)
        if not processed and key.KeyCode == enums.KeyCode.L
            and (input:IsKeyDown(enums.KeyCode.LeftControl) or input:IsKeyDown(enums.KeyCode.RightControl))
            and (input:IsKeyDown(enums.KeyCode.LeftShift) or input:IsKeyDown(enums.KeyCode.RightShift)) then
            show(not root.Visible)
        end
    end)
    gui.Destroying:Connect(function()
        toggle:Disconnect()
        sizeConnection:Disconnect()
        unsubscribe()
        execution:stop()
    end)
    refreshTabs()
    return {gui = gui, view = view}
end
return UI
