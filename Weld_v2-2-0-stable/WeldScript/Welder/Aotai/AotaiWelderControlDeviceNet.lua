--[[焊机DeviceNet接口，继承自`WelderControlDeviceNet`]]--

--【本地私有接口】--
--本地电流值转换为焊机想要的电流值
local function innerCurrent_Locale2Welder(newVal)
    if newVal<0 then newVal=0 end
    if newVal>500 then newVal=500 end
    return newVal/500*65535
end
--焊机电流转换为本地想要的电流值
local function innerCurrent_Welder2Locale(newVal)
    newVal = CHelperTools.ToUInt16(newVal)
    newVal = newVal*1000/65535
    return newVal
end

--本地电压值转换为焊机想要的电压值
local function innerVoltage_Locale2Welder(newVal,mode)
    if "respectively" == mode then --分别模式，范围值[0,50]
        if newVal<0 then newVal=0 end
        if newVal>50 then newVal=50 end
        return newVal/50*65535
    else --monization 默认一元模式，范围值[-5,5]
        if newVal<-5 then newVal=-5 end
        if newVal>5 then newVal=5 end
        return (newVal+5)/10*65535
    end
end
--焊机电压转换为本地想要的电压值
local function innerVoltage_Welder2Locale(newVal)
    newVal = CHelperTools.ToInt16(newVal)
    newVal = newVal*100/65535
    return newVal
end

--焊机送丝速度转换为本地想要的速度值
local function innerWireFeedSpeed_Welder2Locale(newVal)
    newVal = CHelperTools.ToInt16(newVal)
    newVal = newVal*22/65535
    return newVal
end

-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
--【业务实现接口】-------------------------------------------------------------------------------------------------
local AotaiWelderControlDeviceNet = WelderControlDeviceNet:new()
AotaiWelderControlDeviceNet.__index = AotaiWelderControlDeviceNet

-------------------------------------------------------------------------------------------------------------------
--【对内不公开接口，只给本身和派生类使用】-----------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------
--【对外公开接口】-------------------------------------------------------------------------------------------------
function AotaiWelderControlDeviceNet:new(welderObj)
    local o = WelderControlDeviceNet:new()
    o.welderObject = welderObj
    setmetatable(o,self)
    return o
end

function AotaiWelderControlDeviceNet:initWelder()
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
                                                        v = v&(~(1<<12)) --接触寻位使能关闭
                                                        MyWelderDebugLog(welderName..":initWelder->write value="..v)
                                                        return v
                                                     end)
end

function AotaiWelderControlDeviceNet:notifyWelderThatRobotHasReady()
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":notifyWelderThatRobotHasReady->before write")
    return self:innerUpdateHoldRegsValue_Address(0,0x02,function(oldV,newV)
                                                            local v = oldV|newV
                                                            MyWelderDebugLog(welderName..":notifyWelderThatRobotHasReady->write value="..v)
                                                            return v
                                                         end)
end

function AotaiWelderControlDeviceNet:notifyWelderThatRobotNotReady()
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":notifyWelderThatRobotNotReady->before write")
    return self:innerUpdateHoldRegsValue_Address(0,0xFFFD,function(oldV,newV)
                                                            local v = oldV&newV
                                                            MyWelderDebugLog(welderName..":notifyWelderThatRobotNotReady->write value="..v)
                                                            return v
                                                         end)
end

function AotaiWelderControlDeviceNet:isWelderReady()
    local newVal = self:innerGetInRegsValue_Address(0) or {}
    if #newVal<1 then
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":isWelderReady->read fail,return value is nil")
        return nil
    end
    return (newVal[1]&0x02)==0x02
end

function AotaiWelderControlDeviceNet:setTouchPostionEnable(bEnable)
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":setTouchPostionEnable->write value="..tostring(bEnable))
    if bEnable then
        return self:innerUpdateHoldRegsValue_Address(0,0x1000,function(oldV,newV)
                                                                local v = oldV|newV
                                                                MyWelderDebugLog(welderName..":setTouchPostionEnable->write value="..v)
                                                                return v
                                                              end)
    else
        return self:innerUpdateHoldRegsValue_Address(0,0xEFFF,function(oldV,newV)
                                                                local v = oldV&newV
                                                                MyWelderDebugLog(welderName..":setTouchPostionEnable->write value="..v)
                                                                return v
                                                              end)    
    end
end

function AotaiWelderControlDeviceNet:isTouchPositionSuccess()
    local welderName = self.welderObject.welderName
    local newVal = self:innerGetInRegsValue_Address(0) or {}
    if #newVal<1 then
        MyWelderDebugLog(welderName..":isTouchPositionSuccess->read fail,return value is nil")
        return nil
    end
    local state = (newVal[1]&0x01)==0x01
    --MyWelderDebugLog(string.format("%s:isTouchPositionSuccess->read ok,newVal[1]=0x%X, state=%s",welderName,newVal[1], tostring(state)))
    return state
end

function AotaiWelderControlDeviceNet:setWeldCurrent(newVal)
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
    return self:innerUpdateHoldRegsValue_Address(2,newVal,nil)
end

function AotaiWelderControlDeviceNet:setArcStartCurrent(newVal)
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
    return self:innerUpdateHoldRegsValue_Address(2,newVal,nil)
end

function AotaiWelderControlDeviceNet:setArcEndCurrent(newVal)
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
    return self:innerUpdateHoldRegsValue_Address(2,newVal,nil)
end

function AotaiWelderControlDeviceNet:getWeldCurrent()
    local newVal = self:innerGetInRegsValue_Address(3) or {}
    if #newVal<1 then
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":getWeldCurrent->read fail,return value is nil")
        return nil
    end
    return innerCurrent_Welder2Locale(newVal[1])
end

function AotaiWelderControlDeviceNet:setWeldVoltage(newVal)
    local welderName = self.welderObject.welderName
    if nil == newVal then
        local params = self.welderObject:getWelderParamObject():getNotJobModeParam()
        if #params.params < 1 or params.selectedId<1 or params.selectedId > #params.params then
            MyWelderDebugLog(welderName..Language.trLang("WELDER_SET_WELD_VOLTAGE"))
            return false
        end
        newVal = params.params[params.selectedId].weldVoltage
    end
    local workMode = self.welderObject:getWelderParamObject():getWorkMode()
    MyWelderDebugLog(welderName..":setWeldVoltage->write value="..newVal..",workMode="..workMode)
    newVal = math.floor(innerVoltage_Locale2Welder(newVal,workMode))
    return self:innerUpdateHoldRegsValue_Address(3,newVal,nil)
end

function AotaiWelderControlDeviceNet:setArcStartVoltage(newVal)
    local welderName = self.welderObject.welderName
    if nil == newVal then
        local params = self.welderObject:getWelderParamObject():getNotJobModeParam()
        if #params.params < 1 or params.selectedId<1 or params.selectedId > #params.params then
            MyWelderDebugLog(welderName..Language.trLang("WELDER_SET_ARC_VOLTAGE"))
            return false
        end
        newVal = params.params[params.selectedId].arcStartVoltage
    end
    local workMode = self.welderObject:getWelderParamObject():getWorkMode()
    MyWelderDebugLog(welderName..":setArcStartVoltage->write value="..newVal..",workMode="..workMode)
    newVal = math.floor(innerVoltage_Locale2Welder(newVal,workMode))
    return self:innerUpdateHoldRegsValue_Address(3,newVal,nil)
end

function AotaiWelderControlDeviceNet:setArcEndVoltage(newVal)
    local welderName = self.welderObject.welderName
    if nil == newVal then
        local params = self.welderObject:getWelderParamObject():getNotJobModeParam()
        if #params.params < 1 or params.selectedId<1 or params.selectedId > #params.params then
            MyWelderDebugLog(welderName..Language.trLang("WELDER_SET_END_VOLTAGE"))
            return false
        end
        newVal = params.params[params.selectedId].arcEndVoltage
    end
    local workMode = self.welderObject:getWelderParamObject():getWorkMode()
    MyWelderDebugLog(welderName..":setArcEndVoltage->write value="..newVal..",workMode="..workMode)
    newVal = math.floor(innerVoltage_Locale2Welder(newVal,workMode))
    return self:innerUpdateHoldRegsValue_Address(3,newVal,nil)
end

function AotaiWelderControlDeviceNet:getWeldVoltage()
    local newVal = self:innerGetInRegsValue_Address(2) or {}
    if #newVal<1 then
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":getWeldVoltage->read fail,return value is nil")
        return nil
    end
    return innerVoltage_Welder2Locale(newVal[1])
end

function AotaiWelderControlDeviceNet:getWeldWireFeedSpeed()
    local newVal = self:innerGetInRegsValue_Address(5) or {}
    if #newVal<1 then
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":getWeldWireFeedSpeed->read fail,return value is nil")
        return nil
    end
    return innerWireFeedSpeed_Welder2Locale(newVal[1])
end

function AotaiWelderControlDeviceNet:setWeldMode(newVal)
    MyWelderDebugLog("AotaiWelderControlDeviceNet:setWeldMode do nothing,let subclass handle")
    return true
end

function AotaiWelderControlDeviceNet:setJobId(newVal)
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
    return self:innerUpdateHoldRegsValue_Address(1,newVal,function(oldV,newV)
                                                            local tmp=oldV&0xFF00
                                                            tmp=tmp|newV
                                                            MyWelderDebugLog(welderName..":setJobId->write value="..tmp)
                                                            return tmp
                                                          end)
end

function AotaiWelderControlDeviceNet:arcStart()
    local newVal = 0x0001
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":arcStart->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                            local v = oldV|newV
                                                            MyWelderDebugLog(welderName..":arcStart->write value="..v)
                                                            return v
                                                         end)
end

function AotaiWelderControlDeviceNet:isArcStarted()
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

function AotaiWelderControlDeviceNet:arcEnd()
    local newVal = 0xFFFE
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":arcEnd->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                            local v = oldV&newV
                                                            MyWelderDebugLog(welderName..":arcEnd->write value="..v)
                                                            return v
                                                         end)
end

function AotaiWelderControlDeviceNet:isArcEnded()
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

function AotaiWelderControlDeviceNet:hasEndArcByMannual()
    local welderName = self.welderObject.welderName
    local newVal = self:innerGetHoldRegsValue_Address(0) or {}
    if #newVal<1 then
        MyWelderDebugLog(welderName..":hasEndArcByMannual->read fail,return value is nil")
        return nil
    end
    local state = (newVal[1]&0x0001)==0x00
    MyWelderDebugLog(string.format("%s:hasEndArcByMannual->read ok,newVal[1]=0x%X, state=%s",welderName,newVal[1], tostring(state)))
    return state
end

function AotaiWelderControlDeviceNet:clearError()
    local newVal = 0x0800
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":clearError->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                            local v = oldV|newV
                                                            MyWelderDebugLog(welderName..":clearError->write value="..v)
                                                            return v
                                                         end)
end

function AotaiWelderControlDeviceNet:startWireFeed()
    local newVal = 0x0200
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":startWireFeed->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                            local v = oldV|newV
                                                            MyWelderDebugLog(welderName..":startWireFeed->write value="..v)
                                                            return v
                                                         end)
end
function AotaiWelderControlDeviceNet:stopWireFeed()
    local newVal = 0xFDFF
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":stopWireFeed->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                            local v = oldV&newV
                                                            MyWelderDebugLog(welderName..":stopWireFeed->write value="..v)
                                                            return v
                                                         end)
end

function AotaiWelderControlDeviceNet:startWireBack()
    local newVal = 0x0400
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":startWireBack->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                            local v = oldV|newV
                                                            MyWelderDebugLog(welderName..":startWireBack->write value="..v)
                                                            return v
                                                         end)
end
function AotaiWelderControlDeviceNet:stopWireBack()
    local newVal = 0xFBFF
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":stopWireBack->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                            local v = oldV&newV
                                                            MyWelderDebugLog(welderName..":stopWireBack->write value="..v)
                                                            return v
                                                         end)
end

function AotaiWelderControlDeviceNet:isWireHasSignal()
    local newVal = self:innerGetInRegsValue_Address(1) or {}
    if #newVal<1 then --操作失败认为无信号
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":isWireHasSignal->read fail,return value is nil")
        return nil
    end
    return (newVal[1]&0x0010)==0x0010
end

function AotaiWelderControlDeviceNet:isStickRelease()
    local newVal = self:innerGetInRegsValue_Address(1) or {}
    if #newVal<1 then --操作失败认为粘丝未解除
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":isStickRelease->read fail,return value is nil")
        return nil
    end
    return (newVal[1]&0x0100)==0x0000
end

function AotaiWelderControlDeviceNet:startGasCheck()
    local newVal = 0x0100
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":startGasCheck->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                            local v = oldV|newV
                                                            MyWelderDebugLog(welderName..":startGasCheck->write value="..v)
                                                            return v
                                                         end)
end
function AotaiWelderControlDeviceNet:stopGasCheck()
    local newVal = 0xFEFF
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":stopGasCheck->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                            local v = oldV&newV
                                                            MyWelderDebugLog(welderName..":stopGasCheck->write value="..v)
                                                            return v
                                                         end)
end

function AotaiWelderControlDeviceNet:isGasHasSignal()
    local newVal = self:innerGetInRegsValue_Address(1) or {}
    if #newVal<1 then --默认操作失败为无信号
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":isGasHasSignal->read fail,return value is nil")
        return nil
    end
    return (newVal[1]&0x0020)==0x0020
end

function AotaiWelderControlDeviceNet:getWelderRunStateInfo()
    local info = {connectState = false}
    --一次性读取所有的数据
    local newVal = self:innerGetInRegsValue_Address(0,6) or {}
    if #newVal<6 then return info end
    
    if (newVal[1]&0x02)==0x02 then info.connectState = true
    else info.connectState = false
    end
    
    info.weldVoltage = innerVoltage_Welder2Locale(newVal[3])
    info.weldCurrent = innerCurrent_Welder2Locale(newVal[4])
    info.wireFeedSpeed = innerWireFeedSpeed_Welder2Locale(newVal[6])
    
    if (newVal[1]&0x01)==0x01 then info.weldState = 1
    else info.weldState = 0
    end
    
    if (newVal[2]&0x0100)==0x0000 then info.wireState = 0
    else info.wireState = 1
    end
    return info
end

return AotaiWelderControlDeviceNet