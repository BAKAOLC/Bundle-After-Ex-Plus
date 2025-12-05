---道具收集组件
---@class THlib.Player.ItemCollectionComponent : foundation.Component
---@field collectLine number
---@field slowRange number
---@field normalRange number
---@field customFunc function|nil

---创建道具收集组件
---@param owner THlib.Player
---@param config table
---@return THlib.Player.ItemCollectionComponent
local function create(owner, config)
    config = config or {}

    local collectLine = config.collectLine or 96
    local slowRange = config.slowRange or 48
    local normalRange = config.normalRange or 24
    local customFunc = config.customFunc

    ---@type THlib.Player.ItemCollectionComponent
    local component = {
        enabled = true,
        executePriority = 5,
        typeName = "itemCollection",
        owner = owner,
        collectLine = collectLine,
        slowRange = slowRange,
        normalRange = normalRange,
        customFunc = customFunc,
    }

    function component:update()
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
    end

    return component
end

return {
    create = create,
}

