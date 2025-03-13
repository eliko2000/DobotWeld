--[[焊机`DAnalogIO`接口,继承自`WelderControlDAnalogIO`]]--

-------------------------------------------------------------------------------------------------------------------
--【本地私有接口】--


-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
--【业务实现接口】-------------------------------------------------------------------------------------------------
local CloosWelderControlDAnalogIO = WelderControlDAnalogIO:new()
CloosWelderControlDAnalogIO.__index = CloosWelderControlDAnalogIO
CloosWelderControlDAnalogIO.welderObject = nil --焊机对象，也就是`ImplementWelder`的派生类

-------------------------------------------------------------------------------------------------------------------
--【对内不公开接口，只给本身和派生类使用】-----------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------
--【对外公开接口】-------------------------------------------------------------------------------------------------
function CloosWelderControlDAnalogIO:new(welderObj)
    local o = WelderControlObject:new()
    o.welderObject = welderObj
    setmetatable(o,self)
    return o
end

function CloosWelderControlDAnalogIO:setWeldCurrent(newVal)
    return true --协议不支持，所以不执行
end

function CloosWelderControlDAnalogIO:setArcStartCurrent(newVal)
    return true --协议不支持，所以不执行
end

function CloosWelderControlDAnalogIO:setArcEndCurrent(newVal)
    return true --协议不支持，所以不执行
end

function CloosWelderControlDAnalogIO:setWeldVoltage(newVal)
    return true --协议不支持，所以不执行
end

function CloosWelderControlDAnalogIO:setArcStartVoltage(newVal)
    return true --协议不支持，所以不执行
end

function CloosWelderControlDAnalogIO:setArcEndVoltage(newVal)
    return true --协议不支持，所以不执行
end

--有job号的设置
function CloosWelderControlDAnalogIO:setJobId(newVal)
    local welderName = self.welderObject.welderName
    if nil == newVal then
        local params = self.welderObject:getWelderParamObject():getJobModeParam()
        newVal = params.jobId
    end
    if newVal<0 or newVal>255 then
        MyWelderDebugLog(welderName..Language.trLang("WELDER_JOBNUMBER_ERR")..":jobId="..tostring(newVal))
        return false
    end
    MyWelderDebugLog(welderName..":setJobId->write value="..tostring(newVal))
    
    --通过控制DO的组合信号来设置，就是二进制
    --[[DO的1~8分别表示job号的bit0~bit7，需要按照文档接到焊机的对应端口上.
    控制器的DO对应焊接D-IN关系表如下:
    DO1      D-IN5
    DO2      D-IN22
    DO3~8    D-IN7~12
    ]]--
    local doGroupParam={{1,0},{2,0},{3,0},{4,0},{5,0},{6,0},{7,0},{8,0}}
    for i=0,#doGroupParam-1 do
        doGroupParam[i+1][2] = (newVal>>i)&0x01
    end
    DOGroup(table.unpack(doGroupParam))
    return true
end

return CloosWelderControlDAnalogIO