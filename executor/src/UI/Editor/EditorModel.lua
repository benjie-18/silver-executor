--[[
  EditorModel — multi-tab document store.
]]
local EditorModel = {}
local Util = require(script.Parent.Util)
local Document = require(script.Parent.Document)

local model = { tabs = {}, activeId = 1, nextId = 1 }
EditorModel = setmetatable(EditorModel, { __index = EditorModel })

function EditorModel.init(defaultSource, defaultName)
  model.tabs = {}
  model.nextId = 1
  model.activeId = 1
  EditorModel.addTab(defaultName or "main", defaultSource)
end

function EditorModel.addTab(name, source)
  local id = model.nextId
  model.nextId += 1
  model.tabs[id] = {
    id = id, name = name, doc = Document.new(source),
    caret = { line = 1, col = 0 }, selAnchor = nil,
    scrollY = 0, scrollX = 0,
    search = { q = "", dir = 1, last = nil, case = false, word = false, pattern = false,
              replaceMode = false, replaceText = "" },
  }
  return id
end

function EditorModel.close(id)
  if #model.tabs <= 1 then return end
  model.tabs[id] = nil
  if model.activeId == id then
    model.activeId = model.nextId - 1
  end
end

function EditorModel.activate(id)
  if model.tabs[id] then model.activeId = id end
end

function EditorModel.getActive()
  return model.tabs[model.activeId]
end

function EditorModel.cycle(dir)
  local ids = {}
  for id in pairs(model.tabs) do table.insert(ids, id) end
  table.sort(ids)
  if #ids == 0 then return end
  local idx = 1
  for i, id in ids do
    if id == model.activeId then idx = i break end
  end
  idx = (idx - 1 + dir + #ids) % #ids + 1
  model.activeId = ids[idx]
end

function EditorModel.all() return model.tabs end

return EditorModel
