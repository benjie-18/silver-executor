--[[
  Document — line store + undo/redo + all edit ops (1-based lines, 0-based cols).
]]
local Document = {}
Document.__index = Document

function Document.new(source)
  local self = setmetatable({}, Document)
  self.lines = Util.splitLines(source or "")
  if #self.lines == 0 then self.lines = { "" } end
  self.rev = 0
  self.undo = {}
  self.redo = {}
  self.undoLimit = 128
  return self
end

local function snap(self)
  local copy = {}
  for i, l in self.lines do copy[i] = l end
  return { lines = copy, caret = self.caret and { line = self.caret.line, col = self.caret.col } or nil }
end

function Document.pushUndo(self)
  table.insert(self.undo, snap(self))
  while #self.undo > self.undoLimit do table.remove(self.undo, 1) end
  self.redo = {}
end

function Document.undo(self)
  if #self.undo == 0 then return false end
  table.insert(self.redo, snap(self))
  local s = table.remove(self.undo)
  self.lines = s.lines
  self.caret = s.caret
  self.rev += 1
  return true
end

function Document.redo(self)
  if #self.redo == 0 then return false end
  table.insert(self.undo, snap(self))
  local s = table.remove(self.redo)
  self.lines = s.lines
  self.caret = s.caret
  self.rev += 1
  return true
end

function Document.lineCount(self) return #self.lines end
function Document.line(self, i) return self.lines[i] or "" end
function Document.getText(self) return table.concat(self.lines, "\n") end

function Document.insertAt(self, line, col, text)
  self.pushUndo(self)
  local parts = Util.splitLines(text)
  local cur = self.lines[line]
  self.lines[line] = cur:sub(1, col) .. parts[1] .. cur:sub(col + 1)
  for i = #parts, 2, -1 do
    table.insert(self.lines, line + i - 1, parts[i])
  end
  self.rev += 1
  return #parts
end

function Document.deleteRange(self, l1, c1, l2, c2)
  self.pushUndo(self)
  if l1 == l2 then
    local line = self.lines[l1]
    self.lines[l1] = line:sub(1, c1) .. line:sub(c2 + 1)
  else
    local first = self.lines[l1]:sub(1, c1)
    local last = self.lines[l2]:sub(c2 + 1)
    self.lines[l1] = first .. last
    for i = l2, l1 + 1, -1 do
      table.remove(self.lines, i)
    end
  end
  self.rev += 1
end

function Document.backspace(self, line, col)
  if col > 0 then
    self.deleteRange(line, col - 1, line, col)
    return line, col - 1
  elseif line > 1 then
    self.pushUndo(self)
    local prev = self.lines[line - 1]
    self.lines[line - 1] = prev .. self.lines[line]
    table.remove(self.lines, line)
    self.rev += 1
    return line - 1, #prev
  end
  return line, col
end

function Document.deleteKey(self, line, col)
  local n = #self.lines
  if col < #self.lines[line] then
    self.deleteRange(line, col, line, col + 1)
    return line, col
  elseif line < n then
    self.pushUndo(self)
    self.lines[line] = self.lines[line] .. self.lines[line + 1]
    table.remove(self.lines, line + 1)
    self.rev += 1
    return line, col
  end
  return line, col
end

function Document.enter(self, line, col, indent)
  self.pushUndo(self)
  local cur = self.lines[line]
  self.lines[line] = cur:sub(1, col)
  table.insert(self.lines, line + 1, indent .. cur:sub(col + 1))
  self.rev += 1
  return line + 1, #indent
end

function Document.indentLines(self, a, b)
  self.pushUndo(self)
  for i = a, b do
    self.lines[i] = "    " .. self.lines[i]
  end
  self.rev += 1
end

function Document.outdentLines(self, a, b)
  self.pushUndo(self)
  for i = a, b do
    local l = self.lines[i]
    if l:sub(1, 4) == "    " then
      self.lines[i] = l:sub(5)
    elseif l:sub(1, 2) == "  " then
      self.lines[i] = l:sub(3)
    elseif l:sub(1, 1) == " " then
      self.lines[i] = l:sub(2)
    end
  end
  self.rev += 1
end

function Document.toggleComment(self, a, b)
  self.pushUndo(self)
  local allCommented = true
  for i = a, b do
    if not self.lines[i]:match("^%s*--%s") then allCommented = false break end
  end
  for i = a, b do
    if allCommented then
      self.lines[i] = self.lines[i]:gsub("^%s*--%s?", "")
    else
      self.lines[i] = "-- " .. self.lines[i]
    end
  end
  self.rev += 1
end

function Document.selectWordAt(self, line, col)
  local l = self.lines[line]
  local function isWord(c) return c and c:match("[%w_]") end
  local s = col
  while s > 0 and isWord(l:sub(s, s)) do s -= 1 end
  s += 1
  local e = col
  while e < #l and isWord(l:sub(e + 1, e + 1)) do e += 1 end
  return line, s, line, e + 1
end

return Document
