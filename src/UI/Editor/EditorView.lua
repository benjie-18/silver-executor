-- Native TextBox handles caret, selection, IME, paste, and keyboard layout.
local EditorView = {}
function EditorView.new(parent, model, theme, host)
    local instances = host and host.Instance or Instance
    local udim = host and host.UDim2 or UDim2
    local enums = host and host.Enum or Enum
    local box = instances.new("TextBox")
    box.Name = "Source"
    box.Parent = parent
    box.Size = udim.fromScale(1, 1)
    box.BackgroundColor3 = theme.bg
    box.TextColor3 = theme.text
    box.BorderSizePixel = 0
    box.ClearTextOnFocus = false
    box.MultiLine = true
    box.TextWrapped = false
    box.TextXAlignment = enums.TextXAlignment.Left
    box.TextYAlignment = enums.TextYAlignment.Top
    box.Font = enums.Font.Code
    box.TextSize = 15
    box.Text = ""
    local syncing = false
    local view = {box = box}
    box:GetPropertyChangedSignal("Text"):Connect(function()
        if not syncing then
            local tab = model:current()
            if tab and tab.doc:setText(box.Text) and view.onEdit then view.onEdit() end
        end
    end)
    function view:refresh()
        local tab = model:current()
        syncing = true
        box.Text = tab and tab.doc:text() or ""
        syncing = false
    end
    view:refresh()
    return view
end
return EditorView
