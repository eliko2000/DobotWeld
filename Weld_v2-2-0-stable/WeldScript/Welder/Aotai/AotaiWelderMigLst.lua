--[[焊机MIG-LST型号接口类，继承`AotaiWelder`]]--

local AotaiWelderMigLst = AotaiWelder:new()
AotaiWelderMigLst.__index = AotaiWelderMigLst

function AotaiWelderMigLst:new(globalParamObj,welderName)
    local o = AotaiWelder:new()
    o.welderName = welderName
    o.globalParamObject = globalParamObj
    o.welderParamObject = WelderParameter:new("AotaiWelderMigLst")
    setmetatable(o,self)
    return o
end

function AotaiWelderMigLst:getSupportParams()
    local cfg={}
    cfg.communicationType = {"modbus","deviceNet","analogIO"} --参数值只能是 EnumConstant.ConstEnumIOStreamName 的值
    cfg.weldMode = {--参数只能是 EnumConstant.ConstEnumWelderWeldMode 的值
        "flat", --平特性
        "pulseProcess", --脉冲程序
        "job", --调用状态(对于奥太焊机这个就是callState调用模式)
        "lowSplash", --低飞溅模式
        "flatSpotWeld", --平特性点焊
        -- "pulseSpotWeld", --脉冲点焊，此功能目前不支持
        "lowSplashSpotWeld" --低飞溅点焊
    } 
    cfg.wireSpeedEnable = false --焊机是否支持修改送丝机送丝速度
    cfg.wireStickEnable = true --焊接是否支持粘丝解除功能
    return cfg
end

function AotaiWelderMigLst:connect()
    local ioParams = self:getWelderParamObject():getIOStreamParam()
    if "modbus" == ioParams.name then
        self.welderControlObject = AotaiWelderMigLstControlModbus:new(self)
    elseif "deviceNet" == ioParams.name then
        self.welderControlObject = AotaiWelderMigLstControlDeviceNet:new(self)
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

return AotaiWelderMigLst