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
