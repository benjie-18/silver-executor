local H = require("./Harness")
local U = require("../src/Core/Util")
H.test("lines normalize CRLF and preserve trailing empty", function()
    local lines = U.lines("a\r\nb\r")
    H.eq(#lines, 3) H.eq(lines[2], "b") H.eq(lines[3], "")
end)
H.test("rich text escape", function() H.eq(U.escape('<a & "b">'), '&lt;a &amp; &quot;b&quot;&gt;') end)
return true
