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

local function drawTopIcons(ctx, master)
    for _, action in ipairs(TOP_ACTIONS) do
        local rect = { x = action.x, y = 14, w = 52, h = 42 }
        drawMasterCrop(ctx, master, action.x, 14, 52, 42,
            rect.x, rect.y, rect.w, rect.h, interactiveTint(action.id))
        drawInteractionOutline(ctx, action.id, rect, COLORS.gold)
    end
end

local function drawBottom(ctx, master)
    for _, section in ipairs(SECTIONS) do
        local rect = { x = section.x, y = 642, w = section.w, h = 114 }
        drawMasterCrop(ctx, master, section.x, 642, section.w, 114,
            rect.x, rect.y, rect.w, rect.h, interactiveTint(section.id))
        drawInteractionOutline(ctx, section.id, rect, COLORS.gold)
    end

    -- 按设计稿完整外接范围复刻，包含顶部边框、外沿阴影和底部留白。
    -- 默认状态直接还原母版像素；交互染色只作用于内部，避免出现矩形外框。
    drawMasterCrop(ctx, master, 752, 628, 262, 136,
        752, 628, 262, 136)
    local equipTint = interactiveTint("equip")
    if equipTint then
        drawMasterCrop(ctx, master, 767, 648, 233, 100,
            767, 648, 233, 100, equipTint)
    end

    drawMasterCrop(ctx, master, 1018, 628, 340, 136,
        1018, 628, 340, 136)
    local deployTint = interactiveTint("deploy")
    if deployTint then
        drawMasterCrop(ctx, master, 1033, 648, 313, 100,
            1033, 648, 313, 100, deployTint)
    end
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
        HomeUI.SetNotice("主线任务：前往东京废弃城区", 2.6)
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
    drawMasterCrop(ctx, master, 667, 74, 688, 543,
        667, 74, 688, 543)

    -- 顶部与底部从设计稿逐组件取材，保持原稿视觉但不铺整张图。
    drawMasterCrop(ctx, master, 653, 14, 510, 42, 653, 14, 510, 42)
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
