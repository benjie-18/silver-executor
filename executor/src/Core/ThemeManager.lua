--[[
  ThemeManager — configurable themes with live re-skin.
  Colors are full RGB; panels subscribe via onChanged.
]]
local ThemeManager = {}

local function C(r, g, b) return Color3.fromRGB(r, g, b) end

local THEMES = {
  obsidian = {
    name = "Obsidian", base = C(13,15,19), panel = C(20,23,29), panelAlt = C(27,31,38),
    border = C(45,50,60), text = C(202,210,218), muted = C(108,117,126),
    accent = C(88,140,255), accentHover = C(110,158,255), ok = C(63,185,80),
    warn = C(210,153,34), err = C(248,81,76), caret = C(220,226,235),
    editor = {
      bg = C(15,17,21), gutter = C(21,24,30), gutterText = C(90,98,108),
      gutterActive = C(88,140,255), line = C(202,210,218),
      selection = C(38,58,98), fold = C(139,148,158),
      keyword = C(255,123,114), builtin = C(121,192,255), string = C(165,214,255),
      number = C(110,231,183), comment = C(139,148,158), func = C(210,168,255),
      op = C(209,151,217), type = C(103,217,237),
    },
  },
  dracula = {
    name = "Dracula", base = C(24,26,32), panel = C(40,42,54), panelAlt = C(68,71,90),
    border = C(88,91,112), text = C(244,244,245), muted = C(98,114,164),
    accent = C(189,147,249), accentHover = C(214,178,255), ok = C(80,250,123),
    warn = C(255,184,108), err = C(255,85,112), caret = C(254,129,171),
    editor = {
      bg = C(24,26,32), gutter = C(40,42,54), gutterText = C(98,114,164),
      gutterActive = C(189,147,249), line = C(244,244,245),
      selection = C(88,91,112), fold = C(98,114,164),
      keyword = C(189,147,249), builtin = C(137,221,255), string = C(255,184,108),
      number = C(80,250,123), comment = C(98,114,164), func = C(255,121,198),
      op = C(255,121,198), type = C(209,127,171),
    },
  },
  solar = {
    name = "Solar", base = C(38,42,49), panel = C(46,52,61), panelAlt = C(69,77,87),
    border = C(92,99,109), text = C(152,160,167), muted = C(106,115,125),
    accent = C(134,179,2,255) and C(134,179,255), accentHover = C(157,202,255),
    ok = C(134,179,255), warn = C(241,250,140), err = C(225,27,27), caret = C(152,160,167),
    editor = {
      bg = C(38,42,49), gutter = C(46,52,61), gutterText = C(106,115,125),
      gutterActive = C(134,179,255), line = C(152,160,167),
      selection = C(69,77,87), fold = C(106,115,125),
      keyword = C(134,179,255), builtin = C(138,201,39), string = C(230,162,74),
      number = C(255,121,198), comment = C(106,115,125), func = C(255,198,9),
      op = C(255,71,87), type = C(235,147,174),
    },
  },
}
THEMES.solar.accent = C(134,179,255) -- (clear from above)

local current = "obsidian"
local subs = {}

function ThemeManager.init(name)
  if THEMES[name] then current = name end
end

function ThemeManager.set(name)
  if THEMES[name] then
    current = name
    for _, fn in subs do fn(ThemeManager.get()) end
  end
end

function ThemeManager.onChanged(fn) table.insert(subs, fn) end
function ThemeManager.get() return THEMES[current] end
function ThemeManager.list()
  local out = {}
  for k in pairs(THEMES) do table.insert(out, k) end
  table.sort(out)
  return out
end

return ThemeManager
