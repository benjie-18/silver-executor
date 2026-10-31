local Util = if script then require(script.Parent.Parent.Parent.Core.Util) else require("../../Core/Util")
local Document = {}
Document.__index = Document
function Document.new(source)
    return setmetatable({lines = Util.lines(source), undoStack = {}, redoStack = {}, revision = 0, limit = 128}, Document)
end
function Document:text() return table.concat(self.lines, "\n") end
function Document:checkpoint()
    table.insert(self.undoStack, self:text())
    if #self.undoStack > self.limit then table.remove(self.undoStack, 1) end
    self.redoStack = {}
end
function Document:setText(source)
    source = source or ""
    if source == self:text() then return false end
    self:checkpoint()
    self.lines = Util.lines(source)
    self.revision += 1
    return true
end
function Document:undo()
    local previous = table.remove(self.undoStack)
    if not previous then return false end
    table.insert(self.redoStack, self:text())
    self.lines = Util.lines(previous)
    self.revision += 1
    return true
end
function Document:redo()
    local nextText = table.remove(self.redoStack)
    if not nextText then return false end
    table.insert(self.undoStack, self:text())
    self.lines = Util.lines(nextText)
    self.revision += 1
    return true
end
-- 1-based line, zero-based byte column; end position exclusive.
function Document:replace(l1, c1, l2, c2, replacement)
    if not (self.lines[l1] and self.lines[l2] and l1 <= l2 and c1 >= 0 and c2 >= 0
        and c1 <= #self.lines[l1] and c2 <= #self.lines[l2]
        and (l1 < l2 or c1 <= c2)) then return false end
    local prefix = self.lines[l1]:sub(1, c1)
    local suffix = self.lines[l2]:sub(c2 + 1)
    local parts = Util.lines(replacement)
    parts[1] = prefix .. parts[1]
    parts[#parts] = parts[#parts] .. suffix
    self:checkpoint()
    for _ = l1, l2 do table.remove(self.lines, l1) end
    for i = #parts, 1, -1 do table.insert(self.lines, l1, parts[i]) end
    self.revision += 1
    return true
end
return Document
