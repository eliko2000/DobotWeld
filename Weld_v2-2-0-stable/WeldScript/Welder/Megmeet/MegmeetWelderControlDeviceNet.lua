--[[焊机DeviceNet接口，继承自`WelderControlDeviceNet`]]--

--【本地私有接口】--
--本地电流值转换为焊机想要的电流值
local function innerCurrent_Locale2Welder(newVal)
    if newVal<0 then newVal=0 end
    if newVal>550 then newVal=550 end
    return newVal/550*65535
end
--焊机电流转换为本地想要的电流值
local function innerCurrent_Welder2Locale(newVal)
    newVal = CHelperTools.ToUInt16(newVal)
    newVal = newVal*1000/65535
    return newVal
end

--本地电压值转换为焊机想要的电压值
local function innerVoltage_Locale2Welder(newVal,mode)
    if "respectivelyMode" == mode then --分别模式，范围值[0,50]
        if newVal<0 then newVal=0 end
        if newVal>50 then newVal=50 end
        return newVal/50*65535
    else --monization 默认为一元模式吧，范围值[-30,30]
        if newVal<-30 then newVal=-30 end
        if newVal>30 then newVal=30 end
        local tmp = (newVal+30)/60*65535 --这个值不可能是负数，否则就是参数设置有问题
        --[[因为这家焊机这个模式下不支持显示小数部分，而焊机底下又没有做四舍五入操作
        结果导致下发5，显示的却是4，所以为了让显示正确，做了特殊计算]]--
        local vi,vf = math.modf(tmp) --返回正数和小数部分
        if newVal<0 then
            return vi
        elseif newVal==30 then
            return vi
        else
            return (vi+1)
        end
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
    return newVal
end

-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
--【业务实现接口】-------------------------------------------------------------------------------------------------
local MegmeetWelderControlDeviceNet = WelderControlDeviceNet:new()
MegmeetWelderControlDeviceNet.__index = MegmeetWelderControlDeviceNet

-------------------------------------------------------------------------------------------------------------------
--【对内不公开接口，只给本身和派生类使用】-----------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------
--【对外公开接口】-------------------------------------------------------------------------------------------------
function MegmeetWelderControlDeviceNet:new(welderObj)
    local o = WelderControlDeviceNet:new()
    o.welderObject = welderObj
    setmetatable(o,self)
    return o
end

function MegmeetWelderControlDeviceNet:initWelder()
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

function MegmeetWelderControlDeviceNet:notifyWelderThatRobotHasReady()
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":notifyWelderThatRobotHasReady->before write")
    return self:innerUpdateHoldRegsValue_Address(0,0x02,function(oldV,newV) 
                                                        local v = oldV|newV
                                                        MyWelderDebugLog(welderName..":notifyWelderThatRobotHasReady->write value="..v)
                                                        return v
                                                     end)
end

function MegmeetWelderControlDeviceNet:notifyWelderThatRobotNotReady()
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":notifyWelderThatRobotNotReady->before write")
    return self:innerUpdateHoldRegsValue_Address(0,0xFFFD,function(oldV,newV) 
                                                            local v = oldV&newV
                                                            MyWelderDebugLog(welderName..":notifyWelderThatRobotNotReady->write value="..v)
                                                            return v
                                                         end)
end

function MegmeetWelderControlDeviceNet:isWelderReady()
    local newVal = self:innerGetInRegsValue_Address(0) or {}
    if #newVal<1 then
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":isWelderReady->read fail,return value is nil")
        return nil
    end
    --bit6为1表示焊机准备好，为0表示未准备好
    --同时高8位为0，高8位是故障码,为0表示没有故障
    local readyVal = (newVal[1]&0x0040)==0x0040
    local faultCode = (newVal[1]&0xFF00)==0x00
    return readyVal and faultCode
end

function MegmeetWelderControlDeviceNet:setTouchPostionEnable(bEnable)
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

function MegmeetWelderControlDeviceNet:isTouchPositionSuccess()
    local welderName = self.welderObject.welderName
    local newVal = self:innerGetInRegsValue_Address(1) or {}
    if #newVal<1 then
        MyWelderDebugLog(welderName..":isTouchPositionSuccess->read fail,return value is nil")
        return nil
    end
    local state = (newVal[1]&0x0100)==0x0100
    --MyWelderDebugLog(string.format("%s:isTouchPositionSuccess->read ok,newVal[1]=0x%X, state=%s",welderName,newVal[1], tostring(state)))
    return state
end

function MegmeetWelderControlDeviceNet:setWeldCurrent(newVal)
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

function MegmeetWelderControlDeviceNet:setArcStartCurrent(newVal)
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

function MegmeetWelderControlDeviceNet:setArcEndCurrent(newVal)
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

function MegmeetWelderControlDeviceNet:getWeldCurrent()
    local newVal = self:innerGetInRegsValue_Address(3) or {}
    if #newVal<1 then
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":getWeldCurrent->read fail,return value is nil")
        return nil
    end
    return innerCurrent_Welder2Locale(newVal[1])
end

function MegmeetWelderControlDeviceNet:setWeldVoltage(newVal)
    local welderName = self.welderObject.welderName
    if nil == newVal then
        local params = self.welderObject:getWelderParamObject():getNotJobModeParam()
        if #params.params < 1 or params.selectedId<1 or params.selectedId > #params.params then
            MyWelderDebugLog(welderName..Language.trLang("WELDER_SET_WELD_VOLTAGE"))
            return false
        end
        newVal = params.params[params.selectedId].weldVoltage
    end
    local weldMode = self.welderObject:getWelderParamObject():getWeldMode()
    MyWelderDebugLog(welderName..":setWeldVoltage->write value="..newVal..",weldMode="..weldMode)
    newVal = math.floor(innerVoltage_Locale2Welder(newVal,weldMode))
    return self:innerUpdateHoldRegsValue_Address(3,newVal,nil)
end

function MegmeetWelderControlDeviceNet:setArcStartVoltage(newVal)
    local welderName = self.welderObject.welderName
    if nil == newVal then
        local params = self.welderObject:getWelderParamObject():getNotJobModeParam()
        if #params.params < 1 or params.selectedId<1 or params.selectedId > #params.params then
            MyWelderDebugLog(welderName..Language.trLang("WELDER_SET_ARC_VOLTAGE"))
            return false
        end
        newVal = params.params[params.selectedId].arcStartVoltage
    end
    local weldMode = self.welderObject:getWelderParamObject():getWeldMode()
    MyWelderDebugLog(welderName..":setArcStartVoltage->write value="..newVal..",weldMode="..weldMode)
    newVal = math.floor(innerVoltage_Locale2Welder(newVal,weldMode))
    return self:innerUpdateHoldRegsValue_Address(3,newVal,nil)
end

function MegmeetWelderControlDeviceNet:setArcEndVoltage(newVal)
    local welderName = self.welderObject.welderName
    if nil == newVal then
        local params = self.welderObject:getWelderParamObject():getNotJobModeParam()
        if #params.params < 1 or params.selectedId<1 or params.selectedId > #params.params then
            MyWelderDebugLog(welderName..Language.trLang("WELDER_SET_END_VOLTAGE"))
            return false
        end
        newVal = params.params[params.selectedId].arcEndVoltage
    end
    local weldMode = self.welderObject:getWelderParamObject():getWeldMode()
    MyWelderDebugLog(welderName..":setArcEndVoltage->write value="..newVal..",weldMode="..weldMode)
    newVal = math.floor(innerVoltage_Locale2Welder(newVal,weldMode))
    return self:innerUpdateHoldRegsValue_Address(3,newVal,nil)
end

function MegmeetWelderControlDeviceNet:getWeldVoltage()
    local newVal = self:innerGetInRegsValue_Address(2) or {}
    if #newVal<1 then
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":getWeldVoltage->read fail,return value is nil")
        return nil
    end
    return innerVoltage_Welder2Locale(newVal[1])
end

function MegmeetWelderControlDeviceNet:getWeldWireFeedSpeed()
    local newVal = self:innerGetInRegsValue_Address(5) or {}
    if #newVal<1 then
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":getWeldWireFeedSpeed->read fail,return value is nil")
        return nil
    end
    return innerWireFeedSpeed_Welder2Locale(newVal[1])
end

function MegmeetWelderControlDeviceNet:setWeldMode(newVal)
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
        monizationDC = 0, --直流一元化
        pulseMonization = 1, --脉冲一元化
        job = 2, --job号模式
        proximityMode = 3, --近控模式
        respectivelyMode = 4, --分别模式
        cccvMode = 5, --CC/CV模式
        tigMode = 6, --TIG模式
        cmtMode = 7 --CMT模式
    }
    if mapper[params] then
        newVal = (mapper[params]<<2)&0x1C
        
        MyWelderDebugLog(welderName..":setWeldMode->before write,mode="..tostring(params))
        return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                            local tmp=oldV&0xFFE3
                                                            tmp = tmp|newV
                                                            MyWelderDebugLog(welderName..":setWeldMode->write value="..tmp)
                                                            return tmp
                                                           end)
    else
        MyWelderDebugLog(welderName..Language.trLang("WELDER_FUNC_MODE_NO_SUPPORT")..tostring(params))
        return false
    end
end

function MegmeetWelderControlDeviceNet:setJobId(newVal)
    local welderName = self.welderObject.welderName
    if nil == newVal then
        local params = self.welderObject:getWelderParamObject():getJobModeParam()
        newVal = params.jobId
    end
    if newVal<0 or newVal>99 then
        MyWelderDebugLog(welderName..Language.trLang("WELDER_JOBNUMBER_ERR")..":jobId="..tostring(newVal))
        return false
    end
    MyWelderDebugLog(welderName..":setJobId->before write,jobId="..tostring(newVal))
    --lua没有signed short int long概念，为了创造2字节数据同时也为了防止被覆盖，所以这样操作变成2字节数据
    newVal = newVal&0x00FF
    local ret1 = self:innerUpdateHoldRegsValue_Address(1,newVal,function(oldV,newV)
                                                                    local tmp=oldV&0xFF00
                                                                    tmp = tmp|newV
                                                                    MyWelderDebugLog(welderName..":setJobId->write value="..tmp)
                                                                    return tmp
                                                                end)
    local ret2 = self:innerUpdateHoldRegsValue_Address(4,newVal,function(oldV,newV)
                                                                    local tmp=oldV&0xFF00
                                                                    tmp = tmp|newV
                                                                    MyWelderDebugLog(welderName..":setJobId->write value="..tmp)
                                                                    return tmp
                                                                end)
    return ret1 or ret2
end

function MegmeetWelderControlDeviceNet:arcStart()
    local newVal = 0x01
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":arcStart->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV) 
                                                            local v = oldV|newV
                                                            MyWelderDebugLog(welderName..":arcStart->write value="..v)
                                                            return v
                                                         end)
end

function MegmeetWelderControlDeviceNet:isArcStarted()
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

function MegmeetWelderControlDeviceNet:arcEnd()
    local newVal = 0xFFFE
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":arcEnd->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV) 
                                                            local v = oldV&newV
                                                            MyWelderDebugLog(welderName..":arcEnd->write value="..v)
                                                            return v
                                                         end)
end

function MegmeetWelderControlDeviceNet:isArcEnded()
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

function MegmeetWelderControlDeviceNet:hasEndArcByMannual()
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

function MegmeetWelderControlDeviceNet:clearError()
    local newVal = 0x0800
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":clearError->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV) 
                                                            local v = oldV|newV
                                                            MyWelderDebugLog(welderName..":clearError->write value="..v)
                                                            return v
                                                         end)
end

function MegmeetWelderControlDeviceNet:startWireFeed()
    local newVal = 0x0200
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":startWireFeed->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV) 
                                                            local v = oldV|newV
                                                            MyWelderDebugLog(welderName..":startWireFeed->write value="..v)
                                                            return v
                                                         end)
end
function MegmeetWelderControlDeviceNet:stopWireFeed()
    local newVal = 0xFDFF
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":stopWireFeed->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV) 
                                                            local v = oldV&newV
                                                            MyWelderDebugLog(welderName..":stopWireFeed->write value="..v)
                                                            return v
                                                         end)
end

function MegmeetWelderControlDeviceNet:startWireBack()
    local newVal = 0x0400
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":startWireBack->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV) 
                                                            local v = oldV|newV
                                                            MyWelderDebugLog(welderName..":startWireBack->write value="..v)
                                                            return v
                                                         end)
end
function MegmeetWelderControlDeviceNet:stopWireBack()
    local newVal = 0xFBFF
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":stopWireBack->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV) 
                                                            local v = oldV&newV
                                                            MyWelderDebugLog(welderName..":stopWireBack->write value="..v)
                                                            return v
                                                         end)
end

function MegmeetWelderControlDeviceNet:startGasCheck()
    local newVal = 0x0100
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":startGasCheck->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV) 
                                                            local v = oldV|newV
                                                            MyWelderDebugLog(welderName..":startGasCheck->write value="..v)
                                                            return v
                                                         end)
end
function MegmeetWelderControlDeviceNet:stopGasCheck()
    local newVal = 0xFEFF
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":stopGasCheck->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV) 
                                                            local v = oldV&newV
                                                            MyWelderDebugLog(welderName..":stopGasCheck->write value="..v)
                                                            return v
                                                         end)
end

function MegmeetWelderControlDeviceNet:getWelderRunStateInfo()
    local info = {connectState = false}
    --一次性读取所有的数据
    local newVal = self:innerGetInRegsValue_Address(0,6) or {}
    if #newVal<6 then return info end

    if ((newVal[1]&0x0040)==0x0040) and ((newVal[1]&0xFF00)==0x00) then
        info.connectState = true
    else info.connectState = false
    end
    
    info.weldVoltage = innerVoltage_Welder2Locale(newVal[3])
    info.weldCurrent = innerCurrent_Welder2Locale(newVal[4])
    info.wireFeedSpeed = innerWireFeedSpeed_Welder2Locale(newVal[6])
    
    if (newVal[1]&0x01)==0x01 then info.weldState = 1
    else info.weldState = 0
    end

    return info
end

function MegmeetWelderControlDeviceNet:getWelderErrCode()
    local newVal = self:innerGetInRegsValue_Address(0) or {}
    if #newVal<1 then
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":getWelderErrCode->read fail,return value is nil")
        return nil
    end
    newVal = (newVal[1]>>8)&0x00FF
    return newVal
end

return MegmeetWelderControlDeviceNet