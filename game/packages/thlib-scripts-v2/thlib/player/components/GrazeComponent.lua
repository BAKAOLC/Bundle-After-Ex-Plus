---擦弹组件
local grazer_class = require("thlib.player.objects.Grazer")

---@class thlib.Player.GrazeComponent : core.Component
---@field grazeRadius number
---@field visualRadius number
---@field grazeObject lstg.GameObject|nil
---@field onGrazeCallback function|nil
---@field lh number 低速光环强度 (0~1)

---创建擦弹组件
---@param owner thlib.Player
---@param config table
---@return thlib.Player.GrazeComponent
local function create(owner, config)
    config = config or {}

    ---@type thlib.Player.GrazeComponent
    local component = {
        enabled = true,
        executePriority = 7,
        typeName = "graze",
        owner = owner,
        grazeRadius = config.grazeRadius or 24,
        visualRadius = config.visualRadius or 24,
        grazeObject = nil,
        onGrazeCallback = config.onGraze,
        lh = 0, -- 低速光环强度
    }

    function component:onAdd()
        local player = self.owner
        -- 创建擦弹判定对象
        self.grazeObject = New(grazer_class, player)
        if self.grazeObject then
            self.grazeObject.a = self.grazeRadius
            self.grazeObject.b = self.grazeRadius
        end
    end

    function component:onRemove()
        if IsValid(self.grazeObject) then
            Del(self.grazeObject)
            self.grazeObject = nil
        end
    end

    function component:onGraze(grazedObject)
        -- 触发擦弹
        lstg.var.graze = lstg.var.graze + 1

        -- 调用自定义回调
        if self.onGrazeCallback then
            self.onGrazeCallback(self.owner, grazedObject)
        end

        -- 触发事件，传递被擦弹的对象
        self.owner:_dispatchEvent("onGraze", grazedObject)
    end

    function component:update()
        -- 更新低速光环强度（平滑过渡）
        local player = self.owner
        self.lh = self.lh + (player.slow - 0.5) * 0.3
        if self.lh < 0 then
            self.lh = 0
        elseif self.lh > 1 then
            self.lh = 1
        end
    end

    return component
end

return {
    create = create,
}



