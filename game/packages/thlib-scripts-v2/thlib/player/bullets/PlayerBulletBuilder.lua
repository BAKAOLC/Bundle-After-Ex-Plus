local tonumber = tonumber
local pairs = pairs
local math = math

local GameObject = require("core.GameObject")
local TypeDef = require("core.TypeDef")
local PlayerBullet = require("thlib.player.bullets.PlayerBullet")

---玩家子弹构建器
---用于方便地定义和创建新的子弹类型
local PlayerBulletBuilder = {}

---创建新的子弹类型
---@param name string 子弹类型名称
---@param baseType core.TypeDef|nil 基类型（默认为 PlayerBullet.Type）
---@param definition table 定义表
---@return core.TypeDef 新的子弹类型
function PlayerBulletBuilder.createType(name, baseType, definition)
    baseType = baseType or PlayerBullet.Type
    definition = definition or {}

    -- 合并默认值
    local defaults = {}
    if definition.defaults then
        for k, v in pairs(definition.defaults) do
            defaults[k] = v
        end
    end

    -- 合并方法
    local methods = {}
    if definition.methods then
        for k, v in pairs(definition.methods) do
            methods[k] = v
        end
    end

    -- 创建类型
    local BulletType = TypeDef.create(name, baseType, {
        defaults = defaults,
        methods = methods,
    })

    return BulletType
end

---创建直线子弹类型
---@return core.TypeDef 直线子弹类型
function PlayerBulletBuilder.createStraightType()
    return PlayerBulletBuilder.createType("thlib.player.bullets.PlayerBulletStraight", PlayerBullet.Type, {
        defaults = {},
        methods = {
            Awake = function(self)
                -- 设置速度（从 speed 和 angle/rot 中获取）
                if self.speed and (self.angle or self.rot) then
                    local speed = tonumber(self.speed) or 0
                    local angle = tonumber(self.angle or self.rot) or 0
                    self.vx = speed * cos(angle)
                    self.vy = speed * sin(angle)
                else
                    -- 如果没有提供速度，初始化为 0
                    if not self.vx then
                        self.vx = 0
                    end
                    if not self.vy then
                        self.vy = 0
                    end
                end
            end,
        },
    })
end

---创建追踪子弹类型
---@return core.TypeDef 追踪子弹类型
function PlayerBulletBuilder.createTrailType()
    return PlayerBulletBuilder.createType("thlib.player.bullets.PlayerBulletTrail", PlayerBullet.Type, {
        defaults = {
            speed = 0,
            target = nil,
            trail = 1,
        },
        methods = {
            Awake = function(self)
                -- 调用基类 Awake
                if PlayerBullet.Type.defaults and PlayerBullet.Type.defaults.methods and PlayerBullet.Type.defaults.methods.Awake then
                    PlayerBullet.Type.defaults.methods.Awake(self)
                end

                -- 初始化速度
                if self.speed and self.rot then
                    local speed = tonumber(self.speed) or 0
                    self.vx = speed * cos(self.rot)
                    self.vy = speed * sin(self.rot)
                end
            end,

            Update = function(self)
                -- 追踪逻辑
                if IsValid(self.target) and self.target.colli then
                    local a = math.mod(Angle(self, self.target) - self.rot + 720, 360)
                    if a > 180 then
                        a = a - 360
                    end
                    local da = self.trail / (Dist(self, self.target) + 1)
                    if da >= abs(a) then
                        self.rot = Angle(self, self.target)
                    else
                        self.rot = self.rot + sign(a) * da
                    end
                end

                -- 更新速度
                if self.speed then
                    local speed = tonumber(self.speed) or 0
                    self.vx = speed * cos(self.rot)
                    self.vy = speed * sin(self.rot)
                end
            end,
        },
    })
end

---创建直线子弹实例的便捷函数
---@param img string 图片名称
---@param x number x坐标
---@param y number y坐标
---@param v number 速度
---@param angle number 角度
---@param damage number 伤害值
---@return core.GameObject 子弹实例
function PlayerBulletBuilder.newStraight(img, x, y, v, angle, damage)
    local StraightType = PlayerBulletBuilder.createStraightType()

    local bullet = GameObject.create(StraightType, {
        img = img,
        x = x,
        y = y,
        rot = angle,
        damage = damage,
        speed = v,
        angle = angle,
    })

    return bullet
end

---创建追踪子弹实例的便捷函数
---@param img string 图片名称
---@param x number x坐标
---@param y number y坐标
---@param v number 速度
---@param angle number 初始角度
---@param target lstg.GameObject|nil 追踪目标
---@param trail number 追踪强度
---@param damage number 伤害值
---@return core.GameObject 子弹实例
function PlayerBulletBuilder.newTrail(img, x, y, v, angle, target, trail, damage)
    local TrailType = PlayerBulletBuilder.createTrailType()

    local bullet = GameObject.create(TrailType, {
        img = img,
        x = x,
        y = y,
        rot = angle,
        damage = damage,
        speed = v,
        target = target,
        trail = trail or 1,
    })

    return bullet
end

---定义自定义子弹类型的便捷方法
---@param name string 子弹类型名称
---@param definition table 定义表
---@return core.TypeDef 新的子弹类型
function PlayerBulletBuilder.define(name, definition)
    local baseType = definition.base or PlayerBullet.Type

    return PlayerBulletBuilder.createType(name, baseType, {
        defaults = definition.defaults,
        methods = definition.methods,
    })
end

return PlayerBulletBuilder

