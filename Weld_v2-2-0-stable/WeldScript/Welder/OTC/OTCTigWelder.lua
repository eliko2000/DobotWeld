--[[OTC-TIG焊机接口类，继承`OTCWelder`]]--

local OTCTigWelder = OTCWelder:new()
OTCTigWelder.__index = OTCTigWelder

function OTCTigWelder:new(globalParamObj,welderName)
    local o = OTCWelder:new()
    o.welderName = welderName
    o.globalParamObject = globalParamObj
    o.welderParamObject = WelderParameter:new("OTCTigWelder")
    o.selectedIOStreamName = "" --当前选中的通信方式
    setmetatable(o,self)
    return o
end

function OTCTigWelder:getSupportParams()
    local cfg={}
    cfg.communicationType = {"deviceNet","analogIO"} --参数值只能是 EnumConstant.ConstEnumIOStreamName 的值
    cfg.weldMode = {--参数只能是 EnumConstant.ConstEnumWelderWeldMode 的值
        "dcTig", --直流TIG
        "acTig", --交流TIG
        "adcTig", --AC-DC TIG
        "plasma" --等离子体
    } 
    cfg.wireSpeedEnable = true --焊机是否支持修改送丝机送丝速度
    cfg.wireStickEnable = false --焊接是否支持粘丝解除功能
    return cfg
end

function OTCTigWelder:connect()
    local ioParams = self:getWelderParamObject():getIOStreamParam()
    self.selectedIOStreamName = ioParams.name
    if "deviceNet" == ioParams.name then
        self.welderControlObject = OTCTigWelderControlDeviceNet:new(self)
    elseif "analogIO" == ioParams.name then
        self.welderControlObject = WelderControlDAnalogIO:new(self)
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

--拥有独立寄存器存储空间的参数设置。
function OTCTigWelder:setOTCParameter(strKeyName,value)
    if "deviceNet" ~= self.selectedIOStreamName then
        return true --只有devicenet才定义并实现了一下接口，所以不是devicenet的就直接返回，否则报错
    end
    if strKeyName == OTCWelder.keyTigCtrlConfig then
        if type(value)~="table" then return true end --不是table的直接返回吧
        if not self.welderControlObject:setWeldWireFeedSpeed(value.wireFeedSpeed) then
           MyWelderDebugLog("set wireFeedSpeed fail")
           return false
        end
        if not self.welderControlObject:setClearWidth(value.clearWidth) then
           MyWelderDebugLog("set clearWidth fail")
           return false
        end
        if not self.welderControlObject:setHasPulse(value.pulseConfig) then
           MyWelderDebugLog("set pulseConfig fail")
           return false
        end
        if not self.welderControlObject:setPulseFrequence(value.pulseFreq) then
           MyWelderDebugLog("set pulseFreq fail")
           return false
        end
        if not self.welderControlObject:setPeakCurrent(value.peakCurrent) then
           MyWelderDebugLog("set peakCurrent fail")
           return false
        end
    end
    return true
end

--多个焊接参数共享同一个寄存器地址的参数设置。
function OTCTigWelder:setOTCFunctionView(strKeyName,value)
    if "deviceNet" ~= self.selectedIOStreamName then
        return true --只有devicenet才定义并实现了一下接口，所以不是devicenet的就直接返回，否则报错
    end
    local delayTime = 150 --共享4个寄存器地址修改参数，要等待，视实际情况而定
    local beginTime = Systime()
    local deta = 0
    if strKeyName == OTCWelder.keyWeldConfig then
        if type(value)~="table" then return true end --不是table的直接返回吧
        if not self.welderControlObject:setFunctionView1(102, value.preGasTime*10) then
           MyWelderDebugLog("set preGasTime fail")
           return false
        end
        if not self.welderControlObject:setFunctionView2(103, value.afterGasTime*10) then
           MyWelderDebugLog("set afterGasTime fail")
           return false
        end
        deta = Systime()-beginTime
        if deta<delayTime then Wait(delayTime-deta) end
    elseif strKeyName == OTCWelder.keyTigCtrlConfig then
        if type(value)~="table" then return true end --不是table的直接返回吧
        if not self.welderControlObject:setFunctionView1(107, value.acFreq*10) then
           MyWelderDebugLog("set acFreq fail")
           return false
        end
        if not self.welderControlObject:setFunctionView2(108, value.adcSwitchFreq*10) then
           MyWelderDebugLog("set adcSwitchFreq fail")
           return false
        end
        deta = Systime()-beginTime
        if deta<delayTime then Wait(delayTime-deta) end
        
        beginTime = Systime()
        --*******************************************************************--
        if not self.welderControlObject:setFunctionView1(112, value.wireFeedDelayTime*10) then
           MyWelderDebugLog("set wireFeedDelayTime fail")
           return false
        end
        if not self.welderControlObject:setFunctionView2(114, value.wireFeedIntervalTime*10) then
           MyWelderDebugLog("set wireFeedIntervalTime fail")
           return false
        end
        if not self.welderControlObject:setFunctionView3(115, value.stopWireFeedIntervalTime*10) then
           MyWelderDebugLog("set stopWireFeedIntervalTime fail")
           return false
        end
        deta = Systime()-beginTime
        if deta<delayTime then Wait(delayTime-deta) end
    elseif strKeyName == OTCWelder.keyTigF45Config then
        if type(value)~="table" then return true end --不是table的直接返回吧
        local f45Enable=0
        if value.enable then f45Enable=1 end
        if not self.welderControlObject:setFunctionView1(45, f45Enable) then
           MyWelderDebugLog("set f45Enable fail")
           return false
        end
        if not value.enable then return true end --f45未开启则不用设置以下参数
        if not self.welderControlObject:setFunctionView2(118, value.slowUpTime*10) then
           MyWelderDebugLog("set slowUpTime fail")
           return false
        end
        if not self.welderControlObject:setFunctionView3(119, value.slowDownTime*10) then
           MyWelderDebugLog("set slowDownTime fail")
           return false
        end
        deta = Systime()-beginTime
        if deta<delayTime then Wait(delayTime-deta) end
    end
    return true
end

return OTCTigWelder