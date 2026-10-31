local Config = {}
local defaults = { theme = "obsidian", consoleLimit = 500, maxSourceBytes = 250000 }
local values = {}
function Config.init(storage)
    values = {}
    if type(storage) == "table" and type(storage.__SILVER_CONFIG) == "table" then
        for k, v in pairs(storage.__SILVER_CONFIG) do
            if type(v) == type(defaults[k]) then values[k] = v end
        end
    end
end
function Config.get(key) return values[key] or defaults[key] end
function Config.set(key, value, storage)
    if type(value) ~= type(defaults[key]) then return false end
    values[key] = value
    if type(storage) == "table" then storage.__SILVER_CONFIG = values end
    return true
end
return Config
