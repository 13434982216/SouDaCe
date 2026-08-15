local Currency = require "Currency"

local CodexUI = {
    active = false,
    scrollY = 0,
    scrollMax = 0,
    viewport = nil,
    categoryRects = {},
    selectedRarity = "red",
    cardRects = {},
    backRect = nil,
    selectedItem = nil,
    detailCloseRect = nil,
    hovered = nil,
    pressed = nil,
    touchId = nil,
    touchStartY = 0,
    touchLastY = 0,
    touchScrollStart = 0,
    touchScrolling = false,
    ignoreMouseTimer = 0,
    animTime = 0,
}

-- 稀有度从高到低
local RARITY_ORDER = { "red", "pink", "gold", "purple", "blue", "green" }

local RARITY_COLORS = {
    red    = {210, 50, 50},
    pink   = {215, 75, 155},
    gold   = {225, 170, 45},
    purple = {145, 65, 205},
    blue   = {55, 115, 215},
    green  = {55, 165, 75},
}

local RARITY_LABELS = {
    red = "传说", pink = "史诗", gold = "金色收藏",
    purple = "稀有", blue = "精良", green = "普通",
}

local RARITY_SUB = {
    red = "LEGENDARY", pink = "EPIC", gold = "GOLD",
    purple = "RARE", blue = "FINE", green = "COMMON",
}

-- 排除武器装备
local EXCLUDED_ITEMS = {
    ["手枪"] = true, ["散弹枪"] = true, ["棒球棍"] = true,
    ["二级头盔"] = true, ["二级防弹衣"] = true,
    ["二级胸挂"] = true, ["二级背包"] = true,
    ["二级安全箱"] = true, ["三级安全箱"] = true,
}

local function rgba(color, alpha)
    return nvgRGBA(color[1], color[2], color[3], alpha or 255)
end

local function clamp(v, lo, hi)
    return math.max(lo, math.min(hi, v))
end

local function pointInRect(x, y, r)
    return r and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

local function beginCutRect(ctx, x, y, w, h, cut)
    local c = math.min(cut or 8, w * 0.2, h * 0.35)
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, x + c, y)
    nvgLineTo(ctx, x + w, y)
    nvgLineTo(ctx, x + w, y + h - c)
    nvgLineTo(ctx, x + w - c, y + h)
    nvgLineTo(ctx, x, y + h)
    nvgLineTo(ctx, x, y + c)
    nvgClosePath(ctx)
end

local function formatValue(v)
    if v == nil then return "---" end
    return Currency.FormatNumber(v)
end

local function getItemImageAspect(itemName)
    if itemName == "香槟酒" then return 256 / 512 end
    if itemName == "红酒82年" then return 83 / 244 end
    return 1.0
end

-- 构建分区数据：从 itemValues 取所有物资，排除武器装备，按稀有度分组
local function buildSections(itemValues, itemRarity)
    local groups = {}
    for _, r in ipairs(RARITY_ORDER) do groups[r] = {} end

    for name in pairs(itemValues) do
        if not EXCLUDED_ITEMS[name] then
            local rarity = (itemRarity and itemRarity[name]) or "green"
            if not groups[rarity] then groups[rarity] = {} end
            table.insert(groups[rarity], { name = name, rarity = rarity })
        end
    end

    local sections = {}
    for _, rarity in ipairs(RARITY_ORDER) do
        local items = groups[rarity]
        if #items > 0 then
            table.sort(items, function(a, b)
                local va = (itemValues[a.name] and itemValues[a.name].value) or 0
                local vb = (itemValues[b.name] and itemValues[b.name].value) or 0
                if va ~= vb then return va > vb end
                return a.name < b.name
            end)
            table.insert(sections, { rarity = rarity, items = items })
        end
    end
    return sections
end

-- 背景
local function drawBackground(ctx, w, h)
    local bg = nvgLinearGradient(ctx, 0, 0, w, h,
        nvgRGBA(16, 20, 24, 255), nvgRGBA(7, 9, 12, 255))
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, w, h)
    nvgFillPaint(ctx, bg)
    nvgFill(ctx)

    local glow = nvgRadialGradient(ctx, w * 0.5, -h * 0.05, 10, w * 0.6,
        nvgRGBA(90, 65, 25, 30), nvgRGBA(10, 12, 15, 0))
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, w, h)
    nvgFillPaint(ctx, glow)
    nvgFill(ctx)
end

-- 顶栏
local function drawHeader(ctx, w, h, totalCount)
    local headerH = clamp(h * 0.105, 64, 88)
    local grad = nvgLinearGradient(ctx, 0, 0, 0, headerH,
        nvgRGBA(9, 11, 14, 250), nvgRGBA(16, 19, 22, 210))
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, w, headerH)
    nvgFillPaint(ctx, grad)
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, headerH - 1, w, 1)
    nvgFillColor(ctx, nvgRGBA(151, 113, 48, 140))
    nvgFill(ctx)

    nvgFontFace(ctx, "sans")
    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFontSize(ctx, clamp(w * 0.042, 20, 29))
    nvgFillColor(ctx, nvgRGBA(235, 212, 160, 255))
    nvgText(ctx, 58, headerH * 0.32, "物资图鉴")
    nvgFontSize(ctx, clamp(w * 0.013, 7, 10))
    nvgFillColor(ctx, nvgRGBA(130, 138, 142, 220))
    nvgText(ctx, 60, headerH * 0.72, "MATERIAL CODEX  /  " .. tostring(totalCount) .. " ITEMS")

    return headerH
end

-- 返回按钮
local function drawBackButton(ctx)
    local r = { x = 10, y = 10, w = 38, h = 38 }
    CodexUI.backRect = r
    local active = CodexUI.hovered == "back" or CodexUI.pressed == "back"
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, r.x, r.y, r.w, r.h, 7)
    nvgFillColor(ctx, active and nvgRGBA(55, 60, 68, 240) or nvgRGBA(28, 32, 38, 220))
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, r.x, r.y, r.w, r.h, 7)
    nvgStrokeColor(ctx, nvgRGBA(90, 98, 105, 160))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)
    local cx = r.x + r.w * 0.5
    local cy = r.y + r.h * 0.5
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, cx + 6, cy - 8)
    nvgLineTo(ctx, cx - 5, cy)
    nvgLineTo(ctx, cx + 6, cy + 8)
    nvgStrokeColor(ctx, nvgRGBA(210, 205, 190, 230))
    nvgStrokeWidth(ctx, 2.2)
    nvgLineCap(ctx, NVG_ROUND)
    nvgLineJoin(ctx, NVG_ROUND)
    nvgStroke(ctx)
end

-- 分区标题（带品质色条和分隔线）
local function drawSectionHeader(ctx, x, y, w, section)
    local rc = RARITY_COLORS[section.rarity]
    local label = RARITY_LABELS[section.rarity]
    local sub = RARITY_SUB[section.rarity]
    local headerH = 36
    local gap = 10

    -- 左侧粗色条
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x, y, 4, headerH, 2)
    nvgFillColor(ctx, rgba(rc, 255))
    nvgFill(ctx)

    -- 标签背景
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x + 10, y, w - 10, headerH, 4)
    nvgFillColor(ctx, nvgRGBA(rc[1], rc[2], rc[3], 22))
    nvgFill(ctx)

    -- 品质名称
    nvgFontFace(ctx, "sans")
    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFontSize(ctx, 16)
    nvgFillColor(ctx, rgba(rc, 255))
    nvgText(ctx, x + 20, y + headerH * 0.42, label)

    -- 英文副标
    nvgFontSize(ctx, 9)
    local labelW = nvgTextBounds(ctx, 0, 0, label) or 0
    nvgFillColor(ctx, nvgRGBA(150, 155, 158, 180))
    nvgText(ctx, x + 20 + labelW + 8, y + headerH * 0.42, sub)

    -- 分隔虚线
    local dashX = x + 20 + labelW + 8 + (nvgTextBounds(ctx, 0, 0, sub) or 0) + 12
    local dashY = y + headerH * 0.5
    nvgStrokeColor(ctx, nvgRGBA(rc[1], rc[2], rc[3], 50))
    nvgStrokeWidth(ctx, 1)
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, dashX, dashY)
    nvgLineTo(ctx, x + w - 50, dashY)
    nvgStroke(ctx)

    -- 物品数量
    nvgTextAlign(ctx, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFontSize(ctx, 13)
    nvgFillColor(ctx, rgba(rc, 200))
    nvgText(ctx, x + w - 14, y + headerH * 0.42, tostring(#section.items) .. " 种")

    return headerH + gap
end

local function drawCategorySidebar(ctx, x, y, w, h, sections)
    CodexUI.categoryRects = {}
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x, y, w, h, 8)
    nvgFillColor(ctx, nvgRGBA(12, 15, 19, 235))
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x, y, w, h, 8)
    nvgStrokeColor(ctx, nvgRGBA(68, 74, 80, 150))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)

    nvgFontFace(ctx, "sans")
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(ctx, 11)
    nvgFillColor(ctx, nvgRGBA(150, 155, 158, 220))
    nvgText(ctx, x + w * 0.5, y + 18, "分类")

    local top = y + 30
    local gap = 5
    -- 分类按钮严格按侧栏可用高度等分，低高度屏幕不再溢出。
    local availableH = math.max(1, h - 36 - gap * math.max(0, #sections - 1))
    local itemH = availableH / math.max(1, #sections)
    for index, section in ipairs(sections) do
        local rarity = section.rarity
        local rc = RARITY_COLORS[rarity]
        local cy = top + (index - 1) * (itemH + gap)
        local rect = { x = x + 5, y = cy, w = w - 10, h = itemH }
        CodexUI.categoryRects[rarity] = rect
        local active = CodexUI.selectedRarity == rarity
        local hovered = CodexUI.hovered == "category_" .. rarity
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, rect.x, rect.y, rect.w, rect.h, 6)
        nvgFillColor(ctx, active and nvgRGBA(rc[1], rc[2], rc[3], 55)
            or hovered and nvgRGBA(48, 53, 59, 235)
            or nvgRGBA(25, 29, 34, 220))
        nvgFill(ctx)
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, rect.x, rect.y, rect.w, rect.h, 6)
        nvgStrokeColor(ctx, active and rgba(rc, 220) or nvgRGBA(70, 76, 82, 110))
        nvgStrokeWidth(ctx, active and 1.4 or 0.8)
        nvgStroke(ctx)
        local barInset = math.min(7, math.max(2, rect.h * 0.22))
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, rect.x + 5, rect.y + barInset, 3, math.max(2, rect.h - barInset * 2), 1.5)
        nvgFillColor(ctx, rgba(rc, 255))
        nvgFill(ctx)
        nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFontSize(ctx, itemH < 40 and 10 or 13)
        nvgFillColor(ctx, active and rgba(rc, 255) or nvgRGBA(190, 194, 195, 235))
        nvgText(ctx, rect.x + 14, rect.y + itemH * 0.5, RARITY_LABELS[rarity])
        if itemH >= 42 then
            nvgFontSize(ctx, 9)
            nvgFillColor(ctx, nvgRGBA(135, 142, 145, 200))
            nvgText(ctx, rect.x + 14, rect.y + rect.h * 0.76, tostring(#section.items) .. " 种物资")
        end
    end
end

-- 单个物品大图卡片
local function drawItemCard(ctx, x, y, w, h, item, iconId, itemValues)
    local rc = RARITY_COLORS[item.rarity]
    local hovered = CodexUI.hovered == "card_" .. item.name
    local selected = CodexUI.selectedItem == item.name

    -- 外发光（选中时）
    if selected then
        local glow = nvgBoxGradient(ctx, x - 4, y - 4, w + 8, h + 8, 8, 12,
            rgba(rc, 50), nvgRGBA(0, 0, 0, 0))
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, x - 4, y - 4, w + 8, h + 8, 10)
        nvgFillPaint(ctx, glow)
        nvgFill(ctx)
    end

    -- 卡片主体
    beginCutRect(ctx, x, y, w, h, 7)
    local bgGrad = nvgLinearGradient(ctx, x, y, x, y + h,
        selected and nvgRGBA(32, 34, 38, 250)
        or hovered and nvgRGBA(28, 31, 35, 242)
        or nvgRGBA(20, 23, 27, 225),
        nvgRGBA(12, 14, 17, 240))
    nvgFillPaint(ctx, bgGrad)
    nvgFill(ctx)

    -- 顶部品质色条
    nvgBeginPath(ctx)
    nvgRect(ctx, x + 6, y + 4, w - 12, 2)
    nvgFillColor(ctx, rgba(rc, selected and 255 or 180))
    nvgFill(ctx)

    -- 边框
    beginCutRect(ctx, x, y, w, h, 7)
    nvgStrokeColor(ctx, selected and rgba(rc, 180)
        or hovered and rgba(rc, 90)
        or nvgRGBA(50, 55, 60, 90))
    nvgStrokeWidth(ctx, selected and 1.8 or (hovered and 1.2 or 0.7))
    nvgStroke(ctx)

    -- 物品图片（大，居中）
    local imgAreaH = h * 0.62
    local imgPad = 8
    if iconId and iconId > 0 then
        local maxImgW = w - imgPad * 2
        local maxImgH = imgAreaH - imgPad
        local aspect = getItemImageAspect(item.name)
        local drawW = maxImgW
        local drawH = drawW / aspect
        if drawH > maxImgH then
            drawH = maxImgH
            drawW = drawH * aspect
        end
        local ix = x + (w - drawW) * 0.5
        local iy = y + (imgAreaH - drawH) * 0.5 + 4

        local paint = nvgImagePattern(ctx, ix, iy, drawW, drawH, 0, iconId, 1.0)
        nvgBeginPath(ctx)
        nvgRect(ctx, ix, iy, drawW, drawH)
        nvgFillPaint(ctx, paint)
        nvgFill(ctx)

        -- 图片底部微光
        local imgGlow = nvgRadialGradient(ctx,
            ix + drawW * 0.5, iy + drawH, 4, drawW * 0.7,
            rgba(rc, 22), nvgRGBA(0, 0, 0, 0))
        nvgBeginPath(ctx)
        nvgRect(ctx, ix - 10, iy + drawH - 20, drawW + 20, 30)
        nvgFillPaint(ctx, imgGlow)
        nvgFill(ctx)
    else
        -- 无图标占位
        local pSize = math.min(w - 24, imgAreaH - 16)
        local px = x + (w - pSize) * 0.5
        local py = y + (imgAreaH - pSize) * 0.5 + 4
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, px, py, pSize, pSize, 6)
        nvgFillColor(ctx, nvgRGBA(35, 38, 43, 180))
        nvgFill(ctx)
        nvgFontFace(ctx, "sans")
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFontSize(ctx, 24)
        nvgFillColor(ctx, nvgRGBA(90, 95, 100, 160))
        nvgText(ctx, px + pSize * 0.5, py + pSize * 0.5, "?")
    end

    -- 分割线
    local sepY = y + imgAreaH + 2
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, x + 10, sepY)
    nvgLineTo(ctx, x + w - 10, sepY)
    nvgStrokeColor(ctx, nvgRGBA(255, 255, 255, 12))
    nvgStrokeWidth(ctx, 0.5)
    nvgStroke(ctx)

    -- 物品名称
    local nameY = sepY + 6
    nvgFontFace(ctx, "sans")
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFontSize(ctx, clamp(w * 0.11, 9, 13))
    nvgFillColor(ctx, nvgRGBA(228, 225, 215, 245))
    nvgTextBox(ctx, x + 6, nameY, w - 12, item.name)

    -- 价值
    local val = itemValues and itemValues[item.name]
    local valText = val and formatValue(val.value) or "---"
    nvgFontSize(ctx, clamp(w * 0.095, 8, 11))
    nvgFillColor(ctx, rgba(rc, 225))
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgText(ctx, x + w * 0.5, y + h - 16, valText)
end

-- 详情弹窗（大图 + 信息）
local function drawDetailPanel(ctx, w, h, item, iconId, itemValues, itemSizes)
    if not item then return end
    local val = itemValues and itemValues[item.name]
    local size = itemSizes and itemSizes[item.name] or {1, 1}
    local rc = RARITY_COLORS[item.rarity]

    -- 遮罩
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, w, h)
    nvgFillColor(ctx, nvgRGBA(0, 0, 0, 180))
    nvgFill(ctx)

    local pw = math.min(w * 0.88, 400)
    local ph = math.min(h * 0.86, 500)
    local px = (w - pw) * 0.5
    local py = (h - ph) * 0.5

    -- 外发光
    local glow = nvgBoxGradient(ctx, px - 6, py - 6, pw + 12, ph + 12, 12, 20,
        rgba(rc, 35), nvgRGBA(0, 0, 0, 0))
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, px - 6, py - 6, pw + 12, ph + 12, 14)
    nvgFillPaint(ctx, glow)
    nvgFill(ctx)

    -- 面板
    beginCutRect(ctx, px, py, pw, ph, 12)
    local panelGrad = nvgLinearGradient(ctx, px, py, px, py + ph,
        nvgRGBA(26, 29, 34, 252), nvgRGBA(12, 15, 19, 252))
    nvgFillPaint(ctx, panelGrad)
    nvgFill(ctx)
    beginCutRect(ctx, px, py, pw, ph, 12)
    nvgStrokeColor(ctx, rgba(rc, 160))
    nvgStrokeWidth(ctx, 1.5)
    nvgStroke(ctx)

    -- 顶部色条
    nvgBeginPath(ctx)
    nvgRect(ctx, px + 2, py + 2, pw * 0.4, 3)
    nvgFillColor(ctx, rgba(rc, 250))
    nvgFill(ctx)

    -- 关闭按钮
    local closeSize = 32
    local closeX = px + pw - closeSize - 10
    local closeY = py + 10
    CodexUI.detailCloseRect = { x = closeX, y = closeY, w = closeSize, h = closeSize }
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, closeX, closeY, closeSize, closeSize, 6)
    nvgFillColor(ctx, nvgRGBA(48, 52, 58, 220))
    nvgFill(ctx)
    nvgFontFace(ctx, "sans")
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(ctx, 18)
    nvgFillColor(ctx, nvgRGBA(190, 185, 175, 230))
    nvgText(ctx, closeX + closeSize * 0.5, closeY + closeSize * 0.5, "X")

    -- 大图区限制高度，为名称、标签和描述保留明确的下半区。
    local maxImgW = math.min(pw * 0.42, 150)
    local maxImgH = math.min(ph * 0.28, 128)
    local aspect = getItemImageAspect(item.name)
    local imgW = maxImgW
    local imgH = imgW / aspect
    if imgH > maxImgH then
        imgH = maxImgH
        imgW = imgH * aspect
    end
    local imgX = px + (pw - imgW) * 0.5
    local imgY = py + 24

    if iconId and iconId > 0 then
        local paint = nvgImagePattern(ctx, imgX, imgY, imgW, imgH, 0, iconId, 1.0)
        nvgBeginPath(ctx)
        nvgRect(ctx, imgX, imgY, imgW, imgH)
        nvgFillPaint(ctx, paint)
        nvgFill(ctx)
    else
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, imgX, imgY, imgW, imgH, 8)
        nvgFillColor(ctx, nvgRGBA(35, 38, 44, 200))
        nvgFill(ctx)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFontSize(ctx, 40)
        nvgFillColor(ctx, nvgRGBA(80, 85, 90, 150))
        nvgText(ctx, imgX + imgW * 0.5, imgY + imgH * 0.5, "?")
    end

    -- 物品名
    local textY = imgY + imgH + 14
    nvgFontFace(ctx, "sans")
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFontSize(ctx, clamp(pw * 0.065, 20, 28))
    nvgFillColor(ctx, nvgRGBA(240, 235, 220, 255))
    nvgText(ctx, px + pw * 0.5, textY, item.name)

    -- 品质 + 价值
    textY = textY + 34
    local rarityLabel = RARITY_LABELS[item.rarity] or "普通"
    local barY = textY
    local barH = 26
    local barW = pw * 0.38
    -- 品质标签
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, px + pw * 0.5 - barW - 6, barY, barW, barH, 4)
    nvgFillColor(ctx, rgba(rc, 40))
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, px + pw * 0.5 - barW - 6, barY, barW, barH, 4)
    nvgStrokeColor(ctx, rgba(rc, 120))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)
    nvgFontSize(ctx, 13)
    nvgFillColor(ctx, rgba(rc, 240))
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgText(ctx, px + pw * 0.5 - barW * 0.5 - 6, barY + barH * 0.5, rarityLabel)

    -- 价值
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, px + pw * 0.5 + 6, barY, barW, barH, 4)
    nvgFillColor(ctx, nvgRGBA(30, 28, 22, 200))
    nvgFill(ctx)
    nvgFontSize(ctx, 13)
    nvgFillColor(ctx, nvgRGBA(220, 195, 130, 240))
    nvgText(ctx, px + pw * 0.5 + barW * 0.5 + 6, barY + barH * 0.5,
        Currency.Format(val and val.value or 0))

    -- 占用格子
    textY = textY + 36
    nvgFontSize(ctx, 11)
    nvgFillColor(ctx, nvgRGBA(145, 152, 156, 220))
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgText(ctx, px + pw * 0.5, textY, string.format("背包占用: %d × %d 格", size[1], size[2]))

    -- 描述
    textY = textY + 24
    nvgFontSize(ctx, 13)
    nvgFillColor(ctx, nvgRGBA(175, 180, 183, 235))
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    local desc = val and val.desc or "暂无描述信息。"
    nvgTextBox(ctx, px + 24, textY, pw - 48, desc)
end

local function drawDetailPanelFixed(ctx, w, h, item, iconId, itemValues, itemSizes)
    local val = itemValues[item.name] or {}
    local size = itemSizes[item.name] or { 1, 1 }
    local rc = RARITY_COLORS[item.rarity]

    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, w, h)
    nvgFillColor(ctx, nvgRGBA(0, 0, 0, 180))
    nvgFill(ctx)

    local pw = math.min(w * 0.90, 420)
    local ph = math.min(h * 0.88, 500)
    local px = (w - pw) * 0.5
    local py = (h - ph) * 0.5
    beginCutRect(ctx, px, py, pw, ph, 12)
    nvgFillColor(ctx, nvgRGBA(18, 22, 27, 252))
    nvgFill(ctx)
    beginCutRect(ctx, px, py, pw, ph, 12)
    nvgStrokeColor(ctx, rgba(rc, 180))
    nvgStrokeWidth(ctx, 1.5)
    nvgStroke(ctx)

    nvgBeginPath(ctx)
    nvgRect(ctx, px + 2, py + 2, pw * 0.4, 3)
    nvgFillColor(ctx, rgba(rc, 250))
    nvgFill(ctx)

    local closeSize = 30
    local closeX = px + pw - closeSize - 9
    local closeY = py + 9
    CodexUI.detailCloseRect = { x = closeX, y = closeY, w = closeSize, h = closeSize }
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, closeX, closeY, closeSize, closeSize, 6)
    nvgFillColor(ctx, nvgRGBA(48, 52, 58, 235))
    nvgFill(ctx)
    nvgFontFace(ctx, "sans")
    nvgFontSize(ctx, 17)
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(ctx, nvgRGBA(205, 200, 190, 240))
    nvgText(ctx, closeX + closeSize * 0.5, closeY + closeSize * 0.5, "X")

    -- 上半区固定为“左图、右信息”，不让图片影响文字的起始位置。
    local topY = py + 48
    local topH = math.max(100, math.min(150, ph * 0.36))
    local imageBoxW = math.min(pw * 0.34, 122)
    local imageBoxX = px + 18
    local imageBoxY = topY
    local aspect = getItemImageAspect(item.name)
    local imgW = imageBoxW
    local imgH = imgW / aspect
    if imgH > topH then
        imgH = topH
        imgW = imgH * aspect
    end
    local imgX = imageBoxX + (imageBoxW - imgW) * 0.5
    local imgY = imageBoxY + (topH - imgH) * 0.5
    if iconId and iconId > 0 then
        local paint = nvgImagePattern(ctx, imgX, imgY, imgW, imgH, 0, iconId, 1.0)
        nvgBeginPath(ctx)
        nvgRect(ctx, imgX, imgY, imgW, imgH)
        nvgFillPaint(ctx, paint)
        nvgFill(ctx)
    end

    local infoX = imageBoxX + imageBoxW + 16
    local infoW = px + pw - infoX - 18
    nvgFontFace(ctx, "sans")
    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFontSize(ctx, clamp(infoW * 0.10, 18, 25))
    nvgFillColor(ctx, nvgRGBA(240, 235, 220, 255))
    nvgTextBox(ctx, infoX, topY + 2, infoW, item.name)

    local rarityY = topY + 42
    nvgFontSize(ctx, 13)
    nvgFillColor(ctx, rgba(rc, 245))
    nvgText(ctx, infoX, rarityY, RARITY_LABELS[item.rarity] or "普通")
    nvgFontSize(ctx, 13)
    nvgFillColor(ctx, nvgRGBA(225, 195, 130, 245))
    nvgText(ctx, infoX, rarityY + 26, Currency.Format(val.value or 0))
    nvgFontSize(ctx, 11)
    nvgFillColor(ctx, nvgRGBA(145, 152, 156, 230))
    nvgText(ctx, infoX, rarityY + 52, string.format("背包占用: %d × %d 格", size[1], size[2]))

    -- 下半区为独立描述面板，文本永远不会和上方图片或信息相交。
    local descX = px + 18
    local descY = topY + topH + 16
    local descW = pw - 36
    local descH = py + ph - descY - 18
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, descX, descY, descW, descH, 7)
    nvgFillColor(ctx, nvgRGBA(10, 13, 17, 180))
    nvgFill(ctx)
    nvgFontSize(ctx, 11)
    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(ctx, nvgRGBA(125, 133, 138, 230))
    nvgText(ctx, descX + 12, descY + 10, "物资说明")
    nvgFontSize(ctx, 13)
    nvgFillColor(ctx, nvgRGBA(185, 190, 193, 240))
    nvgTextBox(ctx, descX + 12, descY + 31, descW - 24, val.desc or "暂无描述信息。")
end

local function drawSidebarCodex(ctx, w, h, itemIcons, itemValues, itemSizes, itemRarity)
    CodexUI.backRect = nil
    CodexUI.detailCloseRect = nil
    CodexUI.cardRects = {}

    drawBackground(ctx, w, h)
    local sections = buildSections(itemValues, itemRarity)
    local totalCount = 0
    local selectedSection = nil
    for _, section in ipairs(sections) do
        totalCount = totalCount + #section.items
        if section.rarity == CodexUI.selectedRarity then selectedSection = section end
    end
    if not selectedSection and sections[1] then
        selectedSection = sections[1]
        CodexUI.selectedRarity = selectedSection.rarity
    end

    local headerH = drawHeader(ctx, w, h, totalCount)
    drawBackButton(ctx)

    local pad = clamp(w * 0.025, 10, 20)
    local contentTop = headerH + 8
    local contentBottom = h - 10
    local contentH = math.max(1, contentBottom - contentTop)
    -- 窄屏优先保证右侧物品区，侧栏可缩至 76px。
    local sidebarW = clamp(w * 0.20, 76, 132)
    local gap = clamp(w * 0.015, 5, 12)
    local sidebarX = pad
    local contentX = sidebarX + sidebarW + gap
    local contentW = w - contentX - pad

    drawCategorySidebar(ctx, sidebarX, contentTop, sidebarW, contentH, sections)
    CodexUI.viewport = { x = contentX, y = contentTop, w = contentW, h = contentH }

    if selectedSection then
        local rc = RARITY_COLORS[selectedSection.rarity]
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, contentX, contentTop, contentW, contentH, 8)
        nvgFillColor(ctx, nvgRGBA(14, 17, 21, 230))
        nvgFill(ctx)
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, contentX, contentTop, contentW, contentH, 8)
        nvgStrokeColor(ctx, nvgRGBA(68, 74, 80, 140))
        nvgStrokeWidth(ctx, 1)
        nvgStroke(ctx)

        -- 两行标题使用固定的独立基线，避免大标题与副标题贴在一起。
        local titleH = 62
        local titleTextY = contentTop + 16
        local subtitleY = contentTop + 45
        nvgBeginPath(ctx)
        nvgRect(ctx, contentX + 1, contentTop + 1, 4, titleH - 2)
        nvgFillColor(ctx, rgba(rc, 255))
        nvgFill(ctx)
        nvgFontFace(ctx, "sans")
        nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        nvgFontSize(ctx, clamp(contentW * 0.06, 17, 24))
        nvgFillColor(ctx, rgba(rc, 255))
        nvgText(ctx, contentX + 14, titleTextY, RARITY_LABELS[selectedSection.rarity] .. "物资")
        nvgFontSize(ctx, 10)
        nvgFillColor(ctx, nvgRGBA(145, 152, 156, 220))
        nvgText(ctx, contentX + 14, subtitleY,
            RARITY_SUB[selectedSection.rarity] .. "  /  " .. tostring(#selectedSection.items) .. " ITEMS")

        local gridX = contentX + 10
        local gridY = contentTop + titleH + 8
        local gridW = contentW - 20
        local gridH = contentH - titleH - 16
        local cols = contentW < 270 and 2 or (contentW < 480 and 3 or 4)
        local cardGap = clamp(contentW * 0.025, 7, 12)
        local cardW = (gridW - cardGap * (cols - 1)) / cols
        local cardH = cardW * 1.35
        local rows = math.ceil(#selectedSection.items / cols)
        local totalH = rows * (cardH + cardGap) - cardGap
        CodexUI.scrollMax = math.max(0, totalH - gridH)
        CodexUI.scrollY = clamp(CodexUI.scrollY, 0, CodexUI.scrollMax)

        nvgSave(ctx)
        nvgScissor(ctx, gridX, gridY, gridW, gridH)
        for index, item in ipairs(selectedSection.items) do
            local col = (index - 1) % cols
            local row = math.floor((index - 1) / cols)
            local cardX = gridX + col * (cardW + cardGap)
            local cardY = gridY + row * (cardH + cardGap) - CodexUI.scrollY
            if cardY + cardH >= gridY and cardY <= gridY + gridH then
                drawItemCard(ctx, cardX, cardY, cardW, cardH, item, itemIcons[item.name], itemValues)
                table.insert(CodexUI.cardRects, { name = item.name, rect = { x = cardX, y = cardY, w = cardW, h = cardH } })
            end
        end
        nvgRestore(ctx)

        if CodexUI.scrollMax > 0 then
            local barH = math.max(32, gridH * gridH / math.max(totalH, gridH + 1))
            local barY = gridY + (gridH - barH) * (CodexUI.scrollY / CodexUI.scrollMax)
            nvgBeginPath(ctx)
            nvgRoundedRect(ctx, contentX + contentW - 5, barY, 3, barH, 1.5)
            nvgFillColor(ctx, rgba(rc, 110))
            nvgFill(ctx)
        end
    end

    if CodexUI.selectedItem then
        local selectedItem = nil
        for _, section in ipairs(sections) do
            for _, item in ipairs(section.items) do
                if item.name == CodexUI.selectedItem then selectedItem = item; break end
            end
            if selectedItem then break end
        end
        if selectedItem then
            drawDetailPanelFixed(ctx, w, h, selectedItem, itemIcons[selectedItem.name], itemValues, itemSizes)
        end
    end
end

-- ── 公共接口 ──

function CodexUI.Open()
    CodexUI.active = true
    CodexUI.scrollY = 0
    CodexUI.selectedRarity = "red"
    CodexUI.selectedItem = nil
end

function CodexUI.Close()
    CodexUI.active = false
    CodexUI.selectedItem = nil
end

function CodexUI.Update(dt)
    CodexUI.animTime = CodexUI.animTime + (dt or 0)
    if CodexUI.ignoreMouseTimer > 0 then
        CodexUI.ignoreMouseTimer = CodexUI.ignoreMouseTimer - (dt or 0)
    end
end

function CodexUI.ShouldIgnoreMouse()
    return CodexUI.ignoreMouseTimer > 0
end

local function getHit(x, y)
    if pointInRect(x, y, CodexUI.detailCloseRect) then return "detail_close" end
    if pointInRect(x, y, CodexUI.backRect) then return "back" end
    for rarity, rect in pairs(CodexUI.categoryRects) do
        if pointInRect(x, y, rect) then return "category_" .. rarity end
    end
    for _, cr in ipairs(CodexUI.cardRects) do
        if pointInRect(x, y, cr.rect) then return "card_" .. cr.name end
    end
    if CodexUI.viewport and pointInRect(x, y, CodexUI.viewport) then return "area" end
    return nil
end

function CodexUI.PointerMove(x, y)
    CodexUI.hovered = getHit(x, y)
end

function CodexUI.PointerDown(x, y)
    CodexUI.pressed = getHit(x, y)
    if CodexUI.pressed == "area" then
        CodexUI.touchScrollStart = CodexUI.scrollY
        CodexUI.touchLastY = y
        CodexUI.touchScrolling = true
    end
end

function CodexUI.PointerUp(x, y)
    local hit = getHit(x, y)
    local activated = hit and hit == CodexUI.pressed and hit or nil
    CodexUI.pressed = nil
    CodexUI.touchScrolling = false
    if not activated then return nil end
    if activated == "back" then
        CodexUI.Close()
        return "back"
    elseif activated == "detail_close" then
        CodexUI.selectedItem = nil
    elseif activated:sub(1, 9) == "category_" then
        CodexUI.selectedRarity = activated:sub(10)
        CodexUI.scrollY = 0
        CodexUI.selectedItem = nil
    elseif activated:sub(1, 5) == "card_" then
        CodexUI.selectedItem = activated:sub(6)
    end
    return nil
end

function CodexUI.ScrollDelta(delta)
    CodexUI.scrollY = clamp(CodexUI.scrollY + delta, 0, CodexUI.scrollMax)
end

function CodexUI.TouchBegin(touchId, x, y)
    CodexUI.touchId = touchId
    CodexUI.touchStartY = y
    CodexUI.touchLastY = y
    CodexUI.touchScrollStart = CodexUI.scrollY
    CodexUI.touchScrolling = false
    CodexUI.pressed = getHit(x, y)
end

function CodexUI.TouchMove(touchId, x, y)
    if touchId ~= CodexUI.touchId then return end
    if math.abs(y - CodexUI.touchStartY) > 8 then
        CodexUI.touchScrolling = true
    end
    if CodexUI.touchScrolling then
        CodexUI.scrollY = clamp(CodexUI.touchScrollStart + (CodexUI.touchStartY - y), 0, CodexUI.scrollMax)
    end
    CodexUI.touchLastY = y
end

function CodexUI.TouchEnd(touchId, x, y)
    if touchId ~= CodexUI.touchId then return nil end
    CodexUI.touchId = nil
    local wasScrolling = CodexUI.touchScrolling
    CodexUI.touchScrolling = false
    if wasScrolling then
        CodexUI.ignoreMouseTimer = 0.15
        return nil
    end
    local hit = getHit(x, y)
    local activated = hit and hit == CodexUI.pressed and hit or nil
    CodexUI.pressed = nil
    if not activated then return nil end
    if activated == "back" then
        CodexUI.Close()
        return "back"
    elseif activated == "detail_close" then
        CodexUI.selectedItem = nil
    elseif activated:sub(1, 9) == "category_" then
        CodexUI.selectedRarity = activated:sub(10)
        CodexUI.scrollY = 0
        CodexUI.selectedItem = nil
    elseif activated:sub(1, 5) == "card_" then
        CodexUI.selectedItem = activated:sub(6)
    end
    return nil
end

function CodexUI.Draw(ctx, w, h, data)
    data = data or {}
    drawSidebarCodex(
        ctx,
        w,
        h,
        data.itemIcons or {},
        data.itemValues or {},
        data.itemSizes or {},
        data.itemRarity or {}
    )
    if true then return end

    -- 以下为旧的纵向分区绘制路径，保留但不再执行。
    local itemIcons = data.itemIcons or {}
    local itemValues = data.itemValues or {}
    local itemSizes = data.itemSizes or {}
    local itemRarity = data.itemRarity or {}

    CodexUI.backRect = nil
    CodexUI.detailCloseRect = nil
    CodexUI.cardRects = {}

    drawBackground(ctx, w, h)

    -- 先构建分组以统计总数
    local sections = buildSections(itemValues, itemRarity)
    local totalCount = 0
    for _, s in ipairs(sections) do totalCount = totalCount + #s.items end

    local headerH = drawHeader(ctx, w, h, totalCount)
    drawBackButton(ctx)

    -- 布局参数
    local pad = clamp(w * 0.035, 12, 22)
    local contentTop = headerH + 6
    local contentBottom = h - 10
    local contentH = contentBottom - contentTop
    local contentW = w - pad * 2

    CodexUI.viewport = { x = pad, y = contentTop, w = contentW, h = contentH }

    -- 根据屏幕宽度决定列数（图片要大！）
    local cols
    if w < 380 then cols = 2
    elseif w < 520 then cols = 3
    elseif w < 720 then cols = 4
    else cols = 5 end

    local cardGap = 10
    local sectionGap = 22
    local cardW = (contentW - cardGap * (cols - 1)) / cols
    local cardH = cardW * 1.35  -- 卡片高度略大于宽度，图片占62%

    -- 计算总内容高度
    local totalH = 0
    for _, sec in ipairs(sections) do
        local rows = math.ceil(#sec.items / cols)
        totalH = totalH + 36 + 10 + rows * (cardH + cardGap) - cardGap + sectionGap
    end
    totalH = totalH - sectionGap + 10

    CodexUI.scrollMax = math.max(0, totalH - contentH)
    CodexUI.scrollY = clamp(CodexUI.scrollY, 0, CodexUI.scrollMax)

    nvgSave(ctx)
    nvgScissor(ctx, pad - 2, contentTop, contentW + 4, contentH)

    local curY = contentTop - CodexUI.scrollY

    for _, sec in ipairs(sections) do
        -- 分区标题
        local headerPlusGap = drawSectionHeader(ctx, pad, curY, contentW, sec)

        -- 卡片网格
        local gridStartY = curY + headerPlusGap
        local rows = math.ceil(#sec.items / cols)

        for i, item in ipairs(sec.items) do
            local col = (i - 1) % cols
            local row = math.floor((i - 1) / cols)
            local cx = pad + col * (cardW + cardGap)
            local cy = gridStartY + row * (cardH + cardGap)

            if cy + cardH >= contentTop - 10 and cy <= contentBottom + 10 then
                local iconId = itemIcons[item.name]
                drawItemCard(ctx, cx, cy, cardW, cardH, item, iconId, itemValues)
                table.insert(CodexUI.cardRects, {
                    name = item.name,
                    rect = { x = cx, y = cy, w = cardW, h = cardH },
                })
            end
        end

        curY = gridStartY + rows * (cardH + cardGap) - cardGap + sectionGap
    end

    nvgRestore(ctx)

    -- 右下角总统计
    nvgFontFace(ctx, "sans")
    nvgTextAlign(ctx, NVG_ALIGN_RIGHT + NVG_ALIGN_BOTTOM)
    nvgFontSize(ctx, 10)
    nvgFillColor(ctx, nvgRGBA(100, 108, 112, 180))
    nvgText(ctx, w - pad, h - 4, tostring(totalCount) .. " 种可搜刮物资")

    -- 滚动条
    if CodexUI.scrollMax > 0 then
        local barH = math.max(36, contentH * contentH / math.max(totalH, contentH + 1))
        local barY = contentTop + (contentH - barH) * (CodexUI.scrollY / CodexUI.scrollMax)
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, w - 4, barY, 3, barH, 1.5)
        nvgFillColor(ctx, nvgRGBA(140, 140, 140, 70))
        nvgFill(ctx)
    end

    -- 详情弹窗
    if CodexUI.selectedItem then
        local selItem = nil
        for _, sec in ipairs(sections) do
            for _, it in ipairs(sec.items) do
                if it.name == CodexUI.selectedItem then selItem = it; break end
            end
            if selItem then break end
        end
        if selItem then
            drawDetailPanel(ctx, w, h, selItem,
                itemIcons[selItem.name], itemValues, itemSizes)
        end
    end
end

return CodexUI
