local math = math
---擦弹判定对象
---与新的 Player 系统配合使用

---@class THlib.Player.Grazer : lstg.GameObject
local grazer = lstg.CreateGameObjectClass()

function grazer:init(player)
    self.group = GROUP_PLAYER
    self.layer = LAYER_PLAYER
    self.img = "graze"
    self.bound = false
    self.player = player
    self.world = lstg.world
    self.a = 24
    self.b = 24
    self.rect = false
    self.log_state = player.slow
    self._slowTimer = 0
    self._pause = 0
    self.aura = 0        -- 光环旋转角度
    self.aura_d = 0      -- 光环附加旋转
end

function grazer:frame()
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
end

function grazer:render()
    local p = self.player

    -- 渲染粒子效果
    if p.slow == 1 and not self.hide and self._pause == 0 then
        ParticleSetEmission(self, 3 * self.a)
        ParticleFire(self)
    end

    -- 从 GrazeComponent 获取低速光环强度
    local grazeComp = p:getComponent("graze")
    local lh = grazeComp and grazeComp.lh or 0

    -- 渲染低速光环
    SetImageState("player_aura", "", Color(0xC0FFFFFF))
    Render("player_aura", self.x, self.y, -self.aura + self.aura_d, lh)
    SetImageState("player_aura", "", Color(0xC0FFFFFF) * lh + Color(0x00FFFFFF) * (1 - lh))
    Render("player_aura", self.x, self.y, self.aura, 2 - lh)
end

function grazer:colli(other)
    if other.group == GROUP_ENEMY_BULLET then
        local grazesys = self.player:getComponent("graze")
        if grazesys then
            grazesys:onGraze(other)
        end
    end
end

lstg.RegisterGameObjectClass(grazer)

return grazer

