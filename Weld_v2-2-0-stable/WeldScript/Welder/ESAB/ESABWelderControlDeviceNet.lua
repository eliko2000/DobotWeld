--[[焊机DeviceNet接口，继承自`WelderControlDeviceNet`]]--

--【本地私有接口】--
--本地电流值转换为焊机想要的电流值
local function innerCurrent_Locale2Welder(newVal)
    return newVal*100
end
--焊机电流转换为本地想要的电流值
local function innerCurrent_Welder2Locale(newVal)
    newVal = CHelperTools.ToUInt16(newVal)
    return newVal
end

--本地电压值转换为焊机想要的电压值
local function innerVoltage_Locale2Welder(newVal)
    return newVal*100
end
--焊机电压转换为本地想要的电压值
local function innerVoltage_Welder2Locale(newVal)
    newVal = CHelperTools.ToInt16(newVal)
    return newVal*0.01
end

--焊机送丝速度转换为本地想要的速度值
local function innerWireFeedSpeed_Welder2Locale(newVal)
    newVal = CHelperTools.ToInt16(newVal)
    return newVal*0.01
end

-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
--【业务实现接口】-------------------------------------------------------------------------------------------------
local ESABWelderControlDeviceNet = WelderControlDeviceNet:new()
ESABWelderControlDeviceNet.__index = ESABWelderControlDeviceNet

-------------------------------------------------------------------------------------------------------------------
--【对内不公开接口，只给本身和派生类使用】-----------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------
--【对外公开接口】-------------------------------------------------------------------------------------------------
function ESABWelderControlDeviceNet:new(welderObj)
    local o = WelderControlDeviceNet:new()
    o.welderObject = welderObj
    setmetatable(o,self)
    return o
end

function ESABWelderControlDeviceNet:initWelder()
    --[[
    不仅要发机器人准备好信号，还要发灭弧信号,因为刚开机时可能存在有起弧信号，
    导致这个原因是正常起弧焊接时，在需要发送断弧的时没有发成功
    ]]--
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":initWelder->before write")
    return self:innerUpdateHoldRegsValue_Address(0,0x00,function(oldV,newV)
                                                        local v = oldV|(1<<7) --机器人准备好
                                                        v = v&(~(1<<0)) --灭弧
                                                        v = v&(~(1<<1)) --Quick Stop
                                                        v = v&(~(1<<2)) --Emergency Stop
                                                        v = v&(~(1<<3)) --停止送丝
                                                        v = v&(~(1<<4)) --停止气检
                                                        v = v&(~(1<<5)) --气枪清理
                                                        v = v&(~(1<<6)) --停止退丝
                                                        v = v&(~(1<<12)) --接触寻位使能关闭
                                                        MyWelderDebugLog(welderName..":initWelder->write value="..v)
                                                        return v
                                                     end)
end

function ESABWelderControlDeviceNet:isWelderReady()
    local newVal = self:innerGetInRegsValue_Address(0) or {}
    if #newVal<1 then
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":isWelderReady->read fail,return value is nil")
        return nil
    end
    local readyVal = (newVal[1]&0x08)==0x08
    local faultCode = (newVal[1]&0xFF00)==0x00
    return readyVal and faultCode
end

function ESABWelderControlDeviceNet:setWeldCurrent(newVal)
    local welderName = self.welderObject.welderName
    if newVal == nil then
        local params = self.welderObject:getWelderParamObject():getNotJobModeParam()
        if #params.params < 1 or params.selectedId<1 or params.selectedId > #params.params then
            MyWelderDebugLog(welderName..Language.trLang("WELDER_SET_WELD_CURRENT"))
            return false
        end
        newVal = params.params[params.selectedId].weldCurrent
    end
    MyWelderDebugLog(welderName..":setWeldCurrent->write value="..newVal)
    newVal = math.floor(innerCurrent_Locale2Welder(newVal))
    return self:innerUpdateHoldRegsValue_Address(5,newVal,nil)
end

function ESABWelderControlDeviceNet:setArcStartCurrent(newVal)
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
    return self:innerUpdateHoldRegsValue_Address(5,newVal,nil)
end

function ESABWelderControlDeviceNet:setArcEndCurrent(newVal)
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
    return self:innerUpdateHoldRegsValue_Address(5,newVal,nil)
end

function ESABWelderControlDeviceNet:getWeldCurrent()
    local newVal = self:innerGetInRegsValue_Address(2,2) or {}
    if #newVal<2 then
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":getWeldCurrent->read fail,return value is nil")
        return nil
    end
    local vL = (newVal[1]>>8)&0x00FF
    local vH = newVal[2]&0x00FF
    newVal[1] = ((vH<<8)&0xFF00)|vL
    return innerCurrent_Welder2Locale(newVal[1])
end

function ESABWelderControlDeviceNet:setWeldVoltage(newVal)
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
    return self:innerUpdateHoldRegsValue_Address(4,newVal,nil)
end

function ESABWelderControlDeviceNet:setArcStartVoltage(newVal)
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
    return self:innerUpdateHoldRegsValue_Address(4,newVal,nil)
end

function ESABWelderControlDeviceNet:setArcEndVoltage(newVal)
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
    return self:innerUpdateHoldRegsValue_Address(4,newVal,nil)
end

function ESABWelderControlDeviceNet:getWeldVoltage()
    local newVal = self:innerGetInRegsValue_Address(1,2) or {}
    if #newVal<2 then
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":getWeldVoltage->read fail,return value is nil")
        return nil
    end
    local vL = (newVal[1]>>8)&0x00FF
    local vH = newVal[2]&0x00FF
    newVal[1] = ((vH<<8)&0xFF00)|vL
    return innerVoltage_Welder2Locale(newVal[1])
end

function ESABWelderControlDeviceNet:setWeldMode(newVal)
    return true --协议不支持，所以不执行
end

function ESABWelderControlDeviceNet:setJobId(newVal)
    local welderName = self.welderObject.welderName
    if nil == newVal then
        local params = self.welderObject:getWelderParamObject():getJobModeParam()
        newVal = params.jobId
    end
    if newVal<0 or newVal>255 then
        MyWelderDebugLog(welderName..Language.trLang("WELDER_JOBNUMBER_ERR")..":jobId="..tostring(newVal))
        return false
    end
    MyWelderDebugLog(welderName..":setJobId->before write,jobId="..tostring(newVal))
    --lua没有signed short int long概念，为了创造2字节数据同时也为了防止被覆盖，所以这样操作变成2字节数据
    newVal = newVal&0x00FF
    local isOk = self:innerUpdateHoldRegsValue_Address(1,newVal,function(oldV,newV)
                                                            local tmp=oldV&0xFF00
                                                            tmp = tmp|newV
                                                            MyWelderDebugLog(welderName..":setJobId->write value="..tmp)
                                                            return tmp
                                                        end)
    return isOk
end

function ESABWelderControlDeviceNet:arcStart()
    local newVal = 0x01
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":arcStart->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                            local v = oldV|newV
                                                            MyWelderDebugLog(welderName..":arcStart->write value="..v)
                                                            return v
                                                         end)
end

function ESABWelderControlDeviceNet:isArcStarted()
    local welderName = self.welderObject.welderName
    local newVal = self:innerGetInRegsValue_Address(0) or {}
    if #newVal<1 then
        MyWelderDebugLog(welderName..":isArcStarted->read fail,return value is nil")
        return nil
    end
    local state = (newVal[1]&0x02)==0x02
    MyWelderDebugLog(string.format("%s:isArcStarted->read ok,newVal[1]=0x%X, state=%s",welderName,newVal[1], tostring(state)))
    return state
end

function ESABWelderControlDeviceNet:arcEnd()
    local newVal = 0xFFFE
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":arcEnd->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                            local v = oldV&newV
                                                            MyWelderDebugLog(welderName..":arcEnd->write value="..v)
                                                            return v
                                                         end)
end

function ESABWelderControlDeviceNet:isArcEnded()
    local welderName = self.welderObject.welderName
    local newVal = self:innerGetInRegsValue_Address(0) or {}
    if #newVal<1 then
        MyWelderDebugLog(welderName..":isArcEnded->read fail,return value is nil")
        return nil
    end
    local state = (newVal[1]&0x02)==0x00
    MyWelderDebugLog(string.format("%s:isArcEnded->read ok,newVal[1]=0x%X, state=%s",welderName,newVal[1], tostring(state)))
    return state
end

function ESABWelderControlDeviceNet:hasEndArcByMannual()
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

function ESABWelderControlDeviceNet:startWireFeed()
    local newVal = 0x08
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":startWireFeed->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                            local v = oldV|newV
                                                            MyWelderDebugLog(welderName..":startWireFeed->write value="..v)
                                                            return v
                                                         end)
end
function ESABWelderControlDeviceNet:stopWireFeed()
    local newVal = 0xFFF7
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":stopWireFeed->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                            local v = oldV&newV
                                                            MyWelderDebugLog(welderName..":stopWireFeed->write value="..v)
                                                            return v
                                                         end)
end

function ESABWelderControlDeviceNet:startWireBack()
    local newVal = 0x0040
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":startWireBack->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                            local v = oldV|newV
                                                            MyWelderDebugLog(welderName..":startWireBack->write value="..v)
                                                            return v
                                                         end)
end
function ESABWelderControlDeviceNet:stopWireBack()
    local newVal = 0xFFBF
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":stopWireBack->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                            local v = oldV&newV
                                                            MyWelderDebugLog(welderName..":stopWireBack->write value="..v)
                                                            return v
                                                         end)
end

function ESABWelderControlDeviceNet:isWireHasSignal()
    local newVal = self:innerGetInRegsValue_Address(1) or {}
    if #newVal<1 then --操作失败认为无信号
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":isWireHasSignal->read fail,return value is nil")
        return nil
    end
    return (newVal[1]&0x0080)==0x0080
end

function ESABWelderControlDeviceNet:startGasCheck()
    local newVal = 0x0010
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":startGasCheck->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                            local v = oldV|newV
                                                            MyWelderDebugLog(welderName..":startGasCheck->write value="..v)
                                                            return v
                                                         end)
end
function ESABWelderControlDeviceNet:stopGasCheck()
    local newVal = 0xFFEF
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":stopGasCheck->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                            local v = oldV&newV
                                                            MyWelderDebugLog(welderName..":stopGasCheck->write value="..v)
                                                            return v
                                                         end)
end

function ESABWelderControlDeviceNet:isGasHasSignal()
    local newVal = self:innerGetInRegsValue_Address(1) or {}
    if #newVal<1 then --默认操作失败为无信号
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":isGasHasSignal->read fail,return value is nil")
        return nil
    end
    return (newVal[1]&0x0010)==0x0010
end

function ESABWelderControlDeviceNet:getWelderRunStateInfo()
    local info = {connectState = false}
    --一次性读取所有的数据
    local newVal = self:innerGetInRegsValue_Address(0,5) or {}
    if #newVal<5 then return info end

    if ((newVal[1]&0x08)==0x08) and ((newVal[1]&0xFF00)==0x00) then
        info.connectState = true
    else info.connectState = false
    end
    
    local vL = (newVal[3]>>8)&0x00FF
    local vH = newVal[4]&0x00FF
    local tmpValue = ((vH<<8)&0xFF00)|vL
    info.weldCurrent = innerCurrent_Welder2Locale(tmpValue)
    
    vL = (newVal[2]>>8)&0x00FF
    vH = newVal[3]&0x00FF
    tmpValue = ((vH<<8)&0xFF00)|vL
    info.weldVoltage = innerVoltage_Welder2Locale(tmpValue)

    if (newVal[1]&0x02)==0x02 then info.weldState = 1
    else info.weldState = 0
    end

    return info
end

function ESABWelderControlDeviceNet:getWelderErrCode()
    local newVal = self:innerGetInRegsValue_Address(0) or {}
    if #newVal<1 then
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":getWelderErrCode->read fail,return value is nil")
        return nil
    end
    newVal = (newVal[1]>>8)&0x00FF
    return newVal
end

return ESABWelderControlDeviceNet