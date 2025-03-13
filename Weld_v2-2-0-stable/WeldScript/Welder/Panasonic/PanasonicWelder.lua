--[[焊机接口类，继承`ImplementWelder`]]--

--【本地私有接口】

-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
--【业务实现接口】-------------------------------------------------------------------------------------------------
local PanasonicWelder = ImplementWelder:new()
PanasonicWelder.__index = PanasonicWelder

-------------------------------------------------------------------------------------------------------------------
--【对内不公开接口】---------------------------------------------------------------------------------------------
function PanasonicWelder:doStickRelease()
    return true --不支持粘丝解除功能默认返回true
end

-------------------------------------------------------------------------------------------------------------------
--【对外公开接口】-------------------------------------------------------------------------------------------------
function PanasonicWelder:new(globalParamObj,welderName)
    local o = ImplementWelder:new()
    o.welderName = welderName
    o.globalParamObject = globalParamObj
    o.welderParamObject = WelderParameter:new("PanasonicWelder")
    setmetatable(o,self)
    return o
end

function PanasonicWelder:getSupportParams()
    local cfg={}
    cfg.communicationType = {"deviceNet","analogIO"} --参数值只能是 EnumConstant.ConstEnumIOStreamName 的值
    cfg.weldMode = {--参数只能是 EnumConstant.ConstEnumWelderWeldMode 的值
        --"independentCurrentMode", --独立调节/电流优先模式
        --"idenpendentWireFeedMode", --独立调节/送丝速度优先模式
        "monizationCurrentMode", --一元化调节/电流优先模式
        --"monizationWireFeedMode", --一元化调节/送丝速度优先模式
        "job" --job号模式
    } 
    cfg.wireSpeedEnable = false --焊机是否支持修改送丝机送丝速度
    cfg.wireStickEnable = false --焊接是否支持粘丝解除功能，这可以通过焊机的协议来控制开启与关闭，目前暂不启用吧
    return cfg
end

function PanasonicWelder:connect()
    local ioParams = self:getWelderParamObject():getIOStreamParam()
    if "deviceNet" == ioParams.name then
        self.welderControlObject = PanasonicWelderControlDeviceNet:new(self)
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

function PanasonicWelder:isJobMode()
    local mode = self:getWelderParamObject():getWeldMode()
    return "job"==mode
end

return PanasonicWelder