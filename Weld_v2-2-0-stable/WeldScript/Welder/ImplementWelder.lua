--[[焊机接口类，继承`IDobotWelder`]]--
-------------------------------------------------------------------------------------------------------------------
--【业务实现接口】-------------------------------------------------------------------------------------------------
local ImplementWelder = IDobotWelder:new()
ImplementWelder.__index = ImplementWelder
ImplementWelder.welderName = "" --焊机的名称，也就是`EnumConstant.ConstEnumWelderName`的值
ImplementWelder.ioStreamObject = nil --IO通信对象，也就是`IDobotIOStream`的派生类
ImplementWelder.welderParamObject = nil --焊机参数对象，也就是`WelderParameter`对象
ImplementWelder.globalParamObject = nil --焊机全局参数对象，也就是`GlobalParameter`对象
ImplementWelder.welderControlObject = nil --焊机控制对象，也就是`WelderControlObject`的派生类

-------------------------------------------------------------------------------------------------------------------
--【本地私有接口】-------------------------------------------------------------------------------------------------
local InnerLocalAPI = {}
--判断起弧是否成功,true表示成功，false表示失败
function InnerLocalAPI.isArcStartSuccess(self)
    local okTimes = 0
    local beginTime = Systime()
    local endTime = beginTime
    local checkoutTimeout = 3000+self:getCheckStartArcSuccessTimeout()
    local isOk,tmpTime = false,0
    while (endTime-beginTime)<=checkoutTimeout do
        tmpTime = Systime()
        isOk = self.welderControlObject:isArcStarted()
        if true==isOk then
            okTimes = okTimes+1
            if okTimes>=4 then break end
        elseif false==isOk then --起弧未成功标志
        else --发生了通信异常
        end
        endTime = Systime()
        if endTime-tmpTime<50 then
            Wait(50+tmpTime-endTime)
        end
    end
    if okTimes<4 then
        MyWelderDebugLog(Language.trLang("WELDER_CHECK_ARC_FAIL"))
        return false
    end
    return true
end

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

--判断灭弧是否成功,true表示成功，false表示失败
function InnerLocalAPI.isArcEndSuccess(self)
    local beginTime = Systime()
    local endTime = beginTime
    local checkoutTimeout = 3000+self:getCheckEndArcSuccessTimeout()
    while (endTime-beginTime)<=checkoutTimeout do
        local isOk = self.welderControlObject:isArcEnded()
        if true==isOk then return true
        elseif false==isOk then
            Wait(20)
        else --通信发生了异常
            return false
        end
        endTime = Systime()
    end
    MyWelderDebugLog(Language.trLang("WELDER_CHECK_END_FAIL"))
    return false
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

--获取点焊保持时间
function InnerLocalAPI.getSpotWeldHoldingTime(spotWeldParam)
    if type(spotWeldParam)~="table" then return 0 end
    if type(spotWeldParam.durationTime)~="number" or math.type(spotWeldParam.durationTime)~="integer" then return 0 end
    return spotWeldParam.durationTime
end

--[[
在userAPI.lua中：起弧过程中，可能存在一种情况就是起弧检测成功，但还没来得及执行setWelding(true)，结果脚本点击了暂停，
这就导致了焊接中的状态发生错误，所以需要将整个起弧动作封装到daemon.lua进程中并通过rpc方式调用。
]]--
function InnerLocalAPI.innerStartArc(self)
    if DobotWelderRPC.api.useRPC then
        return DobotWelderRPC.api.StartArc()
    end
    -- 非rpc的操作则执行这里，通常是daemon.lua才是非rpc模式
    if not self.welderControlObject:arcStart() then --起弧
        --MyWelderDebugLog(Language.trLang("WELDER_TRIGGER_ARC_ERR"))
        return false,Language.trLang("WELDER_TRIGGER_ARC_ERR")
    end
    if not InnerLocalAPI.isArcStartSuccess(self) then
        --[[起弧状态检测失败了，但是寄存器的起弧信号值还在，所以还是要进行灭弧]]--
        for i=1,3 do
            self.welderControlObject:arcEnd()
            Wait(50)
        end
        --MyWelderDebugLog(Language.trLang("WELDER_ARC_CHECK_FAIL"))
        return false,Language.trLang("WELDER_ARC_CHECK_FAIL")
    end
    self.globalParamObject.setWelding(true) --起弧成功后，设置焊接中标志
    --MyWelderDebugLog(Language.trLang("WELDER_START_ARC_OK"))
    return true,Language.trLang("WELDER_START_ARC_OK")
end

--[[
在userAPI.lua中：灭弧过程中，可能存在一种情况就是灭弧检测成功，但还没来得及执行setWelding(false)，结果脚本点击了暂停，
这就导致了焊接中的状态发生错误，所以需要将整个灭弧动作封装到daemon.lua进程中并通过rpc方式调用。
]]--
function InnerLocalAPI.innerEndArc(self)
    if DobotWelderRPC.api.useRPC then
        return DobotWelderRPC.api.EndArc()
    end
    -- 非rpc的操作则执行这里，通常是daemon.lua才是非rpc模式
    for i=1,3 do
        self.welderControlObject:arcEnd()
        if InnerLocalAPI.isArcEndSuccess(self) then
            self.globalParamObject.setWelding(false) --灭弧成功后，清除焊接中标志
            return true,""
        else
            Wait(10)
        end
    end
    return false,Language.trLang("WELDER_CHECK_END_FAIL")
end

--粘丝解除,true表示解除成功，false表示解除失败
function InnerLocalAPI.innerStickRelease(self)
    if self:isJobMode() then
        return true --job模式下不做粘丝解除处理
    end
    if self.welderControlObject:isStickRelease() then
        return true--没有粘丝，直接返回
    end
    local params = self.globalParamObject.getSpecialHandleParams().stickRelease
    params.retryCount = 1 --固定1次写死
    if not params.isRelease or params.retryCount<1 then --未启用或者重试次数少于1
        MyWelderDebugLog("params.isRelease="..tostring(params.isRelease)..",params.retryCount="..params.retryCount)
        MyWelderDebugLog(Language.trLang("WELDER_STICK_RELEASE_NOUSE"))
        return false --没有启用粘丝解除功能,则认为粘丝解除失败
    end

    --保持时间
    local durationTime = 0
    if type(params.durationTime)~= "number" then durationTime=0 end
    durationTime = math.floor(durationTime)
    if durationTime<0 then durationTime=0 end

    --发生粘丝，则需要用起弧、灭弧的方式炸断焊丝
    MyWelderDebugLog(Language.trLang("WELDER_BEGIN_STICK_RELEASE"))
    self.welderControlObject:setArcStartCurrent(params.current)
    self.welderControlObject:setArcStartVoltage(params.voltage)
    local bIsSuccess = false
    for i=1,params.retryCount do
        InnerLocalAPI.innerStartArc(self)
        if durationTime>0 then Wait(durationTime) end --保持一段时间
        InnerLocalAPI.innerEndArc(self)
        if self.welderControlObject:isStickRelease() then
            bIsSuccess = true --粘丝解除成功了，则直接跳出
            break
        end
    end
    if bIsSuccess then
        MyWelderDebugLog(Language.trLang("WELDER_STICK_RELEASE_OK"))
    else
        MyWelderDebugLog(Language.trLang("WELDER_STICK_RELEASE_FAIL"))
    end
    return bIsSuccess
end

--起弧时设置起弧参数---------------------------
function InnerLocalAPI.innerExecuteSetArcParams(self,params)
    if not self.welderControlObject:setJobId(0) then
        MyWelderDebugLog(Language.trLang("WELDER_ARC_JOB0_ERR"))
        return false
    end
    local newParams = params.params[params.selectedId]
    if not self.welderControlObject:setArcStartCurrent(newParams.arcStartCurrent) then
        MyWelderDebugLog(Language.trLang("WELDER_ARC_CURRENT_ERR"))
        return false
    end
    if not self.welderControlObject:setArcStartVoltage(newParams.arcStartVoltage) then
        MyWelderDebugLog(Language.trLang("WELDER_ARC_VOLTAGE_ERR"))
        return false
    end
    return true
end
--起弧时设置焊接参数---------------------------
function InnerLocalAPI.innerExecuteSetWeldParams(self,params)
    local newParams = params.params[params.selectedId]
    if not self.welderControlObject:setWeldCurrent(newParams.weldCurrent) then
        MyWelderDebugLog(Language.trLang("WELDER_WELD_CURRENT_ERR"))
        return false
    end
    if not self.welderControlObject:setWeldVoltage(newParams.weldVoltage) then
        MyWelderDebugLog(Language.trLang("WELDER_WELD_VOLTAGE_ERR"))
        return false
    end
    return true
end
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
--【对内不公开接口】----------------------------------------------------------------------------------------------
--[[
功能：处理粘丝解除
参数：无
返回值：true表示解除成功，false表示解除失败
说明：默认支持此功能，不支持粘丝解除功能的焊机，则子类一定要重写该函数并且返回true
]]--
function ImplementWelder:doStickRelease()
    return InnerLocalAPI.innerStickRelease(self)
end

--[[
功能：获取检测起弧/灭弧成功的超时时间
参数：无
返回值：毫秒单位的时间
说明：1. 有些焊机存在一些特殊性，导致起弧灭弧成功信号要很久才反馈，比如OTC焊机有预送气和滞后送气，
         这就导致检测时间变长，所以需要根据焊机的不同来决定这个时长。
      2. 需要特殊时长的焊机，子类一定要重写该函数并且返回自己的检测时长
]]--
function ImplementWelder:getCheckStartArcSuccessTimeout()
    return 0
end
function ImplementWelder:getCheckEndArcSuccessTimeout()
    return 0
end


--[[
说明：在起弧(前/后)、灭弧(前/后)的时候，进行相关参数设置。
1. 子类需要特殊处理的，重写此接口。
2. 大多数焊机在起弧、灭弧的时候，设置电流电压和等待时间。
3. 个别焊机在起弧、灭弧的时候，处理有一些特殊性。
   比如激光焊机设置的是功率，且可能需要主动打开/关闭送气、送丝
]]--
--起弧前设置起弧/焊接需要的参数
function ImplementWelder:setParamsBeforeArcStart()
    if self:isJobMode() then return true end --job模式不设置参数,直接返回
    local selectParams = self:getWelderParamObject():getNotJobModeParam()
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
--起弧后设置起弧/焊接需要的参数
function ImplementWelder:setParamAfterArcStart(beginArcStartTime)
    if self:isJobMode() then return true end --job模式不设置参数,直接返回
    local selectParams = self:getWelderParamObject():getNotJobModeParam()
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
--灭弧前设置灭弧需要的参数
function ImplementWelder:setParamBeforeArcEnd()
    if self:isJobMode() then return end --job模式不设置参数,直接返回
    local selectParams = self:getWelderParamObject():getNotJobModeParam()
    local holdingTime = InnerLocalAPI.getArcEndHoldingTime(selectParams)
    if holdingTime>0 then --等待时间大于0则设置灭弧参数并等待
        local beginTime = Systime()
        local newParams = selectParams.params[selectParams.selectedId]
        if not self.welderControlObject:setArcEndCurrent(newParams.arcEndCurrent) then
            MyWelderDebugLog(Language.trLang("WELDER_END_CURRENT_FAIL"))
        end
        if not self.welderControlObject:setArcEndVoltage(newParams.arcEndVoltage) then
            MyWelderDebugLog(Language.trLang("WELDER_END_VOLTAGE_FAIL"))
        end
        local delta = Systime()-beginTime
        if delta<holdingTime then Wait(holdingTime-delta) end
    end
end

-------------------------------------------------------------------------------------------------------------------
--【对外公开接口】-------------------------------------------------------------------------------------------------
function ImplementWelder:new()
    local o = IDobotWelder:new()
    setmetatable(o,self)
    return o
end

function ImplementWelder:getWelderParamObject()
    return self.welderParamObject
end

function ImplementWelder:getIOStreamObject()
    return self.ioStreamObject
end

--让子类去实现
function ImplementWelder:getSupportParams()
    return {}
end

--让子类去实现
function ImplementWelder:connect()
    return false
end

function ImplementWelder:disconnect()
    if nil==self.ioStreamObject then
        self:clearWelderRunStateInfo()
        return
    end
    pcall(function(self) self.ioStreamObject:disconnect() end,self)
    self:clearWelderRunStateInfo() --断开连接则清空状态信息，否则出现虚假连接
end

function ImplementWelder:isConnected()
    if nil==self.ioStreamObject then return false end
    return self.ioStreamObject:isConnected()
end

function ImplementWelder:setMmiLockUI(bIsLock)
    return self.welderControlObject:setMmiLockUI(bIsLock)
end

--目前部分焊机不支持焊丝接触寻位功能，所以默认使用DI和DO的方式处理,此方式与`WelderControlDAnalogIO`完全一样
--焊机实现了此功能并特殊化的，则需要在子类中重写
function ImplementWelder:setTouchPostionEnable(bEnable)
    local welderName = self.welderName
    --MyWelderDebugLog(welderName..":setTouchPostionEnable->write value="..tostring(bEnable))
    local params = self.globalParamObject.getAnalogIOSignalParam() or {}
    if type(params.touchPositionParam)~="table" then
        --MyWelderDebugLog(welderName .. "-->setTouchPostionEnable:" .. Language.trLang("TOUCH_POSITION_PARAM_CFG_ERR"))
        return nil
    end
    local tpp = params.touchPositionParam
    if math.type(tpp.enableDO)~="integer" then
        --MyWelderDebugLog(welderName .. "-->setTouchPostionEnable:" .. Language.trLang("TOUCH_POSITION_PARAM_CFG_ERR"))
        return nil
    end
    if tpp.enableDO<1 then
        --MyWelderDebugLog(welderName .. "-->setTouchPostionEnable:" .. Language.trLang("TOUCH_POSITION_PARAM_CFG_ERR"))
        return nil
    end
    if bEnable then
        DO(tpp.enableDO,ON)
    else
        DO(tpp.enableDO,OFF)
    end
    return true
end

function ImplementWelder:isTouchPositionSuccess()
    local welderName = self.welderName
    local params = self.globalParamObject.getAnalogIOSignalParam() or {}
    if type(params.touchPositionParam)~="table" then
        --MyWelderDebugLog(welderName .. "-->isTouchPositionSuccess:" .. Language.trLang("TOUCH_POSITION_PARAM_CFG_ERR"))
        return nil
    end
    local tpp = params.touchPositionParam
    if math.type(tpp.successDI)~="integer" then
        --MyWelderDebugLog(welderName .. "-->isTouchPositionSuccess:" .. Language.trLang("TOUCH_POSITION_PARAM_CFG_ERR"))
        return nil
    end
    if tpp.successDI<1 then
        --MyWelderDebugLog(welderName .. "-->isTouchPositionSuccess:" .. Language.trLang("TOUCH_POSITION_PARAM_CFG_ERR"))
        return nil
    end
    return DI(tpp.successDI)==ON
end

function ImplementWelder:setTouchPositionFailStatus(bStatus)
    local welderName = self.welderName
    --MyWelderDebugLog(welderName..":setTouchPositionFailStatus->write value="..tostring(bStatus))
    local params = self.globalParamObject.getAnalogIOSignalParam() or {}
    if type(params.touchPositionParam)~="table" then
        --MyWelderDebugLog(welderName .. "-->setTouchPositionFailStatus:" .. Language.trLang("TOUCH_POSITION_PARAM_CFG_ERR"))
        return nil
    end
    local tpp = params.touchPositionParam
    if math.type(tpp.failDO)~="integer" then
        --MyWelderDebugLog(welderName .. "-->setTouchPositionFailStatus:" .. Language.trLang("TOUCH_POSITION_PARAM_CFG_ERR"))
        return nil
    end
    if tpp.failDO<1 then
        --MyWelderDebugLog(welderName .. "-->setTouchPositionFailStatus:" .. Language.trLang("TOUCH_POSITION_PARAM_CFG_ERR"))
        return nil
    end
    if bStatus then
        DO(tpp.failDO,ON)
    else
        DO(tpp.failDO,OFF)
    end
    return true
end

--让子类去实现
function ImplementWelder:isJobMode()
    return false
end

function ImplementWelder:setWorkMode(newVal)
    return self.welderControlObject:setWorkMode(newVal)
end

function ImplementWelder:setWeldMode(newVal)
    return self.welderControlObject:setWeldMode(newVal)
end

function ImplementWelder:setProcessNumber(newVal)
    return self.welderControlObject:setProcessNumber(newVal)
end

function ImplementWelder:setJobId(newVal)
    return self.welderControlObject:setJobId(newVal)
end

function ImplementWelder:setWeldCurrent(newVal)
    return self.welderControlObject:setWeldCurrent(newVal)
end

function ImplementWelder:setWeldVoltage(newVal)
    return self.welderControlObject:setWeldVoltage(newVal)
end

function IDobotWelder:setWeldWireFeedSpeed(newVal)
    return self.welderControlObject:setWeldWireFeedSpeed(newVal)
end

function ImplementWelder:setWeldPower(newVal)
    return self.welderControlObject:setWeldPower(newVal)
end

function ImplementWelder:arcStart()
    --[[
    焊接的工艺要求：
    当保持时间大于0时，流程是：设置起弧参数--->起弧-->保持一段时间-->设置焊接参数-->结束
    当保持时间小等于0，流程是：设置焊接参数--->起弧-------------------------------->结束
    ]]--
    --起弧前设置起弧参数
    if not self:setParamsBeforeArcStart() then return false end

    local beginArcStartTime = Systime() --记录开始起弧的时间，计算“保持一段时间”的差值
    if self.globalParamObject.isVirtualWeld() then
        MyWelderDebugLog(Language.trLang("WELDER_VIR_WELD")) --虚拟焊，不做任何处理
    else
        --非虚拟焊时发送起弧信号
        local isOk,msg = InnerLocalAPI.innerStartArc(self)
        if not isOk then
            MyWelderDebugLog(msg)
            return false
        end
    end
    --起弧成功后设置参数
    if not self:setParamAfterArcStart(beginArcStartTime) then
        InnerLocalAPI.innerEndArc(self) --设置焊接参数失败后需要灭弧
    end
    return true
end

function ImplementWelder:arcEnd()
    self:setParamBeforeArcEnd() --在灭弧之前，设置灭弧参数
    --虚拟焊，不做任何处理
    if not self.globalParamObject.isWelding() then
        MyWelderDebugLog(Language.trLang("WELDER_NO_WELD_DONT"))
        return true
    end

    --起弧状态，发送灭弧信号
    MyWelderDebugLog(Language.trLang("WELDER_END_SIGNAL_CHECK"))
    local isEndSuccess,errmsg = InnerLocalAPI.innerEndArc(self)
    if true==isEndSuccess then
        --[[焊机发了灭弧信号后基本是很快灭弧，并停止送丝和吹气，但是OTC这款焊机特殊，它虽然灭弧并停止送丝，
        但不立马停止吹气，反而是要求停在灭弧位置继续吹气，所以特殊处理。
        这个值也肯能被当作是灭弧检测时间。
        ]]--
        local twait = self:getCheckEndArcSuccessTimeout()
        if twait>0 then Wait(twait) end
        MyWelderDebugLog(Language.trLang("WELDER_END_ARC_OK"))
    else
        MyWelderDebugLog(errmsg)
        MyWelderDebugLog(Language.trLang("WELDER_END_ARC_FAIL"))
    end
    if not self:doStickRelease() then --执行粘丝解除功能
        WeldReportScriptPause(Language.trLang("WELDER_STICK_RELEASE_MANUAL")) --粘丝解除失败时，则暂停脚本，提示人工处理。
    end
    return isEndSuccess
end

--[[
说明：1. 这2个函数是给daemon.lua进程使用的，为了rpc的方式调用。其他地方严禁使用
      2. 这个地方之所以这么调用，是因为目前还没想到更好的方式。
]]--
function ImplementWelder:rpcStartArc()
    return InnerLocalAPI.innerStartArc(self)
end
function ImplementWelder:rpcEndArc()
    return InnerLocalAPI.innerEndArc(self)
end
--********************************************************************************************

function ImplementWelder:readArcStateRealtime()
    return self.welderControlObject:isArcStarted()
end
function ImplementWelder:hasEndArcByMannual()
    return self.welderControlObject:hasEndArcByMannual()
end

function ImplementWelder:setWireFeed(isOn)
    if isOn then
        return self.welderControlObject:startWireFeed()
    else
        return self.welderControlObject:stopWireFeed()
    end
end
--通过rpc方式调用执行一段时间的送丝
function ImplementWelder:execWireFeed(durationMiliseconds)
    if DobotWelderRPC.api.useRPC then
        return DobotWelderRPC.api.ExecWireFeed(durationMiliseconds)
    end
    return true
end

function ImplementWelder:setWireBack(isOn)
    if isOn then
        return self.welderControlObject:startWireBack()
    else
        return self.welderControlObject:stopWireBack()
    end
end
--通过rpc方式调用执行一段时间的退丝
function ImplementWelder:execWireBack(durationMiliseconds)
    if DobotWelderRPC.api.useRPC then
        return DobotWelderRPC.api.ExecWireBack(durationMiliseconds)
    end
    return true
end

function ImplementWelder:setGasCheck(isOn)
    if isOn then
        return self.welderControlObject:startGasCheck()
    else
        return self.welderControlObject:stopGasCheck()
    end
end
--通过rpc方式调用执行一段时间的吹气
function ImplementWelder:execGasCheck(durationMiliseconds)
    if DobotWelderRPC.api.useRPC then
        return DobotWelderRPC.api.ExecGasCheck(durationMiliseconds)
    end
    return true
end

function ImplementWelder:doSpotWeld(spotWeldParam)
    MyWelderDebugLog("begin do spot weld...........")
    self:setApiErrCode(ConstEnumApiErrCode.OK)
    local strErrMsg = ""
    if not spotWeldParam.switch then
        MyWelderDebugLog(Language.trLang("WELDER_NO_DOT_WELD"))
        return true
    end
    if not self.welderControlObject:setWeldMode() then
        self:setApiErrCode(ConstEnumApiErrCode.SetWeldParam_Err)
        strErrMsg = Language.trLang("JOBMODE_DOT_WELD_BEFORE_JOB_COMM_ERR")
        WeldReportScriptStop(strErrMsg)
        return false
    end
    if not self:setProcessNumber(spotWeldParam.processNumber) then
        self:setApiErrCode(ConstEnumApiErrCode.SetWeldParam_Err)
        strErrMsg = Language.trLang("DOT_WELD_PRG_COMM_ERR")
        WeldReportScriptStop(strErrMsg)
        return false
    end
    if self:isJobMode() then --job模式
        if not self.welderControlObject:setJobId(spotWeldParam.jobId) then
            self:setApiErrCode(ConstEnumApiErrCode.SetWeldParam_Err)
            strErrMsg = Language.trLang("JOB_DOT_WELD_BEFORE_JOB_COMM_ERR")
            WeldReportScriptStop(strErrMsg)
            return false
        end
    else
        --下发非job模式的参数给焊机
        if not self.welderControlObject:setJobId(0) then
            self:setApiErrCode(ConstEnumApiErrCode.SetWeldParam_Err)
            strErrMsg = Language.trLang("NO_JOB_DOT_WELD_BEFORE_JOB0_COMM_ERR")
            WeldReportScriptStop(strErrMsg)
            return false
        end
        if not self.welderControlObject:setWeldCurrent(spotWeldParam.current) then
            self:setApiErrCode(ConstEnumApiErrCode.SetWeldParam_Err)
            strErrMsg = Language.trLang("DOT_WELD_CURRENT_FAIL_COMM_ERR")
            WeldReportScriptStop(strErrMsg)
            return false
        end
        if not self.welderControlObject:setWeldVoltage(spotWeldParam.voltage) then
            self:setApiErrCode(ConstEnumApiErrCode.SetWeldParam_Err)
            strErrMsg = Language.trLang("DOT_WELD_VOLTAGE_FAIL_COMM_ERR")
            WeldReportScriptStop(strErrMsg)
            return false
        end
    end

    if self.globalParamObject.isVirtualWeld() then
        MyWelderDebugLog(Language.trLang("WELDER_VIR_NO_DOTWELD"))
        return true
    end

    local durationTime = InnerLocalAPI.getSpotWeldHoldingTime(spotWeldParam) --点焊保持时长，毫秒
    if durationTime<=0 then
        MyWelderDebugLog(Language.trLang("WELDER_DOT_TIME_LESS0"))
        return true
    end
    
    local bIsArcStartOk = false --起弧结果状态
    local bIsArcStartSuccess = false --起弧反馈信号状态
    local bIsArcEndSuccess = false --灭弧反馈信号状态
    --起弧
    local isOk = self.welderControlObject:arcStart()
    if nil==isOk then
        self:setApiErrCode(ConstEnumApiErrCode.TriggerArc_Err)
        strErrMsg = Language.trLang("DOT_WELD_START_ARC_FAIL_COMM_ERR")
        WeldReportScriptStop(strErrMsg)
        return false
    elseif false==isOk then
        self:setApiErrCode(ConstEnumApiErrCode.TriggerArc_Err)
        strErrMsg = Language.trLang("DOT_WELD_START_ARC_FAIL")
        WeldReportScriptStop(strErrMsg)
        goto labelEndArc
    else
        bIsArcStartOk = true
    end

    --起弧检测
    isOk = InnerLocalAPI.isArcStartSuccess(self)
    if true==isOk then --起弧成功
        bIsArcStartSuccess = true
        Wait(durationTime) --延时,让点焊持续这么长时间
    elseif false==isOk then --起弧失败
        self:setApiErrCode(ConstEnumApiErrCode.CheckArc_Err)
        MyWelderDebugLog(Language.trLang("WELDER_DOT_CHECK_ARC_SIGNAL_FAIL"))
    else --通信异常，则需要重新连接
        self:setApiErrCode(ConstEnumApiErrCode.CheckArc_Err)
        MyWelderDebugLog(Language.trLang("WELDER_DOT_ARC_CHECK_CONNECT_AGAIN"))
        pcall(function(self) self:connect() end,self)
    end

::labelEndArc::
    --灭弧
    MyWelderDebugLog(Language.trLang("WELDER_END_SIGNAL_CHECK"))
    isOk,strErrMsg = InnerLocalAPI.innerEndArc(self)
    bIsArcEndSuccess = isOk
    if isOk then
        MyWelderDebugLog(Language.trLang("WELDER_DOT_END_ARC_OK"))
    else
        self:setApiErrCode(ConstEnumApiErrCode.EndArc_Err)
        strErrMsg = Language.trLang("DOT_WELD_FAIL")
        WeldReportScriptStop(strErrMsg)
    end
    --local isReleaseSuccess = self:doStickRelease() --点焊就不用处理粘丝解除功能，让人工自己处理
    local strLogMsgResult = string.format(Language.trLang("WELDER_DOT_RESULT")..":arcState=%s,arcFeedback=%s,endFeedback=%s",
                                          tostring(bIsArcStartOk),tostring(bIsArcStartSuccess),
                                          tostring(bIsArcEndSuccess))
    MyWelderDebugLog(strLogMsgResult)
    return (bIsArcStartOk and bIsArcStartSuccess and bIsArcEndSuccess)
end

function ImplementWelder:readWelderRunStateInfo()
    local isOk,info = false,nil
    if self:isConnected() then
        isOk,info = pcall(function(self) return self.welderControlObject:getWelderRunStateInfo() end, self)
    end
    if isOk then
        self.globalParamObject.saveWelderRunStateInfo(info)
    else
        info = {}
        self.globalParamObject.saveWelderRunStateInfo(info)
    end
    return info
end
function ImplementWelder:clearWelderRunStateInfo()
    self.globalParamObject.saveWelderRunStateInfo({})
end

--当userAPI.lua脚本停止时的处理，在deamon.lua调用
function ImplementWelder:doWhenUserLuaHasStoped()
    pcall(WeldArcSpeedEnd)
    pcall(WeaveEnd)
    
    if not self.globalParamObject.isWelding() then
        --[[发了起弧信号，但是在起弧检测过程中脚本停止/暂停运行了，结果这个isWelding标志位仍然是false，
        因为这个标志只有在真正起弧成功时才会置为true,所以无论是否真的起弧成功，都发送灭弧信号。
        更好的做法是：添加一个发送起弧信号的标志位，只要发了起弧就置为true,不想再跨进程维护变量标志位了。]]--
        for i=1,3 do
            self.welderControlObject:arcEnd()
            Wait(50)
        end
        MyWelderDebugLog(Language.trLang("SCRIPT_NO_WELD_DONOT"))
        return true
    end

    local isOk,_msg = InnerLocalAPI.innerEndArc(self)
    if true==isOk then
        MyWelderDebugLog(Language.trLang("SCRIPT_STOP_ARC_END_OK"))
    else
        MyWelderDebugLog(Language.trLang("SCRIPT_STOP_ARC_END_FAIL"))
    end
    self:doStickRelease() --执行粘丝解除功能
    return isOk
end

--当userAPI.lua脚本暂停时的处理，在deamon.lua调用
function ImplementWelder:doWhenUserLuaHasPause()
    if not self.globalParamObject.isWelding() then
        --[[发了起弧信号，但是在起弧检测过程中脚本停止/暂停运行了，结果这个isWelding标志位仍然是false，
        因为这个标志只有在真正起弧成功时才会置为true,所以无论是否真的起弧成功，都发送灭弧信号。]]--
        for i=1,3 do
            self.welderControlObject:arcEnd()
            Wait(50)
        end
        MyWelderDebugLog(Language.trLang("SCRIPT_PAUSE_NO_WELD_DONOT"))
        return true
    end
    local isOk,_msg = InnerLocalAPI.innerEndArc(self)
    if true==isOk then
        MyWelderDebugLog(Language.trLang("SCRIPT_PAUSE_ARC_END_OK"))
        self:doStickRelease() --执行粘丝解除功能
    else
        local strErrMsg = Language.trLang("SCRIPT_PAUSE_ARC_END_FAIL")
        MyWelderDebugLog(strErrMsg)
        WeldReportScriptPause(strErrMsg) --抛出错误信息并让用户脚本暂停运行
    end
    return isOk
end

--当userAPI.lua脚本继续运行时的处理，在deamon.lua调用
function ImplementWelder:doWhenUserLuaHasContinue()
    local function pfnExecute(self)
        if self.globalParamObject.isVirtualWeld() then
            MyWelderDebugLog(Language.trLang("WELDER_VIR_WELD")) --虚拟焊，不做任何处理
            return true
        end
        local isOk,msg = InnerLocalAPI.innerStartArc(self)
        if not isOk then
            MyWelderDebugLog(msg)
            return false
        end
        return true
    end
    MyWelderDebugLog(Language.trLang("SCRIPT_CONTINUE_START_ARC"))
    local isOk,err = pcall(function(self) return pfnExecute(self) end,self)
    if not isOk or not err then
        local strErrMsg = ""
        if false==isOk then strErrMsg = Language.trLang("CONTINUE_RUN_ARC_START_FAIL").. ":" .. tostring(err) end
        if false==err then strErrMsg = Language.trLang("CONTINUE_RUN_ARC_START_FAIL") end
        MyWelderDebugLog(strErrMsg)
        return false,strErrMsg
    end
    return true,""
end

return ImplementWelder