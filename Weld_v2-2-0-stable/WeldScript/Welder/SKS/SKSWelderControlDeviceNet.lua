--[[焊机DeviceNet接口，继承自`WelderControlDeviceNet`]]--

--【本地私有接口】--
--本地电流值转换为焊机想要的电流值
local function innerCurrent_Locale2Welder(newVal)
    return newVal
end
--焊机电流转换为本地想要的电流值
local function innerCurrent_Welder2Locale(newVal)
    newVal = CHelperTools.ToInt16(newVal)
    newVal = newVal*2
    return newVal
end

--本地电压值转换为焊机想要的电压值
local function innerVoltage_Locale2Welder(newVal)
    return newVal
end
--焊机电压转换为本地想要的电压值
local function innerVoltage_Welder2Locale(newVal)
    newVal = CHelperTools.ToInt16(newVal)
    newVal = newVal*0.2
    return newVal
end

--焊机送丝速度转换为本地想要的速度值
local function innerWireFeedSpeed_Welder2Locale(newVal)
    newVal = CHelperTools.ToInt16(newVal)
    newVal = newVal*0.1
    return newVal
end

-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
--【业务实现接口】-------------------------------------------------------------------------------------------------
local SKSWelderControlDeviceNet = WelderControlDeviceNet:new()
SKSWelderControlDeviceNet.__index = SKSWelderControlDeviceNet

-------------------------------------------------------------------------------------------------------------------
--【对内不公开接口，只给本身和派生类使用】-----------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------
--【对外公开接口】-------------------------------------------------------------------------------------------------
function SKSWelderControlDeviceNet:new(welderObj)
    local o = WelderControlDeviceNet:new()
    o.welderObject = welderObj
    setmetatable(o,self)
    return o
end

function SKSWelderControlDeviceNet:initWelder()
    --[[
    不仅要发机器人准备好信号，还要发灭弧信号,因为刚开机时可能存在有起弧信号，
    导致这个原因是正常起弧焊接时，在需要发送断弧的时没有发成功
    ]]--
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":initWelder->before write")
    return self:innerUpdateHoldRegsValue_Address(0,0x00,function(oldV,newV)
                                                        local v = oldV&(~(1<<0)) --灭弧
                                                        v = v&(~(1<<2)) --停止送丝
                                                        v = v&(~(1<<3)) --停止退丝
                                                        v = v&(~(1<<1)) --停止气检
                                                        MyWelderDebugLog(welderName..":initWelder->write value="..v)
                                                        return v
                                                     end)
end

function SKSWelderControlDeviceNet:isWelderReady()
    local newVal = self:innerGetInRegsValue_Address(0) or {}
    if #newVal<1 then
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":isWelderReady->read fail,return value is nil")
        return nil
    end
    return (newVal[1]&0x01)==0x01
end

function SKSWelderControlDeviceNet:setWeldCurrent(newVal)
    return true --协议不支持，所以不执行
end

function SKSWelderControlDeviceNet:setArcStartCurrent(newVal)
    return true --协议不支持，所以不执行
end

function SKSWelderControlDeviceNet:setArcEndCurrent(newVal)
    return true --协议不支持，所以不执行
end

function SKSWelderControlDeviceNet:getWeldCurrent()
    local newVal = self:innerGetInRegsValue_Address(3) or {}
    if #newVal<1 then
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":getWeldCurrent->read fail,return value is nil")
        return nil
    end
    return innerCurrent_Welder2Locale(newVal[1])
end

function SKSWelderControlDeviceNet:setWeldVoltage(newVal)
    return true --协议不支持，所以不执行
end

function SKSWelderControlDeviceNet:setArcStartVoltage(newVal)
    return true --协议不支持，所以不执行
end

function SKSWelderControlDeviceNet:setArcEndVoltage(newVal)
    return true --协议不支持，所以不执行
end

function SKSWelderControlDeviceNet:getWeldVoltage()
    local newVal = self:innerGetInRegsValue_Address(2) or {}
    if #newVal<1 then
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":getWeldVoltage->read fail,return value is nil")
        return nil
    end
    return innerVoltage_Welder2Locale(newVal[1])
end

function SKSWelderControlDeviceNet:getWeldWireFeedSpeed()
    local newVal = self:innerGetInRegsValue_Address(4) or {}
    if #newVal<1 then
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":getWeldWireFeedSpeed->read fail,return value is nil")
        return nil
    end
    return innerWireFeedSpeed_Welder2Locale(newVal[1])
end

function SKSWelderControlDeviceNet:setWeldMode(newVal)
    return true --协议不支持，所以不执行
end

function SKSWelderControlDeviceNet:setJobId(newVal)
    local welderName = self.welderObject.welderName
    if nil == newVal then
        local params = self.welderObject:getWelderParamObject():getJobModeParam()
        newVal = params.jobId
    end
    if newVal<0 or newVal>124 then
        MyWelderDebugLog(welderName..Language.trLang("WELDER_JOBNUMBER_ERR")..":jobId="..tostring(newVal))
        return false
    end
    MyWelderDebugLog(welderName..":setJobId->before write,jobId="..tostring(newVal))
    --lua没有signed short int long概念，为了创造2字节数据同时也为了防止被覆盖，所以这样操作变成2字节数据
    newVal = (newVal&0x007F)<<8
    local isOk = self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                            local tmp=oldV&0x80FF
                                                            tmp = tmp|newV
                                                            MyWelderDebugLog(welderName..":setJobId->write value="..tmp)
                                                            return tmp
                                                        end)
    Wait(60) --设置job号后至少要等待50ms，协议上是这么要求的
    return isOk
end

function SKSWelderControlDeviceNet:setProcessNumber(newVal)
    local welderName = self.welderObject.welderName
    if nil == newVal then
        local params = self.welderObject:getWelderParamObject():getJobModeParam()
        newVal = params.processNumber
    end
    if newVal<0 or newVal>7 then
        MyWelderDebugLog(welderName..Language.trLang("WELDER_PROGRAM_NUM_ERR").."processNumber="..tostring(newVal))
        return false
    end
    MyWelderDebugLog(welderName..":setProcessNumber->before write,processNumber="..tostring(newVal))
    --lua没有signed short int long概念，为了创造2字节数据同时也为了防止被覆盖，所以这样操作变成2字节数据
    newVal = newVal&0x07
    return self:innerUpdateHoldRegsValue_Address(1,newVal,function(oldV,newV)
                                                            local tmp=oldV&0xFFF8
                                                            tmp=tmp|newV
                                                            MyWelderDebugLog(welderName..":setProcessNumber->write value="..tmp)
                                                            return tmp
                                                        end)
end

function SKSWelderControlDeviceNet:arcStart()
    local newVal = 0x01
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":arcStart->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                            local v = oldV|newV
                                                            MyWelderDebugLog(welderName..":arcStart->write value="..v)
                                                            return v
                                                         end)
end

function SKSWelderControlDeviceNet:isArcStarted()
    local welderName = self.welderObject.welderName
    local newVal = self:innerGetInRegsValue_Address(0) or {}
    if #newVal<1 then
        MyWelderDebugLog(welderName..":isArcStarted->read fail,return value is nil")
        return nil
    end
    local state = (newVal[1]&0x04)==0x04
    MyWelderDebugLog(string.format("%s:isArcStarted->read ok,newVal[1]=0x%X, state=%s",welderName,newVal[1], tostring(state)))
    return state
end

function SKSWelderControlDeviceNet:arcEnd()
    local newVal = 0xFFFE
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":arcEnd->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                            local v = oldV&newV
                                                            MyWelderDebugLog(welderName..":arcEnd->write value="..v)
                                                            return v
                                                         end)
end

function SKSWelderControlDeviceNet:isArcEnded()
    local welderName = self.welderObject.welderName
    local newVal = self:innerGetInRegsValue_Address(0) or {}
    if #newVal<1 then
        MyWelderDebugLog(welderName..":isArcEnded->read fail,return value is nil")
        return nil
    end
    local state = (newVal[1]&0x04)==0x00
    MyWelderDebugLog(string.format("%s:isArcEnded->read ok,newVal[1]=0x%X, state=%s",welderName,newVal[1], tostring(state)))
    return state
end

function SKSWelderControlDeviceNet:hasEndArcByMannual()
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

function SKSWelderControlDeviceNet:clearError()
    return true --协议不支持，所以不执行
end

function SKSWelderControlDeviceNet:startWireFeed()
    local newVal = 0x04
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":startWireFeed->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                            local v = oldV|newV
                                                            MyWelderDebugLog(welderName..":startWireFeed->write value="..v)
                                                            return v
                                                         end)
end
function SKSWelderControlDeviceNet:stopWireFeed()
    local newVal = 0xFFFB
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":stopWireFeed->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                            local v = oldV&newV
                                                            MyWelderDebugLog(welderName..":stopWireFeed->write value="..v)
                                                            return v
                                                         end)
end

function SKSWelderControlDeviceNet:startWireBack()
    local newVal = 0x08
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":startWireBack->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                            local v = oldV|newV
                                                            MyWelderDebugLog(welderName..":startWireBack->write value="..v)
                                                            return v
                                                         end)
end
function SKSWelderControlDeviceNet:stopWireBack()
    local newVal = 0xFFF7
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":stopWireBack->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                            local v = oldV&newV
                                                            MyWelderDebugLog(welderName..":stopWireBack->write value="..v)
                                                            return v
                                                         end)
end

function SKSWelderControlDeviceNet:isStickRelease()
    local newVal = self:innerGetInRegsValue_Address(0) or {}
    if #newVal<1 then --操作失败认为粘丝未解除
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":isStickRelease->read fail,return value is nil")
        return nil
    end
    return (newVal[1]&0x0020)==0x0000
end

function SKSWelderControlDeviceNet:startGasCheck()
    local newVal = 0x02
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":startGasCheck->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                            local v = oldV|newV
                                                            MyWelderDebugLog(welderName..":startGasCheck->write value="..v)
                                                            return v
                                                         end)
end
function SKSWelderControlDeviceNet:stopGasCheck()
    local newVal = 0xFFFD
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":stopGasCheck->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                            local v = oldV&newV
                                                            MyWelderDebugLog(welderName..":stopGasCheck->write value="..v)
                                                            return v
                                                         end)
end

function SKSWelderControlDeviceNet:getWelderRunStateInfo()
    local info = {connectState = false}
    --一次性读取所有的数据
    local newVal = self:innerGetInRegsValue_Address(0,5) or {}
    if #newVal<5 then return info end

    --bit0和bit7只要有一个是on就表示连接成功
    if (newVal[1]&0x01)==0x01 then info.connectState = true
    else info.connectState = false
    end

    info.weldVoltage = innerVoltage_Welder2Locale(newVal[3])
    info.weldCurrent = innerCurrent_Welder2Locale(newVal[4])
    info.wireFeedSpeed = innerWireFeedSpeed_Welder2Locale(newVal[5])

    if (newVal[1]&0x04)==0x04 then info.weldState = 1
    else info.weldState = 0
    end

    if (newVal[1]&0x0020)==0x0000 then info.wireState = 0
    else info.wireState = 1
    end
    return info
end

function SKSWelderControlDeviceNet:getWelderErrCode()
    local newVal = self:innerGetInRegsValue_Address(0) or {}
    if #newVal<1 then
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":getWelderErrCode->read fail,return value is nil")
        return nil
    end
    newVal = (newVal[1]>>8)&0x7F
    return newVal
end

return SKSWelderControlDeviceNet