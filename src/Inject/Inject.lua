-- Explicit capability gate. No unverified memory offsets or CoreScript/thread hijacking.
local Inject = {}
function Inject.probe(host)
    local compiler = if host ~= nil then host.loadstring else loadstring
    if type(compiler) == "function" then return compiler, "host compiler available" end
    return nil, "no compiler available; editor-only mode"
end
return Inject
