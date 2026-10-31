--[[
  Autocomplete — locals (scanned), globals (RobloxApi.Globals), member
  completion (RobloxApi.Classes/Services). Snippets for block keywords.
]]
local Autocomplete = {}
local Api = require(script.Parent.RobloxApi)

local SNIPPETS = {
  ["function"] = { "end", "function %1()\n\t\nend" },
  ["if"] = { "end", "if %1 then\n\t\nend" },
  ["elseif"] = { "end", "elseif %1 then\n\t\nend" },
  ["for"] = { "end", "for %1 = ,  do\n\t\nend" },
  ["while"] = { "end", "while %1 do\n\t\nend" },
  ["return"] = { nil, "return " },
}

function Autocomplete.scanLocals(lines)
  local seen = {}
  local function add(name)
    if name and name ~= "" and not seen[name] then
      seen[name] = true
      table.insert(seen, name)
    end
  end
  for _, line in lines do
    for name in line:gmatch("^%s*local%s+([%a_][%w_]*)") do add(name) end
    for name in line:gmatch("local%s+function%s+([%a_][%w_]*)") do add(name) end
    for name in line:gmatch("function%s+([%a_][%w_]*)%s*%(") do add(name) end
    for name in line:gmatch("for%s+([%a_][%w_]*)%s*=") do add(name) end
    for name in line:gmatch("for%s+([%a_][%w_]*)%s+in") do add(name) end
  end
  local out = {}
  for i = 2, #seen do table.insert(out, seen[i]) end
  return out
end

function Autocomplete.compute(tab, line, col)
  local lineText = tab.doc.line(line)
  local before = lineText:sub(1, col)
  local afterDot = before:match("%.$") ~= nil
  local word = before:match("(%a_%w*)$")

  if SNIPPETS[word] then
    return { prefix = word, items = { { name = word, kind = "keyword",
      doc = "snippet", snippet = SNIPPETS[word][2] } } }
  end

  if afterDot then
    -- member completion: base = last identifier before the dot
    local base = before:match("(%a_%w*)%.$")
    if base then
      local items = Api.membersOf(base)
      if items then
        local filtered = {}
        local suffix = ""
        for _, it in items do
          table.insert(filtered, it)
        end
        return { prefix = suffix, member = true, base = base, items = filtered }
      end
    end
  end

  -- plain identifier: locals + globals
  if word and #word > 0 then
    local items = {}
    for _, name in Autocomplete.scanLocals(tab.doc.lines) do
      table.insert(items, { name = name, kind = "local", doc = "local" })
    end
    for name, doc in Api.Globals do
      table.insert(items, { name = name, kind = "global", doc = doc })
    end
    local filtered = {}
    for _, it in items do
      if it.name:lower():find(word:lower(), 1, true) == 1 then
        table.insert(filtered, it)
      end
    end
    table.sort(filtered, function(a, b) return a.name < b.name end)
    if #filtered > 0 then
      return { prefix = word, items = filtered }
    end
  end
  return nil
end

return Autocomplete
