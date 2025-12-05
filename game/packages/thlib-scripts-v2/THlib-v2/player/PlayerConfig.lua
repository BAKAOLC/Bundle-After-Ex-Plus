---玩家基础配置（仅包含非组件相关的核心配置）
---组件特定配置应通过 setupComponents 的 componentConfigs 参数传入

---@class THlib.Player.Config
---@field initialX number 初始X坐标
---@field initialY number 初始Y坐标
---@field a number 碰撞框半长轴（椭圆）
---@field b number 碰撞框半短轴（椭圆）
---@field rect boolean 是否使用矩形碰撞框
local Config = {}

---创建默认配置
---@return THlib.Player.Config
function Config.createDefault()
    return {
        initialX = 0,
        initialY = -176,
        a = 2,
        b = 2,
        rect = false,
    }
end

---合并配置
---@param base THlib.Player.Config
---@param override table|nil
---@return THlib.Player.Config
function Config.merge(base, override)
    override = override or {}
    return {
        initialX = override.initialX or base.initialX,
        initialY = override.initialY or base.initialY,
        a = override.a or base.a,
        b = override.b or base.b,
        rect = override.rect == nil and base.rect or override.rect,
    }
end

return Config

