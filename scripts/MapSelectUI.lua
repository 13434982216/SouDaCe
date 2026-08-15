local MapSelectUI = {
    selectedMapId = "osaka",
    hovered = nil,
    pressed = nil,
    animTime = 0,
    markerRects = {},
    backRect = nil,
    confirmRect = nil,
    layoutScale = 1,
    layoutOffsetX = 0,
    layoutOffsetY = 0,
    touchId = nil,
    ignoreMouseTimer = 0,
}

local DESIGN_W = 1365
local DESIGN_H = 768
local MAP_X = 107
local MAP_Y = 140
local MAP_W = 468
local MAP_H = 588

local COLORS = {
    paper = { 225, 214, 184 },
    muted = { 139, 137, 121 },
    gold = { 220, 170, 72 },
    red = { 186, 61, 49 },
    panel = { 16, 21, 20 },
}

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

local function drawImage(ctx, image, x, y, w, h, sourceRatio, mode)
    if not image or image <= 0 then return false end
    local frameRatio = w / math.max(1, h)
    local drawW
    local drawH
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
    local paint = nvgImagePattern(ctx, drawX, drawY, drawW, drawH,
        0, image, 1.0)
    nvgBeginPath(ctx)
    nvgRect(ctx, drawX, drawY, drawW, drawH)
    nvgFillPaint(ctx, paint)
    nvgFill(ctx)
    nvgRestore(ctx)
    return true
end

local function drawCutPanel(ctx, x, y, w, h, fill, stroke)
    local cut = math.min(12, w * 0.06, h * 0.2)
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, x + cut, y)
    nvgLineTo(ctx, x + w - cut, y)
    nvgLineTo(ctx, x + w, y + cut)
    nvgLineTo(ctx, x + w, y + h - cut)
    nvgLineTo(ctx, x + w - cut, y + h)
    nvgLineTo(ctx, x + cut, y + h)
    nvgLineTo(ctx, x, y + h - cut)
    nvgLineTo(ctx, x, y + cut)
    nvgClosePath(ctx)
    nvgFillColor(ctx, nvgRGBA(fill[1], fill[2], fill[3], fill[4] or 255))
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(stroke[1], stroke[2], stroke[3], stroke[4] or 255))
    nvgStrokeWidth(ctx, 1.5)
    nvgStroke(ctx)
end

local function getMapById(maps, mapId)
    local osaka = nil
    for _, map in ipairs(maps or {}) do
        if map.id == "osaka" then osaka = map end
        if map.id == mapId then return map end
    end
    return osaka or (maps and maps[1] or nil)
end

local function markerPosition(map)
    return MAP_X + (map.mapX or 0.5) * MAP_W,
        MAP_Y + (map.mapY or 0.5) * MAP_H
end

local function drawSelection(ctx, centerX, centerY)
    local pulse = (math.sin(MapSelectUI.animTime * 3.0) + 1.0) * 0.5
    local scale = 0.88 + pulse * 0.20
    local halfSize = 29 * scale
    local corner = 12 * scale
    local left = centerX - halfSize
    local right = centerX + halfSize
    local top = centerY - halfSize
    local bottom = centerY + halfSize

    nvgBeginPath(ctx)
    nvgCircle(ctx, centerX, centerY, 22 + pulse * 10)
    nvgFillColor(ctx, nvgRGBA(217, 169, 74,
        12 + math.floor(pulse * 16)))
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
    nvgStrokeColor(ctx, nvgRGBA(224, 174, 69,
        165 + math.floor(pulse * 90)))
    nvgStrokeWidth(ctx, 2.2 + pulse * 0.8)
    nvgStroke(ctx)
end

local function drawMarker(ctx, map, selected, hovered)
    local x, y = markerPosition(map)
    local radius = hovered and 10 or 8
    nvgBeginPath(ctx)
    nvgCircle(ctx, x, y, radius + 5)
    nvgFillColor(ctx, nvgRGBA(5, 8, 7, 205))
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgCircle(ctx, x, y, radius)
    local color = selected and COLORS.gold or COLORS.red
    nvgFillColor(ctx, nvgRGBA(color[1], color[2], color[3], 245))
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(238, 221, 177, 230))
    nvgStrokeWidth(ctx, 1.2)
    nvgStroke(ctx)

    local labelW = math.max(72, #tostring(map.shortName or map.name) * 10 + 24)
    local labelX = x - labelW * 0.5
    local labelY = y + 15
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, labelX, labelY, labelW, 25, 3)
    nvgFillColor(ctx, nvgRGBA(12, 15, 13, 226))
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(color[1], color[2], color[3], 210))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)
    nvgFontFace(ctx, "sans")
    nvgFontSize(ctx, 13)
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(ctx, nvgRGBA(226, 217, 192, 255))
    nvgText(ctx, x, labelY + 12, map.shortName or map.name)

    if selected then drawSelection(ctx, x, y) end
end

local function drawHeader(ctx)
    drawCutPanel(ctx, 33, 18, 1299, 66,
        { 17, 20, 18, 248 }, { 129, 111, 71, 235 })
    nvgFontFace(ctx, "sans")
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(ctx, 28)
    nvgFillColor(ctx, nvgRGBA(231, 220, 191, 255))
    nvgText(ctx, DESIGN_W * 0.5, 43, "选择行动地点")
    nvgFontSize(ctx, 11)
    nvgFillColor(ctx, nvgRGBA(130, 137, 128, 245))
    nvgText(ctx, DESIGN_W * 0.5, 68,
        "JAPAN CONTAMINATION ZONES / 点击地图标记查看地点情报")
end

local function drawMapPanel(ctx, data)
    drawCutPanel(ctx, 34, 98, 614, 636,
        { 11, 16, 15, 247 }, { 100, 92, 65, 230 })
    nvgFontFace(ctx, "sans")
    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFontSize(ctx, 17)
    nvgFillColor(ctx, nvgRGBA(220, 209, 180, 255))
    nvgText(ctx, 57, 121, "日本全国沦陷态势")
    nvgTextAlign(ctx, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFontSize(ctx, 11)
    nvgFillColor(ctx, nvgRGBA(150, 75, 61, 255))
    nvgText(ctx, 626, 121, "已侦测 3 个可行动区域")

    drawImage(ctx, data.nationalMapImage, MAP_X, MAP_Y, MAP_W, MAP_H,
        396 / 498, "contain")

    MapSelectUI.markerRects = {}
    for _, map in ipairs(data.maps or {}) do
        local x, y = markerPosition(map)
        local id = "map:" .. tostring(map.id)
        MapSelectUI.markerRects[map.id] = { x = x - 34, y = y - 34, w = 68, h = 68 }
        drawMarker(ctx, map, map.id == MapSelectUI.selectedMapId,
            MapSelectUI.hovered == id)
    end
end

local function drawInfoRow(ctx, x, y, label, value, valueColor)
    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFontSize(ctx, 12)
    nvgFillColor(ctx, nvgRGBA(128, 133, 124, 255))
    nvgText(ctx, x, y, label)
    nvgFontSize(ctx, 15)
    local color = valueColor or COLORS.paper
    nvgFillColor(ctx, nvgRGBA(color[1], color[2], color[3], 255))
    nvgText(ctx, x + 108, y, value)
end

local function drawInfoPanel(ctx, data)
    local map = getMapById(data.maps, MapSelectUI.selectedMapId)
    if not map then return end
    drawCutPanel(ctx, 664, 98, 668, 636,
        { 14, 18, 17, 249 }, { 113, 97, 63, 235 })

    nvgFontFace(ctx, "sans")
    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFontSize(ctx, 26)
    nvgFillColor(ctx, nvgRGBA(228, 216, 184, 255))
    nvgText(ctx, 689, 127, map.name)
    nvgFontSize(ctx, 11)
    nvgFillColor(ctx, nvgRGBA(132, 137, 128, 255))
    nvgText(ctx, 690, 151, map.region or "未知区域")

    local previewX, previewY, previewW, previewH = 688, 174, 620, 258
    nvgBeginPath(ctx)
    nvgRect(ctx, previewX - 3, previewY - 3, previewW + 6, previewH + 6)
    nvgFillColor(ctx, nvgRGBA(6, 9, 8, 255))
    nvgFill(ctx)
    drawImage(ctx, map.previewImage, previewX, previewY,
        previewW, previewH, 664 / 216, "cover")
    nvgBeginPath(ctx)
    nvgRect(ctx, previewX, previewY, previewW, previewH)
    nvgStrokeColor(ctx, nvgRGBA(113, 96, 61, 235))
    nvgStrokeWidth(ctx, 2)
    nvgStroke(ctx)

    drawInfoRow(ctx, 690, 463, "危险等级", map.danger or "未知", COLORS.red)
    drawInfoRow(ctx, 690, 492, "天气状况", map.weather or "未知")
    drawInfoRow(ctx, 690, 521, "主要目标", map.mission or "搜索物资")
    drawInfoRow(ctx, 690, 550, "预估收益", map.reward or "未知", COLORS.gold)

    nvgFontSize(ctx, 12)
    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(ctx, nvgRGBA(152, 157, 145, 245))
    nvgTextBox(ctx, 690, 578, 615, tostring(map.description or ""))

    MapSelectUI.backRect = { x = 688, y = 671, w = 194, h = 45 }
    MapSelectUI.confirmRect = { x = 900, y = 656, w = 408, h = 60 }
    local backHot = MapSelectUI.hovered == "back" or MapSelectUI.pressed == "back"
    local confirmHot = MapSelectUI.hovered == "confirm" or MapSelectUI.pressed == "confirm"
    drawCutPanel(ctx, MapSelectUI.backRect.x, MapSelectUI.backRect.y,
        MapSelectUI.backRect.w, MapSelectUI.backRect.h,
        backHot and { 55, 55, 47, 255 } or { 33, 36, 32, 255 },
        { 113, 108, 88, 230 })
    drawCutPanel(ctx, MapSelectUI.confirmRect.x, MapSelectUI.confirmRect.y,
        MapSelectUI.confirmRect.w, MapSelectUI.confirmRect.h,
        confirmHot and { 139, 87, 36, 255 } or { 106, 62, 29, 255 },
        { 224, 171, 78, 245 })

    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(ctx, 16)
    nvgFillColor(ctx, nvgRGBA(218, 209, 184, 255))
    nvgText(ctx, 785, 693, "返回据点")
    nvgFontSize(ctx, 21)
    nvgFillColor(ctx, nvgRGBA(244, 224, 177, 255))
    nvgText(ctx, 1104, 686, "确认选择  ·  " .. map.shortName)
end

function MapSelectUI.Open(selectedMapId)
    MapSelectUI.selectedMapId = selectedMapId or "osaka"
    MapSelectUI.hovered = nil
    MapSelectUI.pressed = nil
    MapSelectUI.animTime = 0
    MapSelectUI.touchId = nil
    MapSelectUI.ignoreMouseTimer = 0
end

function MapSelectUI.GetSelectedMapId()
    return MapSelectUI.selectedMapId
end

function MapSelectUI.Update(dt)
    MapSelectUI.animTime = MapSelectUI.animTime + (dt or 0)
    MapSelectUI.ignoreMouseTimer = math.max(0,
        MapSelectUI.ignoreMouseTimer - (dt or 0))
end

function MapSelectUI.GetHit(x, y)
    if pointInRect(x, y, MapSelectUI.backRect) then return "back" end
    if pointInRect(x, y, MapSelectUI.confirmRect) then return "confirm" end
    for mapId, rect in pairs(MapSelectUI.markerRects) do
        if pointInRect(x, y, rect) then return "map:" .. tostring(mapId) end
    end
    return nil
end

function MapSelectUI.PointerMove(x, y)
    local scale = math.max(0.0001, MapSelectUI.layoutScale)
    local designX = (x - MapSelectUI.layoutOffsetX) / scale
    local designY = (y - MapSelectUI.layoutOffsetY) / scale
    MapSelectUI.hovered = MapSelectUI.GetHit(designX, designY)
end

function MapSelectUI.PointerDown(x, y)
    local scale = math.max(0.0001, MapSelectUI.layoutScale)
    local designX = (x - MapSelectUI.layoutOffsetX) / scale
    local designY = (y - MapSelectUI.layoutOffsetY) / scale
    MapSelectUI.pressed = MapSelectUI.GetHit(designX, designY)
    return MapSelectUI.pressed
end

function MapSelectUI.PointerUp(x, y)
    local scale = math.max(0.0001, MapSelectUI.layoutScale)
    local designX = (x - MapSelectUI.layoutOffsetX) / scale
    local designY = (y - MapSelectUI.layoutOffsetY) / scale
    local hit = MapSelectUI.GetHit(designX, designY)
    local action = hit and hit == MapSelectUI.pressed and hit or nil
    MapSelectUI.pressed = nil
    local mapId = action and action:match("^map:(.+)$")
    if mapId then
        MapSelectUI.selectedMapId = mapId
        return "select:" .. mapId
    end
    return action
end

function MapSelectUI.TouchBegin(touchId, x, y)
    if MapSelectUI.touchId ~= nil then return false end
    MapSelectUI.touchId = touchId
    MapSelectUI.ignoreMouseTimer = 0.5
    MapSelectUI.PointerDown(x, y)
    return true
end

function MapSelectUI.TouchMove(touchId, x, y)
    if MapSelectUI.touchId ~= touchId then return false end
    MapSelectUI.ignoreMouseTimer = 0.5
    MapSelectUI.PointerMove(x, y)
    return true
end

function MapSelectUI.TouchEnd(touchId, x, y)
    if MapSelectUI.touchId ~= touchId then return nil end
    MapSelectUI.ignoreMouseTimer = 0.5
    MapSelectUI.PointerMove(x, y)
    local action = MapSelectUI.PointerUp(x, y)
    MapSelectUI.touchId = nil
    return action
end

function MapSelectUI.ShouldIgnoreMouse()
    return MapSelectUI.touchId ~= nil or MapSelectUI.ignoreMouseTimer > 0
end

function MapSelectUI.Draw(ctx, width, height, data)
    data = data or {}
    local scale = math.min(width / DESIGN_W, height / DESIGN_H)
    local drawW = DESIGN_W * scale
    local drawH = DESIGN_H * scale
    local offsetX = (width - drawW) * 0.5
    local offsetY = (height - drawH) * 0.5
    MapSelectUI.layoutScale = scale
    MapSelectUI.layoutOffsetX = offsetX
    MapSelectUI.layoutOffsetY = offsetY

    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, width, height)
    nvgFillColor(ctx, nvgRGBA(4, 7, 6, 255))
    nvgFill(ctx)

    nvgSave(ctx)
    nvgTranslate(ctx, offsetX, offsetY)
    nvgScale(ctx, scale, scale)
    drawImage(ctx, data.backgroundImage, 0, 0,
        DESIGN_W, DESIGN_H, DESIGN_W / DESIGN_H, "cover")
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, DESIGN_W, DESIGN_H)
    nvgFillColor(ctx, nvgRGBA(3, 6, 5, 150))
    nvgFill(ctx)
    drawHeader(ctx)
    drawMapPanel(ctx, data)
    drawInfoPanel(ctx, data)
    nvgRestore(ctx)
end

return MapSelectUI
