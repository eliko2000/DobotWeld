--[[焊机接口类，继承`ImplementWelder`]]--

--【本地私有接口】

-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
--【业务实现接口】-------------------------------------------------------------------------------------------------
local AotaiWelder = ImplementWelder:new()
AotaiWelder.__index = AotaiWelder

-------------------------------------------------------------------------------------------------------------------
--【对内不公开接口】---------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------
--【对外公开接口】-------------------------------------------------------------------------------------------------
function AotaiWelder:new()
    local o = ImplementWelder:new()
    setmetatable(o,self)
    return o
end

function AotaiWelder:setTouchPostionEnable(bEnable)
    return self.welderControlObject:setTouchPostionEnable(bEnable)
end

function AotaiWelder:isTouchPositionSuccess()
    return self.welderControlObject:isTouchPositionSuccess()
end
function AotaiWelder:setTouchPositionFailStatus(bStatus)
    return self.welderControlObject:setTouchPositionFailStatus(bStatus)
end

function AotaiWelder:isJobMode()
    local mode = self:getWelderParamObject():getWeldMode()
    return "job"==mode
end

return AotaiWelder