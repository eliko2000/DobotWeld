--[[焊机DeviceNet接口，继承自`WelderControlModbus`]]--

--【本地私有接口】--
--本地电流值转换为焊机想要的电流值
local function innerCurrent_Locale2Welder(newVal)
    return newVal
end
--焊机电流转换为本地想要的电流值
local function innerCurrent_Welder2Locale(newVal)
    newVal = CHelperTools.ToUInt16(newVal)
    return newVal
end

--本地电压值转换为焊机想要的电压值
local function innerVoltage_Locale2Welder(newVal)
    return newVal
end
--焊机电压转换为本地想要的电压值
local function innerVoltage_Welder2Locale(newVal)
    newVal = CHelperTools.ToUInt16(newVal)
    newVal = newVal/10
    return newVal
end

--焊机送丝速度转换为本地想要的速度值
local function innerWireFeedSpeed_Welder2Locale(newVal)
    newVal = CHelperTools.ToUInt16(newVal)
    newVal = newVal/10
    return newVal
end

--焊机有watchdog技术，周期性的轮流置位bit8为0/1，这样当焊机与机器人失去连接时机器人自己中断焊接。
local function innerWatchDogMonitor(self)
    if self.watchdog~=1 then self.watchdog=1
    else self.watchdog=0
    end
    return self:innerUpdateHoldRegsValue_Address(0,self.watchdog,function(oldV,newV)
                                                                    if 1==newV then return oldV|0x0010 end
                                                                    return oldV&0xFFEF
                                                                 end)
end

-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
--【业务实现接口】-------------------------------------------------------------------------------------------------
local KemppiAXWelderControlModbus = WelderControlModbus:new()
KemppiAXWelderControlModbus.__index = KemppiAXWelderControlModbus

-------------------------------------------------------------------------------------------------------------------
--【对内不公开接口，只给本身和派生类使用】-----------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------
--【对外公开接口】-------------------------------------------------------------------------------------------------
function KemppiAXWelderControlModbus:new(welderObj)
    local o = WelderControlModbus:new()
    o.welderObject = welderObj
    o.watchdog = 0
    setmetatable(o,self)
    return o
end

function KemppiAXWelderControlModbus:initWelder()
    --[[
    不仅要发机器人准备好信号，还要发灭弧信号,因为刚开机时可能存在有起弧信号，
    导致这个原因是正常起弧焊接时，在需要发送断弧的时没有发成功
    ]]--
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":initWelder->before write")
    return self:innerUpdateHoldRegsValue_Address(0,0x02,function(oldV,newV)
                                                        local v = oldV|(1<<1) --机器人准备好
                                                        v = v&(~(1<<0)) --灭弧
                                                        v = v&(~(1<<10)) --停止送丝
                                                        v = v&(~(1<<11)) --停止退丝
                                                        v = v&(~(1<<8)) --停止气检
                                                        MyWelderDebugLog(welderName..":initWelder->write value="..v)
                                                        return v
                                                     end)
end

function KemppiAXWelderControlModbus:notifyWelderThatRobotHasReady()
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":notifyWelderThatRobotHasReady->before write")
    return self:innerUpdateHoldRegsValue_Address(0,0x02,function(oldV,newV)
                                                        local v = oldV|newV
                                                        MyWelderDebugLog(welderName..":notifyWelderThatRobotHasReady->write value="..v)
                                                        return v
                                                     end)
end

function KemppiAXWelderControlModbus:notifyWelderThatRobotNotReady()
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":notifyWelderThatRobotNotReady->before write")
    return self:innerUpdateHoldRegsValue_Address(0,0xFFFD,function(oldV,newV)
                                                            local v = oldV&newV
                                                            MyWelderDebugLog(welderName..":notifyWelderThatRobotNotReady->write value="..v)
                                                            return v
                                                         end)
end

function KemppiAXWelderControlModbus:isWelderReady()
    local newVal = self:innerGetInRegsValue_Address(0) or {}
    if #newVal<1 then
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":isWelderReady->read fail,return value is nil")
        return false
    end
    return (newVal[1]&0x08)==0x08
end

function KemppiAXWelderControlModbus:setWeldCurrent(newVal)
    return true --协议不支持，所以不执行
end

function KemppiAXWelderControlModbus:setArcStartCurrent(newVal)
    return true --协议不支持，所以不执行
end

function KemppiAXWelderControlModbus:setArcEndCurrent(newVal)
    return true --协议不支持，所以不执行
end

function KemppiAXWelderControlModbus:getWeldCurrent()
    local newVal = self:innerGetInRegsValue_Address(4) or {}
    if #newVal<1 then
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":getWeldCurrent->read fail,return value is nil")
        return nil
    end
    return innerCurrent_Welder2Locale(newVal[1])
end

function KemppiAXWelderControlModbus:setWeldVoltage(newVal)
    return true --协议不支持，所以不执行
end

function KemppiAXWelderControlModbus:setArcStartVoltage(newVal)
    return true --协议不支持，所以不执行
end

function KemppiAXWelderControlModbus:setArcEndVoltage(newVal)
    return true --协议不支持，所以不执行
end

function KemppiAXWelderControlModbus:getWeldVoltage()
    local newVal = self:innerGetInRegsValue_Address(6) or {}
    if #newVal<1 then
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":getWeldVoltage->read fail,return value is nil")
        return nil
    end
    return innerVoltage_Welder2Locale(newVal[1])
end

function KemppiAXWelderControlModbus:getWeldWireFeedSpeed()
    local newVal = self:innerGetInRegsValue_Address(5) or {}
    if #newVal<1 then
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":getWeldWireFeedSpeed->read fail,return value is nil")
        return nil
    end
    return innerWireFeedSpeed_Welder2Locale(newVal[1])
end

function KemppiAXWelderControlModbus:setWeldMode(newVal)
    return true --暂时不支持设置，因为只开发了job模式
end

function KemppiAXWelderControlModbus:setJobId(newVal)
    local welderName = self.welderObject.welderName
    if nil == newVal then
        local params = self.welderObject:getWelderParamObject():getJobModeParam()
        newVal = params.jobId
    end
    if newVal<0 or newVal>65535 then
        MyWelderDebugLog(welderName..Language.trLang("WELDER_JOBNUMBER_ERR")..":jobId="..tostring(newVal))
        return false
    end
    MyWelderDebugLog(welderName..":setJobId->write,jobId="..tostring(newVal))
    return self:innerUpdateHoldRegsValue_Address(4,newVal,nil)
end

function KemppiAXWelderControlModbus:arcStart()
    local newVal = 0x01
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":arcStart->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                          local v = oldV|newV
                                                          MyWelderDebugLog(welderName..":arcStart->write value="..v)
                                                          return v
                                                       end)
end

function KemppiAXWelderControlModbus:isArcStarted()
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

function KemppiAXWelderControlModbus:arcEnd()
    local newVal = 0xFFFE
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":arcEnd->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                            local v = oldV&newV
                                                            MyWelderDebugLog(welderName..":arcEnd->write value="..v)
                                                            return v
                                                         end)
end

function KemppiAXWelderControlModbus:isArcEnded()
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

function KemppiAXWelderControlModbus:hasEndArcByMannual()
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

function KemppiAXWelderControlModbus:clearError()
    local newVal = (1<<5)&0xFFFF
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":clearError->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                            local v = oldV|newV
                                                            MyWelderDebugLog(welderName..":clearError->write value="..v)
                                                            return v
                                                         end)
end

function KemppiAXWelderControlModbus:startWireFeed()
    local newVal = (1<<10)&0xFFFF
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":startWireFeed->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                            local v = oldV|newV
                                                            MyWelderDebugLog(welderName..":startWireFeed->write value="..v)
                                                            return v
                                                         end)
end
function KemppiAXWelderControlModbus:stopWireFeed()
    local newVal = (~(1<<10))&0xFFFF
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":stopWireFeed->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                            local v = oldV&newV
                                                            MyWelderDebugLog(welderName..":stopWireFeed->write value="..v)
                                                            return v
                                                         end)
end

function KemppiAXWelderControlModbus:startWireBack()
    local newVal = (1<<11)&0xFFFF
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":startWireBack->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                            local v = oldV|newV
                                                            MyWelderDebugLog(welderName..":startWireBack->write value="..v)
                                                            return v
                                                         end)
end
function KemppiAXWelderControlModbus:stopWireBack()
    local newVal = (~(1<<11))&0xFFFF
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":stopWireBack->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                            local v = oldV&newV
                                                            MyWelderDebugLog(welderName..":stopWireBack->write value="..v)
                                                            return v
                                                         end)
end

function KemppiAXWelderControlModbus:startGasCheck()
    local newVal = (1<<8)&0xFFFF
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":startGasCheck->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                            local v = oldV|newV
                                                            MyWelderDebugLog(welderName..":startGasCheck->write value="..v)
                                                            return v
                                                         end)
end
function KemppiAXWelderControlModbus:stopGasCheck()
    local newVal = (~(1<<8))&0xFFFF
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":stopGasCheck->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                            local v = oldV&newV
                                                            MyWelderDebugLog(welderName..":stopGasCheck->write value="..v)
                                                            return v
                                                         end)
end

function KemppiAXWelderControlModbus:getWelderRunStateInfo()
    innerWatchDogMonitor(self) --监控watchdog
    
    local info = {connectState = false}
    --一次性读取所有的数据
    local newVal = self:innerGetInRegsValue_Address(0,9) or {}
    if #newVal<9 then return info end

    if (newVal[1]&0x08)==0x08 then info.connectState = true
    else info.connectState = false
    end

    info.weldVoltage = innerVoltage_Welder2Locale(newVal[7])
    info.weldCurrent = innerCurrent_Welder2Locale(newVal[5])
    info.wireFeedSpeed = innerWireFeedSpeed_Welder2Locale(newVal[6])

    if (newVal[1]&0x01)==0x01 then info.weldState = 1
    else info.weldState = 0
    end

    return info
end

function KemppiAXWelderControlModbus:getWelderErrCode()
    local newVal = self:innerGetInRegsValue_Address(8) or {}
    if #newVal<1 then
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":getWelderErrCode->read fail,return value is nil")
        return nil
    end
    newVal = newVal[1]
    return newVal
end

return KemppiAXWelderControlModbus