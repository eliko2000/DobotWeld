--[[焊机接口类，继承`ImplementWelder`]]--

--【本地私有接口】

-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
--【业务实现接口】-------------------------------------------------------------------------------------------------
local OTCWelder = ImplementWelder:new()
OTCWelder.__index = OTCWelder

--[[
重要说明：请一定要仔细看。
关于`IDobotWelder:setOTCParameter(k,v)`和`IDobotWelder:setOTCFunctionView(k,v)`接口在该焊机中的参数说明。
1. k通常就是需要下发的参数名称，具体定义参考本文档。
2. v就是对应的参数，具体定义参考本文档。
3. 以下为通用函数`setOTCParameter`和`setOTCFunctionView`的参数说明
]]--
OTCWelder.keyWeldConfig = "keyWeldConfig" --value等同`WelderParameter.innerOTCWeldConfig`
OTCWelder.keyMigGasCtrlConfig = "keyMigGasCtrlConfig" --value等同`WelderParameter.innerOTCMigGasCtrlConfig`
OTCWelder.keyTigCtrlConfig = "keyTigCtrlConfig" --value等同`WelderParameter.innerOTCTigCtrlConfig`
OTCWelder.keyTigF45Config = "keyTigF45Config" --value等同`WelderParameter.innerOTCTigF45Config` 

-------------------------------------------------------------------------------------------------------------------
--【对内不公开接口】---------------------------------------------------------------------------------------------
function OTCWelder:doStickRelease()
    return true --不支持粘丝解除功能默认返回true
end

--获取起弧成功检测的最大时间
function OTCWelder:getCheckStartArcSuccessTimeout()
    local params = self:getWelderParamObject():getNotJobModeParam()
    if type(params)~="table" then return 0 end
    if type(params.params)~="table" then return 0 end
    if type(params.selectedId)~="number" or math.type(params.selectedId)~="integer" then return 0 end
    if #params.params < 1 or params.selectedId<1 or params.selectedId > #params.params then
        return 0
    end
    local otc = params.params[params.selectedId].otc
    if type(otc)~="table" then return 0 end
    if type(otc.preGasTime)~="number" then return 0 end --预送气时间
    if otc.preGasTime < 0 then return 0 end
    return math.floor(otc.preGasTime*1000) --原始数据是秒单位，所以要转成毫秒
end
--获取灭弧成功检测的最大时间
function OTCWelder:getCheckEndArcSuccessTimeout()
    local params = self:getWelderParamObject():getNotJobModeParam()
    if type(params)~="table" then return 0 end
    if type(params.params)~="table" then return 0 end
    if type(params.selectedId)~="number" or math.type(params.selectedId)~="integer" then return 0 end
    if #params.params < 1 or params.selectedId<1 or params.selectedId > #params.params then
        return 0
    end
    local otc = params.params[params.selectedId].otc
    if type(otc)~="table" then return 0 end
    if type(otc.afterGasTime)~="number" then return 0 end --滞后关气时间
    if otc.afterGasTime < 0 then return 0 end
    return math.floor(otc.afterGasTime*1000) --原始数据是秒单位，所以要转成毫秒
end

-------------------------------------------------------------------------------------------------------------------
--【对外公开接口】-------------------------------------------------------------------------------------------------
function OTCWelder:new()
    local o = ImplementWelder:new()
    setmetatable(o,self)
    return o
end

function OTCWelder:isJobMode()
    local mode = self:getWelderParamObject():getWeldMode()
    return "job"==mode
end

--2个通用函数，让子类去实现
function OTCWelder:setOTCParameter(strKeyName,value)
    return true
end
function OTCWelder:setOTCFunctionView(strKeyName,value)
    return true
end

return OTCWelder