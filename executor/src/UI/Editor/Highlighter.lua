--[[
  Highlighter — tokens → Roblox rich-text span per line; fold-region scan.
]]
local Util = require(script.Parent.Util)
local Lexer = require(script.Parent.Lexer)
local Highlighter = {}

local function span(text, col)
  return "<color=#" .. string.format("%02X%02X%02X", col.R, col.G, col.B) .. ">"
    .. Util.escRich(text) .. "</color>"
end

function Highlighter.buildLine(lineText, tokens, theme)
  local et = theme.editor
  local out = {}
  local cursor = 0
  for _, tok in tokens do
    if tok.col > cursor then
      local gap = string.sub(lineText, cursor + 1, tok.col)
      out[#out + 1] = span(gap, et.line)
      cursor = tok.col
    end
    local t = string.sub(lineText, tok.col, tok.col2)
    local k = tok.kind
    local col
    if k == "comment" then col = et.comment
    elseif k == "string" then col = et.string
    elseif k == "number" then col = et.number
    elseif k == "keyword" then col = et.keyword
    elseif k == "builtin" then col = et.builtin
    elseif k == "call" then col = et.func
    elseif k == "ident" then col = et.line
    elseif k == "type" then col = et.type
    elseif k == "op" then col = et.op
    else col = et.line end
    out[#out + 1] = span(t, col)
    cursor = tok.col2
  end
  if cursor < #lineText then
    out[#out + 1] = span(string.sub(lineText, cursor + 1), et.line)
  end
  return string.format('<font face="%s" size="%d">', theme.fontFamily, theme.fontSize)
    .. table.concat(out) .. "</font>"
end

-- foldable block starts: function/if/for/while/repeat with a multi-line span
function Highlighter.computeFolds(lines)
  local folds = {}
  local n = #lines
  for start = 1, n do
    local line = lines[start]
    local trimmed = line:match("^%s*(.-)%s*$")
    if trimmed:match("^(function|local function)%s")
      or trimmed:match("^if%s") and not trimmed:match("^if%s.*then%s*$") == nil
      or trimmed:match("^for%s")
      or trimmed:match("^while%s")
      or trimmed:match("^repeat$") then
      -- find matching end by scanning block keywords
      local depth = 0
      local i = start
      local found = nil
      while i <= n do
        local toks = Lexer.tokenizeLine(lines[i], Lexer.newState())
        for _, tok in toks do
          if tok.kind == "keyword" then
            local word = lines[i]:sub(tok.col, tok.col2)
            if word == "function" or word == "if" or word == "for" or word == "while" or word == "repeat" then
              depth += 1
            elseif word == "end" or word == "until" then
              depth -= 1
              if depth == 0 then
                found = i
                break
              end
            end
          end
        end
        if found then break end
        i += 1
      end
      if found and found > start + 1 then
        folds[start] = found
      end
    end
  end
  return folds
end

return Highlighter
