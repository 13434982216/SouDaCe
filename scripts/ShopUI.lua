local ShopUI = {
    selectedCategory = "guns",
    hovered = nil,
    pressed = nil,
    categoryRects = {},
    productRects = {},
    backRect = nil,
    modal = nil,
    modalCloseRect = nil,
    modalBuyRect = nil,
    modalBackdropRect = nil,
    modalPanelRect = nil,
    scrollOffset = 0,
    scrollMax = 0,
    gridViewport = nil,
    categoryScrollOffset = 0,
    categoryScrollMax = 0,
    categoryViewport = nil,
    categoryHorizontal = false,
    animTime = 0,
    notice = "",
    noticeTimer = 0,
    noticeSuccess = false,
    touchId = nil,
    touchStartX = 0,
    touchStartY = 0,
    touchLastY = 0,
    touchScrollStart = 0,
    touchCategoryScrollStart = 0,
    touchScrollTarget = nil,
    touchScrolling = false,
    ignoreMouseTimer = 0,
}

local CATEGORIES = {
    { id = "guns", label = "枪支", subtitle = "FIREARMS" },
    { id = "ammo", label = "弹药", subtitle = "AMMUNITION" },
    { id = "armor", label = "防弹衣", subtitle = "BODY ARMOR" },
    { id = "helmets", label = "头盔", subtitle = "HELMETS" },
    { id = "rigs", label = "胸挂", subtitle = "CHEST RIGS" },
    { id = "backpacks", label = "背包", subtitle = "BACKPACKS" },
    { id = "safe_boxes", label = "安全箱", subtitle = "SAFE BOXES" },
}

local CATEGORY_BY_ID = {}
for _, category in ipairs(CATEGORIES) do
    CATEGORY_BY_ID[category.id] = category
end

local PRODUCTS = {
    {
        id = "pistol",
        category = "guns",
        item = "手枪",
        name = "制式半自动手枪",
        shortName = "手枪",
        model = "P-9 / 9毫米",
        price = 8800,
        rarity = "blue",
        tag = "稳定可靠",
        description = "结构简单、便于维护的半自动手枪。适合作为封锁区行动的基础枪支，可装备到枪支槽。",
        stats = {
            { label = "威力", value = 48 },
            { label = "射速", value = 72 },
            { label = "操控", value = 86 },
        },
    },
    {
        id = "shotgun",
        category = "guns",
        item = "散弹枪",
        name = "双管折管散弹枪",
        shortName = "散弹枪",
        model = "DB-12 / 12号口径",
        price = 12800,
        rarity = "red",
        tag = "近距爆发",
        description = "近距离拥有极高爆发力的双管散弹枪。装填较慢，但非常适合狭窄室内清理感染者。",
        stats = {
            { label = "威力", value = 96 },
            { label = "射速", value = 32 },
            { label = "操控", value = 58 },
        },
    },
    {
        id = "pistol_ammo_box",
        category = "ammo",
        item = "手枪弹药盒",
        name = "9毫米手枪弹药盒",
        shortName = "手枪弹药盒",
        model = "9×19MM / 24发装",
        price = 1200,
        rarity = "green",
        tag = "手枪补给",
        description = "密封铁盒包装的9毫米手枪弹药，适合据点储备与封锁区行动补给。购买后自动送入一号仓库。",
        stats = {
            { label = "弹量", value = 76 },
            { label = "可靠", value = 82 },
            { label = "便携", value = 90 },
        },
    },
    {
        id = "shotgun_ammo_pack",
        category = "ammo",
        item = "散弹枪弹药包",
        name = "12号散弹枪弹药包",
        shortName = "散弹枪弹药包",
        model = "12 GAUGE / 12发装",
        price = 1800,
        rarity = "blue",
        tag = "近距火力补给",
        description = "耐磨帆布携行包装的12号散弹，便于快速取用，为双管散弹枪提供近距离火力补给。",
        stats = {
            { label = "弹量", value = 58 },
            { label = "威力", value = 94 },
            { label = "便携", value = 72 },
        },
    },
    {
        id = "armor_tier2",
        category = "armor",
        item = "二级防弹衣",
        name = "二级战术防弹衣",
        shortName = "二级防弹衣",
        model = "A2 / 复合防护插板",
        price = 7200,
        rarity = "blue",
        tag = "躯干防护",
        description = "配有基础防弹插板的二级战术护甲，可装备到防弹衣槽，降低感染者近身攻击造成的伤害。",
        stats = {
            { label = "防护", value = 68 },
            { label = "耐久", value = 72 },
            { label = "机动", value = 62 },
        },
    },
    {
        id = "helmet_tier2",
        category = "helmets",
        item = "二级头盔",
        name = "二级战术头盔",
        shortName = "二级头盔",
        model = "H2 / 轻型战术盔",
        price = 4800,
        rarity = "blue",
        tag = "头部防护",
        description = "轻量化二级战术头盔，可装备到头盔槽，在保持视野和移动能力的同时提供基础头部防护。",
        stats = {
            { label = "防护", value = 54 },
            { label = "耐久", value = 60 },
            { label = "视野", value = 86 },
        },
    },
    {
        id = "rig_tier2",
        category = "rigs",
        item = "二级胸挂",
        name = "二级战术胸挂",
        shortName = "二级胸挂",
        model = "R2 / 快速取用型",
        price = 5600,
        rarity = "blue",
        tag = "快速取用",
        description = "带有多个快速取用袋位的二级战术胸挂，可装备到胸挂槽，方便在行动中携带和使用补给。",
        stats = {
            { label = "容量", value = 64 },
            { label = "取用", value = 88 },
            { label = "机动", value = 74 },
        },
    },
    {
        id = "backpack_tier2",
        category = "backpacks",
        item = "二级背包",
        name = "二级远征战术背包",
        shortName = "二级背包",
        model = "B2 / 负重扩展型",
        price = 6800,
        rarity = "blue",
        tag = "仓储扩容",
        description = "采用耐磨面料和模块化外挂系统的二级远征背包，可装备到背包槽，为封锁区行动提供稳定的物资携带空间。",
        stats = {
            { label = "容量", value = 78 },
            { label = "耐久", value = 74 },
            { label = "机动", value = 66 },
        },
    },
    {
        id = "safe_box_tier2",
        category = "safe_boxes",
        item = "二级安全箱",
        name = "二级加固战术安全箱",
        shortName = "二级安全箱",
        model = "SV-2 / 3×2 密封舱",
        price = 8600,
        rarity = "blue",
        tag = "密封撤离保护",
        description = "军规级横置防护箱，采用复合装甲壳体、双机械锁扣与防水密封结构。可装备到安全箱槽，为高价值物资提供可靠的撤离保护。",
        stats = {
            { label = "容量", value = 62 },
            { label = "防护", value = 90 },
            { label = "密封", value = 86 },
        },
    },
    {
        id = "safe_box_tier3",
        category = "safe_boxes",
        item = "三级安全箱",
        name = "三级猩红战术安全箱",
        shortName = "三级安全箱",
        model = "SV-3 / 4×3 绝密舱",
        price = 19800,
        rarity = "red",
        tag = "传说级撤离保护",
        description = "据点最高规格的猩红安全箱，采用多层复合装甲、三重机械锁扣与绝密级密封结构。装备后将安全箱扩展为十二格，为顶级物资提供最高等级的撤离保护。",
        stats = {
            { label = "容量", value = 100 },
            { label = "防护", value = 98 },
            { label = "密封", value = 96 },
        },
    },
}

local PRODUCT_BY_ID = {}
for _, product in ipairs(PRODUCTS) do
    PRODUCT_BY_ID[product.id] = product
end

local RARITY_COLORS = {
    red = { 191, 57, 48 },
    pink = { 190, 72, 136 },
    purple = { 128, 78, 178 },
    blue = { 54, 116, 181 },
    green = { 62, 139, 86 },
}

local function clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

local function pointInRect(x, y, rect)
    return rect and x >= rect.x and x <= rect.x + rect.w
        and y >= rect.y and y <= rect.y + rect.h
end

local function formatNumber(value)
    local text = tostring(math.max(0, math.floor(tonumber(value) or 0)))
    local reversed = string.reverse(text)
    reversed = string.gsub(reversed, "(%d%d%d)", "%1,")
    text = string.reverse(reversed)
    return string.gsub(text, "^,", "")
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

local function drawPanel(ctx, x, y, w, h, fill, border, active)
    beginCutRect(ctx, x, y, w, h, 8)
    nvgFillColor(ctx, nvgRGBA(fill[1], fill[2], fill[3], fill[4] or 255))
    nvgFill(ctx)
    beginCutRect(ctx, x, y, w, h, 8)
    nvgStrokeColor(ctx, nvgRGBA(border[1], border[2], border[3], border[4] or 255))
    nvgStrokeWidth(ctx, active and 1.8 or 1)
    nvgStroke(ctx)
end

local function drawImageContained(ctx, imageId, x, y, w, h, scale)
    if not imageId or imageId <= 0 then return false end
    local sourceW, sourceH = nvgImageSize(ctx, imageId)
    sourceW = math.max(1, sourceW or 1)
    sourceH = math.max(1, sourceH or 1)
    local fitScale = math.min(w / sourceW, h / sourceH) * (scale or 1)
    local drawW = sourceW * fitScale
    local drawH = sourceH * fitScale
    local drawX = x + (w - drawW) * 0.5
    local drawY = y + (h - drawH) * 0.5
    local paint = nvgImagePattern(ctx, drawX, drawY, drawW, drawH, 0, imageId, 1.0)
    nvgBeginPath(ctx)
    nvgRect(ctx, drawX, drawY, drawW, drawH)
    nvgFillPaint(ctx, paint)
    nvgFill(ctx)
    return true
end

local function drawAmmoIcon(ctx, itemName, x, y, w, h, alpha)
    if itemName ~= "手枪弹药盒" and itemName ~= "散弹枪弹药包" then
        return false
    end

    local a = math.floor(255 * (alpha or 1))
    local cx = x + w * 0.5
    local cy = y + h * 0.5
    if itemName == "手枪弹药盒" then
        local boxW = math.min(w * 0.72, h * 1.12)
        local boxH = boxW * 0.62
        local boxX = cx - boxW * 0.5
        local boxY = cy - boxH * 0.38
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, boxX, boxY, boxW, boxH, 5)
        nvgFillColor(ctx, nvgRGBA(49, 67, 52, a))
        nvgFill(ctx)
        nvgStrokeColor(ctx, nvgRGBA(130, 157, 111, a))
        nvgStrokeWidth(ctx, 1.5)
        nvgStroke(ctx)
        for index = 1, 5 do
            local bulletX = boxX + boxW * (0.14 + (index - 1) * 0.18)
            nvgBeginPath(ctx)
            nvgRoundedRect(ctx, bulletX, boxY + boxH * 0.18, boxW * 0.09, boxH * 0.56, 2)
            nvgFillColor(ctx, nvgRGBA(203, 157, 66, a))
            nvgFill(ctx)
            nvgBeginPath(ctx)
            nvgCircle(ctx, bulletX + boxW * 0.045, boxY + boxH * 0.18, boxW * 0.045)
            nvgFillColor(ctx, nvgRGBA(240, 208, 126, a))
            nvgFill(ctx)
        end
    else
        local shellW = math.min(w * 0.13, h * 0.20)
        local shellH = shellW * 3.5
        for index = 1, 4 do
            local shellX = cx + (index - 2.5) * shellW * 1.38
            local shellY = cy - shellH * 0.52 + math.abs(index - 2.5) * 2
            nvgBeginPath(ctx)
            nvgRoundedRect(ctx, shellX - shellW * 0.5, shellY, shellW, shellH, shellW * 0.35)
            nvgFillColor(ctx, nvgRGBA(153, 45, 38, a))
            nvgFill(ctx)
            nvgBeginPath(ctx)
            nvgRect(ctx, shellX - shellW * 0.5, shellY + shellH * 0.72, shellW, shellH * 0.25)
            nvgFillColor(ctx, nvgRGBA(205, 158, 65, a))
            nvgFill(ctx)
        end
    end
    return true
end

local function getProductsForCategory(categoryId)
    local result = {}
    for _, product in ipairs(PRODUCTS) do
        if product.category == categoryId then
            result[#result + 1] = product
        end
    end
    return result
end

local function drawBackground(ctx, width, height)
    local background = nvgLinearGradient(ctx, 0, 0, width, height,
        nvgRGBA(28, 31, 33, 255), nvgRGBA(7, 9, 11, 255))
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, width, height)
    nvgFillPaint(ctx, background)
    nvgFill(ctx)

    local glow = nvgRadialGradient(ctx, width * 0.72, height * 0.2, 8, width * 0.62,
        nvgRGBA(172, 103, 44, 45), nvgRGBA(13, 15, 17, 0))
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, width, height)
    nvgFillPaint(ctx, glow)
    nvgFill(ctx)
end

local function drawHeader(ctx, width, data)
    local headerH = 66
    local gradient = nvgLinearGradient(ctx, 0, 0, 0, headerH,
        nvgRGBA(8, 10, 12, 252), nvgRGBA(21, 24, 27, 238))
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, width, headerH)
    nvgFillPaint(ctx, gradient)
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, headerH - 1, width, 1)
    nvgFillColor(ctx, nvgRGBA(175, 119, 55, 185))
    nvgFill(ctx)

    ShopUI.backRect = { x = 12, y = 12, w = 44, h = 42 }
    local backHot = ShopUI.hovered == "back" or ShopUI.pressed == "back"
    drawPanel(ctx, 12, 12, 44, 42,
        backHot and { 77, 52, 42, 255 } or { 36, 40, 43, 250 },
        { 165, 109, 70, 215 }, backHot)
    nvgFontFace(ctx, "sans")
    nvgFontSize(ctx, 24)
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(ctx, nvgRGBA(239, 224, 196, 255))
    nvgText(ctx, 34, 32, "‹")

    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFontSize(ctx, clamp(width * 0.035, 22, 30))
    nvgFillColor(ctx, nvgRGBA(236, 226, 204, 255))
    nvgText(ctx, 70, 25, "战术补给商城")
    nvgFontSize(ctx, 10)
    nvgFillColor(ctx, nvgRGBA(125, 134, 137, 245))
    nvgText(ctx, 72, 48, "TACTICAL SUPPLY / 武器装备采购")

    local balanceW = clamp(width * 0.20, 132, 190)
    local balanceX = width - balanceW - 14
    drawPanel(ctx, balanceX, 12, balanceW, 42,
        { 33, 29, 22, 250 }, { 181, 133, 58, 215 }, false)
    nvgBeginPath(ctx)
    nvgCircle(ctx, balanceX + 18, 33, 7)
    nvgFillColor(ctx, nvgRGBA(220, 169, 67, 255))
    nvgFill(ctx)
    nvgTextAlign(ctx, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFontSize(ctx, 9)
    nvgFillColor(ctx, nvgRGBA(125, 128, 124, 245))
    nvgText(ctx, balanceX + balanceW - 10, 23, "可用比特")
    nvgFontSize(ctx, 16)
    nvgFillColor(ctx, nvgRGBA(239, 222, 181, 255))
    nvgText(ctx, balanceX + balanceW - 10, 40, formatNumber(data.bits))

    return headerH
end

local function drawCategoryRail(ctx, x, y, width, height, horizontal)
    ShopUI.categoryRects = {}
    ShopUI.categoryViewport = { x = x, y = y, w = width, h = height }
    ShopUI.categoryHorizontal = horizontal == true

    local gap = horizontal and 4 or 5
    local itemW = horizontal and clamp(width / 6.2, 84, 112) or math.max(1, width - 7)
    local itemH = horizontal and math.max(1, height - 4) or 50
    local contentSize = horizontal
        and (#CATEGORIES * itemW + gap * (#CATEGORIES - 1))
        or (#CATEGORIES * itemH + gap * (#CATEGORIES - 1))
    local viewportSize = horizontal and width or height
    ShopUI.categoryScrollMax = math.max(0, contentSize - viewportSize)
    ShopUI.categoryScrollOffset = clamp(
        ShopUI.categoryScrollOffset,
        0,
        ShopUI.categoryScrollMax
    )

    nvgSave(ctx)
    nvgScissor(ctx, x, y, width, height)

    for index, category in ipairs(CATEGORIES) do
        local itemX = horizontal
            and (x + (index - 1) * (itemW + gap) - ShopUI.categoryScrollOffset)
            or x
        local itemY = horizontal
            and y
            or (y + (index - 1) * (itemH + gap) - ShopUI.categoryScrollOffset)
        local id = "category:" .. category.id
        local active = ShopUI.selectedCategory == category.id
        local hot = ShopUI.hovered == id or ShopUI.pressed == id
        local rect = { x = itemX, y = itemY, w = itemW, h = itemH }
        ShopUI.categoryRects[category.id] = rect

        local fill = active and { 70, 49, 29, 252 }
            or (hot and { 40, 45, 48, 250 } or { 24, 28, 31, 242 })
        local border = active and { 218, 160, 67, 245 } or { 73, 84, 88, 190 }
        drawPanel(ctx, rect.x, rect.y, rect.w, rect.h, fill, border, active)
        if active then
            nvgBeginPath(ctx)
            nvgRect(ctx, rect.x + 2, rect.y + 2, horizontal and rect.w - 4 or 3,
                horizontal and 3 or rect.h - 4)
            nvgFillColor(ctx, nvgRGBA(220, 162, 67, 245))
            nvgFill(ctx)
        end

        nvgFontFace(ctx, "sans")
        nvgTextAlign(ctx, horizontal and (NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            or (NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE))
        local showSubtitle = not horizontal and itemH >= 44
        nvgFontSize(ctx, horizontal and clamp(itemW * 0.16, 8, 11) or (showSubtitle and 13 or 12))
        nvgFillColor(ctx, active and nvgRGBA(244, 231, 204, 255) or nvgRGBA(174, 181, 181, 245))
        nvgText(ctx, horizontal and (rect.x + rect.w * 0.5) or (rect.x + 14),
            horizontal and (rect.y + rect.h * 0.5)
                or (showSubtitle and (rect.y + rect.h * 0.38) or (rect.y + rect.h * 0.5)), category.label)
        if showSubtitle then
            nvgFontSize(ctx, 8)
            nvgFillColor(ctx, nvgRGBA(102, 112, 115, 235))
            nvgText(ctx, rect.x + 14, rect.y + rect.h * 0.70, category.subtitle)
        end
    end

    if ShopUI.categoryScrollMax > 0 then
        local thumbRatio = viewportSize / contentSize
        local thumbSize = math.max(18, viewportSize * thumbRatio)
        local thumbOffset = (viewportSize - thumbSize)
            * ShopUI.categoryScrollOffset / ShopUI.categoryScrollMax
        nvgBeginPath(ctx)
        if horizontal then
            nvgRoundedRect(ctx, x + thumbOffset, y + height - 3, thumbSize, 3, 1.5)
        else
            nvgRoundedRect(ctx, x + width - 4, y + thumbOffset, 3, thumbSize, 1.5)
        end
        nvgFillColor(ctx, nvgRGBA(218, 160, 67, 225))
        nvgFill(ctx)
    end

    nvgRestore(ctx)
end

local function drawProductCard(ctx, product, rect, data)
    local id = "product:" .. product.id
    local hot = ShopUI.hovered == id or ShopUI.pressed == id
    local selected = ShopUI.modal and ShopUI.modal.productId == product.id
    local rarity = RARITY_COLORS[product.rarity] or RARITY_COLORS.blue
    local fill = hot and { 29, 34, 37, 252 } or { 19, 23, 26, 248 }
    drawPanel(ctx, rect.x, rect.y, rect.w, rect.h, fill,
        selected and rarity or { rarity[1], rarity[2], rarity[3], 195 }, selected or hot)

    local compact = rect.w < 190
    local imageH = rect.h * (compact and 0.44 or 0.48)
    local imageX = rect.x + 6
    local imageY = rect.y + 6
    local imageW = rect.w - 12
    local imageGradient
    if product.id == "safe_box_tier2" then
        imageGradient = nvgRadialGradient(ctx, rect.x + rect.w * 0.5, imageY + imageH * 0.52,
            4, math.max(imageW, imageH) * 0.62,
            nvgRGBA(190, 143, 63, 108), nvgRGBA(10, 14, 17, 0))
    elseif product.id == "safe_box_tier3" then
        imageGradient = nvgRadialGradient(ctx, rect.x + rect.w * 0.5, imageY + imageH * 0.52,
            4, math.max(imageW, imageH) * 0.64,
            nvgRGBA(211, 46, 38, 128), nvgRGBA(15, 7, 8, 0))
    else
        imageGradient = nvgRadialGradient(ctx, rect.x + rect.w * 0.5, imageY + imageH * 0.55,
            6, math.max(imageW, imageH) * 0.58,
            nvgRGBA(rarity[1], rarity[2], rarity[3], 82), nvgRGBA(9, 12, 14, 0))
    end
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, imageX, imageY, imageW, imageH, 5)
    nvgFillPaint(ctx, imageGradient)
    nvgFill(ctx)
    if product.id == "safe_box_tier2" or product.id == "safe_box_tier3" then
        local frameColor = product.id == "safe_box_tier3"
            and { 211, 46, 38, 180 }
            or { 190, 143, 63, 145 }
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, imageX + 2, imageY + 2, imageW - 4, imageH - 4, 4)
        nvgStrokeColor(ctx, nvgRGBA(frameColor[1], frameColor[2], frameColor[3], frameColor[4]))
        nvgStrokeWidth(ctx, product.id == "safe_box_tier3" and 1.5 or 1)
        nvgStroke(ctx)
    end
    local imageScale = product.id == "shotgun" and 1.18
        or ((product.id == "safe_box_tier2" or product.id == "safe_box_tier3") and 1.12 or 1.0)
    if not drawImageContained(ctx, data.itemIcons and data.itemIcons[product.item],
        imageX + 6, imageY + 4, imageW - 12, imageH - 8, imageScale) then
        drawAmmoIcon(ctx, product.item,
            imageX + 6, imageY + 4, imageW - 12, imageH - 8, 1.0)
    end

    nvgFontFace(ctx, "sans")
    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFontSize(ctx, compact and 6.5 or 8)
    nvgFillColor(ctx, nvgRGBA(rarity[1], rarity[2], rarity[3], 255))
    nvgText(ctx, rect.x + 8, imageY + imageH + 6, product.model)
    nvgFontSize(ctx, clamp(rect.w * 0.062, compact and 10 or 14, compact and 13 or 18))
    nvgFillColor(ctx, nvgRGBA(238, 232, 216, 255))
    nvgText(ctx, rect.x + 8, imageY + imageH + 19, product.name)
    nvgFontSize(ctx, compact and 6.5 or 8)
    nvgFillColor(ctx, nvgRGBA(132, 142, 144, 245))
    nvgText(ctx, rect.x + 8, rect.y + rect.h - 25, compact and product.tag or (product.tag .. "  ·  点击查看详情"))

    nvgTextAlign(ctx, NVG_ALIGN_RIGHT + NVG_ALIGN_BOTTOM)
    nvgFontSize(ctx, compact and 12 or 16)
    nvgFillColor(ctx, nvgRGBA(224, 174, 75, 255))
    nvgText(ctx, rect.x + rect.w - 9, rect.y + rect.h - 8, formatNumber(product.price))
    nvgFontSize(ctx, 7)
    nvgFillColor(ctx, nvgRGBA(129, 132, 128, 235))
    nvgText(ctx, rect.x + rect.w - 9, rect.y + rect.h - 25, "比特")
end

local function drawEmptyState(ctx, viewport, category)
    local boxW = math.min(viewport.w - 30, 420)
    local boxH = math.min(viewport.h - 30, 210)
    local boxX = viewport.x + (viewport.w - boxW) * 0.5
    local boxY = viewport.y + (viewport.h - boxH) * 0.5
    drawPanel(ctx, boxX, boxY, boxW, boxH,
        { 20, 24, 27, 242 }, { 69, 80, 84, 180 }, false)

    nvgFontFace(ctx, "sans")
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(ctx, 38)
    nvgFillColor(ctx, nvgRGBA(87, 96, 99, 235))
    nvgText(ctx, boxX + boxW * 0.5, boxY + 57, "—")
    nvgFontSize(ctx, 21)
    nvgFillColor(ctx, nvgRGBA(213, 210, 199, 250))
    nvgText(ctx, boxX + boxW * 0.5, boxY + 103, category.label .. "暂无库存")
    nvgFontSize(ctx, 11)
    nvgFillColor(ctx, nvgRGBA(120, 130, 132, 245))
    nvgTextBox(ctx, boxX + 32, boxY + 132, boxW - 64,
        "商队正在补充该分类物资，后续库存开放后可在这里直接采购。")
end

local function drawCatalog(ctx, x, y, width, height, data)
    local category = CATEGORY_BY_ID[ShopUI.selectedCategory] or CATEGORIES[1]
    local products = getProductsForCategory(category.id)
    local titleH = 46

    nvgFontFace(ctx, "sans")
    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFontSize(ctx, 8)
    nvgFillColor(ctx, nvgRGBA(190, 132, 63, 245))
    nvgText(ctx, x, y, category.subtitle .. " / 据点商人库存")
    nvgFontSize(ctx, 19)
    nvgFillColor(ctx, nvgRGBA(235, 229, 212, 255))
    nvgText(ctx, x, y + 14, category.label)
    nvgTextAlign(ctx, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    nvgFontSize(ctx, 9)
    nvgFillColor(ctx, nvgRGBA(119, 128, 131, 245))
    nvgText(ctx, x + width, y + 21, tostring(#products) .. " 件在售")

    local viewport = { x = x, y = y + titleH, w = width, h = math.max(40, height - titleH) }
    ShopUI.gridViewport = viewport
    ShopUI.productRects = {}
    if #products == 0 then
        ShopUI.scrollOffset = 0
        ShopUI.scrollMax = 0
        drawEmptyState(ctx, viewport, category)
        return
    end

    local gap = clamp(viewport.w * 0.010, 4, 8)
    local columns = viewport.w >= 560 and 4 or 3
    local cardW = (viewport.w - gap * (columns - 1)) / columns
    local cardH = clamp(viewport.h * 0.54, 150, 205)
    local rows = math.ceil(#products / columns)
    local contentH = rows * cardH + math.max(0, rows - 1) * gap
    ShopUI.scrollMax = math.max(0, contentH - viewport.h)
    ShopUI.scrollOffset = clamp(ShopUI.scrollOffset, 0, ShopUI.scrollMax)

    nvgSave(ctx)
    nvgScissor(ctx, viewport.x, viewport.y, viewport.w, viewport.h)
    for index, product in ipairs(products) do
        local column = (index - 1) % columns
        local row = math.floor((index - 1) / columns)
        local rect = {
            x = viewport.x + column * (cardW + gap),
            y = viewport.y + row * (cardH + gap) - ShopUI.scrollOffset,
            w = cardW,
            h = cardH,
        }
        if rect.y + rect.h >= viewport.y and rect.y <= viewport.y + viewport.h then
            ShopUI.productRects[product.id] = rect
            drawProductCard(ctx, product, rect, data)
        end
    end
    nvgRestore(ctx)
end

local function drawStat(ctx, x, y, width, label, value, color)
    nvgFontFace(ctx, "sans")
    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFontSize(ctx, 8)
    nvgFillColor(ctx, nvgRGBA(137, 145, 146, 245))
    nvgText(ctx, x, y, label)
    local barX = x + 36
    local barW = math.max(24, width - 36)
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, barX, y - 2.5, barW, 5, 2.5)
    nvgFillColor(ctx, nvgRGBA(42, 48, 50, 250))
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, barX, y - 2.5, barW * clamp(value / 100, 0, 1), 5, 2.5)
    nvgFillColor(ctx, nvgRGBA(color[1], color[2], color[3], 245))
    nvgFill(ctx)
end

local function drawModal(ctx, width, height, data)
    if not ShopUI.modal then
        ShopUI.modalCloseRect = nil
        ShopUI.modalBuyRect = nil
        ShopUI.modalBackdropRect = nil
        ShopUI.modalPanelRect = nil
        return
    end
    local product = PRODUCT_BY_ID[ShopUI.modal.productId]
    if not product then
        ShopUI.modal = nil
        return
    end

    ShopUI.modalBackdropRect = { x = 0, y = 0, w = width, h = height }
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, width, height)
    nvgFillColor(ctx, nvgRGBA(2, 4, 5, 205))
    nvgFill(ctx)

    local modalW = math.min(width - 48, 500)
    local modalH = math.min(height - 48, 300)
    local modalX = (width - modalW) * 0.5
    local modalY = (height - modalH) * 0.5
    ShopUI.modalPanelRect = { x = modalX, y = modalY, w = modalW, h = modalH }
    local rarity = RARITY_COLORS[product.rarity] or RARITY_COLORS.blue
    drawPanel(ctx, modalX, modalY, modalW, modalH,
        { 17, 21, 24, 255 }, { rarity[1], rarity[2], rarity[3], 245 }, true)

    ShopUI.modalCloseRect = { x = modalX + modalW - 42, y = modalY + 8, w = 34, h = 34 }
    local closeHot = ShopUI.hovered == "modal-close" or ShopUI.pressed == "modal-close"
    drawPanel(ctx, ShopUI.modalCloseRect.x, ShopUI.modalCloseRect.y,
        ShopUI.modalCloseRect.w, ShopUI.modalCloseRect.h,
        closeHot and { 76, 45, 41, 255 } or { 35, 40, 43, 250 },
        { 140, 87, 75, 210 }, closeHot)
    nvgFontFace(ctx, "sans")
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(ctx, 16)
    nvgFillColor(ctx, nvgRGBA(228, 213, 195, 255))
    nvgText(ctx, ShopUI.modalCloseRect.x + ShopUI.modalCloseRect.w * 0.5,
        ShopUI.modalCloseRect.y + ShopUI.modalCloseRect.h * 0.5, "×")

    local imageW = math.min(modalW * 0.37, 178)
    local imageX = modalX + 13
    local imageY = modalY + 14
    local imageH = modalH - 28
    local imageGradient = nvgRadialGradient(ctx, imageX + imageW * 0.5, imageY + imageH * 0.46,
        8, math.max(imageW, imageH) * 0.55,
        nvgRGBA(rarity[1], rarity[2], rarity[3], 86), nvgRGBA(10, 12, 14, 0))
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, imageX, imageY, imageW, imageH, 6)
    nvgFillPaint(ctx, imageGradient)
    nvgFill(ctx)
    local modalImageScale = product.id == "shotgun" and 1.12
        or ((product.id == "safe_box_tier2" or product.id == "safe_box_tier3") and 1.16 or 1.0)
    if not drawImageContained(ctx, data.itemIcons and data.itemIcons[product.item],
        imageX + 10, imageY + 16, imageW - 20, imageH * 0.64, modalImageScale) then
        drawAmmoIcon(ctx, product.item,
            imageX + 10, imageY + 16, imageW - 20, imageH * 0.64, 1.0)
    end

    local infoX = imageX + imageW + 14
    local infoW = modalX + modalW - infoX - 12
    local titleMaxW = math.max(80, infoW - 38)
    local titleLength = math.max(1, utf8.len(product.name) or 1)
    local titleFontSize = clamp(titleMaxW / titleLength, 13, 18)

    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFontSize(ctx, 8)
    nvgFillColor(ctx, nvgRGBA(rarity[1], rarity[2], rarity[3], 255))
    nvgText(ctx, infoX, modalY + 20, product.model)

    nvgFontSize(ctx, titleFontSize)
    nvgFillColor(ctx, nvgRGBA(241, 234, 216, 255))
    nvgText(ctx, infoX, modalY + 38, product.name)

    nvgFontSize(ctx, 9)
    nvgFillColor(ctx, nvgRGBA(145, 154, 155, 245))
    nvgTextBox(ctx, infoX, modalY + 66, infoW, product.description)

    local statY = modalY + 121
    for index, stat in ipairs(product.stats) do
        drawStat(ctx, infoX, statY + (index - 1) * 18, infoW, stat.label, stat.value, rarity)
    end

    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_BOTTOM)
    nvgFontSize(ctx, 8)
    nvgFillColor(ctx, nvgRGBA(126, 133, 132, 245))
    nvgText(ctx, infoX, modalY + modalH - 52, "购买后自动存入一号仓库")
    nvgFontSize(ctx, 18)
    nvgFillColor(ctx, nvgRGBA(225, 176, 76, 255))
    nvgText(ctx, infoX, modalY + modalH - 25, formatNumber(product.price) .. " 比特")

    local canAfford = (tonumber(data.bits) or 0) >= product.price
    ShopUI.modalBuyRect = {
        x = modalX + modalW - 120,
        y = modalY + modalH - 48,
        w = 108,
        h = 36,
    }
    local buyHot = ShopUI.hovered == "modal-buy" or ShopUI.pressed == "modal-buy"
    local buttonFill = canAfford
        and (buyHot and { 171, 116, 39, 255 } or { 128, 86, 30, 255 })
        or { 54, 57, 57, 245 }
    local buttonBorder = canAfford and { 228, 181, 89, 240 } or { 88, 91, 90, 190 }
    drawPanel(ctx, ShopUI.modalBuyRect.x, ShopUI.modalBuyRect.y,
        ShopUI.modalBuyRect.w, ShopUI.modalBuyRect.h, buttonFill, buttonBorder, buyHot and canAfford)
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(ctx, 11)
    nvgFillColor(ctx, canAfford and nvgRGBA(252, 240, 211, 255) or nvgRGBA(128, 132, 131, 245))
    nvgText(ctx, ShopUI.modalBuyRect.x + ShopUI.modalBuyRect.w * 0.5,
        ShopUI.modalBuyRect.y + ShopUI.modalBuyRect.h * 0.5,
        canAfford and "确认购买" or "比特不足")
end

local function drawNotice(ctx, width, height)
    if ShopUI.noticeTimer <= 0 or ShopUI.notice == "" then return end
    local noticeW = math.min(width - 36, 360)
    local noticeH = 42
    local noticeX = (width - noticeW) * 0.5
    local noticeY = height - noticeH - 16
    local border = ShopUI.noticeSuccess and { 91, 166, 107, 235 } or { 200, 104, 77, 235 }
    drawPanel(ctx, noticeX, noticeY, noticeW, noticeH,
        { 25, 29, 29, 250 }, border, false)
    nvgFontFace(ctx, "sans")
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(ctx, 12)
    nvgFillColor(ctx, nvgRGBA(239, 230, 210, 255))
    nvgText(ctx, noticeX + noticeW * 0.5, noticeY + noticeH * 0.5, ShopUI.notice)
end

function ShopUI.Open()
    ShopUI.selectedCategory = "guns"
    ShopUI.hovered = nil
    ShopUI.pressed = nil
    ShopUI.modal = nil
    ShopUI.scrollOffset = 0
    ShopUI.scrollMax = 0
    ShopUI.categoryScrollOffset = 0
    ShopUI.categoryScrollMax = 0
    ShopUI.touchScrollTarget = nil
    ShopUI.notice = ""
    ShopUI.noticeTimer = 0
    ShopUI.touchId = nil
    ShopUI.touchScrolling = false
    ShopUI.ignoreMouseTimer = 0
    print("[Shop] 商城已打开，当前枪支库存=" .. tostring(#getProductsForCategory("guns")))
end

function ShopUI.Update(dt)
    ShopUI.animTime = ShopUI.animTime + (dt or 0)
    ShopUI.ignoreMouseTimer = math.max(0, ShopUI.ignoreMouseTimer - (dt or 0))
    if ShopUI.noticeTimer > 0 then
        ShopUI.noticeTimer = math.max(0, ShopUI.noticeTimer - (dt or 0))
    end
end

function ShopUI.GetProduct(productId)
    return PRODUCT_BY_ID[productId]
end

function ShopUI.SetNotice(message, success)
    ShopUI.notice = message or ""
    ShopUI.noticeSuccess = success == true
    ShopUI.noticeTimer = 2.2
    if success then ShopUI.modal = nil end
end

function ShopUI.Scroll(delta)
    if ShopUI.modal then return false end
    ShopUI.scrollOffset = clamp(ShopUI.scrollOffset + (delta or 0), 0, ShopUI.scrollMax)
    return true
end

function ShopUI.ScrollAt(x, y, delta)
    if ShopUI.modal then return false end
    if pointInRect(x, y, ShopUI.categoryViewport) then
        ShopUI.categoryScrollOffset = clamp(
            ShopUI.categoryScrollOffset + (delta or 0),
            0,
            ShopUI.categoryScrollMax
        )
        return true
    end
    return ShopUI.Scroll(delta)
end

function ShopUI.GetHit(x, y)
    if ShopUI.modal then
        if pointInRect(x, y, ShopUI.modalCloseRect) then return "modal-close" end
        if pointInRect(x, y, ShopUI.modalBuyRect) then return "modal-buy" end
        if pointInRect(x, y, ShopUI.modalPanelRect) then return "modal-panel" end
        return pointInRect(x, y, ShopUI.modalBackdropRect) and "modal-backdrop" or nil
    end
    if pointInRect(x, y, ShopUI.backRect) then return "back" end
    if pointInRect(x, y, ShopUI.categoryViewport) then
        for _, category in ipairs(CATEGORIES) do
            if pointInRect(x, y, ShopUI.categoryRects[category.id]) then
                return "category:" .. category.id
            end
        end
    end
    if pointInRect(x, y, ShopUI.gridViewport) then
        for _, product in ipairs(PRODUCTS) do
            if pointInRect(x, y, ShopUI.productRects[product.id]) then
                return "product:" .. product.id
            end
        end
    end
    return nil
end

function ShopUI.PointerMove(x, y)
    ShopUI.hovered = ShopUI.GetHit(x, y)
end

function ShopUI.PointerDown(x, y)
    ShopUI.pressed = ShopUI.GetHit(x, y)
    return ShopUI.pressed
end

function ShopUI.PointerUp(x, y)
    local hit = ShopUI.GetHit(x, y)
    local action = hit and hit == ShopUI.pressed and hit or nil
    ShopUI.pressed = nil
    if not action then return nil end

    if action == "modal-close" or action == "modal-backdrop" then
        ShopUI.modal = nil
        return "modal-close"
    end
    if action == "modal-buy" then
        return ShopUI.modal and ("purchase:" .. ShopUI.modal.productId) or nil
    end

    local categoryId = action:match("^category:(.+)$")
    if categoryId and CATEGORY_BY_ID[categoryId] then
        ShopUI.selectedCategory = categoryId
        ShopUI.scrollOffset = 0
        ShopUI.hovered = nil
        return "category"
    end

    local productId = action:match("^product:(.+)$")
    if productId and PRODUCT_BY_ID[productId] then
        ShopUI.modal = { productId = productId }
        ShopUI.hovered = nil
        return "product"
    end

    return action
end

function ShopUI.TouchBegin(touchId, x, y)
    if ShopUI.touchId ~= nil then return false end
    ShopUI.touchId = touchId
    ShopUI.ignoreMouseTimer = 0.5
    ShopUI.touchStartX = x
    ShopUI.touchStartY = y
    ShopUI.touchLastY = y
    ShopUI.touchScrollStart = ShopUI.scrollOffset
    ShopUI.touchCategoryScrollStart = ShopUI.categoryScrollOffset
    ShopUI.touchScrollTarget = pointInRect(x, y, ShopUI.categoryViewport)
        and "category"
        or (pointInRect(x, y, ShopUI.gridViewport) and "catalog" or nil)
    ShopUI.touchScrolling = false
    ShopUI.PointerDown(x, y)
    return true
end

function ShopUI.TouchMove(touchId, x, y)
    if ShopUI.touchId ~= touchId then return false end
    ShopUI.ignoreMouseTimer = 0.5
    local dx = x - ShopUI.touchStartX
    local dy = y - ShopUI.touchStartY
    local dragDelta = ShopUI.categoryHorizontal and dx or dy
    local movementSq = dx * dx + dy * dy
    if not ShopUI.modal and ShopUI.touchScrollTarget and movementSq > 64 then
        ShopUI.touchScrolling = true
        ShopUI.pressed = nil
    end
    if ShopUI.touchScrolling then
        if ShopUI.touchScrollTarget == "category" then
            ShopUI.categoryScrollOffset = clamp(
                ShopUI.touchCategoryScrollStart - dragDelta,
                0,
                ShopUI.categoryScrollMax
            )
        elseif ShopUI.touchScrollTarget == "catalog" then
            ShopUI.scrollOffset = clamp(ShopUI.touchScrollStart - dy, 0, ShopUI.scrollMax)
        end
    else
        ShopUI.PointerMove(x, y)
    end
    ShopUI.touchLastY = y
    return true
end

function ShopUI.TouchEnd(touchId, x, y)
    if ShopUI.touchId ~= touchId then return nil end
    ShopUI.ignoreMouseTimer = 0.5
    local action = nil
    if not ShopUI.touchScrolling then
        ShopUI.PointerMove(x, y)
        action = ShopUI.PointerUp(x, y)
    else
        ShopUI.pressed = nil
    end
    ShopUI.touchId = nil
    ShopUI.touchScrolling = false
    ShopUI.touchScrollTarget = nil
    return action
end

function ShopUI.ShouldIgnoreMouse()
    return ShopUI.touchId ~= nil or ShopUI.ignoreMouseTimer > 0
end

function ShopUI.Draw(ctx, width, height, data)
    data = data or {}
    drawBackground(ctx, width, height)
    local headerH = drawHeader(ctx, width, data)
    local pad = 12
    local gap = 10
    local narrow = width < 720

    if narrow then
        local railY = headerH + 8
        local railH = 48
        drawCategoryRail(ctx, pad, railY, width - pad * 2, railH, true)
        drawCatalog(ctx, pad, railY + railH + gap, width - pad * 2,
            height - railY - railH - gap - pad, data)
    else
        local contentY = headerH + 9
        local contentH = height - contentY - pad
        local railW = clamp(width * 0.17, 142, 184)
        drawCategoryRail(ctx, pad, contentY, railW, contentH, false)
        drawCatalog(ctx, pad + railW + gap, contentY, width - railW - gap - pad * 2,
            contentH, data)
    end

    drawModal(ctx, width, height, data)
    drawNotice(ctx, width, height)
end

return ShopUI
