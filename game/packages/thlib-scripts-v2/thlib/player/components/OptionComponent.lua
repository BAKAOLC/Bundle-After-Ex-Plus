local ipairs = ipairs
local table = table

---子机组件
local Option = require("thlib.player.components.Option")

---@class thlib.Player.OptionComponent : core.Component
---@field options thlib.Player.Option[] 子机对象数组
---@field powerComp thlib.Player.PowerComponent|nil 火力组件引用

---创建子机组件
---@param owner thlib.Player
---@param config table
---@return thlib.Player.OptionComponent
local function create(owner, config)
    config = config or {}

    ---@type thlib.Player.OptionComponent
    local component = {
        enabled = true,
        executePriority = 3,
        renderPriority = 3,
        typeName = "option",
        owner = owner,
        options = {},
        powerComp = nil,
    }

    -- 从配置创建子机对象
    if config.options then
        for i, optionConfig in ipairs(config.options) do
            component.options[i] = Option.new(owner, i, optionConfig)
        end
    end

    function component:resolveDependencies(gameObject)
        -- 获取火力组件
        self.powerComp = gameObject:getComponent("power")

        -- 将火力组件引用传递给所有子机，并初始化状态
        for _, option in ipairs(self.options) do
            option:setPowerComponent(self.powerComp)

            -- 初始化子机的激活状态
            if self.powerComp then
                local support = self.powerComp:getSupport()
                option.active = (support >= option.requiredPower)
                option.alpha = option.active and 1.0 or 0
                option.visible = option.active
            end
        end
    end

    function component:update()
        -- 更新所有子机
        for _, option in ipairs(self.options) do
            option:update()
        end
    end

    function component:render()
        -- 渲染所有子机
        for _, option in ipairs(self.options) do
            option:render()
        end
    end

    ---添加子机
    ---@param optionConfig table
    ---@return thlib.Player.Option
    function component:addOption(optionConfig)
        local index = #self.options + 1
        local option = Option.new(self.owner, index, optionConfig)
        if self.powerComp then
            option:setPowerComponent(self.powerComp)
        end
        table.insert(self.options, option)
        return option
    end

    ---移除子机
    ---@param index number
    function component:removeOption(index)
        table.remove(self.options, index)
    end

    ---获取子机
    ---@param index number
    ---@return thlib.Player.Option|nil
    function component:getOption(index)
        return self.options[index]
    end

    ---获取所有激活的子机
    ---@return thlib.Player.Option[]
    function component:getActiveOptions()
        local active = {}
        for _, option in ipairs(self.options) do
            if option.active and option.visible then
                table.insert(active, option)
            end
        end
        return active
    end

    return component
end

return {
    create = create,
}
