--[[焊机Modbus接口，继承自`WelderControlModbus`]]--

--【本地私有接口】--
--本地电流值转换为焊机想要的电流值
local function innerCurrent_Locale2Welder(newVal)
    if newVal<0 then newVal=0 end
    if newVal>25 then newVal=25 end
    return newVal*100
end
--焊机电流转换为本地想要的电流值
local function innerCurrent_Welder2Locale(newVal)
    newVal = CHelperTools.ToUInt16(newVal)
    newVal = newVal/10
    return newVal
end

--本地电压值转换为焊机想要的电压值
local function innerVoltage_Locale2Welder(newVal)
    if newVal<-10 then newVal=-10 end
    if newVal>10 then newVal=10 end
    return (newVal+10)*10
end
--焊机电压转换为本地想要的电压值
local function innerVoltage_Welder2Locale(newVal)
    newVal = CHelperTools.ToInt16(newVal)
    newVal = newVal/100
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
local FroniusWelderControlModbus = WelderControlModbus:new()
FroniusWelderControlModbus.__index = FroniusWelderControlModbus

--[[
福尼斯这款焊机很特殊，在modbus协议中不同硬件，输入寄存器的起始地址会不一样，目前知道的有2种，分别是：
起始地址为 0和2048
]]--
local function innerConvertAddress(addr)
    return addr+2048
end
-------------------------------------------------------------------------------------------------------------------
--【对内不公开接口，只给本身和派生类使用】-----------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------
--【对外公开接口】-------------------------------------------------------------------------------------------------
function FroniusWelderControlModbus:new(welderObj)
    local o = WelderControlModbus:new()
    o.welderObject = welderObj
    setmetatable(o,self)
    return o
end

function FroniusWelderControlModbus:initWelder()
    --[[
    不仅要发机器人准备好信号，还要发灭弧信号,因为刚开机时可能存在有起弧信号，
    导致这个原因是正常起弧焊接时，在需要发送断弧的时没有发成功
    ]]--
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":initWelder->before write")
    return self:innerUpdateHoldRegsValue_Address(0,0x02,function(oldV,newV) 
                                                        local v = oldV|(1<<1) --机器人准备好
                                                        v = v&(~(1<<0)) --灭弧
                                                        v = v&(~(1<<9)) --停止送丝
                                                        v = v&(~(1<<10)) --停止退丝
                                                        v = v&(~(1<<8)) --停止气检
                                                        MyWelderDebugLog(welderName..":initWelder->write value="..v)
                                                        return v
                                                     end)
end

function FroniusWelderControlModbus:notifyWelderThatRobotHasReady()
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":notifyWelderThatRobotHasReady->before write")
    return self:innerUpdateHoldRegsValue_Address(0,0x02,function(oldV,newV)
                                                        local v = oldV|newV
                                                        MyWelderDebugLog(welderName..":notifyWelderThatRobotHasReady->write value="..v)
                                                        return v
                                                     end)
end

function FroniusWelderControlModbus:notifyWelderThatRobotNotReady()
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":notifyWelderThatRobotNotReady->before write")
    return self:innerUpdateHoldRegsValue_Address(0,0xFFFD,function(oldV,newV)
                                                        local v = oldV&newV
                                                        MyWelderDebugLog(welderName..":notifyWelderThatRobotNotReady->write value="..v)
                                                        return v
                                                     end)
end

function FroniusWelderControlModbus:isWelderReady()
    local newVal = self:innerGetInRegsValue_Address(innerConvertAddress(0)) or {}
    if #newVal<1 then
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":isWelderReady->read fail,return value is nil")
        return nil
    end
    return (newVal[1]&0x02)==0x02
end

function FroniusWelderControlModbus:setWeldCurrent(newVal)
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

function FroniusWelderControlModbus:setArcStartCurrent(newVal)
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

function FroniusWelderControlModbus:setArcEndCurrent(newVal)
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

function FroniusWelderControlModbus:getWeldCurrent()
    local newVal = self:innerGetInRegsValue_Address(innerConvertAddress(5)) or {}
    if #newVal<1 then
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":getWeldCurrent->read fail,return value is nil")
        return nil
    end
    return innerCurrent_Welder2Locale(newVal[1])
end

function FroniusWelderControlModbus:setWeldVoltage(newVal)
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
    return self:innerUpdateHoldRegsValue_Address(6,newVal,nil)
end

function FroniusWelderControlModbus:setArcStartVoltage(newVal)
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
    return self:innerUpdateHoldRegsValue_Address(6,newVal,nil)
end

function FroniusWelderControlModbus:setArcEndVoltage(newVal)
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
    return self:innerUpdateHoldRegsValue_Address(6,newVal,nil)
end

function FroniusWelderControlModbus:getWeldVoltage()
    local newVal = self:innerGetInRegsValue_Address(innerConvertAddress(4)) or {}
    if #newVal<1 then
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":getWeldVoltage->read fail,return value is nil")
        return nil
    end
    return innerVoltage_Welder2Locale(newVal[1])
end

function FroniusWelderControlModbus:getWeldWireFeedSpeed()
    local newVal = self:innerGetInRegsValue_Address(innerConvertAddress(6)) or {}
    if #newVal<1 then
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":getWeldWireFeedSpeed->read fail,return value is nil")
        return nil
    end
    return innerWireFeedSpeed_Welder2Locale(newVal[1])
end

function FroniusWelderControlModbus:setWeldMode(newVal)
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
        job = 0x02 --0b00010 job号模式
        --internalParamSelect = 0x00, --0b00000 内部参数选择
        --specialTwoStepModeChar = 0x01, --0b00001 特殊两步模式特性
        --twoStepModeChar = 0x08 --0b01000 两步模式特性
    }
    if mapper[params] then
        newVal = (mapper[params]<<2)&0x007C
        
        MyWelderDebugLog(welderName..":setWeldMode->before write,mode="..tostring(params))
        return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                            local tmp=oldV&0xFF83
                                                            tmp=tmp|newV
                                                            MyWelderDebugLog(welderName..":setWeldMode->write value="..tmp)
                                                            return tmp
                                                           end)
    else
        MyWelderDebugLog(welderName..Language.trLang("WELDER_FUNC_MODE_NO_SUPPORT")..tostring(params))
        return false
    end
end

function FroniusWelderControlModbus:setJobId(newVal)
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
    return self:innerUpdateHoldRegsValue_Address(4,newVal,function(oldV,newV)
                                                            local tmp=oldV&0xFF00
                                                            tmp=tmp|newV
                                                            MyWelderDebugLog(welderName..":setJobId->write value="..tmp)
                                                            return tmp
                                                        end)
end

function FroniusWelderControlModbus:arcStart()
    local newVal = 0x01
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":arcStart->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                        local v = oldV|newV
                                                        MyWelderDebugLog(welderName..":arcStart->write value="..v)
                                                        return v
                                                     end)
end

function FroniusWelderControlModbus:isArcStarted()
    local welderName = self.welderObject.welderName
    local newVal = self:innerGetInRegsValue_Address(innerConvertAddress(0)) or {}
    if #newVal<1 then
        MyWelderDebugLog(welderName..":isArcStarted->read fail,return value is nil")
        return nil
    end
    local state = (newVal[1]&0x0020)==0x0020
    MyWelderDebugLog(string.format("%s:isArcStarted->read ok,newVal[1]=0x%X, state=%s",welderName,newVal[1], tostring(state)))
    return state
end

function FroniusWelderControlModbus:arcEnd()
    local newVal = 0xFFFE
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":arcEnd->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                        local v = oldV&newV
                                                        MyWelderDebugLog(welderName..":arcEnd->write value="..v)
                                                        return v
                                                     end)
end

function FroniusWelderControlModbus:isArcEnded()
    local welderName = self.welderObject.welderName
    local newVal = self:innerGetInRegsValue_Address(innerConvertAddress(0)) or {}
    if #newVal<1 then
        MyWelderDebugLog(welderName..":isArcEnded->read fail,return value is nil")
        return nil
    end
    local state = (newVal[1]&0x0020)==0x0000
    MyWelderDebugLog(string.format("%s:isArcEnded->read ok,newVal[1]=0x%X, state=%s",welderName,newVal[1], tostring(state)))
    return state
end

function FroniusWelderControlModbus:hasEndArcByMannual()
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

function FroniusWelderControlModbus:clearError()
    local newVal = 0x0800
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":clearError->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                        local v = oldV|newV
                                                        MyWelderDebugLog(welderName..":clearError->write value="..v)
                                                        return v
                                                     end)
end

function FroniusWelderControlModbus:startWireFeed()
    local newVal = 0x0200
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":startWireFeed->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                        local v = oldV|newV
                                                        MyWelderDebugLog(welderName..":startWireFeed->write value="..v)
                                                        return v
                                                     end)
end
function FroniusWelderControlModbus:stopWireFeed()
    local newVal = 0xFDFF
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":stopWireFeed->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                        local v = oldV&newV
                                                        MyWelderDebugLog(welderName..":stopWireFeed->write value="..v)
                                                        return v
                                                     end)
end

function FroniusWelderControlModbus:startWireBack()
    local newVal = 0x0400
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":startWireBack->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                        local v = oldV|newV
                                                        MyWelderDebugLog(welderName..":startWireBack->write value="..v)
                                                        return v
                                                     end)
end
function FroniusWelderControlModbus:stopWireBack()
    local newVal = 0xFBFF
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":stopWireBack->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                        local v = oldV&newV
                                                        MyWelderDebugLog(welderName..":stopWireBack->write value="..v)
                                                        return v
                                                     end)
end

function FroniusWelderControlModbus:startGasCheck()
    local newVal = 0x0100
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":startGasCheck->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                        local v = oldV|newV
                                                        MyWelderDebugLog(welderName..":startGasCheck->write value="..v)
                                                        return v
                                                     end)
end
function FroniusWelderControlModbus:stopGasCheck()
    local newVal = 0xFEFF
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":stopGasCheck->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                        local v = oldV&newV
                                                        MyWelderDebugLog(welderName..":stopGasCheck->write value="..v)
                                                        return v
                                                     end)
end

function FroniusWelderControlModbus:getWelderRunStateInfo()
    local info = {connectState = false}
    --一次性读取所有的数据
    local newVal = self:innerGetInRegsValue_Address(innerConvertAddress(0),9) or {}
    if #newVal<9 then return info end
    
    if (newVal[1]&0x02)==0x02 then info.connectState = true
    else info.connectState = false
    end
    
    info.weldVoltage = innerVoltage_Welder2Locale(newVal[5])
    info.weldCurrent = innerCurrent_Welder2Locale(newVal[6])
    info.wireFeedSpeed = innerWireFeedSpeed_Welder2Locale(newVal[7])
    
    if (newVal[1]&0x0020)==0x0020 then info.weldState = 1
    else info.weldState = 0
    end
    
    info.wireState = 0

    return info
end

function FroniusWelderControlModbus:getWelderErrCode()
    local newVal = self:innerGetInRegsValue_Address(innerConvertAddress(8)) or {}
    if #newVal<1 then
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":getWelderErrCode->read fail,return value is nil")
        return nil
    end
    newVal = newVal[1]&0x00FFFF
    return newVal
end

return FroniusWelderControlModbus