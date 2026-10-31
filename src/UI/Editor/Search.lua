local Search = {}
-- Literal search by default; patterns are explicit. Empty/invalid patterns cannot loop forever.
function Search.findAll(lines, query, options)
    options = options or {}
    if query == "" then return {}, nil end
    local result = {}
    local needle = options.caseSensitive and query or query:lower()
    for lineNo, raw in ipairs(lines) do
        local text = options.caseSensitive and raw or raw:lower()
        local pos = 1
        while pos <= #text do
            local ok, first, last = pcall(string.find, text, needle, pos, not options.pattern)
            if not ok then return {}, first end
            if not first then break end
            if last < first then return {}, "zero-width patterns are not supported" end
            local left = first == 1 or not text:sub(first - 1, first - 1):match("[%w_]")
            local right = last == #text or not text:sub(last + 1, last + 1):match("[%w_]")
            if not options.word or (left and right) then
                table.insert(result, {line = lineNo, startCol = first - 1, endCol = last})
            end
            pos = last + 1
        end
    end
    return result, nil
end
function Search.replaceAll(doc, query, replacement, options)
    local matches, err = Search.findAll(doc.lines, query, options)
    if err or #matches == 0 then return 0, err end
    -- One undo checkpoint for the whole operation; literal replacement (no capture substitution).
    local lines = table.clone(doc.lines)
    for i = #matches, 1, -1 do
        local m = matches[i]
        local line = lines[m.line]
        lines[m.line] = line:sub(1, m.startCol) .. replacement .. line:sub(m.endCol + 1)
    end
    doc:setText(table.concat(lines, "\n"))
    return #matches, nil
end
return Search
