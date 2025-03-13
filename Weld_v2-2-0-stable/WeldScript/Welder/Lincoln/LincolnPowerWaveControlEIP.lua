--[[焊机接口，继承自`WelderControlEIP`
configAssemblyId=5
outputAssemblyId=150
inputAssemblyId=100
outputAssemblySize=12
inputAssemblySize=12
]]--

--【本地私有接口】--
--焊机电流转换为本地想要的电流值
local function innerCurrent_Welder2Locale(newVal)
    newVal = CHelperTools.ToInt16(newVal)
    return newVal*0.1
end

--焊机电压转换为本地想要的电压值
local function innerVoltage_Welder2Locale(newVal)
    newVal = CHelperTools.ToInt16(newVal)
    return newVal*0.1
end

--焊机送丝速度转换为本地想要的速度值
local function innerWireFeedSpeed_Welder2Locale(newVal)
    newVal = CHelperTools.ToInt16(newVal)
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
local LincolnPowerWaveControlEIP = WelderControlEIP:new()
LincolnPowerWaveControlEIP.__index = LincolnPowerWaveControlEIP

-------------------------------------------------------------------------------------------------------------------
--【对内不公开接口，只给本身和派生类使用】-----------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------
--【对外公开接口】-------------------------------------------------------------------------------------------------
function LincolnPowerWaveControlEIP:new(welderObj)
    local o = WelderControlEIP:new()
    o.welderObject = welderObj
    setmetatable(o,self)
    return o
end

function LincolnPowerWaveControlEIP:initWelder()
    --[[
    不仅要发机器人准备好信号，还要发灭弧信号,因为刚开机时可能存在有起弧信号，
    导致这个原因是正常起弧焊接时，在需要发送断弧的时没有发成功
    ]]--
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":initWelder->before write")
    local ret1 = self:innerUpdateOutputValue_Address(0,{0,0},function(oldV,newV)
                                                        local v = oldV[1]
                                                        v = v&(~(1<<0)) --灭弧
                                                        v = v&(~(1<<1)) --Process Stop
                                                        
                                                        local v2 = oldV[2]
                                                        v2 = v2&(~(1<<0)) --停止气检
                                                        v2 = v2&(~(1<<1)) --停止送丝
                                                        v2 = v2&(~(1<<2)) --停止退丝
                                                        v2 = v2&(~(1<<4)) --接触传感使能关闭
                                                        v2 = v2&(~(1<<6)) --不禁止起弧
                                                        v2 = v2|(1<<7) --清除错误，每次与焊机断开连接，焊机都会报错，每次连接都要清错
                                                        MyWelderDebugLog(welderName..":initWelder->write value1="..v..",v2="..v2)
                                                        return {v,v2}
                                                     end)
    Wait(500)
    local ret2 = self:innerUpdateOutputValue_Address(1,{0},function(oldV,newV)
                                                        local v = oldV[1]
                                                        v = v&(~(1<<7)) --恢复清除错误
                                                        MyWelderDebugLog(welderName..":initWelder->write value="..v)
                                                        return {v}
                                                     end)
    return ret1 or ret2
end

function LincolnPowerWaveControlEIP:isWelderReady()
    local newVal = self:innerReadInputValue_Address(1,1) or {}
    if #newVal<1 then
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":isWelderReady->read fail,return value is nil")
        return false
    end
    return newVal[1]&0xC1==0xC1
end

function LincolnPowerWaveControlEIP:setWeldCurrent(newVal)
    return true --暂时不支持设置
end

function LincolnPowerWaveControlEIP:setArcStartCurrent(newVal)
    return true --暂时不支持设置
end

function LincolnPowerWaveControlEIP:setArcEndCurrent(newVal)
    return true --暂时不支持设置
end

function LincolnPowerWaveControlEIP:getWeldCurrent()
    local newVal = self:innerReadInputValue_Address(6,2) or {}
    if #newVal<2 then
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":getWeldCurrent->read fail,return value is nil")
        return nil
    end
    return innerCurrent_Welder2Locale(innerByte2Short(newVal))
end

function LincolnPowerWaveControlEIP:setWeldVoltage(newVal)
    return true --暂时不支持设置
end

function LincolnPowerWaveControlEIP:setArcStartVoltage(newVal)
    return true --暂时不支持设置
end

function LincolnPowerWaveControlEIP:setArcEndVoltage(newVal)
    return true --暂时不支持设置
end

function LincolnPowerWaveControlEIP:getWeldVoltage()
    local newVal = self:innerReadInputValue_Address(4,2) or {}
    if #newVal<2 then
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":getWeldVoltage->read fail,return value is nil")
        return nil
    end
    return innerVoltage_Welder2Locale(innerByte2Short(newVal))
end

function LincolnPowerWaveControlEIP:getWeldWireFeedSpeed()
    local newVal = self:innerReadInputValue_Address(10,2) or {}
    if #newVal<2 then
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":getWeldWireFeedSpeed->read fail,return value is nil")
        return nil
    end
    return innerWireFeedSpeed_Welder2Locale(innerByte2Short(newVal))
end

function LincolnPowerWaveControlEIP:setJobId(newVal)
    local welderName = self.welderObject.welderName
    if nil == newVal then
        local params = self.welderObject:getWelderParamObject():getJobModeParam()
        newVal = params.jobId
    end
    if newVal<1 or newVal>1000 then
        MyWelderDebugLog(welderName..Language.trLang("WELDER_JOBNUMBER_ERR")..":jobId="..tostring(newVal))
        return false
    end
    MyWelderDebugLog(welderName..":setJobId->before write,jobId="..tostring(newVal))
    newVal = innerShort2Byte(newVal)
    return self:innerWriteOutputValue_Address(2,newVal)
end

function LincolnPowerWaveControlEIP:arcStart()
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

function LincolnPowerWaveControlEIP:isArcStarted()
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

function LincolnPowerWaveControlEIP:arcEnd()
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

function LincolnPowerWaveControlEIP:isArcEnded()
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

function LincolnPowerWaveControlEIP:hasEndArcByMannual()
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

function LincolnPowerWaveControlEIP:startWireFeed()
    local newVal = 1<<1
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":startWireFeed->before write")
    return self:innerUpdateOutputValue_Address(1,{0},function(oldV,newV)
                                                            local v = (oldV[1]|(1<<1))&0x00FF
                                                            MyWelderDebugLog(welderName..":startWireFeed->write value="..v)
                                                            return {v}
                                                         end)
end
function LincolnPowerWaveControlEIP:stopWireFeed()
    local newVal = (~(1<<1))&0xFFFF
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":stopWireFeed->before write")
    return self:innerUpdateOutputValue_Address(1,{0},function(oldV,newV)
                                                            local v = (oldV[1]&(~(1<<1)))&0x00FF
                                                            MyWelderDebugLog(welderName..":stopWireFeed->write value="..v)
                                                            return {v}
                                                         end)
end

function LincolnPowerWaveControlEIP:startWireBack()
    local newVal = 1<<2
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":startWireBack->before write")
    return self:innerUpdateOutputValue_Address(1,{0},function(oldV,newV)
                                                            local v = (oldV[1]|(1<<2))&0x00FF
                                                            MyWelderDebugLog(welderName..":startWireBack->write value="..v)
                                                            return {v}
                                                         end)
end
function LincolnPowerWaveControlEIP:stopWireBack()
    local newVal = (~(1<<2))&0xFFFF
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":stopWireBack->before write")
    return self:innerUpdateOutputValue_Address(1,{0},function(oldV,newV)
                                                            local v = (oldV[1]&(~(1<<2)))&0x00FF
                                                            MyWelderDebugLog(welderName..":stopWireBack->write value="..v)
                                                            return {v}
                                                         end)
end

function LincolnPowerWaveControlEIP:startGasCheck()
    local newVal = 1<<0
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":startGasCheck->before write")
    return self:innerUpdateOutputValue_Address(1,{0},function(oldV,newV)
                                                            local v = (oldV[1]|(1<<0))&0x00FF
                                                            MyWelderDebugLog(welderName..":startGasCheck->write value="..v)
                                                            return {v}
                                                         end)
end
function LincolnPowerWaveControlEIP:stopGasCheck()
    local newVal = (~(1<<0))&0xFFFF
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":stopGasCheck->before write")
    return self:innerUpdateOutputValue_Address(1,{0},function(oldV,newV)
                                                            local v = (oldV[1]&(~(1<<0)))&0x00FF
                                                            MyWelderDebugLog(welderName..":stopGasCheck->write value="..v)
                                                            return {v}
                                                         end)
end

function LincolnPowerWaveControlEIP:getWelderRunStateInfo()
    local info = {connectState = false}
    --一次性读取所有的数据
    local newVal = self:innerReadInputValue_Address(0,12) or {}
    if #newVal<12 then return info end
    
    local v = innerByte2Short({newVal[1],newVal[2]})
    
    if newVal[2]&0xC1==0xC1 then info.connectState = true
    else info.connectState = false
    end
    
    v = innerByte2Short({newVal[5],newVal[6]})
    info.weldVoltage = innerVoltage_Welder2Locale(v)
    v = innerByte2Short({newVal[7],newVal[8]})
    info.weldCurrent = innerCurrent_Welder2Locale(v)
    v = innerByte2Short({newVal[11],newVal[12]})
    info.wireFeedSpeed = innerWireFeedSpeed_Welder2Locale(v)

    v = newVal[1]
    if (v&0x01)==0x01 then info.weldState = 1
    else info.weldState = 0
    end
    
    return info
end

return LincolnPowerWaveControlEIP