---道具收集组件
local TypeDef = require("core.TypeDef")
local ComponentSystem = require("core.ComponentSystem")

---@class thlib.Player.ItemCollectionComponent : core.Component
---@field collectLine number
---@field slowRange number
---@field normalRange number
---@field customFunc function|nil

-- 定义组件类型
local ItemCollectionComponentType = TypeDef.create("thlib.Player.ItemCollectionComponent", ComponentSystem.ComponentType, {
    defaults = {
        enabled = true,
        executePriority = 5,
        collectLine = 96,
        slowRange = 48,
        normalRange = 24,
        customFunc = nil,
    },
    methods = {
        Update = function(self)
            local player = self.owner

            if player.__currentState ~= "normal" and player.__currentState ~= "protected" then
                return
            end

            if self.customFunc then
                self.customFunc(player, self)
                return
            end

            if player.y > self.collectLine then
                for _, o in ObjList(GROUP_ITEM) do
                    if o.attract < 8 then
                        o.attract = 8
                        o.target = player
                    end
                end
            else
                local range = player.slow == 1 and self.slowRange or self.normalRange
                local rangeSq = range * range
                local px = player.x
                local py = player.y

                for _, o in ObjList(GROUP_ITEM) do
                    local dx = px - o.x
                    local dy = py - o.y
                    local distSq = dx * dx + dy * dy
                    if distSq < rangeSq then
                        if o.attract < 3 then
                            o.attract = 3
                            o.target = player
                        end
                    end
                end
            end
        end,
    },
})

---创建道具收集组件
---@param config table
---@return thlib.Player.ItemCollectionComponent
local function create(config)
    config = config or {}
    return TypeDef.instantiate(ItemCollectionComponentType, {
        collectLine = config.collectLine or 96,
        slowRange = config.slowRange or 48,
        normalRange = config.normalRange or 24,
        customFunc = config.customFunc,
    })
end

return {
    create = create,
    Type = ItemCollectionComponentType,
}

