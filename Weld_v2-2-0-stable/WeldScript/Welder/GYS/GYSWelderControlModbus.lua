--[[焊机DeviceNet接口，继承自`WelderControlModbus`]]--

--【本地私有接口】--
--本地电流值转换为焊机想要的电流值
local function innerCurrent_Locale2Welder(newVal)
    return newVal*10
end
--焊机电流转换为本地想要的电流值
local function innerCurrent_Welder2Locale(newVal)
    newVal = CHelperTools.ToUInt16(newVal)
    newVal = newVal/10
    return newVal
end

--本地电压值转换为焊机想要的电压值
local function innerVoltage_Locale2Welder(newVal)
    return newVal*10
end
--焊机电压转换为本地想要的电压值
local function innerVoltage_Welder2Locale(newVal)
    newVal = CHelperTools.ToInt16(newVal)
    newVal = newVal/10
    return newVal
end

--焊机送丝速度转换为本地想要的速度值
local function innerWireFeedSpeed_Welder2Locale(newVal)
    newVal = CHelperTools.ToInt16(newVal)
    newVal = newVal/100
    return newVal
end

-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
--【业务实现接口】-------------------------------------------------------------------------------------------------
local GYSWelderControlModbus = WelderControlModbus:new()
GYSWelderControlModbus.__index = GYSWelderControlModbus

-------------------------------------------------------------------------------------------------------------------
--【对内不公开接口，只给本身和派生类使用】-----------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------
--【对外公开接口】-------------------------------------------------------------------------------------------------
function GYSWelderControlModbus:new(welderObj)
    local o = WelderControlModbus:new()
    o.welderObject = welderObj
    setmetatable(o,self)
    return o
end

function GYSWelderControlModbus:initWelder()
    --[[
    不仅要发机器人准备好信号，还要发灭弧信号,因为刚开机时可能存在有起弧信号，
    导致这个原因是正常起弧焊接时，在需要发送断弧的时没有发成功
    ]]--
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":initWelder->before write")
    local data = self:innerGetHoldRegsValue_Address(0,7) or {}
    if #data<7 then --失败了那就一个一个设置吧
        local ok1 = self:innerUpdateHoldRegsValue_Address(0,0xFFFE,function(oldV,newV)
                                                                    local v = oldV&newV --灭弧
                                                                    MyWelderDebugLog(welderName..":initWelder->write value="..v)
                                                                    return v
                                                                 end)
        local ok2 = self:innerUpdateHoldRegsValue_Address(2,0xFFFD,function(oldV,newV)
                                                                    local v = oldV&newV --停止气检
                                                                    MyWelderDebugLog(welderName..":initWelder->write value="..v)
                                                                    return v
                                                                 end)
        local ok3 = self:innerUpdateHoldRegsValue_Address(6,0xF9FF,function(oldV,newV)
                                                                    local v = oldV&newV --停止送丝与退丝
                                                                    MyWelderDebugLog(welderName..":initWelder->write value="..v)
                                                                    return v
                                                                 end)
        return (ok1 and ok2 and ok3)
    end
    data[1] = data[1]&0xFFFE --灭弧
    data[3] = data[3]&0xFFFD --停止气检
    data[7] = data[7]&0xF9FF --停止送丝与退丝
    return self:innerSetHoldRegsValue_Address(0,data)
end

function GYSWelderControlModbus:isWelderReady()
    local newVal = self:innerGetInRegsValue_Address(0) or {}
    if #newVal<1 then
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":isWelderReady->read fail,return value is nil")
        return false
    end
    return (newVal[1]&0x02)==0x02
end

function GYSWelderControlModbus:setMmiLockUI(bIsLock)
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":setMmiLockUI->write value="..tostring(bIsLock))
    local newVal
    if bIsLock then newVal=1
    else newVal=3
    end
    return self:innerUpdateHoldRegsValue_Address(4,newVal,function(oldV,newV)
                                                          local v = oldV&0xFF00
                                                          v = v|newVal
                                                          MyWelderDebugLog(welderName..":setMmiLockUI->write value="..v)
                                                          return v
                                                       end)
end

function GYSWelderControlModbus:setWeldCurrent(newVal)
    local welderName = self.welderObject.welderName
    if nil == newVal then
        local params = self.welderObject:getWelderParamObject():getNotJobModeParam()
        if #params.params < 1 or params.selectedId<1 or params.selectedId > #params.params then
            MyWelderDebugLog(welderName..Language.trLang("WELDER_SET_WELD_CURRENT"))
            return false
        end
        newVal = params.params[params.selectedId].weldCurrent
    end
    MyWelderDebugLog(welderName..":setWeldCurrent->write value="..newVal)
    newVal = math.floor(innerCurrent_Locale2Welder(newVal))
    return self:innerUpdateHoldRegsValue_Address(34,newVal,nil)
end

function GYSWelderControlModbus:setArcStartCurrent(newVal)
    local welderName = self.welderObject.welderName
    if nil == newVal then
        local params = self.welderObject:getWelderParamObject():getNotJobModeParam()
        if #params.params < 1 or params.selectedId<1 or params.selectedId > #params.params then
            MyWelderDebugLog(welderName..Language.trLang("WELDER_SET_ARC_CURRENT"))
            return false
        end
        newVal = params.params[params.selectedId].arcStartCurrent
    end
    MyWelderDebugLog(welderName..":setArcStartCurrent->write value="..newVal)
    newVal = math.floor(innerCurrent_Locale2Welder(newVal))
    return self:innerUpdateHoldRegsValue_Address(34,newVal,nil)
end

function GYSWelderControlModbus:setArcEndCurrent(newVal)
    local welderName = self.welderObject.welderName
    if nil == newVal then
        local params = self.welderObject:getWelderParamObject():getNotJobModeParam()
        if #params.params < 1 or params.selectedId<1 or params.selectedId > #params.params then
            MyWelderDebugLog(welderName..Language.trLang("WELDER_SET_END_CURRENT"))
            return false
        end
        newVal = params.params[params.selectedId].arcEndCurrent
    end
    MyWelderDebugLog(welderName..":setArcEndCurrent->write value="..newVal)
    newVal = math.floor(innerCurrent_Locale2Welder(newVal))
    return self:innerUpdateHoldRegsValue_Address(34,newVal,nil)
end

function GYSWelderControlModbus:getWeldCurrent()
    local newVal = self:innerGetInRegsValue_Address(5) or {}
    if #newVal<1 then
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":getWeldCurrent->read fail,return value is nil")
        return nil
    end
    return innerCurrent_Welder2Locale(newVal[1])
end

function GYSWelderControlModbus:setWeldVoltage(newVal)
    local welderName = self.welderObject.welderName
    if nil == newVal then
        local params = self.welderObject:getWelderParamObject():getNotJobModeParam()
        if #params.params < 1 or params.selectedId<1 or params.selectedId > #params.params then
            MyWelderDebugLog(welderName..Language.trLang("WELDER_SET_WELD_VOLTAGE"))
            return false
        end
        newVal = params.params[params.selectedId].weldVoltage
    end
    MyWelderDebugLog(welderName..":setWeldVoltage->write value="..newVal)
    newVal = math.floor(innerVoltage_Locale2Welder(newVal))
    return self:innerUpdateHoldRegsValue_Address(29,newVal,nil)
end

function GYSWelderControlModbus:setArcStartVoltage(newVal)
    local welderName = self.welderObject.welderName
    if nil == newVal then
        local params = self.welderObject:getWelderParamObject():getNotJobModeParam()
        if #params.params < 1 or params.selectedId<1 or params.selectedId > #params.params then
            MyWelderDebugLog(welderName..Language.trLang("WELDER_SET_ARC_VOLTAGE"))
            return false
        end
        newVal = params.params[params.selectedId].arcStartVoltage
    end
    MyWelderDebugLog(welderName..":setArcStartVoltage->write value="..newVal)
    newVal = math.floor(innerVoltage_Locale2Welder(newVal))
    return self:innerUpdateHoldRegsValue_Address(29,newVal,nil)
end

function GYSWelderControlModbus:setArcEndVoltage(newVal)
    local welderName = self.welderObject.welderName
    if nil == newVal then
        local params = self.welderObject:getWelderParamObject():getNotJobModeParam()
        if #params.params < 1 or params.selectedId<1 or params.selectedId > #params.params then
            MyWelderDebugLog(welderName..Language.trLang("WELDER_SET_END_VOLTAGE"))
            return false
        end
        newVal = params.params[params.selectedId].arcEndVoltage
    end
    MyWelderDebugLog(welderName..":setArcEndVoltage->write value="..newVal)
    newVal = math.floor(innerVoltage_Locale2Welder(newVal))
    return self:innerUpdateHoldRegsValue_Address(29,newVal,nil)
end

function GYSWelderControlModbus:getWeldVoltage()
    local newVal = self:innerGetInRegsValue_Address(6) or {}
    if #newVal<1 then
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":getWeldVoltage->read fail,return value is nil")
        return nil
    end
    return innerVoltage_Welder2Locale(newVal[1])
end

function GYSWelderControlModbus:getWeldWireFeedSpeed()
    local newVal = self:innerGetInRegsValue_Address(11) or {}
    if #newVal<1 then
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":getWeldWireFeedSpeed->read fail,return value is nil")
        return nil
    end
    return innerWireFeedSpeed_Welder2Locale(newVal[1])
end

function GYSWelderControlModbus:setWeldMode(newVal)
    return true --暂时不支持设置，因为只开发了job模式
end

function GYSWelderControlModbus:setJobId(newVal)
    local welderName = self.welderObject.welderName
    if nil == newVal then
        local params = self.welderObject:getWelderParamObject():getJobModeParam()
        newVal = params.jobId
    end
    if newVal<0 or newVal>500 then
        MyWelderDebugLog(welderName..Language.trLang("WELDER_JOBNUMBER_ERR")..":jobId="..tostring(newVal))
        return false
    end
    MyWelderDebugLog(welderName..":setJobId->before write,jobId="..tostring(newVal))
    --lua没有signed short int long概念，为了创造2字节数据同时也为了防止被覆盖，所以这样操作变成2字节数据
    return self:innerUpdateHoldRegsValue_Address(9,newVal,function(oldV,newV)
                                                            local v=newV
                                                            MyWelderDebugLog(welderName..":setJobId->write value="..v)
                                                            return v
                                                        end)
end

function GYSWelderControlModbus:arcStart()
    local newVal = 0x01
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":arcStart->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                          local v = oldV|newV
                                                          MyWelderDebugLog(welderName..":arcStart->write value="..v)
                                                          return v
                                                       end)
end

function GYSWelderControlModbus:isArcStarted()
    local welderName = self.welderObject.welderName
    local newVal = self:innerGetInRegsValue_Address(1) or {}
    if #newVal<1 then
        MyWelderDebugLog(welderName..":isArcStarted->read fail,return value is nil")
        return nil
    end
    local state = (newVal[1]&0x04)==0x04
    MyWelderDebugLog(string.format("%s:isArcStarted->read ok,newVal[1]=0x%X, state=%s",welderName,newVal[1], tostring(state)))
    return state
end

function GYSWelderControlModbus:arcEnd()
    local newVal = 0xFFFE
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":arcEnd->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                            local v = oldV&newV
                                                            MyWelderDebugLog(welderName..":arcEnd->write value="..v)
                                                            return v
                                                         end)
end

function GYSWelderControlModbus:isArcEnded()
    local welderName = self.welderObject.welderName
    local newVal = self:innerGetInRegsValue_Address(1) or {}
    if #newVal<1 then
        MyWelderDebugLog(welderName..":isArcEnded->read fail,return value is nil")
        return nil
    end
    local state = (newVal[1]&0x04)==0x00
    MyWelderDebugLog(string.format("%s:isArcEnded->read ok,newVal[1]=0x%X, state=%s",welderName,newVal[1], tostring(state)))
    return state
end

function GYSWelderControlModbus:hasEndArcByMannual()
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

function GYSWelderControlModbus:startWireFeed()
    local newVal = (1<<10)&0xFFFF
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":startWireFeed->before write")
    return self:innerUpdateHoldRegsValue_Address(6,newVal,function(oldV,newV)
                                                            local v = oldV|newV
                                                            MyWelderDebugLog(welderName..":startWireFeed->write value="..v)
                                                            return v
                                                         end)
end
function GYSWelderControlModbus:stopWireFeed()
    local newVal = (~(1<<10))&0xFFFF
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":stopWireFeed->before write")
    return self:innerUpdateHoldRegsValue_Address(6,newVal,function(oldV,newV)
                                                            local v = oldV&newV
                                                            MyWelderDebugLog(welderName..":stopWireFeed->write value="..v)
                                                            return v
                                                         end)
end

function GYSWelderControlModbus:startWireBack()
    local newVal = (1<<9)&0xFFFF
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":startWireBack->before write")
    return self:innerUpdateHoldRegsValue_Address(6,newVal,function(oldV,newV)
                                                            local v = oldV|newV
                                                            MyWelderDebugLog(welderName..":startWireBack->write value="..v)
                                                            return v
                                                         end)
end
function GYSWelderControlModbus:stopWireBack()
    local newVal = (~(1<<9))&0xFFFF
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":stopWireBack->before write")
    return self:innerUpdateHoldRegsValue_Address(6,newVal,function(oldV,newV)
                                                            local v = oldV&newV
                                                            MyWelderDebugLog(welderName..":stopWireBack->write value="..v)
                                                            return v
                                                         end)
end

function GYSWelderControlModbus:isStickRelease()
    local newVal = self:innerGetInRegsValue_Address(1) or {}
    if #newVal<1 then --操作失败认为粘丝未解除
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":isStickRelease->read fail,return value is nil")
        return nil
    end
    return (newVal[1]&0x80)==0x00
end

function GYSWelderControlModbus:startGasCheck()
    local newVal = 0x02
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":startGasCheck->before write")
    return self:innerUpdateHoldRegsValue_Address(2,newVal,function(oldV,newV)
                                                            local v = oldV|newV
                                                            MyWelderDebugLog(welderName..":startGasCheck->write value="..v)
                                                            return v
                                                         end)
end
function GYSWelderControlModbus:stopGasCheck()
    local newVal = 0xFFFD
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":stopGasCheck->before write")
    return self:innerUpdateHoldRegsValue_Address(2,newVal,function(oldV,newV)
                                                            local v = oldV&newV
                                                            MyWelderDebugLog(welderName..":stopGasCheck->write value="..v)
                                                            return v
                                                         end)
end

function GYSWelderControlModbus:getWelderRunStateInfo()
    local info = {connectState = false}
    --一次性读取所有的数据
    local newVal = self:innerGetInRegsValue_Address(0,12) or {}
    if #newVal<12 then return info end
    
    if (newVal[1]&0x02)==0x02 then info.connectState = true
    else info.connectState = false
    end
    
    info.weldVoltage = innerVoltage_Welder2Locale(newVal[7])
    info.weldCurrent = innerCurrent_Welder2Locale(newVal[6])
    info.wireFeedSpeed = innerWireFeedSpeed_Welder2Locale(newVal[12])
    
    if (newVal[2]&0x04)==0x04 then info.weldState = 1
    else info.weldState = 0
    end
    
    if (newVal[2]&0x80)==0x00 then info.wireState = 0
    else info.wireState = 1
    end
    
    return info
end

function GYSWelderControlModbus:getWelderErrCode()
    local newVal = self:innerGetInRegsValue_Address(0) or {}
    if #newVal<1 then
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":getWelderErrCode->read fail,return value is nil")
        return nil
    end
    newVal = (newVal[1]>>8)&0x00FF
    return newVal
end

return GYSWelderControlModbus