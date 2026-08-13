-- ============================================================================
-- 《末世搜寻》 - 动漫画风末世物资搜寻游戏
-- 竖屏 | 2D横版街道 | 动漫画风 | 末世氛围
-- 建筑：近景1-2层街边店铺/民房，带门可进入
-- ============================================================================

---@diagnostic disable: undefined-global

require "urhox-libs.UI.GameHUD"
HomeUI = require "HomeUI"
WarehouseUI = require "WarehouseUI"
ShopUI = require "ShopUI"
CodexUI = require "CodexUI"
BlackMarketUI = require "BlackMarketUI"
BlackMarketCloud = require "BlackMarketCloud"

local joystick_     = nil   -- 虚拟摇杆（PC键盘/移动触摸统一接口）
local descendBtn_   = nil   -- 开门按钮（手机端，原Crouch）
lightSwitchBtn_ = nil       -- 灯光开关按钮（手机端）
lightSwitchPressed_ = false -- 灯光开关按钮按下标记
playerNearLightSwitch = nil -- 玩家靠近的灯光开关 key
-- 房间隔墙门状态：key="fi_divIdx" → {openProg=0~1, target=0/1}
local roomDoorStates = {}
local playerNearRoomDoor = nil  -- 玩家靠近的房间门 key
local playerNearStreetBuilding = nil -- 玩家靠近的街边可进入建筑
local attackPressed_ = false -- 战术攻击HUD被按下标记（供 update 消费）
local reloadPressed_ = false -- 装弹HUD被按下标记（供 update 消费）
consumePressed_ = false -- 食用HUD被按下标记（供 update 消费）
local openDoorPressed_ = false -- 开门按钮被按下标记（供 update 消费）
local doorBtn_      = nil   -- 开门按钮（手机端）
local upBtn_        = nil   -- 上楼按钮（手机端）
local downBtn_      = nil   -- 下楼按钮（手机端）
local doorPressed_  = false -- 开门按钮被按下标记
local upPressed_    = false -- 上楼按钮被按下标记
local downPressed_  = false -- 下楼按钮被按下标记
inventoryBtnPressed_ = false -- 战术背包HUD被按下标记
weaponSwitchPressed_ = false -- 武器HUD或E键触发的切换标记

-- ── Spine 角色（直接在主 NanoVG 渲染，确保铁网能覆盖角色）──
local spineInstance = nil   -- nvgSpineCreate 实例
local spineUIInstance = nil -- 摸金UI左区idle动画展示用的独立Spine实例
local SPINE_DRAW_H = 120    -- Spine 角色显示高度（逻辑像素）
local SPINE_DRAW_W = 85     -- Spine 角色显示宽度（匹配 adira 宽高比 289.61/353.95）
local spineCurrentAnim = "" -- 当前播放的动画名称
local spineFlipX = false    -- 当前翻转状态
-- 枪口骨骼追踪（每帧从 Spine 骨骼获取世界位置和朝向）
local muzzleBone = nil          -- tt_7 骨骼引用
local muzzleScreenX = 0         -- 枪口屏幕X（场景变换内的局部坐标）
local muzzleScreenY = 0         -- 枪口屏幕Y
local muzzleAngle = 0           -- 枪口朝向角度（弧度）
local audioScene = nil           -- 专用音频场景（纯NanoVG游戏无scene_）
local rainSrcNode = nil          -- 雨声节点（保持引用防GC）
local rainSrcComp = nil          -- 雨声 SoundSource 组件
local rainSoundRes = nil         -- 雨声 Sound 资源
bgmSrcNode = nil                 -- 背景音乐节点
bgmSrcComp = nil                 -- 背景音乐 SoundSource
bgmSoundRes = nil                -- 背景音乐 Sound 资源
bgmStarted = false               -- 进入游戏后再启动背景音，避免加载页提前出声
local doorSoundRes = nil         -- 开门音效资源
local lightSwitchSoundRes = nil  -- 开灯/关灯开关音效资源
walkGearSoundRes = nil           -- 行走时衣物/装备摩擦音效资源
walkGearSfxTimer = 0.0           -- 行走摩擦音效节奏计时器
zombieGrowlSoundRes = nil        -- 丧尸嘶吼/喘息音效资源
zombieAttackSoundRes = nil       -- 丧尸攻击音效资源
zombieDeathSoundRes = nil        -- 丧尸死亡音效资源
local playZombieSound = nil      -- 丧尸音效播放函数（供较早声明的战斗函数调用）

local vg = nil

local W, H = 0, 0
local dpr = 1.0
local cameraX = 0
local gameTime = 0

-- ── 客厅门状态（各楼层独立，可动态开关）──
-- openProg: 0=关闭 1=全开, target: 目标状态
local doorStates = {
    [1] = { openProg = 0.0, target = 0 },  -- 5F 工具房 关着
    [2] = { openProg = 0.0, target = 0 },  -- 4F 关着
    [3] = { openProg = 0.0, target = 0 },  -- 3F 关着
    [4] = { openProg = 0.0, target = 0 },  -- 2F 关着
    [5] = { openProg = 0.0, target = 0 },  -- 1F 关着
}
local DOOR_ANIM_SPEED = 2.0  -- 开关动画速度
-- 初始化房间隔墙门状态（所有门默认关闭）
for fi = 1, 5 do
    local divCount = ({1, 2, 2, 2, 2})[fi]  -- 每层隔墙数
    for di = 1, divCount do
        roomDoorStates[fi .. "_" .. di] = { openProg = 0.0, target = 0 }
    end
end
-- 地下室门
roomDoorStates["bas_1"] = { openProg = 0.0, target = 0 }
roomDoorStates["bas_2"] = { openProg = 0.0, target = 0 }
-- 附楼入口钢门
roomDoorStates["annex"] = { openProg = 0.0, target = 0 }
-- 1F左外墙入口门
roomDoorStates["1f_left"] = { openProg = 0.0, target = 0 }
-- 1F右外墙出口门
roomDoorStates["1f_right"] = { openProg = 0.0, target = 0 }
-- 第二栋居民服务楼入口门
roomDoorStates["cs2_entry"] = { openProg = 0.0, target = 0 }
roomLightStates = {} -- 房间灯光状态：key -> true=已开灯；默认 nil/false 为黑暗
basementHeightScale = 1.55 -- 地下室房间高度倍率
lightSwitchZones = {} -- 渲染帧登记的灯光开关命中区
lightSwitchDrawQueue = {} -- 暗层之后补画的开关
lightToggleUIRect = nil -- 独立开灯UI按钮命中区
lightToggleUITouchDown = false -- 独立开灯UI触摸防抖
lightToggleUIConsumed = false -- 本帧开灯UI已消费点击，避免同时触发攻击
weaponHUDRect = nil -- 当前武器HUD命中区域（逻辑坐标）
weaponHUDTouchDown = false -- 当前武器HUD触摸防抖
weaponHUDInputConsumed = false -- 本帧武器HUD已消费点击，避免同时触发攻击
attackHUDRect = nil -- 战术攻击HUD命中区域（逻辑坐标）
doorHUDRect = nil -- 开门HUD命中区域（攻击按钮左侧）
ladderDownHUDRect = nil -- 第二栋楼爬梯到层时的停留按钮命中区域
cs2LadderDownHUDVisible = false -- 第二栋楼爬梯到层时的停留按钮显示状态
ladderEnterPressed_ = false -- 玩家点击停留按钮
reloadHUDRect = nil -- 装弹HUD命中区域（仅持枪时显示）
consumeHUDRect = nil -- 食用HUD命中区域（胸挂/口袋有食物时显示）
inventoryHUDRect = nil -- 战术背包HUD命中区域（逻辑坐标）
exitHomeHUDRect = nil -- 设置HUD命中区域（逻辑坐标）
exitHomeHUDTouchDown = false -- 设置HUD触摸防抖
exitHomeHUDInputConsumed = false -- 本帧设置HUD已消费点击
settingsUI = {
    active = false,
    volume = 1.0,
    panelRect = nil,
    closeRect = nil,
    sliderRect = nil,
    exitRect = nil,
    touchMode = "",
}
actionHUDTouchDown = false -- 攻击/背包HUD触摸防抖
reloadHUDTouchDown = false -- 装弹HUD触摸防抖
actionHUDInputConsumed = false -- 本帧战术按钮已消费点击
reloadHUDInputConsumed = false -- 本帧装弹按钮已消费点击
attackHUDPressTimer = 0 -- 攻击按钮按压动画剩余时间
attackHUDScale = 1.0 -- 攻击按钮当前视觉缩放
reloadHUDPressTimer = 0 -- 装弹按钮按压动画剩余时间
reloadHUDScale = 1.0 -- 装弹按钮当前视觉缩放
consumeHUDPressTimer = 0 -- 食用按钮按压动画剩余时间
consumeHUDScale = 1.0 -- 食用按钮当前视觉缩放
CONSUME_COOLDOWN_DURATION = 3.0 -- 完成一次食用动作所需秒数
consumeCooldown = 0 -- 当前食用动作剩余时间
consumeCooldownItemName = nil -- 食用中保留物资名，确保按钮能完整显示进度
pendingConsumeHeal = 0 -- 食用动作完成时才结算的待恢复生命值

local playerNearDoorFi = 0  -- 玩家靠近第一栋楼哪层楼道门（0=未靠近）
cs2StairDoorStates = {} -- 第二栋楼右侧逐层外梯门状态
cs2LeftStairDoorStates = {} -- 第二栋楼左侧逐层外梯门状态
cs2StairDoorWorldCXByFi = {} -- 第二栋楼各层左右外梯门世界X中心
cs2StairDoorFloorRanges = {} -- 第二栋楼各层角色Y范围与落点
playerNearCS2StairDoorFi = 0 -- 玩家靠近第二栋楼哪层外梯门
playerNearCS2StairDoorSide = "right" -- 当前靠近左侧或右侧外梯门
CS2_NUM_FLOORS = 4
for fi = 1, CS2_NUM_FLOORS do
    cs2StairDoorStates[fi] = { openProg = 0.0, target = 0 }
    cs2LeftStairDoorStates[fi] = { openProg = 0.0, target = 0 }
end
local playerNearBasementLadder = false  -- 玩家靠近地下室梯口
local doorWorldCXByFi = {}   -- 每层门的世界X中心坐标（渲染时更新）
---@type table
local player  -- 提前声明，供爬梯过渡函数捕获同一局部玩家对象

-- ── 换层过渡动画 ──
local floorTransition = {
    active = false,
    phase = "none",     -- "fadeOut" | "fadeIn"
    timer = 0,
    duration = 0.3,     -- 淡出/淡入各 0.3 秒
    alpha = 1.0,        -- 玩家透明度（1=完全可见，0=不可见）
    targetFi = 0,       -- 目标楼层
    targetY = 0,        -- 目标 jumpScrY
    targetX = nil,      -- 目标楼梯门世界X；区分第一栋楼和第二栋楼
}

-- ── 地下室爬梯过渡 ──
function getNearestLadderInfo(initialDirection)
    local ladders = csColliders and csColliders.ladders or nil
    if not ladders or not player then return nil end
    local best = nil
    local bestDist = math.huge
    for _, info in ipairs(ladders) do
        -- 外梯的可用区域覆盖铁梯到门口之间的平台；地下室梯仍保持紧邻梯身触发。
        local approachPadding = info.side and 80 or 32
        local inX = player.x + approachPadding > info.wx1
            and player.x - approachPadding < info.wx2
        local nearTop = info.topY and math.abs(player.jumpScrY - info.topY) < 60
        local nearBottom = info.bottomY and math.abs(player.jumpScrY - info.bottomY) < 60
        if info.floorY and not info.topY then
            nearTop = math.abs(player.jumpScrY) < 24
            nearBottom = math.abs(player.jumpScrY - info.floorY) < 60
        end
        local nearEndpoint = initialDirection == "down" and nearTop
            or initialDirection == "up" and nearBottom
            or (not initialDirection and (nearTop or nearBottom))
        if inX and nearEndpoint then
            local endpointDist = initialDirection == "up"
                and math.abs(player.jumpScrY - (info.bottomY or info.floorY or 0))
                or math.abs(player.jumpScrY - (info.topY or 0))
            local dist = math.abs(player.x - (info.wx1 + info.wx2) * 0.5) + endpointDist * 0.15
            if dist < bestDist then
                best = info
                bestDist = dist
            end
        end
    end
    return best
end

local ladderTransition = {
    active = false,
    timer = 0.0,       -- 0=梯子顶部，duration=梯子底部
    animTime = 0.0,    -- 可正反推进的动画时间，松开摇杆时保持不变
    duration = 1.8,
    ladderInfo = nil,
    phase = "none", -- "climb" | "landingChoice" | "none"
    landingFi = 0,
    landingY = 0,
    landingDirection = nil,
    landingWait = 0,
}

function ladderTransition.GetConnected(info, direction)
    if not info or not info.side then return nil end
    for _, candidate in ipairs(csColliders.ladders or {}) do
        if candidate.side == info.side then
            if direction == "down" and candidate.topFi == info.bottomFi then
                return candidate
            end
            if direction == "up" and candidate.bottomFi == info.topFi then
                return candidate
            end
        end
    end
    return nil
end

local function beginLadderTransition(initialDirection, preferredFloor, preferredSide)
    if ladderTransition.active or floorTransition.active then return false end
    local info = nil
    if preferredFloor and preferredSide then
        for _, candidate in ipairs(csColliders.ladders or {}) do
            local matchesFloor = initialDirection == "down"
                and candidate.topFi == preferredFloor
                or initialDirection == "up"
                and candidate.bottomFi == preferredFloor
            if candidate.side == preferredSide and matchesFloor then
                info = candidate
                break
            end
        end
        if not info then return false end
    else
        info = getNearestLadderInfo(initialDirection)
    end
    if not info then return false end

    local ladderCenterX = (info.wx1 + info.wx2) * 0.5
    local topContactY = info.topY
    if topContactY == nil then
        topContactY = CLIMB_ANIM.handContactOffsetY or 170
    end
    local bottomContactY = info.bottomY or info.floorY
    if not bottomContactY then return false end
    local climbRange = math.max(1, bottomContactY - topContactY)
    -- 从地面开始下爬时，整个人立即贴到梯子；此时双手正好接触梯顶。
    if initialDirection == "down" and player.jumpScrY < topContactY then
        player.jumpScrY = topContactY
    end
    player.x = ladderCenterX
    player.isMoving = false
    player.isRunning = false
    player.onGround = false
    player.jumpVelY = 0
    player.actionState = "climb"
    player.actionTimer = 0.0

    local progress = math.max(0, math.min(1, (player.jumpScrY - topContactY) / climbRange))
    if initialDirection == "down" and math.abs(player.jumpScrY - topContactY) < 60 then
        progress = 0
    elseif initialDirection == "up" and math.abs(player.jumpScrY - bottomContactY) < 60 then
        progress = 1
    end
    ladderTransition.timer = progress * ladderTransition.duration
    ladderTransition.animTime = progress * ladderTransition.duration
    ladderTransition.ladderInfo = info
    ladderTransition.phase = "climb"
    ladderTransition.landingFi = 0
    ladderTransition.landingY = 0
    ladderTransition.landingDirection = initialDirection
    ladderTransition.landingWait = 0
    ladderTransition.active = true
    print("[Ladder] 进入梯子=" .. tostring(info.name) .. "，方向=" .. tostring(initialDirection) .. " 进度=" .. tostring(progress))
    return true
end

-- ── 摸金系统（宝箱搜刮，类似三角洲行动） ──
local lootUI = {
    active = false,          -- 是否正在显示摸金UI
    mode = "loot",           -- "loot"=搜刮容器, "inventory"=只看背包
    chestIdx = 0,            -- 当前打开的宝箱索引
    selectedSlot = 0,        -- 选中的物品槽位
    selectedItem = "",       -- 当前选中的物品名
    selectedContainer = "",  -- 当前选中的容器
    selectedIdx = 0,         -- 当前选中的容器索引
    selectedRect = nil,      -- 当前选中物资在搜刮UI中的屏幕矩形
    itemValues = {},         -- 物资价值与说明
    animTimer = 0,           -- 打开动画计时器
    loadingTimer = 0,        -- 开箱加载动画计时（>0时显示转圈）
    loadingDuration = 3.0,   -- 加载持续时间（秒）- 会按最高稀有度动态设置
    loadingElapsed = 0,      -- 已加载时间（用于判断每个物品是否揭示）
    revealedSet = {},        -- 已揭示物品索引集合（用于触发音效，避免重复播放）
    midScrollY = 0,          -- 中区滚动偏移
    rightScrollY = 0,        -- 战前整备据点仓库滚动偏移
    rightScrollMax = 0,      -- 战前整备据点仓库最大滚动距离
    -- 双击检测
    lastClickTime = 0,       -- 上次点击时间
    lastClickItem = "",      -- 上次点击的物品
    lastClickContainer = "", -- 上次点击的容器
    lastClickIdx = 0,        -- 上次点击的物品索引
    -- 拖拽状态
    dragging = false,        -- 是否正在拖拽
    dragItem = "",           -- 拖拽的物品名
    dragFrom = "",           -- 来源容器: "chest"/"rig"/"pocket"/"inv"/"safe"/"equip_gun"/"equip_melee"
    dragFromIdx = 0,         -- 来源数组中的索引
    dragSourceEntry = nil,   -- 来源容器中的原始条目（用于放置失败时按原格还原）
    dragSourceCol = nil,     -- 来源物资拖起前的网格列
    dragSourceRow = nil,     -- 来源物资拖起前的网格行
    dragOrientation = "horizontal", -- 当前拖拽物资方向，可按 R 切换
    dragInput = "",          -- 拖拽输入来源: "mouse"/"touch"
    lootImgs = {},            -- 房间可搜刮容器图片句柄
    drawerImg = 0,            -- 正视角可搜刮抽屉图片句柄
    equippedHelmetItem = "", -- 头盔槽装备的物品名
    equippedArmorItem = "",  -- 防弹衣槽装备的物品名
    equippedRigItem = "",    -- 中间胸挂槽装备的物品名
    equippedBackpackItem = "", -- 中间背包槽装备的物品名
    equippedSafeBoxItem = "", -- 安全箱槽装备的物品名
    equippedGunItem = "",    -- 枪支槽装备的物品名
    equippedMeleeItem = "",  -- 近战武器槽装备的物品名
    _equipSlotCache = {},     -- 装备槽命中区域缓存
    loadoutConfirmRect = nil, -- 战前整备确认出战按钮区域
    dragMouseX = 0,          -- 当前鼠标X
    dragMouseY = 0,          -- 当前鼠标Y
    dragOffX = 0,            -- 鼠标相对物品左上角偏移X
    dragOffY = 0,            -- 鼠标相对物品左上角偏移Y
    nearChestIdx = 0,                 -- 玩家靠近的宝箱索引
    nearChestDist = math.huge,        -- 多个搜刮区命中时选择最近者
    nearLoosePickup = nil,            -- 靠近的厕所散落医疗物品
    nearLoosePickupDist = math.huge,  -- 最近散落物距离
    bathroomLoosePickups = {
        [2] = {
            { id = "bathroom_4f_medkit", item = "急救包", x = 0.72, y = 0.66, picked = false },
        },
        [3] = {
            { id = "bathroom_3f_water", item = "净水", x = 0.76, y = 0.68, picked = false },
        },
        [4] = {
            { id = "bathroom_2f_medkit", item = "急救包", x = 0.76, y = 0.67, picked = false },
        },
    },
    letterImg = 0,
    letterPaperImg = 0,
    letterOpen = false,
    letterAnim = 0,
    letterNear = false,
    letterDist = math.huge,
    letterRect = nil,
    searchPressedTimer = 0,
    searchTouchDown = false,
    searchButtonRect = nil,
    letterContent = {
        "如果你看到这封信，",
        "说明我没能回来。",
        "楼下的药已被拿走，",
        "别再冒险去找。",
        "地下室右边的",
        "旧柜子后面，",
        "还藏着一把备用钥匙。",
        "雨停以后，",
        "沿街道一直向东走。",
        "记住，不要相信",
        "戴红色袖章的人。",
        "—— 林安",
    },
}

-- ── 资源加载状态（进入游戏前先加载所有资源）──
local appState = "loading"   -- "loading" | "home" | "shop" | "blackmarket" | "warehouse" | "loadout" | "playing"
loadoutWarehouseIdx = nil
local homeTouchActive = false -- 首页触摸防抖
local homeTouchX = 0
local homeTouchY = 0
inventoryOpenedFromHome = false
warehouseTabs = nil
local initCo = nil           -- 资源加载协程（分帧加载，避免卡顿黑屏）
local loadProgress = 0       -- 加载进度 0..1
local loadStatusText = "正在加载资源..."
local downloadObserveStarted = false  -- 是否已开始监测 DWP 后台下载
local downloadsComplete = false       -- 所有 DWP 资源是否下载完成

-- ── 需要在进入游戏前预下载到本地的所有媒体资源（图片/音频/字体）──
-- nvgCreateImage 从本地磁盘读取，必须先下载完成才能拿到真实像素（否则显示占位图）
local PRELOAD_RESOURCES = {
    -- 字体
    "Fonts/MiSans-Regular.ttf",
    -- 音效
    "audio/sfx/gunshot.ogg",
    "audio/sfx/shotgun_blast.ogg",
    "audio/sfx/wooden_bat_attack.ogg",
    "audio/sfx/wooden_bat_swing_miss.ogg",
    "audio/sfx/pistol_reload.ogg",
    "audio/sfx/shotgun_reload.mp3",
    "audio/sfx/item_revealed.ogg",
    "audio/sfx/ui_tactical_tab_click.mp3",
    "audio/sfx/ui_loadout_open.mp3",
    "audio/sfx/ui_deploy_confirm.mp3",
    "audio/sfx/ui_warehouse_open.mp3",
    "audio/sfx/door_open_creak.ogg",
    "audio/sfx/plastic_light_switch_click_soft.ogg",
    "audio/sfx/character_gear_rustle_walk.ogg",
    "audio/sfx/zombie_idle_growl.ogg",
    "audio/sfx/zombie_attack_bite.ogg",
    "audio/sfx/zombie_death_groan.ogg",
    "audio/music_1783777087047.ogg",
    -- 场景/建筑图片
    "image/steel_truss_20260524135622.png",
    "image/ceiling_lamp.png",
    "image/ladder_basement_20260524135555.png",
    "image/edited_basement_window_hd_20260524140353.png",
    "image/edited_basement_door_hd_20260524140332.png",
    "image/edited_wooden_door_front_20260707040928.png",
    "image/door_side_v2_20260621060845.png",
    "image/steel_door_side_20260621113254.png",
    "image/basement_crate_20260524135552.png",
    "image/basement_barrel_20260524135543.png",
    "image/basement_shelf_20260524135755.png",
    "image/basement_cardbox_20260524135712.png",
    "image/basement_bag_rack_20260524135546.png",
    "image/basement_gear_rack_20260524135714.png",
    "image/高级战术安全箱_20260731060159.png",
    "image/edited_loot_nightstand_strict_front_final_20260718093912.png",
    "image/loot_drawer_strict_front_20260718080423.png",
    "image/loot_medicine_cabinet_room_20260707053515.png",
    "image/loot_tool_locker_room_20260707053511.png",
    "image/flashlight_icon_20260603082359.png",
    "image/magnifying_glass_icon_20260609105102.png",
    "image/mcdonalds_trimmed.png",
    "image/fence_trimmed.png",
    "image/lamp_trimmed.png",
    "image/末世混乱垃圾桶_20260729024640.png",
    "image/大盆栽_棕榈_20260531092818.png",
    "image/大盆栽_琴叶榕_20260531092830.png",
    "image/大盆栽_三角梅_20260531092816.png",
    "image/阳台太阳伞_20260531103728.png",
    "image/阳台休闲椅_20260531103729.png",
    "image/卫生间全景_20260531120248.png",
    "image/卫生间3F_20260531121422.png",
    "image/卫生间2F_20260531121402.png",
    "image/厨房4F_20260531133453.png",
    "image/厨房3F_20260531133511.png",
    "image/厨房2F_20260531133447.png",
    "image/工具房5F_20260531135113.png",
    "image/客厅4F_20260531134528.png",
    "image/客厅3F_20260531134542.png",
    "image/客厅2F_20260531134532.png",
    "image/客厅1F_20260531134910.png",
    "image/一楼左侧房间_末世沙发正视图_20260718130944.png",
    "image/一楼左侧房间_旧电视柜正视图_20260718130851.png",
    "image/一楼左侧房间_末世茶几正视图_20260718130907.png",
    "image/一楼左侧房间_落地灯正视图_20260718130757.png",
    "image/一楼左侧房间_废弃绿植正视图_20260718130808.png",
    "image/一楼左侧房间_末世摩托车侧面正视图_20260718141137.png",
    "image/附楼摩托车房_维修工作台正视图_20260718145730.png",
    "image/附楼摩托车房_工具柜正视图_20260718145951.png",
    "image/附楼摩托车房_轮胎架正视图_20260718145717.png",
    "image/附楼摩托车房_红色油桶正视图_20260718145736.png",
    "image/附楼摩托车房_墙面工具板正视图_20260718145920.png",
    "image/正视图_旧衣柜搜刮家具_20260718152219.png",
    "image/正视图_旧书架搜刮家具_20260718152424.png",
    "image/正视图_厨房储物柜搜刮家具_20260718152421.png",
    "image/正视图_金属储物柜搜刮家具_20260718152229.png",
    "image/正视图_旧床头柜搜刮家具_20260718152300.png",
    "image/卡通末世正视图窄边储物柜_20260720115649.png",
    "image/卡通末世正视图床头柜_20260720115727.png",
    "image/卡通末世正视图玻璃展示柜_20260720115651.png",
    "image/卡通末世正视图工具抽屉柜_20260720115935.png",
    -- 第二栋居民服务楼家具（全部为透明背景严格正视图片）
    "image/第二栋楼_卧室家具组合正视图_20260725033547.png",
    "image/第二栋楼_储物间家具组合正视图_20260725033546.png",
    "image/第二栋楼_洗衣区家具组合正视图_20260725033550.png",
    "image/第二栋楼_卫生间家具组合正视图_20260725033542.png",
    "image/第二栋楼_客厅家具组合正视图_20260725033543.png",
    "image/第二栋楼_书房家具组合正视图_20260725033545.png",
    "image/第二栋楼_蓝色卧室家具组合正视图_20260725033744.png",
    "image/第二栋楼_餐厅家具组合正视图_20260725033539.png",
    "image/第二栋楼_厨房家具组合正视图_20260725033545.png",
    "image/第二栋楼_便民店家具组合正视图_20260725033748.png",
    "image/第二栋楼_管理室家具组合正视图_20260725033542.png",
    "image/第二栋楼_维修间家具组合正视图_20260725033752.png",
    "image/外部废弃超市_室内家具组合正视图_20260725052455.png",
    "image/外部旧仓库_室内家具组合正视图_20260725051417.png",
    "image/外部街角药店_室内家具组合正视图_20260725051413.png",
    "image/卡通末世折叠信件_20260719052833.png",
    "image/edited_手机宽版末世信纸背景_20260720045833.png",
    "image/一楼右侧小卖部_整洁收银台严格正视图_20260719073315.png",
    "image/一楼右侧小卖部_整洁展示柜严格正视图_20260719073304.png",
    "image/一楼右侧小卖部_整洁饮料冷柜严格正视图_20260719073306.png",
    "image/一楼右侧小卖部_整洁购物篮严格正视图_20260719073302.png",
    "image/墙面血迹_高速扇形喷溅_20260719075954_clean.png",
    "image/墙面血迹_双向爆裂喷溅_20260719075959_clean.png",
    "image/墙面血迹_大片撞击流淌_20260719075953_clean.png",
    "image/墙面血迹_密集细小飞溅_20260719075944_clean.png",
    "image/天台太阳能板_20260602090719.png",
    "image/天台围栏_20260602090713.png",
    "image/天台桌椅_20260602090711.png",
    "image/天台花盆组合_20260602090730.png",
    "image/天台遮阳伞_20260602090728.png",
    "image/player_char.png",
    "image/首页空手幸存者立绘_20260811135500.png",
    "image/首页日本全国感染态势图_20260811135348.png",
    "image/首页东京废弃城区预览_20260811135412.png",
    "image/首页设计稿母版.png",
    "image/warehouse/据点仓库设计稿母版.png",
    "image/仓库翡翠原石风格物资_20260813045549_clean.png",
    "image/仓库金条风格物资_20260813045541_clean.png",
    "image/仓库古董花瓶风格物资_20260813045540_clean.png",
    "image/仓库军用平板风格物资_20260813045546_clean.png",
    "image/warehouse/item_cells/物资格_红色传说_2x2.png",
    "image/warehouse/item_cells/物资格_金色传说_2x1.png",
    "image/warehouse/item_cells/物资格_粉色史诗_2x2.png",
    "image/warehouse/item_cells/物资格_紫色稀有_2x1.png",
    "image/warehouse/item_cells/物资格_蓝色精良_1x1.png",
    "image/warehouse/item_cells/物资格_绿色普通_1x1.png",
    -- 商城高密度设计稿拆件
    "image/shop_design/顶部完整条.png",
    "image/shop_design/左侧分类金属外框.png",
    "image/shop_design/中央外框顶.png",
    "image/shop_design/中央外框底.png",
    "image/shop_design/中央外框左.png",
    "image/shop_design/中央外框右.png",
    "image/shop_design/边缘_左.png",
    "image/shop_design/间隔_分类中央.png",
    "image/shop_design/间隔_中央档案.png",
    "image/shop_design/边缘_右.png",
    "image/shop_design/商品列间隔_一.png",
    "image/shop_design/商品列间隔_二.png",
    "image/shop_design/商品行间隔.png",
    "image/shop_design/底部背景条.png",
    "image/shop_design/右侧军需档案_动态底板.png",
    "image/shop_design/sidebar/按钮_选中空白.png",
    "image/shop_design/sidebar/按钮_未选中空白.png",
    "image/shop_design/sidebar/图标_深色_guns.png",
    "image/shop_design/sidebar/图标_深色_ammo.png",
    "image/shop_design/sidebar/图标_深色_armor.png",
    "image/shop_design/sidebar/图标_深色_helmets.png",
    "image/shop_design/sidebar/图标_深色_rigs.png",
    "image/shop_design/sidebar/图标_深色_backpacks.png",
    "image/shop_design/sidebar/图标_深色_safe_boxes.png",
    "image/shop_design/sidebar/图标_浅色_guns.png",
    "image/shop_design/sidebar/图标_浅色_ammo.png",
    "image/shop_design/sidebar/图标_浅色_armor.png",
    "image/shop_design/sidebar/图标_浅色_helmets.png",
    "image/shop_design/sidebar/图标_浅色_rigs.png",
    "image/shop_design/sidebar/图标_浅色_backpacks.png",
    "image/shop_design/sidebar/图标_浅色_safe_boxes.png",
    "image/shop_design/cards/卡片底板_蓝色.png",
    "image/shop_design/cards/卡片底板_紫色.png",
    "image/shop_design/cards/卡片底板_绿色.png",
    "image/home_layers/首页背景_无UI.png",
    "image/home_layers/首页Logo.png",
    "image/home_layers/面板边框_角色.png",
    "image/home_layers/面板边框_态势地图.png",
    "image/home_layers/面板边框_地图情报.png",
    "image/home_layers/顶部信息条背景.png",
    "image/home_layers/底部导航按钮背景.png",
    "image/home_layers/战前整备按钮背景.png",
    "image/home_layers/更换地图按钮背景.png",
    "image/home_layers/进入地图按钮背景.png",
    "image/卡通末世双管折管散弹枪物品_20260725160700.png",
    "image/手枪弹药盒_20260801074149.png",
    "image/散弹枪弹药包_20260801074017.png",
    "image/player_shotgun_frames/walk/walk_001.png",
    "image/player_shotgun_frames/run/run_001.png",
    "image/player_shotgun_frames/attack/attack_001.png",
    "image/player_shotgun_frames/hurt/hurt_001.png",
    "image/player_shotgun_frames/reload/reload_001.png",
    "image/卡通丧尸碎块_头部_20260725182041.png",
    "image/卡通丧尸碎块_躯干_20260725182038.png",
    "image/卡通丧尸碎块_手臂_20260725182048.png",
    "image/卡通丧尸碎块_腿部_20260725182039.png",
    "image/卡通丧尸碎块_衣物残片_20260725182039.png",
    -- 物品图标（统一卡通手绘末世风）
    "image/卡通末世物资_金表_20260723024804.png",
    "image/卡通末世物资_翡翠原石_20260723024813.png",
    "image/卡通末世物资_金条_20260723024805.png",
    "image/卡通末世物资_钻石项链_20260723024811.png",
    "image/卡通末世物资_古董花瓶_20260723024817.png",
    "image/卡通末世物资_名牌手包_20260723024810.png",
    "image/卡通末世物资_银币收藏_20260723024808.png",
    "image/卡通末世物资_红酒_20260723024809.png",
    "image/卡通末世物资_珍珠耳环_20260723024822.png",
    "image/卡通末世物资_象牙雕件_20260723024922.png",
    "image/卡通末世物资_机械键盘_20260723024924.png",
    "image/卡通末世物资_平板电脑_20260723024938.png",
    "image/卡通末世物资_铜戒指_20260723024935.png",
    "image/卡通末世物资_旧手机_20260723024920.png",
    "image/卡通末世物资_打火机_20260723024934.png",
    "image/卡通末世物资_罐头_20260723024928.png",
    "image/卡通末世物资_螺丝刀_20260723024920.png",
    "image/卡通末世物资_电池_20260723024935.png",
    "image/卡通末世急救包严格正视图_20260723130308.png",
    "image/卡通末世物资_净水_20260723025045.png",
    "image/卡通末世物资_成捆现金_20260723025056.png",
    "image/卡通末世物资_胶带_20260723025045.png",
    "image/卡通末世物资_扳手_20260723025047.png",
    "image/edited_黄金收藏香槟正视图无文字_20260729101256.png",
    "image/卡通末世物资_高级香烟_20260723025041.png",
    "image/卡通末世物资_名贵香水_20260723025039.png",
    "image/卡通风加密固态硬盘搜刮物品_20260718162139.png",
    "image/卡通风军用望远镜搜刮物品_放大_20260723030500.png",
    "image/卡通风卫星电话搜刮物品_20260718162141.png",
    "image/卡通风古董相机搜刮物品_20260718162145.png",
    "image/卡通风铂金打火机搜刮物品_20260718162138.png",
    "image/卡通风高级太阳镜搜刮物品_20260718162144.png",
    "image/卡通风古董指南针搜刮物品_20260718162142.png",
    "image/卡通风稀有咖啡豆搜刮物品_20260718162158.png",
    "image/卡通风收藏金币搜刮物品_20260718162138.png",
    "image/卡通风红宝石戒指搜刮物品_20260718162146.png",
    "image/edited_漫画版三风扇旗舰显卡_横放_20260730120508.png",
    "image/edited_卡通末世顶级物资_黄金半身像_无底座_20260730121826.png",
    "image/卡通末世顶级物资_军用笔记本_20260723030223.png",
    "image/物资_机密生物样本_20260728061821.png",
    "image/物资_军用热成像仪_20260728061811.png",
    "image/物资_黄金纪念怀表_20260728061824.png",
    "image/物资_稀有邮票册_20260728061826.png",
    "image/物资_高纯度钯金块_20260728061815.png",
    "image/物资_加密无人机核心_20260728061827.png",
    "image/物资_精密光学模组_20260728061822.png",
    "image/物资_绝版游戏卡带_20260728061821.png",
    "image/物资_名厂机械腕表_20260728061820.png",
    "image/物资_航空级控制芯片_20260728061833.png",
    "image/pistol_icon_20260711113020.png",
    "image/barbed_bat_icon_20260711122737.png",
    "image/二级头盔_20260727073512.png",
    "image/二级防弹衣_20260727114218.png",
    "image/二级胸挂_20260727073514.png",
    "image/高级战术安全箱_20260731060159.png",
    "image/三级红色战术安全箱_20260731125534.png",
    -- 黑市交易终端专用视觉资源
    "image/黑市商人渡鸦肖像_20260809093215.png",
    "image/地下管道撤离情报地图_20260809093224.png",
    "image/伪造实验室门禁卡_20260809093213.png",
    "image/黑市通用战术消音器_20260809100641.png",
    "image/黑市武器保险券_20260809100637.png",
    -- 首页远观沦陷城市视觉资源
    "image/远望日本沦陷城市_20260811103414.png",
    -- 二级背包图标
    "image/backpack_tier2_20260718072219.png",
}
local flashlightIconImg = 0  -- 手电筒图标NanoVG纹理ID
local loadingSpinnerImg = 0  -- 搜索放大镜图标NanoVG纹理ID
local backpackTier2Img = 0  -- 二级背包图标
-- 物品图标NanoVG纹理ID表
local itemIcons = {}  -- { ["物品名"] = nvgImageId }
blackMarketArt = {
    broker = 0,
    home_crisis = 0,
    home_survivor = 0,
    home_national_map = 0,
    home_location = 0,
    home_master = 0,
    home_layers = {},
    warehouse_master = 0,
    warehouse_cells = {},
    shop_design = {},
    tunnel_intel = 0,
    lab_keycard = 0,
    suppressor = 0,
    weapon_insurance = 0,
}
local roomDecorImgs = {} -- 一楼左侧客厅装饰家具纹理
local lootBtnPressed_ = false  -- 手机端"搜刮"按钮按下标记
local lootBtn_ = nil           -- 搜刮虚拟按钮

-- 胸挂物品（快速取用层，在背包上方）
playerChestRig = {}  -- { "物品名", ... }
RIG_GRID_COLS = 4   -- 胸挂网格列数
RIG_GRID_ROWS = 2   -- 胸挂网格行数
RIG_MAX = 4          -- 胸挂最大物品数

-- 口袋物品（胸挂下方，背包上方）
playerPocket = {}    -- { "物品名", ... }
PKT_GRID_COLS = 6   -- 口袋网格列数
PKT_GRID_ROWS = 1   -- 口袋网格行数（单层）
PKT_MAX = 6          -- 口袋最大物品数

-- 安全箱物品（背包下方，贵重物品存放）
playerSafeBox = {}   -- { "物品名", ... }
SAFE_GRID_COLS = 3   -- 当前安全箱网格列数（二级 3，三级 4）
SAFE_GRID_ROWS = 2   -- 当前安全箱网格行数（二级 2，三级 3）
SAFE_MAX = 6         -- 当前安全箱最大物品数

function lootUI.IsSafeBoxItem(itemName)
    return itemName == "二级安全箱" or itemName == "三级安全箱"
end

function lootUI.UpdateSafeBoxCapacity(itemName)
    if itemName == "三级安全箱" then
        SAFE_GRID_COLS = 4
        SAFE_GRID_ROWS = 3
    else
        SAFE_GRID_COLS = 3
        SAFE_GRID_ROWS = 2
    end
    SAFE_MAX = SAFE_GRID_COLS * SAFE_GRID_ROWS
end

-- 背包物品（玩家已拾取），与宝箱相同的网格布局
playerInventory = {}  -- 战前从据点仓库选择携带物资
INV_GRID_COLS = 4   -- 背包网格列数
INV_GRID_ROWS = 4   -- 背包网格行数（缩小，给胸挂留空间）
INVENTORY_MAX = 12  -- 背包最大物品数（非格子数）

-- 据点仓库独立于战术背包；首仓保存出战装备和武器。
warehouseTabs = {
    { name = "一号仓库", unlocked = true, level = 1, maxLevel = 3, cols = 8, rows = 20,
        items = { "翡翠原石", "金条", "古董花瓶", "平板电脑", "二级头盔", "二级防弹衣", "二级胸挂", "二级背包", "二级安全箱" },
        upgradeMaterials = {
            [2] = { { item = "螺丝刀", count = 2 }, { item = "胶带", count = 3 } },
            [3] = { { item = "扳手", count = 2 }, { item = "电池", count = 5 } },
        },
    },
    { name = "二号仓库", unlocked = true, level = 1, maxLevel = 3, cols = 8, rows = 20, items = {},
        upgradeMaterials = {
            [2] = { { item = "扳手", count = 3 }, { item = "金条", count = 1 } },
            [3] = { { item = "机械键盘", count = 2 }, { item = "急救包", count = 4 } },
        },
    },
    { name = "三号仓库", unlocked = true, level = 1, maxLevel = 3, cols = 8, rows = 20, items = {},
        upgradeMaterials = {
            [2] = { { item = "电池", count = 6 }, { item = "净水", count = 4 } },
            [3] = { { item = "平板电脑", count = 2 }, { item = "成捆现金", count = 3 } },
        },
    },
}

-- 稀有度对应的加载延迟（价值越高加载越久）
local RARITY_LOAD_DELAY = {
    green  = 0.5,   -- 普通：0.5秒
    blue   = 1.2,   -- 精良：1.2秒
    purple = 2.0,   -- 稀有：2秒
    pink   = 3.0,   -- 史诗：3秒
    gold   = 3.0,   -- 金色收藏品：3秒
    red    = 4.5,   -- 传说：4.5秒
}

-- 宝箱数据（会在 drawCrossSection 渲染时计算屏幕坐标）
-- 每个宝箱: {floor=楼层fi, room="left"/"mid"/"right", items={...}, looted=false, sx, sy, sw, sh}
-- 稀有度等级及对应背景色（价值从高到低）
-- red=传说, pink=史诗, purple=稀有, blue=精良, green=普通
local RARITY_COLORS = {
    red    = {180, 30, 30},    -- 传说
    pink   = {190, 60, 130},   -- 史诗
    gold   = {218, 160, 38},   -- 金色收藏品
    purple = {120, 50, 180},   -- 稀有
    blue   = {40, 100, 200},   -- 精良
    green  = {40, 150, 60},    -- 普通
}

-- 统一物资格子的稀有度背景：四周颜色一致，向中心均匀变深，不绘制边框。
function drawRarityGradient(ctx, rarity, x, y, w, h, alpha, radius)
    local rc = RARITY_COLORS[rarity] or RARITY_COLORS.green
    local opacity = math.max(0, math.min(1, alpha or 1))
    local cornerRadius = radius or 3
    local darkR = math.floor(rc[1] * 0.16)
    local darkG = math.floor(rc[2] * 0.16)
    local darkB = math.floor(rc[3] * 0.16)

    -- 先铺统一稀有度颜色，保证相邻物品的每条边亮度一致。
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x, y, w, h, cornerRadius)
    nvgFillColor(ctx, nvgRGBA(rc[1], rc[2], rc[3], math.floor(185 * opacity)))
    nvgFill(ctx)

    -- BoxGradient 按到四边的距离渐变，使中心均匀压暗，没有方向性断层。
    local insetPaint = nvgBoxGradient(
        ctx,
        x,
        y,
        w,
        h,
        cornerRadius,
        math.max(8, math.min(w, h) * 0.48),
        nvgRGBA(darkR, darkG, darkB, math.floor(220 * opacity)),
        nvgRGBA(darkR, darkG, darkB, 0)
    )
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x, y, w, h, cornerRadius)
    nvgFillPaint(ctx, insetPaint)
    nvgFill(ctx)
end

function drawItemNameBar(ctx, itemName, x, y, w, h, alpha)
    if not itemName or itemName == "" then return end
    local barH = math.min(20, math.max(14, h * 0.28))
    local barY = y + h - barH
    local opacity = math.floor(105 * (alpha or 1))
    local textSize = math.max(5, math.min(8, w * 0.115))
    local availableTextW = math.max(1, w - 12)
    nvgSave(ctx)
    nvgFontFace(ctx, "sans")
    nvgFontSize(ctx, textSize)
    local measuredTextW = nvgTextBounds(ctx, 0, 0, itemName) or 0
    if measuredTextW > availableTextW then
        textSize = math.max(3.5, textSize * availableTextW / measuredTextW * 0.78)
        nvgFontSize(ctx, textSize)
    end
    nvgBeginPath(ctx)
    nvgRect(ctx, x, barY, w, barH)
    nvgFillColor(ctx, nvgRGBA(0, 0, 0, opacity))
    nvgFill(ctx)
    nvgIntersectScissor(ctx, x, barY, w, barH)
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(ctx, nvgRGBA(248, 244, 230, math.floor(245 * (alpha or 1))))
    nvgText(ctx, x + w * 0.5, barY + 2, itemName)
    nvgRestore(ctx)
end

-- 物品定义：尺寸 {w, h} + 稀有度
local ITEM_SIZES = {
    -- 传说（red）
    ["劳力士金表"]   = {1, 1},
    ["翡翠原石"]     = {2, 2},
    ["金条"]         = {2, 1},
    -- 史诗（pink）
    ["钻石项链"]     = {1, 2},
    ["古董花瓶"]     = {2, 2},
    -- 稀有（purple）
    ["名牌手包"]     = {2, 1},
    ["银币收藏"]     = {1, 1},
    ["红酒82年"]     = {1, 2},
    -- 精良（blue）
    ["珍珠耳环"]     = {1, 1},
    ["象牙雕件"]     = {1, 1},
    ["机械键盘"]     = {2, 1},
    ["平板电脑"]     = {2, 1},
    ["急救包"]       = {2, 1},
    ["成捆现金"]     = {2, 1},
    -- 普通（green）
    ["铜戒指"]       = {1, 1},
    ["旧手机"]       = {1, 1},
    ["打火机"]       = {1, 1},
    ["罐头"]         = {1, 1},
    ["螺丝刀"]       = {1, 1},
    ["电池"]         = {1, 1},
    ["净水"]         = {1, 1},
    ["胶带"]         = {1, 1},
    ["扳手"]         = {1, 1},
    ["手枪"]         = {2, 1},
    ["散弹枪"]       = {3, 1},
    ["手枪弹药盒"]   = {1, 1},
    ["散弹枪弹药包"] = {2, 1},
    ["棒球棍"]       = {3, 1},
    ["二级头盔"]     = {2, 2},
    ["二级防弹衣"]   = {2, 2},
    ["二级胸挂"]     = {2, 2},
    ["二级背包"]     = {2, 2},
    ["二级安全箱"]   = {2, 2},
    ["三级安全箱"]   = {3, 2},
}
function lootUI.IsTakenGridEntry(entry)
    local itemName = type(entry) == "table" and entry.item or entry
    return type(itemName) == "string" and itemName:sub(1, 10) == "__taken__:"
end

function lootUI.CleanupTakenEntries(items)
    if not items then return end
    for index = #items, 1, -1 do
        if lootUI.IsTakenGridEntry(items[index]) then
            table.remove(items, index)
        end
    end
end

function lootUI.GetGridItemName(entry)
    local itemName = type(entry) == "table" and entry.item or entry
    if type(itemName) == "string" and itemName:sub(1, 10) == "__taken__:" then
        return itemName:sub(11)
    end
    return itemName
end

function lootUI.GetGridItemSize(entry, orientationOverride)
    local itemName = lootUI.GetGridItemName(entry)
    local size = ITEM_SIZES[itemName] or {1, 1}
    local orientation = orientationOverride
        or (type(entry) == "table" and entry.orientation)
        or "horizontal"
    if orientation == "vertical" then
        return size[2], size[1], orientation
    end
    return size[1], size[2], orientation
end

function lootUI.MakeGridItem(itemName, col, row, orientation)
    if orientation and orientation ~= "horizontal" then
        return { item = itemName, col = col, row = row, orientation = orientation }
    end
    return { item = itemName, col = col, row = row }
end

local function getItemIconDrawRect(itemName, boxX, boxY, boxW, boxH, scale)
    -- 所有物资统一放大约28%，同时限制在物资格内部，避免相邻物资互相覆盖。
    local iconScale = math.min(0.96, (scale or 0.82) * 1.28)
    if itemName == "香槟酒" then
        local aspect = 256 / 512
        local maxW = boxW * 0.82
        local maxH = boxH * 0.88
        local iconH = math.min(maxH, maxW / aspect)
        local iconW = iconH * aspect
        return boxX + (boxW - iconW) * 0.5,
            boxY + (boxH - iconH) * 0.44,
            iconW,
            iconH
    end
    if itemName == "红酒82年" then
        local aspect = 83 / 244
        local maxW = boxW * 0.82
        local maxH = boxH * 0.88
        local iconH = math.min(maxH, maxW / aspect)
        local iconW = iconH * aspect
        return boxX + (boxW - iconW) * 0.5,
            boxY + (boxH - iconH) * 0.54,
            iconW,
            iconH
    end
    if itemName == "散弹枪" or itemName == "棒球棍" then
        local aspect = itemName == "散弹枪" and (498 / 195) or (256 / 71)
        local maxW = boxW * 0.96
        local maxH = boxH * 0.88
        local iconW = maxW
        local iconH = iconW / aspect
        if iconH > maxH then
            iconH = maxH
            iconW = iconH * aspect
        end
        return boxX + (boxW - iconW) * 0.5,
            boxY + (boxH - iconH) * 0.42,
            iconW,
            iconH
    end
    if itemName == "金条" then
        iconScale = math.max(iconScale, 0.90)
    end
    local iconSize = math.min(boxW, boxH) * iconScale
    return boxX + (boxW - iconSize) * 0.5, boxY + (boxH - iconSize) * 0.5, iconSize, iconSize
end

-- 物品稀有度映射
local ITEM_RARITY = {
    ["劳力士金表"] = "red",    ["翡翠原石"]   = "red",    ["金条"] = "red",
    ["收藏金币"]   = "gold",
    ["钻石项链"]   = "pink",   ["古董花瓶"]   = "pink",
    ["名牌手包"]   = "purple", ["银币收藏"]   = "purple", ["红酒82年"] = "purple",
    ["珍珠耳环"]   = "blue",   ["象牙雕件"]   = "blue",   ["机械键盘"] = "blue",  ["平板电脑"] = "blue",
    ["急救包"]     = "blue",   ["成捆现金"]   = "blue",
    ["铜戒指"]     = "green",  ["旧手机"]     = "green",  ["打火机"]   = "green",
    ["罐头"]       = "green",  ["螺丝刀"]     = "green",  ["电池"]     = "green",
    ["净水"]       = "green",  ["胶带"]       = "green",  ["扳手"]     = "green",
    ["手枪"]       = "blue",
    ["散弹枪"]     = "red",
    ["手枪弹药盒"] = "green",
    ["散弹枪弹药包"] = "blue",
    ["棒球棍"]     = "blue",
    ["二级头盔"]   = "blue",
    ["二级防弹衣"] = "blue",
    ["二级胸挂"]   = "blue",
    ["二级背包"]   = "blue",
    ["二级安全箱"] = "blue",
    ["三级安全箱"] = "red",
}

-- 只能从胸挂或口袋快速食用；主背包和安全箱中的食物不会出现在快捷按钮上。
EDIBLE_ITEMS = {
    ["罐头"] = { heal = 25 },
    ["净水"] = { heal = 15 },
}

function getStoredItemName(entry)
    return type(entry) == "table" and entry.item or entry
end

function findQuickConsumable()
    for idx, entry in ipairs(playerChestRig) do
        local itemName = getStoredItemName(entry)
        if EDIBLE_ITEMS[itemName] then
            return playerChestRig, idx, itemName, "胸挂"
        end
    end
    for idx, entry in ipairs(playerPocket) do
        local itemName = getStoredItemName(entry)
        if EDIBLE_ITEMS[itemName] then
            return playerPocket, idx, itemName, "口袋"
        end
    end
    return nil, nil, nil, nil
end

function consumeQuickConsumable()
    if consumeCooldown > 0 then return false end

    local container, idx, itemName, sourceName = findQuickConsumable()
    if not container or not idx or not itemName then return false end

    local hpMax = math.max(1, player.maxHp or 100)
    local hp = math.max(0, math.min(hpMax, player.hp or hpMax))
    if hp >= hpMax then
        print("[Consume] 当前生命已满，未消耗 " .. itemName)
        return false
    end

    local config = EDIBLE_ITEMS[itemName]
    table.remove(container, idx)
    consumeCooldown = CONSUME_COOLDOWN_DURATION
    consumeCooldownItemName = itemName
    pendingConsumeHeal = config.heal
    print("[Consume] 从" .. sourceName .. "开始食用 " .. itemName
        .. "，将在 " .. tostring(CONSUME_COOLDOWN_DURATION)
        .. " 秒后恢复 " .. tostring(config.heal) .. " 生命")
    return true
end

function updateConsumeCooldown(dt)
    if consumeCooldown <= 0 then return end

    local previousCooldown = consumeCooldown
    consumeCooldown = math.max(0, consumeCooldown - dt)
    if previousCooldown > 0 and consumeCooldown <= 0 then
        local hpMax = math.max(1, player.maxHp or 100)
        local hp = math.max(0, math.min(hpMax, player.hp or hpMax))
        local healed = math.min(pendingConsumeHeal, hpMax - hp)
        player.hp = hp + healed
        spawnHealingPlusParticles(healed)
        print("[Consume] 完成食用 " .. tostring(consumeCooldownItemName)
            .. "，恢复 " .. tostring(healed) .. " 生命，当前 "
            .. tostring(player.hp) .. "/" .. tostring(hpMax))
        pendingConsumeHeal = 0
        consumeCooldownItemName = nil
    end
end

-- 按容器顺序生成累计揭示时间：前一个物资完成后，下一个物资才开始加载。
function lootUI.GetSequentialRevealSchedule(items)
    local startTimes = {}
    local revealTimes = {}
    local totalDuration = 0

    for idx, entry in ipairs(items or {}) do
        local itemName = lootUI.GetGridItemName(entry)
        local taken = lootUI.IsTakenGridEntry(entry)
        if not taken then
            local rarity = ITEM_RARITY[itemName] or "green"
            startTimes[idx] = totalDuration
            totalDuration = totalDuration + (RARITY_LOAD_DELAY[rarity] or 0.5)
            revealTimes[idx] = totalDuration
        end
    end

    return startTimes, revealTimes, totalDuration
end
local CHEST_GRID_COLS = 6  -- 右侧容器网格列数
local CHEST_GRID_ROWS = 6  -- 右侧容器网格行数

lootUI.itemValues = {
    ["劳力士金表"] = { value = 120000, desc = "保存完好的名表，黑市高价硬通货。" },
    ["翡翠原石"] = { value = 98000, desc = "稀有玉石原料，重量高但价值稳定。" },
    ["金条"] = { value = 68000, desc = "避险资产，几乎所有商人都愿意收。" },
    ["钻石项链"] = { value = 52000, desc = "奢侈首饰，体积小、价值高。" },
    ["古董花瓶"] = { value = 42000, desc = "完整度不错的古董，易碎但很值钱。" },
    ["名牌手包"] = { value = 18000, desc = "高端品牌包，成色决定出手价格。" },
    ["银币收藏"] = { value = 15000, desc = "成套银币，有收藏和贵金属价值。" },
    ["红酒82年"] = { value = 12000, desc = "稀缺老酒，适合交易或收藏。" },
    ["珍珠耳环"] = { value = 7600, desc = "小件首饰，方便藏在口袋里。" },
    ["象牙雕件"] = { value = 6900, desc = "旧时代工艺品，收藏者会出价。" },
    ["机械键盘"] = { value = 3600, desc = "可拆零件，也能直接卖给幸存者。" },
    ["平板电脑"] = { value = 4200, desc = "电子设备，屏幕和电池仍有价值。" },
    ["急救包"] = { value = 3200, desc = "关键医疗物资，受伤时比钱更有用。" },
    ["成捆现金"] = { value = 6500, desc = "旧钞仍可在部分据点兑换物资。" },
    ["铜戒指"] = { value = 900, desc = "普通金属饰品，聊胜于无。" },
    ["旧手机"] = { value = 1300, desc = "可拆电路板和零件。" },
    ["打火机"] = { value = 700, desc = "小型火源，野外生存常用。" },
    ["罐头"] = { value = 500, desc = "基础食物，安全可靠。" },
    ["螺丝刀"] = { value = 650, desc = "常用工具，可拆卸设备和门锁。" },
    ["电池"] = { value = 450, desc = "消耗品，手电和设备都需要。" },
    ["净水"] = { value = 600, desc = "干净饮用水，短缺时很抢手。" },
    ["胶带"] = { value = 520, desc = "修补和捆扎都用得上。" },
    ["扳手"] = { value = 800, desc = "维修工具，也能临时当武器。" },
    ["手枪"] = { value = 8800, desc = "半自动手枪，可装备到枪支槽，也可以占用背包两格携带。" },
    ["散弹枪"] = { value = 12800, desc = "双管折管散弹枪，近距离爆发力强，可装备到枪支槽。" },
    ["手枪弹药盒"] = { value = 1200, desc = "装有24发9毫米子弹的密封铁盒，可作为手枪弹药补给。" },
    ["散弹枪弹药包"] = { value = 1800, desc = "装有12发12号散弹的帆布弹药包，可作为散弹枪弹药补给。" },
    ["棒球棍"] = { value = 6200, desc = "缠绕铁丝的棒球棍，可装备到近战武器槽并切换为近战角色动作。" },
    ["二级头盔"] = { value = 4800, desc = "基础战术头盔，可装备到头盔槽。" },
    ["二级防弹衣"] = { value = 7200, desc = "带防弹插板的二级战术护甲，可装备到防弹衣槽。" },
    ["二级胸挂"] = { value = 5600, desc = "二级战术胸挂，可装备到胸挂槽。" },
    ["二级背包"] = { value = 6800, desc = "二级战术背包，装备后开放背包储物网格。" },
    ["二级安全箱"] = { value = 8600, desc = "二级安全箱，可装备到安全箱槽保护重要物资。" },
    ["三级安全箱"] = { value = 19800, desc = "传说级猩红安全箱，装备后开放 4×3 共十二格绝密储物空间。" },
}

local chestDefs = {
    { floor = 0, room = "mid",   name = "废弃纸箱", items = {"罐头", "电池", "螺丝刀"}, looted = false },
    { floor = 0, room = "mid",   name = "保险箱",   items = {"劳力士金表", "金条"}, looted = false },
    { floor = 0, room = "left",  name = "武器架",   items = {"银币收藏", "名牌手包", "铜戒指"}, looted = false },
    { floor = 5, room = "right", name = "储物柜",   items = {"翡翠原石", "珍珠耳环"}, looted = false },
    { floor = 4, room = "right", name = "衣柜",     items = {"古董花瓶", "钻石项链"}, looted = false },
    { floor = 3, room = "right", name = "抽屉",     items = {"红酒82年", "打火机", "旧手机"}, looted = false },
    { floor = 2, room = "right", name = "书架",     items = {"平板电脑", "机械键盘", "象牙雕件"}, looted = false },
    { floor = 5, room = "left",  name = "工具柜",   items = {"扳手", "胶带", "电池", "螺丝刀"}, looted = false },
    { floor = 4, room = "left",  name = "药柜",     items = {"急救包", "净水", "电池"}, looted = false },
    { floor = 4, room = "mid",   name = "保险箱",   items = {"成捆现金", "珍珠耳环", "铜戒指"}, looted = false },
    { floor = 3, room = "left",  name = "药柜",     items = {"急救包", "净水", "打火机"}, looted = false },
    { floor = 3, room = "mid",   name = "床头柜",   items = {"旧手机", "铜戒指", "电池"}, looted = false },
    { floor = 2, room = "mid",   name = "床头柜",   items = {"红酒82年", "打火机", "成捆现金"}, looted = false },
    { floor = 2, room = "right", name = "冰箱",     items = {"罐头", "净水", "电池"}, looted = false },
    { floor = 1, room = "mid",   name = "保险箱",   items = {"金条", "成捆现金", "银币收藏"}, looted = false },
    { floor = 1, room = "right", name = "饮料冷柜", items = {"罐头", "净水", "胶带"}, looted = false },
    { floor = 0, room = "street_super", name = "超市收银台", items = {"成捆现金", "旧手机", "打火机"}, looted = false },
    { floor = 0, room = "street_super", name = "超市货架",   items = {"罐头", "净水", "电池", "胶带"}, looted = false },
    { floor = 0, room = "street_super", name = "超市冷柜",   items = {"罐头", "净水", "电池"}, looted = false },
    { floor = 0, room = "street_warehouse", name = "仓库木箱", items = {"螺丝刀", "电池", "胶带", "扳手"}, looted = false },
    { floor = 0, room = "street_warehouse", name = "仓库工具架", items = {"扳手", "螺丝刀", "胶带", "电池"}, looted = false },
    { floor = 0, room = "street_pharmacy", name = "药店药柜", items = {"急救包", "净水", "胶带"}, looted = false },
    { floor = 0, room = "street_pharmacy", name = "药店收银台", items = {"成捆现金", "铜戒指", "旧手机"}, looted = false },
    { floor = 5, room = "left", name = "金属储物柜", items = {}, looted = false },
    { floor = 4, room = "left", name = "卫生间医疗用品", items = {}, looted = false },
    { floor = 4, room = "mid", name = "书架", items = {}, looted = false },
    { floor = 4, room = "right", name = "厨房储物柜", items = {}, looted = false },
    { floor = 3, room = "left", name = "卫生间医疗用品", items = {}, looted = false },
    { floor = 3, room = "mid", name = "衣柜", items = {}, looted = false },
    { floor = 3, room = "right", name = "厨房储物柜", items = {}, looted = false },
    { floor = 2, room = "left", name = "卫生间医疗用品", items = {}, looted = false },
    { floor = 2, room = "mid", name = "书架", items = {}, looted = false },
    { floor = 2, room = "right", name = "厨房储物柜", items = {}, looted = false },
    { floor = 1, room = "left", name = "书架", items = {}, looted = false },
    { floor = 1, room = "mid", name = "衣柜", items = {}, looted = false },
    { floor = 1, room = "right", name = "金属储物柜", items = {}, looted = false },
    { floor = 0, room = "basement_right", name = "金属储物柜", items = {}, looted = false },
    { floor = 0, room = "annex_workbench", name = "工作台", items = {}, looted = false },
    { floor = 0, room = "annex_cabinet", name = "工具柜", items = {}, looted = false },
    { floor = 0, room = "annex_tires", name = "轮胎架", items = {}, looted = false },
    { floor = 4, room = "mid", name = "玻璃展示柜", items = {}, looted = false },
    { floor = 3, room = "mid", name = "床头柜", items = {}, looted = false },
    { floor = 2, room = "mid", name = "工具抽屉柜", items = {}, looted = false },
    { floor = 5, room = "left", name = "窄边储物柜", items = {}, looted = false },
    { floor = 4, room = "right", name = "小型现代保险柜", items = {}, looted = false },
    { floor = 3, room = "mid", name = "小型现代文件保险柜", items = {}, looted = false },
    { floor = 2, room = "right", name = "小型现代珠宝保险柜", items = {}, looted = false },

    -- 第一栋楼背景家具搜刮点：只补充尚未绑定交互的家具，room 使用唯一键避免索引覆盖。
    { floor = 5, room = "cs1_5f_tool_drawers", name = "工具抽屉柜", items = {}, looted = false },
    { floor = 4, room = "cs1_4f_fridge", name = "冰箱", items = {}, looted = false },
    { floor = 3, room = "cs1_3f_fridge", name = "冰箱", items = {}, looted = false },
    { floor = 3, room = "cs1_3f_sink_cabinet", name = "厨房储物柜", items = {}, looted = false },
    { floor = 2, room = "cs1_2f_tv_cabinet", name = "电视柜", items = {}, looted = false },
    { floor = 2, room = "cs1_2f_fridge", name = "冰箱", items = {}, looted = false },
    { floor = 1, room = "cs1_1f_liquor_cabinet", name = "酒柜", items = {}, looted = false },
    { floor = 1, room = "cs1_1f_shop_counter", name = "小卖部收银台", items = {}, looted = false },

    -- 第二栋居民服务楼：搜刮点与家具组合图中的可开启柜体、抽屉和设备一一对应。
    { floor = 4, room = "cs2_1_1_nightstand", name = "床头柜", items = {}, looted = false },
    { floor = 4, room = "cs2_1_1_wardrobe", name = "衣柜", items = {}, looted = false },
    { floor = 4, room = "cs2_1_2_shelf", name = "储物货架", items = {}, looted = false },
    { floor = 4, room = "cs2_1_2_locker", name = "金属储物柜", items = {}, looted = false },
    { floor = 4, room = "cs2_1_3_washer", name = "洗衣机", items = {}, looted = false },
    { floor = 4, room = "cs2_1_3_sink", name = "清洁用品柜", items = {}, looted = false },
    { floor = 4, room = "cs2_1_3_cleaning", name = "洗涤用品架", items = {}, looted = false },
    { floor = 3, room = "cs2_2_1_vanity", name = "洗手台柜", items = {}, looted = false },
    { floor = 3, room = "cs2_2_1_medicine", name = "药品柜", items = {}, looted = false },
    { floor = 3, room = "cs2_2_2_coffee_table", name = "茶几抽屉", items = {}, looted = false },
    { floor = 3, room = "cs2_2_2_tv_cabinet", name = "电视柜", items = {}, looted = false },
    { floor = 3, room = "cs2_2_3_desk", name = "书桌抽屉", items = {}, looted = false },
    { floor = 3, room = "cs2_2_3_bookshelf", name = "书架", items = {}, looted = false },
    { floor = 2, room = "cs2_3_1_nightstand", name = "床头柜", items = {}, looted = false },
    { floor = 2, room = "cs2_3_1_dresser", name = "衣物斗柜", items = {}, looted = false },
    { floor = 2, room = "cs2_3_2_table", name = "餐桌物资", items = {}, looted = false },
    { floor = 2, room = "cs2_3_2_sideboard", name = "餐边柜", items = {}, looted = false },
    { floor = 2, room = "cs2_3_3_sink", name = "厨房储物柜", items = {}, looted = false },
    { floor = 2, room = "cs2_3_3_fridge", name = "冰箱", items = {}, looted = false },
    { floor = 2, room = "cs2_3_3_wall_cabinet", name = "厨房吊柜", items = {}, looted = false },
    { floor = 1, room = "cs2_4_1_register", name = "便民店收银台", items = {}, looted = false },
    { floor = 1, room = "cs2_4_1_shelf", name = "便民店货架", items = {}, looted = false },
    { floor = 1, room = "cs2_4_1_cooler", name = "饮料冷柜", items = {}, looted = false },
    { floor = 1, room = "cs2_4_2_desk", name = "办公桌抽屉", items = {}, looted = false },
    { floor = 1, room = "cs2_4_2_low_files", name = "文件矮柜", items = {}, looted = false },
    { floor = 1, room = "cs2_4_2_tall_files", name = "文件柜", items = {}, looted = false },
    { floor = 1, room = "cs2_4_3_workbench", name = "维修工作台", items = {}, looted = false },
    { floor = 1, room = "cs2_4_3_drawers", name = "工具抽屉柜", items = {}, looted = false },
    { floor = 1, room = "cs2_4_3_parts", name = "零件货架", items = {}, looted = false },
    { floor = 1, room = "cs2_4_3_toolbox", name = "工具箱", items = {}, looted = false },
}

function lootUI.RebuildChestIndexByRoom()
    lootUI.chestIndexByRoom = {}
    for index, chest in ipairs(chestDefs) do
        if chest.room and chest.room ~= "" then
            lootUI.chestIndexByRoom[chest.room] = index
        end
    end
end

lootUI.RebuildChestIndexByRoom()

lootUI.cs2FurnitureLootSpots = {
    ["1_1"] = {
        { room = "cs2_1_1_nightstand", x = 0.48, y = 0.53, w = 0.16, h = 0.32 },
        { room = "cs2_1_1_wardrobe", x = 0.67, y = 0.12, w = 0.27, h = 0.75 },
    },
    ["1_2"] = {
        { room = "cs2_1_2_shelf", x = 0.04, y = 0.11, w = 0.27, h = 0.73 },
        { room = "cs2_1_2_locker", x = 0.55, y = 0.26, w = 0.19, h = 0.58 },
    },
    ["1_3"] = {
        { room = "cs2_1_3_washer", x = 0.04, y = 0.27, w = 0.27, h = 0.57 },
        { room = "cs2_1_3_sink", x = 0.32, y = 0.40, w = 0.31, h = 0.44 },
        { room = "cs2_1_3_cleaning", x = 0.64, y = 0.13, w = 0.17, h = 0.71 },
    },
    ["2_1"] = {
        { room = "cs2_2_1_vanity", x = 0.34, y = 0.45, w = 0.30, h = 0.40 },
        { room = "cs2_2_1_medicine", x = 0.71, y = 0.12, w = 0.21, h = 0.73 },
    },
    ["2_2"] = {
        { room = "cs2_2_2_coffee_table", x = 0.42, y = 0.62, w = 0.22, h = 0.15 },
        { room = "cs2_2_2_tv_cabinet", x = 0.65, y = 0.55, w = 0.24, h = 0.22 },
    },
    ["2_3"] = {
        { room = "cs2_2_3_desk", x = 0.02, y = 0.51, w = 0.38, h = 0.34 },
        { room = "cs2_2_3_bookshelf", x = 0.64, y = 0.10, w = 0.23, h = 0.75 },
    },
    ["3_1"] = {
        { room = "cs2_3_1_nightstand", x = 0.46, y = 0.40, w = 0.15, h = 0.39 },
        { room = "cs2_3_1_dresser", x = 0.63, y = 0.35, w = 0.29, h = 0.44 },
    },
    ["3_2"] = {
        { room = "cs2_3_2_table", x = 0.02, y = 0.43, w = 0.37, h = 0.27 },
        { room = "cs2_3_2_sideboard", x = 0.70, y = 0.43, w = 0.27, h = 0.27 },
    },
    ["3_3"] = {
        { room = "cs2_3_3_sink", x = 0.02, y = 0.46, w = 0.40, h = 0.34 },
        { room = "cs2_3_3_fridge", x = 0.65, y = 0.24, w = 0.20, h = 0.56 },
        { room = "cs2_3_3_wall_cabinet", x = 0.86, y = 0.25, w = 0.12, h = 0.31 },
    },
    ["4_1"] = {
        { room = "cs2_4_1_register", x = 0.03, y = 0.38, w = 0.33, h = 0.41 },
        { room = "cs2_4_1_shelf", x = 0.37, y = 0.28, w = 0.29, h = 0.51 },
        { room = "cs2_4_1_cooler", x = 0.67, y = 0.25, w = 0.17, h = 0.54 },
    },
    ["4_2"] = {
        { room = "cs2_4_2_desk", x = 0.02, y = 0.51, w = 0.35, h = 0.27 },
        { room = "cs2_4_2_low_files", x = 0.64, y = 0.56, w = 0.20, h = 0.22 },
        { room = "cs2_4_2_tall_files", x = 0.85, y = 0.27, w = 0.13, h = 0.51 },
    },
    ["4_3"] = {
        { room = "cs2_4_3_workbench", x = 0.02, y = 0.47, w = 0.44, h = 0.39 },
        { room = "cs2_4_3_drawers", x = 0.47, y = 0.43, w = 0.17, h = 0.43 },
        { room = "cs2_4_3_parts", x = 0.65, y = 0.46, w = 0.21, h = 0.40 },
        { room = "cs2_4_3_toolbox", x = 0.86, y = 0.67, w = 0.13, h = 0.19 },
    },
}

lootUI.currencyName = "比特"
lootUI.bits = 30000

function lootUI.FormatBitValue(value)
    local n = math.max(0, math.floor(tonumber(value) or 0))
    local text = tostring(n)
    local reversed = string.reverse(text)
    reversed = string.gsub(reversed, "(%d%d%d)", "%1,")
    text = string.reverse(reversed)
    text = string.gsub(text, "^,", "")
    return text .. " " .. lootUI.currencyName
end

lootUI.lootPools = {
    general = {
        "劳力士金表", "翡翠原石", "金条", "钻石项链", "古董花瓶", "名牌手包", "银币收藏", "红酒82年",
        "珍珠耳环", "象牙雕件", "机械键盘", "平板电脑", "急救包", "成捆现金", "铜戒指", "旧手机",
        "打火机", "罐头", "螺丝刀", "电池", "净水", "胶带", "扳手",
    },
    common = { "罐头", "电池", "螺丝刀", "打火机", "净水", "胶带", "扳手", "旧手机", "铜戒指" },
    safe = { "劳力士金表", "翡翠原石", "金条", "钻石项链", "古董花瓶", "成捆现金", "银币收藏", "珍珠耳环", "名牌手包", "铜戒指" },
    valuables = { "金条", "钻石项链", "古董花瓶", "名牌手包", "银币收藏", "红酒82年", "珍珠耳环", "铜戒指", "成捆现金" },
    wardrobe = { "名牌手包", "珍珠耳环", "钻石项链", "红酒82年", "铜戒指", "打火机", "旧手机", "古董花瓶" },
    drawer = { "红酒82年", "打火机", "旧手机", "铜戒指", "电池", "珍珠耳环", "成捆现金" },
    electronics = { "平板电脑", "机械键盘", "旧手机", "电池", "螺丝刀", "胶带", "象牙雕件", "红酒82年" },
    tools = { "扳手", "胶带", "电池", "螺丝刀", "机械键盘", "旧手机", "平板电脑" },
    medical = { "急救包", "净水", "电池", "胶带", "打火机" },
    food = { "罐头", "净水", "电池", "胶带", "打火机" },
    supermarket = { "罐头", "净水", "电池", "胶带", "打火机", "旧手机", "成捆现金" },
    warehouse = { "扳手", "胶带", "电池", "螺丝刀", "机械键盘", "旧手机", "平板电脑", "铜戒指" },
}

lootUI.chestLootConfigByName = {
    ["废弃纸箱"] = { pool = "common", min = 2, max = 4 },
    ["保险箱"] = { pool = "safe", min = 2, max = 3 },
    ["武器架"] = { pool = "valuables", min = 2, max = 4 },
    ["储物柜"] = { pool = "general", min = 2, max = 4 },
    ["衣柜"] = { pool = "wardrobe", min = 2, max = 4 },
    ["抽屉"] = { pool = "drawer", min = 2, max = 4 },
    ["书架"] = { pool = "electronics", min = 2, max = 4 },
    ["工具柜"] = { pool = "tools", min = 3, max = 5 },
    ["药柜"] = { pool = "medical", min = 2, max = 4 },
    ["床头柜"] = { pool = "drawer", min = 2, max = 3 },
    ["冰箱"] = { pool = "food", min = 2, max = 4 },
    ["饮料冷柜"] = { pool = "food", min = 2, max = 4 },
    ["超市收银台"] = { pool = "valuables", min = 2, max = 3 },
    ["超市货架"] = { pool = "supermarket", min = 3, max = 5 },
    ["超市冷柜"] = { pool = "food", min = 2, max = 4 },
    ["仓库木箱"] = { pool = "warehouse", min = 3, max = 5 },
    ["仓库工具架"] = { pool = "tools", min = 3, max = 5 },
    ["药店药柜"] = { pool = "medical", min = 3, max = 5 },
    ["药店收银台"] = { pool = "valuables", min = 2, max = 3 },
    ["工具抽屉柜"] = { pool = "tools", min = 2, max = 4 },
    ["电视柜"] = { pool = "electronics", min = 2, max = 4 },
    ["厨房储物柜"] = { pool = "food", min = 2, max = 4 },
    ["酒柜"] = { pool = "valuables", min = 2, max = 4 },
    ["小卖部收银台"] = { pool = "supermarket", min = 2, max = 4 },
}

-- 高价值搜刮物：降低“全是垃圾”的情况，同时保留普通物资的生存意义。
ITEM_SIZES["香槟酒"] = {1, 2}
ITEM_SIZES["高级香烟"] = {1, 1}
ITEM_SIZES["名贵香水"] = {1, 1}
ITEM_SIZES["加密硬盘"] = {2, 1}
ITEM_SIZES["通用战术消音器"] = {2, 1}
ITEM_SIZES["军用望远镜"] = {2, 1}
ITEM_SIZES["卫星电话"] = {2, 1}
ITEM_SIZES["古董相机"] = {2, 2}
ITEM_SIZES["铂金打火机"] = {1, 1}
ITEM_SIZES["高级太阳镜"] = {2, 1}
ITEM_SIZES["古董指南针"] = {1, 1}
ITEM_SIZES["稀有咖啡豆"] = {1, 2}
ITEM_SIZES["收藏金币"] = {1, 1}
ITEM_SIZES["红宝石戒指"] = {1, 1}
ITEM_SIZES["显卡"] = {3, 2}
ITEM_SIZES["黄金半身像"] = {2, 2}
ITEM_SIZES["军用加固笔记本"] = {2, 2}

ITEM_RARITY["香槟酒"] = "red"
ITEM_RARITY["高级香烟"] = "blue"
ITEM_RARITY["名贵香水"] = "purple"
ITEM_RARITY["加密硬盘"] = "pink"
ITEM_RARITY["通用战术消音器"] = "purple"
ITEM_RARITY["军用望远镜"] = "purple"
ITEM_RARITY["卫星电话"] = "pink"
ITEM_RARITY["古董相机"] = "purple"
ITEM_RARITY["铂金打火机"] = "blue"
ITEM_RARITY["高级太阳镜"] = "blue"
ITEM_RARITY["古董指南针"] = "blue"
ITEM_RARITY["稀有咖啡豆"] = "blue"
ITEM_RARITY["收藏金币"] = "gold"
ITEM_RARITY["红宝石戒指"] = "pink"
ITEM_RARITY["显卡"] = "red"
ITEM_RARITY["黄金半身像"] = "red"
ITEM_RARITY["军用加固笔记本"] = "red"

lootUI.itemValues["加密硬盘"] = { value = 24000, desc = "加密数据盘，里面可能保存着旧时代的重要资料。" }
lootUI.itemValues["通用战术消音器"] = { value = 34000, desc = "适配多种枪口的高等级战术消音器，黑市渠道来源不明。" }
lootUI.itemValues["军用望远镜"] = { value = 11000, desc = "耐用的军用光学设备，侦察和交易都很有价值。" }
lootUI.itemValues["卫星电话"] = { value = 30000, desc = "仍可能工作的卫星通信设备，稀缺且价值很高。" }
lootUI.itemValues["古董相机"] = { value = 14500, desc = "保存较好的老式相机，收藏者愿意高价收购。" }
lootUI.itemValues["铂金打火机"] = { value = 6200, desc = "贵金属外壳的高级打火机，小巧且便于交易。" }
lootUI.itemValues["高级太阳镜"] = { value = 5200, desc = "耐用的偏光太阳镜，荒野行动中很实用。" }
lootUI.itemValues["古董指南针"] = { value = 7800, desc = "黄铜古董指南针，既能使用也有收藏价值。" }
lootUI.itemValues["稀有咖啡豆"] = { value = 4300, desc = "保存完好的稀有咖啡豆，末世据点里很受欢迎。" }
lootUI.itemValues["收藏金币"] = { value = 21000, desc = "精制收藏金币，重量小、价值稳定。" }
lootUI.itemValues["红宝石戒指"] = { value = 27000, desc = "红宝石首饰，体积小但交易价值很高。" }
lootUI.itemValues["显卡"] = { value = 260000, desc = "末世中极其罕见的顶级运算核心，目前价值最高的电子物资。" }
lootUI.itemValues["黄金半身像"] = { value = 240000, desc = "纯金铸造的古罗马哲人胸像，工艺精湛，收藏价值极高。" }
lootUI.itemValues["军用加固笔记本"] = { value = 220000, desc = "带加密模块的军用加固终端，保存着高价值战术资料。" }

-- 原创高价值搜打撤物资，覆盖医疗研究、军用电子、贵金属和收藏品。
ITEM_SIZES["机密生物样本"] = {2, 2}
ITEM_SIZES["军用热成像仪"] = {2, 2}
ITEM_SIZES["黄金纪念怀表"] = {1, 1}
ITEM_SIZES["稀有邮票册"] = {2, 2}
ITEM_SIZES["高纯度钯金块"] = {2, 1}
ITEM_SIZES["加密无人机核心"] = {2, 2}
ITEM_SIZES["精密光学模组"] = {2, 1}
ITEM_SIZES["绝版游戏卡带"] = {1, 1}
ITEM_SIZES["名厂机械腕表"] = {1, 1}
ITEM_SIZES["航空级控制芯片"] = {1, 1}

ITEM_RARITY["机密生物样本"] = "red"
ITEM_RARITY["军用热成像仪"] = "pink"
ITEM_RARITY["黄金纪念怀表"] = "gold"
ITEM_RARITY["稀有邮票册"] = "purple"
ITEM_RARITY["高纯度钯金块"] = "red"
ITEM_RARITY["加密无人机核心"] = "red"
ITEM_RARITY["精密光学模组"] = "pink"
ITEM_RARITY["绝版游戏卡带"] = "purple"
ITEM_RARITY["名厂机械腕表"] = "gold"
ITEM_RARITY["航空级控制芯片"] = "pink"

lootUI.itemValues["机密生物样本"] = { value = 185000, desc = "病毒研究设施遗留的密封样本，科研组织愿意付出极高代价。" }
lootUI.itemValues["军用热成像仪"] = { value = 68000, desc = "可穿透黑暗与烟尘观察热源的军用光学设备。" }
lootUI.itemValues["黄金纪念怀表"] = { value = 52000, desc = "保存完整的黄金机械怀表，兼具贵金属与收藏价值。" }
lootUI.itemValues["稀有邮票册"] = { value = 36000, desc = "收录灾变前罕见邮票的收藏册，品相难得。" }
lootUI.itemValues["高纯度钯金块"] = { value = 145000, desc = "工业与精密设备都急需的高纯度贵金属。" }
lootUI.itemValues["加密无人机核心"] = { value = 210000, desc = "军用无人机的加密飞控核心，包含高价值导航模块。" }
lootUI.itemValues["精密光学模组"] = { value = 74000, desc = "用于侦察设备的高精度多层光学组件。" }
lootUI.itemValues["绝版游戏卡带"] = { value = 28000, desc = "灾变前限量发行的收藏卡带，保存状态良好。" }
lootUI.itemValues["名厂机械腕表"] = { value = 88000, desc = "无品牌标识但工艺顶级的精密机械腕表。" }
lootUI.itemValues["航空级控制芯片"] = { value = 96000, desc = "耐高温抗震的航空控制芯片，几乎无法再生产。" }

ITEM_RARITY["香槟酒"] = "red"
ITEM_RARITY["高级香烟"] = "blue"
ITEM_RARITY["名贵香水"] = "purple"

lootUI.itemValues["香槟酒"] = { value = 48000, desc = "灾变前限量收藏香槟，瓶身工艺和酒液保存状态都极其稀有。" }
lootUI.itemValues["高级香烟"] = { value = 4800, desc = "末世前的高档香烟，数量稀少，可在据点换取物资。" }
lootUI.itemValues["名贵香水"] = { value = 9200, desc = "保存完好的名贵香水，体积小，适合高价交易。" }

-- 让住宅家具和商店柜台有机会产出酒类、香烟、香水等高价值物品。
table.insert(lootUI.lootPools.general, "香槟酒")
table.insert(lootUI.lootPools.general, "高级香烟")
table.insert(lootUI.lootPools.general, "名贵香水")
table.insert(lootUI.lootPools.valuables, "香槟酒")
table.insert(lootUI.lootPools.valuables, "高级香烟")
table.insert(lootUI.lootPools.valuables, "名贵香水")
table.insert(lootUI.lootPools.wardrobe, "香槟酒")
table.insert(lootUI.lootPools.wardrobe, "高级香烟")
table.insert(lootUI.lootPools.wardrobe, "名贵香水")
table.insert(lootUI.lootPools.drawer, "香槟酒")
table.insert(lootUI.lootPools.drawer, "高级香烟")
table.insert(lootUI.lootPools.drawer, "名贵香水")
table.insert(lootUI.lootPools.electronics, "高级香烟")
table.insert(lootUI.lootPools.supermarket, "香槟酒")
table.insert(lootUI.lootPools.supermarket, "高级香烟")
table.insert(lootUI.lootPools.general, "加密硬盘")
table.insert(lootUI.lootPools.general, "军用望远镜")
table.insert(lootUI.lootPools.general, "古董相机")
table.insert(lootUI.lootPools.general, "高级太阳镜")
table.insert(lootUI.lootPools.general, "古董指南针")
table.insert(lootUI.lootPools.general, "稀有咖啡豆")
table.insert(lootUI.lootPools.general, "收藏金币")
table.insert(lootUI.lootPools.general, "红宝石戒指")
table.insert(lootUI.lootPools.valuables, "加密硬盘")
table.insert(lootUI.lootPools.valuables, "军用望远镜")
table.insert(lootUI.lootPools.valuables, "卫星电话")
table.insert(lootUI.lootPools.valuables, "古董相机")
table.insert(lootUI.lootPools.valuables, "收藏金币")
table.insert(lootUI.lootPools.valuables, "红宝石戒指")
table.insert(lootUI.lootPools.valuables, "显卡")
table.insert(lootUI.lootPools.valuables, "黄金半身像")
table.insert(lootUI.lootPools.valuables, "军用加固笔记本")
table.insert(lootUI.lootPools.safe, "显卡")
table.insert(lootUI.lootPools.safe, "黄金半身像")
table.insert(lootUI.lootPools.safe, "军用加固笔记本")
table.insert(lootUI.lootPools.electronics, "显卡")
table.insert(lootUI.lootPools.electronics, "军用加固笔记本")
table.insert(lootUI.lootPools.wardrobe, "高级太阳镜")
table.insert(lootUI.lootPools.wardrobe, "铂金打火机")
table.insert(lootUI.lootPools.wardrobe, "红宝石戒指")
table.insert(lootUI.lootPools.drawer, "铂金打火机")
table.insert(lootUI.lootPools.drawer, "古董指南针")
table.insert(lootUI.lootPools.drawer, "收藏金币")
table.insert(lootUI.lootPools.electronics, "加密硬盘")
table.insert(lootUI.lootPools.electronics, "卫星电话")
table.insert(lootUI.lootPools.electronics, "古董相机")
table.insert(lootUI.lootPools.supermarket, "稀有咖啡豆")
table.insert(lootUI.lootPools.supermarket, "收藏金币")
table.insert(lootUI.lootPools.tools, "军用望远镜")
table.insert(lootUI.lootPools.tools, "古董指南针")

lootUI.lootPools.premium = {
    "加密硬盘", "卫星电话", "古董相机", "收藏金币", "红宝石戒指",
    "军用热成像仪", "黄金纪念怀表", "稀有邮票册", "精密光学模组",
    "绝版游戏卡带", "名厂机械腕表", "航空级控制芯片",
}
lootUI.lootPools.topTier = {
    "显卡", "黄金半身像", "军用加固笔记本", "机密生物样本", "高纯度钯金块", "加密无人机核心",
}

function lootUI.ConfigurePremiumPools()
    for _, itemName in ipairs(lootUI.lootPools.premium) do
        lootUI.AddLootPoolItemOnce(lootUI.lootPools.valuables, itemName)
    end
    for _, itemName in ipairs(lootUI.lootPools.topTier) do
        lootUI.AddLootPoolItemOnce(lootUI.lootPools.safe, itemName)
    end
    for _, itemName in ipairs({
        "军用热成像仪", "加密无人机核心", "精密光学模组", "航空级控制芯片",
    }) do
        lootUI.AddLootPoolItemOnce(lootUI.lootPools.electronics, itemName)
    end
    for _, itemName in ipairs({
        "黄金纪念怀表", "稀有邮票册", "绝版游戏卡带", "名厂机械腕表",
    }) do
        lootUI.AddLootPoolItemOnce(lootUI.lootPools.wardrobe, itemName)
    end
    for _, itemName in ipairs({ "机密生物样本", "精密光学模组" }) do
        lootUI.AddLootPoolItemOnce(lootUI.lootPools.medical, itemName)
    end
end

function lootUI.AddLootPoolItemOnce(pool, itemName)
    for _, existingName in ipairs(pool) do
        if existingName == itemName then return end
    end
    table.insert(pool, itemName)
end

lootUI.ConfigurePremiumPools()

-- 新增家具容器不再走 general 默认池，按家具类型给出更有价值的搜刮池。
lootUI.chestLootConfigByName["金属储物柜"] = { pool = "valuables", min = 2, max = 4 }
lootUI.chestLootConfigByName["厨房储物柜"] = { pool = "general", min = 2, max = 4 }
lootUI.chestLootConfigByName["卫生间医疗用品"] = { pool = "medical", min = 2, max = 4 }
lootUI.chestLootConfigByName["工作台"] = { pool = "tools", min = 3, max = 5 }
lootUI.chestLootConfigByName["轮胎架"] = { pool = "tools", min = 2, max = 4 }
lootUI.chestLootConfigByName["玻璃展示柜"] = { pool = "valuables", min = 2, max = 4 }
lootUI.chestLootConfigByName["床头柜"] = { pool = "drawer", min = 2, max = 3 }
lootUI.chestLootConfigByName["工具抽屉柜"] = { pool = "tools", min = 3, max = 5 }
lootUI.chestLootConfigByName["窄边储物柜"] = { pool = "valuables", min = 2, max = 4 }
lootUI.chestLootConfigByName["小型现代保险柜"] = { pool = "safe", min = 2, max = 3 }
lootUI.chestLootConfigByName["小型现代文件保险柜"] = { pool = "valuables", min = 2, max = 4 }
lootUI.chestLootConfigByName["小型现代珠宝保险柜"] = { pool = "safe", min = 2, max = 3 }

-- 第二栋楼家具按用途匹配物资池：生活区、医疗区、商店、办公室和维修间各自产出对应物品。
lootUI.chestLootConfigByName["储物货架"] = { pool = "warehouse", min = 3, max = 5 }
lootUI.chestLootConfigByName["洗衣机"] = { pool = "common", min = 1, max = 3 }
lootUI.chestLootConfigByName["清洁用品柜"] = { pool = "common", min = 2, max = 4 }
lootUI.chestLootConfigByName["洗涤用品架"] = { pool = "common", min = 2, max = 4 }
lootUI.chestLootConfigByName["洗手台柜"] = { pool = "medical", min = 2, max = 4 }
lootUI.chestLootConfigByName["药品柜"] = { pool = "medical", min = 3, max = 5 }
lootUI.chestLootConfigByName["茶几抽屉"] = { pool = "drawer", min = 2, max = 3 }
lootUI.chestLootConfigByName["电视柜"] = { pool = "electronics", min = 2, max = 4 }
lootUI.chestLootConfigByName["书桌抽屉"] = { pool = "electronics", min = 2, max = 4 }
lootUI.chestLootConfigByName["衣物斗柜"] = { pool = "wardrobe", min = 2, max = 4 }
lootUI.chestLootConfigByName["餐桌物资"] = { pool = "food", min = 1, max = 3 }
lootUI.chestLootConfigByName["餐边柜"] = { pool = "food", min = 2, max = 4 }
lootUI.chestLootConfigByName["厨房吊柜"] = { pool = "food", min = 2, max = 4 }
lootUI.chestLootConfigByName["便民店收银台"] = { pool = "valuables", min = 2, max = 3 }
lootUI.chestLootConfigByName["便民店货架"] = { pool = "supermarket", min = 3, max = 5 }
lootUI.chestLootConfigByName["办公桌抽屉"] = { pool = "electronics", min = 2, max = 4 }
lootUI.chestLootConfigByName["文件矮柜"] = { pool = "electronics", min = 2, max = 4 }
lootUI.chestLootConfigByName["文件柜"] = { pool = "electronics", min = 3, max = 5 }
lootUI.chestLootConfigByName["维修工作台"] = { pool = "tools", min = 3, max = 5 }
lootUI.chestLootConfigByName["零件货架"] = { pool = "warehouse", min = 3, max = 5 }
lootUI.chestLootConfigByName["工具箱"] = { pool = "tools", min = 2, max = 4 }

-- 价值分层更明显，但不再让普通物资以压倒性概率淹没搜刮结果。

lootUI.lootRngMod = 2147483647
lootUI.lootWorldSeed = os.time() % lootUI.lootRngMod

function lootUI.CreateLootRng(chestIdx)
    local chest = chestDefs[chestIdx]
    local floorSeed = chest and chest.floor or 0
    local seed = (lootUI.lootWorldSeed + chestIdx * 1009 + floorSeed * 9176) % lootUI.lootRngMod
    if seed <= 0 then seed = 1 end
    return function()
        seed = (seed * 48271) % lootUI.lootRngMod
        return seed / lootUI.lootRngMod
    end
end

function lootUI.RandomInt(rng, minValue, maxValue)
    return minValue + math.floor(rng() * (maxValue - minValue + 1))
end

function lootUI.GetItemValue(itemName)
    local info = lootUI.itemValues[itemName]
    return info and info.value or 1000
end

function lootUI.CalculateTotalIncome()
    local total = 0
    for _, entry in ipairs(playerChestRig) do
        local itemName = type(entry) == "table" and entry.item or entry
        total = total + lootUI.GetItemValue(itemName)
    end
    for _, entry in ipairs(playerPocket) do
        local itemName = type(entry) == "table" and entry.item or entry
        total = total + lootUI.GetItemValue(itemName)
    end
    for _, entry in ipairs(playerInventory) do
        local itemName = type(entry) == "table" and entry.item or entry
        total = total + lootUI.GetItemValue(itemName)
    end
    for _, entry in ipairs(playerSafeBox) do
        local itemName = type(entry) == "table" and entry.item or entry
        total = total + lootUI.GetItemValue(itemName)
    end
    if lootUI.dragging and lootUI.dragFrom ~= "chest" and lootUI.dragItem ~= "" then
        total = total + lootUI.GetItemValue(lootUI.dragItem)
    end
    return total
end

function lootUI.GetLootRollWeight(itemName)
    local value = math.max(1, lootUI.GetItemValue(itemName))
    -- 缩小低价与顶级物资的概率差：电池约 20，顶级物资约 7，不再相差二十多倍。
    return math.max(6, math.floor(85 / (value ^ 0.23)))
end

function lootUI.PickWeightedLootItem(pool, rng, excluded)
    local totalWeight = 0
    for _, itemName in ipairs(pool) do
        if not excluded or not excluded[itemName] then
            totalWeight = totalWeight + lootUI.GetLootRollWeight(itemName)
        end
    end
    if totalWeight <= 0 then return pool[1] end

    local roll = rng() * totalWeight
    local cursor = 0
    for _, itemName in ipairs(pool) do
        if not excluded or not excluded[itemName] then
            cursor = cursor + lootUI.GetLootRollWeight(itemName)
            if roll <= cursor then return itemName end
        end
    end
    return pool[#pool]
end

function lootUI.GetChestGuaranteePool(poolName, rng)
    if poolName == "safe" then
        return rng() < 0.35 and lootUI.lootPools.topTier or lootUI.lootPools.premium
    end
    if poolName == "valuables" or poolName == "electronics" then
        return lootUI.lootPools.premium
    end
    if poolName == "wardrobe" or poolName == "medical" or poolName == "warehouse" then
        return rng() < 0.55 and lootUI.lootPools.premium or nil
    end
    if poolName == "general" or poolName == "supermarket" or poolName == "tools" then
        return rng() < 0.25 and lootUI.lootPools.premium or nil
    end
    return nil
end

function lootUI.GenerateChestLoot(chestIdx)
    local chest = chestDefs[chestIdx]
    if not chest then return {} end

    local config = lootUI.chestLootConfigByName[chest.name] or { pool = "general", min = 2, max = 4 }
    local poolName = config.pool or "general"
    local pool = lootUI.lootPools[poolName] or lootUI.lootPools.general
    local rng = lootUI.CreateLootRng(chestIdx)
    local minCount = config.min or 2
    local maxCount = config.max or minCount
    local count = lootUI.RandomInt(rng, minCount, maxCount)
    local items = {}
    local selected = {}

    -- 价值容器至少给一件稀有物资；普通容器保留小概率惊喜。
    local guaranteePool = lootUI.GetChestGuaranteePool(poolName, rng)
    if guaranteePool and #items < count then
        local guaranteedItem = guaranteePool[lootUI.RandomInt(rng, 1, #guaranteePool)]
        table.insert(items, guaranteedItem)
        selected[guaranteedItem] = true
    end

    while #items < count do
        local itemName = lootUI.PickWeightedLootItem(pool, rng, selected)
        if not itemName then break end
        table.insert(items, itemName)
        selected[itemName] = true
    end

    return items
end

function lootUI.EnsureChestLootGenerated(chestIdx)
    local chest = chestDefs[chestIdx]
    if not chest or chest.generated then return end
    chest.items = lootUI.GenerateChestLoot(chestIdx)
    chest.generated = true
    chest.looted = #chest.items == 0
    print("[Loot] 随机刷新 " .. chest.name .. ": " .. table.concat(chest.items, ", "))
end

function lootUI.IsChestLooted(chestIdx)
    local chest = chestDefs[chestIdx]
    if not chest then return true end
    if not chest.generated then return false end
    return false
end

function lootUI.RestoreDraggedItem()
    local item = lootUI.dragItem
    local fromContainer = lootUI.dragFrom
    if not item or item == "" or not fromContainer or fromContainer == "" then return false end

    local sourceEntry = lootUI.dragSourceEntry or item
    local fromIdx = lootUI.dragFromIdx or 0
    local chest = chestDefs[lootUI.chestIdx]

    if fromContainer == "chest" then
        if chest then
            if lootUI.mode == "loadout" then
                table.insert(
                    chest.items,
                    math.max(1, math.min(fromIdx, #chest.items + 1)),
                    sourceEntry
                )
            elseif fromIdx > 0 and fromIdx <= #chest.items then
                chest.items[fromIdx] = sourceEntry
            else
                table.insert(chest.items, sourceEntry)
            end
        else
            return false
        end
    elseif fromContainer == "rig" then
        table.insert(playerChestRig, math.max(1, math.min(fromIdx, #playerChestRig + 1)), sourceEntry)
    elseif fromContainer == "pocket" then
        table.insert(playerPocket, math.max(1, math.min(fromIdx, #playerPocket + 1)), sourceEntry)
    elseif fromContainer == "inv" then
        table.insert(playerInventory, math.max(1, math.min(fromIdx, #playerInventory + 1)), sourceEntry)
    elseif fromContainer == "safe" then
        table.insert(playerSafeBox, math.max(1, math.min(fromIdx, #playerSafeBox + 1)), sourceEntry)
    elseif fromContainer == "equip_helmet" then
        lootUI.equippedHelmetItem = item
    elseif fromContainer == "equip_armor" then
        lootUI.equippedArmorItem = item
    elseif fromContainer == "equip_rig" then
        lootUI.equippedRigItem = item
    elseif fromContainer == "equip_backpack" then
        lootUI.equippedBackpackItem = item
    elseif fromContainer == "equip_safe_box" then
        lootUI.equippedSafeBoxItem = item
        lootUI.UpdateSafeBoxCapacity(item)
    elseif fromContainer == "equip_gun" then
        lootUI.equippedGunItem = item
    elseif fromContainer == "equip_melee" then
        lootUI.equippedMeleeItem = item
    else
        return false
    end

    print("[Loot] 无效投放，物资已回到原位置: " .. item)
    return true
end

function lootUI.ResetInteractionState()
    if lootUI.dragItem ~= "" and lootUI.dragFrom ~= "" then
        lootUI.RestoreDraggedItem()
    end
    lootUI.dragging = false
    lootUI.dragItem = ""
    lootUI.dragFrom = ""
    lootUI.dragFromIdx = 0
    lootUI.dragSourceEntry = nil
    lootUI.dragSourceCol = nil
    lootUI.dragSourceRow = nil
    lootUI.dragOrientation = "horizontal"
    lootUI.dragInput = ""
    lootUI._touchActive = false
    lootUI._touchDragStarted = false
    lootUI._touchHitItem = false
    lootUI._touchMoved = false
    lootUI._touchLoadoutConfirm = false
    lootUI.lastClickTime = 0
    lootUI.lastClickItem = ""
    lootUI.lastClickContainer = ""
    lootUI.lastClickIdx = 0
    lootUI.closeButtonRect = nil
end

function lootUI.Close()
    lootUI.active = false
    lootUI.ResetInteractionState()
    lootUI.loadoutConfirmRect = nil
    if appState == "loadout" then
        appState = "home"
        HomeUI.Reset()
        print("[Loadout] 取消整备，返回据点")
    elseif inventoryOpenedFromHome then
        inventoryOpenedFromHome = false
        appState = "home"
        HomeUI.Reset()
    end
end

function openShopPanel()
    appState = "shop"
    ShopUI.Open()
    if joystick_ then joystick_._shouldShow = false end
    print("[Shop] 从据点首页进入战术补给商城，余额=" .. lootUI.FormatBitValue(lootUI.bits))
end

blackMarketRates = {
    valuables = 1.12,
    electronics = 1.18,
    medical = 1.05,
    materials = 0.92,
    equipment = 0.96,
    supplies = 1.03,
}
blackMarketRefreshDuration = 30 * 60
blackMarketRefreshRemaining = 18 * 60 + 42
blackMarketRefreshSerial = 0
BLACK_MARKET_RATE_CATEGORIES = {
    "valuables", "electronics", "medical", "materials", "equipment", "supplies",
}
blackMarketReputation = 0
blackMarketActionSerial = 0
blackMarketHistory = {}
blackMarketOrders = {
    {
        id = "offline_server",
        buyer = "灰鸦 / GREY CROW",
        title = "离线服务器",
        description = "从封锁区居民楼带回两块加密硬盘。买家只接收完整且未拆解的存储设备。",
        requirements = { { item = "加密硬盘", count = 2 } },
        reward = 68000,
        reputation = 20,
        accepted = false,
        completed = false,
    },
    {
        id = "field_clinic",
        buyer = "无证医生 / FIELD DOC",
        title = "战地诊所",
        description = "地下诊所急需一批医疗和饮水补给，交付后将开放更稳定的医疗采购渠道。",
        requirements = { { item = "急救包", count = 3 }, { item = "净水", count = 2 } },
        reward = 42000,
        reputation = 15,
        accepted = false,
        completed = false,
    },
    {
        id = "no_questions",
        buyer = "收藏家 K / COLLECTOR K",
        title = "不问来源",
        description = "收藏家正在寻找灾变前的机械腕表，不追问来源，也不接受替代品。",
        requirements = { { item = "名厂机械腕表", count = 1 } },
        reward = 185000,
        reputation = 40,
        accepted = false,
        completed = false,
    },
}
blackMarketMerchantStock = {
    {
        id = "encrypted_drive",
        item = "加密硬盘",
        name = "加密硬盘",
        tag = "电子设备 / 高价收购",
        description = "渡鸦正在回收未拆解的加密存储设备，用于恢复封锁区旧服务器中的实验记录。",
        price = 36000,
        stock = 3,
        maxStock = 3,
    },
    {
        id = "military_laptop",
        item = "军用加固笔记本",
        name = "军用加固笔记本",
        tag = "军用电子 / 稀缺",
        description = "只接收机身完整、接口未被破坏的军用终端，内部数据是否可读不影响结算。",
        price = 310000,
        stock = 1,
        maxStock = 1,
    },
    {
        id = "thermal_scope",
        item = "军用热成像仪",
        name = "军用热成像仪",
        tag = "光学设备 / 紧急需求",
        description = "地下运输队急需夜间侦察设备，渡鸦愿意为完整热成像模组支付额外溢价。",
        price = 145000,
        stock = 2,
        maxStock = 2,
    },
    {
        id = "bio_sample",
        item = "机密生物样本",
        name = "机密生物样本",
        tag = "实验样本 / 高风险",
        description = "来源不明的生物样本必须保持密封。渡鸦不会询问取得过程，但会检查容器完整性。",
        price = 225000,
        stock = 2,
        maxStock = 2,
    },
    {
        id = "vintage_watch",
        item = "名厂机械腕表",
        name = "名厂机械腕表",
        tag = "灾前收藏 / 限量",
        description = "海外收藏家通过渡鸦秘密征集灾变前腕表，只接受原装机械结构完整的藏品。",
        price = 210000,
        stock = 1,
        maxStock = 1,
    },
    {
        id = "control_chip",
        item = "航空级控制芯片",
        name = "航空级控制芯片",
        tag = "精密元件 / 高需求",
        description = "撤离航线维护组需要航空级控制芯片修复导航设备，针脚完整即可成交。",
        price = 125000,
        stock = 2,
        maxStock = 2,
    },
}
blackMarketPerks = {
    tunnel_intel = false,
    lab_keycard = false,
    weapon_insurance = false,
}

BLACK_MARKET_CATEGORY_ITEMS = {
    electronics = {
        ["旧手机"] = true, ["机械键盘"] = true, ["平板电脑"] = true,
        ["加密硬盘"] = true, ["卫星电话"] = true, ["显卡"] = true,
        ["军用加固笔记本"] = true, ["加密无人机核心"] = true,
        ["航空级控制芯片"] = true, ["军用热成像仪"] = true,
    },
    medical = { ["急救包"] = true, ["机密生物样本"] = true },
    materials = {
        ["螺丝刀"] = true, ["电池"] = true, ["胶带"] = true, ["扳手"] = true,
        ["高纯度钯金块"] = true, ["精密光学模组"] = true,
    },
    equipment = {
        ["手枪"] = true, ["散弹枪"] = true, ["棒球棍"] = true,
        ["二级头盔"] = true, ["二级防弹衣"] = true, ["二级胸挂"] = true,
        ["二级背包"] = true, ["二级安全箱"] = true, ["三级安全箱"] = true,
        ["手枪弹药盒"] = true, ["散弹枪弹药包"] = true,
        ["通用战术消音器"] = true,
    },
    supplies = {
        ["罐头"] = true, ["净水"] = true, ["稀有咖啡豆"] = true,
        ["香槟酒"] = true, ["高级香烟"] = true,
    },
}

BlackMarketCloud.VERSION = 1
BlackMarketCloud.LOAD_TIMEOUT = 8.0
BlackMarketCloud.loadStarted = false
BlackMarketCloud.loadComplete = false
BlackMarketCloud.loadElapsed = 0
BlackMarketCloud.dirty = false
BlackMarketCloud.saving = false
BlackMarketCloud.saveDelay = 0
BlackMarketCloud.dirtyReason = ""

function BlackMarketCloud.CloneValue(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do
        result[BlackMarketCloud.CloneValue(key)] = BlackMarketCloud.CloneValue(child)
    end
    return result
end

function BlackMarketCloud.SanitizeWarehouseItems(items)
    local result = {}
    if type(items) ~= "table" then return result end
    for _, entry in ipairs(items) do
        local itemName = type(entry) == "table" and entry.item or entry
        if type(itemName) == "string" and ITEM_SIZES[itemName]
            and not lootUI.IsTakenGridEntry(entry) then
            if type(entry) == "table" then
                local cleaned = { item = itemName }
                if type(entry.col) == "number" then cleaned.col = math.max(1, math.floor(entry.col)) end
                if type(entry.row) == "number" then cleaned.row = math.max(1, math.floor(entry.row)) end
                if entry.orientation == "vertical" then cleaned.orientation = "vertical" end
                result[#result + 1] = cleaned
            else
                result[#result + 1] = itemName
            end
        end
    end
    return result
end

function BlackMarketCloud.BuildSnapshot()
    local warehouse = {}
    for index, tab in ipairs(warehouseTabs or {}) do
        lootUI.CleanupTakenEntries(tab.items)
        warehouse[index] = {
            unlocked = tab.unlocked == true,
            level = math.floor(tonumber(tab.level) or 1),
            cols = math.floor(tonumber(tab.cols) or 8),
            rows = math.floor(tonumber(tab.rows) or 20),
            items = BlackMarketCloud.CloneValue(tab.items or {}),
        }
    end

    local orderStates = {}
    for _, order in ipairs(blackMarketOrders or {}) do
        orderStates[order.id] = {
            accepted = order.accepted == true,
            completed = order.completed == true,
        }
    end

    local merchantStock = {}
    for _, product in ipairs(blackMarketMerchantStock or {}) do
        merchantStock[product.id] = math.floor(tonumber(product.stock) or 0)
    end

    return {
        version = BlackMarketCloud.VERSION,
        bits = math.max(0, math.floor(tonumber(lootUI.bits) or 0)),
        warehouse = warehouse,
        loadout = {
            inventory = BlackMarketCloud.CloneValue(playerInventory),
            chestRig = BlackMarketCloud.CloneValue(playerChestRig),
            pocket = BlackMarketCloud.CloneValue(playerPocket),
            safeBox = BlackMarketCloud.CloneValue(playerSafeBox),
            equipped = {
                helmet = lootUI.equippedHelmetItem,
                armor = lootUI.equippedArmorItem,
                rig = lootUI.equippedRigItem,
                backpack = lootUI.equippedBackpackItem,
                safeBox = lootUI.equippedSafeBoxItem,
                gun = lootUI.equippedGunItem,
                melee = lootUI.equippedMeleeItem,
            },
        },
        blackMarket = {
            reputation = math.max(0, math.floor(tonumber(blackMarketReputation) or 0)),
            actionSerial = math.max(0, math.floor(tonumber(blackMarketActionSerial) or 0)),
            refreshRemaining = math.max(0, tonumber(blackMarketRefreshRemaining) or 0),
            refreshSerial = math.max(0, math.floor(tonumber(blackMarketRefreshSerial) or 0)),
            rates = BlackMarketCloud.CloneValue(blackMarketRates),
            orderStates = orderStates,
            merchantStock = merchantStock,
            perks = BlackMarketCloud.CloneValue(blackMarketPerks),
            history = BlackMarketCloud.CloneValue(blackMarketHistory),
        },
    }
end

function BlackMarketCloud.EnsureShowcaseWarehouseItems()
    local tab = warehouseTabs and warehouseTabs[1]
    if not tab then return end
    local required = { "翡翠原石", "金条", "古董花瓶", "平板电脑" }
    local present = {}
    for _, entry in ipairs(tab.items or {}) do
        local itemName = type(entry) == "table" and entry.item or entry
        present[itemName] = true
    end
    for _, itemName in ipairs(required) do
        if not present[itemName] then
            table.insert(tab.items, itemName)
        end
    end
end

function BlackMarketCloud.ApplySnapshot(snapshot)
    if type(snapshot) ~= "table" then return false end
    local version = math.floor(tonumber(snapshot.version) or 0)
    if version < 1 or version > BlackMarketCloud.VERSION then
        print("[Cloud] 忽略不支持的黑市云档版本: " .. tostring(version))
        return false
    end

    if type(snapshot.bits) == "number" then
        lootUI.bits = math.max(0, math.floor(snapshot.bits))
    end

    if type(snapshot.warehouse) == "table" then
        for index, savedTab in ipairs(snapshot.warehouse) do
            local tab = warehouseTabs and warehouseTabs[index]
            if tab and type(savedTab) == "table" then
                if type(savedTab.unlocked) == "boolean" then tab.unlocked = savedTab.unlocked end
                tab.level = math.max(1, math.min(tab.maxLevel or 3,
                    math.floor(tonumber(savedTab.level) or tab.level or 1)))
                tab.cols = math.max(1, math.floor(tonumber(savedTab.cols) or tab.cols or 8))
                tab.rows = math.max(1, math.floor(tonumber(savedTab.rows) or tab.rows or 20))
                tab.items = BlackMarketCloud.SanitizeWarehouseItems(savedTab.items)
            end
        end
    end

    if type(snapshot.loadout) == "table" then
        playerInventory = BlackMarketCloud.SanitizeWarehouseItems(snapshot.loadout.inventory)
        playerChestRig = BlackMarketCloud.SanitizeWarehouseItems(snapshot.loadout.chestRig)
        playerPocket = BlackMarketCloud.SanitizeWarehouseItems(snapshot.loadout.pocket)
        playerSafeBox = BlackMarketCloud.SanitizeWarehouseItems(snapshot.loadout.safeBox)
        local equipped = snapshot.loadout.equipped
        if type(equipped) == "table" then
            local function validEquipped(itemName)
                return type(itemName) == "string" and ITEM_SIZES[itemName]
                    and itemName or ""
            end
            lootUI.equippedHelmetItem = validEquipped(equipped.helmet)
            lootUI.equippedArmorItem = validEquipped(equipped.armor)
            lootUI.equippedRigItem = validEquipped(equipped.rig)
            lootUI.equippedBackpackItem = validEquipped(equipped.backpack)
            lootUI.equippedSafeBoxItem = validEquipped(equipped.safeBox)
            lootUI.equippedGunItem = validEquipped(equipped.gun)
            lootUI.equippedMeleeItem = validEquipped(equipped.melee)
            lootUI.UpdateSafeBoxCapacity(lootUI.equippedSafeBoxItem)
        end
    end

    local market = snapshot.blackMarket
    if type(market) ~= "table" then return true end
    blackMarketReputation = math.max(0,
        math.floor(tonumber(market.reputation) or blackMarketReputation))
    blackMarketActionSerial = math.max(0,
        math.floor(tonumber(market.actionSerial) or blackMarketActionSerial))
    blackMarketRefreshRemaining = math.max(0.1,
        math.min(blackMarketRefreshDuration,
            tonumber(market.refreshRemaining) or blackMarketRefreshRemaining))
    blackMarketRefreshSerial = math.max(0,
        math.floor(tonumber(market.refreshSerial) or blackMarketRefreshSerial))

    if type(market.rates) == "table" then
        for category in pairs(blackMarketRates) do
            local rate = tonumber(market.rates[category])
            if rate then blackMarketRates[category] = math.max(0.25, math.min(3.0, rate)) end
        end
    end

    if type(market.orderStates) == "table" then
        for _, order in ipairs(blackMarketOrders) do
            local state = market.orderStates[order.id]
            if type(state) == "table" then
                order.accepted = state.accepted == true or state.completed == true
                order.completed = state.completed == true
            end
        end
    end

    if type(market.merchantStock) == "table" then
        for _, product in ipairs(blackMarketMerchantStock) do
            local stock = tonumber(market.merchantStock[product.id])
            if stock then
                product.stock = math.max(0,
                    math.min(product.maxStock or stock, math.floor(stock)))
            end
        end
    end

    if type(market.perks) == "table" then
        for perk in pairs(blackMarketPerks) do
            blackMarketPerks[perk] = market.perks[perk] == true
        end
    end

    if type(market.history) == "table" then
        blackMarketHistory = {}
        for index, entry in ipairs(market.history) do
            if index > 30 then break end
            if type(entry) == "table" then
                blackMarketHistory[#blackMarketHistory + 1] = {
                    action = math.max(0, math.floor(tonumber(entry.action) or 0)),
                    description = tostring(entry.description or "黑市交易"):sub(1, 180),
                    amount = math.floor(tonumber(entry.amount) or 0),
                    balance = math.max(0, math.floor(tonumber(entry.balance) or 0)),
                    time = type(entry.time) == "string" and entry.time:sub(1, 40) or nil,
                }
            end
        end
    end
    return true
end

function BlackMarketCloud.MarkDirty(reason, immediate)
    if not BlackMarketCloud.IsAvailable() then return end
    BlackMarketCloud.dirty = true
    BlackMarketCloud.dirtyReason = reason or "state_changed"
    BlackMarketCloud.saveDelay = immediate and 0 or 0.8
end

function BlackMarketCloud.Flush()
    if not BlackMarketCloud.dirty or BlackMarketCloud.saving
        or not BlackMarketCloud.IsAvailable() then return end
    BlackMarketCloud.dirty = false
    BlackMarketCloud.saving = true
    local reason = BlackMarketCloud.dirtyReason ~= ""
        and BlackMarketCloud.dirtyReason or "checkpoint"
    local snapshot = BlackMarketCloud.BuildSnapshot()
    BlackMarketCloud.Save(snapshot, function(success, status, detail)
        BlackMarketCloud.saving = false
        if success then
            print("[Cloud] 黑市档案保存成功: " .. reason)
            if BlackMarketCloud.dirty then BlackMarketCloud.saveDelay = 0 end
        else
            BlackMarketCloud.dirty = true
            BlackMarketCloud.saveDelay = 5.0
            print("[Cloud] 黑市档案保存失败: " .. tostring(status)
                .. " " .. tostring(detail or ""))
        end
    end)
end

function BlackMarketCloud.BeginLoad()
    if BlackMarketCloud.loadStarted then return end
    BlackMarketCloud.loadStarted = true
    BlackMarketCloud.loadElapsed = 0
    loadStatusText = "正在同步黑市档案..."
    print("[Cloud] 开始读取黑市档案")
    local settled = false
    local ok, reason = pcall(function()
        BlackMarketCloud.Load(function(snapshot, status, detail)
            if settled or BlackMarketCloud.loadComplete then return end
            settled = true
            if snapshot and BlackMarketCloud.ApplySnapshot(snapshot) then
                BlackMarketCloud.EnsureShowcaseWarehouseItems()
                print("[Cloud] 黑市档案读取成功，版本=" .. tostring(snapshot.version))
            elseif status == "empty" then
                print("[Cloud] 未找到黑市云档，使用默认档案")
                BlackMarketCloud.MarkDirty("create_profile", true)
            else
                print("[Cloud] 黑市档案读取失败，使用默认档案: "
                    .. tostring(status) .. " " .. tostring(detail or ""))
            end
            BlackMarketCloud.loadComplete = true
            loadStatusText = "加载完成"
        end)
    end)
    if not ok then
        BlackMarketCloud.loadComplete = true
        loadStatusText = "加载完成"
        print("[Cloud] 黑市档案读取异常，使用默认档案: " .. tostring(reason))
    end
end

function updateBlackMarketRefresh(dt)
    local elapsed = math.max(0, tonumber(dt) or 0)
    blackMarketRefreshRemaining = blackMarketRefreshRemaining - elapsed
    blackMarketRefreshCloudCheckpoint = (blackMarketRefreshCloudCheckpoint or 30) - elapsed

    if blackMarketRefreshRemaining <= 0 then
        blackMarketRefreshSerial = blackMarketRefreshSerial + 1
        local categoryIndex = 0
        for _, category in ipairs(BLACK_MARKET_RATE_CATEGORIES) do
            categoryIndex = categoryIndex + 1
            local wave = math.sin(blackMarketRefreshSerial * 1.73 + categoryIndex * 2.41)
            local fine = math.sin(blackMarketRefreshSerial * 0.61 + categoryIndex * 4.17) * 0.035
            blackMarketRates[category] = math.max(0.78,
                math.min(1.24, 1.0 + wave * 0.16 + fine))
        end
        blackMarketRefreshRemaining = blackMarketRefreshDuration
        blackMarketRefreshCloudCheckpoint = 30
        BlackMarketCloud.MarkDirty("market_refresh", true)
        print("[BlackMarket] 行情已刷新，轮次=" .. tostring(blackMarketRefreshSerial))
    elseif blackMarketRefreshCloudCheckpoint <= 0 then
        blackMarketRefreshCloudCheckpoint = 30
        BlackMarketCloud.MarkDirty("market_timer", false)
    end
end

function getBlackMarketCategory(itemName)
    for category, items in pairs(BLACK_MARKET_CATEGORY_ITEMS) do
        if items[itemName] then return category end
    end
    return "valuables"
end

function addBlackMarketHistory(description, amount)
    blackMarketActionSerial = blackMarketActionSerial + 1
    table.insert(blackMarketHistory, 1, {
        action = blackMarketActionSerial,
        description = description,
        amount = amount,
        balance = lootUI.bits,
    })
    while #blackMarketHistory > 30 do table.remove(blackMarketHistory) end
end

function openBlackMarketPanel()
    lootUI.CleanupTakenEntries(warehouseTabs[1].items)
    appState = "blackmarket"
    BlackMarketUI.Open()
    if joystick_ then joystick_._shouldShow = false end
    print("[BlackMarket] 从据点首页进入交易终端，余额=" .. lootUI.FormatBitValue(lootUI.bits))
end

function getWarehouseUsedCells(tab)
    local usedCells = 0
    for _, entry in ipairs(tab.items or {}) do
        local itemName = type(entry) == "table" and entry.item or entry
        local size = ITEM_SIZES[itemName] or { 1, 1 }
        usedCells = usedCells + size[1] * size[2]
    end
    return usedCells
end

function handleShopAction(action)
    if not action then return end
    if action == "back" then
        appState = "home"
        HomeUI.Reset()
        print("[Shop] 返回据点首页")
        return
    end

    local productId = action:match("^purchase:(.+)$")
    if not productId then return end
    local product = ShopUI.GetProduct(productId)
    if not product then
        ShopUI.SetNotice("商品信息异常，请重新选择", false)
        print("[Shop] ERROR: 未找到商品 " .. tostring(productId))
        return
    end
    if lootUI.bits < product.price then
        ShopUI.SetNotice("比特不足，无法购买 " .. product.shortName, false)
        print("[Shop] 购买失败，余额不足: 商品=" .. product.item
            .. " 价格=" .. tostring(product.price) .. " 余额=" .. tostring(lootUI.bits))
        return
    end

    local warehouse = warehouseTabs[1]
    local size = ITEM_SIZES[product.item] or { 1, 1 }
    local capacity = (warehouse.cols or 8) * (warehouse.rows or 20)
    if getWarehouseUsedCells(warehouse) + size[1] * size[2] > capacity then
        ShopUI.SetNotice("一号仓库空间不足，请先整理仓库", false)
        print("[Shop] 购买失败，一号仓库空间不足: " .. product.item)
        return
    end

    lootUI.bits = lootUI.bits - product.price
    table.insert(warehouse.items, product.item)
    BlackMarketCloud.MarkDirty("shop_purchase", true)
    ShopUI.SetNotice("购买成功，" .. product.shortName .. " 已送入一号仓库", true)
    print("[Shop] 购买成功: 商品=" .. product.item
        .. " 花费=" .. tostring(product.price)
        .. " 余额=" .. tostring(lootUI.bits)
        .. " 仓库物资数=" .. tostring(#warehouse.items))
end

function findBlackMarketOrder(orderId)
    for _, order in ipairs(blackMarketOrders) do
        if order.id == orderId then return order end
    end
    return nil
end

function findBlackMarketProduct(productId)
    for _, product in ipairs(blackMarketMerchantStock) do
        if product.id == productId then return product end
    end
    return nil
end

function countWarehouseItem(itemName)
    local count = 0
    for _, tab in ipairs(warehouseTabs) do
        for _, entry in ipairs(tab.items or {}) do
            local currentName = type(entry) == "table" and entry.item or entry
            if currentName == itemName then count = count + 1 end
        end
    end
    return count
end

function consumeWarehouseItem(itemName, count)
    local remaining = count
    for _, tab in ipairs(warehouseTabs) do
        for index = #(tab.items or {}), 1, -1 do
            local entry = tab.items[index]
            local currentName = type(entry) == "table" and entry.item or entry
            if currentName == itemName and remaining > 0 then
                table.remove(tab.items, index)
                remaining = remaining - 1
            end
        end
        if remaining <= 0 then break end
    end
    return remaining <= 0
end

function handleBlackMarketSale()
    local selection = BlackMarketUI.GetSellSelection()
    if #selection == 0 then
        BlackMarketUI.SetNotice("请先将仓库物资加入出售清单", false)
        return
    end
    table.sort(selection, function(a, b)
        if a.tabIndex == b.tabIndex then return a.itemIndex > b.itemIndex end
        return a.tabIndex > b.tabIndex
    end)

    local validated = {}
    local total = 0
    for _, selected in ipairs(selection) do
        local tab = warehouseTabs[selected.tabIndex]
        local entry = tab and tab.items and tab.items[selected.itemIndex]
        local itemName = type(entry) == "table" and entry.item or entry
        if itemName then
            local category = getBlackMarketCategory(itemName)
            local rate = blackMarketRates[category] or 1.0
            local payout = math.floor(lootUI.GetItemValue(itemName) * rate)
            table.insert(validated, {
                tab = tab,
                tabIndex = selected.tabIndex,
                itemIndex = selected.itemIndex,
                itemName = itemName,
                payout = payout,
            })
            total = total + payout
        end
    end
    if #validated == 0 then
        BlackMarketUI.ClearSellSelection()
        BlackMarketUI.SetNotice("出售清单已失效，请重新选择", false)
        return
    end

    local fee = math.floor(total * 0.05)
    local payout = math.max(0, total - fee)
    for _, sale in ipairs(validated) do
        table.remove(sale.tab.items, sale.itemIndex)
    end
    lootUI.bits = lootUI.bits + payout
    addBlackMarketHistory("出售 " .. tostring(#validated) .. " 件仓库物资（手续费 "
        .. tostring(fee) .. "）", payout)
    BlackMarketCloud.MarkDirty("black_market_sale", true)
    BlackMarketUI.ClearSellSelection()
    BlackMarketUI.SetNotice("交易完成，扣除手续费后获得 " .. lootUI.FormatBitValue(payout), true)
    print("[BlackMarket] 出售成功: 数量=" .. tostring(#validated)
        .. " 报价=" .. tostring(total) .. " 手续费=" .. tostring(fee)
        .. " 实收=" .. tostring(payout) .. " 余额=" .. tostring(lootUI.bits))
end

function handleBlackMarketOrder(orderId)
    local order = findBlackMarketOrder(orderId)
    if not order then
        BlackMarketUI.SetNotice("订单信息异常，请重新选择", false)
        return
    end
    if order.completed then
        BlackMarketUI.SetNotice("该订单已经完成", false)
        return
    end
    if not order.accepted then
        order.accepted = true
        BlackMarketCloud.MarkDirty("black_market_order_accept", true)
        BlackMarketUI.SetNotice("已接受委托：" .. order.title, true)
        print("[BlackMarket] 接受订单: " .. order.id)
        return
    end

    for _, requirement in ipairs(order.requirements or {}) do
        if countWarehouseItem(requirement.item) < requirement.count then
            BlackMarketUI.SetNotice("交付不足：需要 " .. requirement.item .. " ×" .. tostring(requirement.count), false)
            return
        end
    end
    for _, requirement in ipairs(order.requirements or {}) do
        consumeWarehouseItem(requirement.item, requirement.count)
    end
    order.completed = true
    lootUI.bits = lootUI.bits + order.reward
    blackMarketReputation = blackMarketReputation + (order.reputation or 0)
    addBlackMarketHistory("完成订单：" .. order.title, order.reward)
    BlackMarketCloud.MarkDirty("black_market_order_complete", true)
    BlackMarketUI.SetNotice("订单完成，获得 " .. lootUI.FormatBitValue(order.reward), true)
    print("[BlackMarket] 订单完成: " .. order.id
        .. " 奖励=" .. tostring(order.reward)
        .. " 声望=" .. tostring(blackMarketReputation))
end

function handleBlackMarketMerchantSale(productId)
    local request = findBlackMarketProduct(productId)
    if not request then
        BlackMarketUI.SetNotice("收购信息异常，请重新选择", false)
        return
    end
    if (request.stock or 0) <= 0 then
        BlackMarketUI.SetNotice("该项收购需求已经满足", false)
        return
    end
    if not request.item or countWarehouseItem(request.item) <= 0 then
        BlackMarketUI.SetNotice("仓库中没有可交付的 " .. tostring(request.item or "物资"), false)
        return
    end
    if not consumeWarehouseItem(request.item, 1) then
        BlackMarketUI.SetNotice("交付失败，请检查仓库库存", false)
        return
    end

    local payout = math.max(0, math.floor(tonumber(request.price) or 0))
    request.stock = math.max(0, (request.stock or 0) - 1)
    lootUI.bits = lootUI.bits + payout
    blackMarketReputation = blackMarketReputation + 2
    addBlackMarketHistory("出售给渡鸦：" .. request.item, payout)
    BlackMarketCloud.MarkDirty("black_market_merchant_sale", true)
    BlackMarketUI.SetNotice("渡鸦已收货，获得 " .. lootUI.FormatBitValue(payout), true)
    print("[BlackMarket] 渡鸦收购完成: " .. request.id
        .. " 物资=" .. request.item
        .. " 收入=" .. tostring(payout)
        .. " 剩余需求=" .. tostring(request.stock)
        .. " 余额=" .. tostring(lootUI.bits))
end

function handleBlackMarketAction(action)
    if not action then return end
    action = tostring(action)
    if action == "back" then
        appState = "home"
        HomeUI.Reset()
        print("[BlackMarket] 返回据点首页")
        return
    elseif action == "sell-confirm" then
        handleBlackMarketSale()
        return
    end
    local orderId = action:match("^order%-action:(.+)$")
    if orderId then
        handleBlackMarketOrder(orderId)
        return
    end
    local productId = action:match("^merchant%-sell:(.+)$")
    if productId then handleBlackMarketMerchantSale(productId) end
end

function openLoadoutPanel()
    if not loadoutWarehouseIdx then
        loadoutWarehouseIdx = #chestDefs + 1
        chestDefs[loadoutWarehouseIdx] = {
            floor = -1,
            room = "loadout",
            name = "据点仓库",
            items = warehouseTabs[1].items,
            generated = true,
            looted = false,
        }
    else
        chestDefs[loadoutWarehouseIdx].items = warehouseTabs[1].items
    end
    lootUI.ResetInteractionState()
    lootUI.active = true
    lootUI.mode = "loadout"
    lootUI.chestIdx = loadoutWarehouseIdx
    lootUI.animTimer = 0
    lootUI.selectedSlot = 0
    lootUI.selectedItem = ""
    lootUI.selectedContainer = ""
    lootUI.selectedIdx = 0
    lootUI.loadingElapsed = 999
    lootUI.loadingTimer = 0
    lootUI.loadingDuration = 0
    lootUI.midScrollY = 0
    lootUI.rightScrollY = 0
    lootUI.rightScrollMax = 0
    lootUI.revealedSet = {}
    lootUI.loadoutConfirmRect = nil
    appState = "loadout"
    if joystick_ then joystick_._shouldShow = false end
    print("[Loadout] 打开战前整备，仓库物资: " .. tostring(#warehouseTabs[1].items))
end

function confirmLoadout()
    lootUI.active = false
    lootUI.ResetInteractionState()
    lootUI.loadoutConfirmRect = nil
    appState = "playing"
    if joystick_ then joystick_._shouldShow = true end
    startGameAudio()
    BlackMarketCloud.MarkDirty("loadout_confirm", true)
    print("[Loadout] 确认出战，进入封锁区")
end

function openInventoryPanel()
    local idx = lootUI.inventoryChestIdx
    if not idx then
        idx = #chestDefs + 1
        lootUI.inventoryChestIdx = idx
        chestDefs[idx] = {
            floor = -1,
            room = "ui",
            name = "背包",
            items = {},
            generated = true,
            looted = false,
        }
    end
    lootUI.ResetInteractionState()
    lootUI.active = true
    lootUI.mode = "inventory"
    lootUI.chestIdx = idx
    lootUI.animTimer = 0
    lootUI.selectedSlot = 0
    lootUI.selectedItem = ""
    lootUI.selectedContainer = ""
    lootUI.selectedIdx = 0
    lootUI.loadingElapsed = 999
    lootUI.loadingTimer = 0
    lootUI.loadingDuration = 0
    lootUI.midScrollY = 0
    lootUI.rightScrollY = 0
    lootUI.rightScrollMax = 0
    lootUI.revealedSet = {}
end

function lootUI.IsCloseButtonHit(x, y)
    local closePad = 22
    local r = lootUI.closeButtonRect
    if r then
        return x >= r.x - closePad and x <= r.x + r.w + closePad
           and y >= r.y - closePad and y <= r.y + r.h + closePad
    end
    local closeSize = 48
    local closeX = 8
    local closeY = 5
    return x >= closeX - closePad and x <= closeX + closeSize + closePad
       and y >= closeY - closePad and y <= closeY + closeSize + closePad
end
-- 每帧渲染时更新宝箱屏幕坐标
local chestScreenRects = {}  -- { [idx] = {x, y, w, h} }

-- ── 前置声明（供雨效果使用）──
local csInfo = { sx = -9999, sw = 0, basH = 0, sy = -9999, sh = 0,
    rainLeft = -9999, rainRight = -9999,
    basOverlay = nil, floorOverlays = {} }
local PLAYER_IMG_W, PLAYER_IMG_H = 134, 200  -- 前置声明（原图像素尺寸）

local cameraY = 0   -- 垂直平移偏移（像素，向上为负）—— 提前声明，供雨效果函数引用
CAMERA_BASE_Y = -80 -- 正常构图基准；可见地面由透视路面自身表现
local SCENE_ZOOM = 0.55  -- 场景缩放（提前声明，供雨效果函数引用；移动端在 Start() 中覆盖）

-- ── 雨效果 ──────────────────────────────────────────────────
local RAIN_COUNT = 300         -- 雨滴数量
local raindrops = {}           -- 雨滴粒子表
local SPLASH_MAX = 100         -- 水花池大小
local splashes = {}            -- 水花粒子池（模块加载时即初始化，避免异步加载完成前被帧回调访问）
for i = 1, SPLASH_MAX do
    splashes[i] = { x = 0, y = 0, life = 0, maxLife = 0 }
end
local splashIdx = 0            -- 环形索引
local rainLastCamX = 0         -- 上一帧相机X，用于跟随世界
local RAIN_GRAVITY = 980       -- 重力加速度（像素/秒²，约等于9.8m/s²按100px/m换算）
local RAIN_TERMINAL_V = 900    -- 终端速度（像素/秒，现实中雨滴约7~9m/s）

local function getRainVisibleArea()
    -- 计算当前屏幕可见区域在场景坐标中的范围
    local pivotX = W * 0.5
    local pivotY = H * 0.90  -- GROUND_Y_RATIO（此处硬编码避免前向引用）
    -- X方向：屏幕左边(0)和右边(W)映射到场景坐标
    local visLeft = pivotX - pivotX / SCENE_ZOOM
    local visRight = pivotX + (W - pivotX) / SCENE_ZOOM
    -- Y方向：屏幕顶(0)和底(H)映射到场景坐标（考虑cameraY偏移）
    local visTop = pivotY - cameraY - pivotY / SCENE_ZOOM
    local visBottom = pivotY - cameraY + (H - pivotY) / SCENE_ZOOM
    return visLeft, visRight, visTop, visBottom
end

local function initRain()
    -- 雨滴覆盖整个可见区域（基于缩放后的场景坐标）
    local visLeft, visRight, visTop, visBottom = getRainVisibleArea()
    local margin = 150
    local totalW = (visRight - visLeft) + margin * 2
    local startX = visLeft - margin
    local visH = visBottom - visTop
    for i = 1, RAIN_COUNT do
        raindrops[i] = {
            x = startX + math.random() * totalW,
            y = visTop + math.random() * visH,  -- 初始分布在可见区域内
            speed = RAIN_TERMINAL_V * (0.7 + math.random() * 0.3),
            driftX = (math.random() - 0.5) * 80,
            rx = 1.5 + math.random() * 1.0,
            ry = 2.2 + math.random() * 1.3,
            alpha = 140 + math.random(60),
            delay = 0,  -- 0=活跃; >0=等待重生中（秒）
        }
    end
    -- 初始化水花池
    for i = 1, SPLASH_MAX do
        splashes[i] = { x = 0, y = 0, life = 0, maxLife = 0 }
    end
end

-- 生成一个水花
local function spawnSplash(x, y)
    splashIdx = splashIdx % SPLASH_MAX + 1
    local s = splashes[splashIdx]
    s.x = x
    s.y = y
    s.life = 0.25 + math.random() * 0.1  -- 持续 0.25~0.35 秒
    s.maxLife = s.life
end

local function updateRain(dt)
    local gY = H * 0.90
    -- 计算完整可视区域
    local visLeft, visRight, visTop, visBottom = getRainVisibleArea()
    local margin = 100
    local spawnXLeft = visLeft - margin
    local spawnXWidth = (visRight - visLeft) + margin * 2
    local spawnTopY = visTop - 100  -- 重生位置：可见顶部上方100px
    local visBottomY = visBottom + 50

    -- 建筑屋顶信息
    local mainRoofY = csInfo.sy
    local wMainLeft  = csInfo.worldX or -9999
    local wMainRight = (csInfo.worldX or -9999) + (csInfo.worldW or 0)
    local wRoofDivX  = csInfo.worldRoofDivX or wMainRight  -- 天台隔断世界X（右侧为露天）
    local annexRoofY = csInfo.annexRoofY or 9999
    local wAnnexLeft  = csInfo.worldAnnexLeft or 9999
    local wAnnexRight = csInfo.worldAnnexRight or -9999
    local terraceFloorY = csInfo.terraceFloorY or gY  -- 天台地板Y
    -- 角色碰撞信息
    local plrWorldX = player.x
    local plrFeetY = gY + player.jumpScrY
    local plrH = player.drawH
    local plrW = plrH * (PLAYER_IMG_W / PLAYER_IMG_H)
    local plrWorldLeft = plrWorldX - plrW * 0.5
    local plrWorldRight = plrWorldX + plrW * 0.5
    local plrHeadY = plrFeetY - plrH

    for i = 1, RAIN_COUNT do
        local r = raindrops[i]
        if not r then
            r = {
                x = spawnXLeft + math.random() * spawnXWidth,
                y = spawnTopY,
                speed = RAIN_TERMINAL_V * (0.7 + math.random() * 0.3),
                driftX = (math.random() - 0.5) * 80,
                rx = 1.5 + math.random() * 1.0,
                ry = 2.2 + math.random() * 1.3,
                alpha = 140 + math.random(60),
                delay = 0,
            }
            raindrops[i] = r
        end

        -- 如果在延迟等待中，倒计时后才激活
        if r.delay > 0 then
            r.delay = r.delay - dt
            if r.delay <= 0 then
                -- 延迟结束，从顶部开始下落
                r.delay = 0
                r.x = spawnXLeft + math.random() * spawnXWidth
                r.y = spawnTopY
                r.speed = RAIN_TERMINAL_V * (0.7 + math.random() * 0.3)
                r.driftX = (math.random() - 0.5) * 80
            end
            goto continue
        end

        -- 正常下落
        r.speed = math.min(r.speed + RAIN_GRAVITY * dt, RAIN_TERMINAL_V)
        r.y = r.y + r.speed * dt
        r.x = r.x + r.driftX * dt

        -- X超出范围时回收
        if r.x < spawnXLeft or r.x > spawnXLeft + spawnXWidth then
            r.x = spawnXLeft + math.random() * spawnXWidth
        end

        -- 碰撞检测
        local rwx = r.x + cameraX
        local hitRoof = false
        local roofHitY = 0
        -- 主楼屋顶碰撞（排除天台区域：rwx > wRoofDivX 为露天，雨水可穿过屋顶）
        if rwx > wMainLeft and rwx < wRoofDivX and r.y >= mainRoofY then
            hitRoof = true
            roofHitY = mainRoofY
        elseif rwx >= wRoofDivX and rwx < wMainRight and r.y >= terraceFloorY then
            -- 天台区域：雨水落在天台地板上（不穿过到下层）
            hitRoof = true
            roofHitY = terraceFloorY
        elseif rwx > wAnnexLeft and rwx < wAnnexRight and r.y >= annexRoofY then
            hitRoof = true
            roofHitY = annexRoofY
        end
        local hitPlayer = false
        if not hitRoof and rwx > plrWorldLeft and rwx < plrWorldRight and r.y >= plrHeadY and r.y < plrFeetY then
            hitPlayer = true
        end

        -- 重生逻辑
        local needRespawn = false
        local splashX, splashY = nil, nil

        if hitRoof then
            if math.random() < 0.35 then splashX, splashY = r.x, roofHitY end
            needRespawn = true
        elseif hitPlayer then
            if math.random() < 0.5 then splashX, splashY = r.x, plrHeadY end
            needRespawn = true
        elseif r.y >= gY then
            splashX, splashY = r.x, gY
            needRespawn = true
        elseif r.y >= visBottomY then
            needRespawn = true
        end

        if needRespawn then
            if splashX then spawnSplash(splashX, splashY) end
            -- 关键：不立即重生，加随机延迟（0~1.8秒），打破同步
            r.delay = math.random() * 1.8
            r.y = -99999  -- 移出视野（等待期间不可见）
        end

        ::continue::
    end
    -- 更新水花生命周期
    for i = 1, SPLASH_MAX do
        local s = splashes[i]
        if s.life > 0 then
            s.life = s.life - dt
        end
    end
end

local function drawRain(ctx)
    local gY = H * 0.90
    -- 建筑范围（在建筑X范围内的雨滴只在屋顶以上显示）
    local mainRoofY = csInfo.sy
    local annexRoofY = csInfo.annexRoofY or 9999
    local terraceFloorY = csInfo.terraceFloorY or gY
    -- 使用世界坐标判断是否在建筑内（不受相机影响）
    local wMainLeft  = csInfo.worldX or -9999
    local wMainRight = (csInfo.worldX or -9999) + (csInfo.worldW or 0)
    local wRoofDivX  = csInfo.worldRoofDivX or wMainRight  -- 天台隔断（右侧露天）
    local wAnnexLeft  = csInfo.worldAnnexLeft or 9999
    local wAnnexRight = csInfo.worldAnnexRight or -9999
    -- 获取完整可见区域范围
    local visLeft, visRight, visTop, visBottom = getRainVisibleArea()
    local drawMinY = visTop - 50
    local drawMaxY = visBottom + 50
    for i = 1, RAIN_COUNT do
        local r = raindrops[i]
        if r and r.y > drawMinY and r.y < drawMaxY then
            -- 在建筑范围内的雨滴只画到屋顶/地板线之上
            local draw = true
            local rwx = r.x + cameraX
            if rwx > wMainLeft and rwx < wRoofDivX and r.y > mainRoofY then
                draw = false
            elseif rwx >= wRoofDivX and rwx < wMainRight and r.y > terraceFloorY then
                -- 天台区域：地板以下不显示
                draw = false
            elseif rwx > wAnnexLeft and rwx < wAnnexRight and r.y > annexRoofY then
                draw = false
            end
            if draw then
                nvgBeginPath(ctx)
                nvgEllipse(ctx, r.x, r.y, r.rx, r.ry)
                nvgFillColor(ctx, nvgRGBA(160, 200, 235, r.alpha))
                nvgFill(ctx)
            end
        end
    end
    -- 绘制水花（扩散的小圆环 + 向两边弹开的小水珠）
    for i = 1, SPLASH_MAX do
        local s = splashes[i]
        if s.life > 0 then
            local t = 1.0 - s.life / s.maxLife  -- 0→1 进度
            local alpha = math.floor(180 * (1.0 - t))
            -- 扩散圆环
            local ringR = 2 + t * 6
            nvgBeginPath(ctx)
            nvgEllipse(ctx, s.x, s.y, ringR, ringR * 0.4)
            nvgStrokeColor(ctx, nvgRGBA(180, 210, 240, alpha))
            nvgStrokeWidth(ctx, 1.2)
            nvgStroke(ctx)
            -- 左右弹开的小水珠
            local spread = 3 + t * 8
            local dropR = 1.2 * (1.0 - t)
            local dropY = s.y - t * 4 * (1.0 - t) * 12  -- 抛物线上升后下落
            if dropR > 0.3 then
                nvgBeginPath(ctx)
                nvgCircle(ctx, s.x - spread, dropY, dropR)
                nvgCircle(ctx, s.x + spread, dropY, dropR)
                nvgFillColor(ctx, nvgRGBA(170, 205, 235, alpha))
                nvgFill(ctx)
            end
        end
    end
end

-- 鼠标拖拽平移
local drag = { active = false, cooldown = 0, enabled = false }  -- enabled=false 暂时关闭拖拽
-- cameraY 已在文件顶部声明

local trussImg  = -1   -- 钢桁架贴图 handle
local ceilingLampImg = -1  -- 天花灯贴图 handle
local ladderImg    = -1   -- 地下室入口梯子贴图
local basWinImg    = -1   -- 地下室窗户贴图
local basDoorImg   = -1   -- 铁门正面（第一个外部入口打开后朝向玩家）
local roomDoorImg  = -1   -- 木门正面（室内/地下室/普通入口打开后朝向玩家）
local roomDoorSideImg = -1 -- 木门侧面（室内/地下室/普通入口关闭状态）
local steelDoorImg = -1   -- 铁门侧面（第一个外部入口关闭状态）
local basCrateImg   = -1   -- 地下室木箱
local basBarrelImg  = -1   -- 地下室油桶
local basShelfImg   = -1   -- 地下室铁架子
local basCardboxImg  = -1   -- 地下室废弃纸箱
local basWeaponRackImg = -1  -- 地下室置物架（长包）
local basGearRackImg   = -1  -- 地下室置物架（头盔装备）

local WOOD_DOOR_FRONT_RATIO = 0.82  -- 正面木门贴图透明边距较大，绘制时加宽避免门体显窄

-- 玩家角色图片
local playerImg = -1
PLAYER_IMG_W, PLAYER_IMG_H = 134, 200  -- 原图像素尺寸（宽:高比）
PLAYER_VISUAL_OFFSET_Y = 10 -- 地面角色整体下移，避免视觉上踩到家具

-- 玩家动作序列帧资源集（保留 bat/gun 两套，切换 PLAYER_ANIM_SET 即可）
PLAYER_ANIM_SET = "gun"
PLAYER_ANIM_CONFIGS = {
    bat = {
        frameCount = 145,
        fps = 12,
        attackFps = 24,
        runFps = 18,
        idleStart = 1,
        idleEnd = 8,
        walkStart = 1,
        walkEnd = 56,
        runStart = 57,
        runEnd = 88,
        attackStart = 89,
        attackEnd = 104,
        hurtStart = 111,
        hurtEnd = 117,
        deadStart = 129,
        deadEnd = 145,
        attackDuration = 0.45,
        hurtDuration = 0.6,
        frames = {},
        frameW = 206,
        extendedFrameW = 272,
        extendedFrames = {
            [93] = true,
            [94] = true,
            [95] = true,
            [96] = true,
            [100] = true,
            [101] = true,
        },
        frameH = 256,
        drawH = 168,
        footOffsetY = 22,
        pathPattern = "image/player_action_frames/player_action_%03d.png",
    },
    gun = {
        frameCount = 145,
        fps = 12,
        attackFps = 18,
        runFps = 18,
        idleStart = 1,
        idleEnd = 17,
        walkStart = 21,
        walkEnd = 45,
        runStart = 49,
        runEnd = 61,
        attackStart = 65,
        attackEnd = 81,
        reloadStart = 85,
        reloadEnd = 101,
        hurtStart = 111,
        hurtEnd = 117,
        deadStart = 129,
        deadEnd = 145,
        attackDuration = 0.55,
        reloadDuration = 1.35,
        hurtDuration = 0.6,
        frames = {},
        frameW = 194,
        frameH = 256,
        drawH = 152,
        footOffsetY = 22,
        pathPattern = "image/player_gun_frames/player_gun_%03d.png",
        hurtPathPattern = "image/player_action_frames/player_action_%03d.png",
        hurtFrameW = 206,
        hurtFrameH = 256,
        deadPathPattern = "image/player_action_frames/player_action_%03d.png",
        deadFrameW = 206,
        deadFrameH = 256,
    },
    shotgun = {
        frameCount = 61,
        fps = 12,
        attackFps = 48,
        reloadFps = 28,
        hurtFps = 72,
        runFps = 18,
        idleStart = 1,
        idleEnd = 1,
        walkStart = 1,
        walkEnd = 61,
        runStart = 1,
        runEnd = 61,
        attackStart = 1,
        attackEnd = 61,
        reloadStart = 1,
        reloadEnd = 61,
        hurtStart = 1,
        hurtEnd = 61,
        deadStart = 129,
        deadEnd = 145,
        attackDuration = 1.25,
        reloadDuration = 2.18,
        hurtDuration = 0.85,
        frames = {},
        frameW = 256,
        frameH = 256,
        drawH = 152,
        footOffsetY = 6,
        pathPattern = "image/player_shotgun_frames/walk/walk_%03d.png",
        actionPathPatterns = {
            walk = "image/player_shotgun_frames/walk/walk_%03d.png",
            run = "image/player_shotgun_frames/run/run_%03d.png",
            attack = "image/player_shotgun_frames/attack/attack_%03d.png",
            hurt = "image/player_shotgun_frames/hurt/hurt_%03d.png",
            reload = "image/player_shotgun_frames/reload/reload_%03d.png",
        },
        deadPathPattern = "image/player_action_frames/player_action_%03d.png",
        deadFrameW = 206,
        deadFrameH = 256,
    },
    climb = {
        frameCount = 20,
        fps = 10,
        startFrame = 3,
        endFrame = 20,
        duration = 1.8,
        handContactOffsetY = 170,
        frames = {},
        frameW = 171,
        frameH = 256,
        drawH = 190,
        footOffsetY = 0,
        pathPattern = "image/player_climb_frames/climb_%03d.png",
    },
    unarmedIdle = {
        frameCount = 24,
        fps = 6,
        idleStart = 1,
        idleEnd = 24,
        frames = {},
        frameW = 256,
        frameH = 256,
        drawH = 168,
        footOffsetY = 24,
        pathPattern = "image/player_unarmed_idle_frames/idle_%03d.png",
    },
}
BAT_DEMO_ANIM = PLAYER_ANIM_CONFIGS[PLAYER_ANIM_SET]
CLIMB_ANIM = PLAYER_ANIM_CONFIGS.climb

SHOTGUN_ANIM_LOADED = false
SHOTGUN_ANIM_LOADING = false
SHOTGUN_ANIM_PENDING_SET = nil
BAT_ANIM_LOADED = false
BAT_ANIM_LOADING = false
BAT_ANIM_PENDING_SET = nil

function finishPendingWeaponAnim(targetSet)
    if targetSet == "shotgun" and SHOTGUN_ANIM_LOADED then
        SHOTGUN_ANIM_PENDING_SET = nil
        switchPlayerWeaponAnim("shotgun")
    elseif targetSet == "bat" and BAT_ANIM_LOADED then
        BAT_ANIM_PENDING_SET = nil
        switchPlayerWeaponAnim("bat")
    end
end

function loadBatAnimationFrames()
    local animCfg = PLAYER_ANIM_CONFIGS.bat
    if BAT_ANIM_LOADED then return true end
    if BAT_ANIM_LOADING then return false end
    if not vg then return false end
    BAT_ANIM_LOADING = true
    local uris = {}
    for i = 1, animCfg.frameCount do
        table.insert(uris, string.format(animCfg.pathPattern, i))
    end
    cache:DownloadResources(uris, function()
        animCfg.frames = {}
        local loadedTotal = 0
        for i = 1, animCfg.frameCount do
            local path = string.format(animCfg.pathPattern, i)
            local img = nvgCreateImage(vg, path, 0)
            animCfg.frames[i] = img
            if img > 0 then loadedTotal = loadedTotal + 1 end
        end
        BAT_ANIM_LOADING = false
        BAT_ANIM_LOADED = loadedTotal > 0
        print("[DemoAnim] bat 延迟加载: " .. tostring(loadedTotal) .. "/" .. tostring(animCfg.frameCount))
        finishPendingWeaponAnim("bat")
    end)
    return false
end

function loadShotgunAnimationFrames()
    if SHOTGUN_ANIM_LOADED then return true end
    if SHOTGUN_ANIM_LOADING then return false end
    if not vg then return false end
    local animCfg = PLAYER_ANIM_CONFIGS.shotgun
    if animCfg.actionFrames and #animCfg.frames > 0 then
        SHOTGUN_ANIM_LOADED = true
        return true
    end
    SHOTGUN_ANIM_LOADING = true
    local uris = {}
    for _, pathPattern in pairs(animCfg.actionPathPatterns or {}) do
        for i = 1, animCfg.frameCount do
            table.insert(uris, string.format(pathPattern, i))
        end
    end
    for i = animCfg.deadStart, animCfg.deadEnd do
        table.insert(uris, string.format(animCfg.deadPathPattern, i))
    end
    cache:DownloadResources(uris, function()
        animCfg.frames = {}
        animCfg.actionFrames = {}
        local loadedTotal = 0
        for actionName, pathPattern in pairs(animCfg.actionPathPatterns or {}) do
            animCfg.actionFrames[actionName] = {}
            for i = 1, animCfg.frameCount do
                local path = string.format(pathPattern, i)
                local img = nvgCreateImage(vg, path, 0)
                animCfg.actionFrames[actionName][i] = img
                if img > 0 then loadedTotal = loadedTotal + 1 end
            end
        end
        animCfg.frames = animCfg.actionFrames.walk or {}
        animCfg.deadFrames = PLAYER_ANIM_CONFIGS.gun.deadFrames or {}
        SHOTGUN_ANIM_LOADING = false
        SHOTGUN_ANIM_LOADED = loadedTotal > 0
        print("[DemoAnim] shotgun 延迟加载: " .. tostring(loadedTotal) .. "/305")
        finishPendingWeaponAnim("shotgun")
    end)
    return false
end

function isShotgunAnimSet()
    return PLAYER_ANIM_SET == "shotgun"
end

function isFirearmAnimSet()
    return PLAYER_ANIM_SET == "gun" or PLAYER_ANIM_SET == "shotgun"
end

function switchPlayerWeaponAnim(targetSet)
    if targetSet == PLAYER_ANIM_SET and targetSet ~= "shotgun" then return end
    local cfg = PLAYER_ANIM_CONFIGS[targetSet]
    if not cfg then return end
    local ready = true
    if targetSet == "shotgun" then
        ready = SHOTGUN_ANIM_LOADED or loadShotgunAnimationFrames()
        if not ready then SHOTGUN_ANIM_PENDING_SET = targetSet end
    elseif targetSet == "bat" then
        ready = loadBatAnimationFrames()
        if not ready then BAT_ANIM_PENDING_SET = targetSet end
    end
    if not ready then
        print("[DemoAnim] 等待 " .. targetSet .. " 序列帧下载完成")
        return
    end
    PLAYER_ANIM_SET = targetSet
    BAT_DEMO_ANIM = cfg
    BAT_DEMO_ANIM.currentAnimName = nil
    BAT_DEMO_ANIM.currentAnimStartTime = gameTime
    if player then
        player.actionState = "none"
        player.actionTimer = 0.0
        player.attackQueued = false
        if targetSet == "shotgun" then
            player.maxAmmo = 2
            player.ammo = 2
        elseif targetSet == "gun" then
            player.maxAmmo = 6
            player.ammo = 6
        end
    end
end

function togglePlayerWeaponAnim()
    local hasShotgun = lootUI.equippedGunItem == "散弹枪"
    local hasPistol = lootUI.equippedGunItem == "手枪"
    local hasBat = lootUI.equippedMeleeItem == "棒球棍"
    local targetSet = nil

    -- 按固定顺序循环：手枪 -> 散弹枪 -> 棒球棍 -> 手枪。
    if PLAYER_ANIM_SET == "gun" then
        if hasShotgun then
            targetSet = "shotgun"
        elseif hasBat then
            targetSet = "bat"
        end
    elseif PLAYER_ANIM_SET == "shotgun" then
        if hasBat then
            targetSet = "bat"
        elseif hasPistol then
            targetSet = "gun"
        end
    else
        if hasPistol then
            targetSet = "gun"
        elseif hasShotgun then
            targetSet = "shotgun"
        end
    end

    if targetSet then
        print("[Weapon] 切换 " .. PLAYER_ANIM_SET .. " -> " .. targetSet)
        switchPlayerWeaponAnim(targetSet)
    else
        print("[Weapon] 没有可切换的已装备武器")
    end
end
-- 2D 横版世界坐标系
-- worldX: 左右轴（横向滚动）
-- ============================================================================
local GROUND_Y_RATIO = 0.90   -- 地面Y（屏幕高度比例）
local STREET_LENGTH  = 9300
-- SCENE_ZOOM 已在文件顶部声明（移动端在 Start() 中覆盖）

-- 2D 投影：X轴1:1随相机滚动，Y固定在地面线，scale固定1.0
local function worldToScreen(worldX, _worldDepth)
    local screenY = H * GROUND_Y_RATIO
    local scale   = 1.0
    local screenX = worldX - cameraX
    return screenX, screenY, scale
end

-- 兼容旧代码引用
local GROUND_RATIO = GROUND_Y_RATIO
local SIDEWALK_H   = 28

function getPlayerAnimName()
    if player.actionState == "climb" then return "climb" end
    if player.actionState == "dead" then return "dead" end
    if player.actionState == "hurt" then return "hurt" end
    if player.actionState == "reload" then return "reload" end
    if player.actionState == "attack" then return "attack" end
    if player.isMoving then
        if player.isRunning then return "run" end
        return "walk"
    end
    return "idle"
end

function drawBatDemoAnimation(ctx)
    local animName = getPlayerAnimName()
    local unarmedIdle = animName == "idle"
        and lootUI.equippedGunItem == ""
        and lootUI.equippedMeleeItem == ""
    local demo = player.actionState == "climb" and CLIMB_ANIM
        or (unarmedIdle and PLAYER_ANIM_CONFIGS.unarmedIdle or BAT_DEMO_ANIM)
    if #demo.frames == 0 then return end

    if demo.currentAnimName ~= animName then
        demo.currentAnimName = animName
        demo.currentAnimStartTime = gameTime
    end
    if demo == PLAYER_ANIM_CONFIGS.shotgun then
        demo.currentAnimStartTime = demo.currentAnimStartTime or gameTime
    end
    ---@type number
    local startFrame = demo.idleStart or 1
    ---@type number
    local endFrame = demo.idleEnd or demo.frameCount
    ---@type number
    local fps = demo.fps
    if animName == "climb" then
        startFrame = demo.startFrame or 1
        endFrame = demo.endFrame or demo.frameCount
        fps = demo.fps
    elseif animName == "dead" then
        startFrame = demo.deadStart
        endFrame = demo.deadEnd
    elseif animName == "hurt" then
        if demo.hurtStaticFrame then
            startFrame = demo.hurtStaticFrame
            endFrame = demo.hurtStaticFrame
        else
            startFrame = demo.hurtStart
            endFrame = demo.hurtEnd
            fps = demo.hurtFps or demo.fps
        end
    elseif animName == "reload" and demo.reloadStart then
        startFrame = demo.reloadStart
        endFrame = demo.reloadEnd
        fps = demo.reloadFps or demo.fps
    elseif animName == "attack" then
        startFrame = demo.attackStart
        endFrame = demo.attackEnd
        fps = demo.attackFps
    elseif animName == "run" then
        startFrame = demo.runStart
        endFrame = demo.runEnd
        fps = demo.runFps
    elseif animName == "walk" then
        startFrame = demo.walkStart
        endFrame = demo.walkEnd
    end

    local frameCount = endFrame - startFrame + 1
    local frameIndex = startFrame
    if frameCount > 1 then
        local animTime = gameTime
        if player.actionState == "climb" then
            local climbAge = ladderTransition.animTime or 0
            local climbFrame = math.floor(climbAge * fps) % frameCount
            frameIndex = startFrame + climbFrame
        elseif player.actionState == "attack" then
            animTime = gameTime - (demo.attackStartTime or gameTime)
            frameIndex = startFrame + math.min(frameCount - 1, math.floor(animTime * fps))
        elseif player.actionState == "hurt" then
            animTime = gameTime - (demo.hurtStartTime or gameTime)
            frameIndex = startFrame + math.min(frameCount - 1, math.floor(animTime * fps))
        elseif player.actionState == "reload" then
            animTime = gameTime - (demo.reloadStartTime or gameTime)
            frameIndex = startFrame + math.min(frameCount - 1, math.floor(animTime * fps))
        elseif player.actionState == "dead" then
            animTime = gameTime - (demo.deadStartTime or gameTime)
            frameIndex = startFrame + math.min(frameCount - 1, math.floor(animTime * fps))
        else
            animTime = gameTime - (demo.currentAnimStartTime or gameTime)
            frameIndex = startFrame + (math.floor(animTime * fps) % frameCount)
        end
    end

    local frameTable = demo.frames
    if demo.actionFrames and player.actionState ~= "dead" then
        local actionName = animName
        if actionName == "idle" then
            actionName = "walk"
        end
        frameTable = demo.actionFrames[actionName] or demo.actionFrames.walk or demo.frames
    end
    local img = frameTable[frameIndex]
    if demo.hurtFrames and player.actionState == "hurt" and not demo.actionFrames then
        img = demo.hurtFrames[frameIndex]
    elseif demo.deadFrames and player.actionState == "dead" then
        img = demo.deadFrames[frameIndex]
    end
    if not img or img <= 0 then return end

    local usingAltFrame = (player.actionState == "hurt" and demo.hurtFrames)
        or (player.actionState == "dead" and demo.deadFrames)
    local altFrameW = usingAltFrame and ((player.actionState == "hurt" and demo.hurtFrameW) or demo.deadFrameW) or demo.frameW
    local altFrameH = usingAltFrame and ((player.actionState == "hurt" and demo.hurtFrameH) or demo.deadFrameH) or demo.frameH
    local scale = demo.drawH / altFrameH
    ---@type number
    local framePixelW = (demo.extendedFrames and demo.extendedFrames[frameIndex] and not usingAltFrame)
        and (demo.extendedFrameW or demo.frameW)
        or altFrameW
    local drawW = framePixelW * scale
    local drawH = altFrameH * scale
    local baseX = player.x - cameraX
    local visualOffsetY = player.actionState == "climb" and 0 or PLAYER_VISUAL_OFFSET_Y
    local baseY = H * GROUND_Y_RATIO + player.jumpScrY
        + (demo.footOffsetY or 0) + visualOffsetY
    -- 扩展帧只增加右侧画布，角色锚点仍沿用原 834px 画布中心，避免攻击时角色跳位。
    local left = baseX - demo.frameW * scale * 0.5
    local top = baseY - drawH

    nvgSave(ctx)
    if player.actionState == "hurt" and demo.hurtStaticFrame then
        local hurtAge = gameTime - (demo.hurtStartTime or gameTime)
        local hurtT = math.min(1.0, hurtAge / math.max(0.01, demo.hurtDuration or 0.32))
        local dir = player.facingRight and -1 or 1
        local recoil = (1.0 - hurtT) * 13
        local shake = math.sin(hurtAge * 88.0) * (1.0 - hurtT) * 4
        nvgTranslate(ctx, dir * recoil + shake, 0)
        nvgTranslate(ctx, baseX, baseY)
        nvgRotate(ctx, dir * -0.10 * (1.0 - hurtT))
        nvgTranslate(ctx, -baseX, -baseY)
    end
    if not player.facingRight then
        nvgTranslate(ctx, baseX, 0)
        nvgScale(ctx, -1, 1)
        nvgTranslate(ctx, -baseX, 0)
    end

    local finalTint = player.overlayTint or 1.0
    if finalTint >= 1.0 then finalTint = 0.55 end
    local tint = math.floor(255 * finalTint)
    local tintColor = nvgRGBA(tint, tint, tint, 255)
    if (player.hitFlashTimer or 0) > 0 then
        if player.actionState == "hurt" and demo.hurtStaticFrame then
            local pulse = math.sin(gameTime * 90.0) > 0 and 255 or 210
            tintColor = nvgRGBA(255, pulse, pulse, 255)
        else
            tintColor = nvgRGBA(255, 105, 105, 255)
        end
    end
    local paint = nvgImagePatternTinted(ctx, left, top, drawW, drawH, 0, img, tintColor)
    nvgBeginPath(ctx)
    nvgRect(ctx, left, top, drawW, drawH)
    nvgFillPaint(ctx, paint)
    nvgFill(ctx)
    nvgRestore(ctx)
end

function spawnHealingPlusParticles(healAmount)
    if not healAmount or healAmount <= 0 then return end

    local baseY = H * GROUND_Y_RATIO + player.jumpScrY - 72
    local count = math.max(6, math.min(10, 5 + math.floor(healAmount / 5)))
    for i = 1, count do
        local angleOffset = (i - 1) / math.max(1, count - 1) - 0.5
        table.insert(HEALING_PLUS_PARTICLES, {
            x = player.x + angleOffset * 52 + (math.random() - 0.5) * 12,
            y = baseY + (math.random() - 0.5) * 52,
            vx = angleOffset * 10 + (math.random() - 0.5) * 8,
            vy = -(38 + math.random() * 26),
            life = 0.9 + math.random() * 0.45,
            maxLife = 0,
            size = 7 + math.random() * 5,
            delay = (i - 1) * 0.055,
        })
        local particle = HEALING_PLUS_PARTICLES[#HEALING_PLUS_PARTICLES]
        particle.maxLife = particle.life
    end
    print("[HealFX] 生成绿色治疗加号，恢复生命: " .. tostring(healAmount))
end

function drawHealingPlusParticles(ctx)
    for _, particle in ipairs(HEALING_PLUS_PARTICLES) do
        if particle.delay <= 0 then
            local progress = 1.0 - particle.life / particle.maxLife
            local alpha = math.floor(255 * math.max(0, math.min(1, particle.life / 0.35)))
            local scale = 0.72 + math.sin(math.min(1, progress) * math.pi) * 0.34
            local size = particle.size * scale
            local x = particle.x - cameraX
            local y = particle.y

            nvgBeginPath(ctx)
            nvgRoundedRect(ctx, x - size * 0.22, y - size, size * 0.44, size * 2, size * 0.18)
            nvgRoundedRect(ctx, x - size, y - size * 0.22, size * 2, size * 0.44, size * 0.18)
            nvgFillColor(ctx, nvgRGBA(72, 255, 126, alpha))
            nvgFill(ctx)

            nvgBeginPath(ctx)
            nvgRoundedRect(ctx, x - size * 0.22, y - size, size * 0.44, size * 2, size * 0.18)
            nvgRoundedRect(ctx, x - size, y - size * 0.22, size * 2, size * 0.44, size * 0.18)
            nvgStrokeColor(ctx, nvgRGBA(205, 255, 218, math.floor(alpha * 0.82)))
            nvgStrokeWidth(ctx, 1.2)
            nvgStroke(ctx)
        end
    end
end

-- 工具函数（需在丧尸系统之前定义）
local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function rgba(c, a)
    return nvgRGBA(c[1], c[2], c[3], a or c[4] or 255)
end

-- 环境粒子
local dustParticles = {}
local fallingDebris = {}

-- ============================================================================
-- 丧尸系统
-- ============================================================================
local zombies = {}
local bloodParticles = {}  -- 血液粒子
HEALING_PLUS_PARTICLES = {}
WALL_BLOOD_SPLATS = {}
ZOMBIE_GIBS = {}
ZOMBIE_GIB_IMAGES = {}
ZOMBIE_GIB_BASE_SIZES = { 84, 116, 82, 88, 74 }
SCREEN_SHAKE_TIME = 0
SCREEN_SHAKE_POWER = 0
GUN_SCREEN_FLASH = nil
SHOTGUN_MUZZLE_FX = nil
PISTOL_MUZZLE_FX = nil
SHOTGUN_IMPACT_RINGS = {}
ZOMBIE_ANIM_CONFIG = {
    frameW = 192,
    frameH = 256,
    drawH = 132,
    footOffsetY = 6,
    actions = {
        idle = {
            frameCount = 12,
            fps = 6,
            loop = true,
            frames = {},
            pathPattern = "image/zombie_sequence_frames/idle/idle_%03d.png",
        },
        run = {
            frameCount = 14,
            fps = 9,
            loop = true,
            frames = {},
            pathPattern = "image/zombie_sequence_frames/run/run_%03d.png",
        },
        attack = {
            frameCount = 10,
            fps = 8,
            loop = false,
            frames = {},
            pathPattern = "image/zombie_sequence_frames/attack/attack_%03d.png",
        },
        hurt = {
            frameCount = 10,
            fps = 8,
            loop = false,
            frames = {},
            pathPattern = "image/zombie_sequence_frames/hurt/hurt_%03d.png",
        },
        dead = {
            frameCount = 12,
            fps = 8,
            loop = false,
            frames = {},
            pathPattern = "image/zombie_sequence_frames/dead/dead_%03d.png",
        },
    },
}
local ZOMBIE_SPAWN_INTERVAL = 1.1
ZOMBIE_SPAWN_VARIANCE = 0.7
ZOMBIE_MAX_ALIVE = 16
ZOMBIE_INITIAL_COUNT = 8
ZOMBIE_DYNAMIC_SPAWN_ENABLED = false
ZOMBIE_PLAYER_SAFE_DISTANCE = 520
ZOMBIE_DOOR_ATTACK_RANGE = 88
ZOMBIE_DOOR_BREAK_HITS = 3
local zombieSpawnTimer = 0.0

-- ============================================================================
-- 子弹系统
-- ============================================================================
local bullets = {}
local BULLET_SPEED    = 1600  -- 子弹速度 (像素/秒)
local BULLET_MAX_DIST = 1100  -- 手枪最大飞行距离
SHOTGUN_MAX_DIST = 180        -- 约一个角色身位，仅极近距离有效
SHOTGUN_SHATTER_DIST = 110    -- 贴脸命中才会将丧尸打碎
local BULLET_DAMAGE   = 1     -- 手枪单发伤害
SHOTGUN_PELLET_COUNT = 8
SHOTGUN_VOLLEY_SPREAD = 0.24
SHOTGUN_PELLET_DAMAGE = 1
local MUZZLE_FLASH_DUR = 0.08 -- 枪口火焰持续时间
PISTOL_FIRE_DELAY = 0.10
SHOTGUN_FIRE_DELAY = 0.50 -- attack_025：双管枪口火焰关键帧
ZOMBIE_GUNSHOT_ALERT_DURATION = 8.0
ZOMBIE_GUNSHOT_ALERT_RANGE = 1300
zombieAlertX = -9999
zombieAlertTime = -9999

-- 待发射队列（延迟射击）
local pendingShots = {}  -- { {timer, dir} ... }

local function spawnBullet(spreadAngle, playSound)
    local dir = player.facingRight and 1 or -1
    -- 使用骨骼追踪的枪口屏幕坐标（muzzleScreenX/Y 在渲染时从 tt_7 骨骼获取）
    -- 注意：muzzleScreenX/Y 是相对 NanoVG 画布的局部坐标
    -- 而子弹系统使用世界坐标（b.x = 世界X，b.y = 相对地面的Y偏移）
    local spawnX, spawnY, angle
    if muzzleBone and (muzzleScreenX ~= 0 or muzzleScreenY ~= 0) then
        -- 从屏幕坐标转回世界坐标（与渲染时 bx = b.x - cameraX 对应）
        spawnX = muzzleScreenX + cameraX
        -- 子弹 Y：渲染时 by = H * GROUND_Y_RATIO + b.y，所以 b.y = screenY - H*GROUND_Y_RATIO
        spawnY = muzzleScreenY - H * GROUND_Y_RATIO
        angle = muzzleAngle
    else
        -- 回退：使用固定偏移（骨骼未就绪时）
    local weaponSet = isFirearmAnimSet()
    local muzzleOffsetX = weaponSet and 48 or 40
    local muzzleOffsetY = weaponSet and (isShotgunAnimSet() and 52 or 58) or (SPINE_DRAW_H * 0.62)
        spawnX = player.x + dir * muzzleOffsetX
        spawnY = player.jumpScrY - muzzleOffsetY
        angle = dir > 0 and 0 or math.pi
    end
    local shotAngle = angle + (spreadAngle or 0)
    if playSound ~= false then
        local isShotgun = isShotgunAnimSet()
        GUN_SCREEN_FLASH = {
            life = isShotgun and 0.11 or 0.07,
            maxLife = isShotgun and 0.11 or 0.07,
            strength = isShotgun and 0.08 or 0.045,
        }
    end
    if not isShotgunAnimSet() then
        PISTOL_MUZZLE_FX = {
            x = spawnX,
            y = spawnY,
            angle = shotAngle,
            life = 0.075,
            maxLife = 0.075,
        }
    end
    table.insert(bullets, {
        x = spawnX,
        y = spawnY,
        vx = math.cos(shotAngle) * BULLET_SPEED,
        vy = math.sin(shotAngle) * BULLET_SPEED,
        dir = dir,
        dist = 0,
        alive = true,
        muzzleTimer = MUZZLE_FLASH_DUR,
        shotgunPellet = isShotgunAnimSet(),
        damage = isShotgunAnimSet() and SHOTGUN_PELLET_DAMAGE or BULLET_DAMAGE,
    })
    zombieAlertX = player.x
    zombieAlertTime = gameTime
    -- 同一轮散弹只播放一次枪声，避免双弹道叠加成两声。
    if playSound ~= false then
        local soundPath = isShotgunAnimSet()
            and "audio/sfx/shotgun_blast.ogg"
            or "audio/sfx/gunshot.ogg"
        local gunshotSound = cache:GetResource("Sound", soundPath)
        if gunshotSound then
            gunshotSound.looped = false
            local sfxNode = audioScene:CreateChild("GunSFX")
            local src = sfxNode:CreateComponent("SoundSource")
            src:Play(gunshotSound)
            src.gain = isShotgunAnimSet() and 2.2 or 3.0
            src.autoRemoveMode = REMOVE_NODE
        end
    end
end

function spawnShotgunVolley()
    local count = math.max(2, SHOTGUN_PELLET_COUNT)
    local dir = player.facingRight and 1 or -1
    SHOTGUN_MUZZLE_FX = {
        x = player.x + dir * 54,
        y = player.jumpScrY - 56,
        dir = dir,
        life = 0.14,
        maxLife = 0.14,
    }
    SCREEN_SHAKE_TIME = 0.12
    SCREEN_SHAKE_POWER = 5
    for i = 1, count do
        local t = (i - 1) / (count - 1)
        local spread = -SHOTGUN_VOLLEY_SPREAD * 0.5 + t * SHOTGUN_VOLLEY_SPREAD
        spawnBullet(spread, i == 1)
    end
end

function spawnShotgunImpact(x, y, dir)
    for i = 1, 10 do
        local angle = (math.random() - 0.5) * 2.2
        local speed = 70 + math.random() * 150
        table.insert(bloodParticles, {
            x = x + math.random(-8, 8),
            y = y + math.random(-18, 12),
            vx = dir * speed * (0.45 + math.random() * 0.55),
            vy = -80 - math.random() * 120 + angle * 20,
            gravity = 360 + math.random() * 180,
            life = 0.22 + math.random() * 0.24,
            alpha = 235,
            size = 1.5 + math.random() * 2.5,
            groundY = H * GROUND_Y_RATIO,
            isShotgunImpact = true,
        })
    end
end

function spawnWallBloodSplat(x, y, dir, strength)
    local relY = y - H * GROUND_Y_RATIO
    local bestWall = nil
    local bestDist = 999999
    for _, wall in ipairs(csColliders.walls) do
        local wallX = dir > 0 and wall.wx1 or wall.wx2
        local distance = math.abs(wallX - x)
        if distance < bestDist and distance < 260
            and relY > wall.relY1 and relY < wall.relY2
        then
            bestWall = wall
            bestDist = distance
        end
    end
    if not bestWall then return end
    local wallX = dir > 0 and bestWall.wx1 or bestWall.wx2
    if #WALL_BLOOD_SPLATS >= 80 then
        table.remove(WALL_BLOOD_SPLATS, 1)
    end
    table.insert(WALL_BLOOD_SPLATS, {
        x = wallX - dir * 0.8,
        y = relY,
        w = 28 + math.random() * 34 + (strength or 0) * 0.5,
        h = 22 + math.random() * 30 + (strength or 0) * 0.35,
        alpha = 205,
        life = 9999,
        drip = math.random() < 0.7,
        dir = dir,
    })
end

function spawnDeathBloodBurst(z, hitY, dir, strength)
    if not z or z.deathBloodSpawned then return end
    z.deathBloodSpawned = true
    local amount = strength or 1
    for i = 1, 18 + math.floor(amount * 8) do
        local speed = 90 + math.random() * (130 + amount * 40)
        table.insert(bloodParticles, {
            x = z.x + math.random(-16, 16),
            y = hitY + math.random(-30, 18),
            vx = dir * speed * (0.45 + math.random() * 0.65),
            vy = -100 - math.random() * (130 + amount * 30),
            gravity = 420 + math.random() * 180,
            life = 0.45 + math.random() * 0.55,
            alpha = 235,
            size = 2 + math.random() * (3 + amount),
            groundY = H * GROUND_Y_RATIO,
        })
    end
    spawnWallBloodSplat(z.x, hitY, dir, amount * 16)
end

function spawnZombieGibs(z, hitY, dir)
    if not z or z.shattered then return end
    z.shattered = true
    z.alive = false
    z.animState = "dead"
    z.deadTimer = 0
    SCREEN_SHAKE_TIME = 0.22
    SCREEN_SHAKE_POWER = 11
    table.insert(SHOTGUN_IMPACT_RINGS, {
        x = z.x,
        y = hitY - 12,
        life = 0.24,
        maxLife = 0.24,
    })
    local centerY = hitY - 12
    spawnDeathBloodBurst(z, centerY, dir, 3)
    local zombieScale = z.sizeJitter or 1.0
    for i = 1, #ZOMBIE_GIB_IMAGES do
        local img = ZOMBIE_GIB_IMAGES[i]
        if img and img > 0 then
            local speed = 150 + math.random() * 220
            local baseSize = ZOMBIE_GIB_BASE_SIZES[i] or 82
            table.insert(ZOMBIE_GIBS, {
                img = img,
                x = z.x + math.random(-14, 14),
                y = centerY + math.random(-36, 18),
                vx = dir * speed * (0.55 + math.random() * 0.55),
                vy = -170 - math.random() * 230,
                gravity = 720,
                rot = (math.random() - 0.5) * 1.8,
                rotSpeed = (math.random() - 0.5) * 12,
                life = 1.0 + math.random() * 0.45,
                size = baseSize * zombieScale * (0.94 + math.random() * 0.12),
            })
        end
    end
    for i = 1, 3 do
        spawnShotgunImpact(z.x + math.random(-12, 12), centerY + math.random(-30, 18), dir)
    end
end

function segmentHitsZombie(oldX, oldY, newX, newY, z, radius)
    local halfW = 34 * (z.sizeJitter or 1.0) + (radius or 0)
    local topY = -148 * (z.sizeJitter or 1.0) - (radius or 0)
    local bottomY = 8 + (radius or 0)
    local minX = z.x - halfW
    local maxX = z.x + halfW
    local dx = newX - oldX
    local dy = newY - oldY

    local tMin = 0.0
    local tMax = 1.0
    if math.abs(dx) < 0.0001 then
        if oldX < minX or oldX > maxX then return false end
    else
        local tx1 = (minX - oldX) / dx
        local tx2 = (maxX - oldX) / dx
        if tx1 > tx2 then tx1, tx2 = tx2, tx1 end
        tMin = math.max(tMin, tx1)
        tMax = math.min(tMax, tx2)
        if tMin > tMax then return false end
    end
    if math.abs(dy) < 0.0001 then
        if oldY < topY or oldY > bottomY then return false end
    else
        local ty1 = (topY - oldY) / dy
        local ty2 = (bottomY - oldY) / dy
        if ty1 > ty2 then ty1, ty2 = ty2, ty1 end
        tMin = math.max(tMin, ty1)
        tMax = math.min(tMax, ty2)
        if tMin > tMax then return false end
    end
    local hitT = math.max(0.0, math.min(1.0, tMin))
    return true, oldY + dy * hitT
end

function spawnBatBloodSplash(x, y, dir)
    local groundY = H * GROUND_Y_RATIO + (player.jumpScrY or 0)
    for i = 1, 18 do
        local speed = 90 + math.random() * 180
        local spread = -0.9 + math.random() * 1.8
        local vx = dir * speed * (0.55 + math.random() * 0.45)
        local vy = -120 - math.random() * 160 + spread * 35
        table.insert(bloodParticles, {
            x = x + math.random(-8, 8),
            y = y + math.random(-12, 10),
            vx = vx,
            vy = vy,
            gravity = 420 + math.random() * 180,
            life = 0.55 + math.random() * 0.45,
            alpha = 230,
            size = 2 + math.random() * 3,
            groundY = groundY,
        })
    end
    for i = 1, 7 do
        table.insert(bloodParticles, {
            x = x + math.random(-10, 10),
            y = y + math.random(-8, 8),
            vx = dir * (30 + math.random() * 80),
            vy = -40 - math.random() * 80,
            gravity = 520,
            life = 0.8 + math.random() * 0.5,
            alpha = 210,
            size = 4 + math.random() * 4,
            groundY = groundY,
        })
    end
end

function requestBatAttack()
    local dir = player.facingRight and 1 or -1
    local range = 130
    local hitAny = false
    for _, z in ipairs(zombies) do
        if z.alive then
            local dx = z.x - player.x
            if dx * dir > 0 and math.abs(dx) <= range then
                z.hitFlash = 0.18
                z.stagger = dir * 55
                z.animState = "hurt"
                z.animStartTime = gameTime
                z.hurtTimer = 0.38
                spawnBatBloodSplash(z.x, H * GROUND_Y_RATIO + player.jumpScrY - 68, dir)
                z.hp = z.hp - 2
                hitAny = true
                if z.hp <= 0 then
                    spawnDeathBloodBurst(z, H * GROUND_Y_RATIO + player.jumpScrY - 68, dir, 1.5)
                    z.alive = false
                    z.animState = "dead"
                    z.animStartTime = gameTime
                    z.deadTimer = 0
                    if not z.deathSoundPlayed then
                        playZombieSound("death")
                        z.deathSoundPlayed = true
                    end
                    if z.spine then
                        local deathAnims = {"dead_1", "dead_2", "dead_3"}
                        z.spine:SetAnimation(0, deathAnims[math.random(#deathAnims)], false)
                    end
                end
            end
        end
    end
    if hitAny then
        print("[Player] 球棍命中丧尸")
    end
    return hitAny
end

local function requestShot()
    local delay = isShotgunAnimSet() and SHOTGUN_FIRE_DELAY or PISTOL_FIRE_DELAY
    table.insert(pendingShots, {
        timer = delay,
        shotgun = isShotgunAnimSet(),
    })
end

local function damagePlayerFromZombie(z)
    if not z or not player or player.actionState == "dead" then return end
    if (player.hitInvincibleTimer or 0) > 0 then return end

    local dir = (player.x >= z.x) and 1 or -1
    player.attackCombo = 0
    player.attackQueued = false
    player.hp = math.max(0, (player.hp or player.maxHp or 100) - 18)
    if player.hp <= 0 then
        player.actionState = "dead"
        player.actionTimer = 99
        BAT_DEMO_ANIM.deadStartTime = gameTime
        player.hitInvincibleTimer = 99
        player.hitFlashTimer = 0.6
    else
        player.actionState = "hurt"
        player.actionTimer = BAT_DEMO_ANIM.hurtDuration or 0.55
        BAT_DEMO_ANIM.hurtStartTime = gameTime
        player.hitInvincibleTimer = 0.75
        player.hitFlashTimer = 0.28
    end
    player.x = clamp(player.x + dir * 22, 50, STREET_LENGTH - 50)
    spawnBatBloodSplash(player.x, H * GROUND_Y_RATIO + player.jumpScrY - 62, dir)
end

function playHomeUISound(action)
    if not audioScene then return end
    local paths = {
        equip = "audio/sfx/ui_loadout_open.mp3",
        deploy = "audio/sfx/ui_deploy_confirm.mp3",
        warehouse = "audio/sfx/ui_warehouse_open.mp3",
        tab = "audio/sfx/ui_tactical_tab_click.mp3",
    }
    local sound = cache:GetResource("Sound", paths[action] or paths.tab)
    if not sound then return end
    sound.looped = false
    local node = audioScene:CreateChild("HomeUISFX")
    local source = node:CreateComponent("SoundSource")
    source.soundType = SOUND_EFFECT
    source.gain = 1.0
    source:Play(sound)
    source.autoRemoveMode = REMOVE_NODE
end

function playWeaponPlaceSound()
    if not audioScene then return end
    local sound = cache:GetResource(
        "Sound", "audio/sfx/weapon_place_click_short.mp3")
    if not sound then return end
    sound.looped = false
    local node = audioScene:CreateChild("WeaponPlaceSFX")
    local source = node:CreateComponent("SoundSource")
    source.soundType = SOUND_EFFECT
    source.gain = 1.55
    source:Play(sound)
    source.autoRemoveMode = REMOVE_NODE
end

local function playBatAttackSound(hit)
    if not audioScene then return end
    local path = hit and "audio/sfx/wooden_bat_attack.ogg" or "audio/sfx/wooden_bat_swing_miss.ogg"
    local sound = cache:GetResource("Sound", path)
    if not sound then return end
    sound.looped = false
    local sfxNode = audioScene:CreateChild(hit and "BatHitSFX" or "BatMissSFX")
    local src = sfxNode:CreateComponent("SoundSource")
    src:Play(sound)
    src.gain = hit and 1.15 or 1.0
    src.autoRemoveMode = REMOVE_NODE
end

local function playPistolReloadSound()
    if not audioScene then return end
    local soundPath = isShotgunAnimSet() and "audio/sfx/shotgun_reload.mp3" or "audio/sfx/pistol_reload.ogg"
    local sound = cache:GetResource("Sound", soundPath)
    if not sound then return end
    sound.looped = false
    local sfxNode = audioScene:CreateChild("PistolReloadSFX")
    local src = sfxNode:CreateComponent("SoundSource")
    src:Play(sound)
    src.gain = 1.0
    src.autoRemoveMode = REMOVE_NODE
end

local function playDoorSound()
    if not audioScene then return end
    local sound = doorSoundRes or cache:GetResource("Sound", "audio/sfx/door_open_creak.ogg")
    if not sound then return end
    doorSoundRes = sound
    sound.looped = false
    local sfxNode = audioScene:CreateChild("DoorSFX")
    local src = sfxNode:CreateComponent("SoundSource")
    src:Play(sound)
    src.gain = 1.1
    src.autoRemoveMode = REMOVE_NODE
end

local function playLightSwitchSound()
    if not audioScene then return end
    local sound = lightSwitchSoundRes or cache:GetResource("Sound", "audio/sfx/plastic_light_switch_click_soft.ogg")
    if not sound then return end
    lightSwitchSoundRes = sound
    sound.looped = false
    local sfxNode = audioScene:CreateChild("LightSwitchSFX")
    local src = sfxNode:CreateComponent("SoundSource")
    src:Play(sound)
    src.gain = 0.85
    src.autoRemoveMode = REMOVE_NODE
end

local function playWalkGearSound()
    if not audioScene then return end
    local sound = walkGearSoundRes or cache:GetResource("Sound", "audio/sfx/character_gear_rustle_walk.ogg")
    if not sound then return end
    walkGearSoundRes = sound
    sound.looped = false
    local sfxNode = audioScene:CreateChild("WalkGearSFX")
    local src = sfxNode:CreateComponent("SoundSource")
    src:Play(sound)
    src.gain = player.isRunning and 0.48 or 0.40
    src.autoRemoveMode = REMOVE_NODE
end

playZombieSound = function(kind)
    if not audioScene then return end

    local path = "audio/sfx/zombie_idle_growl.ogg"
    local nodeName = "ZombieGrowlSFX"
    local gain = 0.55
    local sound = nil

    if kind == "attack" then
        path = "audio/sfx/zombie_attack_bite.ogg"
        nodeName = "ZombieAttackSFX"
        gain = 1.15
        sound = zombieAttackSoundRes or cache:GetResource("Sound", path)
        zombieAttackSoundRes = sound
    elseif kind == "death" then
        path = "audio/sfx/zombie_death_groan.ogg"
        nodeName = "ZombieDeathSFX"
        gain = 1.05
        sound = zombieDeathSoundRes or cache:GetResource("Sound", path)
        zombieDeathSoundRes = sound
    else
        sound = zombieGrowlSoundRes or cache:GetResource("Sound", path)
        zombieGrowlSoundRes = sound
    end

    if not sound then return end
    sound.looped = false
    local sfxNode = audioScene:CreateChild(nodeName)
    local src = sfxNode:CreateComponent("SoundSource")
    src:Play(sound)
    src.gain = gain
    src.autoRemoveMode = REMOVE_NODE
end

local function isBulletInOpenDoorGap(wall, bulletY)
    for _, gap in ipairs(wall.gaps or {}) do
        local gapActive = true
        if gap.doorKey then
            local rds = roomDoorStates[gap.doorKey]
            if rds and rds.openProg < 0.5 then
                gapActive = false
            end
        end
        if gapActive and bulletY > gap.y1 and bulletY < gap.y2 then
            return true
        end
    end
    return false
end

local function bulletHitsObstacle(oldX, oldY, newX, newY)
    local minX = math.min(oldX, newX)
    local maxX = math.max(oldX, newX)
    local minY = math.min(oldY, newY)
    local maxY = math.max(oldY, newY)

    for _, wall in ipairs(csColliders.walls) do
        if maxX >= wall.wx1 and minX <= wall.wx2 and maxY >= wall.relY1 and minY <= wall.relY2 then
            local t = 0.0
            if newX ~= oldX then
                local wallX = newX > oldX and wall.wx1 or wall.wx2
                t = (wallX - oldX) / (newX - oldX)
                t = math.max(0.0, math.min(1.0, t))
            end
            local hitY = oldY + (newY - oldY) * t
            if hitY > wall.relY1 and hitY < wall.relY2 and not isBulletInOpenDoorGap(wall, hitY) then
                return true
            end
        end
    end
    return false
end

local function updateBullets(dt)
    -- 处理延迟发射队列
    for i = #pendingShots, 1, -1 do
        local s = pendingShots[i]
        s.timer = s.timer - dt
        if s.timer <= 0 then
            if s.shotgun then
                spawnShotgunVolley()
            else
                spawnBullet(nil, true)
            end
            table.remove(pendingShots, i)
        end
    end

    for i = #bullets, 1, -1 do
        local b = bullets[i]
        if not b.alive then
            table.remove(bullets, i)
        else
            -- 使用 vx/vy 方向移动（跟随枪口朝向）
            local oldX = b.x
            local oldY = b.y
            local maxDist = b.shotgunPellet and SHOTGUN_MAX_DIST or BULLET_MAX_DIST
            local moveX = (b.vx or (b.dir * BULLET_SPEED)) * dt
            local moveY = (b.vy or 0) * dt
            local stepDist = math.sqrt(moveX * moveX + moveY * moveY)
            local remainingDist = math.max(0, maxDist - b.dist)
            local reachedMaxDist = stepDist >= remainingDist
            if stepDist > remainingDist and stepDist > 0 then
                local stepScale = remainingDist / stepDist
                moveX = moveX * stepScale
                moveY = moveY * stepScale
                stepDist = remainingDist
            end
            b.x = b.x + moveX
            b.y = b.y + moveY
            b.dist = b.dist + stepDist
            b.muzzleTimer = math.max(0, b.muzzleTimer - dt)

            if b.alive then
                local pelletRadius = b.shotgunPellet and 7 or 3
                for _, z in ipairs(zombies) do
                    local hitZombie, hitY = false, nil
                    if z.alive then
                        hitZombie, hitY = segmentHitsZombie(oldX, oldY, b.x, b.y, z, pelletRadius)
                    end
                    if hitZombie then
                        b.alive = false
                        local closeShotgunHit = b.shotgunPellet and b.dist <= SHOTGUN_SHATTER_DIST
                        if closeShotgunHit then
                            spawnZombieGibs(z, H * GROUND_Y_RATIO + hitY, b.dir)
                            if not z.deathSoundPlayed then
                                playZombieSound("death")
                                z.deathSoundPlayed = true
                            end
                        else
                            z.hitFlash = 0.15
                            z.stagger = b.dir * (b.shotgunPellet and 18 or 30)
                            z.animState = "hurt"
                            z.animStartTime = gameTime
                            z.hurtTimer = 0.34
                            if b.shotgunPellet then
                                spawnShotgunImpact(z.x, H * GROUND_Y_RATIO + hitY, b.dir)
                            else
                                spawnBatBloodSplash(z.x, H * GROUND_Y_RATIO + hitY, b.dir)
                            end
                            z.hp = z.hp - (b.damage or BULLET_DAMAGE)

                            if z.hp <= 0 then
                                spawnDeathBloodBurst(z, H * GROUND_Y_RATIO + hitY, b.dir, 1)
                                z.alive = false
                                z.animState = "dead"
                                z.animStartTime = gameTime
                                z.deadTimer = 0
                                if not z.deathSoundPlayed then
                                    playZombieSound("death")
                                    z.deathSoundPlayed = true
                                end
                                if z.spine then
                                    local deathAnims = {"dead_1", "dead_2", "dead_3"}
                                    local pick = deathAnims[math.random(#deathAnims)]
                                    z.spine:SetAnimation(0, pick, false)
                                end
                            end
                        end
                        break
                    end
                end
            end

            -- 丧尸未命中时再处理墙体，避免贴墙丧尸被墙体优先吞掉。
            if b.alive and bulletHitsObstacle(oldX, oldY, b.x, b.y) then
                b.alive = false
            end
            if reachedMaxDist then
                b.alive = false
            end
        end
    end
end

-- ============================================================================
-- 玩家角色（单张图片绘制）
-- ============================================================================

-- 剖面楼碰撞数据（由 initCrossSection 填充）
csColliders = csColliders or { slabs = {}, walls = {} }

PLAYER_START_X = 7000 -- 出生在第二栋楼一层左侧房间内，靠近入口门

---@diagnostic disable-next-line: redefined-local
player = {
    x           = PLAYER_START_X,
    jumpVelY    = 0,
    onGround    = true,
    jumpScrY    = 0,
    facingRight = true,
    drawH       = 120,     -- 角色绘制高度（逻辑像素）
    isMoving    = false,
    isRunning   = false,
    -- 动画动作状态
    actionState  = "none",  -- "none"|"attack"|"skill"|"reload"|"hurt"|"dead"
    actionTimer  = 0.0,     -- 动作剩余时间
    attackCombo  = 0,       -- 攻击连击计数(1-3)
    attackQueued = false,   -- 攻击输入缓冲，避免连按鬼畜
    ammo         = 6,
    maxAmmo      = 6,
    hp           = 100,
    maxHp        = 100,
    stamina      = 100,
    maxStamina   = 100,
    -- 暗层遮罩亮度（0~1，1=全亮/室外，越小越暗）—— 通用字段，任何角色渲染方式都可读取
    overlayTint  = 1.0,
    hitInvincibleTimer = 0.0,
    hitFlashTimer = 0.0,
}

local PLAYER_SPEED_X  = 220
local PLAYER_JUMP_VEL = -500

local function initPlayer()
    player.x          = PLAYER_START_X
    player.jumpVelY   = 0
    player.onGround   = true
    player.jumpScrY   = 0
    player.facingRight = true
    player.isMoving   = false
    player.isRunning  = false
    player.actionState = "none"
    player.actionTimer = 0.0
    player.attackCombo = 0
    player.attackQueued = false
    player.hitInvincibleTimer = 0.0
    player.hitFlashTimer = 0.0
    player.maxAmmo = PLAYER_ANIM_SET == "shotgun" and 2 or 6
    player.ammo = player.maxAmmo
    player.maxHp = player.maxHp or 100
    player.hp = player.maxHp
    player.maxStamina = player.maxStamina or 100
    player.stamina = player.maxStamina
    player.staminaExhausted = false
    cameraX = math.max(0, player.x - W * 0.4)
end

local function drawPlayer(ctx)
    if playerImg <= 0 then return end

    local sx, sy, sc = worldToScreen(player.x, 0)
    sy = sy + player.jumpScrY

    -- 绘制尺寸：高度基于 drawH，宽度保持原图比例
    local dh = player.drawH
    local dw = dh * (PLAYER_IMG_W / PLAYER_IMG_H)
    -- 图片底部有透明留白，往下偏移让脚踩到地面线
    local footOffset = dh * 0.06

    nvgSave(ctx)
    -- 朝左时水平镜像
    if not player.facingRight then
        nvgTranslate(ctx, sx, 0)
        nvgScale(ctx, -1, 1)
        nvgTranslate(ctx, -sx, 0)
    end

    local topY = sy - dh + footOffset
    local plrAlpha = floorTransition.alpha  -- 换层过渡时淡出淡入
    local paint = nvgImagePattern(ctx, sx - dw * 0.5, topY, dw, dh, 0, playerImg, plrAlpha)
    nvgBeginPath(ctx)
    nvgRect(ctx, sx - dw * 0.5, topY, dw, dh)
    nvgFillPaint(ctx, paint)
    nvgFill(ctx)
    nvgRestore(ctx)
end

local function updatePlayer(dt)
    local PHW = 20  -- 玩家半宽（碰撞用）

    -- 换层过渡期间冻结玩家输入
    if floorTransition.active or ladderTransition.active then return end

    -- 若玩家踩在楼板上（jumpScrY < 0），检测是否走出了楼板范围
    player.hitInvincibleTimer = math.max(0, (player.hitInvincibleTimer or 0) - dt)
    player.hitFlashTimer = math.max(0, (player.hitFlashTimer or 0) - dt)

    if player.onGround and player.jumpScrY < 0 then
        local onSlab = false
        for _, slab in ipairs(csColliders.slabs) do
            if math.abs(player.jumpScrY - slab.relY) < 2 and
               player.x + PHW > slab.wx1 and player.x - PHW < slab.wx2 then
                onSlab = true; break
            end
        end
        if not onSlab then player.onGround = false end
    end

    -- 统一输入：摇杆（PC键盘WASD自动映射，移动端触摸摇杆）
    local mx = 0
    local my = 0  -- 垂直方向输入（正值=向下）
    if joystick_ then
        local moveX, moveY = joystick_:getMovement()
        mx = moveX
        my = moveY or 0
    else
        -- 兜底：摇杆未就绪时直接读键盘
        local left  = input:GetKeyDown(KEY_A) or input:GetKeyDown(KEY_LEFT)
        local right = input:GetKeyDown(KEY_D) or input:GetKeyDown(KEY_RIGHT)
        mx = (right and 1 or 0) - (left and 1 or 0)
    end
    -- 先计算攻击意图，供本帧移动锁定和后续动作映射共用；无武器时屏蔽所有攻击输入。
    local hasEquippedWeapon = lootUI.equippedGunItem ~= "" or lootUI.equippedMeleeItem ~= ""
    local wantAttack = hasEquippedWeapon and (not lootUI.active) and (not lootUI.letterOpen) and (not lightToggleUIConsumed) and (not weaponHUDInputConsumed) and (not actionHUDInputConsumed or attackPressed_) and (input:GetKeyPress(KEY_J) or (dpr < 2 and input:GetMouseButtonPress(MOUSEB_LEFT)) or attackPressed_)
    local willStartAttackOrReload = wantAttack and (player.actionState == "none" or player.actionState == "getup" or player.actionState == "attack")

    -- 开枪/装弹/受击/死亡等动作期间锁定移动，避免动作与位移混播
    local movementLocked = player.actionState == "attack" or player.actionState == "reload" or player.actionState == "hurt" or player.actionState == "dead" or willStartAttackOrReload
    if movementLocked then
        mx = 0
        my = 0
    end

    -- S/DOWN 键盘 + 手机下梯按钮（始终直接读取，不受摇杆分支影响）
    if input:GetKeyDown(KEY_S) or input:GetKeyDown(KEY_DOWN) then
        my = 1
    end
    if movementLocked then
        mx = 0
        my = 0
    end
    -- descendBtn_ 已改为开门按钮，不再用于下梯（S/DOWN 足够）

    -- 跳跃：仅保留键盘空格
    local jump = input:GetKeyPress(KEY_SPACE)
    if movementLocked then jump = false end

    -- 梯子下降：在任一栋楼梯口处按下键可进入对应地下室
    local nearbyLadder = getNearestLadderInfo()
    local inLadderZone = nearbyLadder ~= nil
    -- 地下室上下梯完全由 updateGame 的爬梯过渡处理，不能通过普通重力直接穿过开口。
    if player.onGround and player.jumpScrY == 0 and my > 0.5 and inLadderZone then
        my = 0
    end

    local moveAbs = math.abs(mx)
    if moveAbs < 0.12 then
        mx = 0
        moveAbs = 0
    end
    local runInput = input:GetKeyDown(KEY_SHIFT) or moveAbs > 0.75
    local staminaMax = math.max(1, player.maxStamina or 100)
    local stamina = clamp(player.stamina or staminaMax, 0, staminaMax)
    local recoveryThreshold = staminaMax * 0.2

    -- 体力耗尽后立即停下，并恢复到 20% 后再允许移动，避免按住方向时反复启停。
    if stamina >= staminaMax then
        player.staminaExhausted = false
    end

    local staminaExhausted = player.staminaExhausted == true
    if staminaExhausted then
        player.isRunning = false
        mx = 0
        moveAbs = 0
        stamina = stamina + 22 * dt
        if stamina >= recoveryThreshold then
            player.staminaExhausted = false
        end
    else
        player.isRunning = runInput and moveAbs > 0 and stamina > 0.01
        if player.isRunning then
            stamina = stamina - 10 * dt
            if stamina <= 0 then
                stamina = 0
                player.staminaExhausted = true
                player.isRunning = false
                mx = 0
                moveAbs = 0
            end
        else
            stamina = stamina + 22 * dt
        end
    end

    player.stamina = clamp(stamina, 0, staminaMax)
    local moveSpeed = player.isRunning and PLAYER_SPEED_X or (PLAYER_SPEED_X * 0.55)
    player.x = player.x + mx * moveSpeed * dt
    player.x = clamp(player.x, 50, STREET_LENGTH - 50)

    -- ── 竖向墙体碰撞（水平推出）────────────────────────────
    do
        local feet = player.jumpScrY
        local head = feet - player.drawH
        for _, wall in ipairs(csColliders.walls) do
            if feet > wall.relY1 and head < wall.relY2 then
                -- 检查是否处于某个开口内
                local inGap = false
                for _, gap in ipairs(wall.gaps) do
                    -- 带 doorKey 的 gap：只有门打开才可通行
                    local gapActive = true
                    if gap.walkable then
                        gapActive = true
                    elseif gap.doorKey then
                        local rds = roomDoorStates[gap.doorKey]
                        if rds and rds.openProg < 0.5 then
                            gapActive = false  -- 门关着，gap 不生效
                        end
                    end
                    if gapActive and feet > gap.y1 and head < gap.y2 then
                        inGap = true; break
                    end
                end
                if not inGap then
                    local px1, px2 = player.x - PHW, player.x + PHW
                    if px1 < wall.wx2 and px2 > wall.wx1 then
                        if (px2 - wall.wx1) < (wall.wx2 - px1) then
                            player.x = wall.wx1 - PHW
                        else
                            player.x = wall.wx2 + PHW
                        end
                    end
                end
            end
        end
    end

    if mx > 0 then player.facingRight = true
    elseif mx < 0 then player.facingRight = false end

    player.isMoving = math.abs(mx) > 0
    walkGearSfxTimer = math.max(0, walkGearSfxTimer - dt)
    if player.isMoving and player.onGround and player.actionState == "none" then
        if walkGearSfxTimer <= 0 then
            playWalkGearSound()
            walkGearSfxTimer = player.isRunning and 0.36 or 0.52
        end
    else
        walkGearSfxTimer = 0
    end

    -- ── 动作状态计时器 ──
    if player.actionTimer > 0 then
        player.actionTimer = player.actionTimer - dt
        if player.actionTimer <= 0 then
            if player.actionState == "reload" then
                player.ammo = player.maxAmmo
                player.actionState = "none"
                player.actionTimer = 0.0
            elseif player.actionState == "attack" and isFirearmAnimSet() and player.ammo <= 0 then
                player.attackQueued = false
                player.actionState = "reload"
                player.actionTimer = BAT_DEMO_ANIM.reloadDuration or 1.2
                BAT_DEMO_ANIM.reloadStartTime = gameTime
                if isShotgunAnimSet() then
                    print("[Shotgun] 两发弹药耗尽，开始折管装弹")
                end
                playPistolReloadSound()
            elseif player.actionState == "attack" and player.attackQueued and (PLAYER_ANIM_SET == "bat" or isFirearmAnimSet() and player.ammo > 0) then
                player.attackQueued = false
                player.actionState = "attack"
                player.actionTimer = BAT_DEMO_ANIM.attackDuration
                BAT_DEMO_ANIM.attackStartTime = gameTime
                if isFirearmAnimSet() then
                    player.ammo = math.max(0, player.ammo - 1)
                    requestShot()
                end
                if PLAYER_ANIM_SET == "bat" then
                    local hit = requestBatAttack()
                    playBatAttackSound(hit)
                end
            else
                player.actionState = "none"
                player.actionTimer = 0.0
            end
        end
    end

    -- ── 操作到动作映射 ──
    attackPressed_ = false  -- 每帧消费标记（防止残留）
    local canStartAction = player.actionState == "none" or player.actionState == "getup"

    -- J / 鼠标左键 / 攻击按钮：攻击动作。gun 模式下只消耗弹药，不生成子弹；弹药打光后自动换弹。
    if wantAttack then
        if player.actionState == "attack" then
            if PLAYER_ANIM_SET == "bat" or (isFirearmAnimSet() and player.ammo > 0) then
                player.attackQueued = true
            end
        elseif canStartAction then
            if isFirearmAnimSet() and player.ammo <= 0 then
                player.actionState = "reload"
                player.actionTimer = BAT_DEMO_ANIM.reloadDuration or 1.2
                BAT_DEMO_ANIM.reloadStartTime = gameTime
                playPistolReloadSound()
                player.attackCombo = 0
            else
                player.attackCombo = 1
                player.actionState = "attack"
                player.actionTimer = BAT_DEMO_ANIM.attackDuration
                BAT_DEMO_ANIM.attackStartTime = gameTime
                if isFirearmAnimSet() then
                    player.ammo = math.max(0, player.ammo - 1)
                    requestShot()
                    if player.ammo == 0 then
                        player.attackQueued = false
                    end
                elseif PLAYER_ANIM_SET == "bat" then
                    local hit = requestBatAttack()
                    playBatAttackSound(hit)
                end
            end
        end
    end

    -- R：仅调试非持枪资源时使用；持枪换弹只能由弹药打光自动触发
    if lootUI.equippedGunItem ~= ""
        and input:GetKeyPress(KEY_R)
        and isFirearmAnimSet()
        and canStartAction
        and BAT_DEMO_ANIM.reloadStart then
        player.actionState = "reload"
        player.actionTimer = BAT_DEMO_ANIM.reloadDuration or 1.2
        BAT_DEMO_ANIM.reloadStartTime = gameTime
        playPistolReloadSound()
        player.attackCombo = 0
    end
    -- Q 键：受击测试
    if input:GetKeyPress(KEY_Q) then
        player.actionState = "hurt"
        player.actionTimer = BAT_DEMO_ANIM.hurtDuration
        BAT_DEMO_ANIM.hurtStartTime = gameTime
        player.attackCombo = 0
    end
    -- X 键：死亡测试
    if input:GetKeyPress(KEY_X) then
        player.actionState = "dead"
        player.actionTimer = 99
        BAT_DEMO_ANIM.deadStartTime = gameTime
        player.attackCombo = 0
    end
    -- G 键：从死亡恢复（起身）
    if input:GetKeyPress(KEY_G) and player.actionState == "dead" then
        player.actionState = "getup"
        player.actionTimer = 0.8
    end

    if jump and player.onGround then
        player.jumpVelY = PLAYER_JUMP_VEL
        player.onGround = false
    end

    if not player.onGround then
        local prevY = player.jumpScrY
        player.jumpVelY = player.jumpVelY + 1400 * dt
        player.jumpScrY = player.jumpScrY + player.jumpVelY * dt

        -- ── 水平楼板碰撞（落地 & 撞天花板）────────────────
        for _, slab in ipairs(csColliders.slabs) do
            if player.x + PHW > slab.wx1 and player.x - PHW < slab.wx2 then
                -- 落地：从上方落到楼板顶面
                if player.jumpVelY > 0 and prevY < slab.relY and player.jumpScrY >= slab.relY then
                    player.jumpScrY = slab.relY
                    player.jumpVelY = 0
                    player.onGround = true
                    break
                end
                -- 顶头：从下方跳起撞到楼板底面
                if player.jumpVelY < 0 then
                    local ceilBot  = slab.relY + slab.thick
                    local prevHead = prevY - player.drawH
                    local newHead  = player.jumpScrY - player.drawH
                    if prevHead >= ceilBot and newHead < ceilBot then
                        player.jumpScrY = ceilBot + player.drawH
                        player.jumpVelY = 0
                    end
                end
            end
        end

        -- 回到主地面（梯口处允许穿越）
        if player.jumpScrY >= 0 and not inLadderZone then
            player.jumpScrY = 0
            player.jumpVelY = 0
            player.onGround = true
        end
    end

    -- 相机平滑跟随（拖拽中及松手冷却期暂停跟随）
    if drag.cooldown > 0 then
        drag.cooldown = drag.cooldown - dt
    end
    if not drag.active and drag.cooldown <= 0 then
        local targetCamX = player.x - W * 0.4
        cameraX = cameraX + (targetCamX - cameraX) * math.min(dt * 6, 1.0)
        cameraX = clamp(cameraX, 0, STREET_LENGTH - W)
        -- 垂直偏移：跟随玩家上下楼/地下室
        ---@type number
        local camYTarget = CAMERA_BASE_Y
        if player.jumpScrY > 0 then
            -- 地下室：向下偏移
            camYTarget = CAMERA_BASE_Y - player.jumpScrY
        elseif player.jumpScrY < 0 then
            -- 上楼：向上偏移
            camYTarget = CAMERA_BASE_Y - player.jumpScrY
        end
        cameraY = cameraY + (camYTarget - cameraY) * math.min(dt * 4, 1.0)
    end
end

-- 丧尸颜色
local ZC = {
    skin     = { 95, 120, 80 },    -- 发绿的皮肤
    skinDark = { 70, 90, 60 },     -- 暗部
    clothes  = { 55, 45, 42 },     -- 残破衣服
    clothDk  = { 38, 30, 28 },
    blood    = { 140, 20, 15 },
    bloodDk  = { 90, 12, 10 },
    eye      = { 200, 40, 20 },    -- 红眼
    hair     = { 35, 30, 25 },
    bone     = { 200, 190, 170 },  -- 断面骨头色
    meat     = { 130, 40, 35 },    -- 断面肉色
}

function getAliveZombieCount()
    local count = 0
    for _, z in ipairs(zombies) do
        if z.alive then count = count + 1 end
    end
    return count
end

function isZombieInOpenDoorGap(wall)
    local feet = 0
    local head = feet - (ZOMBIE_ANIM_CONFIG.drawH or 132)
    for _, gap in ipairs(wall.gaps or {}) do
        local gapActive = true
        if gap.doorKey then
            local rds = roomDoorStates[gap.doorKey]
            if rds and rds.openProg < 0.5 then
                gapActive = false
            end
        end
        if gapActive and feet > gap.y1 and head < gap.y2 then
            return true
        end
    end
    return false
end

function findClosedDoorBetween(x1, x2)
    local minX = math.min(x1, x2)
    local maxX = math.max(x1, x2)
    local feet = 0
    local head = feet - (ZOMBIE_ANIM_CONFIG.drawH or 132)
    local best = nil
    local bestDist = math.huge

    for _, wall in ipairs(csColliders.walls) do
        if feet > wall.relY1 and head < wall.relY2 and maxX > wall.wx1 and minX < wall.wx2 then
            for _, gap in ipairs(wall.gaps or {}) do
                local doorKey = gap.doorKey
                local rds = doorKey and roomDoorStates[doorKey]
                if rds and rds.openProg < 0.5 then
                    local doorX = (wall.wx1 + wall.wx2) * 0.5
                    local dist = math.abs(x1 - doorX)
                    if dist < bestDist then
                        bestDist = dist
                        best = { key = doorKey, state = rds, x = doorX, wall = wall }
                    end
                end
            end
        end
    end
    return best
end

function isZombieBlockedByClosedDoorBetween(x1, x2)
    return findClosedDoorBetween(x1, x2) ~= nil
end

function damageDoorFromZombie(z)
    if not z or not z.doorTarget or not z.doorTarget.state then return end
    local state = z.doorTarget.state
    if state.openProg >= 0.5 or state.target == 1 then return end

    state.zombieHits = (state.zombieHits or 0) + 1
    print("[Zombie] 攻击门 " .. tostring(z.doorTarget.key) .. " " .. tostring(state.zombieHits) .. "/" .. tostring(ZOMBIE_DOOR_BREAK_HITS))
    if state.zombieHits >= ZOMBIE_DOOR_BREAK_HITS then
        state.target = 1
        state.zombieHits = 0
        playDoorSound()
    end
end

function resolveZombieDoorCollision(z, prevX)
    local halfW = 22
    local feet = 0
    local head = feet - (ZOMBIE_ANIM_CONFIG.drawH or 132)
    local blocked = false

    for _, wall in ipairs(csColliders.walls) do
        if feet > wall.relY1 and head < wall.relY2 and not isZombieInOpenDoorGap(wall) then
            local px1 = z.x - halfW
            local px2 = z.x + halfW
            local crossedRight = prevX and prevX + halfW <= wall.wx1 and z.x - halfW >= wall.wx2
            local crossedLeft = prevX and prevX - halfW >= wall.wx2 and z.x + halfW <= wall.wx1

            if px1 < wall.wx2 and px2 > wall.wx1 then
                if prevX and z.x > prevX then
                    z.x = wall.wx1 - halfW
                elseif prevX and z.x < prevX then
                    z.x = wall.wx2 + halfW
                elseif (px2 - wall.wx1) < (wall.wx2 - px1) then
                    z.x = wall.wx1 - halfW
                else
                    z.x = wall.wx2 + halfW
                end
                blocked = true
            elseif crossedRight then
                z.x = wall.wx1 - halfW
                blocked = true
            elseif crossedLeft then
                z.x = wall.wx2 + halfW
                blocked = true
            end
        end
    end

    z.x = clamp(z.x, 50, STREET_LENGTH - 50)
    return blocked
end

function keepZombieSpawnAwayFromPlayer(zx)
    if not player then return zx end
    local safe = ZOMBIE_PLAYER_SAFE_DISTANCE
    if math.abs(zx - player.x) >= safe then return zx end

    local leftX = player.x - safe - math.random(80, 220)
    local rightX = player.x + safe + math.random(80, 220)
    local leftValid = leftX >= 80
    local rightValid = rightX <= STREET_LENGTH - 80
    if leftValid and rightValid then
        zx = math.random() < 0.5 and leftX or rightX
    elseif leftValid then
        zx = leftX
    elseif rightValid then
        zx = rightX
    else
        zx = player.x < STREET_LENGTH * 0.5 and STREET_LENGTH - 80 or 80
    end
    return clamp(zx, 80, STREET_LENGTH - 80)
end

function separateZombieSpawnX(zx)
    zx = keepZombieSpawnAwayFromPlayer(zx)
    local candidate = zx + math.random(-95, 95)
    for _ = 1, 8 do
        candidate = keepZombieSpawnAwayFromPlayer(candidate)
        local tooClose = false
        for _, z in ipairs(zombies) do
            if z.alive and math.abs(candidate - z.x) < 86 then
                tooClose = true
                break
            end
        end
        if not tooClose then
            return clamp(candidate, 80, STREET_LENGTH - 80)
        end
        candidate = zx + math.random(-180, 180)
    end
    return clamp(keepZombieSpawnAwayFromPlayer(candidate), 80, STREET_LENGTH - 80)
end

-- 创建一只丧尸
local function spawnZombie(preferNearPlayer, spawnX)
    local zx = spawnX or (80 + math.random() * (STREET_LENGTH - 160))
    if not spawnX and preferNearPlayer ~= false and player then
        local side = (math.random() >= 0.5) and 1 or -1
        local dist = 360 + math.random() * 620
        zx = player.x + side * dist
        if zx < 80 or zx > STREET_LENGTH - 80 then
            zx = player.x - side * dist
        end
        if zx < 80 or zx > STREET_LENGTH - 80 then
            zx = 80 + math.random() * (STREET_LENGTH - 160)
        end
    end
    zx = clamp(zx, 80, STREET_LENGTH - 80)
    zx = separateZombieSpawnX(zx)

    local z = {
        x = zx,
        facing = player and ((player.x >= zx) and 1 or -1) or ((math.random() >= 0.5) and 1 or -1),
        speed = 92,
        alive = true,
        hp = 3,              -- 需要3发子弹击杀
        spine = nil,         -- 旧 Spine 丧尸保留字段，当前默认使用序列帧
        animState = "idle",  -- 当前动画状态: idle/run/attack/hurt/dead
        animStartTime = gameTime,
        hitFlash = 0,
        stagger = 0,
        visualOffsetX = math.random(-16, 16),
        sizeJitter = 0.94 + math.random() * 0.12,
        deadTimer = 0,
        hurtTimer = 0,
        attackTimer = 0,
        attackHitDone = false,
        attackCooldown = 0,
        idleTimer = 0,
        growlTimer = 0.4 + math.random() * 2.0,
        wanderTimer = 0,
        wanderDirX = (math.random() >= 0.5) and 1 or -1,
        isChasing = false,   -- 进入屏幕后激活；激活后不再因固定距离而脱战
    }
    resolveZombieDoorCollision(z, z.x)
    table.insert(zombies, z)
end

ZOMBIE_INITIAL_SPAWNS = {
    2360, -- 第一只：主楼一楼左侧房间内部
    4380, -- 主楼一楼右侧房间内部
    4720, -- 主楼右侧/超市门外
    5380, -- 仓库门外
    6320, -- 仓库与第二栋楼之间的街道
    7640, -- 第二栋楼右侧，避开玩家出生点 7000
    7790, -- 药店附近
    8360, -- 最右侧撤离方向压力点
}

ZOMBIE_DYNAMIC_SPAWNS = {
    720,
    1180,
    4720,
    5380,
    6320,
    7040,
    7790,
    8360,
}

function chooseZombieSceneSpawnX()
    local candidates = {}
    for _, x in ipairs(ZOMBIE_DYNAMIC_SPAWNS) do
        local dist = math.abs(x - player.x)
        if dist >= 420 and dist <= 1800 then
            candidates[#candidates + 1] = x
        end
    end
    if #candidates == 0 then
        for _, x in ipairs(ZOMBIE_DYNAMIC_SPAWNS) do
            if math.abs(x - player.x) >= 360 then
                candidates[#candidates + 1] = x
            end
        end
    end
    if #candidates == 0 then
        return ZOMBIE_DYNAMIC_SPAWNS[math.random(#ZOMBIE_DYNAMIC_SPAWNS)]
    end
    return candidates[math.random(#candidates)]
end

function spawnInitialZombies()
    zombies = {}
    for _, zx in ipairs(ZOMBIE_INITIAL_SPAWNS) do
        spawnZombie(false, zx)
    end
    zombieSpawnTimer = 1.2
    print("[Zombie] 初始场景化丧尸摆放完成，动态刷新关闭: " .. tostring(#zombies))
end

-- ============================================================================
-- 颜色 - 末世暗色调
-- ============================================================================
local C = {
    skyTop       = { 30, 22, 38 },
    skyMid       = { 70, 35, 30 },
    skyBot       = { 110, 55, 28 },
    cloud        = { 45, 28, 22, 90 },
    cloudDk      = { 28, 16, 14, 130 },
    outline      = { 15, 12, 18 },
    -- 建筑墙体
    wallA        = { 62, 58, 55 },
    wallB        = { 52, 48, 52 },
    wallC        = { 72, 65, 58 },
    wallD        = { 45, 42, 48 },
    -- 屋顶
    roofA        = { 75, 55, 42 },
    roofB        = { 55, 50, 55 },
    -- 门
    door         = { 50, 38, 30 },
    doorFrame    = { 40, 32, 25 },
    doorKnob     = { 140, 120, 80 },
    -- 窗
    winDark      = { 18, 15, 22 },
    winGlow      = { 180, 140, 55 },
    winFrame     = { 48, 42, 38 },
    -- 招牌
    signBg       = { 55, 45, 40 },
    signText     = { 160, 140, 110 },
    -- 地面
    sidewalk     = { 55, 50, 45 },
    road         = { 35, 32, 30 },
    roadLine     = { 50, 45, 40, 70 },
    -- 废墟
    rust         = { 110, 65, 40 },
    rubble       = { 60, 52, 45 },
    -- 氛围
    dustCol      = { 140, 110, 75, 35 },
    -- 玩家
    pBody        = { 65, 80, 95 },
    pSkin        = { 215, 180, 150 },
    pHair        = { 32, 28, 25 },
    pBag         = { 90, 72, 50 },
    pPants       = { 55, 58, 65 },
}

STREET_BUILDING_TYPES = {
    supermarket = {
        wallColor = {74, 82, 74, 255}, roofColor = {48, 55, 48, 255},
        sign = "废弃超市", signColor = {120, 190, 90}, hasAwning = true,
        awningColor = {72, 112, 58}, windowStyle = "large",
    },
    warehouse = {
        wallColor = {78, 74, 68, 255}, roofColor = {55, 52, 48, 255},
        sign = "旧仓库", signColor = {185, 120, 55}, hasAwning = false,
        awningColor = {90, 70, 52}, windowStyle = "shutter",
    },
    pharmacy = {
        wallColor = {70, 78, 86, 255}, roofColor = {50, 55, 64, 255},
        sign = "药店", signColor = {90, 190, 170}, hasAwning = true,
        awningColor = {55, 120, 110}, windowStyle = "large",
    },
}

streetBuildings = {
    {
        id = "supermarket", title = "废弃超市", x = 4620, w = 520, h = 245, floors = 1, floorH = 245,
        type = STREET_BUILDING_TYPES.supermarket, doorX = 430, doorW = 72, doorH = 118,
        litWindow = true, brokenGlass = true, doorOpen = false,
        cracks = { {x1=72,y1=88,dx=28,dy=46}, {x1=338,y1=52,dx=-22,dy=58} },
        lootSpots = {
            { idx = 17, x = 0.20, y = 0.60, w = 0.23, h = 0.30, label = "搜收银台" },
            { idx = 18, x = 0.50, y = 0.36, w = 0.34, h = 0.48, label = "搜货架" },
            { idx = 19, x = 0.78, y = 0.33, w = 0.18, h = 0.56, label = "搜冷柜" },
        },
    },
    {
        id = "warehouse", title = "旧仓库", x = 5320, w = 620, h = 230, floors = 1, floorH = 230,
        type = STREET_BUILDING_TYPES.warehouse, doorX = 512, doorW = 96, doorH = 135,
        litWindow = false, brokenGlass = false, doorOpen = false,
        cracks = { {x1=128,y1=54,dx=36,dy=62}, {x1=420,y1=96,dx=-34,dy=46}, {x1=250,y1=30,dx=12,dy=74} },
        lootSpots = {
            { idx = 20, x = 0.33, y = 0.58, w = 0.35, h = 0.32, label = "搜木箱" },
            { idx = 21, x = 0.70, y = 0.32, w = 0.22, h = 0.55, label = "搜工具架" },
        },
    },
    {
        id = "pharmacy", title = "街角药店", x = 7720, w = 420, h = 260, floors = 1, floorH = 260,
        type = STREET_BUILDING_TYPES.pharmacy, doorX = 330, doorW = 66, doorH = 112,
        litWindow = true, brokenGlass = true, doorOpen = false,
        cracks = { {x1=58,y1=74,dx=24,dy=48}, {x1=300,y1=38,dx=-18,dy=54} },
        lootSpots = {
            { idx = 22, x = 0.48, y = 0.34, w = 0.34, h = 0.50, label = "搜药柜" },
            { idx = 23, x = 0.21, y = 0.61, w = 0.24, h = 0.28, label = "搜收银台" },
        },
    },
}

drawOneBuilding = nil

function isRoomLightOn(key)
    return roomLightStates[key] == true
end

function toggleRoomLight(key)
    if not key or key == "" then return end
    roomLightStates[key] = not roomLightStates[key]
    playLightSwitchSound()
end

function getRoomBrightness(key)
    return isRoomLightOn(key) and 1.0 or 0.0
end

function drawLightSwitch(ctx, sx, sy, key, isNear)
    local on = isRoomLightOn(key)
    local pulse = math.sin(gameTime * 6.0) * 0.35 + 0.65
    local boxW = isNear and 24 or 20
    local boxH = isNear and 32 or 26
    local x = sx - boxW * 0.5
    local y = sy - boxH * 0.5
    local a = isNear and 255 or math.floor(170 + 70 * pulse)

    nvgGlobalCompositeOperation(ctx, NVG_LIGHTER)
    local glowR = isNear and 38 or 28
    local glow = nvgRadialGradient(ctx, sx, sy, 2, glowR,
        on and nvgRGBA(255, 230, 120, math.floor(145 * pulse)) or nvgRGBA(160, 210, 255, math.floor(115 * pulse)),
        nvgRGBA(0, 0, 0, 0))
    nvgBeginPath(ctx)
    nvgCircle(ctx, sx, sy, glowR)
    nvgFillPaint(ctx, glow)
    nvgFill(ctx)
    nvgGlobalCompositeOperation(ctx, NVG_SOURCE_OVER)

    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x, y, boxW, boxH, 4)
    nvgFillColor(ctx, on and nvgRGBA(236, 210, 112, a) or nvgRGBA(34, 38, 42, a))
    nvgFill(ctx)
    nvgStrokeColor(ctx, on and nvgRGBA(255, 245, 170, a) or nvgRGBA(170, 160, 130, a))
    nvgStrokeWidth(ctx, isNear and 2.0 or 1.2)
    nvgStroke(ctx)

    nvgBeginPath(ctx)
    nvgCircle(ctx, sx, sy + (on and -5 or 5), isNear and 3.2 or 2.4)
    nvgFillColor(ctx, on and nvgRGBA(255, 255, 210, a) or nvgRGBA(110, 105, 95, a))
    nvgFill(ctx)

    if isNear then
        local pulse = math.sin(gameTime * 5.0) * 0.35 + 0.65
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, x - 5, y - 5, boxW + 10, boxH + 10, 7)
        nvgStrokeColor(ctx, on and nvgRGBA(255, 230, 120, math.floor(95 * pulse)) or nvgRGBA(255, 255, 255, math.floor(80 * pulse)))
        nvgStrokeWidth(ctx, 2.5)
        nvgStroke(ctx)

        nvgFontFace(ctx, "sans")
        nvgFontSize(ctx, 12)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(ctx, nvgRGBA(255, 255, 230, math.floor(230 * pulse)))
        nvgText(ctx, sx, y - 12, on and "关灯" or "开灯")
    end
end

function refreshLightToggleUIRect()
    lightToggleUIRect = nil
    if lootUI.active or lootUI.letterOpen or not playerNearLightSwitch then return nil end

    local bw = 118
    local bh = 46
    local safeBottom = 0
    if GetSafeAreaInsets then
        local safeRect = GetSafeAreaInsets(false)
        if safeRect and safeRect.max then
            safeBottom = (safeRect.max.y or 0) / dpr
        end
    end
    local searchCenterX = W - 66
    local searchCenterY = H - safeBottom - 128
    local searchW = 78
    local gap = 14
    local bx = searchCenterX - searchW * 0.5 - gap - bw
    local by = searchCenterY - bh * 0.5
    bx = math.max(12, bx)
    by = math.max(H * 0.48, by)
    lightToggleUIRect = { x = bx, y = by, w = bw, h = bh, key = playerNearLightSwitch }
    return lightToggleUIRect
end

function isPointInLightToggleUI(px, py)
    local r = lightToggleUIRect or refreshLightToggleUIRect()
    if not r then return false end
    return px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h
end

function toggleLightFromUI()
    local key = (lightToggleUIRect and lightToggleUIRect.key) or playerNearLightSwitch
    if not key then return false end
    toggleRoomLight(key)
    lightSwitchPressed_ = false
    lightToggleUIConsumed = true
    print("[Light] UI切换灯光: " .. tostring(key) .. " -> " .. tostring(isRoomLightOn(key)))
    return true
end

function handleLightToggleUIInput()
    lightToggleUIConsumed = false
    if lootUI.active or lootUI.letterOpen then return false end

    local r = refreshLightToggleUIRect()
    if not r then
        if (input.numTouches or 0) == 0 then lightToggleUITouchDown = false end
        return false
    end

    local toggled = false
    if input:GetMouseButtonPress(MOUSEB_LEFT) then
        local mx = input.mousePosition.x / dpr
        local my = input.mousePosition.y / dpr
        if isPointInLightToggleUI(mx, my) then
            toggled = toggleLightFromUI()
        end
    end

    local numTouches = input.numTouches or 0
    if numTouches > 0 then
        local touch = input:GetTouch(0)
        local tx = touch.position.x / dpr
        local ty = touch.position.y / dpr
        if not lightToggleUITouchDown then
            lightToggleUITouchDown = isPointInLightToggleUI(tx, ty)
            if lightToggleUITouchDown then
                toggled = toggleLightFromUI() or toggled
            end
        end
    else
        lightToggleUITouchDown = false
    end
    return toggled
end

function handleWeaponHUDInput()
    weaponHUDInputConsumed = false
    local hasEquippedWeapon = lootUI.equippedGunItem ~= "" or lootUI.equippedMeleeItem ~= ""
    if lootUI.active or lootUI.letterOpen or not hasEquippedWeapon or not weaponHUDRect then
        if (input.numTouches or 0) == 0 then weaponHUDTouchDown = false end
        return false
    end

    local function isInside(px, py)
        local r = weaponHUDRect
        return px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h
    end

    local triggered = false
    if input:GetMouseButtonPress(MOUSEB_LEFT) then
        local mx = input.mousePosition.x / dpr
        local my = input.mousePosition.y / dpr
        if isInside(mx, my) then
            weaponSwitchPressed_ = true
            weaponHUDInputConsumed = true
            triggered = true
        end
    end

    local numTouches = input.numTouches or 0
    if numTouches > 0 then
        local touch = input:GetTouch(0)
        local tx = touch.position.x / dpr
        local ty = touch.position.y / dpr
        if not weaponHUDTouchDown then
            weaponHUDTouchDown = isInside(tx, ty)
            if weaponHUDTouchDown then
                weaponSwitchPressed_ = true
                weaponHUDInputConsumed = true
                triggered = true
            end
        end
    else
        weaponHUDTouchDown = false
    end
    return triggered
end

function applyGameVolume(value)
    settingsUI.volume = clamp(value, 0, 1)
    if audio then
        audio:SetMasterGain(SOUND_MASTER, settingsUI.volume)
    end
    print("[Settings] 游戏音量: " .. tostring(math.floor(settingsUI.volume * 100 + 0.5)) .. "%")
end

function openSettingsUI()
    settingsUI.active = true
    exitHomeHUDInputConsumed = true
    if joystick_ then joystick_._shouldShow = false end
    if descendBtn_ then descendBtn_._shouldShow = false end
    if attackBtn_ then attackBtn_._shouldShow = false end
    if doorBtn_ then doorBtn_._shouldShow = false end
    if upBtn_ then upBtn_._shouldShow = false end
    if downBtn_ then downBtn_._shouldShow = false end
    if lootBtn_ then lootBtn_._shouldShow = false end
    if inventoryBtn_ then inventoryBtn_._shouldShow = false end
    if weaponSwitchBtn_ then weaponSwitchBtn_._shouldShow = false end
    print("[Settings] 打开游戏设置")
end

function closeSettingsUI()
    settingsUI.active = false
    settingsUI.touchMode = ""
    if joystick_ then joystick_._shouldShow = true end
    if attackBtn_ then attackBtn_._shouldShow = true end
    if inventoryBtn_ then inventoryBtn_._shouldShow = true end
    print("[Settings] 关闭游戏设置")
end

function returnToHomeFromGame()
    settingsUI.active = false
    settingsUI.touchMode = ""
    appState = "home"
    HomeUI.Reset()

    lootUI.active = false
    lootUI.letterOpen = false
    lootUI.dragging = false
    lootUI.dragInput = ""
    lootUI._touchActive = false
    lootUI._touchDragStarted = false
    lootUI._touchHitItem = false
    lootUI._touchMoved = false
    lootUI.ResetInteractionState()

    weaponSwitchPressed_ = false
    inventoryBtnPressed_ = false
    attackPressed_ = false
    openDoorPressed_ = false
    doorPressed_ = false
    lootBtnPressed_ = false
    reloadPressed_ = false
    consumePressed_ = false
    HEALING_PLUS_PARTICLES = {}
    weaponHUDTouchDown = false
    actionHUDTouchDown = false
    reloadHUDTouchDown = false
    exitHomeHUDTouchDown = false
    exitHomeHUDInputConsumed = false

    if joystick_ then joystick_._shouldShow = false end
    if descendBtn_ then descendBtn_._shouldShow = false end
    if lightSwitchBtn_ then lightSwitchBtn_._shouldShow = false end
    if doorBtn_ then doorBtn_._shouldShow = false end
    if upBtn_ then upBtn_._shouldShow = false end
    if downBtn_ then downBtn_._shouldShow = false end
    if lootBtn_ then lootBtn_._shouldShow = false end

    if rainSrcComp then rainSrcComp:Stop() end
    if bgmSrcComp then bgmSrcComp:Stop() end
    bgmStarted = false
    BlackMarketCloud.MarkDirty("return_home", false)

    print("[Game] 退出本局，返回据点首页")
end

function handleExitHomeHUDInput()
    exitHomeHUDInputConsumed = false
    if appState ~= "playing" or lootUI.active or lootUI.letterOpen or not exitHomeHUDRect then
        if (input.numTouches or 0) == 0 then exitHomeHUDTouchDown = false end
        return false
    end

    local function isInside(px, py)
        local r = exitHomeHUDRect
        return px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h
    end

    local triggered = false
    if input:GetMouseButtonPress(MOUSEB_LEFT) then
        local mx = input.mousePosition.x / dpr
        local my = input.mousePosition.y / dpr
        if isInside(mx, my) then
            openSettingsUI()
            exitHomeHUDInputConsumed = true
            triggered = true
        end
    end

    local numTouches = input.numTouches or 0
    if not triggered and numTouches > 0 then
        local touch = input:GetTouch(0)
        local tx = touch.position.x / dpr
        local ty = touch.position.y / dpr
        if not exitHomeHUDTouchDown then
            exitHomeHUDTouchDown = isInside(tx, ty)
            if exitHomeHUDTouchDown then
                openSettingsUI()
                exitHomeHUDInputConsumed = true
                triggered = true
            end
        end
    elseif numTouches == 0 then
        exitHomeHUDTouchDown = false
    end
    return triggered
end

function handleSearchButtonInput()
    local r = lootUI.searchButtonRect
    if not r or lootUI.active then
        if (input.numTouches or 0) == 0 then lootUI.searchTouchDown = false end
        return false
    end

    local function isInside(px, py)
        return px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h
    end

    local triggered = false
    if input:GetMouseButtonPress(MOUSEB_LEFT) then
        local mx = input.mousePosition.x / dpr
        local my = input.mousePosition.y / dpr
        if isInside(mx, my) then
            lootBtnPressed_ = true
            lootUI.searchPressedTimer = 0.12
            triggered = true
        end
    end

    local numTouches = input.numTouches or 0
    if numTouches > 0 then
        local touch = input:GetTouch(0)
        local tx = touch.position.x / dpr
        local ty = touch.position.y / dpr
        if not lootUI.searchTouchDown and isInside(tx, ty) then
            lootUI.searchTouchDown = true
            lootBtnPressed_ = true
            lootUI.searchPressedTimer = 0.12
            triggered = true
        end
    else
        lootUI.searchTouchDown = false
    end
    return triggered
end

function handleActionHUDInput()
    actionHUDInputConsumed = false
    reloadHUDInputConsumed = false
    if lootUI.active or lootUI.letterOpen or not inventoryHUDRect then
        if (input.numTouches or 0) == 0 then
            actionHUDTouchDown = false
            reloadHUDTouchDown = false
        end
        return false
    end

    local function isInside(rect, px, py)
        return rect and px >= rect.x and px <= rect.x + rect.w and py >= rect.y and py <= rect.y + rect.h
    end

    local function triggerAt(px, py)
        if cs2LadderDownHUDVisible and ladderDownHUDRect
            and isInside(ladderDownHUDRect, px, py) then
            ladderEnterPressed_ = true
            actionHUDInputConsumed = true
            return true
        end
        if doorHUDRect and isInside(doorHUDRect, px, py)
            and ((descendBtn_ and descendBtn_._shouldShow) or (doorBtn_ and doorBtn_._shouldShow)) then
            if descendBtn_ and descendBtn_._shouldShow then
                openDoorPressed_ = true
            else
                doorPressed_ = true
            end
            actionHUDInputConsumed = true
            return true
        end
        if isInside(consumeHUDRect, px, py) then
            consumePressed_ = true
            consumeHUDPressTimer = 0.12
            consumeHUDScale = 0.88
            actionHUDInputConsumed = true
            return true
        end
        if reloadHUDRect and lootUI.equippedGunItem ~= "" and isInside(reloadHUDRect, px, py) then
            reloadPressed_ = true
            reloadHUDPressTimer = 0.12
            reloadHUDScale = 0.88
            reloadHUDInputConsumed = true
            actionHUDInputConsumed = true
            return true
        end
        if isInside(inventoryHUDRect, px, py) then
            inventoryBtnPressed_ = true
            actionHUDInputConsumed = true
            return true
        end
        if attackHUDRect and (lootUI.equippedGunItem ~= "" or lootUI.equippedMeleeItem ~= "")
            and isInside(attackHUDRect, px, py) then
            attackPressed_ = true
            attackHUDPressTimer = 0.12
            attackHUDScale = 0.88
            actionHUDInputConsumed = true
            return true
        end
        return false
    end

    local triggered = false
    if input:GetMouseButtonPress(MOUSEB_LEFT) then
        triggered = triggerAt(input.mousePosition.x / dpr, input.mousePosition.y / dpr)
    end

    local numTouches = input.numTouches or 0
    if numTouches > 0 then
        local touch = input:GetTouch(0)
        if not actionHUDTouchDown then
            actionHUDTouchDown = true
            triggered = triggerAt(touch.position.x / dpr, touch.position.y / dpr) or triggered
        end
    else
        actionHUDTouchDown = false
    end
    return triggered
end

function drawLightToggleUIButton(ctx)
    if settingsUI.active then return end
    local r = refreshLightToggleUIRect()
    if not r then return end

    local on = isRoomLightOn(r.key)
    local text = on and "关灯" or "开灯"
    local bx, by, bw, bh = r.x, r.y, r.w, r.h

    local pulse = math.sin(gameTime * 5.5) * 0.35 + 0.65
    nvgSave(ctx)
    nvgResetTransform(ctx)
    nvgResetScissor(ctx)
    nvgScale(ctx, dpr, dpr)

    nvgGlobalCompositeOperation(ctx, NVG_LIGHTER)
    local glow = nvgRadialGradient(ctx, bx + bw * 0.5, by + bh * 0.5, 8, 68,
        on and nvgRGBA(255, 220, 90, math.floor(95 * pulse)) or nvgRGBA(120, 190, 255, math.floor(110 * pulse)),
        nvgRGBA(0, 0, 0, 0))
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, bx - 10, by - 10, bw + 20, bh + 20, 20)
    nvgFillPaint(ctx, glow)
    nvgFill(ctx)
    nvgGlobalCompositeOperation(ctx, NVG_SOURCE_OVER)

    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, bx, by, bw, bh, 13)
    nvgFillColor(ctx, on and nvgRGBA(95, 70, 32, 235) or nvgRGBA(28, 42, 62, 242))
    nvgFill(ctx)
    nvgStrokeColor(ctx, on and nvgRGBA(255, 225, 120, 255) or nvgRGBA(165, 218, 255, 255))
    nvgStrokeWidth(ctx, 2.5)
    nvgStroke(ctx)

    nvgBeginPath(ctx)
    nvgCircle(ctx, bx + 23, by + bh * 0.5, 10)
    nvgFillColor(ctx, on and nvgRGBA(255, 224, 95, 255) or nvgRGBA(95, 180, 255, 255))
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(255, 255, 255, 190))
    nvgStrokeWidth(ctx, 1.5)
    nvgStroke(ctx)

    nvgFontFace(ctx, "sans")
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(ctx, 20)
    nvgFillColor(ctx, nvgRGBA(255, 255, 235, 255))
    nvgText(ctx, bx + bw * 0.62, by + bh * 0.5, text)
    nvgRestore(ctx)
end

function drawSearchButton(ctx)
    if settingsUI.active then return end
    if appState ~= "playing" or lootUI.active then
        lootUI.searchButtonRect = nil
        return
    end
    if not lootBtn_ or not lootBtn_._shouldShow then
        lootUI.searchButtonRect = nil
        return
    end

    local safeBottom = 0
    if GetSafeAreaInsets then
        local safeRect = GetSafeAreaInsets(false)
        if safeRect and safeRect.max then
            safeBottom = (safeRect.max.y or 0) / dpr
        end
    end
    local pressed = lootUI.searchPressedTimer > 0
    local searchScale = pressed and 0.92 or 1.0
    local searchW = 78
    local searchH = 48
    local searchCenterX = W - 66
    local searchCenterY = H - safeBottom - 128
    local searchRectW = 90
    local searchRectH = 62
    lootUI.searchButtonRect = {
        x = searchCenterX - searchRectW * 0.5,
        y = searchCenterY - searchRectH * 0.5,
        w = searchRectW,
        h = searchRectH,
    }

    nvgSave(ctx)
    nvgResetTransform(ctx)
    nvgResetScissor(ctx)
    nvgScale(ctx, dpr, dpr)
    nvgTranslate(ctx, searchCenterX, searchCenterY)
    nvgScale(ctx, searchScale, searchScale)
    nvgTranslate(ctx, -searchCenterX, -searchCenterY)

    local pulse = math.sin(gameTime * 4.5) * 0.5 + 0.5
    local glowAlpha = math.floor(16 + pulse * 18)
    nvgGlobalCompositeOperation(ctx, NVG_LIGHTER)
    local glow = nvgRadialGradient(ctx, searchCenterX, searchCenterY, 12, 52,
        nvgRGBA(235, 176, 62, glowAlpha), nvgRGBA(235, 176, 62, 0))
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, searchCenterX - searchW * 0.5 - 7, searchCenterY - searchH * 0.5 - 7,
        searchW + 14, searchH + 14, 14)
    nvgFillPaint(ctx, glow)
    nvgFill(ctx)
    nvgGlobalCompositeOperation(ctx, NVG_SOURCE_OVER)

    local bx = searchCenterX - searchW * 0.5
    local by = searchCenterY - searchH * 0.5
    local cut = 8
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, bx + cut, by)
    nvgLineTo(ctx, bx + searchW, by)
    nvgLineTo(ctx, bx + searchW, by + searchH - cut)
    nvgLineTo(ctx, bx + searchW - cut, by + searchH)
    nvgLineTo(ctx, bx, by + searchH)
    nvgLineTo(ctx, bx, by + cut)
    nvgClosePath(ctx)
    nvgFillColor(ctx, nvgRGBA(17, 19, 22, 218))
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(224, 170, 67, 220))
    nvgStrokeWidth(ctx, 1.5)
    nvgStroke(ctx)

    nvgBeginPath(ctx)
    nvgRect(ctx, bx, by + cut, 3, searchH - cut * 2)
    nvgFillColor(ctx, nvgRGBA(235, 176, 62, 255))
    nvgFill(ctx)

    -- 小型抽屉图标，与攻击、装弹按钮使用相同的战术线框语言。
    local iconCX = bx + 20
    local iconCY = searchCenterY
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, iconCX - 9, iconCY - 8, 18, 16, 2)
    nvgStrokeColor(ctx, nvgRGBA(244, 204, 116, 245))
    nvgStrokeWidth(ctx, 1.6)
    nvgStroke(ctx)
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, iconCX - 7, iconCY - 2)
    nvgLineTo(ctx, iconCX + 7, iconCY - 2)
    nvgMoveTo(ctx, iconCX - 2, iconCY + 3)
    nvgLineTo(ctx, iconCX + 2, iconCY + 3)
    nvgStrokeColor(ctx, nvgRGBA(224, 170, 67, 240))
    nvgStrokeWidth(ctx, 1.4)
    nvgStroke(ctx)

    nvgFontFace(ctx, "sans")
    nvgFontSize(ctx, 6.5)
    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(ctx, nvgRGBA(224, 170, 67, 225))
    nvgText(ctx, bx + 34, by + 6, "SEARCH")
    nvgFontSize(ctx, 13)
    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(ctx, nvgRGBA(244, 241, 229, 250))
    nvgText(ctx, bx + 34, by + 31, "搜刮")
    nvgRestore(ctx)
end

function isPlayerNearLightSwitch(worldX, screenY, rangeX, rangeY)
    local px = player.x
    local feetY = H * GROUND_Y_RATIO + player.jumpScrY
    local touchY = feetY - (player.drawH or 120) * 0.28
    return math.abs(px - worldX) <= (rangeX or 58) and math.abs(touchY - screenY) <= math.max(rangeY or 70, 112)
end

function registerLightSwitch(ctx, key, sx, sy, worldX, roomWorldLeft, roomWorldRight, roomTop, roomH, nearRangeX, nearRangeY)
    if not key or key == "" then return false end
    local rangeX = nearRangeX or 68
    local rangeY = nearRangeY or 74
    local roomEntryMargin = math.min(42, rangeX * 0.6)
    local playerInRoom = isPlayerInRoomBounds(
        roomWorldLeft - roomEntryMargin,
        roomWorldRight + roomEntryMargin,
        roomTop,
        roomH
    )
    local isNear = playerInRoom and isPlayerNearLightSwitch(worldX, sy, rangeX, rangeY)
    lightSwitchZones[#lightSwitchZones + 1] = {
        key = key,
        worldX = worldX,
        screenY = sy,
        rangeX = rangeX,
        rangeY = rangeY,
        roomWorldLeft = roomWorldLeft,
        roomWorldRight = roomWorldRight,
        roomTop = roomTop,
        roomH = roomH,
    }
    if isNear then playerNearLightSwitch = key end
    lightSwitchDrawQueue[#lightSwitchDrawQueue + 1] = { key = key, sx = sx, sy = sy, isNear = isNear }
    return isNear
end

function isPlayerInRoomBounds(worldLeft, worldRight, screenTop, screenH)
    local feetY = H * GROUND_Y_RATIO + player.jumpScrY
    return player.x >= worldLeft and player.x <= worldRight and feetY >= screenTop - 24 and feetY <= screenTop + screenH + 90
end

function drawDarkRoomOverlay(ctx, x, y, w, h, lightOn, playerSX, playerSY)
    if lightOn then return end
    nvgGlobalCompositeOperation(ctx, NVG_SOURCE_OVER)
    nvgBeginPath(ctx)
    nvgRect(ctx, x, y, w, h)
    nvgFillColor(ctx, nvgRGBA(0, 0, 0, 255))
    nvgFill(ctx)
end

function isPlayerInsideStreetBuilding(b)
    return b and b.doorOpen and math.abs(player.jumpScrY) < 4 and player.x >= b.x + 24 and player.x <= b.x + b.w - 24
end

function getCurrentStreetBuilding()
    for _, b in ipairs(streetBuildings) do
        if isPlayerInsideStreetBuilding(b) then return b end
    end
    return nil
end

function detectNearbyStreetBuilding()
    local best = nil
    local bestDist = math.huge
    if math.abs(player.jumpScrY) > 4 then return nil end
    for _, b in ipairs(streetBuildings) do
        local doorCX = b.x + b.doorX
        local dist = math.abs(player.x - doorCX)
        if dist < 90 and dist < bestDist then
            best = b
            bestDist = dist
        end
    end
    return best
end

function drawStreetBuildingSearchZone(ctx, playerSX, playerSY, rx, ry, rw, rh, spot)
    if not spot then return end
    local hitW = math.floor(rw * spot.w)
    local hitH = math.floor(rh * spot.h)
    local hitX = rx + math.floor(rw * spot.x) - math.floor(hitW * 0.5)
    local hitY = ry + math.floor(rh * spot.y)
    lootUI.DrawKitchenSearchHint(ctx, playerSX, playerSY, hitX, hitY, hitW, hitH, spot.idx, 0.5, 0.0, 1.0, 1.0, spot.label)
end

function drawStreetFurnitureImage(ctx, img, x, y, w, h, alphaBounds)
    if not img or img <= 0 then return end

    local sourceRatio = 768 / 512
    local leftN = alphaBounds[1] / 768
    local topN = alphaBounds[2] / 512
    local rightN = alphaBounds[3] / 768
    local bottomN = alphaBounds[4] / 512
    local visibleWN = rightN - leftN
    local visibleHN = bottomN - topN
    local targetVisibleW = w * 0.92
    local targetVisibleH = h * 0.82
    local drawW = math.min(
        targetVisibleW / visibleWN,
        targetVisibleH * sourceRatio / visibleHN
    )
    local drawH = drawW / sourceRatio
    local visibleW = drawW * visibleWN
    local floorY = y + h - 12
    local drawX = x + (w - visibleW) * 0.5 - drawW * leftN
    local drawY = floorY - drawH * bottomN

    local paint = nvgImagePattern(ctx, drawX, drawY, drawW, drawH, 0, img, 1.0)
    nvgBeginPath(ctx)
    nvgRect(ctx, drawX, drawY, drawW, drawH)
    nvgFillPaint(ctx, paint)
    nvgFill(ctx)
end

function drawStreetBuildingInterior(ctx, b, groundY)
    local sx = b.x - cameraX

    local x = sx + 18
    local y = groundY - b.h + 28
    local w = b.w - 36
    local h = b.h - 42
    local playerSX = player.x - cameraX
    local playerSY = H * GROUND_Y_RATIO + player.jumpScrY

    nvgSave(ctx)
    nvgScissor(ctx, x, y, w, h)
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x, y, w, h, 8)
    nvgFillColor(ctx, nvgRGBA(30, 32, 30, 248))
    nvgFill(ctx)

    local backGrad = nvgLinearGradient(ctx, 0, y, 0, y + h, nvgRGBA(80, 76, 66, 210), nvgRGBA(34, 30, 26, 240))
    nvgBeginPath(ctx)
    nvgRect(ctx, x, y, w, h)
    nvgFillPaint(ctx, backGrad)
    nvgFill(ctx)

    nvgBeginPath(ctx)
    nvgRect(ctx, x, y + h - 12, w, 12)
    nvgFillColor(ctx, nvgRGBA(52, 45, 38, 255))
    nvgFill(ctx)

    nvgFontFace(ctx, "sans")
    nvgFontSize(ctx, 18)
    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(ctx, nvgRGBA(210, 200, 170, 180))
    nvgText(ctx, x + 16, y + 22, b.title)

    if b.id == "supermarket" then
        drawStreetFurnitureImage(
            ctx,
            roomDecorImgs.streetSupermarketFurniture,
            x,
            y,
            w,
            h,
            { 25, 96, 744, 390 }
        )
    elseif b.id == "warehouse" then
        drawStreetFurnitureImage(
            ctx,
            roomDecorImgs.streetWarehouseFurniture,
            x,
            y,
            w,
            h,
            { 10, 111, 764, 405 }
        )
    elseif b.id == "pharmacy" then
        drawStreetFurnitureImage(
            ctx,
            roomDecorImgs.streetPharmacyFurniture,
            x,
            y,
            w,
            h,
            { 22, 104, 755, 400 }
        )
    end

    local lightKey = "street_" .. b.id
    -- 开关紧贴街边建筑入口门的内侧，只保留12像素操作间距。
    local switchSX = x + math.max(30, math.min(w - 28, b.doorX + 12))
    local switchSY = y + h - b.doorH + math.floor(b.doorH * 0.50)

    if isRoomLightOn(lightKey) then
        nvgGlobalCompositeOperation(ctx, NVG_LIGHTER)
        local lampGlow = nvgRadialGradient(ctx, x + w * 0.5, y + 20, 20, math.max(w, h) * 0.75,
            nvgRGBA(255, 230, 170, 115), nvgRGBA(0, 0, 0, 0))
        nvgBeginPath(ctx)
        nvgRect(ctx, x, y, w, h)
        nvgFillPaint(ctx, lampGlow)
        nvgFill(ctx)
        nvgGlobalCompositeOperation(ctx, NVG_SOURCE_OVER)
    else
        drawDarkRoomOverlay(ctx, x, y, w, h, false, playerSX, playerSY)
    end

    registerLightSwitch(ctx, lightKey, switchSX, switchSY, switchSX + cameraX, x + cameraX, x + w + cameraX, y, h, 76, 82)

    if isRoomLightOn(lightKey) then
        for _, spot in ipairs(b.lootSpots or {}) do
            drawStreetBuildingSearchZone(ctx, playerSX, playerSY, x, y, w, h, spot)
        end
    end
    nvgRestore(ctx)
end

function drawStreetEnterableBuildings(ctx, groundY)
    for _, b in ipairs(streetBuildings) do
        drawOneBuilding(ctx, b)
        if isPlayerInsideStreetBuilding(b) then
            drawStreetBuildingInterior(ctx, b, groundY)
        end

        local doorSX = b.x + b.doorX - cameraX
        local doorY = groundY - b.doorH
        local isNear = playerNearStreetBuilding == b
        if isNear then
            local pulse = math.sin(gameTime * 5) * 0.5 + 0.5
            nvgBeginPath(ctx)
            nvgRoundedRect(ctx, doorSX - 40, doorY - 36, 80, 28, 6)
            nvgFillColor(ctx, nvgRGBA(0, 0, 0, math.floor(150 + pulse * 60)))
            nvgFill(ctx)
            nvgStrokeColor(ctx, nvgRGBA(255, 230, 120, math.floor(160 + pulse * 80)))
            nvgStrokeWidth(ctx, 1.5)
            nvgStroke(ctx)
            nvgFontFace(ctx, "sans")
            nvgFontSize(ctx, 13)
            nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(ctx, nvgRGBA(255, 230, 120, 240))
            nvgText(ctx, doorSX, doorY - 22, b.doorOpen and "点门离开" or "点门进入")
        end
    end
end


-- ============================================================================
-- 环境粒子
-- ============================================================================
local function initParticles()
    dustParticles = {}
    for _ = 1, 35 do
        table.insert(dustParticles, {
            x = math.random() * W * 2,
            y = math.random() * H,
            size = 1 + math.random() * 2.5,
            sx = -6 - math.random() * 12,
            sy = -1.5 + math.random() * 3,
            alpha = 15 + math.random() * 35,
        })
    end
    fallingDebris = {}
    for _ = 1, 12 do
        table.insert(fallingDebris, {
            x = math.random() * W * 2,
            y = -math.random() * H,
            size = 2 + math.random() * 3,
            sx = -3 + math.random() * 6,
            sy = 12 + math.random() * 20,
            rot = math.random() * math.pi * 2,
            rs = (math.random() - 0.5) * 2.5,
            alpha = 25 + math.random() * 40,
        })
    end
end

-- ============================================================================
-- 绘制：天空
-- ============================================================================
local function drawSky(ctx)
    local skyH = H * GROUND_Y_RATIO
    -- oy = 屏幕顶部在世界坐标中的 Y（补偿 cameraY 全局偏移）
    local oy = -cameraY
    -- 根据 SCENE_ZOOM 动态计算可见范围，避免两侧出现空白
    local visLeft = W * 0.5 * (1 - 1 / SCENE_ZOOM)
    local visW    = W / SCENE_ZOOM

    local grad = nvgLinearGradient(ctx, 0, oy, 0, oy + skyH, rgba(C.skyTop), rgba(C.skyBot))
    nvgBeginPath(ctx)
    nvgRect(ctx, visLeft, oy - 500, visW, skyH + 1000)
    nvgFillPaint(ctx, grad)
    nvgFill(ctx)

    -- 天空顶部薄雾
    local fogTop = nvgLinearGradient(ctx, 0, oy, 0, oy + H * 0.12,
        nvgRGBA(18, 14, 22, 70), nvgRGBA(18, 14, 22, 0))
    nvgBeginPath(ctx)
    nvgRect(ctx, visLeft, oy, visW, H * 0.12)
    nvgFillPaint(ctx, fogTop)
    nvgFill(ctx)

    -- 末日余晖光晕
    local gx = W * 0.65
    local gy = skyH * 0.35
    local glow = nvgRadialGradient(ctx, gx, gy, 5, W * 0.45,
        nvgRGBA(150, 65, 18, 30), nvgRGBA(150, 65, 18, 0))
    nvgBeginPath(ctx)
    nvgCircle(ctx, gx, gy, W * 0.45)
    nvgFillPaint(ctx, glow)
    nvgFill(ctx)
end

-- ============================================================================
-- 绘制：云
-- ============================================================================
local function drawClouds(ctx)
    local data = {
        { x = 50,  y = H*0.06,  w = 180, h = 35, s = 2.5 },
        { x = 220, y = H*0.10,  w = 130, h = 28, s = 4 },
        { x = 380, y = H*0.04,  w = 160, h = 32, s = 1.8 },
        { x = 120, y = H*0.14,  w = 100, h = 22, s = 3.5 },
    }
    for _, c in ipairs(data) do
        local cx = (c.x + gameTime * c.s) % (W + c.w + 80) - c.w - 40
        nvgBeginPath(ctx)
        nvgEllipse(ctx, cx, c.y, c.w * 0.5, c.h * 0.5)
        nvgFillColor(ctx, rgba(C.cloudDk))
        nvgFill(ctx)
        nvgBeginPath(ctx)
        nvgEllipse(ctx, cx + c.w * 0.08, c.y - c.h * 0.12, c.w * 0.38, c.h * 0.32)
        nvgFillColor(ctx, rgba(C.cloud))
        nvgFill(ctx)
    end
end

-- ============================================================================
-- 绘制：远景剪影（多层城市天际线，参考像素风末世城市）
-- ============================================================================
local function drawDistant(ctx)
    local baseY = H * GROUND_Y_RATIO
    -- 三层远景：最远(淡) → 中间 → 最近(深)
    -- 每层有不同的视差系数、颜色深度和建筑风格

    -- ── 第1层：最远（淡蓝灰色，大轮廓，几乎看不清细节）──
    local skyH = baseY  -- 天空总高度
    local px1 = cameraX * 0.04
    math.randomseed(101)
    for i = 1, 18 do
        local bx = i * 150 - px1 - 200
        local bw = 90 + math.random() * 140
        local bh = skyH * (0.45 + math.random() * 0.5)
        if bx + bw > -50 and bx < W + 50 then
            nvgBeginPath(ctx)
            -- 部分建筑有尖顶/天线
            local topStyle = math.random(1, 5)
            if topStyle == 1 then
                -- 天线尖顶
                local antennaX = bx + bw * 0.5
                nvgRect(ctx, bx, baseY - bh, bw, bh)
                nvgRect(ctx, antennaX - 1.5, baseY - bh - 25, 3, 25)
            elseif topStyle == 2 then
                -- 梯形顶（宽底窄顶）
                nvgMoveTo(ctx, bx, baseY)
                nvgLineTo(ctx, bx, baseY - bh)
                nvgLineTo(ctx, bx + bw * 0.2, baseY - bh - 20)
                nvgLineTo(ctx, bx + bw * 0.8, baseY - bh - 20)
                nvgLineTo(ctx, bx + bw, baseY - bh)
                nvgLineTo(ctx, bx + bw, baseY)
                nvgClosePath(ctx)
            elseif topStyle == 3 then
                -- 阶梯顶（左高右低）
                nvgMoveTo(ctx, bx, baseY)
                nvgLineTo(ctx, bx, baseY - bh)
                nvgLineTo(ctx, bx + bw * 0.6, baseY - bh)
                nvgLineTo(ctx, bx + bw * 0.6, baseY - bh + 25)
                nvgLineTo(ctx, bx + bw, baseY - bh + 25)
                nvgLineTo(ctx, bx + bw, baseY)
                nvgClosePath(ctx)
            else
                -- 普通矩形
                nvgRect(ctx, bx, baseY - bh, bw, bh)
            end
            nvgFillColor(ctx, nvgRGBA(45, 55, 80, 140))
            nvgFill(ctx)
        end
    end

    -- ── 第2层：中间层（蓝灰偏暗，中等细节）──
    local px2 = cameraX * 0.08
    math.randomseed(202)
    for i = 1, 20 do
        local bx = i * 130 - px2 - 150
        local bw = 70 + math.random() * 120
        local bh = skyH * (0.35 + math.random() * 0.55)
        if bx + bw > -50 and bx < W + 50 then
            nvgBeginPath(ctx)
            local topStyle = math.random(1, 6)
            if topStyle == 1 then
                -- 双天线
                nvgRect(ctx, bx, baseY - bh, bw, bh)
                nvgRect(ctx, bx + bw * 0.3, baseY - bh - 18, 2, 18)
                nvgRect(ctx, bx + bw * 0.7, baseY - bh - 12, 2, 12)
            elseif topStyle == 2 then
                -- 水塔/圆顶装饰
                nvgRect(ctx, bx, baseY - bh, bw, bh)
                nvgCircle(ctx, bx + bw * 0.5, baseY - bh - 5, 8)
            elseif topStyle == 3 then
                -- 不规则阶梯
                local step1 = bh * 0.7
                local step2 = bh
                nvgMoveTo(ctx, bx, baseY)
                nvgLineTo(ctx, bx, baseY - step1)
                nvgLineTo(ctx, bx + bw * 0.45, baseY - step1)
                nvgLineTo(ctx, bx + bw * 0.45, baseY - step2)
                nvgLineTo(ctx, bx + bw, baseY - step2)
                nvgLineTo(ctx, bx + bw, baseY)
                nvgClosePath(ctx)
            elseif topStyle == 4 then
                -- 宽矮 + 窄塔
                nvgRect(ctx, bx, baseY - bh * 0.5, bw, bh * 0.5)
                local towerW = bw * 0.35
                nvgRect(ctx, bx + (bw - towerW) * 0.5, baseY - bh, towerW, bh)
            else
                nvgRect(ctx, bx, baseY - bh, bw, bh)
            end
            nvgFillColor(ctx, nvgRGBA(32, 40, 62, 180))
            nvgFill(ctx)
        end
    end

    -- ── 第3层：最近（深蓝黑色，较高对比度）──
    local px3 = cameraX * 0.13
    math.randomseed(303)
    for i = 1, 16 do
        local bx = i * 145 - px3 - 100
        local bw = 80 + math.random() * 110
        local bh = skyH * (0.25 + math.random() * 0.45)
        if bx + bw > -50 and bx < W + 50 then
            nvgBeginPath(ctx)
            local topStyle = math.random(1, 5)
            if topStyle == 1 then
                -- 带空调外机突起
                nvgRect(ctx, bx, baseY - bh, bw, bh)
                nvgRect(ctx, bx + bw, baseY - bh * 0.6, 6, 10)
                nvgRect(ctx, bx + bw, baseY - bh * 0.35, 6, 10)
            elseif topStyle == 2 then
                -- 倾斜屋顶
                nvgMoveTo(ctx, bx, baseY)
                nvgLineTo(ctx, bx, baseY - bh)
                nvgLineTo(ctx, bx + bw, baseY - bh + 15)
                nvgLineTo(ctx, bx + bw, baseY)
                nvgClosePath(ctx)
            elseif topStyle == 3 then
                -- 多层阶梯退缩
                local w1, w2 = bw, bw * 0.7
                local h1, h2 = bh * 0.6, bh
                nvgMoveTo(ctx, bx, baseY)
                nvgLineTo(ctx, bx, baseY - h1)
                nvgLineTo(ctx, bx + (w1 - w2) * 0.5, baseY - h1)
                nvgLineTo(ctx, bx + (w1 - w2) * 0.5, baseY - h2)
                nvgLineTo(ctx, bx + (w1 + w2) * 0.5, baseY - h2)
                nvgLineTo(ctx, bx + (w1 + w2) * 0.5, baseY - h1)
                nvgLineTo(ctx, bx + w1, baseY - h1)
                nvgLineTo(ctx, bx + w1, baseY)
                nvgClosePath(ctx)
            else
                nvgRect(ctx, bx, baseY - bh, bw, bh)
            end
            nvgFillColor(ctx, nvgRGBA(20, 25, 42, 210))
            nvgFill(ctx)

            -- 少量窗户亮光点缀（最近层可见）
            if bh > 100 and math.random() > 0.5 then
                local cols = math.floor(bw / 18)
                local rows = math.floor(bh / 25)
                for row = 0, math.min(rows - 1, 6) do
                    for col = 0, math.min(cols - 1, 3) do
                        if math.random() > 0.7 then
                            local wx = bx + 8 + col * 16
                            local wy = baseY - bh + 15 + row * 22
                            nvgBeginPath(ctx)
                            nvgRect(ctx, wx, wy, 6, 8)
                            local bright = math.random(20, 50)
                            nvgFillColor(ctx, nvgRGBA(60, 70, bright + 80, bright + 40))
                            nvgFill(ctx)
                        end
                    end
                end
            end
        end
    end

    math.randomseed(os.time())
end

-- ============================================================================
-- 绘制：一栋建筑
-- ============================================================================
drawOneBuilding = function(ctx, b)
    -- 横版风格：建筑无X透视压缩，直接1:1随相机滚动
    local screenGroundY = H * GROUND_Y_RATIO
    local screenBX = b.x - cameraX  -- 无透视压缩

    -- 房屋不做离屏懒绘制；所有建筑始终参与场景绘制。

    -- 用 nvgSave/Translate 做坐标偏移，保持原始尺寸（不缩放）
    nvgSave(ctx)
    nvgTranslate(ctx, screenBX - b.x, screenGroundY - b.h)
    -- 以下坐标全部是原始像素坐标，无缩放
    local groundY = b.h   -- 在局部坐标系中，groundY 就是 b.h（底部）
    local bx = b.x        -- 建筑左边X（局部坐标）
    local bw = b.w
    local bh = b.h
    local by = 0          -- 屋顶Y（局部坐标，0=建筑顶）
    local t = b.type
    local OL = 2.5  -- 描边粗细

    -- ========== 墙体 ==========
    nvgBeginPath(ctx)
    nvgRect(ctx, bx, by, bw, bh)
    nvgFillColor(ctx, rgba(t.wallColor))
    nvgFill(ctx)
    -- 墙体底部渐变（脏旧感加重）
    local dirtGrad = nvgLinearGradient(ctx, 0, groundY - 120, 0, groundY,
        nvgRGBA(0, 0, 0, 0), nvgRGBA(5, 3, 0, 90))
    nvgBeginPath(ctx)
    nvgRect(ctx, bx, groundY - 120, bw, 120)
    nvgFillPaint(ctx, dirtGrad)
    nvgFill(ctx)
    -- 末世做旧：血迹/污渍/裂纹/弹孔（基于位置生成伪随机）
    nvgSave(ctx)
    local wallSeedBase = math.floor(bx * 0.1) * 7 + math.floor(by * 0.1) * 13
    -- 不规则脏污（多个重叠圆形模拟自然渗透）
    for i = 0, 3 do
        local s = (wallSeedBase + i * 31) % 160
        local cx2 = bx + (s / 160) * (bw - 20) + 10
        local cy2 = by + bh * 0.3 + (s % 70)
        local alpha = 25 + (s % 30)
        -- 每团污渍由3-5个不规则圆组成
        for j = 0, 2 + (s % 3) do
            local jj = (s + j * 17) % 60
            local ox = (jj % 12) - 6
            local oy = (jj % 10) - 5
            local rr = 4 + (jj % 7)
            nvgBeginPath(ctx)
            nvgCircle(ctx, cx2 + ox, cy2 + oy, rr)
            nvgFillColor(ctx, nvgRGBA(18, 12, 6, alpha - j * 4))
            nvgFill(ctx)
        end
    end
    -- 血迹飞溅（明显的暗红色）
    local bloodSeed = (wallSeedBase + 99) % 200
    if bloodSeed < 120 then
        local bldX = bx + (bloodSeed / 120) * (bw - 20) + 10
        local bldY = by + bh * 0.15 + (bloodSeed % 60)
        -- 主血迹椭圆
        nvgBeginPath(ctx)
        nvgEllipse(ctx, bldX, bldY, 8 + bloodSeed % 10, 5 + bloodSeed % 6)
        nvgFillColor(ctx, nvgRGBA(80, 15, 10, 80 + bloodSeed % 40))
        nvgFill(ctx)
        -- 血迹往下淌
        local dripH = 20 + bloodSeed % 30
        local dripGrad = nvgLinearGradient(ctx, 0, bldY, 0, bldY + dripH,
            nvgRGBA(70, 12, 8, 70), nvgRGBA(50, 8, 5, 0))
        nvgBeginPath(ctx)
        nvgRect(ctx, bldX - 1.5, bldY, 3, dripH)
        nvgFillPaint(ctx, dripGrad)
        nvgFill(ctx)
        -- 溅射小点
        for j = 0, 3 do
            local sp = (bloodSeed + j * 19) % 80
            local spX = bldX + (sp % 20) - 10
            local spY = bldY + (sp % 15) - 7
            nvgBeginPath(ctx)
            nvgCircle(ctx, spX, spY, 1.5 + sp % 2)
            nvgFillColor(ctx, nvgRGBA(90, 20, 12, 60 + sp % 30))
            nvgFill(ctx)
        end
    end
    -- 血手印（部分墙面出现）
    local handSeed = (wallSeedBase + 47) % 250
    if handSeed < 50 then
        local hx = bx + (handSeed / 50) * (bw - 25) + 5
        local hy = by + bh * 0.4 + (handSeed % 30)
        -- 简化手印：掌心+5个手指印
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, hx, hy, 12, 14, 3)
        nvgFillColor(ctx, nvgRGBA(75, 15, 10, 55))
        nvgFill(ctx)
        for f = 0, 3 do
            nvgBeginPath(ctx)
            nvgRoundedRect(ctx, hx + 1 + f * 3, hy - 6 - (f % 2) * 2, 2.5, 7, 1)
            nvgFillColor(ctx, nvgRGBA(70, 12, 8, 45))
            nvgFill(ctx)
        end
    end
    -- 裂纹线条（更粗更明显）
    local crackSeed = (wallSeedBase + 77) % 100
    if crackSeed < 55 then
        local cx = bx + (crackSeed / 55) * bw * 0.7 + bw * 0.15
        local cy = by + bh * 0.15 + (crackSeed % 25)
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, cx, cy)
        nvgLineTo(ctx, cx + 6 + crackSeed % 10, cy + 15 + crackSeed % 12)
        nvgLineTo(ctx, cx + 3 + crackSeed % 6, cy + 30 + crackSeed % 20)
        nvgLineTo(ctx, cx + 8 + crackSeed % 7, cy + 45 + crackSeed % 15)
        nvgStrokeColor(ctx, nvgRGBA(0, 0, 0, 55 + crackSeed % 25))
        nvgStrokeWidth(ctx, 1.2)
        nvgStroke(ctx)
        -- 裂纹分叉
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, cx + 6 + crackSeed % 10, cy + 15 + crackSeed % 12)
        nvgLineTo(ctx, cx + 14 + crackSeed % 8, cy + 22 + crackSeed % 10)
        nvgStrokeColor(ctx, nvgRGBA(0, 0, 0, 40 + crackSeed % 20))
        nvgStrokeWidth(ctx, 0.8)
        nvgStroke(ctx)
    end
    -- 弹孔（小圆+放射裂纹）
    local bulletSeed = (wallSeedBase + 137) % 180
    if bulletSeed < 70 then
        local bhX = bx + (bulletSeed / 70) * (bw - 10) + 5
        local bhY = by + bh * 0.3 + (bulletSeed % 50)
        nvgBeginPath(ctx)
        nvgCircle(ctx, bhX, bhY, 2.5)
        nvgFillColor(ctx, nvgRGBA(5, 5, 5, 150))
        nvgFill(ctx)
        -- 放射裂纹
        for r2 = 0, 3 do
            local angle = (r2 * 1.57) + (bulletSeed % 10) * 0.1
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, bhX + math.cos(angle) * 2.5, bhY + math.sin(angle) * 2.5)
            nvgLineTo(ctx, bhX + math.cos(angle) * (6 + r2 * 2), bhY + math.sin(angle) * (6 + r2 * 2))
            nvgStrokeColor(ctx, nvgRGBA(0, 0, 0, 50))
            nvgStrokeWidth(ctx, 0.6)
            nvgStroke(ctx)
        end
    end
    nvgRestore(ctx)

    -- ========== 屋顶 ==========
    local roofH = 20
    nvgBeginPath(ctx)
    nvgRect(ctx, bx - 6, by - roofH, bw + 12, roofH)
    nvgFillColor(ctx, rgba(t.roofColor))
    nvgFill(ctx)
    nvgStrokeColor(ctx, rgba(C.outline))
    nvgStrokeWidth(ctx, OL)
    nvgStroke(ctx)
    -- 屋顶装饰线
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, bx - 6, by)
    nvgLineTo(ctx, bx + bw + 6, by)
    nvgStrokeColor(ctx, rgba(C.outline))
    nvgStrokeWidth(ctx, OL)
    nvgStroke(ctx)

    -- ========== 招牌 ==========
    if t.sign then
        local signW = math.min(bw * 0.65, 240)
        local signH = 40
        local signX = bx + (bw - signW) / 2
        local signY = by + 16
        -- 招牌底板
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, signX, signY, signW, signH, 5)
        nvgFillColor(ctx, rgba(C.signBg))
        nvgFill(ctx)
        nvgStrokeColor(ctx, rgba(C.outline))
        nvgStrokeWidth(ctx, 2)
        nvgStroke(ctx)
        -- 招牌文字
        nvgFontFace(ctx, "sans")
        nvgFontSize(ctx, 22)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(ctx, rgba(C.signText))
        nvgText(ctx, signX + signW / 2, signY + signH / 2, t.sign, nil)

        -- 招牌上方颜色条
        if t.signColor then
            nvgBeginPath(ctx)
            nvgRect(ctx, signX, signY, signW, 6)
            nvgFillColor(ctx, nvgRGBA(t.signColor[1], t.signColor[2], t.signColor[3], 180))
            nvgFill(ctx)
        end
    end

    -- ========== 雨棚 ==========
    if t.hasAwning then
        local awnY = groundY - b.doorH - 30
        local awnH = 24
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, bx, awnY)
        nvgLineTo(ctx, bx + bw, awnY)
        nvgLineTo(ctx, bx + bw + 10, awnY + awnH)
        nvgLineTo(ctx, bx - 10, awnY + awnH)
        nvgClosePath(ctx)
        nvgFillColor(ctx, nvgRGBA(t.awningColor[1], t.awningColor[2], t.awningColor[3], 200))
        nvgFill(ctx)
        nvgStrokeColor(ctx, rgba(C.outline))
        nvgStrokeWidth(ctx, 2)
        nvgStroke(ctx)
        -- 雨棚条纹
        local stripeCount = math.floor(bw / 28)
        for s = 1, stripeCount do
            local sx = bx + s * (bw / (stripeCount + 1))
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, sx, awnY)
            nvgLineTo(ctx, sx + 3, awnY + awnH)
            nvgStrokeColor(ctx, nvgRGBA(255, 255, 255, 25))
            nvgStrokeWidth(ctx, 5)
            nvgStroke(ctx)
        end
    end

    -- ========== 窗户 ==========
    local signEndY = by + (t.sign and 38 or 14)  -- 招牌下方开始放窗

    if t.windowStyle == "large" then
        -- 大橱窗（店铺一楼）
        local winPad = 30
        local winX = bx + winPad
        local winW2 = bw - winPad * 2 - b.doorW - 20
        local winY = groundY - b.doorH - 15
        local winH2 = b.doorH - 20
        if winW2 > 40 then
            nvgBeginPath(ctx)
            nvgRect(ctx, winX, winY, winW2, winH2)
            if isRoomLightOn("street_" .. b.id) then
                nvgFillColor(ctx, nvgRGBA(C.winGlow[1], C.winGlow[2], C.winGlow[3],
                    70 + math.floor(math.sin(gameTime * 1.5 + b.x) * 20)))
                nvgFill(ctx)
                local glow = nvgRadialGradient(ctx, winX + winW2/2, winY + winH2/2, 10, 70,
                    nvgRGBA(C.winGlow[1], C.winGlow[2], C.winGlow[3], 20),
                    nvgRGBA(C.winGlow[1], C.winGlow[2], C.winGlow[3], 0))
                nvgBeginPath(ctx)
                nvgCircle(ctx, winX + winW2/2, winY + winH2/2, 70)
                nvgFillPaint(ctx, glow)
                nvgFill(ctx)
            else
                nvgFillColor(ctx, rgba(C.winDark))
                nvgFill(ctx)
            end
            nvgBeginPath(ctx)
            nvgRect(ctx, winX, winY, winW2, winH2)
            nvgStrokeColor(ctx, rgba(C.outline))
            nvgStrokeWidth(ctx, 2.0)
            nvgStroke(ctx)
            -- 橱窗中线
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, winX + winW2 / 2, winY)
            nvgLineTo(ctx, winX + winW2 / 2, winY + winH2)
            nvgStrokeColor(ctx, nvgRGBA(C.outline[1], C.outline[2], C.outline[3], 100))
            nvgStrokeWidth(ctx, 1.5)
            nvgStroke(ctx)
            -- 碎玻璃裂纹
            if b.brokenGlass then
                nvgStrokeColor(ctx, nvgRGBA(180, 190, 200, 50))
                nvgStrokeWidth(ctx, 1.2)
                local cx2 = winX + winW2 * 0.3
                local cy = winY + winH2 * 0.4
                for r = 1, 6 do
                    local angle = r * 1.1
                    nvgBeginPath(ctx)
                    nvgMoveTo(ctx, cx2, cy)
                    nvgLineTo(ctx, cx2 + math.cos(angle) * 35, cy + math.sin(angle) * 28)
                    nvgStroke(ctx)
                end
            end
        end
    elseif t.windowStyle == "shutter" then
        -- 卷帘门样式
        local shutY = groundY - b.doorH - 10
        local shutH = b.doorH
        local shutX = bx + 25
        local shutW = bw - 50 - b.doorW - 15
        if shutW > 30 then
            nvgBeginPath(ctx)
            nvgRect(ctx, shutX, shutY, shutW, shutH)
            nvgFillColor(ctx, nvgRGBA(65, 60, 58, 230))
            nvgFill(ctx)
            nvgStrokeColor(ctx, rgba(C.outline))
            nvgStrokeWidth(ctx, 2)
            nvgStroke(ctx)
            -- 卷帘纹
            for sl = 1, math.floor(shutH / 10) do
                nvgBeginPath(ctx)
                nvgMoveTo(ctx, shutX, shutY + sl * 10)
                nvgLineTo(ctx, shutX + shutW, shutY + sl * 10)
                nvgStrokeColor(ctx, nvgRGBA(C.outline[1], C.outline[2], C.outline[3], 40))
                nvgStrokeWidth(ctx, 1)
                nvgStroke(ctx)
            end
        end
    else
        -- 普通窗户（多层楼房）
        local winW3 = 42
        local winH3 = 55
        local padX = 35
        local padY = 30
        for f = 0, b.floors - 1 do
            local floorTop = by + f * b.floorH
            local wy = floorTop + padY + (f == 0 and 40 or 0)
            local wx = bx + padX
            while wx + winW3 < bx + bw - padX do
                -- 跳过门的位置（一楼）
                if f == b.floors - 1 then
                    local doorScreenX = bx + b.doorX - b.doorW/2
                    if wx + winW3 > doorScreenX - 10 and wx < doorScreenX + b.doorW + 10 then
                        wx = wx + winW3 + padX
                        goto nextWin
                    end
                end

                nvgBeginPath(ctx)
                nvgRect(ctx, wx, wy, winW3, winH3)
                local isLit = isRoomLightOn("street_" .. b.id) and f == 0 and wx < bx + bw * 0.4
                if isLit then
                    nvgFillColor(ctx, nvgRGBA(C.winGlow[1], C.winGlow[2], C.winGlow[3],
                        80 + math.floor(math.sin(gameTime * 2 + wx) * 25)))
                else
                    nvgFillColor(ctx, rgba(C.winDark))
                end
                nvgFill(ctx)
                nvgBeginPath(ctx)
                nvgRect(ctx, wx, wy, winW3, winH3)
                nvgStrokeColor(ctx, rgba(C.outline))
                nvgStrokeWidth(ctx, 2)
                nvgStroke(ctx)
                -- 十字窗格
                nvgBeginPath(ctx)
                nvgMoveTo(ctx, wx + winW3/2, wy)
                nvgLineTo(ctx, wx + winW3/2, wy + winH3)
                nvgMoveTo(ctx, wx, wy + winH3/2)
                nvgLineTo(ctx, wx + winW3, wy + winH3/2)
                nvgStrokeColor(ctx, nvgRGBA(C.outline[1], C.outline[2], C.outline[3], 80))
                nvgStrokeWidth(ctx, 1.2)
                nvgStroke(ctx)

                wx = wx + winW3 + padX
                ::nextWin::
            end
        end
    end

    -- ========== 门 ==========
    local doorScreenX = bx + b.doorX - b.doorW / 2
    local doorY = groundY - b.doorH
    -- 门框
    nvgBeginPath(ctx)
    nvgRect(ctx, doorScreenX - 5, doorY - 5, b.doorW + 10, b.doorH + 5)
    nvgFillColor(ctx, rgba(C.doorFrame))
    nvgFill(ctx)
    nvgStrokeColor(ctx, rgba(C.outline))
    nvgStrokeWidth(ctx, OL)
    nvgStroke(ctx)
    -- 门板
    if b.doorOpen then
        -- 门开着 - 里面是黑暗的
        nvgBeginPath(ctx)
        nvgRect(ctx, doorScreenX, doorY, b.doorW, b.doorH)
        nvgFillColor(ctx, nvgRGBA(8, 6, 10, 240))
        nvgFill(ctx)
        -- 半开的门板（透视）
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, doorScreenX, doorY)
        nvgLineTo(ctx, doorScreenX + 14, doorY + 3)
        nvgLineTo(ctx, doorScreenX + 14, doorY + b.doorH - 3)
        nvgLineTo(ctx, doorScreenX, doorY + b.doorH)
        nvgClosePath(ctx)
        nvgFillColor(ctx, rgba(C.door))
        nvgFill(ctx)
        nvgStrokeColor(ctx, rgba(C.outline))
        nvgStrokeWidth(ctx, 1.8)
        nvgStroke(ctx)
    else
        nvgBeginPath(ctx)
        nvgRect(ctx, doorScreenX, doorY, b.doorW, b.doorH)
        nvgFillColor(ctx, rgba(C.door))
        nvgFill(ctx)
        nvgStrokeColor(ctx, rgba(C.outline))
        nvgStrokeWidth(ctx, 2.0)
        nvgStroke(ctx)
        -- 门中线
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, doorScreenX + b.doorW/2, doorY)
        nvgLineTo(ctx, doorScreenX + b.doorW/2, doorY + b.doorH)
        nvgStrokeColor(ctx, nvgRGBA(C.outline[1], C.outline[2], C.outline[3], 80))
        nvgStrokeWidth(ctx, 1.5)
        nvgStroke(ctx)
        -- 门把手
        nvgBeginPath(ctx)
        nvgCircle(ctx, doorScreenX + b.doorW * 0.7, doorY + b.doorH * 0.5, 4.5)
        nvgFillColor(ctx, rgba(C.doorKnob))
        nvgFill(ctx)
        nvgStrokeColor(ctx, rgba(C.outline))
        nvgStrokeWidth(ctx, 1.5)
        nvgStroke(ctx)
    end

    -- ========== 台阶 ==========
    nvgBeginPath(ctx)
    nvgRect(ctx, doorScreenX - 8, groundY - 7, b.doorW + 16, 7)
    nvgFillColor(ctx, rgba(C.sidewalk))
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(C.outline[1], C.outline[2], C.outline[3], 80))
    nvgStrokeWidth(ctx, 1.2)
    nvgStroke(ctx)

    -- ========== 裂缝 ==========
    for _, cr in ipairs(b.cracks) do
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, bx + cr.x1, by + cr.y1)
        nvgLineTo(ctx, bx + cr.x1 + cr.dx * 0.4, by + cr.y1 + cr.dy * 0.5)
        nvgLineTo(ctx, bx + cr.x1 + cr.dx, by + cr.y1 + cr.dy)
        nvgStrokeColor(ctx, nvgRGBA(C.outline[1], C.outline[2], C.outline[3], 90))
        nvgStrokeWidth(ctx, 1.8)
        nvgStroke(ctx)
    end

    -- ========== 整体描边 ==========
    nvgBeginPath(ctx)
    nvgRect(ctx, bx, by, bw, bh)
    nvgStrokeColor(ctx, rgba(C.outline))
    nvgStrokeWidth(ctx, OL)
    nvgStroke(ctx)

    -- ========== 楼层分隔线（多层时）==========
    if b.floors > 1 then
        for f = 1, b.floors - 1 do
            local ly = by + f * b.floorH
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, bx, ly)
            nvgLineTo(ctx, bx + bw, ly)
            nvgStrokeColor(ctx, nvgRGBA(C.outline[1], C.outline[2], C.outline[3], 50))
            nvgStrokeWidth(ctx, 1)
            nvgStroke(ctx)
        end
    end

    nvgRestore(ctx)  -- 恢复透视缩放变换
end

-- ============================================================================
-- 剖面楼（Cross-Section Building）
-- ============================================================================

local CS_NUM_FLOORS = 5
-- 每层数据：
--   hRatio   = 层高倍率（相对 baseFloorH）
--   slabBelow= 该层底板厚度（像素）
--   divT     = 室内纵向隔墙粗细（像素）
--   divs     = 房间分隔点（0-1，每层不同以打破规律感）
--   rooms    = 背景色/纹理配置
local CS_FLOOR_DATA = {
    -- 5F：顶层；左侧为房间，右侧为天台（无背景）
    { hRatio=1.72, slabBelow=44, divT=90,
      divs={0.54}, rooms={
        { bg={68,105,148},  tex="hstripe", tcol={50,82,118},  ta=72 },
    }},
    -- 4F：三间，客厅加大
    { hRatio=1.72, slabBelow=56, divT=90,
      divs={0.24,0.72}, rooms={
        { bg={215,215,215}, tex="tile",    tcol={172,172,172}, ta=155 },
        { bg={170,155,135}, tex="hstripe", tcol={142,130,112}, ta=82  },
        { bg={165,152,133}, tex=nil },
    }},
    -- 3F：三间，客厅加大
    { hRatio=1.72, slabBelow=48, divT=90,
      divs={0.26,0.70}, rooms={
        { bg={215,215,215}, tex="tile",    tcol={172,172,172}, ta=155 },
        { bg={80,112,145},  tex="hstripe", tcol={60,88,118},   ta=82  },
        { bg={165,152,133}, tex=nil },
    }},
    -- 2F：三间，客厅加大
    { hRatio=1.72, slabBelow=64, divT=90,
      divs={0.22,0.68}, rooms={
        { bg={75,105,148},  tex="tile",    tcol={55,82,118},   ta=148 },
        { bg={170,155,135}, tex="hstripe", tcol={142,130,112}, ta=82  },
        { bg={165,152,133}, tex=nil },
    }},
    -- 1F：最高（底层层高大）；三间，客厅加大
    { hRatio=1.72, slabBelow=60, divT=90,
      divs={0.30,0.66}, rooms={
        { bg={148,122,88},  tex="concrete", tcol={118,96,65},  ta=90  },  -- 杂货铺：暖棕混凝土
        { bg={108,30,32},   tex="hstripe",  tcol={85,22,25},   ta=82  },
        { bg={165,152,133}, tex=nil },
    }},
}
-- 地下室数据
local CS_BASEMENT_DATA = {
    divs = {0.22, 0.67},
    rooms = {
        { bg={158,152,138}, tex="concrete", tcol={118,114,102}, ta=80, stains=true },
        { bg={168,162,148}, tex="concrete", tcol={128,122,110}, ta=72, stains=true },
        { bg={150,145,132}, tex="concrete", tcol={112,108,96},  ta=85, stains=true },
    }
}
-- 楼在世界坐标中的 X 位置（固定旧位置，扩街道时不挪动主楼）
local csWldX = 1824
CS2_WLD_X = 6840
CS2_FLOOR_DATA = {
    { hRatio=1.54, slabBelow=46, divT=78,
      divs={0.46,0.72}, rooms={
        { bg={88,108,128},  tex="hstripe", tcol={64,82,102},  ta=70 },   -- 顶层卧室
        { bg={126,112,92},  tex="concrete", tcol={98,86,70},   ta=72 },   -- 储物间
        { bg={72,94,84},    tex="tile", tcol={55,72,64},       ta=110 },  -- 小阳台/洗衣区
    }},
    { hRatio=1.56, slabBelow=54, divT=78,
      divs={0.30,0.64}, rooms={
        { bg={206,206,198}, tex="tile", tcol={164,164,156},    ta=145 },  -- 卫生间
        { bg={150,132,108}, tex="hstripe", tcol={122,104,84},  ta=75 },   -- 客厅
        { bg={102,122,96},  tex="concrete", tcol={78,96,74},   ta=68 },   -- 书房
    }},
    { hRatio=1.56, slabBelow=58, divT=78,
      divs={0.34,0.68}, rooms={
        { bg={96,118,150},  tex="hstripe", tcol={72,92,120},   ta=74 },   -- 卧室
        { bg={150,132,108}, tex="hstripe", tcol={118,98,78},   ta=82 },   -- 餐厅
        { bg={185,178,158}, tex="tile", tcol={145,138,120},    ta=115 },  -- 厨房
    }},
    { hRatio=1.62, slabBelow=58, divT=78,
      divs={0.38,0.70}, rooms={
        { bg={118,92,72},   tex="concrete", tcol={92,70,54},   ta=80 },   -- 便利入口
        { bg={128,104,82},  tex="concrete", tcol={96,78,60},   ta=76 },   -- 管理室
        { bg={86,94,88},    tex="concrete", tcol={62,70,66},   ta=82 },   -- 维修间
    }},
}
CS2_BASEMENT_DATA = {
    divs = {0.25, 0.58},
    rooms = {
        { bg={124,128,120}, tex="concrete", tcol={86,92,86}, ta=95, stains=true },
        { bg={110,116,118}, tex="concrete", tcol={74,82,84}, ta=105, stains=true },
        { bg={96,104,102},  tex="concrete", tcol={66,74,72}, ta=115, stains=true },
    }
}
-- 第二栋楼家具 PNG 的实际可见底边比例，用于忽略透明留白并让家具脚部贴地。
CS2_FURNITURE_BOTTOM_RATIO = {
    cs2Bedroom = 0.867188,
    cs2Storage = 0.841797,
    cs2Laundry = 0.843750,
    cs2Bathroom = 0.849609,
    cs2Living = 0.767578,
    cs2Study = 0.869141,
    cs2BlueBedroom = 0.753906,
    cs2Dining = 0.687500,
    cs2Kitchen = 0.794922,
    cs2Shop = 0.779297,
    cs2Office = 0.779297,
    cs2Workshop = 0.880859,
}

-- 第二栋楼使用独立门状态，关闭时显示侧面厚度门图，打开时显示正面门图。
for fi = 1, #CS2_FLOOR_DATA do
    for di = 1, #(CS2_FLOOR_DATA[fi].divs or {}) do
        roomDoorStates["cs2_" .. fi .. "_" .. di] = { openProg = 0.0, target = 0 }
    end
end
for fi = 1, CS2_NUM_FLOORS do
    roomDoorStates["cs2_stair_" .. fi] = cs2StairDoorStates[fi]
    roomDoorStates["cs2_left_stair_" .. fi] = cs2LeftStairDoorStates[fi]
end
roomDoorStates["cs2_bas_1"] = { openProg = 0.0, target = 0 }
roomDoorStates["cs2_bas_2"] = { openProg = 0.0, target = 0 }

function setDefaultRoomLights()
    local firstFloorIndex = #CS_FLOOR_DATA
    local firstFloorRoomCount = #(CS_FLOOR_DATA[firstFloorIndex].rooms or {})
    for fi = 1, CS2_NUM_FLOORS do
        local rightState = cs2StairDoorStates[fi]
        local leftState = cs2LeftStairDoorStates[fi]
        if rightState then rightState.openProg = 0.0; rightState.target = 0 end
        if leftState then leftState.openProg = 0.0; leftState.target = 0 end
    end
    playerNearCS2StairDoorFi = 0
    cs2StairDoorWorldCXByFi = {}
    roomDoorStates["cs2_entry"].openProg = 0.0
    roomDoorStates["cs2_entry"].target = 0
    roomLightStates["cs_annex"] = true
    roomLightStates["cs2_light_" .. CS2_NUM_FLOORS .. "_1"] = true
    if firstFloorRoomCount >= 1 then
        roomLightStates["cs_" .. firstFloorIndex .. "_" .. firstFloorRoomCount] = true
    end
end

-- 供 drawGround 读取：楼在当前帧的屏幕边界（每帧由 drawCrossSection 更新）
-- basOverlay：地下室暗层遮罩参数，供 drawBasementOverlay 使用（在玩家之后绘制）
csInfo = { sx = -9999, sw = 0, basH = 0, sy = -9999, sh = 0,
    basOverlay = nil,    ---@type {innerL:number,innerR:number,basTop:number,basRoomH:number,bxs:table,brightnesses:table}|nil
    floorOverlays = {},  ---@type {x:number,y:number,w:number,h:number,rooms:{midX:number,brightness:number}[]}[]
}

-- 第二栋楼：复刻主楼剖面结构，但换成生活服务楼布局与水阀泵房地下室
function drawCS2FurnitureLootSpots(ctx, fi, ri, drawX, drawY, drawW, drawH)
    local spots = lootUI.cs2FurnitureLootSpots[tostring(fi) .. "_" .. tostring(ri)]
    if not spots then return end

    local lightKey = "cs2_light_" .. fi .. "_" .. ri
    if not isRoomLightOn(lightKey) then return end

    local playerSX = player.x - cameraX
    local playerSY = H * GROUND_Y_RATIO + player.jumpScrY
    for _, spot in ipairs(spots) do
        local chestIdx = lootUI.chestIndexByRoom[spot.room]
        if chestIdx then
            local hitX = drawX + drawW * spot.x
            local hitY = drawY + drawH * spot.y
            local hitW = drawW * spot.w
            local hitH = drawH * spot.h
            lootUI.CheckChestProximity(ctx, playerSX, playerSY, hitX, hitY, hitW, hitH, chestIdx, 70)
        end
    end
end

function drawCS2Furniture(ctx, fi, ri, rx, ry, rw, rh)
    local imageKey = nil
    if fi == 1 then
        imageKey = ({ "cs2Bedroom", "cs2Storage", "cs2Laundry" })[ri]
    elseif fi == 2 then
        imageKey = ({ "cs2Bathroom", "cs2Living", "cs2Study" })[ri]
    elseif fi == 3 then
        imageKey = ({ "cs2BlueBedroom", "cs2Dining", "cs2Kitchen" })[ri]
    elseif fi == 4 then
        imageKey = ({ "cs2Shop", "cs2Office", "cs2Workshop" })[ri]
    end

    local img = imageKey and roomDecorImgs[imageKey] or nil
    if not img or img <= 0 then
        return
    end

    -- 生成图四周带透明留白；用每张图实际可见的家具脚部对齐房间地面。
    local visibleBottom = CS2_FURNITURE_BOTTOM_RATIO[imageKey] or 1.0

    -- 家具由透明背景正视图片整体呈现，不再使用 NanoVG 基础图形拼画。
    local sourceRatio = 768 / 512
    local drawW = rw * 0.94
    local drawH = drawW / sourceRatio
    local maxH = rh * 0.92
    if drawH > maxH then
        drawH = maxH
        drawW = drawH * sourceRatio
    end

    local drawX = rx + (rw - drawW) * 0.5
    local drawY = ry + rh - drawH * visibleBottom
    local paint = nvgImagePattern(
        ctx,
        drawX,
        drawY,
        drawW,
        drawH,
        0,
        img,
        1.0
    )

    nvgBeginPath(ctx)
    nvgRect(ctx, drawX, drawY, drawW, drawH)
    nvgFillPaint(ctx, paint)
    nvgFill(ctx)

    -- 搜刮热区直接跟随这张家具组合图缩放，放大镜会落在对应柜体、抽屉或设备上。
    drawCS2FurnitureLootSpots(ctx, fi, ri, drawX, drawY, drawW, drawH)
end

function drawCS2StairDoor(ctx, fi, rx, floorTop, rw, fh, floorRelY, topRelY)
    local state = cs2StairDoorStates[fi]
    if not state then return end

    local doorH = math.floor(fh * 0.58)
    local doorW = math.floor(doorH * 0.60)
    local doorX = rx + math.floor(rw * 0.80) - math.floor(doorW * 0.5)
    local doorY = floorTop + fh - doorH - 2
    local doorCX = doorX + doorW * 0.5
    local doorWorldCX = doorCX + cameraX
    cs2StairDoorWorldCXByFi[fi] = doorWorldCX
    cs2StairDoorFloorRanges[fi] = {
        topY = topRelY,
        bottomY = floorRelY,
        landingY = floorRelY,
    }

    if state.openProg > 0.02 then
        nvgBeginPath(ctx)
        nvgRect(ctx, doorX, doorY, doorW, doorH)
        nvgFillColor(ctx, nvgRGBA(24, 22, 20, 245))
        nvgFill(ctx)
        local stairCount = 6
        local stepW = doorW / stairCount
        local stepH = doorH / stairCount
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, doorX + 3, doorY + stepH)
        for si = 0, stairCount - 1 do
            local stepX = doorX + 3 + si * stepW
            local stepY = doorY + (si + 1) * stepH
            nvgLineTo(ctx, stepX + stepW, stepY)
            if si < stairCount - 1 then
                nvgLineTo(ctx, stepX + stepW, stepY + stepH)
            end
        end
        nvgLineTo(ctx, doorX + doorW - 3, doorY + doorH - 3)
        nvgLineTo(ctx, doorX + 3, doorY + doorH - 3)
        nvgClosePath(ctx)
        nvgFillColor(ctx, nvgRGBA(58, 52, 46, math.floor(225 * state.openProg)))
        nvgFill(ctx)
    end

    local doorDrawH = doorH * 1.14
    local isOpen = state.openProg > 0.5
    local img = isOpen and roomDoorImg or roomDoorSideImg
    local doorDrawW = isOpen and doorDrawH * WOOD_DOOR_FRONT_RATIO or doorDrawH * (71 / 128)
    local dx = doorCX - doorDrawW * 0.5
    local dy = doorY - (doorDrawH - doorH) * 0.5
    if img and img > 0 then
        local paint = nvgImagePattern(ctx, dx, dy, doorDrawW, doorDrawH, 0, img, 1.0)
        nvgBeginPath(ctx)
        nvgRect(ctx, dx, dy, doorDrawW, doorDrawH)
        nvgFillPaint(ctx, paint)
        nvgFill(ctx)
    end

    local pY = player.jumpScrY
    local nearFloor = pY > topRelY and pY <= floorRelY + 6
    local isNear = nearFloor and math.abs(player.x - doorWorldCX) < 115
    if isNear then
        playerNearCS2StairDoorFi = fi
        local pulse = math.sin(gameTime * 4.5) * 0.25 + 0.75
        nvgFontFace(ctx, "sans")
        nvgFontSize(ctx, 14)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(ctx, nvgRGBA(255, 255, 255, math.floor(240 * pulse)))
        nvgText(ctx, doorCX, doorY - 13, "F")
    end
end

function drawCS2ExteriorLadderDoor(ctx, fi, sx, upW, wallT, floorTop, fh, floorRelY, topRelY)
    local rightState = cs2StairDoorStates[fi]
    local leftState = cs2LeftStairDoorStates[fi]
    if not rightState or not leftState then return end

    local doorH = math.floor(fh * 0.58)
    local doorW = math.floor(doorH * 0.60)
    local rightDoorCX = sx + upW - wallT * 0.5
    local rightDoorX = rightDoorCX - doorW * 0.5
    local leftDoorCX = sx + wallT * 0.5
    local leftDoorX = leftDoorCX - doorW * 0.5
    local doorY = floorTop + fh - doorH - 2
    local leftLadderCX = sx - 54
    local rightLadderCX = sx + upW + 54
    local doorWorldCenters = {
        left = leftDoorCX + cameraX,
        right = rightDoorCX + cameraX,
    }
    cs2StairDoorWorldCXByFi[fi] = doorWorldCenters
    cs2StairDoorFloorRanges[fi] = {
        topY = topRelY,
        bottomY = floorRelY,
        landingY = floorRelY,
    }

    local doorDrawH = doorH * 1.14
    local dy = doorY - (doorDrawH - doorH) * 0.5

    -- 每层左右外墙各有一扇门，分别连接同侧的大号梯子。
    local sideDoors = {
        { side = "left", state = leftState, doorCX = leftDoorCX, doorX = leftDoorX, ladderCX = leftLadderCX },
        { side = "right", state = rightState, doorCX = rightDoorCX, doorX = rightDoorX, ladderCX = rightLadderCX },
    }
    local pY = player.jumpScrY
    local nearFloor = pY > topRelY and pY <= floorRelY + 6
    for _, door in ipairs(sideDoors) do
        if door.state.openProg > 0.02 then
            nvgBeginPath(ctx)
            nvgRect(ctx, door.doorX, doorY, doorW, doorH)
            nvgFillColor(ctx, nvgRGBA(20, 19, 18, 250))
            nvgFill(ctx)
        end

        local isOpen = door.state.openProg > 0.5
        local img = isOpen and roomDoorImg or roomDoorSideImg
        local doorDrawW = isOpen and doorDrawH * WOOD_DOOR_FRONT_RATIO or doorDrawH * (71 / 128)
        local dx = door.doorCX - doorDrawW * 0.5
        if img and img > 0 then
            local paint = nvgImagePattern(ctx, dx, dy, doorDrawW, doorDrawH, 0, img, 1.0)
            nvgBeginPath(ctx)
            nvgRect(ctx, dx, dy, doorDrawW, doorDrawH)
            nvgFillPaint(ctx, paint)
            nvgFill(ctx)
        end

        local worldCX = doorWorldCenters[door.side]
        if nearFloor and math.abs(player.x - worldCX) < 105 then
            playerNearCS2StairDoorFi = fi
            playerNearCS2StairDoorSide = door.side
            local pulse = math.sin(gameTime * 4.5) * 0.25 + 0.75
            nvgFontFace(ctx, "sans")
            nvgFontSize(ctx, 14)
            nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(ctx, nvgRGBA(255, 255, 255, math.floor(240 * pulse)))
            nvgText(ctx, door.doorCX, doorY - 13, "F")
        end
    end

    -- 左右两侧分别铺设平台，不穿过建筑内部。
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, leftLadderCX + 32, doorY + doorH - 3)
    nvgLineTo(ctx, sx + wallT, doorY + doorH - 3)
    nvgLineTo(ctx, sx + wallT, doorY + doorH + 3)
    nvgLineTo(ctx, leftLadderCX + 32, doorY + doorH + 3)
    nvgClosePath(ctx)
    nvgFillColor(ctx, nvgRGBA(74, 78, 76, 245))
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(28, 32, 31, 235))
    nvgStrokeWidth(ctx, 1.5)
    nvgStroke(ctx)

    nvgBeginPath(ctx)
    nvgMoveTo(ctx, sx + upW - wallT, doorY + doorH - 3)
    nvgLineTo(ctx, rightLadderCX + 32, doorY + doorH - 3)
    nvgLineTo(ctx, rightLadderCX + 32, doorY + doorH + 3)
    nvgLineTo(ctx, sx + upW - wallT, doorY + doorH + 3)
    nvgClosePath(ctx)
    nvgFillColor(ctx, nvgRGBA(74, 78, 76, 245))
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(28, 32, 31, 235))
    nvgStrokeWidth(ctx, 1.5)
    nvgStroke(ctx)

end

function drawCS2ExteriorLadder(ctx, sx, sy, upW, roofSlabT, upTotalH, groundY, fTops, fHeights)
    local ladderCenters = {
        sx - 54,
        sx + upW + 54,
    }
    local platformStartX = ladderCenters[1] - 32
    local platformEndX = ladderCenters[2] + 32
    local ladderTop = sy + roofSlabT + 8
    local ladderBottom = groundY + 10
    local railOffset = 25
    local wallThickness = 34
    for _, ladderCX in ipairs(ladderCenters) do
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, ladderCX - railOffset, ladderTop)
        nvgLineTo(ctx, ladderCX - railOffset, ladderBottom)
        nvgMoveTo(ctx, ladderCX + railOffset, ladderTop)
        nvgLineTo(ctx, ladderCX + railOffset, ladderBottom)
        nvgStrokeColor(ctx, nvgRGBA(48, 54, 53, 255))
        nvgStrokeWidth(ctx, 8)
        nvgStroke(ctx)

        local rungStep = 18
        local rungY = ladderTop + 8
        while rungY < ladderBottom do
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, ladderCX - railOffset, rungY)
            nvgLineTo(ctx, ladderCX + railOffset, rungY)
            nvgStrokeColor(ctx, nvgRGBA(116, 124, 118, 245))
            nvgStrokeWidth(ctx, 5)
            nvgStroke(ctx)
            rungY = rungY + rungStep
        end
    end

    -- 每层左右两侧分别绘制外部平台，建筑内部不铺平台。
    for fi = 1, #fHeights do
        local floorTop = sy + roofSlabT + fTops[fi]
        local fh = fHeights[fi]
        local doorH = math.floor(fh * 0.58)
        local doorY = floorTop + fh - doorH - 2
        local platformY = doorY + doorH - 3
        for _, side in ipairs({"left", "right"}) do
            local platformX1
            local platformX2
            if side == "left" then
                platformX1 = platformStartX
                platformX2 = sx + wallThickness
            else
                platformX1 = sx + upW - wallThickness
                platformX2 = platformEndX
            end
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, platformX1, platformY - 10)
            nvgLineTo(ctx, platformX2, platformY - 10)
            nvgStrokeColor(ctx, nvgRGBA(86, 94, 90, 240))
            nvgStrokeWidth(ctx, 3)
            nvgStroke(ctx)
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, platformX2, platformY - 10)
            nvgLineTo(ctx, platformX2, platformY + 4)
            nvgStrokeColor(ctx, nvgRGBA(42, 48, 46, 245))
            nvgStrokeWidth(ctx, 3)
            nvgStroke(ctx)
        end
    end
end

function drawCS2ValveBasement(ctx, basX, basTop, basW, basRoomH, bxs)
    nvgSave(ctx)
    nvgScissor(ctx, basX, basTop, basW, basRoomH)
    local floorY = basTop + basRoomH

    -- 横向主水管贯穿三间地下室
    local pipeY = basTop + basRoomH * 0.36
    nvgBeginPath(ctx); nvgMoveTo(ctx, basX + 38, pipeY); nvgLineTo(ctx, basX + basW - 38, pipeY)
    nvgStrokeColor(ctx, nvgRGBA(92, 105, 108, 235)); nvgStrokeWidth(ctx, 10); nvgStroke(ctx)
    nvgBeginPath(ctx); nvgMoveTo(ctx, basX + 38, pipeY - 4); nvgLineTo(ctx, basX + basW - 38, pipeY - 4)
    nvgStrokeColor(ctx, nvgRGBA(150, 165, 165, 135)); nvgStrokeWidth(ctx, 2); nvgStroke(ctx)

    -- 左房：生活水表和过滤罐
    local l = bxs[1]
    local r = bxs[2]
    nvgBeginPath(ctx); nvgRoundedRect(ctx, l + 42, floorY - basRoomH * 0.48, 54, basRoomH * 0.34, 8)
    nvgFillColor(ctx, nvgRGBA(72, 92, 96, 245)); nvgFill(ctx)
    nvgBeginPath(ctx); nvgCircle(ctx, l + 69, floorY - basRoomH * 0.34, 16)
    nvgFillColor(ctx, nvgRGBA(190, 205, 198, 220)); nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(40, 48, 50, 220)); nvgStrokeWidth(ctx, 2); nvgStroke(ctx)
    nvgBeginPath(ctx); nvgRoundedRect(ctx, r - 92, floorY - basRoomH * 0.42, 42, basRoomH * 0.30, 9)
    nvgFillColor(ctx, nvgRGBA(115, 118, 108, 245)); nvgFill(ctx)

    -- 中房：红色手轮水阀 + 压力表
    l = bxs[2]; r = bxs[3]
    local valveX = (l + r) * 0.5
    nvgBeginPath(ctx); nvgMoveTo(ctx, valveX, pipeY); nvgLineTo(ctx, valveX, floorY - basRoomH * 0.22)
    nvgStrokeColor(ctx, nvgRGBA(92, 105, 108, 230)); nvgStrokeWidth(ctx, 8); nvgStroke(ctx)
    nvgBeginPath(ctx); nvgCircle(ctx, valveX, pipeY, 24)
    nvgStrokeColor(ctx, nvgRGBA(180, 48, 38, 245)); nvgStrokeWidth(ctx, 5); nvgStroke(ctx)
    nvgBeginPath(ctx); nvgMoveTo(ctx, valveX - 22, pipeY); nvgLineTo(ctx, valveX + 22, pipeY)
    nvgMoveTo(ctx, valveX, pipeY - 22); nvgLineTo(ctx, valveX, pipeY + 22)
    nvgStrokeColor(ctx, nvgRGBA(180, 48, 38, 245)); nvgStrokeWidth(ctx, 4); nvgStroke(ctx)
    nvgBeginPath(ctx); nvgCircle(ctx, valveX + 70, pipeY - 36, 18)
    nvgFillColor(ctx, nvgRGBA(210, 214, 202, 220)); nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(45, 52, 54, 220)); nvgStrokeWidth(ctx, 2); nvgStroke(ctx)
    nvgBeginPath(ctx); nvgMoveTo(ctx, valveX + 70, pipeY - 36); nvgLineTo(ctx, valveX + 80, pipeY - 42)
    nvgStrokeColor(ctx, nvgRGBA(170, 40, 35, 230)); nvgStrokeWidth(ctx, 2); nvgStroke(ctx)

    -- 右房：小型增压泵、排水沟、渗水
    l = bxs[3]; r = bxs[4]
    nvgBeginPath(ctx); nvgRoundedRect(ctx, l + 54, floorY - basRoomH * 0.34, 92, basRoomH * 0.20, 8)
    nvgFillColor(ctx, nvgRGBA(58, 74, 80, 245)); nvgFill(ctx)
    nvgBeginPath(ctx); nvgCircle(ctx, l + 80, floorY - basRoomH * 0.24, 18)
    nvgStrokeColor(ctx, nvgRGBA(150, 160, 150, 210)); nvgStrokeWidth(ctx, 4); nvgStroke(ctx)
    nvgBeginPath(ctx); nvgRect(ctx, l + 20, floorY - 14, r - l - 42, 8)
    nvgFillColor(ctx, nvgRGBA(38, 46, 48, 220)); nvgFill(ctx)
    for i = 1, 5 do
        local dripX = l + 34 + i * ((r - l - 70) / 6)
        nvgBeginPath(ctx); nvgCircle(ctx, dripX, floorY - 18, 3 + (i % 2))
        nvgFillColor(ctx, nvgRGBA(70, 125, 135, 95)); nvgFill(ctx)
    end

    nvgRestore(ctx)
end

-- 灰色楼板从房间底边向外侧伸出的小幅地砖顶面。
INDOOR_FLOOR_DEPTH = 28
function drawIndoorFloorTop(ctx, x, y, w, h)
    local floorY = y + h
    local depth = INDOOR_FLOOR_DEPTH -- 经过场景缩放后约 15 个实际屏幕像素，只露出一小段顶面
    local frontY = floorY + depth
    local inset = math.min(34, w * 0.09)
    local floorPaint = nvgLinearGradient(ctx, 0, floorY, 0, frontY,
        nvgRGBA(148, 151, 151, 255),
        nvgRGBA(72, 75, 76, 255))

    -- 房间底边为后沿，前沿向屏幕下方展开，形成伸出房间外侧的楼板顶面。
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, x + inset, floorY)
    nvgLineTo(ctx, x + w - inset, floorY)
    nvgLineTo(ctx, x + w, frontY)
    nvgLineTo(ctx, x, frontY)
    nvgClosePath(ctx)
    nvgFillPaint(ctx, floorPaint)
    nvgFill(ctx)

    nvgBeginPath(ctx)
    nvgMoveTo(ctx, x + inset, floorY)
    nvgLineTo(ctx, x + w - inset, floorY)
    nvgStrokeColor(ctx, nvgRGBA(168, 170, 168, 155))
    nvgStrokeWidth(ctx, 1.2)
    nvgStroke(ctx)

    -- 灰色地砖缝从房间底边向外伸出的前沿展开。
    for i = 1, 3 do
        local sx = x + w * (i / 4)
        local offset = (i - 2) * 7
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, sx, floorY)
        nvgLineTo(ctx, sx + offset, frontY)
        nvgStrokeColor(ctx, nvgRGBA(32, 35, 36, 175))
        nvgStrokeWidth(ctx, 1.6)
        nvgStroke(ctx)
    end
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, x + inset * 0.45, floorY + depth * 0.52)
    nvgLineTo(ctx, x + w - inset * 0.45, floorY + depth * 0.52)
    nvgStrokeColor(ctx, nvgRGBA(184, 187, 186, 125))
    nvgStrokeWidth(ctx, 1.3)
    nvgStroke(ctx)
end

function drawSecondCrossSection(ctx, groundY)
    local data = CS2_FLOOR_DATA
    local numFloors = #data
    local REF_H = 768
    local baseFloorH = math.floor(REF_H * 0.218)
    local roofSlabT = 62
    local wallT = 34
    local fHeights = {}
    local fTops = {}
    local yOff = 0
    for fi = 1, numFloors do
        local fd = data[fi]
        fTops[fi] = yOff
        fHeights[fi] = math.max(68, math.floor(baseFloorH * fd.hRatio))
        yOff = yOff + fHeights[fi]
        if fi < numFloors then yOff = yOff + fd.slabBelow end
    end
    local upTotalH = roofSlabT + yOff
    local upW = math.floor(upTotalH * 1.46)
    local sx = CS2_WLD_X - cameraX
    local sy = groundY - upTotalH
    local innerW = upW - 2 * wallT
    local gndSlabT = data[numFloors].slabBelow
    local basH = math.floor(baseFloorH * 1.42)
    local basSlabT = 44

    -- 第二栋楼门复用第一栋楼素材：关闭显示侧面厚度图，打开显示正面门图。
    local function drawCS2FrontDoor(ctx, centerX, bottomY, doorH, openProg, fallbackColor)
        local doorDrawH = doorH * 1.2
        local frontDoorW = doorDrawH * WOOD_DOOR_FRONT_RATIO
        local sideDoorW = doorDrawH * (71 / 128)
        local isOpen = (openProg or 0) > 0.5
        local img = isOpen and roomDoorImg or roomDoorSideImg
        local doorDrawW = isOpen and frontDoorW or sideDoorW
        if not img or img <= 0 then
            img = roomDoorImg
            doorDrawW = frontDoorW
        end
        local dx = centerX - doorDrawW * 0.5
        local dy = bottomY - doorH - (doorDrawH - doorH) * 0.5
        nvgBeginPath(ctx)
        nvgRect(ctx, dx, dy, doorDrawW, doorDrawH)
        if img and img > 0 then
            local paint = nvgImagePattern(ctx, dx, dy, doorDrawW, doorDrawH, 0, img, 1.0)
            nvgFillPaint(ctx, paint)
        else
            nvgFillColor(ctx, fallbackColor or nvgRGBA(92, 62, 42, 255))
        end
        nvgFill(ctx)
    end

    -- 上层房间背景与家具
    for fi = 1, numFloors do
        local fd = data[fi]
        local floorTop = sy + roofSlabT + fTops[fi]
        local fh = fHeights[fi]
        local xs = { sx + wallT }
        for _, d in ipairs(fd.divs) do xs[#xs + 1] = sx + wallT + math.floor(innerW * d) end
        xs[#xs + 1] = sx + upW - wallT
        nvgSave(ctx)
        nvgScissor(ctx, sx + wallT, floorTop, innerW, fh)
        for ri, room in ipairs(fd.rooms) do
            local rx = xs[ri]
            local rw = xs[ri + 1] - xs[ri]
            if rw > 2 then
                drawCSRoom(ctx, rx, floorTop, rw, fh, room)
            end
        end
        nvgRestore(ctx)

        -- 地砖顶面与薄地板条都先于家具绘制，家具与物品始终覆盖在地面上方。
        drawIndoorFloorTop(ctx, sx + wallT, floorTop, innerW, fh)
        local floorStripY = floorTop + fh - 6
        nvgBeginPath(ctx); nvgRect(ctx, sx + wallT, floorStripY, innerW, 6)
        nvgFillColor(ctx, nvgRGBA(54, 54, 52, 255)); nvgFill(ctx)

        -- 家具绘制在地砖顶面之后，底脚不会再被地面遮挡。
        for ri, _room in ipairs(fd.rooms) do
            local rx = xs[ri]
            local rw = xs[ri + 1] - xs[ri]
            if rw > 2 then
                nvgSave(ctx)
                nvgScissor(ctx, rx, floorTop, rw, fh + 18)
                drawCS2Furniture(ctx, fi, ri, rx, floorTop, rw, fh)
                nvgRestore(ctx)
            end
        end

        -- 楼层门改为建筑外侧的架子梯门，房间内部不再放置换层门。
        -- 外梯和侧门在建筑结构层之后统一绘制。

        local roomInfos = {}
        for ri, _room in ipairs(fd.rooms) do
            local roomX = xs[ri]
            local roomW = xs[ri + 1] - roomX
            local lightKey = "cs2_light_" .. fi .. "_" .. ri
            local brightness = getRoomBrightness(lightKey)
            roomInfos[#roomInfos + 1] = {
                x = roomX,
                midX = math.floor((roomX + xs[ri + 1]) * 0.5),
                brightness = brightness,
                rw = roomW,
                key = lightKey,
            }

            local switchSX
            local switchSY
            if ri == 3 then
                -- 最右房间从外置架子梯门进入，开关贴在外墙门内侧。
                switchSX = xs[ri + 1] - 26
                switchSY = floorTop + fh - math.floor(fh * 0.29)
            elseif ri == 1 then
                switchSX = xs[ri + 1] - 26
                switchSY = floorTop + fh - math.floor(fh * 0.29)
            else
                switchSX = xs[ri] + 26
                switchSY = floorTop + fh - math.floor(fh * 0.29)
            end
            registerLightSwitch(
                ctx,
                lightKey,
                switchSX,
                switchSY,
                switchSX + cameraX,
                roomX + cameraX,
                xs[ri + 1] + cameraX,
                floorTop,
                fh,
                76,
                82
            )
        end
        csInfo.floorOverlays[#csInfo.floorOverlays + 1] = {
            x = sx + wallT,
            y = floorTop,
            w = innerW,
            h = fh,
            roomH = fh,
            floorIndex = fi,
            building = "cs2",
            wx = CS2_WLD_X + wallT,
            ww = innerW,
            rooms = roomInfos,
        }

        -- 门洞和门板在后面的结构层统一绘制，避免被墙体盖住。
    end

    -- 地下室背景；一楼楼板正面从地砖顶面前沿之后开始，避免覆盖可见顶面。
    local basX = sx - math.floor(upW * 0.06)
    local basW = upW + math.floor(upW * 0.12)
    local basTop = groundY + gndSlabT
    local basRoomH = basH
    local gndFaceY2 = groundY + INDOOR_FLOOR_DEPTH
    local gndFaceH2 = math.max(0, gndSlabT - INDOOR_FLOOR_DEPTH)
    if gndFaceH2 > 0 then
        nvgBeginPath(ctx); nvgRect(ctx, basX, gndFaceY2, basW, gndFaceH2)
        nvgFillColor(ctx, nvgRGBA(72, 70, 66, 255)); nvgFill(ctx)
    end

    local bxs = { basX + wallT }
    local basInnerW = basW - 2 * wallT
    for _, d in ipairs(CS2_BASEMENT_DATA.divs) do bxs[#bxs + 1] = basX + wallT + math.floor(basInnerW * d) end
    bxs[#bxs + 1] = basX + basW - wallT
    nvgSave(ctx)
    nvgScissor(ctx, basX + wallT, basTop, basInnerW, basRoomH)
    for ri, room in ipairs(CS2_BASEMENT_DATA.rooms) do
        drawCSRoom(ctx, bxs[ri], basTop, bxs[ri + 1] - bxs[ri], basRoomH, room)
    end
    nvgRestore(ctx)
    drawCS2ValveBasement(ctx, basX + wallT, basTop, basInnerW, basRoomH, bxs)

    -- 第二栋楼地下室同样按房间独立控制灯光，复用统一暗层和天花灯系统。
    local basementRoomInfos = {}
    for ri, _room in ipairs(CS2_BASEMENT_DATA.rooms) do
        local roomX = bxs[ri]
        local roomW = bxs[ri + 1] - roomX
        local lightKey = "cs2_bas_light_" .. ri
        basementRoomInfos[#basementRoomInfos + 1] = {
            x = roomX,
            midX = math.floor((roomX + bxs[ri + 1]) * 0.5),
            brightness = getRoomBrightness(lightKey),
            rw = roomW,
            key = lightKey,
        }

        local switchSX
        if ri == 1 then
            switchSX = bxs[ri + 1] - 18
        else
            switchSX = bxs[ri] + 18
        end
        local switchSY = basTop + basRoomH - math.floor(basRoomH * 0.38)
        registerLightSwitch(
            ctx,
            lightKey,
            switchSX,
            switchSY,
            switchSX + cameraX,
            roomX + cameraX,
            bxs[ri + 1] + cameraX,
            basTop,
            basRoomH,
            76,
            82
        )
    end
    csInfo.floorOverlays[#csInfo.floorOverlays + 1] = {
        x = basX + wallT,
        y = basTop,
        w = basInnerW,
        h = basRoomH,
        roomH = basRoomH,
        building = "cs2_basement",
        wx = CS2_WLD_X - math.floor(upW * 0.06) + wallT,
        ww = basInnerW,
        rooms = basementRoomInfos,
    }

    -- 第二栋楼地下室梯子放在最右房间左侧，右侧保留完整的入口落脚空间。
    local ladderRelX2 = math.floor(innerW * 0.735)
    local ladderW2 = math.floor(innerW * 0.075)
    local ladderX2 = sx + wallT + ladderRelX2
    local ladderH2 = gndSlabT + basH
    nvgBeginPath(ctx)
    nvgRect(ctx, ladderX2, groundY, ladderW2, gndSlabT)
    nvgFillColor(ctx, nvgRGBA(46, 34, 24, 255))
    nvgFill(ctx)
    if ladderImg and ladderImg > 0 then
        local ladderPaint2 = nvgImagePattern(ctx, ladderX2, groundY, ladderW2, ladderH2, 0, ladderImg, 1.0)
        nvgBeginPath(ctx)
        nvgRect(ctx, ladderX2, groundY, ladderW2, ladderH2)
        nvgFillPaint(ctx, ladderPaint2)
        nvgFill(ctx)
    end

    -- 建筑结构：外墙、楼板、屋顶、地下室隔墙
    nvgBeginPath(ctx); nvgRect(ctx, sx, sy, upW, roofSlabT)
    nvgFillColor(ctx, nvgRGBA(72, 70, 66, 255)); nvgFill(ctx)
    -- 第二栋楼左右外墙：每层只保留门口上方横梁，下半段都是可进入房间的门洞。
    for fi = 1, numFloors do
        local floorTop = sy + roofSlabT + fTops[fi]
        local fh = fHeights[fi]
        local doorH = math.floor(fh * 0.58)
        local lintelH = fh - doorH
        nvgBeginPath(ctx)
        nvgRect(ctx, sx, floorTop, wallT, lintelH)
        nvgRect(ctx, sx + upW - wallT, floorTop, wallT, lintelH)
        nvgFillColor(ctx, nvgRGBA(74, 70, 64, 255))
        nvgFill(ctx)
    end

    for fi = 1, numFloors - 1 do
        local slabY = sy + roofSlabT + fTops[fi] + fHeights[fi]
        local slabFrontY = slabY + INDOOR_FLOOR_DEPTH
        local slabFrontH = math.max(0, data[fi].slabBelow - INDOOR_FLOOR_DEPTH)
        if slabFrontH > 0 then
            nvgBeginPath(ctx); nvgRect(ctx, sx, slabFrontY, upW, slabFrontH)
            nvgFillColor(ctx, nvgRGBA(72, 70, 66, 255)); nvgFill(ctx)
        end
    end
    for fi = 1, numFloors do
        local fd = data[fi]
        local floorTop = sy + roofSlabT + fTops[fi]
        local fh = fHeights[fi]
        for divIdx, d in ipairs(fd.divs) do
            local wallX = sx + wallT + math.floor(innerW * d)
            local wx = wallX - math.floor(fd.divT * 0.5)
            local doorH = math.floor(fh * 0.56)
            local lintelH = fh - doorH
            -- 门洞区域不再绘制左右门柱，只保留门洞上方的横梁。
            nvgBeginPath(ctx)
            nvgRect(ctx, wx, floorTop, fd.divT, lintelH)
            nvgFillColor(ctx, nvgRGBA(68, 64, 58, 255)); nvgFill(ctx)

            -- 第二栋楼层间门使用独立状态，关闭为侧面厚度图，打开为正面图。
            local doorKey = "cs2_" .. fi .. "_" .. divIdx
            local doorState = roomDoorStates[doorKey]
            drawCS2FrontDoor(ctx, wallX, floorTop + fh, doorH, doorState and doorState.openProg or 0,
                nvgRGBA(60, 42, 30, 232))
        end
    end
    nvgBeginPath(ctx); nvgRect(ctx, basX, basTop + basRoomH, basW, basSlabT)
    nvgRect(ctx, basX, basTop, wallT, basRoomH)
    nvgRect(ctx, basX + basW - wallT, basTop, wallT, basRoomH)
    nvgFillColor(ctx, nvgRGBA(64, 62, 58, 255)); nvgFill(ctx)
    for i = 2, #bxs - 1 do
        local doorH = math.floor(basRoomH * 0.56)
        local lintelH = basRoomH - doorH
        local wallX = bxs[i]
        local wallW = 36
        -- 地下室门洞只保留上方横梁，门两侧不绘制门柱。
        nvgBeginPath(ctx)
        nvgRect(ctx, wallX - wallW * 0.5, basTop, wallW, lintelH)
        nvgFillColor(ctx, nvgRGBA(62, 60, 56, 255)); nvgFill(ctx)

        local basementDoorKey = "cs2_bas_" .. (i - 1)
        local basementDoorState = roomDoorStates[basementDoorKey]
        drawCS2FrontDoor(ctx, wallX, basTop + basRoomH, doorH,
            basementDoorState and basementDoorState.openProg or 0, nvgRGBA(48, 54, 54, 235))
    end

    -- 一楼入口已并入左侧逐层外梯门，不再叠加旧入口门。

    -- 外置架子梯先画在建筑侧边，再绘制每层外墙平台门。
    drawCS2ExteriorLadder(ctx, sx, sy, upW, roofSlabT, upTotalH, groundY, fTops, fHeights)
    for fi = 1, numFloors do
        local floorTop = sy + roofSlabT + fTops[fi]
        local fh = fHeights[fi]
        drawCS2ExteriorLadderDoor(
            ctx,
            fi,
            sx,
            upW,
            wallT,
            floorTop,
            fh,
            floorTop + fh - groundY,
            floorTop - groundY
        )
    end

    -- 生活楼外立面标签和门口提示（手机向）
    nvgBeginPath(ctx); nvgRoundedRect(ctx, sx + upW * 0.36, sy + 12, upW * 0.28, 30, 5)
    nvgFillColor(ctx, nvgRGBA(48, 48, 42, 230)); nvgFill(ctx)
    nvgFontFace(ctx, "sans"); nvgFontSize(ctx, 14); nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(ctx, nvgRGBA(218, 198, 132, 230)); nvgText(ctx, sx + upW * 0.50, sy + 27, "居民服务楼")
end

-- 所有暗层遮罩 + 灯光效果（地下室 + 上层房间），在玩家/丧尸绘制之后调用
local function drawBasementOverlay(ctx)
    -- ── 上层房间天花灯 ──────────────────────────────────────
    for _, fo in ipairs(csInfo.floorOverlays) do
        nvgSave(ctx)
        nvgScissor(ctx, fo.x, fo.y, fo.w, fo.h)

        nvgGlobalCompositeOperation(ctx, NVG_SOURCE_OVER)
        for _, r in ipairs(fo.rooms) do
            if r.brightness <= 0.05 then
                local rx = r.x or (r.midX - (r.rw or fo.w) * 0.5)
                local rw = r.rw or fo.w
                local coverH = fo.h
                nvgBeginPath(ctx)
                nvgRect(ctx, rx, fo.y, rw, coverH)
                nvgFillColor(ctx, nvgRGBA(4, 7, 12, 184))
                nvgFill(ctx)
            end
        end

        nvgGlobalCompositeOperation(ctx, NVG_LIGHTER)
        for _, r in ipairs(fo.rooms) do
            if r.brightness > 0.05 then
                local glowA = math.floor(185 * r.brightness)
                local lampCX = r.midX
                local roomW = r.rw or fo.w
                local rx = r.x or (r.midX - roomW * 0.5)
                -- 开灯后给整间房提供暖色环境光，避免只有灯锥亮。
                nvgBeginPath(ctx)
                nvgRect(ctx, rx, fo.y, roomW, fo.h)
                nvgFillColor(ctx, nvgRGBA(120, 98, 62, math.floor(54 * r.brightness)))
                nvgFill(ctx)
                -- 光从灯可见发光区域发出（灯图中间偏下是发光管）
                local lampW = math.floor(roomW * 0.16)
                local lampH = math.floor(lampW * (107 / 192))
                local wireLen = 0  -- 无间距，灯直接贴天花板
                -- 灯图片有透明区：实际灯管约在图片30%~65%高度区间
                local lampTop = fo.y + wireLen - math.floor(lampH * 0.15)  -- 图片略嵌入天花板
                local lampBottom = lampTop + math.floor(lampH * 0.65)  -- 灯管可见底部（光从这里发出）
                local topHalf = math.floor(lampW * 0.5)  -- 灯口宽度=灯图宽度
                local coneHalf = math.floor(roomW * 0.45)  -- 底部扩散半宽
                local coneBottom = fo.y + (fo.roomH or fo.h)  -- 锥形底边

                -- 用梯形路径画锥形光，从灯底部发出
                nvgBeginPath(ctx)
                nvgMoveTo(ctx, lampCX - topHalf, lampBottom)   -- 灯左端
                nvgLineTo(ctx, lampCX + topHalf, lampBottom)   -- 灯右端
                nvgLineTo(ctx, lampCX + coneHalf, coneBottom)  -- 右下（宽口）
                nvgLineTo(ctx, lampCX - coneHalf, coneBottom)  -- 左下（宽口）
                nvgClosePath(ctx)

                -- 从灯底往下的线性渐变（顶部亮，底部淡出）
                local paint = nvgLinearGradient(ctx, lampCX, lampBottom, lampCX, coneBottom,
                    nvgRGBA(255, 240, 200, glowA),
                    nvgRGBA(255, 240, 200, 0))
                nvgFillPaint(ctx, paint)
                nvgFill(ctx)
            end
        end

        nvgGlobalCompositeOperation(ctx, NVG_SOURCE_OVER)

        -- 天花灯图片（每个房间中央贴一盏，电线吊着）
        if ceilingLampImg > 0 then
            for _, r in ipairs(fo.rooms) do
                local roomW = r.rw or fo.w
                local lampW = math.floor(roomW * 0.16)
                local lampH = math.floor(lampW * (107 / 192))
                local lx = r.midX - lampW * 0.5
                local ly = fo.y - math.floor(lampH * 0.15)  -- 图片略嵌入天花板
                -- 电线画到灯管可见顶部（图片约30%处是灯管开始）
                local wireEndY = ly + math.floor(lampH * 0.35)

                -- 画电线（从天花板到灯管可见顶部）
                nvgBeginPath(ctx)
                nvgMoveTo(ctx, r.midX, fo.y)
                nvgLineTo(ctx, r.midX, wireEndY)
                nvgStrokeColor(ctx, nvgRGBA(30, 30, 30, 200))
                nvgStrokeWidth(ctx, 1.5)
                nvgStroke(ctx)

                -- 画灯图片：关灯时完全隐藏，暗房只保留墙边开关可见
                if r.brightness > 0.05 then
                    local paint = nvgImagePattern(ctx, lx, ly, lampW, lampH, 0, ceilingLampImg, 1.0)
                    nvgBeginPath(ctx)
                    nvgRect(ctx, lx, ly, lampW, lampH)
                    nvgFillPaint(ctx, paint)
                    nvgFill(ctx)
                end
            end
        end

        nvgRestore(ctx)
    end

    -- ── 地下室暗层 ──────────────────────────────────────────
    local ov = csInfo.basOverlay
    if not ov then return end
    local innerL, innerR = ov.innerL, ov.innerR
    local basTop, basRoomH = ov.basTop, ov.basRoomH
    local innerW2 = innerR - innerL

    nvgSave(ctx)
    nvgScissor(ctx, innerL, basTop, innerW2, basRoomH)

    nvgGlobalCompositeOperation(ctx, NVG_SOURCE_OVER)
    for ri = 1, #CS_BASEMENT_DATA.rooms do
        if (ov.brightnesses[ri] or 0) <= 0.05 then
            nvgBeginPath(ctx)
            nvgRect(ctx, ov.bxs[ri], basTop, ov.bxs[ri + 1] - ov.bxs[ri], basRoomH)
            nvgFillColor(ctx, nvgRGBA(3, 5, 9, 210))
            nvgFill(ctx)
        end
    end

    nvgGlobalCompositeOperation(ctx, NVG_LIGHTER)
    for ri = 1, #CS_BASEMENT_DATA.rooms do
        local roomMidX = math.floor((ov.bxs[ri] + ov.bxs[ri + 1]) / 2)
        local brightness = ov.brightnesses[ri]
        if brightness > 0.05 then
            local roomLeft = ov.bxs[ri]
            local roomWidth = ov.bxs[ri + 1] - roomLeft
            nvgBeginPath(ctx)
            nvgRect(ctx, roomLeft, basTop, roomWidth, basRoomH)
            nvgFillColor(ctx, nvgRGBA(88, 72, 42, math.floor(42 * brightness)))
            nvgFill(ctx)
            local glowR = math.floor(basRoomH * 1.25)
            local glowA = math.floor(235 * brightness)
            local glow = nvgRadialGradient(ctx, roomMidX, basTop + 10,
                8, glowR,
                nvgRGBA(255, 230, 140, glowA), nvgRGBA(0, 0, 0, 0))
            nvgBeginPath(ctx)
            nvgRect(ctx, roomMidX - glowR, basTop, glowR * 2, basRoomH)
            nvgFillPaint(ctx, glow); nvgFill(ctx)
        end
    end

    nvgGlobalCompositeOperation(ctx, NVG_SOURCE_OVER)
    nvgRestore(ctx)
end

-- 简单整数哈希（用于混凝土纹理，避免干扰 math.random 状态）
local function hashXY(xi, yi)
    local h = xi * 2654435761 + yi * 2246822519
    h = (h ~ (h >> 16)) & 0xFFFFFFFF
    return h
end

-- 绘制单个房间背景+纹理（调用时已在正确的 nvgSave 块内）
function drawCSRoom(ctx, rx, ry, rw, rh, room)
    local r, g, b = room.bg[1], room.bg[2], room.bg[3]
    local bga = room.bga or 255  -- 背景透明度，默认不透明
    -- 背景填充
    nvgBeginPath(ctx)
    nvgRect(ctx, rx, ry, rw, rh)
    nvgFillColor(ctx, nvgRGBA(r, g, b, bga))
    nvgFill(ctx)
    -- 末世做旧：血迹/水渍/脏污
    local roomSeed = math.floor((rx + cameraX) * 0.07) * 11 + math.floor(ry * 0.09) * 7
    -- 底部潮湿渐变（加重）
    local wetH = math.min(50, rh * 0.35)
    local wetGrad = nvgLinearGradient(ctx, 0, ry + rh - wetH, 0, ry + rh,
        nvgRGBA(0, 0, 0, 0), nvgRGBA(10, 6, 3, 80))
    nvgBeginPath(ctx)
    nvgRect(ctx, rx, ry + rh - wetH, rw, wetH)
    nvgFillPaint(ctx, wetGrad)
    nvgFill(ctx)
    -- 不规则脏污（重叠圆形）
    for i = 0, 3 do
        local s = (roomSeed + i * 41) % 180
        local cx2 = rx + (s / 180) * (rw - 20) + 10
        local cy2 = ry + rh * 0.3 + (s % 60)
        for j = 0, 2 + (s % 2) do
            local jj = (s + j * 23) % 50
            local ox = (jj % 10) - 5
            local oy = (jj % 8) - 4
            local rr = 3 + (jj % 6)
            nvgBeginPath(ctx)
            nvgCircle(ctx, cx2 + ox, cy2 + oy, rr)
            nvgFillColor(ctx, nvgRGBA(12, 8, 4, 30 + (s % 20) - j * 3))
            nvgFill(ctx)
        end
    end
    -- 室内血迹（约40%房间出现）
    local roomBlood = (roomSeed + 63) % 100
    if roomBlood < 40 then
        local bx2 = rx + (roomBlood / 40) * (rw - 30) + 10
        local by2 = ry + rh * 0.5 + (roomBlood % 30)
        -- 地面血泊
        nvgBeginPath(ctx)
        nvgEllipse(ctx, bx2, by2, 12 + roomBlood % 8, 6 + roomBlood % 4)
        nvgFillColor(ctx, nvgRGBA(60, 10, 8, 55 + roomBlood % 25))
        nvgFill(ctx)
        -- 拖拽血痕
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, bx2, by2)
        nvgLineTo(ctx, bx2 + 20 + roomBlood % 15, by2 + 3)
        nvgStrokeColor(ctx, nvgRGBA(55, 10, 5, 40))
        nvgStrokeWidth(ctx, 3)
        nvgStroke(ctx)
    end

    if room.tex == "hstripe" and rw > 6 then
        -- 竖向条纹纹理（密集）
        local tr, tg, tb = room.tcol[1], room.tcol[2], room.tcol[3]
        local ta = room.ta
        local stripeW = 3   -- 每条竖纹宽度
        local gap     = 10  -- 条纹间距
        local step    = stripeW + gap
        local x0 = rx + math.floor(rw * 0.02)
        local sx = x0
        while sx < rx + rw - 2 do
            local sw = math.min(stripeW, rx + rw - sx)
            nvgBeginPath(ctx)
            nvgRect(ctx, sx, ry + 2, sw, rh - 4)
            nvgFillColor(ctx, nvgRGBA(tr, tg, tb, ta))
            nvgFill(ctx)
            sx = sx + step
        end

    elseif room.tex == "tile" and rw > 12 and rh > 12 then
        -- 方格瓷砖纹理（用世界坐标计算格线，避免随镜头滑动）
        local tr, tg, tb = room.tcol[1], room.tcol[2], room.tcol[3]
        local ta = room.ta
        local tileS = 15  -- 固定15px，不随屏幕大小缩放
        local wrx = rx + cameraX  -- 世界坐标 X
        local xi0 = math.floor(wrx / tileS)
        local yi0 = math.floor(ry / tileS)
        local xi1 = math.ceil((wrx + rw) / tileS)
        local yi1 = math.ceil((ry + rh) / tileS)
        -- 竖线（世界格线转回屏幕坐标）
        for xi = xi0, xi1 do
            local lx = xi * tileS - cameraX
            if lx > rx and lx < rx + rw then
                nvgBeginPath(ctx)
                nvgMoveTo(ctx, lx, ry + 1)
                nvgLineTo(ctx, lx, ry + rh - 1)
                nvgStrokeColor(ctx, nvgRGBA(tr, tg, tb, ta))
                nvgStrokeWidth(ctx, 1.5)
                nvgStroke(ctx)
            end
        end
        -- 横线（Y 不受 cameraX 影响，直接用屏幕坐标）
        for yi = yi0, yi1 do
            local ly = yi * tileS
            if ly > ry and ly < ry + rh then
                nvgBeginPath(ctx)
                nvgMoveTo(ctx, rx + 1, ly)
                nvgLineTo(ctx, rx + rw - 1, ly)
                nvgStrokeColor(ctx, nvgRGBA(tr, tg, tb, ta))
                nvgStrokeWidth(ctx, 1.5)
                nvgStroke(ctx)
            end
        end

    elseif room.tex == "concrete" and rw > 16 and rh > 16 then
        -- 混凝土破旧纹理：污渍斑块 + 竖向水渍 + 裂缝（确定性随机，世界坐标锚定）
        local tr, tg, tb = room.tcol[1], room.tcol[2], room.tcol[3]
        local ta = room.ta
        local wrxC = rx + cameraX  -- 世界坐标 X

        -- ① 软边渐变晕染斑块（仅地下室等 stains=true 的房间）
        if room.stains then
        local patchCellW = math.max(28, math.floor(rw / 7))
        local patchCellH = math.max(22, math.floor(rh / 4))
        local pxi0 = math.floor(wrxC / patchCellW) - 1
        local pyi0 = math.floor(ry / patchCellH) - 1
        for pxi = pxi0, pxi0 + 9 do
            for pyi = pyi0, pyi0 + 6 do
                local ph = hashXY(pxi * 19 + 5, pyi * 11 + 3)
                -- 约50%的格子出现晕染
                if (ph % 10) < 5 then
                    local pcx = pxi * patchCellW + (ph % patchCellW) - cameraX
                    local pcy = pyi * patchCellH + ((ph >> 8) % patchCellH)
                    -- 椭圆半径：更小
                    local pradX = math.floor(patchCellW * 0.30) + (ph % 10)
                    local pradY = math.floor(patchCellH * 0.28) + ((ph >> 4) % 8)
                    -- 深色为主（暗一些），少量浅色
                    local delta = (ph % 4) == 0 and 15 or -22
                    local pr2 = math.max(0, math.min(255, tr + delta))
                    local pg2 = math.max(0, math.min(255, tg + delta))
                    local pb2 = math.max(0, math.min(255, tb + delta))
                    local pAlpha = 35 + (ph % 40)
                    -- 径向渐变：中心有色，边缘完全透明
                    local paint = nvgRadialGradient(ctx, pcx, pcy, 0, pradX,
                        nvgRGBA(pr2, pg2, pb2, pAlpha),
                        nvgRGBA(pr2, pg2, pb2, 0))
                    nvgBeginPath(ctx)
                    -- 用椭圆绘制，横向压缩成扁平晕
                    nvgSave(ctx)
                    nvgTranslate(ctx, pcx, pcy)
                    nvgScale(ctx, 1.0, pradY / pradX)
                    nvgTranslate(ctx, -pcx, -pcy)
                    nvgEllipse(ctx, pcx, pcy, pradX, pradX)
                    nvgFillPaint(ctx, paint)
                    nvgFill(ctx)
                    nvgRestore(ctx)
                end
            end
        end
        end  -- stains

        -- ② 竖向水渍条纹（仅 stains=true）
        if room.stains then
        local streakCellW = math.max(22, math.floor(rw / 6))
        local sxiS0 = math.floor(wrxC / streakCellW) - 1
        for sxi = sxiS0, sxiS0 + 9 do
            local sh = hashXY(sxi * 29 + 11, 5)
            if (sh % 10) < 4 then
                local lx = sxi * streakCellW + (sh % streakCellW) - cameraX
                if lx > rx and lx < rx + rw then
                    local streakH = math.floor(rh * (0.25 + (sh % 40) * 0.01))
                    local streakW = 2 + (sh % 4)
                    local streakA = 18 + (sh % 22)
                    local paint = nvgLinearGradient(ctx, lx, ry, lx, ry + streakH,
                        nvgRGBA(tr - 25, tg - 22, tb - 18, streakA),
                        nvgRGBA(tr - 25, tg - 22, tb - 18, 0))
                    nvgBeginPath(ctx)
                    nvgRect(ctx, lx, ry, streakW, streakH)
                    nvgFillPaint(ctx, paint)
                    nvgFill(ctx)
                end
            end
        end
        end  -- stains

        -- ③ 短裂缝线条
        local cellW = math.max(18, math.floor(rw / 5))
        local cellH = math.max(14, math.floor(rh / 4))
        local xiB = math.floor(wrxC / cellW)
        local yiB = math.floor(ry / cellH)
        for xi = xiB, xiB + 6 do
            for yi = yiB, yiB + 5 do
                local cx2 = xi * cellW
                local cy2 = yi * cellH
                local h1 = hashXY(xi * 3 + 7, yi * 5 + 13)
                local ox1 = (h1 % cellW)
                local oy1 = ((h1 >> 8) % cellH)
                local h2 = hashXY(xi * 11 + 3, yi * 7 + 5)
                local dx = ((h2 % 17) - 8) * 1.2
                local dy = (((h2 >> 8) % 13) - 6) * 1.2
                local lx1 = cx2 + ox1 - cameraX
                local ly1 = cy2 + oy1
                if lx1 > rx and lx1 < rx + rw and ly1 > ry and ly1 < ry + rh then
                    nvgBeginPath(ctx)
                    nvgMoveTo(ctx, lx1, ly1)
                    nvgLineTo(ctx, lx1 + dx, ly1 + dy)
                    nvgStrokeColor(ctx, nvgRGBA(tr, tg, tb, ta))
                    nvgStrokeWidth(ctx, 1.2)
                    nvgStroke(ctx)
                end
            end
        end

    elseif room.tex == "brick" and rw > 10 and rh > 8 then
        -- 砖块纹理（世界坐标锚定，走动不滑动）
        local tr, tg, tb = room.tcol[1], room.tcol[2], room.tcol[3]
        local ta = room.ta
        -- room.brickW 可覆盖自动计算值，确保多房间砖块尺寸一致
        local brickW = room.brickW or math.max(20, math.floor(rw * 0.12))
        local brickH = math.max(8,  math.floor(brickW * 0.46))
        local mortarT = 2
        local wrxB = rx + cameraX  -- 世界坐标

        -- 横向灰缝（全宽水平线）
        local rowH = brickH + mortarT
        local yi0 = math.floor(ry / rowH)
        local yi1 = math.ceil((ry + rh) / rowH)
        for yi = yi0, yi1 do
            local ly = yi * rowH
            if ly > ry and ly < ry + rh then
                nvgBeginPath(ctx)
                nvgMoveTo(ctx, rx, ly)
                nvgLineTo(ctx, rx + rw, ly)
                nvgStrokeColor(ctx, nvgRGBA(tr, tg, tb, ta))
                nvgStrokeWidth(ctx, mortarT)
                nvgStroke(ctx)
            end
        end
        -- 竖向灰缝（偶数行和奇数行错缝）
        local colW = brickW + mortarT
        for yi = yi0, yi1 do
            local rowTop = yi * rowH
            if rowTop + brickH > ry and rowTop < ry + rh then
                -- 奇数行偏移半砖
                local offset = (yi % 2 == 0) and 0 or math.floor(colW * 0.5)
                local xi0 = math.floor((wrxB - offset) / colW)
                local xi1 = math.ceil((wrxB + rw - offset) / colW)
                for xi = xi0, xi1 do
                    local lx = xi * colW + offset - cameraX
                    if lx > rx and lx < rx + rw then
                        local lineTop    = math.max(ry, rowTop + mortarT)
                        local lineBottom = math.min(ry + rh, rowTop + rowH - mortarT)
                        if lineBottom > lineTop then
                            nvgBeginPath(ctx)
                            nvgMoveTo(ctx, lx, lineTop)
                            nvgLineTo(ctx, lx, lineBottom)
                            nvgStrokeColor(ctx, nvgRGBA(tr, tg, tb, ta))
                            nvgStrokeWidth(ctx, mortarT)
                            nvgStroke(ctx)
                        end
                    end
                end
            end
        end
    end

    -- 墙面动态血迹：沿墙面法线贴在命中墙体上。
    for _, splat in ipairs(WALL_BLOOD_SPLATS) do
        local sx = splat.x - cameraX
        local sy = H * GROUND_Y_RATIO + splat.y
        local alpha = math.floor(splat.alpha or 205)
        nvgBeginPath(ctx)
        nvgEllipse(ctx, sx, sy, splat.w * 0.5, splat.h * 0.5)
        nvgFillColor(ctx, nvgRGBA(95, 10, 12, alpha))
        nvgFill(ctx)
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, sx, sy + splat.h * 0.2)
        nvgLineTo(ctx, sx + (splat.dir or 1) * 2, sy + splat.h * 0.9)
        nvgStrokeColor(ctx, nvgRGBA(70, 8, 10, math.floor(alpha * 0.82)))
        nvgStrokeWidth(ctx, math.max(1.5, splat.w * 0.07))
        nvgStroke(ctx)
        if splat.drip then
            nvgBeginPath(ctx)
            nvgCircle(ctx, sx + (splat.dir or 1) * 2, sy + splat.h * 0.92, math.max(2, splat.w * 0.09))
            nvgFillColor(ctx, nvgRGBA(80, 8, 10, math.floor(alpha * 0.86)))
            nvgFill(ctx)
        end
    end

    -- 绘制墙面喷溅血迹贴花：位于墙体纹理之后、电线与家具之前。
    if rw > 80 and rh > 70 then
        local bloodDecals = {
            { roomDecorImgs.wallBloodFan, 514 / 384 },
            { roomDecorImgs.wallBloodBurst, 514 / 384 },
            { roomDecorImgs.wallBloodDrip, 384 / 514 },
            { roomDecorImgs.wallBloodMist, 1.0 },
        }
        local bloodBaseSeed = hashXY(math.floor((rx + cameraX) / 37), math.floor(ry / 29))
        local bloodCount = 2 + (bloodBaseSeed % 3)
        for bloodIndex = 1, bloodCount do
            local bloodSeed = hashXY(bloodBaseSeed + bloodIndex * 47, bloodIndex * 83 + 17)
            local decal = bloodDecals[(bloodSeed % #bloodDecals) + 1]
            local bloodImg = decal[1]
            if bloodImg and bloodImg > 0 then
                local bloodW = rw * (0.22 + ((bloodSeed >> 5) % 22) * 0.01)
                bloodW = math.max(48, math.min(bloodW, rw * 0.48))
                local bloodH = bloodW / decal[2]
                if bloodH > rh * 0.48 then
                    bloodH = rh * 0.48
                    bloodW = bloodH * decal[2]
                end
                local freeX = math.max(1, rw - bloodW - 12)
                local bloodX = rx + 6 + ((bloodSeed >> 9) % 1000) / 1000 * freeX
                local bloodY = ry + rh * (0.10 + ((bloodSeed >> 19) % 36) * 0.01)
                bloodY = math.min(bloodY, ry + rh - bloodH - rh * 0.12)
                local bloodAlpha = 0.56 + ((bloodSeed >> 13) % 25) * 0.01
                local bloodPaint = nvgImagePattern(ctx, bloodX, bloodY, bloodW, bloodH, 0, bloodImg, bloodAlpha)
                nvgBeginPath(ctx)
                nvgRect(ctx, bloodX, bloodY, bloodW, bloodH)
                nvgFillPaint(ctx, bloodPaint)
                nvgFill(ctx)
            end
        end
    end

    -- ── 墙面电线线路 + 开关插座 ──────────────────────────────
    if rw > 20 and rh > 20 then
        local wireColor = nvgRGBA(40, 40, 40, 180)
        local wireW = 1.5
        -- 确定性随机：用世界坐标哈希决定开关在左墙还是右墙
        local wrx = rx + cameraX
        local wallSeed = hashXY(math.floor(wrx / 30), math.floor(ry / 30))
        local onLeft = (wallSeed % 2 == 0)

        -- 开关位置参数
        local switchW = math.max(4, math.floor(rw * 0.04))
        local switchH = math.floor(switchW * 1.6)
        local switchY = ry + math.floor(rh * 0.55)  -- 墙面中偏下
        local switchX
        local lampMidX = rx + math.floor(rw * 0.5)  -- 灯的中心X
        local wireWallX  -- 电线贴墙的X

        if onLeft then
            switchX = rx + math.floor(rw * 0.08)
            wireWallX = switchX + switchW * 0.5
        else
            switchX = rx + rw - math.floor(rw * 0.08) - switchW
            wireWallX = switchX + switchW * 0.5
        end

        -- 电线：从天花板灯中心水平到墙边，再竖直下到开关
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, lampMidX, ry + 2)
        nvgLineTo(ctx, wireWallX, ry + 2)        -- 天花板水平段
        nvgLineTo(ctx, wireWallX, switchY)        -- 竖直段到开关
        nvgStrokeColor(ctx, wireColor)
        nvgStrokeWidth(ctx, wireW)
        nvgStroke(ctx)

        -- 开关面板（白色小方块 + 暗边框）
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, switchX, switchY, switchW, switchH, 1)
        nvgFillColor(ctx, nvgRGBA(235, 235, 230, 220))
        nvgFill(ctx)
        nvgStrokeColor(ctx, nvgRGBA(80, 80, 80, 160))
        nvgStrokeWidth(ctx, 1.0)
        nvgStroke(ctx)

        -- 开关按钮（中间小横线）
        local btnY = switchY + math.floor(switchH * 0.45)
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, switchX + 1, btnY)
        nvgLineTo(ctx, switchX + switchW - 1, btnY)
        nvgStrokeColor(ctx, nvgRGBA(60, 60, 60, 200))
        nvgStrokeWidth(ctx, 1.0)
        nvgStroke(ctx)

        -- 有些房间加一个插座（低位，靠另一侧墙）
        if (wallSeed % 3) == 0 then
            local sockW = math.max(4, math.floor(rw * 0.035))
            local sockH = math.floor(sockW * 1.3)
            local sockY = ry + math.floor(rh * 0.78)
            local sockX = onLeft
                and (rx + rw - math.floor(rw * 0.10) - sockW)
                or  (rx + math.floor(rw * 0.10))

            -- 插座到天花板的竖直线路
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, sockX + sockW * 0.5, ry + 2)
            nvgLineTo(ctx, sockX + sockW * 0.5, sockY)
            nvgStrokeColor(ctx, wireColor)
            nvgStrokeWidth(ctx, wireW)
            nvgStroke(ctx)

            -- 插座面板
            nvgBeginPath(ctx)
            nvgRoundedRect(ctx, sockX, sockY, sockW, sockH, 1)
            nvgFillColor(ctx, nvgRGBA(235, 235, 230, 220))
            nvgFill(ctx)
            nvgStrokeColor(ctx, nvgRGBA(80, 80, 80, 160))
            nvgStrokeWidth(ctx, 1.0)
            nvgStroke(ctx)

            -- 插孔（两个小圆点）
            local holeR = math.max(1, math.floor(sockW * 0.12))
            local holeGap = math.floor(sockW * 0.25)
            local holeCY = sockY + math.floor(sockH * 0.5)
            local holeCX = sockX + math.floor(sockW * 0.5)
            nvgBeginPath(ctx)
            nvgCircle(ctx, holeCX - holeGap, holeCY, holeR)
            nvgCircle(ctx, holeCX + holeGap, holeCY, holeR)
            nvgFillColor(ctx, nvgRGBA(40, 40, 40, 200))
            nvgFill(ctx)
        end
    end
end

-- 绘制剖面楼主函数
-- 杂物高亮描边：玩家接近时白色闪烁轮廓
-- px/py = 玩家屏幕坐标，rx/ry/rw/rh = 道具矩形，threshold = 触发距离
-- 道具高亮闪烁：玩家靠近时贴图可见区域变白闪烁
-- 原理：NVG_LIGHTER 加法混合下再绘一次图片，有像素处趋向白色，透明区域不受影响
-- imgHandle: nvgCreateImage 返回的图片句柄
local function drawPropHighlight(ctx, px, py, rx, ry, rw, rh, imgHandle, threshold)
    local nearX = math.max(rx, math.min(px, rx + rw))
    local nearY = math.max(ry, math.min(py, ry + rh))
    local dist  = math.sqrt((px - nearX)^2 + (py - nearY)^2)
    if dist > threshold then return end

    local proximity = 1 - dist / threshold
    local flash = math.sin(gameTime * 8) * 0.5 + 0.5
    -- overlay alpha：0.3~1.0
    local oa = flash * 0.7 + proximity * 0.3
    oa = math.max(0.0, math.min(1.0, oa))

    -- NVG_LIGHTER：加法混合，叠加图片自身使可见像素趋向白色，透明像素不变
    nvgSave(ctx)
    nvgGlobalCompositeOperation(ctx, NVG_LIGHTER)
    local paint = nvgImagePattern(ctx, rx, ry, rw, rh, 0, imgHandle, oa)
    nvgBeginPath(ctx)
    nvgRect(ctx, rx, ry, rw, rh)
    nvgFillPaint(ctx, paint)
    nvgFill(ctx)
    nvgRestore(ctx)
end

-- 宝箱接近检测 + 白色放大镜提示绘制
-- chestIdx: chestDefs 中的索引; 返回 true 表示玩家在交互范围内
local function checkChestProximity(ctx, px, py, rx, ry, rw, rh, chestIdx, threshold)
    if not chestDefs[chestIdx] then return false end
    local nearX = math.max(rx, math.min(px, rx + rw))
    local nearY = math.max(ry, math.min(py, ry + rh))
    local dist = math.sqrt((px - nearX)^2 + (py - nearY)^2)
    -- 记录宝箱屏幕坐标（供摸金UI使用）
    chestScreenRects[chestIdx] = { x = rx, y = ry, w = rw, h = rh }
    if dist > threshold then return false end
    -- 玩家在范围内 → 始终选择距离最近的搜刮点，避免重叠区域锁死后绘制的交互。
    if dist < lootUI.nearChestDist then
        lootUI.nearChestDist = dist
        lootUI.nearChestIdx = chestIdx
    end
    -- 仅为当前最近搜刮点绘制提示，避免多个图标重叠。
    if lootUI.nearChestIdx ~= chestIdx then return true end

    -- 白色放大镜：圆形镜片 + 斜向手柄，无文字和按钮底板。
    local blink = math.sin(gameTime * 4.5) * 0.16 + 0.84
    local iconA = math.floor(255 * blink)
    local iconSize = 24
    local centerX = rx + rw * 0.5
    local centerY = ry - 18
    local lensR = iconSize * 0.26

    nvgSave(ctx)
    nvgResetScissor(ctx)
    nvgBeginPath(ctx)
    nvgCircle(ctx, centerX - 2, centerY - 2, lensR)
    nvgMoveTo(ctx, centerX + 2.5, centerY + 2.5)
    nvgLineTo(ctx, centerX + 8.5, centerY + 8.5)
    nvgStrokeColor(ctx, nvgRGBA(255, 255, 255, iconA))
    nvgStrokeWidth(ctx, 3)
    nvgLineCap(ctx, NVG_ROUND)
    nvgStroke(ctx)
    nvgRestore(ctx)
    return true
end

lootUI.CheckChestProximity = checkChestProximity

function lootUI.DrawRoomContainer(ctx, img, playerSX, playerSY, rx, ry, rw, rh, chestIdx, xRatio, wRatio, hRatio, bottomPad)
    if not img or img <= 0 or not chestIdx or not chestDefs[chestIdx] or not rw or rw <= 0 then return end
    local drawH = math.floor(rh * hRatio)
    local drawW = math.floor(drawH * wRatio)
    local drawX = rx + math.floor(rw * xRatio) - math.floor(drawW * 0.5)
    -- 图片画布通常带透明底边；用 bottomPad 把可见底脚压到地板线。
    local drawY = ry + rh - drawH + drawH * (bottomPad or 0)
    nvgSave(ctx)
    nvgScissor(ctx, rx, ry, rw, rh)
    local paint = nvgImagePattern(ctx, drawX, drawY, drawW, drawH, 0, img, 1.0)
    nvgBeginPath(ctx)
    nvgRect(ctx, drawX, drawY, drawW, drawH)
    nvgFillPaint(ctx, paint)
    nvgFill(ctx)
    drawPropHighlight(ctx, playerSX, playerSY, drawX, drawY, drawW, drawH, img, 85)
    checkChestProximity(ctx, playerSX, playerSY, drawX, drawY, drawW, drawH, chestIdx, 70)
    nvgRestore(ctx)
end

function lootUI.DrawKitchenSearchHint(ctx, playerSX, playerSY, rx, ry, rw, rh, chestIdx, xRatio, yRatio, wRatio, hRatio, labelText)
    if not chestIdx or not chestDefs[chestIdx] or not rw or rw <= 0 then return end
    local hitW = math.floor(rw * wRatio)
    local hitH = math.floor(rh * hRatio)
    local hitX = rx + math.floor(rw * xRatio) - math.floor(hitW * 0.5)
    local hitY = ry + math.floor(rh * yRatio)

    -- 热区仅用于接近检测；不绘制边框或文字，避免破坏房间画面。
    checkChestProximity(ctx, playerSX, playerSY, hitX, hitY, hitW, hitH, chestIdx, 70)
end

function lootUI.DrawLetterUI(ctx, screenW, screenH)
    if not lootUI.letterOpen then return end

    local t = math.max(0, math.min(1, lootUI.letterAnim or 0))
    local eased = 1 - (1 - t) * (1 - t) * (1 - t)
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, screenW, screenH)
    nvgFillColor(ctx, nvgRGBA(8, 9, 10, math.floor(185 * eased)))
    nvgFill(ctx)

    -- 手机界面使用 2:3 的加宽长信纸；按图片原比例缩放，不做横向压缩。
    local maxPaperW = math.min(screenW * 0.88, 460)
    local maxPaperH = screenH * 0.88
    local paperAspect = 896 / 1344
    local finalH = maxPaperH
    local finalW = finalH * paperAspect
    if finalW > maxPaperW then
        finalW = maxPaperW
        finalH = finalW / paperAspect
    end
    local startW = finalW * 0.18
    local startH = finalH * 0.18
    local paperW = startW + (finalW - startW) * eased
    local paperH = startH + (finalH - startH) * eased
    local targetX = screenW * 0.5
    local targetY = screenH * 0.50
    local startX = screenW * 0.80
    local startY = screenH * 0.90
    local centerX = startX + (targetX - startX) * eased
    local centerY = startY + (targetY - startY) * eased
    local paperX = centerX - paperW * 0.5
    local paperY = centerY - paperH * 0.5
    local angle = (1 - eased) * 0.20

    nvgSave(ctx)
    nvgTranslate(ctx, centerX, centerY)
    nvgRotate(ctx, angle)
    nvgTranslate(ctx, -centerX, -centerY)

    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, paperX + 7, paperY + 10, paperW, paperH, 8)
    nvgFillColor(ctx, nvgRGBA(0, 0, 0, math.floor(105 * eased)))
    nvgFill(ctx)

    if lootUI.letterPaperImg and lootUI.letterPaperImg > 0 then
        local paperPaint = nvgImagePattern(ctx, paperX, paperY, paperW, paperH, 0, lootUI.letterPaperImg, eased)
        nvgBeginPath(ctx)
        nvgRect(ctx, paperX, paperY, paperW, paperH)
        nvgFillPaint(ctx, paperPaint)
        nvgFill(ctx)
    else
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, paperX, paperY, paperW, paperH, 8)
        nvgFillColor(ctx, nvgRGBA(232, 210, 158, math.floor(255 * eased)))
        nvgFill(ctx)
    end

    if t > 0.58 then
        local textAlpha = math.floor(255 * ((t - 0.58) / 0.42))
        -- 长信纸边缘较窄，正文使用中央大面积干净书写区。
        local safeLeft = paperX + paperW * 0.13
        local safeTop = paperY + paperH * 0.145
        local safeRight = paperX + paperW * 0.87
        local safeBottom = paperY + paperH * 0.875

        nvgFontFace(ctx, "sans")
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFontSize(ctx, math.max(15, math.min(20, finalW * 0.052)))
        nvgFillColor(ctx, nvgRGBA(76, 48, 29, textAlpha))
        nvgText(ctx, paperX + paperW * 0.5, paperY + paperH * 0.105, "留给后来者")

        nvgSave(ctx)
        nvgScissor(
            ctx,
            safeLeft,
            safeTop,
            safeRight - safeLeft,
            safeBottom - safeTop
        )
        nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        nvgFontSize(ctx, math.max(10, math.min(13, finalW * 0.032)))
        nvgFillColor(ctx, nvgRGBA(67, 45, 29, math.floor(textAlpha * 0.96)))
        local textX = safeLeft
        local textY = paperY + paperH * 0.175
        local lineGap = paperH * 0.056
        for i, line in ipairs(lootUI.letterContent) do
            local lineY = textY + (i - 1) * lineGap
            if lineY <= safeBottom - lineGap * 0.5 then
                nvgText(ctx, textX, lineY, line)
            end
        end
        nvgRestore(ctx)

        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFontSize(ctx, 8)
        nvgFillColor(ctx, nvgRGBA(88, 59, 36, math.floor(textAlpha * 0.72)))
        nvgText(ctx, paperX + paperW * 0.5, paperY + paperH * 0.925, "按 F / ESC 或下方按钮收起")
    end
    nvgRestore(ctx)
end

-- ── 计算物品在网格中的放置位置（左上角优先装箱算法） ──
-- 返回 { {item=name, col=0起始列, row=0起始行, w=宽格数, h=高格数}, ... }
local function layoutChestGrid(items, cols, rows)
    cols = cols or CHEST_GRID_COLS
    rows = rows or CHEST_GRID_ROWS
    -- 初始化占位矩阵 (0=空, 1=占)
    local grid = {}
    for r = 0, rows - 1 do
        grid[r] = {}
        for c = 0, cols - 1 do
            grid[r][c] = false
        end
    end

    local placements = {}

    local function placeAt(itemName, iw, ih, sourceIdx, orientation, taken, col, row)
        if not col or not row or col < 0 or row < 0 or col + iw > cols or row + ih > rows then
            return false
        end
        for dr = 0, ih - 1 do
            for dc = 0, iw - 1 do
                if grid[row + dr][col + dc] then return false end
            end
        end
        for dr = 0, ih - 1 do
            for dc = 0, iw - 1 do
                grid[row + dr][col + dc] = true
            end
        end
        table.insert(placements, {
            item = itemName,
            idx = sourceIdx,
            col = col,
            row = row,
            w = iw,
            h = ih,
            orientation = orientation,
            taken = taken,
        })
        return true
    end

    -- 尝试放置一个物品（寻找第一个能容纳 w×h 的位置）
    local function tryPlace(itemName, iw, ih, sourceIdx, orientation, taken)
        for r = 0, rows - ih do
            for c = 0, cols - iw do
                -- 检查 w×h 区域是否全部空闲
                local canFit = true
                for dr = 0, ih - 1 do
                    for dc = 0, iw - 1 do
                        if grid[r + dr][c + dc] then
                            canFit = false
                            break
                        end
                    end
                    if not canFit then break end
                end
                if canFit then
                    -- 标记占位
                    for dr = 0, ih - 1 do
                        for dc = 0, iw - 1 do
                            grid[r + dr][c + dc] = true
                        end
                    end
                    table.insert(placements, {item = itemName, idx = sourceIdx, col = c, row = r, w = iw, h = ih, orientation = orientation, taken = taken})
                    return true
                end
            end
        end
        return false
    end

    for sourceIdx, entry in ipairs(items) do
        local itemName = lootUI.GetGridItemName(entry)
        local iw, ih, orientation = lootUI.GetGridItemSize(entry)
        if type(itemName) == "string" and itemName ~= "" then
            local taken = lootUI.IsTakenGridEntry(entry)
            local storedCol = type(entry) == "table" and entry.col or nil
            local storedRow = type(entry) == "table" and entry.row or nil
            local placed = placeAt(
                itemName,
                iw,
                ih,
                sourceIdx,
                orientation,
                taken,
                storedCol,
                storedRow
            )
            if not placed then
                placed = tryPlace(itemName, iw, ih, sourceIdx, orientation, taken)
                if placed and not taken then
                    local p = placements[#placements]
                    items[sourceIdx] = lootUI.MakeGridItem(
                        itemName,
                        p.col,
                        p.row,
                        p.orientation
                    )
                end
            end
        end
    end

    -- 过滤掉已拾取的占位项（渲染和点击不需要它们）
    local visiblePlacements = {}
    for _, p in ipairs(placements) do
        if not p.taken then
            table.insert(visiblePlacements, p)
        end
    end

    return visiblePlacements, grid
end

function lootUI.GetChestGridDimensions()
    if lootUI.mode == "loadout" then
        local tab = warehouseTabs and warehouseTabs[1]
        return (tab and tab.cols) or 8, (tab and tab.rows) or 20
    end
    return CHEST_GRID_COLS, CHEST_GRID_ROWS
end

function lootUI.IsPointInGridViewport(cache, x, y)
    return cache and x >= cache.areaX and x <= cache.areaX + cache.areaW
        and y >= cache.areaY and y <= cache.areaY + cache.areaH
end

-- ══ 通用带位置网格布局系统 ══
-- 容器格式: { {item="名字", col=0, row=0}, ... }
-- 返回 placements: { {item="名字", col=X, row=Y, w=宽, h=高}, ... }

-- 通用布局：优先读取已存储的位置；位置冲突时自动寻找空位，绝不隐藏物品。
local function layoutPositionalGrid(items, cols, rows)
    local grid = {}
    for r = 0, rows - 1 do
        grid[r] = {}
        for c = 0, cols - 1 do
            grid[r][c] = false
        end
    end
    local placements = {}
    for sourceIdx, entry in ipairs(items) do
        local itemName = lootUI.GetGridItemName(entry)
        local iw, ih, orientation = lootUI.GetGridItemSize(entry)
        local col = type(entry) == "table" and entry.col or nil
        local row = type(entry) == "table" and entry.row or nil
        local placed = false

        if col and row and col >= 0 and row >= 0 and col + iw <= cols and row + ih <= rows then
            local fits = true
            for dr = 0, ih - 1 do
                for dc = 0, iw - 1 do
                    if grid[row + dr] and grid[row + dr][col + dc] then
                        fits = false
                        break
                    end
                end
                if not fits then break end
            end
            if fits then
                for dr = 0, ih - 1 do
                    for dc = 0, iw - 1 do
                        grid[row + dr][col + dc] = true
                    end
                end
                table.insert(placements, {item = itemName, idx = sourceIdx, col = col, row = row, w = iw, h = ih, orientation = orientation})
                placed = true
            end
        end

        -- 当前位置无效或没有存储位置时，先尝试当前方向；放不下则自动旋转 90°。
        if not placed then
            local candidateOrientations = { orientation }
            if iw ~= ih then
                candidateOrientations[2] = orientation == "vertical" and "horizontal" or "vertical"
            end
            for _, candidateOrientation in ipairs(candidateOrientations) do
                local candidateW, candidateH = lootUI.GetGridItemSize(itemName, candidateOrientation)
                for r = 0, rows - candidateH do
                    for c = 0, cols - candidateW do
                        local canFit = true
                        for dr = 0, candidateH - 1 do
                            for dc = 0, candidateW - 1 do
                                if grid[r + dr][c + dc] then
                                    canFit = false
                                    break
                                end
                            end
                            if not canFit then break end
                        end
                        if canFit then
                            for dr = 0, candidateH - 1 do
                                for dc = 0, candidateW - 1 do
                                    grid[r + dr][c + dc] = true
                                end
                            end
                            if not lootUI.IsTakenGridEntry(entry) then
                                items[sourceIdx] = lootUI.MakeGridItem(
                                    itemName,
                                    c,
                                    r,
                                    candidateOrientation
                                )
                            end
                            table.insert(placements, {
                                item = itemName,
                                idx = sourceIdx,
                                col = c,
                                row = r,
                                w = candidateW,
                                h = candidateH,
                                orientation = candidateOrientation,
                            })
                            placed = true
                            break
                        end
                    end
                    if placed then break end
                end
                if placed then break end
            end
        end
    end
    return placements, grid
end

-- 检查指定物品能否放入网格的指定位置
local function canPlaceAtPosition(items, itemName, targetCol, targetRow, cols, rows, orientation)
    local iw, ih = lootUI.GetGridItemSize(itemName, orientation)
    if targetCol + iw > cols or targetRow + ih > rows then return false end
    -- 构建占用网格（排除要放置的物品本身）
    local grid = {}
    for r = 0, rows - 1 do
        grid[r] = {}
        for c = 0, cols - 1 do grid[r][c] = false end
    end
    local placements = layoutPositionalGrid(items, cols, rows)
    for _, p in ipairs(placements) do
        for dr = 0, p.h - 1 do
            for dc = 0, p.w - 1 do
                if grid[p.row + dr] then grid[p.row + dr][p.col + dc] = true end
            end
        end
    end
    -- 检查目标区域是否空闲
    for dr = 0, ih - 1 do
        for dc = 0, iw - 1 do
            if grid[targetRow + dr][targetCol + dc] then return false end
        end
    end
    return true
end

function lootUI.FindFreeGridPosition(items, itemName, cols, rows, orientation)
    local _, occupied = layoutPositionalGrid(items, cols, rows)
    local candidateOrientations = { orientation }
    local baseW, baseH = lootUI.GetGridItemSize(itemName, orientation)
    if baseW ~= baseH then
        candidateOrientations[2] = orientation == "vertical" and "horizontal" or "vertical"
    end
    for _, candidateOrientation in ipairs(candidateOrientations) do
        local itemW, itemH = lootUI.GetGridItemSize(itemName, candidateOrientation)
        for row = 0, rows - itemH do
            for col = 0, cols - itemW do
                local fits = true
                for dr = 0, itemH - 1 do
                    for dc = 0, itemW - 1 do
                        if occupied[row + dr] and occupied[row + dr][col + dc] then
                            fits = false
                            break
                        end
                    end
                    if not fits then break end
                end
                if fits then
                    return col, row, candidateOrientation
                end
            end
        end
    end
    return nil
end

-- 所有仓库/随身容器统一使用精确拖放：只允许放入玩家指向的空位，
-- 目标占用或越界时返回 false，由释放逻辑恢复原位置；绝不移动其他物资。
function tryPlaceOrSwapGrid(
    targetItems,
    itemName,
    targetCol,
    targetRow,
    targetCols,
    targetRows,
    sourceItems,
    sourceCols,
    sourceRows,
    sourceCol,
    sourceRow,
    orientation
)
    if not canPlaceAtPosition(
        targetItems,
        itemName,
        targetCol,
        targetRow,
        targetCols,
        targetRows,
        orientation
    ) then
        return false
    end
    table.insert(
        targetItems,
        lootUI.MakeGridItem(itemName, targetCol, targetRow, orientation)
    )
    return true
end

-- 各容器的布局函数（兼容旧接口）
local function layoutInventoryGrid(items) return layoutPositionalGrid(items, INV_GRID_COLS, INV_GRID_ROWS) end
local function layoutRigGrid(items) return layoutPositionalGrid(items, RIG_GRID_COLS, RIG_GRID_ROWS) end
local function layoutPocketGrid(items) return layoutPositionalGrid(items, PKT_GRID_COLS, PKT_GRID_ROWS) end
local function layoutSafeGrid(items) return layoutPositionalGrid(items, SAFE_GRID_COLS, SAFE_GRID_ROWS) end

-- 检查容器是否能放下物品（自动找位）
local function canFitInRig(itemName)
    if lootUI.equippedRigItem == "" then return false end
    if #playerChestRig >= RIG_MAX then return false end
    local col, row, orientation = lootUI.FindFreeGridPosition(playerChestRig, itemName, RIG_GRID_COLS, RIG_GRID_ROWS, "horizontal")
    return col ~= nil, orientation or "horizontal"
end
local function canFitInPocket(itemName)
    if #playerPocket >= PKT_MAX then return false end
    local col, row, orientation = lootUI.FindFreeGridPosition(playerPocket, itemName, PKT_GRID_COLS, PKT_GRID_ROWS, "horizontal")
    return col ~= nil, orientation or "horizontal"
end
local function canFitInSafe(itemName)
    if lootUI.equippedSafeBoxItem == "" then return false end
    if #playerSafeBox >= SAFE_MAX then return false end
    local col, row, orientation = lootUI.FindFreeGridPosition(playerSafeBox, itemName, SAFE_GRID_COLS, SAFE_GRID_ROWS, "horizontal")
    return col ~= nil, orientation or "horizontal"
end
local function canFitInInventory(itemName)
    if lootUI.equippedBackpackItem == "" then return false end
    local col, row, orientation = lootUI.FindFreeGridPosition(playerInventory, itemName, INV_GRID_COLS, INV_GRID_ROWS, "horizontal")
    return col ~= nil, orientation or "horizontal"
end

function lootUI.PickupLooseWorldItem(pickup)
    if not pickup or pickup.picked then return false end
    local itemName = pickup.item
    local placed = false
    local function addToContainer(container, itemOrientation)
        table.insert(container, lootUI.MakeGridItem(itemName, nil, nil, itemOrientation))
        return true
    end
    local fits, orientation = canFitInPocket(itemName)
    if fits then
        placed = addToContainer(playerPocket, orientation)
    else
        fits, orientation = canFitInRig(itemName)
        if fits then
            placed = addToContainer(playerChestRig, orientation)
        else
            fits, orientation = canFitInInventory(itemName)
            if fits then
                placed = addToContainer(playerInventory, orientation)
            else
                fits, orientation = canFitInSafe(itemName)
                if fits then
                    placed = addToContainer(playerSafeBox, orientation)
                end
            end
        end
    end
    if placed then
        pickup.picked = true
        print("[Pickup] 直接拾取厕所物品: " .. itemName)
    else
        print("[Pickup] 容器空间不足，无法拾取: " .. itemName)
    end
    return placed
end

-- ── 摸金UI绘制（三角洲行动风格） ──
-- ── 辅助：从容器中按索引移除物品 ──
local function removeFromContainer(container, idx)
    local item = container[idx]
    table.remove(container, idx)
    return item
end

local function getGridStep(cache)
    return (cache.cellSize or 0) + (cache.gap or 0)
end

function isGunItem(itemName)
    return itemName == "手枪" or itemName == "散弹枪"
end

function isShotgunEquipped()
    return lootUI.equippedGunItem == "散弹枪"
end

function isMeleeItem(itemName)
    return itemName == "棒球棍"
end

function lootUI.SelectItem(hit)
    if not hit then
        lootUI.selectedSlot = 0
        lootUI.selectedItem = ""
        lootUI.selectedContainer = ""
        lootUI.selectedIdx = 0
        lootUI.selectedRect = nil
        return
    end
    lootUI.selectedSlot = hit.idx or 0
    lootUI.selectedItem = hit.item or ""
    lootUI.selectedContainer = hit.container or ""
    lootUI.selectedIdx = hit.idx or 0
    lootUI.selectedRect = hit.px and { x = hit.px, y = hit.py, w = hit.pw, h = hit.ph } or nil
end

function lootUI.IsItemSelected(container, sourceIdx)
    return lootUI.selectedContainer == container and lootUI.selectedIdx == sourceIdx
end

function lootUI.DrawSelection(ctx, container, sourceIdx, x, y, w, h, anim)
    if not lootUI.IsItemSelected(container, sourceIdx) then return end
    lootUI.selectedRect = { x = x, y = y, w = w, h = h }
    nvgBeginPath(ctx)
    nvgRect(ctx, x - 2, y - 2, w + 4, h + 4)
    nvgStrokeColor(ctx, nvgRGBA(255, 230, 90, math.floor(240 * anim)))
    nvgStrokeWidth(ctx, 3)
    nvgStroke(ctx)
    nvgBeginPath(ctx)
    nvgRect(ctx, x + 2, y + 2, math.max(0, w - 4), math.max(0, h - 4))
    nvgStrokeColor(ctx, nvgRGBA(255, 255, 255, math.floor(120 * anim)))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)
end

function lootUI.DrawContainerEquipmentSlot(ctx, key, itemName, emptyLabel, x, y, w, h, color, anim)
    lootUI._equipSlotCache[key] = { x = x, y = y, w = w, h = h }
    nvgBeginPath(ctx)
    nvgRect(ctx, x, y, w, h)
    nvgFillColor(ctx, nvgRGBA(color[1], color[2], color[3], math.floor(200 * anim)))
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgRect(ctx, x, y, w, h)
    nvgStrokeColor(ctx, nvgRGBA(color[4], color[5], color[6], math.floor(160 * anim)))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)

    if itemName and itemName ~= "" then
        local rarity = ITEM_RARITY[itemName] or "green"
        drawRarityGradient(ctx, rarity, x, y, w, h, anim * 0.84, 3)
        local iconId = itemIcons[itemName]
        if iconId and iconId > 0 then
            local iconX, iconY, iconW, iconH = getItemIconDrawRect(itemName, x + 3, y + 3, w - 6, h - 18, 0.78)
            local paint = nvgImagePattern(ctx, iconX, iconY, iconW, iconH, 0, iconId, anim)
            nvgBeginPath(ctx)
            nvgRect(ctx, iconX, iconY, iconW, iconH)
            nvgFillPaint(ctx, paint)
            nvgFill(ctx)
        end
        nvgFontSize(ctx, 9)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
        nvgFillColor(ctx, nvgRGBA(240, 230, 205, math.floor(235 * anim)))
        nvgText(ctx, x + w * 0.5, y + h - 3, itemName)
        lootUI.DrawSelection(ctx, "equip_" .. key, 1, x, y, w, h, anim)
    else
        nvgFontSize(ctx, 10)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(ctx, nvgRGBA(color[4], color[5], color[6], math.floor(150 * anim)))
        nvgText(ctx, x + w * 0.5, y + h * 0.5, emptyLabel)
    end
end

function lootUI.DrawItemTooltip(ctx, screenW, screenH, anim)
    local itemName = lootUI.selectedItem
    if not itemName or itemName == "" then return end
    local info = lootUI.itemValues[itemName]
    if not info then return end
    local rarity = ITEM_RARITY[itemName] or "green"
    local rc = RARITY_COLORS[rarity] or RARITY_COLORS.green
    local rarityText = ({ red = "传说", pink = "史诗", gold = "金币", purple = "稀有", blue = "精良", green = "普通" })[rarity] or "普通"
    local tipW = math.min(300, math.floor(screenW * 0.34))
    local tipH = 118
    local anchor = lootUI.selectedRect
    local margin = 10
    local tipX = math.max(8, screenW - tipW - 14)
    local tipY = math.max(48, screenH - tipH - 32)
    local arrowSide = "none"
    if anchor then
        if anchor.x + anchor.w + margin + tipW <= screenW - 8 then
            tipX = anchor.x + anchor.w + margin
            arrowSide = "left"
        elseif anchor.x - margin - tipW >= 8 then
            tipX = anchor.x - margin - tipW
            arrowSide = "right"
        else
            tipX = math.max(8, math.min(anchor.x + anchor.w * 0.5 - tipW * 0.5, screenW - tipW - 8))
            arrowSide = "top"
        end
        tipY = math.max(42, math.min(anchor.y + anchor.h * 0.5 - tipH * 0.5, screenH - tipH - 28))
    end

    nvgSave(ctx)
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, tipX, tipY, tipW, tipH, 8)
    if arrowSide == "left" then
        local ay = math.max(tipY + 14, math.min(anchor.y + anchor.h * 0.5, tipY + tipH - 14))
        nvgMoveTo(ctx, tipX, ay - 8)
        nvgLineTo(ctx, tipX - 8, ay)
        nvgLineTo(ctx, tipX, ay + 8)
    elseif arrowSide == "right" then
        local ay = math.max(tipY + 14, math.min(anchor.y + anchor.h * 0.5, tipY + tipH - 14))
        nvgMoveTo(ctx, tipX + tipW, ay - 8)
        nvgLineTo(ctx, tipX + tipW + 8, ay)
        nvgLineTo(ctx, tipX + tipW, ay + 8)
    elseif arrowSide == "top" then
        local ax = math.max(tipX + 16, math.min(anchor.x + anchor.w * 0.5, tipX + tipW - 16))
        nvgMoveTo(ctx, ax - 8, tipY)
        nvgLineTo(ctx, ax, tipY - 8)
        nvgLineTo(ctx, ax + 8, tipY)
    end
    nvgFillColor(ctx, nvgRGBA(10, 14, 18, math.floor(235 * anim)))
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, tipX, tipY, tipW, tipH, 8)
    nvgStrokeColor(ctx, nvgRGBA(rc[1], rc[2], rc[3], math.floor(230 * anim)))
    nvgStrokeWidth(ctx, 2)
    nvgStroke(ctx)

    local iconId = itemIcons[itemName]
    local iconSize = 48
    local iconX = tipX + 12
    local iconY = tipY + 14
    drawRarityGradient(ctx, rarity, iconX, iconY, iconSize, iconSize, anim, 5)
    if iconId and iconId > 0 then
        local drawX, drawY, drawW, drawH = getItemIconDrawRect(
            itemName, iconX + 2, iconY + 2, iconSize - 4, iconSize - 4, 0.96)
        local paint = nvgImagePattern(ctx, drawX, drawY, drawW, drawH, 0, iconId, anim)
        nvgBeginPath(ctx)
        nvgRect(ctx, drawX, drawY, drawW, drawH)
        nvgFillPaint(ctx, paint)
        nvgFill(ctx)
    end

    nvgFontFace(ctx, "sans")
    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFontSize(ctx, 15)
    nvgFillColor(ctx, nvgRGBA(245, 245, 235, math.floor(255 * anim)))
    nvgText(ctx, tipX + 72, tipY + 14, itemName)
    nvgFontSize(ctx, 11)
    nvgFillColor(ctx, nvgRGBA(rc[1], rc[2], rc[3], math.floor(245 * anim)))
    nvgText(ctx, tipX + 72, tipY + 36, rarityText)
    nvgFillColor(ctx, nvgRGBA(235, 205, 120, math.floor(245 * anim)))
    nvgText(ctx, tipX + 72, tipY + 54, "物品价值: " .. lootUI.FormatBitValue(info.value))
    nvgFillColor(ctx, nvgRGBA(180, 190, 198, math.floor(230 * anim)))
    nvgFontSize(ctx, 11)
    nvgTextBox(ctx, tipX + 12, tipY + 76, tipW - 24, info.desc)
    nvgRestore(ctx)
end

-- ── 辅助：检测鼠标命中哪个容器的哪个物品 ──
local function hitTestAllContainers(mx, my)
    local gc = lootUI._gridCache
    if not gc then return nil end
    local containers = {
        { name = "rig",    list = playerChestRig, layout = layoutRigGrid,    cache = gc.rig },
        { name = "pocket", list = playerPocket,   layout = layoutPocketGrid, cache = gc.pocket },
        { name = "inv",    list = playerInventory, layout = layoutInventoryGrid, cache = gc.inv },
        { name = "safe",   list = playerSafeBox,  layout = layoutSafeGrid,  cache = gc.safe },
    }
    for _, c in ipairs(containers) do
        if c.cache then
            local placements = c.layout(c.list)
            for _, p in ipairs(placements) do
                local cs = c.cache.cellSize
                local step = getGridStep(c.cache)
                local px = c.cache.offX + p.col * step
                local py = c.cache.offY + p.row * step
                local pw = p.w * cs + (p.w - 1) * (c.cache.gap or 0)
                local ph = p.h * cs + (p.h - 1) * (c.cache.gap or 0)
                if mx >= px and mx <= px + pw and my >= py and my <= py + ph then
                    return {
                        container = c.name,
                        idx = p.idx or 0,
                        item = p.item,
                        col = p.col,
                        row = p.row,
                        orientation = p.orientation,
                        px = px,
                        py = py,
                        pw = pw,
                        ph = ph,
                    }
                end
            end
        end
    end
    local equipItems = {
        helmet = lootUI.equippedHelmetItem,
        armor = lootUI.equippedArmorItem,
        rig = lootUI.equippedRigItem,
        backpack = lootUI.equippedBackpackItem,
        safe_box = lootUI.equippedSafeBoxItem,
        gun = lootUI.equippedGunItem,
        melee = lootUI.equippedMeleeItem,
    }
    for key, item in pairs(equipItems) do
        local slot = lootUI._equipSlotCache and lootUI._equipSlotCache[key]
        if slot and item and item ~= "" and mx >= slot.x and mx <= slot.x + slot.w and my >= slot.y and my <= slot.y + slot.h then
            return { container = "equip_" .. key, idx = 1, item = item, px = slot.x, py = slot.y, pw = slot.w, ph = slot.h }
        end
    end
    if gc.chest then
        local chest = chestDefs[lootUI.chestIdx]
        if chest and lootUI.IsPointInGridViewport(gc.chest, mx, my) then
            local chestCols, chestRows = lootUI.GetChestGridDimensions()
            local placements = layoutChestGrid(chest.items, chestCols, chestRows)
            for _, p in ipairs(placements) do
                local cs = gc.chest.cellSize
                local step = getGridStep(gc.chest)
                local px = gc.chest.offX + p.col * step
                local py = gc.chest.offY + p.row * step
                local pw = p.w * cs + (p.w - 1) * (gc.chest.gap or 0)
                local ph = p.h * cs + (p.h - 1) * (gc.chest.gap or 0)
                if mx >= px and mx <= px + pw and my >= py and my <= py + ph then
                    return { container = "chest", idx = p.idx or 0, item = p.item, col = p.col, row = p.row, orientation = p.orientation, px = px, py = py, pw = pw, ph = ph }
                end
            end
        end
    end
    return nil
end

-- ── 辅助：检测坐标在哪个容器区域上方 ──
local function getDropTargetAt(x, y)
    local gc = lootUI._gridCache
    if not gc then return nil end
    local containers = {}
    if lootUI.equippedRigItem ~= "" then table.insert(containers, "rig") end
    table.insert(containers, "pocket")
    if lootUI.equippedBackpackItem ~= "" then table.insert(containers, "inv") end
    if lootUI.equippedSafeBoxItem ~= "" then table.insert(containers, "safe") end
    if lootUI.mode ~= "inventory" then table.insert(containers, "chest") end
    for _, name in ipairs(containers) do
        local c = gc[name]
        if c then
            if x >= c.areaX and x <= c.areaX + c.areaW and y >= c.areaY and y <= c.areaY + c.areaH then
                return name
            end
        end
    end
    local equipSlots = lootUI._equipSlotCache or {}
    local equipTargets = {
        { key = "helmet", target = "equip_helmet", accepts = lootUI.dragItem == "二级头盔" },
        { key = "armor", target = "equip_armor", accepts = lootUI.dragItem == "二级防弹衣" },
        { key = "rig", target = "equip_rig", accepts = lootUI.dragItem == "二级胸挂" },
        { key = "backpack", target = "equip_backpack", accepts = lootUI.dragItem == "二级背包" },
        { key = "safe_box", target = "equip_safe_box", accepts = lootUI.IsSafeBoxItem(lootUI.dragItem) },
        { key = "gun", target = "equip_gun", accepts = isGunItem(lootUI.dragItem) },
        { key = "melee", target = "equip_melee", accepts = isMeleeItem(lootUI.dragItem) },
    }
    for _, target in ipairs(equipTargets) do
        local c = equipSlots[target.key]
        if c and target.accepts and x >= c.x and x <= c.x + c.w and y >= c.y and y <= c.y + c.h then
            return target.target
        end
    end
    return nil
end

-- ── 辅助：检测拖拽物品应该投放到哪个容器区域 ──
local function getDropTarget(mx, my)
    if lootUI.dragging and lootUI.dragItem ~= "" then
        local itemW, itemH = lootUI.GetGridItemSize(lootUI.dragItem, lootUI.dragOrientation)
        local itemLeft = mx - lootUI.dragOffX
        local itemTop = my - lootUI.dragOffY
        local centerX = itemLeft + itemW * 18
        local centerY = itemTop + itemH * 18
        return getDropTargetAt(centerX, centerY) or getDropTargetAt(itemLeft, itemTop) or getDropTargetAt(mx, my)
    end
    return getDropTargetAt(mx, my)
end

function lootUI.ScrollAt(x, y, delta)
    local chestCache = lootUI._gridCache and lootUI._gridCache.chest
    if lootUI.mode == "loadout" and lootUI.IsPointInGridViewport(chestCache, x, y) then
        lootUI.rightScrollY = math.max(0,
            math.min(lootUI.rightScrollY + delta, lootUI.rightScrollMax or 0))
        return "chest"
    end
    lootUI.midScrollY = math.max(0, lootUI.midScrollY + delta)
    return "mid"
end

function drawInventoryPlayerIdle(ctx, charPanelX, charPanelW, charAreaY, charAreaH, isInventoryMode, alpha)
    local cfg = PLAYER_ANIM_CONFIGS[PLAYER_ANIM_SET]
    if not cfg or not cfg.frames or #cfg.frames == 0 then return false end

    local startFrame = cfg.idleStart or 1
    local endFrame = cfg.idleEnd or startFrame
    local idleFrameCount = math.max(1, endFrame - startFrame + 1)
    local frameIndex = startFrame + (math.floor(gameTime * (cfg.fps or 12)) % idleFrameCount)
    local frameTable = cfg.frames
    if cfg.actionFrames then
        frameTable = cfg.actionFrames.walk or cfg.frames
    end
    local img = frameTable[frameIndex]
    if not img or img <= 0 then return false end

    local frameW = cfg.frameW or PLAYER_IMG_W
    local frameH = cfg.frameH or PLAYER_IMG_H
    local targetH = math.min(
        charAreaH * (isInventoryMode and 0.82 or 0.88),
        isInventoryMode and 180 or 140
    )
    local targetW = targetH * (frameW / frameH)
    if targetW > charPanelW * 0.92 then
        targetW = charPanelW * 0.92
        targetH = targetW * (frameH / frameW)
    end

    local drawX = charPanelX + (charPanelW - targetW) * 0.5
    local drawY = charAreaY + (charAreaH - targetH) * 0.5 - (isInventoryMode and 14 or 8)
    local tint = nvgRGBA(255, 255, 255, math.floor(255 * alpha))
    local paint = nvgImagePatternTinted(ctx, drawX, drawY, targetW, targetH, 0, img, tint)
    nvgBeginPath(ctx)
    nvgRect(ctx, drawX, drawY, targetW, targetH)
    nvgFillPaint(ctx, paint)
    nvgFill(ctx)
    return true
end

local function drawLootUI(ctx, screenW, screenH)
    if not lootUI.active then return end
    local chest = chestDefs[lootUI.chestIdx]
    if not chest then lootUI.active = false; return end
    local isLoadoutMode = lootUI.mode == "loadout"

    lootUI.animTimer = math.min(lootUI.animTimer + 0.05, 1.0)
    local anim = lootUI.animTimer

    -- 初始化网格位置缓存（供拖拽命中检测使用）
    lootUI._gridCache = {}
    lootUI.selectedRect = nil

    -- ── 全屏半透明遮罩 ──
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, screenW, screenH)
    nvgFillColor(ctx, nvgRGBA(0, 0, 0, math.floor(180 * anim)))
    nvgFill(ctx)

    -- ── 整体面板（满屏）──
    local panelW = screenW
    local panelH = screenH
    local panelX = 0
    local panelY = 0

    -- 全屏不透明背景（遮挡游戏画面）
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, screenW, screenH)
    nvgFillColor(ctx, nvgRGBA(12, 14, 18, math.floor(255 * anim)))
    nvgFill(ctx)

    -- 滑入动画
    local slideY = panelY + math.floor((1 - anim) * 30)

    -- ── 顶部标题栏 ──
    local titleH = isLoadoutMode and 44 or 58
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, panelX, slideY, panelW, titleH, 6)
    nvgFillColor(ctx, nvgRGBA(25, 30, 35, math.floor(250 * anim)))
    nvgFill(ctx)
    nvgFontFace(ctx, "sans")
    -- 关闭按钮放左上，避免被右侧平台/收入/虚拟控件遮挡
    local closeSize = isLoadoutMode and 36 or 48
    local closeX = panelX + (isLoadoutMode and 7 or 8)
    local closeBtnY = slideY + math.floor((titleH - closeSize) * 0.5)
    local closeInset = isLoadoutMode and 11 or 15
    lootUI.closeButtonRect = { x = closeX, y = closeBtnY, w = closeSize, h = closeSize }
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, closeX, closeBtnY, closeSize, closeSize, 8)
    nvgFillColor(ctx, nvgRGBA(160, 50, 50, math.floor(225 * anim)))
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, closeX + closeInset, closeBtnY + closeInset)
    nvgLineTo(ctx, closeX + closeSize - closeInset, closeBtnY + closeSize - closeInset)
    nvgMoveTo(ctx, closeX + closeSize - closeInset, closeBtnY + closeInset)
    nvgLineTo(ctx, closeX + closeInset, closeBtnY + closeSize - closeInset)
    nvgStrokeColor(ctx, nvgRGBA(255, 255, 255, math.floor(250 * anim)))
    nvgStrokeWidth(ctx, isLoadoutMode and 3 or 4)
    nvgStroke(ctx)

    nvgFontSize(ctx, isLoadoutMode and 12 or 14)
    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(ctx, nvgRGBA(200, 200, 200, math.floor(220 * anim)))
    nvgText(ctx, closeX + closeSize + 12, slideY + math.floor(titleH * 0.5),
        isLoadoutMode and "战前整备" or (inventoryOpenedFromHome and "据点仓库" or (lootUI.mode == "inventory" and "战术背包" or "搜刮")))
    -- 标题中间：仓库页显示物资管理说明，搜刮页显示容器名称
    nvgFontSize(ctx, isLoadoutMode and 14 or 15)
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(ctx, nvgRGBA(255, 220, 80, math.floor(255 * anim)))
    nvgText(ctx, panelX + math.floor(panelW * 0.5), slideY + math.floor(titleH * 0.5),
        isLoadoutMode and "战前整备" or (inventoryOpenedFromHome and "物资与装备管理" or chest.name))
    nvgFontSize(ctx, isLoadoutMode and 12 or 13)
    nvgTextAlign(ctx, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFillColor(ctx, nvgRGBA(235, 205, 120, math.floor(245 * anim)))
    nvgText(ctx, panelX + panelW - 12, slideY + math.floor(titleH * 0.5),
        (isLoadoutMode and "仓库物资: " or (inventoryOpenedFromHome and "仓库总价值: " or "当局收入: "))
            .. (isLoadoutMode and tostring(#chest.items) or lootUI.FormatBitValue(lootUI.CalculateTotalIncome())))

    -- ── 三分区内容 ──
    local contentY = slideY + titleH + 4
    local contentH = panelH - titleH - 8
    local gap = 4
    local isInventoryMode = lootUI.mode == "inventory" or isLoadoutMode
    -- 搜刮模式: 左/中/右 = 20/40/40；普通背包隐藏右区；
    -- 战前整备扩大右侧仓库区域，让真实 8 列网格和武器图标更清晰。
    local leftW, midW, rightW
    if isLoadoutMode then
        leftW = math.floor((panelW - gap * 2) * 0.34)
        midW = math.floor((panelW - gap * 2) * 0.28)
        rightW = panelW - gap * 2 - leftW - midW
    elseif isInventoryMode then
        leftW = math.floor((panelW - gap) * 0.48)
        midW = panelW - gap - leftW
        rightW = 0
    else
        leftW = math.floor((panelW - gap * 2) * 0.20)
        midW = math.floor((panelW - gap * 2) * 0.40)
        rightW = panelW - gap * 2 - leftW - midW
    end
    local leftX = panelX
    local midX = leftX + leftW + gap
    local rightX = midX + midW + gap
    local secTitleH = 24

    -- ════════════════════════════════════
    -- 【左区】角色展示（idle）
    -- ════════════════════════════════════
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, leftX, contentY, leftW, contentH, 6)
    nvgFillColor(ctx, nvgRGBA(15, 18, 22, math.floor(240 * anim)))
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, leftX, contentY, leftW, contentH, 6)
    nvgStrokeColor(ctx, nvgRGBA(50, 60, 70, math.floor(150 * anim)))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)

    -- 角色框内部：背包模式为“角色 + 装备竖列”，搜刮模式沿用“角色上方 + 装备下方”
    local leftPad = 8
    local equipColumnW = 0
    local charPanelX = leftX + leftPad
    local charPanelW = leftW - leftPad * 2
    if isInventoryMode then
        equipColumnW = math.max(120, math.min(180, math.floor(leftW * 0.42)))
        charPanelW = leftW - leftPad * 3 - equipColumnW
    end
    local charAreaH = isInventoryMode and (contentH - leftPad * 2) or math.floor(contentH * 0.55)
    local charAreaY = contentY + (isInventoryMode and leftPad or 0)

    -- 背包角色预览复用世界角色当前武器动作集，始终显示对应 Idle。
    if not drawInventoryPlayerIdle(
        ctx,
        charPanelX,
        charPanelW,
        charAreaY,
        charAreaH,
        isInventoryMode,
        anim
    ) and playerImg > 0 then
        local charH = math.min(charAreaH * (isInventoryMode and 0.72 or 0.8), isInventoryMode and 150 or 120)
        local charW = charH * (PLAYER_IMG_W / PLAYER_IMG_H)
        if isInventoryMode and charW > charPanelW * 0.88 then
            charW = charPanelW * 0.88
            charH = charW * (PLAYER_IMG_H / PLAYER_IMG_W)
        end
        local charX = charPanelX + math.floor((charPanelW - charW) * 0.5)
        local charY = charAreaY + math.floor((charAreaH - charH) * 0.5) - (isInventoryMode and 14 or 8)
        local paint = nvgImagePattern(ctx, charX, charY, charW, charH, 0, playerImg, anim)
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, charX, charY, charW, charH, 4)
        nvgFillPaint(ctx, paint)
        nvgFill(ctx)
    end

    -- 角色名称
    nvgFontSize(ctx, 11)
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(ctx, nvgRGBA(180, 190, 200, math.floor(200 * anim)))
    local nameY = isInventoryMode and (contentY + contentH - 16) or (contentY + charAreaH - 8)
    nvgText(ctx, charPanelX + math.floor(charPanelW * 0.5), nameY, "幸存者")

    -- ── 装备槽区域：背包模式竖排在角色右侧；搜刮模式保持下半部分布局 ──
    lootUI._equipSlotCache = {}
    local eqPad = 6
    local equipSlots = {
        { name = "头盔", key = "helmet", itemField = "equippedHelmetItem", accept = "二级头盔", color = {62, 70, 78}, long = false },
        { name = "防弹衣", key = "armor", itemField = "equippedArmorItem", accept = "二级防弹衣", color = {62, 70, 78}, long = false },
        { name = "枪支", key = "gun", itemField = "equippedGunItem", color = {62, 70, 78}, long = true },
        { name = "近战武器", key = "melee", itemField = "equippedMeleeItem", color = {62, 70, 78}, long = true },
    }
    if isInventoryMode then
        local eqSlotGap = 8
        local eqX = leftX + leftW - leftPad - equipColumnW
        local eqY = contentY + leftPad
        local eqH = contentH - leftPad * 2
        -- 防护装备槽占可用高度约 31%，让头盔和防弹衣更醒目；武器槽使用剩余空间。
        local shortSlotSize = math.min(equipColumnW, math.max(48, math.floor((eqH - eqSlotGap * 3) * 0.31)))
        local longSlotH = math.max(28, math.floor((eqH - eqSlotGap * 3 - shortSlotSize * 2) / 2))
        local slotY = eqY
        for i, slot in ipairs(equipSlots) do
            local slotW = slot.long and equipColumnW or shortSlotSize
            local slotH = slot.long and longSlotH or shortSlotSize
            local slotX = eqX + math.floor((equipColumnW - slotW) * 0.5)
            nvgBeginPath(ctx)
            nvgRoundedRect(ctx, slotX, slotY, slotW, slotH, 5)
            nvgFillColor(ctx, nvgRGBA(12, 15, 20, math.floor(210 * anim)))
            nvgFill(ctx)
            nvgBeginPath(ctx)
            nvgRoundedRect(ctx, slotX, slotY, slotW, slotH, 5)
            nvgStrokeColor(ctx, nvgRGBA(slot.color[1], slot.color[2], slot.color[3], math.floor(115 * anim)))
            nvgStrokeWidth(ctx, 1)
            nvgStroke(ctx)
            lootUI._equipSlotCache[slot.key] = { x = slotX, y = slotY, w = slotW, h = slotH }
            local equippedItem = lootUI[slot.itemField] or ""
            local selectionContainer = "equip_" .. slot.key
            if equippedItem ~= "" then
                local equippedRarity = ITEM_RARITY[equippedItem] or "green"
                drawRarityGradient(ctx, equippedRarity, slotX, slotY, slotW, slotH, anim * 0.82, 5)
                local iconId = itemIcons[equippedItem]
                local iconX, iconY, iconW, iconH = getItemIconDrawRect(equippedItem, slotX + 8, slotY, math.min(slotW - 16, 72), slotH, slot.name == "近战武器" and 0.72 or 0.76)
                if iconId and iconId > 0 then
                    local paint = nvgImagePattern(ctx, iconX, iconY, iconW, iconH, 0, iconId, anim)
                    nvgBeginPath(ctx)
                    nvgRoundedRect(ctx, iconX, iconY, iconW, iconH, 3)
                    nvgFillPaint(ctx, paint)
                    nvgFill(ctx)
                end
                if not slot.long then
                    drawItemNameBar(ctx, equippedItem, slotX, slotY, slotW, slotH, anim)
                else
                    nvgFontSize(ctx, 10)
                    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                    nvgFillColor(ctx, nvgRGBA(235, 225, 190, math.floor(230 * anim)))
                    nvgText(ctx, iconX + iconW + 6, slotY + slotH * 0.5, equippedItem)
                end
                lootUI.DrawSelection(ctx, selectionContainer, 1, slotX, slotY, slotW, slotH, anim)
            else
                nvgFontSize(ctx, slot.long and 15 or 18)
                nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
                nvgFillColor(ctx, nvgRGBA(slot.color[1], slot.color[2], slot.color[3], math.floor(110 * anim)))
                nvgText(ctx, slotX + slotW * 0.5, slotY + slotH * 0.5 - 2, "+")
                nvgFontSize(ctx, 10)
                nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
                nvgFillColor(ctx, nvgRGBA(slot.color[1], slot.color[2], slot.color[3], math.floor(145 * anim)))
                nvgText(ctx, slotX + slotW * 0.5, slotY + slotH * 0.5 + 3, slot.name)
            end
            slotY = slotY + slotH + eqSlotGap
        end
    else
        local equipAreaY = contentY + charAreaH + 6
        local equipAreaH = contentH - charAreaH - 10
        local eqSlotGap = 4
        local eqRowGap = 4
        local eqFullW = leftW - eqPad * 2
        local eqRowH = math.floor((equipAreaH - eqRowGap) / 2)

        -- 上层：头盔 + 防弹衣 并排
        local eqHalfW = math.floor((eqFullW - eqSlotGap) / 2)
        for i = 1, 2 do
            local slot = equipSlots[i]
            local slotX = leftX + eqPad + (i - 1) * (eqHalfW + eqSlotGap)
            local slotY = equipAreaY
            nvgBeginPath(ctx)
            nvgRect(ctx, slotX, slotY, eqHalfW, eqRowH)
            nvgFillColor(ctx, nvgRGBA(12, 15, 20, math.floor(210 * anim)))
            nvgFill(ctx)
            nvgBeginPath(ctx)
            nvgRect(ctx, slotX, slotY, eqHalfW, eqRowH)
            nvgStrokeColor(ctx, nvgRGBA(slot.color[1], slot.color[2], slot.color[3], math.floor(100 * anim)))
            nvgStrokeWidth(ctx, 1)
            nvgStroke(ctx)
            nvgFontSize(ctx, 16)
            nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
            nvgFillColor(ctx, nvgRGBA(slot.color[1], slot.color[2], slot.color[3], math.floor(100 * anim)))
            nvgText(ctx, slotX + eqHalfW * 0.5, slotY + eqRowH * 0.5 - 2, "+")
            nvgFontSize(ctx, 10)
            nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
            nvgFillColor(ctx, nvgRGBA(slot.color[1], slot.color[2], slot.color[3], math.floor(130 * anim)))
            nvgText(ctx, slotX + eqHalfW * 0.5, slotY + eqRowH * 0.5 + 2, slot.name)
        end

        -- 下层：枪支（整行宽）
        local gunSlot = equipSlots[3]
        local gunSlotY = equipAreaY + eqRowH + eqRowGap
        nvgBeginPath(ctx)
        nvgRect(ctx, leftX + eqPad, gunSlotY, eqFullW, eqRowH)
        nvgFillColor(ctx, nvgRGBA(12, 15, 20, math.floor(210 * anim)))
        nvgFill(ctx)
        nvgBeginPath(ctx)
        nvgRect(ctx, leftX + eqPad, gunSlotY, eqFullW, eqRowH)
        nvgStrokeColor(ctx, nvgRGBA(gunSlot.color[1], gunSlot.color[2], gunSlot.color[3], math.floor(100 * anim)))
        nvgStrokeWidth(ctx, 1)
        nvgStroke(ctx)
        nvgFontSize(ctx, 16)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
        nvgFillColor(ctx, nvgRGBA(gunSlot.color[1], gunSlot.color[2], gunSlot.color[3], math.floor(100 * anim)))
        nvgText(ctx, leftX + eqPad + eqFullW * 0.5, gunSlotY + eqRowH * 0.5 - 2, "+")
        nvgFontSize(ctx, 10)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(ctx, nvgRGBA(gunSlot.color[1], gunSlot.color[2], gunSlot.color[3], math.floor(130 * anim)))
        nvgText(ctx, leftX + eqPad + eqFullW * 0.5, gunSlotY + eqRowH * 0.5 + 2, "枪支")
    end

    -- ════════════════════════════════════
    -- 【中区】背包（玩家已有物品 - 网格）
    -- ════════════════════════════════════
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, midX, contentY, midW, contentH, 6)
    nvgFillColor(ctx, nvgRGBA(18, 22, 28, math.floor(230 * anim)))
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, midX, contentY, midW, contentH, 6)
    nvgStrokeColor(ctx, nvgRGBA(60, 70, 80, math.floor(150 * anim)))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)

    -- ── 中区分四层：胸挂(上) + 口袋 + 背包 + 安全箱(下)，支持滚动 ──
    local midPad = 6
    local midGap = 0
    local midInnerW = midW - midPad * 2
    -- 统一格子大小：以宽度为基准（4列），放大紧凑物资单元格。
    local uniCellSize = math.floor((midInnerW - midGap * (RIG_GRID_COLS - 1)) / RIG_GRID_COLS * 0.58)
    -- 根据统一格子大小计算各区域实际占用高度
    local rigGridH = uniCellSize * RIG_GRID_ROWS + midGap * (RIG_GRID_ROWS - 1)
    local pktGridH = uniCellSize * PKT_GRID_ROWS + midGap * (PKT_GRID_ROWS - 1)
    local invGridH = uniCellSize * INV_GRID_ROWS + midGap * (INV_GRID_ROWS - 1)
    local safeGridH = uniCellSize * SAFE_GRID_ROWS + midGap * (SAFE_GRID_ROWS - 1)
    local rigSectionH = secTitleH + 8 + rigGridH
    local pktSectionH = secTitleH + 8 + pktGridH
    local invSectionH = secTitleH + 8 + invGridH
    local safeSectionH = secTitleH + 8 + safeGridH

    -- 计算总内容高度和滚动限制
    local midTotalContentH = rigSectionH + 4 + pktSectionH + 4 + invSectionH + 4 + safeSectionH
    local midMaxScroll = math.max(0, midTotalContentH - contentH)
    if lootUI.midScrollY > midMaxScroll then lootUI.midScrollY = midMaxScroll end

    -- 应用滚动裁剪
    nvgSave(ctx)
    nvgScissor(ctx, midX, contentY, midW, contentH)

    local scrollOff = lootUI.midScrollY

    -- 装备槽尺寸（左侧大格子，高度=网格高度）
    local equipSlotW = uniCellSize * 2 + midGap  -- 2格宽
    local equipGap = 4  -- 装备槽与网格间距

    -- ── 胸挂标题 ──
    local rigY = contentY - scrollOff
    nvgBeginPath(ctx)
    nvgRect(ctx, midX, rigY, midW, secTitleH)
    nvgFillColor(ctx, nvgRGBA(45, 35, 30, math.floor(200 * anim)))
    nvgFill(ctx)
    nvgFontSize(ctx, 12)
    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(ctx, nvgRGBA(240, 180, 120, math.floor(220 * anim)))
    nvgText(ctx, midX + 8, rigY + math.floor(secTitleH * 0.5),
        "胸挂 " .. #playerChestRig .. "/" .. RIG_MAX)

    -- ── 胸挂网格 ──
    local rigGridStartY = rigY + secTitleH + 4
    local rigCellSize = uniCellSize
    local rigTotalGW = rigCellSize * RIG_GRID_COLS + midGap * (RIG_GRID_COLS - 1)
    local rigTotalGH = rigCellSize * RIG_GRID_ROWS + midGap * (RIG_GRID_ROWS - 1)
    -- 左侧装备槽
    local rigEquipX = midX + midPad
    local rigEquipY = rigGridStartY
    local rigEquipH = rigTotalGH
    lootUI.DrawContainerEquipmentSlot(
        ctx,
        "rig",
        lootUI.equippedRigItem,
        "胸挂",
        rigEquipX,
        rigEquipY,
        equipSlotW,
        rigEquipH,
        { 25, 20, 15, 180, 140, 90 },
        anim
    )

    -- 网格偏移到装备槽右侧；未装备胸挂时不显示也不开放网格。
    local rigGridOffX = rigEquipX + equipSlotW + equipGap
    local rigGridOffY = rigGridStartY
    if lootUI.equippedRigItem ~= "" then
    lootUI._gridCache.rig = { offX = rigGridOffX, offY = rigGridOffY, cellSize = rigCellSize, gap = midGap, areaX = rigGridOffX, areaY = rigGridOffY, areaW = rigTotalGW, areaH = rigTotalGH }

    -- 胸挂网格背景+线
    nvgBeginPath(ctx)
    nvgRect(ctx, rigGridOffX, rigGridOffY, rigTotalGW, rigTotalGH)
    nvgFillColor(ctx, nvgRGBA(16, 12, 10, math.floor(210 * anim)))
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(65, 50, 40, math.floor(140 * anim)))
    nvgStrokeWidth(ctx, 1)
    for row = 1, RIG_GRID_ROWS - 1 do
        local ly = rigGridOffY + row * (rigCellSize + midGap) - midGap * 0.5
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, rigGridOffX, ly)
        nvgLineTo(ctx, rigGridOffX + rigTotalGW, ly)
        nvgStroke(ctx)
    end
    for col = 1, RIG_GRID_COLS - 1 do
        local lx = rigGridOffX + col * (rigCellSize + midGap) - midGap * 0.5
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, lx, rigGridOffY)
        nvgLineTo(ctx, lx, rigGridOffY + rigTotalGH)
        nvgStroke(ctx)
    end
    nvgBeginPath(ctx)
    nvgRect(ctx, rigGridOffX, rigGridOffY, rigTotalGW, rigTotalGH)
    nvgStrokeColor(ctx, nvgRGBA(70, 55, 45, math.floor(160 * anim)))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)

    -- 胸挂物品
    local rigPlacements = layoutRigGrid(playerChestRig)
    for _, p in ipairs(rigPlacements) do
        local px = rigGridOffX + p.col * (rigCellSize + midGap)
        local py = rigGridOffY + p.row * (rigCellSize + midGap)
        local pw = p.w * rigCellSize + (p.w - 1) * midGap
        local ph = p.h * rigCellSize + (p.h - 1) * midGap
        local invRarity = ITEM_RARITY[p.item] or "green"
        drawRarityGradient(ctx, invRarity, px, py, pw, ph, anim, 3)
        local rigIconId = itemIcons[p.item]
        if rigIconId and rigIconId > 0 then
            local iconX, iconY, iconW, iconH = getItemIconDrawRect(
                p.item, px, py, pw, ph, p.item == "金条" and 0.90 or 0.62)
            local iPaint = nvgImagePattern(ctx, iconX, iconY, iconW, iconH, 0, rigIconId, anim)
            nvgBeginPath(ctx)
            nvgRect(ctx, iconX, iconY, iconW, iconH)
            nvgFillPaint(ctx, iPaint)
            nvgFill(ctx)
        end
        drawItemNameBar(ctx, p.item, px, py, pw, ph, anim)
        lootUI.DrawSelection(ctx, "rig", p.idx, px, py, pw, ph, anim)
    end
    end

    -- ── 口袋标题 ──
    local pktY = rigY + rigSectionH + 4
    nvgBeginPath(ctx)
    nvgRect(ctx, midX, pktY, midW, secTitleH)
    nvgFillColor(ctx, nvgRGBA(30, 40, 35, math.floor(200 * anim)))
    nvgFill(ctx)
    nvgFontSize(ctx, 12)
    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(ctx, nvgRGBA(140, 220, 160, math.floor(220 * anim)))
    nvgText(ctx, midX + 8, pktY + math.floor(secTitleH * 0.5),
        "口袋 " .. #playerPocket .. "/" .. PKT_MAX)

    -- ── 口袋网格 ──
    local pktGridStartY = pktY + secTitleH + 4
    local pktCellSize = uniCellSize
    local pktTotalGW = pktCellSize * PKT_GRID_COLS + midGap * (PKT_GRID_COLS - 1)
    local pktTotalGH = pktCellSize * PKT_GRID_ROWS + midGap * (PKT_GRID_ROWS - 1)
    local pktGridOffX = midX + midPad  -- 靠左对齐
    local pktGridOffY = pktGridStartY
    lootUI._gridCache.pocket = { offX = pktGridOffX, offY = pktGridOffY, cellSize = pktCellSize, gap = midGap, areaX = pktGridOffX, areaY = pktGridOffY, areaW = pktTotalGW, areaH = pktTotalGH }

    nvgBeginPath(ctx)
    nvgRect(ctx, pktGridOffX, pktGridOffY, pktTotalGW, pktTotalGH)
    nvgFillColor(ctx, nvgRGBA(10, 14, 12, math.floor(210 * anim)))
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(40, 60, 50, math.floor(140 * anim)))
    nvgStrokeWidth(ctx, 1)
    for row = 1, PKT_GRID_ROWS - 1 do
        local ly = pktGridOffY + row * (pktCellSize + midGap) - midGap * 0.5
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, pktGridOffX, ly)
        nvgLineTo(ctx, pktGridOffX + pktTotalGW, ly)
        nvgStroke(ctx)
    end
    for col = 1, PKT_GRID_COLS - 1 do
        local lx = pktGridOffX + col * (pktCellSize + midGap) - midGap * 0.5
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, lx, pktGridOffY)
        nvgLineTo(ctx, lx, pktGridOffY + pktTotalGH)
        nvgStroke(ctx)
    end
    nvgBeginPath(ctx)
    nvgRect(ctx, pktGridOffX, pktGridOffY, pktTotalGW, pktTotalGH)
    nvgStrokeColor(ctx, nvgRGBA(45, 65, 55, math.floor(160 * anim)))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)

    -- 口袋物品
    local pktPlacements = layoutPocketGrid(playerPocket)
    for _, p in ipairs(pktPlacements) do
        local px = pktGridOffX + p.col * (pktCellSize + midGap)
        local py = pktGridOffY + p.row * (pktCellSize + midGap)
        local pw = p.w * pktCellSize + (p.w - 1) * midGap
        local ph = p.h * pktCellSize + (p.h - 1) * midGap
        local pktRarity = ITEM_RARITY[p.item] or "green"
        drawRarityGradient(ctx, pktRarity, px, py, pw, ph, anim, 3)
        local pktIconId = itemIcons[p.item]
        if pktIconId and pktIconId > 0 then
            local iconX, iconY, iconW, iconH = getItemIconDrawRect(
                p.item, px, py, pw, ph, p.item == "金条" and 0.90 or 0.62)
            local iPaint = nvgImagePattern(ctx, iconX, iconY, iconW, iconH, 0, pktIconId, anim)
            nvgBeginPath(ctx)
            nvgRect(ctx, iconX, iconY, iconW, iconH)
            nvgFillPaint(ctx, iPaint)
            nvgFill(ctx)
        end
        drawItemNameBar(ctx, p.item, px, py, pw, ph, anim)
        lootUI.DrawSelection(ctx, "pocket", p.idx, px, py, pw, ph, anim)
    end

    -- ── 背包标题 ──
    local invY = pktY + pktSectionH + 4
    nvgBeginPath(ctx)
    nvgRect(ctx, midX, invY, midW, secTitleH)
    nvgFillColor(ctx, nvgRGBA(35, 45, 55, math.floor(200 * anim)))
    nvgFill(ctx)
    nvgFontSize(ctx, 12)
    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(ctx, nvgRGBA(180, 200, 220, math.floor(220 * anim)))
    nvgText(ctx, midX + 8, invY + math.floor(secTitleH * 0.5),
        "背包 " .. #playerInventory .. "/" .. INVENTORY_MAX)
    -- 容量进度条
    local capBarW = 50
    local capBarH = 6
    local capBarX = midX + midW - capBarW - 8
    local capBarY = invY + math.floor((secTitleH - capBarH) * 0.5)
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, capBarX, capBarY, capBarW, capBarH, 3)
    nvgFillColor(ctx, nvgRGBA(30, 40, 50, math.floor(200 * anim)))
    nvgFill(ctx)
    local capFillW = math.floor(capBarW * #playerInventory / INVENTORY_MAX)
    if capFillW > 0 then
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, capBarX, capBarY, capFillW, capBarH, 3)
        nvgFillColor(ctx, (#playerInventory >= INVENTORY_MAX)
            and nvgRGBA(220, 80, 80, math.floor(220 * anim))
            or nvgRGBA(80, 200, 140, math.floor(220 * anim)))
        nvgFill(ctx)
    end

    -- ── 背包网格 ──
    local mGridStartY = invY + secTitleH + 4
    local mCellSize = uniCellSize
    local mTotalGW = mCellSize * INV_GRID_COLS + midGap * (INV_GRID_COLS - 1)
    local mTotalGH = mCellSize * INV_GRID_ROWS + midGap * (INV_GRID_ROWS - 1)
    -- 左侧装备槽
    local invEquipX = midX + midPad
    local invEquipY = mGridStartY
    local invEquipH = mTotalGH
    lootUI.DrawContainerEquipmentSlot(
        ctx,
        "backpack",
        lootUI.equippedBackpackItem,
        "背包",
        invEquipX,
        invEquipY,
        equipSlotW,
        invEquipH,
        { 15, 20, 28, 140, 170, 200 },
        anim
    )

    local mGridOffX = invEquipX + equipSlotW + equipGap
    local mGridOffY = mGridStartY
    if lootUI.equippedBackpackItem ~= "" then
    lootUI._gridCache.inv = { offX = mGridOffX, offY = mGridOffY, cellSize = mCellSize, gap = midGap, areaX = mGridOffX, areaY = mGridOffY, areaW = mTotalGW, areaH = mTotalGH }

    -- 背包网格背景+线
    nvgBeginPath(ctx)
    nvgRect(ctx, mGridOffX, mGridOffY, mTotalGW, mTotalGH)
    nvgFillColor(ctx, nvgRGBA(12, 16, 22, math.floor(210 * anim)))
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(45, 52, 65, math.floor(140 * anim)))
    nvgStrokeWidth(ctx, 1)
    for row = 1, INV_GRID_ROWS - 1 do
        local ly = mGridOffY + row * (mCellSize + midGap) - midGap * 0.5
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, mGridOffX, ly)
        nvgLineTo(ctx, mGridOffX + mTotalGW, ly)
        nvgStroke(ctx)
    end
    for col = 1, INV_GRID_COLS - 1 do
        local lx = mGridOffX + col * (mCellSize + midGap) - midGap * 0.5
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, lx, mGridOffY)
        nvgLineTo(ctx, lx, mGridOffY + mTotalGH)
        nvgStroke(ctx)
    end
    nvgBeginPath(ctx)
    nvgRect(ctx, mGridOffX, mGridOffY, mTotalGW, mTotalGH)
    nvgStrokeColor(ctx, nvgRGBA(50, 58, 72, math.floor(160 * anim)))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)

    -- 背包物品
    local invPlacements = layoutInventoryGrid(playerInventory)
    for _, p in ipairs(invPlacements) do
        local px = mGridOffX + p.col * (mCellSize + midGap)
        local py = mGridOffY + p.row * (mCellSize + midGap)
        local pw = p.w * mCellSize + (p.w - 1) * midGap
        local ph = p.h * mCellSize + (p.h - 1) * midGap
        local invRarity = ITEM_RARITY[p.item] or "green"
        drawRarityGradient(ctx, invRarity, px, py, pw, ph, anim, 3)
        local invIconId = itemIcons[p.item]
        if invIconId and invIconId > 0 then
            local iconX, iconY, iconW, iconH = getItemIconDrawRect(p.item, px, py, pw, ph, p.item == "棒球棍" and 0.76 or 0.72)
            local iPaint = nvgImagePattern(ctx, iconX, iconY, iconW, iconH, 0, invIconId, anim)
            nvgBeginPath(ctx)
            nvgRect(ctx, iconX, iconY, iconW, iconH)
            nvgFillPaint(ctx, iPaint)
            nvgFill(ctx)
        end
        drawItemNameBar(ctx, p.item, px, py, pw, ph, anim)
        lootUI.DrawSelection(ctx, "inv", p.idx, px, py, pw, ph, anim)
    end
    end

    -- ── 安全箱标题 ──
    local safeY = invY + invSectionH + 4
    nvgBeginPath(ctx)
    nvgRect(ctx, midX, safeY, midW, secTitleH)
    nvgFillColor(ctx, nvgRGBA(40, 30, 45, math.floor(200 * anim)))
    nvgFill(ctx)
    nvgFontSize(ctx, 12)
    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(ctx, nvgRGBA(200, 160, 240, math.floor(220 * anim)))
    nvgText(ctx, midX + 8, safeY + math.floor(secTitleH * 0.5),
        "安全箱 " .. #playerSafeBox .. "/" .. SAFE_MAX)

    -- ── 安全箱网格 ──
    local safeGridStartY = safeY + secTitleH + 4
    local safeCellSize = uniCellSize
    local safeTotalGW = safeCellSize * SAFE_GRID_COLS + midGap * (SAFE_GRID_COLS - 1)
    local safeTotalGH = safeCellSize * SAFE_GRID_ROWS + midGap * (SAFE_GRID_ROWS - 1)
    -- 左侧装备槽
    local safeEquipX = midX + midPad
    local safeEquipY = safeGridStartY
    local safeEquipH = safeTotalGH
    lootUI.DrawContainerEquipmentSlot(
        ctx,
        "safe_box",
        lootUI.equippedSafeBoxItem,
        "安全箱",
        safeEquipX,
        safeEquipY,
        equipSlotW,
        safeEquipH,
        { 18, 12, 22, 180, 140, 220 },
        anim
    )

    local safeGridOffX = safeEquipX + equipSlotW + equipGap
    local safeGridOffY = safeGridStartY
    if lootUI.equippedSafeBoxItem ~= "" then
    lootUI._gridCache.safe = { offX = safeGridOffX, offY = safeGridOffY, cellSize = safeCellSize, gap = midGap, areaX = safeGridOffX, areaY = safeGridOffY, areaW = safeTotalGW, areaH = safeTotalGH }

    nvgBeginPath(ctx)
    nvgRect(ctx, safeGridOffX, safeGridOffY, safeTotalGW, safeTotalGH)
    nvgFillColor(ctx, nvgRGBA(14, 10, 18, math.floor(210 * anim)))
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(55, 40, 65, math.floor(140 * anim)))
    nvgStrokeWidth(ctx, 1)
    for row = 1, SAFE_GRID_ROWS - 1 do
        local ly = safeGridOffY + row * (safeCellSize + midGap) - midGap * 0.5
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, safeGridOffX, ly)
        nvgLineTo(ctx, safeGridOffX + safeTotalGW, ly)
        nvgStroke(ctx)
    end
    for col = 1, SAFE_GRID_COLS - 1 do
        local lx = safeGridOffX + col * (safeCellSize + midGap) - midGap * 0.5
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, lx, safeGridOffY)
        nvgLineTo(ctx, lx, safeGridOffY + safeTotalGH)
        nvgStroke(ctx)
    end
    nvgBeginPath(ctx)
    nvgRect(ctx, safeGridOffX, safeGridOffY, safeTotalGW, safeTotalGH)
    nvgStrokeColor(ctx, nvgRGBA(60, 45, 70, math.floor(160 * anim)))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)

    -- 安全箱物品
    local safePlacements = layoutSafeGrid(playerSafeBox)
    for _, p in ipairs(safePlacements) do
        local px = safeGridOffX + p.col * (safeCellSize + midGap)
        local py = safeGridOffY + p.row * (safeCellSize + midGap)
        local pw = p.w * safeCellSize + (p.w - 1) * midGap
        local ph = p.h * safeCellSize + (p.h - 1) * midGap
        local safeRarity = ITEM_RARITY[p.item] or "green"
        drawRarityGradient(ctx, safeRarity, px, py, pw, ph, anim, 3)
        local safeIconId = itemIcons[p.item]
        if safeIconId and safeIconId > 0 then
            local iconX, iconY, iconW, iconH = getItemIconDrawRect(
                p.item, px, py, pw, ph, p.item == "金条" and 0.90 or 0.62)
            local iPaint = nvgImagePattern(ctx, iconX, iconY, iconW, iconH, 0, safeIconId, anim)
            nvgBeginPath(ctx)
            nvgRect(ctx, iconX, iconY, iconW, iconH)
            nvgFillPaint(ctx, iPaint)
            nvgFill(ctx)
        end
        drawItemNameBar(ctx, p.item, px, py, pw, ph, anim)
        lootUI.DrawSelection(ctx, "safe", p.idx, px, py, pw, ph, anim)
    end
    end

    -- 结束中区滚动裁剪
    nvgRestore(ctx)

    -- ════════════════════════════════════
    -- 【右区】宝箱/容器物品（统一格子网格，物品按尺寸占多格）
    -- ════════════════════════════════════
    if not isInventoryMode or isLoadoutMode then
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, rightX, contentY, rightW, contentH, 6)
    nvgFillColor(ctx, nvgRGBA(20, 24, 30, math.floor(230 * anim)))
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, rightX, contentY, rightW, contentH, 6)
    nvgStrokeColor(ctx, nvgRGBA(70, 60, 50, math.floor(150 * anim)))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)

    -- 右区标题
    nvgBeginPath(ctx)
    nvgRect(ctx, rightX, contentY, rightW, secTitleH)
    nvgFillColor(ctx, nvgRGBA(50, 40, 30, math.floor(200 * anim)))
    nvgFill(ctx)
    nvgFontSize(ctx, 12)
    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(ctx, nvgRGBA(255, 200, 80, math.floor(240 * anim)))
    local remainCount = 0
    for _, v in ipairs(chest.items) do
        if not lootUI.IsTakenGridEntry(v) then remainCount = remainCount + 1 end
    end
    nvgText(ctx, rightX + 8, contentY + math.floor(secTitleH * 0.5),
        (isLoadoutMode and "据点仓库" or chest.name) .. " (" .. remainCount .. ")")

    -- 右区统一网格绘制。战前整备复用外部据点仓库的真实列数/行数，超出可视区时滚动。
    local rGridStartY = contentY + secTitleH + 6
    local rGridPad = 6
    local rGridGap = 0
    local scrollBarW = isLoadoutMode and 14 or 0
    local gridAreaW = rightW - rGridPad * 2 - scrollBarW
    local gridAreaH = contentH - secTitleH - 12
    local chestCols, chestRows = lootUI.GetChestGridDimensions()
    local rCellSize
    if isLoadoutMode then
        -- 战前整备网格必须完整适配右栏宽度；禁止最小格宽导致首尾列横向溢出被裁切。
        rCellSize = math.max(1, math.min(76, math.floor(
            (gridAreaW - rGridGap * (chestCols - 1)) / chestCols)))
    else
        rCellSize = math.floor(math.min(
            (gridAreaW - rGridGap * (chestCols - 1)) / chestCols,
            (gridAreaH - rGridGap * (chestRows - 1)) / chestRows
        ))
    end
    local totalGridW = rCellSize * chestCols + rGridGap * (chestCols - 1)
    local totalGridH = rCellSize * chestRows + rGridGap * (chestRows - 1)
    lootUI.rightScrollMax = isLoadoutMode and math.max(0, totalGridH - gridAreaH) or 0
    lootUI.rightScrollY = math.max(0, math.min(lootUI.rightScrollY, lootUI.rightScrollMax))
    local rGridOffX = rightX + rGridPad + math.floor((gridAreaW - totalGridW) * 0.5)
    local rGridOffY = rGridStartY + (isLoadoutMode and -lootUI.rightScrollY
        or math.floor((gridAreaH - totalGridH) * 0.5))
    lootUI._gridCache.chest = {
        offX = rGridOffX,
        offY = rGridOffY,
        cellSize = rCellSize,
        gap = rGridGap,
        areaX = rightX + rGridPad,
        areaY = rGridStartY,
        areaW = gridAreaW,
        areaH = gridAreaH,
    }

    nvgSave(ctx)
    nvgScissor(ctx, rightX + rGridPad, rGridStartY, gridAreaW, gridAreaH)

    -- 1) 绘制网格底板（整体背景 + 网格线）
    nvgBeginPath(ctx)
    nvgRect(ctx, rGridOffX, rGridOffY, totalGridW, totalGridH)
    nvgFillColor(ctx, nvgRGBA(12, 16, 22, math.floor(210 * anim)))
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(45, 52, 65, math.floor(140 * anim)))
    nvgStrokeWidth(ctx, 1)
    for row = 1, chestRows - 1 do
        local ly = rGridOffY + row * (rCellSize + rGridGap) - rGridGap * 0.5
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, rGridOffX, ly)
        nvgLineTo(ctx, rGridOffX + totalGridW, ly)
        nvgStroke(ctx)
    end
    for col = 1, chestCols - 1 do
        local lx = rGridOffX + col * (rCellSize + rGridGap) - rGridGap * 0.5
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, lx, rGridOffY)
        nvgLineTo(ctx, lx, rGridOffY + totalGridH)
        nvgStroke(ctx)
    end
    nvgBeginPath(ctx)
    nvgRect(ctx, rGridOffX, rGridOffY, totalGridW, totalGridH)
    nvgStrokeColor(ctx, nvgRGBA(50, 58, 72, math.floor(160 * anim)))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)

    -- 2) 物资严格串行加载：只有当前物资显示加载动画，后续物资保持等待。
    local placements = layoutChestGrid(chest.items, chestCols, chestRows)
    local elapsed = lootUI.loadingElapsed
    local revealStarts, revealTimes = lootUI.GetSequentialRevealSchedule(chest.items)
    local t = gameTime * 2.5  -- 加载动画转圈速度

    for idx, p in ipairs(placements) do
        local px = rGridOffX + p.col * (rCellSize + rGridGap)
        local py = rGridOffY + p.row * (rCellSize + rGridGap)
        local pw = p.w * rCellSize + (p.w - 1) * rGridGap
        local ph = p.h * rCellSize + (p.h - 1) * rGridGap

        -- 累计时间保证同一时刻只加载一个物资。
        local rarity = ITEM_RARITY[p.item] or "green"
        local revealStart = revealStarts[p.idx] or 0
        local revealTime = revealTimes[p.idx] or revealStart
        local revealed = elapsed >= revealTime
        local loadingNow = elapsed >= revealStart and elapsed < revealTime

        if revealed then
            -- 已揭示：显示物品（稀有度渐变背景 + 图标）
            drawRarityGradient(ctx, rarity, px, py, pw, ph, anim, 3)

            -- 物品图标+名字（左上角，柔和亮度）
            local iconId = itemIcons[p.item]
            if iconId and iconId > 0 then
                local iconScale = p.item == "金条" and 0.90
                    or (isLoadoutMode and p.item == "手枪" and 0.88 or 0.62)
                local iconX, iconY, iconW, iconH = getItemIconDrawRect(
                    p.item, px, py, pw, ph, iconScale)
                local imgPaint = nvgImagePattern(ctx, iconX, iconY, iconW, iconH, 0, iconId, anim)
                nvgBeginPath(ctx)
                nvgRoundedRect(ctx, iconX, iconY, iconW, iconH, 3)
                nvgFillPaint(ctx, imgPaint)
                nvgFill(ctx)
            end
            drawItemNameBar(ctx, p.item, px, py, pw, ph, anim)
            lootUI.DrawSelection(ctx, "chest", p.idx, px, py, pw, ph, anim)
        else
            -- 未揭示区域使用暖灰棕向内压暗渐变，与蓝黑网格底色明确区分。
            nvgBeginPath(ctx)
            nvgRect(ctx, px, py, pw, ph)
            nvgFillColor(ctx, nvgRGBA(76, 66, 49, math.floor(220 * anim)))
            nvgFill(ctx)
            nvgBeginPath(ctx)
            nvgRect(ctx, px, py, pw, ph)
            nvgFillPaint(ctx, nvgBoxGradient(
                ctx,
                px,
                py,
                pw,
                ph,
                0,
                math.max(6, math.min(pw, ph) * 0.38),
                nvgRGBA(24, 19, 13, math.floor(230 * anim)),
                nvgRGBA(24, 19, 13, 0)
            ))
            nvgFill(ctx)

            if loadingNow then
                local cx2 = px + pw * 0.5
                local cy2 = py + ph * 0.5 - 4
                local orbitR = math.min(pw, ph) * 0.15
                local iconSize = math.min(pw, ph) * 0.4
                local angle = t
                local ix = cx2 + math.cos(angle) * orbitR
                local iy = cy2 + math.sin(angle) * orbitR
                if loadingSpinnerImg > 0 then
                    local imgPaint = nvgImagePattern(ctx, ix - iconSize * 0.5, iy - iconSize * 0.5, iconSize, iconSize, 0, loadingSpinnerImg, anim * 0.9)
                    nvgBeginPath(ctx)
                    nvgRect(ctx, ix - iconSize * 0.5, iy - iconSize * 0.5, iconSize, iconSize)
                    nvgFillPaint(ctx, imgPaint)
                    nvgFill(ctx)
                end
            end
        end
    end

    nvgRestore(ctx)

    if isLoadoutMode and lootUI.rightScrollMax > 0 then
        local barX = rightX + rightW - 12
        local barY = rGridStartY
        local barH = gridAreaH
        local thumbH = math.max(34, barH * barH / totalGridH)
        local thumbY = barY + (barH - thumbH) * lootUI.rightScrollY / lootUI.rightScrollMax
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, barX, barY, 7, barH, 3.5)
        nvgFillColor(ctx, nvgRGBA(34, 40, 43, math.floor(230 * anim)))
        nvgFill(ctx)
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, barX, thumbY, 7, thumbH, 3.5)
        nvgFillColor(ctx, nvgRGBA(196, 145, 58, math.floor(245 * anim)))
        nvgFill(ctx)
    end

    -- 若宝箱已空（所有物品都被拾取）
    if remainCount == 0 then
        nvgFontSize(ctx, 13)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(ctx, nvgRGBA(120, 130, 140, math.floor(180 * anim)))
        nvgText(ctx, rightX + math.floor(rightW * 0.5), contentY + math.floor(contentH * 0.5), "已搜刮完毕")
    end
    end

    lootUI.DrawItemTooltip(ctx, screenW, screenH, anim)

    -- 战前整备不在面板内部显示操作按钮。
    local tipH = 20
    local tipY = slideY + panelH - tipH
    lootUI.loadoutConfirmRect = nil
    if not isLoadoutMode then
        nvgFontSize(ctx, 11)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(ctx, nvgRGBA(140, 150, 160, math.floor(160 * anim)))
        nvgText(ctx, panelX + math.floor(panelW * 0.5), tipY + math.floor(tipH * 0.5),
            "双击物资自动放入背包 | 长按拖拽物品 | 拖拽时按 R 切换横/竖放 | Esc/F 关闭")
    end

    -- ── 拖拽中：最近格子高亮提示 ──
    if lootUI.dragging and lootUI.dragItem ~= "" then
        local target = getDropTarget(lootUI.dragMouseX, lootUI.dragMouseY)
        if target then
            if target:sub(1, 6) == "equip_" then
                local eqKey = target:sub(7)
                local eq = lootUI._equipSlotCache and lootUI._equipSlotCache[eqKey]
                if eq then
                    nvgBeginPath(ctx)
                    nvgRoundedRect(ctx, eq.x, eq.y, eq.w, eq.h, 5)
                    nvgFillColor(ctx, nvgRGBA(80, 220, 140, 45))
                    nvgFill(ctx)
                    nvgBeginPath(ctx)
                    nvgRoundedRect(ctx, eq.x, eq.y, eq.w, eq.h, 5)
                    nvgStrokeColor(ctx, nvgRGBA(100, 255, 160, 220))
                    nvgStrokeWidth(ctx, 2)
                    nvgStroke(ctx)
                end
            else
            local gc = lootUI._gridCache and lootUI._gridCache[target]
            if gc then
                -- 计算拖动物品左上角最近的格子位置
                local cs = gc.cellSize
                local step = getGridStep(gc)
                local itemLeft = lootUI.dragMouseX - lootUI.dragOffX
                local itemTop = lootUI.dragMouseY - lootUI.dragOffY
                local relX = itemLeft - gc.offX
                local relY = itemTop - gc.offY
                local snapCol = math.floor((relX + step * 0.5) / step)
                local snapRow = math.floor((relY + step * 0.5) / step)
                -- 获取物品尺寸
                local itemW, itemH = lootUI.GetGridItemSize(lootUI.dragItem, lootUI.dragOrientation)
                -- 获取目标网格的列/行数
                local maxCols, maxRows = CHEST_GRID_COLS, CHEST_GRID_ROWS
                if target == "chest" then maxCols, maxRows = lootUI.GetChestGridDimensions()
                elseif target == "rig" then maxCols, maxRows = RIG_GRID_COLS, RIG_GRID_ROWS
                elseif target == "pocket" then maxCols, maxRows = PKT_GRID_COLS, PKT_GRID_ROWS
                elseif target == "inv" then maxCols, maxRows = INV_GRID_COLS, INV_GRID_ROWS
                elseif target == "safe" then maxCols, maxRows = SAFE_GRID_COLS, SAFE_GRID_ROWS
                end
                -- 限制范围
                snapCol = math.max(0, math.min(snapCol, maxCols - itemW))
                snapRow = math.max(0, math.min(snapRow, maxRows - itemH))
                local canDrop = false
                local targetItems = nil
                if target == "chest" then
                    local targetChest = chestDefs[lootUI.chestIdx]
                    targetItems = targetChest and targetChest.items or nil
                elseif target == "rig" then targetItems = playerChestRig
                elseif target == "pocket" then targetItems = playerPocket
                elseif target == "inv" then targetItems = playerInventory
                elseif target == "safe" then targetItems = playerSafeBox
                end
                if targetItems then
                    canDrop = canPlaceAtPosition(
                        targetItems,
                        lootUI.dragItem,
                        snapCol,
                        snapRow,
                        maxCols,
                        maxRows,
                        lootUI.dragOrientation
                    )
                end
                local previewR = canDrop and 80 or 210
                local previewG = canDrop and 220 or 70
                local previewB = canDrop and 140 or 60
                -- 绘制高亮格子（物品尺寸大小）
                local gap = gc.gap or 0
                local hlX = gc.offX + snapCol * step
                local hlY = gc.offY + snapRow * step
                local hlW = itemW * cs + (itemW - 1) * gap
                local hlH = itemH * cs + (itemH - 1) * gap
                nvgBeginPath(ctx)
                nvgRect(ctx, hlX, hlY, hlW, hlH)
                nvgFillColor(ctx, nvgRGBA(previewR, previewG, previewB, 50))
                nvgFill(ctx)
                nvgBeginPath(ctx)
                nvgRect(ctx, hlX, hlY, hlW, hlH)
                nvgStrokeColor(ctx, nvgRGBA(previewR, previewG, previewB, 220))
                nvgStrokeWidth(ctx, 2)
                nvgStroke(ctx)
            end
            end
        end
    end

    -- ── 拖拽中：渲染跟随鼠标的物品 ──
    if lootUI.dragging and lootUI.dragItem ~= "" then
        local dItem = lootUI.dragItem
        local dW, dH = lootUI.GetGridItemSize(dItem, lootUI.dragOrientation)
        local dCellSz = 36  -- 拖拽时固定显示尺寸
        local dw = dW * dCellSz
        local dh = dH * dCellSz
        local dx = lootUI.dragMouseX - lootUI.dragOffX
        local dy = lootUI.dragMouseY - lootUI.dragOffY

        -- 半透明稀有度渐变背景
        local dRarity = ITEM_RARITY[dItem] or "green"
        drawRarityGradient(ctx, dRarity, dx, dy, dw, dh, 0.78, 3)
        -- 拖拽状态白色外框
        nvgBeginPath(ctx)
        nvgRect(ctx, dx, dy, dw, dh)
        nvgStrokeColor(ctx, nvgRGBA(255, 255, 255, 120))
        nvgStrokeWidth(ctx, 1.5)
        nvgStroke(ctx)
        -- 图标
        local dIconId = itemIcons[dItem]
        if dIconId and dIconId > 0 then
            local iconX, iconY, iconW, iconH = getItemIconDrawRect(dItem, dx, dy, dw, dh, dItem == "棒球棍" and 0.88 or 0.60)
            local iPaint = nvgImagePattern(ctx, iconX, iconY, iconW, iconH, 0, dIconId, 0.9)
            nvgBeginPath(ctx)
            nvgRect(ctx, iconX, iconY, iconW, iconH)
            nvgFillPaint(ctx, iPaint)
            nvgFill(ctx)
        end
        -- 名称
        nvgFontSize(ctx, 9)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
        nvgFillColor(ctx, nvgRGBA(255, 255, 255, 200))
        nvgText(ctx, dx + dw * 0.5, dy + dh - 2, dItem)
    end
end

-- ── 拖拽：鼠标按下开始拖拽 ──
local function handleLootUIMouseDown(mx, my, suppressAutoTransfer, inputSource, tapOnly)
    if not lootUI.active then return end

    -- 关闭按钮优先级最高：即使拖拽状态异常残留，也必须能关闭搜刮界面。
    if lootUI.IsCloseButtonHit(mx, my) then
        lootUI.Close()
        return
    end

    if lootUI.dragging then return end

    -- 检测命中任何容器中的物品
    local hit = hitTestAllContainers(mx, my)
    if not hit then
        lootUI.SelectItem(nil)
        return
    end
    if inputSource == "touch" and suppressAutoTransfer then
        lootUI.SelectItem(nil)
    else
        lootUI.SelectItem(hit)
    end

    -- 有物品的容器不能卸下，否则物品会随隐藏网格变得不可操作。
    if (hit.container == "equip_rig" and #playerChestRig > 0)
        or (hit.container == "equip_backpack" and #playerInventory > 0)
        or (hit.container == "equip_safe_box" and #playerSafeBox > 0) then
        print("[Equipment] 请先清空容器再卸下装备: " .. tostring(hit.item))
        return
    end

    -- 宝箱物品需要检查是否已揭示
    if hit.container == "chest" and lootUI.mode ~= "loadout" then
        local chest = chestDefs[lootUI.chestIdx]
        local _, revealTimes = lootUI.GetSequentialRevealSchedule(chest and chest.items or {})
        local itemRevealTime = revealTimes[hit.idx] or math.huge
        if lootUI.loadingElapsed < itemRevealTime then return end
    end

    -- 双击检测：360ms内点同一个槽位。搜刮物资始终优先放入背包。
    local now = gameTime or 0
    local allowAutoTransfer = (lootUI.mode ~= "inventory") and (not suppressAutoTransfer)
    local isSameSlot = lootUI.lastClickContainer == hit.container
        and lootUI.lastClickIdx == hit.idx
        and lootUI.lastClickItem == hit.item
    if allowAutoTransfer and (now - lootUI.lastClickTime) < 0.36 and isSameSlot then
        lootUI.lastClickTime = 0
        lootUI.lastClickItem = ""
        lootUI.lastClickContainer = ""
        lootUI.lastClickIdx = 0
        -- 从来源移除
        if hit.container == "chest" then
            local chest = chestDefs[lootUI.chestIdx]
            chest.items[hit.idx] = { item = "__taken__:" .. hit.item, orientation = hit.orientation }
        elseif hit.container == "rig" then
            table.remove(playerChestRig, hit.idx)
        elseif hit.container == "pocket" then
            table.remove(playerPocket, hit.idx)
        elseif hit.container == "inv" then
            table.remove(playerInventory, hit.idx)
        elseif hit.container == "safe" then
            table.remove(playerSafeBox, hit.idx)
        elseif hit.container == "equip_helmet" then
            lootUI.equippedHelmetItem = ""
        elseif hit.container == "equip_armor" then
            lootUI.equippedArmorItem = ""
        elseif hit.container == "equip_rig" then
            lootUI.equippedRigItem = ""
        elseif hit.container == "equip_backpack" then
            lootUI.equippedBackpackItem = ""
        elseif hit.container == "equip_safe_box" then
            lootUI.equippedSafeBoxItem = ""
            lootUI.UpdateSafeBoxCapacity("")
        elseif hit.container == "equip_gun" then
            lootUI.equippedGunItem = ""
        elseif hit.container == "equip_melee" then
            lootUI.equippedMeleeItem = ""
        end
        -- 自动放入第一个有空间的容器（来源不同则目标不同）
        local item = hit.item
        local placed = false
        if hit.container == "chest" then
            -- 从宝箱双击 → 直接放入玩家背包；若默认方向放不下，自动旋转。
            local fits, orientation = canFitInInventory(item)
            if fits then
                table.insert(playerInventory, lootUI.MakeGridItem(item, nil, nil, orientation))
                placed = true
            end
        else
            -- 从身上容器双击 → 作为新物资放回宝箱，不能覆盖同名已取走占位。
            local chest = chestDefs[lootUI.chestIdx]
            if chest then
                table.insert(chest.items, lootUI.MakeGridItem(item, nil, nil, hit.orientation))
                placed = true
            end
        end
        if placed and hit.container == "chest" then
            local chest = chestDefs[lootUI.chestIdx]
            if chest and hit.idx > 0 and hit.idx <= #chest.items then
                table.remove(chest.items, hit.idx)
            end
        end
        if not placed then
            -- 放不下，还原并保留当前物资选择。
            if hit.container == "chest" then
                local chest = chestDefs[lootUI.chestIdx]
                if chest then chest.items[hit.idx] = { item = item, orientation = hit.orientation } end
            elseif hit.container == "rig" then table.insert(playerChestRig, lootUI.MakeGridItem(item, nil, nil, hit.orientation))
            elseif hit.container == "pocket" then table.insert(playerPocket, lootUI.MakeGridItem(item, nil, nil, hit.orientation))
            elseif hit.container == "inv" then table.insert(playerInventory, lootUI.MakeGridItem(item, nil, nil, hit.orientation))
            elseif hit.container == "safe" then table.insert(playerSafeBox, lootUI.MakeGridItem(item, nil, nil, hit.orientation))
            elseif hit.container == "equip_helmet" then lootUI.equippedHelmetItem = item
            elseif hit.container == "equip_armor" then lootUI.equippedArmorItem = item
            elseif hit.container == "equip_rig" then lootUI.equippedRigItem = item
            elseif hit.container == "equip_backpack" then lootUI.equippedBackpackItem = item
            elseif hit.container == "equip_safe_box" then
                lootUI.equippedSafeBoxItem = item
                lootUI.UpdateSafeBoxCapacity(item)
            elseif hit.container == "equip_gun" then lootUI.equippedGunItem = item
            elseif hit.container == "equip_melee" then lootUI.equippedMeleeItem = item
            end
            lootUI.SelectItem(hit)
            print("[Loot] 背包空间不足，无法自动拾取: " .. item)
        end
        -- 检查宝箱是否清空
        local chest = chestDefs[lootUI.chestIdx]
        if chest then
            local allTaken = true
            for _, v in ipairs(chest.items) do
                if not lootUI.IsTakenGridEntry(v) then allTaken = false; break end
            end
            if allTaken then
                chest.looted = true
            end
        end
        return
    end
    if not allowAutoTransfer then
        lootUI.lastClickTime = 0
        lootUI.lastClickItem = ""
        lootUI.lastClickContainer = ""
        lootUI.lastClickIdx = 0
    else
        lootUI.lastClickTime = now
        lootUI.lastClickItem = hit.item
        lootUI.lastClickContainer = hit.container
        lootUI.lastClickIdx = hit.idx
    end

    -- 手机短点击只用于选中/双击，不进入拖拽；长按仍会走下面的拖拽流程。
    if tapOnly then return end

    local sourceEntry = hit.item
    if hit.container == "rig" then
        sourceEntry = playerChestRig[hit.idx]
    elseif hit.container == "pocket" then
        sourceEntry = playerPocket[hit.idx]
    elseif hit.container == "inv" then
        sourceEntry = playerInventory[hit.idx]
    elseif hit.container == "safe" then
        sourceEntry = playerSafeBox[hit.idx]
    elseif hit.container == "chest" then
        local chest = chestDefs[lootUI.chestIdx]
        sourceEntry = chest and chest.items[hit.idx] or hit.item
    elseif hit.container == "equip_helmet" then
        sourceEntry = lootUI.equippedHelmetItem
    elseif hit.container == "equip_armor" then
        sourceEntry = lootUI.equippedArmorItem
    elseif hit.container == "equip_rig" then
        sourceEntry = lootUI.equippedRigItem
    elseif hit.container == "equip_backpack" then
        sourceEntry = lootUI.equippedBackpackItem
    elseif hit.container == "equip_safe_box" then
        sourceEntry = lootUI.equippedSafeBoxItem
    elseif hit.container == "equip_gun" then
        sourceEntry = lootUI.equippedGunItem
    elseif hit.container == "equip_melee" then
        sourceEntry = lootUI.equippedMeleeItem
    end

    local _, _, sourceOrientation = lootUI.GetGridItemSize(sourceEntry)

    -- 开始拖拽
    lootUI.dragging = true
    lootUI.dragItem = hit.item
    lootUI.dragFrom = hit.container
    lootUI.dragFromIdx = hit.idx
    lootUI.dragSourceEntry = sourceEntry
    lootUI.dragSourceCol = hit.col
    lootUI.dragSourceRow = hit.row
    lootUI.dragOrientation = sourceOrientation
    lootUI.dragInput = inputSource or "mouse"
    lootUI.dragMouseX = mx
    lootUI.dragMouseY = my
    lootUI.dragOffX = mx - hit.px
    lootUI.dragOffY = my - hit.py

    -- 从来源容器移除
    if hit.container == "chest" then
        local chest = chestDefs[lootUI.chestIdx]
        if lootUI.mode == "loadout" then
            if chest then table.remove(chest.items, hit.idx) end
        elseif chest then
            chest.items[hit.idx] = {
                item = "__taken__:" .. hit.item,
                col = hit.col,
                row = hit.row,
                orientation = hit.orientation,
            }
        end
    elseif hit.container == "rig" then
        table.remove(playerChestRig, hit.idx)
    elseif hit.container == "pocket" then
        table.remove(playerPocket, hit.idx)
    elseif hit.container == "inv" then
        table.remove(playerInventory, hit.idx)
    elseif hit.container == "safe" then
        table.remove(playerSafeBox, hit.idx)
    elseif hit.container == "equip_helmet" then
        lootUI.equippedHelmetItem = ""
    elseif hit.container == "equip_armor" then
        lootUI.equippedArmorItem = ""
    elseif hit.container == "equip_rig" then
        lootUI.equippedRigItem = ""
    elseif hit.container == "equip_backpack" then
        lootUI.equippedBackpackItem = ""
    elseif hit.container == "equip_safe_box" then
        lootUI.equippedSafeBoxItem = ""
        lootUI.UpdateSafeBoxCapacity("")
    elseif hit.container == "equip_gun" then
        lootUI.equippedGunItem = ""
    elseif hit.container == "equip_melee" then
        lootUI.equippedMeleeItem = ""
    end
end

-- ── 拖拽：鼠标释放放置物品 ──
local function handleLootUIMouseUp(mx, my)
    if not lootUI.active then return end
    if not lootUI.dragging then return end

    local item = lootUI.dragItem
    local fromContainer = lootUI.dragFrom
    local fromIdx = lootUI.dragFromIdx
    local sourceEntry = lootUI.dragSourceEntry
    local sourceCol = lootUI.dragSourceCol
    local sourceRow = lootUI.dragSourceRow
    local sourceOrientation = lootUI.dragOrientation
    lootUI.dragging = false

    local sourceItems = nil
    local sourceCols = 0
    local sourceRows = 0
    if fromContainer == "rig" then
        sourceItems, sourceCols, sourceRows = playerChestRig, RIG_GRID_COLS, RIG_GRID_ROWS
    elseif fromContainer == "pocket" then
        sourceItems, sourceCols, sourceRows = playerPocket, PKT_GRID_COLS, PKT_GRID_ROWS
    elseif fromContainer == "inv" then
        sourceItems, sourceCols, sourceRows = playerInventory, INV_GRID_COLS, INV_GRID_ROWS
    elseif fromContainer == "safe" then
        sourceItems, sourceCols, sourceRows = playerSafeBox, SAFE_GRID_COLS, SAFE_GRID_ROWS
    end

    -- 检测鼠标释放位置所在的容器区域，计算目标格子
    local target = getDropTarget(mx, my)
    local placed = false

    -- 计算鼠标在目标网格中的格子坐标
    local function calcSnapCell(targetName)
        local gc = lootUI._gridCache and lootUI._gridCache[targetName]
        if not gc then return 0, 0 end
        local cs = gc.cellSize
        local step = getGridStep(gc)
        local itemLeft = mx - lootUI.dragOffX
        local itemTop = my - lootUI.dragOffY
        local relX = itemLeft - gc.offX
        local relY = itemTop - gc.offY
        local itemW, itemH = lootUI.GetGridItemSize(item, lootUI.dragOrientation)
        local maxCols, maxRows = CHEST_GRID_COLS, CHEST_GRID_ROWS
        if targetName == "chest" then maxCols, maxRows = lootUI.GetChestGridDimensions()
        elseif targetName == "rig" then maxCols, maxRows = RIG_GRID_COLS, RIG_GRID_ROWS
        elseif targetName == "pocket" then maxCols, maxRows = PKT_GRID_COLS, PKT_GRID_ROWS
        elseif targetName == "inv" then maxCols, maxRows = INV_GRID_COLS, INV_GRID_ROWS
        elseif targetName == "safe" then maxCols, maxRows = SAFE_GRID_COLS, SAFE_GRID_ROWS
        end
        local col = math.max(0, math.min(math.floor((relX + step * 0.5) / step), maxCols - itemW))
        local row = math.max(0, math.min(math.floor((relY + step * 0.5) / step), maxRows - itemH))
        return col, row, maxCols, maxRows
    end

    if target == "rig" then
        local col, row = calcSnapCell("rig")
        placed = tryPlaceOrSwapGrid(
            playerChestRig, item, col, row, RIG_GRID_COLS, RIG_GRID_ROWS,
            sourceItems, sourceCols, sourceRows, sourceCol, sourceRow, lootUI.dragOrientation
        )
    elseif target == "pocket" then
        local col, row = calcSnapCell("pocket")
        placed = tryPlaceOrSwapGrid(
            playerPocket, item, col, row, PKT_GRID_COLS, PKT_GRID_ROWS,
            sourceItems, sourceCols, sourceRows, sourceCol, sourceRow, lootUI.dragOrientation
        )
    elseif target == "inv" then
        local col, row = calcSnapCell("inv")
        placed = tryPlaceOrSwapGrid(
            playerInventory, item, col, row, INV_GRID_COLS, INV_GRID_ROWS,
            sourceItems, sourceCols, sourceRows, sourceCol, sourceRow, lootUI.dragOrientation
        )
    elseif target == "safe" then
        local col, row = calcSnapCell("safe")
        placed = tryPlaceOrSwapGrid(
            playerSafeBox, item, col, row, SAFE_GRID_COLS, SAFE_GRID_ROWS,
            sourceItems, sourceCols, sourceRows, sourceCol, sourceRow, lootUI.dragOrientation
        )
    elseif target == "equip_helmet" then
        if item == "二级头盔" and lootUI.equippedHelmetItem == "" then
            lootUI.equippedHelmetItem = item
            placed = true
        end
    elseif target == "equip_armor" then
        if item == "二级防弹衣" and lootUI.equippedArmorItem == "" then
            lootUI.equippedArmorItem = item
            placed = true
        end
    elseif target == "equip_rig" then
        if item == "二级胸挂" and lootUI.equippedRigItem == "" then
            lootUI.equippedRigItem = item
            placed = true
        end
    elseif target == "equip_backpack" then
        if item == "二级背包" and lootUI.equippedBackpackItem == "" then
            lootUI.equippedBackpackItem = item
            placed = true
        end
    elseif target == "equip_safe_box" then
        if lootUI.IsSafeBoxItem(item) and lootUI.equippedSafeBoxItem == "" then
            lootUI.equippedSafeBoxItem = item
            lootUI.UpdateSafeBoxCapacity(item)
            placed = true
        end
    elseif target == "equip_gun" then
        if isGunItem(item) and lootUI.equippedGunItem == "" then
            lootUI.equippedGunItem = item
            placed = true
            if item == "散弹枪" then
                switchPlayerWeaponAnim("shotgun")
            else
                switchPlayerWeaponAnim("gun")
            end
        end
    elseif target == "equip_melee" then
        if isMeleeItem(item) and lootUI.equippedMeleeItem == "" then
            lootUI.equippedMeleeItem = item
            placed = true
        end
    elseif target == "chest" then
        local chest = chestDefs[lootUI.chestIdx]
        if lootUI.mode == "loadout" then
            local col, row, maxCols, maxRows = calcSnapCell("chest")
            if chest then
                local sourceChestItems = fromContainer == "chest" and chest.items or sourceItems
                local sourceChestCols = fromContainer == "chest" and maxCols or sourceCols
                local sourceChestRows = fromContainer == "chest" and maxRows or sourceRows
                placed = tryPlaceOrSwapGrid(
                    chest.items,
                    item,
                    col,
                    row,
                    maxCols,
                    maxRows,
                    sourceChestItems,
                    sourceChestCols,
                    sourceChestRows,
                    sourceCol,
                    sourceRow,
                    lootUI.dragOrientation
                )
            end
        elseif chest and fromContainer == "chest" and fromIdx > 0 and fromIdx <= #chest.items then
            ---@diagnostic disable-next-line: assign-type-mismatch
            chest.items[fromIdx] = lootUI.MakeGridItem(
                item,
                sourceCol,
                sourceRow,
                sourceOrientation
            )
            placed = true
        elseif chest then
            table.insert(chest.items, lootUI.MakeGridItem(item, nil, nil, sourceOrientation))
            placed = true
        end
    end

    if placed and isGunItem(item) then
        playWeaponPlaceSound()
    end

    if placed and fromContainer == "chest" and lootUI.mode ~= "loadout" then
        local sourceChest = chestDefs[lootUI.chestIdx]
        if sourceChest and fromIdx > 0 and fromIdx <= #sourceChest.items
            and lootUI.IsTakenGridEntry(sourceChest.items[fromIdx]) then
            table.remove(sourceChest.items, fromIdx)
        end
    end

    if placed and fromContainer == "equip_gun" then
        if lootUI.equippedGunItem == "散弹枪" then
            switchPlayerWeaponAnim("shotgun")
        elseif lootUI.equippedGunItem == "手枪" then
            switchPlayerWeaponAnim("gun")
        elseif lootUI.equippedMeleeItem == "棒球棍" then
            switchPlayerWeaponAnim("bat")
        end
    elseif placed and fromContainer == "equip_melee" and PLAYER_ANIM_SET == "bat" then
        if lootUI.equippedGunItem == "散弹枪" then
            switchPlayerWeaponAnim("shotgun")
        else
            switchPlayerWeaponAnim("gun")
        end
    end

    if not placed then
        -- 界外释放、错误槽位或空间不足时，统一还原来源条目及原网格坐标。
        lootUI.RestoreDraggedItem()
    end

    -- 检查宝箱是否清空
    local chest = chestDefs[lootUI.chestIdx]
    if chest then
        local allTaken = true
        for _, v in ipairs(chest.items) do
            if not lootUI.IsTakenGridEntry(v) then
                allTaken = false; break
            end
        end
        if allTaken then
            chest.looted = true
        end
    end

    lootUI.dragItem = ""
    lootUI.dragFrom = ""
    lootUI.dragFromIdx = 0
    lootUI.dragSourceEntry = nil
    lootUI.dragSourceCol = nil
    lootUI.dragSourceRow = nil
    lootUI.dragInput = ""
end

-- 兼容手机触摸（点击=立即拾取到第一个可用容器）
local function handleLootUIClick(mx, my)
    handleLootUIMouseDown(mx, my)
    if lootUI.dragging then
        handleLootUIMouseUp(mx, my)
    end
end

-- ── 麦当劳建筑绘制 ──────────────────────────────────────────
local function drawMcDonalds(ctx, groundY)
    if not mcdonaldsImg or mcdonaldsImg <= 0 then return end

    -- 定位：与 drawCrossSection 使用相同的常量计算 annex 左边缘
    local REF_H = 768
    local baseFloorH = math.floor(REF_H * 0.235)
    local roofSlabT  = 72

    local fHeights_mc = {}
    local yOff = 0
    for fi = 1, CS_NUM_FLOORS do
        local fd = CS_FLOOR_DATA[fi]
        fHeights_mc[fi] = math.max(70, math.floor(baseFloorH * fd.hRatio))
        yOff = yOff + fHeights_mc[fi]
        if fi < CS_NUM_FLOORS then
            yOff = yOff + fd.slabBelow
        end
    end
    local upTotalH = roofSlabT + yOff
    local upW  = math.floor(upTotalH * 1.55)
    local annexW = math.floor(upW * 0.38)

    local sx = csWldX - cameraX  -- 主楼左边缘屏幕X

    -- 麦当劳尺寸：裁剪后图片 469x356，宽高比 469/356 ≈ 1.317
    -- 高度以附楼总高为参考（含屋顶板）
    local annexFh = fHeights_mc[CS_NUM_FLOORS]
    local annexSlabT = 52
    local annexTotalH = annexFh + annexSlabT  -- 附楼总可见高度 ~322px
    local mcH = math.floor(annexTotalH * 2.2)  -- 麦当劳高度（含M标志，约2层楼高）
    local mcW = math.floor(mcH * (477 / 356))  -- 按裁剪后图片比例计算宽度

    -- 位置：annex 左侧偏左
    local gap = 40
    local mcRight = sx - annexW - gap
    local mcLeft  = mcRight - mcW
    local mcTop   = groundY - mcH + math.floor(mcH * 0.07)  -- 下移贴地

    -- 绘制麦当劳图片
    nvgSave(ctx)
    local paint = nvgImagePattern(ctx, mcLeft, mcTop, mcW, mcH, 0, mcdonaldsImg, 1.0)
    nvgBeginPath(ctx)
    nvgRect(ctx, mcLeft, mcTop, mcW, mcH)
    nvgFillPaint(ctx, paint)
    nvgFill(ctx)
    nvgRestore(ctx)


end

-- ── 路灯闪烁状态（故障感：连续闪→稳定→灭）──────────────
-- phase: "steady"=稳定亮, "flicker"=连续快闪, "dead"=熄灭
local lampFlicker = {
    alpha = 1.0, on = true,
    phase = "steady", timer = 0, phaseDur = 3.0,
    flickTimer = 0, flickInterval = 0.06,
}

local function updateLampFlicker(dt)
    lampFlicker.timer = lampFlicker.timer + dt

    if lampFlicker.phase == "steady" then
        -- 稳定亮着
        lampFlicker.on = true
        lampFlicker.alpha = 0.85 + math.random() * 0.15
        if lampFlicker.timer >= lampFlicker.phaseDur then
            -- 进入快闪阶段
            lampFlicker.phase = "flicker"
            lampFlicker.timer = 0
            lampFlicker.phaseDur = 0.8 + math.random() * 1.5  -- 闪 0.8~2.3 秒
            lampFlicker.flickTimer = 0
            lampFlicker.flickInterval = 0.04 + math.random() * 0.06
        end

    elseif lampFlicker.phase == "flicker" then
        -- 连续快速闪烁
        lampFlicker.flickTimer = lampFlicker.flickTimer + dt
        if lampFlicker.flickTimer >= lampFlicker.flickInterval then
            lampFlicker.flickTimer = 0
            lampFlicker.flickInterval = 0.03 + math.random() * 0.08
            lampFlicker.on = not lampFlicker.on
            if lampFlicker.on then
                lampFlicker.alpha = 0.2 + math.random() * 0.6
            end
        end
        if lampFlicker.timer >= lampFlicker.phaseDur then
            -- 闪完→熄灭
            lampFlicker.phase = "dead"
            lampFlicker.timer = 0
            lampFlicker.phaseDur = 3.0 + math.random() * 5.0  -- 灭 3~8 秒
            lampFlicker.on = false
        end

    elseif lampFlicker.phase == "dead" then
        -- 熄灭
        lampFlicker.on = false
        if lampFlicker.timer >= lampFlicker.phaseDur then
            -- 尝试重新亮起（先进入快闪挣扎）
            local r = math.random()
            if r < 0.6 then
                -- 闪几下再亮
                lampFlicker.phase = "flicker"
                lampFlicker.timer = 0
                lampFlicker.phaseDur = 0.4 + math.random() * 0.8
                lampFlicker.flickTimer = 0
            else
                -- 直接亮
                lampFlicker.phase = "steady"
                lampFlicker.timer = 0
                lampFlicker.phaseDur = 2.0 + math.random() * 4.0  -- 亮 2~6 秒
                lampFlicker.on = true
                lampFlicker.alpha = 0.9
            end
        end
    end
end

-- ── 街道道具绘制（铁网栏 + 路灯，在麦当劳左侧）──────────────
local function drawStreetProps(ctx, groundY)
    -- 复用麦当劳的定位计算，获取麦当劳左边缘位置
    local REF_H = 768
    local baseFloorH = math.floor(REF_H * 0.235)
    local roofSlabT  = 72
    local yOff = 0
    for fi = 1, CS_NUM_FLOORS do
        local fd = CS_FLOOR_DATA[fi]
        local fh = math.max(70, math.floor(baseFloorH * fd.hRatio))
        yOff = yOff + fh
        if fi < CS_NUM_FLOORS then yOff = yOff + fd.slabBelow end
    end
    local upTotalH = roofSlabT + yOff
    local upW  = math.floor(upTotalH * 1.55)
    local annexW = math.floor(upW * 0.38)
    local sx = csWldX - cameraX
    -- 计算麦当劳左边缘（与 drawMcDonalds 一致）
    local annexFh = math.max(70, math.floor(baseFloorH * CS_FLOOR_DATA[CS_NUM_FLOORS].hRatio))
    local annexSlabT = 52
    local annexTotalH = annexFh + annexSlabT
    local mcH = math.floor(annexTotalH * 2.2)
    local mcW = math.floor(mcH * (477 / 356))
    local gap = 40
    local mcRight = sx - annexW - gap
    local mcLeft  = mcRight - mcW

    -- 路灯：竖在麦当劳左侧（高度与建筑挂钩）
    local lampH = math.floor(mcH * 0.45)
    local lampW = math.floor(lampH * (111 / 461))
    if lampImg and lampImg > 0 then
        local lampX = mcLeft - lampW - 5  -- 麦当劳左边缘再往左
        local lampY = groundY - lampH + math.floor(lampH * 0.03)
        nvgSave(ctx)
        local paint = nvgImagePattern(ctx, lampX, lampY, lampW, lampH, 0, lampImg, 1.0)
        nvgBeginPath(ctx)
        nvgRect(ctx, lampX, lampY, lampW, lampH)
        nvgFillPaint(ctx, paint)
        nvgFill(ctx)
        -- 灯头发光效果（受闪烁影响）
        local fAlpha = lampFlicker.on and lampFlicker.alpha or 0
        if fAlpha > 0 then
            local glowCX = lampX + lampW * 0.5
            local glowCY = lampY + lampH * 0.06
            local glowR = lampW * 2.5
            local ga1 = math.floor(90 * fAlpha)
            local glow = nvgRadialGradient(ctx, glowCX, glowCY, lampW * 0.3, glowR,
                nvgRGBA(255, 230, 160, ga1), nvgRGBA(255, 200, 100, 0))
            nvgBeginPath(ctx)
            nvgCircle(ctx, glowCX, glowCY, glowR)
            nvgFillPaint(ctx, glow)
            nvgFill(ctx)
            -- 灯头亮芯
            local coreR = lampW * 0.6
            local ca1 = math.floor(180 * fAlpha)
            local core = nvgRadialGradient(ctx, glowCX, glowCY, 0, coreR,
                nvgRGBA(255, 250, 220, ca1), nvgRGBA(255, 230, 160, 0))
            nvgBeginPath(ctx)
            nvgCircle(ctx, glowCX, glowCY, coreR)
            nvgFillPaint(ctx, core)
            nvgFill(ctx)
            -- 圆锥形光照（从灯头向下扩散）
            local coneTopX = glowCX
            local coneTopY = glowCY + lampW * 0.3
            local coneBottomY = groundY
            local coneHalfW = lampW * 3.0
            local cga = math.floor(70 * fAlpha)
            local conePaint = nvgLinearGradient(ctx, coneTopX, coneTopY, coneTopX, coneBottomY,
                nvgRGBA(255, 230, 160, cga), nvgRGBA(255, 200, 100, 0))
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, coneTopX - lampW * 0.2, coneTopY)
            nvgLineTo(ctx, coneTopX - coneHalfW, coneBottomY)
            nvgLineTo(ctx, coneTopX + coneHalfW, coneBottomY)
            nvgLineTo(ctx, coneTopX + lampW * 0.2, coneTopY)
            nvgClosePath(ctx)
            nvgFillPaint(ctx, conePaint)
            nvgFill(ctx)
            -- 地面光斑（锥底亮斑）
            local gndCX = glowCX
            local gndCY = groundY - 2
            local gndRX = coneHalfW * 0.7
            local gndRY = lampW * 0.6
            local gga = math.floor(50 * fAlpha)
            nvgSave(ctx)
            nvgTranslate(ctx, gndCX, gndCY)
            nvgScale(ctx, 1.0, gndRY / gndRX)
            local gndGlow = nvgRadialGradient(ctx, 0, 0, 0, gndRX,
                nvgRGBA(255, 230, 160, gga), nvgRGBA(255, 200, 100, 0))
            nvgBeginPath(ctx)
            nvgCircle(ctx, 0, 0, gndRX)
            nvgFillPaint(ctx, gndGlow)
            nvgFill(ctx)
            nvgRestore(ctx)
        end
        nvgRestore(ctx)
    end

    -- 路灯2：麦当劳门口（右侧）
    if lampImg and lampImg > 0 then
        local lampX = mcRight - lampW - 5  -- 麦当劳右边缘附近（门口）
        local lampY = groundY - lampH + math.floor(lampH * 0.03)
        nvgSave(ctx)
        local paint = nvgImagePattern(ctx, lampX, lampY, lampW, lampH, 0, lampImg, 1.0)
        nvgBeginPath(ctx)
        nvgRect(ctx, lampX, lampY, lampW, lampH)
        nvgFillPaint(ctx, paint)
        nvgFill(ctx)
        -- 灯头发光效果（受闪烁影响）
        local fAlpha2 = lampFlicker.on and lampFlicker.alpha or 0
        if fAlpha2 > 0 then
            local glowCX = lampX + lampW * 0.5
            local glowCY = lampY + lampH * 0.06
            local glowR = lampW * 2.5
            local ga1 = math.floor(90 * fAlpha2)
            local glow = nvgRadialGradient(ctx, glowCX, glowCY, lampW * 0.3, glowR,
                nvgRGBA(255, 230, 160, ga1), nvgRGBA(255, 200, 100, 0))
            nvgBeginPath(ctx)
            nvgCircle(ctx, glowCX, glowCY, glowR)
            nvgFillPaint(ctx, glow)
            nvgFill(ctx)
            -- 灯头亮芯
            local coreR = lampW * 0.6
            local ca1 = math.floor(180 * fAlpha2)
            local core = nvgRadialGradient(ctx, glowCX, glowCY, 0, coreR,
                nvgRGBA(255, 250, 220, ca1), nvgRGBA(255, 230, 160, 0))
            nvgBeginPath(ctx)
            nvgCircle(ctx, glowCX, glowCY, coreR)
            nvgFillPaint(ctx, core)
            nvgFill(ctx)
            -- 圆锥形光照（从灯头向下扩散）
            local coneTopX = glowCX
            local coneTopY = glowCY + lampW * 0.3
            local coneBottomY = groundY
            local coneHalfW = lampW * 3.0
            local cga2 = math.floor(70 * fAlpha2)
            local conePaint = nvgLinearGradient(ctx, coneTopX, coneTopY, coneTopX, coneBottomY,
                nvgRGBA(255, 230, 160, cga2), nvgRGBA(255, 200, 100, 0))
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, coneTopX - lampW * 0.2, coneTopY)
            nvgLineTo(ctx, coneTopX - coneHalfW, coneBottomY)
            nvgLineTo(ctx, coneTopX + coneHalfW, coneBottomY)
            nvgLineTo(ctx, coneTopX + lampW * 0.2, coneTopY)
            nvgClosePath(ctx)
            nvgFillPaint(ctx, conePaint)
            nvgFill(ctx)
            -- 地面光斑（锥底亮斑）
            local gndCX = glowCX
            local gndCY = groundY - 2
            local gndRX = coneHalfW * 0.7
            local gndRY = lampW * 0.6
            local gga2 = math.floor(50 * fAlpha2)
            nvgSave(ctx)
            nvgTranslate(ctx, gndCX, gndCY)
            nvgScale(ctx, 1.0, gndRY / gndRX)
            local gndGlow = nvgRadialGradient(ctx, 0, 0, 0, gndRX,
                nvgRGBA(255, 230, 160, gga2), nvgRGBA(255, 200, 100, 0))
            nvgBeginPath(ctx)
            nvgCircle(ctx, 0, 0, gndRX)
            nvgFillPaint(ctx, gndGlow)
            nvgFill(ctx)
            nvgRestore(ctx)
        end
        nvgRestore(ctx)
    end

    -- 两栋主楼之间的道路路灯：布置在旧仓库右侧至第二栋楼左侧的空旷路段。
    -- 仅作背景装饰，不加入碰撞或交互，避免阻挡玩家、丧尸和搜刮点。
    if lampImg and lampImg > 0 then
        local function drawRoadLamp(worldX, lightScale)
            local lampX = worldX - cameraX - lampW * 0.5
            local lampY = groundY - lampH + math.floor(lampH * 0.03)
            local glowCX = lampX + lampW * 0.5
            local glowCY = lampY + lampH * 0.06
            local fAlpha = 0.9 * (lightScale or 1.0)

            nvgSave(ctx)
            if fAlpha > 0 then
                local coneBottomY = groundY + 16
                local coneHalfW = lampW * 2.7
                local conePaint = nvgLinearGradient(ctx, glowCX, glowCY, glowCX, coneBottomY,
                    nvgRGBA(255, 228, 154, math.floor(48 * fAlpha)),
                    nvgRGBA(255, 205, 112, 0))
                nvgBeginPath(ctx)
                nvgMoveTo(ctx, glowCX - lampW * 0.18, glowCY + lampW * 0.25)
                nvgLineTo(ctx, glowCX - coneHalfW, coneBottomY)
                nvgLineTo(ctx, glowCX + coneHalfW, coneBottomY)
                nvgLineTo(ctx, glowCX + lampW * 0.18, glowCY + lampW * 0.25)
                nvgClosePath(ctx)
                nvgFillPaint(ctx, conePaint)
                nvgFill(ctx)

                nvgSave(ctx)
                nvgTranslate(ctx, glowCX, groundY + 10)
                nvgScale(ctx, 1.0, 0.24)
                local roadGlow = nvgRadialGradient(ctx, 0, 0, 0, coneHalfW * 0.78,
                    nvgRGBA(255, 222, 142, math.floor(44 * fAlpha)),
                    nvgRGBA(255, 196, 100, 0))
                nvgBeginPath(ctx)
                nvgCircle(ctx, 0, 0, coneHalfW * 0.78)
                nvgFillPaint(ctx, roadGlow)
                nvgFill(ctx)
                nvgRestore(ctx)
            end

            -- 路灯本体乘上夜色冷蓝，保持与黑夜中的建筑和路面一致；灯光随后单独叠加。
            local paint = nvgImagePatternTinted(ctx, lampX, lampY, lampW, lampH, 0, lampImg,
                nvgRGBA(128, 133, 164, 255))
            nvgBeginPath(ctx)
            nvgRect(ctx, lampX, lampY, lampW, lampH)
            nvgFillPaint(ctx, paint)
            nvgFill(ctx)

            if fAlpha > 0 then
                local glowR = lampW * 2.25
                local glow = nvgRadialGradient(ctx, glowCX, glowCY, lampW * 0.25, glowR,
                    nvgRGBA(255, 235, 176, math.floor(84 * fAlpha)),
                    nvgRGBA(255, 205, 112, 0))
                nvgBeginPath(ctx)
                nvgCircle(ctx, glowCX, glowCY, glowR)
                nvgFillPaint(ctx, glow)
                nvgFill(ctx)
            end
            nvgRestore(ctx)
        end

        -- 第一盏放在废弃超市与旧仓库之间，第二盏留在第二栋楼前，避免成组挤在一起。
        drawRoadLamp(5220, 0.86)
        drawRoadLamp(6520, 1.0)
    end

    -- 旧仓库外道路装饰：垃圾桶放在第二盏路灯左侧，靠近灯下但与灯杆保持间距。
    do
        local binX = 6435 - cameraX
        local binY = groundY
        if messyTrashBinImg and messyTrashBinImg > 0 then
            local binH = 104
            local binW = binH
            local drawX = binX - binW * 0.5
            -- 原图底部约 11% 为透明留白，以可见垃圾的底边对齐地面。
            local drawY = binY - binH * 0.89
            nvgSave(ctx)
            nvgBeginPath(ctx)
            nvgEllipse(ctx, binX, binY + 2, binW * 0.38, 5)
            nvgFillColor(ctx, nvgRGBA(5, 7, 10, 95))
            nvgFill(ctx)
            local binPaint = nvgImagePatternTinted(ctx, drawX, drawY, binW, binH, 0,
                messyTrashBinImg, nvgRGBA(150, 154, 176, 255))
            nvgBeginPath(ctx)
            nvgRect(ctx, drawX, drawY, binW, binH)
            nvgFillPaint(ctx, binPaint)
            nvgFill(ctx)
            nvgRestore(ctx)
        end

        local signX = 6030 - cameraX
        local signBaseY = groundY
        nvgSave(ctx)
        nvgBeginPath(ctx)
        nvgEllipse(ctx, signX, signBaseY + 3, 19, 5)
        nvgFillColor(ctx, nvgRGBA(5, 7, 10, 85))
        nvgFill(ctx)
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, signX - 3, signBaseY - 96, 6, 96, 2)
        nvgFillColor(ctx, nvgRGBA(43, 48, 54, 255))
        nvgFill(ctx)
        nvgStrokeColor(ctx, nvgRGBA(94, 100, 106, 170))
        nvgStrokeWidth(ctx, 1)
        nvgStroke(ctx)

        nvgSave(ctx)
        nvgTranslate(ctx, signX, signBaseY - 78)
        nvgRotate(ctx, -0.055)
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, -45, -15)
        nvgLineTo(ctx, 29, -15)
        nvgLineTo(ctx, 45, 0)
        nvgLineTo(ctx, 29, 15)
        nvgLineTo(ctx, -45, 15)
        nvgClosePath(ctx)
        local signPaint = nvgLinearGradient(ctx, 0, -15, 0, 15,
            nvgRGBA(80, 75, 58, 255), nvgRGBA(42, 42, 38, 255))
        nvgFillPaint(ctx, signPaint)
        nvgFill(ctx)
        nvgStrokeColor(ctx, nvgRGBA(126, 116, 82, 190))
        nvgStrokeWidth(ctx, 1.4)
        nvgStroke(ctx)
        nvgFontFace(ctx, "sans")
        nvgFontSize(ctx, 11)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(ctx, nvgRGBA(183, 177, 151, 215))
        nvgText(ctx, -4, 0, "居民服务楼")
        nvgRestore(ctx)
        nvgRestore(ctx)
    end

    -- 铁网栏：在麦当劳左侧地面线附近
    if fenceImg and fenceImg > 0 then
        local fenceH = math.floor(groundY * 0.12)
        local fenceW = math.floor(fenceH * (499 / 268))
        local fenceX = mcLeft - fenceW - 10  -- 麦当劳左边缘再往左
        local fenceY = groundY - fenceH + math.floor(fenceH * 0.15)
        nvgSave(ctx)
        local paint = nvgImagePattern(ctx, fenceX, fenceY, fenceW, fenceH, 0, fenceImg, 1.0)
        nvgBeginPath(ctx)
        nvgRect(ctx, fenceX, fenceY, fenceW, fenceH)
        nvgFillPaint(ctx, paint)
        nvgFill(ctx)
        nvgRestore(ctx)
    end
end

-- 傍晚远景暗色遮罩（覆盖全屏，在地面/主楼之前绘制）
local function drawEveningOverlay(ctx)
    nvgSave(ctx)
    nvgBeginPath(ctx)
    nvgRect(ctx, -2000, -2000, W + 4000, H + 4000)
    nvgFillColor(ctx, nvgRGBA(10, 10, 25, 120))
    nvgFill(ctx)
    nvgRestore(ctx)
end

local function drawCrossSection(ctx, groundY)
    -- 每帧重置遮罩参数（防止数组无限增长）
    csInfo.floorOverlays = {}
    csInfo.basOverlay = nil
    csInfo.camX = cameraX  -- 记录渲染帧的 cameraX，供 HandleUpdate 坐标转换

    -- 玩家屏幕坐标（用于杂物高亮检测）
    local playerSX = player.x - cameraX
    local playerSY = H * GROUND_Y_RATIO + player.jumpScrY

    local REF_H = 768  -- 房子尺寸固定基准，不随屏幕大小缩放
    local baseFloorH = math.floor(REF_H * 0.235)  -- 固定基准层高 180px
    local roofSlabT  = 72   -- 顶部屋顶板固定厚度
    local wallT      = 38

    -- 预计算每层净高和顶端偏移（5F在上，1F在下）
    -- 注意：最后一层(1F)的 slabBelow 不计入地上高度，
    -- 而是作为地下室天花板（从 groundY 向下延伸），使 1F 底部与地面齐平。
    local fHeights = {}
    local fTops    = {}
    local yOff = 0
    for fi = 1, CS_NUM_FLOORS do
        local fd = CS_FLOOR_DATA[fi]
        fTops[fi]    = yOff
        fHeights[fi] = math.max(70, math.floor(baseFloorH * fd.hRatio))
        yOff = yOff + fHeights[fi]
        if fi < CS_NUM_FLOORS then
            yOff = yOff + fd.slabBelow  -- 层间楼板（1F以上）
        end
    end
    -- 此时 sy + roofSlabT + yOff == groundY，1F底部恰好在地面线
    local upTotalH = roofSlabT + yOff
    -- 楼宽按宽高比 ~1.28
    local upW  = math.floor(upTotalH * 1.55)
    -- 1F与地下室之间的楼板（从groundY向下）
    local gndSlabT = CS_FLOOR_DATA[CS_NUM_FLOORS].slabBelow
    -- 地下室高度（约1.35x基准层高），起点在 groundY + gndSlabT
    local basH = math.floor(baseFloorH * basementHeightScale)
    local basSlabT = 52  -- 地下室底板厚度

    -- 更新屏幕边界，供 drawGround 挖空用
    csInfo.sx   = csWldX - cameraX
    csInfo.sw   = upW
    csInfo.basH = gndSlabT + basH + basSlabT
    csInfo.sy   = groundY - upTotalH   -- 建筑屏幕顶部Y
    csInfo.sh   = upTotalH + gndSlabT + basH + basSlabT  -- 建筑总高度
    -- 完整建筑边界（含左侧附楼和地下室扩展），供雨滴剔除用
    local basExt_ = math.floor(upW * 0.08)
    local annexW_ = math.floor(upW * 0.38)
    local fullLeft = math.min(csWldX - cameraX - annexW_, csWldX - cameraX - basExt_)
    local fullRight = csWldX - cameraX + upW + basExt_
    csInfo.rainLeft  = fullLeft
    csInfo.rainRight = fullRight
    -- 主楼屋顶Y（已有 csInfo.sy）
    -- 附楼屋顶Y（附楼比主楼矮，只有1F高度）
    local ann1FTop_ = groundY - upTotalH + roofSlabT + fTops[CS_NUM_FLOORS]
    csInfo.annexRoofY = ann1FTop_ - 52  -- 52 = annexSlabT
    csInfo.annexLeft  = csWldX - cameraX - annexW_
    csInfo.annexRight = csWldX - cameraX
    -- 世界坐标（供雨滴碰撞用，不受相机影响）
    csInfo.worldX     = csWldX
    csInfo.worldW     = upW
    csInfo.worldAnnexLeft  = csWldX - annexW_
    csInfo.worldAnnexRight = csWldX
    -- 天台隔断世界X坐标（5F右侧为露天天台，雨水可穿过屋顶但落在天台地板上）
    local wallT_ = 38
    local innerW5F_ = upW - 2 * wallT_
    csInfo.worldRoofDivX = csWldX + wallT_ + math.floor(innerW5F_ * CS_FLOOR_DATA[1].divs[1])
    -- 天台地板Y（5F底部 = 4F天花板，雨滴落在这里）
    csInfo.terraceFloorY = groundY - upTotalH + roofSlabT + fHeights[1]

    -- 屏幕 X（世界坐标 → 屏幕）
    local sx = csWldX - cameraX
    local sy = groundY - upTotalH  -- 地上部分顶端（屋顶板顶）

    -- 天台隔断X（5F左室右边缘，步骤1.5和步骤4共用）
    local innerW5F = upW - 2 * wallT
    local roofDivX = sx + wallT + math.floor(innerW5F * CS_FLOOR_DATA[1].divs[1])

    -- ── 1. 各层房间背景（5F→1F，使用每层独立高度）
    for fi = 1, CS_NUM_FLOORS do
        local fd       = CS_FLOOR_DATA[fi]
        local floorTop = sy + roofSlabT + fTops[fi]
        local fh       = fHeights[fi]
        local innerW   = upW - 2 * wallT

        local xs = { sx + wallT }
        for _, d in ipairs(fd.divs) do
            xs[#xs + 1] = sx + wallT + math.floor(innerW * d)
        end
        xs[#xs + 1] = sx + upW - wallT

        nvgSave(ctx)
        nvgScissor(ctx, sx + wallT, floorTop, innerW, fh)
        for ri, room in ipairs(fd.rooms) do
            local rx = xs[ri]
            local rw = xs[ri + 1] - xs[ri]
            if rw > 2 then
                drawCSRoom(ctx, rx, floorTop, rw, fh, room)
            end
        end
        nvgRestore(ctx)

        -- 地砖顶面先绘制，后续所有家具、保险柜、散落物和门都覆盖在它上方。
        drawIndoorFloorTop(ctx, sx + wallT, floorTop, innerW, fh)

        -- ── 5F工具房（fi==1, 第1间房，右侧留出门的位置）
        if fi == 1 and toolRoomImg and toolRoomImg ~= 0 then
            local rx = xs[1]
            local rw = xs[2] - xs[1]
            local floorBot = floorTop + fh
            nvgSave(ctx)
            nvgScissor(ctx, rx, floorTop, rw, fh)

            -- 图片只铺到房间 80% 宽度，右侧留给门
            local imgH = math.floor(fh * 0.92)
            local imgW = math.floor(rw * 0.78)
            local ix = rx + math.floor(rw * 0.02)
            local iy = floorBot - imgH
            local paint = nvgImagePattern(ctx, ix, iy, imgW, imgH, 0, toolRoomImg, 1.0)
            nvgBeginPath(ctx)
            nvgRect(ctx, ix, iy, imgW, imgH)
            nvgFillPaint(ctx, paint)
            nvgFill(ctx)

            -- 工具房整景图中部抽屉柜；避开左侧新增窄柜与右侧楼梯门。
            if isRoomLightOn("cs_1_1") then
                local chestIdx = lootUI.chestIndexByRoom["cs1_5f_tool_drawers"]
                if chestIdx then
                    checkChestProximity(
                        ctx, playerSX, playerSY,
                        ix + imgW * 0.53, iy + imgH * 0.25,
                        imgW * 0.22, imgH * 0.66,
                        chestIdx, 58
                    )
                end
            end

            nvgRestore(ctx)
        end

        -- ── 卫生间家具（第1间房为tile纹理的楼层）── 复刻参考图
        do
            local brImg = nil
            if fi == 2 then brImg = bathroomImg4F
            elseif fi == 3 then brImg = bathroomImg3F
            elseif fi == 4 then brImg = bathroomImg2F
            end
            if brImg and brImg ~= 0 then
                local rx = xs[1]
                local rw = xs[2] - xs[1]
                local floorBot = floorTop + fh
                nvgSave(ctx)
                nvgScissor(ctx, rx, floorTop, rw, fh)

                -- 整张卫生间图贴满房间（图片比例512:217≈2.36:1）
                local imgH = math.floor(fh * 0.92)
                local imgW = math.floor(rw * 0.96)
                local ix = rx + math.floor((rw - imgW) * 0.5)
                local iy = floorBot - imgH
                local paint = nvgImagePattern(ctx, ix, iy, imgW, imgH, 0, brImg, 1.0)
                nvgBeginPath(ctx)
                nvgRect(ctx, ix, iy, imgW, imgH)
                nvgFillPaint(ctx, paint)
                nvgFill(ctx)

                -- 卫生间直接摆放医疗物品；玩家靠近后直接拾取，不进入开箱界面。
                local looseItems = lootUI.bathroomLoosePickups[fi]
                if looseItems then
                    for _, pickup in ipairs(looseItems) do
                        if not pickup.picked then
                            local iconId = itemIcons[pickup.item]
                            local itemSize = math.max(30, math.floor(math.min(rw, fh) * 0.25))
                            local itemX = rx + math.floor(rw * pickup.x) - math.floor(itemSize * 0.5)
                            local itemY = floorTop + math.floor(fh * pickup.y) - math.floor(itemSize * 0.5)
                            if iconId and iconId > 0 then
                                local itemPaint = nvgImagePattern(ctx, itemX, itemY, itemSize, itemSize, 0, iconId, 1.0)
                                nvgBeginPath(ctx)
                                nvgRect(ctx, itemX, itemY, itemSize, itemSize)
                                nvgFillPaint(ctx, itemPaint)
                                nvgFill(ctx)
                            end

                            local nearX = math.max(itemX, math.min(playerSX, itemX + itemSize))
                            local nearY = math.max(itemY, math.min(playerSY, itemY + itemSize))
                            local pickupDist = math.sqrt((playerSX - nearX)^2 + (playerSY - nearY)^2)
                            if pickupDist <= 58 and pickupDist < lootUI.nearLoosePickupDist then
                                lootUI.nearLoosePickupDist = pickupDist
                                lootUI.nearLoosePickup = pickup
                            end

                            if pickupDist <= 58 then
                                local pulse = math.sin(gameTime * 5.0) * 0.5 + 0.5
                                nvgBeginPath(ctx)
                                nvgRoundedRect(ctx, itemX - 3, itemY - 3, itemSize + 6, itemSize + 6, 6)
                                nvgStrokeColor(ctx, nvgRGBA(90, 220, 150, math.floor(150 + pulse * 90)))
                                nvgStrokeWidth(ctx, 2)
                                nvgStroke(ctx)
                            end
                        end
                    end
                end

                nvgRestore(ctx)
            end
        end

        -- ── 客厅家具（第2间房，hstripe 纹理）── 各楼层差异化
        do
            local lvImg = nil
            if fi == 2 then lvImg = livingImg4F
            elseif fi == 3 then lvImg = livingImg3F
            elseif fi == 4 then lvImg = livingImg2F
            elseif fi == 5 then lvImg = livingImg1F
            end
            if lvImg and lvImg ~= 0 and xs[3] then
                local rx = xs[2]
                local rw = xs[3] - xs[2]
                local floorBot = floorTop + fh
                nvgSave(ctx)
                nvgScissor(ctx, rx, floorTop, rw, fh + ((fi == 5) and 12 or 0))

                -- 家具图只占房间左侧78%，右侧留给门；1F第二间整体略微下移以贴近地砖。
                local imgH = math.floor(fh * 0.92)
                local imgW = math.floor(rw * 0.74)
                local ix = rx + math.floor(rw * 0.02)  -- 左侧留2%边距
                local iy = floorBot - imgH + ((fi == 5) and 12 or 0)
                local paint = nvgImagePattern(ctx, ix, iy, imgW, imgH, 0, lvImg, 1.0)
                nvgBeginPath(ctx)
                nvgRect(ctx, ix, iy, imgW, imgH)
                nvgFillPaint(ctx, paint)
                nvgFill(ctx)

                -- 客厅整景图内只绑定明确且不与前景容器重叠的电视柜。
                local livingSpot = nil
                if fi == 4 then
                    livingSpot = { room = "cs1_2f_tv_cabinet", x = 0.59, y = 0.42, w = 0.25, h = 0.48 }
                end
                if livingSpot and isRoomLightOn("cs_" .. fi .. "_2") then
                    local chestIdx = lootUI.chestIndexByRoom[livingSpot.room]
                    if chestIdx then
                        checkChestProximity(
                            ctx, playerSX, playerSY,
                            ix + imgW * livingSpot.x, iy + imgH * livingSpot.y,
                            imgW * livingSpot.w, imgH * livingSpot.h,
                            chestIdx, 58
                        )
                    end
                end

                nvgRestore(ctx)
            end
        end

        -- ── 客厅动态门（可开关，开时显示楼道）──
        -- fi=1(5F)只有2间房，门在第1间右侧；其他层门在第2间右侧
        local hasDoor = doorStates[fi] and ((fi == 1 and xs[2]) or xs[3])
        if hasDoor then
            local rx, rw
            if fi == 1 then
                rx = xs[1]
                rw = xs[2] - xs[1]
            else
                rx = xs[2]
                rw = xs[3] - xs[2]
            end
            local floorBot = floorTop + fh
            local ds = doorStates[fi]

            -- 门的尺寸和位置
            local doorH = math.floor(fh * 0.58)
            local doorW = math.floor(doorH * 0.6)
            local doorX = rx + math.floor(rw * 0.88) - math.floor(doorW * 0.5)
            local doorY = floorBot - doorH - 2

            -- 检测玩家是否在当前层且靠近门
            local doorWorldCX = doorX + cameraX + math.floor(doorW * 0.5)
            doorWorldCXByFi[fi] = doorWorldCX  -- 记录每层门的世界X
            local playerNearDoor = false
            do
                -- slab 索引：slabs[1..4] 分别是 fi=1/2, fi=2/3, fi=3/4, fi=4/5 之间的楼板
                -- fi 层的天花板 = slabs[fi-1]（fi=2时为slabs[1]）
                -- fi 层的地板   = slabs[fi]（仅当 fi < CS_NUM_FLOORS 时；fi=5 地板是地面 relY=0）
                local slabAbove = (fi > 1) and csColliders.slabs[fi - 1] or nil
                local slabBelow = (fi < CS_NUM_FLOORS) and csColliders.slabs[fi] or nil
                local pY = player.jumpScrY
                local topRY = slabAbove and slabAbove.relY or -9999
                local botRY = slabBelow and slabBelow.relY or 0  -- fi=5 地板=0（地面）
                -- 上边界用严格 >（站在楼板上属于该层，不属于下层）
                if pY > topRY and pY <= botRY then
                    if math.abs(player.x - doorWorldCX) < doorW * 2.0 then
                        playerNearDoor = true
                        playerNearDoorFi = fi  -- 更新全局变量供键盘输入使用
                    end
                end
            end
            -- 玩家靠近时不自动开门，仅记录状态供F键和视觉提示使用

            nvgSave(ctx)
            nvgScissor(ctx, rx, floorTop, rw, fh)

            -- 1) 楼道背景 + 侧面楼梯（阶梯轮廓，从右下往左上）
            local corridorAlpha = ds.openProg
            if corridorAlpha > 0.01 then
                -- 楼道暗色背景
                nvgBeginPath(ctx)
                nvgRect(ctx, doorX, doorY, doorW, doorH)
                nvgFillColor(ctx, nvgRGBA(25, 20, 18, math.floor(235 * corridorAlpha)))
                nvgFill(ctx)

                -- 侧面楼梯（台阶从右下角往左上角排列）
                local stairCount = 6
                local margin = 3
                local stairAreaW = doorW - margin * 2
                local stairAreaH = doorH - margin * 2
                local stepW = math.floor(stairAreaW / stairCount)  -- 每级台阶宽度
                local stepH = math.floor(stairAreaH / stairCount)  -- 每级台阶高度

                -- 画阶梯形状（从左上到右下逐级下降，形成侧面楼梯）
                nvgBeginPath(ctx)
                local stairBaseX = doorX + margin
                local stairBaseY = doorY + margin

                -- 从最高的台阶（左上）开始画轮廓
                nvgMoveTo(ctx, stairBaseX, stairBaseY + stepH)
                for si = 0, stairCount - 1 do
                    local sx2 = stairBaseX + si * stepW
                    local sy2 = stairBaseY + si * stepH
                    -- 水平踏面
                    nvgLineTo(ctx, sx2 + stepW, sy2 + stepH)
                    -- 竖直踢面（往下到下一级）
                    if si < stairCount - 1 then
                        nvgLineTo(ctx, sx2 + stepW, sy2 + stepH * 2)
                    end
                end
                -- 封闭底部
                local endX = stairBaseX + stairCount * stepW
                local endY = stairBaseY + stairCount * stepH
                nvgLineTo(ctx, endX, endY)
                nvgLineTo(ctx, endX, doorY + doorH - margin)
                nvgLineTo(ctx, stairBaseX, doorY + doorH - margin)
                nvgClosePath(ctx)
                nvgFillColor(ctx, nvgRGBA(55, 48, 42, math.floor(220 * corridorAlpha)))
                nvgFill(ctx)

                -- 每级台阶的踏面高亮线（水平面稍亮，增加立体感）
                for si = 0, stairCount - 1 do
                    local sx2 = stairBaseX + si * stepW
                    local sy2 = stairBaseY + (si + 1) * stepH
                    nvgBeginPath(ctx)
                    nvgRect(ctx, sx2, sy2, stepW, 2)
                    nvgFillColor(ctx, nvgRGBA(90, 80, 70, math.floor(200 * corridorAlpha)))
                    nvgFill(ctx)
                end

                -- 扶手（斜线从左上到右下）
                nvgBeginPath(ctx)
                nvgRect(ctx, stairBaseX, stairBaseY, endX - stairBaseX, 2)
                nvgFillColor(ctx, nvgRGBA(80, 65, 50, math.floor(150 * corridorAlpha)))
                nvgFill(ctx)

                -- 楼道顶部微光
                nvgBeginPath(ctx)
                nvgRect(ctx, doorX + math.floor(doorW * 0.3), doorY + 4, math.floor(doorW * 0.4), 2)
                nvgFillColor(ctx, nvgRGBA(200, 180, 120, math.floor(50 * corridorAlpha)))
                nvgFill(ctx)
            end

            -- 2) 门框（只在门打开时可见，作为门洞边缘）
            if ds.openProg > 0.05 then
                local frameT = 4
                nvgBeginPath(ctx)
                nvgRect(ctx, doorX, doorY, doorW, frameT)                  -- 顶框
                nvgRect(ctx, doorX, doorY, frameT, doorH)                  -- 左框
                nvgRect(ctx, doorX + doorW - frameT, doorY, frameT, doorH) -- 右框
                nvgRect(ctx, doorX, doorY + doorH - 3, doorW, 3)           -- 门槛
                nvgFillColor(ctx, nvgRGBA(55, 38, 25, 255))
                nvgFill(ctx)
            end

            -- 3) 门板（关闭时完全覆盖整个门区域，无缝无框）
            local leafProg = 1.0 - ds.openProg
            if leafProg > 0.02 then
                -- 关闭时门板覆盖整个doorX/doorY/doorW/doorH区域
                local leafW = math.floor(doorW * leafProg)
                local leafX = doorX
                local leafH = doorH

                -- 门板主体（完全覆盖门框和楼道）
                nvgBeginPath(ctx)
                nvgRect(ctx, leafX, doorY, leafW, leafH)
                nvgFillColor(ctx, nvgRGBA(130, 85, 55, 255))
                nvgFill(ctx)

                -- 门板内嵌面板
                local panelInset = math.max(4, math.floor(leafW * 0.14))
                if leafW > panelInset * 2 + 8 then
                    nvgBeginPath(ctx)
                    nvgRect(ctx, leafX + panelInset, doorY + math.floor(leafH * 0.08),
                            leafW - 2 * panelInset, math.floor(leafH * 0.36))
                    nvgRect(ctx, leafX + panelInset, doorY + math.floor(leafH * 0.52),
                            leafW - 2 * panelInset, math.floor(leafH * 0.36))
                    nvgFillColor(ctx, nvgRGBA(108, 70, 44, 255))
                    nvgFill(ctx)
                end

                -- 门把手
                if leafW > 14 then
                    nvgBeginPath(ctx)
                    local knobX = leafX + leafW - math.max(6, math.floor(leafW * 0.16))
                    local knobY = doorY + math.floor(leafH * 0.48)
                    nvgCircle(ctx, knobX, knobY, 3)
                    nvgFillColor(ctx, nvgRGBA(210, 190, 90, 240))
                    nvgFill(ctx)
                end
            end

            -- 4) 玩家靠近时显示闪烁 F 按钮提示
            if playerNearDoor then
                local blink = math.sin(gameTime * 4.5) * 0.4 + 0.6  -- 0.2~1.0 闪烁
                local btnA = math.floor(220 * blink)
                local btnW = 22
                local btnH = 22
                local btnX = doorX + math.floor((doorW - btnW) * 0.5)
                local btnY = doorY - btnH - 6
                -- 圆角背景
                nvgBeginPath(ctx)
                nvgRoundedRect(ctx, btnX, btnY, btnW, btnH, 4)
                nvgFillColor(ctx, nvgRGBA(0, 0, 0, math.floor(160 * blink)))
                nvgFill(ctx)
                -- 边框
                nvgBeginPath(ctx)
                nvgRoundedRect(ctx, btnX, btnY, btnW, btnH, 4)
                nvgStrokeColor(ctx, nvgRGBA(255, 255, 255, btnA))
                nvgStrokeWidth(ctx, 1.5)
                nvgStroke(ctx)
                -- F 文字
                nvgFontFace(ctx, "sans")
                nvgFontSize(ctx, 14)
                nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(ctx, nvgRGBA(255, 255, 255, btnA))
                nvgText(ctx, btnX + math.floor(btnW * 0.5), btnY + math.floor(btnH * 0.5), "F")
            end

            nvgRestore(ctx)
        end

        -- ── 厨房家具（第3间房，tex=nil 的楼层）── 各楼层差异化
        do
            local ktImg = nil
            if fi == 2 then ktImg = kitchenImg4F
            elseif fi == 3 then ktImg = kitchenImg3F
            elseif fi == 4 then ktImg = kitchenImg2F
            end
            if ktImg and ktImg ~= 0 and xs[4] then
                local rx = xs[3]
                local rw = xs[4] - xs[3]
                local floorBot = floorTop + fh
                nvgSave(ctx)
                nvgScissor(ctx, rx, floorTop, rw, fh)

                local imgH = math.floor(fh * 0.92)
                local imgW = math.floor(rw * 0.96)
                local ix = rx + math.floor((rw - imgW) * 0.5)
                local iy = floorBot - imgH
                local paint = nvgImagePattern(ctx, ix, iy, imgW, imgH, 0, ktImg, 1.0)
                nvgBeginPath(ctx)
                nvgRect(ctx, ix, iy, imgW, imgH)
                nvgFillPaint(ctx, paint)
                nvgFill(ctx)

                -- 第一栋楼整景家具热区：使用各自唯一 room 索引，并让同房间点位至少相隔一个交互半径。
                local kitchenSpots = nil
                if fi == 2 then
                    kitchenSpots = {
                        { room = "cs1_4f_fridge", x = 0.16, y = 0.27, w = 0.20, h = 0.66 },
                    }
                elseif fi == 3 then
                    kitchenSpots = {
                        { room = "cs1_3f_fridge", x = 0.13, y = 0.22, w = 0.22, h = 0.70 },
                        { room = "cs1_3f_sink_cabinet", x = 0.79, y = 0.57, w = 0.20, h = 0.30 },
                    }
                elseif fi == 4 then
                    kitchenSpots = {
                        { room = "cs1_2f_fridge", x = 0.11, y = 0.32, w = 0.18, h = 0.60 },
                    }
                end
                if kitchenSpots and isRoomLightOn("cs_" .. fi .. "_3") then
                    for _, spot in ipairs(kitchenSpots) do
                        local chestIdx = lootUI.chestIndexByRoom[spot.room]
                        if chestIdx then
                            checkChestProximity(
                                ctx, playerSX, playerSY,
                                ix + imgW * spot.x, iy + imgH * spot.y,
                                imgW * spot.w, imgH * spot.h,
                                chestIdx, 58
                            )
                        end
                    end
                end

                -- 只有单独绘制的抽屉图片可搜刮；厨房整景图中的其他背景家具不绑定交互。
                if fi == 4 and lootUI.drawerImg and lootUI.drawerImg > 0 then
                    local cIdx = 6
                    local drawerH = math.min(math.floor(fh * 0.58), math.floor(rw * 0.34))
                    local drawerW = drawerH
                    local drawerCenterX = rx + math.floor(rw * 0.78)
                    local drawerX = drawerCenterX - math.floor(drawerW * 0.5)
                    local drawerY = floorBot - drawerH
                    local drawerPaint = nvgImagePattern(ctx, drawerX, drawerY, drawerW, drawerH, 0, lootUI.drawerImg, 1.0)
                    nvgBeginPath(ctx)
                    nvgRect(ctx, drawerX, drawerY, drawerW, drawerH)
                    nvgFillPaint(ctx, drawerPaint)
                    nvgFill(ctx)

                    local chestX = drawerX + drawerW * 0.24
                    local chestY = drawerY + drawerH * 0.05
                    local chestW = drawerW * 0.52
                    local chestH = drawerH * 0.90
                    checkChestProximity(ctx, playerSX, playerSY, chestX, chestY, chestW, chestH, cIdx, 70)
                end

                nvgRestore(ctx)
            end
        end

        -- ── 新增可搜刮前景家具：严格正视图，贴地并避开玩家主通道 ──
        do
            -- 5F工具房左侧：窄边储物柜，产出贵重物品。
            if fi == 1 and xs[2] then
                local extraRx = xs[1]
                local extraRw = xs[2] - xs[1]
                if isRoomLightOn("cs_1_1") then
                    lootUI.DrawRoomContainer(
                        ctx, roomDecorImgs.slimLocker,
                        playerSX, playerSY,
                        extraRx, floorTop, extraRw, fh,
                        44, 0.22, 0.62, 0.52
                    )
                end
            end

            -- 4F中间客厅左侧：玻璃展示柜，专门搜刮高价值收藏品。
            if fi == 2 and xs[3] then
                local extraRx = xs[2]
                local extraRw = xs[3] - xs[2]
                if isRoomLightOn("cs_2_2") then
                    lootUI.DrawRoomContainer(
                        ctx, roomDecorImgs.displayCase,
                        playerSX, playerSY,
                        extraRx, floorTop, extraRw, fh,
                        41, 0.23, 0.86, 0.46
                    )
                end
            end

            -- 3F中间客厅左侧：床头柜，位置低矮，不挡玩家经过的右侧楼梯门。
            if fi == 3 and xs[3] then
                local extraRx = xs[2]
                local extraRw = xs[3] - xs[2]
                if isRoomLightOn("cs_3_2") then
                    lootUI.DrawRoomContainer(
                        ctx, roomDecorImgs.newNightstand,
                        playerSX, playerSY,
                        extraRx, floorTop, extraRw, fh,
                        42, 0.25, 0.72, 0.31
                    )
                end
            end

            -- 2F右侧厨房前景：珠宝保险柜移到左侧，和右侧抽屉柜完全分开。
            if fi == 4 and xs[4] then
                local extraRx = xs[3]
                local extraRw = xs[4] - xs[3]
                if isRoomLightOn("cs_4_3") then
                    lootUI.DrawRoomContainer(
                        ctx, roomDecorImgs.modernJewelrySafe,
                        playerSX, playerSY,
                        extraRx, floorTop, extraRw, fh,
                        47, 0.28, 0.82, 0.30, 0.15
                    )
                end
            end

            -- 3F中间客厅右侧：文件保险柜移到房间中段，和左侧床头柜留出间隔。
            if fi == 3 and xs[3] then
                local extraRx = xs[2]
                local extraRw = xs[3] - xs[2]
                if isRoomLightOn("cs_3_2") then
                    lootUI.DrawRoomContainer(
                        ctx, roomDecorImgs.modernFileSafe,
                        playerSX, playerSY,
                        extraRx, floorTop, extraRw, fh,
                        46, 0.56, 0.82, 0.30, 0.15
                    )
                end
            end

            -- 4F右侧厨房前景：换成原楼下的大保险柜，作为高价值搜刮点。
            if fi == 2 and xs[4] then
                local extraRx = xs[3]
                local extraRw = xs[4] - xs[3]
                if isRoomLightOn("cs_2_3") then
                    lootUI.DrawRoomContainer(
                        ctx, lootUI.lootImgs.safe,
                        playerSX, playerSY,
                        extraRx, floorTop, extraRw, fh,
                        45, 0.76, 1.0, 0.48, 0.12
                    )
                end
            end

            -- 2F中间客厅左侧：工具抽屉柜，产出工具和电子设备。
            if fi == 4 and xs[3] then
                local extraRx = xs[2]
                local extraRw = xs[3] - xs[2]
                if isRoomLightOn("cs_4_2") then
                    lootUI.DrawRoomContainer(
                        ctx, roomDecorImgs.toolDrawer,
                        playerSX, playerSY,
                        extraRx, floorTop, extraRw, fh,
                        43, 0.24, 0.92, 0.34
                    )
                end
            end
        end

        -- ── 1F左侧客厅信件交互：信件是独立图片，放在沙发前的茶几上 ──
        -- 不再给电视柜设置搜刮点。

        -- ── 独立家具与房间装饰 ──
        do
            if fi == 5 and xs[4] then
                -- 1F最左侧房间：客厅装修，家具全部使用正视图素材，保持立面朝向玩家。
                do
                    local rx = xs[1]
                    local rw = xs[2] - xs[1]
                    local floorBot = floorTop + fh + 12
                    nvgSave(ctx)
                    nvgScissor(ctx, rx, floorTop, rw, fh + 12)

                    local function drawRoomDecor(img, centerX, bottomY, size, bottomPad)
                        if img and img > 0 then
                            -- bottomPad 补偿透明画布底部留白，让可见家具底边真正贴地。
                            local drawX = centerX - size * 0.5
                            local drawY = bottomY - size + size * (bottomPad or 0)
                            local paint = nvgImagePattern(ctx, drawX, drawY, size, size, 0, img, 1.0)
                            nvgBeginPath(ctx)
                            nvgRect(ctx, drawX, drawY, size, size)
                            nvgFillPaint(ctx, paint)
                            nvgFill(ctx)
                        end
                    end

                    -- 所有素材保持1:1绘制；不同素材按透明底边做落地补偿。
                    local roomCenterX = rx + rw * 0.50

                    -- 后墙电视柜：落地摆放，避免悬在墙面中间。
                    local tvSize = math.min(fh * 0.48, rw * 0.62)
                    drawRoomDecor(roomDecorImgs.tvCabinet, roomCenterX, floorBot, tvSize, 0.33)

                    -- 三人沙发：底部透明留白较大，向下补偿后再贴地。
                    local sofaSize = math.min(fh * 0.68, rw * 0.90)
                    drawRoomDecor(roomDecorImgs.sofa, roomCenterX, floorBot, sofaSize, 0.28)

                    -- 茶几：按素材底部透明区补偿，四条腿落到地面。
                    local tableSize = math.min(fh * 0.40, rw * 0.58)
                    drawRoomDecor(roomDecorImgs.coffeeTable, roomCenterX, floorBot + 2, tableSize, 0.25)

                    -- 独立信封放在茶几桌面中央；靠近时使用明暗脉冲提示。
                    if lootUI.letterImg and lootUI.letterImg > 0 then
                        local pulse = math.sin(gameTime * 6.0) * 0.5 + 0.5
                        local baseSize = math.max(24, math.floor(tableSize * 0.30))
                        local letterSize = baseSize * (1.0 + pulse * 0.08)
                        local letterX = roomCenterX - letterSize * 0.5
                        local letterY = floorBot - tableSize * 0.47 - (letterSize - baseSize) * 0.5
                        local letterAlpha = 0.72 + pulse * 0.28
                        local letterPaint = nvgImagePattern(ctx, letterX, letterY, letterSize, letterSize, 0, lootUI.letterImg, letterAlpha)
                        nvgBeginPath(ctx)
                        nvgRect(ctx, letterX, letterY, letterSize, letterSize)
                        nvgFillPaint(ctx, letterPaint)
                        nvgFill(ctx)

                        local nearX = math.max(letterX, math.min(playerSX, letterX + letterSize))
                        local nearY = math.max(letterY, math.min(playerSY, letterY + letterSize))
                        local letterDist = math.sqrt((playerSX - nearX)^2 + (playerSY - nearY)^2)
                        lootUI.letterRect = { x = letterX, y = letterY, w = letterSize, h = letterSize }
                        if letterDist <= 62 and letterDist < lootUI.letterDist then
                            lootUI.letterDist = letterDist
                            lootUI.letterNear = true
                        end
                    end

                    -- 落地灯与花盆都以可见底座为落地点。
                    local lampSize = math.min(fh * 0.66, rw * 0.30)
                    drawRoomDecor(roomDecorImgs.floorLamp, rx + rw * 0.14, floorBot, lampSize, 0.03)

                    local plantSize = math.min(fh * 0.58, rw * 0.32)
                    drawRoomDecor(roomDecorImgs.plant, rx + rw * 0.86, floorBot, plantSize, 0.09)

                    -- 1F背景组合图右侧酒柜，与茶几信件及中间房保险柜分开。
                    local liquorChestIdx = lootUI.chestIndexByRoom["cs1_1f_liquor_cabinet"]
                    if liquorChestIdx and isRoomLightOn("cs_5_1") then
                        checkChestProximity(
                            ctx, playerSX, playerSY,
                            rx + rw * 0.80, floorTop + fh * 0.18,
                            rw * 0.17, fh * 0.74,
                            liquorChestIdx, 58
                        )
                    end

                    nvgRestore(ctx)
                end
                if isRoomLightOn("cs_" .. fi .. "_2") then
                    -- 原大保险柜位置改为小型现代保险柜，并保留原搜刮索引15。
                    lootUI.DrawRoomContainer(
                        ctx, roomDecorImgs.modernSafe,
                        playerSX, playerSY,
                        xs[2], floorTop + 12, xs[3] - xs[2], fh,
                        15, 0.28, 0.82, 0.34, 0.15
                    )
                end

                -- 1F右侧房间是直接通外面的临街门厅：收银台、展示柜、饮料冷柜和门口杂物。
                -- 右侧出口门前保留通道，避免家具视觉上堵住玩家离开路线。
                do
                    local rx = xs[3]
                    local rw = xs[4] - xs[3]
                    local floorBot = floorTop + fh
                    nvgSave(ctx)
                    nvgScissor(ctx, rx, floorTop, rw, fh)

                    -- 后墙旧招牌 / 营业提示牌
                    local signW = math.floor(rw * 0.42)
                    local signH = math.floor(fh * 0.13)
                    local signX = rx + math.floor(rw * 0.13)
                    local signY = floorTop + math.floor(fh * 0.13)
                    nvgBeginPath(ctx)
                    nvgRoundedRect(ctx, signX, signY, signW, signH, 5)
                    nvgFillColor(ctx, nvgRGBA(66, 48, 38, 230))
                    nvgFill(ctx)
                    nvgStrokeColor(ctx, nvgRGBA(150, 115, 72, 170))
                    nvgStrokeWidth(ctx, 1.4)
                    nvgStroke(ctx)
                    nvgFontFace(ctx, "sans")
                    nvgFontSize(ctx, math.max(11, math.floor(fh * 0.055)))
                    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgFillColor(ctx, nvgRGBA(215, 180, 115, 190))
                    nvgText(ctx, signX + signW * 0.5, signY + signH * 0.52, "便利小卖部")

                    -- 小卖部家具全部使用独立正视图图片，保持原图宽高比并贴地摆放。
                    local counterW = math.floor(rw * 0.34)
                    local counterH = counterW * (384 / 514)
                    local counterX = rx + math.floor(rw * 0.04)
                    local counterY = floorBot - counterH + counterH * 0.068
                    if roomDecorImgs.shopCounter and roomDecorImgs.shopCounter > 0 then
                        local counterPaint = nvgImagePattern(ctx, counterX, counterY, counterW, counterH, 0, roomDecorImgs.shopCounter, 1.0)
                        nvgBeginPath(ctx)
                        nvgRect(ctx, counterX, counterY, counterW, counterH)
                        nvgFillPaint(ctx, counterPaint)
                        nvgFill(ctx)
                        local counterChestIdx = lootUI.chestIndexByRoom["cs1_1f_shop_counter"]
                        if counterChestIdx and isRoomLightOn("cs_5_3") then
                            checkChestProximity(
                                ctx, playerSX, playerSY,
                                counterX, counterY + counterH * 0.18,
                                counterW * 0.76, counterH * 0.76,
                                counterChestIdx, 58
                            )
                        end
                    end

                    local caseW = math.floor(rw * 0.32)
                    local caseH = caseW * (384 / 514)
                    local caseX = rx + math.floor(rw * 0.36)
                    local caseY = floorBot - caseH + caseH * 0.091
                    if roomDecorImgs.shopDisplayCase and roomDecorImgs.shopDisplayCase > 0 then
                        local casePaint = nvgImagePattern(ctx, caseX, caseY, caseW, caseH, 0, roomDecorImgs.shopDisplayCase, 1.0)
                        nvgBeginPath(ctx)
                        nvgRect(ctx, caseX, caseY, caseW, caseH)
                        nvgFillPaint(ctx, casePaint)
                        nvgFill(ctx)
                    end

                    local coolerH = math.floor(fh * 0.64)
                    local coolerW = coolerH * (384 / 514)
                    local coolerX = rx + math.floor(rw * 0.69)
                    local coolerY = floorBot - coolerH + coolerH * 0.058
                    if roomDecorImgs.shopDrinkCooler and roomDecorImgs.shopDrinkCooler > 0 then
                        local coolerPaint = nvgImagePattern(ctx, coolerX, coolerY, coolerW, coolerH, 0, roomDecorImgs.shopDrinkCooler, 1.0)
                        nvgBeginPath(ctx)
                        nvgRect(ctx, coolerX, coolerY, coolerW, coolerH)
                        nvgFillPaint(ctx, coolerPaint)
                        nvgFill(ctx)
                    end

                    local basketSize = math.floor(math.min(rw * 0.13, fh * 0.28))
                    local basketX = rx + math.floor(rw * 0.79)
                    local basketY = floorBot - basketSize + basketSize * 0.094
                    if roomDecorImgs.shopBaskets and roomDecorImgs.shopBaskets > 0 then
                        local basketPaint = nvgImagePattern(ctx, basketX, basketY, basketSize, basketSize, 0, roomDecorImgs.shopBaskets, 1.0)
                        nvgBeginPath(ctx)
                        nvgRect(ctx, basketX, basketY, basketSize, basketSize)
                        nvgFillPaint(ctx, basketPaint)
                        nvgFill(ctx)
                    end

                    nvgRestore(ctx)
                end
            end
        end

        -- ── 天花灯照明：收集参数，由 drawBasementOverlay 统一在玩家之后绘制 ──
        -- 5F(fi==1) 右侧为天台（露天），暗层遮罩只覆盖左侧室内部分
        do
            local overlayX = sx + wallT
            local overlayW = innerW
            if fi == 1 then
                -- 只覆盖到天台隔墙左侧（roofDivX 是隔墙中心）
                overlayW = roofDivX - overlayX
            end

            local roomInfos = {}
            for ri, _ in ipairs(fd.rooms) do
                local roomMidX = math.floor((xs[ri] + xs[ri + 1]) / 2)
                local rw = xs[ri + 1] - xs[ri]
                local lightKey = "cs_" .. fi .. "_" .. ri
                local brightness = getRoomBrightness(lightKey)
                roomInfos[#roomInfos + 1] = { x = xs[ri], midX = roomMidX, brightness = brightness, rw = rw, key = lightKey }

                -- 开关贴在玩家真正经过的门旁，而不是放在房间远端墙面。
                -- 5F玩家从右侧楼梯门进入左侧房间；其余楼层从中间房间的右侧楼梯门进入。
                local switchSX
                local switchSY
                if (fi == 1 and ri == 1) or (fi > 1 and ri == 2) then
                    local pathDoorX = xs[ri] + math.floor(rw * 0.88)
                    local pathDoorH = math.floor(fh * 0.58)
                    local pathDoorW = math.floor(pathDoorH * 0.6)
                    local pathDoorY = floorTop + fh - pathDoorH - 2
                    -- 门在玩家直行路径上，开关贴在门左侧，仅留少量操作间距。
                    switchSX = pathDoorX - math.floor(pathDoorW * 0.5) - 12
                    switchSY = pathDoorY + math.floor(pathDoorH * 0.50)
                elseif ri == 1 then
                    -- 非主路径房间：入口门在右侧分隔墙内侧。
                    switchSX = xs[ri + 1] - 26
                    switchSY = floorTop + fh - math.floor(fh * 0.29)
                else
                    -- 非主路径房间：入口门在左侧分隔墙内侧。
                    switchSX = xs[ri] + 26
                    switchSY = floorTop + fh - math.floor(fh * 0.29)
                end
                registerLightSwitch(ctx, lightKey, switchSX, switchSY, switchSX + cameraX, xs[ri] + cameraX, xs[ri + 1] + cameraX, floorTop, fh, 76, 82)
            end
            local overlayH = fh
            if fi == CS_NUM_FLOORS then overlayH = overlayH + 34 end
            csInfo.floorOverlays[#csInfo.floorOverlays + 1] = {
                x = overlayX, y = floorTop, w = overlayW, h = overlayH,
                roomH = fh,
                floorIndex = fi,
                wx = csWldX + wallT, ww = overlayW,
                rooms = roomInfos,
            }
        end

    end

    -- ── 1.5 天台开口：露天区域，不填充背景，直接透出后方天空和远景建筑
    -- （之前用天空渐变盖住远景，但天台应该是露天的，所以移除填充）

    -- ── 1.6 天台装饰物（图片贴图：太阳能板、围栏、花盆、桌椅、遮阳伞）
    do
        local divT5F = CS_FLOOR_DATA[1].divT
        local terrL = roofDivX + math.floor(divT5F * 0.5)  -- 天台左边（隔墙右侧）
        local terrR = sx + upW - wallT                      -- 天台右边（右外墙内面）
        local terrW = terrR - terrL
        local terrFloorY = sy + roofSlabT + fHeights[1]     -- 天台地板Y
        local terrTopY   = sy + roofSlabT                   -- 天台顶部（天空）
        local terrH = terrFloorY - terrTopY                 -- 天台净高

        nvgSave(ctx)
        nvgScissor(ctx, terrL, terrTopY, terrW, terrH)

        -- ─── 太阳能板（天台左侧，图片比例 512:343 ≈ 1.49:1） ───
        if terraceSolarImg and terraceSolarImg > 0 then
            local solarH = math.floor(terrH * 0.45)
            local solarW = math.floor(solarH * 1.49)
            local solarX = terrL + math.floor(terrW * 0.03)
            local solarY = terrFloorY - solarH - math.floor(terrH * 0.05)
            local paint = nvgImagePattern(ctx, solarX, solarY, solarW, solarH, 0, terraceSolarImg, 1.0)
            nvgBeginPath(ctx)
            nvgRect(ctx, solarX, solarY, solarW, solarH)
            nvgFillPaint(ctx, paint)
            nvgFill(ctx)
        end

        -- ─── 遮阳伞 + 桌椅（天台中偏右） ───
        -- 先画遮阳伞（在桌椅后面，图片比例 384:514 ≈ 0.747:1）
        if terraceUmbrellaImg and terraceUmbrellaImg > 0 then
            local umbH = math.floor(terrH * 0.82)
            local umbW = math.floor(umbH * 0.747)
            local umbX = terrL + math.floor(terrW * 0.58) - math.floor(umbW * 0.5)
            local umbY = terrFloorY - umbH
            local paint = nvgImagePattern(ctx, umbX, umbY, umbW, umbH, 0, terraceUmbrellaImg, 1.0)
            nvgBeginPath(ctx)
            nvgRect(ctx, umbX, umbY, umbW, umbH)
            nvgFillPaint(ctx, paint)
            nvgFill(ctx)
        end

        -- 桌椅（图片比例 514:384 ≈ 1.34:1）
        if terraceTableImg and terraceTableImg > 0 then
            local tblH = math.floor(terrH * 0.48)
            local tblW = math.floor(tblH * 1.34)
            local tblX = terrL + math.floor(terrW * 0.58) - math.floor(tblW * 0.5)
            local tblY = terrFloorY - tblH
            local paint = nvgImagePattern(ctx, tblX, tblY, tblW, tblH, 0, terraceTableImg, 1.0)
            nvgBeginPath(ctx)
            nvgRect(ctx, tblX, tblY, tblW, tblH)
            nvgFillPaint(ctx, paint)
            nvgFill(ctx)
        end

        -- ─── 花盆组合（天台右侧靠近围栏，图片比例 512:343 ≈ 1.49:1） ───
        if terracePlantsImg and terracePlantsImg > 0 then
            local plantW = math.floor(terrW * 0.30)
            local plantH = math.floor(plantW / 1.49)
            local plantX = terrR - plantW - math.floor(terrW * 0.04)
            local plantY = terrFloorY - plantH
            local paint = nvgImagePattern(ctx, plantX, plantY, plantW, plantH, 0, terracePlantsImg, 1.0)
            nvgBeginPath(ctx)
            nvgRect(ctx, plantX, plantY, plantW, plantH)
            nvgFillPaint(ctx, paint)
            nvgFill(ctx)
        end

        -- ─── 围栏（最前面一层，图片比例 512:286 ≈ 1.79:1） ───
        if terraceRailImg and terraceRailImg > 0 then
            local railH = math.floor(terrH * 0.38)
            local railW = terrW
            local railX = terrL
            local railY = terrFloorY - railH
            local paint = nvgImagePattern(ctx, railX, railY, railW, railH, 0, terraceRailImg, 1.0)
            nvgBeginPath(ctx)
            nvgRect(ctx, railX, railY, railW, railH)
            nvgFillPaint(ctx, paint)
            nvgFill(ctx)
        end

        nvgRestore(ctx)
    end

    -- ── 2. 地下室背景（从 groundY + gndSlabT 开始，gndSlabT 是1F底板）
    local basTop = groundY + gndSlabT
    -- 地下室比地上楼宽：两侧各向外延伸 8%
    local basExt = math.floor(upW * 0.08)
    local basX   = sx - basExt             -- 地下室屏幕左起点
    local basW   = upW + basExt * 2        -- 地下室总宽
    local bdivs  = CS_BASEMENT_DATA.divs
    local bxs    = { basX + wallT }
    for _, d in ipairs(bdivs) do
        bxs[#bxs + 1] = basX + wallT + math.floor((basW - 2 * wallT) * d)
    end
    bxs[#bxs + 1] = basX + basW - wallT

    -- 砖块尺寸固定，不随房间宽度缩放，各房间共用保持一致
    local basBrickW = 36
    nvgSave(ctx)
    -- 房间高度延伸到底部围墙顶边，消除缝隙
    local basRoomH = basH + basSlabT - wallT
    nvgScissor(ctx, basX + wallT, basTop, basW - 2 * wallT, basRoomH)
    for ri, room in ipairs(CS_BASEMENT_DATA.rooms) do
        local rx = bxs[ri]
        local rw = bxs[ri + 1] - rx
        if rw > 2 then
            -- 注入统一砖块尺寸
            local r = setmetatable({ brickW = basBrickW }, { __index = room })
            drawCSRoom(ctx, rx, basTop, rw, basRoomH, r)
        end
    end
    -- 地下室天花管道和灯具
    do
        local innerL  = basX + wallT
        local innerR  = basX + basW - wallT
        local innerW2 = innerR - innerL
        local pipeY   = basTop + 10   -- 主横管中心Y
        local pipeR   = 4             -- 管道半径
        local pipeCol = nvgRGBA(72, 78, 85, 255)
        local pipeHiCol = nvgRGBA(112, 120, 128, 255)

        -- 重新设置 scissor 到整个内墙区域
        nvgScissor(ctx, innerL, basTop, innerW2, basRoomH)

        -- 计算每盏灯亮度
        local brightnesses = {}
        for ri = 1, #CS_BASEMENT_DATA.rooms do
            brightnesses[ri] = getRoomBrightness("cs_bas_" .. ri)
        end

        -- 暗层遮罩和灯光参数存入 csInfo，由 drawBasementOverlay 在玩家绘制之后执行
        csInfo.basOverlay = {
            innerL    = innerL,
            innerR    = innerR,
            basTop    = basTop,
            basRoomH  = basRoomH,
            bxs       = bxs,
            brightnesses = brightnesses,
        }

        -- 恢复正常混合，绘制管道、灯具外壳和灯管（在光照层之上，此处仍在玩家之前）
        nvgGlobalCompositeOperation(ctx, NVG_SOURCE_OVER)

        -- 主横管
        nvgBeginPath(ctx)
        nvgRect(ctx, innerL, pipeY - pipeR, innerW2, pipeR * 2)
        nvgFillColor(ctx, pipeCol); nvgFill(ctx)
        nvgBeginPath(ctx)
        nvgRect(ctx, innerL, pipeY - pipeR, innerW2, 2)
        nvgFillColor(ctx, pipeHiCol); nvgFill(ctx)

        -- 垂直分支管（间隔 110px）
        local worldX0 = innerL + cameraX
        local xi0 = math.floor(worldX0 / 110)
        for xi = xi0, xi0 + math.ceil(innerW2 / 110) + 1 do
            local px = xi * 110 - cameraX
            if px >= innerL and px <= innerR - pipeR * 2 then
                nvgBeginPath(ctx)
                nvgRect(ctx, px, pipeY + pipeR, pipeR * 2, 16)
                nvgFillColor(ctx, pipeCol); nvgFill(ctx)
                nvgBeginPath(ctx)
                nvgRect(ctx, px, pipeY + pipeR, 2, 16)
                nvgFillColor(ctx, pipeHiCol); nvgFill(ctx)
            end
        end

        for ri = 1, #CS_BASEMENT_DATA.rooms do
            local roomMidX = math.floor((bxs[ri] + bxs[ri + 1]) / 2)
            local lightKey = "cs_bas_" .. ri
            -- 地下室同样将开关固定在入口门内侧。
            local doorSideOffset = 12
            local switchSX
            if ri == 1 then
                switchSX = bxs[ri + 1] - doorSideOffset
            else
                switchSX = bxs[ri] + doorSideOffset
            end
            local switchSY = basTop + basRoomH - math.floor(basRoomH * 0.40)
            registerLightSwitch(ctx, lightKey, switchSX, switchSY, switchSX + cameraX, bxs[ri] + cameraX, bxs[ri + 1] + cameraX, basTop, basRoomH, 76, 82)

            local lampW, lampH = 28, 8
            local lampX = roomMidX - math.floor(lampW / 2)
            local lampY = basTop + 2
            local brightness = brightnesses[ri]

            -- 灯具外壳
            nvgBeginPath(ctx)
            nvgRect(ctx, lampX, lampY, lampW, lampH)
            nvgFillColor(ctx, nvgRGBA(50, 52, 55, 255)); nvgFill(ctx)

            if brightness > 0.05 then
                -- 灯管亮条
                local tubeA = math.floor(255 * brightness)
                nvgBeginPath(ctx)
                nvgRect(ctx, lampX + 3, lampY + 2, lampW - 6, 3)
                nvgFillColor(ctx, nvgRGBA(255, 252, 220, tubeA)); nvgFill(ctx)
            end
        end
    end


    -- 地下室左侧房间：两个置物架并排（地板之前画）
    do
        local leftRoomL = bxs[1]
        local leftRoomR = bxs[2]
        local floorY    = basTop + basRoomH
        if basWeaponRackImg > 0 then
            local roomW = leftRoomR - leftRoomL
            -- 每个架子宽度 = 房间宽度的 38%，高度等比，上限 72% 房间高
            local drawW = math.floor(roomW * 0.38)
            local drawH = math.floor(drawW * 192 / 129)
            if drawH > math.floor(basRoomH * 0.72) then
                drawH = math.floor(basRoomH * 0.72)
                drawW = math.floor(drawH * 129 / 192)
            end
            local gap   = math.floor(roomW * 0.05)  -- 两架之间间距
            local totalW = drawW * 2 + gap
            local startX = leftRoomL + math.floor((roomW - totalW) / 2)
            local y      = floorY - drawH
            nvgSave(ctx)
            nvgScissor(ctx, leftRoomL + 2, basTop, leftRoomR - leftRoomL - 4, basRoomH)
            -- 左架（长包）
            local p1 = nvgImagePattern(ctx, startX, y, drawW, drawH, 0, basWeaponRackImg, 1.0)
            nvgBeginPath(ctx); nvgRect(ctx, startX, y, drawW, drawH)
            nvgFillPaint(ctx, p1); nvgFill(ctx)
            drawPropHighlight(ctx, playerSX, playerSY, startX, y, drawW, drawH, basWeaponRackImg, 90)
            -- 右架（头盔装备），图片加载失败时降级用左架图片
            local rackImg2 = basGearRackImg > 0 and basGearRackImg or basWeaponRackImg
            local x2 = startX + drawW + gap
            local p2 = nvgImagePattern(ctx, x2, y, drawW, drawH, 0, rackImg2, 1.0)
            nvgBeginPath(ctx); nvgRect(ctx, x2, y, drawW, drawH)
            nvgFillPaint(ctx, p2); nvgFill(ctx)
            drawPropHighlight(ctx, playerSX, playerSY, x2, y, drawW, drawH, rackImg2, 90)
            -- 宝箱#3：武器架整体区域作为可搜刮目标
            if isRoomLightOn("cs_bas_1") then
                checkChestProximity(ctx, playerSX, playerSY, startX, y, totalW, drawH, 3, 80)
            end
            -- 铁网栅栏坐标存入 csInfo，在角色之后绘制以覆盖角色
            csInfo.fenceData = { fx = leftRoomL, fy = basTop, fw = leftRoomR - leftRoomL, fh = basRoomH }
            nvgRestore(ctx)
        end
    end

    -- 地下室中间房间杂物装饰（在地板之前画，地板会盖住底部）
    do
        local midRoomL = bxs[2]
        local midRoomR = bxs[3]
        local floorY   = basTop + basRoomH
        nvgScissor(ctx, midRoomL + 36, basTop, midRoomR - midRoomL - 72, basRoomH)

        -- 左侧：铁架子（贴左墙）
        if basShelfImg > 0 then
            local w, h = 64, 96
            local x = midRoomL + 36 + 8
            local y = floorY - h
            local p = nvgImagePattern(ctx, x, y, w, h, 0, basShelfImg, 1.0)
            nvgBeginPath(ctx); nvgRect(ctx, x, y, w, h)
            nvgFillPaint(ctx, p); nvgFill(ctx)
            drawPropHighlight(ctx, playerSX, playerSY, x, y, w, h, basShelfImg, 90)
        end

        -- 铁架子旁：废弃纸箱堆（贴地）— 宝箱#1
        if basCardboxImg > 0 then
            local w, h = 121, 90
            local x = midRoomL + 36 + 8 + 64 + 4
            local y = floorY - h
            local p = nvgImagePattern(ctx, x, y, w, h, 0, basCardboxImg, 1.0)
            nvgBeginPath(ctx); nvgRect(ctx, x, y, w, h)
            nvgFillPaint(ctx, p); nvgFill(ctx)
            drawPropHighlight(ctx, playerSX, playerSY, x, y, w, h, basCardboxImg, 90)
            if isRoomLightOn("cs_bas_2") then
                checkChestProximity(ctx, playerSX, playerSY, x, y, w, h, 1, 70)
            end
        end

        -- 中间偏右：油桶（不可搜刮，纯装饰）
        if basBarrelImg > 0 then
            local w, h = 54, 80
            local midX = math.floor((midRoomL + midRoomR) / 2)
            local x = midX + 14
            local y = floorY - h
            local p = nvgImagePattern(ctx, x, y, w, h, 0, basBarrelImg, 1.0)
            nvgBeginPath(ctx); nvgRect(ctx, x, y, w, h)
            nvgFillPaint(ctx, p); nvgFill(ctx)
            drawPropHighlight(ctx, playerSX, playerSY, x, y, w, h, basBarrelImg, 90)
        end

        -- 油桶旁：木箱 — 宝箱#2
        if basCrateImg > 0 then
            local w, h = 64, 64
            local midX = math.floor((midRoomL + midRoomR) / 2)
            local x = midX + 14 + 54 + 4
            local y = floorY - h + 8
            local p = nvgImagePattern(ctx, x, y, w, h, 0, basCrateImg, 1.0)
            nvgBeginPath(ctx); nvgRect(ctx, x, y, w, h)
            nvgFillPaint(ctx, p); nvgFill(ctx)
            drawPropHighlight(ctx, playerSX, playerSY, x, y, w, h, basCrateImg, 90)
            if isRoomLightOn("cs_bas_2") then
                checkChestProximity(ctx, playerSX, playerSY, x, y, w, h, 2, 60)
            end
        end
        -- 右侧房间新增金属储物柜（可搜刮）
        if roomDecorImgs.metalLocker and roomDecorImgs.metalLocker > 0 then
            local roomW = bxs[4] - bxs[3]
            local lockerW, lockerH = math.min(roomW * 0.52, basRoomH * 0.62), math.min(basRoomH * 0.62, roomW * 0.70)
            local lockerX = bxs[3] + roomW * 0.48 - lockerW * 0.5
            local lockerY = basTop + basRoomH - lockerH + lockerH * 0.05
            local lockerPaint = nvgImagePattern(ctx, lockerX, lockerY, lockerW, lockerH, 0, roomDecorImgs.metalLocker, 1.0)
            nvgBeginPath(ctx); nvgRect(ctx, lockerX, lockerY, lockerW, lockerH)
            nvgFillPaint(ctx, lockerPaint); nvgFill(ctx)
            drawPropHighlight(ctx, playerSX, playerSY, lockerX, lockerY, lockerW, lockerH, roomDecorImgs.metalLocker, 90)
            if isRoomLightOn("cs_bas_3") then
                checkChestProximity(ctx, playerSX, playerSY, lockerX, lockerY, lockerW, lockerH, 37, 70)
            end
        end
    end

    -- 地下室地板条（与上层一致的灰色横纹，贴房间底边）
    do
        local floorThick = 6
        local floorStripY = basTop + basRoomH - floorThick
        local innerW = basW - 2 * wallT
        nvgScissor(ctx, basX + wallT, floorStripY, innerW, floorThick)
        nvgBeginPath(ctx)
        nvgRect(ctx, basX + wallT, floorStripY, innerW, floorThick)
        nvgFillColor(ctx, nvgRGBA(60, 60, 60, 255))
        nvgFill(ctx)
        local plankW = math.max(6, math.floor(innerW / 40))
        local worldX0 = basX + wallT + cameraX
        local xi0 = math.floor(worldX0 / plankW)
        for xi = xi0, xi0 + math.ceil(innerW / plankW) + 1 do
            local px = xi * plankW - cameraX
            local bright = (xi % 2 == 0) and 90 or 72
            nvgBeginPath(ctx)
            nvgRect(ctx, px, floorStripY, plankW - 1, floorThick)
            nvgFillColor(ctx, nvgRGBA(bright, bright, bright, 240))
            nvgFill(ctx)
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, px + plankW - 1, floorStripY)
            nvgLineTo(ctx, px + plankW - 1, floorStripY + floorThick)
            nvgStrokeColor(ctx, nvgRGBA(30, 30, 30, 200))
            nvgStrokeWidth(ctx, 1.0)
            nvgStroke(ctx)
        end
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, basX + wallT, floorStripY)
        nvgLineTo(ctx, basX + basW - wallT, floorStripY)
        nvgStrokeColor(ctx, nvgRGBA(160, 160, 160, 100))
        nvgStrokeWidth(ctx, 1.0)
        nvgStroke(ctx)
    end
    nvgRestore(ctx)

    -- 地下室中间房间左右各一扇窗户
    if basWinImg > 0 then
        local midRoomL = bxs[2]   -- 中间房间左边界
        local midRoomR = bxs[3]   -- 中间房间右边界
        local winW = 80
        local winH = 54
        local winY = basTop + math.floor((basH - winH) * 0.38) - 30
        local midX = math.floor((midRoomL + midRoomR) / 2)
        local gap  = 150   -- 两窗之间间距
        -- 左侧窗户（右边贴近中心）
        local lx = midX - math.floor(gap / 2) - winW
        local paint = nvgImagePattern(ctx, lx, winY, winW, winH, 0, basWinImg, 1.0)
        nvgBeginPath(ctx); nvgRect(ctx, lx, winY, winW, winH)
        nvgFillPaint(ctx, paint); nvgFill(ctx)
        -- 右侧窗户（左边贴近中心）
        local rx2 = midX + math.floor(gap / 2)
        paint = nvgImagePattern(ctx, rx2, winY, winW, winH, 0, basWinImg, 1.0)
        nvgBeginPath(ctx); nvgRect(ctx, rx2, winY, winW, winH)
        nvgFillPaint(ctx, paint); nvgFill(ctx)
    end
    -- 地下室中间房间右侧铁门
    if basDoorImg > 0 then
        local midRoomR = bxs[3]
        local doorH = math.floor(basH * 0.72)
        local doorW = math.floor(doorH * 334 / 532)  -- 铁门正面原始比例
        local doorX = midRoomR - 36 - doorW - 10  -- 36 = basDiv/2
        local doorY = basTop + basRoomH - doorH
        local paint = nvgImagePattern(ctx, doorX, doorY, doorW, doorH, 0, basDoorImg, 1.0)
        nvgBeginPath(ctx); nvgRect(ctx, doorX, doorY, doorW, doorH)
        nvgFillPaint(ctx, paint); nvgFill(ctx)
    end



    -- ── 3. 楼层分隔墙（每层独立粗细，底部留门洞，四角圆化）
    playerNearRoomDoor = nil  -- 每帧重置，在门检测循环前清除
    local cr = 8  -- 圆角半径（此处提前定义，步骤4复用）
    nvgFillColor(ctx, nvgRGBA(25, 22, 18, 255))
    for fi = 1, CS_NUM_FLOORS do
        local fd       = CS_FLOOR_DATA[fi]
        local floorTop = sy + roofSlabT + fTops[fi]
        local fh       = fHeights[fi]
        local doorH    = math.floor(fh * 0.58)
        local divW     = fd.divT
        local wallH    = fh - doorH
        for _divIdx, d in ipairs(fd.divs) do
            local lx = sx + wallT + math.floor((upW - 2 * wallT) * d)
            -- 上半截隔墙（底部留门洞缺口）
            nvgBeginPath(ctx)
            nvgRoundedRectVarying(ctx, lx - math.floor(divW / 2), floorTop, divW, wallH, 0, 0, cr, cr)
            nvgFill(ctx)
            -- 房间门：关闭时显示侧向门板；打开后切换为朝向玩家的正面门图
            if (roomDoorImg and roomDoorImg > 0) or (roomDoorSideImg and roomDoorSideImg > 0) then
                local doorKey = fi .. "_" .. _divIdx
                local rds = roomDoorStates[doorKey]
                local openProg = rds and rds.openProg or 0
                -- 检测玩家靠近（世界坐标X + 屏幕坐标Y）
                local doorWorldX = lx + cameraX
                local nearDistX = math.abs(player.x - doorWorldX)
                local playerFeetScrY = groundY + player.jumpScrY
                local doorTopY = floorTop + wallH          -- 门顶部Y
                local doorBotY = floorTop + wallH + doorH  -- 门底部Y
                local doorCenterY = doorTopY + doorH * 0.5 -- 门中心Y（图标用）
                -- 玩家脚在门的Y范围内（含一定容差）
                local yInRange = (playerFeetScrY >= doorTopY - 10 and playerFeetScrY <= doorBotY + 20)
                local isNear = (nearDistX < 80 and yInRange)
                if isNear then playerNearRoomDoor = doorKey end

                local doorDrawH = doorH * 1.2
                local frontDoorW = doorDrawH * (WOOD_DOOR_FRONT_RATIO)
                local sideDoorW = doorH * (71 / 128) * 1.2
                local img = roomDoorSideImg
                local doorDrawW = sideDoorW
                if openProg > 0.5 and roomDoorImg and roomDoorImg > 0 then
                    img = roomDoorImg
                    doorDrawW = frontDoorW
                elseif not img or img <= 0 then
                    img = roomDoorImg
                    doorDrawW = frontDoorW
                end
                local doorX = lx - math.floor(doorDrawW / 2)
                local doorY = floorTop + wallH - (doorDrawH - doorH) * 0.5
                local dPaint = nvgImagePattern(ctx, doorX, doorY, doorDrawW, doorDrawH, 0, img, 1.0)
                nvgBeginPath(ctx)
                nvgRect(ctx, doorX, doorY, doorDrawW, doorDrawH)
                nvgFillPaint(ctx, dPaint)
                nvgFill(ctx)
                -- 关门时显示图标
                if openProg < 0.5 then
                    local iconR = math.min(doorDrawW, doorH) * 0.25
                    local iconCX = lx
                    local iconCY = doorCenterY
                    local iconAlpha = isNear and 255 or 140
                    local sw2 = isNear and 4.5 or 3.0
                    nvgBeginPath(ctx)
                    nvgCircle(ctx, iconCX, iconCY, iconR)
                    nvgStrokeColor(ctx, nvgRGBA(255, 255, 255, iconAlpha))
                    nvgStrokeWidth(ctx, sw2)
                    nvgStroke(ctx)
                    if isNear then
                        nvgBeginPath(ctx)
                        nvgCircle(ctx, iconCX, iconCY, iconR + 3)
                        nvgStrokeColor(ctx, nvgRGBA(255, 255, 255, 60))
                        nvgStrokeWidth(ctx, 4)
                        nvgStroke(ctx)
                    end
                    local dIW = iconR * 0.7
                    local dIH = iconR * 1.1
                    local dIX = iconCX - dIW * 0.5
                    local dIY = iconCY - dIH * 0.5
                    nvgBeginPath(ctx)
                    nvgRoundedRect(ctx, dIX, dIY, dIW, dIH, 2)
                    nvgStrokeColor(ctx, nvgRGBA(255, 255, 255, iconAlpha))
                    nvgStrokeWidth(ctx, 2.5)
                    nvgStroke(ctx)
                    nvgBeginPath(ctx)
                    nvgCircle(ctx, dIX + dIW * 0.78, iconCY, 2.5)
                    nvgFillColor(ctx, nvgRGBA(255, 255, 255, iconAlpha))
                    nvgFill(ctx)
                end
                nvgFillColor(ctx, nvgRGBA(25, 22, 18, 255))
            end
        end
    end
    -- 地下室分隔墙（同样底部留门洞，四角圆化）+ 门
    do
        local basDiv   = 90
        local basDoorH = math.floor(basH * 0.58)
        local wallH    = basH - basDoorH
        for divIdx, d in ipairs(CS_BASEMENT_DATA.divs) do
            local lx = basX + wallT + math.floor((basW - 2 * wallT) * d)
            nvgBeginPath(ctx)
            nvgRoundedRectVarying(ctx, lx - math.floor(basDiv / 2), basTop, basDiv, wallH, 0, 0, cr, cr)
            nvgFill(ctx)
            -- 门：关闭时显示侧向门板；打开后切换为朝向玩家的正面门图
            if (roomDoorImg and roomDoorImg > 0) or (roomDoorSideImg and roomDoorSideImg > 0) then
                local doorKey = "bas_" .. divIdx
                local rds = roomDoorStates[doorKey]
                local openProg = rds and rds.openProg or 0
                local doorDrawH = basDoorH * 1.2
                local frontDoorW = doorDrawH * (WOOD_DOOR_FRONT_RATIO)
                local sideDoorW = doorDrawH * (71 / 128)
                local img = roomDoorSideImg
                local doorDrawW = sideDoorW
                if openProg > 0.5 and roomDoorImg and roomDoorImg > 0 then
                    img = roomDoorImg
                    doorDrawW = frontDoorW
                elseif not img or img <= 0 then
                    img = roomDoorImg
                    doorDrawW = frontDoorW
                end
                local doorX = lx - math.floor(doorDrawW / 2)
                local doorY = basTop + wallH - (doorDrawH - basDoorH) * 0.5
                local dPaint = nvgImagePattern(ctx, doorX, doorY, doorDrawW, doorDrawH, 0, img, 1.0)
                nvgBeginPath(ctx)
                nvgRect(ctx, doorX, doorY, doorDrawW, doorDrawH)
                nvgFillPaint(ctx, dPaint)
                nvgFill(ctx)
                -- 图标
                local iconR = math.min(doorDrawW, basDoorH) * 0.32
                local iconCX = lx
                local iconCY = basTop + wallH + basDoorH * 0.5
                local doorWorldX = lx + cameraX
                local nearDistX = math.abs(player.x - doorWorldX)
                local playerScrY = H * GROUND_Y_RATIO + player.jumpScrY
                local nearDistY = math.abs(playerScrY - iconCY)
                local isNear = (nearDistX < 60 and nearDistY < basH * 0.6)
                local iconAlpha = isNear and 255 or 140
                local strokeW2 = isNear and 4.5 or 3.0
                nvgBeginPath(ctx)
                nvgCircle(ctx, iconCX, iconCY, iconR)
                nvgStrokeColor(ctx, nvgRGBA(255, 255, 255, iconAlpha))
                nvgStrokeWidth(ctx, strokeW2)
                nvgStroke(ctx)
                if isNear then
                    nvgBeginPath(ctx)
                    nvgCircle(ctx, iconCX, iconCY, iconR + 3)
                    nvgStrokeColor(ctx, nvgRGBA(255, 255, 255, 60))
                    nvgStrokeWidth(ctx, 4)
                    nvgStroke(ctx)
                end
                local dIconW = iconR * 0.7
                local dIconH = iconR * 1.1
                local dIconX = iconCX - dIconW * 0.5
                local dIconY = iconCY - dIconH * 0.5
                nvgBeginPath(ctx)
                nvgRoundedRect(ctx, dIconX, dIconY, dIconW, dIconH, 2)
                nvgStrokeColor(ctx, nvgRGBA(255, 255, 255, iconAlpha))
                nvgStrokeWidth(ctx, 2.5)
                nvgStroke(ctx)
                nvgBeginPath(ctx)
                nvgCircle(ctx, dIconX + dIconW * 0.78, iconCY, 2.5)
                nvgFillColor(ctx, nvgRGBA(255, 255, 255, iconAlpha))
                nvgFill(ctx)
                nvgFillColor(ctx, nvgRGBA(25, 22, 18, 255))
            end
        end
    end

    -- ── 4. 楼层水平板（全角圆化，T形交接处用补块消除缺口）
    -- cr = 8 已在步骤3定义
    local col = nvgRGBA(25, 22, 18, 255)
    nvgFillColor(ctx, col)

    -- 辅助：画全角圆角矩形
    local function rr(x, y, w, h)
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, x, y, w, h, cr)
        nvgFill(ctx)
    end
    -- 辅助：画无圆角补块（填 T形接头的凹口）
    local function patch(x, y, w, h)
        nvgBeginPath(ctx)
        nvgRect(ctx, x, y, w, h)
        nvgFill(ctx)
    end

    -- 顶部屋顶板（全角圆化）
    rr(sx, sy, roofDivX - sx + wallT, roofSlabT)

    -- 2F~5F 各层楼板正面从地砖顶面的前沿开始，避免后绘制的楼板盖住地砖和家具底脚。
    for fi = 1, CS_NUM_FLOORS - 1 do
        local fd      = CS_FLOOR_DATA[fi]
        local slabTop = sy + roofSlabT + fTops[fi] + fHeights[fi]
        local slabH   = fd.slabBelow
        local faceTop = slabTop + INDOOR_FLOOR_DEPTH
        local faceH   = math.max(0, slabH - INDOOR_FLOOR_DEPTH)
        if faceH > 0 then
            rr(sx, faceTop, upW, faceH)
            -- 左右端 T 接补块只填楼板正面，不覆盖地砖顶面。
            patch(sx, faceTop, cr, math.min(cr, faceH))
            patch(sx, faceTop + math.max(0, faceH - cr), cr, math.min(cr, faceH))
            patch(sx + upW - cr, faceTop, cr, math.min(cr, faceH))
            patch(sx + upW - cr, faceTop + math.max(0, faceH - cr), cr, math.min(cr, faceH))
        end
    end

    -- 1F楼板正面同样从地砖前沿开始；两端补块；楼梯开口处留空
    -- 楼梯开口在地下室最右侧房间上方（innerW1F 约 80% 处）
    local innerW1F  = upW - 2 * wallT
    local ladW      = math.floor(innerW1F * 0.09)   -- 开口宽
    local ladRelX   = math.floor(innerW1F * 0.80)   -- 距左内墙偏移，对应右侧房间
    local ladX1     = sx + wallT + ladRelX           -- 开口左边 X（屏幕）
    local ladX2     = ladX1 + ladW                   -- 开口右边 X
    local gndFaceY  = groundY + INDOOR_FLOOR_DEPTH
    local gndFaceH  = math.max(0, gndSlabT - INDOOR_FLOOR_DEPTH)
    -- 左段（从外墙左到开口左）
    if gndFaceH > 0 then
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, sx, gndFaceY, ladX1 - sx, gndFaceH, cr)
        nvgFill(ctx)
        patch(sx, gndFaceY, cr, math.min(cr, gndFaceH))
        patch(sx, gndFaceY + math.max(0, gndFaceH - cr), cr, math.min(cr, gndFaceH))
        -- 右段（从开口右到外墙右）
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, ladX2, gndFaceY, sx + upW - ladX2, gndFaceH, cr)
        nvgFill(ctx)
        patch(sx + upW - cr, gndFaceY, cr, math.min(cr, gndFaceH))
        patch(sx + upW - cr, gndFaceY + math.max(0, gndFaceH - cr), cr, math.min(cr, gndFaceH))
        -- 开口左右补块仅覆盖楼板正面。
        patch(ladX1 - cr, gndFaceY, cr, math.min(cr, gndFaceH))
        patch(ladX1 - cr, gndFaceY + math.max(0, gndFaceH - cr), cr, math.min(cr, gndFaceH))
        patch(ladX2, gndFaceY, cr, math.min(cr, gndFaceH))
        patch(ladX2, gndFaceY + math.max(0, gndFaceH - cr), cr, math.min(cr, gndFaceH))
    end
    -- 开口两侧楼板截面：木板横纹背景
    -- 绘制辅助函数：在指定矩形内绘制横向木板纹理
    local function drawSlabWood(wx, wy, ww, wh)
        if ww < 2 or wh < 2 then return end
        -- 底色（深木色）
        nvgBeginPath(ctx)
        nvgRect(ctx, wx, wy, ww, wh)
        nvgFillColor(ctx, nvgRGBA(90, 62, 35, 255))
        nvgFill(ctx)
        -- 横向木纹线（水平方向，模拟木板层叠截面）
        local plankH = math.max(5, math.floor(wh / 5))
        for li = 0, math.ceil(wh / plankH) do
            local ly = wy + li * plankH
            -- 每块木板微微不同深浅（用li奇偶交替）
            local bright = (li % 2 == 0) and 110 or 80
            nvgBeginPath(ctx)
            nvgRect(ctx, wx, ly, ww, plankH - 1)
            nvgFillColor(ctx, nvgRGBA(bright, math.floor(bright * 0.65), math.floor(bright * 0.36), 220))
            nvgFill(ctx)
            -- 木纹深色细线（靠近接缝处）
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, wx, ly + plankH - 1)
            nvgLineTo(ctx, wx + ww, ly + plankH - 1)
            nvgStrokeColor(ctx, nvgRGBA(40, 25, 12, 180))
            nvgStrokeWidth(ctx, 1.0)
            nvgStroke(ctx)
        end
        -- 纵向木纹短线（模拟木材纹理，确定性随机）
        local grainCnt = math.max(1, math.floor(ww / 8))
        for gi = 0, grainCnt do
            local gx = wx + gi * 8 + 3
            if gx < wx + ww - 2 then
                local gh = math.floor(wh * 0.4)
                local gy = wy + math.floor(wh * 0.15)
                nvgBeginPath(ctx)
                nvgMoveTo(ctx, gx, gy)
                nvgLineTo(ctx, gx + 1, gy + gh)
                nvgStrokeColor(ctx, nvgRGBA(50, 30, 14, 80))
                nvgStrokeWidth(ctx, 1.0)
                nvgStroke(ctx)
            end
        end
    end

    -- 整条开口区域铺木板背景（梯子图片叠在上面）
    drawSlabWood(ladX1, groundY, ladW, gndSlabT)

    -- 绘制梯子图片（从1F楼板顶部延伸到地下室底部，含楼板厚度）
    if ladderImg > 0 then
        local ladImgH = gndSlabT + basH   -- 梯子从地面楼板顶到地下室底壁顶
        local paint = nvgImagePattern(ctx, ladX1, groundY, ladW, ladImgH, 0, ladderImg, 1.0)
        nvgBeginPath(ctx)
        nvgRect(ctx, ladX1, groundY, ladW, ladImgH)
        nvgFillPaint(ctx, paint)
        nvgFill(ctx)
    end

    -- 地下室底板（全角圆化）；两端补块
    rr(basX, basTop + basH, basW, basSlabT)
    patch(basX, basTop + basH, cr, cr)
    patch(basX, basTop + basH + basSlabT - cr, cr, cr)
    patch(basX + basW - cr, basTop + basH, cr, cr)
    patch(basX + basW - cr, basTop + basH + basSlabT - cr, cr, cr)

    -- ── 4.5 地下室延伸区顶板（左右各一块，与地面平齐，用土层颜色填充）
    -- 延伸区 groundY ~ basTop 段本是空洞，用墙体同色填实
    nvgFillColor(ctx, nvgRGBA(25, 22, 18, 255))  -- 与外墙同色
    nvgBeginPath(ctx)
    nvgRect(ctx, basX, groundY, basExt, gndSlabT)   -- 左延伸区顶
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgRect(ctx, sx + upW, groundY, basExt, gndSlabT)  -- 右延伸区顶
    nvgFill(ctx)

    -- ── 5. 左右外墙（全角圆化，T接处用补块消除缺口；含外墙开口）
    -- 地下室底部围墙（底边与侧墙底边对齐：basTop+basH+basSlabT）
    nvgFillColor(ctx, nvgRGBA(25, 22, 18, 255))
    nvgBeginPath(ctx)
    nvgRect(ctx, basX, basTop + basH + basSlabT - wallT, basW, wallT)
    nvgFill(ctx)

    nvgFillColor(ctx, col)
    local totalH  = upTotalH + gndSlabT + basH + basSlabT
    local ann1FDoorH = math.floor(fHeights[CS_NUM_FLOORS] * 0.58)

    -- 预计算各层外墙开口位置（fi=1~4 即 5F~2F；右墙跳过 fi=1 天台侧）
    local lGaps, rGaps = {}, {}
    for fi = 1, CS_NUM_FLOORS - 1 do
        local fh       = fHeights[fi]
        local floorTop = sy + roofSlabT + fTops[fi]
        local g = { y = floorTop + math.floor(fh * 0.18), h = math.floor(fh * 0.38) }
        lGaps[#lGaps + 1] = g
        if fi > 1 then rGaps[#rGaps + 1] = g end
    end
    -- 右外墙绘制用开口：保留 2F~4F 窗洞，并额外给 1F 右侧出口留门洞。
    -- 碰撞区同步见 initCrossSection() 中的 1f_right doorKey。
    local rWallGaps = {}
    for _, g in ipairs(rGaps) do rWallGaps[#rWallGaps + 1] = g end
    rWallGaps[#rWallGaps + 1] = { y = groundY - ann1FDoorH, h = ann1FDoorH }

    -- 辅助：分段绘制外墙，跳过 gaps 列表中的开口区（gaps 已按 y 升序）
    local function drawWallSegs(wx, wallY, wallH, gaps, isLeftWall)
        local y       = wallY
        local wallEnd = wallY + wallH
        local isTop   = true
        for _, g in ipairs(gaps) do
            local gy   = math.max(g.y, y)
            local gEnd = math.min(g.y + g.h, wallEnd)
            if gEnd > gy and gy >= y then
                if gy > y then
                    nvgBeginPath(ctx)
                    if isTop then
                        nvgRoundedRect(ctx, wx, y, wallT, gy - y, cr)
                    else
                        nvgRect(ctx, wx, y, wallT, gy - y)
                    end
                    nvgFill(ctx)
                    isTop = false
                end
                y = gEnd
            end
        end
        if y < wallEnd then
            nvgBeginPath(ctx)
            if isTop then
                nvgRoundedRect(ctx, wx, y, wallT, wallEnd - y, cr)
            else
                nvgRect(ctx, wx, y, wallT, wallEnd - y)
            end
            nvgFill(ctx)
        end
    end

    -- 左外墙（地上，含开口）
    drawWallSegs(sx, sy, upTotalH - ann1FDoorH, lGaps, true)
    -- 屋顶板与左墙 T接：填右上角缺口
    patch(sx + wallT - cr, sy, cr, cr)
    -- (1F左入口门移到函数末尾绘制，防止被附属房间覆盖)
    -- 左外墙（地下建筑段：1F底板厚度）
    rr(sx, groundY, wallT, gndSlabT)
    patch(sx, groundY, cr, cr)
    patch(sx, groundY + gndSlabT - cr, cr, cr)
    -- 地下室延伸左墙（从 basTop 到底板底）
    rr(basX, basTop, wallT, basH + basSlabT)
    patch(basX, basTop, cr, cr)
    patch(basX, basTop + basH, cr, cr)
    patch(basX, basTop + basH + basSlabT - cr, cr, cr)

    -- 右外墙 / 天台围墙（全角圆化，含开口）
    local f5H      = roofSlabT + fHeights[1]
    local f5SlabH  = CS_FLOOR_DATA[1].slabBelow
    local parapetH = math.floor(fHeights[1] * 0.55)
    local parapetTop = sy + f5H + f5SlabH - parapetH
    -- 右外墙地上段（含1F底板），止于 basTop
    local rWallAboveH = groundY + gndSlabT - parapetTop
    drawWallSegs(sx + upW - wallT, parapetTop, rWallAboveH, rWallGaps, false)
    -- 各楼板与右墙 T接补块
    local slab4FTop = sy + roofSlabT + fTops[1] + fHeights[1]
    local slab4FH   = CS_FLOOR_DATA[1].slabBelow
    patch(sx + upW - cr, slab4FTop, cr, cr)
    patch(sx + upW - cr, slab4FTop + slab4FH - cr, cr, cr)
    -- 右外墙地下段（1F底板右侧接头补块）
    patch(sx + upW - cr, groundY, cr, cr)
    patch(sx + upW - cr, groundY + gndSlabT - cr, cr, cr)
    -- 地下室延伸右墙
    rr(basX + basW - wallT, basTop, wallT, basH + basSlabT)
    patch(basX + basW - cr, basTop, cr, cr)
    patch(basX + basW - cr, basTop + basH, cr, cr)
    patch(basX + basW - cr, basTop + basH + basSlabT - cr, cr, cr)

    -- ── 5.5 外墙开口剖面窗户（窗框 + 玻璃剖面，贴外侧绘制）
    do
        local frameW   = 10                             -- 窗框厚度（外/内各一条）
        local glassW   = wallT - frameW * 2             -- 玻璃填满两框中间
        local frameCol = nvgRGBA(58, 50, 40, 255)       -- 深棕色窗框
        local glassCol = nvgRGBA(185, 220, 245, 200)    -- 淡蓝色玻璃（半透明）

        local function drawWinSection(wx, wy, wh)
            -- 外侧窗框
            nvgBeginPath(ctx)
            nvgRect(ctx, wx, wy, frameW, wh)
            nvgFillColor(ctx, frameCol)
            nvgFill(ctx)
            -- 玻璃
            nvgBeginPath(ctx)
            nvgRect(ctx, wx + frameW, wy, glassW, wh)
            nvgFillColor(ctx, glassCol)
            nvgFill(ctx)
            -- 内侧窗框
            nvgBeginPath(ctx)
            nvgRect(ctx, wx + wallT - frameW, wy, frameW, wh)
            nvgFillColor(ctx, frameCol)
            nvgFill(ctx)
        end

        for _, g in ipairs(lGaps) do
            drawWinSection(sx, g.y, g.h)
        end
        for _, g in ipairs(rGaps) do
            drawWinSection(sx + upW - wallT, g.y, g.h)
        end
    end

    -- ── 6. 右侧钢桁架（贴图，放在相邻楼层窗户之间的间隙）
    if trussImg and trussImg > 0 then
        for fi = 1, CS_NUM_FLOORS - 1 do
            local fh       = fHeights[fi]
            local fhNext   = fHeights[fi + 1]
            local floorTop = sy + roofSlabT + fTops[fi]
            local floorTopNext = sy + roofSlabT + fTops[fi + 1]
            -- 上层窗底 → 下层窗顶
            local gapTop    = floorTop     + math.floor(fh     * 0.56)
            local gapBottom = floorTopNext + math.floor(fhNext * 0.18)
            local size      = gapBottom - gapTop
            if size > 4 then
                local tx    = sx + upW - math.floor(size * 0.05)   -- 补偿图片左侧透明边
                local paint = nvgImagePattern(ctx, tx, gapTop, size, size, 0, trussImg, 1.0)
                nvgBeginPath(ctx)
                nvgRect(ctx, tx, gapTop, size, size)
                nvgFillPaint(ctx, paint)
                nvgFill(ctx)
            end
        end
    end

    -- ── 8. 左侧附属房间（与1F同高，向左凸出主楼外）
    local annexW     = math.floor(upW * 0.38)   -- 附属宽度约为主楼的38%
    local annexSlabT = 52                        -- 屋顶板厚度
    local ann1FTop   = sy + roofSlabT + fTops[CS_NUM_FLOORS]  -- 与1F顶齐平
    local annexFh    = fHeights[CS_NUM_FLOORS]   -- 与1F同高
    local annexLeft  = sx - annexW
    local annexRoom  = { bg={142, 118, 92}, tex="hstripe", tcol={112, 90, 68}, ta=65 }

    -- 房间背景（两侧均延伸到墙体开口区域：左到 annexLeft，右到 sx+wallT）
    nvgSave(ctx)
    nvgScissor(ctx, annexLeft, ann1FTop, annexW + wallT, annexFh)
    drawCSRoom(ctx, annexLeft, ann1FTop, annexW + wallT, annexFh, annexRoom)
    nvgRestore(ctx)

    -- 附楼左侧房间停放摩托车：严格侧面正视图，原始3:2比例，显著放大。
    do
        local motorcycleRoomW = annexW + wallT
        local motorcycleH = math.min(annexFh * 0.72, motorcycleRoomW * 0.46)
        local motorcycleW = motorcycleH * 1.5
        local motorcycleX = annexLeft + motorcycleRoomW * 0.50
        -- 房间地面线就是附楼房间背景的底边，不使用屋顶板的 y 坐标。
        local motorcycleBottom = ann1FTop + annexFh + 4
        local motorcycleDrawX = motorcycleX - motorcycleW * 0.5
        -- 素材底部约有12.5%的透明留白，补偿后让两个轮胎接触地面线。
        local motorcycleDrawY = motorcycleBottom - motorcycleH + motorcycleH * 0.16
        if roomDecorImgs.motorcycle and roomDecorImgs.motorcycle > 0 then
            local motorcyclePaint = nvgImagePattern(ctx, motorcycleDrawX, motorcycleDrawY, motorcycleW, motorcycleH, 0, roomDecorImgs.motorcycle, 1.0)
            nvgBeginPath(ctx)
            nvgRect(ctx, motorcycleDrawX, motorcycleDrawY, motorcycleW, motorcycleH)
            nvgFillPaint(ctx, motorcyclePaint)
            nvgFill(ctx)
        end
    end

    -- 附楼维修间配套物件：全部使用正视图素材，避开摩托车和入口通道。
    do
        local roomW = annexW + wallT
        local roomL = annexLeft
        local roomR = annexLeft + roomW
        local roomFloor = ann1FTop + annexFh + 4
        local function drawWorkshopProp(img, centerX, bottomY, size, bottomPad)
            if img and img > 0 then
                local drawX = centerX - size * 0.5
                local drawY = bottomY - size + size * (bottomPad or 0)
                local paint = nvgImagePattern(ctx, drawX, drawY, size, size, 0, img, 1.0)
                nvgBeginPath(ctx)
                nvgRect(ctx, drawX, drawY, size, size)
                nvgFillPaint(ctx, paint)
                nvgFill(ctx)
            end
        end

        -- 墙面工具板：挂在摩托车上方，强化维修间主题。
        local boardSize = math.min(annexFh * 0.40, roomW * 0.42)
        drawWorkshopProp(roomDecorImgs.toolBoard, roomL + roomW * 0.52, ann1FTop + annexFh * 0.50, boardSize, 0.02)

        -- 工具柜：靠右墙落地。
        local cabinetSize = math.min(annexFh * 0.56, roomW * 0.30)
        drawWorkshopProp(roomDecorImgs.toolCabinet, roomR - roomW * 0.18, roomFloor, cabinetSize, 0.04)

        -- 维修工作台：靠右下方，和工具柜形成工作区。
        local benchSize = math.min(annexFh * 0.48, roomW * 0.42)
        drawWorkshopProp(roomDecorImgs.workbench, roomR - roomW * 0.49, roomFloor, benchSize, 0.06)

        -- 轮胎架：放在右侧中部墙边。
        local rackSize = math.min(annexFh * 0.45, roomW * 0.28)
        drawWorkshopProp(roomDecorImgs.tireRack, roomR - roomW * 0.78, roomFloor, rackSize, 0.04)

        -- 油桶：靠右前角落地摆放。
        local drumSize = math.min(annexFh * 0.30, roomW * 0.20)
        local drumX = roomR - roomW * 0.08
        drawWorkshopProp(roomDecorImgs.oilDrum, drumX, roomFloor, drumSize, 0.03)

        -- 附楼维修物件搜刮点：只在房间亮灯时激活。
        if isRoomLightOn("cs_annex") then
            checkChestProximity(ctx, playerSX, playerSY,
                roomR - roomW * 0.49 - benchSize * 0.5,
                roomFloor - benchSize + benchSize * 0.06,
                benchSize, benchSize, 38, 70)
            checkChestProximity(ctx, playerSX, playerSY,
                roomR - roomW * 0.18 - cabinetSize * 0.5,
                roomFloor - cabinetSize + cabinetSize * 0.04,
                cabinetSize, cabinetSize, 39, 70)
            checkChestProximity(ctx, playerSX, playerSY,
                roomR - roomW * 0.78 - rackSize * 0.5,
                roomFloor - rackSize + rackSize * 0.04,
                rackSize, rackSize, 40, 70)
        end
    end

    -- ── 墙面红色油漆 SOS（粗犷手刷感，油漆质感明显）──
    do
        local baseX = annexLeft + math.floor(annexW * 0.12)
        local baseY = ann1FTop + math.floor(annexFh * 0.20)
        local baseSz = math.floor(annexFh * 0.24)
        nvgSave(ctx)
        nvgFontFace(ctx, "sans")
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        -- 每个字母独立：位置、大小、旋转都略有不同
        local letters = {
            { c = "S", dx = 0,            dy = 0,    sz = baseSz * 1.0,  rot = -0.08 },
            { c = "O", dx = baseSz * 0.65, dy = 4,    sz = baseSz * 0.85, rot = 0.05  },
            { c = "S", dx = baseSz * 1.25, dy = -3,  sz = baseSz * 0.95, rot = 0.12  },
        }
        for _, l in ipairs(letters) do
            local lx = baseX + l.dx
            local ly = baseY + l.dy
            nvgSave(ctx)
            nvgTranslate(ctx, lx, ly)
            nvgRotate(ctx, l.rot)
            nvgFontSize(ctx, l.sz)
            -- 第1层：墙壁渗透晕染（油漆渗入墙面的扩散痕迹）
            nvgFillColor(ctx, nvgRGBA(80, 5, 0, 45))
            nvgText(ctx, 2, 3, l.c)
            nvgText(ctx, -1, 2, l.c)
            -- 第2层：厚油漆主体（偏移重叠模拟笔刷宽度）
            nvgFillColor(ctx, nvgRGBA(180, 20, 15, 255))
            nvgText(ctx, 0, 0, l.c)
            nvgText(ctx, 1, 0, l.c)   -- 右偏1px → 加粗
            nvgText(ctx, 0, 1, l.c)   -- 下偏1px → 加粗
            -- 第3层：高光（油漆未干的湿润反光）
            nvgFillColor(ctx, nvgRGBA(220, 50, 30, 100))
            nvgText(ctx, -1, -1, l.c)
            nvgRestore(ctx)
        end
        -- 上方滴痕（字母顶部笔画起笔处往下淌）
        nvgLineCap(ctx, NVG_ROUND)
        -- 上滴1：第一个S顶部
        nvgStrokeColor(ctx, nvgRGBA(175, 22, 14, 160))
        nvgStrokeWidth(ctx, 2.2)
        nvgBeginPath(ctx)
        local u1x = baseX + 5
        local u1y = baseY - math.floor(baseSz * 0.38)
        nvgMoveTo(ctx, u1x, u1y)
        nvgBezierTo(ctx, u1x - 1, u1y + math.floor(annexFh * 0.05),
                         u1x + 1, u1y + math.floor(annexFh * 0.10),
                         u1x + 0, u1y + math.floor(annexFh * 0.16))
        nvgStroke(ctx)
        -- 上滴2：O顶部偏右
        nvgStrokeColor(ctx, nvgRGBA(165, 18, 10, 140))
        nvgStrokeWidth(ctx, 1.8)
        nvgBeginPath(ctx)
        local u2x = baseX + math.floor(baseSz * 0.72)
        local u2y = baseY - math.floor(baseSz * 0.30)
        nvgMoveTo(ctx, u2x, u2y)
        nvgBezierTo(ctx, u2x + 1, u2y + math.floor(annexFh * 0.04),
                         u2x - 1, u2y + math.floor(annexFh * 0.08),
                         u2x + 0, u2y + math.floor(annexFh * 0.12))
        nvgStroke(ctx)
        -- 上滴3：最后S顶部
        nvgStrokeColor(ctx, nvgRGBA(155, 16, 8, 150))
        nvgStrokeWidth(ctx, 2.0)
        nvgBeginPath(ctx)
        local u3x = baseX + math.floor(baseSz * 1.30)
        local u3y = baseY - math.floor(baseSz * 0.35)
        nvgMoveTo(ctx, u3x, u3y)
        nvgBezierTo(ctx, u3x - 1, u3y + math.floor(annexFh * 0.06),
                         u3x + 2, u3y + math.floor(annexFh * 0.12),
                         u3x + 1, u3y + math.floor(annexFh * 0.19))
        nvgStroke(ctx)

        -- 下方滴痕（字母底部油漆往下淌）
        -- 滴痕1：从第一个S下方
        nvgStrokeColor(ctx, nvgRGBA(170, 20, 12, 180))
        nvgStrokeWidth(ctx, 2.5)
        nvgBeginPath(ctx)
        local d1x = baseX + 3
        local d1y = baseY + math.floor(baseSz * 0.38)
        nvgMoveTo(ctx, d1x, d1y)
        nvgBezierTo(ctx, d1x + 1, d1y + math.floor(annexFh * 0.08),
                         d1x - 1, d1y + math.floor(annexFh * 0.14),
                         d1x + 0, d1y + math.floor(annexFh * 0.22))
        nvgStroke(ctx)
        -- 滴痕2：从O底部，更短更细
        nvgStrokeColor(ctx, nvgRGBA(160, 18, 10, 140))
        nvgStrokeWidth(ctx, 2.0)
        nvgBeginPath(ctx)
        local d2x = baseX + math.floor(baseSz * 0.65) + 5
        local d2y = baseY + math.floor(baseSz * 0.32)
        nvgMoveTo(ctx, d2x, d2y)
        nvgBezierTo(ctx, d2x - 1, d2y + math.floor(annexFh * 0.06),
                         d2x + 1, d2y + math.floor(annexFh * 0.10),
                         d2x + 0, d2y + math.floor(annexFh * 0.14))
        nvgStroke(ctx)
        -- 滴痕3：从最后S，最长的一条
        nvgStrokeColor(ctx, nvgRGBA(150, 15, 8, 160))
        nvgStrokeWidth(ctx, 2.2)
        nvgBeginPath(ctx)
        local d3x = baseX + math.floor(baseSz * 1.25) - 2
        local d3y = baseY + math.floor(baseSz * 0.40)
        nvgMoveTo(ctx, d3x, d3y)
        nvgBezierTo(ctx, d3x + 2, d3y + math.floor(annexFh * 0.10),
                         d3x - 1, d3y + math.floor(annexFh * 0.18),
                         d3x + 1, d3y + math.floor(annexFh * 0.28))
        nvgStroke(ctx)
        -- 溅点（甩油漆时飞溅的小点）
        nvgBeginPath(ctx)
        nvgFillColor(ctx, nvgRGBA(170, 20, 12, 150))
        nvgCircle(ctx, baseX - 4, baseY - math.floor(baseSz * 0.25), 2)
        nvgCircle(ctx, baseX + math.floor(baseSz * 1.4), baseY + math.floor(baseSz * 0.15), 1.5)
        nvgCircle(ctx, baseX + math.floor(baseSz * 0.5), baseY + math.floor(baseSz * 0.42), 1.8)
        nvgFill(ctx)
        nvgRestore(ctx)
    end

    -- ── 附属房间天花灯：收集 overlay 信息 ──
    do
        local annexRoomW = annexW + wallT
        local annexMidX = annexLeft + math.floor(annexRoomW * 0.5)
        local lightKey = "cs_annex"
        local brightness = getRoomBrightness(lightKey)
        -- 附属维修间的入口位于右侧连接门，开关放在门内侧左边。
        local switchSX = sx - 28
        local switchSY = ann1FTop + annexFh - math.floor(annexFh * 0.42)
        registerLightSwitch(ctx, lightKey, switchSX, switchSY, switchSX + cameraX, csWldX - annexW, csWldX + wallT, ann1FTop, annexFh, 76, 82)
        csInfo.floorOverlays[#csInfo.floorOverlays + 1] = {
            x = annexLeft, y = ann1FTop, w = annexRoomW, h = annexFh,
            wx = csWldX - annexW, ww = annexRoomW, -- 世界坐标 X
            rooms = { { x = annexLeft, midX = annexMidX, brightness = brightness, rw = annexRoomW } },
        }
    end

    -- 附属屋顶板（全角圆化）
    nvgFillColor(ctx, col)
    rr(annexLeft, ann1FTop - annexSlabT, annexW, annexSlabT)
    -- 附属屋顶板右端与主楼左墙 T接补块
    patch(annexLeft + annexW - cr, ann1FTop - annexSlabT, cr, cr)
    patch(annexLeft + annexW - cr, ann1FTop - cr, cr, cr)

    -- 附属左外墙（全角圆化）—— 加厚一倍
    local railH  = math.floor(annexFh * 0.22)
    local doorH  = math.floor(annexFh * 0.58)
    rr(annexLeft, ann1FTop - annexSlabT - railH, wallT * 2, railH + annexSlabT + annexFh - doorH)
    -- 附属屋顶板与左墙 T接补块
    patch(annexLeft + wallT * 2 - cr, ann1FTop - annexSlabT, cr, cr)
    patch(annexLeft + wallT * 2 - cr, ann1FTop - cr, cr, cr)

    -- 附属右侧隔墙（全角圆化；底部接门洞，是外露角）—— 加厚一倍
    rr(sx, ann1FTop, wallT * 2, annexFh - doorH)
    -- 附属隔墙与附属屋顶板 T接补块（顶端）
    patch(sx, ann1FTop, cr, cr)
    patch(sx + wallT * 2 - cr, ann1FTop, cr, cr)

    -- ── 阳台盆栽（紧挨着放在阳台最左侧）──
    do
        local balconyY = ann1FTop - annexSlabT  -- 阳台地面 = 屋顶板顶部
        local potSize = math.floor(railH * 1.2) -- 盆栽大小
        local pots = { potImg1, potImg2, potImg3 }
        local startX = annexLeft + wallT * 2 + 2    -- 紧贴左墙（加厚后）
        for i, img in ipairs(pots) do
            if img and img ~= 0 then
                local px = startX + (i - 1) * math.floor(potSize * 0.7)  -- 紧密排列，略有重叠
                local py = balconyY - potSize
                local paint = nvgImagePattern(ctx, px, py, potSize, potSize, 0, img, 1.0)
                nvgBeginPath(ctx)
                nvgRect(ctx, px, py, potSize, potSize)
                nvgFillPaint(ctx, paint)
                nvgFill(ctx)
            end
        end
    end

    -- ── 阳台太阳伞和椅子 ──
    do
        local balconyY = ann1FTop - annexSlabT  -- 阳台地面
        local balconyLeft = annexLeft + wallT * 2
        local balconyRight = annexLeft + annexW
        local balconyMidX = math.floor((balconyLeft + balconyRight) * 0.5)

        -- 太阳伞（较大，放在阳台中偏右）
        local umbSize = math.floor(railH * 2.2)
        if umbrellaImg and umbrellaImg ~= 0 then
            local ux = balconyMidX + math.floor(umbSize * 0.1)
            local uy = balconyY - umbSize
            local paint = nvgImagePattern(ctx, ux, uy, umbSize, umbSize, 0, umbrellaImg, 1.0)
            nvgBeginPath(ctx)
            nvgRect(ctx, ux, uy, umbSize, umbSize)
            nvgFillPaint(ctx, paint)
            nvgFill(ctx)
        end

        -- 椅子（放在太阳伞下方偏左）
        local chairSize = math.floor(railH * 1.4)
        if chairImg and chairImg ~= 0 then
            local cx = balconyMidX - math.floor(chairSize * 0.3)
            local cy = balconyY - chairSize
            local paint = nvgImagePattern(ctx, cx, cy, chairSize, chairSize, 0, chairImg, 1.0)
            nvgBeginPath(ctx)
            nvgRect(ctx, cx, cy, chairSize, chairSize)
            nvgFillPaint(ctx, paint)
            nvgFill(ctx)
        end
    end

    -- ── 阳台围栏（底部水泥矮墙 + 上方铁艺栏杆）──
    do
        local railTop = ann1FTop - annexSlabT - railH  -- 围栏顶部
        local railBot = ann1FTop - annexSlabT          -- 阳台地面
        local railLeft = annexLeft + wallT * 2         -- 左墙内侧（加厚后）
        local railRight = annexLeft + annexW           -- 右侧到主楼墙
        local railW = railRight - railLeft
        local wallH = math.floor(railH * 0.45)        -- 矮墙占栏杆区约45%
        local fenceH = railH - wallH                  -- 铁栏杆区域

        -- 底部水泥矮墙（浅灰色，有厚度感）
        local wallTop = railBot - wallH
        nvgBeginPath(ctx)
        nvgRect(ctx, railLeft, wallTop, railW, wallH)
        nvgFillColor(ctx, nvgRGBA(160, 158, 152, 240))
        nvgFill(ctx)
        -- 矮墙顶面（浅色高光模拟厚度）
        nvgBeginPath(ctx)
        nvgRect(ctx, railLeft, wallTop, railW, 2)
        nvgFillColor(ctx, nvgRGBA(190, 188, 182, 200))
        nvgFill(ctx)
        -- 矮墙底部阴影线
        nvgBeginPath(ctx)
        nvgRect(ctx, railLeft, railBot - 1, railW, 1)
        nvgFillColor(ctx, nvgRGBA(100, 98, 92, 150))
        nvgFill(ctx)

        -- 上方铁艺栏杆
        local fenceTop = railTop
        local fenceBot = wallTop

        -- 顶部扶手（粗方管，深灰偏黑）
        local handRailH = 4
        nvgBeginPath(ctx)
        nvgRect(ctx, railLeft - 1, fenceTop, railW + 2, handRailH)
        nvgFillColor(ctx, nvgRGBA(40, 42, 45, 250))
        nvgFill(ctx)
        -- 扶手顶面高光
        nvgBeginPath(ctx)
        nvgRect(ctx, railLeft - 1, fenceTop, railW + 2, 1)
        nvgFillColor(ctx, nvgRGBA(100, 105, 110, 140))
        nvgFill(ctx)

        -- 左右角柱（粗竖管）
        local postW = 4
        nvgBeginPath(ctx)
        nvgRect(ctx, railLeft, fenceTop, postW, fenceH)
        nvgFillColor(ctx, nvgRGBA(45, 47, 50, 250))
        nvgFill(ctx)
        nvgBeginPath(ctx)
        nvgRect(ctx, railRight - postW, fenceTop, postW, fenceH)
        nvgFillColor(ctx, nvgRGBA(45, 47, 50, 250))
        nvgFill(ctx)

        -- 竖直栏杆条（较粗，间距均匀）
        local barW = 2.5
        local numBars = 6
        local innerW = railW - postW * 2
        local spacing = innerW / (numBars + 1)
        for i = 1, numBars do
            local bx = railLeft + postW + math.floor(spacing * i) - math.floor(barW * 0.5)
            nvgBeginPath(ctx)
            nvgRect(ctx, bx, fenceTop + handRailH, barW, fenceH - handRailH)
            nvgFillColor(ctx, nvgRGBA(50, 52, 56, 240))
            nvgFill(ctx)
            -- 栏杆条高光
            nvgBeginPath(ctx)
            nvgRect(ctx, bx, fenceTop + handRailH, 1, fenceH - handRailH)
            nvgFillColor(ctx, nvgRGBA(90, 95, 100, 80))
            nvgFill(ctx)
        end
    end

    -- ── 空调外机（挂在主楼左侧外墙，正面朝左，看到的是厚度侧面）──
    do
        local acThick = math.floor(wallT * 1.1)    -- 外机厚度（侧面宽度，约等于墙厚）
        local acH     = math.floor(baseFloorH * 0.42) -- 外机高度（接近半层高）
        local acX     = sx - acThick - 2           -- 紧贴左墙外侧
        -- 在 2F~4F（fi=2~4）每层外墙中间偏下放一台
        for fi = 2, 4 do
            local floorTop = sy + roofSlabT + fTops[fi]
            local fh = fHeights[fi]
            local acY = floorTop + math.floor(fh * 0.65)

            -- 支架横梁（先画，在外机下方）
            local bracketH = 4
            local bracketExt = 6  -- 支架比外机宽出一点
            nvgBeginPath(ctx)
            nvgRect(ctx, acX - bracketExt, acY + acH, acThick + bracketExt * 2, bracketH)
            nvgFillColor(ctx, nvgRGBA(70, 72, 75, 255))
            nvgFill(ctx)
            -- 支架斜撑（两根三角形从墙面到横梁两端）
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, sx, acY + acH + bracketH)
            nvgLineTo(ctx, sx, acY + acH + bracketH + 12)
            nvgLineTo(ctx, acX - bracketExt, acY + acH + bracketH)
            nvgClosePath(ctx)
            nvgFillColor(ctx, nvgRGBA(60, 62, 65, 220))
            nvgFill(ctx)

            -- 外机主体（浅灰白色外壳）
            nvgBeginPath(ctx)
            nvgRoundedRect(ctx, acX, acY, acThick, acH, 3)
            nvgFillColor(ctx, nvgRGBA(180, 185, 190, 240))
            nvgFill(ctx)
            -- 外壳描边
            nvgBeginPath(ctx)
            nvgRoundedRect(ctx, acX, acY, acThick, acH, 3)
            nvgStrokeColor(ctx, nvgRGBA(80, 85, 90, 200))
            nvgStrokeWidth(ctx, 1.5)
            nvgStroke(ctx)

            -- 侧面散热百叶（密集水平线条）
            local slotTop = acY + math.floor(acH * 0.15)
            local slotBot = acY + math.floor(acH * 0.85)
            local slotCount = 8
            local slotGap = (slotBot - slotTop) / slotCount
            for g = 0, slotCount - 1 do
                local gy = slotTop + math.floor(slotGap * g)
                nvgBeginPath(ctx)
                nvgRect(ctx, acX + 3, gy, acThick - 6, 2)
                nvgFillColor(ctx, nvgRGBA(100, 105, 110, 180))
                nvgFill(ctx)
            end

            -- 顶部出风口暗缝
            nvgBeginPath(ctx)
            nvgRect(ctx, acX + 3, acY + 3, acThick - 6, 3)
            nvgFillColor(ctx, nvgRGBA(40, 42, 45, 200))
            nvgFill(ctx)

            -- 铜管（从外机右侧伸向墙面）
            local pipeY1 = acY + math.floor(acH * 0.3)
            local pipeY2 = acY + math.floor(acH * 0.45)
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, acX + acThick, pipeY1)
            nvgLineTo(ctx, sx, pipeY1)
            nvgStrokeColor(ctx, nvgRGBA(180, 130, 70, 200))
            nvgStrokeWidth(ctx, 3)
            nvgStroke(ctx)
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, acX + acThick, pipeY2)
            nvgLineTo(ctx, sx, pipeY2)
            nvgStrokeColor(ctx, nvgRGBA(160, 115, 60, 180))
            nvgStrokeWidth(ctx, 2.5)
            nvgStroke(ctx)
        end
    end

    -- ── 附楼左外墙入口钢门（街道进入建筑）──
    if steelDoorImg and steelDoorImg > 0 then
        local annexDoorH = math.floor(fHeights[CS_NUM_FLOORS] * 0.58)
        local annexFhLocal = fHeights[CS_NUM_FLOORS]
        local annexSlabTLocal = 52
        local annexWLocal = math.floor(upW * 0.38)
        local annexLeftLocal = sx - annexWLocal
        local ann1FTopLocal = groundY - annexFhLocal
        local sDoorDrawH = annexDoorH * 1.2
        local sState = roomDoorStates["annex"]
        local sOpenProg = sState and sState.openProg or 0
        local sDoorImg = steelDoorImg
        local sDoorDrawW = sDoorDrawH * (71 / 128)
        if sOpenProg > 0.5 and basDoorImg and basDoorImg > 0 then
            sDoorImg = basDoorImg
            sDoorDrawW = sDoorDrawH * (334 / 532)
        end
        local sDoorX = annexLeftLocal + wallT - sDoorDrawW * 0.5 - 6
        local sDoorGapTop = ann1FTopLocal + annexFhLocal - annexDoorH
        local sDoorY = sDoorGapTop - (sDoorDrawH - annexDoorH) * 0.5
        local sPaint = nvgImagePattern(ctx, sDoorX, sDoorY, sDoorDrawW, sDoorDrawH, 0, sDoorImg, 1.0)
        nvgBeginPath(ctx)
        nvgRect(ctx, sDoorX, sDoorY, sDoorDrawW, sDoorDrawH)
        nvgFillPaint(ctx, sPaint)
        nvgFill(ctx)
        -- 图标
        local sIconR = math.min(sDoorDrawW, annexDoorH) * 0.32
        local sIconCX = annexLeftLocal + wallT - 6
        local sIconCY = sDoorGapTop + annexDoorH * 0.5
        local sDoorWX = annexLeftLocal + cameraX
        local sNearX = math.abs(player.x - sDoorWX)
        local sPlrY = H * GROUND_Y_RATIO + player.jumpScrY
        local sNearY = math.abs(sPlrY - sIconCY)
        local sIsNear = (sNearX < 60 and sNearY < annexDoorH * 0.7)
        local sAlpha = sIsNear and 255 or 140
        local sSW = sIsNear and 4.5 or 3.0
        nvgBeginPath(ctx)
        nvgCircle(ctx, sIconCX, sIconCY, sIconR)
        nvgStrokeColor(ctx, nvgRGBA(255, 255, 255, sAlpha))
        nvgStrokeWidth(ctx, sSW)
        nvgStroke(ctx)
        if sIsNear then
            nvgBeginPath(ctx)
            nvgCircle(ctx, sIconCX, sIconCY, sIconR + 3)
            nvgStrokeColor(ctx, nvgRGBA(255, 255, 255, 60))
            nvgStrokeWidth(ctx, 4)
            nvgStroke(ctx)
        end
        local sDIconW = sIconR * 0.7
        local sDIconH = sIconR * 1.1
        local sDIconX = sIconCX - sDIconW * 0.5
        local sDIconY = sIconCY - sDIconH * 0.5
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, sDIconX, sDIconY, sDIconW, sDIconH, 2)
        nvgStrokeColor(ctx, nvgRGBA(255, 255, 255, sAlpha))
        nvgStrokeWidth(ctx, 2.5)
        nvgStroke(ctx)
        nvgBeginPath(ctx)
        nvgCircle(ctx, sDIconX + sDIconW * 0.78, sIconCY, 2.5)
        nvgFillColor(ctx, nvgRGBA(255, 255, 255, sAlpha))
        nvgFill(ctx)
    end

    -- 完整楼板和外墙切面已经绘制；地砖顶面已在家具之前绘制，不能在这里重复覆盖物品。

    -- ── 1F左入口门（最后绘制，确保不被覆盖）──
    if (roomDoorImg and roomDoorImg > 0) or (roomDoorSideImg and roomDoorSideImg > 0) then
        local ent1FDoorH = ann1FDoorH * 1.2
        local entState = roomDoorStates["1f_left"]
        local entOpenProg = entState and entState.openProg or 0
        local entImg = roomDoorSideImg
        local ent1FDoorW = ent1FDoorH * (71 / 128)
        if entOpenProg > 0.5 and roomDoorImg and roomDoorImg > 0 then
            entImg = roomDoorImg
            ent1FDoorW = ent1FDoorH * (WOOD_DOOR_FRONT_RATIO)
        elseif not entImg or entImg <= 0 then
            entImg = roomDoorImg
            ent1FDoorW = ent1FDoorH * (WOOD_DOOR_FRONT_RATIO)
        end
        local ent1FDoorX = sx + wallT - ent1FDoorW * 0.5 + 4
        local ent1FGapTop = sy + upTotalH - ann1FDoorH
        local ent1FDoorY = ent1FGapTop - (ent1FDoorH - ann1FDoorH) * 0.5
        local ePaint = nvgImagePattern(ctx, ent1FDoorX, ent1FDoorY, ent1FDoorW, ent1FDoorH, 0, entImg, 1.0)
        nvgBeginPath(ctx)
        nvgRect(ctx, ent1FDoorX, ent1FDoorY, ent1FDoorW, ent1FDoorH)
        nvgFillPaint(ctx, ePaint)
        nvgFill(ctx)
        -- 图标
        local eIconR = math.min(ent1FDoorW, ann1FDoorH) * 0.32
        local eIconCX = sx + wallT + 4
        local eIconCY = ent1FGapTop + ann1FDoorH * 0.5
        local eDoorWX = sx + cameraX
        local eNearX = math.abs(player.x - eDoorWX)
        local ePlrY = H * GROUND_Y_RATIO + player.jumpScrY
        local eNearY = math.abs(ePlrY - eIconCY)
        local eIsNear = (eNearX < 60 and eNearY < ann1FDoorH * 0.7)
        local eAlpha = eIsNear and 255 or 140
        local eSW = eIsNear and 4.5 or 3.0
        nvgBeginPath(ctx)
        nvgCircle(ctx, eIconCX, eIconCY, eIconR)
        nvgStrokeColor(ctx, nvgRGBA(255, 255, 255, eAlpha))
        nvgStrokeWidth(ctx, eSW)
        nvgStroke(ctx)
        if eIsNear then
            nvgBeginPath(ctx)
            nvgCircle(ctx, eIconCX, eIconCY, eIconR + 3)
            nvgStrokeColor(ctx, nvgRGBA(255, 255, 255, 60))
            nvgStrokeWidth(ctx, 4)
            nvgStroke(ctx)
        end
        local eDW = eIconR * 0.7
        local eDH = eIconR * 1.1
        local eDX = eIconCX - eDW * 0.5
        local eDY = eIconCY - eDH * 0.5
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, eDX, eDY, eDW, eDH, 2)
        nvgStrokeColor(ctx, nvgRGBA(255, 255, 255, eAlpha))
        nvgStrokeWidth(ctx, 2.5)
        nvgStroke(ctx)
        nvgBeginPath(ctx)
        nvgCircle(ctx, eDX + eDW * 0.78, eIconCY, 2.5)
        nvgFillColor(ctx, nvgRGBA(255, 255, 255, eAlpha))
        nvgFill(ctx)

        -- 1F右侧出口门：和碰撞门洞 1f_right 对齐，避免玩家到最后房间后无法从右侧离开。
        local rightDoorH = ann1FDoorH * 1.2
        local rightState = roomDoorStates["1f_right"]
        local rightOpenProg = rightState and rightState.openProg or 0
        local rightImg = roomDoorSideImg
        local rightDoorW = rightDoorH * (71 / 128)
        if rightOpenProg > 0.5 and roomDoorImg and roomDoorImg > 0 then
            rightImg = roomDoorImg
            rightDoorW = rightDoorH * (WOOD_DOOR_FRONT_RATIO)
        elseif not rightImg or rightImg <= 0 then
            rightImg = roomDoorImg
            rightDoorW = rightDoorH * (WOOD_DOOR_FRONT_RATIO)
        end
        local rightGapTop = sy + upTotalH - ann1FDoorH
        local rightDoorCX = sx + upW - wallT * 0.5 - 4
        local rightDoorX = rightDoorCX - rightDoorW * 0.5
        local rightDoorY = rightGapTop - (rightDoorH - ann1FDoorH) * 0.5
        local rPaint = nvgImagePattern(ctx, rightDoorX, rightDoorY, rightDoorW, rightDoorH, 0, rightImg, 1.0)
        nvgBeginPath(ctx)
        nvgRect(ctx, rightDoorX, rightDoorY, rightDoorW, rightDoorH)
        nvgFillPaint(ctx, rPaint)
        nvgFill(ctx)

        local rIconR = math.min(rightDoorW, ann1FDoorH) * 0.32
        local rIconCX = rightDoorCX
        local rIconCY = rightGapTop + ann1FDoorH * 0.5
        local rDoorWX = rightDoorCX + cameraX
        local rNearX = math.abs(player.x - rDoorWX)
        local rPlrY = H * GROUND_Y_RATIO + player.jumpScrY
        local rNearY = math.abs(rPlrY - rIconCY)
        local rIsNear = (rNearX < 60 and rNearY < ann1FDoorH * 0.7)
        local rAlpha = rIsNear and 255 or 140
        local rSW = rIsNear and 4.5 or 3.0
        nvgBeginPath(ctx)
        nvgCircle(ctx, rIconCX, rIconCY, rIconR)
        nvgStrokeColor(ctx, nvgRGBA(255, 255, 255, rAlpha))
        nvgStrokeWidth(ctx, rSW)
        nvgStroke(ctx)
        if rIsNear then
            nvgBeginPath(ctx)
            nvgCircle(ctx, rIconCX, rIconCY, rIconR + 3)
            nvgStrokeColor(ctx, nvgRGBA(255, 255, 255, 60))
            nvgStrokeWidth(ctx, 4)
            nvgStroke(ctx)
        end
        local rDW = rIconR * 0.7
        local rDH = rIconR * 1.1
        local rDX = rIconCX - rDW * 0.5
        local rDY = rIconCY - rDH * 0.5
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, rDX, rDY, rDW, rDH, 2)
        nvgStrokeColor(ctx, nvgRGBA(255, 255, 255, rAlpha))
        nvgStrokeWidth(ctx, 2.5)
        nvgStroke(ctx)
        nvgBeginPath(ctx)
        nvgCircle(ctx, rDX + rDW * 0.78, rIconCY, 2.5)
        nvgFillColor(ctx, nvgRGBA(255, 255, 255, rAlpha))
        nvgFill(ctx)
    end

end

local function initCrossSection()
    -- 每次初始化都重建碰撞数据，避免热重载后重复叠加墙体、楼板和梯区。
    csColliders.slabs = {}
    csColliders.walls = {}
    csColliders.ladders = {}

    -- 计算剖面楼碰撞体（与 drawCrossSection 使用完全相同的常量）
    local REF_H      = 768
    local baseFloorH = math.floor(REF_H * 0.235)
    local roofSlabT  = 72
    local wT         = 38   -- 与 drawCrossSection 中 wallT 保持一致

    local fH = {}   -- fHeights
    local fT = {}   -- fTops
    local yOff = 0
    for fi = 1, CS_NUM_FLOORS do
        local fd = CS_FLOOR_DATA[fi]
        fT[fi] = yOff
        fH[fi] = math.max(70, math.floor(baseFloorH * fd.hRatio))
        yOff   = yOff + fH[fi]
        if fi < CS_NUM_FLOORS then yOff = yOff + fd.slabBelow end
    end
    local upTotalH = roofSlabT + yOff
    local upW      = math.floor(upTotalH * 1.55)  -- 与 drawCrossSection 保持一致
    local innerW   = upW - 2 * wT

    local bx1 = csWldX
    local bx2 = csWldX + upW
    local ann1FDoorH = math.floor(fH[CS_NUM_FLOORS] * 0.58)

    -- ── 水平楼板 ────────────────────────────────────────────
    -- 各层间楼板（fi 层底部 / fi+1 层顶部）
    for fi = 1, CS_NUM_FLOORS - 1 do
        local topRelY = fT[fi] + fH[fi] - yOff
        csColliders.slabs[#csColliders.slabs + 1] = {
            wx1 = bx1, wx2 = bx2,
            relY  = topRelY,
            thick = CS_FLOOR_DATA[fi].slabBelow,
        }
    end

    -- ── 左右外墙（实心，窗洞太小玩家无法通行）───────────────
    -- 左外墙：全高，底部入口受 1f_left 门状态控制
    csColliders.walls[#csColliders.walls + 1] = {
        wx1 = bx1, wx2 = bx1 + wT,
        relY1 = -yOff, relY2 = 0,
        gaps = { { y1 = -ann1FDoorH, y2 = 0, doorKey = "1f_left" } }
    }
    -- 右外墙：1F右侧房间出口受 1f_right 门状态控制
    csColliders.walls[#csColliders.walls + 1] = {
        wx1 = bx2 - wT, wx2 = bx2,
        relY1 = -yOff, relY2 = 0,
        gaps = { { y1 = -ann1FDoorH, y2 = 0, doorKey = "1f_right" } }
    }

    -- ── 屋顶楼板（阻止玩家从顶层跳出）──────────────────────
    csColliders.slabs[#csColliders.slabs + 1] = {
        wx1 = bx1, wx2 = bx2,
        relY  = -yOff - roofSlabT,
        thick = roofSlabT,
    }

    -- ── 竖向墙体（仅隔墙，不含外墙）───────────────────────
    -- 各层隔墙：覆盖全高，底部门洞作为 gap（受门状态控制）
    for fi = 1, CS_NUM_FLOORS do
        local fd     = CS_FLOOR_DATA[fi]
        local ry1    = fT[fi] - yOff           -- 房间顶部
        local ry2    = ry1 + fH[fi]            -- 房间底部（地板）
        local doorH  = math.floor(fH[fi] * 0.58)
        local solidBot = ry2 - doorH           -- 门洞顶边
        for _divIdx, d in ipairs(fd.divs) do
            local wCenter = bx1 + wT + math.floor(innerW * d)
            local halfT   = math.floor(fd.divT / 2)
            local doorKey = fi .. "_" .. _divIdx
            csColliders.walls[#csColliders.walls + 1] = {
                wx1 = wCenter - halfT, wx2 = wCenter - halfT + fd.divT,
                relY1 = ry1, relY2 = ry2,   -- 覆盖全高
                gaps = { { y1 = solidBot, y2 = ry2, doorKey = doorKey } }
            }
        end
    end

    -- ── 左侧附属房间（annex）碰撞体 ────────────────────────
    local annexW     = math.floor(upW * 0.38)
    local annexSlabT = 52
    local annexLeft  = bx1 - annexW
    local annRelY    = fT[CS_NUM_FLOORS] - yOff   -- annex顶部（与1F顶齐）
    local annexFh    = fH[CS_NUM_FLOORS]
    local annexDoorH = math.floor(annexFh * 0.58)

    -- 附属屋顶板（阻止从上方穿入）
    csColliders.slabs[#csColliders.slabs + 1] = {
        wx1  = annexLeft,
        wx2  = bx1,
        relY  = annRelY - annexSlabT,
        thick = annexSlabT,
    }
    -- 附属左外墙（全高，底部门洞受 annex 门状态控制）
    csColliders.walls[#csColliders.walls + 1] = {
        wx1   = annexLeft,
        wx2   = annexLeft + wT,
        relY1 = annRelY,
        relY2 = annRelY + annexFh,
        gaps  = { { y1 = annRelY + annexFh - annexDoorH, y2 = annRelY + annexFh, doorKey = "annex" } }
    }

    -- ── 地下室碰撞体 ────────────────────────────────────────
    local gndSlabT  = CS_FLOOR_DATA[CS_NUM_FLOORS].slabBelow
    local basHC     = math.floor(baseFloorH * basementHeightScale)
    local basSlabTC = 52
    local basExtC   = math.floor(upW * 0.08)
    local basXW     = bx1 - basExtC          -- 地下室世界X左起点
    local basWC     = upW + basExtC * 2      -- 地下室总宽
    local basRoomH  = basHC + basSlabTC - wT
    local basRelTop = gndSlabT               -- relY=0是地面，正值向下
    local basRelFloor = gndSlabT + basRoomH  -- 地下室地板顶面

    -- 梯子开口世界X坐标（与绘制代码保持一致）
    local innerW1F = upW - 2 * wT
    local ladRelX  = math.floor(innerW1F * 0.80)
    local ladW     = math.floor(innerW1F * 0.09)
    local ladWX1   = bx1 + wT + ladRelX
    local ladWX2   = ladWX1 + ladW
    -- 登记第一栋楼梯区；通用爬梯系统会选择玩家当前所在的梯子。
    csColliders.ladders = csColliders.ladders or {}
    csColliders.ladders[#csColliders.ladders + 1] = {
        name = "main",
        wx1 = ladWX1,
        wx2 = ladWX2,
        floorY = basRelFloor,
    }

    -- 地下室地板（防止玩家穿底）
    csColliders.slabs[#csColliders.slabs + 1] = {
        wx1   = basXW,
        wx2   = basXW + basWC,
        relY  = basRelFloor,
        thick = basSlabTC,
    }
    -- 地下室天花板：分两段，梯口留空（防止玩家从非梯口位置跳出）
    csColliders.slabs[#csColliders.slabs + 1] = {   -- 左段
        wx1   = basXW,
        wx2   = ladWX1,
        relY  = 0,
        thick = gndSlabT,
    }
    csColliders.slabs[#csColliders.slabs + 1] = {   -- 右段
        wx1   = ladWX2,
        wx2   = basXW + basWC,
        relY  = 0,
        thick = gndSlabT,
    }
    -- 地下室左外墙
    csColliders.walls[#csColliders.walls + 1] = {
        wx1   = basXW,
        wx2   = basXW + wT,
        relY1 = basRelTop,
        relY2 = basRelFloor,
        gaps  = {}
    }
    -- 地下室右外墙
    csColliders.walls[#csColliders.walls + 1] = {
        wx1   = basXW + basWC - wT,
        wx2   = basXW + basWC,
        relY1 = basRelTop,
        relY2 = basRelFloor,
        gaps  = {}
    }
    -- 地下室内隔墙（两道，与绘制中的 divs 对应；门洞受门状态控制）
    local innerBasW  = basWC - 2 * wT
    local basDivW    = 90  -- 与绘制中 basDiv 保持一致
    local basDoorH   = math.floor(basHC * 0.58)
    local divSolidH  = basHC - basDoorH  -- 实心顶部高度
    for _divIdx, d in ipairs(CS_BASEMENT_DATA.divs) do
        local divX = basXW + wT + math.floor(innerBasW * d)
        local halfT = math.floor(basDivW / 2)
        local doorKey = "bas_" .. _divIdx
        csColliders.walls[#csColliders.walls + 1] = {
            wx1   = divX - halfT,
            wx2   = divX + halfT,
            relY1 = basRelTop,
            relY2 = basRelFloor,  -- 覆盖全高
            gaps  = { { y1 = basRelTop + divSolidH, y2 = basRelFloor, doorKey = doorKey } }
        }
    end

    -- ── 第二栋居民服务楼碰撞体：与第一栋楼使用同一套门洞/阻挡协议 ──
    do
        local refH2 = 768
        local baseFloorH2 = math.floor(refH2 * 0.218)
        local roofSlabT2 = 62
        local wallT2 = 34
        local floorHeights2 = {}
        local floorTops2 = {}
        local yOff2 = 0
        for fi = 1, #CS2_FLOOR_DATA do
            local fd2 = CS2_FLOOR_DATA[fi]
            floorTops2[fi] = yOff2
            floorHeights2[fi] = math.max(68, math.floor(baseFloorH2 * fd2.hRatio))
            yOff2 = yOff2 + floorHeights2[fi]
            if fi < #CS2_FLOOR_DATA then yOff2 = yOff2 + fd2.slabBelow end
        end

        local upW2 = math.floor((roofSlabT2 + yOff2) * 1.46)
        local innerW2 = upW2 - 2 * wallT2
        local bx12 = CS2_WLD_X
        local bx22 = bx12 + upW2
        local firstFloor2 = #CS2_FLOOR_DATA
        local leftLadderCenterX2 = bx12 - 54
        local rightLadderCenterX2 = bx22 + 54
        local gndSlabT2 = CS2_FLOOR_DATA[firstFloor2].slabBelow

        -- 层间楼板和屋顶：让第二栋楼上下层碰撞与第一栋楼一致。
        for fi = 1, firstFloor2 - 1 do
            csColliders.slabs[#csColliders.slabs + 1] = {
                wx1 = bx12,
                wx2 = bx22,
                relY = floorTops2[fi] + floorHeights2[fi] - yOff2,
                thick = CS2_FLOOR_DATA[fi].slabBelow,
            }
        end
        csColliders.slabs[#csColliders.slabs + 1] = {
            wx1 = bx12,
            wx2 = bx22,
            relY = -yOff2 - roofSlabT2,
            thick = roofSlabT2,
        }

        -- 左右外墙每层都有外梯门洞；对应门打开后才能从平台进入房间。
        local leftExteriorDoorGaps2 = {}
        local rightExteriorDoorGaps2 = {}
        for fi = 1, firstFloor2 do
            local roomTop2 = floorTops2[fi] - yOff2
            local roomBottom2 = roomTop2 + floorHeights2[fi]
            local stairDoorH2 = math.floor(floorHeights2[fi] * 0.58)
            leftExteriorDoorGaps2[#leftExteriorDoorGaps2 + 1] = {
                y1 = roomBottom2 - stairDoorH2,
                y2 = roomBottom2,
                doorKey = "cs2_left_stair_" .. fi,
            }
            rightExteriorDoorGaps2[#rightExteriorDoorGaps2 + 1] = {
                y1 = roomBottom2 - stairDoorH2,
                y2 = roomBottom2,
                doorKey = "cs2_stair_" .. fi,
            }
            -- 左外侧平台：覆盖大号左梯并连接建筑左墙。
            csColliders.slabs[#csColliders.slabs + 1] = {
                wx1 = bx12 - 86,
                wx2 = bx12 + wallT2,
                relY = roomBottom2,
                thick = 8,
            }
            -- 右外侧平台：覆盖大号右梯并连接右墙。
            csColliders.slabs[#csColliders.slabs + 1] = {
                wx1 = bx22 - wallT2,
                wx2 = bx22 + 86,
                relY = roomBottom2,
                thick = 8,
            }
        end
        csColliders.walls[#csColliders.walls + 1] = {
            wx1 = bx12,
            wx2 = bx12 + wallT2,
            relY1 = -yOff2,
            relY2 = 0,
            gaps = leftExteriorDoorGaps2,
        }
        csColliders.walls[#csColliders.walls + 1] = {
            wx1 = bx22 - wallT2,
            wx2 = bx22,
            relY1 = -yOff2,
            relY2 = 0,
            gaps = rightExteriorDoorGaps2,
        }

        -- 各层隔墙门：关闭阻挡、打开通行，状态与第二栋楼门贴图一一对应。
        for fi = 1, firstFloor2 do
            local fd2 = CS2_FLOOR_DATA[fi]
            local roomTop2 = floorTops2[fi] - yOff2
            local roomBottom2 = roomTop2 + floorHeights2[fi]
            local doorH2 = math.floor(floorHeights2[fi] * 0.56)
            for divIdx, d in ipairs(fd2.divs) do
                local wallCenter2 = bx12 + wallT2 + math.floor(innerW2 * d)
                local halfWall2 = math.floor(fd2.divT * 0.5)
                csColliders.walls[#csColliders.walls + 1] = {
                    wx1 = wallCenter2 - halfWall2,
                    wx2 = wallCenter2 + halfWall2,
                    relY1 = roomTop2,
                    relY2 = roomBottom2,
                    gaps = { {
                        y1 = roomBottom2 - doorH2,
                        y2 = roomBottom2,
                        doorKey = "cs2_" .. fi .. "_" .. divIdx,
                    } },
                }
            end
        end

        -- 现有地下室梯子使用的双向顶部/底部端点。
        -- 外梯只负责楼层间移动，不再把整栋楼误当成一根地下室梯子。
        local floorLadderHalfW2 = 25
        for fi = 1, firstFloor2 - 1 do
            local topY2 = floorTops2[fi] - yOff2 + floorHeights2[fi]
            local bottomY2 = floorTops2[fi + 1] - yOff2 + floorHeights2[fi + 1]
            csColliders.ladders[#csColliders.ladders + 1] = {
                name = "service_left_" .. fi,
                wx1 = leftLadderCenterX2 - floorLadderHalfW2,
                wx2 = leftLadderCenterX2 + floorLadderHalfW2,
                topY = topY2,
                bottomY = bottomY2,
                side = "left",
                topFi = fi,
                bottomFi = fi + 1,
            }
            csColliders.ladders[#csColliders.ladders + 1] = {
                name = "service_right_" .. fi,
                wx1 = rightLadderCenterX2 - floorLadderHalfW2,
                wx2 = rightLadderCenterX2 + floorLadderHalfW2,
                topY = topY2,
                bottomY = bottomY2,
                side = "right",
                topFi = fi,
                bottomFi = fi + 1,
            }
        end

        -- 第二栋楼地下室梯口继续使用原有梯子贴图和地下室爬梯动画。
        local basH2 = math.floor(baseFloorH2 * 1.42)
        local basSlabT2 = 44
        local basX2 = bx12 - math.floor(upW2 * 0.06)
        local basW2 = upW2 + math.floor(upW2 * 0.12)
        local basInnerW2 = basW2 - 2 * wallT2
        local basTop2 = gndSlabT2
        local basFloor2 = basTop2 + basH2
        -- 梯口放在最右房间左侧，右外墙入口与右侧空间保持完整可行走。
        local ladderRelX2 = math.floor(innerW2 * 0.735)
        local ladderW2 = math.floor(innerW2 * 0.075)
        local ladderWX12 = bx12 + wallT2 + ladderRelX2
        local ladderWX22 = ladderWX12 + ladderW2

        csColliders.ladders[#csColliders.ladders + 1] = {
            name = "service_basement",
            wx1 = ladderWX12,
            wx2 = ladderWX22,
            floorY = basFloor2,
        }

        -- 地面与地下室之间的顶板在梯口处分两段，只有梯口允许上下穿越。
        csColliders.slabs[#csColliders.slabs + 1] = {
            wx1 = basX2,
            wx2 = ladderWX12,
            relY = 0,
            thick = gndSlabT2,
        }
        csColliders.slabs[#csColliders.slabs + 1] = {
            wx1 = ladderWX22,
            wx2 = basX2 + basW2,
            relY = 0,
            thick = gndSlabT2,
        }

        csColliders.slabs[#csColliders.slabs + 1] = {
            wx1 = basX2,
            wx2 = basX2 + basW2,
            relY = basFloor2,
            thick = basSlabT2,
        }
        csColliders.walls[#csColliders.walls + 1] = {
            wx1 = basX2,
            wx2 = basX2 + wallT2,
            relY1 = basTop2,
            relY2 = basFloor2,
            gaps = {},
        }
        csColliders.walls[#csColliders.walls + 1] = {
            wx1 = basX2 + basW2 - wallT2,
            wx2 = basX2 + basW2,
            relY1 = basTop2,
            relY2 = basFloor2,
            gaps = {},
        }
        for divIdx, d in ipairs(CS2_BASEMENT_DATA.divs) do
            local wallCenter2 = basX2 + wallT2 + math.floor(basInnerW2 * d)
            local wallW2 = 36
            local doorH2 = math.floor(basH2 * 0.56)
            csColliders.walls[#csColliders.walls + 1] = {
                wx1 = wallCenter2 - wallW2 * 0.5,
                wx2 = wallCenter2 + wallW2 * 0.5,
                relY1 = basTop2,
                relY2 = basFloor2,
                gaps = { {
                    y1 = basFloor2 - doorH2,
                    y2 = basFloor2,
                    doorKey = "cs2_bas_" .. divIdx,
                } },
            }
        end
    end
end

-- ============================================================================
-- 绘制：地下剖面（横版格斗经典风格）
-- ============================================================================
local function drawGround(ctx)
    local groundY = H * GROUND_Y_RATIO
    local groundH = H - groundY
    -- 根据 SCENE_ZOOM 动态计算可见范围，避免两侧出现空白
    local visLeft = W * 0.5 * (1 - 1 / SCENE_ZOOM)
    local visW    = W / SCENE_ZOOM

    -- 地表以下只绘制土层切面；可见路面统一交给 drawForegroundGround 控制。
    local subY = groundY
    local subH = groundH + 500
    local soilGrad = nvgLinearGradient(ctx, 0, subY, 0, H,
        nvgRGBA(72, 50, 28, 255),
        nvgRGBA(38, 24, 14, 255))
    nvgBeginPath(ctx)
    nvgRect(ctx, visLeft, subY, visW, subH)
    nvgFillPaint(ctx, soilGrad)
    nvgFill(ctx)

    -- ── 3. 土层纹理：随机石块（用相机偏移驱动，看起来随场景滚动）
    math.randomseed(42)
    for i = 1, 28 do
        local rx = (i * 137.5) % STREET_LENGTH
        local sx = rx - cameraX
        sx = sx % (W + 60) - 30
        local ry = subY + math.random() * subH * 0.75 + subH * 0.05
        local rw = 6 + math.random() * 14
        local rh = rw * (0.5 + math.random() * 0.4)
        local alpha = 60 + math.random() * 50
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, sx - rw*0.5, ry - rh*0.5, rw, rh, rh * 0.3)
        nvgFillColor(ctx, nvgRGBA(95, 82, 65, math.floor(alpha)))
        nvgFill(ctx)
    end
    math.randomseed(os.time())

    -- ── 4. 土层纹理：细根须（表层下延伸的短线）
    math.randomseed(77)
    for i = 1, 18 do
        local rx = (i * 211.3) % STREET_LENGTH
        local sx = rx - cameraX
        sx = sx % (W + 40) - 20
        local baseY2 = subY + 10
        local rootLen = 6 + math.random() * subH * 0.25
        local rootAngle = (math.random() - 0.5) * 0.6  -- 轻微倾斜
        local ex = sx + math.sin(rootAngle) * rootLen
        local ey = baseY2 + math.cos(rootAngle) * rootLen
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, sx, baseY2)
        nvgLineTo(ctx, ex, ey)
        nvgStrokeColor(ctx, nvgRGBA(45, 30, 15, 80))
        nvgStrokeWidth(ctx, 1)
        nvgStroke(ctx)
    end
    math.randomseed(os.time())

    -- ── 5. 地面线上方薄雾（与建筑/角色底部融合）
    local fogGrad = nvgLinearGradient(ctx, 0, groundY - 6, 0, groundY + 4,
        nvgRGBA(30, 20, 10, 0), nvgRGBA(30, 20, 10, 55))
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, groundY - 6, W, 10)
    nvgFillPaint(ctx, fogGrad)
    nvgFill(ctx)
end

-- 建筑脚下向镜头方向展开的小幅透视顶面；只覆盖地表线下方的一小段切面。
function drawForegroundGround(ctx)
    if ladderTransition.active or (player and player.jumpScrY > 24) then return end

    local groundY = H * GROUND_Y_RATIO
    local roadDepth = 44 -- 经过 0.55 场景缩放后约为 24 个实际屏幕像素
    local roadFrontY = groundY + roadDepth
    local visLeft = W * 0.5 * (1 - 1 / SCENE_ZOOM) - 80
    local visW = W / SCENE_ZOOM + 160
    local centerX = W * 0.5

    nvgSave(ctx)
    nvgScissor(ctx, visLeft, groundY, visW, roadDepth + 1)

    -- 冷灰蓝沥青，与房间内的暖棕/米色地板明显区分。
    local roadPaint = nvgLinearGradient(ctx, 0, groundY, 0, roadFrontY,
        nvgRGBA(78, 86, 91, 255),
        nvgRGBA(38, 44, 49, 255))
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, visLeft + 34, groundY)
    nvgLineTo(ctx, visLeft + visW - 34, groundY)
    nvgLineTo(ctx, visLeft + visW, roadFrontY)
    nvgLineTo(ctx, visLeft, roadFrontY)
    nvgClosePath(ctx)
    nvgFillPaint(ctx, roadPaint)
    nvgFill(ctx)

    -- 地表后沿。
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, visLeft + 34, groundY)
    nvgLineTo(ctx, visLeft + visW - 34, groundY)
    nvgStrokeColor(ctx, nvgRGBA(132, 145, 151, 185))
    nvgStrokeWidth(ctx, 1.2)
    nvgStroke(ctx)

    -- 多条淡汇聚线贯穿路面，让小面积也能清楚看出向镜头展开。
    for i = -4, 4 do
        local topX = centerX + i * 70
        local frontX = centerX + i * 98
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, topX, groundY)
        nvgLineTo(ctx, frontX, roadFrontY)
        nvgStrokeColor(ctx, nvgRGBA(128, 142, 150, 48))
        nvgStrokeWidth(ctx, 1)
        nvgStroke(ctx)
    end
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, visLeft, roadFrontY)
    nvgLineTo(ctx, visLeft + visW, roadFrontY)
    nvgStrokeColor(ctx, nvgRGBA(38, 37, 36, 160))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)
    nvgRestore(ctx)
end

-- ============================================================================
-- 绘制：街道废弃物
-- ============================================================================
local function drawDebris(ctx)
    local _dx0, gy, debrisSC = worldToScreen(0, 0)
    local items = {
        { x = 400,  type = "trash" },
        { x = 950,  type = "barrel" },
        { x = 1700, type = "crate" },
        { x = 2500, type = "trash" },
        { x = 3200, type = "barrel" },
        { x = 3900, type = "crate" },
        { x = 4400, type = "trash" },
    }

    for _, d in ipairs(items) do
        local dx, _dy, _sc = worldToScreen(d.x, 0)
        if dx < -80 or dx > W + 80 then goto skip end

        if d.type == "trash" then
            nvgBeginPath(ctx)
            nvgEllipse(ctx, dx, gy + 10, 18, 13)
            nvgFillColor(ctx, nvgRGBA(40, 42, 38, 220))
            nvgFill(ctx)
            nvgStrokeColor(ctx, rgba(C.outline))
            nvgStrokeWidth(ctx, 2)
            nvgStroke(ctx)
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, dx - 3, gy + 1)
            nvgLineTo(ctx, dx + 2, gy - 8)
            nvgLineTo(ctx, dx + 5, gy + 1)
            nvgStrokeWidth(ctx, 1.5)
            nvgStroke(ctx)
        elseif d.type == "barrel" then
            nvgSave(ctx)
            nvgTranslate(ctx, dx, gy + 6)
            nvgRotate(ctx, 0.25)
            nvgBeginPath(ctx)
            nvgRoundedRect(ctx, -12, -24, 24, 34, 3)
            nvgFillColor(ctx, rgba(C.rust))
            nvgFill(ctx)
            nvgStrokeColor(ctx, rgba(C.outline))
            nvgStrokeWidth(ctx, 2)
            nvgStroke(ctx)
            nvgRestore(ctx)
        elseif d.type == "crate" then
            nvgBeginPath(ctx)
            nvgRect(ctx, dx - 18, gy - 10, 36, 28)
            nvgFillColor(ctx, rgba(C.rubble))
            nvgFill(ctx)
            nvgStrokeColor(ctx, rgba(C.outline))
            nvgStrokeWidth(ctx, 2)
            nvgStroke(ctx)
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, dx, gy - 10)
            nvgLineTo(ctx, dx, gy + 18)
            nvgMoveTo(ctx, dx - 18, gy + 4)
            nvgLineTo(ctx, dx + 18, gy + 4)
            nvgStrokeColor(ctx, nvgRGBA(C.outline[1], C.outline[2], C.outline[3], 60))
            nvgStrokeWidth(ctx, 1.2)
            nvgStroke(ctx)
        end
        ::skip::
    end
end

-- ============================================================================
-- 绘制：丧尸（序列帧动画，旧 Spine 兜底）
-- ============================================================================
local ZOMBIE_DRAW_H = 132  -- 丧尸显示高度（逻辑像素）

local function getZombieSequenceFrame(z)
    local cfg = ZOMBIE_ANIM_CONFIG
    local state = z.animState or "idle"
    local actionCfg = cfg.actions[state] or cfg.actions.idle
    local frameCount = actionCfg.frameCount
    local animTime = math.max(0, gameTime - (z.animStartTime or gameTime))
    local frameIndex = 1
    if actionCfg.loop then
        frameIndex = 1 + (math.floor(animTime * actionCfg.fps) % frameCount)
    else
        frameIndex = 1 + math.min(frameCount - 1, math.floor(animTime * actionCfg.fps))
    end
    return actionCfg, frameIndex
end

local function drawZombieSequence(ctx, z, sx, sy, sc)
    local cfg = ZOMBIE_ANIM_CONFIG
    local actionCfg, frameIndex = getZombieSequenceFrame(z)
    if not actionCfg or not actionCfg.frames or #actionCfg.frames == 0 then return false end
    local img = actionCfg.frames[frameIndex]
    if not img or img <= 0 then return false end

    local targetH = (cfg.drawH or ZOMBIE_DRAW_H) * sc * (z.sizeJitter or 1.0)
    local scale = targetH / cfg.frameH
    local drawW = cfg.frameW * scale
    local drawH = cfg.frameH * scale
    local baseX = sx + ((z.stagger or 0) + (z.visualOffsetX or 0)) * sc
    local baseY = sy + (cfg.footOffsetY or 0) * sc
    local left = baseX - drawW * 0.5
    local top = baseY - drawH

    nvgSave(ctx)
    -- 视频序列帧默认朝左，朝右时镜像
    if z.facing > 0 then
        nvgTranslate(ctx, baseX, 0)
        nvgScale(ctx, -1, 1)
        nvgTranslate(ctx, -baseX, 0)
    end

    local tint = 150
    if z.hitFlash and z.hitFlash > 0 then
        tint = 255
    end
    local paint = nvgImagePatternTinted(ctx, left, top, drawW, drawH, 0, img, nvgRGBA(tint, tint, tint, 255))
    nvgBeginPath(ctx)
    nvgRect(ctx, left, top, drawW, drawH)
    nvgFillPaint(ctx, paint)
    nvgFill(ctx)
    nvgRestore(ctx)

    -- 影子
    nvgBeginPath(ctx)
    nvgEllipse(ctx, baseX, sy + 2, 20 * sc, 6 * sc)
    nvgFillColor(ctx, nvgRGBA(0, 0, 0, 34))
    nvgFill(ctx)
    return true
end

local function drawOneZombie(ctx, z)
    if z.shattered then return end
    local sx, sy, sc = worldToScreen(z.x, 0)
    if sx < -160 or sx > W + 160 then return end

    if drawZombieSequence(ctx, z, sx, sy, sc) then return end

    if not z.spine or not z.spine:IsLoaded() then return end

    local dataW = z.spine:GetDataWidth()
    local dataH = z.spine:GetDataHeight()
    local dataX = z.spine:GetDataX()
    local dataY = z.spine:GetDataY()
    if dataW <= 0 or dataH <= 0 then return end

    -- 按目标高度计算缩放（与玩家角色相同的逻辑）
    local targetH = ZOMBIE_DRAW_H * sc
    local scale = targetH / dataH

    -- Spine Y-up → 屏幕 Y-down，需要 flipY
    -- celestial_researcher 默认朝左，facing>0(右)时需翻转
    local flipY = true
    local isFlipped = (z.facing > 0)  -- 朝右时翻转（默认朝左）
    local sxScale = scale * (isFlipped and -1 or 1)
    local syScale = scale * (flipY and -1 or 1)
    z.spine:SetScale(sxScale, syScale)

    -- bottom-center 对齐：脚底在 (sx, sy)
    local drawW = dataW * scale
    local drawH = dataH * scale
    local localX = sx + (z.stagger or 0) * sc
    local localY = sy

    local cx = localX - drawW * 0.5
    local cy = localY - drawH

    local posX = cx + (isFlipped and (dataW + dataX) or (-dataX)) * scale
    local posY = cy + (flipY and (dataH + dataY) or (-dataY)) * scale
    z.spine:SetPosition(posX, posY)

    -- 室外傍晚暗色调（丧尸始终在室外）
    local eTint = 0.55
    -- 受击闪白效果
    if z.hitFlash > 0 then
        z.spine:SetColor(eTint, 0.5 * eTint, 0.5 * eTint, 1.0)
    else
        z.spine:SetColor(eTint, eTint, eTint, 1.0)
    end

    nvgSpineRender(ctx, z.spine)

    -- 影子
    nvgBeginPath(ctx)
    nvgEllipse(ctx, localX, sy + 2, 18 * sc, 5 * sc)
    nvgFillColor(ctx, nvgRGBA(0, 0, 0, 30))
    nvgFill(ctx)
end
-- ============================================================================
-- 绘制：血液粒子
-- ============================================================================
local function drawBloodParticles(ctx)
    for _, bp in ipairs(bloodParticles) do
        local bx = bp.x - cameraX
        if bx < -20 or bx > W + 20 then goto skipBlood end

        if bp.isFlash then
            -- 枪口火花（黄色）
            nvgBeginPath(ctx)
            nvgCircle(ctx, bx, bp.y, bp.size)
            nvgFillColor(ctx, nvgRGBA(255, 200, 60, math.floor(bp.alpha)))
            nvgFill(ctx)
        elseif bp.isShotgunImpact then
            nvgBeginPath(ctx)
            nvgCircle(ctx, bx, bp.y, bp.size * 1.25)
            nvgFillColor(ctx, nvgRGBA(255, 85, 52, math.floor(bp.alpha)))
            nvgFill(ctx)
        else
            nvgBeginPath(ctx)
            nvgCircle(ctx, bx, bp.y, bp.size)
            nvgFillColor(ctx, nvgRGBA(ZC.blood[1], ZC.blood[2], ZC.blood[3], math.floor(bp.alpha)))
            nvgFill(ctx)
        end
        ::skipBlood::
    end
end


-- 绘制：粒子 + 雾气
-- ============================================================================
local function drawParticles(ctx)
    for _, p in ipairs(dustParticles) do
        local px = p.x - cameraX * 0.25
        px = px % (W + 20) - 10
        nvgBeginPath(ctx)
        nvgCircle(ctx, px, p.y, p.size)
        nvgFillColor(ctx, nvgRGBA(C.dustCol[1], C.dustCol[2], C.dustCol[3], math.floor(p.alpha)))
        nvgFill(ctx)
    end
    for _, d in ipairs(fallingDebris) do
        local dx = d.x - cameraX * 0.1
        dx = dx % (W + 30) - 15
        nvgSave(ctx)
        nvgTranslate(ctx, dx, d.y)
        nvgRotate(ctx, d.rot)
        nvgBeginPath(ctx)
        nvgRect(ctx, -d.size/2, -d.size/4, d.size, d.size/2)
        nvgFillColor(ctx, nvgRGBA(115, 95, 65, math.floor(d.alpha)))
        nvgFill(ctx)
        nvgRestore(ctx)
    end
end

local function drawFog(ctx)
    local groundY = H * GROUND_Y_RATIO
    -- 地面底部向下淡出雾（增强纵深感）
    local fogBot = nvgLinearGradient(ctx, 0, groundY, 0, H,
        nvgRGBA(75, 50, 38, 0), nvgRGBA(75, 50, 38, 40))
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, groundY, W, H - groundY)
    nvgFillPaint(ctx, fogBot)
    nvgFill(ctx)

end

-- ============================================================================
-- 更新
-- ============================================================================
local function isPlayerOnDoorFloor(fi)
    local slabAbove = (fi > 1) and csColliders.slabs[fi - 1] or nil
    local slabBelow = (fi < CS_NUM_FLOORS) and csColliders.slabs[fi] or nil
    local playerY = player.jumpScrY
    local topRY = slabAbove and slabAbove.relY or -9999
    local botRY = slabBelow and slabBelow.relY or 0
    return playerY > topRY and playerY <= botRY
end

local function detectNearbyStairDoor()
    local bestFi = 0
    local bestDist = math.huge
    for fi = 1, CS_NUM_FLOORS do
        local doorCX = doorWorldCXByFi[fi]
        if doorStates[fi] and doorCX and isPlayerOnDoorFloor(fi) then
            local dist = math.abs(player.x - doorCX)
            if dist < 120 and dist < bestDist then
                bestFi = fi
                bestDist = dist
            end
        end
    end
    return bestFi
end

function detectNearbyCS2StairDoor()
    local bestFi = 0
    local bestSide = "right"
    local bestDist = math.huge
    local playerY = player.jumpScrY
    for fi = 1, CS2_NUM_FLOORS do
        local centers = cs2StairDoorWorldCXByFi[fi]
        local range = cs2StairDoorFloorRanges[fi]
        if centers and range and playerY >= range.topY - 6
            and playerY <= range.bottomY + 6 then
            for _, side in ipairs({"left", "right"}) do
                local doorCX = centers[side]
                local state = side == "left" and cs2LeftStairDoorStates[fi] or cs2StairDoorStates[fi]
                if state and doorCX then
                    local dist = math.abs(player.x - doorCX)
                    if dist < 105 and dist < bestDist then
                        bestFi = fi
                        bestSide = side
                        bestDist = dist
                    end
                end
            end
        end
    end
    playerNearCS2StairDoorSide = bestSide
    return bestFi
end

local function detectNearbyBasementLadder()
    local info = getNearestLadderInfo()
    return info ~= nil and info.side == nil
end

local function detectNearbyRoomDoor()
    local bestDoorKey = nil
    local bestScore = math.huge
    local feetY = player.jumpScrY

    for _, wall in ipairs(csColliders.walls) do
        local gaps = wall.gaps
        if gaps then
            local wallCX = (wall.wx1 + wall.wx2) * 0.5
            local wallW = math.max(1, wall.wx2 - wall.wx1)
            for _, gap in ipairs(gaps) do
                local doorKey = gap.doorKey
                if doorKey and roomDoorStates[doorKey] then
                    local gapH = math.max(1, gap.y2 - gap.y1)
                    local gapCY = (gap.y1 + gap.y2) * 0.5
                    local nearX = math.abs(player.x - wallCX)
                    local nearY = math.abs(feetY - gapCY)
                    local xLimit = math.max(75, wallW * 0.9)
                    local yLimit = math.max(55, gapH * 0.65)
                    if nearX <= xLimit and nearY <= yLimit then
                        local score = nearX + nearY * 0.2
                        if score < bestScore then
                            bestScore = score
                            bestDoorKey = doorKey
                        end
                    end
                end
            end
        end
    end

    return bestDoorKey
end

local function detectNearbyLightSwitch()
    local bestKey = nil
    local bestScore = math.huge
    local touchY = H * GROUND_Y_RATIO + player.jumpScrY - (player.drawH or 120) * 0.28
    for _, z in ipairs(lightSwitchZones) do
        local roomEntryMargin = math.min(42, (z.rangeX or 68) * 0.6)
        if z.key and isPlayerInRoomBounds(
            z.roomWorldLeft - roomEntryMargin,
            z.roomWorldRight + roomEntryMargin,
            z.roomTop,
            z.roomH
        ) then
            local nearX = math.abs(player.x - z.worldX)
            local nearY = math.abs(touchY - z.screenY)
            local yLimit = math.max(z.rangeY or 74, 112)
            if nearX <= (z.rangeX or 68) and nearY <= yLimit then
                local score = nearX + nearY * 0.25
                if score < bestScore then
                    bestScore = score
                    bestKey = z.key
                end
            end
        end
    end
    return bestKey
end

function detectCurrentRoomLightKey()
    local px = player.x
    local feetY = H * GROUND_Y_RATIO + player.jumpScrY
    for _, fo in ipairs(csInfo.floorOverlays or {}) do
        for _, r in ipairs(fo.rooms or {}) do
            local left = (r.x or (r.midX - (r.rw or fo.w) * 0.5)) + (csInfo.camX or cameraX)
            local right = left + (r.rw or fo.w)
            if r.key and px >= left and px <= right and feetY >= fo.y - 24 and feetY <= fo.y + fo.h + 90 then
                return r.key
            end
        end
    end
    local ov = csInfo.basOverlay
    if ov then
        for ri = 1, #CS_BASEMENT_DATA.rooms do
            local left = ov.bxs[ri] + (csInfo.camX or cameraX)
            local right = ov.bxs[ri + 1] + (csInfo.camX or cameraX)
            if px >= left and px <= right and feetY >= ov.basTop - 24 and feetY <= ov.basTop + ov.basRoomH + 90 then
                return "cs_bas_" .. ri
            end
        end
    end
    local b = getCurrentStreetBuilding()
    if b then
        return "street_" .. b.id
    end
    return nil
end

local function updateGame(dt)
    -- 每帧用碰撞门洞数据检测靠近状态，避免依赖渲染帧导致按钮不出现
    playerNearRoomDoor = detectNearbyRoomDoor()
    playerNearDoorFi = detectNearbyStairDoor()
    playerNearCS2StairDoorFi = detectNearbyCS2StairDoor()
    if playerNearCS2StairDoorFi > 0 then
        playerNearRoomDoor = nil
    end
    playerNearBasementLadder = detectNearbyBasementLadder()
    playerNearStreetBuilding = detectNearbyStreetBuilding()
    playerNearLightSwitch = detectNearbyLightSwitch()

    -- ========== 门动画更新 ==========
    for _, ds in pairs(doorStates) do
        if ds.openProg < ds.target then
            ds.openProg = math.min(ds.openProg + DOOR_ANIM_SPEED * dt, ds.target)
        elseif ds.openProg > ds.target then
            ds.openProg = math.max(ds.openProg - DOOR_ANIM_SPEED * dt, ds.target)
        end
    end
    for _, ds in pairs(cs2StairDoorStates) do
        if ds.openProg < ds.target then
            ds.openProg = math.min(ds.openProg + DOOR_ANIM_SPEED * dt, ds.target)
        elseif ds.openProg > ds.target then
            ds.openProg = math.max(ds.openProg - DOOR_ANIM_SPEED * dt, ds.target)
        end
    end
    -- 房间门动画更新
    for _, rds in pairs(roomDoorStates) do
        if rds.openProg < rds.target then
            rds.openProg = math.min(rds.openProg + DOOR_ANIM_SPEED * dt, rds.target)
        elseif rds.openProg > rds.target then
            rds.openProg = math.max(rds.openProg - DOOR_ANIM_SPEED * dt, rds.target)
        end
    end
    -- 房间门交互（C键 / F键 / 手机开门按钮）
    if playerNearRoomDoor then
        if descendBtn_ then descendBtn_._shouldShow = true end
        local rds = roomDoorStates[playerNearRoomDoor]
        if rds then
            if input:GetKeyPress(KEY_C) or input:GetKeyPress(KEY_F) or openDoorPressed_ then
                rds.target = rds.target == 1 and 0 or 1
                playDoorSound()
                openDoorPressed_ = false
            end
        end
    else
        -- 不靠近任何房间门时隐藏按钮
        if descendBtn_ then descendBtn_._shouldShow = false end
    end
    -- 消费残余标记
    if openDoorPressed_ then openDoorPressed_ = false end

    -- ========== 换层过渡动画更新 ==========
    if ladderTransition.active then
        local lt = ladderTransition
        local ladderMoveY = 0
        if joystick_ then
            local _, moveY = joystick_:getMovement()
            ladderMoveY = moveY or 0
        end
        if downPressed_ then
            ladderMoveY = -1
            downPressed_ = false
        elseif upPressed_ then
            ladderMoveY = 1
            upPressed_ = false
        elseif input:GetKeyDown(KEY_S) or input:GetKeyDown(KEY_DOWN) then
            ladderMoveY = -1
        elseif input:GetKeyDown(KEY_W) or input:GetKeyDown(KEY_UP) then
            ladderMoveY = 1
        end

        -- 梯子中途可随时反向：负值向下，正值向上；松开时位置和动作帧都暂停。
        local climbDirection = 0
        if ladderMoveY < -0.45 then
            climbDirection = 1
        elseif ladderMoveY > 0.45 then
            climbDirection = -1
        end
        if lt.phase == "climb" and climbDirection ~= 0 then
            lt.timer = clamp(lt.timer + climbDirection * dt, 0, lt.duration)
            lt.animTime = lt.timer
        end

        local progress = lt.timer / math.max(0.01, lt.duration)
        local activeLadder = lt.ladderInfo
        local playerLadderSide = activeLadder and activeLadder.side
        if playerLadderSide then
            playerNearCS2StairDoorSide = playerLadderSide
        end
        local basementFloorY = activeLadder and (activeLadder.bottomY or activeLadder.floorY) or 0
        local topContactY = CLIMB_ANIM.handContactOffsetY or 170
        if activeLadder and activeLadder.topY ~= nil then
            topContactY = activeLadder.topY
        end
        local climbRange = math.max(1, basementFloorY - topContactY)
        -- 有效爬梯区从“双手接触梯顶”开始，到脚到达地下室地面结束。
        player.jumpScrY = topContactY + climbRange * progress
        player.isMoving = false
        player.isRunning = false
        player.onGround = false
        player.actionState = "climb"

        if lt.phase == "landingChoice" then
            -- 中间楼层只提供短暂的停靠选择，不按按钮便衔接同侧下一段梯子。
            player.jumpScrY = lt.landingY
            lt.landingWait = lt.landingWait + dt
            if ladderEnterPressed_ then
                player.jumpVelY = 0
                player.onGround = true
                player.actionState = "none"
                player.actionTimer = 0
                player.climbReverse = false
                lt.active = false
                lt.phase = "none"
                lt.ladderInfo = nil
                lt.landingFi = 0
                lt.landingDirection = nil
                lt.landingWait = 0
                ladderEnterPressed_ = false
                print("[Ladder] 玩家选择停留楼层，当前位置Y=" .. tostring(player.jumpScrY))
            elseif lt.landingWait >= 0.65 then
                local nextLadder = ladderTransition.GetConnected(activeLadder, lt.landingDirection)
                if nextLadder then
                    lt.ladderInfo = nextLadder
                    lt.timer = lt.landingDirection == "down" and 0 or lt.duration
                    lt.animTime = lt.timer
                    lt.phase = "climb"
                    lt.landingFi = 0
                    lt.landingY = 0
                    lt.landingWait = 0
                    player.x = (nextLadder.wx1 + nextLadder.wx2) * 0.5
                    ladderEnterPressed_ = false
                    print("[Ladder] 未停留，继续攀爬梯子=" .. tostring(nextLadder.name))
                else
                    player.jumpVelY = 0
                    player.onGround = true
                    player.actionState = "none"
                    player.actionTimer = 0
                    player.climbReverse = false
                    lt.active = false
                    lt.phase = "none"
                    lt.ladderInfo = nil
                    lt.landingFi = 0
                    lt.landingDirection = nil
                    lt.landingWait = 0
                    ladderEnterPressed_ = false
                end
            end
        else
            -- 第二栋楼的中间端点先提供停靠按钮；边界层和地下室梯直接离梯。
            local reachedTop = climbDirection < 0 and lt.timer <= 0
            local reachedBottom = climbDirection > 0 and lt.timer >= lt.duration
            if reachedTop or reachedBottom then
                local travelDirection = reachedBottom and "down" or "up"
                local endpointY = reachedTop
                    and (activeLadder.topY ~= nil and activeLadder.topY or 0)
                    or (activeLadder.bottomY or basementFloorY)
                local nextLadder = ladderTransition.GetConnected(activeLadder, travelDirection)
                player.jumpScrY = endpointY

                if nextLadder then
                    lt.phase = "landingChoice"
                    lt.landingFi = reachedBottom
                        and (activeLadder.bottomFi or 0)
                        or (activeLadder.topFi or 0)
                    lt.landingY = endpointY
                    lt.landingDirection = travelDirection
                    lt.landingWait = 0
                    ladderEnterPressed_ = false
                    print("[Ladder] 到达中间楼层=" .. tostring(lt.landingFi) .. "，等待停留选择")
                else
                    player.jumpVelY = 0
                    player.onGround = true
                    player.actionState = "none"
                    player.actionTimer = 0
                    player.climbReverse = false
                    lt.active = false
                    lt.phase = "none"
                    lt.ladderInfo = nil
                    lt.landingFi = 0
                    lt.landingDirection = nil
                    lt.landingWait = 0
                    ladderEnterPressed_ = false
                    print("[Ladder] 到达梯子边界并离梯，当前位置Y=" .. tostring(player.jumpScrY))
                end
            end
        end

        -- updatePlayer 在爬梯期间会冻结返回，因此这里单独同步相机。
        if not drag.active and drag.cooldown <= 0 then
            cameraX = clamp(player.x - W * 0.4, 0, STREET_LENGTH - W)
            cameraY = CAMERA_BASE_Y - player.jumpScrY
        end
    else
        ladderEnterPressed_ = false
    end

    if floorTransition.active then
        local ft = floorTransition
        ft.timer = ft.timer + dt
        if ft.phase == "fadeOut" then
            ft.alpha = math.max(0, 1.0 - ft.timer / ft.duration)
            if ft.timer >= ft.duration then
                -- 淡出完成，执行传送
                player.jumpScrY = ft.targetY
                player.jumpVelY = 0
                player.onGround = true
                -- 将玩家水平位置移到对应建筑的目标楼层门。
                if ft.targetX then
                    player.x = ft.targetX
                elseif doorWorldCXByFi[ft.targetFi] then
                    player.x = doorWorldCXByFi[ft.targetFi]
                end
                -- 每层门独立控制，不自动打开目标楼层的门
                -- 切换到淡入
                ft.phase = "fadeIn"
                ft.timer = 0
                ft.alpha = 0
            end
        elseif ft.phase == "fadeIn" then
            ft.alpha = math.min(1.0, ft.timer / ft.duration)
            if ft.timer >= ft.duration then
                -- 过渡完成
                ft.active = false
                ft.phase = "none"
                ft.alpha = 1.0
            end
        end
    end

    -- ========== 摸金/信件系统交互 ==========
    reloadPressed_ = false
    consumePressed_ = false
    handleSearchButtonInput()
    if lootUI.letterOpen then
        -- 信件界面打开时隐藏游戏操控；F、ESC、手机按钮均可关闭。
        if joystick_ then joystick_._shouldShow = false end
        if descendBtn_ then descendBtn_._shouldShow = false end
        if lightSwitchBtn_ then lightSwitchBtn_._shouldShow = false end
        if doorBtn_ then doorBtn_._shouldShow = false end
        if upBtn_ then upBtn_._shouldShow = false end
        if downBtn_ then downBtn_._shouldShow = false end
        if lootBtn_ then lootBtn_._shouldShow = true end
        if input:GetKeyPress(KEY_F) or input:GetKeyPress(KEY_ESCAPE) or lootBtnPressed_ then
            lootBtnPressed_ = false
            lootUI.letterOpen = false
            lootUI.letterAnim = 0
        else
            lootUI.letterAnim = math.min(1, (lootUI.letterAnim or 0) + dt * 2.8)
        end
    elseif lootUI.active then
        -- 摸金UI打开时 → 只能通过关闭按钮关闭（不响应ESC/F）
        -- 触屏/鼠标点击处理（在 NanoVGRender 中通过 handleLootUIClick 实现）
        -- 隐藏所有虚拟操控（弹窗全屏覆盖，控件不应显示）
        if joystick_ then joystick_._shouldShow = false end
        if descendBtn_ then descendBtn_._shouldShow = false end
        if lightSwitchBtn_ then lightSwitchBtn_._shouldShow = false end
        if doorBtn_ then doorBtn_._shouldShow = false end
        if upBtn_ then upBtn_._shouldShow = false end
        if downBtn_ then downBtn_._shouldShow = false end
        if lootBtn_ then lootBtn_._shouldShow = false end
    else
        -- 没打开摸金UI → 恢复虚拟操控显示
        if joystick_ then joystick_._shouldShow = true end
        -- descendBtn_（开门按钮）不在这里恢复，由门靠近检测逻辑控制
        if input:GetKeyPress(KEY_L) then
            if playerNearLightSwitch then
                toggleRoomLight(playerNearLightSwitch)
            end
        end
        handleWeaponHUDInput()
        handleActionHUDInput()
        if consumePressed_ then
            consumeQuickConsumable()
        end
        if lootUI.equippedGunItem == "" or not isFirearmAnimSet() then
            reloadPressed_ = false
        end
        if reloadPressed_
            and lootUI.equippedGunItem ~= ""
            and isFirearmAnimSet()
            and player.actionState == "none"
            and player.ammo < player.maxAmmo then
            player.actionState = "reload"
            player.actionTimer = BAT_DEMO_ANIM.reloadDuration or 1.2
            BAT_DEMO_ANIM.reloadStartTime = gameTime
            playPistolReloadSound()
            player.attackCombo = 0
            player.attackQueued = false
        end
        if (lootUI.equippedGunItem ~= "" or lootUI.equippedMeleeItem ~= "")
            and (input:GetKeyPress(KEY_E) or weaponSwitchPressed_) then
            weaponSwitchPressed_ = false
            togglePlayerWeaponAnim()
        else
            weaponSwitchPressed_ = false
        end
        if input:GetKeyPress(KEY_I) or inventoryBtnPressed_ then
            inventoryBtnPressed_ = false
            openInventoryPanel()
        end
        -- 1F左侧茶几上的信件：打开纸张界面，不进入搜刮UI。
        if lootUI.letterNear then
            if lootBtn_ then lootBtn_._shouldShow = true end
            if doorBtn_ then doorBtn_._shouldShow = false end
            if input:GetKeyPress(KEY_F) or lootBtnPressed_ then
                lootBtnPressed_ = false
                lootUI.letterAnim = 0
                lootUI.letterOpen = true
            end
        -- 厕所散落医疗物品：按 F 或手机“搜刮”按钮直接放入随身容器，不打开摸金UI。
        elseif lootUI.nearLoosePickup then
            if lootBtn_ then lootBtn_._shouldShow = true end
            if doorBtn_ then doorBtn_._shouldShow = false end
            if input:GetKeyPress(KEY_F) or lootBtnPressed_ then
                lootBtnPressed_ = false
                lootUI.PickupLooseWorldItem(lootUI.nearLoosePickup)
                lootUI.nearLoosePickup = nil
            end
        -- 检测是否靠近宝箱
        elseif lootUI.nearChestIdx > 0 then
            local nearChest = chestDefs[lootUI.nearChestIdx]
            if nearChest then
                -- 显示搜刮按钮（手机端），同时隐藏门按钮避免冲突
                if lootBtn_ then lootBtn_._shouldShow = true end
                if doorBtn_ then doorBtn_._shouldShow = false end
                -- F键或触屏按钮打开摸金UI
                if input:GetKeyPress(KEY_F) or lootBtnPressed_ then
                    lootBtnPressed_ = false
                    lootUI.EnsureChestLootGenerated(lootUI.nearChestIdx)
                    nearChest = chestDefs[lootUI.nearChestIdx]
                    if nearChest then
                        lootUI.ResetInteractionState()
                        lootUI.active = true
                        lootUI.mode = "loot"
                        lootUI.chestIdx = lootUI.nearChestIdx
                        lootUI.animTimer = 0
                        lootUI.selectedSlot = 0
                        lootUI.selectedItem = ""
                        lootUI.selectedContainer = ""
                        lootUI.selectedIdx = 0
                        lootUI.loadingElapsed = nearChest.lootLoaded and 999 or 0
                        lootUI.midScrollY = 0
                        lootUI.revealedSet = {}
                        -- 已完成过整箱加载的搜刮点再次打开时直接显示，不重复播放加载动画。
                        if nearChest.lootLoaded then
                            lootUI.loadingDuration = 0
                            lootUI.loadingTimer = 0
                            lootUI.maxRevealDelay = 0
                        else
                            -- 串行加载：总时长是每个未拾取物资加载时长之和。
                            local _, _, totalRevealDuration =
                                lootUI.GetSequentialRevealSchedule(nearChest.items)
                            lootUI.loadingDuration = totalRevealDuration + 0.15
                            lootUI.loadingTimer = lootUI.loadingDuration
                            lootUI.maxRevealDelay = totalRevealDuration
                        end
                    end
                end
            else
                if lootBtn_ then lootBtn_._shouldShow = false end
                lootBtnPressed_ = false
                lootUI.nearChestIdx = 0
            end
        else
            if lootBtn_ then lootBtn_._shouldShow = false end
            lootBtnPressed_ = false
        end
    end

    -- ========== 门交互（F键/触屏开关门 + W/S/触屏换层） ==========
    cs2LadderDownHUDVisible = false
    if lootUI.active or lootUI.letterOpen then
        -- 弹窗打开时强制隐藏所有按钮（信件保留搜刮按钮用于关闭）。
        if doorBtn_ then doorBtn_._shouldShow = false end
        if upBtn_ then upBtn_._shouldShow = false end
        if downBtn_ then downBtn_._shouldShow = false end
        if lootUI.active and lootBtn_ then lootBtn_._shouldShow = false end
    elseif ladderTransition.active then
        -- 仅在第二栋楼外梯经过中间楼层时显示“停留”按钮。
        cs2LadderDownHUDVisible = ladderTransition.phase == "landingChoice"
        if doorBtn_ then doorBtn_._shouldShow = false end
        if upBtn_ then upBtn_._shouldShow = false end
        if downBtn_ then downBtn_._shouldShow = false end
        if lootBtn_ then lootBtn_._shouldShow = false end
    elseif playerNearBasementLadder and playerNearCS2StairDoorFi <= 0 and not floorTransition.active then
        -- 地下室梯口只使用摇杆纵向输入：向下进入地下室，向上离开地下室。
        if doorBtn_ then doorBtn_._shouldShow = false end
        if upBtn_ then upBtn_._shouldShow = false end
        if downBtn_ then downBtn_._shouldShow = false end
        local ladderMoveY = 0
        if joystick_ then
            local _, moveY = joystick_:getMovement()
            ladderMoveY = moveY or 0
        end
        downPressed_ = false
        upPressed_ = false
        -- 当前摇杆坐标中，负值代表手指向下，正值代表手指向上。
        -- 因此负值进入地下室，正值从地下室向上离开。
        local startedClimb = false
        if player.jumpScrY <= 24 and ladderMoveY < -0.45 then
            startedClimb = beginLadderTransition("down")
        elseif player.jumpScrY > 24 and ladderMoveY > 0.45 then
            startedClimb = beginLadderTransition("up")
        end
        if startedClimb then
            -- 角色先贴上梯子，再在同一帧把镜头锁到新的角色位置。
            drag.active = false
            drag.cooldown = 0
            cameraX = clamp(player.x - W * 0.4, 0, STREET_LENGTH - W)
            cameraY = CAMERA_BASE_Y - player.jumpScrY
        end
    elseif playerNearStreetBuilding and not floorTransition.active then
        if doorBtn_ then doorBtn_._shouldShow = true end
        if upBtn_ then upBtn_._shouldShow = false end
        if downBtn_ then downBtn_._shouldShow = false end
        if input:GetKeyPress(KEY_F) or doorPressed_ then
            playerNearStreetBuilding.doorOpen = not playerNearStreetBuilding.doorOpen
            playDoorSound()
            doorPressed_ = false
            if playerNearStreetBuilding.doorOpen then
                player.x = playerNearStreetBuilding.x + playerNearStreetBuilding.doorX - 24
            else
                player.x = playerNearStreetBuilding.x + playerNearStreetBuilding.doorX + 36
            end
        end
    elseif playerNearCS2StairDoorFi > 0 and not floorTransition.active then
        -- 每层门口都可进入房间；门打开后同时提供相邻楼层的精确爬梯按钮。
        if doorBtn_ then doorBtn_._shouldShow = true end
        if upBtn_ then upBtn_._shouldShow = false end
        if downBtn_ then downBtn_._shouldShow = false end
        local side = playerNearCS2StairDoorSide
        local ds = side == "left" and cs2LeftStairDoorStates[playerNearCS2StairDoorFi] or cs2StairDoorStates[playerNearCS2StairDoorFi]
        if ds and (input:GetKeyPress(KEY_F) or doorPressed_) then
            ds.target = ds.target == 1 and 0 or 1
            playDoorSound()
            doorPressed_ = false
        end
        if ds and ds.openProg > 0.5 then
            local ladderMoveY = 0
            if joystick_ then
                local _, moveY = joystick_:getMovement()
                ladderMoveY = moveY or 0
            end
            -- 第二栋楼的上下楼按钮需要和摇杆、键盘共用同一输入通道。
            -- 摇杆存在但处于中立时，不能屏蔽手机按钮或键盘输入。
            if downPressed_ then
                ladderMoveY = -1
                downPressed_ = false
            elseif upPressed_ then
                ladderMoveY = 1
                upPressed_ = false
            elseif math.abs(ladderMoveY) <= 0.45 then
                if input:GetKeyDown(KEY_S) or input:GetKeyDown(KEY_DOWN) then
                    ladderMoveY = -1
                elseif input:GetKeyDown(KEY_W) or input:GetKeyDown(KEY_UP) then
                    ladderMoveY = 1
                end
            end

            local startedClimb = false
            if ladderMoveY < -0.45 and playerNearCS2StairDoorFi < CS2_NUM_FLOORS then
                startedClimb = beginLadderTransition(
                    "down",
                    playerNearCS2StairDoorFi,
                    side
                )
            elseif ladderMoveY > 0.45 and playerNearCS2StairDoorFi > 1 then
                startedClimb = beginLadderTransition(
                    "up",
                    playerNearCS2StairDoorFi,
                    side
                )
            end
            if startedClimb then
                drag.active = false
                drag.cooldown = 0
                cameraX = clamp(player.x - W * 0.4, 0, STREET_LENGTH - W)
                cameraY = CAMERA_BASE_Y - player.jumpScrY
            end
        end
    elseif playerNearDoorFi > 0 and not floorTransition.active then
        local fi = playerNearDoorFi
        local ds = doorStates[fi]
        if ds then
            -- 显示开门按钮（手机端）
            if doorBtn_ then doorBtn_._shouldShow = true end

            -- F键或触屏按钮开关门
            if input:GetKeyPress(KEY_F) or doorPressed_ then
                ds.target = ds.target == 1 and 0 or 1
                playDoorSound()
                doorPressed_ = false
            end
            -- 门打开状态下，W/上键/触屏上楼，S/下键/触屏下楼
            if ds.openProg > 0.5 then
                -- 显示上下楼按钮（手机端）
                if upBtn_ and fi > 1 then upBtn_._shouldShow = true end
                if downBtn_ and fi < CS_NUM_FLOORS then downBtn_._shouldShow = true end

                local targetFi = 0
                local targetY = 0
                if input:GetKeyPress(KEY_UP) or input:GetKeyPress(KEY_W) or upPressed_ then
                    -- 上楼
                    upPressed_ = false
                    if fi > 1 then
                        targetFi = fi - 1
                        local slab = csColliders.slabs[targetFi]
                        if slab then targetY = slab.relY end
                    end
                elseif input:GetKeyPress(KEY_DOWN) or input:GetKeyPress(KEY_S) or downPressed_ then
                    -- 下楼
                    downPressed_ = false
                    if fi < CS_NUM_FLOORS then
                        targetFi = fi + 1
                        if targetFi >= CS_NUM_FLOORS then
                            -- 目标是1F（地面层），jumpScrY = 0
                            targetY = 0
                        else
                            -- 目标是中间层，站在目标层的地板上
                            local slab = csColliders.slabs[targetFi]
                            if slab then targetY = slab.relY end
                        end
                    end
                end
                -- 启动过渡动画
                if targetFi > 0 then
                    floorTransition.active = true
                    floorTransition.phase = "fadeOut"
                    floorTransition.timer = 0
                    floorTransition.alpha = 1.0
                    floorTransition.targetFi = targetFi
                    floorTransition.targetY = targetY
                    floorTransition.targetX = doorWorldCXByFi[targetFi]
                end
            else
                -- 门未打开，隐藏上下楼按钮
                if upBtn_ then upBtn_._shouldShow = false end
                if downBtn_ then downBtn_._shouldShow = false end
            end
        end
    else
        -- 不靠近门，隐藏所有门交互按钮
        if doorBtn_ then doorBtn_._shouldShow = false end
        if upBtn_ then upBtn_._shouldShow = false end
        if downBtn_ then downBtn_._shouldShow = false end
        doorPressed_ = false
        upPressed_ = false
        downPressed_ = false
    end
    -- 独立 NanoVG 开灯按钮已负责显示，不再刷新虚拟开灯按钮
    handleLightToggleUIInput()

    -- 用完后重置，本帧渲染会重新计算
    playerNearDoorFi = 0
    playerNearCS2StairDoorFi = 0
    lootUI.nearChestIdx = 0
    lootUI.nearChestDist = math.huge
    lootUI.nearLoosePickup = nil
    lootUI.nearLoosePickupDist = math.huge
    lootUI.letterNear = false
    lootUI.letterDist = math.huge
    lootUI.letterRect = nil

    -- ========== 雨更新 ==========
    updateRain(dt)

    -- ========== 玩家更新 ==========
    updatePlayer(dt)
    -- updateBuildingInteraction(dt)  -- 进入房间功能暂不启用

    -- ========== 丧尸生成 ==========
    if ZOMBIE_DYNAMIC_SPAWN_ENABLED then
        zombieSpawnTimer = zombieSpawnTimer - dt
        if zombieSpawnTimer <= 0 then
            if getAliveZombieCount() < ZOMBIE_MAX_ALIVE then
                spawnZombie(false, chooseZombieSceneSpawnX())
            end
            zombieSpawnTimer = ZOMBIE_SPAWN_INTERVAL + math.random() * ZOMBIE_SPAWN_VARIANCE
        end
    end

    -- ========== 丧尸更新（序列帧动画驱动） ==========
    for i = #zombies, 1, -1 do
        local z = zombies[i]

        if z.alive then
            local playerDx = player.x - z.x
            local playerDist = math.abs(playerDx)
            local sameLevel = math.abs((player.jumpScrY or 0)) < 80
            local zombieScreenX = worldToScreen(z.x, 0)
            local zombieOnScreen = zombieScreenX >= -160 and zombieScreenX <= W + 160
            local doorTarget = sameLevel and findClosedDoorBetween(z.x, player.x) or nil
            local closedDoorBetween = doorTarget ~= nil

            -- 与绘制裁剪使用同一屏幕范围：进入可见区即发现玩家。
            -- 激活后不再按世界距离脱战，只在跨层或被关闭的门隔断时停止。
            if not sameLevel or closedDoorBetween then
                z.isChasing = false
            elseif zombieOnScreen then
                z.isChasing = true
            end

            if z.hurtTimer and z.hurtTimer > 0 then
                z.hurtTimer = math.max(0, z.hurtTimer - dt)
                if z.hurtTimer <= 0 then
                    z.animState = z.isChasing and "run" or "idle"
                    z.animStartTime = gameTime
                end
            else
                z.attackCooldown = math.max(0, (z.attackCooldown or 0) - dt)
                local gunshotAlertActive = (gameTime - zombieAlertTime) <= ZOMBIE_GUNSHOT_ALERT_DURATION
                    and math.abs(z.x - zombieAlertX) <= ZOMBIE_GUNSHOT_ALERT_RANGE
                local alertedByGunshot = closedDoorBetween and gunshotAlertActive
                local seePlayer = sameLevel and not closedDoorBetween and z.isChasing
                local attackRange = sameLevel and not closedDoorBetween and playerDist < 118
                local doorAttackRange = alertedByGunshot and math.abs(z.x - doorTarget.x) <= ZOMBIE_DOOR_ATTACK_RANGE

                -- 攻击动作优先级最高：攻击期间完全停止移动，不允许切回奔跑
                if z.attackTimer and z.attackTimer > 0 then
                    z.attackTimer = math.max(0, z.attackTimer - dt)
                    z.animState = "attack"
                    local attackAge = gameTime - (z.animStartTime or gameTime)
                    if not z.attackHitDone and attackAge >= 0.42 then
                        if z.attackTarget == "door" then
                            damageDoorFromZombie(z)
                        elseif attackRange then
                            damagePlayerFromZombie(z)
                        end
                        z.attackHitDone = true
                    end
                    if z.attackTimer <= 0 then
                        z.attackTarget = nil
                        z.doorTarget = nil
                        z.animState = attackRange and "idle" or (seePlayer and "run" or (alertedByGunshot and doorTarget and "run" or "idle"))
                        z.animStartTime = gameTime
                    end
                elseif attackRange then
                    z.facing = playerDx >= 0 and 1 or -1
                    if z.attackCooldown <= 0 then
                        z.animState = "attack"
                        z.animStartTime = gameTime
                        z.attackTimer = 1.05
                        z.attackHitDone = false
                        z.attackCooldown = 0.15
                        z.attackTarget = "player"
                        z.doorTarget = nil
                        playZombieSound("attack")
                    elseif z.animState ~= "idle" then
                        z.animState = "idle"
                        z.animStartTime = gameTime
                    end
                elseif doorAttackRange then
                    z.facing = (doorTarget.x >= z.x) and 1 or -1
                    if z.attackCooldown <= 0 then
                        z.animState = "attack"
                        z.animStartTime = gameTime
                        z.attackTimer = 1.05
                        z.attackHitDone = false
                        z.attackCooldown = 0.25
                        z.attackTarget = "door"
                        z.doorTarget = doorTarget
                        playZombieSound("attack")
                    elseif z.animState ~= "idle" then
                        z.animState = "idle"
                        z.animStartTime = gameTime
                    end
                elseif alertedByGunshot and doorTarget then
                    z.growlTimer = math.max(0, (z.growlTimer or 0) - dt)
                    if z.growlTimer <= 0 then
                        playZombieSound("growl")
                        z.growlTimer = 2.2 + math.random() * 2.2
                    end
                    z.facing = (doorTarget.x >= z.x) and 1 or -1
                    if z.animState ~= "run" then
                        z.animState = "run"
                        z.animStartTime = gameTime
                        if z.spine then z.spine:SetAnimation(0, "walk", true) end
                    else
                        local runAnimAge = gameTime - (z.animStartTime or gameTime)
                        if runAnimAge >= 0.08 then
                            local prevX = z.x
                            local targetDist = math.max(0, math.abs(z.x - doorTarget.x) - ZOMBIE_DOOR_ATTACK_RANGE)
                            local step = math.min(z.speed * dt, targetDist)
                            z.x = z.x + z.facing * step
                            resolveZombieDoorCollision(z, prevX)
                        end
                    end
                elseif seePlayer then
                    z.growlTimer = math.max(0, (z.growlTimer or 0) - dt)
                    if z.growlTimer <= 0 then
                        playZombieSound("growl")
                        z.growlTimer = 2.2 + math.random() * 2.2
                    end
                    z.facing = playerDx >= 0 and 1 or -1
                    if z.animState ~= "run" then
                        z.animState = "run"
                        z.animStartTime = gameTime
                        if z.spine then z.spine:SetAnimation(0, "walk", true) end
                    else
                        local runAnimAge = gameTime - (z.animStartTime or gameTime)
                        if runAnimAge >= 0.08 then
                            local prevX = z.x
                            z.x = z.x + z.facing * z.speed * dt
                            if resolveZombieDoorCollision(z, prevX) then
                                z.animState = "idle"
                                z.animStartTime = gameTime
                            end
                        end
                    end
                else
                    if z.animState ~= "idle" then
                        z.animState = "idle"
                        z.animStartTime = gameTime
                    end
                end
            end
        else
            -- 死亡后保留尸体，不再自动移除
            z.deadTimer = (z.deadTimer or 0) + dt
            if z.animState ~= "dead" then
                z.animState = "dead"
                z.animStartTime = gameTime
            end
        end

        -- 更新旧 Spine 动画（兜底用）
        if z.spine then z.spine:Update(dt) end

        -- 受击闪白消退
        z.hitFlash = math.max(0, z.hitFlash - dt)
        -- 击退消退
        if math.abs(z.stagger) > 0.5 then
            z.stagger = z.stagger * math.max(0, 1 - dt * 6)
        else
            z.stagger = 0
        end

        ::continueZombie::
    end

    -- ========== 子弹更新 ==========
    updateBullets(dt)

    if SHOTGUN_MUZZLE_FX then
        SHOTGUN_MUZZLE_FX.life = SHOTGUN_MUZZLE_FX.life - dt
        if SHOTGUN_MUZZLE_FX.life <= 0 then SHOTGUN_MUZZLE_FX = nil end
    end
    if PISTOL_MUZZLE_FX then
        PISTOL_MUZZLE_FX.life = PISTOL_MUZZLE_FX.life - dt
        if PISTOL_MUZZLE_FX.life <= 0 then PISTOL_MUZZLE_FX = nil end
    end
    if GUN_SCREEN_FLASH then
        GUN_SCREEN_FLASH.life = GUN_SCREEN_FLASH.life - dt
        if GUN_SCREEN_FLASH.life <= 0 then GUN_SCREEN_FLASH = nil end
    end
    SCREEN_SHAKE_TIME = math.max(0, SCREEN_SHAKE_TIME - dt)
    if SCREEN_SHAKE_TIME <= 0 then SCREEN_SHAKE_POWER = 0 end

    for i = #SHOTGUN_IMPACT_RINGS, 1, -1 do
        local ring = SHOTGUN_IMPACT_RINGS[i]
        ring.life = ring.life - dt
        if ring.life <= 0 then table.remove(SHOTGUN_IMPACT_RINGS, i) end
    end

    for i = #ZOMBIE_GIBS, 1, -1 do
        local gib = ZOMBIE_GIBS[i]
        gib.x = gib.x + gib.vx * dt
        gib.y = gib.y + gib.vy * dt
        gib.vy = gib.vy + gib.gravity * dt
        gib.rot = gib.rot + gib.rotSpeed * dt
        gib.life = gib.life - dt
        if gib.y > H * GROUND_Y_RATIO + 4 then
            gib.y = H * GROUND_Y_RATIO + 4
            gib.vy = -math.abs(gib.vy) * 0.22
            gib.vx = gib.vx * 0.72
            gib.rotSpeed = gib.rotSpeed * 0.65
        end
        if gib.life <= 0 then table.remove(ZOMBIE_GIBS, i) end
    end

    -- ========== 治疗加号更新 ==========
    for i = #HEALING_PLUS_PARTICLES, 1, -1 do
        local particle = HEALING_PLUS_PARTICLES[i]
        if particle.delay > 0 then
            particle.delay = math.max(0, particle.delay - dt)
        else
            particle.x = particle.x + particle.vx * dt
            particle.y = particle.y + particle.vy * dt
            particle.vx = particle.vx * math.max(0, 1 - dt * 1.8)
            particle.life = particle.life - dt
            if particle.life <= 0 then
                table.remove(HEALING_PLUS_PARTICLES, i)
            end
        end
    end

    -- ========== 血液粒子更新 ==========
    for i = #bloodParticles, 1, -1 do
        local bp = bloodParticles[i]
        bp.x = bp.x + bp.vx * dt
        bp.y = bp.y + bp.vy * dt
        bp.vy = bp.vy + bp.gravity * dt
        bp.life = bp.life - dt
        if bp.life < 0.5 then
            bp.alpha = math.max(0, bp.life / 0.5 * 255)
        end
        -- 落地停住（用各自的 groundY）
        local bpGY = bp.groundY or (H * GROUND_Y_RATIO)
        if bp.y > bpGY + 5 then
            bp.y = bpGY + 5
            bp.vy = 0
            bp.vx = bp.vx * 0.8
        end
        if bp.life <= 0 then
            table.remove(bloodParticles, i)
        end
    end
end

-- ============================================================================
-- 引擎入口
-- ============================================================================
function Start()
    graphics.windowTitle = "末世搜寻"
    dpr = graphics:GetDPR()
    W = graphics:GetWidth() / dpr
    H = graphics:GetHeight() / dpr

    -- 每次进入游戏都强制关闭所有门，避免热重载或旧状态让门默认打开。
    for _, state in pairs(doorStates) do
        state.openProg = 0.0
        state.target = 0
    end
    for _, state in pairs(roomDoorStates) do
        state.openProg = 0.0
        state.target = 0
    end
    print("[Door] 所有门已重置为默认关闭")

    -- 移动端镜头拉远（dpr>=2 视为移动设备）
    if dpr >= 2 then
        SCENE_ZOOM = 0.38
    end

    -- 创建专用音频场景（纯NanoVG游戏需要自己的Scene来挂载SoundSource）
    audioScene = Scene()
    audioScene:CreateComponent("Octree")

    -- 循环雨声（末世氛围，保持模块级引用防GC）
    rainSoundRes = cache:GetResource("Sound", "audio/sfx/rain_ambience.ogg")
    if rainSoundRes then
        rainSoundRes.looped = true
        rainSrcNode = audioScene:CreateChild("RainAmbience")
        rainSrcComp = rainSrcNode:CreateComponent("SoundSource")
        rainSrcComp.soundType = SOUND_AMBIENT
        rainSrcComp.gain = 0.0
    end

    -- 背景音乐：末世搜刮氛围，低音量循环，避免盖过枪声和UI音效
    bgmSoundRes = cache:GetResource("Sound", "audio/music_1783777087047.ogg")
    if bgmSoundRes then
        bgmSoundRes.looped = true
        bgmSrcNode = audioScene:CreateChild("BackgroundMusic")
        bgmSrcComp = bgmSrcNode:CreateComponent("SoundSource")
        bgmSrcComp.soundType = SOUND_MUSIC
        bgmSrcComp.gain = 0.0
    else
        print("[Audio] WARNING: 背景音乐加载失败")
    end

    vg = nvgCreate(1)
    nvgCreateFont(vg, "sans", "Fonts/MiSans-Regular.ttf")
    HomeUI.Reset()

    -- 进入资源加载流程：用协程分帧加载所有资源，期间显示加载界面
    appState = "loading"
    loadProgress = 0
    loadStatusText = "正在加载音效..."
    downloadObserveStarted = false
    downloadsComplete = false
    initCo = coroutine.create(function()
    -- ── 阶段A：显式预下载所有媒体资源到本地，确保 nvgCreateImage 读到真实像素 ──
    local preloadUris = {}
    for _, p in ipairs(PRELOAD_RESOURCES) do table.insert(preloadUris, p) end
    for _, animCfg in pairs(PLAYER_ANIM_CONFIGS) do
        if animCfg ~= PLAYER_ANIM_CONFIGS.bat then
            for i = 1, animCfg.frameCount do
                table.insert(preloadUris, string.format(animCfg.pathPattern, i))
            end
            for _, pathPattern in pairs(animCfg.actionPathPatterns or {}) do
                for i = 1, animCfg.frameCount do
                    table.insert(preloadUris, string.format(pathPattern, i))
                end
            end
        end
    end
    for _, actionCfg in pairs(ZOMBIE_ANIM_CONFIG.actions) do
        for i = 1, actionCfg.frameCount do
            table.insert(preloadUris, string.format(actionCfg.pathPattern, i))
        end
    end
    -- 背包角色预览已复用当前武器序列帧，不再加载旧 Spine 角色依赖。

    local dlDone = false
    loadStatusText = "正在下载资源..."
    cache:DownloadResources(preloadUris,
        function(success, failedCount)
            dlDone = true
            if failedCount and failedCount > 0 then
                print("[Load] 资源下载完成，失败数: " .. tostring(failedCount))
            end
        end,
        function(completed, total, dlBytes, totalBytes)
            if total and total > 0 then
                loadProgress = 0.05 + 0.55 * (completed / total)
                loadStatusText = string.format("正在下载资源 %d/%d", completed, total)
            end
        end
    )
    -- 等待下载完成（每帧让出，加载界面持续刷新进度）
    while not dlDone do coroutine.yield() end

    ZOMBIE_GIB_IMAGES = {
        nvgCreateImage(vg, "image/卡通丧尸碎块_头部_20260725182041.png", 0),
        nvgCreateImage(vg, "image/卡通丧尸碎块_躯干_20260725182038.png", 0),
        nvgCreateImage(vg, "image/卡通丧尸碎块_手臂_20260725182048.png", 0),
        nvgCreateImage(vg, "image/卡通丧尸碎块_腿部_20260725182039.png", 0),
        nvgCreateImage(vg, "image/卡通丧尸碎块_衣物残片_20260725182039.png", 0),
    }

    -- 预加载音效到缓存（文件已下载到本地）
    cache:GetResource("Sound", "audio/sfx/gunshot.ogg")
    cache:GetResource("Sound", "audio/sfx/shotgun_blast.ogg")
    cache:GetResource("Sound", "audio/sfx/wooden_bat_attack.ogg")
    cache:GetResource("Sound", "audio/sfx/wooden_bat_swing_miss.ogg")
    cache:GetResource("Sound", "audio/sfx/pistol_reload.ogg")
    cache:GetResource("Sound", "audio/sfx/shotgun_reload.mp3")
    cache:GetResource("Sound", "audio/sfx/item_revealed.ogg")
    cache:GetResource("Sound", "audio/sfx/legendary_reveal_short.mp3")
    cache:GetResource("Sound", "audio/sfx/weapon_place_click_short.mp3")
    zombieGrowlSoundRes = cache:GetResource("Sound", "audio/sfx/zombie_idle_growl.ogg")
    zombieAttackSoundRes = cache:GetResource("Sound", "audio/sfx/zombie_attack_bite.ogg")
    zombieDeathSoundRes = cache:GetResource("Sound", "audio/sfx/zombie_death_groan.ogg")
    doorSoundRes = cache:GetResource("Sound", "audio/sfx/door_open_creak.ogg")
    loadProgress = 0.62
    loadStatusText = "正在加载场景资源..."
    coroutine.yield()

    trussImg  = nvgCreateImage(vg, "image/steel_truss_20260524135622.png", 0)
    ceilingLampImg = nvgCreateImage(vg, "image/ceiling_lamp.png", 0)
    if ceilingLampImg <= 0 then print("[CS] 警告: 天花灯图片加载失败") end
    ladderImg = nvgCreateImage(vg, "image/ladder_basement_20260524135555.png", 0)
    if ladderImg <= 0 then print("[CS] 警告: 楼梯图片加载失败") end
    basWinImg = nvgCreateImage(vg, "image/edited_basement_window_hd_20260524140353.png", 0)
    if basWinImg <= 0 then print("[CS] 警告: 地下室窗户图片加载失败") end
    basDoorImg  = nvgCreateImage(vg, "image/edited_basement_door_hd_20260524140332.png", 0)
    roomDoorImg = nvgCreateImage(vg, "image/edited_wooden_door_front_20260707040928.png", 0)
    roomDoorSideImg = nvgCreateImage(vg, "image/door_side_v2_20260621060845.png", 0)
    if roomDoorImg <= 0 then print("[CS] 警告: 正面房间门图片加载失败") end
    if roomDoorSideImg <= 0 then print("[CS] 警告: 侧向房间门图片加载失败") end
    steelDoorImg = nvgCreateImage(vg, "image/steel_door_side_20260621113254.png", 0)
    if steelDoorImg <= 0 then print("[CS] 警告: 钢门图片加载失败") end
    basCrateImg   = nvgCreateImage(vg, "image/basement_crate_20260524135552.png",   0)
    basBarrelImg  = nvgCreateImage(vg, "image/basement_barrel_20260524135543.png",  0)
    basShelfImg   = nvgCreateImage(vg, "image/basement_shelf_20260524135755.png",    0)
    basCardboxImg    = nvgCreateImage(vg, "image/basement_cardbox_20260524135712.png", 0)
    basWeaponRackImg = nvgCreateImage(vg, "image/basement_bag_rack_20260524135546.png", 0)
    basGearRackImg   = nvgCreateImage(vg, "image/basement_gear_rack_20260524135714.png", 0)
    lootUI.lootImgs.safe = nvgCreateImage(vg, "image/edited_正视图战术保险箱_20260731024424.png", 0)
    lootUI.lootImgs.nightstand = nvgCreateImage(vg, "image/edited_loot_nightstand_strict_front_final_20260718093912.png", 0)
    lootUI.drawerImg = nvgCreateImage(vg, "image/loot_drawer_strict_front_20260718080423.png", 0)
    if lootUI.drawerImg <= 0 then print("[LootUI] 警告: 正视角抽屉图片加载失败") end
    lootUI.lootImgs.medicine = nvgCreateImage(vg, "image/loot_medicine_cabinet_room_20260707053515.png", 0)
    lootUI.lootImgs.toolLocker = nvgCreateImage(vg, "image/loot_tool_locker_room_20260707053511.png", 0)
    roomDecorImgs = {
        sofa = nvgCreateImage(vg, "image/一楼左侧房间_末世沙发正视图_20260718130944.png", 0),
        tvCabinet = nvgCreateImage(vg, "image/一楼左侧房间_旧电视柜正视图_20260718130851.png", 0),
        coffeeTable = nvgCreateImage(vg, "image/一楼左侧房间_末世茶几正视图_20260718130907.png", 0),
        floorLamp = nvgCreateImage(vg, "image/一楼左侧房间_落地灯正视图_20260718130757.png", 0),
        plant = nvgCreateImage(vg, "image/一楼左侧房间_废弃绿植正视图_20260718130808.png", 0),
        motorcycle = nvgCreateImage(vg, "image/一楼左侧房间_末世摩托车侧面正视图_20260718141137.png", 0),
        workbench = nvgCreateImage(vg, "image/附楼摩托车房_维修工作台正视图_20260718145730.png", 0),
        toolCabinet = nvgCreateImage(vg, "image/附楼摩托车房_工具柜正视图_20260718145951.png", 0),
        tireRack = nvgCreateImage(vg, "image/附楼摩托车房_轮胎架正视图_20260718145717.png", 0),
        oilDrum = nvgCreateImage(vg, "image/附楼摩托车房_红色油桶正视图_20260718145736.png", 0),
        toolBoard = nvgCreateImage(vg, "image/附楼摩托车房_墙面工具板正视图_20260718145920.png", 0),
        wardrobe = nvgCreateImage(vg, "image/正视图_旧衣柜搜刮家具_20260718152219.png", 0),
        bookcase = nvgCreateImage(vg, "image/正视图_旧书架搜刮家具_20260718152424.png", 0),
        kitchenCabinet = nvgCreateImage(vg, "image/正视图_厨房储物柜搜刮家具_20260718152421.png", 0),
        metalLocker = nvgCreateImage(vg, "image/正视图_金属储物柜搜刮家具_20260718152229.png", 0),
        lootNightstand = nvgCreateImage(vg, "image/正视图_旧床头柜搜刮家具_20260718152300.png", 0),
        slimLocker = nvgCreateImage(vg, "image/卡通末世正视图窄边储物柜_20260720115649.png", 0),
        newNightstand = nvgCreateImage(vg, "image/卡通末世正视图床头柜_20260720115727.png", 0),
        displayCase = nvgCreateImage(vg, "image/卡通末世正视图玻璃展示柜_20260720115651.png", 0),
        toolDrawer = nvgCreateImage(vg, "image/卡通末世正视图工具抽屉柜_20260720115935.png", 0),
        modernSafe = nvgCreateImage(vg, "image/卡通末世小型现代保险柜正视图_20260720121641.png", 0),
        modernFileSafe = nvgCreateImage(vg, "image/卡通末世小型现代文件保险柜正视图_20260720121840.png", 0),
        modernJewelrySafe = nvgCreateImage(vg, "image/卡通末世小型现代珠宝保险柜正视图_20260720121839.png", 0),
        cs2Bedroom = nvgCreateImage(vg, "image/第二栋楼_卧室家具组合正视图_20260725033547.png", 0),
        cs2Storage = nvgCreateImage(vg, "image/第二栋楼_储物间家具组合正视图_20260725033546.png", 0),
        cs2Laundry = nvgCreateImage(vg, "image/第二栋楼_洗衣区家具组合正视图_20260725033550.png", 0),
        cs2Bathroom = nvgCreateImage(vg, "image/第二栋楼_卫生间家具组合正视图_20260725033542.png", 0),
        cs2Living = nvgCreateImage(vg, "image/第二栋楼_客厅家具组合正视图_20260725033543.png", 0),
        cs2Study = nvgCreateImage(vg, "image/第二栋楼_书房家具组合正视图_20260725033545.png", 0),
        cs2BlueBedroom = nvgCreateImage(vg, "image/第二栋楼_蓝色卧室家具组合正视图_20260725033744.png", 0),
        cs2Dining = nvgCreateImage(vg, "image/第二栋楼_餐厅家具组合正视图_20260725033539.png", 0),
        cs2Kitchen = nvgCreateImage(vg, "image/第二栋楼_厨房家具组合正视图_20260725033545.png", 0),
        cs2Shop = nvgCreateImage(vg, "image/第二栋楼_便民店家具组合正视图_20260725033748.png", 0),
        cs2Office = nvgCreateImage(vg, "image/第二栋楼_管理室家具组合正视图_20260725033542.png", 0),
        cs2Workshop = nvgCreateImage(vg, "image/第二栋楼_维修间家具组合正视图_20260725033752.png", 0),
        streetSupermarketFurniture = nvgCreateImage(vg, "image/外部废弃超市_室内家具组合正视图_20260725052455.png", 0),
        streetWarehouseFurniture = nvgCreateImage(vg, "image/外部旧仓库_室内家具组合正视图_20260725051417.png", 0),
        streetPharmacyFurniture = nvgCreateImage(vg, "image/外部街角药店_室内家具组合正视图_20260725051413.png", 0),
        shopCounter = nvgCreateImage(vg, "image/一楼右侧小卖部_整洁收银台严格正视图_20260719073315.png", 0),
        shopDisplayCase = nvgCreateImage(vg, "image/一楼右侧小卖部_整洁展示柜严格正视图_20260719073304.png", 0),
        shopDrinkCooler = nvgCreateImage(vg, "image/一楼右侧小卖部_整洁饮料冷柜严格正视图_20260719073306.png", 0),
        shopBaskets = nvgCreateImage(vg, "image/一楼右侧小卖部_整洁购物篮严格正视图_20260719073302.png", 0),
        wallBloodFan = nvgCreateImage(vg, "image/墙面血迹_高速扇形喷溅_20260719075954_clean.png", 0),
        wallBloodBurst = nvgCreateImage(vg, "image/墙面血迹_双向爆裂喷溅_20260719075959_clean.png", 0),
        wallBloodDrip = nvgCreateImage(vg, "image/墙面血迹_大片撞击流淌_20260719075953_clean.png", 0),
        wallBloodMist = nvgCreateImage(vg, "image/墙面血迹_密集细小飞溅_20260719075944_clean.png", 0),
    }
    lootUI.letterImg = nvgCreateImage(vg, "image/卡通末世折叠信件_20260719052833.png", 0)
    lootUI.letterPaperImg = nvgCreateImage(vg, "image/edited_手机宽版末世信纸背景_20260720045833.png", 0)

    -- 加载物品图标
    flashlightIconImg = nvgCreateImage(vg, "image/flashlight_icon_20260603082359.png", 0)
    loadingSpinnerImg = nvgCreateImage(vg, "image/magnifying_glass_icon_20260609105102.png", 0)
    backpackTier2Img = nvgCreateImage(vg, "image/backpack_tier2_20260718072219.png", 0)
    if backpackTier2Img <= 0 then print("[LootUI] 警告: 二级背包图片加载失败") end
    -- 加载所有物品图标
    local itemIconPaths = {
        ["劳力士金表"] = "image/卡通末世物资_金表_20260723024804.png",
        ["翡翠原石"]   = "image/仓库翡翠原石风格物资_20260813045549_clean.png",
        ["金条"]       = "image/仓库金条风格物资_20260813045541_clean.png",
        ["钻石项链"]   = "image/卡通末世物资_钻石项链_20260723024811.png",
        ["古董花瓶"]   = "image/仓库古董花瓶风格物资_20260813045540_clean.png",
        ["名牌手包"]   = "image/卡通末世物资_名牌手包_20260723024810.png",
        ["银币收藏"]   = "image/卡通末世物资_银币收藏_20260723024808.png",
        ["红酒82年"]   = "image/卡通末世物资_红酒_20260723024809.png",
        ["珍珠耳环"]   = "image/卡通末世物资_珍珠耳环_20260723024822.png",
        ["象牙雕件"]   = "image/卡通末世物资_象牙雕件_20260723024922.png",
        ["机械键盘"]   = "image/卡通末世物资_机械键盘_20260723024924.png",
        ["平板电脑"]   = "image/仓库军用平板风格物资_20260813045546_clean.png",
        ["铜戒指"]     = "image/卡通末世物资_铜戒指_20260723024935.png",
        ["旧手机"]     = "image/卡通末世物资_旧手机_20260723024920.png",
        ["打火机"]     = "image/卡通末世物资_打火机_20260723024934.png",
        ["罐头"]       = "image/卡通末世物资_罐头_20260723024928.png",
        ["螺丝刀"]     = "image/卡通末世物资_螺丝刀_20260723024920.png",
        ["电池"]       = "image/卡通末世物资_电池_20260723024935.png",
        ["急救包"]     = "image/卡通末世急救包严格正视图_20260723130308.png",
        ["净水"]       = "image/卡通末世物资_净水_20260723025045.png",
        ["成捆现金"]   = "image/卡通末世物资_成捆现金_20260723025056.png",
        ["胶带"]       = "image/卡通末世物资_胶带_20260723025045.png",
        ["扳手"]       = "image/卡通末世物资_扳手_20260723025047.png",
        ["香槟酒"]     = "image/edited_黄金收藏香槟正视图无文字_20260729101256.png",
        ["高级香烟"]   = "image/卡通末世物资_高级香烟_20260723025041.png",
        ["名贵香水"]   = "image/卡通末世物资_名贵香水_20260723025039.png",
        ["加密硬盘"]   = "image/卡通风加密固态硬盘搜刮物品_20260718162139.png",
        ["军用望远镜"] = "image/卡通风军用望远镜搜刮物品_放大_20260723030500.png",
        ["卫星电话"]   = "image/卡通风卫星电话搜刮物品_20260718162141.png",
        ["古董相机"]   = "image/卡通风古董相机搜刮物品_20260718162145.png",
        ["铂金打火机"] = "image/卡通风铂金打火机搜刮物品_20260718162138.png",
        ["高级太阳镜"] = "image/卡通风高级太阳镜搜刮物品_20260718162144.png",
        ["古董指南针"] = "image/卡通风古董指南针搜刮物品_20260718162142.png",
        ["稀有咖啡豆"] = "image/卡通风稀有咖啡豆搜刮物品_20260718162158.png",
        ["收藏金币"]   = "image/卡通风收藏金币搜刮物品_20260718162138.png",
        ["红宝石戒指"] = "image/卡通风红宝石戒指搜刮物品_20260718162146.png",
        ["显卡"]   = "image/edited_漫画版三风扇旗舰显卡_横放_20260730120508.png",
        ["黄金半身像"] = "image/edited_卡通末世顶级物资_黄金半身像_无底座_20260730121826.png",
        ["军用加固笔记本"] = "image/卡通末世顶级物资_军用笔记本_20260723030223.png",
        ["机密生物样本"] = "image/物资_机密生物样本_20260728061821.png",
        ["军用热成像仪"] = "image/物资_军用热成像仪_20260728061811.png",
        ["黄金纪念怀表"] = "image/物资_黄金纪念怀表_20260728061824.png",
        ["稀有邮票册"] = "image/物资_稀有邮票册_20260728061826.png",
        ["高纯度钯金块"] = "image/物资_高纯度钯金块_20260728061815.png",
        ["加密无人机核心"] = "image/物资_加密无人机核心_20260728061827.png",
        ["精密光学模组"] = "image/物资_精密光学模组_20260728061822.png",
        ["绝版游戏卡带"] = "image/物资_绝版游戏卡带_20260728061821.png",
        ["名厂机械腕表"] = "image/物资_名厂机械腕表_20260728061820.png",
        ["航空级控制芯片"] = "image/物资_航空级控制芯片_20260728061833.png",
        ["手枪"]       = "image/pistol_icon_20260711113020.png",
        ["散弹枪"]     = "image/卡通末世双管折管散弹枪物品_20260725160700.png",
        ["手枪弹药盒"] = "image/手枪弹药盒_20260801074149.png",
        ["散弹枪弹药包"] = "image/散弹枪弹药包_20260801074017.png",
        ["棒球棍"]     = "image/barbed_bat_icon_20260711122737.png",
        ["二级头盔"]   = "image/二级头盔_20260727073512.png",
        ["二级防弹衣"] = "image/二级防弹衣_20260727114218.png",
        ["二级胸挂"]   = "image/二级胸挂_20260727073514.png",
        ["二级背包"]   = "image/backpack_tier2_20260718072219.png",
        ["二级安全箱"] = "image/高级战术安全箱_20260731060159.png",
        ["三级安全箱"] = "image/三级红色战术安全箱_20260731125534.png",
        ["通用战术消音器"] = "image/黑市通用战术消音器_20260809100641.png",
    }
    for name, path in pairs(itemIconPaths) do
        itemIcons[name] = nvgCreateImage(vg, path, 0)
    end
    blackMarketArt.broker = nvgCreateImage(vg, "image/黑市商人渡鸦肖像_20260809093215.png", 0)
    blackMarketArt.tunnel_intel = nvgCreateImage(vg, "image/地下管道撤离情报地图_20260809093224.png", 0)
    blackMarketArt.lab_keycard = nvgCreateImage(vg, "image/伪造实验室门禁卡_20260809093213.png", 0)
    blackMarketArt.suppressor = nvgCreateImage(vg, "image/黑市通用战术消音器_20260809100641.png", 0)
    blackMarketArt.weapon_insurance = nvgCreateImage(vg, "image/黑市武器保险券_20260809100637.png", 0)
    print("[BlackMarket] 专用图片加载: broker=" .. tostring(blackMarketArt.broker)
        .. " map=" .. tostring(blackMarketArt.tunnel_intel)
        .. " keycard=" .. tostring(blackMarketArt.lab_keycard)
        .. " suppressor=" .. tostring(blackMarketArt.suppressor)
        .. " insurance=" .. tostring(blackMarketArt.weapon_insurance))
    loadProgress = 0.7
    loadStatusText = "正在加载建筑资源..."
    coroutine.yield()

    -- 加载麦当劳建筑图片
    mcdonaldsImg = nvgCreateImage(vg, "image/mcdonalds_trimmed.png", 0)
    if mcdonaldsImg > 0 then
        print("[Scene] 麦当劳图片加载成功")
    else
        print("[Scene] 警告: 麦当劳图片加载失败")
    end
    -- 加载铁网栏和路灯图片
    fenceImg = nvgCreateImage(vg, "image/fence_trimmed.png", 0)
    lampImg  = nvgCreateImage(vg, "image/lamp_trimmed.png", 0)
    messyTrashBinImg = nvgCreateImage(vg, "image/末世混乱垃圾桶_20260729024640.png", 0)
    potImg1  = nvgCreateImage(vg, "image/大盆栽_棕榈_20260531092818.png", 0)
    potImg2  = nvgCreateImage(vg, "image/大盆栽_琴叶榕_20260531092830.png", 0)
    potImg3  = nvgCreateImage(vg, "image/大盆栽_三角梅_20260531092816.png", 0)
    umbrellaImg = nvgCreateImage(vg, "image/阳台太阳伞_20260531103728.png", 0)
    chairImg    = nvgCreateImage(vg, "image/阳台休闲椅_20260531103729.png", 0)
    -- 卫生间家具（复刻参考图 - 各楼层差异化）
    bathroomImg4F = nvgCreateImage(vg, "image/卫生间全景_20260531120248.png", 0)
    bathroomImg3F = nvgCreateImage(vg, "image/卫生间3F_20260531121422.png", 0)
    bathroomImg2F = nvgCreateImage(vg, "image/卫生间2F_20260531121402.png", 0)
    -- 厨房家具（各楼层差异化）
    kitchenImg4F = nvgCreateImage(vg, "image/厨房4F_20260531133453.png", 0)
    kitchenImg3F = nvgCreateImage(vg, "image/厨房3F_20260531133511.png", 0)
    kitchenImg2F = nvgCreateImage(vg, "image/厨房2F_20260531133447.png", 0)
    -- 工具房（5F）
    toolRoomImg = nvgCreateImage(vg, "image/工具房5F_20260531135113.png", 0)
    -- 客厅家具（各楼层差异化）
    livingImg4F = nvgCreateImage(vg, "image/客厅4F_20260531134528.png", 0)
    livingImg3F = nvgCreateImage(vg, "image/客厅3F_20260531134542.png", 0)
    livingImg2F = nvgCreateImage(vg, "image/客厅2F_20260531134532.png", 0)
    livingImg1F = nvgCreateImage(vg, "image/客厅1F_20260531134910.png", 0)
    -- 天台装饰物图片
    terraceSolarImg   = nvgCreateImage(vg, "image/天台太阳能板_20260602090719.png", 0)
    terraceRailImg    = nvgCreateImage(vg, "image/天台围栏_20260602090713.png", 0)
    terraceTableImg   = nvgCreateImage(vg, "image/天台桌椅_20260602090711.png", 0)
    terracePlantsImg  = nvgCreateImage(vg, "image/天台花盆组合_20260602090730.png", 0)
    terraceUmbrellaImg = nvgCreateImage(vg, "image/天台遮阳伞_20260602090728.png", 0)
    print("[Scene] 铁网栏=" .. tostring(fenceImg) .. " 路灯=" .. tostring(lampImg))

    -- 加载玩家角色与首页行动终端图片
    playerImg = nvgCreateImage(vg, "image/player_char.png", 0)
    blackMarketArt.home_crisis = nvgCreateImage(vg, "image/远望日本沦陷城市_20260811103414.png", 0)
    blackMarketArt.home_survivor = nvgCreateImage(vg,
        "image/首页空手幸存者立绘_20260811135500.png", 0)
    blackMarketArt.home_national_map = nvgCreateImage(vg,
        "image/首页日本全国感染态势图_20260811135348.png", 0)
    blackMarketArt.home_location = nvgCreateImage(vg,
        "image/首页东京废弃城区预览_20260811135412.png", 0)
    blackMarketArt.home_master = nvgCreateImage(vg,
        "image/首页设计稿母版.png", 0)
    blackMarketArt.warehouse_master = nvgCreateImage(vg,
        "image/warehouse/据点仓库设计稿母版.png", 0)
    blackMarketArt.warehouse_cells = {
        red2x2 = nvgCreateImage(vg,
            "image/warehouse/item_cells/物资格_红色传说_2x2.png", 0),
        gold2x1 = nvgCreateImage(vg,
            "image/warehouse/item_cells/物资格_金色传说_2x1.png", 0),
        pink2x2 = nvgCreateImage(vg,
            "image/warehouse/item_cells/物资格_粉色史诗_2x2.png", 0),
        purple2x1 = nvgCreateImage(vg,
            "image/warehouse/item_cells/物资格_紫色稀有_2x1.png", 0),
        blue1x1 = nvgCreateImage(vg,
            "image/warehouse/item_cells/物资格_蓝色精良_1x1.png", 0),
        green1x1 = nvgCreateImage(vg,
            "image/warehouse/item_cells/物资格_绿色普通_1x1.png", 0),
    }
    blackMarketArt.shop_design = {
        header = nvgCreateImage(vg, "image/shop_design/顶部完整条.png", 0),
        categories = nvgCreateImage(vg, "image/shop_design/左侧分类金属外框.png", 0),
        frameTop = nvgCreateImage(vg, "image/shop_design/中央外框顶.png", 0),
        frameBottom = nvgCreateImage(vg, "image/shop_design/中央外框底.png", 0),
        frameLeft = nvgCreateImage(vg, "image/shop_design/中央外框左.png", 0),
        frameRight = nvgCreateImage(vg, "image/shop_design/中央外框右.png", 0),
        edgeLeft = nvgCreateImage(vg, "image/shop_design/边缘_左.png", 0),
        categoryGap = nvgCreateImage(vg, "image/shop_design/间隔_分类中央.png", 0),
        detailGap = nvgCreateImage(vg, "image/shop_design/间隔_中央档案.png", 0),
        edgeRight = nvgCreateImage(vg, "image/shop_design/边缘_右.png", 0),
        cardGapOne = nvgCreateImage(vg, "image/shop_design/商品列间隔_一.png", 0),
        cardGapTwo = nvgCreateImage(vg, "image/shop_design/商品列间隔_二.png", 0),
        cardRowGap = nvgCreateImage(vg, "image/shop_design/商品行间隔.png", 0),
        footer = nvgCreateImage(vg, "image/shop_design/底部背景条.png", 0),
        detailFrame = nvgCreateImage(vg, "image/shop_design/右侧军需档案_动态底板.png", 0),
        categoryButton = {
            active = nvgCreateImage(vg, "image/shop_design/sidebar/按钮_选中空白.png", 0),
            inactive = nvgCreateImage(vg, "image/shop_design/sidebar/按钮_未选中空白.png", 0),
        },
        categoryIcons = { active = {}, inactive = {} },
        cardTemplates = {
            blue = nvgCreateImage(vg, "image/shop_design/cards/卡片底板_蓝色.png", 0),
            purple = nvgCreateImage(vg, "image/shop_design/cards/卡片底板_紫色.png", 0),
            green = nvgCreateImage(vg, "image/shop_design/cards/卡片底板_绿色.png", 0),
        },
    }
    for _, categoryId in ipairs({ "guns", "ammo", "armor", "helmets", "rigs", "backpacks", "safe_boxes" }) do
        blackMarketArt.shop_design.categoryIcons.active[categoryId] = nvgCreateImage(vg,
            "image/shop_design/sidebar/图标_深色_" .. categoryId .. ".png", 0)
        blackMarketArt.shop_design.categoryIcons.inactive[categoryId] = nvgCreateImage(vg,
            "image/shop_design/sidebar/图标_浅色_" .. categoryId .. ".png", 0)
    end
    blackMarketArt.home_layers = {
        background = nvgCreateImage(vg, "image/home_layers/首页背景_无UI.png", 0),
        logo = nvgCreateImage(vg, "image/home_layers/首页Logo.png", 0),
        survivorFrame = nvgCreateImage(vg, "image/home_layers/面板边框_角色.png", 0),
        mapFrame = nvgCreateImage(vg, "image/home_layers/面板边框_态势地图.png", 0),
        locationFrame = nvgCreateImage(vg, "image/home_layers/面板边框_地图情报.png", 0),
        topChip = nvgCreateImage(vg, "image/home_layers/顶部信息条背景.png", 0),
        navButton = nvgCreateImage(vg, "image/home_layers/底部导航按钮背景.png", 0),
        equipButton = nvgCreateImage(vg, "image/home_layers/战前整备按钮背景.png", 0),
        changeMapButton = nvgCreateImage(vg, "image/home_layers/更换地图按钮背景.png", 0),
        deployButton = nvgCreateImage(vg, "image/home_layers/进入地图按钮背景.png", 0),
    }
    print("[Home] 设计稿拆件已加载 主面板="
        .. tostring(blackMarketArt.home_layers.locationFrame)
        .. " 母版组件源=" .. tostring(blackMarketArt.home_master)
        .. " 按钮=" .. tostring(blackMarketArt.home_layers.deployButton))
    if playerImg > 0 then
        print("[Player] 角色图片加载成功")
    else
        print("[Player] 警告: 角色图片加载失败")
    end

    -- 加载玩家动作序列帧（手枪/棒球棍两套，运行时可切换）
    for animName, animCfg in pairs(PLAYER_ANIM_CONFIGS) do
        if animName == "bat" then
            animCfg.frames = {}
            animCfg.actionFrames = nil
            print("[DemoAnim] bat 使用延迟加载，跳过启动阶段图片")
        elseif animName == "shotgun" then
            animCfg.frames = {}
            animCfg.actionFrames = nil
            animCfg.deadFrames = nil
            SHOTGUN_ANIM_LOADED = false
            SHOTGUN_ANIM_LOADING = false
            print("[DemoAnim] shotgun 使用延迟加载，跳过启动阶段图片")
        elseif animName == "climb" then
            animCfg.frames = {}
            local loadedFrames = 0
            for i = 1, animCfg.frameCount do
                local path = string.format(animCfg.pathPattern, i)
                local img = nvgCreateImage(vg, path, 0)
                animCfg.frames[i] = img
                if img > 0 then loadedFrames = loadedFrames + 1 end
            end
            print("[DemoAnim] climb 启动加载: " .. tostring(loadedFrames) .. "/" .. tostring(animCfg.frameCount))
        else
        local loadedFrames = 0
        -- 加载基础动作帧；散弹枪的每个动作使用独立序列帧目录。
        if animCfg.actionPathPatterns then
            animCfg.actionFrames = {}
            for actionName, pathPattern in pairs(animCfg.actionPathPatterns) do
                animCfg.actionFrames[actionName] = {}
                local actionLoaded = 0
                for i = 1, animCfg.frameCount do
                    local path = string.format(pathPattern, i)
                    local img = nvgCreateImage(vg, path, 0)
                    animCfg.actionFrames[actionName][i] = img
                    if img > 0 then
                        actionLoaded = actionLoaded + 1
                    end
                end
                if actionName == "walk" then
                    animCfg.frames = animCfg.actionFrames[actionName]
                end
                print("[DemoAnim] " .. animName .. " " .. actionName .. "帧加载: " .. tostring(actionLoaded) .. "/" .. tostring(animCfg.frameCount))
            end
            loadedFrames = #(animCfg.frames or {})
        else
            for i = 1, animCfg.frameCount do
                local path = string.format(animCfg.pathPattern, i)
                local img = nvgCreateImage(vg, path, 0)
                animCfg.frames[i] = img
                if img > 0 then
                    loadedFrames = loadedFrames + 1
                end
            end
        end
        -- 持枪受击动作复用用户指定的无枪受击序列帧 111-117。
        if animCfg.hurtPathPattern then
            animCfg.hurtFrames = {}
            for i = animCfg.hurtStart, animCfg.hurtEnd do
                local path = string.format(animCfg.hurtPathPattern, i)
                animCfg.hurtFrames[i] = nvgCreateImage(vg, path, 0)
            end
        end
        if animCfg.deadPathPattern then
            animCfg.deadFrames = {}
            for i = animCfg.deadStart, animCfg.deadEnd do
                local path = string.format(animCfg.deadPathPattern, i)
                animCfg.deadFrames[i] = nvgCreateImage(vg, path, 0)
            end
        end
        print("[DemoAnim] " .. animName .. " 动作序列帧加载: " .. tostring(loadedFrames) .. "/" .. tostring(animCfg.frameCount))
        end
    end
    PLAYER_ANIM_CONFIGS.shotgun.deadFrames = PLAYER_ANIM_CONFIGS.gun.deadFrames or {}
    BAT_DEMO_ANIM = PLAYER_ANIM_CONFIGS[PLAYER_ANIM_SET]

    -- 加载新丧尸动作序列帧（五套动作目录：idle/run/attack/hurt/dead）
    local zombieTotalFrames = 0
    local zombieLoadedFrames = 0
    for actionName, actionCfg in pairs(ZOMBIE_ANIM_CONFIG.actions) do
        actionCfg.frames = {}
        local actionLoaded = 0
        for i = 1, actionCfg.frameCount do
            local path = string.format(actionCfg.pathPattern, i)
            local img = nvgCreateImage(vg, path, 0)
            actionCfg.frames[i] = img
            zombieTotalFrames = zombieTotalFrames + 1
            if img > 0 then
                actionLoaded = actionLoaded + 1
                zombieLoadedFrames = zombieLoadedFrames + 1
            end
        end
        print("[ZombieAnim] " .. actionName .. " 帧加载: " .. tostring(actionLoaded) .. "/" .. tostring(actionCfg.frameCount))
    end
    print("[ZombieAnim] 新丧尸动作总帧加载: " .. tostring(zombieLoadedFrames) .. "/" .. tostring(zombieTotalFrames))

    if basDoorImg <= 0 then print("[CS] 警告: 地下室门图片加载失败") end

    loadProgress = 0.8
    loadStatusText = "正在初始化游戏..."
    coroutine.yield()

    initPlayer()

    initParticles()
    initCrossSection()
    setDefaultRoomLights()
    initRain()
    spawnInitialZombies()

    -- 初始化虚拟摇杆（PC端键盘自动生效，移动端显示触摸摇杆）
    GameHUD.Initialize()
    local hud = GameHUD.Create({ enableJump = false, enableCrouch = false })
    joystick_ = hud.joystick

    -- 开门按钮改由主 NanoVG HUD 绘制和命中，保留状态表避免默认圆形按钮抢占位置。
    descendBtn_ = { _shouldShow = false }

    -- 开门按钮（靠近门时显示，绑定 F 键）
    doorBtn_ = { _shouldShow = false }

    -- 灯光开关只保留独立 NanoVG 按钮，避免和虚拟按钮重复显示；PC 仍可用 L 键切换
    lightSwitchBtn_ = nil
    lightSwitchPressed_ = false

    -- 上楼按钮（门打开时显示，绑定 W 键）
    upBtn_ = VirtualControls.CreateButton({
        position = Vector2(-80, -350),
        alignment = {HA_RIGHT, VA_BOTTOM},
        radius = 40,
        label = "↑",
        keyBinding = "W",
        opacity = 0.6,
        activeOpacity = 0.95,
        alwaysShow = true,
        color = {80, 255, 150},
        pressedColor = {150, 255, 200},
        on_press = function()
            upPressed_ = true
        end,
    })
    upBtn_._shouldShow = false  -- 默认隐藏

    -- 下楼按钮（门打开时显示，绑定 S 键）
    downBtn_ = VirtualControls.CreateButton({
        position = Vector2(-280, -280),
        alignment = {HA_RIGHT, VA_BOTTOM},
        radius = 40,
        label = "↓",
        keyBinding = "S",
        opacity = 0.6,
        activeOpacity = 0.95,
        alwaysShow = true,
        color = {255, 200, 80},
        pressedColor = {255, 230, 150},
        on_press = function()
            downPressed_ = true
        end,
    })
    downBtn_._shouldShow = false  -- 默认隐藏

    -- 搜刮按钮改由主 NanoVG HUD 绘制和命中，避免默认虚拟圆按钮限制视觉样式。
    lootBtn_ = { _shouldShow = false }

    loadProgress = 0.88
    loadStatusText = "正在加载角色动画..."
    coroutine.yield()

    -- ── 世界主角改用球棍序列帧，跳过 Spine 主角实例 ──
    spineInstance = nil
    muzzleBone = nil
    muzzleScreenX = 0
    muzzleScreenY = 0
    muzzleAngle = 0
    print("[Player] 世界主角使用球棍序列帧动画")

    -- 背包角色预览复用当前武器序列帧，无需创建额外 Spine 实例。
    spineUIInstance = nil

    loadProgress = 0.95
    loadStatusText = "即将进入游戏..."
    end)  -- ── 资源加载协程定义结束 ──

    SubscribeToEvent(vg, "NanoVGRender", "HandleNanoVGRender")
    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("MouseButtonDown", "HandleMouseDown")
    SubscribeToEvent("MouseButtonUp",   "HandleMouseUp")
    SubscribeToEvent("MouseMove",       "HandleMouseMove")
    SubscribeToEvent("TouchBegin",      "HandleTouchBegin")
    SubscribeToEvent("TouchMove",       "HandleTouchMove")
    SubscribeToEvent("TouchEnd",        "HandleTouchEnd")
    print("=== 末世搜寻 - 丧尸世界 ===")
end

function handleHomeAction(action)
    if action == "equip" then
        openLoadoutPanel()
        print("[Home] 打开装备界面")
    elseif action == "deploy" then
        playHomeUISound("deploy")
        confirmLoadout()
        print("[Home] 使用当前装备出战")
    elseif action == "change-map" then
        playHomeUISound("tab")
        HomeUI.SetNotice("当前版本仅开放：东京废弃城区", 2.8)
        print("[Home] 地图选择：当前仅开放东京废弃城区")
    elseif action == "blackmarket" then
        playHomeUISound("tab")
        openBlackMarketPanel()
        print("[Home] 打开黑市交易终端")
    elseif action == "shop" then
        playHomeUISound("tab")
        openShopPanel()
        print("[Home] 打开战术补给商城")
    elseif action == "warehouse" then
        playHomeUISound("warehouse")
        lootUI.CleanupTakenEntries(warehouseTabs[1].items)
        appState = "warehouse"
        WarehouseUI.Open(warehouseTabs)
        print("[Home] 打开独立据点仓库")
    elseif action == "codex" then
        playHomeUISound("tab")
        appState = "codex"
        CodexUI.Open()
        print("[Codex] 打开物资图片图鉴")
    elseif action then
        playHomeUISound("tab")
        print("[Home] 切换首页页签: " .. tostring(action))
    end
end

function HandleTouchBegin(eventType, eventData)
    if appState ~= "home" and appState ~= "warehouse" and appState ~= "shop"
        and appState ~= "codex" and appState ~= "blackmarket" then return end
    local touchId = eventData:GetInt("TouchID")
    local x = eventData:GetInt("X") / dpr
    local y = eventData:GetInt("Y") / dpr
    if appState == "home" then
        HomeUI.PointerDown(x, y)
    elseif appState == "blackmarket" then
        BlackMarketUI.TouchBegin(touchId, x, y)
    elseif appState == "shop" then
        ShopUI.TouchBegin(touchId, x, y)
    elseif appState == "codex" then
        CodexUI.TouchBegin(touchId, x, y)
    else
        WarehouseUI.TouchBegin(touchId, x, y)
    end
end

function HandleTouchMove(eventType, eventData)
    if appState ~= "home" and appState ~= "warehouse" and appState ~= "shop"
        and appState ~= "codex" and appState ~= "blackmarket" then return end
    if appState == "home" then return end
    local touchId = eventData:GetInt("TouchID")
    local x = eventData:GetInt("X") / dpr
    local y = eventData:GetInt("Y") / dpr
    if appState == "blackmarket" then
        BlackMarketUI.TouchMove(touchId, x, y)
    elseif appState == "shop" then
        ShopUI.TouchMove(touchId, x, y)
    elseif appState == "codex" then
        CodexUI.TouchMove(touchId, x, y)
    else
        WarehouseUI.TouchMove(touchId, x, y)
    end
end

function HandleTouchEnd(eventType, eventData)
    if appState ~= "home" and appState ~= "warehouse" and appState ~= "shop"
        and appState ~= "codex" and appState ~= "blackmarket" then return end
    local touchId = eventData:GetInt("TouchID")
    local x = eventData:GetInt("X") / dpr
    local y = eventData:GetInt("Y") / dpr
    if appState == "home" then
        handleHomeAction(HomeUI.PointerUp(x, y))
        return
    elseif appState == "blackmarket" then
        handleBlackMarketAction(BlackMarketUI.TouchEnd(touchId, x, y))
        return
    elseif appState == "shop" then
        handleShopAction(ShopUI.TouchEnd(touchId, x, y))
        return
    elseif appState == "codex" then
        local action = CodexUI.TouchEnd(touchId, x, y)
        if action == "back" then
            appState = "home"
            HomeUI.Reset()
            print("[Codex] 触摸返回据点首页")
        end
        return
    end
    local action = WarehouseUI.TouchEnd(touchId, x, y)
    if action == "back" then
        appState = "home"
        HomeUI.Reset()
        print("[Warehouse] 触摸返回据点首页")
    elseif action == "move" or action == "upgrade" or action == "rotate" then
        BlackMarketCloud.MarkDirty("warehouse_" .. action, false)
        print("[Warehouse] 触摸仓库状态已更新: " .. action)
    end
end

function HandleMouseDown(eventType, eventData)
    if eventData:GetInt("Button") == MOUSEB_LEFT then
        local x = eventData:GetInt("X") / dpr
        local y = eventData:GetInt("Y") / dpr
        if appState == "home" then
            HomeUI.PointerDown(x, y)
            return
        elseif appState == "blackmarket" then
            if not BlackMarketUI.ShouldIgnoreMouse() then BlackMarketUI.PointerDown(x, y) end
            return
        elseif appState == "shop" then
            if not ShopUI.ShouldIgnoreMouse() then ShopUI.PointerDown(x, y) end
            return
        elseif appState == "loadout" then
            return
        elseif appState == "warehouse" then
            if not WarehouseUI.ShouldIgnoreMouse() then WarehouseUI.PointerDown(x, y) end
            return
        elseif appState == "codex" then
            if not CodexUI.ShouldIgnoreMouse() then CodexUI.PointerDown(x, y) end
            return
        end
        if drag.enabled then drag.active = true end
    end
end

function HandleMouseUp(eventType, eventData)
    if eventData:GetInt("Button") == MOUSEB_LEFT then
        local x = eventData:GetInt("X") / dpr
        local y = eventData:GetInt("Y") / dpr
        if appState == "home" then
            handleHomeAction(HomeUI.PointerUp(x, y))
            return
        elseif appState == "blackmarket" then
            if not BlackMarketUI.ShouldIgnoreMouse() then
                handleBlackMarketAction(BlackMarketUI.PointerUp(x, y))
            end
            return
        elseif appState == "shop" then
            if not ShopUI.ShouldIgnoreMouse() then
                handleShopAction(ShopUI.PointerUp(x, y))
            end
            return
        elseif appState == "loadout" then
            return
        elseif appState == "warehouse" then
            if WarehouseUI.ShouldIgnoreMouse() then return end
            local action = WarehouseUI.PointerUp(x, y)
            if action == "back" then
                appState = "home"
                HomeUI.Reset()
                print("[Warehouse] 返回据点首页")
            elseif action == "move" or action == "upgrade" or action == "rotate" then
                BlackMarketCloud.MarkDirty("warehouse_" .. action, false)
                print("[Warehouse] 仓库状态已更新: " .. action)
            end
            return
        elseif appState == "codex" then
            if CodexUI.ShouldIgnoreMouse() then return end
            local action = CodexUI.PointerUp(x, y)
            if action == "back" then
                appState = "home"
                HomeUI.Reset()
                print("[Codex] 返回据点首页")
            end
            return
        end
        drag.active = false
        drag.cooldown = 1.2
    end
end

function HandleMouseMove(eventType, eventData)
    local x = eventData:GetInt("X") / dpr
    local y = eventData:GetInt("Y") / dpr
    if appState == "home" then
        HomeUI.PointerMove(x, y)
        return
    elseif appState == "blackmarket" then
        if not BlackMarketUI.ShouldIgnoreMouse() then BlackMarketUI.PointerMove(x, y) end
        return
    elseif appState == "shop" then
        if not ShopUI.ShouldIgnoreMouse() then ShopUI.PointerMove(x, y) end
        return
    elseif appState == "loadout" then
        return
    elseif appState == "warehouse" then
        if not WarehouseUI.ShouldIgnoreMouse() then WarehouseUI.PointerMove(x, y) end
        return
    elseif appState == "codex" then
        if not CodexUI.ShouldIgnoreMouse() then CodexUI.PointerMove(x, y) end
        return
    end
    if drag.enabled and drag.active then
        local dx = eventData:GetInt("DX") / dpr
        local dy = eventData:GetInt("DY") / dpr
        cameraX = clamp(cameraX - dx, 0, STREET_LENGTH - W)
        cameraY = clamp(cameraY + dy, -500, 1500)
    end
end

function Stop()
    if BlackMarketCloud.dirty and BlackMarketCloud.loadComplete then
        BlackMarketCloud.Flush()
    end
    if vg then nvgDelete(vg); vg = nil end
end

function startGameAudio()
    if bgmStarted then return end
    bgmStarted = true
    if rainSrcComp and rainSoundRes then
        rainSrcComp.gain = 0.35
        rainSrcComp:Play(rainSoundRes)
    end
    if bgmSrcComp and bgmSoundRes then
        bgmSrcComp.gain = 0.55
        bgmSrcComp:Play(bgmSoundRes)
    end
end

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    if lootUI.dragging and lootUI.active and input:GetKeyPress(KEY_R) then
        if lootUI.dragOrientation == "vertical" then
            lootUI.dragOrientation = "horizontal"
        else
            lootUI.dragOrientation = "vertical"
        end
        print("[Loot] 物资方向切换为 " .. lootUI.dragOrientation)
    end
    if attackHUDPressTimer > 0 then
        attackHUDPressTimer = math.max(0, attackHUDPressTimer - dt)
    end
    local attackScaleTarget = attackHUDPressTimer > 0.055 and 0.88 or 1.0
    attackHUDScale = attackHUDScale + (attackScaleTarget - attackHUDScale) * math.min(1.0, dt * 22)
    if reloadHUDPressTimer > 0 then
        reloadHUDPressTimer = math.max(0, reloadHUDPressTimer - dt)
    end
    if lootUI.searchPressedTimer > 0 then
        lootUI.searchPressedTimer = math.max(0, lootUI.searchPressedTimer - dt)
    end
    local reloadScaleTarget = reloadHUDPressTimer > 0.055 and 0.88 or 1.0
    reloadHUDScale = reloadHUDScale + (reloadScaleTarget - reloadHUDScale) * math.min(1.0, dt * 22)
    if consumeHUDPressTimer > 0 then
        consumeHUDPressTimer = math.max(0, consumeHUDPressTimer - dt)
    end
    updateConsumeCooldown(dt)
    local consumeScaleTarget = consumeHUDPressTimer > 0.055 and 0.88 or 1.0
    consumeHUDScale = consumeHUDScale + (consumeScaleTarget - consumeHUDScale) * math.min(1.0, dt * 22)
    dpr = graphics:GetDPR()
    W = graphics:GetWidth() / dpr
    H = graphics:GetHeight() / dpr

    if BlackMarketCloud.loadComplete and BlackMarketCloud.dirty then
        BlackMarketCloud.saveDelay = math.max(0, BlackMarketCloud.saveDelay - dt)
        if BlackMarketCloud.saveDelay <= 0 then BlackMarketCloud.Flush() end
    end

    -- 资源加载阶段：每帧推进加载协程，加载完成前不执行游戏逻辑
    if appState == "loading" then
        gameTime = gameTime + dt  -- 供加载界面旋转动画使用
        -- 阶段1：协程分帧创建所有资源句柄（触发 DWP 后台下载）
        if initCo and coroutine.status(initCo) ~= "dead" then
            local ok, err = coroutine.resume(initCo)
            if not ok then
                initCo = nil
                loadStatusText = "资源初始化失败，请查看日志"
                print("[Load] 资源加载协程错误: " .. tostring(err))
            end
            return
        end
        if initCo == nil then
            return
        end
        -- 阶段2：等待所有 DWP 后台下载完成（图片/音频/动画从 CDN 下载完成后才进游戏）
        if not downloadObserveStarted then
            downloadObserveStarted = true
            loadStatusText = "正在下载资源..."
            cache:ObserveDownloads(
                function(completed, total, bytes)
                    if total and total > 0 then
                        loadProgress = 0.95 + 0.04 * (completed / total)
                    end
                end,
                function(bytes)
                    downloadsComplete = true
                    loadProgress = 1.0
                    loadStatusText = "加载完成"
                end
            )
        end
        if downloadsComplete and not BlackMarketCloud.loadStarted then
            BlackMarketCloud.BeginLoad()
        end
        if BlackMarketCloud.loadStarted and not BlackMarketCloud.loadComplete then
            BlackMarketCloud.loadElapsed = BlackMarketCloud.loadElapsed + dt
            if BlackMarketCloud.loadElapsed >= BlackMarketCloud.LOAD_TIMEOUT then
                BlackMarketCloud.loadComplete = true
                loadStatusText = "加载完成"
                print("[Cloud] 黑市档案读取超时，继续使用默认档案")
            end
        end
        if downloadsComplete and BlackMarketCloud.loadComplete then
            appState = "home"
            HomeUI.Reset()
            if joystick_ then joystick_._shouldShow = false end
            if upBtn_ then upBtn_._shouldShow = false end
            if downBtn_ then downBtn_._shouldShow = false end
            print("[Load] 所有资源下载完成，进入据点首页")
        end
        return
    end

    updateBlackMarketRefresh(dt)

    if appState == "home" then
        gameTime = gameTime + dt
        HomeUI.Update(dt)
        if joystick_ then joystick_._shouldShow = false end
        if descendBtn_ then descendBtn_._shouldShow = false end
        if doorBtn_ then doorBtn_._shouldShow = false end
        if upBtn_ then upBtn_._shouldShow = false end
        if downBtn_ then downBtn_._shouldShow = false end
        if lootBtn_ then lootBtn_._shouldShow = false end

        local numTouches = input.numTouches or 0
        if numTouches > 0 then
            local touch = input:GetTouch(0)
            homeTouchX = touch.position.x / dpr
            homeTouchY = touch.position.y / dpr
            HomeUI.PointerMove(homeTouchX, homeTouchY)
            if not homeTouchActive then
                homeTouchActive = true
                HomeUI.PointerDown(homeTouchX, homeTouchY)
            end
        elseif homeTouchActive then
            homeTouchActive = false
            local action = HomeUI.PointerUp(homeTouchX, homeTouchY)
            if action == "equip" then
                playHomeUISound("equip")
                openLoadoutPanel()
                print("[Home] 触摸打开装备界面")
            elseif action == "deploy" then
                playHomeUISound("deploy")
                confirmLoadout()
                print("[Home] 触摸使用当前装备出战")
            elseif action == "change-map" then
                playHomeUISound("tab")
                HomeUI.SetNotice("当前版本仅开放：东京废弃城区", 2.8)
                print("[Home] 触摸地图选择：当前仅开放东京废弃城区")
            elseif action == "blackmarket" then
                playHomeUISound("tab")
                openBlackMarketPanel()
                print("[Home] 触摸打开黑市交易终端")
            elseif action == "shop" then
                playHomeUISound("tab")
                openShopPanel()
                print("[Home] 触摸打开战术补给商城")
            elseif action == "warehouse" then
                playHomeUISound("warehouse")
                lootUI.CleanupTakenEntries(warehouseTabs[1].items)
                appState = "warehouse"
                WarehouseUI.Open(warehouseTabs)
                print("[Home] 触摸打开独立据点仓库")
            elseif action then
                playHomeUISound("tab")
                print("[Home] 触摸切换首页页签: " .. tostring(action))
            end
        elseif input:GetKeyPress(KEY_RETURN) or input:GetKeyPress(KEY_SPACE) then
            playHomeUISound("deploy")
            confirmLoadout()
            print("[Home] 键盘使用当前装备出战")
        end
        return
    end

    if appState == "loadout" then
        gameTime = gameTime + dt
        if joystick_ then joystick_._shouldShow = false end
        if descendBtn_ then descendBtn_._shouldShow = false end
        if attackBtn_ then attackBtn_._shouldShow = false end
        if doorBtn_ then doorBtn_._shouldShow = false end
        if upBtn_ then upBtn_._shouldShow = false end
        if downBtn_ then downBtn_._shouldShow = false end
        if lootBtn_ then lootBtn_._shouldShow = false end
        if inventoryBtn_ then inventoryBtn_._shouldShow = false end
        if weaponSwitchBtn_ then weaponSwitchBtn_._shouldShow = false end
        if input:GetKeyPress(KEY_ESCAPE) then
            lootUI.Close()
            return
        end
        if spineUIInstance and lootUI.active then
            spineUIInstance:Update(dt)
        end
        local wheel = input:GetMouseMoveWheel()
        if wheel ~= 0 then
            local mx = input.mousePosition.x / dpr
            local my = input.mousePosition.y / dpr
            lootUI.ScrollAt(mx, my, -wheel * 20)
        end
        local numTouches = input.numTouches or 0
        if numTouches > 0 then
            local touch = input:GetTouch(0)
            local tx = touch.position.x / dpr
            local ty = touch.position.y / dpr
            local dy = touch.delta.y / dpr
            if not lootUI._touchActive then
                lootUI._touchActive = true
                lootUI._touchStartX = tx
                lootUI._touchStartY = ty
                lootUI._touchStartTime = gameTime
                lootUI._touchMoved = false
                lootUI._touchDragStarted = false
                lootUI._touchLoadoutConfirm = false
                lootUI._touchHitItem = hitTestAllContainers(tx, ty) ~= nil
            else
                local totalDist = math.abs(tx - lootUI._touchStartX) + math.abs(ty - lootUI._touchStartY)
                if totalDist > 8 then lootUI._touchMoved = true end
                local holdTime = gameTime - lootUI._touchStartTime
                if lootUI.dragging then
                    lootUI.dragMouseX = tx
                    lootUI.dragMouseY = ty
                elseif lootUI._touchHitItem and holdTime > 0.25 then
                    handleLootUIMouseDown(lootUI._touchStartX, lootUI._touchStartY, true, "touch")
                    lootUI._touchDragStarted = true
                elseif lootUI._touchMoved and not lootUI._touchHitItem then
                    lootUI.ScrollAt(tx, ty, -dy)
                end
            end
        elseif lootUI._touchActive then
            if lootUI.dragging then
                handleLootUIMouseUp(lootUI.dragMouseX, lootUI.dragMouseY)
            elseif not lootUI._touchMoved and lootUI.IsCloseButtonHit(lootUI._touchStartX, lootUI._touchStartY) then
                lootUI.Close()
            end
            lootUI._touchActive = false
            lootUI._touchLoadoutConfirm = false
            lootUI._touchDragStarted = false
            lootUI._touchHitItem = false
        end
        return
    end

    if appState == "blackmarket" then
        gameTime = gameTime + dt
        BlackMarketUI.Update(dt)
        if joystick_ then joystick_._shouldShow = false end
        if descendBtn_ then descendBtn_._shouldShow = false end
        if doorBtn_ then doorBtn_._shouldShow = false end
        if upBtn_ then upBtn_._shouldShow = false end
        if downBtn_ then downBtn_._shouldShow = false end
        if lootBtn_ then lootBtn_._shouldShow = false end

        local wheel = input:GetMouseMoveWheel()
        if wheel ~= 0 then
            local mousePos = input:GetMousePosition()
            BlackMarketUI.ScrollAt(mousePos.x / dpr, mousePos.y / dpr, -wheel * 34)
        end
        if input:GetKeyPress(KEY_ESCAPE) then
            appState = "home"
            HomeUI.Reset()
            print("[BlackMarket] 键盘返回据点首页")
        end
        return
    end

    if appState == "shop" then
        gameTime = gameTime + dt
        ShopUI.Update(dt)
        if joystick_ then joystick_._shouldShow = false end
        if descendBtn_ then descendBtn_._shouldShow = false end
        if doorBtn_ then doorBtn_._shouldShow = false end
        if upBtn_ then upBtn_._shouldShow = false end
        if downBtn_ then downBtn_._shouldShow = false end
        if lootBtn_ then lootBtn_._shouldShow = false end

        local wheel = input:GetMouseMoveWheel()
        if wheel ~= 0 then
            local mousePos = input:GetMousePosition()
            ShopUI.ScrollAt(mousePos.x / dpr, mousePos.y / dpr, -wheel * 34)
        end
        if input:GetKeyPress(KEY_ESCAPE) then
            appState = "home"
            HomeUI.Reset()
            print("[Shop] 键盘返回据点首页")
        end
        return
    end

    if appState == "warehouse" then
        gameTime = gameTime + dt
        WarehouseUI.Update(dt)
        if joystick_ then joystick_._shouldShow = false end
        if descendBtn_ then descendBtn_._shouldShow = false end
        if doorBtn_ then doorBtn_._shouldShow = false end
        if upBtn_ then upBtn_._shouldShow = false end
        if downBtn_ then downBtn_._shouldShow = false end
        if lootBtn_ then lootBtn_._shouldShow = false end

        if input:GetKeyPress(KEY_ESCAPE) then
            appState = "home"
            HomeUI.Reset()
            print("[Warehouse] 返回据点首页")
        end
        return
    end

    if appState == "codex" then
        gameTime = gameTime + dt
        CodexUI.Update(dt)
        if joystick_ then joystick_._shouldShow = false end
        if descendBtn_ then descendBtn_._shouldShow = false end
        if doorBtn_ then doorBtn_._shouldShow = false end
        if upBtn_ then upBtn_._shouldShow = false end
        if downBtn_ then downBtn_._shouldShow = false end
        if lootBtn_ then lootBtn_._shouldShow = false end

        local wheel = input:GetMouseMoveWheel()
        if wheel ~= 0 then CodexUI.ScrollDelta(-wheel * 34) end
        if input:GetKeyPress(KEY_ESCAPE) then
            appState = "home"
            HomeUI.Reset()
            print("[Codex] 键盘返回据点首页")
        end
        return
    end

    if settingsUI.active then
        handleSettingsUIInput()
        return
    end

    if appState ~= "loadout" then
        if handleExitHomeHUDInput() then
            return
        end

        startGameAudio()

    -- 雨声保活 + 室内外音量调节
    if rainSrcComp and rainSoundRes then
        if not rainSrcComp:IsPlaying() then
            rainSrcComp:Play(rainSoundRes)
        end
        -- 判断玩家是否在建筑内（x在建筑世界范围内）
        local wLeft = csInfo.worldAnnexLeft or 9999
        local wRight = (csInfo.worldX or -9999) + (csInfo.worldW or 0)
        local isIndoor = (player.x >= wLeft and player.x <= wRight) or (getCurrentStreetBuilding() ~= nil)
        local targetGain = isIndoor and 0.1 or 0.35
        -- 平滑过渡音量
        local curGain = rainSrcComp.gain
        if math.abs(curGain - targetGain) > 0.005 then
            rainSrcComp.gain = curGain + (targetGain - curGain) * math.min(dt * 3, 1)
        end
    end

    -- 背景音乐保活，避免音频设备恢复或切场景后停止
    if bgmSrcComp and bgmSoundRes and not bgmSrcComp:IsPlaying() then
        bgmSrcComp:Play(bgmSoundRes)
    end

    gameTime = gameTime + dt
    updateGame(dt)
    updateLampFlicker(dt)
    end

    -- ── 更新 Spine UI展示实例（摸金UI idle 动画）──
    if spineUIInstance and lootUI.active then
        spineUIInstance:Update(dt)
    end
    -- 更新开箱加载计时器
    if lootUI.active and lootUI.loadingTimer > 0 then
        lootUI.loadingTimer = lootUI.loadingTimer - dt
        lootUI.loadingElapsed = lootUI.loadingElapsed + dt
        if lootUI.loadingTimer < 0 then lootUI.loadingTimer = 0 end
        -- 每个物资按串行累计时间揭示并播放一次音效。
        local chest = chestDefs[lootUI.chestIdx]
        if chest then
            local _, revealTimes = lootUI.GetSequentialRevealSchedule(chest.items)
            local allRevealed = true
            for idx, itm in ipairs(chest.items) do
                local revealTime = revealTimes[idx]
                if revealTime and lootUI.loadingElapsed < revealTime then
                    allRevealed = false
                end
                if revealTime and lootUI.loadingElapsed >= revealTime
                    and not lootUI.revealedSet[idx] then
                    lootUI.revealedSet[idx] = true
                    local revealItemName = lootUI.GetGridItemName(itm)
                    local revealRarity = ITEM_RARITY[revealItemName] or "green"
                    local revealSoundPath = revealRarity == "red"
                        and "audio/sfx/legendary_reveal_short.mp3"
                        or "audio/sfx/item_revealed.ogg"
                    local revealSfx = cache:GetResource("Sound", revealSoundPath)
                    if revealSfx and audioScene then
                        revealSfx.looped = false
                        local sfxNode = audioScene:CreateChild(
                            revealRarity == "red" and "LegendaryRevealSFX" or "RevealSFX")
                        local src = sfxNode:CreateComponent("SoundSource")
                        src:Play(revealSfx)
                        src.gain = revealRarity == "red" and 1.65 or 1.5
                        src.autoRemoveMode = REMOVE_NODE
                    end
                end
            end
            if allRevealed then
                chest.lootLoaded = true
            end
        end
    end
    -- 中区滚动：鼠标滚轮
    if lootUI.active then
        local wheel = input:GetMouseMoveWheel()
        if wheel ~= 0 then
            lootUI.midScrollY = lootUI.midScrollY - wheel * 20
            if lootUI.midScrollY < 0 then lootUI.midScrollY = 0 end
        end
    end

    -- (拖拽逻辑已移至 NanoVGRender 渲染循环中处理)

    -- 手机触摸：拖拽 + 滚动 + 双击
    if lootUI.active then
        local numTouches = input.numTouches
        if numTouches > 0 then
            local touch = input:GetTouch(0)
            local tx = touch.position.x / dpr
            local ty = touch.position.y / dpr
            local dx = touch.delta.x / dpr
            local dy = touch.delta.y / dpr

            if not lootUI._touchActive then
                -- 新触摸开始：关闭按钮优先，避免轻微滑动导致难触发
                if lootUI.IsCloseButtonHit(tx, ty) then
                    lootUI.Close()
                    lootUI._touchActive = false
                    return
                else
                    lootUI._touchLoadoutConfirm = false
                    lootUI._touchActive = true
                    lootUI._touchStartX = tx
                    lootUI._touchStartY = ty
                    lootUI._touchStartTime = gameTime or 0
                    lootUI._touchMoved = false
                    lootUI._touchDragStarted = false
                    lootUI._touchHitItem = hitTestAllContainers(tx, ty) ~= nil
                end
            else
                -- 触摸移动中
                local totalDist = math.abs(tx - lootUI._touchStartX) + math.abs(ty - lootUI._touchStartY)
                if totalDist > 8 and not lootUI._touchHitItem then lootUI._touchMoved = true end

                local holdTime = (gameTime or 0) - lootUI._touchStartTime

                if lootUI.dragging then
                    -- 正在拖拽：更新位置
                    lootUI.dragMouseX = tx
                    lootUI.dragMouseY = ty
                elseif lootUI._touchHitItem and not lootUI._touchDragStarted and holdTime > 0.25 then
                    -- 长按物品 → 开始拖拽（不要求先移动）
                    handleLootUIMouseDown(lootUI._touchStartX, lootUI._touchStartY, true, "touch")
                    lootUI._touchDragStarted = true
                    if lootUI.dragging then
                        lootUI.dragMouseX = tx
                        lootUI.dragMouseY = ty
                    end
                elseif lootUI._touchMoved and not lootUI.dragging then
                    -- 未拖拽的滑动 → 中区滚动
                    lootUI.midScrollY = lootUI.midScrollY - dy
                    if lootUI.midScrollY < 0 then lootUI.midScrollY = 0 end
                end
            end
        else
            -- 触摸结束
            if lootUI._touchActive then
                local tx2 = lootUI._touchStartX
                local ty2 = lootUI._touchStartY
                if lootUI.dragging then
                    -- 拖拽松手 → 放置
                    handleLootUIMouseUp(lootUI.dragMouseX, lootUI.dragMouseY)
                elseif not lootUI._touchMoved and not lootUI._touchDragStarted then
                    if lootUI.IsCloseButtonHit(tx2, ty2) then
                        lootUI.Close()
                    else
                        local hit = hitTestAllContainers(tx2, ty2)
                        if hit then
                            -- 短触摸交给统一点击处理，第二次点同一槽位会自动放入背包。
                            handleLootUIMouseDown(tx2, ty2, false, "touch", true)
                        else
                            lootUI.SelectItem(nil)
                            lootUI.lastClickTime = 0
                            lootUI.lastClickItem = ""
                            lootUI.lastClickContainer = ""
                            lootUI.lastClickIdx = 0
                        end
                    end
                end
                lootUI._touchActive = false
                lootUI._touchLoadoutConfirm = false
                lootUI._touchDragStarted = false
                lootUI._touchHitItem = false
            end
        end
    end

    -- ── 更新序列帧主角暗层遮罩亮度 ──
    do
        -- 使用世界坐标做 X 比较，避免帧间 cameraX 漂移导致匹配失败
            local px = player.x  -- 玩家世界 X
            local ply = H * GROUND_Y_RATIO + player.jumpScrY
            local checkY = ply - player.drawH * 0.4
            local tint = 1.0
            -- 渲染帧记录的 cameraX，用于将 room.midX（屏幕坐标）转回世界坐标
            local rcamX = csInfo.camX or cameraX

            -- 上层房间暗层
            for _, fo in ipairs(csInfo.floorOverlays) do
                local fwx = fo.wx or (fo.x + rcamX)  -- 世界 X 左边界
                local fww = fo.ww or fo.w             -- 宽度
                if px >= fwx and px <= fwx + fww
                   and checkY >= fo.y and checkY <= fo.y + fo.h then
                    local baseTint = 0.72
                    local lightAdd = 0
                    local bestDist = math.huge
                    local nearBright = 0
                    for _, r in ipairs(fo.rooms) do
                        local rmwx = r.midX + rcamX  -- room midX 转世界坐标
                        local d = math.abs(px - rmwx)
                        if d < bestDist then bestDist = d; nearBright = r.brightness end
                    end
                    local ambient = nearBright * 0.45
                    local directLight = 0
                    for _, r in ipairs(fo.rooms) do
                        if r.brightness > 0.05 then
                            local rmwx = r.midX + rcamX
                            local roomW = r.rw or fo.w
                            local coneHalf = math.floor(roomW * 0.45)
                            local dx = math.abs(px - rmwx)
                            if dx < coneHalf then
                                local hFade = 1.0 - (dx / coneHalf)
                                local l = r.brightness * 0.32 * hFade
                                if l > directLight then directLight = l end
                            end
                        end
                    end
                    lightAdd = ambient + directLight
                    tint = math.min(1.0, baseTint + lightAdd)
                    break
                end
            end

            -- 地下室暗层（优先级更高）
            local ov = csInfo.basOverlay
            if ov then
                local ovL = ov.innerL + rcamX  -- 转世界坐标
                local ovR = ov.innerR + rcamX
                if px >= ovL and px <= ovR
                   and checkY >= ov.basTop and checkY <= ov.basTop + ov.basRoomH then
                    local baseTint = 0.58
                    local lightAdd = 0
                    for ri = 1, #ov.bxs - 1 do
                        local brightness = ov.brightnesses[ri] or 0
                        if brightness > 0.05 then
                            local roomMidX = math.floor((ov.bxs[ri] + ov.bxs[ri + 1]) / 2) + rcamX
                            local dx = math.abs(px - roomMidX)
                            local glowR = math.floor(ov.basRoomH * 1.25)
                            local hFade = math.max(0, 1.0 - dx / glowR)
                            local ambient = brightness * 0.4
                            local direct = brightness * 0.55 * hFade
                            local l = ambient + direct
                            if l > lightAdd then lightAdd = l end
                        end
                    end
                    tint = math.min(1.0, baseTint + lightAdd)
                end
            end

            player.overlayTint = tint
    end
end

function handleSettingsUIInput()
    if not settingsUI.active then return false end

    local function inside(r, px, py)
        return r and px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h
    end
    local function updateSlider(px)
        local r = settingsUI.sliderRect
        if r then applyGameVolume((px - r.x - 8) / (r.w - 16)) end
    end

    local mx = input.mousePosition.x / dpr
    local my = input.mousePosition.y / dpr
    if input:GetMouseButtonPress(MOUSEB_LEFT) then
        if inside(settingsUI.closeRect, mx, my) then
            closeSettingsUI()
            return true
        elseif inside(settingsUI.exitRect, mx, my) then
            returnToHomeFromGame()
            return true
        elseif inside(settingsUI.sliderRect, mx, my) then
            settingsUI.touchMode = "mouse_slider"
            updateSlider(mx)
        end
    elseif settingsUI.touchMode == "mouse_slider" and input:GetMouseButtonDown(MOUSEB_LEFT) then
        updateSlider(mx)
    elseif settingsUI.touchMode == "mouse_slider" then
        settingsUI.touchMode = ""
    end

    local numTouches = input.numTouches or 0
    if numTouches > 0 then
        local touch = input:GetTouch(0)
        local tx = touch.position.x / dpr
        local ty = touch.position.y / dpr
        if settingsUI.touchMode == "" then
            if inside(settingsUI.closeRect, tx, ty) then
                settingsUI.touchMode = "close"
                closeSettingsUI()
                return true
            elseif inside(settingsUI.exitRect, tx, ty) then
                settingsUI.touchMode = "exit"
                returnToHomeFromGame()
                return true
            elseif inside(settingsUI.sliderRect, tx, ty) then
                settingsUI.touchMode = "touch_slider"
                updateSlider(tx)
            else
                settingsUI.touchMode = "blocked"
            end
        elseif settingsUI.touchMode == "touch_slider" then
            updateSlider(tx)
        end
    elseif settingsUI.touchMode ~= "mouse_slider" then
        settingsUI.touchMode = ""
    end

    if input:GetKeyPress(KEY_ESCAPE) then
        closeSettingsUI()
    end
    return true
end

function drawSettingsUI(ctx)
    if not settingsUI.active then return end

    nvgSave(ctx)
    nvgResetTransform(ctx)
    nvgResetScissor(ctx)
    nvgScale(ctx, dpr, dpr)

    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, W, H)
    nvgFillColor(ctx, nvgRGBA(0, 0, 0, 185))
    nvgFill(ctx)

    local panelW = math.min(430, W * 0.84)
    local panelH = math.min(320, H * 0.72)
    local panelX = (W - panelW) * 0.5
    local panelY = (H - panelH) * 0.5
    settingsUI.panelRect = { x = panelX, y = panelY, w = panelW, h = panelH }

    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, panelX, panelY, panelW, panelH, 14)
    nvgFillColor(ctx, nvgRGBA(18, 23, 30, 250))
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(201, 172, 103, 230))
    nvgStrokeWidth(ctx, 2)
    nvgStroke(ctx)

    nvgFontFace(ctx, "sans")
    nvgFontSize(ctx, 25)
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(ctx, nvgRGBA(245, 230, 190, 255))
    nvgText(ctx, panelX + panelW * 0.5, panelY + 38, "游戏设置")

    local closeSize = 42
    local closeX = panelX + panelW - closeSize - 10
    local closeY = panelY + 10
    settingsUI.closeRect = { x = closeX, y = closeY, w = closeSize, h = closeSize }
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, closeX, closeY, closeSize, closeSize, 8)
    nvgFillColor(ctx, nvgRGBA(55, 62, 72, 230))
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, closeX + 13, closeY + 13)
    nvgLineTo(ctx, closeX + closeSize - 13, closeY + closeSize - 13)
    nvgMoveTo(ctx, closeX + closeSize - 13, closeY + 13)
    nvgLineTo(ctx, closeX + 13, closeY + closeSize - 13)
    nvgStrokeColor(ctx, nvgRGBA(235, 235, 235, 255))
    nvgStrokeWidth(ctx, 3)
    nvgStroke(ctx)

    local sliderX = panelX + 42
    local sliderY = panelY + 118
    local sliderW = panelW - 84
    local sliderH = 18
    settingsUI.sliderRect = { x = sliderX - 8, y = sliderY - 16, w = sliderW + 16, h = 50 }
    nvgFontSize(ctx, 17)
    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(ctx, nvgRGBA(220, 220, 220, 255))
    nvgText(ctx, sliderX, sliderY - 30, "游戏声音")
    nvgTextAlign(ctx, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFillColor(ctx, nvgRGBA(235, 205, 120, 255))
    nvgText(ctx, sliderX + sliderW, sliderY - 30, tostring(math.floor(settingsUI.volume * 100 + 0.5)) .. "%")

    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, sliderX, sliderY, sliderW, sliderH, sliderH * 0.5)
    nvgFillColor(ctx, nvgRGBA(48, 55, 65, 255))
    nvgFill(ctx)
    local fillW = sliderW * settingsUI.volume
    if fillW > 0 then
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, sliderX, sliderY, fillW, sliderH, sliderH * 0.5)
        nvgFillColor(ctx, nvgRGBA(220, 165, 55, 255))
        nvgFill(ctx)
    end
    local knobX = sliderX + fillW
    nvgBeginPath(ctx)
    nvgCircle(ctx, knobX, sliderY + sliderH * 0.5, 13)
    nvgFillColor(ctx, nvgRGBA(250, 232, 180, 255))
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(120, 85, 30, 255))
    nvgStrokeWidth(ctx, 2)
    nvgStroke(ctx)

    local exitW = math.min(260, panelW - 70)
    local exitH = 54
    local exitX = panelX + (panelW - exitW) * 0.5
    local exitY = panelY + panelH - exitH - 32
    settingsUI.exitRect = { x = exitX, y = exitY, w = exitW, h = exitH }
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, exitX, exitY, exitW, exitH, 9)
    nvgFillColor(ctx, nvgRGBA(145, 48, 48, 245))
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(235, 105, 90, 220))
    nvgStrokeWidth(ctx, 1.5)
    nvgStroke(ctx)
    nvgFontSize(ctx, 18)
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(ctx, nvgRGBA(255, 238, 230, 255))
    nvgText(ctx, exitX + exitW * 0.5, exitY + exitH * 0.5, "退出游戏并返回首页")

    nvgRestore(ctx)
end

function drawExitHomeHUD(ctx)
    if appState ~= "playing" or settingsUI.active or lootUI.active or lootUI.letterOpen then
        exitHomeHUDRect = nil
        return
    end

    local buttonSize = 50
    local x = W - buttonSize - 10
    local y = 10
    exitHomeHUDRect = { x = x, y = y, w = buttonSize, h = buttonSize }

    nvgSave(ctx)
    -- 退出场景变换后重新进入逻辑屏幕坐标，保证始终锚定手机画布右上角。
    nvgResetTransform(ctx)
    nvgResetScissor(ctx)
    nvgScale(ctx, dpr, dpr)
    local cut = 9
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, x + cut, y)
    nvgLineTo(ctx, x + buttonSize, y)
    nvgLineTo(ctx, x + buttonSize, y + buttonSize - cut)
    nvgLineTo(ctx, x + buttonSize - cut, y + buttonSize)
    nvgLineTo(ctx, x, y + buttonSize)
    nvgLineTo(ctx, x, y + cut)
    nvgClosePath(ctx)
    nvgFillColor(ctx, nvgRGBA(12, 17, 23, 218))
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(201, 172, 103, 220))
    nvgStrokeWidth(ctx, 1.5)
    nvgStroke(ctx)

    -- 设置齿轮图标。
    local iconCX = x + buttonSize * 0.5
    local iconCY = y + buttonSize * 0.5
    local teeth = 8
    local outerR = 15
    local innerR = 11
    nvgBeginPath(ctx)
    for i = 0, teeth * 2 - 1 do
        local angle = -math.pi * 0.5 + i * math.pi / teeth
        local radius = (i % 2 == 0) and outerR or innerR
        local px = iconCX + math.cos(angle) * radius
        local py = iconCY + math.sin(angle) * radius
        if i == 0 then nvgMoveTo(ctx, px, py) else nvgLineTo(ctx, px, py) end
    end
    nvgClosePath(ctx)
    nvgFillColor(ctx, nvgRGBA(235, 215, 157, 245))
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgCircle(ctx, iconCX, iconCY, 6)
    nvgFillColor(ctx, nvgRGBA(12, 17, 23, 255))
    nvgFill(ctx)
    nvgRestore(ctx)
end

function drawPlayerStatusHUD(ctx)
    if appState ~= "playing" or settingsUI.active or lootUI.letterOpen then return end

    local hpMax = math.max(1, player.maxHp or 100)
    local hp = clamp(player.hp or hpMax, 0, hpMax)
    local ratio = hp / hpMax
    local staminaMax = math.max(1, player.maxStamina or 100)
    local stamina = clamp(player.stamina or staminaMax, 0, staminaMax)
    local staminaRatio = stamina / staminaMax
    -- HUD 已在逻辑坐标系中绘制，不再根据 DPR 二次放大
    local hudScale = 0.78
    local x = 18 * hudScale
    local y = 18 * hudScale
    local iconR = 16 * hudScale
    local barW = math.min(330 * hudScale, W * 0.58)
    local panelH = math.max(78 * hudScale, iconR * 2 + 34 * hudScale)
    local ammo = math.max(0, player.ammo or 0)
    local ammoMax = math.max(1, player.maxAmmo or 1)
    local ammoWarn = ammo <= 2
    local ammoPulse = ammoWarn and (math.sin(gameTime * 11.0) * 0.5 + 0.5) or 0
    local ammoW = 136 * hudScale
    local ammoH = 52 * hudScale
    local safeBottom = 0
    if GetSafeAreaInsets then
        local safeRect = GetSafeAreaInsets(false)
        if safeRect and safeRect.max then
            safeBottom = (safeRect.max.y or 0) / dpr
        end
    end
    local bottomMargin = 22 * hudScale
    -- 武器、弹药、背包、装弹、食用整排向左偏移，给最右侧食用按钮留出空间。
    local quickHUDShiftLeft = 86 * hudScale
    local ammoX = (W - ammoW) * 0.5 - quickHUDShiftLeft
    local ammoY = H - safeBottom - bottomMargin - ammoH
    local edgePad = 12 * hudScale
    ammoX = clamp(ammoX, edgePad, math.max(edgePad, W - ammoW - edgePad))
    ammoY = clamp(ammoY, edgePad, math.max(edgePad, H - ammoH - edgePad))

    -- 战术背包按钮布局：固定在弹药 HUD 右侧
    local actionGap = 10 * hudScale
    local inventoryW = ammoH
    local inventoryX = ammoX + ammoW + actionGap
    inventoryHUDRect = { x = inventoryX, y = ammoY, w = inventoryW, h = ammoH }

    -- 装弹按钮：仅枪支槽实际装备武器时显示，避免动画集残留造成无枪按钮。
    local showReloadHUD = lootUI.equippedGunItem ~= "" and isFirearmAnimSet() and not lootUI.active
    reloadHUDRect = nil
    if showReloadHUD then
        local reloadGap = 8 * hudScale
        local reloadW = 82 * hudScale
        local reloadH = ammoH
        local reloadX = inventoryX + inventoryW + reloadGap
        local reloadY = ammoY
        reloadHUDRect = { x = reloadX, y = reloadY, w = reloadW, h = reloadH }
    end

    -- 食用按钮：显示在装弹按钮右侧；冷却期间保留刚食用物资并显示进度。
    consumeHUDRect = nil
    local quickConsumableName = select(3, findQuickConsumable())
    local displayedConsumableName = quickConsumableName or consumeCooldownItemName
    if displayedConsumableName and not lootUI.active then
        local consumeGap = 8 * hudScale
        local consumeW = 82 * hudScale
        local consumeH = ammoH
        local consumeX
        if reloadHUDRect then
            consumeX = reloadHUDRect.x + reloadHUDRect.w + consumeGap
        else
            consumeX = inventoryX + inventoryW + consumeGap
        end
        local consumeY = ammoY
        consumeHUDRect = {
            x = consumeX,
            y = consumeY,
            w = consumeW,
            h = consumeH,
            itemName = displayedConsumableName,
        }
    end

    -- 战术攻击按钮布局：右下角切角按钮
    local attackW = 94 * hudScale
    local attackH = 56 * hudScale
    local attackX = W - attackW - 34 * hudScale
    local attackY = H - safeBottom - 34 * hudScale - attackH
    if lootUI.equippedGunItem ~= "" or lootUI.equippedMeleeItem ~= "" then
        attackHUDRect = { x = attackX, y = attackY, w = attackW, h = attackH }
    else
        attackHUDRect = nil
    end

    -- 开门按钮位于攻击按钮左上方，使用更紧凑的手机尺寸。
    local doorHUDW = 68 * hudScale
    local doorHUDH = 44 * hudScale
    local doorHUDGap = 8 * hudScale
    local doorHUDX = attackX - doorHUDGap - doorHUDW
    local doorHUDY = attackY - doorHUDH - 6 * hudScale
    doorHUDRect = { x = doorHUDX, y = doorHUDY, w = doorHUDW, h = doorHUDH }
    if not ((descendBtn_ and descendBtn_._shouldShow) or (doorBtn_ and doorBtn_._shouldShow)) then
        doorHUDRect = nil
    end

    -- 第二栋楼外梯到楼层时显示“停留”按钮。
    ladderDownHUDRect = nil
    if cs2LadderDownHUDVisible and ladderTransition.active
        and ladderTransition.phase == "landingChoice" then
        ladderDownHUDRect = {
            x = doorHUDX - 6 * hudScale - 58 * hudScale,
            y = doorHUDY,
            w = 58 * hudScale,
            h = doorHUDH,
        }
    end

    nvgSave(ctx)
    nvgResetScissor(ctx)

    -- 战术射击风格生命 HUD
    local hpPanelX = x - 10 * hudScale
    local hpPanelY = y - 8 * hudScale
    local hpPanelW = barW + iconR * 2 + 36 * hudScale
    local hpLow = ratio <= 0.35
    local hpPulse = hpLow and (math.sin(gameTime * 8.0) * 0.5 + 0.5) or 0
    local hpAccentR = hpLow and 255 or 225
    local hpAccentG = hpLow and (105 + math.floor(55 * hpPulse)) or 62
    local hpAccentB = hpLow and 48 or 74
    local hpAccent = nvgRGBA(hpAccentR, hpAccentG, hpAccentB, 255)

    -- 深色切角面板
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, hpPanelX + 8 * hudScale, hpPanelY)
    nvgLineTo(ctx, hpPanelX + hpPanelW, hpPanelY)
    nvgLineTo(ctx, hpPanelX + hpPanelW, hpPanelY + panelH - 8 * hudScale)
    nvgLineTo(ctx, hpPanelX + hpPanelW - 8 * hudScale, hpPanelY + panelH)
    nvgLineTo(ctx, hpPanelX, hpPanelY + panelH)
    nvgLineTo(ctx, hpPanelX, hpPanelY + 8 * hudScale)
    nvgClosePath(ctx)
    nvgFillColor(ctx, nvgRGBA(10, 14, 19, 225))
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(hpAccentR, hpAccentG, hpAccentB, hpLow and 215 or 120))
    nvgStrokeWidth(ctx, 1.2 * hudScale)
    nvgStroke(ctx)

    -- 左侧状态色条
    nvgBeginPath(ctx)
    nvgRect(ctx, hpPanelX, hpPanelY + 8 * hudScale, 3 * hudScale, panelH - 16 * hudScale)
    nvgFillColor(ctx, hpAccent)
    nvgFill(ctx)

    -- 切角医疗图标底板
    local medX = hpPanelX + 9 * hudScale
    local medY = hpPanelY + 8 * hudScale
    local medSize = panelH - 16 * hudScale
    local medCut = 5 * hudScale
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, medX + medCut, medY)
    nvgLineTo(ctx, medX + medSize, medY)
    nvgLineTo(ctx, medX + medSize, medY + medSize - medCut)
    nvgLineTo(ctx, medX + medSize - medCut, medY + medSize)
    nvgLineTo(ctx, medX, medY + medSize)
    nvgLineTo(ctx, medX, medY + medCut)
    nvgClosePath(ctx)
    nvgFillColor(ctx, nvgRGBA(44, 18, 24, 235))
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(hpAccentR, hpAccentG, hpAccentB, 180))
    nvgStrokeWidth(ctx, 1 * hudScale)
    nvgStroke(ctx)

    -- 医疗十字图标
    local medCX = medX + medSize * 0.5
    local medCY = medY + medSize * 0.5
    local crossLong = medSize * 0.58
    local crossShort = medSize * 0.20
    nvgBeginPath(ctx)
    nvgRect(ctx, medCX - crossShort * 0.5, medCY - crossLong * 0.5, crossShort, crossLong)
    nvgRect(ctx, medCX - crossLong * 0.5, medCY - crossShort * 0.5, crossLong, crossShort)
    nvgFillColor(ctx, hpAccent)
    nvgFill(ctx)

    local hpContentX = medX + medSize + 11 * hudScale
    local hpContentRight = hpPanelX + hpPanelW - 12 * hudScale
    nvgFontFace(ctx, "sans")
    nvgFontSize(ctx, 8.5 * hudScale)
    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(ctx, nvgRGBA(hpAccentR, hpAccentG, hpAccentB, 225))
    nvgText(ctx, hpContentX, hpPanelY + 6 * hudScale, hpLow and "CRITICAL" or "VITALS")

    -- 当前生命值为主信息，最大生命值弱化
    nvgFontSize(ctx, 22 * hudScale)
    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(ctx, hpLow and hpAccent or nvgRGBA(244, 248, 252, 255))
    nvgText(ctx, hpContentX, hpPanelY + panelH * 0.42, string.format("%03d", math.floor(hp + 0.5)))
    nvgFontSize(ctx, 10 * hudScale)
    nvgTextAlign(ctx, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFillColor(ctx, nvgRGBA(155, 166, 178, 225))
    nvgText(ctx, hpContentRight, hpPanelY + panelH * 0.40, "/ " .. tostring(hpMax))

    -- 体力条：与生命刻度分层显示在同一战术面板底部
    local staminaLabelY = hpPanelY + panelH - 27 * hudScale
    local staminaBarY = hpPanelY + panelH - 19 * hudScale
    local staminaBarH = 3.5 * hudScale
    local staminaBarW = hpContentRight - hpContentX
    local staminaColor = staminaRatio <= 0.2
        and nvgRGBA(255, 174, 62, 240)
        or nvgRGBA(86, 205, 224, 235)
    nvgFontSize(ctx, 7 * hudScale)
    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(ctx, nvgRGBA(125, 190, 205, 210))
    nvgText(ctx, hpContentX, staminaLabelY, "STAMINA")
    nvgTextAlign(ctx, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFillColor(ctx, nvgRGBA(145, 165, 178, 190))
    nvgText(ctx, hpContentRight, staminaLabelY, string.format("%03d", math.floor(stamina + 0.5)))
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, hpContentX, staminaBarY, staminaBarW, staminaBarH, 1.5 * hudScale)
    nvgFillColor(ctx, nvgRGBA(35, 55, 65, 190))
    nvgFill(ctx)
    if staminaRatio > 0 then
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, hpContentX, staminaBarY, staminaBarW * staminaRatio, staminaBarH, 1.5 * hudScale)
        nvgFillColor(ctx, staminaColor)
        nvgFill(ctx)
    end

    -- 底部连续生命条
    local hpBarX = hpContentX
    local hpBarY = hpPanelY + panelH - 8 * hudScale
    local hpBarW = hpContentRight - hpContentX
    local hpBarH = 3.5 * hudScale
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, hpBarX, hpBarY, hpBarW, hpBarH, 1.75 * hudScale)
    nvgFillColor(ctx, nvgRGBA(66, 38, 42, 185))
    nvgFill(ctx)
    if ratio > 0 then
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, hpBarX, hpBarY, hpBarW * ratio, hpBarH, 1.75 * hudScale)
        nvgFillColor(ctx, hpAccent)
        nvgFill(ctx)
    end

    -- 当前武器切换 HUD：仅装备枪支或近战武器时显示并保留命中区域。
    weaponHUDRect = nil
    if lootUI.equippedGunItem ~= "" or lootUI.equippedMeleeItem ~= "" then
        local weaponName = PLAYER_ANIM_SET == "bat" and "棒球棍"
        or (PLAYER_ANIM_SET == "shotgun" and "散弹枪" or "手枪")
    local weaponIcon = itemIcons[weaponName]
    local weaponGap = 10 * hudScale
    local weaponW = ammoH
    local weaponX = ammoX - weaponGap - weaponW
    local weaponCut = 6 * hudScale
    weaponHUDRect = { x = weaponX, y = ammoY, w = weaponW, h = ammoH }
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, weaponX + weaponCut, ammoY)
    nvgLineTo(ctx, weaponX + weaponW, ammoY)
    nvgLineTo(ctx, weaponX + weaponW, ammoY + ammoH - weaponCut)
    nvgLineTo(ctx, weaponX + weaponW - weaponCut, ammoY + ammoH)
    nvgLineTo(ctx, weaponX, ammoY + ammoH)
    nvgLineTo(ctx, weaponX, ammoY + weaponCut)
    nvgClosePath(ctx)
    nvgFillColor(ctx, nvgRGBA(10, 14, 19, 128))
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(105, 195, 235, 135))
    nvgStrokeWidth(ctx, 1.1 * hudScale)
    nvgStroke(ctx)
    if weaponIcon and weaponIcon > 0 then
        local iconInset = 6 * hudScale
        local iconPaint = nvgImagePattern(
            ctx,
            weaponX + iconInset,
            ammoY + iconInset,
            weaponW - iconInset * 2,
            ammoH - iconInset * 2,
            0,
            weaponIcon,
            1.0
        )
        nvgBeginPath(ctx)
        nvgRect(ctx, weaponX + iconInset, ammoY + iconInset, weaponW - iconInset * 2, ammoH - iconInset * 2)
        nvgFillPaint(ctx, iconPaint)
        nvgFill(ctx)
    else
        nvgFontFace(ctx, "sans")
        nvgFontSize(ctx, 10 * hudScale)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(ctx, nvgRGBA(210, 225, 240, 255))
        nvgText(ctx, weaponX + weaponW * 0.5, ammoY + ammoH * 0.5, weaponName)
    end
    nvgFontFace(ctx, "sans")
    nvgFontSize(ctx, 6.5 * hudScale)
    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(ctx, nvgRGBA(105, 195, 235, 230))
        nvgText(ctx, weaponX + 5 * hudScale, ammoY + 3 * hudScale, "SWAP")
    end

    -- 战术射击风格弹药 HUD：突出当前弹量，弱化弹夹容量
    local accentR = ammoWarn and 255 or 105
    local accentG = ammoWarn and (125 + math.floor(75 * ammoPulse)) or 195
    local accentB = ammoWarn and 65 or 235
    local accentColor = nvgRGBA(accentR, accentG, accentB, 255)

    -- 深色切角面板
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, ammoX + 8 * hudScale, ammoY)
    nvgLineTo(ctx, ammoX + ammoW, ammoY)
    nvgLineTo(ctx, ammoX + ammoW, ammoY + ammoH - 8 * hudScale)
    nvgLineTo(ctx, ammoX + ammoW - 8 * hudScale, ammoY + ammoH)
    nvgLineTo(ctx, ammoX, ammoY + ammoH)
    nvgLineTo(ctx, ammoX, ammoY + 8 * hudScale)
    nvgClosePath(ctx)
    nvgFillColor(ctx, nvgRGBA(10, 14, 19, 128))
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(accentR, accentG, accentB, ammoWarn and 205 or 110))
    nvgStrokeWidth(ctx, 1.2 * hudScale)
    nvgStroke(ctx)

    -- 左侧状态色条与标签
    nvgBeginPath(ctx)
    nvgRect(ctx, ammoX, ammoY + 8 * hudScale, 3 * hudScale, ammoH - 16 * hudScale)
    nvgFillColor(ctx, accentColor)
    nvgFill(ctx)
    nvgFontFace(ctx, "sans")
    nvgFontSize(ctx, 8.5 * hudScale)
    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(ctx, nvgRGBA(accentR, accentG, accentB, 220))
    local ammoLabel = ammo <= 0 and "EMPTY" or (ammoWarn and "LOW" or "AMMO")
    nvgText(ctx, ammoX + 10 * hudScale, ammoY + 6 * hudScale, ammoLabel)

    -- 当前弹量（主信息）
    local dividerX = ammoX + ammoW - 42 * hudScale
    nvgFontSize(ctx, 27 * hudScale)
    nvgTextAlign(ctx, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFillColor(ctx, ammoWarn and accentColor or nvgRGBA(244, 248, 252, 255))
    nvgText(ctx, dividerX - 8 * hudScale, ammoY + ammoH * 0.51, string.format("%02d", ammo))

    -- 分隔线与弹夹容量（次要信息）
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, dividerX, ammoY + 9 * hudScale)
    nvgLineTo(ctx, dividerX, ammoY + ammoH - 10 * hudScale)
    nvgStrokeColor(ctx, nvgRGBA(255, 255, 255, 65))
    nvgStrokeWidth(ctx, 1 * hudScale)
    nvgStroke(ctx)
    nvgFontSize(ctx, 9 * hudScale)
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(ctx, nvgRGBA(150, 162, 174, 220))
    nvgText(ctx, dividerX + 20 * hudScale, ammoY + 8 * hudScale, "MAG")
    nvgFontSize(ctx, 15 * hudScale)
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(ctx, nvgRGBA(215, 222, 230, 245))
    nvgText(ctx, dividerX + 20 * hudScale, ammoY + 32 * hudScale, tostring(ammoMax))

    -- 底部逐发弹量刻度
    local pipCount = math.min(ammoMax, 12)
    local pipGap = 2 * hudScale
    local pipAreaX = ammoX + 10 * hudScale
    local pipAreaW = dividerX - pipAreaX - 9 * hudScale
    local pipW = math.max(2 * hudScale, (pipAreaW - (pipCount - 1) * pipGap) / pipCount)
    local pipY = ammoY + ammoH - 6 * hudScale
    local filledPips = math.ceil((ammo / ammoMax) * pipCount)
    for i = 1, pipCount do
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, pipAreaX + (i - 1) * (pipW + pipGap), pipY, pipW, 2 * hudScale, hudScale)
        if i <= filledPips then
            nvgFillColor(ctx, accentColor)
        else
            nvgFillColor(ctx, nvgRGBA(80, 90, 100, 120))
        end
        nvgFill(ctx)
    end

    if consumeHUDRect then
        local r = consumeHUDRect
        local itemName = r.itemName
        local consumeAccent = nvgRGBA(100, 220, 135, 245)
        local consumeCenterX = r.x + r.w * 0.5
        local consumeCenterY = r.y + r.h * 0.5
        nvgSave(ctx)
        nvgTranslate(ctx, consumeCenterX, consumeCenterY)
        nvgScale(ctx, consumeHUDScale, consumeHUDScale)
        nvgTranslate(ctx, -consumeCenterX, -consumeCenterY)

        local consumeCut = 6 * hudScale
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, r.x + consumeCut, r.y)
        nvgLineTo(ctx, r.x + r.w, r.y)
        nvgLineTo(ctx, r.x + r.w, r.y + r.h - consumeCut)
        nvgLineTo(ctx, r.x + r.w - consumeCut, r.y + r.h)
        nvgLineTo(ctx, r.x, r.y + r.h)
        nvgLineTo(ctx, r.x, r.y + consumeCut)
        nvgClosePath(ctx)
        nvgFillColor(ctx, nvgRGBA(10, 19, 15, 158))
        nvgFill(ctx)
        nvgStrokeColor(ctx, consumeAccent)
        nvgStrokeWidth(ctx, 1.2 * hudScale)
        nvgStroke(ctx)

        local itemIcon = itemIcons[itemName]
        local iconBoxX = r.x + 4 * hudScale
        local iconBoxY = r.y + 14 * hudScale
        local iconBoxW = 31 * hudScale
        local iconBoxH = 31 * hudScale
        if itemIcon and itemIcon > 0 then
            local drawX, drawY, drawW, drawH = getItemIconDrawRect(
                itemName, iconBoxX, iconBoxY, iconBoxW, iconBoxH, 0.92)
            local iconPaint = nvgImagePattern(
                ctx, drawX, drawY, drawW, drawH, 0, itemIcon, 1.0)
            nvgBeginPath(ctx)
            nvgRect(ctx, drawX, drawY, drawW, drawH)
            nvgFillPaint(ctx, iconPaint)
            nvgFill(ctx)
        else
            nvgBeginPath(ctx)
            nvgRoundedRect(ctx, iconBoxX + 5 * hudScale, iconBoxY + 4 * hudScale,
                17 * hudScale, 22 * hudScale, 3 * hudScale)
            nvgStrokeColor(ctx, consumeAccent)
            nvgStrokeWidth(ctx, 1.5 * hudScale)
            nvgStroke(ctx)
        end

        nvgFontFace(ctx, "sans")
        nvgFontSize(ctx, 6.5 * hudScale)
        nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        nvgFillColor(ctx, consumeAccent)
        nvgText(ctx, r.x + 5 * hudScale, r.y + 3 * hudScale, "USE")
        nvgFontSize(ctx, 13 * hudScale)
        nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(ctx, nvgRGBA(240, 250, 244, 250))
        nvgText(ctx, r.x + 37 * hudScale, r.y + r.h * 0.45, "食用")
        nvgFontSize(ctx, 7 * hudScale)
        nvgFillColor(ctx, nvgRGBA(155, 220, 175, 230))
        nvgText(ctx, r.x + 37 * hudScale, r.y + r.h * 0.72, itemName)

        if consumeCooldown > 0 then
            local cooldownRatio = math.max(0, math.min(1,
                consumeCooldown / CONSUME_COOLDOWN_DURATION))
            -- 自底向上消退的半透明遮罩，直观看到剩余冷却比例。
            local overlayH = r.h * cooldownRatio
            nvgSave(ctx)
            nvgScissor(ctx, r.x, r.y, r.w, r.h)
            nvgBeginPath(ctx)
            nvgRect(ctx, r.x, r.y + r.h - overlayH, r.w, overlayH)
            nvgFillColor(ctx, nvgRGBA(3, 7, 5, 185))
            nvgFill(ctx)
            nvgRestore(ctx)

            -- 底部冷却进度条从左向右填满。
            local progress = 1.0 - cooldownRatio
            nvgBeginPath(ctx)
            nvgRect(ctx, r.x + 3 * hudScale, r.y + r.h - 4 * hudScale,
                (r.w - 6 * hudScale) * progress, 2.5 * hudScale)
            nvgFillColor(ctx, nvgRGBA(100, 220, 135, 245))
            nvgFill(ctx)

            nvgFontFace(ctx, "sans")
            nvgFontSize(ctx, 15 * hudScale)
            nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(ctx, nvgRGBA(245, 252, 247, 255))
            nvgText(ctx, r.x + r.w * 0.5, r.y + r.h * 0.53,
                string.format("%.1f", consumeCooldown))
        end
        nvgRestore(ctx)
    end

    if reloadHUDRect then
        local r = reloadHUDRect
        local reloadCenterX = r.x + r.w * 0.5
        local reloadCenterY = r.y + r.h * 0.5
        nvgSave(ctx)
        nvgTranslate(ctx, reloadCenterX, reloadCenterY)
        nvgScale(ctx, reloadHUDScale, reloadHUDScale)
        nvgTranslate(ctx, -reloadCenterX, -reloadCenterY)

        local reloadCut = 6 * hudScale
        local reloadAccent = ammo <= 0 and nvgRGBA(255, 125, 65, 245) or nvgRGBA(105, 195, 235, 235)
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, r.x + reloadCut, r.y)
        nvgLineTo(ctx, r.x + r.w, r.y)
        nvgLineTo(ctx, r.x + r.w, r.y + r.h - reloadCut)
        nvgLineTo(ctx, r.x + r.w - reloadCut, r.y + r.h)
        nvgLineTo(ctx, r.x, r.y + r.h)
        nvgLineTo(ctx, r.x, r.y + reloadCut)
        nvgClosePath(ctx)
        nvgFillColor(ctx, nvgRGBA(10, 14, 19, 145))
        nvgFill(ctx)
        nvgStrokeColor(ctx, reloadAccent)
        nvgStrokeWidth(ctx, 1.2 * hudScale)
        nvgStroke(ctx)

        local iconCX = r.x + 21 * hudScale
        local iconCY = r.y + r.h * 0.55
        local iconW = 20 * hudScale
        local iconH = 7 * hudScale
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, iconCX - iconW * 0.5, iconCY - iconH * 0.5, iconW, iconH, 2 * hudScale)
        nvgFillColor(ctx, reloadAccent)
        nvgFill(ctx)
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, iconCX - 3 * hudScale, iconCY - 8 * hudScale)
        nvgLineTo(ctx, iconCX + 3 * hudScale, iconCY - 8 * hudScale)
        nvgLineTo(ctx, iconCX + 3 * hudScale, iconCY - 4 * hudScale)
        nvgLineTo(ctx, iconCX - 3 * hudScale, iconCY - 4 * hudScale)
        nvgClosePath(ctx)
        nvgFillColor(ctx, reloadAccent)
        nvgFill(ctx)
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, iconCX - 11 * hudScale, iconCY + 9 * hudScale)
        nvgLineTo(ctx, iconCX - 5 * hudScale, iconCY + 9 * hudScale)
        nvgMoveTo(ctx, iconCX + 5 * hudScale, iconCY + 9 * hudScale)
        nvgLineTo(ctx, iconCX + 11 * hudScale, iconCY + 9 * hudScale)
        nvgStrokeColor(ctx, nvgRGBA(190, 225, 245, 235))
        nvgStrokeWidth(ctx, 1.4 * hudScale)
        nvgStroke(ctx)

        nvgFontFace(ctx, "sans")
        nvgFontSize(ctx, 6.5 * hudScale)
        nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        nvgFillColor(ctx, reloadAccent)
        nvgText(ctx, r.x + 5 * hudScale, r.y + 3 * hudScale, "RELOAD")
        nvgFontSize(ctx, 13 * hudScale)
        nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(ctx, nvgRGBA(240, 246, 250, 250))
        nvgText(ctx, r.x + 37 * hudScale, r.y + r.h * 0.58, "装弹")
        nvgRestore(ctx)
    end

    -- 战术背包按钮：与底部 HUD 同高
    local invCut = 6 * hudScale
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, inventoryX + invCut, ammoY)
    nvgLineTo(ctx, inventoryX + inventoryW, ammoY)
    nvgLineTo(ctx, inventoryX + inventoryW, ammoY + ammoH - invCut)
    nvgLineTo(ctx, inventoryX + inventoryW - invCut, ammoY + ammoH)
    nvgLineTo(ctx, inventoryX, ammoY + ammoH)
    nvgLineTo(ctx, inventoryX, ammoY + invCut)
    nvgClosePath(ctx)
    nvgFillColor(ctx, nvgRGBA(10, 14, 19, 128))
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(105, 195, 235, 135))
    nvgStrokeWidth(ctx, 1.1 * hudScale)
    nvgStroke(ctx)
    -- 当前背包图片：外部 HUD 与背包界面使用同一件二级背包
    if backpackTier2Img and backpackTier2Img > 0 then
        local bagInset = 4 * hudScale
        local bagSize = math.min(inventoryW - bagInset * 2, ammoH - bagInset * 2)
        local bagX = inventoryX + (inventoryW - bagSize) * 0.5
        local bagY = ammoY + (ammoH - bagSize) * 0.5 + 2 * hudScale
        local bagPaint = nvgImagePattern(ctx, bagX, bagY, bagSize, bagSize, 0, backpackTier2Img, 1.0)
        nvgBeginPath(ctx)
        nvgRect(ctx, bagX, bagY, bagSize, bagSize)
        nvgFillPaint(ctx, bagPaint)
        nvgFill(ctx)
    else
        -- 图片未加载时保留简化线框作为兜底
        local bagCX = inventoryX + inventoryW * 0.5
        local bagCY = ammoY + ammoH * 0.56
        local bagW = 20 * hudScale
        local bagH = 17 * hudScale
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, bagCX - bagW * 0.5, bagCY - bagH * 0.42, bagW, bagH, 2 * hudScale)
        nvgStrokeColor(ctx, nvgRGBA(185, 225, 245, 245))
        nvgStrokeWidth(ctx, 1.6 * hudScale)
        nvgStroke(ctx)
        nvgBeginPath(ctx)
        nvgArc(ctx, bagCX, bagCY - bagH * 0.42, 5 * hudScale, math.pi, math.pi * 2, NVG_CW)
        nvgStrokeColor(ctx, nvgRGBA(185, 225, 245, 245))
        nvgStrokeWidth(ctx, 1.6 * hudScale)
        nvgStroke(ctx)
    end
    nvgFontFace(ctx, "sans")
    nvgFontSize(ctx, 6.5 * hudScale)
    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(ctx, nvgRGBA(105, 195, 235, 230))
    nvgText(ctx, inventoryX + 5 * hudScale, ammoY + 3 * hudScale, "PACK")

    -- 开门 HUD：与攻击按钮共用切角、深色底和红色强调线。
    if doorHUDRect and ((descendBtn_ and descendBtn_._shouldShow) or (doorBtn_ and doorBtn_._shouldShow)) then
        local r = doorHUDRect
        local doorCut = 9 * hudScale
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, r.x + doorCut, r.y)
        nvgLineTo(ctx, r.x + r.w, r.y)
        nvgLineTo(ctx, r.x + r.w, r.y + r.h - doorCut)
        nvgLineTo(ctx, r.x + r.w - doorCut, r.y + r.h)
        nvgLineTo(ctx, r.x, r.y + r.h)
        nvgLineTo(ctx, r.x, r.y + doorCut)
        nvgClosePath(ctx)
        nvgFillColor(ctx, nvgRGBA(28, 11, 15, 128))
        nvgFill(ctx)
        nvgStrokeColor(ctx, nvgRGBA(245, 70, 80, 190))
        nvgStrokeWidth(ctx, 1.4 * hudScale)
        nvgStroke(ctx)
        nvgBeginPath(ctx)
        nvgRect(ctx, r.x, r.y + doorCut, 3 * hudScale, r.h - doorCut * 2)
        nvgFillColor(ctx, nvgRGBA(245, 70, 80, 255))
        nvgFill(ctx)

        local lockCX = r.x + 17 * hudScale
        local lockCY = r.y + r.h * 0.54
        local lockW = 13 * hudScale
        local lockH = 11 * hudScale
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, lockCX - lockW * 0.5, lockCY - lockH * 0.2, lockW, lockH, 2 * hudScale)
        nvgStrokeColor(ctx, nvgRGBA(255, 170, 175, 245))
        nvgStrokeWidth(ctx, 1.5 * hudScale)
        nvgStroke(ctx)
        nvgBeginPath(ctx)
        nvgArc(ctx, lockCX, lockCY - lockH * 0.18, 5 * hudScale, math.pi, math.pi * 2, NVG_CW)
        nvgStrokeColor(ctx, nvgRGBA(255, 170, 175, 245))
        nvgStrokeWidth(ctx, 1.5 * hudScale)
        nvgStroke(ctx)
        nvgBeginPath(ctx)
        nvgCircle(ctx, lockCX, lockCY + 2 * hudScale, 1.5 * hudScale)
        nvgFillColor(ctx, nvgRGBA(255, 220, 220, 245))
        nvgFill(ctx)

        nvgFontFace(ctx, "sans")
        nvgFontSize(ctx, 5.5 * hudScale)
        nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        nvgFillColor(ctx, nvgRGBA(245, 70, 80, 235))
        nvgText(ctx, r.x + 29 * hudScale, r.y + 6 * hudScale, "DOOR")
        nvgFontSize(ctx, 10.5 * hudScale)
        nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(ctx, nvgRGBA(248, 242, 243, 255))
        nvgText(ctx, r.x + 29 * hudScale, r.y + 28 * hudScale, "开门")
    end

    -- 第二栋楼外梯停留 HUD：沿用切角深色面板，以琥珀色区分楼层选择。
    if ladderDownHUDRect and cs2LadderDownHUDVisible then
        local r = ladderDownHUDRect
        local cut = 8 * hudScale
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, r.x + cut, r.y)
        nvgLineTo(ctx, r.x + r.w, r.y)
        nvgLineTo(ctx, r.x + r.w, r.y + r.h - cut)
        nvgLineTo(ctx, r.x + r.w - cut, r.y + r.h)
        nvgLineTo(ctx, r.x, r.y + r.h)
        nvgLineTo(ctx, r.x, r.y + cut)
        nvgClosePath(ctx)
        nvgFillColor(ctx, nvgRGBA(25, 20, 10, 205))
        nvgFill(ctx)
        nvgStrokeColor(ctx, nvgRGBA(239, 178, 63, 220))
        nvgStrokeWidth(ctx, 1.3 * hudScale)
        nvgStroke(ctx)
        nvgBeginPath(ctx)
        nvgRect(ctx, r.x, r.y + cut, 3 * hudScale, r.h - cut * 2)
        nvgFillColor(ctx, nvgRGBA(239, 178, 63, 255))
        nvgFill(ctx)
        nvgFontFace(ctx, "sans")
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFontSize(ctx, 17 * hudScale)
        nvgFillColor(ctx, nvgRGBA(255, 225, 157, 255))
        nvgText(ctx, r.x + 16 * hudScale, r.y + r.h * 0.5, "停")
        nvgFontSize(ctx, 10 * hudScale)
        nvgFillColor(ctx, nvgRGBA(248, 242, 225, 255))
        nvgText(ctx, r.x + 39 * hudScale, r.y + r.h * 0.5, "停留")
    end

    -- 战术攻击按钮：仅装备枪支或近战武器时显示。
    if attackHUDRect then
    local attackCenterX = attackX + attackW * 0.5
    local attackCenterY = attackY + attackH * 0.5
    nvgSave(ctx)
    nvgTranslate(ctx, attackCenterX, attackCenterY)
    nvgScale(ctx, attackHUDScale, attackHUDScale)
    nvgTranslate(ctx, -attackCenterX, -attackCenterY)
    local attackCut = 10 * hudScale
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, attackX + attackCut, attackY)
    nvgLineTo(ctx, attackX + attackW, attackY)
    nvgLineTo(ctx, attackX + attackW, attackY + attackH - attackCut)
    nvgLineTo(ctx, attackX + attackW - attackCut, attackY + attackH)
    nvgLineTo(ctx, attackX, attackY + attackH)
    nvgLineTo(ctx, attackX, attackY + attackCut)
    nvgClosePath(ctx)
    nvgFillColor(ctx, nvgRGBA(28, 11, 15, 128))
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(245, 70, 80, 190))
    nvgStrokeWidth(ctx, 1.4 * hudScale)
    nvgStroke(ctx)
    nvgBeginPath(ctx)
    nvgRect(ctx, attackX, attackY + attackCut, 3 * hudScale, attackH - attackCut * 2)
    nvgFillColor(ctx, nvgRGBA(245, 70, 80, 255))
    nvgFill(ctx)
    local aimCX = attackX + 24 * hudScale
    local aimCY = attackY + attackH * 0.56
    local aimR = 9 * hudScale
    nvgBeginPath(ctx)
    nvgCircle(ctx, aimCX, aimCY, aimR)
    nvgMoveTo(ctx, aimCX - aimR - 5 * hudScale, aimCY)
    nvgLineTo(ctx, aimCX - aimR * 0.45, aimCY)
    nvgMoveTo(ctx, aimCX + aimR * 0.45, aimCY)
    nvgLineTo(ctx, aimCX + aimR + 5 * hudScale, aimCY)
    nvgMoveTo(ctx, aimCX, aimCY - aimR - 5 * hudScale)
    nvgLineTo(ctx, aimCX, aimCY - aimR * 0.45)
    nvgMoveTo(ctx, aimCX, aimCY + aimR * 0.45)
    nvgLineTo(ctx, aimCX, aimCY + aimR + 5 * hudScale)
    nvgStrokeColor(ctx, nvgRGBA(255, 170, 175, 250))
    nvgStrokeWidth(ctx, 1.5 * hudScale)
    nvgStroke(ctx)
    nvgFontFace(ctx, "sans")
    nvgFontSize(ctx, 7 * hudScale)
    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(ctx, nvgRGBA(245, 70, 80, 235))
    nvgText(ctx, attackX + 43 * hudScale, attackY + 8 * hudScale, "FIRE")
    nvgFontSize(ctx, 14 * hudScale)
    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(ctx, nvgRGBA(248, 242, 243, 255))
    nvgText(ctx, attackX + 43 * hudScale, attackY + 34 * hudScale, "攻击")
    nvgRestore(ctx) -- 攻击按钮按压缩放
    end
    nvgRestore(ctx)
end

function HandleNanoVGRender(eventType, eventData)
    if vg == nil then return end
    nvgBeginFrame(vg, W * dpr, H * dpr, 1.0)
    nvgSave(vg)
    nvgScale(vg, dpr, dpr)

    -- 资源加载界面：加载完成前只绘制加载画面
    if appState == "loading" then
        -- 深色背景
        nvgBeginPath(vg)
        nvgRect(vg, 0, 0, W, H)
        nvgFillColor(vg, nvgRGBA(14, 17, 22, 255))
        nvgFill(vg)

        local cx = W * 0.5
        nvgFontFace(vg, "sans")

        -- 标题
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFontSize(vg, 46)
        nvgFillColor(vg, nvgRGBA(235, 205, 120, 255))
        nvgText(vg, cx, H * 0.34, "末世搜寻")

        -- 旋转加载点
        local cyS = H * 0.5
        local dots = 8
        for i = 0, dots - 1 do
            local ang = (i / dots) * math.pi * 2
            local phase = (gameTime * 1.5 - i / dots) % 1
            local a = 0.2 + 0.8 * (1 - phase)
            local dx = cx + math.cos(ang) * 24
            local dy = cyS + math.sin(ang) * 24
            nvgBeginPath(vg)
            nvgCircle(vg, dx, dy, 4)
            nvgFillColor(vg, nvgRGBA(235, 180, 60, math.floor(255 * a)))
            nvgFill(vg)
        end

        -- 进度条
        local barW = math.min(W * 0.6, 420)
        local barH = 8
        local barX = cx - barW * 0.5
        local barY = H * 0.64
        nvgBeginPath(vg)
        nvgRoundedRect(vg, barX, barY, barW, barH, 4)
        nvgFillColor(vg, nvgRGBA(40, 46, 56, 255))
        nvgFill(vg)
        local fillW = barW * math.max(0, math.min(1, loadProgress))
        if fillW > 0 then
            nvgBeginPath(vg)
            nvgRoundedRect(vg, barX, barY, fillW, barH, 4)
            nvgFillColor(vg, nvgRGBA(235, 180, 60, 255))
            nvgFill(vg)
        end

        -- 状态文字（进度条上方）
        nvgFontSize(vg, 15)
        nvgFillColor(vg, nvgRGBA(150, 158, 168, 255))
        nvgText(vg, cx, barY - 22, loadStatusText)

        -- 百分比（进度条下方）
        nvgFontSize(vg, 18)
        nvgFillColor(vg, nvgRGBA(220, 220, 225, 255))
        nvgText(vg, cx, barY + 28, string.format("%d%%", math.floor(loadProgress * 100)))

        nvgRestore(vg)
        nvgEndFrame(vg)
        return
    end

    if appState == "home" then
        local homeData = {
            bits = lootUI and lootUI.bits or "12,840",
            playerImage = playerImg,
            crisisImage = blackMarketArt.home_crisis,
            survivorImage = blackMarketArt.home_survivor,
            nationalMapImage = blackMarketArt.home_national_map,
            locationImage = blackMarketArt.home_location,
            masterImage = blackMarketArt.home_master,
            layers = blackMarketArt.home_layers,
            selectedMapName = "东京废弃城区",
            shelterLevel = 6,
            survivorCount = "42 / 60",
            playerLevel = 18,
            playerExp = "3260 / 7200",
            health = "100 / 100",
            reputation = tostring(blackMarketReputation or 3250) .. " / 6000",
            inventoryCount = #playerInventory,
            inventoryCapacity = INVENTORY_MAX,
        }
        HomeUI.Draw(vg, W, H, gameTime, homeData)
        nvgRestore(vg)
        nvgEndFrame(vg)
        return
    end

    if appState == "blackmarket" then
        BlackMarketUI.Draw(vg, W, H, {
            bits = lootUI.bits,
            reputation = blackMarketReputation,
            itemIcons = itemIcons,
            itemRarity = ITEM_RARITY,
            itemSizes = ITEM_SIZES,
            itemValues = lootUI.itemValues,
            warehouseTabs = warehouseTabs,
            art = blackMarketArt,
            marketRates = blackMarketRates,
            refreshRemaining = blackMarketRefreshRemaining,
            orders = blackMarketOrders,
            merchantStock = blackMarketMerchantStock,
            countWarehouseItem = countWarehouseItem,
            history = blackMarketHistory,
        })
        nvgRestore(vg)
        nvgEndFrame(vg)
        return
    end

    if appState == "shop" then
        ShopUI.Draw(vg, W, H, {
            bits = lootUI.bits,
            itemIcons = itemIcons,
            backgroundImage = blackMarketArt.home_layers.background,
            cellImages = blackMarketArt.warehouse_cells,
            designImages = blackMarketArt.shop_design,
        })
        nvgRestore(vg)
        nvgEndFrame(vg)
        return
    end

    if appState == "warehouse" then
        local warehouseData = {
            itemIcons = itemIcons,
            itemRarity = ITEM_RARITY,
            itemSizes = ITEM_SIZES,
            itemValues = lootUI.itemValues,
            masterImage = blackMarketArt.warehouse_master,
            cellImages = blackMarketArt.warehouse_cells,
        }
        WarehouseUI.Draw(vg, W, H, warehouseData)
        nvgRestore(vg)
        nvgEndFrame(vg)
        return
    end

    if appState == "codex" then
        local codexData = {
            itemIcons = itemIcons,
            itemRarity = ITEM_RARITY,
            itemSizes = ITEM_SIZES,
            itemValues = lootUI.itemValues,
        }
        CodexUI.Draw(vg, W, H, codexData)
        nvgRestore(vg)
        nvgEndFrame(vg)
        return
    end

    if appState == "loadout" then
        drawLootUI(vg, W, H)
        local hasTouchInput = ((input.numTouches or 0) > 0) or lootUI._touchActive
        local mouseX = input.mousePosition.x / dpr
        local mouseY = input.mousePosition.y / dpr
        if not hasTouchInput and input:GetMouseButtonPress(MOUSEB_LEFT) then
            if lootUI.IsCloseButtonHit(mouseX, mouseY) then
                lootUI.Close()
            elseif not lootUI.dragging then
                handleLootUIMouseDown(mouseX, mouseY, false, "mouse")
            end
        elseif not hasTouchInput and lootUI.dragging and lootUI.dragInput == "mouse" then
            lootUI.dragMouseX = mouseX
            lootUI.dragMouseY = mouseY
            if not input:GetMouseButtonDown(MOUSEB_LEFT) then
                handleLootUIMouseUp(mouseX, mouseY)
            end
        end
        nvgRestore(vg)
        nvgEndFrame(vg)
        return
    end

    -- playerNearDoorFi 由本帧渲染中计算，供下一帧 updateGame 使用（不在此重置）
    lightSwitchZones = {}
    lightSwitchDrawQueue = {}

    -- 背景层：不受 SCENE_ZOOM 影响，始终铺满屏幕
    drawSky(vg)
    drawClouds(vg)
    drawDistant(vg)

    -- 场景缩放：以地面中心为锚点拉远镜头，降低贴图放大模糊
    -- 独立保存场景变换，确保恢复后仍保留帧级 DPR 缩放供 HUD 使用
    nvgSave(vg)
    local pivotX = W * 0.5
    local pivotY = H * GROUND_Y_RATIO
    if SCREEN_SHAKE_TIME > 0 then
        nvgTranslate(vg,
            (math.random() - 0.5) * SCREEN_SHAKE_POWER * 2,
            (math.random() - 0.5) * SCREEN_SHAKE_POWER)
    end
    nvgTranslate(vg, pivotX, pivotY)
    nvgScale(vg, SCENE_ZOOM, SCENE_ZOOM)
    nvgTranslate(vg, -pivotX, -pivotY)
    nvgTranslate(vg, 0, cameraY)

    drawEveningOverlay(vg)
    drawGround(vg)
    drawForegroundGround(vg)
    drawMcDonalds(vg, H * GROUND_Y_RATIO)
    drawStreetProps(vg, H * GROUND_Y_RATIO)
    drawStreetEnterableBuildings(vg, H * GROUND_Y_RATIO)
    drawCrossSection(vg, H * GROUND_Y_RATIO)
    drawSecondCrossSection(vg, H * GROUND_Y_RATIO)

    -- 2D 横版：先绘制丧尸，再绘制玩家，再画铁网（覆盖角色），最后暗层
    for _, z in ipairs(zombies) do
        drawOneZombie(vg, z)
    end

    -- ── 渲染球棍序列帧主角（在场景变换内，位置由 player.x/cameraX 决定）──
    drawBatDemoAnimation(vg)
    drawHealingPlusParticles(vg)

    -- ── 近距离散弹冲击环 ──
    for _, ring in ipairs(SHOTGUN_IMPACT_RINGS) do
        local t = 1.0 - ring.life / ring.maxLife
        local alpha = math.floor(220 * (1.0 - t))
        local radius = 12 + t * 64
        nvgBeginPath(vg)
        nvgCircle(vg, ring.x - cameraX, ring.y, radius)
        nvgStrokeColor(vg, nvgRGBA(255, 188, 92, alpha))
        nvgStrokeWidth(vg, 4 * (1.0 - t) + 1)
        nvgStroke(vg)
    end

    -- ── 近距离散弹碎裂块 ──
    for _, gib in ipairs(ZOMBIE_GIBS) do
        local gx = gib.x - cameraX
        local alpha = math.floor(255 * math.min(1, math.max(0, gib.life / 0.35)))
        nvgSave(vg)
        nvgTranslate(vg, gx, gib.y)
        nvgRotate(vg, gib.rot)
        local size = gib.size
        local paint = nvgImagePatternTinted(vg, -size * 0.5, -size * 0.5, size, size, 0,
            gib.img, nvgRGBA(255, 255, 255, alpha))
        nvgBeginPath(vg)
        nvgRect(vg, -size * 0.5, -size * 0.5, size, size)
        nvgFillPaint(vg, paint)
        nvgFill(vg)
        nvgRestore(vg)
    end

    -- ── 散弹枪枪口爆焰：锥形外焰 + 白芯 + 火星 ──
    if SHOTGUN_MUZZLE_FX then
        local fx = SHOTGUN_MUZZLE_FX
        local t = math.max(0, fx.life / fx.maxLife)
        local x = fx.x - cameraX
        local y = H * GROUND_Y_RATIO + fx.y
        local d = fx.dir
        nvgBeginPath(vg)
        nvgMoveTo(vg, x, y - 9 * t)
        nvgLineTo(vg, x + d * (58 + 34 * t), y)
        nvgLineTo(vg, x, y + 9 * t)
        nvgClosePath(vg)
        nvgFillColor(vg, nvgRGBA(255, 100, 20, math.floor(220 * t)))
        nvgFill(vg)
        nvgBeginPath(vg)
        nvgMoveTo(vg, x, y - 4 * t)
        nvgLineTo(vg, x + d * (38 + 20 * t), y)
        nvgLineTo(vg, x, y + 4 * t)
        nvgClosePath(vg)
        nvgFillColor(vg, nvgRGBA(255, 248, 190, math.floor(255 * t)))
        nvgFill(vg)
        for i = 1, 6 do
            local sparkX = x + d * (20 + i * 8) * t
            local sparkY = y + (i - 3.5) * 3.6 * t
            nvgBeginPath(vg)
            nvgCircle(vg, sparkX, sparkY, 1.2 + t)
            nvgFillColor(vg, nvgRGBA(255, 190, 55, math.floor(230 * t)))
            nvgFill(vg)
        end
    end

    -- ── 手枪枪口火焰：独立于子弹，固定在真实枪口位置 ──
    if PISTOL_MUZZLE_FX then
        local fx = PISTOL_MUZZLE_FX
        local t = math.max(0, fx.life / fx.maxLife)
        local x = fx.x - cameraX
        local y = H * GROUND_Y_RATIO + fx.y
        local cosA = math.cos(fx.angle)
        local sinA = math.sin(fx.angle)
        local length = 30 + 12 * t
        local width = 9 + 5 * t

        nvgBeginPath(vg)
        nvgMoveTo(vg, x, y)
        nvgLineTo(vg, x + cosA * length - sinA * width, y + sinA * length + cosA * width)
        nvgLineTo(vg, x + cosA * length * 0.72, y + sinA * length * 0.72)
        nvgLineTo(vg, x + cosA * length + sinA * width, y + sinA * length - cosA * width)
        nvgClosePath(vg)
        nvgFillColor(vg, nvgRGBA(255, 125, 24, math.floor(235 * t)))
        nvgFill(vg)

        nvgBeginPath(vg)
        nvgMoveTo(vg, x, y)
        nvgLineTo(vg, x + cosA * length * 0.68 - sinA * width * 0.42, y + sinA * length * 0.68 + cosA * width * 0.42)
        nvgLineTo(vg, x + cosA * length * 0.64, y + sinA * length * 0.64)
        nvgLineTo(vg, x + cosA * length * 0.68 + sinA * width * 0.42, y + sinA * length * 0.68 - cosA * width * 0.42)
        nvgClosePath(vg)
        nvgFillColor(vg, nvgRGBA(255, 250, 190, math.floor(255 * t)))
        nvgFill(vg)

        nvgBeginPath(vg)
        nvgCircle(vg, x, y, 4 + 3 * t)
        nvgFillColor(vg, nvgRGBA(255, 225, 90, math.floor(210 * t)))
        nvgFill(vg)
    end

    -- ── 子弹渲染 ──
    for _, b in ipairs(bullets) do
        local bx = b.x - cameraX
        local by = H * GROUND_Y_RATIO + b.y
        -- 计算子弹飞行角度（用于渲染方向）
        local bAngle = math.atan(b.vy or 0, b.vx or (b.dir * BULLET_SPEED))
        local cosA = math.cos(bAngle)
        local sinA = math.sin(bAngle)
        -- 枪口火焰（发射瞬间）
        if b.muzzleTimer > 0 then
            local flashAlpha = b.muzzleTimer / MUZZLE_FLASH_DUR
            local flashR = b.shotgunPellet and (8 + 12 * flashAlpha) or (12 + 8 * flashAlpha)
            -- 火焰在子弹后方（沿飞行反方向偏移）
            local fxOff = b.shotgunPellet and -7 or -10
            nvgBeginPath(vg)
            nvgCircle(vg, bx + cosA * fxOff, by + sinA * fxOff, flashR)
            nvgFillColor(vg, b.shotgunPellet
                and nvgRGBA(255, 145, 35, math.floor(225 * flashAlpha))
                or nvgRGBA(255, 200, 50, math.floor(200 * flashAlpha)))
            nvgFill(vg)
            nvgBeginPath(vg)
            nvgCircle(vg, bx + cosA * fxOff, by + sinA * fxOff, flashR * 0.5)
            nvgFillColor(vg, nvgRGBA(255, 255, 220, math.floor(255 * flashAlpha)))
            nvgFill(vg)
        end
        -- 子弹弹体（散弹使用更短、更亮的喷射拖尾）
        local tailLen = b.shotgunPellet and 10 or 18
        nvgBeginPath(vg)
        nvgMoveTo(vg, bx, by)
        nvgLineTo(vg, bx - cosA * tailLen, by - sinA * tailLen)
        nvgStrokeColor(vg, b.shotgunPellet
            and nvgRGBA(255, 175, 55, 235)
            or nvgRGBA(255, 220, 80, 220))
        nvgStrokeWidth(vg, b.shotgunPellet and 2 or 3)
        nvgStroke(vg)
        -- 弹头亮点
        nvgBeginPath(vg)
        nvgCircle(vg, bx, by, b.shotgunPellet and 2.2 or 3)
        nvgFillColor(vg, nvgRGBA(255, 255, 200, 255))
        nvgFill(vg)
    end

    -- ── 铁网栅栏（覆盖在角色之上）──
    do
        local fd = csInfo.fenceData
        if fd then
            local ctx = vg
            local fx, fy, fw, fh = fd.fx, fd.fy, fd.fw, fd.fh
            local postW = 6
            local postC = nvgRGBA(80, 85, 90, 220)
            local wireC = nvgRGBA(110, 120, 125, 180)
            local wireW = 1.2

            -- 菱形网格
            nvgSave(ctx)
            nvgScissor(ctx, fx + postW, fy, fw - postW * 2, fh)
            local cell = 14
            nvgStrokeColor(ctx, wireC)
            nvgStrokeWidth(ctx, wireW)
            local wireStartX = fx + postW - math.ceil(fh / cell) * cell
            local x = wireStartX
            while x < fx + fw - postW + fh do
                nvgBeginPath(ctx)
                nvgMoveTo(ctx, x, fy + fh)
                nvgLineTo(ctx, x + fh, fy)
                nvgStroke(ctx)
                x = x + cell
            end
            x = wireStartX
            while x < fx + fw - postW + fh do
                nvgBeginPath(ctx)
                nvgMoveTo(ctx, x, fy)
                nvgLineTo(ctx, x + fh, fy + fh)
                nvgStroke(ctx)
                x = x + cell
            end
            nvgRestore(ctx)

            -- 边框立柱
            nvgBeginPath(ctx); nvgRect(ctx, fx, fy, fw, postW)
            nvgFillColor(ctx, postC); nvgFill(ctx)
            nvgBeginPath(ctx); nvgRect(ctx, fx, fy + fh - postW, fw, postW)
            nvgFillColor(ctx, postC); nvgFill(ctx)
            nvgBeginPath(ctx); nvgRect(ctx, fx, fy, postW, fh)
            nvgFillColor(ctx, postC); nvgFill(ctx)
            nvgBeginPath(ctx); nvgRect(ctx, fx + fw - postW, fy, postW, fh)
            nvgFillColor(ctx, postC); nvgFill(ctx)
            -- 中间竖向门框
            local doorX = fx + math.floor(fw * 0.62)
            nvgBeginPath(ctx); nvgRect(ctx, doorX, fy, postW - 1, fh)
            nvgFillColor(ctx, postC); nvgFill(ctx)
        end
    end

    drawRain(vg)              -- 雨在角色之上，但剔除建筑区域内的雨滴
    drawBasementOverlay(vg)   -- 必须在玩家/丧尸之后，暗层才能盖住它们
    for _, sw in ipairs(lightSwitchDrawQueue) do
        drawLightSwitch(vg, sw.sx, sw.sy, sw.key, sw.isNear)
    end

    -- ── 碰撞体调试显示（暂时关闭）──────────────────────────
    if false then do
        local groundY = H * GROUND_Y_RATIO
        -- 楼板（绿色）
        for _, slab in ipairs(csColliders.slabs) do
            local sx1 = slab.wx1 - cameraX
            local sx2 = slab.wx2 - cameraX
            local sy1 = groundY + slab.relY
            local sy2 = sy1 + slab.thick
            nvgBeginPath(vg)
            nvgRect(vg, sx1, sy1, sx2 - sx1, sy2 - sy1)
            nvgFillColor(vg, nvgRGBA(0, 255, 0, 80))
            nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(0, 255, 0, 200))
            nvgStrokeWidth(vg, 1.5)
            nvgStroke(vg)
        end
        -- 玩家碰撞体（黄色）
        do
            local PHW = 20
            local px = player.x - cameraX
            local py = groundY + player.jumpScrY
            nvgBeginPath(vg)
            nvgRect(vg, px - PHW, py - player.drawH, PHW * 2, player.drawH)
            nvgFillColor(vg, nvgRGBA(255, 255, 0, 60))
            nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(255, 255, 0, 220))
            nvgStrokeWidth(vg, 1.5)
            nvgStroke(vg)
        end
        -- 墙体（红色）
        for _, wall in ipairs(csColliders.walls) do
            local sx1 = wall.wx1 - cameraX
            local sx2 = wall.wx2 - cameraX
            local sy1 = groundY + wall.relY1
            local sy2 = groundY + wall.relY2
            nvgBeginPath(vg)
            nvgRect(vg, sx1, sy1, sx2 - sx1, sy2 - sy1)
            nvgFillColor(vg, nvgRGBA(255, 0, 0, 80))
            nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(255, 0, 0, 200))
            nvgStrokeWidth(vg, 1.5)
            nvgStroke(vg)
        end
    end end  -- end if false

    drawBloodParticles(vg)
    drawParticles(vg)
    drawFog(vg)

    nvgRestore(vg)  -- 仅恢复场景变换，保留逻辑坐标的 DPR 缩放

    -- 开枪时全屏短暂暖色闪光，置于场景之上、HUD之下。
    if GUN_SCREEN_FLASH then
        local flashT = math.max(0, GUN_SCREEN_FLASH.life / GUN_SCREEN_FLASH.maxLife)
        local flashAlpha = math.floor(255 * GUN_SCREEN_FLASH.strength * flashT)
        nvgBeginPath(vg)
        nvgRect(vg, 0, 0, W, H)
        nvgFillColor(vg, nvgRGBA(255, 222, 150, flashAlpha))
        nvgFill(vg)
    end

    drawPlayerStatusHUD(vg)
    drawLightToggleUIButton(vg)
    drawExitHomeHUD(vg)

    -- ========== 信件界面（最顶层，纸张效果） ==========
    if lootUI.letterOpen then
        nvgSave(vg)
        nvgResetTransform(vg)
        nvgResetScissor(vg)
        nvgScale(vg, dpr, dpr)
        lootUI.DrawLetterUI(vg, W, H)
        nvgRestore(vg)
    end

    -- 搜刮交互按钮最后绘制，确保不会被信件或其他 HUD 盖住。
    drawSearchButton(vg)

    -- ========== 摸金UI（最顶层绘制，屏幕坐标系，居中） ==========
    if lootUI.active then
        nvgSave(vg)
        nvgResetTransform(vg)
        nvgResetScissor(vg)
        nvgScale(vg, dpr, dpr)
        drawLootUI(vg, W, H)
        local hasTouchInput = ((input.numTouches or 0) > 0) or lootUI._touchActive
        local mouseX = input.mousePosition.x / dpr
        local mouseY = input.mousePosition.y / dpr
        if not hasTouchInput and input:GetMouseButtonPress(MOUSEB_LEFT) and lootUI.IsCloseButtonHit(mouseX, mouseY) then
            lootUI.Close()
        -- 拖拽处理（鼠标）
        elseif not hasTouchInput and not lootUI.dragging then
            if input:GetMouseButtonPress(MOUSEB_LEFT) then
                handleLootUIMouseDown(mouseX, mouseY, false, "mouse")
            end
        elseif lootUI.dragInput == "mouse" then
            -- 更新鼠标拖拽位置
            lootUI.dragMouseX = mouseX
            lootUI.dragMouseY = mouseY
            -- 松开放置
            if not input:GetMouseButtonDown(MOUSEB_LEFT) then
                handleLootUIMouseUp(lootUI.dragMouseX, lootUI.dragMouseY)
            end
        end
        -- (手机触摸拖拽已在 HandleUpdate 中处理)
        nvgRestore(vg)
    end

    -- 设置弹窗最后绘制，覆盖所有战斗 HUD 与虚拟控件。
    drawSettingsUI(vg)

    nvgRestore(vg)  -- 恢复帧级 DPR 缩放
    nvgEndFrame(vg)
end


