---血量组件
local TypeDef = require("core.TypeDef")
local ComponentSystem = require("core.ComponentSystem")

---@class components.HealthComponent : core.Component
---@field maxHealth number 最大血量
---@field currentHealth number 当前血量
---@field onHealthChanged function|nil 血量变化回调 function(healthComponent, oldHealth, newHealth, delta)
---@field onHealthDepleted function|nil 血量耗尽回调 function(healthComponent)
---@field onHealthFull function|nil 血量回满回调 function(healthComponent)

-- 定义组件类型
local HealthComponentType = TypeDef.create("components.HealthComponent", ComponentSystem.ComponentType, {
    defaults = {
        enabled = true,
        executePriority = 90,
        alias = "health",
        maxHealth = 100,
        currentHealth = nil,
        onHealthChanged = nil,
        onHealthDepleted = nil,
        onHealthFull = nil,
    },
    methods = {
        Awake = function(self)
            -- 初始化当前血量
            if self.currentHealth == nil then
                self.currentHealth = self.maxHealth
            end

            -- 确保当前血量不超过最大血量
            if self.currentHealth > self.maxHealth then
                self.currentHealth = self.maxHealth
            end
        end,

        -- 设置最大血量
        setMaxHealth = function(self, maxHealth)
            local oldMax = self.maxHealth
            self.maxHealth = maxHealth
            if self.maxHealth < 0 then
                self.maxHealth = 0
            end

            -- 如果当前血量超过新的最大血量，调整当前血量
            if self.currentHealth > self.maxHealth then
                self.currentHealth = self.maxHealth
            end
        end,

        -- 设置当前血量
        setHealth = function(self, health)
            local oldHealth = self.currentHealth
            self.currentHealth = health

            -- 限制在 0 到 maxHealth 之间
            if self.currentHealth < 0 then
                self.currentHealth = 0
            elseif self.currentHealth > self.maxHealth then
                self.currentHealth = self.maxHealth
            end

            local delta = self.currentHealth - oldHealth
            if delta ~= 0 then
                self:_notifyHealthChanged(oldHealth, self.currentHealth, delta)
            end
        end,

        -- 接收伤害
        takeDamage = function(self, damage, source)
            if damage <= 0 then
                return 0
            end

            local oldHealth = self.currentHealth
            local actualDamage = damage

            -- 如果伤害超过当前血量，只造成当前血量的伤害
            if actualDamage > self.currentHealth then
                actualDamage = self.currentHealth
            end

            self.currentHealth = self.currentHealth - actualDamage

            if self.currentHealth < 0 then
                self.currentHealth = 0
            end

            local delta = self.currentHealth - oldHealth
            self:_notifyHealthChanged(oldHealth, self.currentHealth, delta)

            return actualDamage
        end,

        -- 治疗
        heal = function(self, heal)
            if heal <= 0 then
                return 0
            end

            local oldHealth = self.currentHealth
            local actualHeal = heal

            -- 如果治疗超过最大血量，只治疗到最大血量
            if self.currentHealth + actualHeal > self.maxHealth then
                actualHeal = self.maxHealth - self.currentHealth
            end

            self.currentHealth = self.currentHealth + actualHeal

            if self.currentHealth > self.maxHealth then
                self.currentHealth = self.maxHealth
            end

            local delta = self.currentHealth - oldHealth
            if delta ~= 0 then
                self:_notifyHealthChanged(oldHealth, self.currentHealth, delta)
            end

            return actualHeal
        end,

        -- 恢复满血
        fullHeal = function(self)
            if self.currentHealth ~= self.maxHealth then
                local oldHealth = self.currentHealth
                self.currentHealth = self.maxHealth
                local delta = self.currentHealth - oldHealth
                self:_notifyHealthChanged(oldHealth, self.currentHealth, delta)
            end
        end,

        -- 获取当前血量
        getHealth = function(self)
            return self.currentHealth
        end,

        -- 获取最大血量
        getMaxHealth = function(self)
            return self.maxHealth
        end,

        -- 获取血量百分比
        getHealthPercent = function(self)
            if self.maxHealth <= 0 then
                return 0
            end
            return self.currentHealth / self.maxHealth
        end,

        -- 检查是否存活
        isAlive = function(self)
            return self.currentHealth > 0
        end,

        -- 检查是否死亡
        isDead = function(self)
            return self.currentHealth <= 0
        end,

        -- 检查是否满血
        isFullHealth = function(self)
            return self.currentHealth >= self.maxHealth
        end,

        -- 通知血量变化
        -- @private
        _notifyHealthChanged = function(self, oldHealth, newHealth, delta)
            if self.onHealthChanged then
                self.onHealthChanged(self, oldHealth, newHealth, delta)
            end

            -- 血量耗尽
            if newHealth <= 0 and oldHealth > 0 then
                if self.onHealthDepleted then
                    self.onHealthDepleted(self)
                end
            end

            -- 血量回满
            if newHealth >= self.maxHealth and oldHealth < self.maxHealth then
                if self.onHealthFull then
                    self.onHealthFull(self)
                end
            end
        end,
    },
})

---创建Health组件
---@param config table
---@return components.HealthComponent
local function create(config)
    config = config or {}
    return TypeDef.instantiate(HealthComponentType, config)
end

return {
    create = create,
    Type = HealthComponentType,
}
