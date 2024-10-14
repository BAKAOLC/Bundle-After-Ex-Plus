--region Imports
local lstg = lstg
local AttributeProxy = require("foundation.AttributeProxy")
--endregion

--region Class Definition
local class = lstg.CreateGameObjectClass()

function class.create(master, group, offset)
    local self = lstg.New(class)
    self.group = group or GROUP_ENEMY_BULLET    -- Collider group
    self.layer = LAYER_ENEMY_BULLET             -- Collider layer
    self.rect = true                            -- Use rectangle collider
    self.hide = true                            -- Collider do not render
    ---@diagnostic disable
    self.___collider_master = master            -- Master object
    self.___collider_offset = offset            -- Offset
    ---@diagnostic enable
    AttributeProxy.applyProxies(self, class.___attribute_proxies)
    return self
end

function class:del()
    if IsValid(self.___collider_master) and self.___collider_master.onDelCollider then
        self.___collider_master:onDelCollider(self, self.___collider_offset)
    end
end

function class:kill()
    if IsValid(self.___collider_master) and self.___collider_master.onKillCollider then
        self.___collider_master:onKillCollider(self, self.___collider_offset)
    end
end

--endregion

--region Attribute Proxies
local attribute_proxies = {}
class.___attribute_proxies = attribute_proxies

--region ___killed
local proxy_killed = AttributeProxy.createProxy("___killed")
attribute_proxies["___killed"] = proxy_killed

function proxy_killed:setter(key, value, storage)
    local old_value = storage[key]
    if value == old_value then
        return
    end
    storage[key] = value
    if lstg.IsValid(self.___collider_master) then
        lstg.SetAttr(self, "colli", self.___collider_master.colli and not value)
    else
        lstg.SetAttr(self, "colli", false)
    end
end

--endregion

--region _graze
local proxy_graze = AttributeProxy.createProxy("_graze")
attribute_proxies["_graze"] = proxy_graze

function proxy_graze:getter(key, storage)
    if IsValid(self.___collider_master) then
        return self.___collider_master._graze
    end
end

function proxy_graze:setter(key, value, storage)
    if IsValid(self.___collider_master) then
        self.___collider_master._graze = value
    end
end

--endregion

--region colli
local proxy_colli = AttributeProxy.createProxy("colli")
attribute_proxies["colli"] = proxy_colli

function proxy_colli:getter(key, storage)
    if IsValid(self.___collider_master) then
        return self.___collider_master.colli and not self.___killed
    end
end

function proxy_colli:setter(key, value, storage)
    if IsValid(self.___collider_master) then
        lstg.SetAttr(self, "colli", self.___collider_master.colli and value and not self.___killed)
    else
        lstg.SetAttr(self, "colli", false)
    end
end

--endregion

--region bound
local proxy_bound = AttributeProxy.createProxy("bound")
attribute_proxies["bound"] = proxy_bound

function proxy_bound:init()
    lstg.SetAttr(self, "bound", false)
end

function proxy_bound:getter(key, storage)
    if IsValid(self.___collider_master) then
        return self.___collider_master.bound
    end
end

function proxy_bound:setter(key, value, storage)
    if IsValid(self.___collider_master) then
        self.___collider_master.bound = value
    else
        lstg.SetAttr(self, "bound", true)
    end
end

--endregion
--endregion

return class