local math = math
local table = table
local ipairs = ipairs
local pairs = pairs

---通用对象管理工具类
---提供对象集合的查询、排序、过滤等功能
local ObjectManager = {}

---获取距离指定位置最近的对象
---@param objects table 对象列表
---@param x number 目标X坐标
---@param y number 目标Y坐标
---@return any|nil object 最近的对象
---@return number|nil distance 距离
function ObjectManager.getNearestObject(objects, x, y)
    local nearest
    local minDistance = math.huge

    for _, obj in ipairs(objects) do
        if obj and obj.x and obj.y then
            local dx = obj.x - x
            local dy = obj.y - y
            local distance = math.sqrt(dx * dx + dy * dy)

            if distance < minDistance then
                minDistance = distance
                nearest = obj
            end
        end
    end

    return nearest, (nearest and minDistance or nil)
end

---获取距离指定位置最近的N个对象
---@param objects table 对象列表
---@param x number 目标X坐标
---@param y number 目标Y坐标
---@param count number 要获取的对象数量
---@return table<number, {object: any, distance: number}> 对象及距离列表，按距离排序
function ObjectManager.getNearestObjects(objects, x, y, count)
    local candidates = {}

    for _, obj in ipairs(objects) do
        if obj and obj.x and obj.y then
            local dx = obj.x - x
            local dy = obj.y - y
            local distance = math.sqrt(dx * dx + dy * dy)

            table.insert(candidates, {
                object = obj,
                distance = distance
            })
        end
    end

    table.sort(candidates, function(a, b)
        return a.distance < b.distance
    end)

    local result = {}
    for i = 1, math.min(count, #candidates) do
        table.insert(result, candidates[i])
    end

    return result
end

---获取指定范围内的所有对象
---@param objects table 对象列表
---@param x number 中心X坐标
---@param y number 中心Y坐标
---@param radius number 范围半径
---@return table 范围内的对象列表
function ObjectManager.getObjectsInRange(objects, x, y, radius)
    local result = {}
    local radiusSq = radius * radius

    for _, obj in ipairs(objects) do
        if obj and obj.x and obj.y then
            local dx = obj.x - x
            local dy = obj.y - y
            local distanceSq = dx * dx + dy * dy

            if distanceSq <= radiusSq then
                table.insert(result, obj)
            end
        end
    end

    return result
end

---获取距离指定位置最远的对象
---@param objects table 对象列表
---@param x number 目标X坐标
---@param y number 目标Y坐标
---@return any|nil object 最远的对象
---@return number|nil distance 距离
function ObjectManager.getFarthestObject(objects, x, y)
    local farthest
    local maxDistance = -1

    for _, obj in ipairs(objects) do
        if obj and obj.x and obj.y then
            local dx = obj.x - x
            local dy = obj.y - y
            local distance = math.sqrt(dx * dx + dy * dy)

            if distance > maxDistance then
                maxDistance = distance
                farthest = obj
            end
        end
    end

    return farthest, (farthest and maxDistance or nil)
end

---获取所有对象的中心位置（质心）
---@param objects table 对象列表
---@return number|nil x 中心X坐标
---@return number|nil y 中心Y坐标
function ObjectManager.getObjectsCenter(objects)
    if #objects == 0 then
        return nil, nil
    end

    local sumX, sumY = 0, 0
    local count = 0

    for _, obj in ipairs(objects) do
        if obj and obj.x and obj.y then
            sumX = sumX + obj.x
            sumY = sumY + obj.y
            count = count + 1
        end
    end

    if count == 0 then
        return nil, nil
    end

    return sumX / count, sumY / count
end

---获取指定矩形区域内的对象
---@param objects table 对象列表
---@param left number 左边界
---@param right number 右边界
---@param bottom number 下边界
---@param top number 上边界
---@return table 区域内的对象列表
function ObjectManager.getObjectsInRect(objects, left, right, bottom, top)
    local result = {}

    for _, obj in ipairs(objects) do
        if obj and obj.x and obj.y then
            if obj.x >= left and obj.x <= right and
                    obj.y >= bottom and obj.y <= top then
                table.insert(result, obj)
            end
        end
    end

    return result
end

---获取指定角度扇形范围内的对象
---@param objects table 对象列表
---@param x number 扇形顶点X坐标
---@param y number 扇形顶点Y坐标
---@param angle number 扇形中心角度（度）
---@param angleRange number 扇形角度范围（度）
---@param maxDistance number|nil 最大距离限制，nil表示无限制
---@return table 范围内的对象列表
function ObjectManager.getObjectsInSector(objects, x, y, angle, angleRange, maxDistance)
    local result = {}
    local halfRange = angleRange / 2

    for _, obj in ipairs(objects) do
        if obj and obj.x and obj.y then
            local dx = obj.x - x
            local dy = obj.y - y
            local inRange = true

            if maxDistance then
                local distanceSq = dx * dx + dy * dy
                if distanceSq > maxDistance * maxDistance then
                    inRange = false
                end
            end

            if inRange then
                local objAngle = math.atan2(dy, dx) * 180 / math.pi
                local angleDiff = math.abs((objAngle - angle + 180) % 360 - 180)

                if angleDiff <= halfRange then
                    table.insert(result, obj)
                end
            end
        end
    end

    return result
end

---获取所有对象的边界框
---@param objects table 对象列表
---@return number|nil left
---@return number|nil right
---@return number|nil bottom
---@return number|nil top
function ObjectManager.getObjectsBounds(objects)
    if #objects == 0 then
        return nil, nil, nil, nil
    end

    local left = math.huge
    local right = -math.huge
    local bottom = math.huge
    local top = -math.huge

    for _, obj in ipairs(objects) do
        if obj and obj.x and obj.y then
            left = math.min(left, obj.x)
            right = math.max(right, obj.x)
            bottom = math.min(bottom, obj.y)
            top = math.max(top, obj.y)
        end
    end

    return left, right, bottom, top
end

---按指定条件排序对象
---@param objects table 对象列表
---@param comparator fun(a: any, b: any): boolean 比较函数
---@return table 排序后的对象列表（新列表）
function ObjectManager.sortObjects(objects, comparator)
    local sorted = {}
    for _, obj in ipairs(objects) do
        table.insert(sorted, obj)
    end
    table.sort(sorted, comparator)
    return sorted
end

---按X坐标排序对象（从左到右）
---@param objects table 对象列表
---@return table 排序后的对象列表
function ObjectManager.sortByX(objects)
    return ObjectManager.sortObjects(objects, function(a, b)
        return a.x < b.x
    end)
end

---按Y坐标排序对象（从下到上）
---@param objects table 对象列表
---@return table 排序后的对象列表
function ObjectManager.sortByY(objects)
    return ObjectManager.sortObjects(objects, function(a, b)
        return a.y < b.y
    end)
end

---随机获取一个对象
---@param objects table 对象列表
---@return any|nil
function ObjectManager.getRandomObject(objects)
    if #objects == 0 then
        return nil
    end

    local index = ran:Int(1, #objects)
    return objects[index]
end

---随机获取N个不重复的对象
---@param objects table 对象列表
---@param count number 要获取的对象数量
---@return table 随机对象列表
function ObjectManager.getRandomObjects(objects, count)
    if count <= 0 or #objects == 0 then
        return {}
    end

    local indices = {}
    for i = 1, #objects do
        indices[i] = i
    end

    for i = #indices, 2, -1 do
        local j = ran:Int(1, i)
        indices[i], indices[j] = indices[j], indices[i]
    end

    local result = {}
    local actualCount = math.min(count, #objects)
    for i = 1, actualCount do
        table.insert(result, objects[indices[i]])
    end

    return result
end

---按权重随机选择一个对象
---@param objects table 对象列表
---@param weightFunc fun(obj: any): number 权重函数，返回值越大被选中概率越高
---@return any|nil
function ObjectManager.getWeightedRandomObject(objects, weightFunc)
    if #objects == 0 then
        return nil
    end

    local weights = {}
    local totalWeight = 0

    for _, obj in ipairs(objects) do
        local weight = weightFunc(obj)
        if weight > 0 then
            weights[obj] = weight
            totalWeight = totalWeight + weight
        end
    end

    if totalWeight == 0 then
        return nil
    end

    local rand = ran:Float(0, totalWeight)
    local accumulated = 0

    for obj, weight in pairs(weights) do
        accumulated = accumulated + weight
        if rand <= accumulated then
            return obj
        end
    end

    return next(weights)
end

---过滤符合条件的对象
---@param objects table 对象列表
---@param predicate fun(obj: any): boolean 过滤条件
---@return table 符合条件的对象列表
function ObjectManager.filter(objects, predicate)
    local result = {}
    for _, obj in ipairs(objects) do
        if predicate(obj) then
            table.insert(result, obj)
        end
    end
    return result
end

---查找第一个符合条件的对象
---@param objects table 对象列表
---@param predicate fun(obj: any): boolean 查找条件
---@return any|nil
function ObjectManager.find(objects, predicate)
    for _, obj in ipairs(objects) do
        if predicate(obj) then
            return obj
        end
    end
    return nil
end

---对所有对象执行映射操作
---@param objects table 对象列表
---@param mapper fun(obj: any): any 映射函数
---@return table 映射结果数组
function ObjectManager.map(objects, mapper)
    local result = {}
    for _, obj in ipairs(objects) do
        table.insert(result, mapper(obj))
    end
    return result
end

---统计符合条件的对象数量
---@param objects table 对象列表
---@param predicate fun(obj: any): boolean 统计条件
---@return number
function ObjectManager.count(objects, predicate)
    local count = 0
    for _, obj in ipairs(objects) do
        if predicate(obj) then
            count = count + 1
        end
    end
    return count
end

---检查是否存在符合条件的对象
---@param objects table 对象列表
---@param predicate fun(obj: any): boolean 检查条件
---@return boolean
function ObjectManager.any(objects, predicate)
    for _, obj in ipairs(objects) do
        if predicate(obj) then
            return true
        end
    end
    return false
end

---检查是否所有对象都符合条件
---@param objects table 对象列表
---@param predicate fun(obj: any): boolean 检查条件
---@return boolean
function ObjectManager.all(objects, predicate)
    for _, obj in ipairs(objects) do
        if not predicate(obj) then
            return false
        end
    end
    return true
end

---计算两个对象之间的距离
---@param obj1 any 对象1（需要有x,y属性）
---@param obj2 any 对象2（需要有x,y属性）
---@return number|nil distance 距离，如果任一对象无效则返回nil
function ObjectManager.getDistance(obj1, obj2)
    if not obj1 or not obj2 or not obj1.x or not obj1.y or not obj2.x or not obj2.y then
        return nil
    end

    local dx = obj1.x - obj2.x
    local dy = obj1.y - obj2.y
    return math.sqrt(dx * dx + dy * dy)
end

---获取对象间的最大距离
---@param objects table 对象列表
---@return number|nil maxDistance 最大距离，如果对象少于2个则返回nil
function ObjectManager.getMaxDistanceBetween(objects)
    if #objects < 2 then
        return nil
    end

    local maxDist = 0

    for i = 1, #objects do
        for j = i + 1, #objects do
            local obj1 = objects[i]
            local obj2 = objects[j]

            if obj1 and obj2 and obj1.x and obj1.y and obj2.x and obj2.y then
                local dx = obj1.x - obj2.x
                local dy = obj1.y - obj2.y
                local dist = math.sqrt(dx * dx + dy * dy)
                maxDist = math.max(maxDist, dist)
            end
        end
    end

    return maxDist
end

---获取对象间的最小距离
---@param objects table 对象列表
---@return number|nil minDistance 最小距离，如果对象少于2个则返回nil
function ObjectManager.getMinDistanceBetween(objects)
    if #objects < 2 then
        return nil
    end

    local minDist = math.huge

    for i = 1, #objects do
        for j = i + 1, #objects do
            local obj1 = objects[i]
            local obj2 = objects[j]

            if obj1 and obj2 and obj1.x and obj1.y and obj2.x and obj2.y then
                local dx = obj1.x - obj2.x
                local dy = obj1.y - obj2.y
                local dist = math.sqrt(dx * dx + dy * dy)
                minDist = math.min(minDist, dist)
            end
        end
    end

    return minDist == math.huge and nil or minDist
end

---分组对象（按指定的键函数）
---@param objects table 对象列表
---@param keyFunc fun(obj: any): any 键函数，返回分组的键
---@return table<any, table> 分组后的对象映射表
function ObjectManager.groupBy(objects, keyFunc)
    local groups = {}

    for _, obj in ipairs(objects) do
        local key = keyFunc(obj)
        if not groups[key] then
            groups[key] = {}
        end
        table.insert(groups[key], obj)
    end

    return groups
end

---分配目标（为每个源对象分配最近的目标对象）
---@param sources table 源对象列表
---@param targets table 目标对象列表
---@return table<any, any> 源对象到目标对象的映射
function ObjectManager.assignTargets(sources, targets)
    local assignments = {}
    local usedTargets = {}

    for _, source in ipairs(sources) do
        if source and source.x and source.y then
            local nearest
            local minDist = math.huge

            for _, target in ipairs(targets) do
                if target and target.x and target.y and not usedTargets[target] then
                    local dx = source.x - target.x
                    local dy = source.y - target.y
                    local dist = dx * dx + dy * dy

                    if dist < minDist then
                        minDist = dist
                        nearest = target
                    end
                end
            end

            if nearest then
                assignments[source] = nearest
                usedTargets[nearest] = true
            end
        end
    end

    return assignments
end

return ObjectManager

