--[[焊机Modbus接口，继承自`WelderControlModbus`]]--

--【本地私有接口】--
--本地电流值转换为焊机想要的电流值
local function innerCurrent_Locale2Welder(newVal)
    if newVal<0 then newVal=0 end
    if newVal>25 then newVal=25 end
    return newVal/25*32767
end
--焊机电流转换为本地想要的电流值
local function innerCurrent_Welder2Locale(newVal)
    newVal = CHelperTools.ToUInt16(newVal)
    newVal = newVal*1000/32767
    return newVal
end

--本地电压值转换为焊机想要的电压值
local function innerVoltage_Locale2Welder(newVal)
    if newVal<-10 then newVal=-10 end
    if newVal>10 then newVal=10 end
    return (newVal+10)/20*32767
end
--焊机电压转换为本地想要的电压值
local function innerVoltage_Welder2Locale(newVal)
    newVal = CHelperTools.ToInt16(newVal)
    newVal = newVal*100/32767
    return newVal
end

--焊机送丝速度转换为本地想要的速度值
local function innerWireFeedSpeed_Welder2Locale(newVal)
    newVal = CHelperTools.ToInt16(newVal)
    newVal = newVal*40/32767
    return newVal
end

-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
--【业务实现接口】-------------------------------------------------------------------------------------------------
local EWMWelderControlModbus = WelderControlModbus:new()
EWMWelderControlModbus.__index = EWMWelderControlModbus

-------------------------------------------------------------------------------------------------------------------
--【对内不公开接口，只给本身和派生类使用】-----------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------
--【对外公开接口】-------------------------------------------------------------------------------------------------
function EWMWelderControlModbus:new(welderObj)
    local o = WelderControlModbus:new()
    o.welderObject = welderObj
    setmetatable(o,self)
    return o
end

function EWMWelderControlModbus:initWelder()
    --[[
    不仅要发机器人准备好信号，还要发灭弧信号,因为刚开机时可能存在有起弧信号，
    导致这个原因是正常起弧焊接时，在需要发送断弧的时没有发成功
    ]]--
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":initWelder->before write")
    return self:innerUpdateHoldRegsValue_Address(599,0x2000,function(oldV,newV) 
                                                        local v = oldV|(1<<13) --机器人准备好
                                                        v = v&(~(1<<12)) --灭弧
                                                        v = v&(~(1<<0)) --停止送丝
                                                        v = v&(~(1<<2)) --停止退丝
                                                        v = v&(~(1<<14)) --停止气检
                                                        MyWelderDebugLog(welderName..":initWelder->write value="..v)
                                                        return v
                                                     end)
end

function EWMWelderControlModbus:notifyWelderThatRobotHasReady()
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":notifyWelderThatRobotHasReady->before write")
    return self:innerUpdateHoldRegsValue_Address(599,0x2000,function(oldV,newV)
                                                            local v = oldV|newV
                                                            MyWelderDebugLog(welderName..":notifyWelderThatRobotHasReady->write value="..v)
                                                            return v
                                                         end)
end

function EWMWelderControlModbus:notifyWelderThatRobotNotReady()
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":notifyWelderThatRobotNotReady->before write")
    return self:innerUpdateHoldRegsValue_Address(599,0xDFFF,function(oldV,newV)
                                                            local v = oldV&newV
                                                            MyWelderDebugLog(welderName..":notifyWelderThatRobotNotReady->write value="..v)
                                                            return v
                                                         end)
end

function EWMWelderControlModbus:isWelderReady()
    local newVal = self:innerGetInRegsValue_Address(599) or {}
    if #newVal<1 then
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":isWelderReady->read fail,return value is nil")
        return nil
    end
    return (newVal[1]&0x0200)==0x0200
end

function EWMWelderControlModbus:setWeldCurrent(newVal)
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
    return self:innerUpdateHoldRegsValue_Address(602,newVal,nil)
end

function EWMWelderControlModbus:setArcStartCurrent(newVal)
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
    return self:innerUpdateHoldRegsValue_Address(602,newVal,nil)
end

function EWMWelderControlModbus:setArcEndCurrent(newVal)
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
    return self:innerUpdateHoldRegsValue_Address(602,newVal,nil)
end

function EWMWelderControlModbus:getWeldCurrent()
    local newVal = self:innerGetInRegsValue_Address(603) or {}
    if #newVal<1 then
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":getWeldCurrent->read fail,return value is nil")
        return nil
    end
    return innerCurrent_Welder2Locale(newVal[1])
end

function EWMWelderControlModbus:setWeldVoltage(newVal)
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
    return self:innerUpdateHoldRegsValue_Address(603,newVal,nil)
end

function EWMWelderControlModbus:setArcStartVoltage(newVal)
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
    return self:innerUpdateHoldRegsValue_Address(603,newVal,nil)
end

function EWMWelderControlModbus:setArcEndVoltage(newVal)
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
    return self:innerUpdateHoldRegsValue_Address(603,newVal,nil)
end

function EWMWelderControlModbus:getWeldVoltage()
    local newVal = self:innerGetInRegsValue_Address(602) or {}
    if #newVal<1 then
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":getWeldVoltage->read fail,return value is nil")
        return nil
    end
    return innerVoltage_Welder2Locale(newVal[1])
end

function EWMWelderControlModbus:getWeldWireFeedSpeed()
    local newVal = self:innerGetInRegsValue_Address(604) or {}
    if #newVal<1 then
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":getWeldWireFeedSpeed->read fail,return value is nil")
        return nil
    end
    return innerWireFeedSpeed_Welder2Locale(newVal[1])
end

function EWMWelderControlModbus:setWeldMode(newVal)
    local welderName = self.welderObject.welderName
    local params = newVal
    if nil == params then
        params = self.welderObject:getWelderParamObject():getWeldMode()
    end
    if not ConstEnumWelderWeldMode[params] then
        MyWelderDebugLog(welderName..Language.trLang("WELDER_FUNC_MODE_NO_RECOGNIZE")..tostring(params))
        return false
    end
    local mapper = {
        twoStepDCWeld = 0x00, --0b000 两步常规直流焊（操作模式：两步，焊接方法：常规直流焊）
        twoStepPulseWeld = 0x04, --0b100 两步脉冲焊（操作模式：两步，焊接方法：脉冲焊）
        specialTwoStepDCWeld = 0x03, --0b011 特殊两步常规直流焊（操作模式：特殊两步，焊接方法：常规直流焊）
        specialTwoStepPulseWeld = 0x07 --0b111 特殊两步脉冲焊（操作模式：特殊两步，焊接方法：脉冲焊）
    }
    if mapper[params] then
        newVal = mapper[params]&0x0007 --取低三位
        newVal = newVal<<8
        
        MyWelderDebugLog(welderName..":setWeldMode->before write,mode="..tostring(params))
        return self:innerUpdateHoldRegsValue_Address(599,newVal,function(oldV,newV)
                                                                local tmp=oldV&0xF8FF
                                                                tmp=tmp|newV
                                                                MyWelderDebugLog(welderName..":setWeldMode->write value="..tmp)
                                                                return tmp
                                                             end)
    else
        MyWelderDebugLog(welderName..Language.trLang("WELDER_FUNC_MODE_NO_SUPPORT")..tostring(params))
        return false
    end
end

function EWMWelderControlModbus:setJobId(newVal)
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
    return self:innerUpdateHoldRegsValue_Address(600,newVal,function(oldV,newV)
                                                            local tmp=oldV&0xFF00
                                                            tmp=tmp|newV
                                                            MyWelderDebugLog(welderName..":setJobId->write value="..tmp)
                                                            return tmp
                                                         end)
end

function EWMWelderControlModbus:setProcessNumber(newVal)
    local welderName = self.welderObject.welderName
    if nil == newVal then
        local params = self.welderObject:getWelderParamObject():getJobModeParam()
        newVal = params.processNumber
    end
    if newVal<1 or newVal>15 then
        MyWelderDebugLog(welderName..Language.trLang("WELDER_PROGRAM_NUM_ERR").."processNumber="..tostring(newVal))
        return false
    end
    MyWelderDebugLog(welderName..":setProcessNumber->before write,processNumber="..tostring(newVal))
    --lua没有signed short int long概念，为了创造2字节数据同时也为了防止被覆盖，所以这样操作变成2字节数据
    newVal = (newVal&0x000F)<<8
    return self:innerUpdateHoldRegsValue_Address(600,newVal,function(oldV,newV)
                                                            local tmp=oldV&0xF0FF
                                                            tmp=tmp|newV
                                                            MyWelderDebugLog(welderName..":setProcessNumber->write value="..tmp)
                                                            return tmp
                                                         end)
end

function EWMWelderControlModbus:arcStart()
    local newVal = 0x1000
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":arcStart->before write")
    return self:innerUpdateHoldRegsValue_Address(599,newVal,function(oldV,newV)
                                                            local v = oldV|newV
                                                            MyWelderDebugLog(welderName..":arcStart->write value="..v)
                                                            return v
                                                         end)
end

function EWMWelderControlModbus:isArcStarted()
    local welderName = self.welderObject.welderName
    local newVal = self:innerGetInRegsValue_Address(599) or {}
    if #newVal<1 then
        MyWelderDebugLog(welderName..":isArcStarted->read fail,return value is nil")
        return nil
    end
    local state = (newVal[1]&0x0100)==0x0100
    MyWelderDebugLog(string.format("%s:isArcStarted->read ok,newVal[1]=0x%X, state=%s",welderName,newVal[1], tostring(state)))
    return state
end

function EWMWelderControlModbus:arcEnd()
    local newVal = 0xEFFF
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":arcEnd->before write")
    return self:innerUpdateHoldRegsValue_Address(599,newVal,function(oldV,newV)
                                                            local v = oldV&newV
                                                            MyWelderDebugLog(welderName..":arcEnd->write value="..v)
                                                            return v
                                                         end)
end

function EWMWelderControlModbus:isArcEnded()
    local welderName = self.welderObject.welderName
    local newVal = self:innerGetInRegsValue_Address(599) or {}
    if #newVal<1 then
        MyWelderDebugLog(welderName..":isArcEnded->read fail,return value is nil")
        return nil
    end
    local state = (newVal[1]&0x0100)==0x0000
    MyWelderDebugLog(string.format("%s:isArcEnded->read ok,newVal[1]=0x%X, state=%s",welderName,newVal[1], tostring(state)))
    return state
end

function EWMWelderControlModbus:hasEndArcByMannual()
    local welderName = self.welderObject.welderName
    local newVal = self:innerGetHoldRegsValue_Address(599) or {}
    if #newVal<1 then
        MyWelderDebugLog(welderName..":hasEndArcByMannual->read fail,return value is nil")
        return nil
    end
    local state = (newVal[1]&0x1000)==0x00
    MyWelderDebugLog(string.format("%s:hasEndArcByMannual->read ok,newVal[1]=0x%X, state=%s",welderName,newVal[1], tostring(state)))
    return state
end

function EWMWelderControlModbus:clearError()
    local newVal = 0x0010
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":clearError->before write")
    return self:innerUpdateHoldRegsValue_Address(599,newVal,function(oldV,newV)
                                                            local v = oldV|newV
                                                            MyWelderDebugLog(welderName..":clearError->write value="..v)
                                                            return v
                                                         end)
end

function EWMWelderControlModbus:startWireFeed()
    local newVal = 0x01
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":startWireFeed->before write")
    return self:innerUpdateHoldRegsValue_Address(599,newVal,function(oldV,newV)
                                                            local v = oldV|newV
                                                            MyWelderDebugLog(welderName..":startWireFeed->write value="..v)
                                                            return v
                                                         end)
end
function EWMWelderControlModbus:stopWireFeed()
    local newVal = 0xFFFE
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":stopWireFeed->before write")
    return self:innerUpdateHoldRegsValue_Address(599,newVal,function(oldV,newV)
                                                            local v = oldV&newV
                                                            MyWelderDebugLog(welderName..":stopWireFeed->write value="..v)
                                                            return v
                                                         end)
end

function EWMWelderControlModbus:startWireBack()
    local newVal = 0x04
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":startWireBack->before write")
    return self:innerUpdateHoldRegsValue_Address(599,newVal,function(oldV,newV)
                                                            local v = oldV|newV
                                                            MyWelderDebugLog(welderName..":startWireBack->write value="..v)
                                                            return v
                                                         end)
end
function EWMWelderControlModbus:stopWireBack()
    local newVal = 0xFFFB
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":stopWireBack->before write")
    return self:innerUpdateHoldRegsValue_Address(599,newVal,function(oldV,newV)
                                                            local v = oldV&newV
                                                            MyWelderDebugLog(welderName..":stopWireBack->write value="..v)
                                                            return v
                                                         end)
end

function EWMWelderControlModbus:isStickRelease()
    local newVal = self:innerGetInRegsValue_Address(599) or {}
    if #newVal<1 then --操作失败认为粘丝未解除
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":isStickRelease->read fail,return value is nil")
        return nil
    end
    return (newVal[1]&0x0400)==0x0000
end

function EWMWelderControlModbus:startGasCheck()
    local newVal = 0x4000
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":startGasCheck->before write")
    return self:innerUpdateHoldRegsValue_Address(599,newVal,function(oldV,newV)
                                                            local v = oldV|newV
                                                            MyWelderDebugLog(welderName..":startGasCheck->write value="..v)
                                                            return v
                                                         end)
end
function EWMWelderControlModbus:stopGasCheck()
    local newVal = 0xBFFF
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":stopGasCheck->before write")
    return self:innerUpdateHoldRegsValue_Address(599,newVal,function(oldV,newV)
                                                            local v = oldV&newV
                                                            MyWelderDebugLog(welderName..":stopGasCheck->write value="..v)
                                                            return v
                                                         end)
end

function EWMWelderControlModbus:getWelderRunStateInfo()
    local info = {connectState = false}
    --一次性读取所有的数据
    local newVal = self:innerGetInRegsValue_Address(599,6) or {}
    if #newVal<6 then return info end
    
    if (newVal[1]&0x0200)==0x0200 then info.connectState = true
    else info.connectState = false
    end
    
    info.weldVoltage = innerVoltage_Welder2Locale(newVal[4])
    info.weldCurrent = innerCurrent_Welder2Locale(newVal[5])
    info.wireFeedSpeed = innerWireFeedSpeed_Welder2Locale(newVal[6])
    
    if (newVal[1]&0x0100)==0x0100 then info.weldState = 1
    else info.weldState = 0
    end
    
    if (newVal[1]&0x0400)==0x0000 then info.wireState = 0
    else info.wireState = 1
    end
    return info
end

function EWMWelderControlModbus:getWelderErrCode()
    local newVal = self:innerGetInRegsValue_Address(599) or {}
    if #newVal<1 then
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":getWelderErrCode->read fail,return value is nil")
        return nil
    end
    newVal = newVal[1]&0x00FF
    return newVal
end

return EWMWelderControlModbus