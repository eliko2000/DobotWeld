--[[焊机接口，继承自`WelderControlEIP`
configAssemblyId=0/197
outputAssemblyId=150
inputAssemblyId=100
outputAssemblySize=18
inputAssemblySize=16
]]--

--【本地私有接口】--
--本地电流值转换为焊机想要的电流值
local function innerCurrent_Locale2Welder(newVal)
    if newVal<0 then newVal=0 end
    if newVal>550 then newVal=550 end
    return newVal*10
end
--焊机电流转换为本地想要的电流值
local function innerCurrent_Welder2Locale(newVal)
    newVal = CHelperTools.ToUInt16(newVal)
    newVal = newVal/10
    return newVal
end

--本地电压值转换为焊机想要的电压值
local function innerVoltage_Locale2Welder(newVal,weldMode)
    if "independentCurrentMode" == mode then --独立调节/电流优先模式
        return newVal*10
    else --monizationCurrentMode 默认一元化调节/电流优先模式，范围值[-9.8,9.8]（0～99～197对应实际调整量-9.8V～0～+9.8V）
        if newVal<-9.8 then newVal=-9.8 end
        if newVal>9.8 then newVal=9.8 end
        newVal = newVal*10+99
        return newVal
    end
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

--2字节的byte转为short,小端字节序
local function innerByte2Short(values)
    return (((values[2]&0x00FF)<<8)|(values[1]&0x00FF))&0x00FFFF
end
--short转为2字节的byte,小端字节序
local function innerShort2Byte(value)
    return {value&0x00FF,(value>>8)&0x00FF}
end
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
--【业务实现接口】-------------------------------------------------------------------------------------------------
local PanasonicWTDEUControlEIP = WelderControlEIP:new()
PanasonicWTDEUControlEIP.__index = PanasonicWTDEUControlEIP

-------------------------------------------------------------------------------------------------------------------
--【对内不公开接口，只给本身和派生类使用】-----------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------
--【对外公开接口】-------------------------------------------------------------------------------------------------
function PanasonicWTDEUControlEIP:new(welderObj)
    local o = WelderControlEIP:new()
    o.welderObject = welderObj
    setmetatable(o,self)
    return o
end

function PanasonicWTDEUControlEIP:initWelder()
    --[[
    不仅要发机器人准备好信号，还要发灭弧信号,因为刚开机时可能存在有起弧信号，
    导致这个原因是正常起弧焊接时，在需要发送断弧的时没有发成功
    ]]--
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":initWelder->before write")
    local ret1 = self:innerUpdateOutputValue_Address(0,{0,0},function(oldV,newV)
                                                        local v = oldV[1]
                                                        v = v&(~(1<<0)) --灭弧
                                                        v = v|(1<<1) --机器人准备好
                                                        
                                                        local v2 = oldV[2]
                                                        v2 = v2&(~(1<<0)) --停止气检
                                                        v2 = v2&(~(1<<1)) --停止送丝
                                                        v2 = v2&(~(1<<2)) --停止退丝
                                                        v2 = v2&(~(1<<4)) --粘丝解除检测关闭
                                                        v2 = v2|(1<<5) --清除错误，每次与焊机断开连接，焊机都会报错，每次连接都要清错
                                                        v2 = v2&(~(1<<6)) --接触传感使能关闭
                                                        MyWelderDebugLog(welderName..":initWelder->write value1="..v..",v2="..v2)
                                                        return {v,v2}
                                                     end)
    Wait(500)
    local ret2 = self:innerUpdateOutputValue_Address(1,{0},function(oldV,newV)
                                                        local v = oldV[1]
                                                        v = v&(~(1<<5)) --恢复清除错误
                                                        MyWelderDebugLog(welderName..":initWelder->write value="..v)
                                                        return {v}
                                                     end)
    return ret1 or ret2
end

function PanasonicWTDEUControlEIP:notifyWelderThatRobotHasReady()
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":notifyWelderThatRobotHasReady->before write")
    return self:innerUpdateOutputValue_Address(0,{0},function(oldV,newV)
                                                        local v = oldV[1]|0x02
                                                        MyWelderDebugLog(welderName..":notifyWelderThatRobotHasReady->write value="..v)
                                                        return {v}
                                                     end)
end

function PanasonicWTDEUControlEIP:notifyWelderThatRobotNotReady()
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":notifyWelderThatRobotNotReady->before write")
    return self:innerUpdateOutputValue_Address(0,{0},function(oldV,newV)
                                                        local v = oldV[1]&0xFD
                                                        MyWelderDebugLog(welderName..":notifyWelderThatRobotNotReady->write value="..v)
                                                        return {v}
                                                     end)
end

function PanasonicWTDEUControlEIP:isWelderReady()
    local newVal = self:innerReadInputValue_Address(0,2) or {}
    if #newVal<2 then
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":isWelderReady->read fail,return value is nil")
        return false
    end
    if (newVal[1]&0x02)==0x02 then
        return true
    else
        return false
    end
end

function PanasonicWTDEUControlEIP:setWeldCurrent(newVal)
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
    newVal = innerShort2Byte(newVal)
    return self:innerWriteOutputValue_Address(4,newVal,nil)
end

function PanasonicWTDEUControlEIP:setArcStartCurrent(newVal)
    local welderName = self.welderObject.welderName
    if nil == newVal then
        local params = self.welderObject:getWelderParamObject():getNotJobModeParam()
        if #params.params < 1 or params.selectedId<1 or params.selectedId > #params.params then
            MyWelderDebugLog(welderName..Language.trLang("WELDER_SET_WELD_CURRENT"))
            return false
        end
        newVal = params.params[params.selectedId].arcStartCurrent
    end
    MyWelderDebugLog(welderName..":setArcStartCurrent->write value="..newVal)
    newVal = math.floor(innerCurrent_Locale2Welder(newVal))
    newVal = innerShort2Byte(newVal)
    return self:innerWriteOutputValue_Address(4,newVal,nil)
end

function PanasonicWTDEUControlEIP:setArcEndCurrent(newVal)
    local welderName = self.welderObject.welderName
    if nil == newVal then
        local params = self.welderObject:getWelderParamObject():getNotJobModeParam()
        if #params.params < 1 or params.selectedId<1 or params.selectedId > #params.params then
            MyWelderDebugLog(welderName..Language.trLang("WELDER_SET_WELD_CURRENT"))
            return false
        end
        newVal = params.params[params.selectedId].arcEndCurrent
    end
    MyWelderDebugLog(welderName..":setArcEndCurrent->write value="..newVal)
    newVal = math.floor(innerCurrent_Locale2Welder(newVal))
    newVal = innerShort2Byte(newVal)
    return self:innerWriteOutputValue_Address(4,newVal,nil)
end

function PanasonicWTDEUControlEIP:getWeldCurrent()
    local newVal = self:innerReadInputValue_Address(4,2) or {}
    if #newVal<2 then
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":getWeldCurrent->read fail,return value is nil")
        return nil
    end
    return innerCurrent_Welder2Locale(innerByte2Short(newVal))
end

function PanasonicWTDEUControlEIP:setWeldVoltage(newVal)
    local welderName = self.welderObject.welderName
    if nil == newVal then
        local params = self.welderObject:getWelderParamObject():getNotJobModeParam()
        if #params.params < 1 or params.selectedId<1 or params.selectedId > #params.params then
            MyWelderDebugLog(welderName..Language.trLang("WELDER_SET_WELD_VOLTAGE"))
            return false
        end
        newVal = params.params[params.selectedId].weldVoltage
    end
    local weldMode = self.welderObject:getWelderParamObject():getWeldMode() or ""
    MyWelderDebugLog(welderName..":setWeldVoltage->write value="..newVal..",weldMode="..weldMode)
    newVal = math.floor(innerVoltage_Locale2Welder(newVal,weldMode))
    newVal = innerShort2Byte(newVal)
    return self:innerWriteOutputValue_Address(6,newVal,nil)
end

function PanasonicWTDEUControlEIP:setArcStartVoltage(newVal)
    local welderName = self.welderObject.welderName
    if nil == newVal then
        local params = self.welderObject:getWelderParamObject():getNotJobModeParam()
        if #params.params < 1 or params.selectedId<1 or params.selectedId > #params.params then
            MyWelderDebugLog(welderName..Language.trLang("WELDER_SET_ARC_VOLTAGE"))
            return false
        end
        newVal = params.params[params.selectedId].arcStartVoltage
    end
    local weldMode = self.welderObject:getWelderParamObject():getWeldMode() or ""
    MyWelderDebugLog(welderName..":setArcStartVoltage->write value="..newVal..",weldMode="..weldMode)
    newVal = math.floor(innerVoltage_Locale2Welder(newVal,weldMode))
    newVal = innerShort2Byte(newVal)
    return self:innerWriteOutputValue_Address(6,newVal,nil)
end

function PanasonicWTDEUControlEIP:setArcEndVoltage(newVal)
    local welderName = self.welderObject.welderName
    if nil == newVal then
        local params = self.welderObject:getWelderParamObject():getNotJobModeParam()
        if #params.params < 1 or params.selectedId<1 or params.selectedId > #params.params then
            MyWelderDebugLog(welderName..Language.trLang("WELDER_SET_END_VOLTAGE"))
            return false
        end
        newVal = params.params[params.selectedId].arcEndVoltage
    end
    local weldMode = self.welderObject:getWelderParamObject():getWeldMode() or ""
    MyWelderDebugLog(welderName..":setArcEndVoltage->write value="..newVal..",weldMode="..weldMode)
    newVal = math.floor(innerVoltage_Locale2Welder(newVal,weldMode))
    newVal = innerShort2Byte(newVal)
    return self:innerWriteOutputValue_Address(6,newVal,nil)
end

function PanasonicWTDEUControlEIP:getWeldVoltage()
    local newVal = self:innerReadInputValue_Address(6,2) or {}
    if #newVal<2 then
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":getWeldVoltage->read fail,return value is nil")
        return nil
    end
    return innerVoltage_Welder2Locale(innerByte2Short(newVal))
end

function PanasonicWTDEUControlEIP:getWeldWireFeedSpeed()
    local newVal = self:innerReadInputValue_Address(8,2) or {}
    if #newVal<2 then
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":getWeldWireFeedSpeed->read fail,return value is nil")
        return nil
    end
    return innerWireFeedSpeed_Welder2Locale(innerByte2Short(newVal))
end

function PanasonicWTDEUControlEIP:setWeldMode(newVal)
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
        independentCurrentMode = 0x00, --独立调节/电流优先模式
        --idenpendentWireFeedMode = 0x01, --独立调节/送丝速度优先模式
        monizationCurrentMode = 0x02, --一元化调节/电流优先模式
        --monizationWireFeedMode = 0x03, --一元化调节/送丝速度优先模式
        job = 0x04 --job号模式，就是调用号模式
    }
    if mapper[params] then
        newVal = (mapper[params]<<2)&0x1C --取中间三位
        
        MyWelderDebugLog(welderName..":setWeldMode->before write,mode="..tostring(params))
        return self:innerUpdateOutputValue_Address(0,{newVal},function(oldV,newV)
                                                            local tmp=oldV[1]&0xE3
                                                            tmp=tmp|newV[1]
                                                            MyWelderDebugLog(welderName..":setWeldMode->write value="..tmp)
                                                            return {tmp}
                                                           end)
    else
        MyWelderDebugLog(welderName..Language.trLang("WELDER_FUNC_MODE_NO_SUPPORT")..tostring(params))
        return false
    end
end

function PanasonicWTDEUControlEIP:setJobId(newVal)
    local welderName = self.welderObject.welderName
    if nil == newVal then
        local params = self.welderObject:getWelderParamObject():getJobModeParam()
        newVal = params.jobId
    end
    if newVal<1 or newVal>255 then
        MyWelderDebugLog(welderName..Language.trLang("WELDER_JOBNUMBER_ERR")..":jobId="..tostring(newVal))
        return false
    end
    MyWelderDebugLog(welderName..":setJobId->before write,jobId="..tostring(newVal))
    return self:innerWriteOutputValue_Address(3,{newVal})
end

function PanasonicWTDEUControlEIP:setProcessNumber(newVal)
    local welderName = self.welderObject.welderName
    if nil == newVal then
        local params = self.welderObject:getWelderParamObject():getJobModeParam()
        newVal = params.processNumber
    end
    if newVal<0 or newVal>255 then
        MyWelderDebugLog(welderName..Language.trLang("WELDER_PROGRAM_NUM_ERR").."processNumber="..tostring(newVal))
        return false
    end
    MyWelderDebugLog(welderName..":setProcessNumber->before write,processNumber="..tostring(newVal))
    return self:innerWriteOutputValue_Address(2,{newVal})
end

function PanasonicWTDEUControlEIP:arcStart()
    local newVal = 1<<0
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":arcStart->before write")
    return self:innerUpdateOutputValue_Address(0,{0},function(oldV,newV)
                                                          local v = oldV[1]
                                                          v = v|(1<<0)
                                                          MyWelderDebugLog(welderName..":arcStart->write value="..v)
                                                          return {v}
                                                       end)
end

function PanasonicWTDEUControlEIP:isArcStarted()
    local welderName = self.welderObject.welderName
    local newVal = self:innerReadInputValue_Address(0,1) or {}
    if #newVal<1 then
        MyWelderDebugLog(welderName..":isArcStarted->read fail,return value is nil")
        return nil
    end
    newVal = newVal[1]
    local state = ((newVal>>0)&0x01)==0x01
    MyWelderDebugLog(string.format("%s:isArcStarted->read ok,newVal=0x%X, state=%s",welderName,newVal, tostring(state)))
    return state
end

function PanasonicWTDEUControlEIP:arcEnd()
    local newVal = (~(1<<0))&0x00FF
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":arcEnd->before write")
    return self:innerUpdateOutputValue_Address(0,{0},function(oldV,newV)
                                                          local v = oldV[1]
                                                          v = v&((~(1<<0))&0x00FF)
                                                          MyWelderDebugLog(welderName..":arcEnd->write value="..v)
                                                          return {v}
                                                       end)
end

function PanasonicWTDEUControlEIP:isArcEnded()
    local welderName = self.welderObject.welderName
    local newVal = self:innerReadInputValue_Address(0,1) or {}
    if #newVal<1 then
        MyWelderDebugLog(welderName..":isArcEnded->read fail,return value is nil")
        return nil
    end
    newVal = newVal[1]
    local state = (newVal&0x01)==0x00
    MyWelderDebugLog(string.format("%s:isArcEnded->read ok,newVal=0x%X, state=%s",welderName,newVal, tostring(state)))
    return state
end

function PanasonicWTDEUControlEIP:hasEndArcByMannual()
    local welderName = self.welderObject.welderName
    local newVal = self:innerReadOutputValue_Address(0,1) or {}
    if #newVal<1 then
        MyWelderDebugLog(welderName..":hasEndArcByMannual->read fail,return value is nil")
        return nil
    end
    newVal = newVal[1]
    local state = ((newVal>>0)&0x01)==0x00
    MyWelderDebugLog(string.format("%s:hasEndArcByMannual->read ok,newVal=0x%X, state=%s",welderName,newVal, tostring(state)))
    return state
end

function PanasonicWTDEUControlEIP:startWireFeed()
    local newVal = 1<<1
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":startWireFeed->before write")
    return self:innerUpdateOutputValue_Address(1,{0},function(oldV,newV)
                                                            local v = (oldV[1]|(1<<1))&0x00FF
                                                            MyWelderDebugLog(welderName..":startWireFeed->write value="..v)
                                                            return {v}
                                                         end)
end
function PanasonicWTDEUControlEIP:stopWireFeed()
    local newVal = (~(1<<1))&0xFFFF
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":stopWireFeed->before write")
    return self:innerUpdateOutputValue_Address(1,{0},function(oldV,newV)
                                                            local v = (oldV[1]&(~(1<<1)))&0x00FF
                                                            MyWelderDebugLog(welderName..":stopWireFeed->write value="..v)
                                                            return {v}
                                                         end)
end

function PanasonicWTDEUControlEIP:startWireBack()
    local newVal = 1<<2
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":startWireBack->before write")
    return self:innerUpdateOutputValue_Address(1,{0},function(oldV,newV)
                                                            local v = (oldV[1]|(1<<2))&0x00FF
                                                            MyWelderDebugLog(welderName..":startWireBack->write value="..v)
                                                            return {v}
                                                         end)
end
function PanasonicWTDEUControlEIP:stopWireBack()
    local newVal = (~(1<<2))&0xFFFF
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":stopWireBack->before write")
    return self:innerUpdateOutputValue_Address(1,{0},function(oldV,newV)
                                                            local v = (oldV[1]&(~(1<<2)))&0x00FF
                                                            MyWelderDebugLog(welderName..":stopWireBack->write value="..v)
                                                            return {v}
                                                         end)
end

function PanasonicWTDEUControlEIP:isStickRelease()
    local newVal = self:innerReadInputValue_Address(0,1) or {}
    if #newVal<1 then --操作失败认为粘丝未解除
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":isStickRelease->read fail,return value is nil")
        return nil
    end
    return (newVal[1]&0x08)==0x00
end

function PanasonicWTDEUControlEIP:startGasCheck()
    local newVal = 1<<0
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":startGasCheck->before write")
    return self:innerUpdateOutputValue_Address(1,{0},function(oldV,newV)
                                                            local v = (oldV[1]|(1<<0))&0x00FF
                                                            MyWelderDebugLog(welderName..":startGasCheck->write value="..v)
                                                            return {v}
                                                         end)
end
function PanasonicWTDEUControlEIP:stopGasCheck()
    local newVal = (~(1<<0))&0xFFFF
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":stopGasCheck->before write")
    return self:innerUpdateOutputValue_Address(1,{0},function(oldV,newV)
                                                            local v = (oldV[1]&(~(1<<0)))&0x00FF
                                                            MyWelderDebugLog(welderName..":stopGasCheck->write value="..v)
                                                            return {v}
                                                         end)
end

function PanasonicWTDEUControlEIP:getWelderRunStateInfo()
    local info = {connectState = false}
    --一次性读取所有的数据
    local newVal = self:innerReadInputValue_Address(0,10) or {}
    if #newVal<10 then return info end
    
    if (newVal[1]&0x02)==0x02 then info.connectState = true
    else info.connectState = false
    end
    
    local v = innerByte2Short({newVal[6],newVal[7]})
    info.weldVoltage = innerVoltage_Welder2Locale(v)
    v = innerByte2Short({newVal[4],newVal[5]})
    info.weldCurrent = innerCurrent_Welder2Locale(v)
    v = innerByte2Short({newVal[8],newVal[9]})
    info.wireFeedSpeed = innerWireFeedSpeed_Welder2Locale(v)
    info.errcode = newVal[2]
    if (newVal[1]&0x01)==0x01 then info.weldState = 1
    else info.weldState = 0
    end
    
    return info
end

function PanasonicWTDEUControlEIP:getWelderErrCode()
    local newVal = self:innerReadInputValue_Address(1,1) or {}
    if #newVal<1 then
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":getWelderErrCode->read fail,return value is nil")
        return nil
    end
    return newVal[1]&0x00FF
end

return PanasonicWTDEUControlEIP