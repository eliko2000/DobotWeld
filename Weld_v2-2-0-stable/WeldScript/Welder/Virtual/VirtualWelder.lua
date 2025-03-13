--[[焊机接口类，继承`ImplementWelder`]]--
--[[
虚拟焊机没有真实机器，也就不存在连接与断开，以及通信交互，也不可能发生失败。为了不破坏框架结构，
并且能够模拟演示，所以需要做特殊化处理。
]]--

--【本地私有接口】

-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
--【业务实现接口】-------------------------------------------------------------------------------------------------
local VirtualWelder = ImplementWelder:new()
VirtualWelder.__index = VirtualWelder

-------------------------------------------------------------------------------------------------------------------
--【对内不公开接口】---------------------------------------------------------------------------------------------
function VirtualWelder:doStickRelease()
    return true --不支持粘丝解除功能默认返回true
end

-------------------------------------------------------------------------------------------------------------------
--【对外公开接口】-------------------------------------------------------------------------------------------------
function VirtualWelder:new(globalParamObj,welderName)
    local o = ImplementWelder:new()
    o.welderName = welderName
    o.globalParamObject = globalParamObj
    o.welderParamObject = WelderParameter:new("VirtualWelder")
    setmetatable(o,self)
    o.hasConnected = false
    return o
end

function VirtualWelder:getSupportParams()
    local cfg={}
    cfg.communicationType = {"modbus","deviceNet","analogIO"} --参数值只能是 EnumConstant.ConstEnumIOStreamName 的值
    cfg.weldMode = {--参数只能是 EnumConstant.ConstEnumWelderWeldMode 的值
        "pulseProcess", --脉冲程序
        "job" --job号模式
    }
    cfg.wireSpeedEnable = false --焊机是否支持修改送丝机送丝速度
    cfg.wireStickEnable = false --焊接是否支持粘丝解除功能
    return cfg
end

function VirtualWelder:connect()
    self.welderControlObject = VirtualWelderControl:new(self)
    self.ioStreamObject = RobotManager.createIOStream("analogIO","",0)
    --默认连接上了焊机
    --默认通知了焊机"机器人准备就绪"
    --焊机默认准备好了
    self.hasConnected = true
    self:setApiErrCode(ConstEnumApiErrCode.OK)
    self:readWelderRunStateInfo() --保存一次状态值
    return true
end

function VirtualWelder:disconnect()
    self.hasConnected = false
    self.welderControlObject:arcEnd()
    self:clearWelderRunStateInfo() --断开连接则清空状态信息，否则出现虚假连接
end

function VirtualWelder:isConnected()
    return self.hasConnected
end

function VirtualWelder:isJobMode()
    local mode = self:getWelderParamObject():getWeldMode()
    return "job"==mode
end

function VirtualWelder:arcStart()
    if self.globalParamObject.isVirtualWeld() then --虚拟焊时不发起弧信号
        MyWelderDebugLog(Language.trLang("WELDER_VIR_WELD"))
    else
        self.welderControlObject:arcStart()
    end
    self:readWelderRunStateInfo() --保存一次状态值
    return true
end

function VirtualWelder:arcEnd()
    if self.globalParamObject.isVirtualWeld() then --虚拟焊时不发灭弧信号
        MyWelderDebugLog(Language.trLang("WELDER_NO_WELD_DONT"))
    else
        self.welderControlObject:arcEnd()
    end
    self:readWelderRunStateInfo() --保存一次状态值
    MyWelderDebugLog(Language.trLang("WELDER_END_ARC_OK"))
    return true
end

function VirtualWelder:doSpotWeld(spotWeldParam)
    if not spotWeldParam.switch then
        MyWelderDebugLog(Language.trLang("WELDER_NO_DOT_WELD"))
        return true
    end
    if self.globalParamObject.isVirtualWeld() then
        MyWelderDebugLog(Language.trLang("WELDER_VIR_NO_DOTWELD"))
        return true
    end
    local durationTime = spotWeldParam.durationTime --点焊保持时长，毫秒
    if durationTime<=0 then
        MyWelderDebugLog(Language.trLang("WELDER_DOT_TIME_LESS0"))
        return true
    end
    
    self.welderControlObject:arcStart()
    self:readWelderRunStateInfo() --保存一次状态值
    Wait(durationTime)
    self.welderControlObject:arcEnd()
    self:readWelderRunStateInfo() --保存一次状态值
    MyWelderDebugLog(Language.trLang("WELDER_DOT_END_ARC_OK"))
    return true
end

function VirtualWelder:doWhenUserLuaHasStoped()
    return true
end

function VirtualWelder:doWhenUserLuaHasPause()
    return true
end

function VirtualWelder:doWhenUserLuaHasContinue()
    return true
end

return VirtualWelder