local Theme = {}
local palettes = {
    obsidian = { bg = {15, 17, 23}, panel = {28, 32, 42}, text = {215, 222, 235}, accent = {100, 155, 255}, muted = {130, 142, 161} },
    light = { bg = {245, 247, 252}, panel = {225, 232, 242}, text = {30, 39, 58}, accent = {35, 95, 200}, muted = {95, 108, 128} },
}
function Theme.get(name, colors)
    colors = colors or Color3
    local src = palettes[name] or palettes.obsidian
    local out = {}
    for key, rgb in pairs(src) do out[key] = colors.fromRGB(table.unpack(rgb)) end
    return out
end
function Theme.names() return {"obsidian", "light"} end
return Theme
