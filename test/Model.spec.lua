local H = require("./Harness")
local M = require("../src/UI/Editor/EditorModel")
H.test("tabs select and close with stable ids", function()
    local m = M.new() local first = m:current().id
    local second = m:add("two", "content")
    H.eq(m:current().id, second.id)
    H.ok(m:close(second.id)) H.eq(m:current().id, first)
    H.eq(m:close(first), false)
end)
return true
