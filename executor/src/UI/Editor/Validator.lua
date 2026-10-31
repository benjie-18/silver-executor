--[[
  Validator — structural diagnostics: block balance, unterminated strings,
  dangling and/or. Uses the Lexer state across lines.
]]
local Lexer = require(script.Parent.Lexer)
local Validator = {}

function Validator.check(lines)
  local errors = {}
  local state = Lexer.newState()
  local stack = {}

  for i = 1, #lines do
    local line = lines[i]
    local toks = Lexer.tokenizeLine(line, state)
    for _, tok in toks do
      if tok.kind == "keyword" then
        local word = line:sub(tok.col, tok.col2)
        if word == "function" or word == "if" or word == "for" or word == "while" or word == "repeat" then
          table.insert(stack, { kind = word, line = i, col = tok.col })
        elseif word == "end" then
          if #stack == 0 then
            table.insert(errors, { line = i, col = tok.col, level = "error",
              msg = "unexpected 'end'" })
          else
            table.remove(stack)
          end
        elseif word == "until" then
          if #stack > 0 and stack[#stack].kind == "repeat" then
            table.remove(stack)
          else
            table.insert(errors, { line = i, col = tok.col, level = "error",
              msg = "unexpected 'until'" })
          end
        end
      end
    end
    -- dangling and/or
    local lastNonWs = nil
    for _, tok in toks do
      if tok.kind ~= "ws" and tok.kind ~= "comment" then lastNonWs = tok end
    end
    if lastNonWs and lastNonWs.kind == "keyword" then
      local w = line:sub(lastNonWs.col, lastNonWs.col2)
      if w == "and" or w == "or" or w == "not" then
        table.insert(errors, { line = i, col = lastNonWs.col, level = "warn",
          msg = "dangling '" .. w .. "' at end of line" })
      end
    end
  end

  if state.inBlockComment then
    table.insert(errors, { line = #lines, col = 0, level = "error",
      msg = "unterminated block comment" })
  end

  for _, open in stack do
    table.insert(errors, { line = open.line, col = open.col, level = "error",
      msg = "unclosed '" .. open.kind .. "'" })
  end

  table.sort(errors, function(a, b) return a.line < b.line end)
  return errors
end

return Validato
