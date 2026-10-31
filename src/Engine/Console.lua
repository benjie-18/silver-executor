local Console = {}
Console.__index = Console
function Console.new(limit)
    return setmetatable({lines = {}, limit = math.max(1, limit or 500), listeners = {}}, Console)
end
function Console:onChange(fn)
    table.insert(self.listeners, fn)
    return function()
        for i, callback in ipairs(self.listeners) do
            if callback == fn then table.remove(self.listeners, i) break end
        end
    end
end
function Console:log(level, text)
    table.insert(self.lines, {level = level, text = tostring(text)})
    if #self.lines > self.limit then table.remove(self.lines, 1) end
    for _, fn in ipairs(self.listeners) do fn(self.lines) end
end
function Console:clear()
    self.lines = {}
    for _, fn in ipairs(self.listeners) do fn(self.lines) end
end
function Console:text()
    local out = {}
    for _, row in ipairs(self.lines) do table.insert(out, "[" .. row.level .. "] " .. row.text) end
    return table.concat(out, "\n")
end
return Console
