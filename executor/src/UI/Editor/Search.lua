--[[
  Search — find/replace: literal, case, whole-word, Lua-pattern modes.
]]
local Search = {}

function Search.makeFinder(query, opts)
  opts = opts or {}
  local q = opts.case and query or query:lower()
  local function findInLine(text)
    text = opts.case and text or text:lower()
    local matches = {}
    if opts.pattern then
      local i, e
      local pos = 1
      while true do
        i, e = text:find(q, pos)
        if not i then break end
        if not opts.word or (i == 1 or not text:sub(i - 1, i - 1):match("[%w_]"))
          and (e == #text or not text:sub(e + 1, e + 1):match("[%w_]")) then
          table.insert(matches, { i, e })
        end
        pos = e + 1
      end
    else
      local pos = 1
      while true do
        local i = text:find(q, pos, true)
        if not i then break end
        if not opts.word or (i == 1 or not text:sub(i - 1, i - 1):match("[%w_]"))
          and (i + #q - 1 == #text or not text:sub(i + #q, i + #q):match("[%w_]")) then
          table.insert(matches, { i, i + #q - 1 })
        end
        pos = i + 1
      end
    end
    return matches
  end
  return findInLine
end

function Search.findAll(lines, findInLine)
  local out = {}
  for line = 1, #lines do
    local ms = findInLine(lines[line])
    for _, m in ms do
      table.insert(out, { line = line, c1 = m[1] - 1, c2 = m[2] })
    end
  end
  return out
end

function Search.replaceAll(doc, findInLine, replacement)
  local matches = Search.findAll(doc.lines, findInLine)
  doc.pushUndo(doc)
  for i = #matches, 1, -1 do
    local m = matches[i]
    doc.deleteRange(m.line, m.c1, m.line, m.c2)
    doc.insertAt(m.line, m.c1, replacement)
  end
  return #matches
end

return Search
