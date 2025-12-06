---擦弹组件
local grazer_class = require("thlib.player.objects.Grazer")
local TypeDef = require("core.TypeDef")
local ComponentSystem = require("core.ComponentSystem")

---@class thlib.Player.GrazeComponent : core.Component
---@field grazeRadius number
---@field visualRadius number
---@field grazeObject lstg.GameObject|nil
---@field onGrazeCallback function|nil
---@field lh number 低速光环强度 (0~1)

-- 定义组件类型
local GrazeComponentType = TypeDef.create("thlib.Player.GrazeComponent", ComponentSystem.ComponentType, {
    defaults = {
        enabled = true,
        executePriority = 7,
        grazeRadius = 24,
        visualRadius = 24,
        grazeObject = nil,
        onGrazeCallback = nil,
        lh = 0, -- 低速光环强度
    },
    methods = {
        Awake = function(self)
            local player = self.owner
            -- 创建擦弹判定对象
            self.grazeObject = New(grazer_class, player)
            if self.grazeObject then
                self.grazeObject.a = self.grazeRadius
                self.grazeObject.b = self.grazeRadius
            end

            -- 注册删除事件，清理 Grazer 对象
            player:registerEvent("onDelete", "grazeDeleteHandler", 10, function(p)
                if IsValid(self.grazeObject) then
                    Del(self.grazeObject)
                    self.grazeObject = nil
                end
            end)
        end,

        OnDestroy = function(self)
            local player = self.owner
            -- 取消注册事件
            player:unregisterEvent("onDelete", "grazeDeleteHandler")

            -- 清理 Grazer 对象（作为备用清理）
            if IsValid(self.grazeObject) then
                Del(self.grazeObject)
                self.grazeObject = nil
            end
        end,

        onGraze = function(self, grazedObject)
            -- 触发擦弹
            lstg.var.graze = lstg.var.graze + 1

            -- 调用自定义回调
            if self.onGrazeCallback then
                self.onGrazeCallback(self.owner, grazedObject)
            end

            -- 触发事件，传递被擦弹的对象
            self.owner:_dispatchEvent("onGraze", grazedObject)
        end,

        Update = function(self)
            -- 更新低速光环强度（平滑过渡）
            local player = self.owner
            self.lh = self.lh + (player.slow - 0.5) * 0.3
            if self.lh < 0 then
                self.lh = 0
            elseif self.lh > 1 then
                self.lh = 1
            end
        end,
    },
})

---创建擦弹组件
---@param config table
---@return thlib.Player.GrazeComponent
local function create(config)
    config = config or {}
    return TypeDef.instantiate(GrazeComponentType, {
        grazeRadius = config.grazeRadius or 24,
        visualRadius = config.visualRadius or 24,
        onGrazeCallback = config.onGraze,
    })
end

return {
    create = create,
    Type = GrazeComponentType,
}



