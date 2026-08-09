local HomeUI = {
    selected = "blackmarket",
    pressed = nil,
    hovered = nil,
    navRects = {},
    equipRect = nil,
    deployRect = nil,
    animTime = 0,
}

local SECTIONS = {
    {
        id = "blackmarket",
        label = "黑市",
        kicker = "BLACK MARKET / 实时报价",
        title = "雨夜收购清单",
        description = "游商将在换班前离开。优先出售高价值、小体积的稀缺物资。",
        accent = { 218, 164, 65 },
        metricLabel = "今日溢价",
        metricValue = "+18%",
        entries = {
            { name = "军用加固笔记本", meta = "收购价上浮", value = "260,000 比特" },
            { name = "显卡", meta = "需求紧张", value = "238,000 比特" },
            { name = "加密硬盘", meta = "限收 2 件", value = "28,400 比特" },
        },
    },
    {
        id = "shop",
        label = "商城",
        kicker = "SUPPLY SHOP / 战术补给",
        title = "出发前整备",
        description = "补充弹药、医疗和生存物资。每日补给会在据点换班后刷新。",
        accent = { 196, 105, 61 },
        metricLabel = "今日折扣",
        metricValue = "-12%",
        entries = {
            { name = "散弹枪弹药包", meta = "近距离火力", value = "1,800 比特" },
            { name = "野战急救包", meta = "恢复生命", value = "2,600 比特" },
            { name = "雨夜行动箱", meta = "每日限购", value = "4,900 比特" },
        },
    },
    {
        id = "character",
        label = "角色",
        kicker = "SURVIVOR / 生存档案",
        title = "幸存者 07",
        description = "检查当前装备与生存状态。负重越高，雨夜行动时的脚步声越明显。",
        accent = { 111, 163, 126 },
        metricLabel = "生存评级",
        metricValue = "B+",
        entries = {
            { name = "主武器", meta = "近距压制", value = "双管散弹枪" },
            { name = "近战", meta = "低噪清理", value = "铁丝球棒" },
            { name = "防护状态", meta = "装备完整", value = "72 / 100" },
        },
    },
    {
        id = "warehouse",
        label = "仓库",
        kicker = "STASH / 物资仓储",
        title = "据点仓库",
        description = "整理从封锁区带回的物资。稀有战利品应优先转移到安全箱。",
        accent = { 101, 145, 169 },
        metricLabel = "仓储状态",
        metricValue = "安全",
        entries = {
            { name = "战术背包", meta = "当前装备", value = "二级背包" },
            { name = "安全箱", meta = "撤离保护", value = "3 × 2 格" },
            { name = "随身口袋", meta = "快速取用", value = "6 格" },
        },
    },
    {
        id = "missions",
        label = "任务",
        kicker = "CONTRACTS / 行动委托",
        title = "今日行动目标",
        description = "完成委托可提升据点声望，并解锁更高等级的商人库存。",
        accent = { 184, 72, 67 },
        metricLabel = "行动进度",
        metricValue = "1 / 3",
        entries = {
            { name = "雨中来客", meta = "进入居民楼", value = "进行中" },
            { name = "旧时代零件", meta = "带回 3 件电子物资", value = "0 / 3" },
            { name = "清理街区", meta = "击败 5 名感染者", value = "2 / 5" },
        },
    },
    {
        id = "codex",
        label = "图鉴",
        kicker = "CODEX / 物资百科",
        title = "物资图鉴",
        description = "查阅所有可在封锁区搜刮到的物资信息，了解它们的价值和稀有度。",
        accent = { 160, 130, 70 },
        metricLabel = "已收录",
        metricValue = "ALL",
        entries = {
            { name = "传说物资", meta = "最高价值", value = "红色品质" },
            { name = "史诗物资", meta = "稀缺掉落", value = "粉色品质" },
            { name = "金色收藏", meta = "稳定保值", value = "金色品质" },
        },
    },
}

local SECTION_BY_ID = {}
for _, section in ipairs(SECTIONS) do
    SECTION_BY_ID[section.id] = section
end

local function rgba(color, alpha)
    return nvgRGBA(color[1], color[2], color[3], alpha or 255)
end

local function clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

local function pointInRect(x, y, rect)
    return rect and x >= rect.x and x <= rect.x + rect.w
        and y >= rect.y and y <= rect.y + rect.h
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

local function drawPanel(ctx, x, y, w, h, accent, active, alpha, hideAccentLine)
    alpha = alpha or 255
    beginCutRect(ctx, x, y, w, h, 9)
    local fill = nvgLinearGradient(ctx, x, y, x, y + h,
        nvgRGBA(27, 31, 36, math.floor(alpha * 0.97)),
        nvgRGBA(13, 16, 20, math.floor(alpha * 0.98)))
    nvgFillPaint(ctx, fill)
    nvgFill(ctx)

    beginCutRect(ctx, x, y, w, h, 9)
    nvgStrokeColor(ctx, active and rgba(accent, alpha) or nvgRGBA(76, 82, 88, math.floor(alpha * 0.72)))
    nvgStrokeWidth(ctx, active and 1.8 or 1)
    nvgStroke(ctx)

    if active and not hideAccentLine then
        nvgBeginPath(ctx)
        nvgRect(ctx, x + 1, y + 1, math.max(28, w * 0.28), 2)
        nvgFillColor(ctx, rgba(accent, alpha))
        nvgFill(ctx)
    end
end

local function drawIcon(ctx, id, cx, cy, size, color)
    local s = size * 0.5
    nvgStrokeColor(ctx, rgba(color, 240))
    nvgFillColor(ctx, rgba(color, 240))
    nvgStrokeWidth(ctx, math.max(1.4, size * 0.075))

    if id == "blackmarket" then
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, cx - s, cy)
        nvgBezierTo(ctx, cx - s * 0.45, cy - s * 0.65, cx + s * 0.45, cy - s * 0.65, cx + s, cy)
        nvgBezierTo(ctx, cx + s * 0.45, cy + s * 0.65, cx - s * 0.45, cy + s * 0.65, cx - s, cy)
        nvgStroke(ctx)
        nvgBeginPath(ctx)
        nvgCircle(ctx, cx, cy, s * 0.26)
        nvgFill(ctx)
    elseif id == "shop" then
        nvgBeginPath(ctx)
        nvgRect(ctx, cx - s * 0.7, cy - s * 0.34, s * 1.4, s * 1.05)
        nvgStroke(ctx)
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, cx - s * 0.38, cy - s * 0.36)
        nvgBezierTo(ctx, cx - s * 0.35, cy - s, cx + s * 0.35, cy - s, cx + s * 0.38, cy - s * 0.36)
        nvgStroke(ctx)
    elseif id == "character" then
        nvgBeginPath(ctx)
        nvgCircle(ctx, cx, cy - s * 0.38, s * 0.3)
        nvgStroke(ctx)
        nvgBeginPath(ctx)
        nvgArc(ctx, cx, cy + s * 0.72, s * 0.68, math.pi * 1.12, math.pi * 1.88, NVG_CW)
        nvgStroke(ctx)
    elseif id == "warehouse" then
        nvgBeginPath(ctx)
        nvgRect(ctx, cx - s * 0.72, cy - s * 0.62, s * 1.44, s * 1.28)
        nvgStroke(ctx)
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, cx - s * 0.72, cy - s * 0.2)
        nvgLineTo(ctx, cx + s * 0.72, cy - s * 0.2)
        nvgMoveTo(ctx, cx, cy - s * 0.62)
        nvgLineTo(ctx, cx, cy + s * 0.66)
        nvgStroke(ctx)
    elseif id == "codex" then
        -- Open book icon
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, cx, cy - s * 0.6)
        nvgLineTo(ctx, cx, cy + s * 0.7)
        nvgStroke(ctx)
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, cx, cy - s * 0.6)
        nvgBezierTo(ctx, cx - s * 0.3, cy - s * 0.7, cx - s * 0.8, cy - s * 0.5, cx - s * 0.8, cy - s * 0.3)
        nvgLineTo(ctx, cx - s * 0.8, cy + s * 0.55)
        nvgBezierTo(ctx, cx - s * 0.8, cy + s * 0.7, cx - s * 0.3, cy + s * 0.6, cx, cy + s * 0.7)
        nvgStroke(ctx)
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, cx, cy - s * 0.6)
        nvgBezierTo(ctx, cx + s * 0.3, cy - s * 0.7, cx + s * 0.8, cy - s * 0.5, cx + s * 0.8, cy - s * 0.3)
        nvgLineTo(ctx, cx + s * 0.8, cy + s * 0.55)
        nvgBezierTo(ctx, cx + s * 0.8, cy + s * 0.7, cx + s * 0.3, cy + s * 0.6, cx, cy + s * 0.7)
        nvgStroke(ctx)
    else
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, cx - s * 0.62, cy - s * 0.72, s * 1.24, s * 1.44, 2)
        nvgStroke(ctx)
        for i = 0, 2 do
            local lineY = cy - s * 0.34 + i * s * 0.42
            nvgBeginPath(ctx)
            nvgCircle(ctx, cx - s * 0.32, lineY, 1.3)
            nvgFill(ctx)
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, cx - s * 0.12, lineY)
            nvgLineTo(ctx, cx + s * 0.38, lineY)
            nvgStroke(ctx)
        end
    end
end

local function drawTopBar(ctx, width, height, data)
    local headerH = clamp(height * 0.085, 54, 72)
    local headerGrad = nvgLinearGradient(ctx, 0, 0, 0, headerH,
        nvgRGBA(9, 11, 14, 248), nvgRGBA(18, 20, 23, 220))
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, width, headerH)
    nvgFillPaint(ctx, headerGrad)
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, headerH - 1, width, 1)
    nvgFillColor(ctx, nvgRGBA(151, 113, 48, 155))
    nvgFill(ctx)

    nvgFontFace(ctx, "sans")
    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFontSize(ctx, clamp(width * 0.040, 20, 28))
    nvgFillColor(ctx, nvgRGBA(232, 209, 157, 255))
    nvgText(ctx, 18, headerH * 0.34, "末世搜寻")
    nvgFontSize(ctx, clamp(width * 0.016, 8, 11))
    nvgFillColor(ctx, nvgRGBA(123, 132, 137, 235))
    nvgText(ctx, 20, headerH * 0.79, "封锁区行动终端  /  SHELTER-07")

    local bits = tostring(data.bits or "12,840") .. " 比特"
    local chipW = width < 560 and 112 or 132
    local chipH = 30
    local chipX = width - chipW - 16
    local chipY = (headerH - chipH) * 0.5
    beginCutRect(ctx, chipX, chipY, chipW, chipH, 6)
    nvgFillColor(ctx, nvgRGBA(31, 29, 23, 245))
    nvgFill(ctx)
    beginCutRect(ctx, chipX, chipY, chipW, chipH, 6)
    nvgStrokeColor(ctx, nvgRGBA(170, 128, 51, 180))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)
    nvgBeginPath(ctx)
    nvgCircle(ctx, chipX + 17, chipY + chipH * 0.5, 6)
    nvgFillColor(ctx, nvgRGBA(218, 164, 65, 255))
    nvgFill(ctx)
    nvgFontSize(ctx, 11)
    nvgTextAlign(ctx, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFillColor(ctx, nvgRGBA(231, 220, 194, 255))
    nvgText(ctx, chipX + chipW - 10, chipY + chipH * 0.5, bits)

    return headerH
end

local function drawAtmosphere(ctx, width, height, time)
    local bg = nvgLinearGradient(ctx, 0, 0, width, height,
        nvgRGBA(24, 29, 32, 255), nvgRGBA(8, 10, 13, 255))
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, width, height)
    nvgFillPaint(ctx, bg)
    nvgFill(ctx)

    local glow = nvgRadialGradient(ctx, width * 0.72, height * 0.28, 5, width * 0.6,
        nvgRGBA(141, 93, 43, 72), nvgRGBA(20, 24, 28, 0))
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, width, height)
    nvgFillPaint(ctx, glow)
    nvgFill(ctx)

    local offset = (time * 190) % 54
    nvgStrokeWidth(ctx, 1)
    for x = -height, width + height, 38 do
        local rainX = x + offset
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, rainX, 0)
        nvgLineTo(ctx, rainX - height * 0.16, height)
        nvgStrokeColor(ctx, nvgRGBA(104, 126, 136, 15))
        nvgStroke(ctx)
    end

    nvgBeginPath(ctx)
    nvgRect(ctx, 0, height * 0.78, width, height * 0.22)
    local ground = nvgLinearGradient(ctx, 0, height * 0.78, 0, height,
        nvgRGBA(19, 20, 21, 0), nvgRGBA(4, 5, 7, 190))
    nvgFillPaint(ctx, ground)
    nvgFill(ctx)
end

local function drawHero(ctx, x, y, w, h, section, data)
    drawPanel(ctx, x, y, w, h, section.accent, false, 235)

    local portraitW = math.min(w * 0.42, h * 0.56)
    local portraitX = x + w - portraitW - 6
    local portraitY = y + 6
    local portraitH = h - 12

    local silhouette = nvgRadialGradient(ctx,
        portraitX + portraitW * 0.55, portraitY + portraitH * 0.55,
        6, math.max(portraitW, portraitH) * 0.62,
        rgba(section.accent, 52), nvgRGBA(5, 7, 9, 0))
    nvgBeginPath(ctx)
    nvgRect(ctx, portraitX, portraitY, portraitW, portraitH)
    nvgFillPaint(ctx, silhouette)
    nvgFill(ctx)

    if data.playerImage and data.playerImage > 0 then
        local imageH = portraitH * 0.94
        local imageW = imageH * 0.67
        local imageX = portraitX + (portraitW - imageW) * 0.5
        local imageY = portraitY + portraitH - imageH
        nvgSave(ctx)
        nvgScissor(ctx, portraitX, portraitY, portraitW, portraitH)
        local paint = nvgImagePatternTinted(ctx, imageX, imageY, imageW, imageH, 0,
            data.playerImage, nvgRGBA(208, 213, 207, 238))
        nvgBeginPath(ctx)
        nvgRect(ctx, imageX, imageY, imageW, imageH)
        nvgFillPaint(ctx, paint)
        nvgFill(ctx)
        nvgRestore(ctx)
    else
        nvgBeginPath(ctx)
        nvgCircle(ctx, portraitX + portraitW * 0.55, portraitY + portraitH * 0.35, portraitW * 0.13)
        nvgFillColor(ctx, nvgRGBA(54, 60, 62, 255))
        nvgFill(ctx)
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, portraitX + portraitW * 0.30, portraitY + portraitH * 0.48,
            portraitW * 0.5, portraitH * 0.50, 8)
        nvgFillColor(ctx, nvgRGBA(45, 51, 52, 255))
        nvgFill(ctx)
    end

    local textW = w - portraitW - 24
    nvgFontFace(ctx, "sans")
    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFontSize(ctx, clamp(w * 0.028, 10, 14))
    nvgFillColor(ctx, rgba(section.accent, 245))
    nvgText(ctx, x + 14, y + 15, "据点状态：安全  /  雨势：中等")

    nvgFontSize(ctx, clamp(w * 0.076, 28, 48))
    nvgFillColor(ctx, nvgRGBA(236, 231, 216, 255))
    nvgText(ctx, x + 14, y + 38, "准备进入")
    nvgFontSize(ctx, clamp(w * 0.070, 25, 43))
    nvgFillColor(ctx, nvgRGBA(214, 167, 79, 255))
    nvgText(ctx, x + 14, y + 76, "封锁区")

    nvgFontSize(ctx, clamp(w * 0.025, 9, 12))
    nvgFillColor(ctx, nvgRGBA(139, 148, 150, 245))
    nvgTextBox(ctx, x + 14, y + 120, math.max(110, textW - 8),
        "搜索废弃建筑，带回物资，并在天黑前找到撤离路线。")

    local buttonH = clamp(h * 0.22, 42, 56)
    local buttonGap = 8
    local buttonW = math.max(72, math.min((textW - buttonGap - 4) * 0.5, 104))
    local buttonX = x + 14
    local buttonY = y + h - buttonH - 14
    HomeUI.equipRect = { x = buttonX, y = buttonY, w = buttonW, h = buttonH }
    HomeUI.deployRect = { x = buttonX + buttonW + buttonGap, y = buttonY, w = buttonW, h = buttonH }
    local pulse = 0.5 + 0.5 * math.sin(HomeUI.animTime * 2.4)

    local function drawActionButton(rect, id, label, primary)
        local active = HomeUI.hovered == id or HomeUI.pressed == id
        if primary then
            beginCutRect(ctx, rect.x - 4, rect.y - 4, rect.w + 8, rect.h + 8, 10)
            nvgFillColor(ctx, nvgRGBA(218, 164, 65, math.floor(12 + pulse * 16)))
            nvgFill(ctx)
        end
        beginCutRect(ctx, rect.x, rect.y, rect.w, rect.h, 8)
        local topColor
        local bottomColor
        if primary then
            topColor = active and nvgRGBA(189, 137, 49, 255) or nvgRGBA(157, 111, 39, 255)
            bottomColor = nvgRGBA(87, 59, 23, 255)
        else
            topColor = active and nvgRGBA(68, 88, 99, 255) or nvgRGBA(48, 61, 69, 255)
            bottomColor = nvgRGBA(24, 31, 36, 255)
        end
        local gradient = nvgLinearGradient(ctx, rect.x, rect.y, rect.x, rect.y + rect.h, topColor, bottomColor)
        nvgFillPaint(ctx, gradient)
        nvgFill(ctx)
        beginCutRect(ctx, rect.x, rect.y, rect.w, rect.h, 8)
        nvgStrokeColor(ctx, primary and nvgRGBA(232, 193, 111, 230) or nvgRGBA(132, 163, 178, 220))
        nvgStrokeWidth(ctx, 1.4)
        nvgStroke(ctx)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFontSize(ctx, clamp(rect.h * 0.34, 13, 17))
        nvgFillColor(ctx, nvgRGBA(253, 245, 222, 255))
        nvgText(ctx, rect.x + rect.w * 0.5, rect.y + rect.h * 0.48, label)
    end

    drawActionButton(HomeUI.equipRect, "equip", "装备", false)
    drawActionButton(HomeUI.deployRect, "deploy", "出战", true)
end

local function drawSectionDetail(ctx, x, y, w, h, section, data)
    drawPanel(ctx, x, y, w, h, section.accent, true, 242, true)

    local pad = clamp(w * 0.045, 12, 22)
    nvgFontFace(ctx, "sans")
    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFontSize(ctx, clamp(w * 0.023, 8, 11))
    nvgFillColor(ctx, rgba(section.accent, 238))
    nvgText(ctx, x + pad, y + pad, section.kicker)
    nvgFontSize(ctx, clamp(w * 0.055, 20, 30))
    nvgFillColor(ctx, nvgRGBA(231, 229, 219, 255))
    nvgText(ctx, x + pad, y + pad + 22, section.title)

    local metricW = clamp(w * 0.24, 78, 112)
    local metricH = 44
    local metricX = x + w - metricW - pad
    local metricY = y + pad
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, metricX, metricY, metricW, metricH, 4)
    nvgFillColor(ctx, nvgRGBA(9, 12, 14, 210))
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgRect(ctx, metricX, metricY, 2, metricH)
    nvgFillColor(ctx, rgba(section.accent, 255))
    nvgFill(ctx)
    nvgTextAlign(ctx, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    nvgFontSize(ctx, 8)
    nvgFillColor(ctx, nvgRGBA(116, 124, 128, 240))
    nvgText(ctx, metricX + metricW - 7, metricY + 6, section.metricLabel)
    nvgFontSize(ctx, 16)
    nvgFillColor(ctx, rgba(section.accent, 255))
    nvgText(ctx, metricX + metricW - 7, metricY + 20, section.metricValue)

    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFontSize(ctx, clamp(w * 0.025, 9, 12))
    nvgFillColor(ctx, nvgRGBA(142, 150, 152, 245))
    nvgTextBox(ctx, x + pad, y + pad + 58, w - pad * 2, section.description)

    local listTop = y + clamp(h * 0.39, 92, 124)
    local listBottom = y + h - pad
    local rowGap = 5
    local rowH = math.max(28, (listBottom - listTop - rowGap * 2) / 3)
    for index, entry in ipairs(section.entries) do
        local rowY = listTop + (index - 1) * (rowH + rowGap)
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, x + pad, rowY, w - pad * 2, rowH, 3)
        nvgFillColor(ctx, index == 1 and nvgRGBA(34, 34, 31, 238) or nvgRGBA(19, 22, 25, 228))
        nvgFill(ctx)
        nvgBeginPath(ctx)
        nvgRect(ctx, x + pad, rowY, 2, rowH)
        nvgFillColor(ctx, rgba(section.accent, index == 1 and 235 or 110))
        nvgFill(ctx)

        nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFontSize(ctx, clamp(rowH * 0.26, 9, 12))
        nvgFillColor(ctx, nvgRGBA(220, 218, 208, 250))
        nvgText(ctx, x + pad + 10, rowY + rowH * 0.40, entry.name)
        nvgFontSize(ctx, clamp(rowH * 0.20, 7, 9))
        nvgFillColor(ctx, nvgRGBA(105, 113, 117, 240))
        nvgText(ctx, x + pad + 10, rowY + rowH * 0.72, entry.meta)

        nvgTextAlign(ctx, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        nvgFontSize(ctx, clamp(rowH * 0.24, 8, 11))
        nvgFillColor(ctx, rgba(section.accent, 245))
        nvgText(ctx, x + w - pad - 9, rowY + rowH * 0.5, entry.value)
    end

    if section.id == "warehouse" then
        local used = data.inventoryCount or 3
        local capacity = math.max(1, data.inventoryCapacity or 12)
        local ratio = clamp(used / capacity, 0, 1)
        local barW = w - pad * 2
        local barY = y + h - 5
        nvgBeginPath(ctx)
        nvgRect(ctx, x + pad, barY, barW * ratio, 2)
        nvgFillColor(ctx, rgba(section.accent, 220))
        nvgFill(ctx)
    end
end

local function drawBottomNavigation(ctx, width, height, navH)
    local pad = 8
    local gap = width < 520 and 4 or 7
    local navY = height - navH
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, navY - 8, width, navH + 8)
    local navGrad = nvgLinearGradient(ctx, 0, navY - 8, 0, height,
        nvgRGBA(12, 14, 17, 215), nvgRGBA(5, 7, 9, 252))
    nvgFillPaint(ctx, navGrad)
    nvgFill(ctx)

    local itemW = (width - pad * 2 - gap * (#SECTIONS - 1)) / #SECTIONS
    local itemH = navH - 12
    HomeUI.navRects = {}

    for index, section in ipairs(SECTIONS) do
        local itemX = pad + (index - 1) * (itemW + gap)
        local itemY = navY + 4
        local active = HomeUI.selected == section.id
        local interactive = HomeUI.hovered == section.id or HomeUI.pressed == section.id
        HomeUI.navRects[section.id] = { x = itemX, y = itemY, w = itemW, h = itemH }
        drawPanel(ctx, itemX, itemY, itemW, itemH, section.accent, active, interactive and 255 or 228, true)

        local iconSize = clamp(itemH * 0.29, 18, 25)
        drawIcon(ctx, section.id, itemX + itemW * 0.5, itemY + itemH * 0.35,
            iconSize, active and section.accent or { 123, 131, 134 })
        nvgFontFace(ctx, "sans")
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFontSize(ctx, clamp(itemW * 0.18, 10, 13))
        nvgFillColor(ctx, active and nvgRGBA(236, 224, 197, 255) or nvgRGBA(138, 145, 147, 245))
        nvgText(ctx, itemX + itemW * 0.5, itemY + itemH * 0.73, section.label)
    end
end

function HomeUI.Reset()
    HomeUI.selected = "blackmarket"
    HomeUI.pressed = nil
    HomeUI.hovered = nil
    HomeUI.navRects = {}
    HomeUI.equipRect = nil
    HomeUI.deployRect = nil
    HomeUI.animTime = 0
end

function HomeUI.Update(dt)
    HomeUI.animTime = HomeUI.animTime + (dt or 0)
end

function HomeUI.GetHit(x, y)
    if pointInRect(x, y, HomeUI.equipRect) then return "equip" end
    if pointInRect(x, y, HomeUI.deployRect) then return "deploy" end
    for _, section in ipairs(SECTIONS) do
        if pointInRect(x, y, HomeUI.navRects[section.id]) then
            return section.id
        end
    end
    return nil
end

function HomeUI.PointerMove(x, y)
    HomeUI.hovered = HomeUI.GetHit(x, y)
end

function HomeUI.PointerDown(x, y)
    HomeUI.pressed = HomeUI.GetHit(x, y)
    return HomeUI.pressed
end

function HomeUI.PointerUp(x, y)
    local hit = HomeUI.GetHit(x, y)
    local activated = hit and hit == HomeUI.pressed and hit or nil
    HomeUI.pressed = nil
    if activated and activated ~= "equip" and activated ~= "deploy" then
        HomeUI.selected = activated
    end
    return activated
end

function HomeUI.Draw(ctx, width, height, time, data)
    data = data or {}
    local section = SECTION_BY_ID[HomeUI.selected] or SECTIONS[1]
    HomeUI.equipRect = nil
    HomeUI.deployRect = nil

    drawAtmosphere(ctx, width, height, time or HomeUI.animTime)
    local headerH = drawTopBar(ctx, width, height, data)
    local navH = clamp(height * 0.12, 76, 96)
    local mainX = clamp(width * 0.025, 10, 22)
    local mainY = headerH + 10
    local mainW = width - mainX * 2
    local mainH = height - mainY - navH - 12
    local gap = clamp(width * 0.018, 7, 14)

    if width / math.max(1, height) >= 1.15 then
        local heroW = mainW * 0.43
        drawHero(ctx, mainX, mainY, heroW, mainH, section, data)
        drawSectionDetail(ctx, mainX + heroW + gap, mainY,
            mainW - heroW - gap, mainH, section, data)
    else
        local heroH = mainH * 0.44
        drawHero(ctx, mainX, mainY, mainW, heroH, section, data)
        drawSectionDetail(ctx, mainX, mainY + heroH + gap,
            mainW, mainH - heroH - gap, section, data)
    end

    drawBottomNavigation(ctx, width, height, navH)
end

return HomeUI
