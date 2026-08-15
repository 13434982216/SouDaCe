-- 大阪临港工业区：横版左右移动关卡。
-- 背景使用设计稿拆分图，角色、守卫和前景道具独立绘制，碰撞由代码控制。

local PortLevel = {}

local DESIGN_ASPECT = 16 / 9
local IMAGE_GROUND_RATIO = 0.605
local PANEL_HEIGHT_SCALE = 1.72
local PANEL_OVERLAP_RATIO = 0.075
local GATE_X_RATIO = 0.515
local GATE_HALF_WIDTH = 48
local GATE_HEIGHT = 300
local GUARD_HEIGHT = 146

local leftImage = 0
local mainImage = 0
local guardImage = 0
local barricadeImage = 0
local layout = {
    panelW = 0,
    panelH = 0,
    panelTop = 0,
    mainX = 0,
    worldLength = 0,
    gateX = 0,
    groundY = 0,
}

function PortLevel.SetImages(left, main, guard, barricade)
    leftImage = left or 0
    mainImage = main or 0
    guardImage = guard or 0
    barricadeImage = barricade or 0
    print("[PortLevel] 临港素材已绑定: left=" .. tostring(leftImage)
        .. " main=" .. tostring(mainImage)
        .. " guard=" .. tostring(guardImage)
        .. " barricade=" .. tostring(barricadeImage))
end

function PortLevel.Recalculate(screenHeight, groundY, sceneZoom)
    local zoom = math.max(0.1, sceneZoom or 1.0)
    -- 背景在主渲染链中还会乘一次 SCENE_ZOOM，因此这里先除以 zoom。
    -- PANEL_HEIGHT_SCALE 让最终可见高度覆盖整块横屏，避免 16:9 素材只占下半屏。
    local panelH = screenHeight * PANEL_HEIGHT_SCALE / zoom
    local panelW = panelH * DESIGN_ASPECT
    local overlap = panelW * PANEL_OVERLAP_RATIO

    layout.panelW = panelW
    layout.panelH = panelH
    layout.panelTop = groundY - panelH * IMAGE_GROUND_RATIO
    layout.mainX = panelW - overlap
    layout.worldLength = layout.mainX + panelW
    layout.groundY = groundY
    layout.gateX = layout.mainX + panelW * GATE_X_RATIO

    return layout
end

function PortLevel.GetLayout()
    return layout
end

function PortLevel.GetWorldLength()
    return layout.worldLength
end

function PortLevel.GetGateWorldX()
    return layout.gateX
end

function PortLevel.GetPlayerStartX()
    return math.max(180, layout.panelW * 0.28)
end

function PortLevel.GetZombieSpawns()
    return {
        layout.mainX + layout.panelW * 0.20,
        layout.mainX + layout.panelW * 0.84,
    }
end

function PortLevel.ApplyColliders(colliders)
    colliders.slabs = {}
    colliders.walls = {}
    colliders.ladders = {}

    -- 碰撞示意：
    -- 偷渡登陆区 ───────────── [世界组织封锁铁门] ───────────── 港区封锁线
    -- 地面 relY=0；铁门覆盖角色全高，角色只能沿水平道路左右移动。
    colliders.walls[1] = {
        wx1 = layout.gateX - GATE_HALF_WIDTH,
        wx2 = layout.gateX + GATE_HALF_WIDTH,
        relY1 = -GATE_HEIGHT,
        relY2 = 0,
        gaps = {},
        portGate = true,
    }

    print(string.format(
        "[PortLevel] 碰撞初始化: world=%.1f gateX=%.1f gateWidth=%d",
        layout.worldLength,
        layout.gateX,
        GATE_HALF_WIDTH * 2
    ))
end

local function drawImage(ctx, image, x, y, w, h)
    if not image or image <= 0 then return end
    local paint = nvgImagePattern(ctx, x, y, w, h, 0, image, 1.0)
    nvgBeginPath(ctx)
    nvgRect(ctx, x, y, w, h)
    nvgFillPaint(ctx, paint)
    nvgFill(ctx)
end

local function drawSpotlight(ctx, x, y, direction, length, width)
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, x, y)
    nvgLineTo(ctx, x + direction * length, y + width)
    nvgLineTo(ctx, x + direction * length, y - width)
    nvgClosePath(ctx)
    nvgFillColor(ctx, nvgRGBA(220, 232, 218, 22))
    nvgFill(ctx)

    nvgBeginPath(ctx)
    nvgMoveTo(ctx, x, y)
    nvgLineTo(ctx, x + direction * (length * 0.72), y + width * 0.45)
    nvgLineTo(ctx, x + direction * (length * 0.72), y - width * 0.45)
    nvgClosePath(ctx)
    nvgFillColor(ctx, nvgRGBA(244, 246, 226, 32))
    nvgFill(ctx)
end

local function drawGuard(ctx, x, groundY, flip)
    if not guardImage or guardImage <= 0 then return end
    local size = GUARD_HEIGHT
    local visibleBottomRatio = 457 / 512
    local drawX = x - size * 0.5
    local drawY = groundY - size * visibleBottomRatio

    nvgSave(ctx)
    if flip then
        nvgTranslate(ctx, x, 0)
        nvgScale(ctx, -1, 1)
        nvgTranslate(ctx, -x, 0)
    end
    local paint = nvgImagePattern(ctx, drawX, drawY, size, size, 0, guardImage, 1.0)
    nvgBeginPath(ctx)
    nvgRect(ctx, drawX, drawY, size, size)
    nvgFillPaint(ctx, paint)
    nvgFill(ctx)
    nvgRestore(ctx)
end

local function drawBarricade(ctx, x, groundY)
    if not barricadeImage or barricadeImage <= 0 then return end
    local size = 116
    local visibleBottomRatio = 363 / 512
    local drawX = x - size * 0.5
    local drawY = groundY - size * visibleBottomRatio
    drawImage(ctx, barricadeImage, drawX, drawY, size, size)
end

function PortLevel.Draw(ctx, cameraX, screenWidth, screenHeight, gameTime)
    local x1 = -cameraX
    local x2 = layout.mainX - cameraX
    local y = layout.panelTop
    local w = layout.panelW
    local h = layout.panelH
    local groundY = layout.groundY

    -- 设计稿之外只铺同色夜空，避免极端宽屏边缘漏底。
    nvgBeginPath(ctx)
    nvgRect(ctx, -screenWidth * 2, -screenHeight * 2, screenWidth * 5, screenHeight * 5)
    nvgFillColor(ctx, nvgRGBA(5, 19, 39, 255))
    nvgFill(ctx)

    drawImage(ctx, leftImage, x1, y, w, h)
    drawImage(ctx, mainImage, x2, y, w, h)

    -- 动态探照灯：保持横版构图，只在水平道路上形成警戒光束。
    local sweep = math.sin((gameTime or 0) * 0.8) * 0.18
    local lightY = groundY - h * 0.34
    drawSpotlight(ctx, x2 + w * 0.43, lightY, -1, w * (0.30 + sweep), h * 0.075)
    drawSpotlight(ctx, x2 + w * 0.74, lightY + h * 0.02, 1, w * (0.24 - sweep), h * 0.065)

    -- 左侧登陆区前景道具和封锁守卫，脚底严格落在同一条水平地面。
    drawBarricade(ctx, x1 + w * 0.62, groundY)
    drawGuard(ctx, x2 + w * 0.45, groundY, false)
    drawGuard(ctx, x2 + w * 0.75, groundY, true)

    -- 铁门前的冷白警戒高光，强化阻挡点但不改变碰撞形状。
    local pulse = 0.5 + 0.5 * math.sin((gameTime or 0) * 4.5)
    nvgBeginPath(ctx)
    nvgRect(ctx, layout.gateX - cameraX - GATE_HALF_WIDTH,
        groundY - 4, GATE_HALF_WIDTH * 2, 4)
    nvgFillColor(ctx, nvgRGBA(220, 226, 194, math.floor(35 + pulse * 35)))
    nvgFill(ctx)
end

return PortLevel
