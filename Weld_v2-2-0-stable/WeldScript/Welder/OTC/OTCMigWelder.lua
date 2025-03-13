--[[OTC-MIG焊机接口类，继承`OTCWelder`]]--

local OTCMigWelder = OTCWelder:new()
OTCMigWelder.__index = OTCMigWelder

function OTCMigWelder:new(globalParamObj,welderName)
    local o = OTCWelder:new()
    o.welderName = welderName
    o.globalParamObject = globalParamObj
    o.welderParamObject = WelderParameter:new("OTCMigWelder")
    o.selectedIOStreamName = "" --当前选中的通信方式
    setmetatable(o,self)
    return o
end

function OTCMigWelder:getSupportParams()
    local cfg={}
    cfg.communicationType = {"deviceNet","analogIO"} --参数值只能是 EnumConstant.ConstEnumIOStreamName 的值
    cfg.weldMode = {--参数只能是 EnumConstant.ConstEnumWelderWeldMode 的值
        "dcPulse", --直流脉冲
        "dc", --直流电
        "dcLowSplash", --直流低溅射
        "dcWavePulse", --直流波脉冲
        "acPulse", --交流脉冲
        "acWavePulse", --交流波脉冲
        "dArc", --D-Arc
        "msMig" --MS-MIG
    } 
    cfg.wireSpeedEnable = true --焊机是否支持修改送丝机送丝速度
    cfg.wireStickEnable = false --焊接是否支持粘丝解除功能
    return cfg
end

function OTCMigWelder:connect()
    local ioParams = self:getWelderParamObject():getIOStreamParam()
    self.selectedIOStreamName = ioParams.name
    if "deviceNet" == ioParams.name then
        self.welderControlObject = OTCMigWelderControlDeviceNet:new(self)
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
function OTCMigWelder:setOTCParameter(strKeyName,value)
    if "deviceNet" ~= self.selectedIOStreamName then
        return true --只有devicenet才定义并实现了一下接口，所以不是devicenet的就直接返回，否则报错
    end
    if strKeyName == OTCWelder.keyWeldConfig then
        if type(value)~="table" then return true end --不是table的直接返回吧
        if not self.welderControlObject:setGasNumber(value.gasNumber) then
           MyWelderDebugLog("set gasNumber fail")
           return false
        end
        if not self.welderControlObject:setWireMaterialNumber(value.wireMaterialNumber) then
           MyWelderDebugLog("set wireMaterialNumber fail")
           return false
        end
        if not self.welderControlObject:setWireDiameterNumber(value.wireDiameterNumber) then
           MyWelderDebugLog("set wireDiameterNumber fail")
           return false
        end
    elseif strKeyName == OTCWelder.keyMigGasCtrlConfig then
        if type(value)~="table" then return true end
        if not self.welderControlObject:setPenetrationOn(value.penetration) then
           MyWelderDebugLog("set penetration fail")
           return false
        end
        if not self.welderControlObject:setWaveFreq(value.waveFreq) then
           MyWelderDebugLog("set waveFreq fail")
           return false
        end
        if not self.welderControlObject:setArcCharact(value.arcValue) then
           MyWelderDebugLog("set arcValue fail")
           return false
        end
    end
    return true
end

--多个焊接参数共享同一个寄存器地址的参数设置。
function OTCMigWelder:setOTCFunctionView(strKeyName,value)
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
    elseif strKeyName == OTCWelder.keyMigGasCtrlConfig then
        if type(value)~="table" then return true end --不是table的直接返回吧
        local waterCooledTorch = 0
        if value.waterCooledTorch then waterCooledTorch=1 end
        if not self.welderControlObject:setFunctionView1(101, waterCooledTorch) then
           MyWelderDebugLog("set waterCooledTorch fail")
           return false
        end
        deta = Systime()-beginTime
        if deta<delayTime then Wait(delayTime-deta) end
    end 
    return true
end

return OTCMigWelder