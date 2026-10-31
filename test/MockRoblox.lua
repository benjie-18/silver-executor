-- Lightweight host stand-ins for pure module tests; no claim of Studio parity.
local Mock = {}
function Mock.compiler(source)
    return loadstring(source)
end
function Mock.scheduler()
    local pending = {}
    return function(fn)
        table.insert(pending, fn)
        return #pending
    end, function()
        local current = pending
        pending = {}
        for _, fn in ipairs(current) do fn() end
    end
end
function Mock.installUI()
    local function signal()
        local listeners = {}
        local event = {}
        function event:Connect(fn)
            table.insert(listeners, fn)
            return {Disconnect = function()
                for i, listener in ipairs(listeners) do
                    if listener == fn then table.remove(listeners, i) break end
                end
            end}
        end
        function event:Fire(...)
            for _, fn in ipairs(table.clone(listeners)) do fn(...) end
        end
        return event
    end
    local function instance(class)
        local props, children, events = {}, {}, {}
        local methods = {}
        function methods:GetChildren() return table.clone(children) end
        function methods:IsA(name) return class == name end
        function methods:GetPropertyChangedSignal(name)
            events[name] = events[name] or signal()
            return events[name]
        end
        function methods:FindFirstChild(name)
            for _, child in ipairs(children) do if child.Name == name then return child end end
        end
        function methods:WaitForChild(name) return assert(self:FindFirstChild(name), name) end
        function methods:CaptureFocus() end
        function methods:Destroy()
            for _, child in ipairs(table.clone(children)) do child:Destroy() end
            self.Destroying:Fire()
            self.Parent = nil
        end
        local obj
        obj = setmetatable({}, {
            __index = function(_, key)
                if methods[key] then return methods[key] end
                if key == "MouseButton1Click" or key == "Destroying" or key == "InputBegan" then
                    events[key] = events[key] or signal()
                    return events[key]
                end
                return props[key]
            end,
            __newindex = function(_, key, value)
                if key == "Parent" then
                    local old = props.Parent
                    if old then
                        for i, child in ipairs(old._children) do
                            if child == obj then table.remove(old._children, i) break end
                        end
                    end
                    if value then table.insert(value._children, obj) end
                end
                props[key] = value
                if events[key] then events[key]:Fire() end
            end,
        })
        props._children = children
        props.ClassName = class
        props.AbsoluteSize = {X = 400, Y = 600}
        return obj
    end
    local playerGui = instance("PlayerGui")
    playerGui.Name = "PlayerGui"
    local player = instance("Player")
    playerGui.Parent = player
    local input = instance("UserInputService")
    function input:IsKeyDown() return false end
    local host = {}
    host.Instance = {new = instance}
    host.Color3 = {fromRGB = function(...) return {...} end}
    host.UDim2 = {fromOffset = function(...) return {...} end,
        fromScale = function(...) return {...} end,
        new = function(...) return {...} end}
    host.Enum = {Font = {Gotham = "Gotham", Code = "Code"},
        TextXAlignment = {Left = "Left"}, TextYAlignment = {Top = "Top"},
        ScrollingDirection = {X = "X", Y = "Y"},
        KeyCode = {L = "L", LeftControl = "LC", RightControl = "RC", LeftShift = "LS", RightShift = "RS"}}
    host.game = {GetService = function(_, name)
        if name == "Players" then return {LocalPlayer = player} end
        if name == "UserInputService" then return input end
        error("unexpected service " .. name)
    end}
    return playerGui, input, host
end

return Mock
