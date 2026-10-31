--[[
  Config — layered configuration: DEFAULTS <- persisted overrides (genv).
  Every tunable lives here: theme, editor, execution, layout, injection.
]]
local Util = require(script.Parent.Util)
local Config = {}

local DEFAULTS = {
  theme = "obsidian",
  autoInject = false,
  font = { family = "Consolas", size = 13 },
  timeoutMs = 30000,        -- 0 = no timeout
  isolate = true,           -- sandbox user globals into a private env
  editor = {
    autoPairs = true, autoEnd = true, autoIndent = true,
    showFolds = true, undoLimit = 128,
  },
  console = { maxLines = 1500, autoScroll = true },
  layout = { rightWidth = 280, rightSplit = 0.5, consoleHeight = 190,
             minConsole = 64, minRight = 200, minRightSplit = 0.15, maxRightSplit = 0.85 },
  inject = {
    escIntervalMs = 450,
    envPollMs = 100, envPollTimeoutMs = 6000,
    maxThreadsToScan = 512,
    restoreAfterCapture = true,
    coreThreadDenylist = { "MainLoop", "RenderLoop", "JSThread", "CoreUI", "Jest" },
  },
}

local overrides = {}
local storage = nil

function Config.init(storageTable)
  storage = storageTable
  if type(storageTable) == "table" and type(storageTable.__LX_CONFIG__) == "table" then
    overrides = Util.deepCopy(storageTable.__LX_CONFIG__)
  end
end

function Config.get()
  local out = Util.deepCopy(DEFAULTS)
  Util.merge(out, overrides)
  return out
end

function Config.update(t)
  Util.merge(overrides, t)
  Config.persist()
end

function Config.persist()
  if type(storage) == "table" then storage.__LX_CONFIG__ = Util.deepCopy(overrides) end
  return overrides
end

function Config.value(dotted)
  local t = Config.get()
  for part in string.gmatch(dotted, "[^%.]+") do
    if type(t) ~= "table" then return nil end
    t = t[part]
  end
  return t
end

return Config
