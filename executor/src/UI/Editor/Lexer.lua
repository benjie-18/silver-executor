--[[
  Lexer — line-oriented Luau tokenizer.
  State carries cross-line context: long-string open level, block-comment,
  type-annotation depth (for `::`).
  Token: {kind, col, col2}  (1-based, col..col2 inclusive)
  kinds: ws, comment, string, number, keyword, builtin, ident, call, type, op, punct
]]
local Lexer = {}

local KEYWORDS = {
  local = true, function = true, end = true, if = true, then = true,
  else = true, elseif = true, return = true, for = true, in = true,
  do = true, while = true, until = true, repeat = true, break = true,
  continue = true, and = true, or = true, not = true,
  true = true, false = true, nil = true, self = true,
}

local BUILTINS = {
  print = true, warn = true, error = true, pcall = true, xpcall = true,
  ipairs = true, pairs = true, select = true, tostring = true, tonumber = true,
  type = true, typeof = true, setmetatable = true, getmetatable = true,
  rawget = true, rawset = true, rawequal = true, rawlen = true, rawnext = true,
  unpack = true, next = true, assert = true, require = true, loadstring = true,
  setfenv = true, getfenv = true, tick = true, wait = true, spawn = true,
  delay = true, task = true, game = true, script = true, workspace = true,
  shared = true, sharedatamodel = true, getrenv = true, getgenv = true,
  gethui = true, getrenv = true, readclipboard = true, setclipboard = true,
  hookfunction = true, hookmetamethod = true, getcallingscript = true,
  getgc = true, getupvalue = true, sethiddenproperty = true,
  fromaddress = true, toaddress = true, getbytecode = true,
  writeflag = true, writeint = true, getint = true, getdword = true,
  getstring = true, getrawstring = true, makeobject = true,
  string = true, math = true, table = true, bit32 = true, buffer = true,
  utf8 = true, os = true, Enum = true,
}

local FUNCS = {
  function = true, for = true, if = true, while = true,
  repeat = true, return = true, do = true, then = true, and = true, or = true,
}

local OPS2 = { "~=", "==", "..", "::", "++", "--", "+=", "-=", "*=",
  "/=", "%=", "^=", "&=", "|=", "~=", "<<", ">>", "//", "&=", "|=" }
local OPS1 = { "~", "!", "<", ">", "+", "-", "*", "/", "%", "^",
  "&", "|", "#", "@", ":", "=", "?" }
local PUNCT = { "(", ")", "{", "}", "[", "]", ",", ";", "." }

local function isDigit(c) return c >= "0" and c <= "9" end
local function isIdentStart(c) return (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or c == "_" end
local function isIdentChar(c) return isIdentStart(c) or isDigit(c) end

function Lexer.newState()
  return { longOpen = nil, inBlockComment = false, typeDepth = 0, inType = false,
           pendingCall = false }
end

local function matchLongOpen(line, i)
  local n = 0
  local j = i + 1
  while j <= #line and line:sub(j, j) == "=" do j += 1; n += 1 end
  if line:sub(j, j) == "[" then return n, j + 1 end
  return nil
end

local function matchLongClose(line, i, level)
  local j = i + level
  for _ = 1, level do
    if line:sub(j, j) ~= "=" then return nil end
    j += 1
  end
  if line:sub(j, j) == "]" then return j + 1 end
  return nil
end

function Lexer.tokenizeLine(line, state)
  local toks = {}
  local i = 1
  local n = #line

  local function add(kind, from, to)
    if to >= from then table.insert(toks, { kind = kind, col = from, col2 = to }) end
  end

  while i <= n do
    local c = line:sub(i, i)
    local c2 = line:sub(i, i + 1)

    -- comments
    if c == "-" and c2 == "--" then
      if line:sub(i, i + 3) == "--[[" then
        state.inBlockComment = true
        local close = line:find("]]", i + 4)
        if close then
          state.inBlockComment = false
          add("comment", i, close + 1)
          i = close + 2
        else
          add("comment", i, n)
          i = n + 1
        end
        continue
      end
      add("comment", i, n)
      i = n + 1
      continue
    end
    if state.inBlockComment then
      local close = line:find("]]", i)
      if close then
        state.inBlockComment = false
        add("comment", i, close + 1)
        i = close + 2
      else
        add("comment", i, n)
        i = n + 1
      end
      continue
    end

    -- long strings
    if c == "[" and line:sub(i, i + 1) == "[[" then
      local close = line:find("]]", i + 2)
      if close then
        add("string", i, close + 1)
        i = close + 2
      else
        add("string", i, n)
        state.longOpen = 0
        i = n + 1
      end
      continue
    end
    if c == "[" then
      local lvl, nxt = matchLongOpen(line, i)
      if lvl then
        local close = line:find(string.rep("=", lvl) .. "]", nxt)
        if close then
          add("string", i, close + lvl)
          i = close + lvl + 1
        else
          add("string", i, n)
          state.longOpen = lvl
          i = n + 1
        end
        continue
      end
    end
    if state.longOpen then
      local lvl = state.longOpen
      local close = line:find(string.rep("=", lvl) .. "]", i)
      if close then
        add("string", i, close + lvl)
        i = close + lvl + 1
        state.longOpen = nil
      else
        add("string", i, n)
        i = n + 1
      end
      continue
    end

    -- short strings
    if c == '"' or c == "'" then
      local j = i + 1
      while j <= n do
        if line:sub(j, j) == "\\" then j += 2 continue end
        if line:sub(j, j) == c then break end
        j += 1
      end
      add("string", i, math.min(j, n))
      i = j + 1
      continue
    end

    -- numbers
    if isDigit(c) or (c == "." and isDigit(line:sub(i + 1, i + 1))) then
      local j = i
      while j <= n do
        local cj = line:sub(j, j)
        if isDigit(cj) or cj == "." or cj == "x" or cj == "X"
          or (cj >= "a" and cj <= "f") or (cj >= "A" and cj <= "F")
          or cj == "e" or cj == "E" or cj == "+" or cj == "-" then j += 1 else break end
      end
      add("number", i, j - 1)
      i = j
      continue
    end

    -- identifiers / keywords / builtins / calls
    if isIdentStart(c) then
      local j = i
      while j <= n and isIdentChar(line:sub(j, j)) do j += 1 end
      local word = line:sub(i, j - 1)
      if KEYWORDS[word] then
        add("keyword", i, j - 1)
      elseif BUILTINS[word] then
        add("builtin", i, j - 1)
      elseif state.pendingCall then
        add("call", i, j - 1)
        state.pendingCall = false
      else
        add("ident", i, j - 1)
      end
      i = j
      continue
    end

    -- type annotation (after ::)
    if state.inType then
      local depth = state.typeDepth
      if c == "(" or c == "[" then depth += 1 end
      if c == ")" or c == "]" then depth -= 1 end
      state.typeDepth = depth
      if depth <= 0 and (c == ")" or c == "}" or c == ";" or c == "\n") then
        state.inType = false
        state.typeDepth = 0
      end
      add("type", i, i)
      i += 1
      continue
    end

    -- operators (2-char first)
    local matched = false
    for _, op in OPS2 do
      if c2 == op then
        add("op", i, i + 1)
        if op == "::" then state.inType = true; state.typeDepth = 0 end
        if op == "(" then state.pendingCall = true end
        i += 2
        matched = true
        break
      end
    end
    if matched then continue end
    for _, op in OPS1 do
      if c == op then
        add("op", i, i)
        if c == "(" then state.pendingCall = true end
        if c == ")" then state.pendingCall = false end
        i += 1
        matched = true
        break
      end
    end
    if matched then continue end

    -- punctuation
    for _, p in PUNCT do
      if c == p then
        add("punct", i, i)
        i += 1
        matched = true
        break
      end
    end
    if matched then continue end

    -- whitespace / other
    add("ws", i, i)
    i += 1
  end

  return toks
end

return Lexer
