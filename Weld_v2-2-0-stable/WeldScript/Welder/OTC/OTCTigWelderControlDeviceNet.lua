--[[焊机DeviceNet接口，继承自`WelderControlDeviceNet`]]--

--【本地私有接口】--
--本地电流值转换为焊机想要的电流值
local function innerCurrent_Locale2Welder(newVal,mode)
    if newVal<0 then newVal=0 end
    if newVal>350 then newVal=350 end
    return newVal*10
end
--焊机电流转换为本地想要的电流值
local function innerCurrent_Welder2Locale(newVal)
    newVal = CHelperTools.ToInt16(newVal)
    return newVal
end

--本地电压值转换为焊机想要的电压值
local function innerVoltage_Locale2Welder(newVal)
    return newVal
end
--焊机电压转换为本地想要的电压值
local function innerVoltage_Welder2Locale(newVal)
    newVal = CHelperTools.ToInt16(newVal)
    return newVal*0.1
end

--本地送丝速度转换为想要焊机的速度值
local function innerWireFeedSpeed_Locale2Welder(newVal)
    return newVal*10
end
--焊机送丝速度转换为本地想要的速度值
local function innerWireFeedSpeed_Welder2Locale(newVal)
    newVal = CHelperTools.ToInt16(newVal)
    return newVal*0.1
end

--[[
功能：4个函数视图值的设置
参数：newNo-编号,整数
      newVal-对应的值
      bIsDisplayView-是否显示视图,true显示,false或不填为不显示
返回值：true表示成功，false表示失败
]]--
local function innerSetFunctionView1(self, newNo, newVal, bIsDisplayView)
    MyWelderDebugLog(string.format("innerSetFunctionView1(newNo=%s,newVal=%s,bIsDisplayView=%s)",tostring(newNo),tostring(newVal),tostring(bIsDisplayView)))
    local iStartAddr = 9
    local data = self:innerGetHoldRegsValue_Address(iStartAddr,2) or {}
    if #data<2 then
        MyWelderDebugLog("innerSetFunctionView1->read fail,return value is nil")
        return nil
    end
    newNo = math.floor(newNo)
    newVal = math.floor(newVal)
    --设置编号值,并显示视图bit7=1
    if bIsDisplayView then newNo = (newNo&0x00FF)|0x80
    else newNo = newNo&0x00FF
    end
    local vL = newVal&0x00FF
    local vH = (newVal>>8)&0x00FF
    data[1] = (data[1]&0xFF00)|newNo
    data[1] = (data[1]&0x00FF)|((vL<<8)&0xFF00)
    data[2] = (data[2]&0xFF00)|vH
    return self:innerSetHoldRegsValue_Address(iStartAddr,data)
end
local function innerSetFunctionView2(self, newNo, newVal, bIsDisplayView)
    MyWelderDebugLog(string.format("innerSetFunctionView2(newNo=%s,newVal=%s,bIsDisplayView=%s)",tostring(newNo),tostring(newVal),tostring(bIsDisplayView)))
    local iStartAddr = 10
    local data = self:innerGetHoldRegsValue_Address(iStartAddr,2) or {}
    if #data<2 then
        MyWelderDebugLog("innerSetFunctionView2->read fail,return value is nil")
        return nil
    end
    newNo = math.floor(newNo)
    newVal = math.floor(newVal)
    --设置编号值,并显示视图bit7=1
    if bIsDisplayView then newNo = (newNo&0x00FF)|0x80
    else newNo = newNo&0x00FF
    end
    data[1] = (data[1]&0x00FF)|((newNo<<8)&0xFF00)
    data[2] = newVal&0xFFFF
    return self:innerSetHoldRegsValue_Address(iStartAddr,data)
end
local function innerSetFunctionView3(self, newNo, newVal, bIsDisplayView)
    MyWelderDebugLog(string.format("innerSetFunctionView3(newNo=%s,newVal=%s,bIsDisplayView=%s)",tostring(newNo),tostring(newVal),tostring(bIsDisplayView)))
    local iStartAddr = 12
    local data = self:innerGetHoldRegsValue_Address(iStartAddr,2) or {}
    if #data<2 then
        MyWelderDebugLog("innerSetFunctionView3->read fail,return value is nil")
        return nil
    end
    newNo = math.floor(newNo)
    newVal = math.floor(newVal)
    --设置编号值,并显示视图bit7=1
    if bIsDisplayView then newNo = (newNo&0x00FF)|0x80
    else newNo = newNo&0x00FF
    end
    local vL = newVal&0x00FF
    local vH = (newVal>>8)&0x00FF
    data[1] = (data[1]&0xFF00)|newNo
    data[1] = (data[1]&0x00FF)|((vL<<8)&0xFF00)
    data[2] = (data[2]&0xFF00)|vH
    return self:innerSetHoldRegsValue_Address(iStartAddr,data)
end
local function innerSetFunctionView4(self, newNo, newVal, bIsDisplayView)
    MyWelderDebugLog(string.format("innerSetFunctionView4(newNo=%s,newVal=%s,bIsDisplayView=%s)",tostring(newNo),tostring(newVal),tostring(bIsDisplayView)))
    local iStartAddr = 13
    local data = self:innerGetHoldRegsValue_Address(iStartAddr,2) or {}
    if #data<2 then
        MyWelderDebugLog("innerSetFunctionView4->read fail,return value is nil")
        return nil
    end
    newNo = math.floor(newNo)
    newVal = math.floor(newVal)
    --设置编号值,并显示视图bit7=1
    if bIsDisplayView then newNo = (newNo&0x00FF)|0x80
    else newNo = newNo&0x00FF
    end
    data[1] = (data[1]&0x00FF)|((newNo<<8)&0xFF00)
    data[2] = newVal&0xFFFF
    return self:innerSetHoldRegsValue_Address(iStartAddr,data)
end

--OTC焊机有watchdog技术，0.5~1.0s之内周期性的轮流置位bit7为0/1，这样当焊机与机器人失去连接时机器人自己中断焊接。
local function innerWatchDogMonitor(self)
    if self.watchdog~=1 then self.watchdog=1
    else self.watchdog=0
    end
    return self:innerUpdateHoldRegsValue_Address(0,self.watchdog,function(oldV,newV)
                                                                    if 1==newV then return oldV|0x0080 end
                                                                    return oldV&0xFF7F
                                                                 end)
end

-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
--【业务实现接口】-------------------------------------------------------------------------------------------------
local OTCTigWelderControlDeviceNet = WelderControlDeviceNet:new()
OTCTigWelderControlDeviceNet.__index = OTCTigWelderControlDeviceNet

-------------------------------------------------------------------------------------------------------------------
--【对内不公开接口，只给本身和派生类使用】-----------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------
--【对外公开接口】-------------------------------------------------------------------------------------------------
function OTCTigWelderControlDeviceNet:new(welderObj)
    local o = WelderControlDeviceNet:new()
    o.welderObject = welderObj
    o.watchdog = 0
    setmetatable(o,self)
    return o
end

function OTCTigWelderControlDeviceNet:initWelder()
    --[[
    不仅要发机器人准备好信号，还要发灭弧信号,因为刚开机时可能存在有起弧信号，
    导致这个原因是正常起弧焊接时，在需要发送断弧的时没有发成功
    ]]--
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":initWelder->before write")
    local data = self:innerGetHoldRegsValue_Address(0,2) or {}
    if #data<2 then --失败了那就一个一个设置吧
        local ok1 = self:innerUpdateHoldRegsValue_Address(0,0x00,function(oldV,newV)
                                                                    local v = newV
                                                                    v = v&(~(1<<0)) --灭弧
                                                                    v = v&(~(1<<1)) --停止送丝
                                                                    v = v&(~(1<<2)) --停止退丝
                                                                    v = v&(~(1<<3)) --停止气检
                                                                    MyWelderDebugLog(welderName..":initWelder->write value="..v)
                                                                    return v
                                                                 end)
        local ok2 = self:innerUpdateHoldRegsValue_Address(1,0x8000,function(oldV,newV)
                                                                    local v = oldV|newV --下发电流电压生效,更改设置允许
                                                                    MyWelderDebugLog(welderName..":initWelder->write value="..v)
                                                                    return v
                                                                 end)
        return (ok1 and ok2)
    end
    data[1] = data[1]&0xFFF0
    data[2] = data[2]|0x8000 --下发电流电压生效
    return self:innerSetHoldRegsValue_Address(0,data)
end

function OTCTigWelderControlDeviceNet:isWelderReady()
    local newVal = self:innerGetInRegsValue_Address(0) or {}
    if #newVal<1 then
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":isWelderReady->read fail,return value is nil")
        return nil
    end
    return (newVal[1]&0x0200)==0x0200
end

function OTCTigWelderControlDeviceNet:setWeldCurrent(newVal)
    local welderName = self.welderObject.welderName
    if nil == newVal then
        local params = self.welderObject:getWelderParamObject():getNotJobModeParam()
        if #params.params < 1 or params.selectedId<1 or params.selectedId > #params.params then
            MyWelderDebugLog(welderName..Language.trLang("WELDER_SET_WELD_CURRENT"))
            return false
        end
        newVal = params.params[params.selectedId].weldCurrent
    end
    local workMode = self.welderObject:getWelderParamObject():getWorkMode()
    MyWelderDebugLog(welderName..":setWeldCurrent->write value="..newVal..",workMode="..workMode)
    newVal = math.floor(innerCurrent_Locale2Welder(newVal,workMode))
    local data = self:innerGetHoldRegsValue_Address(4,2) or {}
    if #data<2 then
        MyWelderDebugLog(welderName..":setWeldCurrent->read fail,return value is nil")
        return nil
    end
    local vL = newVal&0x00FF
    local vH = (newVal>>8)&0x00FF
    data[1] = (data[1]&0x00FF)|((vL<<8)&0xFF00)
    data[2] = (data[2]&0xFF00)|vH
    return self:innerSetHoldRegsValue_Address(4,data)
end

function OTCTigWelderControlDeviceNet:setArcStartCurrent(newVal)
    local welderName = self.welderObject.welderName
    if nil == newVal then
        local params = self.welderObject:getWelderParamObject():getNotJobModeParam()
        if #params.params < 1 or params.selectedId<1 or params.selectedId > #params.params then
            MyWelderDebugLog(welderName..Language.trLang("WELDER_SET_ARC_CURRENT"))
            return false
        end
        newVal = params.params[params.selectedId].arcStartCurrent
    end
    local workMode = self.welderObject:getWelderParamObject():getWorkMode()
    MyWelderDebugLog(welderName..":setArcStartCurrent->write value="..newVal..",workMode="..workMode)
    newVal = math.floor(innerCurrent_Locale2Welder(newVal,workMode))
    local data = self:innerGetHoldRegsValue_Address(4,2) or {}
    if #data<2 then
        MyWelderDebugLog(welderName..":setArcStartCurrent->read fail,return value is nil")
        return nil
    end
    local vL = newVal&0x00FF
    local vH = (newVal>>8)&0x00FF
    data[1] = (data[1]&0x00FF)|((vL<<8)&0xFF00)
    data[2] = (data[2]&0xFF00)|vH
    return self:innerSetHoldRegsValue_Address(4,data)
end

function OTCTigWelderControlDeviceNet:setArcEndCurrent(newVal)
    local welderName = self.welderObject.welderName
    if nil == newVal then
        local params = self.welderObject:getWelderParamObject():getNotJobModeParam()
        if #params.params < 1 or params.selectedId<1 or params.selectedId > #params.params then
            MyWelderDebugLog(welderName..Language.trLang("WELDER_SET_END_CURRENT"))
            return false
        end
        newVal = params.params[params.selectedId].arcEndCurrent
    end
    local workMode = self.welderObject:getWelderParamObject():getWorkMode()
    MyWelderDebugLog(welderName..":setArcEndCurrent->write value="..newVal..",workMode="..workMode)
    newVal = math.floor(innerCurrent_Locale2Welder(newVal,workMode))
    local data = self:innerGetHoldRegsValue_Address(4,2) or {}
    if #data<2 then
        MyWelderDebugLog(welderName..":setArcEndCurrent->read fail,return value is nil")
        return nil
    end
    local vL = newVal&0x00FF
    local vH = (newVal>>8)&0x00FF
    data[1] = (data[1]&0x00FF)|((vL<<8)&0xFF00)
    data[2] = (data[2]&0xFF00)|vH
    return self:innerSetHoldRegsValue_Address(4,data)
end

function OTCTigWelderControlDeviceNet:getWeldCurrent()
    local newVal = self:innerGetInRegsValue_Address(4,2) or {}
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

--没有电压，不支持设置
function OTCTigWelderControlDeviceNet:setWeldVoltage(newVal)
    return true
end

function OTCTigWelderControlDeviceNet:setArcStartVoltage(newVal)
    return true
end

function OTCTigWelderControlDeviceNet:setArcEndVoltage(newVal)
    return true
end

function OTCTigWelderControlDeviceNet:getWeldVoltage()
    local newVal = self:innerGetInRegsValue_Address(6,2) or {}
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

function OTCTigWelderControlDeviceNet:setWeldWireFeedSpeed(newVal)
    local welderName = self.welderObject.welderName
    if nil == newVal then
        newVal = self.welderObject:getWelderParamObject():getOTCTigCtrlParam().wireFeedSpeed
    end
    MyWelderDebugLog(welderName..":setWeldWireFeedSpeed->before write,newVal="..tostring(newVal))
    newVal = math.floor(innerWireFeedSpeed_Locale2Welder(newVal))
    local data = self:innerGetHoldRegsValue_Address(5,2) or {}
    if #data<2 then
        MyWelderDebugLog(welderName..":setWeldWireFeedSpeed->read fail,return value is nil")
        return nil
    end
    local vL = newVal&0x00FF
    local vH = (newVal>>8)&0x00FF
    data[1] = (data[1]&0x00FF)|((vL<<8)&0xFF00)
    data[2] = (data[2]&0xFF00)|vH
    return self:innerSetHoldRegsValue_Address(5,data)
end

function OTCTigWelderControlDeviceNet:getWeldWireFeedSpeed()
    local newVal = self:innerGetInRegsValue_Address(5,2) or {}
    if #newVal<2 then
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":getWeldWireFeedSpeed->read fail,return value is nil")
        return nil
    end
    local vL = (newVal[1]>>8)&0x00FF
    local vH = newVal[2]&0x00FF
    newVal[1] = ((vH<<8)&0xFF00)|vL
    return innerWireFeedSpeed_Welder2Locale(newVal[1])
end

function OTCTigWelderControlDeviceNet:setWeldMode(newVal)
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
        dcTig = 0, --直流TIG
        acTig = 1, --交流TIG
        adcTig = 2, --AC-DC TIG
        plasma = 3 --等离子体
    }
    if mapper[params] then
        newVal = (mapper[params]<<2)&0x1C
        
        MyWelderDebugLog(welderName..":setWeldMode->before write,mode="..tostring(params))
        return self:innerUpdateHoldRegsValue_Address(2,newVal,function(oldV,newV)
                                                            local tmp=oldV&0xFFE3
                                                            tmp=tmp|newV
                                                            MyWelderDebugLog(welderName..":setWeldMode->write value="..tmp)
                                                            return tmp
                                                           end)
    else
        MyWelderDebugLog(welderName..Language.trLang("WELDER_FUNC_MODE_NO_SUPPORT")..tostring(params))
        return false
    end
end

function OTCTigWelderControlDeviceNet:setJobId(newVal)
    return true --暂时还不支持
end

function OTCTigWelderControlDeviceNet:arcStart()
    local newVal = 0x01
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":arcStart->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                        local v = oldV|newV
                                                        MyWelderDebugLog(welderName..":arcStart->write value="..v)
                                                        return v
                                                     end)
end

function OTCTigWelderControlDeviceNet:isArcStarted()
    local welderName = self.welderObject.welderName
    local newVal = self:innerGetInRegsValue_Address(0) or {}
    if #newVal<1 then
        MyWelderDebugLog(welderName..":isArcStarted->read fail,return value is nil")
        return nil
    end
    local state = (newVal[1]&0x0100)==0x0100
    MyWelderDebugLog(string.format("%s:isArcStarted->read ok,newVal[1]=0x%X, state=%s",welderName,newVal[1], tostring(state)))
    return state
end

function OTCTigWelderControlDeviceNet:arcEnd()
    local newVal = 0xFFFE
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":arcEnd->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                        local v = oldV&newV
                                                        MyWelderDebugLog(welderName..":arcEnd->write value="..v)
                                                        return v
                                                     end)
end

function OTCTigWelderControlDeviceNet:isArcEnded()
    local welderName = self.welderObject.welderName
    local newVal = self:innerGetInRegsValue_Address(0) or {}
    if #newVal<1 then
        MyWelderDebugLog(welderName..":isArcEnded->read fail,return value is nil")
        return nil
    end
    local state = (newVal[1]&0x0100)==0x00
    MyWelderDebugLog(string.format("%s:isArcEnded->read ok,newVal[1]=0x%X, state=%s",welderName,newVal[1], tostring(state)))
    return state
end

function OTCTigWelderControlDeviceNet:hasEndArcByMannual()
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

function OTCTigWelderControlDeviceNet:startWireFeed()
    local newVal = 0x02
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":startWireFeed->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                        local v = oldV|newV
                                                        MyWelderDebugLog(welderName..":startWireFeed->write value="..v)
                                                        return v
                                                     end)
end
function OTCTigWelderControlDeviceNet:stopWireFeed()
    local newVal = 0xFFFD
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":stopWireFeed->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                        local v = oldV&newV
                                                        MyWelderDebugLog(welderName..":stopWireFeed->write value="..v)
                                                        return v
                                                     end)
end

function OTCTigWelderControlDeviceNet:startWireBack()
    local newVal = 0x04
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":startWireBack->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                        local v = oldV|newV
                                                        MyWelderDebugLog(welderName..":startWireBack->write value="..v)
                                                        return v
                                                     end)
end
function OTCTigWelderControlDeviceNet:stopWireBack()
    local newVal = 0xFFFB
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":stopWireBack->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                        local v = oldV&newV
                                                        MyWelderDebugLog(welderName..":stopWireBack->write value="..v)
                                                        return v
                                                     end)
end

function OTCTigWelderControlDeviceNet:startGasCheck()
    local newVal = 0x08
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":startGasCheck->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                        local v = oldV|newV
                                                        MyWelderDebugLog(welderName..":startGasCheck->write value="..v)
                                                        return v
                                                     end)
end
function OTCTigWelderControlDeviceNet:stopGasCheck()
    local newVal = 0xFFF7
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":stopGasCheck->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                        local v = oldV&newV
                                                        MyWelderDebugLog(welderName..":stopGasCheck->write value="..v)
                                                        return v
                                                     end)
end

function OTCTigWelderControlDeviceNet:getWelderRunStateInfo()
    innerWatchDogMonitor(self) --监控watchdog
    
    local info = {connectState = false}
    --一次性读取所有的数据
    local newVal = self:innerGetInRegsValue_Address(0,9) or {}
    if #newVal<9 then return info end
    
    --if (newVal[1]&0x0200)==0x0200 then info.connectState = true
    if newVal[1]~=0x00 then info.connectState = true --只要不等于0都表示连接上了
    else info.connectState = false
    end
    
    local vL = (newVal[5]>>8)&0x00FF
    local vH = newVal[6]&0x00FF
    local tmpValue = ((vH<<8)&0xFF00)|vL
    info.weldCurrent = innerCurrent_Welder2Locale(tmpValue)
    
    vL = (newVal[6]>>8)&0x00FF
    vH = newVal[7]&0x00FF
    tmpValue = ((vH<<8)&0xFF00)|vL
    info.wireFeedSpeed = innerWireFeedSpeed_Welder2Locale(tmpValue)
    
    vL = (newVal[7]>>8)&0x00FF
    vH = newVal[8]&0x00FF
    tmpValue = ((vH<<8)&0xFF00)|vL
    info.weldVoltage = innerVoltage_Welder2Locale(tmpValue)
    
    if (newVal[1]&0x0100)==0x0100 then info.weldState = 1
    else info.weldState = 0
    end

--[[
    --调试信息，可以删掉
    if (newVal[1]>>1)&0x01==0x01 then info.wireFeed="on"
    else info.wireFeed="off"
    end
    if (newVal[1]>>2)&0x01==0x01 then info.wireBack="on"
    else info.wireBack="off"
    end
    if (newVal[1]>>3)&0x01==0x01 then info.gas="on"
    else info.gas="off"
    end
    info.jobId = newVal[2]&0xFF
    info.weldMethod = (newVal[3]>>2)&0x07
    info.hasPulse = (newVal[3]>>7)&0x01
    info.clearWidth = CHelperTools.ToInt8((newVal[4]>>8)&0xFF)
    info.peakCurrent = info.weldVoltage
    info.pulseFreq = CHelperTools.ToInt16(newVal[9]&0xFFFF)
]]--    
    return info
end

function OTCTigWelderControlDeviceNet:getWelderErrCode()
    local newVal = self:innerGetInRegsValue_Address(15) or {}
    if #newVal<1 then
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":getWelderErrCode->read fail,return value is nil")
        return nil
    end
    newVal = CHelperTools.ToInt16(newVal[1])
    return newVal
end

--=============================================================================================================================
--*****************************************************************************************************************************
--*****************************************************************************************************************************
--OTC-TIG焊机特有的协议属性****************************************************************************************************
--[[
功能：设置清理宽度
参数：newVal-清理宽度值
返回值：true表示成功，false表示失败
]]--
function OTCTigWelderControlDeviceNet:setClearWidth(newVal)
    local welderName = self.welderObject.welderName
    if nil == newVal then
        newVal = self.welderObject:getWelderParamObject():getOTCTigCtrlParam().clearWidth
    end
    MyWelderDebugLog(welderName..":setClearWidth->before write,newVal="..tostring(newVal))
    newVal = math.floor(newVal)&0x00FF
    newVal = newVal<<8
    return self:innerUpdateHoldRegsValue_Address(3,newVal,function(oldV,newV)
                                                            local tmp=oldV&0x00FF
                                                            tmp=tmp|newV
                                                            MyWelderDebugLog(welderName..":setClearWidth->write value="..tmp)
                                                            return tmp
                                                           end)
end

--[[
功能：设置有无脉冲
参数：newVal-有无脉冲值,0-表示无脉冲，非0表示有脉冲
返回值：true表示成功，false表示失败
]]--
function OTCTigWelderControlDeviceNet:setHasPulse(newVal)
    local welderName = self.welderObject.welderName
    if nil == newVal then
        newVal = self.welderObject:getWelderParamObject():getOTCTigCtrlParam().pulseConfig
    end
    MyWelderDebugLog(welderName..":setClearWidth->before write,newVal="..tostring(newVal))
    newVal = math.floor(newVal)
    if newVal~=0 then --有脉冲
        return self:innerUpdateHoldRegsValue_Address(2,0x0100,function(oldV,newV)
                                                                local tmp=oldV|newV
                                                                MyWelderDebugLog(welderName..":setClearWidth->write value="..tmp)
                                                                return tmp
                                                              end)
    else --无脉冲
        return self:innerUpdateHoldRegsValue_Address(2,0xFEFF,function(oldV,newV)
                                                                local tmp=oldV&newV
                                                                MyWelderDebugLog(welderName..":setClearWidth->write value="..tmp)
                                                                return tmp
                                                              end)
    end
end

--[[
功能：设置脉冲频率
参数：newVal-频率值
返回值：true表示成功，false表示失败
]]--
function OTCTigWelderControlDeviceNet:setPulseFrequence(newVal)
    local welderName = self.welderObject.welderName
    if nil == newVal then
        newVal = self.welderObject:getWelderParamObject():getOTCTigCtrlParam().pulseFreq
    end
    MyWelderDebugLog(welderName..":setPulseFrequence->before write,newVal="..tostring(newVal))
    newVal = math.floor(newVal*10) --注意倍率关系
    return self:innerUpdateHoldRegsValue_Address(8,newVal,nil)
end

--[[
功能：设置峰值电流
参数：newVal-电流值
返回值：true表示成功，false表示失败
]]--
function OTCTigWelderControlDeviceNet:setPeakCurrent(newVal)
    local welderName = self.welderObject.welderName
    if nil == newVal then
        newVal = self.welderObject:getWelderParamObject():getOTCTigCtrlParam().peakCurrent
    end
    MyWelderDebugLog(welderName..":setPeakCurrent->before write,newVal="..tostring(newVal))
    newVal = math.floor(newVal*10) --注意倍率关系
    local data = self:innerGetHoldRegsValue_Address(6,2) or {}
    if #data<2 then
        MyWelderDebugLog(welderName..":setPeakCurrent->read fail,return value is nil")
        return nil
    end
    local vL = newVal&0x00FF
    local vH = (newVal>>8)&0x00FF
    data[1] = (data[1]&0x00FF)|((vL<<8)&0xFF00)
    data[2] = (data[2]&0xFF00)|vH
    return self:innerSetHoldRegsValue_Address(6,data)
end

--[[
功能：通用功能函数单个参数设置
参数：newNo-编号
      newVal-对应编号的值
返回值：true表示成功，false表示失败
]]--
function OTCTigWelderControlDeviceNet:setFunctionView1(newNo, newVal)
    return innerSetFunctionView1(self, newNo, newVal, true)
end
function OTCTigWelderControlDeviceNet:setFunctionView2(newNo, newVal)
    return innerSetFunctionView2(self, newNo, newVal, true)
end
function OTCTigWelderControlDeviceNet:setFunctionView3(newNo, newVal)
    return innerSetFunctionView3(self, newNo, newVal, true)
end
function OTCTigWelderControlDeviceNet:setFunctionView4(newNo, newVal)
    return innerSetFunctionView4(self, newNo, newVal, true)
end

--通过 innerSetFunctionView设置的参数
--[[
local params = self.welderObject:getWelderParamObject():getNotJobModeParam()
newVal = params.params[params.selectedId].otc.preGasTime * 10
newVal = params.params[params.selectedId].otc.afterGasTime * 10

newVal = self.welderObject:getWelderParamObject():getOTCTigCtrlParam().acFreq * 10
newVal = self.welderObject:getWelderParamObject():getOTCTigCtrlParam().adcSwitchFreq * 10
newVal = self.welderObject:getWelderParamObject():getOTCTigCtrlParam().wireFeedDelayTime * 10
newVal = self.welderObject:getWelderParamObject():getOTCTigCtrlParam().wireFeedIntervalTime * 10
newVal = self.welderObject:getWelderParamObject():getOTCTigCtrlParam().stopWireFeedIntervalTime* 10

newVal = self.welderObject:getWelderParamObject():getOTCTigF45Param().slowUpTime * 10
newVal = self.welderObject:getWelderParamObject():getOTCTigF45Param().slowDownTime * 10
]]--
return OTCTigWelderControlDeviceNet