--[[焊机接口，继承自`WelderControlEIP`
configAssemblyId=128
outputAssemblyId=112
inputAssemblyId=100
outputAssemblySize=26
inputAssemblySize=20
]]--

--【本地私有接口】--
--本地电流值转换为焊机想要的电流值
local function innerCurrent_Locale2Welder(newVal)
    return newVal*10
end
--焊机电流转换为本地想要的电流值
local function innerCurrent_Welder2Locale(newVal)
    newVal = CHelperTools.ToInt16(newVal)
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
local MillerWelderControlEIP = WelderControlEIP:new()
MillerWelderControlEIP.__index = MillerWelderControlEIP

-------------------------------------------------------------------------------------------------------------------
--【对内不公开接口，只给本身和派生类使用】-----------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------
--【对外公开接口】-------------------------------------------------------------------------------------------------
function MillerWelderControlEIP:new(welderObj)
    local o = WelderControlEIP:new()
    o.welderObject = welderObj
    setmetatable(o,self)
    return o
end

function MillerWelderControlEIP:initWelder()
    --[[
    不仅要发机器人准备好信号，还要发灭弧信号,因为刚开机时可能存在有起弧信号，
    导致这个原因是正常起弧焊接时，在需要发送断弧的时没有发成功
    ]]--
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":initWelder->before write")
    local ret1 = self:innerUpdateOutputValue_Address(0,{0,0},function(oldV,newV)
                                                        local v = innerByte2Short(oldV)
                                                        v = v&(~(1<<1)) --停止退丝
                                                        v = v&(~(1<<2)) --停止送丝
                                                        v = v&(~(1<<3)) --停止气检
                                                        v = v&(~(1<<4)) --不禁止起弧
                                                        v = v&(~(1<<9)) --灭弧
                                                        v = v|(1<<8) --清除错误，每次与焊机断开连接，焊机都会报错，每次连接都要清错
                                                        v = v&(~(1<<11)) --接触传感使能关闭
                                                        MyWelderDebugLog(welderName..":initWelder->write value="..v)
                                                        return innerShort2Byte(v)
                                                     end)
    Wait(500)
    local ret2 = self:innerUpdateOutputValue_Address(0,{0,0},function(oldV,newV)
                                                        local v = innerByte2Short(oldV)
                                                        v = v&(~(1<<8)) --恢复清除错误
                                                        MyWelderDebugLog(welderName..":initWelder->write value="..v)
                                                        return innerShort2Byte(v)
                                                     end)
    return ret1 or ret2
end

function MillerWelderControlEIP:isWelderReady()
    local newVal = self:innerReadInputValue_Address(0,2) or {}
    if #newVal<2 then
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":isWelderReady->read fail,return value is nil")
        return false
    end
    newVal = innerByte2Short(newVal)
    return newVal~=0 --((newVal>>9)&0x01)==0x01
end

function MillerWelderControlEIP:setWeldCurrent(newVal)
    return true --暂时不支持设置
end

function MillerWelderControlEIP:setArcStartCurrent(newVal)
    return true --暂时不支持设置
end

function MillerWelderControlEIP:setArcEndCurrent(newVal)
    return true --暂时不支持设置
end

function MillerWelderControlEIP:getWeldCurrent()
    local newVal = self:innerReadInputValue_Address(4,2) or {}
    if #newVal<2 then
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":getWeldCurrent->read fail,return value is nil")
        return nil
    end
    return innerCurrent_Welder2Locale(innerByte2Short(newVal))
end

function MillerWelderControlEIP:setWeldVoltage(newVal)
    return true --暂时不支持设置
end

function MillerWelderControlEIP:setArcStartVoltage(newVal)
    return true --暂时不支持设置
end

function MillerWelderControlEIP:setArcEndVoltage(newVal)
    return true --暂时不支持设置
end

function MillerWelderControlEIP:getWeldVoltage()
    local newVal = self:innerReadInputValue_Address(6,2) or {}
    if #newVal<2 then
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":getWeldVoltage->read fail,return value is nil")
        return nil
    end
    return innerVoltage_Welder2Locale(innerByte2Short(newVal))
end

function MillerWelderControlEIP:getWeldWireFeedSpeed()
    local newVal = self:innerReadInputValue_Address(2,2) or {}
    if #newVal<2 then
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":getWeldWireFeedSpeed->read fail,return value is nil")
        return nil
    end
    return innerWireFeedSpeed_Welder2Locale(innerByte2Short(newVal))
end

function MillerWelderControlEIP:setProcessNumber(newVal)
    --[[
    local welderName = self.welderObject.welderName
    if nil == newVal then
        local params = self.welderObject:getWelderParamObject():getJobModeParam()
        newVal = params.processNumber
    end
    if newVal<1 or newVal>98 then
        MyWelderDebugLog(welderName..Language.trLang("WELDER_PROGRAM_NUM_ERR").."processNumber="..tostring(newVal))
        return false
    end
    MyWelderDebugLog(welderName..":setProcessNumber->before write,processNumber="..tostring(newVal))
    newVal = innerShort2Byte(newVal)
    return self:innerWriteOutputValue_Address(8,newVal)
    ]]--
    return true
end

function MillerWelderControlEIP:setJobId(newVal)
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
    newVal = innerShort2Byte(newVal)
    --return self:innerWriteOutputValue_Address(22,newVal)
    return self:innerWriteOutputValue_Address(8,newVal) --此款焊机特殊，使用程序号代替job号
end

function MillerWelderControlEIP:arcStart()
    local newVal = 1<<9
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":arcStart->before write")
    return self:innerUpdateOutputValue_Address(0,{0,0},function(oldV,newV)
                                                          local v = innerByte2Short(oldV)
                                                          v = v|(1<<9)
                                                          MyWelderDebugLog(welderName..":arcStart->write value="..v)
                                                          return innerShort2Byte(v)
                                                       end)
end

function MillerWelderControlEIP:isArcStarted()
    local welderName = self.welderObject.welderName
    local newVal = self:innerReadInputValue_Address(0,2) or {}
    if #newVal<2 then
        MyWelderDebugLog(welderName..":isArcStarted->read fail,return value is nil")
        return nil
    end
    newVal = innerByte2Short(newVal)
    local state = ((newVal>>10)&0x01)==0x01
    MyWelderDebugLog(string.format("%s:isArcStarted->read ok,newVal=0x%X, state=%s",welderName,newVal, tostring(state)))
    return state
end

function MillerWelderControlEIP:arcEnd()
    local newVal = (~(1<<9))&0x00FFFF
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":arcEnd->before write")
    return self:innerUpdateOutputValue_Address(0,{0,0},function(oldV,newV)
                                                          local v = innerByte2Short(oldV)
                                                          v = v&((~(1<<9))&0x00FFFF)
                                                          MyWelderDebugLog(welderName..":arcEnd->write value="..v)
                                                          return innerShort2Byte(v)
                                                       end)
end

function MillerWelderControlEIP:isArcEnded()
    local welderName = self.welderObject.welderName
    local newVal = self:innerReadInputValue_Address(0,2) or {}
    if #newVal<2 then
        MyWelderDebugLog(welderName..":isArcEnded->read fail,return value is nil")
        return nil
    end
    newVal = innerByte2Short(newVal)
    local state = ((newVal>>10)&0x01)==0x00
    MyWelderDebugLog(string.format("%s:isArcEnded->read ok,newVal=0x%X, state=%s",welderName,newVal, tostring(state)))
    return state
end

function MillerWelderControlEIP:hasEndArcByMannual()
    local welderName = self.welderObject.welderName
    local newVal = self:innerReadOutputValue_Address(0,2) or {}
    if #newVal<2 then
        MyWelderDebugLog(welderName..":hasEndArcByMannual->read fail,return value is nil")
        return nil
    end
    newVal = innerByte2Short(newVal)
    local state = ((newVal>>9)&0x01)==0x00
    MyWelderDebugLog(string.format("%s:hasEndArcByMannual->read ok,newVal=0x%X, state=%s",welderName,newVal, tostring(state)))
    return state
end

function MillerWelderControlEIP:startWireFeed()
    local newVal = 1<<2
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":startWireFeed->before write")
    return self:innerUpdateOutputValue_Address(0,{0},function(oldV,newV)
                                                            local v = (oldV[1]|(1<<2))&0x00FF
                                                            MyWelderDebugLog(welderName..":startWireFeed->write value="..v)
                                                            return {v}
                                                         end)
end
function MillerWelderControlEIP:stopWireFeed()
    local newVal = (~(1<<2))&0xFFFF
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":stopWireFeed->before write")
    return self:innerUpdateOutputValue_Address(0,{0},function(oldV,newV)
                                                            local v = (oldV[1]&(~(1<<2)))&0x00FF
                                                            MyWelderDebugLog(welderName..":stopWireFeed->write value="..v)
                                                            return {v}
                                                         end)
end

function MillerWelderControlEIP:startWireBack()
    local newVal = 1<<1
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":startWireBack->before write")
    return self:innerUpdateOutputValue_Address(0,{0},function(oldV,newV)
                                                            local v = (oldV[1]|(1<<1))&0x00FF
                                                            MyWelderDebugLog(welderName..":startWireBack->write value="..v)
                                                            return {v}
                                                         end)
end
function MillerWelderControlEIP:stopWireBack()
    local newVal = (~(1<<1))&0xFFFF
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":stopWireBack->before write")
    return self:innerUpdateOutputValue_Address(0,{0},function(oldV,newV)
                                                            local v = (oldV[1]&(~(1<<1)))&0x00FF
                                                            MyWelderDebugLog(welderName..":stopWireBack->write value="..v)
                                                            return {v}
                                                         end)
end

function MillerWelderControlEIP:isWireHasSignal()
    local welderName = self.welderObject.welderName
    local newVal = self:innerReadInputValue_Address(0,1) or {}
    if #newVal<1 then --默认操作失败为无信号
        MyWelderDebugLog(welderName..":isGasHasSignal->read fail,return value is nil")
        return nil
    end
    local state = newVal[1]&0x06~=0x00 --bit1/2有信号即可
    MyWelderDebugLog(string.format("%s:isGasHasSignal->read ok,newVal=0x%X, state=%s",welderName,newVal[1], tostring(state)))
    return state
end

function MillerWelderControlEIP:startGasCheck()
    local newVal = 1<<3
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":startGasCheck->before write")
    return self:innerUpdateOutputValue_Address(0,{0},function(oldV,newV)
                                                            local v = (oldV[1]|(1<<3))&0x00FF
                                                            MyWelderDebugLog(welderName..":startGasCheck->write value="..v)
                                                            return {v}
                                                         end)
end
function MillerWelderControlEIP:stopGasCheck()
    local newVal = (~(1<<3))&0xFFFF
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":stopGasCheck->before write")
    return self:innerUpdateOutputValue_Address(0,{0},function(oldV,newV)
                                                            local v = (oldV[1]&(~(1<<3)))&0x00FF
                                                            MyWelderDebugLog(welderName..":stopGasCheck->write value="..v)
                                                            return {v}
                                                         end)
end

function MillerWelderControlEIP:isGasHasSignal()
    local welderName = self.welderObject.welderName
    local newVal = self:innerReadInputValue_Address(0,1) or {}
    if #newVal<1 then --默认操作失败为无信号
        MyWelderDebugLog(welderName..":isGasHasSignal->read fail,return value is nil")
        return nil
    end
    local state = ((newVal[1]>>3)&0x01)==0x01
    MyWelderDebugLog(string.format("%s:isGasHasSignal->read ok,newVal=0x%X, state=%s",welderName,newVal[1], tostring(state)))
    return state
end

function MillerWelderControlEIP:getWelderRunStateInfo()
    local info = {connectState = false}
    --一次性读取所有的数据
    local newVal = self:innerReadInputValue_Address(0,18) or {}
    if #newVal<18 then return info end
    
    local v = innerByte2Short({newVal[1],newVal[2]})
    --[[
    if v~=0 then info.connectState = true
    else info.connectState = false
    end
    ]]--
    --非焊接状态下，即使连接上了，byte1和byte2也是0，很奇怪,所以判断返回数据只要有不等于0的就认为连接成功。
    info.connectState = false
    for i=1,#newVal do
        if newVal[i]~=0 then
            info.connectState = true
            break
        end
    end
    
    v = innerByte2Short({newVal[7],newVal[8]})
    info.weldVoltage = innerVoltage_Welder2Locale(v)
    v = innerByte2Short({newVal[5],newVal[6]})
    info.weldCurrent = innerCurrent_Welder2Locale(v)
    v = innerByte2Short({newVal[3],newVal[4]})
    info.wireFeedSpeed = innerWireFeedSpeed_Welder2Locale(v)
    v = innerByte2Short({newVal[9],newVal[10]})
    info.errcode = v
    v = innerByte2Short({newVal[1],newVal[2]})
    if (v>>10)==0x01 then info.weldState = 1
    else info.weldState = 0
    end
    
    return info
end

function MillerWelderControlEIP:getWelderErrCode()
    local newVal = self:innerReadInputValue_Address(8,2) or {}
    if #newVal<2 then
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":getWelderErrCode->read fail,return value is nil")
        return nil
    end
    newVal = innerByte2Short(newVal)
    return newVal
end

return MillerWelderControlEIP