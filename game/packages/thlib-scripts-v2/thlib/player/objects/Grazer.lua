local math = math

local lstg = lstg

local GameObject = require("core.GameObject")
local TypeDef = require("core.TypeDef")

---擦弹判定对象
---与新的 Player 系统配合使用

---@class thlib.Player.Grazer : core.GameObject
---@field player thlib.Player 玩家对象
---@field log_state number 记录的低速状态
---@field _slowTimer number 低速计时器
---@field _pause number 暂停计时器
---@field aura number 光环旋转角度
---@field aura_d number 光环附加旋转
---@field grazed boolean 是否发生擦弹

-- 定义 Grazer 类型（继承自 GameObject）
local GrazerType = TypeDef.create("thlib.Player.Grazer", GameObject.Type, {
    defaults = {
        group = GROUP_PLAYER,
        layer = LAYER_PLAYER,
        img = "graze",
        bound = false,
        colli = true,
        a = 24,
        b = 24,
        rect = false,
        log_state = 0,
        _slowTimer = 0,
        _pause = 0,
        aura = 0,
        aura_d = 0,
        grazed = false,
    },
    methods = {
        Awake = function(self)
            -- Awake 时 player 已经通过 config 传入
            local player = self.player
            if player then
                self.world = lstg.world
                self.log_state = player.slow
            end
            -- 初始化时停止粒子
            ParticleStop(self)
        end,

        Update = function(self)
            local p = self.player

            -- 通过状态机组件判断玩家是否存活
            local stateComp = p:getComponent("state")
            local alive = stateComp and (stateComp.currentState == "normal" or stateComp.currentState == "protected")

            if alive then
                self.x = p.x
                self.y = p.y
                self.hide = p.hide
            end

            if not p.time_stop then
                if alive then
                    if self.log_state ~= p.slow then
                        self.log_state = p.slow
                        self._pause = 30
                    end
                end

                -- 更新低速计时器
                if p.slow == 1 then
                    self._slowTimer = math.min(self._slowTimer + 1, 30)
                else
                    self._slowTimer = 0
                end

                -- 更新光环旋转
                if self._pause == 0 then
                    self.aura = self.aura + 1.5
                end
                self._pause = math.max(0, self._pause - 1)
                self.aura_d = 180 * math.cos(math.rad(90 * self._slowTimer / 30)) ^ 2
            end

            if p.world then
                self.world = p.world
            end

            -- 处理粒子效果（只在擦弹时发射）
            if self.grazed then
                PlaySound("graze", 0.3, self.x / 200)
                self.grazed = false
                lstg.ParticleFire(self)
            else
                lstg.ParticleStop(self)
            end
        end,

        OnRender = function(self)
            local p = self.player

            -- 从 GrazeComponent 获取低速光环强度
            local grazeComp = p:getComponent("graze")
            local lh = grazeComp and grazeComp.lh or 0

            lstg.DefaultRenderFunc(self)

            -- 渲染低速光环
            lstg.SetImageState("player_aura", "", lstg.Color(0xC0FFFFFF))
            lstg.Render("player_aura", self.x, self.y, -self.aura + self.aura_d, lh)
            lstg.SetImageState("player_aura", "", lstg.Color(0xC0FFFFFF) * lh + lstg.Color(0x00FFFFFF) * (1 - lh))
            lstg.Render("player_aura", self.x, self.y, self.aura, 2 - lh)
        end,

        OnCollision = function(self, other)
            if other.group == GROUP_ENEMY_BULLET or other.group == GROUP_INDES then
                -- 初始化擦弹记录表（如果不存在）
                if not other._grazed_by then
                    other._grazed_by = {}
                end

                -- 检查是否支持无限擦弹
                local inf_graze = other._inf_graze or false
                -- 获取擦弹间隔，默认1
                local graze_interval = other._graze_interval or 1

                -- 检查该玩家是否已经擦弹过这个子弹
                local player_slot = self.player.slot
                local last_graze_time = other._grazed_by[player_slot]
                local current_time = other.timer or 0

                -- 判断是否可以擦弹
                local can_graze = false
                if inf_graze then
                    -- 无限擦弹：检查是否已经过了间隔时间
                    if not last_graze_time then
                        -- 从未擦弹过
                        can_graze = true
                    else
                        -- 检查间隔是否已过
                        local time_since_last_graze = current_time - last_graze_time
                        can_graze = time_since_last_graze >= graze_interval
                    end
                else
                    -- 普通擦弹：只能擦弹一次
                    can_graze = not last_graze_time
                end

                -- 如果可以擦弹，则触发擦弹
                if can_graze then
                    local grazesys = self.player:getComponent("graze")
                    if grazesys then
                        grazesys:onGraze(other)
                        -- 设置擦弹标志，下一帧发射粒子
                        self.grazed = true

                        -- 记录擦弹时间
                        other._grazed_by[player_slot] = current_time
                    end
                end
            end
        end,
    },
})

---创建擦弹判定对象
---@param player thlib.Player 玩家对象
---@return thlib.Player.Grazer
local function create(player)
    return GameObject.create(GrazerType, {
        player = player,
    })
end

return {
    create = create,
    Type = GrazerType,
}

