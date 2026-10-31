--[[
  EditorView — the editor surface.
  Owns rendering (line labels, gutter, caret, selection, folds), caret/selection
  model, mouse (click/drag/dbl-click), keys (edit + caret + undo/redo + shortcuts),
  autocomplete popup, and the find/replace bar.
  State that must survive tab switches lives on the TAB (caret, scrollY, sel, _hi).
  View-level state lives in S (firstVisible, dirty, popup, drag, transient labels).
]]
local Util = require(script.Parent.Util)
local Config = require(script.Parent.Config)
local ThemeManager = require(script.Parent.ThemeManager)
local Lexer = require(script.Parent.Lexer)
local Highlighter = require(script.Parent.Highlighter)
local Search = require(script.Parent.Search)
local Autocomplete = require(script.Parent.Autocomplete)
local Clipboard = require(script.Parent.Clipboard)
local Widgets = require(script.Parent.Widgets)

local EditorView = {}

local S = nil            -- view-level state (set in init)
local model = nil
local theme = nil
local editorCfg = {}

local LH = 18
local CHAR_W = 8
local GUTTER = 52
local PAD_X = 8

local PAIR = { ["("] = ")", "[" = "]", "{" = "}" }
local CLOSER = { [")"] = "(", "]" = "[", ["}"] = "{", ['"'] = '"', ["'"] = "'" }

local function hex(c) return string.format("#%02X%02X%02X", c.R, c.G, c.B) end

-- ── caret / selection ─────────────────────────────────────────────
local function setCaret(tab, line, col)
  local n = tab.doc.lineCount()
  line = Util.clamp(line, 1, n)
  col = Util.clamp(col, 0, #tab.doc.line(line))
  tab.caret = { line = line, col = col }
  S.dirty = true
end

local function setSel(tab, l1, c1, l2, c2)
  if l2 < l1 or (l2 == l1 and c2 < c1) then l1, c1, l2, c2 = l2, c2, l1, c1 end
  tab.sel = { l1, c1, l2, c2 }
  S.dirty = true
end

local function clearSel(tab) tab.sel = nil; tab.selAnchor = nil; S.dirty = true end

local function getSelText(tab)
  local sel = tab.sel
  if not sel then return nil end
  local l1, c1, l2, c2 = sel[1], sel[2], sel[3], sel[4]
  if l1 == l2 then
    local line = tab.doc.line(l1)
    return line:sub(c1 + 1, c2)
  end
  local parts = { tab.doc.line(l1):sub(c1 + 1) }
  for l = l1 + 1, l2 - 1 do parts[#parts + 1] = tab.doc.line(l) end
  parts[#parts + 1] = tab.doc.line(l2):sub(1, c2)
  return table.concat(parts, "\n")
end

local function deleteSel(tab)
  local sel = tab.sel
  if not sel then return end
  tab.doc:deleteRange(sel[1], sel[2], sel[3], sel[4])
  tab.caret = { line = sel[1], col = sel[2] }
  clearSel(tab)
end

local function invalidate(tab)
  tab._hi = nil
  S.dirty = true
end

local function buildHighlights(tab)
  local n = tab.doc.lineCount()
  local hi = {}
  local st = Lexer.newState()
  for i = 1, n do
    local ok, toks = pcall(Lexer.tokenizeLine, tab.doc.line(i), st)
    hi[i] = (ok and Highlighter.buildLine(tab.doc.line(i), toks, theme))
      or ("<font size=\"" .. theme.fontSize .. "\">" .. Util.escRich(tab.doc.line(i)) .. "</font>")
  end
  tab._hi = hi
  tab._hiRev = tab.doc.rev
end

local function insertText(tab, text)
  local doc = tab.doc
  local line, col = tab.caret.line, tab.caret.col
  local cur = doc.line(line)
  if #text == 1 then
    local close = PAIR[text]
    if close and cur:sub(col + 1, col + 1) == close then
      setCaret(tab, line, col + 1); return
    end
    if CLOSER[text] and cur:sub(col + 1, col + 1) == text then
      setCaret(tab, line, col + 1); return
    end
    if close and editorCfg.autoPairs then
      doc:insertAt(line, col, text .. close)
      setCaret(tab, line, col + 1); invalidate(tab); return
    end
  end
  doc:insertAt(line, col, text)
  local parts = Util.splitLines(text)
  setCaret(tab, line + #parts - 1, col + #parts[#parts])
  invalidate(tab)
end

local function expandSnippet(text)
  -- %1 markers → tabs; expand each \n with an indent tab
  local out = {}
  for seg in string.gmatch(text, "([^\n]*)" .. "\n") do
  end
  -- simple approach: split on \n, prefix tabs
  local lines = Util.splitLines(text)
  for i, l in lines do
    out[i] = ("\t"):rep(1) .. l
  end
  return table.concat(out, "\n")
end

-- ── autocomplete ───────────────────────────────────────────────────
local function closeAuto()
  if S.auto and S.auto.popup then S.auto.popup:Destroy() end
  S.auto = nil
end

local function wordBounds(line, col)
  local l = line
  local function isW(c) return c and c:match("[%w_]") end
  local s = col
  while s > 0 and isW(l:sub(s, s)) do s -= 1 end
  s += 1
  local e = col
  while e < #l and isW(l:sub(e + 1, e + 1)) do e += 1 end
  return s, e + 1
end

local function acceptAuto()
  local a = S.auto
  if not a then return end
  local tab = model.getActive()
  local item = a.items[a.sel]
  if item and item.kind == "keyword" and item.snippet then
    local s, e = wordBounds(tab.doc.line(tab.caret.line), tab.caret.col)
    tab.doc:deleteRange(tab.caret.line, s - 1, tab.caret.line, e - 1)
    local text = expandSnippet(item.snippet)
    insertText(tab, text)
  elseif item.kind == "member" then
    local before = tab.doc.line(tab.caret.line):sub(1, tab.caret.col)
    local dot = before:find("%.$")
    if dot then
      tab.doc:deleteRange(tab.caret.line, dot, tab.caret.line, tab.caret.col)
      local suffix = (item.kind == "method") and "()--" or ""
      insertText(tab, item.name .. (item.kind == "method" and "()" or ""))
    end
  else
    local s, e = wordBounds(tab.doc.line(tab.caret.line), tab.caret.col)
    tab.doc:deleteRange(tab.caret.line, s - 1, tab.caret.line, e - 1)
    insertText(tab, item.name)
  end
  closeAuto()
end

local function maybeAuto(force)
  local tab = model.getActive()
  if not tab then return end
  if not force and S.auto then
    local r = Autocomplete.compute(tab, tab.caret.line, tab.caret.col)
    if r and r.prefix == S.auto.prefix and r.member == S.auto.member then return end
  end
  local r = Autocomplete.compute(tab, tab.caret.line, tab.caret.col)
  if not r or #r.items == 0 then closeAuto(); return end
  if not force and not r.member and #r.prefix < 1 then closeAuto(); return end
  closeAuto()
  local a = { items = r.items, prefix = r.prefix or "", member = r.member, sel = 1 }
  a.popup = Instance.new("Frame", S.labelsLayer.Parent) -- parented to vp
  a.popup.Name = "autocomplete"
  a.popup.BackgroundColor3 = theme.panel
  a.popup.BorderSizePixel = 0
  a.popup.ZIndex = 30
  local w = 180
  local h = math.min(#a.items, 8) * 18 + 6
  local x = PAD_X + tab.caret.col * CHAR_W
  local y = (tab.caret.line - S.first) * LH + LH
  a.popup.Position = UDim2.fromOffset(Util.clamp(x, 0, S.vpW - w), y)
  a.popup.Size = UDim2.new(0, w, 0, h)
  a.buttons = {}
  for i = 1, math.min(#a.items, 8) do
    local it = a.items[i]
    local b = Instance.new("TextButton", a.popup)
    b.Position = UDim2.fromOffset(3, 3 + (i - 1) * 18)
    b.Size = UDim2.new(1, -6, 0, 18)
    b.BackgroundTransparency = 1
    b.Text = string.format("%-18s %s", it.name, it.kind or "")
    b.TextXAlignment = Enum.TextXAlignment.Left
    b.TextColor3 = theme.text
    b.Font = Enum.Font.Code; b.TextSize = 11
    b.MouseButton1Click:Connect(function() a.sel = i; acceptAuto() end)
    a.buttons[i] = b
  end
  a._render = function()
    for i, b in a.buttons do
      b.BackgroundColor3 = (i == a.sel) and theme.accent or Color3.new(0, 0, 0)
      b.BackgroundTransparency = (i == a.sel) and 0.25 or 1
    end
  end
  a._render()
  S.auto = a
end

local function autoNav(dir)
  if not S.auto then return end
  S.auto.sel = Util.clamp(S.auto.sel + dir, 1, #S.auto.items)
  S.auto._render()
end

-- ── mouse ──────────────────────────────────────────────────────────
local function mouseToLineCol(tab, ox, oy)
  local rows = math.floor(S.vpH / LH)
  local line = S.first + math.floor(oy / LH)
  line = Util.clamp(line, 1, tab.doc.lineCount())
  local col = math.floor((ox - PAD_X) / CHAR_W)
  col = Util.clamp(col, 0, #tab.doc.line(line))
  return line, col
end

local function onDown(tab, ox, oy, shift)
  local line, col = mouseToLineCol(tab, ox, oy)
  if shift and tab.selAnchor then
    setSel(tab, tab.selAnchor.line, tab.selAnchor.col, line, col)
  else
    clearSel(tab)
    tab.selAnchor = { line = line, col = col }
    setCaret(tab, line, col)
  end
  S.dragging = true
end

local function onDrag(tab, ox, oy)
  local line, col = mouseToLineCol(tab, ox, oy)
  if tab.selAnchor then
    setSel(tab, tab.selAnchor.line, tab.selAnchor.col, line, col)
  else
    setCaret(tab, line, col)
  end
end

local function onUp()
  S.dragging = false
  clearSel(model.getActive()) -- collapse to caret (keep simple)
end

local function onDouble(tab, ox, oy)
  local line, col = mouseToLineCol(tab, ox, oy)
  local s, e = tab.doc:selectWordAt(line, col)
  setSel(tab, s, s - 1, e, e - 1)
  tab.caret = { line = e, col = e }
end

-- ── search / replace ──────────────────────────────────────────────
local function currentFinder()
  return Search.makeFinder(S.search.q,
    { case = S.search.case, word = S.search.word, pattern = S.search.pattern })
end

local function findNext(dir)
  local tab = model.getActive()
  local findInLine = currentFinder()
  local matches = Search.findAll(tab.doc.lines, findInLine)
  if #matches == 0 then return end
  local cl, cc = tab.caret.line, tab.caret.col
  local idx = nil
  for i = 1, #matches do
    local m = matches[i]
    if m.line > cl or (m.line == cl and m.c1 >= cc) then idx = i break end
  end
  if not idx then idx = 1 end
  local m = matches[idx]
  setSel(tab, m.line, m.c1, m.line, m.c2)
  tab.caret = { line = m.line, col = m.c2 }
end

local function replaceOne()
  local tab = model.getActive()
  local txt = getSelText(tab)
  local q = S.search.q
  local cmp = (S.search.case and txt or txt:lower())
  local cq = (S.search.case and q or q:lower())
  if cmp == cq and txt ~= "" then
    deleteSel(tab)
    insertText(tab, S.search.replaceText)
    findNext(1)
  end
end

local function replaceAll()
  local tab = model.getActive()
  local n = Search.replaceAll(tab.doc, currentFinder(), S.search.replaceText)
  invalidate(tab)
  S.dirty = true
  return n
end

local function openSearch(replaceMode)
  S.search = { q = "", case = false, word = false, pattern = false,
               replaceText = "", replaceMode = replaceMode or false }
  if not S.searchBar then
    S.searchBar = Instance.new("Frame", S.host)
    S.searchBar.Name = "searchBar"
    S.searchBar.BackgroundColor3 = theme.panel
    S.searchBar.BorderSizePixel = 0
    S.searchBar.Position = UDim2.fromScale(0, 0)
    S.searchBar.Size = UDim2.new(1, 0, 0, 28)
    S.searchBar.Visible = false
    S.searchInput = Widgets.input(S.searchBar, {
      placeholder = "find…", theme = theme,
      pos = UDim2.fromOffset(8, 4), size = UDim2.new(0, 160, 0, 20),
      onEnter = function() findNext(1) end,
      onChange = function() end,
    })
    S.replaceInput = Widgets.input(S.searchBar, {
      placeholder = "replace…", theme = theme,
      pos = UDim2.fromOffset(176, 4), size = UDim2.new(0, 140, 0, 20),
    })
    local bx = 324
    local function btn(label, fn)
      local b = Widgets.button(S.searchBar, label, { theme = theme,
        pos = UDim2.fromOffset(bx, 4), size = UDim2.new(0, 46, 0, 20) })
      b.MouseButton1Click:Connect(fn)
      bx += 50
    end
    btn("Find", function() S.search.q = S.searchInput.getText(); findNext(1) end)
    btn("Next", function() findNext(1) end)
    btn("Prev", function()
      S.search.q = S.searchInput.getText()
      tab_ = model.getActive()
      local findInLine = currentFinder()
      local matches = Search.findAll(tab_.doc.lines, findInLine)
      if #matches == 0 then return end
      local cl, cc = tab_.caret.line, tab_.caret.col
      local idx = #matches
      for i = 1, #matches do
        local m = matches[i]
        if m.line < cl or (m.line == cl and m.c1 < cc) then idx = i break end
      end
      if idx == #matches then idx = 1 end
      local m = matches[idx]
      setSel(tab_, m.line, m.c1, m.line, m.c2)
      tab_.caret = { line = m.line, col = m.c2 }
    end)
    btn("Repl", function() replaceOne() end)
    btn("All", function() replaceAll() end)
    Widgets.button(S.searchBar, "✕", { theme = theme,
      pos = UDim2.fromOffset(bx, 4), size = UDim2.new(0, 20, 0, 20) })
      .MouseButton1Click:Connect(function() S.searchBar.Visible = false; S.search = nil end)
  end
  S.searchBar.Visible = true
  S.searchInput.setText(S.search.q)
  S.replaceInput.setText(S.search.replaceText)
  S.searchInput.onChange = function(v) S.search.q = v end
  S.replaceInput.onChange = function(v) S.search.replaceText = v end
  Widgets.focus.current = S.searchInput.id
end

-- ── render ─────────────────────────────────────────────────────────
local function relayout()
  local w, h = S.host.AbsoluteSize.X, S.host.AbsoluteSize.Y
  S.vpW = w - GUTTER; S.vpH = h
  S.gutter.Size = UDim2.new(0, GUTTER, 1, 0)
  S.vp.Position = UDim2.fromOffset(GUTTER, 0)
  S.vp.Size = UDim2.new(1, -GUTTER, 1, 0)
end

local function render()
  local tab = model.getActive()
  if not tab then return end
  local doc = tab.doc
  local n = doc.lineCount()
  if S.vpW == nil then relayout() end
  S.vpW = S.host.AbsoluteSize.X - GUTTER
  S.vpH = S.host.AbsoluteSize.Y
  local rows = math.floor(S.vpH / LH)
  local first = math.floor(tab.scrollY / LH)
  first = Util.clamp(first, 0, math.max(0, n - rows))
  S.first = first
  if not tab._hi or tab._hiRev ~= doc.rev then buildHighlights(tab) end

  -- labels
  for _, w in S.labels do w:Destroy() end
  S.labels = {}
  for i = first + 1, math.min(n, first + rows) do
    local w = Instance.new("TextLabel", S.labelsLayer)
    w.Position = UDim2.fromOffset(PAD_X, (i - first - 1) * LH)
    w.Size = UDim2.new(1, -PAD_X, 0, LH)
    w.BackgroundTransparency = 1
    w.TextXAlignment = Enum.TextXAlignment.Left
    w.TextYAlignment = Enum.TextYAlignment.Center
    w.Text = tab._hi[i] or ("<font size=\"" .. theme.fontSize .. "\">" .. Util.escRich(doc.line(i)))
    w.Font = Enum.Font.Code; w.TextSize = theme.fontSize
    S.labels[i] = w
  end

  -- gutter numbers + fold markers
  for _, w in S.gutterLabels do w:Destroy() end
  S.gutterLabels = {}
  local folds = tab._folds
  if not folds then tab._folds = folds = Highlighter.computeFolds(doc.lines) end
  for i = first + 1, math.min(n, first + rows) do
    local w = Instance.new("TextLabel", S.gutter)
    w.Position = UDim2.fromOffset(GUTTER - 22, (i - first - 1) * LH)
    w.Size = UDim2.new(0, 20, 0, LH)
    w.BackgroundTransparency = 1
    w.Text = (folds[i] and "▾ " or "   ") .. i
    w.TextXAlignment = Enum.TextXAlignment.Right
    w.TextColor3 = theme.editor.gutterText
    w.Font = Enum.Font.Code; w.TextSize = 10
    S.gutterLabels[i] = w
  end

  -- selection
  for _, f in S.selFrames do f:Destroy() end
  S.selFrames = {}
  local sel = tab.sel
  if sel then
    for l = sel[1], sel[3] do
      if l >= first + 1 and l <= first + rows then
        local c1 = (l == sel[1]) and sel[2] or 0
        local c2 = (l == sel[3]) and sel[4] or #doc.line(l)
        local x1, x2 = PAD_X + c1 * CHAR_W, PAD_X + c2 * CHAR_W
        local f = Instance.new("Frame", S.selLayer)
        f.Position = UDim2.fromOffset(x1, (l - first - 1) * LH)
        f.Size = UDim2.new(0, math.max(0, x2 - x1), 0, LH - 1)
        f.BackgroundColor3 = theme.editor.selection
        f.BackgroundTransparency = 0.2
        f.BorderSizePixel = 0
        S.selFrames[#S.selFrames + 1] = f
      end
    end
  end

  -- caret
  for _, f in S.caretFrames do f:Destroy() end
  S.caretFrames = {}
  if Widgets.focus.current == "editor" and tab.caret.line >= first + 1 and tab.caret.line <= first + rows then
    local f = Instance.new("Frame", S.caretLayer)
    f.Position = UDim2.fromOffset(PAD_X + tab.caret.col * CHAR_W, (tab.caret.line - first - 1) * LH)
    f.Size = UDim2.new(0, 1, 0, LH - 2)
    f.BackgroundColor3 = theme.caret
    f.BorderSizePixel = 0
    S.caretFrames[1] = f
  end
end

-- ── public API ────────────────────────────────────────────────────
function EditorView.init(host, modelArg, themeArg)
  model = modelArg
  theme = themeArg
  editorCfg = Config.get().editor
  S = {
    host = host, first = 1, dirty = true, auto = nil,
    labels = {}, gutterLabels = {}, selFrames = {}, caretFrames = {},
    lastW = 0, lastH = 0, dragging = false, vpW = nil, vpH = nil,
  }
  host.BackgroundColor3 = theme.editor.bg
  S.gutter = Instance.new("Frame", host)
  S.gutter.Name = "gutter"
  S.gutter.BackgroundColor3 = theme.editor.gutter
  S.gutter.BorderSizePixel = 0
  S.vp = Instance.new("Frame", host)
  S.vp.Name = "vp"
  S.vp.BackgroundColor3 = theme.editor.bg
  S.vp.BorderSizePixel = 0
  S.vp.ClipContents = true
  S.selLayer = Instance.new("Frame", S.vp); S.selLayer.BackgroundColor3 = theme.editor.bg
  S.labelsLayer = Instance.new("Frame", S.vp); S.labelsLayer.BackgroundTransparency = 1
  S.caretLayer = Instance.new("Frame", S.vp); S.caretLayer.BackgroundTransparency = 1

  relayout()

  -- mouse
  S.vp.MouseButton1Click:Connect(function()
    local tab = model.getActive()
    Widgets.focus.current = "editor"
    local mx, my = mouseToHost(S.vp)
    -- dbl-click detection
    local now = os.clock()
    if S._lastClick and (now - S._lastClick.t) < 0.35
      and S._lastClick.x == mx and S._lastClick.y == my then
      onDouble(tab, mx - PAD_X, my)
    else
      onDown(tab, mx - PAD_X, my)
    end
    S._lastClick = { t = now, x = mx, y = my }
  end)

  game:GetService("UserInputService").InputChanged:Connect(function(input)
    if S.dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
      local tab = model.getActive()
      local gp = input.Position
      local rel = gp - S.vp.AbsolutePosition
      onDrag(tab, rel.X - PAD_X, rel.Y)
    end
  end)
  game:GetService("UserInputService").InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 and S.dragging then onUp() end
  end)

  game:GetService("RunService").Heartbeat:Connect(function()
    local w, h = host.AbsoluteSize.X, host.AbsoluteSize.Y
    if w > 0 and (w ~= S.lastW or h ~= S.lastH) then
      S.lastW, S.lastH = w, h
      relayout()
    end
    if S.dirty then S.dirty = false; render() end
  end)
end

local function mouseToHost(frame)
  local gp = game:GetService("UserInputService"):GetMouseLocation()
  return gp.X - frame.AbsolutePosition.X, gp.Y - frame.AbsolutePosition.Y
end

function EditorView.setTheme(t)
  theme = t
  if S then
    S.host.BackgroundColor3 = t.editor.bg
    S.gutter.BackgroundColor3 = t.editor.gutter
    S.vp.BackgroundColor3 = t.editor.bg
    S.selLayer.BackgroundColor3 = t.editor.bg
    S.dirty = true
  end
end

function EditorView.focus() Widgets.focus.current = "editor" end
function EditorView.blur() if Widgets.focus.current == "editor" then Widgets.focus.current = nil end end

function EditorView.handleKey(key, shift, ctrl)
  local tab = model.getActive()
  if not tab then return false end
  local doc = tab.doc
  if S.auto then
    if key == Enum.KeyCode.Escape then closeAuto(); return true end
    if key == Enum.KeyCode.Down then autoNav(1); return true end
    if key == Enum.KeyCode.Up then autoNav(-1); return true end
    if key == Enum.KeyCode.Tab or key == Enum.KeyCode.Enter then acceptAuto(); return true end
  end
  if ctrl then
    if key == Enum.KeyCode.Z then (shift and doc:redo() or doc:undo()); invalidate(tab); return true end
    if key == Enum.KeyCode.Y then doc:redo(); invalidate(tab); return true end
    if key == Enum.KeyCode.A then
      clearSel(tab)
      setSel(tab, 1, 0, doc.lineCount(), #doc.line(doc.lineCount()))
      return true
    end
    if key == Enum.KeyCode.C then local t = getSelText(tab); if t then Clipboard.copy(t) end; return true end
    if key == Enum.KeyCode.X then local t = getSelText(tab); if t then Clipboard.copy(t) end; deleteSel(tab);
return true end
    if key == Enum.KeyCode.V then local t = Clipboard.paste(); if t then insertText(tab, t) end; invalidate(tab);
return true end
    if key == Enum.KeyCode.F then openSearch(false); return true end
    if key == Enum.KeyCode.H then openSearch(true); return true end
    if key == Enum.KeyCode.Space then maybeAuto(true); return true end
    return false
  end
  local line, col = tab.caret.line, tab.caret.col
  if key == Enum.KeyCode.Left then
    (shift and setSel(tab, tab.selAnchor and tab.selAnchor.line or line, tab.selAnchor and tab.selAnchor.col or
col, line, col - 1))
      or setCaret(tab, line, col - 1)
    if not shift then tab.selAnchor = { line = line, col = col } end
    return true
  end
  if key == Enum.KeyCode.Right then
    (shift and setSel(tab, tab.selAnchor and tab.selAnchor.line or line, tab.selAnchor and tab.selAnchor.col or
col, line, col + 1))
      or setCaret(tab, line, col + 1)
    return true
  end
  if key == Enum.KeyCode.Up then
    (shift and setSel(tab, tab.selAnchor and tab.selAnchor.line or line, tab.selAnchor and tab.selAnchor.col or
col, line - 1, col))
      or setCaret(tab, line - 1, col)
    return true
  end
  if key == Enum.KeyCode.Down then
    (shift and setSel(tab, tab.selAnchor and tab.selAnchor.line or line, tab.selAnchor and tab.selAnchor.col or
col, line + 1, col))
      or setCaret(tab, line + 1, col)
    return true
  end
  if key == Enum.KeyCode.Home then
    (shift and setSel(tab, line, (tab.selAnchor and tab.selAnchor.line == line and tab.selAnchor.col) or line,
line, 0))
      or setCaret(tab, line, 0)
    if not shift then tab.selAnchor = { line = line, col = 0 } end
    return true
  end
  if key == Enum.KeyCode.End then
    (shift and setSel(tab, line, 0, line, #doc.line(line)))
      or setCaret(tab, line, #doc.line(line))
    if not shift then tab.selAnchor = { line = line, col = #doc.line(line) } end
    return true
  end
  if key == Enum.KeyCode.Enter then
    local indent = doc.line(line):match("^( *%s*%)") or ""
    local nl, nc = doc:enter(line, col, indent)
    setCaret(tab, nl, nc); invalidate(tab); return true
  end
  if key == Enum.KeyCode.Tab then
    doc:indentLines(line, line); setCaret(tab, line, col + 4); invalidate(tab); return true
  end
  if key == Enum.KeyCode.Backspace then
    local nl, nc = doc:backspace(line, col); setCaret(tab, nl, nc); invalidate(tab); return true
  end
  if key == Enum.KeyCode.Delete then
    local nl, nc = doc:deleteKey(line, col); setCaret(tab, nl, nc); invalidate(tab); return true
  end
  if key == Enum.KeyCode.PageUp then tab.scrollY = math.max(0, tab.scrollY - LH * 10); S.dirty = true; return true
end
  if key == Enum.KeyCode.PageDown then tab.scrollY = tab.scrollY + LH * 10; S.dirty = true; return true end

  local ch = Widgets.CHAR_MAP[key] or (shift and Widgets.SHIFT_MAP[key])
  if ch then
    insertText(tab, ch)
    maybeAuto(false)
    return true
  end
  return false
end

function EditorView.refresh() S.dirty = true end
function EditorView.openSearchBar(replaceMode) openSearch(replaceMode) end

return EditorView
