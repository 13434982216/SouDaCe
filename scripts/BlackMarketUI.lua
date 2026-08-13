local BlackMarketUI = {
    activeTab = "quotes",
    hovered = nil,
    pressed = nil,
    tabRects = {},
    categoryRects = {},
    sellRowRects = {},
    orderRowRects = {},
    merchantRowRects = {},
    backRect = nil,
    primaryRect = nil,
    secondaryRect = nil,
    listViewport = nil,
    orderViewport = nil,
    historyViewport = nil,
    selectedCategory = "all",
    selectedSellKey = nil,
    selectedOrderId = nil,
    selectedMerchantId = nil,
    sellSelection = {},
    scrollOffset = 0,
    scrollMax = 0,
    orderScrollOffset = 0,
    orderScrollMax = 0,
    historyScrollOffset = 0,
    historyScrollMax = 0,
    scrollKind = nil,
    notice = "",
    noticeTimer = 0,
    noticeSuccess = false,
    animTime = 0,
    touchId = nil,
    touchStartX = 0,
    touchStartY = 0,
    touchScrollStart = 0,
    touchScrolling = false,
    ignoreMouseTimer = 0,
    layoutScale = 1,
    layoutOffsetX = 0,
    layoutOffsetY = 0,
    layoutWidth = 1568,
}

local DESIGN_W, DESIGN_H = 1568, 1038
-- 与首页统一：旧金属、暗橄榄黑、纸张米色、行动红和黄铜金。
local ACCENT = { 217, 169, 74 }
local INK = { 28, 24, 17 }
local PANEL = { 13, 17, 14 }
local PAPER = { 221, 211, 183 }
local MUTED = { 148, 145, 126 }
local ACTION_RED = { 160, 57, 41 }
local SAFE_GREEN = { 101, 148, 66 }
local TABS = {
    { id = "quotes", label = "行情总览" },
    { id = "sell", label = "快速出售" },
    { id = "orders", label = "收购订单" },
    { id = "merchant", label = "神秘商人" },
    { id = "history", label = "交易记录" },
}
local CATEGORIES = {
    { id = "all", label = "全部物资", code = "ALL" },
    { id = "valuables", label = "贵重收藏", code = "VAL" },
    { id = "electronics", label = "电子设备", code = "ELC" },
    { id = "medical", label = "医疗物资", code = "MED" },
    { id = "materials", label = "工具材料", code = "MAT" },
    { id = "equipment", label = "武器装备", code = "EQP" },
    { id = "supplies", label = "生存补给", code = "SUP" },
}
local CATEGORY_LABELS = {
    all = "全部物资", valuables = "贵重收藏", electronics = "电子设备", medical = "医疗物资",
    materials = "工具材料", equipment = "武器装备", supplies = "生存补给",
}
local CATEGORY_ITEMS = {
    electronics = {
        ["旧手机"] = true, ["机械键盘"] = true, ["平板电脑"] = true, ["加密硬盘"] = true,
        ["卫星电话"] = true, ["显卡"] = true, ["军用加固笔记本"] = true, ["加密无人机核心"] = true,
        ["航空级控制芯片"] = true, ["军用热成像仪"] = true,
    },
    medical = { ["急救包"] = true, ["机密生物样本"] = true },
    materials = {
        ["螺丝刀"] = true, ["电池"] = true, ["胶带"] = true, ["扳手"] = true,
        ["高纯度钯金块"] = true, ["精密光学模组"] = true,
    },
    equipment = {
        ["手枪"] = true, ["散弹枪"] = true, ["棒球棍"] = true, ["二级头盔"] = true,
        ["二级防弹衣"] = true, ["二级胸挂"] = true, ["二级背包"] = true, ["二级安全箱"] = true,
        ["三级安全箱"] = true, ["手枪弹药盒"] = true, ["散弹枪弹药包"] = true,
        ["通用战术消音器"] = true,
    },
    supplies = { ["罐头"] = true, ["净水"] = true, ["稀有咖啡豆"] = true, ["香槟酒"] = true, ["高级香烟"] = true },
}
local RARITY_COLORS = {
    red = { 191, 57, 48 }, pink = { 190, 72, 136 }, gold = { 218, 160, 38 },
    purple = { 128, 78, 178 }, blue = { 54, 116, 181 }, green = { 62, 139, 86 },
}
local RARITY_LABELS = { red = "传说", pink = "史诗", gold = "珍藏", purple = "稀有", blue = "精良", green = "普通" }

local function clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

local function splitWidths(totalWidth, gap, baseWidths)
    local available = totalWidth - gap * (#baseWidths - 1)
    local baseTotal = 0
    for _, baseWidth in ipairs(baseWidths) do baseTotal = baseTotal + baseWidth end
    local result = {}
    local used = 0
    for index, baseWidth in ipairs(baseWidths) do
        local width
        if index == #baseWidths then
            width = available - used
        else
            width = available * baseWidth / baseTotal
            used = used + width
        end
        result[index] = width
    end
    return result
end

local function rgba(color, alpha)
    return nvgRGBA(color[1], color[2], color[3], alpha or color[4] or 255)
end

local function pointInRect(x, y, rect)
    return rect and x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h
end

local function formatNumber(value)
    local text = tostring(math.max(0, math.floor(tonumber(value) or 0)))
    local reversed = string.reverse(text)
    reversed = string.gsub(reversed, "(%d%d%d)", "%1,")
    return string.gsub(string.reverse(reversed), "^,", "")
end

local function formatCountdown(seconds)
    local total = math.max(0, math.ceil(tonumber(seconds) or 0))
    local hours = math.floor(total / 3600)
    local minutes = math.floor((total % 3600) / 60)
    local secs = total % 60
    return string.format("%02d:%02d:%02d", hours, minutes, secs)
end

local function percent(rate)
    local delta = math.floor(((tonumber(rate) or 1) - 1) * 100 + 0.5)
    return (delta >= 0 and "+" or "") .. tostring(delta) .. "%", delta
end

local function toDesignPoint(x, y)
    local scale = BlackMarketUI.layoutScale
    if scale <= 0 then return x, y end
    return x / scale - BlackMarketUI.layoutOffsetX, y / scale - BlackMarketUI.layoutOffsetY
end

local function drawFrameCorners(ctx, x, y, w, h, color, length, inset)
    local mark = math.min(length or 12, w * 0.24, h * 0.34)
    local pad = inset or 3
    local left, top = x + pad, y + pad
    local right, bottom = x + w - pad, y + h - pad
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, left, top + mark)
    nvgLineTo(ctx, left, top)
    nvgLineTo(ctx, left + mark, top)
    nvgMoveTo(ctx, right - mark, top)
    nvgLineTo(ctx, right, top)
    nvgLineTo(ctx, right, top + mark)
    nvgMoveTo(ctx, left, bottom - mark)
    nvgLineTo(ctx, left, bottom)
    nvgLineTo(ctx, left + mark, bottom)
    nvgMoveTo(ctx, right - mark, bottom)
    nvgLineTo(ctx, right, bottom)
    nvgLineTo(ctx, right, bottom - mark)
    nvgStrokeColor(ctx, color)
    nvgStrokeWidth(ctx, 1.7)
    nvgStroke(ctx)
end

local function drawPanel(ctx, x, y, w, h, fill, border, active)
    if w > 80 and h > 42 then
        local shadow = nvgBoxGradient(ctx, x - 5, y - 4, w + 10, h + 12,
            5, 9, nvgRGBA(0, 0, 0, 135), nvgRGBA(0, 0, 0, 0))
        nvgBeginPath(ctx)
        nvgRect(ctx, x - 13, y - 13, w + 26, h + 26)
        nvgFillPaint(ctx, shadow)
        nvgFill(ctx)
    end

    local topColor = nvgRGBA(
        math.min(255, (fill[1] or 0) + 13),
        math.min(255, (fill[2] or 0) + 13),
        math.min(255, (fill[3] or 0) + 10), fill[4] or 255)
    local bottomColor = nvgRGBA(
        math.max(0, (fill[1] or 0) - 7),
        math.max(0, (fill[2] or 0) - 7),
        math.max(0, (fill[3] or 0) - 6), fill[4] or 255)
    local surface = nvgLinearGradient(ctx, x, y, x, y + h,
        topColor, bottomColor)
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x, y, w, h, 3)
    nvgFillPaint(ctx, surface)
    nvgFill(ctx)

    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x, y, w, h, 3)
    nvgStrokeColor(ctx, rgba(border, border[4] or 225))
    nvgStrokeWidth(ctx, active and 2.2 or 1.4)
    nvgStroke(ctx)

    if w > 50 and h > 24 then
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, x + 5, y + 5, w - 10, h - 10, 1.5)
        nvgStrokeColor(ctx, nvgRGBA(68, 69, 55, active and 210 or 145))
        nvgStrokeWidth(ctx, 0.8)
        nvgStroke(ctx)
        drawFrameCorners(ctx, x, y, w, h,
            nvgRGBA(139, 121, 77, active and 245 or 155), 11, 2.5)
    end
    if active then
        nvgBeginPath(ctx)
        nvgRect(ctx, x + 9, y + 3, math.min(82, w * 0.32), 3)
        nvgFillColor(ctx, rgba(ACCENT))
        nvgFill(ctx)
    end
end

local function drawDivider(ctx, x1, y1, x2, y2, alpha)
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, x1, y1)
    nvgLineTo(ctx, x2, y2)
    nvgStrokeColor(ctx, nvgRGBA(154, 121, 56, alpha or 100))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)
end

local function adjustedFontSize(size, isTextBox)
    local factor
    local physicalMinimum
    if size <= 7 then
        factor = isTextBox and 1.18 or 1.30
        physicalMinimum = isTextBox and 7.6 or 8.0
    elseif size <= 8 then
        factor = isTextBox and 1.16 or 1.28
        physicalMinimum = isTextBox and 8.0 or 8.6
    elseif size <= 10 then
        factor = isTextBox and 1.20 or 1.34
        physicalMinimum = isTextBox and 9.2 or 10.0
    elseif size <= 12 then
        factor = 1.24
        physicalMinimum = 11.2
    elseif size <= 16 then
        factor = 1.18
        physicalMinimum = 13.4
    else
        factor = 1.08
        physicalMinimum = 15.0
    end
    local scaledSize = size * factor
    return math.max(scaledSize, physicalMinimum / math.max(BlackMarketUI.layoutScale, 0.001))
end

local function drawText(ctx, text, x, y, size, color, align)
    nvgFontFace(ctx, "sans")
    nvgFontSize(ctx, adjustedFontSize(size, false))
    nvgTextAlign(ctx, align or (NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE))
    nvgFillColor(ctx, rgba(color))
    nvgText(ctx, x, y, tostring(text or ""))
end

local function drawTextBox(ctx, text, x, y, width, size, color)
    nvgFontFace(ctx, "sans")
    nvgFontSize(ctx, adjustedFontSize(size, true))
    nvgTextLineHeight(ctx, 1.28)
    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(ctx, rgba(color))
    nvgTextBox(ctx, x, y, width, tostring(text or ""))
end

local function drawScrollbar(ctx, viewport, offset, maximum)
    if not viewport or maximum <= 0 then return end
    local trackX = viewport.x + viewport.w - 5
    local trackY = viewport.y + 4
    local trackH = viewport.h - 8
    local contentH = viewport.h + maximum
    local thumbH = math.max(38, trackH * viewport.h / math.max(contentH, 1))
    local travel = math.max(0, trackH - thumbH)
    local thumbY = trackY + travel * offset / maximum
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, trackX, trackY, 3, trackH, 1.5)
    nvgFillColor(ctx, nvgRGBA(47, 56, 56, 210))
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, trackX - 1, thumbY, 5, thumbH, 2.5)
    nvgFillColor(ctx, nvgRGBA(218, 164, 65, 230))
    nvgFill(ctx)
end

local function drawLabel(ctx, text, x, y, w, color)
    nvgBeginPath(ctx)
    nvgRect(ctx, x, y - 9, w, 18)
    nvgFillColor(ctx, rgba(color, 38))
    nvgFill(ctx)
    nvgStrokeColor(ctx, rgba(color, 160))
    nvgStrokeWidth(ctx, 0.8)
    nvgStroke(ctx)
    drawText(ctx, text, x + w * 0.5, y, 8, color, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
end

local function drawImageContained(ctx, imageId, x, y, w, h, padding)
    if type(imageId) ~= "number" or imageId <= 0 then return false end
    local imageW, imageH = nvgImageSize(ctx, imageId)
    if not imageW or not imageH or imageW <= 0 or imageH <= 0 then return false end
    local inset = padding or 0
    local scale = math.min(math.max(1, w - inset * 2) / imageW, math.max(1, h - inset * 2) / imageH)
    local drawW, drawH = imageW * scale, imageH * scale
    local drawX, drawY = x + (w - drawW) * 0.5, y + (h - drawH) * 0.5
    nvgBeginPath(ctx)
    nvgRect(ctx, drawX, drawY, drawW, drawH)
    nvgFillPaint(ctx, nvgImagePattern(ctx, drawX, drawY, drawW, drawH, 0, imageId, 1.0))
    nvgFill(ctx)
    return true
end

local function drawImageCovered(ctx, imageId, x, y, w, h, padding)
    if type(imageId) ~= "number" or imageId <= 0 then return false end
    local imageW, imageH = nvgImageSize(ctx, imageId)
    if not imageW or not imageH or imageW <= 0 or imageH <= 0 then return false end
    local inset = padding or 0
    local innerW = math.max(1, w - inset * 2)
    local innerH = math.max(1, h - inset * 2)
    local scale = math.max(innerW / imageW, innerH / imageH)
    local drawW, drawH = imageW * scale, imageH * scale
    local drawX = x + inset + (innerW - drawW) * 0.5
    local drawY = y + inset + (innerH - drawH) * 0.5
    nvgSave(ctx)
    nvgScissor(ctx, x + inset, y + inset, innerW, innerH)
    nvgBeginPath(ctx)
    nvgRect(ctx, drawX, drawY, drawW, drawH)
    nvgFillPaint(ctx, nvgImagePattern(ctx, drawX, drawY, drawW, drawH, 0, imageId, 1.0))
    nvgFill(ctx)
    nvgRestore(ctx)
    return true
end

local function drawPlaceholder(ctx, x, y, w, h, emblem)
    local cx, cy = x + w * 0.5, y + h * 0.5
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x, y, w, h, 4)
    nvgFillColor(ctx, nvgRGBA(24, 30, 32, 255))
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(101, 91, 56, 170))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)
    nvgBeginPath(ctx)
    nvgCircle(ctx, cx, cy, math.min(w, h) * 0.26)
    nvgStrokeColor(ctx, nvgRGBA(190, 151, 64, 150))
    nvgStrokeWidth(ctx, 1.5)
    nvgStroke(ctx)
    nvgBeginPath(ctx)
    if emblem == "intel" then
        nvgMoveTo(ctx, cx - w * 0.16, cy + h * 0.08)
        nvgLineTo(ctx, cx, cy - h * 0.16)
        nvgLineTo(ctx, cx + w * 0.16, cy + h * 0.08)
        nvgLineTo(ctx, cx, cy + h * 0.18)
        nvgClosePath(ctx)
    elseif emblem == "card" then
        nvgRect(ctx, cx - w * 0.17, cy - h * 0.11, w * 0.34, h * 0.22)
    else
        nvgMoveTo(ctx, cx - w * 0.16, cy)
        nvgLineTo(ctx, cx + w * 0.16, cy)
        nvgMoveTo(ctx, cx, cy - h * 0.16)
        nvgLineTo(ctx, cx, cy + h * 0.16)
    end
    nvgStrokeColor(ctx, nvgRGBA(220, 176, 76, 215))
    nvgStrokeWidth(ctx, 2)
    nvgStroke(ctx)
end

local function drawArt(ctx, imageId, x, y, w, h, fallback)
    local drawn
    if fallback == "broker" then
        drawn = drawImageCovered(ctx, imageId, x, y, w, h, 2)
    else
        drawn = drawImageContained(ctx, imageId, x, y, w, h, 4)
    end
    if not drawn then drawPlaceholder(ctx, x, y, w, h, fallback) end
end

local function getItemName(entry)
    return type(entry) == "table" and entry.item or entry
end

local function getCategory(itemName)
    for category, items in pairs(CATEGORY_ITEMS) do if items[itemName] then return category end end
    return "valuables"
end

local function getRate(data, itemName)
    return tonumber((data.marketRates or {})[getCategory(itemName)]) or 1
end

local function getBaseValue(data, itemName)
    local info = (data.itemValues or {})[itemName]
    return info and tonumber(info.value) or 1000
end

local function getQuote(data, itemName)
    return math.floor(getBaseValue(data, itemName) * getRate(data, itemName))
end

local function isUpgradeMaterial(data, itemName)
    for _, tab in ipairs(data.warehouseTabs or {}) do
        for _, requirements in pairs(tab.upgradeMaterials or {}) do
            for _, requirement in ipairs(requirements) do if requirement.item == itemName then return true end end
        end
    end
    return false
end

local function buildSellItems(data)
    local result = {}
    for tabIndex, tab in ipairs(data.warehouseTabs or {}) do
        if tab.unlocked ~= false then
            for itemIndex, entry in ipairs(tab.items or {}) do
                local itemName = getItemName(entry)
                if itemName and itemName:sub(1, 10) ~= "__taken__:" then
                    local category = getCategory(itemName)
                    if BlackMarketUI.selectedCategory == "all" or BlackMarketUI.selectedCategory == category then
                        local size = (data.itemSizes or {})[itemName] or { 1, 1 }
                        local cells = math.max(1, (size[1] or 1) * (size[2] or 1))
                        result[#result + 1] = {
                            key = tostring(tabIndex) .. ":" .. tostring(itemIndex), tabIndex = tabIndex, itemIndex = itemIndex,
                            itemName = itemName, category = category, rarity = (data.itemRarity or {})[itemName] or "green",
                            baseValue = getBaseValue(data, itemName), quote = getQuote(data, itemName), rate = getRate(data, itemName),
                            cells = cells, protected = isUpgradeMaterial(data, itemName),
                        }
                    end
                end
            end
        end
    end
    table.sort(result, function(a, b) return a.quote == b.quote and a.itemName < b.itemName or a.quote > b.quote end)
    return result
end

local function findSellItem(items, key)
    for _, item in ipairs(items) do if item.key == key then return item end end
    return items[1]
end

local function findById(items, id)
    for _, item in ipairs(items or {}) do if item.id == id then return item end end
    return items and items[1] or nil
end

local function drawBackground(ctx, width, height)
    local gradient = nvgLinearGradient(ctx, 0, 0, 0, height,
        nvgRGBA(20, 24, 20, 255), nvgRGBA(5, 8, 7, 255))
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, width, height)
    nvgFillPaint(ctx, gradient)
    nvgFill(ctx)

    -- 与首页一致的程序化沦陷城市剪影，不依赖整张背景图片。
    local horizon = height * 0.125
    local cursor = 0
    local pattern = { 0.042, 0.027, 0.058, 0.034, 0.071, 0.031, 0.049, 0.063, 0.036 }
    local heights = { 0.055, 0.082, 0.046, 0.096, 0.061, 0.104, 0.071, 0.049, 0.087 }
    local index = 1
    while cursor < width do
        local bw = math.max(22, width * pattern[index])
        local bh = math.max(22, height * heights[index])
        nvgBeginPath(ctx)
        nvgRect(ctx, cursor, horizon - bh, bw, bh)
        nvgFillColor(ctx, nvgRGBA(3, 6, 5, 220))
        nvgFill(ctx)
        if bw > 42 then
            nvgBeginPath(ctx)
            nvgRect(ctx, cursor + bw * 0.24, horizon - bh * 0.68, 4, 2)
            nvgRect(ctx, cursor + bw * 0.62, horizon - bh * 0.42, 4, 2)
            nvgFillColor(ctx, nvgRGBA(113, 98, 56, 45))
            nvgFill(ctx)
        end
        cursor = cursor + bw + 3
        index = index % #pattern + 1
    end

    local glow = nvgRadialGradient(ctx, width * 0.48, height * 0.22,
        20, width * 0.62, nvgRGBA(91, 77, 43, 24), nvgRGBA(0, 0, 0, 0))
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, width, height)
    nvgFillPaint(ctx, glow)
    nvgFill(ctx)

    for y = horizon, height, 4 do
        nvgBeginPath(ctx)
        nvgRect(ctx, 0, y, width, 1)
        nvgFillColor(ctx, nvgRGBA(0, 0, 0, 17))
        nvgFill(ctx)
    end
    local pulse = (math.sin(BlackMarketUI.animTime * 1.7) + 1) * 0.5
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, height * 0.17, width, 1)
    nvgFillColor(ctx, nvgRGBA(217, 169, 74, 10 + math.floor(pulse * 13)))
    nvgFill(ctx)
end

local function drawCornerMarks(ctx, x, y, w, h)
    drawFrameCorners(ctx, x, y, w, h, nvgRGBA(151, 130, 82, 225), 16, 3)
end

local function drawSkullMark(ctx, cx, cy, size, color)
    nvgStrokeColor(ctx, rgba(color, 245))
    nvgFillColor(ctx, rgba(color, 245))
    nvgStrokeWidth(ctx, 2)
    nvgBeginPath(ctx)
    nvgCircle(ctx, cx, cy - size * 0.12, size * 0.39)
    nvgStroke(ctx)
    nvgBeginPath(ctx)
    nvgCircle(ctx, cx - size * 0.14, cy - size * 0.14, size * 0.06)
    nvgCircle(ctx, cx + size * 0.14, cy - size * 0.14, size * 0.06)
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, cx - size * 0.19, cy + size * 0.23)
    nvgLineTo(ctx, cx - size * 0.12, cy + size * 0.45)
    nvgMoveTo(ctx, cx, cy + size * 0.26)
    nvgLineTo(ctx, cx, cy + size * 0.47)
    nvgMoveTo(ctx, cx + size * 0.19, cy + size * 0.23)
    nvgLineTo(ctx, cx + size * 0.12, cy + size * 0.45)
    nvgStroke(ctx)
end

local function drawHeader(ctx, data, layoutWidth)
    local fullWidth = layoutWidth - 36
    drawPanel(ctx, 18, 16, fullWidth, 98,
        { 13, 17, 14, 250 }, { 104, 94, 66, 235 }, false)
    drawCornerMarks(ctx, 18, 16, fullWidth, 98)

    drawSkullMark(ctx, 53, 65, 38, ACCENT)
    drawText(ctx, "末日求生", 83, 42, 12, PAPER)
    drawText(ctx, "黑市交易终端", 83, 76, 27, ACCENT)
    drawText(ctx, "07号据点 · 加密频道", 83, 99, 8, MUTED)
    drawDivider(ctx, 345, 31, 345, 99, 130)

    local reputation = math.max(0, tonumber(data.reputation) or tonumber(data.marketReputation) or 0)
    local repLevel = math.floor(reputation / 100) + 2
    local repProgress = reputation % 100
    local repTitles = { [2] = "中间人", [3] = "掮客", [4] = "贸易伙伴" }
    local repTitle = repTitles[repLevel] or "核心代理"
    drawText(ctx, "黑市声望", 372, 38, 8, MUTED)
    drawText(ctx, "等级 " .. string.format("%02d", repLevel) .. "  " .. repTitle,
        372, 67, 12, PAPER)
    nvgBeginPath(ctx); nvgRoundedRect(ctx, 372, 89, 210, 7, 2); nvgFillColor(ctx, nvgRGBA(5, 8, 6, 255)); nvgFill(ctx)
    nvgBeginPath(ctx); nvgRoundedRect(ctx, 372, 89, 210 * repProgress / 100, 7, 2); nvgFillColor(ctx, rgba(ACCENT)); nvgFill(ctx)
    drawText(ctx, tostring(math.floor(repProgress)) .. " / 100", 594, 92, 7, MUTED)

    drawDivider(ctx, 650, 31, 650, 99, 130)
    drawText(ctx, "行情刷新", 678, 65, 10, MUTED)
    drawText(ctx, formatCountdown(data.refreshRemaining), 806, 65, 18, ACCENT)

    local backX = layoutWidth - 214
    local balanceW = 260
    local balanceX = backX - balanceW - 24
    drawPanel(ctx, balanceX, 27, balanceW, 74,
        { 24, 24, 18, 255 }, { 121, 99, 53, 225 }, false)
    local coinX, coinY, coinR = balanceX + 45, 64, 21
    nvgBeginPath(ctx)
    nvgCircle(ctx, coinX, coinY, coinR)
    nvgFillColor(ctx, nvgRGBA(218, 164, 65, 255))
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, coinX - 6, coinY - 13)
    nvgLineTo(ctx, coinX - 6, coinY + 13)
    nvgMoveTo(ctx, coinX - 6, coinY - 12)
    nvgLineTo(ctx, coinX + 3, coinY - 12)
    nvgBezierTo(ctx, coinX + 12, coinY - 12, coinX + 12, coinY - 2, coinX + 3, coinY - 2)
    nvgLineTo(ctx, coinX - 6, coinY - 2)
    nvgMoveTo(ctx, coinX - 6, coinY - 2)
    nvgLineTo(ctx, coinX + 4, coinY - 2)
    nvgBezierTo(ctx, coinX + 13, coinY - 2, coinX + 13, coinY + 12, coinX + 3, coinY + 12)
    nvgLineTo(ctx, coinX - 6, coinY + 12)
    nvgMoveTo(ctx, coinX - 2, coinY - 17)
    nvgLineTo(ctx, coinX - 2, coinY - 12)
    nvgMoveTo(ctx, coinX + 4, coinY - 17)
    nvgLineTo(ctx, coinX + 4, coinY - 12)
    nvgMoveTo(ctx, coinX - 2, coinY + 12)
    nvgLineTo(ctx, coinX - 2, coinY + 17)
    nvgMoveTo(ctx, coinX + 4, coinY + 12)
    nvgLineTo(ctx, coinX + 4, coinY + 17)
    nvgStrokeColor(ctx, nvgRGBA(53, 41, 21, 255))
    nvgStrokeWidth(ctx, 2.8)
    nvgStroke(ctx)
    drawText(ctx, formatNumber(data.bits), balanceX + 84, 64, 24, { 244, 222, 169 })

    BlackMarketUI.backRect = { x = backX, y = 36, w = 164, h = 56 }
    local hot = BlackMarketUI.hovered == "back" or BlackMarketUI.pressed == "back"
    local pressed = BlackMarketUI.pressed == "back"
    drawPanel(ctx, backX, 36, 164, 56,
        hot and { 72, 54, 29, 255 } or { 25, 29, 24, 255 },
        hot and ACCENT or { 91, 84, 63, 225 }, hot)
    drawText(ctx, "‹", backX + 25, 64 + (pressed and 2 or 0), 21,
        hot and ACCENT or MUTED, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    drawText(ctx, "返回据点", backX + 90, 64 + (pressed and 2 or 0), 12,
        hot and PAPER or { 190, 183, 157 }, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
end

local function drawTabs(ctx, layoutWidth)
    BlackMarketUI.tabRects = {}
    local x, y, w, h, gap = 18, 126, layoutWidth - 36, 48, 8
    local tabW = (w - gap * (#TABS - 1)) / #TABS
    for index, tab in ipairs(TABS) do
        local tx = x + (index - 1) * (tabW + gap)
        local rect = { x = tx, y = y, w = tabW, h = h }
        BlackMarketUI.tabRects[tab.id] = rect
        local active = BlackMarketUI.activeTab == tab.id
        local hoverId = "tab:" .. tab.id
        local hot = BlackMarketUI.hovered == hoverId or BlackMarketUI.pressed == hoverId
        local pressed = BlackMarketUI.pressed == hoverId
        local fill
        if active then
            fill = { 74, 56, 29, 255 }
        elseif hot then
            fill = { 46, 45, 32, 255 }
        else
            fill = { 22, 27, 22, 255 }
        end
        drawPanel(ctx, tx, y, tabW, h, fill,
            active and ACCENT or (hot and { 139, 121, 77 } or { 76, 76, 61, 220 }),
            active or hot)
        drawText(ctx, string.format("0%d", index), tx + 22,
            y + h * 0.5 + (pressed and 2 or 0), 7,
            active and ACCENT or MUTED)
        drawText(ctx, tab.label, tx + tabW * 0.5,
            y + h * 0.5 + (pressed and 2 or 0), 15,
            active and PAPER or (hot and { 207, 197, 168 } or { 167, 165, 143 }),
            NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    end
end

local function drawSectionTitle(ctx, title, code, x, y, w)
    local strip = nvgLinearGradient(ctx, x - 7, y - 17, x - 7, y + 18,
        nvgRGBA(48, 51, 41, 218), nvgRGBA(17, 21, 17, 218))
    nvgBeginPath(ctx)
    nvgRect(ctx, x - 7, y - 17, w + 14, 35)
    nvgFillPaint(ctx, strip)
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgRect(ctx, x - 7, y - 17, w + 14, 35)
    nvgStrokeColor(ctx, nvgRGBA(80, 78, 60, 185))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)
    drawText(ctx, title, x + 3, y, 15, PAPER)
    drawText(ctx, code, x + w - 3, y + 1, 7, ACCENT,
        NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    drawDivider(ctx, x, y + 18, x + w, y + 18, 105)
end

local function drawTrend(ctx, x, y, w, h, rates)
    nvgBeginPath(ctx); nvgRect(ctx, x, y, w, h); nvgFillColor(ctx, nvgRGBA(11, 15, 17, 225)); nvgFill(ctx)
    for i = 1, 4 do drawDivider(ctx, x, y + h * i / 5, x + w, y + h * i / 5, 45) end
    for i = 1, 6 do drawDivider(ctx, x + w * i / 7, y, x + w * i / 7, y + h, 35) end
    local series = {
        { key = "electronics", color = { 203, 73, 61 }, phase = 0.2 },
        { key = "valuables", color = { 218, 164, 65 }, phase = 1.1 },
        { key = "equipment", color = { 94, 145, 77 }, phase = 2.2 },
        { key = "medical", color = { 75, 125, 92 }, phase = 3.0 },
    }
    for index, line in ipairs(series) do
        local rate = tonumber((rates or {})[line.key]) or 1
        local rise = (rate - 1) * 38
        nvgBeginPath(ctx)
        for i = 0, 8 do
            local px = x + 8 + (w - 16) * i / 8
            local wave = math.sin(i * 1.38 + line.phase + BlackMarketUI.animTime * 0.22) * 5
            local py = y + h * (0.25 + index * 0.13) - rise * i / 8 - wave
            py = clamp(py, y + 8, y + h - 8)
            if i == 0 then nvgMoveTo(ctx, px, py) else nvgLineTo(ctx, px, py) end
        end
        nvgStrokeColor(ctx, rgba(line.color, 225))
        nvgStrokeWidth(ctx, index == 1 and 2.2 or 1.5)
        nvgStroke(ctx)
    end
end

local function drawQuotePage(ctx, x, y, w, h, data)
    local gap, bottomH = 12, 180
    local upperH = h - bottomH - gap
    local widths = splitWidths(w, gap, { 315, 868, 325 })
    local leftW, centerW, rightW = widths[1], widths[2], widths[3]
    local centerX = x + leftW + gap
    local rightX = centerX + centerW + gap
    local rates = data.marketRates or {}
    local heat = clamp(((tonumber(rates.electronics) or 1) + (tonumber(rates.valuables) or 1) - 1.4) * 45, 0, 100)

    drawPanel(ctx, x, y, leftW, upperH, PANEL, { 79, 87, 86 }, false)
    drawSectionTitle(ctx, "今日市场简报", "06", x + 16, y + 25, leftW - 32)
    local briefLines = {
        "地下电台：东区物流节点重新开放。",
        "高价值电子件遭多名买家争抢。",
        "医疗物资流入持续增加。",
        "普通补给成交热度回落。",
    }
    for index, line in ipairs(briefLines) do
        drawText(ctx, line, x + 18, y + 72 + (index - 1) * 34, 7, { 180, 187, 178 })
    end
    drawPanel(ctx, x + 18, y + 205, leftW - 36, 76, { 31, 36, 36, 255 }, { 76, 91, 85 }, false)
    drawText(ctx, "局势评估", x + 30, y + 228, 8, { 128, 145, 138 })
    drawText(ctx, "电子设备需求 + 机房区域竞争升温", x + 30, y + 260, 8, { 220, 183, 95 })
    drawText(ctx, "黑市热度", x + 18, y + 307, 9, { 144, 154, 150 })
    drawText(ctx, math.floor(heat) .. "%", x + leftW - 18, y + 307, 11, { 231, 178, 66 }, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgBeginPath(ctx); nvgRect(ctx, x + 18, y + 325, leftW - 36, 10); nvgFillColor(ctx, nvgRGBA(41, 46, 45, 255)); nvgFill(ctx)
    nvgBeginPath(ctx); nvgRect(ctx, x + 18, y + 325, (leftW - 36) * heat / 100, 10); nvgFillColor(ctx, nvgRGBA(196, 141, 46, 255)); nvgFill(ctx)
    drawText(ctx, "热度排行 / CATEGORY INDEX", x + 18, y + 357, 8, { 174, 177, 164 })
    local rows = {
        { "电子设备", "electronics" }, { "贵重收藏", "valuables" }, { "医疗物资", "medical" },
        { "工具材料", "materials" }, { "武器装备", "equipment" }, { "生存补给", "supplies" },
    }
    for index, row in ipairs(rows) do
        local ry = y + 389 + (index - 1) * 35
        local rate = tonumber(rates[row[2]]) or 1
        local text, delta = percent(rate)
        local color = delta >= 0 and { 224, 169, 65 } or { 92, 150, 173 }
        drawDivider(ctx, x + 18, ry + 16, x + leftW - 18, ry + 16, 38)
        drawText(ctx, string.format("%02d", index), x + 20, ry, 8, { 99, 110, 110 })
        drawText(ctx, row[1], x + 52, ry, 10, { 193, 199, 193 })
        nvgBeginPath(ctx); nvgRect(ctx, x + 165, ry - 4, 76, 7); nvgFillColor(ctx, nvgRGBA(35, 41, 41, 255)); nvgFill(ctx)
        local barW = clamp(math.abs(delta) * 2.1, 2, 38)
        nvgBeginPath(ctx); nvgRect(ctx, delta >= 0 and x + 203 or x + 203 - barW, ry - 4, barW, 7); nvgFillColor(ctx, rgba(color)); nvgFill(ctx)
        drawText(ctx, text, x + leftW - 18, ry, 11, color, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    end

    drawPanel(ctx, centerX, y, centerW, upperH, PANEL, { 150, 112, 43 }, false)
    drawSectionTitle(ctx, "高价收购 / PREMIUM BUY", "LIMITED QUOTA // +18%", centerX + 18, y + 25, centerW - 36)
    local premium = { "军用加固笔记本", "显卡", "加密硬盘" }
    local cardY, cardH, cardGap = y + 48, upperH - 70, 10
    local cardW = (centerW - 36 - cardGap * 2) / 3
    BlackMarketUI.sellRowRects = {}
    for index, itemName in ipairs(premium) do
        local cx = centerX + 18 + (index - 1) * (cardW + cardGap)
        local selected = BlackMarketUI.hovered == "quote:" .. itemName or BlackMarketUI.pressed == "quote:" .. itemName
        local rarity = RARITY_COLORS[(data.itemRarity or {})[itemName] or "gold"] or RARITY_COLORS.gold
        drawPanel(ctx, cx, cardY, cardW, cardH, selected and { 54, 44, 28, 255 } or { 27, 32, 33, 255 }, selected and ACCENT or { rarity[1], rarity[2], rarity[3], 160 }, selected)
        drawLabel(ctx, RARITY_LABELS[(data.itemRarity or {})[itemName] or "gold"], cx + 14, cardY + 20, 48, rarity)
        drawText(ctx, "ELECTRONICS", cx + cardW - 14, cardY + 20, 7, { 122, 133, 130 }, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        drawArt(ctx, (data.itemIcons or {})[itemName], cx + 17, cardY + 44, cardW - 34, cardH * 0.42, "item")
        drawText(ctx, itemName, cx + cardW * 0.5, cardY + cardH * 0.53, 13, { 237, 228, 208 }, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        local quote = getQuote(data, itemName)
        drawText(ctx, formatNumber(quote) .. " 比特", cx + cardW * 0.5, cardY + cardH * 0.64, 16, { 233, 177, 65 }, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        drawText(ctx, "收购限额  02 / 05", cx + cardW * 0.5, cardY + cardH * 0.71, 8, { 142, 151, 147 }, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        drawDivider(ctx, cx + 14, cardY + cardH * 0.76, cx + cardW - 14, cardY + cardH * 0.76, 70)
        drawText(ctx, "市均 " .. formatNumber(getBaseValue(data, itemName)), cx + 15, cardY + cardH * 0.81, 8, { 132, 141, 139 })
        drawText(ctx, "稀缺电子零件，买方即时结算", cx + 15, cardY + cardH * 0.88, 8, { 159, 158, 145 })
        drawText(ctx, "前往出售  →", cx + cardW * 0.5, cardY + cardH - 19, 10, { 233, 191, 91 }, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        BlackMarketUI.sellRowRects["quote:" .. itemName] = { x = cx, y = cardY, w = cardW, h = cardH }
    end

    local holdingH = 300
    drawPanel(ctx, rightX, y, rightW, holdingH, PANEL, { 78, 87, 86 }, false)
    drawSectionTitle(ctx, "持有物资估值", "TOP 03", rightX + 16, y + 25, rightW - 32)
    local items = buildSellItems(data)
    for index = 1, math.min(3, #items) do
        local item, ry = items[index], y + 76 + (index - 1) * 62
        local rarity = RARITY_COLORS[item.rarity] or RARITY_COLORS.green
        nvgBeginPath(ctx); nvgRect(ctx, rightX + 17, ry - 18, 4, 40); nvgFillColor(ctx, rgba(rarity)); nvgFill(ctx)
        drawText(ctx, item.itemName, rightX + 31, ry - 10, 9, { 203, 208, 202 })
        drawText(ctx, formatNumber(item.quote), rightX + rightW - 17, ry - 10, 9, { 228, 172, 66 }, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        drawText(ctx, CATEGORY_LABELS[item.category] .. "  /  " .. tostring(item.cells) .. " 格", rightX + 31, ry + 18, 7, { 120, 130, 129 })
        drawText(ctx, "数量 ×1", rightX + rightW - 17, ry + 18, 7, { 130, 141, 136 }, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    end
    drawPanel(ctx, rightX + 17, y + holdingH - 58, rightW - 34, 40, { 29, 35, 35, 255 }, { 82, 97, 92 }, false)
    drawText(ctx, "查看全部仓库", rightX + rightW * 0.5, y + holdingH - 38, 10, { 211, 175, 92 }, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    local trendY, trendH = y + holdingH + gap, upperH - holdingH - gap
    drawPanel(ctx, rightX, trendY, rightW, trendH, PANEL, { 78, 87, 86 }, false)
    drawSectionTitle(ctx, "市场趋势", "24H", rightX + 16, trendY + 24, rightW - 32)
    drawText(ctx, "指数", rightX + 18, trendY + 64, 8, { 124, 138, 134 })
    drawText(ctx, "1.00", rightX + 18, trendY + 170, 7, { 103, 119, 116 })
    drawText(ctx, "1.15", rightX + 18, trendY + 110, 7, { 103, 119, 116 })
    local trendGraphX = rightX + 82
    local trendGraphW = rightW - 118
    drawTrend(ctx, trendGraphX, trendY + 104, trendGraphW, 64, rates)
    drawText(ctx, "00:00", trendGraphX, trendY + 187, 7, { 104, 113, 112 })
    drawText(ctx, "12:00", trendGraphX + trendGraphW * 0.5, trendY + 187, 7, { 104, 113, 112 }, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    drawText(ctx, "NOW", trendGraphX + trendGraphW, trendY + 187, 7, { 104, 113, 112 }, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    local trendText = (tonumber(rates.electronics) or 1) >= 1 and "需求持续抬升，建议尽快锁定成交价。" or "需求趋缓，建议保留高价值电子件。"
    drawText(ctx, trendText, rightX + 18, trendY + trendH - 68, 8, { 164, 172, 165 })
    drawLabel(ctx, "电子设备", rightX + 18, trendY + trendH - 28, 72, { 224, 169, 65 })
    drawLabel(ctx, "基准指数", rightX + 132, trendY + trendH - 28, 72, { 92, 150, 173 })

    local by = y + upperH + gap
    local bottomWidths = splitWidths(w, gap, { 430, 555, 523 })
    local rumorW, adviceW, ctaW = bottomWidths[1], bottomWidths[2], bottomWidths[3]
    local ctaX = x + rumorW + adviceW + gap * 2
    drawPanel(ctx, x, by, rumorW, bottomH, { 18, 23, 25, 252 }, { 112, 85, 40 }, false)
    drawSectionTitle(ctx, "市场传闻", "RUMOR WIRE", x + 16, by + 22, rumorW - 32)
    local rumors = {
        "08:14  东区机房仍有未清理的服务器机柜。",
        "07:46  管理室钥匙卡买方报价上浮。",
        "07:12  医疗站补给已被多支小队搜刮。",
        "06:38  红区巡逻密度增加，慎带重装。",
    }
    local rumorStartY = by + 63
    local rumorStep = math.max(34, (bottomH - 88) / math.max(#rumors - 1, 1))
    for i, rumor in ipairs(rumors) do
        drawText(ctx, rumor, x + 18, rumorStartY + (i - 1) * rumorStep, 9, i == 1 and { 220, 181, 91 } or { 164, 174, 168 })
    end

    local adviceX = x + rumorW + gap
    drawPanel(ctx, adviceX, by, adviceW, bottomH, { 18, 23, 25, 252 }, { 112, 85, 40 }, false)
    drawSectionTitle(ctx, "下一局搜刮建议", "TACTICAL PLAN", adviceX + 16, by + 22, adviceW - 32)
    local advice = {
        { "优先搜刮", "电子机房、办公桌与通信设备" },
        { "重点目标", "加密硬盘 / 显卡 / 军用笔记本" },
        { "风险提示", "红区巡逻升温，避免长时间驻留" },
        { "装备建议", "轻型护甲 + 扩容背包 + 消音武器" },
    }
    local adviceStartY = by + 63
    local adviceStep = math.max(36, (bottomH - 88) / math.max(#advice - 1, 1))
    local adviceLabelRight = adviceX + 112
    local adviceValueX = adviceX + 132
    for i, row in ipairs(advice) do
        local ay = adviceStartY + (i - 1) * adviceStep
        drawText(ctx, row[1], adviceLabelRight, ay, 8, { 220, 173, 70 }, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        drawText(ctx, row[2], adviceValueX, ay, 8, { 184, 191, 184 })
    end

    BlackMarketUI.primaryRect = { x = ctaX, y = by, w = ctaW, h = bottomH }
    local hot = BlackMarketUI.hovered == "primary" or BlackMarketUI.pressed == "primary"
    drawPanel(ctx, ctaX, by, ctaW, bottomH,
        hot and { 190, 72, 47, 255 } or { 145, 49, 37, 255 },
        hot and { 224, 117, 82 } or { 126, 55, 42 }, hot)
    local ctaCenterY = by + bottomH * 0.54
    drawText(ctx, "前往出售", ctaX + ctaW * 0.5, ctaCenterY - 34, 19, { 249, 231, 193 }, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    drawText(ctx, "锁定当前行情  /  快速结算", ctaX + ctaW * 0.5, ctaCenterY + 8, 9, { 225, 184, 98 }, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    drawText(ctx, "OPEN LIQUIDATION TERMINAL  →", ctaX + ctaW * 0.5, ctaCenterY + 43, 8, { 202, 168, 97 }, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
end

local function drawCategories(ctx, x, y, w, h)
    drawPanel(ctx, x, y, w, h, PANEL, { 73, 83, 82 }, false)
    drawSectionTitle(ctx, "仓库筛选", "FILTER", x + 14, y + 24, w - 28)
    BlackMarketUI.categoryRects = {}
    for index, category in ipairs(CATEGORIES) do
        local ry = y + 72 + (index - 1) * 56
        local rect = { x = x + 12, y = ry, w = w - 24, h = 46 }
        BlackMarketUI.categoryRects[category.id] = rect
        local active = BlackMarketUI.selectedCategory == category.id
        local hot = BlackMarketUI.hovered == "category:" .. category.id
        drawPanel(ctx, rect.x, rect.y, rect.w, rect.h, active and { 66, 50, 29, 255 } or (hot and { 35, 40, 40, 255 } or { 25, 30, 31, 255 }), active and ACCENT or { 61, 71, 70 }, active)
        drawText(ctx, category.code, rect.x + 58, rect.y + rect.h * 0.5, 8, active and { 238, 185, 78 } or { 111, 125, 123 }, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        drawText(ctx, category.label, rect.x + 82, rect.y + rect.h * 0.5, 10, active and { 237, 222, 191 } or { 172, 181, 176 })
    end
    local sy = y + h - 156
    drawText(ctx, "出售安全开关", x + 15, sy, 10, { 222, 214, 194 })
    local toggles = { "隐藏已锁定物品", "标识升级材料", "显示委托需求" }
    for i, label in ipairs(toggles) do
        local ty = sy + 27 + (i - 1) * 28
        nvgBeginPath(ctx); nvgRoundedRect(ctx, x + 16, ty - 8, 27, 15, 7); nvgFillColor(ctx, nvgRGBA(119, 82, 28, 255)); nvgFill(ctx)
        nvgBeginPath(ctx); nvgCircle(ctx, x + 34, ty - 0.5, 5); nvgFillColor(ctx, nvgRGBA(239, 190, 84, 255)); nvgFill(ctx)
        drawText(ctx, label, x + 51, ty, 8, { 143, 151, 146 })
    end
    drawPanel(ctx, x + 12, y + h - 48, w - 24, 31, { 54, 33, 28, 255 }, { 164, 83, 58 }, false)
    drawText(ctx, "!  受保护物资出售前将再次提示", x + 20, y + h - 32, 8, { 222, 138, 105 })
end

local function drawSellPage(ctx, x, y, w, h, data)
    local gap, footerH = 12, 150
    local widths = splitWidths(w, gap, { 250, 790, 468 })
    local leftW, tableW, detailW = widths[1], widths[2], widths[3]
    local detailX = x + leftW + tableW + gap * 2
    local bodyH = h - footerH - 12
    drawCategories(ctx, x, y, leftW, bodyH)

    local tableX = x + leftW + gap
    drawPanel(ctx, tableX, y, tableW, bodyH, PANEL, { 79, 87, 86 }, false)
    drawSectionTitle(ctx, "可出售物资", "WAREHOUSE / QUICK SALE", tableX + 16, y + 24, tableW - 32)
    local cols = {
        tableW * 0.023,
        tableW * 0.309,
        tableW * 0.439,
        tableW * 0.539,
        tableW * 0.673,
        tableW * 0.818,
        tableW - 48,
    }
    local titles = { "物品", "品质", "数量", "基础价", "今日价", "涨幅", "单格价值" }
    nvgBeginPath(ctx); nvgRect(ctx, tableX + 12, y + 42, tableW - 24, 31); nvgFillColor(ctx, nvgRGBA(37, 42, 42, 255)); nvgFill(ctx)
    for i, title in ipairs(titles) do
        local align = i == #titles and (NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE) or nil
        drawText(ctx, title, tableX + cols[i], y + 58, 8, { 151, 160, 155 }, align)
    end
    local items = buildSellItems(data)
    BlackMarketUI.sellRowRects = {}
    local viewport = { x = tableX + 12, y = y + 76, w = tableW - 24, h = bodyH - 90 }
    BlackMarketUI.listViewport = viewport
    local rowH = 126
    BlackMarketUI.scrollMax = math.max(0, #items * rowH - viewport.h)
    BlackMarketUI.scrollOffset = clamp(BlackMarketUI.scrollOffset, 0, BlackMarketUI.scrollMax)
    nvgSave(ctx); nvgScissor(ctx, viewport.x, viewport.y, viewport.w, viewport.h)
    for index, item in ipairs(items) do
        local ry = viewport.y + (index - 1) * rowH - BlackMarketUI.scrollOffset
        local rect = { x = viewport.x, y = ry, w = viewport.w, h = rowH - 2 }
        BlackMarketUI.sellRowRects[item.key] = rect
        if ry + rowH >= viewport.y and ry <= viewport.y + viewport.h then
            local selected = BlackMarketUI.selectedSellKey == item.key
            local checked = BlackMarketUI.sellSelection[item.key] == true
            local hot = BlackMarketUI.hovered == "sell-row:" .. item.key
            local rarity = RARITY_COLORS[item.rarity] or RARITY_COLORS.green
            nvgBeginPath(ctx); nvgRect(ctx, rect.x, rect.y, rect.w, rect.h); nvgFillColor(ctx, selected and nvgRGBA(68, 51, 27, 255) or (hot and nvgRGBA(33, 39, 39, 255) or nvgRGBA(23, 28, 30, 255))); nvgFill(ctx)
            nvgBeginPath(ctx); nvgRect(ctx, rect.x, rect.y, 3, rect.h); nvgFillColor(ctx, rgba(selected and ACCENT or rarity)); nvgFill(ctx)
            drawArt(ctx, (data.itemIcons or {})[item.itemName], tableX + 22, ry + 13, 92, 96, "item")
            drawText(ctx, item.itemName, tableX + 128, ry + 42, 10, { 223, 225, 215 })
            drawText(ctx, CATEGORY_LABELS[item.category], tableX + 128, ry + 86, 7, { 113, 125, 122 })
            drawText(ctx, RARITY_LABELS[item.rarity], tableX + cols[2], ry + 63, 9, rarity)
            drawText(ctx, "×1", tableX + cols[3], ry + 63, 10, { 191, 198, 190 })
            drawText(ctx, formatNumber(item.baseValue), tableX + cols[4], ry + 63, 10, { 165, 174, 169 })
            drawText(ctx, formatNumber(item.quote), tableX + cols[5], ry + 63, 11, { 228, 171, 65 })
            local rateText, delta = percent(item.rate)
            drawText(ctx, rateText, tableX + cols[6], ry + 63, 10, delta >= 0 and { 224, 169, 65 } or { 92, 150, 173 })
            drawText(ctx, formatNumber(math.floor(item.quote / item.cells)), tableX + cols[7], ry + 63, 9, { 169, 179, 172 }, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
            nvgBeginPath(ctx); nvgRoundedRect(ctx, tableX + tableW - 36, ry + 54, 18, 18, 2); nvgFillColor(ctx, checked and nvgRGBA(153, 105, 34, 255) or nvgRGBA(16, 21, 23, 255)); nvgFill(ctx); nvgStrokeColor(ctx, checked and nvgRGBA(231, 179, 76, 255) or nvgRGBA(78, 89, 88, 255)); nvgStroke(ctx)
            if checked then drawText(ctx, "✓", tableX + tableW - 27, ry + 63, 11, { 248, 229, 192 }, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE) end
        end
    end
    nvgRestore(ctx)
    drawScrollbar(ctx, viewport, BlackMarketUI.scrollOffset, BlackMarketUI.scrollMax)

    drawPanel(ctx, detailX, y, detailW, bodyH, PANEL, { 133, 98, 41 }, false)
    drawSectionTitle(ctx, "物资鉴定", "ITEM ANALYSIS", detailX + 16, y + 24, detailW - 32)
    local selectedItem = findSellItem(items, BlackMarketUI.selectedSellKey)
    BlackMarketUI.primaryRect = nil
    if selectedItem then
        BlackMarketUI.selectedSellKey = selectedItem.key
        local rarity = RARITY_COLORS[selectedItem.rarity] or RARITY_COLORS.green
        local itemSize = (data.itemSizes or {})[selectedItem.itemName] or { 1, 1 }
        local sizeW = tonumber(itemSize[1]) or 1
        local sizeH = tonumber(itemSize[2]) or 1
        local ownedCount, taskDemand, taskRequired = 0, 0, false
        for _, item in ipairs(items) do
            if item.itemName == selectedItem.itemName then ownedCount = ownedCount + 1 end
        end
        for _, order in ipairs(data.orders or {}) do
            for _, requirement in ipairs(order.requirements or {}) do
                if requirement.item == selectedItem.itemName then
                    taskDemand = taskDemand + (tonumber(requirement.count) or 0)
                    taskRequired = true
                end
            end
        end
        local perCellValue = math.floor(selectedItem.quote / math.max(1, selectedItem.cells))
        drawArt(ctx, (data.itemIcons or {})[selectedItem.itemName], detailX + 42, y + 49, detailW - 84, 162, "item")
        drawLabel(ctx, RARITY_LABELS[selectedItem.rarity], detailX + 18, y + 224, 52, rarity)
        drawText(ctx, selectedItem.itemName, detailX + 18, y + 258, 17, { 239, 228, 205 })
        drawText(ctx, CATEGORY_LABELS[selectedItem.category], detailX + 18, y + 292, 8, { 143, 153, 149 })
        drawDivider(ctx, detailX + 18, y + 310, detailX + detailW - 18, y + 310, 100)
        local infoRows = {
            { label = "持有数量", value = "×" .. tostring(ownedCount), color = { 206, 214, 204 }, size = 11 },
            { label = "实际尺寸", value = tostring(sizeW) .. " × " .. tostring(sizeH) .. " 格", color = { 206, 214, 204 }, size = 11 },
            { label = "单格报价", value = formatNumber(perCellValue) .. " 比特", color = { 224, 169, 65 }, size = 11 },
            { label = "基础估值", value = formatNumber(selectedItem.baseValue), color = { 190, 196, 185 }, size = 11 },
            { label = "今日成交价", value = formatNumber(selectedItem.quote) .. " 比特", color = { 229, 174, 65 }, size = 14 },
        }
        for index, row in ipairs(infoRows) do
            local iy = y + 322 + (index - 1) * 36
            drawText(ctx, row.label, detailX + 18, iy, 9, { 132, 145, 141 })
            drawText(ctx, row.value, detailX + detailW - 18, iy, row.size, row.color, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        end
        local statusY = y + 504
        local taskFill = taskRequired and { 68, 48, 27, 255 } or { 28, 42, 37, 255 }
        local taskBorder = taskRequired and { 193, 145, 52 } or { 74, 132, 99 }
        local taskColor = taskRequired and { 232, 184, 75 } or { 113, 180, 132 }
        drawPanel(ctx, detailX + 18, statusY, detailW - 36, 36, taskFill, taskBorder, false)
        drawText(ctx, taskRequired and "委托需求  /  TASK REQUIRED" or "委托需求  /  NO ACTIVE DEMAND", detailX + 29, statusY + 18, 8, taskColor)
        drawText(ctx, taskRequired and ("需求 ×" .. tostring(taskDemand)) or "未被订单占用", detailX + detailW - 29, statusY + 18, 9, taskColor, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        statusY = statusY + 43
        local upgradeFill = selectedItem.protected and { 54, 33, 28, 255 } or { 28, 42, 37, 255 }
        local upgradeBorder = selectedItem.protected and { 166, 82, 58 } or { 74, 132, 99 }
        local upgradeColor = selectedItem.protected and { 225, 137, 102 } or { 113, 180, 132 }
        drawPanel(ctx, detailX + 18, statusY, detailW - 36, 36, upgradeFill, upgradeBorder, false)
        drawText(ctx, selectedItem.protected and "仓库升级  /  PROTECTED MATERIAL" or "仓库升级  /  CLEAR FOR SALE", detailX + 29, statusY + 18, 8, upgradeColor)
        drawText(ctx, selectedItem.protected and "建议保留" or "可安全出售", detailX + detailW - 29, statusY + 18, 9, upgradeColor, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        local buttonH = 72
        BlackMarketUI.primaryRect = {
            x = detailX + 18,
            y = y + bodyH - buttonH - 19,
            w = detailW - 36,
            h = buttonH,
        }
        local checked = BlackMarketUI.sellSelection[selectedItem.key] == true
        local hot = BlackMarketUI.hovered == "primary" or BlackMarketUI.pressed == "primary"
        drawPanel(ctx, BlackMarketUI.primaryRect.x, BlackMarketUI.primaryRect.y, BlackMarketUI.primaryRect.w, BlackMarketUI.primaryRect.h, hot and { 153, 105, 33, 255 } or { 105, 72, 28, 255 }, ACCENT, hot)
        drawText(ctx, checked and "从出售清单移除" or "加入出售清单", detailX + detailW * 0.5, BlackMarketUI.primaryRect.y + buttonH * 0.5, 14, { 247, 230, 199 }, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    else
        drawText(ctx, "选择一件仓库物资进行鉴定", detailX + detailW * 0.5, y + bodyH * 0.5, 11, { 120, 132, 130 }, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    end

    local baseTotal, quoteTotal, count = 0, 0, 0
    local byKey = {}; for _, item in ipairs(items) do byKey[item.key] = item end
    for key in pairs(BlackMarketUI.sellSelection) do
        local item = byKey[key]
        if item then count = count + 1; baseTotal = baseTotal + item.baseValue; quoteTotal = quoteTotal + item.quote end
    end
    local bonus = quoteTotal - baseTotal
    local fee = math.floor(quoteTotal * 0.05)
    local final = math.max(0, quoteTotal - fee)
    local fy = y + bodyH + 12
    drawPanel(ctx, x, fy, w, footerH, { 15, 20, 22, 255 }, { 156, 115, 43 }, false)
    drawText(ctx, "本次结算清单", x + 18, fy + 34, 9, { 221, 213, 194 })
    drawText(ctx, tostring(count) .. " 件物资", x + 18, fy + 100, 15, { 231, 175, 65 })

    local buttonW = 250
    local buttonX = x + w - buttonW - 18
    local finalW = 260
    local finalX = buttonX - finalW - 24
    local statX = x + 230
    local statStep = (finalX - statX - 24) / 3
    local stats = { { "基础总价", baseTotal, { 183, 191, 181 } }, { "市场溢价", bonus, { 224, 169, 65 } }, { "交易手续费 5%", fee, { 207, 117, 86 } } }
    for i, stat in ipairs(stats) do
        local sx = statX + (i - 1) * statStep
        drawText(ctx, stat[1], sx, fy + 34, 8, { 128, 140, 137 })
        drawText(ctx, (i == 2 and "+" or "") .. formatNumber(stat[2]), sx, fy + 100, 14, stat[3])
    end
    drawDivider(ctx, finalX - 18, fy + 20, finalX - 18, fy + footerH - 20, 100)
    drawText(ctx, "最终收入", finalX, fy + 34, 9, { 162, 167, 155 })
    drawText(ctx, formatNumber(final) .. " 比特", finalX, fy + 100, 18, { 241, 184, 70 })
    BlackMarketUI.secondaryRect = { x = buttonX, y = fy + 22, w = buttonW, h = footerH - 44 }
    local sellHot = BlackMarketUI.hovered == "secondary"
        or BlackMarketUI.pressed == "secondary"
    local sellEnabled = count > 0
    local sellFill = { 43, 48, 40, 255 }
    local sellBorder = { 73, 81, 66 }
    if sellEnabled then
        sellFill = sellHot and { 190, 72, 47, 255 } or { 145, 49, 37, 255 }
        sellBorder = sellHot and { 224, 117, 82 } or { 126, 55, 42 }
    end
    drawPanel(ctx, BlackMarketUI.secondaryRect.x, BlackMarketUI.secondaryRect.y,
        BlackMarketUI.secondaryRect.w, BlackMarketUI.secondaryRect.h,
        sellFill, sellBorder, sellEnabled and sellHot)
    drawText(ctx, "确认出售", buttonX + buttonW * 0.5, fy + footerH * 0.5, 15, count > 0 and { 248, 231, 197 } or { 119, 130, 128 }, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
end

local function drawOrderEmblem(ctx, x, y, size, active)
    nvgBeginPath(ctx); nvgCircle(ctx, x, y, size); nvgFillColor(ctx, active and nvgRGBA(95, 69, 29, 255) or nvgRGBA(28, 35, 36, 255)); nvgFill(ctx); nvgStrokeColor(ctx, active and nvgRGBA(228, 177, 70, 255) or nvgRGBA(95, 108, 105, 220)); nvgStroke(ctx)
    nvgBeginPath(ctx); nvgMoveTo(ctx, x, y - size * 0.56); nvgLineTo(ctx, x + size * 0.45, y); nvgLineTo(ctx, x, y + size * 0.56); nvgLineTo(ctx, x - size * 0.45, y); nvgClosePath(ctx); nvgStrokeColor(ctx, nvgRGBA(223, 171, 66, 210)); nvgStrokeWidth(ctx, 1.4); nvgStroke(ctx)
end

local function compactName(value, fallback)
    local text = tostring(value or fallback or "")
    local primary = text:match("^%s*(.-)%s*/")
    return primary and primary ~= "" and primary or text
end

local function drawOrdersPage(ctx, x, y, w, h, data)
    local gap, footerH = 12, 86
    local widths = splitWidths(w, gap, { 375, 640, 493 })
    local leftW, middleW, rightW = widths[1], widths[2], widths[3]
    local rightX = x + leftW + middleW + gap * 2
    local bodyH = h - footerH - 12
    local orders = data.orders or {}

    drawPanel(ctx, x, y, leftW, bodyH, PANEL, { 74, 84, 83 }, false)
    drawSectionTitle(ctx, "匿名买家列表", "", x + 16, y + 24, leftW - 32)
    BlackMarketUI.orderRowRects = {}
    local orderViewport = { x = x + 10, y = y + 72, w = leftW - 20, h = bodyH - 84 }
    BlackMarketUI.orderViewport = orderViewport
    local orderRowH = 164
    BlackMarketUI.orderScrollMax = math.max(0, #orders * orderRowH - orderViewport.h)
    BlackMarketUI.orderScrollOffset = clamp(BlackMarketUI.orderScrollOffset, 0, BlackMarketUI.orderScrollMax)
    nvgSave(ctx)
    nvgScissor(ctx, orderViewport.x, orderViewport.y, orderViewport.w, orderViewport.h)
    for index, order in ipairs(orders) do
        local ry = orderViewport.y + (index - 1) * orderRowH - BlackMarketUI.orderScrollOffset
        local rect = { x = x + 12, y = ry, w = leftW - 24, h = 148 }
        BlackMarketUI.orderRowRects[order.id] = rect
        if ry + rect.h >= orderViewport.y and ry <= orderViewport.y + orderViewport.h then
            local selected = BlackMarketUI.selectedOrderId == order.id
            local hot = BlackMarketUI.hovered == "order-row:" .. order.id
            drawPanel(ctx, rect.x, rect.y, rect.w, rect.h, selected and { 63, 49, 28, 255 } or (hot and { 34, 40, 40, 255 } or { 24, 29, 31, 255 }), selected and ACCENT or { 59, 71, 70 }, selected)
            drawOrderEmblem(ctx, rect.x + 42, rect.y + 74, 25, selected)
            drawText(ctx, compactName(order.buyer, "匿名买家"), rect.x + 82, rect.y + 28, 8, { 150, 159, 155 })
            drawText(ctx, order.title or "特殊物资委托", rect.x + 82, rect.y + 74, 12, { 228, 222, 207 })
            local requirement = (order.requirements or {})[1]
            drawText(ctx, requirement and (requirement.item .. " ×" .. tostring(requirement.count)) or "机密交付", rect.x + 82, rect.y + 124, 8, { 142, 151, 146 })
            drawText(ctx, formatNumber(order.reward), rect.x + rect.w - 18, rect.y + 28, 10, { 226, 171, 65 }, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
            local state = order.completed and "已完成" or (order.accepted and "进行中" or "待接取")
            drawText(ctx, state, rect.x + rect.w - 18, rect.y + 124, 8, order.completed and { 94, 159, 111 } or (order.accepted and { 223, 171, 65 } or { 122, 135, 132 }), NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        end
    end
    nvgRestore(ctx)
    drawScrollbar(ctx, orderViewport, BlackMarketUI.orderScrollOffset, BlackMarketUI.orderScrollMax)

    local middleX = x + leftW + gap
    drawPanel(ctx, middleX, y, middleW, bodyH, PANEL, { 144, 106, 42 }, false)
    local selected = findById(orders, BlackMarketUI.selectedOrderId)
    BlackMarketUI.primaryRect = nil
    if selected then
        BlackMarketUI.selectedOrderId = selected.id
        drawSectionTitle(ctx, selected.title or "收购订单", "", middleX + 18, y + 25, middleW - 36)
        drawText(ctx, "委托人：" .. compactName(selected.buyer, "匿名买家"), middleX + 18, y + 76, 8, { 157, 166, 161 })
        drawTextBox(ctx, selected.description or "按照买方要求交付指定物资。", middleX + 18, y + 118, middleW - 36, 8, { 192, 195, 185 })
        drawText(ctx, "交付物资", middleX + 18, y + 196, 10, { 222, 214, 194 })
        local reqs = selected.requirements or {}
        local slotW, slotGap, slotY = (middleW - 36 - 24) / 4, 8, y + 224
        for index = 1, 4 do
            local requirement = reqs[index]
            local rx = middleX + 18 + (index - 1) * (slotW + slotGap)
            local occupied = requirement ~= nil
            drawPanel(ctx, rx, slotY, slotW, 148, occupied and { 26, 31, 32, 255 } or { 19, 25, 27, 255 }, occupied and { 92, 98, 86 } or { 66, 77, 76 }, false)
            if occupied then
                drawArt(ctx, (data.itemIcons or {})[requirement.item], rx + 15, slotY + 14, slotW - 30, 78, "item")
                drawText(ctx, requirement.item .. " ×" .. tostring(requirement.count), rx + slotW * 0.5, slotY + 124, 8, { 224, 169, 65 }, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            else
                drawText(ctx, "+", rx + slotW * 0.5, slotY + 58, 24, { 126, 140, 135 }, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                drawText(ctx, "备用槽", rx + slotW * 0.5, slotY + 124, 7, { 104, 119, 115 }, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            end
        end
        drawPanel(ctx, middleX + 18, y + 402, middleW - 36, 70, { 24, 31, 31, 255 }, { 68, 85, 80 }, false)
        local sourceColX = middleX + 31
        local qualityColX = middleX + middleW * 0.56
        drawText(ctx, "物资来源", sourceColX, y + 422, 7, { 128, 144, 138 })
        drawText(ctx, "已验证仓库库存", sourceColX, y + 456, 8, { 195, 203, 193 })
        drawText(ctx, "品质要求", qualityColX, y + 422, 7, { 128, 144, 138 })
        drawText(ctx, "完整度 ≥ 80%", qualityColX, y + 456, 8, { 224, 171, 65 })

        local rewardY, rewardW = y + 506, (middleW - 48) * 0.5
        drawPanel(ctx, middleX + 18, rewardY, rewardW, 100, { 52, 40, 24, 255 }, { 172, 130, 48 }, false)
        drawText(ctx, "比特结算", middleX + 34, rewardY + 28, 8, { 185, 160, 104 })
        drawText(ctx, formatNumber(selected.reward), middleX + 34, rewardY + 72, 19, { 240, 185, 70 })
        local repX = middleX + 30 + rewardW
        drawPanel(ctx, repX, rewardY, rewardW, 100, { 27, 43, 37, 255 }, { 74, 132, 99 }, false)
        drawText(ctx, "黑市声望", repX + 16, rewardY + 28, 8, { 126, 164, 139 })
        drawText(ctx, "+" .. tostring(selected.reputation or 0), repX + 16, rewardY + 72, 19, { 110, 184, 133 })
        drawText(ctx, "提交后不可撤回", middleX + 18, y + 646, 8, { 157, 153, 137 })
    else
        drawText(ctx, "暂无激活的收购订单", middleX + middleW * 0.5, y + bodyH * 0.5, 12, { 124, 136, 133 }, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    end

    drawPanel(ctx, rightX, y, rightW, bodyH, PANEL, { 74, 84, 83 }, false)
    drawSectionTitle(ctx, "买方档案", "", rightX + 16, y + 24, rightW - 32)
    local portraitDrawn = drawImageContained(ctx, (data.art or {}).broker, rightX + 26, y + 52, rightW - 52, 230, 4)
    if not portraitDrawn then
        drawPlaceholder(ctx, rightX + 26, y + 52, rightW - 52, 230, "broker")
    end
    drawText(ctx, selected and compactName(selected.buyer, "渡鸦") or "渡鸦", rightX + 18, y + 312, 16, { 235, 226, 204 })
    drawText(ctx, "地下交易中间人", rightX + 18, y + 350, 9, { 211, 161, 61 })
    drawDivider(ctx, rightX + 18, y + 372, rightX + rightW - 18, y + 372, 100)
    drawText(ctx, "交易规则", rightX + 18, y + 400, 9, { 218, 213, 196 })
    local rules = {
        "01  仅接收交付槽内指定的物资", "02  货物须来自受信任仓库库存", "03  完整度低于 80% 将拒绝结算",
        "04  接受后可从仓库直接提交交付", "05  放弃委托将损失信誉与联络机会",
    }
    for i, rule in ipairs(rules) do drawText(ctx, rule, rightX + 20, y + 434 + (i - 1) * 30, 8, { 151, 161, 157 }) end
    if selected then
        local enabled = not selected.completed
        BlackMarketUI.primaryRect = { x = rightX + 18, y = y + 588, w = rightW - 36, h = 48 }
        local hot = BlackMarketUI.hovered == "primary" or BlackMarketUI.pressed == "primary"
        drawPanel(ctx, BlackMarketUI.primaryRect.x, BlackMarketUI.primaryRect.y, BlackMarketUI.primaryRect.w, BlackMarketUI.primaryRect.h, enabled and (hot and { 151, 104, 33, 255 } or { 105, 73, 29, 255 }) or { 42, 48, 48, 255 }, enabled and ACCENT or { 75, 83, 82 }, hot and enabled)
        drawText(ctx, selected.completed and "订单已完成" or (selected.accepted and "提交仓库物资" or "接受收购委托"), rightX + rightW * 0.5, y + 612, 10, enabled and { 249, 231, 196 } or { 120, 132, 130 }, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    end
    drawPanel(ctx, rightX + 18, y + 652, rightW - 36, 66, { 54, 33, 28, 255 }, { 162, 82, 58 }, false)
    drawText(ctx, "放弃警告", rightX + 31, y + 672, 9, { 225, 139, 102 })
    drawText(ctx, "中止订单将扣除黑市声望", rightX + 31, y + 699, 8, { 167, 140, 130 })

    local fy, sectionW = y + bodyH + 12, (w - 48) / 3
    drawPanel(ctx, x, fy, w, footerH, { 16, 21, 23, 255 }, { 120, 92, 42 }, false)
    local footer = {
        { "订单追踪", tostring(#orders) .. " 条可用委托", { 225, 171, 65 } },
        { "交付校验", "来源与品质双重审查", { 106, 164, 130 } },
        { "联络状态", "加密线路稳定", { 146, 157, 151 } },
    }
    for i, section in ipairs(footer) do
        local sx = x + 16 + (i - 1) * (sectionW + 8)
        if i > 1 then drawDivider(ctx, sx - 8, fy + 14, sx - 8, fy + footerH - 14, 72) end
        drawText(ctx, section[1], sx, fy + 27, 9, { 187, 196, 187 })
        drawText(ctx, section[2], sx, fy + 61, 11, section[3])
    end
end

local function productArt(data, product)
    local id = tostring(product.id or ""):lower()
    local name = tostring(product.name or product.item or "")
    if id:find("encrypted") or name:find("加密硬盘") then return (data.itemIcons or {})[product.item], "item" end
    if id:find("laptop") or name:find("笔记本") then return (data.itemIcons or {})[product.item], "item" end
    if id:find("thermal") or name:find("热成像") then return (data.itemIcons or {})[product.item], "item" end
    if id:find("bio") or name:find("生物样本") then return (data.itemIcons or {})[product.item], "item" end
    if id:find("watch") or name:find("腕表") then return (data.itemIcons or {})[product.item], "item" end
    if id:find("chip") or name:find("控制芯片") then return (data.itemIcons or {})[product.item], "item" end
    return (data.itemIcons or {})[product.item], "item"
end

local function drawMerchantPage(ctx, x, y, w, h, data)
    local gap, footerH = 12, 170
    local widths = splitWidths(w, gap, { 325, 700, 483 })
    local leftW, centerW, rightW = widths[1], widths[2], widths[3]
    local rightX = x + leftW + centerW + gap * 2
    local bodyH = h - footerH - 12
    local stock = data.merchantStock or {}
    drawPanel(ctx, x, y, leftW, bodyH, { 15, 20, 22 }, { 76, 92, 89 }, false)
    drawSectionTitle(ctx, "私人收购频道", "", x + 16, y + 24, leftW - 32)
    local brokerDrawn = drawImageContained(ctx, (data.art or {}).broker, x + 17, y + 52, leftW - 34, 210, 4)
    if not brokerDrawn then drawPlaceholder(ctx, x + 17, y + 52, leftW - 34, 210, "broker") end
    drawText(ctx, "代号：渡鸦", x + 18, y + 294, 17, { 232, 222, 201 })
    drawText(ctx, "黑市情报掮客", x + 18, y + 334, 9, { 217, 167, 63 })
    drawPanel(ctx, x + 17, y + 364, leftW - 34, bodyH - 382, { 21, 28, 29, 255 }, { 57, 75, 72 }, false)
    drawText(ctx, "收购通信", x + 31, y + 390, 8, { 100, 160, 118 })
    drawTextBox(ctx, "“外面的商店负责卖货。我只收那些没人敢公开报价的东西。”", x + 31, y + 430, leftW - 62, 9, { 192, 198, 187 })
    drawDivider(ctx, x + 31, y + 496, x + leftW - 31, y + 496, 78)
    drawText(ctx, "线路状态", x + 31, y + 530, 8, { 105, 152, 118 })
    drawText(ctx, "稳定", x + leftW - 31, y + 530, 10, { 222, 173, 68 }, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)

    local centerX = x + leftW + gap
    drawPanel(ctx, centerX, y, centerW, bodyH, PANEL, { 139, 104, 40 }, false)
    drawSectionTitle(ctx, "渡鸦的高价收购清单", "", centerX + 16, y + 24, centerW - 32)
    BlackMarketUI.merchantRowRects = {}
    local cardX, cardY, cardGap = centerX + 18, y + 52, 12
    local cardW, cardH = (centerW - 36 - cardGap * 2) / 3, (bodyH - 64 - cardGap) / 2
    for index, product in ipairs(stock) do
        if index <= 6 then
            local cx = cardX + ((index - 1) % 3) * (cardW + cardGap)
            local cy = cardY + math.floor((index - 1) / 3) * (cardH + cardGap)
            local selected = BlackMarketUI.selectedMerchantId == product.id
            local hot = BlackMarketUI.hovered == "merchant-row:" .. product.id
            drawPanel(ctx, cx, cy, cardW, cardH, selected and { 58, 45, 26, 255 } or (hot and { 35, 41, 40, 255 } or { 24, 30, 31, 255 }), selected and ACCENT or { 67, 77, 75 }, selected)
            local image, fallback = productArt(data, product)
            drawArt(ctx, image, cx + 16, cy + 28, cardW - 32, cardH * 0.38, fallback)
            drawText(ctx, product.tag or "限时交易", cx + cardW * 0.5, cy + 17, 7, { 177, 137, 58 }, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            drawText(ctx, product.name or product.item or "未知物资", cx + 14, cy + cardH * 0.60, 9, { 230, 224, 207 })
            local owned = data.countWarehouseItem and data.countWarehouseItem(product.item) or 0
            drawText(ctx, formatNumber(product.price) .. " 比特/件", cx + 14, cy + cardH - 52, 10, { 229, 173, 65 })
            drawText(ctx, "持有 " .. tostring(owned), cx + 14, cy + cardH - 18, 8, owned > 0 and { 105, 177, 128 } or { 152, 162, 156 })
            drawText(ctx, "还需 " .. tostring(product.stock or 0), cx + cardW - 14, cy + cardH - 18, 8, { 152, 162, 156 }, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
            BlackMarketUI.merchantRowRects[product.id] = { x = cx, y = cy, w = cardW, h = cardH }
        end
    end
    if #stock == 0 then drawText(ctx, "渡鸦暂时没有新的收购需求", centerX + centerW * 0.5, y + bodyH * 0.5, 11, { 123, 138, 133 }, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE) end

    drawPanel(ctx, rightX, y, rightW, bodyH, PANEL, { 136, 101, 40 }, false)
    drawSectionTitle(ctx, "交货结算", "", rightX + 16, y + 24, rightW - 32)
    local selected = findById(stock, BlackMarketUI.selectedMerchantId)
    BlackMarketUI.primaryRect = nil
    if selected then
        BlackMarketUI.selectedMerchantId = selected.id
        local image, fallback = productArt(data, selected)
        drawArt(ctx, image, rightX + 28, y + 52, rightW - 56, 178, fallback)
        drawText(ctx, selected.name or selected.item or "未知物资", rightX + 18, y + 264, 16, { 239, 228, 206 })
        drawText(ctx, selected.tag or "特殊渠道", rightX + 18, y + 304, 8, { 219, 169, 64 })
        drawTextBox(ctx, selected.description or "渡鸦正在高价回收这种物资。", rightX + 18, y + 342, rightW - 36, 8, { 171, 179, 170 })
        drawDivider(ctx, rightX + 18, y + 408, rightX + rightW - 18, y + 408, 100)
        local owned = data.countWarehouseItem and data.countWarehouseItem(selected.item) or 0
        local baseValue = getBaseValue(data, selected.item)
        local premium = baseValue > 0 and math.floor(((selected.price / baseValue) - 1) * 100 + 0.5) or 0
        drawText(ctx, "仓库持有", rightX + 18, y + 442, 8, { 133, 145, 141 })
        drawText(ctx, tostring(owned) .. " 件", rightX + rightW - 18, y + 442, 12, owned > 0 and { 105, 177, 128 } or { 191, 198, 188 }, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        drawText(ctx, "剩余需求", rightX + 18, y + 480, 8, { 133, 145, 141 })
        drawText(ctx, tostring(selected.stock or 0) .. " 件", rightX + rightW - 18, y + 480, 10, { 191, 198, 188 }, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        drawPanel(ctx, rightX + 18, y + 510, rightW - 36, 82, { 31, 42, 36, 255 }, { 76, 137, 101 }, false)
        drawText(ctx, "渡鸦单件报价", rightX + 31, y + 532, 8, { 135, 160, 145 })
        drawText(ctx, formatNumber(selected.price) .. " 比特", rightX + rightW - 31, y + 532, 14, { 232, 175, 65 }, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        drawText(ctx, "相对公开市场 " .. (premium >= 0 and "+" or "") .. tostring(premium) .. "%", rightX + 31, y + 558, 8, { 111, 180, 132 })
        local canSell = (selected.stock or 0) > 0 and owned > 0
        local buttonH = 64
        BlackMarketUI.primaryRect = { x = rightX + 18, y = y + bodyH - buttonH - 18, w = rightW - 36, h = buttonH }
        local hot = BlackMarketUI.hovered == "primary" or BlackMarketUI.pressed == "primary"
        drawPanel(ctx, BlackMarketUI.primaryRect.x, BlackMarketUI.primaryRect.y, BlackMarketUI.primaryRect.w, BlackMarketUI.primaryRect.h, canSell and (hot and { 154, 105, 33, 255 } or { 106, 73, 28, 255 }) or { 42, 48, 48, 255 }, canSell and ACCENT or { 74, 83, 81 }, canSell and hot)
        local buttonText = (selected.stock or 0) <= 0 and "收购需求已满足" or (canSell and "出售 1 件给渡鸦" or "仓库暂无该物资")
        drawText(ctx, buttonText, rightX + rightW * 0.5, BlackMarketUI.primaryRect.y + buttonH * 0.5, 12, canSell and { 248, 230, 197 } or { 121, 133, 130 }, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    else
        drawText(ctx, "选择一项收购需求查看交货报价", rightX + rightW * 0.5, y + bodyH * 0.5, 11, { 123, 137, 132 }, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    end

    local fy = y + bodyH + 12
    local footerWidths = splitWidths(w, gap, { 960, 548 })
    local barterW, reputationW = footerWidths[1], footerWidths[2]
    local reputationX = x + barterW + gap
    drawPanel(ctx, x, fy, barterW, footerH, { 16, 21, 23, 255 }, { 118, 91, 42 }, false)
    drawText(ctx, "私人收购规则", x + 18, fy + 25, 10, { 219, 211, 193 })
    local rules = {
        { title = "指定物资", text = "只收清单中的货物" },
        { title = "单件结算", text = "每次从仓库交付 1 件" },
        { title = "高价溢价", text = "报价高于公开市场" },
        { title = "需求有限", text = "数量满足后停止收购" },
    }
    local ruleX = x + 18
    local ruleGap = 10
    local ruleW = (barterW - 36 - ruleGap * 3) / 4
    for index, rule in ipairs(rules) do
        local rx = ruleX + (index - 1) * (ruleW + ruleGap)
        drawPanel(ctx, rx, fy + 48, ruleW, 104, { 22, 27, 29, 255 }, { 66, 76, 75 }, false)
        drawText(ctx, string.format("%02d", index), rx + 14, fy + 70, 8, { 219, 169, 64 })
        drawText(ctx, rule.title, rx + 14, fy + 100, 10, { 211, 215, 203 })
        drawText(ctx, rule.text, rx + 14, fy + 135, 7, { 135, 148, 143 })
    end

    drawPanel(ctx, reputationX, fy, reputationW, footerH,
        { 16, 21, 23, 255 }, { 118, 91, 42 }, false)
    local reputation = math.max(0, tonumber(data.reputation) or 0)
    local repLevel = math.floor(reputation / 100) + 2
    local repProgress = reputation % 100
    drawText(ctx, "信誉进度", reputationX + 18, fy + 25, 10, { 219, 211, 193 })
    drawOrderEmblem(ctx, reputationX + 52, fy + 94, 26, true)
    drawText(ctx, "等级 " .. tostring(repLevel) .. "  黑市中间人", reputationX + 92, fy + 66, 14, { 230, 214, 184 })
    drawText(ctx, "每次成功交货获得 2 点声望", reputationX + 92, fy + 100, 8, { 151, 162, 157 })
    nvgBeginPath(ctx); nvgRect(ctx, reputationX + 92, fy + 120, reputationW - 116, 10)
    nvgFillColor(ctx, nvgRGBA(36, 43, 42, 255)); nvgFill(ctx)
    nvgBeginPath(ctx); nvgRect(ctx, reputationX + 92, fy + 120,
        (reputationW - 116) * repProgress / 100, 10)
    nvgFillColor(ctx, nvgRGBA(191, 141, 46, 255)); nvgFill(ctx)
    drawText(ctx, tostring(repProgress) .. " / 100",
        reputationX + 92, fy + 149, 8, { 207, 171, 92 })
end

local function drawHistoryPage(ctx, x, y, w, h, data)
    local summaryH = 150
    local gap = 12
    local cardW = (w - gap * 2) / 3
    local history = data.history or {}
    local income, expense = 0, 0
    for _, entry in ipairs(history) do
        local amount = tonumber(entry.amount) or 0
        if amount >= 0 then income = income + amount else expense = expense + math.abs(amount) end
    end
    local stats = { { "累计交易收入", income, { 91, 166, 108 } }, { "黑市采购支出", expense, { 203, 112, 80 } }, { "净收益", income - expense, { 225, 171, 65 } } }
    for i, stat in ipairs(stats) do
        local sx = x + (i - 1) * (cardW + gap)
        drawPanel(ctx, sx, y, cardW, summaryH, { 21, 27, 29 }, stat[3], false)
        drawText(ctx, string.format("%02d", i), sx + 18, y + 28, 7, { 132, 145, 140 })
        drawText(ctx, stat[1], sx + 62, y + 28, 10, { 181, 190, 183 })
        drawText(ctx, formatNumber(stat[2]) .. " 比特", sx + 18, y + 88, 20, stat[3])
        drawText(ctx, "最近 30 条交易流水", sx + 18, y + 128, 7, { 119, 132, 128 })
    end
    local tableY, tableH = y + summaryH + 12, h - summaryH - 12
    drawPanel(ctx, x, tableY, w, tableH, PANEL, { 77, 87, 86 }, false)
    drawSectionTitle(ctx, "交易流水", "", x + 16, tableY + 30, w - 32)
    local headerY, headerH = tableY + 66, 42
    nvgBeginPath(ctx); nvgRect(ctx, x + 12, headerY, w - 24, headerH); nvgFillColor(ctx, nvgRGBA(37, 43, 43, 255)); nvgFill(ctx)
    local columns = {
        { "时间", x + 28, nil },
        { "行动", x + 210, nil },
        { "交易摘要", x + 390, nil },
        { "金额变动", x + w - 315, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE },
        { "结算余额", x + w - 32, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE },
    }
    for _, column in ipairs(columns) do
        drawText(ctx, column[1], column[2], headerY + headerH * 0.5, 8, { 148, 159, 154 }, column[3])
    end
    if #history == 0 then
        local cx = x + w * 0.5
        local contentTop = headerY + headerH
        local contentBottom = tableY + tableH
        local cy = (contentTop + contentBottom) * 0.5
        nvgBeginPath(ctx); nvgCircle(ctx, cx, cy - 64, 37); nvgStrokeColor(ctx, nvgRGBA(175, 137, 58, 150)); nvgStrokeWidth(ctx, 1.5); nvgStroke(ctx)
        nvgBeginPath(ctx); nvgRect(ctx, cx - 17, cy - 78, 34, 26); nvgStrokeColor(ctx, nvgRGBA(215, 169, 69, 210)); nvgStrokeWidth(ctx, 1.7); nvgStroke(ctx)
        drawText(ctx, "暂无交易记录", cx, cy + 14, 14, { 192, 199, 190 }, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        drawText(ctx, "完成首次交易后，流水会显示在这里", cx, cy + 62, 9, { 120, 135, 131 }, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        return
    end
    local rowH = 94
    local historyViewport = { x = x + 12, y = headerY + headerH + 4, w = w - 24, h = tableY + tableH - headerY - headerH - 10 }
    BlackMarketUI.historyViewport = historyViewport
    BlackMarketUI.historyScrollMax = math.max(0, #history * rowH - historyViewport.h)
    BlackMarketUI.historyScrollOffset = clamp(BlackMarketUI.historyScrollOffset, 0, BlackMarketUI.historyScrollMax)
    nvgSave(ctx)
    nvgScissor(ctx, historyViewport.x, historyViewport.y, historyViewport.w, historyViewport.h)
    for index, entry in ipairs(history) do
        local ry = historyViewport.y + (index - 1) * rowH - BlackMarketUI.historyScrollOffset
        if ry + rowH >= historyViewport.y and ry <= historyViewport.y + historyViewport.h then
            if index % 2 == 0 then nvgBeginPath(ctx); nvgRect(ctx, x + 12, ry, w - 24, rowH - 2); nvgFillColor(ctx, nvgRGBA(23, 29, 30, 255)); nvgFill(ctx) end
            local amount = tonumber(entry.amount) or 0
            drawText(ctx, entry.time or ("T-" .. tostring(index) .. "H"), x + 28, ry + 28, 9, { 134, 147, 143 })
            drawText(ctx, "#" .. tostring(entry.action or "MARKET"), x + 210, ry + 28, 9, { 181, 190, 181 })
            drawText(ctx, (amount >= 0 and "+" or "-") .. formatNumber(math.abs(amount)), x + w - 315, ry + 28, 11, amount >= 0 and { 93, 168, 111 } or { 207, 112, 81 }, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
            drawText(ctx, formatNumber(entry.balance or 0), x + w - 32, ry + 28, 10, { 226, 172, 65 }, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
            drawText(ctx, entry.description or entry.itemName or "黑市交易", x + 390, ry + 69, 10, { 211, 213, 201 })
        end
    end
    nvgRestore(ctx)
    drawScrollbar(ctx, historyViewport, BlackMarketUI.historyScrollOffset, BlackMarketUI.historyScrollMax)
end

local function drawNotice(ctx)
    if BlackMarketUI.noticeTimer <= 0 or BlackMarketUI.notice == "" then return end
    local noticeW, noticeH = 520, 46
    local x, y = (DESIGN_W - noticeW) * 0.5, DESIGN_H - 65
    local border = BlackMarketUI.noticeSuccess and { 91, 166, 107 } or { 200, 104, 77 }
    drawPanel(ctx, x, y, noticeW, noticeH, { 24, 29, 30 }, border, false)
    drawText(ctx, BlackMarketUI.notice, x + noticeW * 0.5, y + noticeH * 0.5, 11, { 240, 231, 210 }, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
end

function BlackMarketUI.Open()
    BlackMarketUI.activeTab = "quotes"; BlackMarketUI.hovered = nil; BlackMarketUI.pressed = nil
    BlackMarketUI.selectedCategory = "all"; BlackMarketUI.selectedSellKey = nil; BlackMarketUI.selectedOrderId = nil; BlackMarketUI.selectedMerchantId = nil
    BlackMarketUI.sellSelection = {}; BlackMarketUI.scrollOffset = 0; BlackMarketUI.orderScrollOffset = 0; BlackMarketUI.historyScrollOffset = 0; BlackMarketUI.scrollKind = nil; BlackMarketUI.notice = ""; BlackMarketUI.noticeTimer = 0
    BlackMarketUI.touchId = nil; BlackMarketUI.touchScrolling = false; BlackMarketUI.ignoreMouseTimer = 0
    print("[BlackMarket] 交易终端界面已打开")
end

function BlackMarketUI.Update(dt)
    BlackMarketUI.animTime = BlackMarketUI.animTime + (dt or 0)
    BlackMarketUI.ignoreMouseTimer = math.max(0, BlackMarketUI.ignoreMouseTimer - (dt or 0))
    if BlackMarketUI.noticeTimer > 0 then BlackMarketUI.noticeTimer = math.max(0, BlackMarketUI.noticeTimer - (dt or 0)) end
end

function BlackMarketUI.SetNotice(message, success)
    BlackMarketUI.notice = message or ""; BlackMarketUI.noticeSuccess = success == true; BlackMarketUI.noticeTimer = 2.6
end

function BlackMarketUI.GetSellSelection()
    local result = {}
    for key in pairs(BlackMarketUI.sellSelection) do
        local tabIndex, itemIndex = key:match("^(%d+):(%d+)$")
        if tabIndex and itemIndex then result[#result + 1] = { tabIndex = tonumber(tabIndex), itemIndex = tonumber(itemIndex) } end
    end
    return result
end

function BlackMarketUI.ClearSellSelection()
    BlackMarketUI.sellSelection = {}; BlackMarketUI.selectedSellKey = nil
end

function BlackMarketUI.ScrollAt(x, y, delta)
    local dx, dy = toDesignPoint(x, y)
    local amount = (delta or 0) / math.max(BlackMarketUI.layoutScale, 0.01)
    if BlackMarketUI.activeTab == "sell" and pointInRect(dx, dy, BlackMarketUI.listViewport) then
        BlackMarketUI.scrollOffset = clamp(BlackMarketUI.scrollOffset + amount, 0, BlackMarketUI.scrollMax)
        return true
    elseif BlackMarketUI.activeTab == "orders" and pointInRect(dx, dy, BlackMarketUI.orderViewport) then
        BlackMarketUI.orderScrollOffset = clamp(BlackMarketUI.orderScrollOffset + amount, 0, BlackMarketUI.orderScrollMax)
        return true
    elseif BlackMarketUI.activeTab == "history" and pointInRect(dx, dy, BlackMarketUI.historyViewport) then
        BlackMarketUI.historyScrollOffset = clamp(BlackMarketUI.historyScrollOffset + amount, 0, BlackMarketUI.historyScrollMax)
        return true
    end
    return false
end

function BlackMarketUI.GetHit(x, y)
    local dx, dy = toDesignPoint(x, y)
    if pointInRect(dx, dy, BlackMarketUI.backRect) then return "back" end
    for _, tab in ipairs(TABS) do if pointInRect(dx, dy, BlackMarketUI.tabRects[tab.id]) then return "tab:" .. tab.id end end
    if BlackMarketUI.activeTab == "quotes" then
        if pointInRect(dx, dy, BlackMarketUI.primaryRect) then return "primary" end
        for action, rect in pairs(BlackMarketUI.sellRowRects) do if pointInRect(dx, dy, rect) then return action end end
    elseif BlackMarketUI.activeTab == "sell" then
        if pointInRect(dx, dy, BlackMarketUI.primaryRect) then return "primary" end
        if pointInRect(dx, dy, BlackMarketUI.secondaryRect) then return "secondary" end
        for _, category in ipairs(CATEGORIES) do if pointInRect(dx, dy, BlackMarketUI.categoryRects[category.id]) then return "category:" .. category.id end end
        if pointInRect(dx, dy, BlackMarketUI.listViewport) then
            for key, rect in pairs(BlackMarketUI.sellRowRects) do if pointInRect(dx, dy, rect) then return "sell-row:" .. key end end
        end
    elseif BlackMarketUI.activeTab == "orders" then
        if pointInRect(dx, dy, BlackMarketUI.primaryRect) then return "primary" end
        if pointInRect(dx, dy, BlackMarketUI.orderViewport) then
            for id, rect in pairs(BlackMarketUI.orderRowRects) do if pointInRect(dx, dy, rect) then return "order-row:" .. id end end
        end
    elseif BlackMarketUI.activeTab == "merchant" then
        if pointInRect(dx, dy, BlackMarketUI.primaryRect) then return "primary" end
        for id, rect in pairs(BlackMarketUI.merchantRowRects) do if pointInRect(dx, dy, rect) then return "merchant-row:" .. id end end
    end
    return nil
end

function BlackMarketUI.PointerMove(x, y)
    BlackMarketUI.hovered = BlackMarketUI.GetHit(x, y)
end

function BlackMarketUI.PointerDown(x, y)
    BlackMarketUI.pressed = BlackMarketUI.GetHit(x, y)
    return BlackMarketUI.pressed
end

function BlackMarketUI.PointerUp(x, y)
    local hit = BlackMarketUI.GetHit(x, y)
    local action = hit and hit == BlackMarketUI.pressed and hit or nil
    BlackMarketUI.pressed = nil
    if not action then return nil end
    action = tostring(action)
    if action == "back" then return "back" end
    local tabId = action:match("^tab:(.+)$")
    if tabId then
        BlackMarketUI.activeTab = tabId
        BlackMarketUI.scrollOffset = 0
        BlackMarketUI.orderScrollOffset = 0
        BlackMarketUI.historyScrollOffset = 0
        BlackMarketUI.hovered = nil
        return "tab"
    end
    local quoteName = action:match("^quote:(.+)$")
    if quoteName then BlackMarketUI.activeTab = "sell"; BlackMarketUI.selectedCategory = getCategory(quoteName); BlackMarketUI.selectedSellKey = nil; BlackMarketUI.scrollOffset = 0; return "tab" end
    if action == "primary" and BlackMarketUI.activeTab == "quotes" then BlackMarketUI.activeTab = "sell"; BlackMarketUI.scrollOffset = 0; return "tab" end
    local categoryId = action:match("^category:(.+)$")
    if categoryId then BlackMarketUI.selectedCategory = categoryId; BlackMarketUI.selectedSellKey = nil; BlackMarketUI.scrollOffset = 0; return "category" end
    local sellKey = action:match("^sell%-row:(.+)$")
    if sellKey then BlackMarketUI.selectedSellKey = sellKey; return "select" end
    local orderId = action:match("^order%-row:(.+)$")
    if orderId then BlackMarketUI.selectedOrderId = orderId; return "select" end
    local merchantId = action:match("^merchant%-row:(.+)$")
    if merchantId then BlackMarketUI.selectedMerchantId = merchantId; return "select" end
    if action == "primary" then
        if BlackMarketUI.activeTab == "sell" and BlackMarketUI.selectedSellKey then
            BlackMarketUI.sellSelection[BlackMarketUI.selectedSellKey] = not BlackMarketUI.sellSelection[BlackMarketUI.selectedSellKey] or nil
            return "selection"
        elseif BlackMarketUI.activeTab == "orders" and BlackMarketUI.selectedOrderId then
            return "order-action:" .. BlackMarketUI.selectedOrderId
        elseif BlackMarketUI.activeTab == "merchant" and BlackMarketUI.selectedMerchantId then
            return "merchant-sell:" .. BlackMarketUI.selectedMerchantId
        end
    elseif action == "secondary" and BlackMarketUI.activeTab == "sell" then
        return "sell-confirm"
    end
    return action
end

function BlackMarketUI.TouchBegin(touchId, x, y)
    if BlackMarketUI.touchId ~= nil then return false end
    BlackMarketUI.touchId = touchId; BlackMarketUI.ignoreMouseTimer = 0.5
    BlackMarketUI.touchStartX, BlackMarketUI.touchStartY = toDesignPoint(x, y)
    BlackMarketUI.scrollKind = nil
    if BlackMarketUI.activeTab == "sell" and pointInRect(BlackMarketUI.touchStartX, BlackMarketUI.touchStartY, BlackMarketUI.listViewport) then
        BlackMarketUI.scrollKind = "sell"
        BlackMarketUI.touchScrollStart = BlackMarketUI.scrollOffset
    elseif BlackMarketUI.activeTab == "orders" and pointInRect(BlackMarketUI.touchStartX, BlackMarketUI.touchStartY, BlackMarketUI.orderViewport) then
        BlackMarketUI.scrollKind = "orders"
        BlackMarketUI.touchScrollStart = BlackMarketUI.orderScrollOffset
    elseif BlackMarketUI.activeTab == "history" and pointInRect(BlackMarketUI.touchStartX, BlackMarketUI.touchStartY, BlackMarketUI.historyViewport) then
        BlackMarketUI.scrollKind = "history"
        BlackMarketUI.touchScrollStart = BlackMarketUI.historyScrollOffset
    end
    BlackMarketUI.touchScrolling = false
    BlackMarketUI.PointerDown(x, y)
    return true
end

function BlackMarketUI.TouchMove(touchId, x, y)
    if BlackMarketUI.touchId ~= touchId then return false end
    BlackMarketUI.ignoreMouseTimer = 0.5
    local dx, dy = toDesignPoint(x, y)
    local moveX, moveY = dx - BlackMarketUI.touchStartX, dy - BlackMarketUI.touchStartY
    if BlackMarketUI.scrollKind and moveX * moveX + moveY * moveY > 64 then
        BlackMarketUI.touchScrolling = true; BlackMarketUI.pressed = nil
    end
    if BlackMarketUI.touchScrolling then
        local nextOffset = BlackMarketUI.touchScrollStart - moveY
        if BlackMarketUI.scrollKind == "sell" then
            BlackMarketUI.scrollOffset = clamp(nextOffset, 0, BlackMarketUI.scrollMax)
        elseif BlackMarketUI.scrollKind == "orders" then
            BlackMarketUI.orderScrollOffset = clamp(nextOffset, 0, BlackMarketUI.orderScrollMax)
        elseif BlackMarketUI.scrollKind == "history" then
            BlackMarketUI.historyScrollOffset = clamp(nextOffset, 0, BlackMarketUI.historyScrollMax)
        end
    else
        BlackMarketUI.PointerMove(x, y)
    end
    return true
end

function BlackMarketUI.TouchEnd(touchId, x, y)
    if BlackMarketUI.touchId ~= touchId then return nil end
    BlackMarketUI.ignoreMouseTimer = 0.5
    local action = nil
    if not BlackMarketUI.touchScrolling then BlackMarketUI.PointerMove(x, y); action = BlackMarketUI.PointerUp(x, y) else BlackMarketUI.pressed = nil end
    BlackMarketUI.touchId = nil; BlackMarketUI.touchScrolling = false; BlackMarketUI.scrollKind = nil
    return action
end

function BlackMarketUI.ShouldIgnoreMouse()
    return BlackMarketUI.touchId ~= nil or BlackMarketUI.ignoreMouseTimer > 0
end

function BlackMarketUI.Draw(ctx, width, height, data)
    data = data or {}
    local viewportAspect = width / math.max(height, 1)
    local designAspect = DESIGN_W / DESIGN_H
    local scale
    if viewportAspect >= designAspect then
        scale = height / DESIGN_H
    else
        scale = width / DESIGN_W
    end
    BlackMarketUI.layoutScale = math.max(scale, 0.001)
    BlackMarketUI.layoutWidth = width / BlackMarketUI.layoutScale
    BlackMarketUI.layoutOffsetX = 0
    BlackMarketUI.layoutOffsetY = (height / BlackMarketUI.layoutScale - DESIGN_H) * 0.5
    BlackMarketUI.primaryRect = nil; BlackMarketUI.secondaryRect = nil; BlackMarketUI.sellRowRects = {}; BlackMarketUI.orderRowRects = {}; BlackMarketUI.merchantRowRects = {}; BlackMarketUI.listViewport = nil; BlackMarketUI.orderViewport = nil; BlackMarketUI.historyViewport = nil; BlackMarketUI.scrollMax = 0; BlackMarketUI.orderScrollMax = 0; BlackMarketUI.historyScrollMax = 0

    drawBackground(ctx, width, height)
    nvgSave(ctx)
    nvgScale(ctx, BlackMarketUI.layoutScale, BlackMarketUI.layoutScale)
    nvgTranslate(ctx, BlackMarketUI.layoutOffsetX, BlackMarketUI.layoutOffsetY)
    drawHeader(ctx, data, BlackMarketUI.layoutWidth)
    drawTabs(ctx, BlackMarketUI.layoutWidth)
    local contentX, contentY = 18, 186
    local contentW = BlackMarketUI.layoutWidth - 36
    local contentH = DESIGN_H - contentY - 18
    if BlackMarketUI.activeTab == "quotes" then
        drawQuotePage(ctx, contentX, contentY, contentW, contentH, data)
    elseif BlackMarketUI.activeTab == "sell" then
        drawSellPage(ctx, contentX, contentY, contentW, contentH, data)
    elseif BlackMarketUI.activeTab == "orders" then
        drawOrdersPage(ctx, contentX, contentY, contentW, contentH, data)
    elseif BlackMarketUI.activeTab == "merchant" then
        drawMerchantPage(ctx, contentX, contentY, contentW, contentH, data)
    else
        drawHistoryPage(ctx, contentX, contentY, contentW, contentH, data)
    end
    drawNotice(ctx)
    nvgRestore(ctx)
end

return BlackMarketUI
