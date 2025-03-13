--[[焊机接口类，继承`ImplementWelder`]]--

--【本地私有接口】

-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
--【业务实现接口】-------------------------------------------------------------------------------------------------
local OtherWelder = ImplementWelder:new()
OtherWelder.__index = OtherWelder

-------------------------------------------------------------------------------------------------------------------
--【对内不公开接口】---------------------------------------------------------------------------------------------
function OtherWelder:doStickRelease()
    return true --不支持粘丝解除功能默认返回true
end

-------------------------------------------------------------------------------------------------------------------
--【对外公开接口】-------------------------------------------------------------------------------------------------
function OtherWelder:new(globalParamObj,welderName)
    local o = ImplementWelder:new()
    o.welderName = welderName
    o.globalParamObject = globalParamObj
    o.welderParamObject = WelderParameter:new("OtherWelder")
    setmetatable(o,self)
    return o
end

function OtherWelder:getSupportParams()
    local cfg={}
    cfg.communicationType = {"analogIO"} --参数值只能是 EnumConstant.ConstEnumIOStreamName 的值
    cfg.weldMode = {} --模拟量
    cfg.wireSpeedEnable = false --焊机是否支持修改送丝机送丝速度
    cfg.wireStickEnable = false --焊接是否支持粘丝解除功能
    return cfg
end

function OtherWelder:connect()
    local ioParams = self:getWelderParamObject():getIOStreamParam()
    if "analogIO" == ioParams.name then
        self.welderControlObject = OtherWelderControlDAnalogIO:new(self)
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

function OtherWelder:isJobMode()
    return false --模拟通信没有
end

return OtherWelder