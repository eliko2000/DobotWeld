--[[焊机接口类，继承`ImplementWelder`]]--

--【本地私有接口】
local InnerLocalAPI = {}
--获取起弧保持时间
function InnerLocalAPI.getArcStartHoldingTime(params)
    if type(params)~="table" then return 0 end
    if type(params.params)~="table" then return 0 end
    if type(params.selectedId)~="number" or math.type(params.selectedId)~="integer" then return 0 end
    if #params.params < 1 or params.selectedId<1 or params.selectedId > #params.params then
        return 0
    end
    local newVal = params.params[params.selectedId].arcStartDurationTime
    if type(newVal)~="number" or math.type(newVal)~="integer" then return 0 end
    if newVal <= 0 then
        MyWelderDebugLog(Language.trLang("WELDER_ARC_PRM_NO")..":hold-time="..tostring(newVal))
        return 0
    end
    return newVal
end

--获取灭弧保持时间
function InnerLocalAPI.getArcEndHoldingTime(params)
    if type(params)~="table" then return 0 end
    if type(params.params)~="table" then return 0 end
    if type(params.selectedId)~="number" or math.type(params.selectedId)~="integer" then return 0 end
    if #params.params < 1 or params.selectedId<1 or params.selectedId > #params.params then
        return 0
    end
    local newVal = params.params[params.selectedId].arcEndDurationTime
    if type(newVal)~="number" or math.type(newVal)~="integer" then return 0 end
    if newVal <= 0 then
       MyWelderDebugLog(Language.trLang("WELDER_END_PRM_NO")..":time="..tostring(newVal))
       return 0
    end
    return newVal
end

--起弧时设置起弧参数---------------------------
function InnerLocalAPI.innerExecuteSetArcParams(self,params)
    if self:isJobMode() then return true end --job模式不设置以下参数
    if not self.welderControlObject:setJobId(0) then
        MyWelderDebugLog(Language.trLang("WELDER_ARC_JOB0_ERR"))
        return false
    end
    local newParams = params.params[params.selectedId]
    if not self.welderControlObject:setArcStartPower(newParams.arcStartPower) then
        MyWelderDebugLog(Language.trLang("WELDER_ARC_POWER_ERR"))
        return false
    end
    return true
end
--起弧时设置焊接参数---------------------------
function InnerLocalAPI.innerExecuteSetWeldParams(self,params)
    if self:isJobMode() then return true end --job模式不设置以下参数
    local newParams = params.params[params.selectedId]
    if not self.welderControlObject:setWeldPower(newParams.weldPower) then
        MyWelderDebugLog(Language.trLang("WELDER_WELD_POWER_ERR"))
        return false
    end
    return true
end

-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
--【业务实现接口】-------------------------------------------------------------------------------------------------
local LaserWelder = ImplementWelder:new()
LaserWelder.__index = LaserWelder

-------------------------------------------------------------------------------------------------------------------
--【对内不公开接口】---------------------------------------------------------------------------------------------
function LaserWelder:doStickRelease()
    return true --不支持粘丝解除功能默认返回true
end

function LaserWelder:setParamsBeforeArcStart()
    if self:isJobMode() then return true end --job模式不设置参数,直接返回
    local selectParams = self:getWelderParamObject():getLaserWeldParam()
    local holdingTime = InnerLocalAPI.getArcStartHoldingTime(selectParams) --保持时间
    if holdingTime>0 then --保持时间>0则设置起弧参数
        if not InnerLocalAPI.innerExecuteSetArcParams(self,selectParams) then
            MyWelderDebugLog(Language.trLang("WELDER_ARC_PRM_ERR"))
            return false
        end
    else --保持时间<=0则设置焊接参数
        if not InnerLocalAPI.innerExecuteSetWeldParams(self,selectParams) then
            MyWelderDebugLog(Language.trLang("WELDER_WELD_PRM_ERR"))
            return false
        end
    end
    return true
end

function LaserWelder:setParamAfterArcStart(beginArcStartTime)
    if self:isJobMode() then return true end --job模式不设置参数,直接返回
    local selectParams = self:getWelderParamObject():getLaserWeldParam()
    local holdingTime = InnerLocalAPI.getArcStartHoldingTime(selectParams) --保持时间
    if holdingTime<=0 then return true end --等待时间不合理的,直接返回
    
    --起弧成功后保持一段时间
    local arcStartCostTime = Systime()-beginArcStartTime --计算起弧总共消耗的时间
    --如果起弧保持时间大于起弧过程中消耗的时间，则继续等待剩余时间，否则不等待，这样可以节省时间
    if holdingTime>arcStartCostTime then
        holdingTime = holdingTime-arcStartCostTime
        Wait(holdingTime) --设置焊接参数
    end
    if not InnerLocalAPI.innerExecuteSetWeldParams(self,selectParams) then
        MyWelderDebugLog(Language.trLang("WELDER_WELD_PRM_ERR"))
        return false
    end
    return true
end

function LaserWelder:setParamBeforeArcEnd()
    if self:isJobMode() then return end --job模式不设置参数,直接返回
    local selectParams = self:getWelderParamObject():getLaserWeldParam()
    local holdingTime = InnerLocalAPI.getArcEndHoldingTime(selectParams)
    if holdingTime>0 then --等待时间大于0则设置灭弧参数
        local beginTime = Systime()
        local newParams = selectParams.params[selectParams.selectedId]
        if not self.welderControlObject:setArcEndPower(newParams.arcEndPower) then
            MyWelderDebugLog(Language.trLang("WELDER_END_POWER_FAIL"))
        end
        local delta = Systime()-beginTime
        if delta<holdingTime then Wait(holdingTime-delta) end
    end
end

-------------------------------------------------------------------------------------------------------------------
--【对外公开接口】-------------------------------------------------------------------------------------------------
function LaserWelder:new(globalParamObj,welderName)
    local o = ImplementWelder:new()
    o.welderName = welderName
    o.globalParamObject = globalParamObj
    o.welderParamObject = WelderParameter:new("LaserWelder")
    setmetatable(o,self)
    return o
end

function LaserWelder:getSupportParams()
    local cfg={}
    cfg.communicationType = {"analogIO"} --参数值只能是 EnumConstant.ConstEnumIOStreamName 的值
    cfg.weldMode = {} --模拟量
    cfg.wireSpeedEnable = false --焊机是否支持修改送丝机送丝速度
    cfg.wireStickEnable = false --焊接是否支持粘丝解除功能
    return cfg
end

function LaserWelder:connect()
    local ioParams = self:getWelderParamObject():getIOStreamParam()
    if "analogIO" == ioParams.name then
        self.welderControlObject = LaserWelderControlDAnalogIO:new(self)
    else
        self:setApiErrCode(ConstEnumApiErrCode.Param_Err)
        MyWelderDebugLog(Language.trLang("WELDER_NO_SUPPORT_COMM"))
        return false
    end
    
    self.ioStreamObject = RobotManager.createIOStream(ioParams.name,ioParams.ip,ioParams.port)
    local isSuccess = self.ioStreamObject:connect()
    if not isSuccess then
        self:setApiErrCode(ConstEnumApiErrCode.ConnectWelder_Err)
        MyWelderDebugLog(Language.trLang("WELDER_CONNECT_WELDER_FAIL"))
        return false
    end
    --每次连接成功就先通知焊机"机器人准备就绪"
    if not self.welderControlObject:initWelder() then
        self:setApiErrCode(ConstEnumApiErrCode.InitWelder_Err)
        MyWelderDebugLog(Language.trLang("WELDER_INIT_WELDER_FAIL"))
        return false
    end
    if not self.welderControlObject:isWelderReady() then
        self:setApiErrCode(ConstEnumApiErrCode.WelderNoReady_Err)
        MyWelderDebugLog(Language.trLang("WELDER_NOT_READY"))
        return false
    end
    self:setApiErrCode(ConstEnumApiErrCode.OK)
    return true
end

function LaserWelder:isJobMode()
    return false --模拟通信没有
end

return LaserWelder