local Currency = {
    Name = "比特",
}

function Currency.FormatNumber(value)
    local n = math.max(0, math.floor(tonumber(value) or 0))
    local text = tostring(n)
    local reversed = string.reverse(text)
    reversed = string.gsub(reversed, "(%d%d%d)", "%1,")
    text = string.reverse(reversed)
    return string.gsub(text, "^,", "")
end

function Currency.Format(value)
    return Currency.FormatNumber(value) .. " " .. Currency.Name
end

return Currency
