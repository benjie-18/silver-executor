local Util = {}
function Util.lines(text)
    text = (text or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
    local result = {}
    for line in (text .. "\n"):gmatch("(.-)\n") do table.insert(result, line) end
    return result
end
function Util.escape(text)
    return tostring(text):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;")
end
function Util.copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for k, v in pairs(value) do result[Util.copy(k)] = Util.copy(v) end
    return result
end
return Util
