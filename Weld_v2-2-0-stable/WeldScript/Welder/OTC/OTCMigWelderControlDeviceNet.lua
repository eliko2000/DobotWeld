--[[焊机DeviceNet接口，继承自`WelderControlDeviceNet`]]--

--【本地私有接口】--
--本地电流值转换为焊机想要的电流值
local function innerCurrent_Locale2Welder(newVal)
    if newVal<20 then newVal=20 end
    if newVal>550 then newVal=550 end
    return newVal
end
--焊机电流转换为本地想要的电流值
local function innerCurrent_Welder2Locale(newVal)
    newVal = CHelperTools.ToInt16(newVal)
    return newVal
end

--本地电压值转换为焊机想要的电压值
local function innerVoltage_Locale2Welder(newVal,mode)
    if "respectively" == mode then --分别模式，范围值[10,50]
        if newVal<10 then newVal=10 end
        if newVal>50 then newVal=50 end
        return newVal*10
    else --monization 默认一元模式，范围值[-10,10]
        if newVal<-10 then newVal=-10 end
        if newVal>10 then newVal=10 end
        return newVal*10
    end
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
local OTCMigWelderControlDeviceNet = WelderControlDeviceNet:new()
OTCMigWelderControlDeviceNet.__index = OTCMigWelderControlDeviceNet

-------------------------------------------------------------------------------------------------------------------
--【对内不公开接口，只给本身和派生类使用】-----------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------
--【对外公开接口】-------------------------------------------------------------------------------------------------
function OTCMigWelderControlDeviceNet:new(welderObj)
    local o = WelderControlDeviceNet:new()
    o.welderObject = welderObj
    o.watchdog = 0
    setmetatable(o,self)
    return o
end

function OTCMigWelderControlDeviceNet:initWelder()
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

function OTCMigWelderControlDeviceNet:isWelderReady()
    local newVal = self:innerGetInRegsValue_Address(0) or {}
    if #newVal<1 then
        local welderName = self.welderObject.welderName
        MyWelderDebugLog(welderName..":isWelderReady->read fail,return value is nil")
        return nil
    end
    return (newVal[1]&0x0200)==0x0200
end

function OTCMigWelderControlDeviceNet:setWeldCurrent(newVal)
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

function OTCMigWelderControlDeviceNet:setArcStartCurrent(newVal)
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

function OTCMigWelderControlDeviceNet:setArcEndCurrent(newVal)
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

function OTCMigWelderControlDeviceNet:getWeldCurrent()
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

function OTCMigWelderControlDeviceNet:setWeldVoltage(newVal)
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
    if "monization"==workMode then --一元化模式
        return self:innerUpdateHoldRegsValue_Address(7,newVal,function(oldV,newV)
                                                                local v = oldV&0x00FF
                                                                v = v|((newV<<8)&0xFF00)
                                                                MyWelderDebugLog(welderName..":setWeldVoltage->write value="..v)
                                                                return v
                                                              end)
    elseif "respectively"==workMode then --分别模式
        local data = self:innerGetHoldRegsValue_Address(6,2) or {}
        if #data<2 then
            MyWelderDebugLog(welderName..":setWeldVoltage->read fail,return value is nil")
            return nil
        end
        local vL = newVal&0x00FF
        local vH = (newVal>>8)&0x00FF
        data[1] = (data[1]&0x00FF)|((vL<<8)&0xFF00)
        data[2] = (data[2]&0xFF00)|vH
        return self:innerSetHoldRegsValue_Address(6,data)
    end
    return true
end

function OTCMigWelderControlDeviceNet:setArcStartVoltage(newVal)
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
    if "monization"==workMode then --一元化模式
        return self:innerUpdateHoldRegsValue_Address(7,newVal,function(oldV,newV)
                                                                local v = oldV&0x00FF
                                                                v = v|((newV<<8)&0xFF00)
                                                                MyWelderDebugLog(welderName..":setArcStartVoltage->write value="..v)
                                                                return v
                                                              end)
    elseif "respectively"==workMode then --分别模式
        local data = self:innerGetHoldRegsValue_Address(6,2) or {}
        if #data<2 then
            MyWelderDebugLog(welderName..":setArcStartVoltage->read fail,return value is nil")
            return nil
        end
        local vL = newVal&0x00FF
        local vH = (newVal>>8)&0x00FF
        data[1] = (data[1]&0x00FF)|((vL<<8)&0xFF00)
        data[2] = (data[2]&0xFF00)|vH
        return self:innerSetHoldRegsValue_Address(6,data)
    end
    return true
end

function OTCMigWelderControlDeviceNet:setArcEndVoltage(newVal)
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
    if "monization"==workMode then --一元化模式
        return self:innerUpdateHoldRegsValue_Address(7,newVal,function(oldV,newV)
                                                                local v = oldV&0x00FF
                                                                v = v|((newV<<8)&0xFF00)
                                                                MyWelderDebugLog(welderName..":setArcEndVoltage->write value="..v)
                                                                return v
                                                              end)
    elseif "respectively"==workMode then --分别模式
        local data = self:innerGetHoldRegsValue_Address(6,2) or {}
        if #data<2 then
            MyWelderDebugLog(welderName..":setArcEndVoltage->read fail,return value is nil")
            return nil
        end
        local vL = newVal&0x00FF
        local vH = (newVal>>8)&0x00FF
        data[1] = (data[1]&0x00FF)|((vL<<8)&0xFF00)
        data[2] = (data[2]&0xFF00)|vH
        return self:innerSetHoldRegsValue_Address(6,data)
    end
    return true
end

function OTCMigWelderControlDeviceNet:getWeldVoltage()
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

function OTCMigWelderControlDeviceNet:setWeldWireFeedSpeed(newVal)
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":setWeldWireFeedSpeed->before write,newVal="..tostring(newVal))
    if nil == newVal then
        return true --设置为nil则认为不设置
    end
    newVal = math.floor(innerWireFeedSpeed_Locale2Welder(newVal))
    local data = self:innerGetHoldRegsValue_Address(4,3) or {}
    if #data<3 then
        MyWelderDebugLog(welderName..":setWeldWireFeedSpeed->read fail,return value is nil")
        return nil
    end
    local vL = newVal&0x00FF
    local vH = (newVal>>8)&0x00FF
    data[1] = data[1]&0xFFFD --启用offset9~10的焊接电流
    data[1] = data[1]|0x04 --启用“手动送/退丝”速度的设置模式。
    data[2] = (data[2]&0x00FF)|((vL<<8)&0xFF00)
    data[3] = (data[3]&0xFF00)|vH
    return self:innerSetHoldRegsValue_Address(4,data)
end

function OTCMigWelderControlDeviceNet:getWeldWireFeedSpeed()
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

function OTCMigWelderControlDeviceNet:setWorkMode(newVal)
    local welderName = self.welderObject.welderName
    local params = newVal
    if nil == params then
        params = self.welderObject:getWelderParamObject():getWorkMode()
    end
    if not ConstEnumWelderWorkMode[params] then
        MyWelderDebugLog(welderName..Language.trLang("SET_WORK_MODE_PRM_ERROR")..tostring(params))
        return false
    end
    
    MyWelderDebugLog(welderName..":setWorkMode->before write,mode="..tostring(params))
    if "monization"==params then --一元化模式,bit0=1
        return self:innerUpdateHoldRegsValue_Address(4,1,function(oldV,newV)
                                                            local v = oldV|0x01
                                                            MyWelderDebugLog(welderName..":setWorkMode->write value="..v)
                                                            return v
                                                         end)
    elseif "respectively"==params then --分别模式,bit0=0
        return self:innerUpdateHoldRegsValue_Address(4,0,function(oldV,newV)
                                                            local v = oldV&0xFFFE
                                                            MyWelderDebugLog(welderName..":setWorkMode->write value="..v)
                                                            return v
                                                         end)
    end
    return true
end

function OTCMigWelderControlDeviceNet:setWeldMode(newVal)
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
        dcPulse = 0, --直流脉冲
        dc = 1, --直流电
        dcLowSplash = 2, --直流低溅射
        dcWavePulse = 3, --直流波脉冲
        acPulse = 4, --交流脉冲
        acWavePulse = 5, --交流波脉冲
        dArc = 6, --D-Arc
        msMig = 7 --MS-MIG
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

function OTCMigWelderControlDeviceNet:setJobId(newVal)
    return true --暂时还不支持
end

function OTCMigWelderControlDeviceNet:arcStart()
    local newVal = 0x01
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":arcStart->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                        local v = oldV|newV
                                                        MyWelderDebugLog(welderName..":arcStart->write value="..v)
                                                        return v
                                                     end)
end

function OTCMigWelderControlDeviceNet:isArcStarted()
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

function OTCMigWelderControlDeviceNet:arcEnd()
    local newVal = 0xFFFE
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":arcEnd->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                        local v = oldV&newV
                                                        MyWelderDebugLog(welderName..":arcEnd->write value="..v)
                                                        return v
                                                     end)
end

function OTCMigWelderControlDeviceNet:isArcEnded()
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

function OTCMigWelderControlDeviceNet:hasEndArcByMannual()
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

function OTCMigWelderControlDeviceNet:startWireFeed()
    local newVal = 0x02
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":startWireFeed->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                        local v = oldV|newV
                                                        MyWelderDebugLog(welderName..":startWireFeed->write value="..v)
                                                        return v
                                                     end)
end
function OTCMigWelderControlDeviceNet:stopWireFeed()
    local newVal = 0xFFFD
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":stopWireFeed->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                        local v = oldV&newV
                                                        MyWelderDebugLog(welderName..":stopWireFeed->write value="..v)
                                                        return v
                                                     end)
end

function OTCMigWelderControlDeviceNet:startWireBack()
    local newVal = 0x04
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":startWireBack->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                        local v = oldV|newV
                                                        MyWelderDebugLog(welderName..":startWireBack->write value="..v)
                                                        return v
                                                     end)
end
function OTCMigWelderControlDeviceNet:stopWireBack()
    local newVal = 0xFFFB
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":stopWireBack->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                        local v = oldV&newV
                                                        MyWelderDebugLog(welderName..":stopWireBack->write value="..v)
                                                        return v
                                                     end)
end

function OTCMigWelderControlDeviceNet:startGasCheck()
    local newVal = 0x08
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":startGasCheck->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                        local v = oldV|newV
                                                        MyWelderDebugLog(welderName..":startGasCheck->write value="..v)
                                                        return v
                                                     end)
end
function OTCMigWelderControlDeviceNet:stopGasCheck()
    local newVal = 0xFFF7
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":stopGasCheck->before write")
    return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV)
                                                        local v = oldV&newV
                                                        MyWelderDebugLog(welderName..":stopGasCheck->write value="..v)
                                                        return v
                                                     end)
end

function OTCMigWelderControlDeviceNet:getWelderRunStateInfo()
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
    info.gasType = (newVal[3]>>5)&0x07
    info.materialType = (newVal[3]>>8)&0x0F
    info.wireDiameter = (newVal[3]>>12)&0x07
    if (newVal[3]>>15)&0x01==0x01 then info.penetration="on"
    else info.penetration="off"
    end
    info.arcCharacteristic = newVal[4]&0xFF
    info.enRatio = (newVal[4]>>8)&0xFF
    if newVal[5]&0x01==0x01 then info.workMode = "monization" --一元化模式
    else info.workMode = "respectively" --分别模式
    end
    info.voltage = CHelperTools.ToInt8((newVal[8]>>8)&0x00FF)
    info.waveFreq = CHelperTools.ToInt16(newVal[9]&0xFFFF)*0.1
]]--    
    return info
end

function OTCMigWelderControlDeviceNet:getWelderErrCode()
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
--OTC-MIG焊机特有的协议属性****************************************************************************************************
--[[
功能：设置保护气体
参数：newVal-保护气体的编号id
返回值：true表示成功，false表示失败
]]--
function OTCMigWelderControlDeviceNet:setGasNumber(newVal)
    local welderName = self.welderObject.welderName
    if nil == newVal then
        local params = self.welderObject:getWelderParamObject():getNotJobModeParam()
        if #params.params < 1 or params.selectedId<1 or params.selectedId > #params.params then
            MyWelderDebugLog(welderName..Language.trLang("WELDER_SET_GAS_NUM_ERR"))
            return false
        end
        newVal = params.params[params.selectedId].otc.gasNumber
    end
    newVal = math.floor(newVal)
    MyWelderDebugLog(welderName..":setGasNumber->before write,id="..tostring(newVal))
    newVal = (newVal<<5)&0x00E0
    return self:innerUpdateHoldRegsValue_Address(2,newVal,function(oldV,newV)
                                                            local tmp=oldV&0xFF1F
                                                            tmp=tmp|newV
                                                            MyWelderDebugLog(welderName..":setGasNumber->write value="..tmp)
                                                            return tmp
                                                           end)
end

--[[
功能：设置焊接材质
参数：newVal-材质的编号id
返回值：true表示成功，false表示失败
]]--
function OTCMigWelderControlDeviceNet:setWireMaterialNumber(newVal)
    local welderName = self.welderObject.welderName
    if nil == newVal then
        local params = self.welderObject:getWelderParamObject():getNotJobModeParam()
        if #params.params < 1 or params.selectedId<1 or params.selectedId > #params.params then
            MyWelderDebugLog(welderName..Language.trLang("WELDER_SET_WIRE_NUM_ERR"))
            return false
        end
        newVal = params.params[params.selectedId].otc.wireMaterialNumber
    end
    newVal = math.floor(newVal)
    MyWelderDebugLog(welderName..":setWireMaterialNumber->before write,id="..tostring(newVal))
    newVal = (newVal<<8)&0x0F00
    return self:innerUpdateHoldRegsValue_Address(2,newVal,function(oldV,newV)
                                                            local tmp=oldV&0xF0FF
                                                            tmp=tmp|newV
                                                            MyWelderDebugLog(welderName..":setWireMaterialNumber->write value="..tmp)
                                                            return tmp
                                                           end)
end

--[[
功能：设置焊丝直径
参数：newVal-焊丝直径的编号id
返回值：true表示成功，false表示失败
]]--
function OTCMigWelderControlDeviceNet:setWireDiameterNumber(newVal)
    local welderName = self.welderObject.welderName
    if nil == newVal then
        local params = self.welderObject:getWelderParamObject():getNotJobModeParam()
        if #params.params < 1 or params.selectedId<1 or params.selectedId > #params.params then
            MyWelderDebugLog(welderName..Language.trLang("WELDER_SET_WIRE_DIAMETER_ERR"))
            return false
        end
        newVal = params.params[params.selectedId].otc.wireDiameterNumber
    end
    newVal = math.floor(newVal)
    MyWelderDebugLog(welderName..":setWireDiameterNumber->before write,id="..tostring(newVal))
    newVal = (newVal<<12)&0x7000
    return self:innerUpdateHoldRegsValue_Address(2,newVal,function(oldV,newV)
                                                            local tmp=oldV&0x8FFF
                                                            tmp=tmp|newV
                                                            MyWelderDebugLog(welderName..":setWireDiameterNumber->write value="..tmp)
                                                            return tmp
                                                           end)
end

--[[
功能：设置渗透控制的开关
参数：bIsOn-true表示开启渗透控制，false表示关闭
返回值：true表示成功，false表示失败
]]--
function OTCMigWelderControlDeviceNet:setPenetrationOn(bIsOn)
    local welderName = self.welderObject.welderName
    if nil == bIsOn then
        bIsOn = self.welderObject:getWelderParamObject():getOTCMigCtrlParam().penetration
    end
    MyWelderDebugLog(welderName..":setPenetrationOn->before write,bIsOn="..tostring(bIsOn))
    if bIsOn then
        return self:innerUpdateHoldRegsValue_Address(2,0x8000,function(oldV,newV)
                                                                local tmp=oldV|newV
                                                                MyWelderDebugLog(welderName..":setPenetrationOn->write value="..tmp)
                                                                return tmp
                                                              end)
    else
        return self:innerUpdateHoldRegsValue_Address(2,0x7FFF,function(oldV,newV)
                                                                local tmp=oldV&newV
                                                                MyWelderDebugLog(welderName..":setPenetrationOn->write value="..tmp)
                                                                return tmp
                                                              end)    
    end
end

--[[
功能：设置电弧控制
参数：newVal-电弧控制的值
返回值：true表示成功，false表示失败
]]--
function OTCMigWelderControlDeviceNet:setArcCharact(newVal)
    local welderName = self.welderObject.welderName
    if nil == newVal then
        newVal = self.welderObject:getWelderParamObject():getOTCMigCtrlParam().arcValue
    end
    MyWelderDebugLog(welderName..":setArcCharact->before write,newVal="..tostring(newVal))
    newVal = math.floor(newVal)&0x00FF
    return self:innerUpdateHoldRegsValue_Address(3,newVal,function(oldV,newV)
                                                            local tmp=oldV&0xFF00
                                                            tmp=tmp|newV
                                                            MyWelderDebugLog(welderName..":setArcCharact->write value="..tmp)
                                                            return tmp
                                                           end)
end

--[[
功能：设置摆动频率
参数：newVal-摆动频率的值
返回值：true表示成功，false表示失败
]]--
function OTCMigWelderControlDeviceNet:setWaveFreq(newVal)
    local welderName = self.welderObject.welderName
    if nil == newVal then
        newVal = self.welderObject:getWelderParamObject():getOTCMigCtrlParam().waveFreq
    end
    MyWelderDebugLog(welderName..":setWaveFreq->before write,newVal="..tostring(newVal))
    newVal = math.floor(newVal*10) --注意倍率关系
    return self:innerUpdateHoldRegsValue_Address(8,newVal,nil)
end

--[[
功能：通用功能函数单个参数设置
参数：newNo-编号
      newVal-对应编号的值
返回值：true表示成功，false表示失败
]]--
function OTCMigWelderControlDeviceNet:setFunctionView1(newNo, newVal)
    return innerSetFunctionView1(self, newNo, newVal, true)
end
function OTCMigWelderControlDeviceNet:setFunctionView2(newNo, newVal)
    return innerSetFunctionView2(self, newNo, newVal, true)
end
function OTCMigWelderControlDeviceNet:setFunctionView3(newNo, newVal)
    return innerSetFunctionView3(self, newNo, newVal, true)
end
function OTCMigWelderControlDeviceNet:setFunctionView4(newNo, newVal)
    return innerSetFunctionView4(self, newNo, newVal, true)
end

return OTCMigWelderControlDeviceNet