local H = require("./Harness")
local C = require("../src/Engine/Console")
H.test("bounded log and unsubscribe", function()
    local c = C.new(2) local calls = 0
    local off = c:onChange(function() calls += 1 end)
    c:log("info", "a") c:log("warn", "b") c:log("error", "c")
    H.eq(#c.lines, 2) H.eq(calls, 3)
    off() c:clear() H.eq(calls, 3) H.eq(c:text(), "")
end)
return true
