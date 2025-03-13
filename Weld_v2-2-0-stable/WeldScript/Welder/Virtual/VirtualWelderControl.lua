--[[焊机接口，继承自`WelderControlObject`]]--

--[[
虚拟焊接机，没有与真实的机器连接，所以这里面所有数据都是模拟的，不存在返回失败的情况
]]--
local VirtualWelderControl = WelderControlObject:new()
VirtualWelderControl.__index = VirtualWelderControl

function VirtualWelderControl:new(welderObj)
    local o = WelderControlObject:new()
    setmetatable(o,self)
    o.isWelding = false --当前焊接中
    return o
end


function VirtualWelderControl:setWeldCurrent(newVal)
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":setWeldCurrent->write value="..tostring(newVal))
    return true
end

function VirtualWelderControl:setArcStartCurrent(newVal)
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":setArcStartCurrent->write value="..tostring(newVal))
    return true
end

function VirtualWelderControl:setArcEndCurrent(newVal)
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":setArcEndCurrent->write value="..tostring(newVal))
    return true
end

function VirtualWelderControl:getWeldCurrent()
    if true==self.isWelding then
        return math.random(1000,2000)*0.1
    else
        return math.random(0,10)*0.1
    end
end

function VirtualWelderControl:setWeldVoltage(newVal)
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":setWeldVoltage->write value="..tostring(newVal))
    return true
end

function VirtualWelderControl:setArcStartVoltage(newVal)
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":setArcStartVoltage->write value="..tostring(newVal))
    return true
end

function VirtualWelderControl:setArcEndVoltage(newVal)
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":setArcEndVoltage->write value="..tostring(newVal))
    return true
end

function VirtualWelderControl:getWeldVoltage()
    if true==self.isWelding then
        return math.random(-100,100)*0.1
    else
        return 0
    end
end

function VirtualWelderControl:getWeldWireFeedSpeed()
    if true==self.isWelding then
        return math.random(-50,50)*0.1
    else
        return 0
    end
end

function VirtualWelderControl:setWeldMode(newVal)
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":setWeldMode->before write,weldMode="..tostring(newVal))
    return true
end

function VirtualWelderControl:setJobId(newVal)
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":setJobId->before write,jobId="..tostring(newVal))
    return true
end

function VirtualWelderControl:setProcessNumber(newVal)
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":setProcessNumber->before write,processNumber="..tostring(newVal))
    return true
end

function VirtualWelderControl:arcStart()
    self.isWelding = true
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":arcStart")
    return true
end

function VirtualWelderControl:isArcStarted()
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(string.format("%s:isArcStarted->read ok,state=%s",tostring(self.isWelding)))
    if true==self.isWelding then
        return true
    else
        return false
    end
end

function VirtualWelderControl:arcEnd()
    self.isWelding = false
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":arcEnd")
    return true
end

function VirtualWelderControl:isArcEnded()
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(string.format("%s:isArcEnded->read ok,state=%s",tostring(self.isWelding)))
    if true==self.isWelding then
        return false
    else
        return true
    end
end

function VirtualWelderControl:getWelderRunStateInfo()
    local info = {}
    info.connectState = true
    info.weldVoltage = self:getWeldVoltage()
    info.weldCurrent = self:getWeldCurrent()
    info.wireFeedSpeed = self:getWeldWireFeedSpeed()
    if true==self.isWelding then
        info.weldState = 1 --焊接状态，0-焊接结束/待机、1-焊接中
    else
        info.weldState = 0
    end
    info.wireState = 0 --焊丝状态，0-正常、1-焊丝粘结
    return info
end

function VirtualWelderControl:getWelderErrCode()
    return 0
end

return VirtualWelderControl