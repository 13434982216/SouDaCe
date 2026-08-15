local Currency = require "Currency"

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
    touchScrollStart = 0,
    touchScrollTarget = nil,
    touchScrolling = false,
    ignoreMouseTimer = 0,
    layoutScale = 1,
    layoutOffsetX = 0,
    layoutOffsetY = 0,
}

local DESIGN_W = 1365
local DESIGN_H = 768

local CATEGORIES = {
    { id = "guns", label = "枪支", subtitle = "FIREARMS", mark = "01" },
    { id = "ammo", label = "弹药", subtitle = "AMMUNITION", mark = "02" },
    { id = "armor", label = "防弹衣", subtitle = "BODY ARMOR", mark = "03" },
    { id = "helmets", label = "头盔", subtitle = "HELMETS", mark = "04" },
    { id = "rigs", label = "胸挂", subtitle = "CHEST RIGS", mark = "05" },
    { id = "backpacks", label = "背包", subtitle = "BACKPACKS", mark = "06" },
    { id = "safe_boxes", label = "安全箱", subtitle = "SAFE BOXES", mark = "07" },
}

local CATEGORY_BY_ID = {}
for _, category in ipairs(CATEGORIES) do
    CATEGORY_BY_ID[category.id] = category
end

local PRODUCTS = {
    {
        id = "pistol", category = "guns", item = "手枪",
        name = "G17 9mm手枪", shortName = "G17 9mm手枪", model = "G17 / 9毫米",
        price = 8500, rarity = "blue", tag = "稳定可靠",
        description = "结构简单、便于维护的半自动手枪。适合作为封锁区行动的基础枪支，可装备到枪支槽。",
        stats = {
            { label = "威力", value = 48 }, { label = "射速", value = 72 },
            { label = "操控", value = 86 },
        },
    },
    {
        id = "shotgun", category = "guns", item = "散弹枪",
        name = "双管散弹枪", shortName = "双管散弹枪", model = "DB-12 / 12号口径",
        price = 14000, rarity = "purple", tag = "近距爆发",
        description = "近距离拥有极高爆发力的双管散弹枪。装填较慢，但非常适合狭窄室内清理感染者。",
        stats = {
            { label = "威力", value = 96 }, { label = "射速", value = 32 },
            { label = "操控", value = 58 },
        },
    },
    {
        id = "pistol_ammo_box", category = "ammo", item = "手枪弹药盒",
        name = "9mm手枪弹药盒", shortName = "9mm手枪弹药盒", model = "9×19MM / 50发装",
        price = 2000, rarity = "green", tag = "手枪补给",
        description = "密封铁盒包装的9毫米手枪弹药，适合据点储备与封锁区行动补给。购买后自动送入一号仓库。",
        stats = {
            { label = "弹量", value = 76 }, { label = "可靠", value = 82 },
            { label = "便携", value = 90 },
        },
    },
    {
        id = "shotgun_ammo_pack", category = "ammo", item = "散弹枪弹药包",
        name = "12号散弹枪弹药包", shortName = "散弹枪弹药包", model = "12 GAUGE / 12发装",
        price = 1800, rarity = "blue", tag = "近距火力补给",
        description = "耐磨帆布携行包装的12号散弹，便于快速取用，为双管散弹枪提供近距离火力补给。",
        stats = {
            { label = "弹量", value = 58 }, { label = "威力", value = 94 },
            { label = "便携", value = 72 },
        },
    },
    {
        id = "armor_tier2", category = "armor", item = "二级防弹衣",
        name = "二级战术防弹衣", shortName = "二级防弹衣", model = "A2 / 复合防护插板",
        price = 9000, rarity = "purple", tag = "躯干防护",
        description = "配有基础防弹插板的二级战术护甲，可装备到防弹衣槽，降低感染者近身攻击造成的伤害。",
        stats = {
            { label = "防护", value = 68 }, { label = "耐久", value = 72 },
            { label = "机动", value = 62 },
        },
    },
    {
        id = "helmet_tier2", category = "helmets", item = "二级头盔",
        name = "二级战术头盔", shortName = "二级头盔", model = "H2 / 轻型战术盔",
        price = 6000, rarity = "blue", tag = "头部防护",
        description = "轻量化二级战术头盔，可装备到头盔槽，在保持视野和移动能力的同时提供基础头部防护。",
        stats = {
            { label = "防护", value = 54 }, { label = "耐久", value = 60 },
            { label = "视野", value = 86 },
        },
    },
    {
        id = "rig_tier2", category = "rigs", item = "二级胸挂",
        name = "二级战术胸挂", shortName = "二级胸挂", model = "R2 / 快速取用型",
        price = 5600, rarity = "blue", tag = "快速取用",
        description = "带有多个快速取用袋位的二级战术胸挂，可装备到胸挂槽，方便在行动中携带和使用补给。",
        stats = {
            { label = "容量", value = 64 }, { label = "取用", value = 88 },
            { label = "机动", value = 74 },
        },
    },
    {
        id = "backpack_tier2", category = "backpacks", item = "二级背包",
        name = "二级远征战术背包", shortName = "二级背包", model = "B2 / 负重扩展型",
        price = 5500, rarity = "blue", tag = "仓储扩容",
        description = "采用耐磨面料和模块化外挂系统的二级远征背包，可装备到背包槽，为封锁区行动提供稳定的物资携带空间。",
        stats = {
            { label = "容量", value = 78 }, { label = "耐久", value = 74 },
            { label = "机动", value = 66 },
        },
    },
    {
        id = "safe_box_tier2", category = "safe_boxes", item = "二级安全箱",
        name = "二级加固战术安全箱", shortName = "二级安全箱", model = "SV-2 / 3×2 密封舱",
        price = 8600, rarity = "blue", tag = "密封撤离保护",
        description = "军规级横置防护箱，采用复合装甲壳体、双机械锁扣与防水密封结构。可装备到安全箱槽，为高价值物资提供可靠的撤离保护。",
        stats = {
            { label = "容量", value = 62 }, { label = "防护", value = 90 },
            { label = "密封", value = 86 },
        },
    },
    {
        id = "safe_box_tier3", category = "safe_boxes", item = "三级安全箱",
        name = "三级猩红战术安全箱", shortName = "三级安全箱", model = "SV-3 / 4×3 绝密舱",
        price = 19800, rarity = "red", tag = "传说级撤离保护",
        description = "据点最高规格的猩红安全箱，采用多层复合装甲、三重机械锁扣与绝密级密封结构。装备后将安全箱扩展为十二格，为顶级物资提供最高等级的撤离保护。",
        stats = {
            { label = "容量", value = 100 }, { label = "防护", value = 98 },
            { label = "密封", value = 96 },
        },
    },
}

local PRODUCT_BY_ID = {}
for _, product in ipairs(PRODUCTS) do PRODUCT_BY_ID[product.id] = product end

local RARITY_COLORS = {
    red = { 142, 54, 42 }, gold = { 146, 113, 44 }, pink = { 128, 76, 104 },
    purple = { 86, 64, 102 }, blue = { 50, 75, 88 }, green = { 67, 79, 51 },
}

local CELL_KEYS = {
    red = "red2x2", gold = "gold2x1", pink = "pink2x2",
    purple = "purple2x1", blue = "blue1x1", green = "green1x1",
}

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function pointInRect(x, y, rect)
    return rect and x >= rect.x and x <= rect.x + rect.w
        and y >= rect.y and y <= rect.y + rect.h
end

local function formatNumber(value)
    return Currency.FormatNumber(value)
end

local function formatBitValue(value)
    return Currency.Format(value)
end

local function screenToDesign(x, y)
    local scale = math.max(0.0001, ShopUI.layoutScale or 1)
    return (x - (ShopUI.layoutOffsetX or 0)) / scale,
        (y - (ShopUI.layoutOffsetY or 0)) / scale
end

local function drawImageCover(ctx, image, x, y, w, h, alpha)
    if not image or image <= 0 then return false end
    local sourceW, sourceH = nvgImageSize(ctx, image)
    sourceW, sourceH = math.max(1, sourceW or 1), math.max(1, sourceH or 1)
    local scale = math.max(w / sourceW, h / sourceH)
    local drawW, drawH = sourceW * scale, sourceH * scale
    local drawX, drawY = x + (w - drawW) * 0.5, y + (h - drawH) * 0.5
    nvgSave(ctx)
    nvgScissor(ctx, x, y, w, h)
    nvgBeginPath(ctx)
    nvgRect(ctx, drawX, drawY, drawW, drawH)
    nvgFillPaint(ctx, nvgImagePattern(ctx, drawX, drawY, drawW, drawH, 0, image, alpha or 1))
    nvgFill(ctx)
    nvgRestore(ctx)
    return true
end

local function drawImageContained(ctx, image, x, y, w, h, scale)
    if not image or image <= 0 then return false end
    local sourceW, sourceH = nvgImageSize(ctx, image)
    sourceW, sourceH = math.max(1, sourceW or 1), math.max(1, sourceH or 1)
    local fit = math.min(w / sourceW, h / sourceH) * (scale or 1)
    local drawW, drawH = sourceW * fit, sourceH * fit
    local drawX, drawY = x + (w - drawW) * 0.5, y + (h - drawH) * 0.5
    nvgSave(ctx)
    nvgIntersectScissor(ctx, x, y, w, h)
    nvgBeginPath(ctx)
    nvgRect(ctx, drawX, drawY, drawW, drawH)
    nvgFillPaint(ctx, nvgImagePattern(ctx, drawX, drawY, drawW, drawH, 0, image, 1))
    nvgFill(ctx)
    nvgRestore(ctx)
    return true
end

local function drawCellBackground(ctx, image, rect)
    if image and image > 0 then
        nvgBeginPath(ctx)
        nvgRect(ctx, rect.x, rect.y, rect.w, rect.h)
        nvgFillPaint(ctx, nvgImagePattern(ctx, rect.x, rect.y, rect.w, rect.h, 0, image, 1))
        nvgFill(ctx)
        return
    end
    nvgBeginPath(ctx)
    nvgRect(ctx, rect.x, rect.y, rect.w, rect.h)
    nvgFillColor(ctx, nvgRGBA(31, 37, 38, 250))
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(119, 103, 70, 230))
    nvgStrokeWidth(ctx, 2)
    nvgStroke(ctx)
end

local function beginTornRect(ctx, x, y, w, h, cut)
    local c = cut or 8
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, x + c, y)
    nvgLineTo(ctx, x + w - c * 0.7, y)
    nvgLineTo(ctx, x + w, y + c)
    nvgLineTo(ctx, x + w, y + h - c)
    nvgLineTo(ctx, x + w - c, y + h)
    nvgLineTo(ctx, x + c * 0.6, y + h)
    nvgLineTo(ctx, x, y + h - c * 0.8)
    nvgLineTo(ctx, x, y + c)
    nvgClosePath(ctx)
end

local function drawPaper(ctx, x, y, w, h, active)
    beginTornRect(ctx, x, y, w, h, 9)
    local gradient = nvgLinearGradient(ctx, x, y, x, y + h,
        active and nvgRGBA(226, 215, 183, 255) or nvgRGBA(197, 187, 157, 252),
        active and nvgRGBA(179, 164, 126, 255) or nvgRGBA(152, 143, 116, 252))
    nvgFillPaint(ctx, gradient)
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(65, 58, 43, 240))
    nvgStrokeWidth(ctx, active and 2 or 1.2)
    nvgStroke(ctx)
end

local function drawMetalPanel(ctx, x, y, w, h, selected)
    beginTornRect(ctx, x, y, w, h, 11)
    local gradient = nvgLinearGradient(ctx, x, y, x + w, y + h,
        nvgRGBA(31, 32, 27, 252), nvgRGBA(10, 14, 14, 252))
    nvgFillPaint(ctx, gradient)
    nvgFill(ctx)
    nvgStrokeColor(ctx, selected and nvgRGBA(205, 177, 111, 245)
        or nvgRGBA(104, 94, 70, 230))
    nvgStrokeWidth(ctx, selected and 2.2 or 1.4)
    nvgStroke(ctx)
    nvgBeginPath(ctx)
    nvgRect(ctx, x + 7, y + 7, w - 14, h - 14)
    nvgStrokeColor(ctx, nvgRGBA(46, 49, 43, 210))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)
end

local function drawTape(ctx, x, y, w, h, angle)
    nvgSave(ctx)
    nvgTranslate(ctx, x + w * 0.5, y + h * 0.5)
    nvgRotate(ctx, angle or 0)
    nvgBeginPath(ctx)
    nvgRect(ctx, -w * 0.5, -h * 0.5, w, h)
    nvgFillColor(ctx, nvgRGBA(205, 191, 146, 154))
    nvgFill(ctx)
    nvgRestore(ctx)
end

local function drawAmmoFallback(ctx, itemName, x, y, w, h)
    if itemName ~= "手枪弹药盒" and itemName ~= "散弹枪弹药包" then return false end
    local color = itemName == "手枪弹药盒" and nvgRGBA(71, 86, 61, 255)
        or nvgRGBA(137, 51, 41, 255)
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x + w * 0.18, y + h * 0.22, w * 0.64, h * 0.56, 5)
    nvgFillColor(ctx, color)
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(195, 157, 80, 245))
    nvgStrokeWidth(ctx, 2)
    nvgStroke(ctx)
    return true
end

local STOREFRONT_ORDER = {
    "pistol", "shotgun", "pistol_ammo_box", "helmet_tier2",
    "armor_tier2", "backpack_tier2", "shotgun_ammo_pack",
    "rig_tier2", "safe_box_tier2", "safe_box_tier3",
}

local function getProductsForCategory(categoryId)
    local result = {}
    for _, product in ipairs(PRODUCTS) do
        if product.category == categoryId then result[#result + 1] = product end
    end
    return result
end

local function getStorefrontProducts(categoryId)
    local result = {}
    local added = {}
    for _, productId in ipairs(STOREFRONT_ORDER) do
        local product = PRODUCT_BY_ID[productId]
        if product and product.category == categoryId then
            result[#result + 1] = product
            added[product.id] = true
        end
    end
    for _, productId in ipairs(STOREFRONT_ORDER) do
        local product = PRODUCT_BY_ID[productId]
        if product and not added[product.id] then
            result[#result + 1] = product
            added[product.id] = true
        end
    end
    return result
end

local function getSelectedProduct()
    if ShopUI.modal and PRODUCT_BY_ID[ShopUI.modal.productId] then
        return PRODUCT_BY_ID[ShopUI.modal.productId]
    end
    local products = getProductsForCategory(ShopUI.selectedCategory)
    return products[1]
end

local function ensureSelectedProduct()
    local selected = getSelectedProduct()
    if selected and (not ShopUI.modal or ShopUI.modal.productId ~= selected.id) then
        ShopUI.modal = { productId = selected.id }
    end
    return selected
end

local function drawBackground(ctx, data)
    if not drawImageCover(ctx, data.backgroundImage, 0, 0, DESIGN_W, DESIGN_H, 1) then
        nvgBeginPath(ctx)
        nvgRect(ctx, 0, 0, DESIGN_W, DESIGN_H)
        nvgFillColor(ctx, nvgRGBA(9, 13, 13, 255))
        nvgFill(ctx)
    end
    local shade = nvgLinearGradient(ctx, 0, 0, DESIGN_W, 0,
        nvgRGBA(2, 4, 4, 105), nvgRGBA(2, 4, 4, 174))
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, DESIGN_W, DESIGN_H)
    nvgFillPaint(ctx, shade)
    nvgFill(ctx)
    local vignette = nvgRadialGradient(ctx, DESIGN_W * 0.5, DESIGN_H * 0.46,
        180, 780, nvgRGBA(0, 0, 0, 0), nvgRGBA(0, 0, 0, 165))
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, DESIGN_W, DESIGN_H)
    nvgFillPaint(ctx, vignette)
    nvgFill(ctx)
end

local function drawHeader(ctx, data)
    drawPaper(ctx, 492, 7, 382, 75, true)
    drawTape(ctx, 478, 4, 84, 23, -0.08)
    drawTape(ctx, 810, 61, 76, 20, 0.06)
    nvgFontFace(ctx, "sans")
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(ctx, 34)
    nvgFillColor(ctx, nvgRGBA(28, 26, 20, 255))
    nvgText(ctx, 683, 40, "据点军需商店")
    nvgFontSize(ctx, 9)
    nvgFillColor(ctx, nvgRGBA(78, 67, 49, 245))
    nvgText(ctx, 683, 65, "OUTPOST QUARTERMASTER / 生存物资采购处")

    ShopUI.backRect = { x = 1283, y = 14, w = 64, h = 60 }
    drawMetalPanel(ctx, 1283, 14, 64, 60, ShopUI.hovered == "back")
    nvgFontSize(ctx, 34)
    nvgFillColor(ctx, nvgRGBA(213, 199, 162, 255))
    nvgText(ctx, 1315, 44, "×")

    drawMetalPanel(ctx, 1008, 20, 254, 49, false)
    drawImageContained(ctx, data.currencyIcon, 1017, 30, 29, 29, 1)
    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFontSize(ctx, 10)
    nvgFillColor(ctx, nvgRGBA(151, 138, 105, 245))
    nvgText(ctx, 1053, 35, "据点账户 / 比特")
    nvgFontSize(ctx, 22)
    nvgFillColor(ctx, nvgRGBA(228, 195, 105, 255))
    nvgText(ctx, 1053, 56, formatNumber(data.bits))
    nvgTextAlign(ctx, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFontSize(ctx, 9)
    nvgFillColor(ctx, nvgRGBA(150, 66, 50, 245))
    nvgText(ctx, 1245, 48, "仅限据点内使用")
end

local function drawCategoryRail(ctx)
    local x, y, w, h = 9, 95, 222, 638
    drawMetalPanel(ctx, x, y, w, h, false)
    drawPaper(ctx, 24, 91, 190, 45, false)
    drawTape(ctx, 17, 84, 58, 18, -0.09)
    nvgFontFace(ctx, "sans")
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(ctx, 20)
    nvgFillColor(ctx, nvgRGBA(38, 34, 25, 255))
    nvgText(ctx, 119, 113, "军需分类")

    ShopUI.categoryRects = {}
    ShopUI.categoryViewport = { x = x + 8, y = y + 42, w = w - 16, h = h - 52 }
    ShopUI.categoryHorizontal = false
    ShopUI.categoryScrollMax = 0
    ShopUI.categoryScrollOffset = 0
    local itemH, gap = 72, 9
    for index, category in ipairs(CATEGORIES) do
        local rect = { x = 19, y = 143 + (index - 1) * (itemH + gap), w = 202, h = itemH }
        ShopUI.categoryRects[category.id] = rect
        local id = "category:" .. category.id
        local active = ShopUI.selectedCategory == category.id
        local hot = ShopUI.hovered == id or ShopUI.pressed == id
        if active then
            drawPaper(ctx, rect.x, rect.y, rect.w, rect.h, true)
        else
            drawMetalPanel(ctx, rect.x, rect.y, rect.w, rect.h, hot)
        end
        if active then
            nvgBeginPath(ctx)
            nvgRect(ctx, rect.x + 4, rect.y + 4, 6, rect.h - 8)
            nvgFillColor(ctx, nvgRGBA(151, 55, 43, 245))
            nvgFill(ctx)
        end
        nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFontSize(ctx, 10)
        nvgFillColor(ctx, active and nvgRGBA(139, 52, 42, 255)
            or nvgRGBA(137, 126, 99, 245))
        nvgText(ctx, rect.x + 17, rect.y + 17, category.mark)
        nvgFontSize(ctx, 18)
        nvgFillColor(ctx, active and nvgRGBA(31, 29, 23, 255)
            or nvgRGBA(187, 175, 142, 255))
        nvgText(ctx, rect.x + 50, rect.y + 28, category.label)
        nvgFontSize(ctx, 8)
        nvgFillColor(ctx, active and nvgRGBA(93, 82, 61, 235)
            or nvgRGBA(117, 109, 89, 235))
        nvgText(ctx, rect.x + 50, rect.y + 49, category.subtitle)
    end
end

local RARITY_LABELS = {
    red = "传说", gold = "珍贵", pink = "史诗",
    purple = "稀有", blue = "稀有", green = "普通",
}

local function drawProductCard(ctx, product, rect, data)
    local id = "product:" .. product.id
    local selected = ShopUI.modal and ShopUI.modal.productId == product.id
    local hot = ShopUI.hovered == id or ShopUI.pressed == id
    local cellKey = CELL_KEYS[product.rarity] or "green1x1"
    local rarity = RARITY_COLORS[product.rarity] or RARITY_COLORS.green
    drawCellBackground(ctx, data.cellImages and data.cellImages[cellKey], rect)

    local paperWash = nvgLinearGradient(ctx, rect.x, rect.y, rect.x + rect.w, rect.y + rect.h,
        nvgRGBA(187, 166, 119, 20), nvgRGBA(30, 25, 18, 76))
    nvgBeginPath(ctx)
    nvgRect(ctx, rect.x + 5, rect.y + 44, rect.w - 10, rect.h - 105)
    nvgFillPaint(ctx, paperWash)
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgCircle(ctx, rect.x + rect.w * 0.18, rect.y + rect.h * 0.58, 24)
    nvgFillColor(ctx, nvgRGBA(78, 58, 35, 26))
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgCircle(ctx, rect.x + rect.w * 0.83, rect.y + rect.h * 0.36, 17)
    nvgFillColor(ctx, nvgRGBA(40, 33, 22, 34))
    nvgFill(ctx)

    nvgBeginPath(ctx)
    nvgRect(ctx, rect.x + 5, rect.y + 5, rect.w - 10, 39)
    nvgFillColor(ctx, nvgRGBA(7, 10, 10, 220))
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(rarity[1], rarity[2], rarity[3], 245))
    nvgStrokeWidth(ctx, 1.5)
    nvgStroke(ctx)
    nvgFontFace(ctx, "sans")
    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFontSize(ctx, 12)
    nvgFillColor(ctx, nvgRGBA(rarity[1] + 55, rarity[2] + 55,
        rarity[3] + 55, 255))
    nvgText(ctx, rect.x + 14, rect.y + 24,
        RARITY_LABELS[product.rarity] or "普通")
    nvgTextAlign(ctx, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFontSize(ctx, 15)
    nvgFillColor(ctx, nvgRGBA(207, 192, 153, 255))
    nvgText(ctx, rect.x + rect.w - 13, rect.y + 24, product.shortName)

    local imageArea = {
        x = rect.x + 14, y = rect.y + 48,
        w = rect.w - 28, h = rect.h - 111,
    }
    local imageScale = product.id == "shotgun" and 1.14
        or ((product.id == "safe_box_tier2" or product.id == "safe_box_tier3") and 1.08 or 1)
    if not drawImageContained(ctx, data.itemIcons and data.itemIcons[product.item],
        imageArea.x, imageArea.y, imageArea.w, imageArea.h, imageScale) then
        drawAmmoFallback(ctx, product.item,
            imageArea.x, imageArea.y, imageArea.w, imageArea.h)
    end

    local priceRect = {
        x = rect.x + 15, y = rect.y + rect.h - 57,
        w = rect.w - 30, h = 43,
    }
    drawMetalPanel(ctx, priceRect.x, priceRect.y, priceRect.w, priceRect.h,
        selected or hot)
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(ctx, 19)
    nvgFillColor(ctx, nvgRGBA(218, 178, 78, 255))
    nvgText(ctx, priceRect.x + priceRect.w * 0.5,
        priceRect.y + priceRect.h * 0.5,
        formatBitValue(product.price))

    if selected or hot then
        nvgBeginPath(ctx)
        nvgRect(ctx, rect.x + 2, rect.y + 2, rect.w - 4, rect.h - 4)
        nvgStrokeColor(ctx, selected and nvgRGBA(233, 212, 154, 255)
            or nvgRGBA(211, 181, 105, 235))
        nvgStrokeWidth(ctx, selected and 3 or 2)
        nvgStroke(ctx)
    end
end

local function drawCatalog(ctx, data)
    local x, y, w, h = 239, 95, 770, 638
    drawMetalPanel(ctx, x, y, w, h, false)
    local category = CATEGORY_BY_ID[ShopUI.selectedCategory] or CATEGORIES[1]
    local products = getStorefrontProducts(category.id)
    ShopUI.productRects = {}
    ShopUI.gridViewport = { x = x + 12, y = y + 14, w = w - 24, h = h - 28 }
    local columns = 3
    local gap = 10
    local cardW = (ShopUI.gridViewport.w - gap * (columns - 1)) / columns
    local cardH = 296
    local rows = math.ceil(#products / columns)
    local contentH = rows * cardH + math.max(0, rows - 1) * gap
    ShopUI.scrollMax = math.max(0, contentH - ShopUI.gridViewport.h)
    ShopUI.scrollOffset = clamp(ShopUI.scrollOffset, 0, ShopUI.scrollMax)

    nvgSave(ctx)
    nvgScissor(ctx, ShopUI.gridViewport.x, ShopUI.gridViewport.y,
        ShopUI.gridViewport.w, ShopUI.gridViewport.h)
    for index, product in ipairs(products) do
        local column = (index - 1) % columns
        local row = math.floor((index - 1) / columns)
        local rect = {
            x = ShopUI.gridViewport.x + column * (cardW + gap),
            y = ShopUI.gridViewport.y + row * (cardH + gap) - ShopUI.scrollOffset,
            w = cardW, h = cardH,
        }
        if rect.y + rect.h >= ShopUI.gridViewport.y
            and rect.y <= ShopUI.gridViewport.y + ShopUI.gridViewport.h then
            ShopUI.productRects[product.id] = rect
            drawProductCard(ctx, product, rect, data)
        end
    end
    nvgRestore(ctx)

    if ShopUI.scrollMax > 0 then
        local trackX = x + w - 8
        local thumbH = math.max(46, ShopUI.gridViewport.h * ShopUI.gridViewport.h / contentH)
        local thumbY = ShopUI.gridViewport.y
            + (ShopUI.gridViewport.h - thumbH) * ShopUI.scrollOffset / ShopUI.scrollMax
        nvgBeginPath(ctx)
        nvgRect(ctx, trackX, ShopUI.gridViewport.y, 3, ShopUI.gridViewport.h)
        nvgFillColor(ctx, nvgRGBA(53, 48, 37, 215))
        nvgFill(ctx)
        nvgBeginPath(ctx)
        nvgRect(ctx, trackX, thumbY, 3, thumbH)
        nvgFillColor(ctx, nvgRGBA(197, 157, 76, 245))
        nvgFill(ctx)
    end
end

local function drawStat(ctx, x, y, w, stat, color)
    nvgFontFace(ctx, "sans")
    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFontSize(ctx, 10)
    nvgFillColor(ctx, nvgRGBA(67, 60, 45, 245))
    nvgText(ctx, x, y, stat.label)
    local barX, barW = x + 42, w - 42
    nvgBeginPath(ctx)
    nvgRect(ctx, barX, y - 4, barW, 8)
    nvgFillColor(ctx, nvgRGBA(85, 77, 59, 100))
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgRect(ctx, barX, y - 4, barW * clamp(stat.value / 100, 0, 1), 8)
    nvgFillColor(ctx, nvgRGBA(color[1], color[2], color[3], 245))
    nvgFill(ctx)
end

local function drawDetail(ctx, data)
    local x, y, w, h = 1018, 95, 338, 638
    drawMetalPanel(ctx, x, y, w, h, false)
    drawPaper(ctx, x + 16, y + 15, w - 32, h - 30, false)
    nvgBeginPath(ctx)
    nvgCircle(ctx, x + 72, y + 212, 38)
    nvgFillColor(ctx, nvgRGBA(86, 64, 37, 24))
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgCircle(ctx, x + w - 66, y + 380, 54)
    nvgFillColor(ctx, nvgRGBA(55, 44, 29, 22))
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, x + 30, y + 468)
    nvgLineTo(ctx, x + w - 28, y + 462)
    nvgStrokeColor(ctx, nvgRGBA(88, 72, 49, 52))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)
    local product = ensureSelectedProduct()
    ShopUI.modalBackdropRect = nil
    ShopUI.modalCloseRect = nil
    ShopUI.modalPanelRect = { x = x, y = y, w = w, h = h }
    if not product then
        ShopUI.modalBuyRect = nil
        return
    end

    local rarity = RARITY_COLORS[product.rarity] or RARITY_COLORS.blue
    nvgFontFace(ctx, "sans")
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(ctx, 24)
    nvgFillColor(ctx, nvgRGBA(38, 34, 25, 255))
    nvgText(ctx, x + w * 0.5, y + 45, "军需档案")
    nvgBeginPath(ctx)
    nvgRect(ctx, x + 44, y + 65, w - 88, 1)
    nvgFillColor(ctx, nvgRGBA(86, 74, 51, 185))
    nvgFill(ctx)

    local imageRect = { x = x + 44, y = y + 82, w = w - 88, h = 190 }
    nvgBeginPath(ctx)
    nvgRect(ctx, imageRect.x, imageRect.y, imageRect.w, imageRect.h)
    nvgFillColor(ctx, nvgRGBA(rarity[1], rarity[2], rarity[3], 55))
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(82, 73, 54, 210))
    nvgStrokeWidth(ctx, 2)
    nvgStroke(ctx)
    if not drawImageContained(ctx, data.itemIcons and data.itemIcons[product.item],
        imageRect.x + 15, imageRect.y + 10, imageRect.w - 30, imageRect.h - 20,
        product.id == "shotgun" and 1.1 or 1) then
        drawAmmoFallback(ctx, product.item, imageRect.x + 15, imageRect.y + 10,
            imageRect.w - 30, imageRect.h - 20)
    end

    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFontSize(ctx, 10)
    nvgFillColor(ctx, nvgRGBA(rarity[1], rarity[2], rarity[3], 255))
    nvgText(ctx, x + 44, y + 284, product.model)
    nvgFontSize(ctx, 21)
    nvgFillColor(ctx, nvgRGBA(32, 29, 22, 255))
    nvgText(ctx, x + 44, y + 303, product.name)
    nvgFontSize(ctx, 10)
    nvgFillColor(ctx, nvgRGBA(74, 66, 49, 245))
    nvgTextBox(ctx, x + 44, y + 337, w - 88, product.description)
    for index, stat in ipairs(product.stats) do
        drawStat(ctx, x + 44, y + 402 + (index - 1) * 23, w - 88, stat, rarity)
    end

    local canAfford = (tonumber(data.bits) or 0) >= product.price
    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFontSize(ctx, 10)
    nvgFillColor(ctx, nvgRGBA(91, 78, 54, 235))
    nvgText(ctx, x + 44, y + 494, "购买后送入一号仓库")
    nvgFontSize(ctx, 25)
    nvgFillColor(ctx, canAfford and nvgRGBA(151, 104, 42, 255)
        or nvgRGBA(126, 64, 51, 255))
    nvgText(ctx, x + 44, y + 526, formatBitValue(product.price))

    ShopUI.modalBuyRect = { x = x + 42, y = y + 548, w = w - 84, h = 49 }
    local hot = ShopUI.hovered == "modal-buy" or ShopUI.pressed == "modal-buy"
    if canAfford then
        drawMetalPanel(ctx, ShopUI.modalBuyRect.x, ShopUI.modalBuyRect.y,
            ShopUI.modalBuyRect.w, ShopUI.modalBuyRect.h, hot)
    else
        drawPaper(ctx, ShopUI.modalBuyRect.x, ShopUI.modalBuyRect.y,
            ShopUI.modalBuyRect.w, ShopUI.modalBuyRect.h, false)
    end
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(ctx, 17)
    nvgFillColor(ctx, canAfford and nvgRGBA(231, 211, 158, 255)
        or nvgRGBA(111, 72, 58, 255))
    nvgText(ctx, x + w * 0.5, y + 572, canAfford and "确认采购" or "账户余额不足")
end

local function drawNotice(ctx)
    if ShopUI.noticeTimer <= 0 or ShopUI.notice == "" then return end
    local x, y, w, h = 458, 688, 448, 48
    drawPaper(ctx, x, y, w, h, true)
    nvgFontFace(ctx, "sans")
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(ctx, 14)
    nvgFillColor(ctx, ShopUI.noticeSuccess and nvgRGBA(48, 82, 47, 255)
        or nvgRGBA(128, 48, 39, 255))
    nvgText(ctx, x + w * 0.5, y + h * 0.5, ShopUI.notice)
end

function ShopUI.Open()
    ShopUI.selectedCategory = "guns"
    ShopUI.hovered = nil
    ShopUI.pressed = nil
    ShopUI.modal = { productId = "pistol" }
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
    print("[Shop] 据点军需商店已打开")
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
end

function ShopUI.Scroll(delta)
    ShopUI.scrollOffset = clamp(ShopUI.scrollOffset + (delta or 0), 0, ShopUI.scrollMax)
    return true
end

function ShopUI.ScrollAt(x, y, delta)
    local dx, dy = screenToDesign(x, y)
    if pointInRect(dx, dy, ShopUI.categoryViewport) then return false end
    return ShopUI.Scroll((delta or 0) / math.max(0.0001, ShopUI.layoutScale))
end

local function getHitDesign(x, y)
    if pointInRect(x, y, ShopUI.modalBuyRect) then return "modal-buy" end
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

function ShopUI.GetHit(x, y)
    local dx, dy = screenToDesign(x, y)
    return getHitDesign(dx, dy)
end

function ShopUI.PointerMove(x, y)
    ShopUI.hovered = ShopUI.GetHit(x, y)
end

function ShopUI.PointerDown(x, y)
    ShopUI.pressed = ShopUI.GetHit(x, y)
    return ShopUI.pressed
end

function ShopUI.SetCategory(categoryId)
    if not CATEGORY_BY_ID[categoryId] then return false end
    ShopUI.selectedCategory = categoryId
    ShopUI.scrollOffset = 0
    local products = getProductsForCategory(categoryId)
    ShopUI.modal = products[1] and { productId = products[1].id } or nil
    ShopUI.hovered = nil
    return true
end

function ShopUI.PointerUp(x, y)
    local hit = ShopUI.GetHit(x, y)
    local action = hit and hit == ShopUI.pressed and hit or nil
    ShopUI.pressed = nil
    if not action then return nil end
    if action == "modal-buy" then
        return ShopUI.modal and ("purchase:" .. ShopUI.modal.productId) or nil
    end
    local categoryId = action:match("^category:(.+)$")
    if categoryId and ShopUI.SetCategory(categoryId) then
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
    local dx, dy = screenToDesign(x, y)
    ShopUI.touchId = touchId
    ShopUI.ignoreMouseTimer = 0.5
    ShopUI.touchStartX, ShopUI.touchStartY = dx, dy
    ShopUI.touchScrollStart = ShopUI.scrollOffset
    ShopUI.touchScrollTarget = pointInRect(dx, dy, ShopUI.gridViewport) and "catalog" or nil
    ShopUI.touchScrolling = false
    ShopUI.pressed = getHitDesign(dx, dy)
    return true
end

function ShopUI.TouchMove(touchId, x, y)
    if ShopUI.touchId ~= touchId then return false end
    local dx, dy = screenToDesign(x, y)
    ShopUI.ignoreMouseTimer = 0.5
    local moveX, moveY = dx - ShopUI.touchStartX, dy - ShopUI.touchStartY
    if ShopUI.touchScrollTarget and moveX * moveX + moveY * moveY > 64 then
        ShopUI.touchScrolling = true
        ShopUI.pressed = nil
    end
    if ShopUI.touchScrolling then
        ShopUI.scrollOffset = clamp(ShopUI.touchScrollStart - moveY, 0, ShopUI.scrollMax)
    else
        ShopUI.hovered = getHitDesign(dx, dy)
    end
    return true
end

function ShopUI.TouchEnd(touchId, x, y)
    if ShopUI.touchId ~= touchId then return nil end
    local action
    if not ShopUI.touchScrolling then
        action = ShopUI.PointerUp(x, y)
    else
        ShopUI.pressed = nil
    end
    ShopUI.touchId = nil
    ShopUI.touchScrolling = false
    ShopUI.touchScrollTarget = nil
    ShopUI.ignoreMouseTimer = 0.5
    return action
end

function ShopUI.ShouldIgnoreMouse()
    return ShopUI.touchId ~= nil or ShopUI.ignoreMouseTimer > 0
end

local function drawDesignImage(ctx, image, x, y, w, h)
    if not image or image <= 0 then return false end
    nvgBeginPath(ctx)
    nvgRect(ctx, x, y, w, h)
    nvgFillPaint(ctx, nvgImagePattern(ctx, x, y, w, h, 0, image, 1))
    nvgFill(ctx)
    return true
end

local DESIGN_CARD_SLOTS = {
    { id = "pistol", x = 258, y = 111, w = 242, h = 314 },
    { id = "shotgun", x = 505, y = 111, w = 247, h = 314 },
    { id = "pistol_ammo_box", x = 758, y = 111, w = 246, h = 314 },
    { id = "helmet_tier2", x = 258, y = 436, w = 242, h = 278 },
    { id = "armor_tier2", x = 505, y = 436, w = 247, h = 278 },
    { id = "backpack_tier2", x = 758, y = 436, w = 246, h = 278 },
}

local DESIGN_CATEGORY_RECTS = {
    guns = { x = 20, y = 121, w = 198, h = 73 },
    ammo = { x = 20, y = 204, w = 198, h = 73 },
    armor = { x = 20, y = 286, w = 198, h = 73 },
    helmets = { x = 20, y = 368, w = 198, h = 73 },
    rigs = { x = 20, y = 450, w = 198, h = 73 },
    backpacks = { x = 20, y = 532, w = 198, h = 73 },
    safe_boxes = { x = 20, y = 614, w = 198, h = 73 },
}

local function hasDesignReplica(data)
    local design = data and data.designImages
    if not design or not design.header or design.header <= 0
        or not design.categories or design.categories <= 0
        or not design.categoryButton
        or not design.categoryIcons
        or not design.cardTemplates then
        return false
    end
    return design.categoryButton.active > 0
        and design.categoryButton.inactive > 0
        and design.cardTemplates.blue > 0
end

local function drawReplicaCategoryRail(ctx, design)
    ShopUI.categoryRects = {}
    for _, category in ipairs(CATEGORIES) do
        local rect = DESIGN_CATEGORY_RECTS[category.id]
        ShopUI.categoryRects[category.id] = rect
        local active = ShopUI.selectedCategory == category.id
        local hot = ShopUI.hovered == "category:" .. category.id
            or ShopUI.pressed == "category:" .. category.id
        local buttonImage = active and design.categoryButton.active
            or design.categoryButton.inactive
        drawDesignImage(ctx, buttonImage, rect.x, rect.y, rect.w, rect.h)

        local iconTable = active and design.categoryIcons.active
            or design.categoryIcons.inactive
        local icon = iconTable and iconTable[category.id]
        drawImageContained(ctx, icon, rect.x + 22, rect.y + 12, 58, 49, 1)

        nvgFontFace(ctx, "sans")
        nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFontSize(ctx, 21)
        nvgFillColor(ctx, active and nvgRGBA(34, 29, 20, 255)
            or nvgRGBA(172, 160, 130, 255))
        nvgText(ctx, rect.x + 94, rect.y + 36, category.label)
        if hot then
            nvgBeginPath(ctx)
            nvgRect(ctx, rect.x + 2, rect.y + 2, rect.w - 4, rect.h - 4)
            nvgStrokeColor(ctx, nvgRGBA(224, 190, 102, 230))
            nvgStrokeWidth(ctx, 2)
            nvgStroke(ctx)
        end
    end
    ShopUI.categoryViewport = { x = 20, y = 121, w = 198, h = 566 }
    ShopUI.categoryHorizontal = false
    ShopUI.categoryScrollOffset = 0
    ShopUI.categoryScrollMax = 0
end

local function drawReplicaProductCard(ctx, product, rect, data, design)
    local templateKey = product.rarity == "purple" and "purple"
        or (product.rarity == "green" and "green" or "blue")
    drawDesignImage(ctx, design.cardTemplates[templateKey], rect.x, rect.y, rect.w, rect.h)

    local rarity = RARITY_COLORS[product.rarity] or RARITY_COLORS.blue
    nvgFontFace(ctx, "sans")
    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFontSize(ctx, 15)
    nvgFillColor(ctx, nvgRGBA(rarity[1] + 65, rarity[2] + 65, rarity[3] + 65, 255))
    nvgText(ctx, rect.x + 18, rect.y + 25,
        RARITY_LABELS[product.rarity] or "普通")
    nvgTextAlign(ctx, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFontSize(ctx, 16)
    nvgFillColor(ctx, nvgRGBA(194, 179, 143, 255))
    nvgText(ctx, rect.x + rect.w - 18, rect.y + 25, product.shortName)

    local imageArea = {
        x = rect.x + 18, y = rect.y + 50,
        w = rect.w - 36, h = rect.h - 111,
    }
    local imageScale = product.id == "shotgun" and 1.13 or 1
    if not drawImageContained(ctx, data.itemIcons and data.itemIcons[product.item],
        imageArea.x, imageArea.y, imageArea.w, imageArea.h, imageScale) then
        drawAmmoFallback(ctx, product.item,
            imageArea.x, imageArea.y, imageArea.w, imageArea.h)
    end

    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(ctx, 18)
    nvgFillColor(ctx, nvgRGBA(211, 171, 79, 255))
    nvgText(ctx, rect.x + rect.w * 0.5, rect.y + rect.h - 29,
        formatBitValue(product.price))

    local id = "product:" .. product.id
    local selected = ShopUI.modal and ShopUI.modal.productId == product.id
    local hot = ShopUI.hovered == id or ShopUI.pressed == id
    if selected or hot then
        local color = selected and nvgRGBA(54, 91, 106, 235)
            or nvgRGBA(133, 117, 78, 185)
        local inset = 7
        nvgBeginPath(ctx)
        nvgRect(ctx, rect.x + inset, rect.y + inset,
            rect.w - inset * 2, rect.h - inset * 2)
        nvgStrokeColor(ctx, color)
        nvgStrokeWidth(ctx, selected and 1.6 or 1.1)
        nvgStroke(ctx)
        if selected then
            local corner = 18
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, rect.x + inset, rect.y + inset + corner)
            nvgLineTo(ctx, rect.x + inset, rect.y + inset)
            nvgLineTo(ctx, rect.x + inset + corner, rect.y + inset)
            nvgMoveTo(ctx, rect.x + rect.w - inset - corner, rect.y + inset)
            nvgLineTo(ctx, rect.x + rect.w - inset, rect.y + inset)
            nvgLineTo(ctx, rect.x + rect.w - inset, rect.y + inset + corner)
            nvgMoveTo(ctx, rect.x + inset, rect.y + rect.h - inset - corner)
            nvgLineTo(ctx, rect.x + inset, rect.y + rect.h - inset)
            nvgLineTo(ctx, rect.x + inset + corner, rect.y + rect.h - inset)
            nvgMoveTo(ctx, rect.x + rect.w - inset - corner, rect.y + rect.h - inset)
            nvgLineTo(ctx, rect.x + rect.w - inset, rect.y + rect.h - inset)
            nvgLineTo(ctx, rect.x + rect.w - inset, rect.y + rect.h - inset - corner)
            nvgStrokeColor(ctx, nvgRGBA(105, 141, 151, 245))
            nvgStrokeWidth(ctx, 2.3)
            nvgStroke(ctx)
        end
    end
end

local function drawReplicaCatalog(ctx, data, design)
    local products = getProductsForCategory(ShopUI.selectedCategory)
    ShopUI.productRects = {}
    ShopUI.gridViewport = { x = 258, y = 111, w = 746, h = 603 }

    local rows = math.ceil(#products / 3)
    local contentH = rows <= 1 and 314 or (314 + 11 + 278 + math.max(0, rows - 2) * 289)
    ShopUI.scrollMax = math.max(0, contentH - ShopUI.gridViewport.h)
    ShopUI.scrollOffset = clamp(ShopUI.scrollOffset, 0, ShopUI.scrollMax)

    nvgSave(ctx)
    nvgScissor(ctx, ShopUI.gridViewport.x, ShopUI.gridViewport.y,
        ShopUI.gridViewport.w, ShopUI.gridViewport.h)
    for index = 1, math.max(6, #products) do
        local column = (index - 1) % 3
        local row = math.floor((index - 1) / 3)
        local baseSlot = DESIGN_CARD_SLOTS[(row % 2) * 3 + column + 1]
        local slotY
        if row == 0 then
            slotY = 111
        else
            slotY = 436 + (row - 1) * 289
        end
        local rect = {
            x = baseSlot.x,
            y = slotY - ShopUI.scrollOffset,
            w = baseSlot.w,
            h = row == 0 and 314 or 278,
        }
        if rect.y + rect.h >= ShopUI.gridViewport.y
            and rect.y <= ShopUI.gridViewport.y + ShopUI.gridViewport.h then
            local emptyTemplate = column == 1 and design.cardTemplates.purple
                or (column == 2 and design.cardTemplates.green or design.cardTemplates.blue)
            drawDesignImage(ctx, emptyTemplate, rect.x, rect.y, rect.w, rect.h)
            local product = products[index]
            if product then
                ShopUI.productRects[product.id] = rect
                drawReplicaProductCard(ctx, product, rect, data, design)
            end
        end
    end
    nvgRestore(ctx)
end

local function drawReplicaDetail(ctx, data, design)
    local x, y, w, h = 1015, 92, 340, 643
    drawDesignImage(ctx, design.detailFrame, x, y, w, h)
    local product = ensureSelectedProduct()
    ShopUI.modalPanelRect = { x = x, y = y, w = w, h = h }
    ShopUI.modalBackdropRect = nil
    ShopUI.modalCloseRect = nil
    ShopUI.modalBuyRect = { x = x + 25, y = y + 528, w = 273, h = 68 }
    if not product then return end

    local rarity = RARITY_COLORS[product.rarity] or RARITY_COLORS.blue
    nvgFontFace(ctx, "sans")
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(ctx, 19)
    nvgFillColor(ctx, nvgRGBA(rarity[1] + 66, rarity[2] + 66, rarity[3] + 66, 255))
    nvgText(ctx, x + w * 0.5, y + 86, product.shortName)

    local imageRect = { x = x + 36, y = y + 104, w = w - 72, h = 222 }
    local imageScale = product.id == "shotgun" and 1.08
        or ((product.id == "safe_box_tier2" or product.id == "safe_box_tier3") and 1.04 or 1)
    if not drawImageContained(ctx, data.itemIcons and data.itemIcons[product.item],
        imageRect.x, imageRect.y, imageRect.w, imageRect.h, imageScale) then
        drawAmmoFallback(ctx, product.item,
            imageRect.x, imageRect.y, imageRect.w, imageRect.h)
    end

    local detailStats = {}
    for index = 1, math.min(3, #(product.stats or {})) do
        detailStats[#detailStats + 1] = product.stats[index]
    end
    local total = 0
    for _, stat in ipairs(detailStats) do total = total + (stat.value or 0) end
    detailStats[4] = {
        label = "综合",
        value = #detailStats > 0 and math.floor(total / #detailStats + 0.5) or 0,
    }

    for index, stat in ipairs(detailStats) do
        local statY = y + 354 + (index - 1) * 27
        nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFontSize(ctx, 12)
        nvgFillColor(ctx, nvgRGBA(174, 163, 132, 245))
        nvgText(ctx, x + 27, statY, stat.label)
        local barX, barW = x + 112, 137
        nvgBeginPath(ctx)
        nvgRect(ctx, barX, statY - 4, barW, 8)
        nvgFillColor(ctx, nvgRGBA(66, 65, 54, 215))
        nvgFill(ctx)
        nvgBeginPath(ctx)
        nvgRect(ctx, barX, statY - 4,
            barW * clamp((stat.value or 0) / 100, 0, 1), 8)
        nvgFillColor(ctx, nvgRGBA(155, 151, 125, 245))
        nvgFill(ctx)
        nvgTextAlign(ctx, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        nvgFontSize(ctx, 12)
        nvgFillColor(ctx, nvgRGBA(189, 178, 145, 245))
        nvgText(ctx, x + 289, statY, tostring(stat.value or 0))
    end

    local canAfford = (tonumber(data.bits) or 0) >= product.price
    nvgTextAlign(ctx, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFontSize(ctx, 17)
    nvgFillColor(ctx, canAfford and nvgRGBA(211, 171, 79, 255)
        or nvgRGBA(142, 75, 57, 255))
    nvgText(ctx, x + 296, y + 501, formatBitValue(product.price))

    local hot = ShopUI.hovered == "modal-buy" or ShopUI.pressed == "modal-buy"
    if hot then
        nvgBeginPath(ctx)
        nvgRect(ctx, ShopUI.modalBuyRect.x + 5, ShopUI.modalBuyRect.y + 5,
            ShopUI.modalBuyRect.w - 10, ShopUI.modalBuyRect.h - 10)
        nvgStrokeColor(ctx, nvgRGBA(225, 188, 92, 225))
        nvgStrokeWidth(ctx, 1.5)
        nvgStroke(ctx)
    end
    if not canAfford then
        nvgBeginPath(ctx)
        nvgRect(ctx, ShopUI.modalBuyRect.x + 4, ShopUI.modalBuyRect.y + 4,
            ShopUI.modalBuyRect.w - 8, ShopUI.modalBuyRect.h - 8)
        nvgFillColor(ctx, nvgRGBA(48, 28, 24, 205))
        nvgFill(ctx)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFontSize(ctx, 17)
        nvgFillColor(ctx, nvgRGBA(205, 157, 112, 255))
        nvgText(ctx, x + 161, y + 562, "账户余额不足")
    end
end

local function drawDesignReplica(ctx, data)
    local design = data.designImages
    drawDesignImage(ctx, design.header, 0, 0, 1365, 95)
    drawDesignImage(ctx, design.edgeLeft, 0, 92, 5, 643)
    drawDesignImage(ctx, design.categories, 5, 92, 225, 643)
    drawReplicaCategoryRail(ctx, design)
    drawDesignImage(ctx, design.categoryGap, 230, 92, 8, 643)
    drawDesignImage(ctx, design.frameTop, 238, 92, 774, 20)
    drawDesignImage(ctx, design.frameBottom, 238, 714, 774, 21)
    drawDesignImage(ctx, design.frameLeft, 238, 92, 20, 643)
    drawDesignImage(ctx, design.frameRight, 992, 92, 20, 643)
    drawDesignImage(ctx, design.cardGapOne, 500, 111, 5, 603)
    drawDesignImage(ctx, design.cardGapTwo, 752, 111, 6, 603)
    drawDesignImage(ctx, design.cardRowGap, 258, 425, 746, 11)
    drawReplicaCatalog(ctx, data, design)

    drawDesignImage(ctx, design.detailGap, 1012, 92, 3, 643)
    drawReplicaDetail(ctx, data, design)
    drawDesignImage(ctx, design.edgeRight, 1355, 92, 10, 643)
    drawDesignImage(ctx, design.footer, 0, 735, 1365, 33)

    ShopUI.backRect = { x = 1289, y = 16, w = 61, h = 58 }
    ShopUI.modalBackdropRect = nil
    ShopUI.modalCloseRect = nil

    if ShopUI.hovered then
        local hitRect
        local productId = ShopUI.hovered:match("^product:(.+)$")
        local categoryId = ShopUI.hovered:match("^category:(.+)$")
        if productId then hitRect = ShopUI.productRects[productId]
        elseif categoryId then hitRect = ShopUI.categoryRects[categoryId]
        elseif ShopUI.hovered == "modal-buy" then hitRect = ShopUI.modalBuyRect
        elseif ShopUI.hovered == "back" then hitRect = ShopUI.backRect end
        if hitRect then
            nvgBeginPath(ctx)
            nvgRect(ctx, hitRect.x + 2, hitRect.y + 2, hitRect.w - 4, hitRect.h - 4)
            nvgStrokeColor(ctx, nvgRGBA(225, 196, 111, 210))
            nvgStrokeWidth(ctx, 2)
            nvgStroke(ctx)
        end
    end

    nvgBeginPath(ctx)
    nvgRect(ctx, 1063, 18, 208, 57)
    nvgFillColor(ctx, nvgRGBA(10, 11, 9, 248))
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(103, 83, 43, 230))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)
    drawImageContained(ctx, data.currencyIcon, 1073, 31, 31, 31, 1)
    nvgFontFace(ctx, "sans")
    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFontSize(ctx, 9)
    nvgFillColor(ctx, nvgRGBA(151, 138, 105, 245))
    nvgText(ctx, 1112, 34, "据点账户 / 比特")
    nvgFontSize(ctx, 18)
    nvgFillColor(ctx, nvgRGBA(209, 170, 83, 255))
    nvgText(ctx, 1112, 57, formatNumber(data.bits))

    drawNotice(ctx)
end

function ShopUI.Draw(ctx, width, height, data)
    data = data or {}
    local scale = math.min(width / DESIGN_W, height / DESIGN_H)
    local drawW, drawH = DESIGN_W * scale, DESIGN_H * scale
    local offsetX, offsetY = (width - drawW) * 0.5, (height - drawH) * 0.5
    ShopUI.layoutScale = scale
    ShopUI.layoutOffsetX = offsetX
    ShopUI.layoutOffsetY = offsetY

    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, width, height)
    nvgFillColor(ctx, nvgRGBA(3, 5, 5, 255))
    nvgFill(ctx)
    nvgSave(ctx)
    nvgTranslate(ctx, offsetX, offsetY)
    nvgScale(ctx, scale, scale)
    if hasDesignReplica(data) then
        drawDesignReplica(ctx, data)
    else
        drawBackground(ctx, data)
        drawHeader(ctx, data)
        drawCategoryRail(ctx)
        drawCatalog(ctx, data)
        drawDetail(ctx, data)
        drawNotice(ctx)
    end
    nvgRestore(ctx)
end

return ShopUI
