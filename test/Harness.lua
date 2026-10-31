local Harness = {count = 0, failed = 0}
function Harness.eq(actual, expected)
    if actual ~= expected then error(`expected {tostring(expected)}, got {tostring(actual)}`, 2) end
end
function Harness.ok(value)
    if not value then error("expected truthy value", 2) end
end
function Harness.test(name, fn)
    Harness.count += 1
    local ok, err = pcall(fn)
    if ok then print("PASS " .. name)
    else Harness.failed += 1 print("FAIL " .. name .. ": " .. tostring(err)) end
end
return Harness
