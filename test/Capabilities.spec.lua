local H = require("./Harness")
local Inject = require("../src/Inject/Inject")
local Theme = require("../src/Core/ThemeManager")
local Api = require("../src/Api/RobloxApi")
H.test("explicit host without compiler cannot silently use ambient compiler", function()
    local compiler, detail = Inject.probe({})
    H.eq(compiler, nil)
    H.ok(detail:find("editor-only", 1, true))
    local fn = function() end
    H.eq(Inject.probe({loadstring = fn}), fn)
end)
H.test("themes and compact API are usable without Roblox for host tests", function()
    local colors = {fromRGB = function(r, g, b) return {r, g, b} end}
    local t = Theme.get("obsidian", colors)
    H.eq(t.bg[1], 15)
    H.eq(Theme.get("unknown", colors).bg[1], 15)
    H.ok(#Api.globals > 0)
end)
return true
