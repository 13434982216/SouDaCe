local Currency = require "Currency"

local HomeUI = {
    selected = "blackmarket",
    pressed = nil,
    hovered = nil,
    navRects = {},
    topRects = {},
    equipRect = nil,
    deployRect = nil,
    changeMapRect = nil,
    animTime = 0,
    notice = nil,
    noticeTimer = 0,
}

local DESIGN_W = 1365
local DESIGN_H = 768

local SECTIONS = {
    { id = "blackmarket", x = 13, w = 110 },
    { id = "shop", x = 128, w = 121 },
    { id = "character", x = 253, w = 121 },
    { id = "warehouse", x = 378, w = 121 },
    { id = "missions", x = 503, w = 121 },
    { id = "codex", x = 628, w = 121 },
}

local TOP_ACTIONS = {
    { id = "settings", x = 1178 },
    { id = "mail", x = 1241 },
    { id = "notes", x = 1304 },
}

local COLORS = {
    paper = { 221, 211, 183 },
    gold = { 217, 169, 74 },
    red = { 197, 70, 57 },
    statusText = { 128, 111, 79 },
}

local function rgba(color, alpha)
    return nvgRGBA(color[1], color[2], color[3], alpha or 255)
end

local function pointInRect(x, y, rect)
    return rect and x >= rect.x and x <= rect.x + rect.w
        and y >= rect.y and y <= rect.y + rect.h
end

local function setScreenRect(offsetX, offsetY, scale, x, y, w, h)
    return {
        x = offsetX + x * scale,
        y = offsetY + y * scale,
        w = w * scale,
        h = h * scale,
    }
end

local function drawImage(ctx, image, x, y, w, h, sourceRatio, mode, alpha, tint)
    if not image or image <= 0 or w <= 0 or h <= 0 then return false end
    local frameRatio = w / math.max(h, 1)
    local drawW, drawH
    if mode == "contain" then
        if frameRatio > sourceRatio then
            drawH = h
            drawW = drawH * sourceRatio
        else
            drawW = w
            drawH = drawW / sourceRatio
        end
    elseif frameRatio > sourceRatio then
        drawW = w
        drawH = drawW / sourceRatio
    else
        drawH = h
        drawW = drawH * sourceRatio
    end
    local drawX = x + (w - drawW) * 0.5
    local drawY = y + (h - drawH) * 0.5
    nvgSave(ctx)
    nvgScissor(ctx, x, y, w, h)
    local paint
    if tint then
        paint = nvgImagePatternTinted(ctx, drawX, drawY, drawW, drawH,
            0, image, tint)
    else
        paint = nvgImagePattern(ctx, drawX, drawY, drawW, drawH,
            0, image, alpha or 1.0)
    end
    nvgBeginPath(ctx)
    nvgRect(ctx, drawX, drawY, drawW, drawH)
    nvgFillPaint(ctx, paint)
    nvgFill(ctx)
    nvgRestore(ctx)
    return true
end

local function drawMasterCrop(ctx, master, sx, sy, sw, sh, x, y, w, h, tint)
    if not master or master <= 0 then return false end
    nvgSave(ctx)
    nvgScissor(ctx, x, y, w, h)
    local scaleX = w / sw
    local scaleY = h / sh
    local imageX = x - sx * scaleX
    local imageY = y - sy * scaleY
    local imageW = DESIGN_W * scaleX
    local imageH = DESIGN_H * scaleY
    local paint
    if tint then
        paint = nvgImagePatternTinted(ctx, imageX, imageY, imageW, imageH,
            0, master, tint)
    else
        paint = nvgImagePattern(ctx, imageX, imageY, imageW, imageH,
            0, master, 1.0)
    end
    nvgBeginPath(ctx)
    nvgRect(ctx, x, y, w, h)
    nvgFillPaint(ctx, paint)
    nvgFill(ctx)
    nvgRestore(ctx)
    return true
end

local function actionState(id)
    if HomeUI.pressed == id then return "pressed" end
    if HomeUI.hovered == id then return "hover" end
    return "normal"
end

local function interactiveTint(id)
    local state = actionState(id)
    if state == "pressed" then return nvgRGBA(182, 170, 140, 255) end
    if state == "hover" then return nvgRGBA(255, 238, 195, 255) end
    return nil
end

local function drawInteractionOutline(ctx, id, rect, color)
    local state = actionState(id)
    if state == "normal" then return end
    nvgBeginPath(ctx)
    nvgRect(ctx, rect.x + 2, rect.y + 2, rect.w - 4, rect.h - 4)
    nvgFillColor(ctx, nvgRGBA(color[1], color[2], color[3],
        state == "pressed" and 25 or 13))
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(color[1], color[2], color[3],
        state == "pressed" and 230 or 175))
    nvgStrokeWidth(ctx, 1.5)
    nvgStroke(ctx)
end

local function drawTopStatusCard(ctx, background, x, width)
    drawImage(ctx, background, x, 14, width, 42,
        150 / 40, "cover", 1.0)
end

local function drawTopStatusText(ctx, text, cardX, cardWidth, textStartX)
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgText(ctx, textStartX + (cardX + cardWidth - textStartX) * 0.5,
        35, text)
end

local function drawTopStatusCards(ctx, data, layers)
    local shelterX, currencyX, survivorsX = 652, 827, 1004
    local shelterW, currencyW, survivorsW = 162, 162, 159
    drawTopStatusCard(ctx, layers.topChip, shelterX, shelterW)
    drawTopStatusCard(ctx, layers.topChip, currencyX, currencyW)
    drawTopStatusCard(ctx, layers.topChip, survivorsX, survivorsW)

    drawImage(ctx, layers.shelterStatusIcon, shelterX + 7, 19, 28, 32,
        28 / 32, "contain", 1.0)
    drawImage(ctx, data.currencyIcon, currencyX + 4, 17, 36, 36,
        1, "contain", 1.0)
    drawImage(ctx, layers.survivorStatusIcon, survivorsX + 7, 19, 28, 32,
        28 / 32, "contain", 1.0)

    nvgFontFace(ctx, "sans")
    nvgFontSize(ctx, 17)
    nvgFillColor(ctx, rgba(COLORS.statusText))
    drawTopStatusText(ctx,
        "据点等级  " .. tostring(data.shelterLevel or 0),
        shelterX, shelterW, shelterX + 45)
    drawTopStatusText(ctx, Currency.FormatNumber(data.bits),
        currencyX, currencyW, currencyX + 48)
    drawTopStatusText(ctx, tostring(data.survivorCount or "0 / 0"),
        survivorsX, survivorsW, survivorsX + 45)
end

local function drawMapSelection(ctx, selectedMap)
    selectedMap = selectedMap or {}
    local centerX = 255 + (selectedMap.mapX or 0.455) * 396
    local centerY = 128 + (selectedMap.mapY or 0.676) * 498
    local pulse = (math.sin(HomeUI.animTime * 3.0) + 1.0) * 0.5
    local scale = 0.88 + pulse * 0.20
    local halfW, halfH = 26 * scale, 26 * scale
    local corner = 11 * scale
    local left, top = centerX - halfW, centerY - halfH
    local right, bottom = centerX + halfW, centerY + halfH

    nvgSave(ctx)
    nvgBeginPath(ctx)
    nvgCircle(ctx, centerX, centerY, 20 + pulse * 9)
    nvgFillColor(ctx, nvgRGBA(217, 169, 74,
        9 + math.floor(pulse * 12)))
    nvgFill(ctx)

    nvgBeginPath(ctx)
    nvgMoveTo(ctx, left, top + corner)
    nvgLineTo(ctx, left, top)
    nvgLineTo(ctx, left + corner, top)
    nvgMoveTo(ctx, right - corner, top)
    nvgLineTo(ctx, right, top)
    nvgLineTo(ctx, right, top + corner)
    nvgMoveTo(ctx, right, bottom - corner)
    nvgLineTo(ctx, right, bottom)
    nvgLineTo(ctx, right - corner, bottom)
    nvgMoveTo(ctx, left + corner, bottom)
    nvgLineTo(ctx, left, bottom)
    nvgLineTo(ctx, left, bottom - corner)
    nvgStrokeColor(ctx, nvgRGBA(221, 170, 64,
        155 + math.floor(pulse * 90)))
    nvgStrokeWidth(ctx, 2.0 + pulse * 0.8)
    nvgStroke(ctx)

    local label = tostring(selectedMap.shortName or selectedMap.name or "")
    if label ~= "" then
        nvgFontFace(ctx, "sans")
        nvgFontSize(ctx, 16)
        local labelW = math.max(58, (nvgTextBounds(ctx, 0, 0, label) or 0) + 22)
        local labelH = 27
        local labelX = centerX - labelW * 0.5
        local labelY = bottom + 8
        nvgBeginPath(ctx)
        nvgRect(ctx, labelX, labelY, labelW, labelH)
        nvgFillColor(ctx, nvgRGBA(13, 16, 13, 232))
        nvgFill(ctx)
        nvgStrokeColor(ctx, nvgRGBA(221, 170, 64, 225))
        nvgStrokeWidth(ctx, 1.2)
        nvgStroke(ctx)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(ctx, nvgRGBA(232, 213, 166, 255))
        nvgText(ctx, centerX, labelY + labelH * 0.5, label)
    end
    nvgRestore(ctx)
end

local function drawNationalMap(ctx, layers, selectedMap)
    nvgSave(ctx)
    nvgScissor(ctx, 232, 74, 428, 543)
    local drawn = drawImage(ctx, layers.nationalMapClean,
        255, 128, 396, 498, 396 / 498, "contain", 1.0)
    nvgRestore(ctx)
    if not drawn then return false end
    drawMapSelection(ctx, selectedMap)
    return true
end

local function drawSelectedMapInfo(ctx, selectedMap)
    selectedMap = selectedMap or {}
    local panelColor = nvgRGBA(14, 18, 15, 250)
    local coverRects = {
        { x = 680, y = 84, w = 662, h = 45 },
        { x = 729, y = 365, w = 257, h = 59 },
        { x = 1057, y = 365, w = 277, h = 59 },
        { x = 729, y = 438, w = 257, h = 66 },
        { x = 1057, y = 438, w = 277, h = 66 },
        { x = 729, y = 519, w = 257, h = 75 },
    }
    for _, rect in ipairs(coverRects) do
        nvgBeginPath(ctx)
        nvgRect(ctx, rect.x, rect.y, rect.w, rect.h)
        nvgFillColor(ctx, panelColor)
        nvgFill(ctx)
    end

    nvgFontFace(ctx, "sans")
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(ctx, 25)
    nvgFillColor(ctx, nvgRGBA(221, 170, 67, 255))
    nvgText(ctx, 1011, 107,
        "已选地图 | " .. tostring(selectedMap.name or "大阪临港工业区"))

    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFontSize(ctx, 14)
    nvgFillColor(ctx, nvgRGBA(152, 148, 126, 255))
    nvgText(ctx, 733, 370, "危险等级")
    nvgText(ctx, 1061, 370, "天气")
    nvgText(ctx, 733, 443, "主要任务")
    nvgText(ctx, 1061, 443, "尸潮时间")
    nvgText(ctx, 733, 524, "预估收益")

    nvgFontSize(ctx, 20)
    nvgFillColor(ctx, nvgRGBA(197, 70, 57, 255))
    nvgText(ctx, 733, 393, tostring(selectedMap.danger or "中高危"))
    nvgFontSize(ctx, 16)
    nvgFillColor(ctx, nvgRGBA(190, 185, 161, 255))
    nvgText(ctx, 1061, 394, tostring(selectedMap.weather or "强风 / 阵雨"))
    nvgTextBox(ctx, 733, 465, 250,
        tostring(selectedMap.mission or "搜索港区仓储与工业物资"))
    nvgFontSize(ctx, 20)
    nvgFillColor(ctx, nvgRGBA(185, 78, 60, 255))
    nvgText(ctx, 1061, 465, tostring(selectedMap.tideTime or "22:00"))
    nvgFontSize(ctx, 18)
    nvgFillColor(ctx, nvgRGBA(217, 169, 74, 255))
    nvgText(ctx, 733, 551, tostring(selectedMap.reward or "16,000 - 25,000 比特"))
end

local function drawTopIcons(ctx, master)
    for _, action in ipairs(TOP_ACTIONS) do
        local rect = { x = action.x, y = 14, w = 52, h = 42 }
        drawMasterCrop(ctx, master, action.x, 14, 52, 42,
            rect.x, rect.y, rect.w, rect.h, interactiveTint(action.id))
        drawInteractionOutline(ctx, action.id, rect, COLORS.gold)
    end
end

local function drawPressedCrop(ctx, master, id, x, y, w, h)
    local pressedScale = HomeUI.pressed == id and 0.94 or 1.0
    local drawW = w * pressedScale
    local drawH = h * pressedScale
    local drawX = x + (w - drawW) * 0.5
    local drawY = y + (h - drawH) * 0.5
    drawMasterCrop(ctx, master, x, y, w, h,
        drawX, drawY, drawW, drawH, interactiveTint(id))
end

local function drawBottom(ctx, master)
    for _, section in ipairs(SECTIONS) do
        drawPressedCrop(ctx, master, section.id,
            section.x, 642, section.w, 114)
    end

    -- 底部操作按钮按中心缩小，保留设计稿原始外观且不绘制交互边框。
    drawPressedCrop(ctx, master, "equip", 752, 628, 262, 136)
    drawPressedCrop(ctx, master, "deploy", 1018, 628, 340, 136)
end

local function drawNotice(ctx)
    if not HomeUI.notice or HomeUI.noticeTimer <= 0 then return end
    local w, h = 420, 46
    local x, y = (DESIGN_W - w) * 0.5, 68
    nvgBeginPath(ctx)
    nvgRect(ctx, x, y, w, h)
    nvgFillColor(ctx, nvgRGBA(14, 17, 14, 246))
    nvgFill(ctx)
    nvgStrokeColor(ctx, rgba(COLORS.gold, 230))
    nvgStrokeWidth(ctx, 1.5)
    nvgStroke(ctx)
    nvgFontFace(ctx, "sans")
    nvgFontSize(ctx, 16)
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(ctx, rgba(COLORS.paper))
    nvgText(ctx, x + w * 0.5, y + h * 0.5, HomeUI.notice)
end

function HomeUI.SetNotice(value, duration)
    HomeUI.notice = tostring(value or "")
    HomeUI.noticeTimer = duration or 2.4
end

function HomeUI.Reset()
    HomeUI.selected = "blackmarket"
    HomeUI.pressed = nil
    HomeUI.hovered = nil
    HomeUI.navRects = {}
    HomeUI.topRects = {}
    HomeUI.equipRect = nil
    HomeUI.deployRect = nil
    HomeUI.changeMapRect = nil
    HomeUI.animTime = 0
    HomeUI.notice = nil
    HomeUI.noticeTimer = 0
end

function HomeUI.Update(dt)
    HomeUI.animTime = HomeUI.animTime + (dt or 0)
    if HomeUI.noticeTimer > 0 then
        HomeUI.noticeTimer = math.max(0, HomeUI.noticeTimer - (dt or 0))
        if HomeUI.noticeTimer <= 0 then HomeUI.notice = nil end
    end
end

function HomeUI.GetHit(x, y)
    if pointInRect(x, y, HomeUI.changeMapRect) then return "change-map" end
    if pointInRect(x, y, HomeUI.equipRect) then return "equip" end
    if pointInRect(x, y, HomeUI.deployRect) then return "deploy" end
    for _, action in ipairs(TOP_ACTIONS) do
        if pointInRect(x, y, HomeUI.topRects[action.id]) then return action.id end
    end
    for _, section in ipairs(SECTIONS) do
        if pointInRect(x, y, HomeUI.navRects[section.id]) then return section.id end
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
    if activated and activated ~= "equip" and activated ~= "deploy"
        and activated ~= "change-map" and activated ~= "settings"
        and activated ~= "mail" and activated ~= "notes" then
        HomeUI.selected = activated
    end
    if activated == "settings" then
        HomeUI.SetNotice("设置面板将在战斗内开放", 2.4)
    elseif activated == "mail" then
        HomeUI.SetNotice("暂无新的幸存者来信", 2.4)
    elseif activated == "notes" then
        HomeUI.SetNotice("今日目标：搜索物资并安全撤离", 2.8)
    elseif activated == "character" then
        HomeUI.SetNotice("角色档案功能正在整理中", 2.4)
    elseif activated == "missions" then
        HomeUI.SetNotice("主线任务：前往当前已选地点", 2.6)
    end
    return activated
end

function HomeUI.Draw(ctx, width, height, time, data)
    data = data or {}
    local layers = data.layers or {}
    local scale = math.min(width / DESIGN_W, height / DESIGN_H)
    local drawW = DESIGN_W * scale
    local drawH = DESIGN_H * scale
    local offsetX = (width - drawW) * 0.5
    local offsetY = (height - drawH) * 0.5

    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, width, height)
    nvgFillColor(ctx, nvgRGBA(4, 6, 5, 255))
    nvgFill(ctx)

    nvgSave(ctx)
    nvgTranslate(ctx, offsetX, offsetY)
    nvgScale(ctx, scale, scale)

    local master = data.masterImage
    drawImage(ctx, layers.background, 0, 0, DESIGN_W, DESIGN_H,
        DESIGN_W / DESIGN_H, "cover", 1.0)
    drawMasterCrop(ctx, master, 14, 5, 168, 62,
        14, 5, 168, 62)

    -- 主面板按设计稿区域拆分显示；每块都是独立组件而非整图铺屏。
    drawMasterCrop(ctx, master, 10, 74, 215, 543,
        10, 74, 215, 543)
    drawMasterCrop(ctx, master, 232, 74, 428, 543,
        232, 74, 428, 543)
    -- 覆盖母版中的静态地图内容，当前地点选中框由 Lua 独立绘制并循环缩放。
    drawNationalMap(ctx, layers, data.selectedMap)
    drawMasterCrop(ctx, master, 667, 74, 688, 543,
        667, 74, 688, 543)

    local selectedMap = data.selectedMap or {}
    local previewX, previewY, previewW, previewH = 681, 137, 660, 216
    drawImage(ctx, selectedMap.previewImage or data.locationImage,
        previewX, previewY, previewW, previewH, 664 / 216, "cover", 1.0)
    drawSelectedMapInfo(ctx, selectedMap)

    -- 顶部状态卡仅使用空底板和设计稿图标，所有数据由 Lua 动态绘制。
    drawTopStatusCards(ctx, data, layers)
    drawTopIcons(ctx, master)
    drawBottom(ctx, master)

    local changeRect = { x = 1005, y = 514, w = 337, h = 83 }
    drawMasterCrop(ctx, master, changeRect.x, changeRect.y,
        changeRect.w, changeRect.h, changeRect.x, changeRect.y,
        changeRect.w, changeRect.h, interactiveTint("change-map"))
    drawInteractionOutline(ctx, "change-map", changeRect, COLORS.gold)
    drawNotice(ctx)
    nvgRestore(ctx)

    HomeUI.changeMapRect = setScreenRect(offsetX, offsetY, scale,
        1005, 514, 337, 83)
    HomeUI.equipRect = setScreenRect(offsetX, offsetY, scale,
        752, 628, 262, 136)
    HomeUI.deployRect = setScreenRect(offsetX, offsetY, scale,
        1018, 628, 340, 136)
    for _, action in ipairs(TOP_ACTIONS) do
        HomeUI.topRects[action.id] = setScreenRect(offsetX, offsetY, scale,
            action.x, 14, 52, 42)
    end
    for _, section in ipairs(SECTIONS) do
        HomeUI.navRects[section.id] = setScreenRect(offsetX, offsetY, scale,
            section.x, 642, section.w, 114)
    end
end

return HomeUI
