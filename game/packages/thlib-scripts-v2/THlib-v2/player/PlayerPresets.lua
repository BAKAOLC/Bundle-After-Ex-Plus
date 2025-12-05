---玩家预设配置
---提供默认的组件配置

local Presets = {}

---默认组件配置
---@return table
function Presets.default()
    return {
        -- 状态机配置
        state = {
            enableDeathSpell = true,
            deathSpellDuration = 10,
            deathAnimationDuration = 90,
            respawnMode = "bottom",
            respawnDuration = 60,
        },

        -- 输入组件（默认启用，无需配置）
        input = {},

        -- 保护组件配置
        protect = {
            initialProtectTime = 180, -- 初始无敌时间
            respawnProtectTime = 120, -- 重生后无敌时间
        },

        -- 火力组件配置（默认启用）
        power = {
            supportLerpSpeed = 0.0625, -- 子机数量变化速度
            supportPosLerpSpeed = 0.6875, -- 子机位置跟随速度
        },

        -- 移动组件配置（支持8向移动）
        movement = {
            highSpeed = 4.5,
            lowSpeed = 2.0,
            use8Directions = true, -- false允许任意方向，true限制为8方向
            bounds = {
                left = 8,
                right = 8,
                bottom = 16,
                top = 32,
            }
        },

        -- 计时器配置
        timer = {
            timers = {
                shoot = 0,
                spell = 0,
                special = 0,
            }
        },

        -- Buff组件（默认启用，无需配置）
        buff = {},

        -- 倍率组件配置
        multiplier = {
            multipliers = {
                damage = 1.0,
                speed = 1.0,
            }
        },

        -- 碰撞处理（默认启用，无需配置）
        collision = {},

        -- 擦弹组件（默认启用，无需配置）
        graze = {},

        -- 复活组件配置
        respawn = {
            respawnX = 0,
            respawnY = -176,
        },

        -- 死亡动画配置
        deathAnimation = {
            style = "classic", -- "classic" / "simple" / "none"
        },

        -- 道具收集配置
        itemCollection = {
            collectLine = 96,
        },

        -- 目标锁定（默认启用，无需配置）
        targeting = {},

        -- 行走图（默认启用，无需配置）
        walkImage = {},
    }
end

return Presets
