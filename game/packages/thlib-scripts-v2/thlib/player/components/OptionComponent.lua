local ipairs = ipairs
local table = table

---子机组件
local Option = require("thlib.player.components.Option")
local TypeDef = require("core.TypeDef")
local ComponentSystem = require("core.ComponentSystem")

---@class thlib.Player.OptionComponent : core.Component
---@field options thlib.Player.Option[] 子机对象数组
---@field powerComp thlib.Player.PowerComponent|nil 火力组件引用

-- 定义组件类型
local OptionComponentType = TypeDef.create("thlib.Player.OptionComponent", ComponentSystem.ComponentType, {
    defaults = {
        enabled = true,
        executePriority = 3,
        renderPriority = 3,
        alias = "option",
        options = {},
        powerComp = nil,
    },
    methods = {
        Awake = function(self)
            -- 从配置创建子机对象
            if self._config and self._config.options then
                for i, optionConfig in ipairs(self._config.options) do
                    self.options[i] = Option.new(self.owner, i, optionConfig)
                end
            end
            self._config = nil
        end,

        Start = function(self)
            -- 获取火力组件
            self.powerComp = self.owner:getComponent("power")

            -- 将火力组件引用传递给所有子机，并初始化状态
            for _, option in ipairs(self.options) do
                option:setPowerComponent(self.powerComp)

                -- 初始化子机的激活状态
                if self.powerComp then
                    local support = self.powerComp:getSupport()
                    option.active = (support >= option.requiredPower)
                    option.alpha = option.active and 1.0 or 0
                    option.visible = option.alpha > 0
                end

                -- 调用子机的 Start 生命周期（第一次调用时）
                if not option._lifecycleStarted then
                    option._lifecycleStarted = true
                    local start = option.Start
                    if start then
                        start(option)
                    end
                end
            end
        end,

        Update = function(self)
            -- 更新所有子机
            for _, option in ipairs(self.options) do
                local update = option.Update
                if update then
                    update(option)
                end
            end
        end,

        LateUpdate = function(self)
            -- 更新所有子机的 LateUpdate 生命周期
            for _, option in ipairs(self.options) do
                local lateUpdate = option.LateUpdate
                if lateUpdate then
                    lateUpdate(option)
                end
            end
        end,

        OnRender = function(self)
            -- 渲染所有子机
            for _, option in ipairs(self.options) do
                local onRender = option.OnRender
                if onRender then
                    onRender(option)
                end
            end
        end,

        OnDestroy = function(self)
            -- 销毁所有子机
            for _, option in ipairs(self.options) do
                local onDestroy = option.OnDestroy
                if onDestroy then
                    onDestroy(option)
                end
            end
        end,

        ---添加子机
        ---@param optionConfig table
        ---@return thlib.Player.Option
        addOption = function(self, optionConfig)
            local index = #self.options + 1
            local option = Option.new(self.owner, index, optionConfig)
            if self.powerComp then
                option:setPowerComponent(self.powerComp)
            end
            table.insert(self.options, option)

            -- 如果组件已经启动，立即调用子机的 Start 生命周期
            if self.powerComp and not option._lifecycleStarted then
                option._lifecycleStarted = true
                local start = option.Start
                if start then
                    start(option)
                end
            end

            return option
        end,

        ---移除子机
        ---@param index number
        removeOption = function(self, index)
            local option = self.options[index]
            if option then
                -- 调用子机的 OnDestroy 生命周期
                local onDestroy = option.OnDestroy
                if onDestroy then
                    onDestroy(option)
                end
                table.remove(self.options, index)
            end
        end,

        ---获取子机
        ---@param index number
        ---@return thlib.Player.Option|nil
        getOption = function(self, index)
            return self.options[index]
        end,

        ---获取所有激活的子机
        ---@return thlib.Player.Option[]
        getActiveOptions = function(self)
            local active = {}
            for _, option in ipairs(self.options) do
                if option.active and option.visible then
                    table.insert(active, option)
                end
            end
            return active
        end,
    },
})

---创建子机组件
---@param config table
---@return thlib.Player.OptionComponent
local function create(config)
    config = config or {}
    return TypeDef.instantiate(OptionComponentType, {
        _config = config,
    })
end

return {
    create = create,
    Type = OptionComponentType,
}
