local GameplayHUD = {}

local DESIGN_W = 1365
local DESIGN_H = 768

local COLORS = {
    bone = { 213, 194, 151, 238 },
    brass = { 193, 143, 48, 238 },
    brassDim = { 145, 103, 37, 190 },
    blood = { 112, 31, 28, 210 },
    bloodBright = { 158, 49, 39, 235 },
    stamina = { 61, 113, 105, 220 },
    shadow = { 4, 5, 4, 150 },
}

local function rgba(color, alpha)
    return nvgRGBA(color[1], color[2], color[3], alpha or color[4] or 255)
end

local function drawSprite(ctx, image, x, y, w, h, alpha)
    if not image or image <= 0 then return false end
    local paint = nvgImagePattern(ctx, x, y, w, h, 0, image, alpha or 1.0)
    nvgBeginPath(ctx)
    nvgRect(ctx, x, y, w, h)
    nvgFillPaint(ctx, paint)
    nvgFill(ctx)
    return true
end

local function drawShadowText(ctx, x, y, text, size, align, color)
    nvgFontFace(ctx, "sans")
    nvgFontSize(ctx, size)
    nvgTextAlign(ctx, align)
    nvgFillColor(ctx, nvgRGBA(0, 0, 0, 225))
    nvgText(ctx, x + 2, y + 2, text)
    nvgFillColor(ctx, rgba(color))
    nvgText(ctx, x, y, text)
end

local function drawRoughLine(ctx, x1, y1, x2, y2, color, width)
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, x1, y1)
    nvgLineTo(ctx, x2, y2)
    nvgStrokeColor(ctx, rgba(color))
    nvgStrokeWidth(ctx, width)
    nvgStroke(ctx)

    nvgBeginPath(ctx)
    nvgMoveTo(ctx, x1 + 4, y1 + 2)
    nvgLineTo(ctx, x2 - 9, y2 + 1)
    nvgStrokeColor(ctx, nvgRGBA(color[1], color[2], color[3], 65))
    nvgStrokeWidth(ctx, math.max(1, width * 0.45))
    nvgStroke(ctx)
end

local function drawHeart(ctx, cx, cy, size, ratio, time)
    local pulse = ratio <= 0.35 and (1.0 + math.sin((time or 0) * 7.0) * 0.06) or 1.0
    size = size * pulse
    nvgSave(ctx)
    nvgTranslate(ctx, cx, cy)
    nvgScale(ctx, size / 42, size / 42)
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, 0, 17)
    nvgBezierTo(ctx, -5, 10, -20, 2, -19, -9)
    nvgBezierTo(ctx, -18, -20, -5, -24, 0, -15)
    nvgBezierTo(ctx, 5, -24, 18, -20, 19, -9)
    nvgBezierTo(ctx, 20, 2, 5, 10, 0, 17)
    nvgClosePath(ctx)
    nvgFillColor(ctx, ratio <= 0.35 and rgba(COLORS.bloodBright) or rgba(COLORS.bone, 220))
    nvgFill(ctx)

    nvgBeginPath(ctx)
    nvgMoveTo(ctx, -14, 10)
    nvgLineTo(ctx, 9, -17)
    nvgMoveTo(ctx, -5, 16)
    nvgLineTo(ctx, 17, -8)
    nvgMoveTo(ctx, -18, -5)
    nvgLineTo(ctx, 4, -15)
    nvgStrokeColor(ctx, nvgRGBA(74, 27, 24, 205))
    nvgStrokeWidth(ctx, 2.2)
    nvgStroke(ctx)
    nvgRestore(ctx)
end

local function drawHealth(ctx, data, s)
    local hpMax = math.max(1, data.hpMax or 100)
    local hp = math.max(0, math.min(hpMax, data.hp or hpMax))
    local hpRatio = hp / hpMax
    local staminaMax = math.max(1, data.staminaMax or 100)
    local stamina = math.max(0, math.min(staminaMax, data.stamina or staminaMax))
    local staminaRatio = stamina / staminaMax
    local x = 38 * s
    local y = 42 * s

    if not drawSprite(ctx, data.sprites and data.sprites.heart,
        24 * s, 28 * s, 62 * s, 83 * s, 1.0) then
        drawHeart(ctx, 55 * s, 69 * s, 43 * s, hpRatio, data.time)
    end
    drawShadowText(ctx, 104 * s, 70 * s,
        tostring(math.floor(hp + 0.5)), 31 * s,
        NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE,
        hpRatio <= 0.35 and COLORS.bloodBright or COLORS.bone)

    local barX = 103 * s
    local barY = 95 * s
    local barW = 220 * s
    drawRoughLine(ctx, barX, barY, barX + barW, barY, { 72, 31, 28, 150 }, 4.0 * s)
    drawRoughLine(ctx, barX, barY, barX + barW * hpRatio, barY, COLORS.bloodBright, 4.0 * s)
    drawRoughLine(ctx, barX, barY + 18 * s, barX + barW, barY + 18 * s,
        { 25, 48, 46, 155 }, 3.0 * s)
    drawRoughLine(ctx, barX, barY + 18 * s, barX + barW * staminaRatio, barY + 18 * s,
        COLORS.stamina, 3.0 * s)
end

local function drawWeaponImage(ctx, image, x, y, w, h)
    if not image or image <= 0 then return false end
    local paint = nvgImagePattern(ctx, x, y, w, h, 0, image, 0.78)
    nvgBeginPath(ctx)
    nvgRect(ctx, x, y, w, h)
    nvgFillPaint(ctx, paint)
    nvgFill(ctx)
    return true
end

local function drawJoystick(ctx, data, s)
    local cx = 184 * s
    local cy = 628 * s
    local radius = 90 * s
    local moveX = (data.moveX or 0) * 34 * s
    local moveY = -(data.moveY or 0) * 34 * s
    local outer = { 127, 108, 70, 112 }
    local inner = { 155, 138, 99, 105 }

    -- 参考图的摇杆是透明磨损双环，不带任何黑色底盘。
    nvgBeginPath(ctx)
    nvgCircle(ctx, cx, cy, radius)
    nvgStrokeColor(ctx, rgba(outer))
    nvgStrokeWidth(ctx, 2.0 * s)
    nvgStroke(ctx)
    nvgBeginPath(ctx)
    nvgCircle(ctx, cx, cy, radius - 5 * s)
    nvgStrokeColor(ctx, nvgRGBA(78, 65, 41, 76))
    nvgStrokeWidth(ctx, 1.1 * s)
    nvgStroke(ctx)

    -- 磨损缺口：用短弧段与方向刻痕打破规则圆形。
    for i = 0, 7 do
        local a = i * math.pi * 0.25 + 0.12
        local arcR = radius - ((i % 2) * 3) * s
        nvgBeginPath(ctx)
        nvgArc(ctx, cx, cy, arcR, a, a + 0.18 + (i % 3) * 0.04, NVG_CW)
        nvgStrokeColor(ctx, nvgRGBA(190, 164, 112, 78 + (i % 2) * 28))
        nvgStrokeWidth(ctx, (i % 3 == 0 and 2.0 or 1.1) * s)
        nvgStroke(ctx)
    end

    -- 内芯是真实摇杆旋钮，会随 moveX/moveY 移动。
    local knobX = cx + moveX
    local knobY = cy + moveY
    local knobR = 42 * s
    nvgBeginPath(ctx)
    nvgCircle(ctx, knobX, knobY, knobR)
    nvgFillColor(ctx, nvgRGBA(58, 55, 42, 30))
    nvgFill(ctx)
    nvgStrokeColor(ctx, rgba(inner))
    nvgStrokeWidth(ctx, 1.7 * s)
    nvgStroke(ctx)
    nvgBeginPath(ctx)
    nvgCircle(ctx, knobX, knobY, knobR - 4 * s)
    nvgStrokeColor(ctx, nvgRGBA(78, 72, 52, 70))
    nvgStrokeWidth(ctx, 1.0 * s)
    nvgStroke(ctx)

    for i = 0, 3 do
        local angle = i * math.pi * 0.5
        local x1 = cx + math.cos(angle) * 72 * s
        local y1 = cy + math.sin(angle) * 72 * s
        local x2 = cx + math.cos(angle) * 82 * s
        local y2 = cy + math.sin(angle) * 82 * s
        drawRoughLine(ctx, x1, y1, x2, y2, { 183, 160, 112, 82 }, 1.3 * s)
    end
end

local function drawAmmo(ctx, data, s)
    local x = 315 * s
    local y = 655 * s
    local weaponW = 72 * s
    local weaponH = 45 * s
    local ammo = math.max(0, data.ammo or 0)
    local ammoMax = math.max(1, data.ammoMax or 1)
    local ammoColor = COLORS.bone

    if not drawSprite(ctx, data.sprites and data.sprites.weapon,
        296 * s, 625 * s, 101 * s, 91 * s, 1.0) then
        drawWeaponImage(ctx, data.weaponIcon, x, y - 9 * s, weaponW, weaponH)
    end
    drawShadowText(ctx, x + 82 * s, y + 8 * s,
        string.format("%02d", ammo), 38 * s,
        NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE, ammoColor)
    drawShadowText(ctx, x + 143 * s, y + 13 * s,
        "/ " .. tostring(ammoMax), 19 * s,
        NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE, COLORS.bone)

    local pipY = y + 37 * s
    local count = math.min(ammoMax, 8)
    for i = 1, count do
        local px = x + 84 * s + (i - 1) * 11 * s
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, px, pipY, 7 * s, 2.5 * s, s)
        nvgFillColor(ctx, i <= ammo and rgba(ammoColor, 205) or nvgRGBA(92, 82, 63, 90))
        nvgFill(ctx)
    end

    return {
        x = x - 12 * s,
        y = y - 18 * s,
        w = 230 * s,
        h = 72 * s,
    }
end

local function drawBackpack(ctx, data, cx, cy, size, alpha)
    if drawSprite(ctx, data.sprites and data.sprites.backpack,
        cx - size * 0.5, cy - size * 0.53, size, size * 1.06, alpha or 1.0) then
        return
    end
    if data.backpackImage and data.backpackImage > 0 then
        local paint = nvgImagePattern(ctx, cx - size * 0.5, cy - size * 0.5,
            size, size, 0, data.backpackImage, alpha or 0.78)
        nvgBeginPath(ctx)
        nvgRect(ctx, cx - size * 0.5, cy - size * 0.5, size, size)
        nvgFillPaint(ctx, paint)
        nvgFill(ctx)
        return
    end

    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, cx - size * 0.28, cy - size * 0.20,
        size * 0.56, size * 0.55, size * 0.08)
    nvgStrokeColor(ctx, rgba(COLORS.bone, 205))
    nvgStrokeWidth(ctx, 2)
    nvgStroke(ctx)
    nvgBeginPath(ctx)
    nvgArc(ctx, cx, cy - size * 0.20, size * 0.16, math.pi, math.pi * 2, NVG_CW)
    nvgStrokeColor(ctx, rgba(COLORS.bone, 205))
    nvgStroke(ctx)
end

local function drawReload(ctx, cx, cy, size, color, image)
    if drawSprite(ctx, image, cx - size * 0.5, cy - size * 0.5,
        size, size, 1.0) then
        return
    end
    nvgBeginPath(ctx)
    nvgArc(ctx, cx, cy, size * 0.34, -math.pi * 0.15, math.pi * 1.35, NVG_CW)
    nvgStrokeColor(ctx, rgba(color, 220))
    nvgStrokeWidth(ctx, 2.2)
    nvgStroke(ctx)
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, cx - size * 0.35, cy - size * 0.12)
    nvgLineTo(ctx, cx - size * 0.47, cy + size * 0.08)
    nvgLineTo(ctx, cx - size * 0.24, cy + size * 0.06)
    nvgFillColor(ctx, rgba(color, 220))
    nvgFill(ctx)
    for i = -1, 1 do
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, cx + i * size * 0.12 - size * 0.035,
            cy - size * 0.16, size * 0.07, size * 0.33, size * 0.02)
        nvgFillColor(ctx, rgba(color, 205))
        nvgFill(ctx)
    end
end

local function drawAttack(ctx, data, cx, cy, radius, scale)
    radius = radius * scale

    -- 透明暗红圆面，不使用带场景像素的整图切片。
    nvgBeginPath(ctx)
    nvgCircle(ctx, cx, cy, radius)
    nvgFillColor(ctx, nvgRGBA(64, 17, 14, 92))
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(122, 70, 42, 178))
    nvgStrokeWidth(ctx, 2.4 * (radius / 91))
    nvgStroke(ctx)

    nvgBeginPath(ctx)
    nvgCircle(ctx, cx, cy, radius - 6 * (radius / 91))
    nvgStrokeColor(ctx, nvgRGBA(55, 30, 22, 185))
    nvgStrokeWidth(ctx, 2.0 * (radius / 91))
    nvgStroke(ctx)

    for i = 0, 9 do
        local a = i * math.pi * 0.2 + 0.08
        nvgBeginPath(ctx)
        nvgArc(ctx, cx, cy, radius - (i % 2) * 3,
            a, a + 0.12 + (i % 3) * 0.035, NVG_CW)
        nvgStrokeColor(ctx, nvgRGBA(177, 112, 60, 90 + (i % 2) * 38))
        nvgStrokeWidth(ctx, (i % 3 == 0 and 2.1 or 1.1) * (radius / 91))
        nvgStroke(ctx)
    end

    nvgBeginPath(ctx)
    nvgCircle(ctx, cx, cy, radius * 0.40)
    nvgStrokeColor(ctx, rgba(COLORS.bone, 205))
    nvgStrokeWidth(ctx, 1.9 * (radius / 91))
    nvgStroke(ctx)

    local gap = radius * 0.18
    local reach = radius * 0.53
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, cx - reach, cy)
    nvgLineTo(ctx, cx - gap, cy)
    nvgMoveTo(ctx, cx + gap, cy)
    nvgLineTo(ctx, cx + reach, cy)
    nvgMoveTo(ctx, cx, cy - reach)
    nvgLineTo(ctx, cx, cy - gap)
    nvgMoveTo(ctx, cx, cy + gap)
    nvgLineTo(ctx, cx, cy + reach)
    nvgStrokeColor(ctx, rgba(COLORS.bone, 205))
    nvgStrokeWidth(ctx, 2.1)
    nvgStroke(ctx)

    nvgBeginPath(ctx)
    nvgCircle(ctx, cx, cy, 3.2)
    nvgFillColor(ctx, rgba(COLORS.bloodBright, 220))
    nvgFill(ctx)
end

local function drawEdgeScratches(ctx, data, s)
    local alpha = data.hpRatio and data.hpRatio <= 0.35 and 155 or 58
    local w = data.width
    local h = data.height
    local scratches = {
        { 12, 0, 72, 47 }, { 31, 0, 85, 28 }, { 0, 64, 43, 18 },
        { DESIGN_W - 8, 12, DESIGN_W - 78, 54 },
        { DESIGN_W, DESIGN_H - 90, DESIGN_W - 54, DESIGN_H - 22 },
        { 0, DESIGN_H - 74, 69, DESIGN_H - 18 },
    }
    local sx = w / DESIGN_W
    local sy = h / DESIGN_H
    for _, line in ipairs(scratches) do
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, line[1] * sx, line[2] * sy)
        nvgLineTo(ctx, line[3] * sx, line[4] * sy)
        nvgStrokeColor(ctx, nvgRGBA(104, 24, 21, alpha))
        nvgStrokeWidth(ctx, 2.2 * s)
        nvgStroke(ctx)
    end
end

function GameplayHUD.Draw(ctx, data)
    local w = data.width
    local h = data.height
    local s = math.min(w / DESIGN_W, h / DESIGN_H)
    local rects = {}

    nvgSave(ctx)
    nvgResetScissor(ctx)
    drawEdgeScratches(ctx, data, s)
    drawHealth(ctx, data, s)
    drawJoystick(ctx, data, s)

    if data.hasWeapon then
        rects.weapon = drawAmmo(ctx, data, s)
    end

    local attackCX = 1196 * s
    local attackCY = 618 * s
    local attackRadius = 91 * s
    if data.hasWeapon then
        drawAttack(ctx, data, attackCX, attackCY, attackRadius, data.attackScale or 1.0)
        rects.attack = {
            x = attackCX - attackRadius,
            y = attackCY - attackRadius,
            w = attackRadius * 2,
            h = attackRadius * 2,
        }
    end

    local bagCX = 1021 * s
    local bagCY = 584 * s
    local bagSize = 105 * s
    drawBackpack(ctx, data, bagCX, bagCY, bagSize, 1.0)
    rects.inventory = {
        x = bagCX - 52 * s,
        y = bagCY - 55 * s,
        w = 105 * s,
        h = 111 * s,
    }

    if data.showReload then
        local reloadCX = 1048 * s
        local reloadCY = 671 * s
        local reloadSize = 88 * s
        nvgSave(ctx)
        nvgTranslate(ctx, reloadCX, reloadCY)
        nvgScale(ctx, data.reloadScale or 1.0, data.reloadScale or 1.0)
        nvgTranslate(ctx, -reloadCX, -reloadCY)
        drawReload(ctx, reloadCX, reloadCY, reloadSize,
            (data.ammo or 0) <= 0 and COLORS.bloodBright or COLORS.bone,
            data.sprites and data.sprites.reload)
        nvgRestore(ctx)
        rects.reload = {
            x = reloadCX - 44 * s,
            y = reloadCY - 44 * s,
            w = 88 * s,
            h = 88 * s,
        }
    end

    if data.consumeName then
        local useCX = w - 370 * s
        local useCY = h - 72 * s
        local useSize = 45 * s
        drawShadowText(ctx, useCX, useCY, "+", 31 * s,
            NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE, COLORS.bone)
        rects.consume = {
            x = useCX - 30 * s,
            y = useCY - 30 * s,
            w = 60 * s,
            h = 60 * s,
            itemName = data.consumeName,
        }
    end

    if data.showDoor then
        local anchorX = data.doorAnchorX or w * 0.58
        local anchorY = data.doorAnchorY or h * 0.54
        rects.door = GameplayHUD.DrawPrompt(ctx, {
            x = anchorX,
            y = anchorY,
            text = data.doorText or "开门",
            scale = s,
            side = anchorX > w * 0.68 and "left" or "right",
        })
    end

    if data.showLadderStay then
        rects.ladder = GameplayHUD.DrawPrompt(ctx, {
            x = w * 0.52,
            y = h * 0.48,
            text = "停留",
            scale = s,
            side = "left",
        })
    end

    nvgRestore(ctx)
    return rects
end

function GameplayHUD.DrawPrompt(ctx, data)
    local s = data.scale or 1
    local x = data.x
    local y = data.y
    local side = data.side or "right"
    local direction = side == "left" and -1 or 1
    local elbowX = x + direction * 28 * s
    local textX = elbowX + direction * 18 * s
    local textAlign = side == "left"
        and (NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        or (NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)

    nvgBeginPath(ctx)
    nvgCircle(ctx, x, y, 4.5 * s)
    nvgStrokeColor(ctx, rgba(COLORS.brass, 230))
    nvgStrokeWidth(ctx, 1.6 * s)
    nvgStroke(ctx)
    nvgBeginPath(ctx)
    nvgCircle(ctx, x, y, 1.6 * s)
    nvgFillColor(ctx, rgba(COLORS.brass, 240))
    nvgFill(ctx)

    nvgBeginPath(ctx)
    nvgMoveTo(ctx, x + direction * 5 * s, y)
    nvgLineTo(ctx, elbowX, y)
    nvgLineTo(ctx, elbowX + direction * 10 * s, y - 11 * s)
    nvgStrokeColor(ctx, rgba(COLORS.brass, 220))
    nvgStrokeWidth(ctx, 1.5 * s)
    nvgStroke(ctx)

    drawShadowText(ctx, textX, y - 13 * s, data.text or "交互",
        19 * s, textAlign, COLORS.brass)

    local hitW = 104 * s
    local hitH = 58 * s
    return {
        x = side == "left" and (textX - hitW) or (x - 12 * s),
        y = y - 34 * s,
        w = hitW,
        h = hitH,
        key = data.key,
    }
end

return GameplayHUD
