local H = require("./Harness")
local C = require("../src/Core/Config")
H.test("config validates persisted overrides", function()
    local store = {__SILVER_CONFIG = {consoleLimit = "wrong", theme = "light"}}
    C.init(store)
    H.eq(C.get("consoleLimit"), 500) H.eq(C.get("theme"), "light")
    H.eq(C.set("theme", 3, store), false)
    H.ok(C.set("theme", "obsidian", store)) H.eq(store.__SILVER_CONFIG.theme, "obsidian")
end)
return true
