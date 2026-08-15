local WarehouseUI = {
    activeTab = 1,
    hovered = nil,
    pressed = nil,
    tabs = {},
    tabRects = {},
    gridRects = {},
    gridCellSize = 0,
    gridCellW = 0,
    gridCellH = 0,
    cellRects = {},
    gridViewport = nil,
    scrollOffset = 0,
    scrollMax = 0,
    scrollBarRect = nil,
    scrollThumbRect = nil,
    scrollBarHitRect = nil,
    scrollThumbHitRect = nil,
    scrollTouchId = nil,
    scrollTouchStartX = 0,
    scrollTouchStartY = 0,
    scrollStartOffset = 0,
    scrollDragging = false,
    scrollFromGrid = false,
    itemRects = {},
    placements = {},
    cellOwners = {},
    dragging = false,
    dragPending = false,
    dragIndex = 0,
    dragStartX = 0,
    dragStartY = 0,
    dragX = 0,
    dragY = 0,
    dragOffsetX = 0,
    dragOffsetY = 0,
    touchId = nil,
    ignoreMouseTimer = 0,
    itemSizes = {},
    itemValues = {},
    itemRarity = {},
    backRect = nil,
    popupRotateRect = nil,
    upgradeRect = nil,
    animTime = 0,
    notice = "",
    noticeTimer = 0,
    infoPopup = nil,
    selectedItemIndex = 1,
    rotateRect = nil,
    organizeRect = nil,
    layoutScale = 1,
    layoutOffsetX = 0,
    layoutOffsetY = 0,
}

local RARITY_COLORS = {
    red = { 181, 52, 45 },
    pink = { 184, 74, 132 },
    gold = { 218, 164, 65 },
    purple = { 116, 76, 166 },
    blue = { 54, 106, 166 },
    green = { 57, 125, 79 },
}

local DESIGN_W = 1365
local DESIGN_H = 768

local CELL_COLORS = {
    red = { 91, 39, 29 },
    pink = { 83, 57, 75 },
    gold = { 104, 83, 39 },
    purple = { 64, 48, 77 },
    blue = { 43, 62, 72 },
    green = { 56, 68, 44 },
}

local function beginWarehouseCellPath(ctx, x, y, w, h, inset)
    local gap = inset or 0
    local left = x + gap
    local top = y + gap
    local right = x + w - gap
    local bottom = y + h - gap
    local cut = math.min(5, math.max(2, (right - left) * 0.035),
        math.max(2, (bottom - top) * 0.12))
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, left + cut, top)
    nvgLineTo(ctx, right - cut, top)
    nvgLineTo(ctx, right, top + cut)
    nvgLineTo(ctx, right, bottom - cut)
    nvgLineTo(ctx, right - cut, bottom)
    nvgLineTo(ctx, left + cut, bottom)
    nvgLineTo(ctx, left, bottom - cut)
    nvgLineTo(ctx, left, top + cut)
    nvgClosePath(ctx)
end

local WAREHOUSE_MASTER_CROPS = {
    ["翡翠原石"] = { x = 50, y = 148, w = 211, h = 230 },
    ["金条"] = { x = 544, y = 148, w = 186, h = 153 },
    ["古董花瓶"] = { x = 731, y = 148, w = 170, h = 230 },
    ["平板电脑"] = { x = 474, y = 455, w = 212, h = 77 },
}

local function drawMasterCrop(ctx, master, source, rect)
    if not master or master <= 0 or not source then return false end
    local scaleX = rect.w / source.w
    local scaleY = rect.h / source.h
    local imageX = rect.x - source.x * scaleX
    local imageY = rect.y - source.y * scaleY
    local imageW = DESIGN_W * scaleX
    local imageH = DESIGN_H * scaleY
    local paint = nvgImagePattern(ctx, imageX, imageY, imageW, imageH, 0, master, 1.0)
    nvgSave(ctx)
    nvgScissor(ctx, rect.x, rect.y, rect.w, rect.h)
    nvgBeginPath(ctx)
    nvgRect(ctx, rect.x, rect.y, rect.w, rect.h)
    nvgFillPaint(ctx, paint)
    nvgFill(ctx)
    nvgRestore(ctx)
    return true
end

local WAREHOUSE_CELL_KEYS = {
    ["翡翠原石"] = "red2x2",
    ["金条"] = "gold2x1",
    ["古董花瓶"] = "pink2x2",
    ["平板电脑"] = "purple2x1",
}

local WAREHOUSE_RARITY_CELL_KEYS = {
    red = "red2x2",
    gold = "gold2x1",
    pink = "pink2x2",
    purple = "purple2x1",
    blue = "blue1x1",
    green = "green1x1",
}

local function drawWarehouseCellImage(ctx, image, rect, selected, vertical)
    if not image or image <= 0 then return false end
    if vertical then
        local centerX = rect.x + rect.w * 0.5
        local centerY = rect.y + rect.h * 0.5
        local imageW = rect.h
        local imageH = rect.w
        nvgSave(ctx)
        nvgTranslate(ctx, centerX, centerY)
        nvgRotate(ctx, math.pi * 0.5)
        local paint = nvgImagePattern(ctx, -imageW * 0.5, -imageH * 0.5,
            imageW, imageH, 0, image, 1.0)
        nvgBeginPath(ctx)
        nvgRect(ctx, -imageW * 0.5, -imageH * 0.5, imageW, imageH)
        nvgFillPaint(ctx, paint)
        nvgFill(ctx)
        nvgRestore(ctx)
    else
        local paint = nvgImagePattern(ctx, rect.x, rect.y,
            rect.w, rect.h, 0, image, 1.0)
        nvgBeginPath(ctx)
        nvgRect(ctx, rect.x, rect.y, rect.w, rect.h)
        nvgFillPaint(ctx, paint)
        nvgFill(ctx)
    end
    if selected then
        nvgBeginPath(ctx)
        nvgRect(ctx, rect.x + 1, rect.y + 1, rect.w - 2, rect.h - 2)
        nvgStrokeColor(ctx, nvgRGBA(229, 210, 158, 245))
        nvgStrokeWidth(ctx, 2)
        nvgStroke(ctx)
    end
    return true
end

local function drawWarehouseItemCell(ctx, rect, color, selected)
    local dark = {
        math.floor(color[1] * 0.42),
        math.floor(color[2] * 0.42),
        math.floor(color[3] * 0.42),
    }
    beginWarehouseCellPath(ctx, rect.x, rect.y, rect.w, rect.h, 0)
    nvgFillColor(ctx, nvgRGBA(31, 29, 22, 255))
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(107, 95, 67, 235))
    nvgStrokeWidth(ctx, selected and 2.2 or 1.4)
    nvgStroke(ctx)
    local inner = nvgLinearGradient(ctx, rect.x, rect.y, rect.x, rect.y + rect.h,
        nvgRGBA(color[1], color[2], color[3], 244),
        nvgRGBA(dark[1], dark[2], dark[3], 250))
    beginWarehouseCellPath(ctx, rect.x + 4, rect.y + 4, rect.w - 8, rect.h - 8, 0)
    nvgFillPaint(ctx, inner)
    nvgFill(ctx)
    beginWarehouseCellPath(ctx, rect.x + 4, rect.y + 4, rect.w - 8, rect.h - 8, 0)
    nvgStrokeColor(ctx, selected
        and nvgRGBA(225, 205, 151, 255)
        or nvgRGBA(139, 123, 84, 210))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)
end

local function screenToDesign(x, y)
    local scale = math.max(0.0001, WarehouseUI.layoutScale or 1)
    return (x - (WarehouseUI.layoutOffsetX or 0)) / scale,
        (y - (WarehouseUI.layoutOffsetY or 0)) / scale
end

local function drawImageRect(ctx, image, x, y, w, h, tint)
    if not image or image <= 0 then return false end
    local paint = tint
        and nvgImagePatternTinted(ctx, x, y, w, h, 0, image, tint)
        or nvgImagePattern(ctx, x, y, w, h, 0, image, 1.0)
    nvgBeginPath(ctx)
    nvgRect(ctx, x, y, w, h)
    nvgFillPaint(ctx, paint)
    nvgFill(ctx)
    return true
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

local function drawCutPanel(ctx, x, y, w, h, fillColor, borderColor, active)
    beginCutRect(ctx, x, y, w, h, 8)
    nvgFillColor(ctx, nvgRGBA(fillColor[1], fillColor[2], fillColor[3], fillColor[4] or 255))
    nvgFill(ctx)
    beginCutRect(ctx, x, y, w, h, 8)
    nvgStrokeColor(ctx, nvgRGBA(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 255))
    nvgStrokeWidth(ctx, active and 1.8 or 1)
    nvgStroke(ctx)
end

local function getItemName(entry)
    return type(entry) == "table" and entry.item or entry
end

local function getTab()
    return WarehouseUI.tabs[WarehouseUI.activeTab] or WarehouseUI.tabs[1]
end

local function getCapacity(tab)
    return math.max(1, (tab.cols or 8) * (tab.rows or 6))
end

local function getCellIndex(tab, entry, fallbackIndex)
    local cols = tab.cols or 8
    local rows = tab.rows or 6
    if type(entry) == "table" and entry.col ~= nil and entry.row ~= nil
        and entry.col >= 0 and entry.col < cols
        and entry.row >= 0 and entry.row < rows then
        return entry.row * cols + entry.col + 1
    end
    return fallbackIndex <= cols * rows and fallbackIndex or nil
end

local function setItemCell(tab, itemIndex, cellIndex)
    local cols = tab.cols or 8
    local col = ((cellIndex - 1) % cols) + 1
    local row = math.floor((cellIndex - 1) / cols) + 1
    local entry = tab.items[itemIndex]
    local itemName = getItemName(entry)
    local orientation = type(entry) == "table" and entry.orientation or nil
    tab.items[itemIndex] = {
        item = itemName,
        col = col - 1,
        row = row - 1,
        orientation = orientation,
    }
end

local function getItemSize(entry)
    local itemName = getItemName(entry)
    local size = WarehouseUI.itemSizes and WarehouseUI.itemSizes[itemName]
    local itemW = size and math.max(1, size[1]) or 1
    local itemH = size and math.max(1, size[2]) or 1
    if type(entry) == "table" and entry.orientation == "vertical" then
        return itemH, itemW
    end
    return itemW, itemH
end

local function placementFits(tab, col, row, itemW, itemH, exceptIndex)
    local cols = tab.cols or 8
    local rows = tab.rows or 6
    if col < 1 or row < 1 or col + itemW - 1 > cols or row + itemH - 1 > rows then
        return false
    end
    for y = row, row + itemH - 1 do
        for x = col, col + itemW - 1 do
            local owner = WarehouseUI.cellOwners[(y - 1) * cols + x]
            if owner and owner ~= exceptIndex then return false end
        end
    end
    return true
end

local function markPlacement(tab, itemIndex, col, row, itemW, itemH)
    local cols = tab.cols or 8
    local placement = { col = col, row = row, w = itemW, h = itemH }
    WarehouseUI.placements[itemIndex] = placement
    for y = row, row + itemH - 1 do
        for x = col, col + itemW - 1 do
            WarehouseUI.cellOwners[(y - 1) * cols + x] = itemIndex
        end
    end
    return placement
end

local function rebuildPlacements(tab)
    local cols = tab.cols or 8
    local rows = tab.rows or 6
    WarehouseUI.placements = {}
    WarehouseUI.cellOwners = {}

    for index, entry in ipairs(tab.items or {}) do
        local itemW, itemH = getItemSize(entry)
        local placed = false
        local storedCol = type(entry) == "table" and entry.col or nil
        local storedRow = type(entry) == "table" and entry.row or nil
        local gridCol = storedCol ~= nil and storedCol + 1 or nil
        local gridRow = storedRow ~= nil and storedRow + 1 or nil
        if gridCol and gridRow
            and placementFits(tab, gridCol, gridRow, itemW, itemH, index) then
            markPlacement(tab, index, gridCol, gridRow, itemW, itemH)
            placed = true
        end
        if not placed then
            for row = 1, rows do
                for col = 1, cols do
                    if placementFits(tab, col, row, itemW, itemH, index) then
                        markPlacement(tab, index, col, row, itemW, itemH)
                        local itemName = getItemName(entry)
                        local orientation = type(entry) == "table" and entry.orientation or nil
                        tab.items[index] = {
                            item = itemName,
                            col = col - 1,
                            row = row - 1,
                            orientation = orientation,
                        }
                        placed = true
                        break
                    end
                end
                if placed then break end
            end
        end
    end
end

local function canPlaceItem(tab, itemIndex, cellIndex)
    local entry = tab.items[itemIndex]
    if not entry then return false end
    local cols = tab.cols or 8
    local itemW, itemH = getItemSize(entry)
    local col = ((cellIndex - 1) % cols) + 1
    local row = math.floor((cellIndex - 1) / cols) + 1
    return placementFits(tab, col, row, itemW, itemH, itemIndex)
end

local function isCellOccupied(tab, cellIndex, exceptIndex)
    local owner = WarehouseUI.cellOwners[cellIndex]
    return owner ~= nil and owner ~= exceptIndex
end

local function transferItemToTab(sourceItemIndex, targetTabIndex)
    local sourceTab = WarehouseUI.tabs[WarehouseUI.activeTab]
    local targetTab = WarehouseUI.tabs[targetTabIndex]
    if not sourceTab or not targetTab or sourceTab == targetTab
        or not targetTab.unlocked or not sourceTab.items[sourceItemIndex] then
        return nil
    end

    local sourceEntry = sourceTab.items[sourceItemIndex]
    rebuildPlacements(targetTab)
    targetTab.items[#targetTab.items + 1] = sourceEntry
    local targetItemIndex = #targetTab.items
    rebuildPlacements(targetTab)

    if not WarehouseUI.placements[targetItemIndex] then
        table.remove(targetTab.items, targetItemIndex)
        rebuildPlacements(targetTab)
        rebuildPlacements(sourceTab)
        return nil
    end

    table.remove(sourceTab.items, sourceItemIndex)
    rebuildPlacements(sourceTab)
    WarehouseUI.activeTab = targetTabIndex
    WarehouseUI.scrollOffset = 0
    WarehouseUI.infoPopup = nil
    rebuildPlacements(targetTab)
    WarehouseUI.notice = ""
    WarehouseUI.noticeTimer = 0
    print("[Warehouse] 物资 " .. tostring(getItemName(sourceEntry))
        .. " 已转移至 " .. tostring(targetTab.name))
    return targetItemIndex
end

local function rotateItem(tab, itemIndex)
    rebuildPlacements(tab)
    local entry = tab.items[itemIndex]
    local placement = WarehouseUI.placements[itemIndex]
    if not entry or not placement then return false end

    local baseSize = WarehouseUI.itemSizes[getItemName(entry)] or { 1, 1 }
    if baseSize[1] == baseSize[2] then return false end

    if type(entry) ~= "table" then
        entry = { item = getItemName(entry) }
        tab.items[itemIndex] = entry
    end

    local oldOrientation = entry.orientation
    local oldCol = entry.col
    local oldRow = entry.row
    local currentOrientation = oldOrientation or "horizontal"
    entry.orientation = currentOrientation == "vertical"
        and "horizontal" or "vertical"

    local itemW, itemH = getItemSize(entry)
    local sameCellCount = itemW * itemH == baseSize[1] * baseSize[2]
    local fitsInPlace = sameCellCount and placementFits(tab,
        placement.col, placement.row, itemW, itemH, itemIndex)
    if fitsInPlace then
        entry.col = placement.col - 1
        entry.row = placement.row - 1
        rebuildPlacements(tab)
        local rotated = WarehouseUI.placements[itemIndex]
        if rotated and rotated.col == placement.col
            and rotated.row == placement.row
            and rotated.w == itemW and rotated.h == itemH then
            return true
        end
    end

    entry.orientation = oldOrientation
    entry.col = oldCol
    entry.row = oldRow
    rebuildPlacements(tab)
    return false
end

local function getItemInfo(itemName, data)
    local info = data and data.itemValues and data.itemValues[itemName]
    return info or { value = 0, desc = "暂无物品说明。" }
end

local function getRarityLabel(rarity)
    return ({ red = "传说", pink = "史诗", gold = "收藏", purple = "稀有", blue = "精良", green = "普通" })[rarity] or "普通"
end

local function dismissInfoPopup(x, y)
    local popup = WarehouseUI.infoPopup
    if popup and not pointInRect(x, y, popup) then
        WarehouseUI.infoPopup = nil
        return true
    end
    return false
end

local function drawInfoPopup(ctx, width, height, data)
    local popup = WarehouseUI.infoPopup
    if not popup then
        WarehouseUI.popupRotateRect = nil
        return
    end
    local itemName = popup.itemName
    local info = getItemInfo(itemName, data)
    local rarity = popup.rarity
    local color = RARITY_COLORS[rarity] or RARITY_COLORS.green
    local baseSize = WarehouseUI.itemSizes[itemName] or { 1, 1 }
    local rotatable = baseSize[1] ~= baseSize[2]
    local popupW = math.min(width - 28, 330)
    local popupH = rotatable and 230 or 184
    local popupX = clamp(popup.anchorX - popupW * 0.5, 14, width - popupW - 14)
    local popupY = clamp(popup.anchorY - popupH - 14, 76, height - popupH - 14)
    popup.x = popupX
    popup.y = popupY
    popup.w = popupW
    popup.h = popupH

    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, popupX, popupY, popupW, popupH, 8)
    nvgFillColor(ctx, nvgRGBA(13, 16, 19, 250))
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, popupX, popupY, popupW, popupH, 8)
    nvgStrokeColor(ctx, nvgRGBA(color[1], color[2], color[3], 245))
    nvgStrokeWidth(ctx, 2)
    nvgStroke(ctx)

    nvgFontFace(ctx, "sans")
    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFontSize(ctx, 20)
    nvgFillColor(ctx, nvgRGBA(245, 239, 220, 255))
    nvgText(ctx, popupX + 16, popupY + 14, itemName)
    nvgFontSize(ctx, 11)
    nvgFillColor(ctx, nvgRGBA(color[1], color[2], color[3], 255))
    nvgText(ctx, popupX + 16, popupY + 45, getRarityLabel(rarity) .. "  ·  " .. tostring(popup.wCells) .. " × " .. tostring(popup.hCells) .. " 格")
    nvgFontSize(ctx, 22)
    nvgFillColor(ctx, nvgRGBA(224, 177, 77, 255))
    nvgText(ctx, popupX + 16, popupY + 66, "价值  " .. tostring(info.value or 0))
    nvgFontSize(ctx, 12)
    nvgFillColor(ctx, nvgRGBA(178, 187, 188, 245))
    nvgTextBox(ctx, popupX + 16, popupY + 102, popupW - 32, 42, info.desc or "暂无物品说明。")

    if rotatable then
        WarehouseUI.popupRotateRect = { x = popupX + 16, y = popupY + popupH - 54, w = popupW - 32, h = 38 }
        drawCutPanel(ctx, WarehouseUI.popupRotateRect.x, WarehouseUI.popupRotateRect.y,
            WarehouseUI.popupRotateRect.w, WarehouseUI.popupRotateRect.h,
            { 100, 70, 30, 255 }, { 221, 174, 82, 235 }, false)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFontSize(ctx, 13)
        nvgFillColor(ctx, nvgRGBA(250, 239, 211, 255))
        nvgText(ctx, popupX + popupW * 0.5, WarehouseUI.popupRotateRect.y + 19, "旋转物品")
    else
        WarehouseUI.popupRotateRect = nil
        nvgFontSize(ctx, 10)
        nvgTextAlign(ctx, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
        nvgFillColor(ctx, nvgRGBA(113, 124, 128, 245))
        nvgText(ctx, popupX + popupW - 16, popupY + popupH - 16, "点击其他位置关闭")
    end
end

local function drawHeader(ctx, width, tab)
    local headerH = 64
    local grad = nvgLinearGradient(ctx, 0, 0, 0, headerH,
        nvgRGBA(8, 10, 13, 252), nvgRGBA(21, 25, 29, 236))
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, width, headerH)
    nvgFillPaint(ctx, grad)
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, headerH - 1, width, 1)
    nvgFillColor(ctx, nvgRGBA(161, 123, 53, 180))
    nvgFill(ctx)

    WarehouseUI.backRect = { x = 12, y = 12, w = 44, h = 40 }
    local backActive = WarehouseUI.hovered == "back" or WarehouseUI.pressed == "back"
    drawCutPanel(ctx, 12, 12, 44, 40,
        backActive and { 78, 50, 40, 255 } or { 37, 40, 43, 250 },
        { 156, 104, 72, 210 }, backActive)
    nvgFontFace(ctx, "sans")
    nvgFontSize(ctx, 23)
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(ctx, nvgRGBA(238, 222, 192, 255))
    nvgText(ctx, 34, 31, "‹")

    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFontSize(ctx, clamp(width * 0.036, 22, 30))
    nvgFillColor(ctx, nvgRGBA(234, 224, 202, 255))
    nvgText(ctx, 70, 25, "据点仓库")
    nvgFontSize(ctx, 10)
    nvgFillColor(ctx, nvgRGBA(121, 130, 134, 240))
    nvgText(ctx, 72, 47, "STASH MANAGEMENT / 物资长期存放")

    local cols = tab.cols or 8
    local rows = tab.rows or 6
    local capacity = getCapacity(tab)
    local tabIndex = WarehouseUI.activeTab
    nvgTextAlign(ctx, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFontSize(ctx, 12)
    nvgFillColor(ctx, nvgRGBA(228, 218, 198, 255))
    nvgText(ctx, width - 16, 17, tostring(tabIndex) .. "号仓库  LV." .. tostring(tab.level or 1))
    nvgFontSize(ctx, 10)
    nvgFillColor(ctx, nvgRGBA(216, 169, 79, 255))
    nvgText(ctx, width - 16, 36,
        tostring(cols) .. " × " .. tostring(rows) .. "  ·  " .. tostring(capacity) .. " 格")
    nvgFontSize(ctx, 9)
    nvgFillColor(ctx, nvgRGBA(125, 135, 139, 245))
    nvgText(ctx, width - 16, 52,
        "已存放 " .. tostring(#(tab.items or {})) .. " 件物资")

    return headerH
end

local function drawTabs(ctx, x, topY, width)
    local gap = 5
    local tabH = 40
    WarehouseUI.tabRects = {}

    for index, tab in ipairs(WarehouseUI.tabs) do
        local y = topY + (index - 1) * (tabH + gap)
        local id = "tab:" .. tostring(index)
        local active = index == WarehouseUI.activeTab
        local hot = WarehouseUI.hovered == id or WarehouseUI.pressed == id
        WarehouseUI.tabRects[index] = { x = x, y = y, w = width, h = tabH }

        local fill
        local border
        if not tab.unlocked then
            fill = hot and { 37, 35, 34, 246 } or { 23, 25, 27, 238 }
            border = { 78, 76, 72, 175 }
        elseif active then
            fill = { 48, 42, 31, 252 }
            border = { 216, 164, 65, 245 }
        else
            fill = hot and { 38, 43, 47, 250 } or { 24, 28, 31, 240 }
            border = { 74, 86, 92, 185 }
        end
        drawCutPanel(ctx, x, y, width, tabH, fill, border, active)

        nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFontSize(ctx, 10)
        nvgFillColor(ctx, tab.unlocked and nvgRGBA(228, 222, 207, 255) or nvgRGBA(112, 114, 114, 245))
        nvgText(ctx, x + 8, y + 13, tab.name or ("仓库 " .. tostring(index)))
        nvgFontSize(ctx, 8)
        nvgFillColor(ctx, tab.unlocked and nvgRGBA(137, 145, 146, 240) or nvgRGBA(142, 104, 69, 235))
        local status = tab.unlocked
            and ("LV." .. tostring(tab.level or 1) .. "  " .. tostring(#(tab.items or {})) .. "/" .. tostring(getCapacity(tab)))
            or "未解锁"
        nvgText(ctx, x + 8, y + 29, status)
    end
end

local function drawItem(ctx, rect, entry, data, index, registerHit, ghost)
    local itemName = getItemName(entry) or "未知物资"
    local rarity = (data.itemRarity and data.itemRarity[itemName]) or "green"
    local color = RARITY_COLORS[rarity] or RARITY_COLORS.green
    local iconId = data.itemIcons and data.itemIcons[itemName]
    local isDragging = WarehouseUI.dragging and WarehouseUI.dragIndex == index
    local isSelected = WarehouseUI.selectedItemIndex == index
    local hideIcon = isDragging and not ghost

    local cellColor = CELL_COLORS[rarity] or CELL_COLORS.green
    local cellKey = WAREHOUSE_CELL_KEYS[itemName]
        or WAREHOUSE_RARITY_CELL_KEYS[rarity]
        or "green1x1"
    local cellImage = data.cellImages and data.cellImages[cellKey]
    local hasExactCell = cellImage and cellImage > 0
    local vertical = type(entry) == "table" and entry.orientation == "vertical"
    if hasExactCell then
        drawWarehouseCellImage(ctx, cellImage, rect, isSelected, vertical)
    else
        drawWarehouseItemCell(ctx, rect, cellColor, isSelected)
    end

    local nameBarH = math.min(22, math.max(16, rect.h * 0.28))
    local nameBarY = rect.y + rect.h - nameBarH
    if iconId and iconId > 0 and not hideIcon then
        local sourceW, sourceH = nvgImageSize(ctx, iconId)
        sourceW = math.max(1, sourceW or 1)
        sourceH = math.max(1, sourceH or 1)
        local imageScale = (itemName == "棒球棍" or itemName == "散弹枪") and 0.82 or 1.0
        local itemW, itemH = getItemSize(entry)
        local isSingleCell = itemW == 1 and itemH == 1
        local layoutW = vertical and rect.h or rect.w
        local layoutH = vertical and rect.w or rect.h
        local layoutNameBarH = math.min(22, math.max(16, layoutH * 0.28))
        local targetW = layoutW * 0.72 * imageScale
        local targetH = math.max(12, layoutH - layoutNameBarH - 8) * 0.82 * imageScale
        if isSingleCell then
            targetW = layoutW * 0.94
            targetH = math.max(12, layoutH - layoutNameBarH - 2) * 0.98
        end
        local centerX = rect.x + rect.w * 0.5
        local centerY = rect.y + (rect.h - nameBarH) * 0.5
        if not hasExactCell then
            targetW = layoutW * 1.14 * imageScale
            targetH = layoutH * 0.98 * imageScale
        end
        local imageAspect = sourceW / sourceH
        local targetAspect = targetW / targetH
        local drawW
        local drawH
        if imageAspect > targetAspect then
            drawW = targetW
            drawH = targetW / imageAspect
        else
            drawH = targetH
            drawW = targetH * imageAspect
        end
        nvgSave(ctx)
        nvgIntersectScissor(ctx, rect.x, rect.y, rect.w, math.max(1, nameBarY - rect.y))
        if vertical then
            nvgTranslate(ctx, centerX, centerY)
            nvgRotate(ctx, math.pi * 0.5)
            local paint = nvgImagePattern(ctx, -drawW * 0.5, -drawH * 0.5,
                drawW, drawH, 0, iconId, 1.0)
            nvgBeginPath(ctx)
            nvgRect(ctx, -drawW * 0.5, -drawH * 0.5, drawW, drawH)
            nvgFillPaint(ctx, paint)
            nvgFill(ctx)
        else
            local iconX = centerX - drawW * 0.5
            local iconY = centerY - drawH * 0.5
            local paint = nvgImagePattern(ctx, iconX, iconY, drawW, drawH, 0, iconId, 1.0)
            nvgBeginPath(ctx)
            nvgRect(ctx, iconX, iconY, drawW, drawH)
            nvgFillPaint(ctx, paint)
            nvgFill(ctx)
        end
        nvgRestore(ctx)
    end

    nvgFontFace(ctx, "sans")
    local textSize = clamp(rect.w * 0.115, 5, 8)
    local availableTextW = math.max(1, rect.w - 14)
    nvgFontSize(ctx, textSize)
    local measuredTextW = nvgTextBounds(ctx, 0, 0, itemName) or 0
    if measuredTextW > availableTextW then
        textSize = math.max(3.5, textSize * availableTextW / measuredTextW * 0.78)
        nvgFontSize(ctx, textSize)
    end
    nvgBeginPath(ctx)
    nvgRect(ctx, rect.x + 1, nameBarY, math.max(1, rect.w - 2), nameBarH)
    nvgFillColor(ctx, nvgRGBA(0, 0, 0, 105))
    nvgFill(ctx)
    nvgSave(ctx)
    nvgIntersectScissor(ctx, rect.x + 1, nameBarY,
        math.max(1, rect.w - 2), nameBarH)
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(ctx, nvgRGBA(245, 239, 219, 250))
    nvgText(ctx, rect.x + rect.w * 0.5, nameBarY + 3, itemName)
    nvgRestore(ctx)

    if registerHit ~= false then
        WarehouseUI.itemRects[index] = rect
    end
end

local function drawGrid(ctx, x, y, w, h, tab, data)
    local cols = tab.cols or 8
    local rows = tab.rows or 6
    local scrollbarW = 18
    local viewportW = math.max(40, w - scrollbarW)
    local cellSize = viewportW / cols
    local cellW = cellSize
    local cellH = cellSize
    local contentW = cellSize * cols
    local contentH = cellSize * rows
    local maxScroll = math.max(0, contentH - h)
    WarehouseUI.scrollMax = maxScroll
    WarehouseUI.scrollOffset = clamp(WarehouseUI.scrollOffset, 0, maxScroll)
    WarehouseUI.gridViewport = { x = x, y = y, w = viewportW, h = h }
    local startX = x + (viewportW - contentW) * 0.5
    local startY = y - WarehouseUI.scrollOffset
    WarehouseUI.gridRects = {}
    WarehouseUI.gridCellSize = cellSize
    WarehouseUI.gridCellW = cellSize
    WarehouseUI.gridCellH = cellSize
    WarehouseUI.cellRects = {}
    WarehouseUI.itemRects = {}
    WarehouseUI.itemSizes = data.itemSizes or WarehouseUI.itemSizes or {}
    WarehouseUI.itemValues = data.itemValues or WarehouseUI.itemValues or {}
    WarehouseUI.itemRarity = data.itemRarity or WarehouseUI.itemRarity or {}
    rebuildPlacements(tab)

    nvgSave(ctx)
    nvgScissor(ctx, x, y, viewportW, h)

    for row = 1, rows do
        for col = 1, cols do
            local index = (row - 1) * cols + col
            local rect = {
                x = startX + (col - 1) * cellW,
                y = startY + (row - 1) * cellH,
                w = cellW,
                h = cellH,
            }
            local occupied = isCellOccupied(tab, index)
            nvgBeginPath(ctx)
            nvgRect(ctx, rect.x, rect.y, rect.w, rect.h)
            nvgFillColor(ctx, occupied and nvgRGBA(25, 29, 31, 244) or nvgRGBA(17, 21, 24, 240))
            nvgFill(ctx)
            nvgBeginPath(ctx)
            nvgRect(ctx, rect.x, rect.y, rect.w, rect.h)
            nvgStrokeColor(ctx, nvgRGBA(65, 75, 79, 210))
            nvgStrokeWidth(ctx, 1)
            nvgStroke(ctx)
            WarehouseUI.cellRects[index] = rect
            WarehouseUI.gridRects[index] = rect
        end
    end

    for index, entry in ipairs(tab.items or {}) do
        local placement = WarehouseUI.placements[index]
        if placement then
            local anchor = WarehouseUI.cellRects[(placement.row - 1) * cols + placement.col]
            if anchor then
                local rect = {
                    x = anchor.x,
                    y = anchor.y,
                    w = placement.w * cellW,
                    h = placement.h * cellH,
                }
                drawItem(ctx, rect, entry, data, index, true, false)
            end
        end
    end

    if WarehouseUI.dragging and WarehouseUI.dragIndex > 0 then
        local entry = tab.items[WarehouseUI.dragIndex]
        if entry then
            local itemW, itemH = getItemSize(entry)
            local anchorX = WarehouseUI.dragX - WarehouseUI.dragOffsetX + cellW * 0.5
            local anchorY = WarehouseUI.dragY - WarehouseUI.dragOffsetY + cellH * 0.5
            local targetCell = nil
            for index, cellRect in ipairs(WarehouseUI.cellRects) do
                if pointInRect(anchorX, anchorY, cellRect) then
                    targetCell = index
                    break
                end
            end

            if targetCell then
                local targetCol = ((targetCell - 1) % cols) + 1
                local targetRow = math.floor((targetCell - 1) / cols) + 1
                local targetAnchor = WarehouseUI.cellRects[targetCell]
                local canDrop = placementFits(tab, targetCol, targetRow, itemW, itemH, WarehouseUI.dragIndex)
                local previewW = itemW * cellW
                local previewH = itemH * cellH
                local previewR = canDrop and 66 or 194
                local previewG = canDrop and 174 or 67
                local previewB = canDrop and 101 or 58

                nvgBeginPath(ctx)
                nvgRoundedRect(ctx, targetAnchor.x + 2, targetAnchor.y + 2,
                    previewW - 4, previewH - 4, 4)
                nvgFillColor(ctx, nvgRGBA(previewR, previewG, previewB, canDrop and 76 or 88))
                nvgFill(ctx)

                nvgBeginPath(ctx)
                nvgRoundedRect(ctx, targetAnchor.x + 1, targetAnchor.y + 1,
                    previewW - 2, previewH - 2, 4)
                nvgStrokeColor(ctx, nvgRGBA(previewR, previewG, previewB, 255))
                nvgStrokeWidth(ctx, 2.5)
                nvgStroke(ctx)

                for previewRow = 0, itemH - 1 do
                    for previewCol = 0, itemW - 1 do
                        nvgBeginPath(ctx)
                        nvgRect(ctx,
                            targetAnchor.x + previewCol * cellW + 3,
                            targetAnchor.y + previewRow * cellH + 3,
                            cellW - 6,
                            cellH - 6)
                        nvgStrokeColor(ctx, nvgRGBA(previewR, previewG, previewB, 150))
                        nvgStrokeWidth(ctx, 1)
                        nvgStroke(ctx)
                    end
                end
            end

            local ghost = {
                x = WarehouseUI.dragX - WarehouseUI.dragOffsetX,
                y = WarehouseUI.dragY - WarehouseUI.dragOffsetY,
                w = itemW * cellW,
                h = itemH * cellH,
            }
            nvgSave(ctx)
            drawItem(ctx, ghost, entry, data, WarehouseUI.dragIndex, false, true)
            nvgRestore(ctx)
        end
    end

    nvgRestore(ctx)
    local barX = x + viewportW + 4
    local barH = h
    WarehouseUI.scrollBarRect = { x = barX, y = y, w = 10, h = barH }
    local thumbH = maxScroll > 0 and math.max(34, barH * barH / contentH) or barH
    local thumbY = y + (barH - thumbH) * (WarehouseUI.scrollOffset / math.max(1, maxScroll))
    WarehouseUI.scrollThumbRect = { x = barX, y = thumbY, w = 10, h = thumbH }
    local touchHitW = 32
    local touchHitX = barX + 5 - touchHitW * 0.5
    WarehouseUI.scrollBarHitRect = { x = touchHitX, y = y, w = touchHitW, h = barH }
    WarehouseUI.scrollThumbHitRect = { x = touchHitX, y = thumbY - 6, w = touchHitW, h = thumbH + 12 }
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, barX, y, 10, barH, 5)
    nvgFillColor(ctx, nvgRGBA(34, 40, 43, 245))
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, barX, thumbY, 10, thumbH, 5)
    nvgFillColor(ctx, maxScroll > 0 and nvgRGBA(196, 145, 58, 245) or nvgRGBA(79, 88, 91, 220))
    nvgFill(ctx)
end

local function getMaterialCount(tab, itemName)
    local total = 0
    for _, entry in ipairs(tab.items or {}) do
        if getItemName(entry) == itemName then total = total + 1 end
    end
    return total
end

local function hasUpgradeMaterials(tab, materials)
    for _, material in ipairs(materials or {}) do
        if getMaterialCount(tab, material.item) < material.count then return false end
    end
    return true
end

local function consumeUpgradeMaterials(tab, materials)
    for _, material in ipairs(materials or {}) do
        local remaining = material.count
        for index = #tab.items, 1, -1 do
            if remaining > 0 and getItemName(tab.items[index]) == material.item then
                table.remove(tab.items, index)
                remaining = remaining - 1
            end
        end
    end
end

local function drawMaterialIcon(ctx, iconId, x, y, size)
    if not iconId or iconId <= 0 then return end
    local sourceW, sourceH = nvgImageSize(ctx, iconId)
    sourceW = math.max(1, sourceW or 1)
    sourceH = math.max(1, sourceH or 1)
    local drawW = size
    local drawH = size
    if sourceW > sourceH then drawH = size * sourceH / sourceW
    else drawW = size * sourceW / sourceH end
    local paint = nvgImagePattern(ctx, x + (size - drawW) * 0.5, y + (size - drawH) * 0.5, drawW, drawH, 0, iconId, 1.0)
    nvgBeginPath(ctx)
    nvgRect(ctx, x + (size - drawW) * 0.5, y + (size - drawH) * 0.5, drawW, drawH)
    nvgFillPaint(ctx, paint)
    nvgFill(ctx)
end

local function drawUpgradePanel(ctx, x, y, w, h, tab, data)
    drawCutPanel(ctx, x, y, w, h, { 20, 24, 27, 246 }, { 69, 79, 84, 190 }, false)
    local pad = 14
    nvgFontFace(ctx, "sans")
    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFontSize(ctx, 11)
    nvgFillColor(ctx, nvgRGBA(135, 146, 149, 245))
    nvgText(ctx, x + pad, y + pad, "仓库扩建")
    nvgFontSize(ctx, 22)
    nvgFillColor(ctx, nvgRGBA(231, 222, 202, 255))
    nvgText(ctx, x + pad, y + 34, "LV." .. tostring(tab.level or 1))

    local maxLevel = tab.maxLevel or 3
    local atMax = (tab.level or 1) >= maxLevel
    local nextCols = tab.cols or 8
    local nextRows = (tab.rows or 6) + 2
    if (tab.level or 1) >= 2 then nextCols = (tab.cols or 8) + 2 end

    nvgFontSize(ctx, 10)
    nvgFillColor(ctx, nvgRGBA(116, 126, 129, 245))
    local desc = atMax
        and "当前仓库已达到最大容量。"
        or ("升级后容量：" .. tostring(nextCols) .. " × " .. tostring(nextRows)
            .. "（" .. tostring(nextCols * nextRows) .. " 格）")
    nvgTextBox(ctx, x + pad, y + 68, w - pad * 2, desc)

    local barX = x + pad
    local barY = y + 105
    local barW = w - pad * 2
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, barX, barY, barW, 6, 3)
    nvgFillColor(ctx, nvgRGBA(39, 44, 47, 255))
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, barX, barY, barW * clamp((tab.level or 1) / maxLevel, 0, 1), 6, 3)
    nvgFillColor(ctx, nvgRGBA(204, 151, 61, 255))
    nvgFill(ctx)

    local nextLevel = (tab.level or 1) + 1
    local materials = tab.upgradeMaterials and tab.upgradeMaterials[nextLevel] or {}
    local canUpgrade = hasUpgradeMaterials(tab, materials)
    local materialY = y + 126
    local iconSize = math.min(34, math.max(24, w * 0.22))
    for index, material in ipairs(materials) do
        local rowY = materialY + (index - 1) * (iconSize + 8)
        local iconId = data.itemIcons and data.itemIcons[material.item]
        if iconId and iconId > 0 then drawMaterialIcon(ctx, iconId, x + pad, rowY, iconSize) end
        local owned = getMaterialCount(tab, material.item)
        nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFontSize(ctx, 10)
        nvgFillColor(ctx, (canUpgrade or owned >= material.count)
            and nvgRGBA(187, 198, 191, 245) or nvgRGBA(194, 91, 76, 245))
        nvgText(ctx, x + pad + iconSize + 7, rowY + iconSize * 0.5 - 5, material.item)
        nvgFontSize(ctx, 9)
        nvgFillColor(ctx, owned >= material.count and nvgRGBA(146, 181, 151, 245) or nvgRGBA(210, 104, 89, 245))
        nvgText(ctx, x + pad + iconSize + 7, rowY + iconSize * 0.5 + 9,
            tostring(owned) .. " / " .. tostring(material.count))
    end

    local buttonH = 42
    WarehouseUI.upgradeRect = { x = x + pad, y = y + h - buttonH - pad, w = w - pad * 2, h = buttonH }
    local hot = WarehouseUI.hovered == "upgrade" or WarehouseUI.pressed == "upgrade"
    local fill = atMax and { 48, 50, 50, 235 }
        or (not canUpgrade and { 67, 55, 39, 235 }
        or (hot and { 168, 116, 39, 255 } or { 126, 84, 29, 255 }))
    local border = atMax and { 80, 82, 82, 180 }
        or (not canUpgrade and { 127, 96, 57, 210 } or { 225, 181, 93, 235 })
    drawCutPanel(ctx, WarehouseUI.upgradeRect.x, WarehouseUI.upgradeRect.y,
        WarehouseUI.upgradeRect.w, WarehouseUI.upgradeRect.h, fill, border, hot and not atMax)
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(ctx, 13)
    nvgFillColor(ctx, atMax and nvgRGBA(126, 128, 128, 245) or nvgRGBA(250, 239, 211, 255))
    nvgText(ctx, WarehouseUI.upgradeRect.x + WarehouseUI.upgradeRect.w * 0.5,
        WarehouseUI.upgradeRect.y + WarehouseUI.upgradeRect.h * 0.5,
        atMax and "已满级" or (canUpgrade and "升级扩大仓库" or "材料不足"))
end

local function organizeTab(tab)
    for index, entry in ipairs(tab.items or {}) do
        tab.items[index] = {
            item = getItemName(entry),
            orientation = type(entry) == "table" and entry.orientation or nil,
        }
    end
    rebuildPlacements(tab)
end

local function drawArchivePanel(ctx, tab, data)
    local selectedIndex = clamp(WarehouseUI.selectedItemIndex or 1, 1,
        math.max(1, #(tab.items or {})))
    WarehouseUI.selectedItemIndex = selectedIndex
    local entry = tab.items and tab.items[selectedIndex]
    local itemName = entry and getItemName(entry) or "暂无物资"
    local info = getItemInfo(itemName, data)
    local rarity = (data.itemRarity and data.itemRarity[itemName]) or "green"
    local color = RARITY_COLORS[rarity] or RARITY_COLORS.green
    local iconId = data.itemIcons and data.itemIcons[itemName]
    local itemW, itemH = 1, 1
    if entry then itemW, itemH = getItemSize(entry) end

    -- 覆盖设计稿示例档案内容，保留外部金属框与标题胶带。
    nvgBeginPath(ctx)
    nvgRect(ctx, 1014, 153, 313, 447)
    nvgFillColor(ctx, nvgRGBA(208, 199, 171, 255))
    nvgFill(ctx)
    local paper = nvgLinearGradient(ctx, 1014, 153, 1327, 600,
        nvgRGBA(229, 220, 191, 245), nvgRGBA(190, 179, 148, 245))
    nvgBeginPath(ctx)
    nvgRect(ctx, 1022, 160, 297, 432)
    nvgFillPaint(ctx, paper)
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgRect(ctx, 1022, 160, 297, 432)
    nvgStrokeColor(ctx, nvgRGBA(68, 61, 46, 230))
    nvgStrokeWidth(ctx, 2)
    nvgStroke(ctx)

    nvgBeginPath(ctx)
    nvgRect(ctx, 1030, 169, 281, 194)
    nvgFillColor(ctx, nvgRGBA(201, 194, 170, 255))
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgRect(ctx, 1030, 169, 281, 194)
    nvgStrokeColor(ctx, nvgRGBA(106, 96, 73, 210))
    nvgStrokeWidth(ctx, 1.5)
    nvgStroke(ctx)

    if iconId and iconId > 0 then
        local sourceW, sourceH = nvgImageSize(ctx, iconId)
        sourceW = math.max(1, sourceW or 1)
        sourceH = math.max(1, sourceH or 1)
        local maxW, maxH = 220, 174
        local drawW, drawH = maxW, maxW * sourceH / sourceW
        if drawH > maxH then
            drawH = maxH
            drawW = maxH * sourceW / sourceH
        end
        local imageX = 1170.5 - drawW * 0.5
        local imageY = 266 - drawH * 0.5
        local paint = nvgImagePattern(ctx, imageX, imageY, drawW, drawH, 0, iconId, 1.0)
        nvgBeginPath(ctx)
        nvgRect(ctx, imageX, imageY, drawW, drawH)
        nvgFillPaint(ctx, paint)
        nvgFill(ctx)
    end

    nvgFontFace(ctx, "sans")
    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(ctx, nvgRGBA(32, 29, 23, 255))
    nvgFontSize(ctx, 21)
    nvgText(ctx, 1028, 375, itemName)
    nvgFontSize(ctx, 17)
    nvgText(ctx, 1028, 408, "品质：" .. getRarityLabel(rarity))
    nvgFillColor(ctx, nvgRGBA(color[1], color[2], color[3], 255))
    nvgText(ctx, 1122, 408, "■")
    nvgFillColor(ctx, nvgRGBA(32, 29, 23, 255))
    nvgText(ctx, 1028, 436, "大小：" .. tostring(itemW) .. "×" .. tostring(itemH))
    nvgText(ctx, 1028, 464, "价值：" .. tostring(info.value or 0))
    nvgFontSize(ctx, 15)
    local desc = tostring(info.desc or "暂无物品说明。")
    nvgTextBox(ctx, 1028, 497, 278, desc)
end

local function drawDesignTabs(ctx)
    local rects = {
        { x = 68, y = 94, w = 180, h = 47 },
        { x = 271, y = 92, w = 177, h = 49 },
        { x = 470, y = 92, w = 177, h = 49 },
    }
    WarehouseUI.tabRects = {}
    for index, rect in ipairs(rects) do
        WarehouseUI.tabRects[index] = rect
        if index == WarehouseUI.activeTab then
            nvgBeginPath(ctx)
            nvgRect(ctx, rect.x + 3, rect.y + 3, rect.w - 6, rect.h - 6)
            nvgFillColor(ctx, nvgRGBA(111, 105, 66, 42))
            nvgFill(ctx)
        end
    end
end

local function drawDesignButtons(ctx)
    WarehouseUI.rotateRect = { x = 1010, y = 625, w = 96, h = 127 }
    WarehouseUI.organizeRect = { x = 1117, y = 625, w = 100, h = 127 }
    WarehouseUI.upgradeRect = { x = 1228, y = 625, w = 108, h = 127 }
    local actions = {
        { id = "rotate", rect = WarehouseUI.rotateRect },
        { id = "organize", rect = WarehouseUI.organizeRect },
        { id = "upgrade", rect = WarehouseUI.upgradeRect },
    }
    for _, action in ipairs(actions) do
        if WarehouseUI.hovered == action.id or WarehouseUI.pressed == action.id then
            nvgBeginPath(ctx)
            nvgRect(ctx, action.rect.x + 4, action.rect.y + 4,
                action.rect.w - 8, action.rect.h - 8)
            nvgFillColor(ctx, nvgRGBA(225, 201, 139,
                WarehouseUI.pressed == action.id and 42 or 24))
            nvgFill(ctx)
        end
    end
end

function WarehouseUI.Open(tabs)
    WarehouseUI.tabs = tabs or WarehouseUI.tabs
    WarehouseUI.activeTab = 1
    WarehouseUI.hovered = nil
    WarehouseUI.pressed = nil
    WarehouseUI.infoPopup = nil
    WarehouseUI.scrollOffset = 0
    WarehouseUI.scrollMax = 0
    WarehouseUI.dragPending = false
    WarehouseUI.dragIndex = 0
    WarehouseUI.touchId = nil
    WarehouseUI.ignoreMouseTimer = 0
    WarehouseUI.notice = ""
    WarehouseUI.noticeTimer = 0
    WarehouseUI.selectedItemIndex = 1
end

function WarehouseUI.Update(dt)
    WarehouseUI.animTime = WarehouseUI.animTime + (dt or 0)
    WarehouseUI.ignoreMouseTimer = math.max(0, WarehouseUI.ignoreMouseTimer - (dt or 0))
    if WarehouseUI.noticeTimer > 0 then
        WarehouseUI.noticeTimer = math.max(0, WarehouseUI.noticeTimer - (dt or 0))
    end
end

local function getDropCellAt(x, y)
    local bestIndex = nil
    local bestDistance = math.huge
    for index, rect in ipairs(WarehouseUI.cellRects) do
        local centerX = rect.x + rect.w * 0.5
        local centerY = rect.y + rect.h * 0.5
        local dx = x - centerX
        local dy = y - centerY
        local distance = dx * dx + dy * dy
        if pointInRect(x, y, rect) and distance < bestDistance then
            bestIndex = index
            bestDistance = distance
        end
    end
    return bestIndex
end

function WarehouseUI.GetHit(x, y)
    if pointInRect(x, y, WarehouseUI.scrollThumbHitRect) then return "scroll-thumb" end
    if pointInRect(x, y, WarehouseUI.scrollBarHitRect) then return "scrollbar" end
    if pointInRect(x, y, WarehouseUI.backRect) then return "back" end
    if pointInRect(x, y, WarehouseUI.rotateRect) then return "rotate" end
    if pointInRect(x, y, WarehouseUI.organizeRect) then return "organize" end
    if pointInRect(x, y, WarehouseUI.upgradeRect) then return "upgrade" end
    for index, rect in ipairs(WarehouseUI.tabRects) do
        if pointInRect(x, y, rect) then return "tab:" .. tostring(index) end
    end
    for index, rect in ipairs(WarehouseUI.itemRects) do
        if pointInRect(x, y, rect) then return "item:" .. tostring(index) end
    end
    for index, rect in ipairs(WarehouseUI.cellRects) do
        if pointInRect(x, y, rect) then return "cell:" .. tostring(index) end
    end
    return nil
end

function WarehouseUI.PointerMove(x, y)
    x, y = screenToDesign(x, y)
    if WarehouseUI.scrollDragging then
        local thumb = WarehouseUI.scrollThumbRect
        local bar = WarehouseUI.scrollBarRect
        if thumb and bar then
            local available = math.max(1, bar.h - thumb.h)
            local deltaY = y - WarehouseUI.scrollTouchStartY
            if WarehouseUI.scrollFromGrid then deltaY = -deltaY end
            local scrollMultiplier = WarehouseUI.scrollFromGrid and 0.35 or 1.0
            WarehouseUI.scrollOffset = clamp(
                WarehouseUI.scrollStartOffset
                    + deltaY * WarehouseUI.scrollMax / available * scrollMultiplier,
                0, WarehouseUI.scrollMax)
        end
        return
    end
    WarehouseUI.hovered = WarehouseUI.GetHit(x, y)
    if WarehouseUI.dragPending or WarehouseUI.dragging then
        WarehouseUI.dragX = x
        WarehouseUI.dragY = y
        if not WarehouseUI.dragging then
            local dx = x - WarehouseUI.dragStartX
            local dy = y - WarehouseUI.dragStartY
            if dx * dx + dy * dy >= 36 then
                WarehouseUI.dragging = true
                WarehouseUI.pressed = nil
            end
        end

        if WarehouseUI.dragging then
            local targetTabIndex = tonumber(
                (WarehouseUI.hovered or ""):match("^tab:(%d+)$"))
            if targetTabIndex and targetTabIndex ~= WarehouseUI.activeTab then
                local targetItemIndex = transferItemToTab(
                    WarehouseUI.dragIndex, targetTabIndex)
                if targetItemIndex then
                    WarehouseUI.dragIndex = targetItemIndex
                else
                    local targetTab = WarehouseUI.tabs[targetTabIndex]
                    WarehouseUI.notice = targetTab and targetTab.unlocked
                        and "目标仓库空间不足，无法转移"
                        or "该仓库尚未解锁"
                    WarehouseUI.noticeTimer = 1.6
                end
            end
        end
    end
end

function WarehouseUI.PointerDown(x, y)
    x, y = screenToDesign(x, y)
    if WarehouseUI.infoPopup then
        if pointInRect(x, y, WarehouseUI.popupRotateRect) then
            WarehouseUI.pressed = "popup-rotate"
            return "popup-rotate"
        end
        if pointInRect(x, y, WarehouseUI.infoPopup) then
            WarehouseUI.pressed = "popup"
            return "popup"
        end
        WarehouseUI.infoPopup = nil
        WarehouseUI.pressed = nil
        return "popup-dismiss"
    end
    local hit = WarehouseUI.GetHit(x, y)
    if hit == "scroll-thumb" then
        WarehouseUI.scrollDragging = true
        WarehouseUI.scrollTouchStartX = x
        WarehouseUI.scrollTouchStartY = y
        WarehouseUI.scrollStartOffset = WarehouseUI.scrollOffset
        WarehouseUI.pressed = hit
        return hit
    elseif hit == "scrollbar" then
        local bar = WarehouseUI.scrollBarRect
        local thumb = WarehouseUI.scrollThumbRect
        local target = clamp(y - thumb.h * 0.5, bar.y, bar.y + bar.h - thumb.h)
        WarehouseUI.scrollOffset = (target - bar.y) / math.max(1, bar.h - thumb.h) * WarehouseUI.scrollMax
        WarehouseUI.scrollDragging = true
        WarehouseUI.scrollTouchStartX = x
        WarehouseUI.scrollTouchStartY = y
        WarehouseUI.scrollStartOffset = WarehouseUI.scrollOffset
        WarehouseUI.pressed = hit
        return hit
    elseif hit and hit:match("^cell:") and WarehouseUI.scrollMax > 0 then
        WarehouseUI.scrollDragging = true
        WarehouseUI.scrollFromGrid = true
        WarehouseUI.scrollTouchStartX = x
        WarehouseUI.scrollTouchStartY = y
        WarehouseUI.scrollStartOffset = WarehouseUI.scrollOffset
        WarehouseUI.pressed = hit
        return "grid-scroll"
    end
    WarehouseUI.pressed = hit
    local itemIndex = hit and tonumber(hit:match("^item:(%d+)$"))
    if itemIndex then
        local rect = WarehouseUI.itemRects[itemIndex]
        WarehouseUI.dragOffsetX = rect and (x - rect.x) or 0
        WarehouseUI.dragOffsetY = rect and (y - rect.y) or 0
        WarehouseUI.dragPending = true
        WarehouseUI.dragging = false
        WarehouseUI.dragIndex = itemIndex
        WarehouseUI.dragStartX = x
        WarehouseUI.dragStartY = y
        WarehouseUI.dragX = x
        WarehouseUI.dragY = y
        return "item"
    end
    return hit
end

function WarehouseUI.TouchBegin(touchId, x, y)
    if WarehouseUI.touchId ~= nil then return false end
    WarehouseUI.touchId = touchId
    WarehouseUI.ignoreMouseTimer = 0.5
    WarehouseUI.PointerDown(x, y)
    return true
end

function WarehouseUI.TouchMove(touchId, x, y)
    if WarehouseUI.touchId ~= touchId then return false end
    WarehouseUI.ignoreMouseTimer = 0.5
    WarehouseUI.PointerMove(x, y)
    return true
end

function WarehouseUI.TouchEnd(touchId, x, y)
    if WarehouseUI.touchId ~= touchId then return nil end
    WarehouseUI.ignoreMouseTimer = 0.5
    WarehouseUI.PointerMove(x, y)
    local action = WarehouseUI.PointerUp(x, y)
    WarehouseUI.touchId = nil
    return action
end

function WarehouseUI.ShouldIgnoreMouse()
    return WarehouseUI.touchId ~= nil or WarehouseUI.ignoreMouseTimer > 0
end

function WarehouseUI.PointerUp(x, y)
    x, y = screenToDesign(x, y)
    if WarehouseUI.scrollDragging then
        WarehouseUI.scrollDragging = false
        WarehouseUI.scrollFromGrid = false
        WarehouseUI.pressed = nil
        return "scroll"
    end
    local wasDragging = WarehouseUI.dragging
    local wasPending = WarehouseUI.dragPending
    local dragIndex = WarehouseUI.dragIndex
    WarehouseUI.dragPending = false
    WarehouseUI.dragging = false
    WarehouseUI.dragIndex = 0
    local hit
    if WarehouseUI.pressed == "popup-rotate" and pointInRect(x, y, WarehouseUI.popupRotateRect) then
        hit = "popup-rotate"
    elseif WarehouseUI.pressed == "popup" and pointInRect(x, y, WarehouseUI.infoPopup) then
        hit = "popup"
    else
        hit = WarehouseUI.GetHit(x, y)
    end
    local action = hit and hit == WarehouseUI.pressed and hit or nil
    WarehouseUI.pressed = nil

    if wasDragging and dragIndex > 0 then
        local targetTabIndex = tonumber((hit or ""):match("^tab:(%d+)$"))
        if targetTabIndex then
            if targetTabIndex == WarehouseUI.activeTab then
                return "move"
            end
            local targetItemIndex = transferItemToTab(dragIndex, targetTabIndex)
            if targetItemIndex then
                return "move"
            end
            local targetTab = WarehouseUI.tabs[targetTabIndex]
            WarehouseUI.notice = targetTab and targetTab.unlocked
                and "目标仓库空间不足，无法转移"
                or "该仓库尚未解锁"
            WarehouseUI.noticeTimer = 1.6
            return "move"
        end

        local cellW = math.max(1, WarehouseUI.gridCellW)
        local cellH = math.max(1, WarehouseUI.gridCellH)
        local anchorX = x - WarehouseUI.dragOffsetX + cellW * 0.5
        local anchorY = y - WarehouseUI.dragOffsetY + cellH * 0.5
        local cellIndex = getDropCellAt(anchorX, anchorY)
        local tab = getTab()
        if cellIndex and tab and canPlaceItem(tab, dragIndex, cellIndex) then
            setItemCell(tab, dragIndex, cellIndex)
            rebuildPlacements(tab)
            WarehouseUI.notice = ""
            WarehouseUI.noticeTimer = 0
        else
            WarehouseUI.notice = cellIndex and "目标区域空间不足，无法摆放" or "物资已放回原位"
            WarehouseUI.noticeTimer = 1.6
        end
        return "move"
    end

    if wasPending and dragIndex > 0 then
        action = "item:" .. tostring(dragIndex)
    end

    if not action then return nil end

    if action == "popup-rotate" then
        local popup = WarehouseUI.infoPopup
        local tab = getTab()
        if popup and tab and rotateItem(tab, popup.itemIndex) then
            local placement = WarehouseUI.placements[popup.itemIndex]
            if placement then
                popup.wCells = placement.w
                popup.hCells = placement.h
            end
        else
            WarehouseUI.notice = "当前空间无法旋转该物品"
            WarehouseUI.noticeTimer = 1.6
        end
        return "rotate"
    end

    if action == "popup" then return nil end

    local itemIndex = tonumber(action:match("^item:(%d+)$"))
    if itemIndex then
        WarehouseUI.selectedItemIndex = itemIndex
        WarehouseUI.infoPopup = nil
        return "item-info"
    end

    local tabIndex = action:match("^tab:(%d+)$")
    if tabIndex then
        local index = tonumber(tabIndex)
        local tab = WarehouseUI.tabs[index]
        if tab and tab.unlocked then
            WarehouseUI.activeTab = index
            WarehouseUI.selectedItemIndex = 1
            WarehouseUI.scrollOffset = 0
            WarehouseUI.infoPopup = nil
            WarehouseUI.notice = ""
            WarehouseUI.noticeTimer = 0
        else
            WarehouseUI.notice = "该仓库尚未解锁"
            WarehouseUI.noticeTimer = 1.8
        end
        return "tab"
    end

    if action == "rotate" then
        local tab = getTab()
        local itemIndex = WarehouseUI.selectedItemIndex or 1
        if tab and tab.items[itemIndex] and rotateItem(tab, itemIndex) then
            WarehouseUI.notice = "物品已旋转"
            WarehouseUI.noticeTimer = 1.2
        else
            WarehouseUI.notice = "请选择可旋转且有足够空间的物品"
            WarehouseUI.noticeTimer = 1.8
        end
        return "rotate"
    end

    if action == "organize" then
        local tab = getTab()
        if tab then
            organizeTab(tab)
            WarehouseUI.selectedItemIndex = clamp(WarehouseUI.selectedItemIndex or 1,
                1, math.max(1, #(tab.items or {})))
            WarehouseUI.notice = "仓库整理完成"
            WarehouseUI.noticeTimer = 1.4
        end
        return "move"
    end

    if action == "upgrade" then
        local tab = getTab()
        local nextLevel = tab and ((tab.level or 1) + 1) or 0
        local materials = tab and tab.upgradeMaterials and tab.upgradeMaterials[nextLevel] or {}
        if tab and tab.unlocked and (tab.level or 1) < (tab.maxLevel or 3)
            and hasUpgradeMaterials(tab, materials) then
            consumeUpgradeMaterials(tab, materials)
            tab.level = nextLevel
            if tab.level == 2 then
                tab.rows = (tab.rows or 6) + 2
            else
                tab.cols = (tab.cols or 8) + 2
            end
            rebuildPlacements(tab)
            WarehouseUI.notice = ""
            WarehouseUI.noticeTimer = 0
        elseif tab and not hasUpgradeMaterials(tab, materials) then
            WarehouseUI.notice = "升级材料不足"
            WarehouseUI.noticeTimer = 1.8
        else
            WarehouseUI.notice = "当前仓库无法继续升级"
            WarehouseUI.noticeTimer = 1.8
        end
        return "upgrade"
    end

    return action
end

function WarehouseUI.Draw(ctx, width, height, data)
    data = data or {}
    local tab = getTab()
    if not tab then return end

    local scale = math.min(width / DESIGN_W, height / DESIGN_H)
    local drawW = DESIGN_W * scale
    local drawH = DESIGN_H * scale
    local offsetX = (width - drawW) * 0.5
    local offsetY = (height - drawH) * 0.5
    WarehouseUI.layoutScale = scale
    WarehouseUI.layoutOffsetX = offsetX
    WarehouseUI.layoutOffsetY = offsetY

    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, width, height)
    nvgFillColor(ctx, nvgRGBA(4, 6, 5, 255))
    nvgFill(ctx)

    nvgSave(ctx)
    nvgTranslate(ctx, offsetX, offsetY)
    nvgScale(ctx, scale, scale)

    if not drawImageRect(ctx, data.masterImage, 0, 0, DESIGN_W, DESIGN_H) then
        nvgBeginPath(ctx)
        nvgRect(ctx, 0, 0, DESIGN_W, DESIGN_H)
        nvgFillColor(ctx, nvgRGBA(12, 14, 12, 255))
        nvgFill(ctx)
    end

    -- 清空母版中的示例物品，只保留设计稿网格与旧纸金属框架。
    nvgBeginPath(ctx)
    nvgRect(ctx, 50, 150, 850, 532)
    nvgFillColor(ctx, nvgRGBA(9, 13, 11, 246))
    nvgFill(ctx)

    local usedCells = 0
    rebuildPlacements(tab)
    for _, placement in pairs(WarehouseUI.placements) do
        usedCells = usedCells + placement.w * placement.h
    end
    local capacity = getCapacity(tab)
    nvgBeginPath(ctx)
    nvgRect(ctx, 772, 91, 135, 57)
    nvgFillColor(ctx, nvgRGBA(31, 29, 21, 245))
    nvgFill(ctx)
    nvgFontFace(ctx, "sans")
    nvgTextAlign(ctx, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    nvgFontSize(ctx, 20)
    nvgFillColor(ctx, nvgRGBA(218, 207, 176, 255))
    nvgText(ctx, 897, 97, "容量 " .. tostring(usedCells) .. "/" .. tostring(capacity))
    nvgText(ctx, 897, 121, "仓库等级 " .. tostring(tab.level or 1))

    drawDesignTabs(ctx)
    WarehouseUI.backRect = { x = 1304, y = 10, w = 57, h = 55 }

    drawGrid(ctx, 50, 150, 870, 532, tab, data)
    drawArchivePanel(ctx, tab, data)
    drawDesignButtons(ctx)

    if WarehouseUI.noticeTimer > 0 and WarehouseUI.notice ~= "" then
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, 500, 704, 400, 42, 5)
        nvgFillColor(ctx, nvgRGBA(24, 24, 19, 244))
        nvgFill(ctx)
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, 500, 704, 400, 42, 5)
        nvgStrokeColor(ctx, nvgRGBA(186, 153, 81, 220))
        nvgStrokeWidth(ctx, 1)
        nvgStroke(ctx)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFontSize(ctx, 16)
        nvgFillColor(ctx, nvgRGBA(235, 224, 196, 255))
        nvgText(ctx, 700, 725, WarehouseUI.notice)
    end

    nvgRestore(ctx)
end

return WarehouseUI
