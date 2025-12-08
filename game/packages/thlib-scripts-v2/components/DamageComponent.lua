local type = type

---伤害组件（装备在造成伤害的实体上）
local TypeDef = require("core.TypeDef")
local ComponentSystem = require("core.ComponentSystem")

---构建伤害信息
---@param damage number 伤害值
---@param source any|nil 伤害来源
---@param damageType string|nil 伤害类型
---@param canBlock boolean|nil 是否可以被阻挡
---@param data table|nil 自定义数据
---@return components.DamageInfo
local function buildDamageInfo(damage, source, damageType, canBlock, data)
    return {
        damage = damage,
        source = source,
        damageType = damageType,
        canBlock = canBlock ~= false,
        data = data or {},
    }
end

---应用伤害倍率修饰器
---@param owner any 拥有者对象
---@param damage number 原始伤害值
---@return number 应用修饰后的伤害值
local function applyDamageModifier(owner, damage)
    if owner and owner.getComponent then
        local modifierComp = owner:getComponent("modifier")
        if modifierComp then
            return modifierComp:apply("damageDealt", damage)
        end
    end
    return damage
end

---@class components.DamageInfo
---@field damage number 伤害值
---@field source any|nil 伤害来源
---@field damageType string|nil 伤害类型
---@field canBlock boolean 是否可以被阻挡
---@field data table|nil 自定义数据

---@class components.DamageComponent : core.Component
---@field baseDamage number|nil 基础伤害值（可选，用于自动计算）

-- 定义组件类型
local DamageComponentType = TypeDef.create("components.DamageComponent", ComponentSystem.ComponentType, {
    defaults = {
        enabled = true,
        executePriority = 80,
        alias = "damage",
        baseDamage = nil,
    },
    methods = {
        -- 对目标造成伤害
        -- @param target any 目标对象（需要有 getComponent 方法）
        -- @param damage number|components.DamageInfo|nil 伤害值或伤害信息对象（如果为nil，使用baseDamage）
        -- @param source any|nil 伤害来源（当damage为数字时使用，默认使用self.owner）
        -- @param damageType string|nil 伤害类型（当damage为数字时使用）
        -- @return number|nil 实际造成的伤害值，如果目标无效或没有DamageReceiverComponent则返回nil
        dealDamage = function(self, target, damage, source, damageType)
            if not target or not target.getComponent then
                return nil
            end

            -- 获取目标的 DamageReceiverComponent
            local receiverComp = target:getComponent("damageReceiver")
            if not receiverComp then
                return nil
            end

            -- 构建伤害信息
            local damageInfo
            if damage == nil then
                -- 如果没有提供伤害值，使用baseDamage
                if self.baseDamage == nil then
                    return nil
                end
                damage = self.baseDamage
            end

            if type(damage) == "number" then
                -- 应用伤害倍率（通过ModifierComponent）
                local finalDamage = applyDamageModifier(self.owner, damage)
                damageInfo = buildDamageInfo(finalDamage, source or self.owner, damageType, true, {})
            else
                damageInfo = damage
                -- 应用伤害倍率
                damageInfo.damage = applyDamageModifier(self.owner, damageInfo.damage)
                -- 如果没有指定source，使用self.owner
                if not damageInfo.source then
                    damageInfo.source = self.owner
                end
                if damageInfo.canBlock == nil then
                    damageInfo.canBlock = true
                end
                if not damageInfo.data then
                    damageInfo.data = {}
                end
            end

            -- 对目标造成伤害
            local actualDamage = receiverComp:takeDamage(damageInfo)

            -- 通过事件系统通知造成伤害
            if actualDamage and actualDamage > 0 and self.owner and self.owner._dispatchEvent then
                self.owner:_dispatchEvent("DamageComponent:onDamageDealt", self, target, damageInfo, actualDamage)
            end

            return actualDamage
        end,

        -- 创建伤害信息（辅助方法）
        createDamageInfo = function(self, damage, source, damageType, canBlock, data)
            -- 应用伤害倍率
            local finalDamage = applyDamageModifier(self.owner, damage)
            return buildDamageInfo(finalDamage, source or self.owner, damageType, canBlock, data)
        end,

        -- 设置基础伤害值
        setBaseDamage = function(self, damage)
            self.baseDamage = damage
        end,

        -- 获取基础伤害值
        getBaseDamage = function(self)
            return self.baseDamage
        end,
    },
})

---创建Damage组件
---@param config table
---@return components.DamageComponent
local function create(config)
    config = config or {}
    return TypeDef.instantiate(DamageComponentType, config)
end

return {
    create = create,
    Type = DamageComponentType,
}
