local BlackMarketCloud = {}

BlackMarketCloud.KEY = "soudace_black_market_profile"

function BlackMarketCloud.IsAvailable()
    return clientCloud ~= nil
end

function BlackMarketCloud.Load(callback)
    if not BlackMarketCloud.IsAvailable() then
        callback(nil, "unavailable")
        return
    end

    local settled = false
    local function finish(snapshot, status, detail)
        if settled then return end
        settled = true
        callback(snapshot, status, detail)
    end

    local ok, reason = pcall(function()
        clientCloud:Get(BlackMarketCloud.KEY, {
            ok = function(values)
                local snapshot = type(values) == "table"
                    and values[BlackMarketCloud.KEY] or nil
                finish(snapshot, snapshot and "loaded" or "empty")
            end,
            error = function(code, message)
                finish(nil, "error", tostring(code) .. " " .. tostring(message))
            end,
            timeout = function()
                finish(nil, "timeout", "request timeout")
            end,
        })
    end)
    if not ok then
        finish(nil, "error", tostring(reason))
    end
end

function BlackMarketCloud.Save(snapshot, callback)
    if not BlackMarketCloud.IsAvailable() then
        if callback then callback(false, "unavailable") end
        return
    end

    local settled = false
    local function finish(success, status, detail)
        if settled then return end
        settled = true
        if callback then callback(success, status, detail) end
    end

    local ok, reason = pcall(function()
        clientCloud:Set(BlackMarketCloud.KEY, snapshot, {
            ok = function()
                finish(true, "saved")
            end,
            error = function(code, message)
                finish(false, "error", tostring(code) .. " " .. tostring(message))
            end,
            timeout = function()
                finish(false, "timeout", "request timeout")
            end,
        })
    end)
    if not ok then
        finish(false, "error", tostring(reason))
    end
end

return BlackMarketCloud
