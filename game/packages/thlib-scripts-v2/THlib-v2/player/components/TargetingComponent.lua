---目标锁定组件
local abs = math.abs

---@class THlib.Player.TargetingComponent : foundation.Component
---@field customFunc function|nil
---@field inputComp THlib.Player.InputComponent|nil

---创建目标锁定组件
---@param owner THlib.Player
---@param config table
---@return THlib.Player.TargetingComponent
local function create(owner, config)
    config = config or {}

    ---@type THlib.Player.TargetingComponent
    local component = {
        enabled = true,
        executePriority = 8,
        typeName = "targeting",
        owner = owner,
        customFunc = config.customFunc,
    }

    function component:resolveDependencies(gameObject)
        local inputComp = gameObject:getComponent("input")
        self.inputComp = inputComp
    end

    function component:update()
        local player = self.owner

        if not self.inputComp or not self.inputComp.keyState.shoot then
            player.target = nil
            return
        end

        if IsValid(player.target) and player.target.colli then
            return
        end

        if self.customFunc then
            self.customFunc(player)
            return
        end

        player.target = nil
        local maxPri = -1
        local px = player.x
        local py = player.y

        for _, o in ObjList(GROUP_ENEMY) do
            if o.colli then
                local dx = px - o.x
                local dy = py - o.y
                local pri = abs(dy) / (abs(dx) + 0.01)
                if pri > maxPri then
                    maxPri = pri
                    player.target = o
                end
            end
        end

        for _, o in ObjList(GROUP_NONTJT) do
            if o.colli then
                local dx = px - o.x
                local dy = py - o.y
                local pri = abs(dy) / (abs(dx) + 0.01)
                if pri > maxPri then
                    maxPri = pri
                    player.target = o
                end
            end
        end
    end

    return component
end

return {
    create = create,
}

