local type = type

---伤害接收组件（装备在接受伤害的实体上）
local TypeDef = require("core.TypeDef")
local ComponentSystem = require("core.ComponentSystem")

---@class components.DamageReceiverComponent : core.Component
---@field onDamageReceived function|nil 接收伤害回调 function(damageReceiverComponent, source, damageInfo, actualDamage)
---@field onDamageBlocked function|nil 伤害被阻挡回调 function(damageReceiverComponent, source, damageInfo)

-- 定义组件类型
local DamageReceiverComponentType = TypeDef.create("components.DamageReceiverComponent", ComponentSystem.ComponentType, {
    defaults = {
        enabled = true,
        executePriority = 85,
        alias = "damageReceiver",
        onDamageReceived = nil,
        onDamageBlocked = nil,
    },
    methods = {
        -- 接收伤害
        -- @param damage number|components.DamageInfo 伤害值或伤害信息对象
        -- @param source any|nil 伤害来源（当damage为数字时使用）
        -- @param damageType string|nil 伤害类型（当damage为数字时使用）
        -- @return number|nil 实际造成的伤害值，如果被阻挡或无效则返回0或nil
        takeDamage = function(self, damage, source, damageType)
            -- 构建伤害信息
            local damageInfo
            if type(damage) == "number" then
                damageInfo = {
                    damage = damage,
                    source = source,
                    damageType = damageType,
                    canBlock = true,
                    data = {},
                }
            else
                damageInfo = damage
                if damageInfo.canBlock == nil then
                    damageInfo.canBlock = true
                end
                if not damageInfo.data then
                    damageInfo.data = {}
                end
            end

            -- 检查是否有 HealthComponent
            local healthComp
            if self.owner and self.owner.getComponent then
                healthComp = self.owner:getComponent("health")
            end

            if not healthComp then
                return nil
            end

            -- 检查是否被阻挡
            if damageInfo.canBlock and self:_checkBlocked(damageInfo) then
                if self.onDamageBlocked then
                    self.onDamageBlocked(self, damageInfo.source, damageInfo)
                end
                return 0
            end

            -- 应用受伤倍率
            local finalDamage = damageInfo.damage
            if self.owner and self.owner.getComponent then
                local modifierComp = self.owner:getComponent("modifier")
                if modifierComp then
                    finalDamage = modifierComp:apply("damageReceived", finalDamage)
                end
            end

            -- 更新伤害信息中的最终伤害值
            damageInfo.damage = finalDamage

            -- 应用伤害
            local actualDamage = healthComp:takeDamage(finalDamage, damageInfo.source)

            -- 通知接收伤害
            if self.onDamageReceived then
                self.onDamageReceived(self, damageInfo.source, damageInfo, actualDamage)
            end

            return actualDamage
        end,

        -- 检查伤害是否被阻挡
        -- @private
        _checkBlocked = function(self, damageInfo)
            return false
        end,

        -- 创建伤害信息（辅助方法）
        createDamageInfo = function(self, damage, source, damageType, canBlock, data)
            return {
                damage = damage,
                source = source,
                damageType = damageType,
                canBlock = canBlock ~= false,
                data = data or {},
            }
        end,
    },
})

---创建DamageReceiver组件
---@param config table
---@return components.DamageReceiverComponent
local function create(config)
    config = config or {}
    return TypeDef.instantiate(DamageReceiverComponentType, config)
end

return {
    create = create,
    Type = DamageReceiverComponentType,
}

