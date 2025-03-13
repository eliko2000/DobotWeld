--[[焊机DeviceNet接口，继承自`WelderControlDeviceNet`]]--

--【本地私有接口】--
--本地电流值转换为焊机想要的电流值
local function innerCurrent_Locale2Welder(newVal)
    return newVal
end
--焊机电流转换为本地想要的电流值
local function innerCurrent_Welder2Locale(newVal)
    return newVal
end

--本地电压值转换为焊机想要的电压值
local function innerVoltage_Locale2Welder(newVal)
    return newVal
end
--焊机电压转换为本地想要的电压值
local function innerVoltage_Welder2Locale(newVal)
    return newVal
end

--焊机送丝速度转换为本地想要的速度值
local function innerWireFeedSpeed_Welder2Locale(newVal)
    return newVal
end
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
--【业务实现接口】-------------------------------------------------------------------------------------------------
local LincolnPowerWaveControlDeviceNet = WelderControlDeviceNet:new()
LincolnPowerWaveControlDeviceNet.__index = LincolnPowerWaveControlDeviceNet

-------------------------------------------------------------------------------------------------------------------
--【对内不公开接口，只给本身和派生类使用】-----------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------
--【对外公开接口】-------------------------------------------------------------------------------------------------
function LincolnPowerWaveControlDeviceNet:new(welderObj)
    local o = WelderControlDeviceNet:new()
    o.welderObject = welderObj
    setmetatable(o,self)
    return o
end

function LincolnPowerWaveControlDeviceNet:initWelder()
    --[[
    不仅要发机器人准备好信号，还要发灭弧信号,因为刚开机时可能存在有起弧信号，
    导致这个原因是正常起弧焊接时，在需要发送断弧的时没有发成功
    ]]--
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":initWelder->before write")
    return self:innerUpdateHoldRegsValue_Address(0,0x00,function(oldV,newV) 
                                                        local v = oldV
                                                        v = v&(~(1<<0)) --灭弧
                                                        v = v&(~(1<<3)) --停止送丝
                                                        v = v&(~(1<<4)) --停止退丝
                                                        v = v&(~(1<<1)) --停止气检
                                                        MyWelderDebugLog(welderName..":initWelder->write value="..v)
                                                        return v
                                                     end)
end

function LincolnPowerWaveControlDeviceNet:isWelderReady()
    local newVal = self:innerGetInRegsValue_Address(0,4) or {}
    if #newVal<4 then
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":isWelderReady->read fail,return value is nil")
        return nil
    end
    --特殊处理，只要有一个数字不为0则表示焊机连接并准备好
    for i=1,#newVal do
        if 0~=newVal[i] then
            return true
        end
    end
    return false
end

function LincolnPowerWaveControlDeviceNet:setWeldCurrent(newVal)
    return true --协议不支持，所以不执行
end

function LincolnPowerWaveControlDeviceNet:setArcStartCurrent(newVal)
    return true --协议不支持，所以不执行
end

function LincolnPowerWaveControlDeviceNet:setArcEndCurrent(newVal)
    return true --协议不支持，所以不执行
end

function LincolnPowerWaveControlDeviceNet:getWeldCurrent()
    local newVal = self:innerGetInRegsValue_Address(2) or {}
    if #newVal<1 then
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":getWeldCurrent->read fail,return value is nil")
        return nil
    end
    return innerCurrent_Welder2Locale(newVal[1])
end

function LincolnPowerWaveControlDeviceNet:setWeldVoltage(newVal)
    return true --协议不支持，所以不执行
end

function LincolnPowerWaveControlDeviceNet:setArcStartVoltage(newVal)
    return true --协议不支持，所以不执行
end

function LincolnPowerWaveControlDeviceNet:setArcEndVoltage(newVal)
    return true --协议不支持，所以不执行
end

function LincolnPowerWaveControlDeviceNet:getWeldVoltage()
    local newVal = self:innerGetInRegsValue_Address(1) or {}
    if #newVal<1 then
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":getWeldVoltage->read fail,return value is nil")
        return nil
    end
    return innerVoltage_Welder2Locale(newVal[1])
end

function LincolnPowerWaveControlDeviceNet:getWeldWireFeedSpeed()
    local newVal = self:innerGetInRegsValue_Address(3) or {}
    if #newVal<1 then
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":getWeldWireFeedSpeed->read fail,return value is nil")
        return nil
    end
    return innerWireFeedSpeed_Welder2Locale(newVal[1])
end

function LincolnPowerWaveControlDeviceNet:setWeldMode(newVal)
    return true --协议不支持，所以不执行
end

function LincolnPowerWaveControlDeviceNet:setJobId(newVal)
    return true --协议不支持，所以不执行
end

function LincolnPowerWaveControlDeviceNet:arcStart()
    local newVal = 0x01
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":arcStart->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                            local v = oldV|newV
                                                            MyWelderDebugLog(welderName..":arcStart->write value="..v)
                                                            return v
                                                         end)
end

function LincolnPowerWaveControlDeviceNet:isArcStarted()
    local welderName = self.welderObject.welderName
    local newVal = self:innerGetInRegsValue_Address(0) or {}
    if #newVal<1 then
        MyWelderDebugLog(welderName..":isArcStarted->read fail,return value is nil")
        return nil
    end
    local state = (newVal[1]&0x01)==0x01
    MyWelderDebugLog(string.format("%s:isArcStarted->read ok,newVal[1]=0x%X, state=%s",welderName,newVal[1], tostring(state)))
    return state
end

function LincolnPowerWaveControlDeviceNet:arcEnd()
    local newVal = 0xFFFE
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":arcEnd->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                            local v = oldV&newV
                                                            MyWelderDebugLog(welderName..":arcEnd->write value="..v)
                                                            return v
                                                         end)
end

function LincolnPowerWaveControlDeviceNet:isArcEnded()
    local welderName = self.welderObject.welderName
    local newVal = self:innerGetInRegsValue_Address(0) or {}
    if #newVal<1 then
        MyWelderDebugLog(welderName..":isArcEnded->read fail,return value is nil")
        return nil
    end
    local state = (newVal[1]&0x01)==0x00
    MyWelderDebugLog(string.format("%s:isArcEnded->read ok,newVal[1]=0x%X, state=%s",welderName,newVal[1], tostring(state)))
    return state
end

function LincolnPowerWaveControlDeviceNet:hasEndArcByMannual()
    local welderName = self.welderObject.welderName
    local newVal = self:innerGetHoldRegsValue_Address(0) or {}
    if #newVal<1 then
        MyWelderDebugLog(welderName..":hasEndArcByMannual->read fail,return value is nil")
        return nil
    end
    local state = (newVal[1]&0x01)==0x00
    MyWelderDebugLog(string.format("%s:hasEndArcByMannual->read ok,newVal[1]=0x%X, state=%s",welderName,newVal[1], tostring(state)))
    return state
end

function LincolnPowerWaveControlDeviceNet:startWireFeed()
    local newVal = 1<<3
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":startWireFeed->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                            local v = oldV|newV
                                                            MyWelderDebugLog(welderName..":startWireFeed->write value="..v)
                                                            return v
                                                         end)
end
function LincolnPowerWaveControlDeviceNet:stopWireFeed()
    local newVal = (~(1<<3))&0xFFFF
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":stopWireFeed->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                            local v = oldV&newV
                                                            MyWelderDebugLog(welderName..":stopWireFeed->write value="..v)
                                                            return v
                                                         end)
end

function LincolnPowerWaveControlDeviceNet:startWireBack()
    local newVal = 1<<4
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":startWireBack->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                            local v = oldV|newV
                                                            MyWelderDebugLog(welderName..":startWireBack->write value="..v)
                                                            return v
                                                         end)
end
function LincolnPowerWaveControlDeviceNet:stopWireBack()
    local newVal = (~(1<<4))&0xFFFF
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":stopWireBack->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                            local v = oldV&newV
                                                            MyWelderDebugLog(welderName..":stopWireBack->write value="..v)
                                                            return v
                                                         end)
end

function LincolnPowerWaveControlDeviceNet:isWireHasSignal()
    local newVal = self:innerGetInRegsValue_Address(1) or {}
    if #newVal<1 then --操作失败认为无信号
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":isWireHasSignal->read fail,return value is nil")
        return nil
    end
    return ((newVal[1]>>13)&0x01)==0x01
end

function LincolnPowerWaveControlDeviceNet:startGasCheck()
    local newVal = 1<<1
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":startGasCheck->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                            local v = oldV|newV
                                                            MyWelderDebugLog(welderName..":startGasCheck->write value="..v)
                                                            return v
                                                         end)
end
function LincolnPowerWaveControlDeviceNet:stopGasCheck()
    local newVal = (~(1<<1))&0xFFFF
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":stopGasCheck->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                            local v = oldV&newV
                                                            MyWelderDebugLog(welderName..":stopGasCheck->write value="..v)
                                                            return v
                                                         end)
end

function LincolnPowerWaveControlDeviceNet:isGasHasSignal()
    local newVal = self:innerGetInRegsValue_Address(1) or {}
    if #newVal<1 then --默认操作失败为无信号
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":isGasHasSignal->read fail,return value is nil")
        return nil
    end
    return ((newVal[1]>>11)&0x01)==0x01
end

function LincolnPowerWaveControlDeviceNet:getWelderRunStateInfo()
    local info = {connectState = false}
    --一次性读取所有的数据
    local newVal = self:innerGetInRegsValue_Address(0,4) or {}
    if #newVal<4 then return info end
    
    if newVal[1]~=0 then info.connectState = true
    else info.connectState = false
    end
    
    info.weldVoltage = innerVoltage_Welder2Locale(newVal[2])
    info.weldCurrent = innerCurrent_Welder2Locale(newVal[3])
    info.wireFeedSpeed = innerCurrent_Welder2Locale(newVal[4])
    
    if (newVal[1]&0x01)==0x01 then info.weldState = 1
    else info.weldState = 0
    end

    return info
end

function LincolnPowerWaveControlDeviceNet:getWelderErrCode()
    return 0
end

return LincolnPowerWaveControlDeviceNet