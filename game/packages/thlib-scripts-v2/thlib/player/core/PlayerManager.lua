local string = string
local table = table
local ipairs = ipairs
local pairs = pairs
local setmetatable = setmetatable

---玩家管理器
---用于管理多个玩家实例的创建、更新和销毁
local Player = require("thlib.player.core.Player")
local PlayerPresets = require("thlib.player.config.PlayerPresets")
local ObjectHelper = require("helpers.ObjectHelper")

---@class thlib.PlayerManager
---@field players table<number, thlib.Player> 玩家实例映射表 (slot -> player)
---@field playerList thlib.Player[] 玩家实例列表
---@field activeSlots table<number, boolean> 活跃的槽位
---@field maxPlayers number 最大玩家数量
local PlayerManager = {}
PlayerManager.__index = PlayerManager

---创建玩家管理器实例
---@param maxPlayers number|nil 最大玩家数量，默认为4
---@return thlib.PlayerManager
function PlayerManager.new(maxPlayers)
    local self = setmetatable({}, PlayerManager)

    self.players = {}
    self.playerList = {}
    self.activeSlots = {}
    self.maxPlayers = maxPlayers or 4

    return self
end

---创建并添加一个玩家
---@param slot number 玩家槽位 (1-based)
---@param playerConfig table|nil 玩家配置
---@param componentConfigs table|nil 组件配置
---@return thlib.Player|nil player 创建的玩家实例，失败返回nil
---@return string|nil error 错误信息
function PlayerManager:createPlayer(slot, playerConfig, componentConfigs)
    -- 验证槽位
    if slot < 1 or slot > self.maxPlayers then
        return nil, string.format("槽位 %d 超出范围 (1-%d)", slot, self.maxPlayers)
    end

    -- 检查槽位是否已被占用
    if self.players[slot] then
        return nil, string.format("槽位 %d 已被占用", slot)
    end

    -- 合并默认配置
    playerConfig = playerConfig or {}
    componentConfigs = componentConfigs or PlayerPresets.default()

    -- 创建玩家对象
    local player = New(Player)
    if not player then
        return nil, "创建玩家对象失败"
    end

    -- 初始化玩家
    player:init(slot, playerConfig)

    -- 设置组件
    player:setupComponents(componentConfigs)

    -- 添加到管理器
    self.players[slot] = player
    table.insert(self.playerList, player)
    self.activeSlots[slot] = true

    return player
end

---移除指定槽位的玩家
---@param slot number 玩家槽位
---@return boolean success 是否成功移除
function PlayerManager:removePlayer(slot)
    local player = self.players[slot]
    if not player then
        return false
    end

    -- 从列表中移除
    for i, p in ipairs(self.playerList) do
        if p == player then
            table.remove(self.playerList, i)
            break
        end
    end

    -- 删除游戏对象
    if IsValid(player) then
        Del(player)
    end

    -- 清理引用
    self.players[slot] = nil
    self.activeSlots[slot] = nil

    return true
end

---获取指定槽位的玩家
---@param slot number 玩家槽位
---@return thlib.Player|nil
function PlayerManager:getPlayer(slot)
    return self.players[slot]
end

---获取所有玩家列表
---@return thlib.Player[]
function PlayerManager:getAllPlayers()
    return self.playerList
end

---获取活跃玩家数量
---@return number
function PlayerManager:getPlayerCount()
    return #self.playerList
end

---检查槽位是否可用
---@param slot number 玩家槽位
---@return boolean
function PlayerManager:isSlotAvailable(slot)
    return slot >= 1 and slot <= self.maxPlayers and not self.players[slot]
end

---获取第一个可用的槽位
---@return number|nil slot 可用槽位，如果没有则返回nil
function PlayerManager:getFirstAvailableSlot()
    for i = 1, self.maxPlayers do
        if not self.players[i] then
            return i
        end
    end
    return nil
end

---清空所有玩家
function PlayerManager:clear()
    -- 删除所有玩家对象
    for _, player in pairs(self.players) do
        if IsValid(player) then
            Del(player)
        end
    end

    -- 清空表
    self.players = {}
    self.playerList = {}
    self.activeSlots = {}
end

---遍历所有玩家
---@param callback fun(player: thlib.Player, slot: number)
function PlayerManager:forEach(callback)
    for slot, player in pairs(self.players) do
        if IsValid(player) then
            callback(player, slot)
        end
    end
end

---查找符合条件的玩家
---@param predicate fun(player: thlib.Player, slot: number): boolean
---@return thlib.Player|nil
function PlayerManager:find(predicate)
    for slot, player in pairs(self.players) do
        if IsValid(player) and predicate(player, slot) then
            return player
        end
    end
    return nil
end

---过滤符合条件的玩家
---@param predicate fun(player: thlib.Player, slot: number): boolean
---@return thlib.Player[]
function PlayerManager:filter(predicate)
    local result = {}
    for slot, player in pairs(self.players) do
        if IsValid(player) and predicate(player, slot) then
            table.insert(result, player)
        end
    end
    return result
end

---获取主玩家（槽位1的玩家，如果不存在则返回第一个玩家）
---@return thlib.Player|nil
function PlayerManager:getMainPlayer()
    -- 优先返回槽位1的玩家
    if self.players[1] then
        return self.players[1]
    end

    -- 否则返回第一个玩家
    return self.playerList[1]
end

---设置全局玩家引用（兼容旧代码）
---@param slot number|nil 玩家槽位，如果为nil则使用主玩家
function PlayerManager:setGlobalPlayer(slot)
    local player
    if slot then
        player = self.players[slot]
    else
        player = self:getMainPlayer()
    end

    if player then
        lstg.player = player
        _G.player = player
    end
end

---批量创建玩家
---@param configs table[] 配置数组，每个元素包含 {slot, playerConfig, componentConfigs}
---@return table<number, thlib.Player> 成功创建的玩家映射表
---@return table<number, string> 失败的槽位及错误信息
function PlayerManager:createPlayers(configs)
    local succeeded = {}
    local failed = {}

    for _, config in ipairs(configs) do
        local slot = config.slot or config[1]
        local playerConfig = config.playerConfig or config[2]
        local componentConfigs = config.componentConfigs or config[3]

        local player, err = self:createPlayer(slot, playerConfig, componentConfigs)
        if player then
            succeeded[slot] = player
        else
            failed[slot] = err
        end
    end

    return succeeded, failed
end

---检查并清理无效的玩家对象
---@return number 清理的数量
function PlayerManager:cleanup()
    local cleaned = 0
    local toRemove = {}

    -- 收集需要移除的槽位
    for slot, player in pairs(self.players) do
        if not IsValid(player) then
            table.insert(toRemove, slot)
        end
    end

    -- 移除无效玩家
    for _, slot in ipairs(toRemove) do
        self:removePlayer(slot)
        cleaned = cleaned + 1
    end

    return cleaned
end

---获取管理器状态信息
---@return table
function PlayerManager:getStatus()
    return {
        playerCount = self:getPlayerCount(),
        maxPlayers = self.maxPlayers,
        activeSlots = self.activeSlots,
        availableSlots = self.maxPlayers - self:getPlayerCount(),
    }
end

---随机获取一个玩家
---@return thlib.Player|nil
function PlayerManager:getRandomPlayer()
    return ObjectManager.getRandomObject(self.playerList)
end

---获取距离指定位置最近的玩家
---@param x number 目标X坐标
---@param y number 目标Y坐标
---@return thlib.Player|nil player 最近的玩家
---@return number|nil distance 距离
function PlayerManager:getNearestPlayer(x, y)
    local validPlayers = self:filter(function(p)
        return IsValid(p)
    end)
    return ObjectManager.getNearestObject(validPlayers, x, y)
end

---获取距离指定位置最近的N个玩家
---@param x number 目标X坐标
---@param y number 目标Y坐标
---@param count number 要获取的玩家数量
---@return table<number, {player: thlib.Player, distance: number}> 玩家及距离列表，按距离排序
function PlayerManager:getNearestPlayers(x, y, count)
    local validPlayers = self:filter(function(p)
        return IsValid(p)
    end)
    local results = ObjectManager.getNearestObjects(validPlayers, x, y, count)

    -- 重命名 object 为 player 以保持接口一致
    for _, item in ipairs(results) do
        item.player = item.object
        item.object = nil
    end

    return results
end

---获取指定范围内的所有玩家
---@param x number 中心X坐标
---@param y number 中心Y坐标
---@param radius number 范围半径
---@return thlib.Player[] 范围内的玩家列表
function PlayerManager:getPlayersInRange(x, y, radius)
    local validPlayers = self:filter(function(p)
        return IsValid(p)
    end)
    return ObjectManager.getObjectsInRange(validPlayers, x, y, radius)
end

---获取距离指定位置最远的玩家
---@param x number 目标X坐标
---@param y number 目标Y坐标
---@return thlib.Player|nil player 最远的玩家
---@return number|nil distance 距离
function PlayerManager:getFarthestPlayer(x, y)
    local validPlayers = self:filter(function(p)
        return IsValid(p)
    end)
    return ObjectManager.getFarthestObject(validPlayers, x, y)
end

---获取所有玩家的中心位置（质心）
---@return number|nil x 中心X坐标
---@return number|nil y 中心Y坐标
function PlayerManager:getPlayersCenter()
    local validPlayers = self:filter(function(p)
        return IsValid(p)
    end)
    return ObjectManager.getObjectsCenter(validPlayers)
end

---按指定条件排序玩家
---@param comparator fun(a: thlib.Player, b: thlib.Player): boolean 比较函数
---@return thlib.Player[] 排序后的玩家列表（新列表）
function PlayerManager:getSortedPlayers(comparator)
    return ObjectManager.sortObjects(self.playerList, comparator)
end

---获取按X坐标排序的玩家（从左到右）
---@return thlib.Player[]
function PlayerManager:getPlayersByX()
    return ObjectManager.sortByX(self.playerList)
end

---获取按Y坐标排序的玩家（从下到上）
---@return thlib.Player[]
function PlayerManager:getPlayersByY()
    return ObjectManager.sortByY(self.playerList)
end

---获取按槽位排序的玩家
---@return thlib.Player[]
function PlayerManager:getPlayersBySlot()
    return self:getSortedPlayers(function(a, b)
        return a.slot < b.slot
    end)
end

---随机获取N个不重复的玩家
---@param count number 要获取的玩家数量
---@return thlib.Player[] 随机玩家列表
function PlayerManager:getRandomPlayers(count)
    return ObjectManager.getRandomObjects(self.playerList, count)
end

---获取满足条件的玩家数量
---@param predicate fun(player: thlib.Player, slot: number): boolean
---@return number
function PlayerManager:countPlayers(predicate)
    local count = 0
    for slot, player in pairs(self.players) do
        if IsValid(player) and predicate(player, slot) then
            count = count + 1
        end
    end
    return count
end

---检查是否存在满足条件的玩家
---@param predicate fun(player: thlib.Player, slot: number): boolean
---@return boolean
function PlayerManager:hasPlayer(predicate)
    for slot, player in pairs(self.players) do
        if IsValid(player) and predicate(player, slot) then
            return true
        end
    end
    return false
end

---对所有玩家执行映射操作
---@param mapper fun(player: thlib.Player, slot: number): any
---@return table 映射结果数组
function PlayerManager:map(mapper)
    local result = {}
    for slot, player in pairs(self.players) do
        if IsValid(player) then
            table.insert(result, mapper(player, slot))
        end
    end
    return result
end

---获取所有玩家的平均位置
---@return number|nil avgX 平均X坐标
---@return number|nil avgY 平均Y坐标
function PlayerManager:getAveragePosition()
    return self:getPlayersCenter()
end

---获取指定角度扇形范围内的玩家
---@param x number 扇形顶点X坐标
---@param y number 扇形顶点Y坐标
---@param angle number 扇形中心角度（度）
---@param angleRange number 扇形角度范围（度）
---@param maxDistance number|nil 最大距离限制，nil表示无限制
---@return thlib.Player[] 范围内的玩家列表
function PlayerManager:getPlayersInSector(x, y, angle, angleRange, maxDistance)
    local validPlayers = self:filter(function(p)
        return IsValid(p)
    end)
    return ObjectManager.getObjectsInSector(validPlayers, x, y, angle, angleRange, maxDistance)
end

---获取指定矩形区域内的玩家
---@param left number 左边界
---@param right number 右边界
---@param bottom number 下边界
---@param top number 上边界
---@return thlib.Player[] 区域内的玩家列表
function PlayerManager:getPlayersInRect(left, right, bottom, top)
    local validPlayers = self:filter(function(p)
        return IsValid(p)
    end)
    return ObjectManager.getObjectsInRect(validPlayers, left, right, bottom, top)
end

---分配目标给所有玩家（每个玩家分配最近的目标）
---@param targets lstg.GameObject[] 目标对象列表
---@return table<thlib.Player, lstg.GameObject> 玩家到目标的映射
function PlayerManager:assignTargets(targets)
    local validPlayers = self:filter(function(p)
        return IsValid(p)
    end)
    return ObjectManager.assignTargets(validPlayers, targets)
end

---获取所有玩家的边界框
---@return number|nil left
---@return number|nil right
---@return number|nil bottom
---@return number|nil top
function PlayerManager:getPlayersBounds()
    local validPlayers = self:filter(function(p)
        return IsValid(p)
    end)
    return ObjectManager.getObjectsBounds(validPlayers)
end

---获取两个玩家之间的距离
---@param slot1 number 玩家1的槽位
---@param slot2 number 玩家2的槽位
---@return number|nil distance 距离，如果任一玩家不存在则返回nil
function PlayerManager:getDistanceBetween(slot1, slot2)
    local p1 = self.players[slot1]
    local p2 = self.players[slot2]
    return ObjectManager.getDistance(p1, p2)
end

---检查所有玩家是否都满足条件
---@param predicate fun(player: thlib.Player, slot: number): boolean
---@return boolean
function PlayerManager:allPlayers(predicate)
    for slot, player in pairs(self.players) do
        if IsValid(player) then
            if not predicate(player, slot) then
                return false
            end
        end
    end
    return true
end

---检查是否有任意玩家满足条件
---@param predicate fun(player: thlib.Player, slot: number): boolean
---@return boolean
function PlayerManager:anyPlayer(predicate)
    return self:hasPlayer(predicate)
end

---对所有玩家执行操作（带错误处理）
---@param action fun(player: thlib.Player, slot: number)
---@return number successCount 成功执行的数量
---@return table errors 错误信息表
function PlayerManager:forEachSafe(action)
    local successCount = 0
    local errors = {}

    for slot, player in pairs(self.players) do
        if IsValid(player) then
            local success, err = pcall(action, player, slot)
            if success then
                successCount = successCount + 1
            else
                errors[slot] = err
            end
        end
    end

    return successCount, errors
end

---获取指定状态的所有玩家
---@param stateName string 状态名称（如 "normal", "dying", "respawning"）
---@return thlib.Player[] 处于该状态的玩家列表
function PlayerManager:getPlayersByState(stateName)
    return self:filter(function(player)
        local stateComp = player:getComponent("state")
        return stateComp and stateComp.currentState == stateName
    end)
end

---获取存活的玩家（非dying/respawning状态）
---@return thlib.Player[] 存活的玩家列表
function PlayerManager:getAlivePlayers()
    return self:filter(function(player)
        local stateComp = player:getComponent("state")
        if not stateComp then
            return true
        end
        local state = stateComp.currentState
        return state ~= "dying" and state ~= "respawning"
    end)
end

---获取死亡中的玩家
---@return thlib.Player[] 死亡中的玩家列表
function PlayerManager:getDeadPlayers()
    return self:filter(function(player)
        local stateComp = player:getComponent("state")
        if not stateComp then
            return false
        end
        local state = stateComp.currentState
        return state == "dying" or state == "respawning"
    end)
end

---检查是否所有玩家都已死亡
---@return boolean
function PlayerManager:allPlayersDead()
    if #self.playerList == 0 then
        return true
    end

    return #self:getAlivePlayers() == 0
end

---检查是否至少有一个玩家存活
---@return boolean
function PlayerManager:hasAlivePlayer()
    return #self:getAlivePlayers() > 0
end

---广播事件到所有玩家
---@param eventName string 事件名称
---@vararg any 事件参数
function PlayerManager:broadcastEvent(eventName, ...)
    for _, player in ipairs(self.playerList) do
        if IsValid(player) then
            player:_dispatchEvent(eventName, ...)
        end
    end
end

---为所有玩家添加Buff
---@param buffId string Buff ID
---@param duration number Buff持续时间
---@param data table|nil Buff数据
function PlayerManager:addBuffToAll(buffId, duration, data)
    self:forEach(function(player)
        local buffComp = player:getComponent("buff")
        if buffComp then
            buffComp:addBuff(buffId, duration, data)
        end
    end)
end

---为所有玩家移除Buff
---@param buffId string Buff ID
function PlayerManager:removeBuffFromAll(buffId)
    self:forEach(function(player)
        local buffComp = player:getComponent("buff")
        if buffComp then
            buffComp:removeBuff(buffId)
        end
    end)
end

---设置所有玩家的倍率
---@param multiplierName string 倍率名称（如 "damage", "speed"）
---@param value number 倍率值
function PlayerManager:setMultiplierForAll(multiplierName, value)
    self:forEach(function(player)
        local multComp = player:getComponent("multiplier")
        if multComp then
            multComp:set(multiplierName, value)
        end
    end)
end

---锁定/解锁所有玩家
---@param locked boolean 是否锁定
function PlayerManager:setAllPlayersLocked(locked)
    self:forEach(function(player)
        player.locked = locked
    end)
end

---隐藏/显示所有玩家
---@param hidden boolean 是否隐藏
function PlayerManager:setAllPlayersHidden(hidden)
    self:forEach(function(player)
        player.hide = hidden
    end)
end

---获取玩家间的最大距离
---@return number|nil maxDistance 最大距离，如果玩家少于2个则返回nil
function PlayerManager:getMaxDistanceBetweenPlayers()
    local validPlayers = self:filter(function(p)
        return IsValid(p)
    end)
    return ObjectManager.getMaxDistanceBetween(validPlayers)
end

---获取玩家间的最小距离
---@return number|nil minDistance 最小距离，如果玩家少于2个则返回nil
function PlayerManager:getMinDistanceBetweenPlayers()
    local validPlayers = self:filter(function(p)
        return IsValid(p)
    end)
    return ObjectManager.getMinDistanceBetween(validPlayers)
end

---轮询获取下一个玩家（用于轮流分配目标等）
---@param currentSlot number|nil 当前槽位，nil表示从第一个开始
---@return thlib.Player|nil nextPlayer 下一个玩家
---@return number|nil nextSlot 下一个槽位
function PlayerManager:getNextPlayer(currentSlot)
    if #self.playerList == 0 then
        return nil, nil
    end

    -- 获取排序后的槽位列表
    local slots = {}
    for slot in pairs(self.players) do
        table.insert(slots, slot)
    end
    table.sort(slots)

    -- 如果没有当前槽位，返回第一个
    if not currentSlot then
        local firstSlot = slots[1]
        return self.players[firstSlot], firstSlot
    end

    -- 找到当前槽位的下一个
    for i, slot in ipairs(slots) do
        if slot == currentSlot then
            local nextIndex = (i % #slots) + 1
            local nextSlot = slots[nextIndex]
            return self.players[nextSlot], nextSlot
        end
    end

    -- 如果当前槽位不存在，返回第一个
    local firstSlot = slots[1]
    return self.players[firstSlot], firstSlot
end

---按权重随机选择一个玩家
---@param weightFunc fun(player: thlib.Player, slot: number): number 权重函数，返回值越大被选中概率越高
---@return thlib.Player|nil
function PlayerManager:getWeightedRandomPlayer(weightFunc)
    local validPlayers = self:filter(function(p)
        return IsValid(p)
    end)
    return ObjectManager.getWeightedRandomObject(validPlayers, function(player)
        return weightFunc(player, player.slot)
    end)
end

return PlayerManager

