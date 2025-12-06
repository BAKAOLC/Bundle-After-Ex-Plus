local GameObject = require("core.GameObject")
local PlayerBullet = require("thlib.player.bullets.PlayerBullet")
local PlayerBulletBuilder = require("thlib.player.bullets.PlayerBulletBuilder")

---常用子弹类型
local CommonBullets = {}

-- 缓存子弹类型（避免重复创建）
local _straightType = nil
local _trailType = nil

---获取直线子弹类型
---@return core.TypeDef
function CommonBullets.getStraightType()
    if not _straightType then
        _straightType = PlayerBulletBuilder.createStraightType()
    end
    return _straightType
end

---获取追踪子弹类型
---@return core.TypeDef
function CommonBullets.getTrailType()
    if not _trailType then
        _trailType = PlayerBulletBuilder.createTrailType()
    end
    return _trailType
end

---创建直线子弹
---@param img string 图片名称
---@param x number x坐标
---@param y number y坐标
---@param v number 速度
---@param angle number 角度
---@param damage number 伤害值
---@return core.GameObject 子弹实例
function CommonBullets.newStraight(img, x, y, v, angle, damage)
    local bullet = GameObject.create(CommonBullets.getStraightType(), {
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

---创建追踪子弹
---@param img string 图片名称
---@param x number x坐标
---@param y number y坐标
---@param v number 速度
---@param angle number 初始角度
---@param target lstg.GameObject|nil 追踪目标
---@param trail number 追踪强度
---@param damage number 伤害值
---@return core.GameObject 子弹实例
function CommonBullets.newTrail(img, x, y, v, angle, target, trail, damage)
    local bullet = GameObject.create(CommonBullets.getTrailType(), {
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

return CommonBullets

