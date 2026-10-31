local Document = if script then require(script.Parent.Document) else require("./Document")
local Model = {}
Model.__index = Model
function Model.new()
    local self = setmetatable({tabs = {}, active = nil, nextId = 1}, Model)
    self:add("main", "-- Write Luau here\nprint(\"Hello, world!\")")
    return self
end
function Model:add(name, text)
    local tab = {id = self.nextId, name = name or "untitled", doc = Document.new(text), savedRevision = 0}
    self.nextId += 1
    table.insert(self.tabs, tab)
    self.active = tab.id
    return tab
end
function Model:current()
    for _, tab in ipairs(self.tabs) do if tab.id == self.active then return tab end end
end
function Model:select(id)
    for _, tab in ipairs(self.tabs) do
        if tab.id == id then self.active = id return true end
    end
    return false
end
function Model:close(id)
    if #self.tabs == 1 then return false end
    for index, tab in ipairs(self.tabs) do
        if tab.id == id then
            table.remove(self.tabs, index)
            if self.active == id then self.active = self.tabs[math.min(index, #self.tabs)].id end
            return true
        end
    end
    return false
end
return Model
