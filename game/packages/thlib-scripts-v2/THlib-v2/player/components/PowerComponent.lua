local math = math

---火力组件
---管理玩家的火力相关属性，包括子机数量等

---@class THlib.Player.PowerComponent : foundation.Component
---@field support number 子机数量（浮点数，平滑过渡）
---@field supportx number 子机跟随X坐标
---@field supporty number 子机跟随Y坐标
---@field supportLerpSpeed number 子机数量变化速度
---@field supportPosLerpSpeed number 子机位置跟随速度
---@field getSupport fun(self: THlib.Player.PowerComponent): number 获取当前子机数量
---@field getSupportPosition fun(self: THlib.Player.PowerComponent): number, number 获取子机跟随位置

---创建火力组件
---@param owner THlib.Player
---@param config table
---@return THlib.Player.PowerComponent
local function create(owner, config)
    config = config or {}

    -- 初始化 support 值
    local initialSupport = 0
    if lstg and lstg.var and lstg.var.power then
        initialSupport = math.floor(lstg.var.power / 100)
    end

    ---@type THlib.Player.PowerComponent
    local component = {
        enabled = true,
        executePriority = 85, -- 在大多数组件之后，但在子机组件之前
        typeName = "power",
        owner = owner,
        support = initialSupport,
        supportx = owner.x,
        supporty = owner.y,
        supportLerpSpeed = config.supportLerpSpeed or 0.0625, -- 每帧变化速度
        supportPosLerpSpeed = config.supportPosLerpSpeed or 0.6875, -- 位置跟随速度
    }

    function component:update()
        local player = self.owner

        -- 更新 support 值，平滑过渡到目标值
        if lstg and lstg.var and lstg.var.power then
            local targetSupport = math.floor(lstg.var.power / 100)

            if self.support > targetSupport then
                self.support = self.support - self.supportLerpSpeed
            elseif self.support < targetSupport then
                self.support = self.support + self.supportLerpSpeed
            end

            -- 如果差值小于变化速度，直接设置为目标值
            if math.abs(self.support - targetSupport) < self.supportLerpSpeed then
                self.support = targetSupport
            end
        end

        -- 更新 support 位置，平滑跟随玩家
        self.supportx = player.x + (self.supportx - player.x) * self.supportPosLerpSpeed
        self.supporty = player.y + (self.supporty - player.y) * self.supportPosLerpSpeed
    end

    --- 获取当前子机数量
    ---@return number
    function component:getSupport()
        return self.support
    end

    --- 获取子机跟随位置
    ---@return number, number
    function component:getSupportPosition()
        return self.supportx, self.supporty
    end

    return component
end

return {
    create = create,
}

