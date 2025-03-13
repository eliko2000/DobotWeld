--[[焊机`DAnalogIO`接口,继承自`WelderControlDAnalogIO`]]--

-------------------------------------------------------------------------------------------------------------------
--【本地私有接口】--


-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
--【业务实现接口】-------------------------------------------------------------------------------------------------
local OtherWelderControlDAnalogIO = WelderControlDAnalogIO:new()
OtherWelderControlDAnalogIO.__index = OtherWelderControlDAnalogIO
OtherWelderControlDAnalogIO.welderObject = nil --焊机对象，也就是`ImplementWelder`的派生类

-------------------------------------------------------------------------------------------------------------------
--【对内不公开接口，只给本身和派生类使用】-----------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------
--【对外公开接口】-------------------------------------------------------------------------------------------------
function OtherWelderControlDAnalogIO:new(welderObj)
    local o = WelderControlDAnalogIO:new()
    o.welderObject = welderObj
    o.isArcSuccess = false
    setmetatable(o,self)
    return o
end

function OtherWelderControlDAnalogIO:arcStart()
    local welderName = self.welderObject.welderName
    local params = self.welderObject:getWelderParamObject():getAnalogIOSignalParam()
    MyWelderDebugLog(welderName..":arcStart->DO("..tostring(params.controlBoxSignalParam.arcStart)..",ON)")
    DO(params.controlBoxSignalParam.arcStart,ON)
    self.isArcSuccess = true
    return true
end

function OtherWelderControlDAnalogIO:isArcStarted()
    local params = self.welderObject:getWelderParamObject():getAnalogIOSignalParam() or {}
    local cbsp = params.controlBoxSignalParam or {}
    --如果没有配置起弧反馈检测信号，则认为该信号不需要检测
    if math.type(cbsp.arcStartCheck) ~= "integer" then
        return self.isArcSuccess
    end
    if cbsp.arcStartCheck<1 then
        return self.isArcSuccess
    end
    
    local welderName = self.welderObject.welderName
    --有配置起弧反馈检测信号则直接检测
    if DI(cbsp.arcStartCheck) == ON then 
        MyWelderDebugLog(welderName..":isArcStarted->DI("..tostring(cbsp.arcStartCheck)..")=ON")
        return true
    else
        MyWelderDebugLog(welderName..":isArcStarted->DI("..tostring(cbsp.arcStartCheck)..")=OFF")
        return false
    end
end

function OtherWelderControlDAnalogIO:arcEnd()
    local welderName = self.welderObject.welderName
    local params = self.welderObject:getWelderParamObject():getAnalogIOSignalParam()
    MyWelderDebugLog(welderName..":arcEnd->DO("..tostring(params.controlBoxSignalParam.arcStart)..",OFF)")
    DO(params.controlBoxSignalParam.arcStart,OFF)
    self.isArcSuccess = false
    return true
end

function OtherWelderControlDAnalogIO:isArcEnded()
    local params = self.welderObject:getWelderParamObject():getAnalogIOSignalParam()
    local cbsp = params.controlBoxSignalParam or {}
    --如果没有配置起弧反馈检测信号，则认为该信号不需要检测
    if math.type(cbsp.arcStartCheck) ~= "integer" then
        return not self.isArcSuccess
    end
    if cbsp.arcStartCheck<1 then
        return not self.isArcSuccess
    end
    
    local welderName = self.welderObject.welderName
    --有配置起弧反馈检测信号则直接检测
    if DI(cbsp.arcStartCheck) == OFF then 
        MyWelderDebugLog(welderName..":isArcEnded->DI("..tostring(cbsp.arcStartCheck)..")=OFF")
        return true
    else
        MyWelderDebugLog(welderName..":isArcEnded->DI("..tostring(cbsp.arcStartCheck)..")=ON")
        return false
    end
end


function OtherWelderControlDAnalogIO:getWelderRunStateInfo()
    local info = {connectState=true, --模拟量通信没有断开连接的状态，所以永远都是连接状态
                  weldState=0
                 }
    --之所以不用isArcStarted，是不想打印太多日志
    local params = self.welderObject:getWelderParamObject():getAnalogIOSignalParam() or {}
    if type(params.controlBoxSignalParam)~="table" then return info end
    if math.type(params.controlBoxSignalParam.arcStartCheck)~="integer" then --没有配置起弧反馈检测信号，则认为该信号不需要检测
        if self.isArcSuccess then
            info.weldState = 1
        else
            info.weldState = 0
        end
        return info
    end
    if params.controlBoxSignalParam.arcStartCheck<1 then --没有配置起弧反馈检测信号，则认为该信号不需要检测
        if self.isArcSuccess then
            info.weldState = 1
        else
            info.weldState = 0
        end
        return info
    end
    --有配置起弧反馈检测信号则直接检测
    if DI(params.controlBoxSignalParam.arcStartCheck) == ON then 
        info.weldState = 1
    else
        info.weldState = 0
    end
    return info
end

return OtherWelderControlDAnalogIO