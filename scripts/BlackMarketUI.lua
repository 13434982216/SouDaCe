local Currency = require "Currency"

local BlackMarketUI = {
    activeTab = "shop",
    hovered = nil,
    pressed = nil,
    tabRects = {},
    itemRects = {},
    merchantRects = {},
    auctionRects = {},
    categoryRects = {},
    backRect = nil,
    primaryRect = nil,
    secondaryRect = nil,
    listViewport = nil,
    selectedCategory = "all",
    selectedMerchantId = nil,
    selectedAuctionId = nil,
    sellSelection = {},
    scrollOffset = 0,
    scrollMax = 0,
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
}

local DESIGN_W, DESIGN_H = 1365, 768
local PAPER = { 185, 174, 143 }
local PAPER_BRIGHT = { 218, 205, 167 }
local MUTED = { 119, 112, 91 }
local ACCENT = { 151, 119, 56 }
local ACCENT_BRIGHT = { 191, 148, 65 }
local RED = { 143, 54, 43 }
local GREEN = { 91, 125, 78 }
local DARK = { 13, 16, 13 }

local TABS = {
    { id = "shop", label = "黑店" },
    { id = "merchant", label = "神秘商人" },
    { id = "auction", label = "拍卖行" },
}

local CATEGORIES = {
    { id = "all", label = "全部" },
    { id = "valuables", label = "贵重" },
    { id = "electronics", label = "电子" },
    { id = "medical", label = "医疗" },
    { id = "materials", label = "材料" },
    { id = "equipment", label = "装备" },
    { id = "supplies", label = "补给" },
}

local CATEGORY_ITEMS = {
    electronics = {
        ["旧手机"] = true, ["机械键盘"] = true, ["平板电脑"] = true,
        ["加密硬盘"] = true, ["卫星电话"] = true, ["显卡"] = true,
        ["军用加固笔记本"] = true, ["加密无人机核心"] = true,
        ["航空级控制芯片"] = true, ["军用热成像仪"] = true,
    },
    medical = { ["急救包"] = true, ["机密生物样本"] = true },
    materials = {
        ["螺丝刀"] = true, ["电池"] = true, ["胶带"] = true,
        ["扳手"] = true, ["高纯度钯金块"] = true, ["精密光学模组"] = true,
    },
    equipment = {
        ["手枪"] = true, ["散弹枪"] = true, ["棒球棍"] = true,
        ["二级头盔"] = true, ["二级防弹衣"] = true, ["二级胸挂"] = true,
        ["二级背包"] = true, ["二级安全箱"] = true, ["三级安全箱"] = true,
        ["手枪弹药盒"] = true, ["散弹枪弹药包"] = true,
        ["通用战术消音器"] = true,
    },
    supplies = {
        ["罐头"] = true, ["净水"] = true, ["稀有咖啡豆"] = true,
        ["香槟酒"] = true, ["高级香烟"] = true,
    },
}

local RARITY_COLORS = {
    red = { 157, 55, 46 }, pink = { 153, 68, 116 }, gold = { 174, 129, 43 },
    purple = { 102, 71, 137 }, blue = { 55, 91, 128 }, green = { 57, 99, 66 },
}
local RARITY_LABELS = {
    red = "传说", pink = "史诗", gold = "珍藏",
    purple = "稀有", blue = "精良", green = "普通",
}

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function rgba(color, alpha)
    return nvgRGBA(color[1], color[2], color[3], alpha or color[4] or 255)
end

local function pointInRect(x, y, rect)
    return rect and x >= rect.x and x <= rect.x + rect.w
        and y >= rect.y and y <= rect.y + rect.h
end

local function toDesignPoint(x, y)
    local scale = math.max(BlackMarketUI.layoutScale, 0.001)
    return x / scale - BlackMarketUI.layoutOffsetX,
        y / scale - BlackMarketUI.layoutOffsetY
end

local function formatCountdown(seconds)
    local total = math.max(0, math.ceil(tonumber(seconds) or 0))
    local hours = math.floor(total / 3600)
    local minutes = math.floor((total % 3600) / 60)
    local secs = total % 60
    if hours > 0 then
        return string.format("%02d:%02d:%02d", hours, minutes, secs)
    end
    return string.format("%02d:%02d", minutes, secs)
end

local function drawText(ctx, text, x, y, size, color, align)
    nvgFontFace(ctx, "sans")
    nvgFontSize(ctx, size)
    nvgTextAlign(ctx, align or (NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE))
    nvgFillColor(ctx, rgba(color))
    nvgText(ctx, x, y, tostring(text or ""))
end

local function drawTextBox(ctx, text, x, y, width, size, color)
    nvgFontFace(ctx, "sans")
    nvgFontSize(ctx, size)
    nvgTextLineHeight(ctx, 1.25)
    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(ctx, rgba(color))
    nvgTextBox(ctx, x, y, width, tostring(text or ""))
end

local function drawLine(ctx, x1, y1, x2, y2, color, alpha)
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, x1, y1)
    nvgLineTo(ctx, x2, y2)
    nvgStrokeColor(ctx, rgba(color, alpha or 120))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)
end

local function fillRect(ctx, x, y, w, h, color, alpha)
    nvgBeginPath(ctx)
    nvgRect(ctx, x, y, w, h)
    nvgFillColor(ctx, rgba(color, alpha))
    nvgFill(ctx)
end

local function strokeRect(ctx, x, y, w, h, color, alpha, width)
    nvgBeginPath(ctx)
    nvgRect(ctx, x, y, w, h)
    nvgStrokeColor(ctx, rgba(color, alpha))
    nvgStrokeWidth(ctx, width or 1)
    nvgStroke(ctx)
end

local function drawImageContained(ctx, imageId, x, y, w, h, padding)
    if type(imageId) ~= "number" or imageId <= 0 then return false end
    local imageW, imageH = nvgImageSize(ctx, imageId)
    if not imageW or not imageH or imageW <= 0 or imageH <= 0 then return false end
    local inset = padding or 0
    local scale = math.min((w - inset * 2) / imageW, (h - inset * 2) / imageH)
    local drawW, drawH = imageW * scale, imageH * scale
    local drawX = x + (w - drawW) * 0.5
    local drawY = y + (h - drawH) * 0.5
    nvgBeginPath(ctx)
    nvgRect(ctx, drawX, drawY, drawW, drawH)
    nvgFillPaint(ctx, nvgImagePattern(ctx, drawX, drawY, drawW, drawH,
        0, imageId, 1.0))
    nvgFill(ctx)
    return true
end

local function drawImageCovered(ctx, imageId, x, y, w, h)
    if type(imageId) ~= "number" or imageId <= 0 then return false end
    local imageW, imageH = nvgImageSize(ctx, imageId)
    if not imageW or not imageH or imageW <= 0 or imageH <= 0 then return false end
    local scale = math.max(w / imageW, h / imageH)
    local drawW, drawH = imageW * scale, imageH * scale
    local drawX, drawY = x + (w - drawW) * 0.5, y + (h - drawH) * 0.5
    nvgSave(ctx)
    nvgScissor(ctx, x, y, w, h)
    nvgBeginPath(ctx)
    nvgRect(ctx, drawX, drawY, drawW, drawH)
    nvgFillPaint(ctx, nvgImagePattern(ctx, drawX, drawY, drawW, drawH,
        0, imageId, 1.0))
    nvgFill(ctx)
    nvgRestore(ctx)
    return true
end

local function drawPlaceholder(ctx, x, y, w, h)
    fillRect(ctx, x, y, w, h, { 18, 21, 17 }, 245)
    strokeRect(ctx, x, y, w, h, ACCENT, 80, 1)
    drawText(ctx, "?", x + w * 0.5, y + h * 0.5, 22, MUTED,
        NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
end

local function drawItemArt(ctx, imageId, x, y, w, h)
    if not drawImageContained(ctx, imageId, x, y, w, h, 6) then
        drawPlaceholder(ctx, x, y, w, h)
    end
end

local function drawButton(ctx, id, rect, label, enabled, redStyle)
    local hot = enabled and (BlackMarketUI.hovered == id or BlackMarketUI.pressed == id)
    local pressed = enabled and BlackMarketUI.pressed == id
    local offset = pressed and 2 or 0
    local fill = enabled and (redStyle and RED or { 78, 59, 29 }) or { 35, 37, 30 }
    if hot then
        fill = redStyle and { 169, 66, 50 } or { 105, 77, 34 }
    end
    fillRect(ctx, rect.x + offset, rect.y + offset,
        rect.w - offset * 2, rect.h - offset * 2, fill, 245)
    strokeRect(ctx, rect.x + offset, rect.y + offset,
        rect.w - offset * 2, rect.h - offset * 2,
        enabled and (redStyle and { 119, 61, 48 } or ACCENT_BRIGHT) or MUTED,
        enabled and 220 or 90, 1.5)
    drawText(ctx, label, rect.x + rect.w * 0.5,
        rect.y + rect.h * 0.5 + offset, 16,
        enabled and PAPER_BRIGHT or MUTED,
        NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
end

local function getItemName(entry)
    return type(entry) == "table" and entry.item or entry
end

local function getCategory(itemName)
    for category, items in pairs(CATEGORY_ITEMS) do
        if items[itemName] then return category end
    end
    return "valuables"
end

local function getBaseValue(data, itemName)
    local info = (data.itemValues or {})[itemName]
    return info and math.max(0, math.floor(tonumber(info.value) or 0)) or 1000
end

local function getQuote(data, itemName)
    local rate = tonumber((data.marketRates or {})[getCategory(itemName)]) or 1
    return math.floor(getBaseValue(data, itemName) * rate), rate
end

local function buildSellItems(data)
    local result = {}
    for tabIndex, tab in ipairs(data.warehouseTabs or {}) do
        if tab.unlocked ~= false then
            for itemIndex, entry in ipairs(tab.items or {}) do
                local itemName = getItemName(entry)
                if type(itemName) == "string" and itemName:sub(1, 10) ~= "__taken__:" then
                    local category = getCategory(itemName)
                    if BlackMarketUI.selectedCategory == "all"
                        or BlackMarketUI.selectedCategory == category then
                        local quote, rate = getQuote(data, itemName)
                        result[#result + 1] = {
                            key = tostring(tabIndex) .. ":" .. tostring(itemIndex),
                            tabIndex = tabIndex,
                            itemIndex = itemIndex,
                            itemName = itemName,
                            category = category,
                            rarity = (data.itemRarity or {})[itemName] or "green",
                            baseValue = getBaseValue(data, itemName),
                            quote = quote,
                            rate = rate,
                        }
                    end
                end
            end
        end
    end
    table.sort(result, function(a, b)
        if a.quote == b.quote then return a.itemName < b.itemName end
        return a.quote > b.quote
    end)
    return result
end

local function findById(items, id)
    for _, item in ipairs(items or {}) do
        if tostring(item.id) == tostring(id) then return item end
    end
    return items and items[1] or nil
end

local function drawFrame(ctx, data)
    local frame = (data.art or {}).frame
    if drawImageCovered(ctx, frame, 0, 0, DESIGN_W, DESIGN_H) then return end
    fillRect(ctx, 0, 0, DESIGN_W, DESIGN_H, { 5, 7, 5 }, 255)
    strokeRect(ctx, 8, 8, DESIGN_W - 16, DESIGN_H - 16, ACCENT, 180, 2)
    strokeRect(ctx, 10, 150, 840, 530, ACCENT, 120, 1)
    strokeRect(ctx, 865, 150, 490, 530, ACCENT, 120, 1)
end

local function drawHeader(ctx, data)
    drawText(ctx, "黑市交易终端", 34, 46, 27, { 31, 27, 19 })
    drawText(ctx, "BLACK MARKET TERMINAL", 36, 69, 9, { 72, 61, 40 })

    local reputation = math.max(0, math.floor(tonumber(data.reputation) or 0))
    local repLevel = math.floor(reputation / 100) + 1
    local repProgress = reputation % 100
    drawText(ctx, "声望等级 · " .. tostring(repLevel), 432, 30, 12, PAPER)
    fillRect(ctx, 432, 51, 174, 7, { 6, 8, 6 }, 255)
    fillRect(ctx, 432, 51, 174 * repProgress / 100, 7, ACCENT, 230)
    drawText(ctx, tostring(repProgress) .. " / 100", 616, 55, 9, MUTED)

    drawText(ctx, "行情刷新", 740, 28, 11, MUTED)
    drawText(ctx, formatCountdown(data.refreshRemaining), 740, 54, 17, { 151, 75, 57 })

    drawText(ctx, "比特币余额", 938, 28, 11, MUTED)
    local iconRect = { x = 936, y = 42, w = 31, h = 31 }
    drawImageContained(ctx, data.currencyIcon, iconRect.x, iconRect.y,
        iconRect.w, iconRect.h, 0)
    drawText(ctx, Currency.FormatNumber(data.bits), 976, 57, 18, PAPER_BRIGHT)

    BlackMarketUI.backRect = { x = 1173, y = 16, w = 170, h = 55 }
    local hot = BlackMarketUI.hovered == "back" or BlackMarketUI.pressed == "back"
    if hot then fillRect(ctx, 1177, 20, 162, 47, { 87, 64, 31 }, 105) end
    drawText(ctx, "返回据点", 1251, 44, 17, hot and PAPER_BRIGHT or PAPER,
        NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    drawText(ctx, "›", 1320, 44, 25, ACCENT,
        NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
end

local function drawTabs(ctx)
    BlackMarketUI.tabRects = {}
    local x, y, w, h, gap = 12, 92, 1341, 48, 8
    local tabW = (w - gap * 2) / 3
    for index, tab in ipairs(TABS) do
        local tx = x + (index - 1) * (tabW + gap)
        local rect = { x = tx, y = y, w = tabW, h = h }
        BlackMarketUI.tabRects[tab.id] = rect
        local id = "tab:" .. tab.id
        local active = BlackMarketUI.activeTab == tab.id
        local hot = BlackMarketUI.hovered == id or BlackMarketUI.pressed == id
        if active or hot then
            fillRect(ctx, tx + 4, y + 4, tabW - 8, h - 8,
                active and { 111, 82, 37 } or { 55, 50, 34 }, active and 145 or 90)
        end
        if active then fillRect(ctx, tx + 12, y + h - 5, tabW - 24, 3, ACCENT_BRIGHT, 220) end
        drawText(ctx, string.format("0%d", index), tx + 25, y + h * 0.5,
            10, active and ACCENT_BRIGHT or MUTED)
        drawText(ctx, tab.label, tx + tabW * 0.5, y + h * 0.5,
            19, active and PAPER_BRIGHT or (hot and PAPER or MUTED),
            NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    end
end

local function drawCategoryBar(ctx)
    BlackMarketUI.categoryRects = {}
    drawText(ctx, "搜刽物资", 30, 180, 18, PAPER_BRIGHT)
    drawText(ctx, "探索中获得", 128, 181, 10, ACCENT)
    local x, y, gap = 250, 163, 4
    for _, category in ipairs(CATEGORIES) do
        local w = 54
        local rect = { x = x, y = y, w = w, h = 34 }
        BlackMarketUI.categoryRects[category.id] = rect
        local active = BlackMarketUI.selectedCategory == category.id
        local hot = BlackMarketUI.hovered == "category:" .. category.id
        if active or hot then
            fillRect(ctx, x, y, w, 34,
                active and { 70, 61, 38 } or { 42, 43, 32 }, 210)
        end
        strokeRect(ctx, x, y, w, 34, active and ACCENT_BRIGHT or MUTED,
            active and 190 or 70, 1)
        drawText(ctx, category.label, x + w * 0.5, y + 17, 11,
            active and PAPER_BRIGHT or MUTED,
            NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        x = x + w + gap
    end
end

local function drawShopCard(ctx, data, item, rect)
    local checked = BlackMarketUI.sellSelection[item.key] == true
    local id = "item:" .. item.key
    local hot = BlackMarketUI.hovered == id or BlackMarketUI.pressed == id
    local rarity = RARITY_COLORS[item.rarity] or RARITY_COLORS.green
    fillRect(ctx, rect.x, rect.y, rect.w, rect.h,
        checked and { 43, 39, 25 } or (hot and { 29, 31, 25 } or { 18, 21, 17 }), 244)
    strokeRect(ctx, rect.x, rect.y, rect.w, rect.h,
        checked and ACCENT_BRIGHT or rarity, checked and 235 or 150,
        checked and 2 or 1)
    drawItemArt(ctx, (data.itemIcons or {})[item.itemName],
        rect.x + 7, rect.y + 7, rect.w - 14, rect.h - 50)
    fillRect(ctx, rect.x, rect.y + rect.h - 42, rect.w, 42, DARK, 225)
    drawText(ctx, item.itemName, rect.x + 8, rect.y + rect.h - 27,
        11, checked and PAPER_BRIGHT or PAPER)
    drawText(ctx, Currency.FormatNumber(item.quote), rect.x + 8,
        rect.y + rect.h - 10, 11, ACCENT_BRIGHT)
    drawText(ctx, RARITY_LABELS[item.rarity] or "普通", rect.x + rect.w - 7,
        rect.y + rect.h - 10, 9, rarity,
        NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    fillRect(ctx, rect.x + 6, rect.y + 6, 19, 19,
        checked and GREEN or { 18, 22, 18 }, 250)
    strokeRect(ctx, rect.x + 6, rect.y + 6, 19, 19,
        checked and { 151, 171, 113 } or MUTED, 190, 1)
    if checked then
        drawText(ctx, "✓", rect.x + 15.5, rect.y + 15.5, 13, PAPER_BRIGHT,
            NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    end
end

local function drawShopPage(ctx, data)
    drawCategoryBar(ctx)
    local items = buildSellItems(data)
    BlackMarketUI.itemRects = {}
    BlackMarketUI.listViewport = { x = 20, y = 207, w = 822, h = 463 }
    local viewport = BlackMarketUI.listViewport
    local cols, gap, cardH = 6, 8, 143
    local cardW = (viewport.w - gap * (cols - 1)) / cols
    local rows = math.ceil(#items / cols)
    BlackMarketUI.scrollMax = math.max(0, rows * (cardH + gap) - gap - viewport.h)
    BlackMarketUI.scrollOffset = clamp(BlackMarketUI.scrollOffset, 0, BlackMarketUI.scrollMax)
    nvgSave(ctx)
    nvgScissor(ctx, viewport.x, viewport.y, viewport.w, viewport.h)
    for index, item in ipairs(items) do
        local col = (index - 1) % cols
        local row = math.floor((index - 1) / cols)
        local rect = {
            x = viewport.x + col * (cardW + gap),
            y = viewport.y + row * (cardH + gap) - BlackMarketUI.scrollOffset,
            w = cardW,
            h = cardH,
        }
        BlackMarketUI.itemRects[item.key] = rect
        if rect.y + rect.h >= viewport.y and rect.y <= viewport.y + viewport.h then
            drawShopCard(ctx, data, item, rect)
        end
    end
    nvgRestore(ctx)
    if #items == 0 then
        drawText(ctx, "仓库中没有符合筛选条件的物资", 431, 425, 15, MUTED,
            NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    end

    drawText(ctx, "出售清单与估价", 894, 181, 18, PAPER_BRIGHT)
    local selected = {}
    local selectedByKey = {}
    for _, item in ipairs(items) do selectedByKey[item.key] = item end
    local gross = 0
    for key in pairs(BlackMarketUI.sellSelection) do
        local item = selectedByKey[key]
        if item then
            selected[#selected + 1] = item
            gross = gross + item.quote
        end
    end
    table.sort(selected, function(a, b) return a.quote > b.quote end)
    local rowY = 219
    for index = 1, math.min(7, #selected) do
        local item = selected[index]
        local y = rowY + (index - 1) * 48
        if index % 2 == 1 then fillRect(ctx, 884, y - 18, 448, 43, { 22, 25, 20 }, 175) end
        drawItemArt(ctx, (data.itemIcons or {})[item.itemName], 890, y - 15, 38, 38)
        drawText(ctx, item.itemName, 938, y, 11, PAPER)
        local delta = math.floor((item.rate - 1) * 100 + 0.5)
        drawText(ctx, (delta >= 0 and "+" or "") .. tostring(delta) .. "%",
            1162, y, 10, delta >= 0 and ACCENT_BRIGHT or { 115, 92, 72 },
            NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        drawText(ctx, Currency.FormatNumber(item.quote), 1318, y, 11,
            PAPER_BRIGHT, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    end
    if #selected == 0 then
        drawText(ctx, "从左侧选择要出售的搜刽物资", 1108, 355, 14, MUTED,
            NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    elseif #selected > 7 then
        drawText(ctx, "另有 " .. tostring(#selected - 7) .. " 件已选物资",
            1108, 561, 10, MUTED, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    end

    local fee = math.floor(gross * 0.05)
    local payout = math.max(0, gross - fee)
    drawLine(ctx, 885, 572, 1325, 572, ACCENT, 85)
    drawText(ctx, "物资估价", 894, 594, 11, MUTED)
    drawText(ctx, Currency.FormatNumber(gross), 1318, 594, 12, PAPER,
        NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    drawText(ctx, "黑市手续费 5%", 894, 621, 11, MUTED)
    drawText(ctx, "-" .. Currency.FormatNumber(fee), 1318, 621, 12,
        { 151, 82, 63 }, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    drawText(ctx, "预计获得", 894, 652, 13, PAPER)
    drawImageContained(ctx, data.currencyIcon, 1115, 637, 29, 29, 0)
    drawText(ctx, Currency.FormatNumber(payout), 1318, 652, 21,
        ACCENT_BRIGHT, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)

    BlackMarketUI.primaryRect = { x = 665, y = 163, w = 167, h = 34 }
    drawButton(ctx, "primary", BlackMarketUI.primaryRect,
        "一键选择可出售", #items > 0, false)
    BlackMarketUI.secondaryRect = { x = 995, y = 690, w = 335, h = 56 }
    drawButton(ctx, "secondary", BlackMarketUI.secondaryRect,
        "确认出售", #selected > 0, true)

    local used, capacity = 0, 0
    for _, tab in ipairs(data.warehouseTabs or {}) do
        capacity = capacity + (tonumber(tab.cols) or 0) * (tonumber(tab.rows) or 0)
        for _, entry in ipairs(tab.items or {}) do
            local size = (data.itemSizes or {})[getItemName(entry)] or { 1, 1 }
            used = used + (size[1] or 1) * (size[2] or 1)
        end
    end
    drawText(ctx, "仓库容量", 35, 718, 11, MUTED)
    drawText(ctx, tostring(used) .. " / " .. tostring(capacity), 132, 718, 15, PAPER)
    drawText(ctx, "已选 " .. tostring(#selected) .. " 件", 468, 718, 14, PAPER_BRIGHT)
    drawText(ctx, "价格随行情实时波动 · 出售后无法撤回", 678, 718, 11, MUTED)
end

local function drawMerchantPage(ctx, data)
    local stock = data.merchantStock or {}
    BlackMarketUI.merchantRects = {}
    drawText(ctx, "私人收购频道", 30, 181, 18, PAPER_BRIGHT)
    drawImageContained(ctx, (data.art or {}).broker, 30, 214, 220, 222, 2)
    drawText(ctx, "代号：渡鸦", 31, 462, 20, PAPER_BRIGHT)
    drawText(ctx, "黑市情报掮客", 31, 490, 11, ACCENT_BRIGHT)
    drawTextBox(ctx, "“公开市场处理普通货物。真正稀缺的东西，带来给我。”",
        31, 520, 215, 12, PAPER)
    drawLine(ctx, 31, 583, 247, 583, ACCENT, 75)
    drawText(ctx, "加密线路", 31, 606, 11, MUTED)
    drawText(ctx, "稳定", 247, 606, 12, GREEN,
        NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)

    drawText(ctx, "高价收购清单", 276, 181, 18, PAPER_BRIGHT)
    local startX, startY, gap = 276, 213, 10
    local cardW, cardH = 181, 216
    for index, product in ipairs(stock) do
        if index <= 6 then
            local col = (index - 1) % 3
            local row = math.floor((index - 1) / 3)
            local rect = {
                x = startX + col * (cardW + gap),
                y = startY + row * (cardH + gap),
                w = cardW,
                h = cardH,
            }
            BlackMarketUI.merchantRects[product.id] = rect
            local id = "merchant:" .. product.id
            local selected = BlackMarketUI.selectedMerchantId == product.id
            local hot = BlackMarketUI.hovered == id or BlackMarketUI.pressed == id
            fillRect(ctx, rect.x, rect.y, rect.w, rect.h,
                selected and { 49, 41, 25 } or (hot and { 27, 30, 24 } or { 17, 20, 16 }), 246)
            strokeRect(ctx, rect.x, rect.y, rect.w, rect.h,
                selected and ACCENT_BRIGHT or ACCENT, selected and 235 or 100,
                selected and 2 or 1)
            drawItemArt(ctx, (data.itemIcons or {})[product.item],
                rect.x + 9, rect.y + 9, rect.w - 18, 116)
            drawText(ctx, product.name or product.item, rect.x + 10,
                rect.y + 144, 12, PAPER_BRIGHT)
            drawText(ctx, Currency.FormatNumber(product.price), rect.x + 10,
                rect.y + 172, 14, ACCENT_BRIGHT)
            local owned = data.countWarehouseItem
                and data.countWarehouseItem(product.item) or 0
            drawText(ctx, "持有 " .. tostring(owned), rect.x + 10,
                rect.y + 199, 10, owned > 0 and GREEN or MUTED)
            drawText(ctx, "还需 " .. tostring(product.stock or 0),
                rect.x + rect.w - 10, rect.y + 199, 10, MUTED,
                NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        end
    end

    drawText(ctx, "交货结算", 892, 181, 18, PAPER_BRIGHT)
    local selected = findById(stock, BlackMarketUI.selectedMerchantId)
    BlackMarketUI.primaryRect = nil
    if selected then
        BlackMarketUI.selectedMerchantId = selected.id
        drawItemArt(ctx, (data.itemIcons or {})[selected.item],
            928, 213, 355, 220)
        drawText(ctx, selected.name or selected.item, 892, 463, 21, PAPER_BRIGHT)
        drawText(ctx, selected.tag or "特殊渠道", 892, 490, 11, ACCENT_BRIGHT)
        drawTextBox(ctx, selected.description or "渡鸦正在高价回收这种物资。",
            892, 515, 425, 11, PAPER)
        local owned = data.countWarehouseItem
            and data.countWarehouseItem(selected.item) or 0
        drawLine(ctx, 892, 577, 1319, 577, ACCENT, 80)
        drawText(ctx, "仓库持有", 892, 600, 11, MUTED)
        drawText(ctx, tostring(owned) .. " 件", 1319, 600, 13,
            owned > 0 and GREEN or PAPER,
            NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        drawText(ctx, "渡鸦单件报价", 892, 628, 11, MUTED)
        drawImageContained(ctx, data.currencyIcon, 1104, 615, 28, 28, 0)
        drawText(ctx, Currency.FormatNumber(selected.price), 1319, 628,
            20, ACCENT_BRIGHT, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        local canSell = owned > 0 and (selected.stock or 0) > 0
        BlackMarketUI.primaryRect = { x = 996, y = 690, w = 334, h = 56 }
        drawButton(ctx, "primary", BlackMarketUI.primaryRect,
            canSell and "出售 1 件给渡鸦"
                or ((selected.stock or 0) <= 0 and "收购需求已满足" or "仓库暂无该物资"),
            canSell, true)
    else
        drawText(ctx, "选择一项收购需求", 1105, 410, 15, MUTED,
            NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    end
    drawText(ctx, "每次成功交货可获得 2 点黑市声望", 35, 718, 11, MUTED)
    drawText(ctx, "高价收购 · 数量有限 · 即时结算", 540, 718, 12, PAPER)
end

local function auctionStatusText(auction)
    if auction.status == "won" then return "已竞得" end
    if auction.status == "lost" then return "已结束" end
    if auction.status ~= "open" then return "已关闭" end
    if auction.leader == "player" then return "你是最高出价者" end
    return "竞拍中"
end

local function drawAuctionPage(ctx, data)
    local auctions = data.auctions or {}
    BlackMarketUI.auctionRects = {}
    drawText(ctx, "地下拍卖目录", 30, 181, 18, PAPER_BRIGHT)
    drawText(ctx, "所有拍品将在倒计时结束后自动结算", 198, 182, 10, MUTED)
    local startX, startY, gap = 26, 212, 10
    local cardW, cardH = 258, 214
    for index, auction in ipairs(auctions) do
        if index <= 6 then
            local col = (index - 1) % 3
            local row = math.floor((index - 1) / 3)
            local rect = {
                x = startX + col * (cardW + gap),
                y = startY + row * (cardH + gap),
                w = cardW,
                h = cardH,
            }
            BlackMarketUI.auctionRects[auction.id] = rect
            local id = "auction:" .. auction.id
            local selected = BlackMarketUI.selectedAuctionId == auction.id
            local hot = BlackMarketUI.hovered == id or BlackMarketUI.pressed == id
            fillRect(ctx, rect.x, rect.y, rect.w, rect.h,
                selected and { 49, 41, 25 } or (hot and { 28, 30, 24 } or { 17, 20, 16 }), 246)
            strokeRect(ctx, rect.x, rect.y, rect.w, rect.h,
                selected and ACCENT_BRIGHT or ACCENT, selected and 235 or 100,
                selected and 2 or 1)
            drawItemArt(ctx, (data.itemIcons or {})[auction.item],
                rect.x + 8, rect.y + 8, 104, 112)
            drawText(ctx, auction.item, rect.x + 122, rect.y + 30,
                13, PAPER_BRIGHT)
            drawText(ctx, auction.seller or "匿名卖家", rect.x + 122,
                rect.y + 55, 10, MUTED)
            drawText(ctx, "当前价", rect.x + 122, rect.y + 82, 9, MUTED)
            drawText(ctx, Currency.FormatNumber(auction.currentBid),
                rect.x + 122, rect.y + 106, 15, ACCENT_BRIGHT)
            drawLine(ctx, rect.x + 9, rect.y + 132,
                rect.x + rect.w - 9, rect.y + 132, ACCENT, 65)
            drawText(ctx, auctionStatusText(auction), rect.x + 10,
                rect.y + 156, 10,
                auction.leader == "player" and GREEN or PAPER)
            drawText(ctx, formatCountdown(auction.remaining),
                rect.x + rect.w - 10, rect.y + 156, 12,
                (auction.remaining or 0) < 60 and { 160, 67, 50 } or PAPER,
                NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
            drawText(ctx, "最低加价 " .. Currency.FormatNumber(auction.minIncrement),
                rect.x + 10, rect.y + 193, 10, MUTED)
        end
    end

    drawText(ctx, "竞拍详情", 892, 181, 18, PAPER_BRIGHT)
    local selected = findById(auctions, BlackMarketUI.selectedAuctionId)
    BlackMarketUI.primaryRect = nil
    if selected then
        BlackMarketUI.selectedAuctionId = selected.id
        drawItemArt(ctx, (data.itemIcons or {})[selected.item],
            925, 212, 365, 219)
        drawText(ctx, selected.item, 892, 462, 22, PAPER_BRIGHT)
        drawText(ctx, "卖家：" .. tostring(selected.seller or "匿名卖家"),
            892, 491, 11, MUTED)
        drawLine(ctx, 892, 515, 1319, 515, ACCENT, 80)
        drawText(ctx, "当前最高价", 892, 542, 11, MUTED)
        drawImageContained(ctx, data.currencyIcon, 1098, 528, 30, 30, 0)
        drawText(ctx, Currency.FormatNumber(selected.currentBid), 1319, 542,
            22, ACCENT_BRIGHT, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        drawText(ctx, "下一次出价", 892, 579, 11, MUTED)
        local nextBid = (tonumber(selected.currentBid) or 0)
            + (tonumber(selected.minIncrement) or 0)
        drawText(ctx, Currency.Format(nextBid), 1319, 579, 15, PAPER,
            NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        drawText(ctx, "剩余时间", 892, 614, 11, MUTED)
        drawText(ctx, formatCountdown(selected.remaining), 1319, 614, 17,
            (selected.remaining or 0) < 60 and { 168, 70, 52 } or PAPER,
            NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        local open = selected.status == "open" and (selected.remaining or 0) > 0
        local required = selected.leader == "player"
            and (selected.minIncrement or 0) or nextBid
        local canBid = open and (tonumber(data.bits) or 0) >= required
        BlackMarketUI.primaryRect = { x = 996, y = 690, w = 334, h = 56 }
        local label
        if not open then
            label = selected.status == "won" and "拍品已进入仓库" or "竞拍已经结束"
        elseif not canBid then
            label = "比特不足"
        elseif selected.leader == "player" then
            label = "继续加价"
        else
            label = "出价 " .. Currency.FormatNumber(nextBid)
        end
        drawButton(ctx, "primary", BlackMarketUI.primaryRect, label, canBid, true)
    else
        drawText(ctx, "选择一件拍品查看竞价详情", 1105, 410, 15, MUTED,
            NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    end
    drawText(ctx, "出价将立即冻结对应比特 · 被超价后自动退回", 35, 718, 11, MUTED)
    drawText(ctx, "竞拍结束后，获胜拍品自动送入一号仓库", 518, 718, 12, PAPER)
end

local function drawNotice(ctx)
    if BlackMarketUI.noticeTimer <= 0 or BlackMarketUI.notice == "" then return end
    local x, y, w, h = 432, 646, 500, 44
    fillRect(ctx, x, y, w, h,
        BlackMarketUI.noticeSuccess and { 27, 43, 31 } or { 56, 29, 24 }, 248)
    strokeRect(ctx, x, y, w, h,
        BlackMarketUI.noticeSuccess and GREEN or RED, 230, 1.5)
    drawText(ctx, BlackMarketUI.notice, x + w * 0.5, y + h * 0.5,
        12, PAPER_BRIGHT, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
end

function BlackMarketUI.Open()
    BlackMarketUI.activeTab = "shop"
    BlackMarketUI.hovered = nil
    BlackMarketUI.pressed = nil
    BlackMarketUI.selectedCategory = "all"
    BlackMarketUI.selectedMerchantId = nil
    BlackMarketUI.selectedAuctionId = nil
    BlackMarketUI.sellSelection = {}
    BlackMarketUI.scrollOffset = 0
    BlackMarketUI.scrollKind = nil
    BlackMarketUI.notice = ""
    BlackMarketUI.noticeTimer = 0
    BlackMarketUI.touchId = nil
    BlackMarketUI.touchScrolling = false
    BlackMarketUI.ignoreMouseTimer = 0
    print("[BlackMarket] 三页签交易终端已打开")
end

function BlackMarketUI.Update(dt)
    local elapsed = math.max(0, tonumber(dt) or 0)
    BlackMarketUI.animTime = BlackMarketUI.animTime + elapsed
    BlackMarketUI.ignoreMouseTimer = math.max(0,
        BlackMarketUI.ignoreMouseTimer - elapsed)
    BlackMarketUI.noticeTimer = math.max(0, BlackMarketUI.noticeTimer - elapsed)
end

function BlackMarketUI.SetNotice(message, success)
    BlackMarketUI.notice = tostring(message or "")
    BlackMarketUI.noticeSuccess = success == true
    BlackMarketUI.noticeTimer = 2.8
end

function BlackMarketUI.GetSellSelection()
    local result = {}
    for key in pairs(BlackMarketUI.sellSelection) do
        local tabIndex, itemIndex = key:match("^(%d+):(%d+)$")
        if tabIndex and itemIndex then
            result[#result + 1] = {
                tabIndex = tonumber(tabIndex),
                itemIndex = tonumber(itemIndex),
            }
        end
    end
    return result
end

function BlackMarketUI.ClearSellSelection()
    BlackMarketUI.sellSelection = {}
end

function BlackMarketUI.ScrollAt(x, y, delta)
    local dx, dy = toDesignPoint(x, y)
    if BlackMarketUI.activeTab ~= "shop"
        or not pointInRect(dx, dy, BlackMarketUI.listViewport) then
        return false
    end
    local amount = (tonumber(delta) or 0)
        / math.max(BlackMarketUI.layoutScale, 0.01)
    BlackMarketUI.scrollOffset = clamp(
        BlackMarketUI.scrollOffset + amount, 0, BlackMarketUI.scrollMax)
    return true
end

function BlackMarketUI.GetHit(x, y)
    local dx, dy = toDesignPoint(x, y)
    if pointInRect(dx, dy, BlackMarketUI.backRect) then return "back" end
    for _, tab in ipairs(TABS) do
        if pointInRect(dx, dy, BlackMarketUI.tabRects[tab.id]) then
            return "tab:" .. tab.id
        end
    end
    if pointInRect(dx, dy, BlackMarketUI.primaryRect) then return "primary" end
    if pointInRect(dx, dy, BlackMarketUI.secondaryRect) then return "secondary" end
    if BlackMarketUI.activeTab == "shop" then
        for _, category in ipairs(CATEGORIES) do
            if pointInRect(dx, dy, BlackMarketUI.categoryRects[category.id]) then
                return "category:" .. category.id
            end
        end
        if pointInRect(dx, dy, BlackMarketUI.listViewport) then
            for key, rect in pairs(BlackMarketUI.itemRects) do
                if pointInRect(dx, dy, rect) then return "item:" .. key end
            end
        end
    elseif BlackMarketUI.activeTab == "merchant" then
        for id, rect in pairs(BlackMarketUI.merchantRects) do
            if pointInRect(dx, dy, rect) then return "merchant:" .. id end
        end
    elseif BlackMarketUI.activeTab == "auction" then
        for id, rect in pairs(BlackMarketUI.auctionRects) do
            if pointInRect(dx, dy, rect) then return "auction:" .. id end
        end
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
    if action == "back" then return "back" end
    local tabId = action:match("^tab:(.+)$")
    if tabId then
        BlackMarketUI.activeTab = tabId
        BlackMarketUI.scrollOffset = 0
        BlackMarketUI.hovered = nil
        return "tab"
    end
    local categoryId = action:match("^category:(.+)$")
    if categoryId then
        BlackMarketUI.selectedCategory = categoryId
        BlackMarketUI.scrollOffset = 0
        return "category"
    end
    local itemKey = action:match("^item:(.+)$")
    if itemKey then
        BlackMarketUI.sellSelection[itemKey]
            = not BlackMarketUI.sellSelection[itemKey] or nil
        return "selection"
    end
    local merchantId = action:match("^merchant:(.+)$")
    if merchantId then
        BlackMarketUI.selectedMerchantId = merchantId
        return "select"
    end
    local auctionId = action:match("^auction:(.+)$")
    if auctionId then
        BlackMarketUI.selectedAuctionId = auctionId
        return "select"
    end
    if action == "primary" then
        if BlackMarketUI.activeTab == "shop" then
            return "sell-select-all"
        elseif BlackMarketUI.activeTab == "merchant"
            and BlackMarketUI.selectedMerchantId then
            return "merchant-sell:" .. BlackMarketUI.selectedMerchantId
        elseif BlackMarketUI.activeTab == "auction"
            and BlackMarketUI.selectedAuctionId then
            return "auction-bid:" .. BlackMarketUI.selectedAuctionId
        end
    elseif action == "secondary" and BlackMarketUI.activeTab == "shop" then
        return "sell-confirm"
    end
    return nil
end

function BlackMarketUI.SelectAllVisible(data)
    local items = buildSellItems(data or {})
    local allSelected = #items > 0
    for _, item in ipairs(items) do
        if not BlackMarketUI.sellSelection[item.key] then
            allSelected = false
            break
        end
    end
    for _, item in ipairs(items) do
        BlackMarketUI.sellSelection[item.key] = not allSelected or nil
    end
end

function BlackMarketUI.TouchBegin(touchId, x, y)
    if BlackMarketUI.touchId ~= nil then return false end
    BlackMarketUI.touchId = touchId
    BlackMarketUI.ignoreMouseTimer = 0.5
    BlackMarketUI.touchStartX, BlackMarketUI.touchStartY = toDesignPoint(x, y)
    BlackMarketUI.scrollKind = nil
    if BlackMarketUI.activeTab == "shop"
        and pointInRect(BlackMarketUI.touchStartX,
            BlackMarketUI.touchStartY, BlackMarketUI.listViewport) then
        BlackMarketUI.scrollKind = "shop"
        BlackMarketUI.touchScrollStart = BlackMarketUI.scrollOffset
    end
    BlackMarketUI.touchScrolling = false
    BlackMarketUI.PointerDown(x, y)
    return true
end

function BlackMarketUI.TouchMove(touchId, x, y)
    if BlackMarketUI.touchId ~= touchId then return false end
    BlackMarketUI.ignoreMouseTimer = 0.5
    local dx, dy = toDesignPoint(x, y)
    local moveX = dx - BlackMarketUI.touchStartX
    local moveY = dy - BlackMarketUI.touchStartY
    if BlackMarketUI.scrollKind and moveX * moveX + moveY * moveY > 64 then
        BlackMarketUI.touchScrolling = true
        BlackMarketUI.pressed = nil
    end
    if BlackMarketUI.touchScrolling then
        BlackMarketUI.scrollOffset = clamp(
            BlackMarketUI.touchScrollStart - moveY, 0, BlackMarketUI.scrollMax)
    else
        BlackMarketUI.PointerMove(x, y)
    end
    return true
end

function BlackMarketUI.TouchEnd(touchId, x, y)
    if BlackMarketUI.touchId ~= touchId then return nil end
    BlackMarketUI.ignoreMouseTimer = 0.5
    local action = nil
    if BlackMarketUI.touchScrolling then
        BlackMarketUI.pressed = nil
    else
        BlackMarketUI.PointerMove(x, y)
        action = BlackMarketUI.PointerUp(x, y)
    end
    BlackMarketUI.touchId = nil
    BlackMarketUI.touchScrolling = false
    BlackMarketUI.scrollKind = nil
    return action
end

function BlackMarketUI.ShouldIgnoreMouse()
    return BlackMarketUI.touchId ~= nil or BlackMarketUI.ignoreMouseTimer > 0
end

function BlackMarketUI.Draw(ctx, width, height, data)
    data = data or {}
    local scale = math.min(width / DESIGN_W, height / DESIGN_H)
    BlackMarketUI.layoutScale = math.max(scale, 0.001)
    BlackMarketUI.layoutOffsetX = (width / BlackMarketUI.layoutScale - DESIGN_W) * 0.5
    BlackMarketUI.layoutOffsetY = (height / BlackMarketUI.layoutScale - DESIGN_H) * 0.5
    BlackMarketUI.tabRects = {}
    BlackMarketUI.itemRects = {}
    BlackMarketUI.merchantRects = {}
    BlackMarketUI.auctionRects = {}
    BlackMarketUI.categoryRects = {}
    BlackMarketUI.primaryRect = nil
    BlackMarketUI.secondaryRect = nil
    BlackMarketUI.listViewport = nil
    BlackMarketUI.scrollMax = 0

    fillRect(ctx, 0, 0, width, height, { 4, 6, 4 }, 255)
    nvgSave(ctx)
    nvgScale(ctx, BlackMarketUI.layoutScale, BlackMarketUI.layoutScale)
    nvgTranslate(ctx, BlackMarketUI.layoutOffsetX, BlackMarketUI.layoutOffsetY)
    drawFrame(ctx, data)
    drawHeader(ctx, data)
    drawTabs(ctx)
    if BlackMarketUI.activeTab == "shop" then
        drawShopPage(ctx, data)
    elseif BlackMarketUI.activeTab == "merchant" then
        drawMerchantPage(ctx, data)
    else
        drawAuctionPage(ctx, data)
    end
    drawNotice(ctx)
    nvgRestore(ctx)
end

return BlackMarketUI
