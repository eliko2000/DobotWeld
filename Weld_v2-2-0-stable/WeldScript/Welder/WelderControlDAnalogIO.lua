--[[焊机`WelderControlDAnalogIO`接口,继承自`WelderControlObject`]]--

-------------------------------------------------------------------------------------------------------------------
--【本地私有接口】--
--[[
功能：根据2点计算一次方程，并返回结果
参数：x1,y1,x2,y2,x
返回值：返回y值
]]--
local function innerFuncCalcY(x1,y1,x2,y2,x)
    if x1==x2 then --垂直于X轴的线
        return (y1+y2)*0.5
    end
    local k=(y1-y2)/(x1-x2)
    local b=(x1*y2-x2*y1)/(x1-x2)
    local y = k*x+b
    return y
end
local function innerFuncCalcX(x1,y1,x2,y2,y)
    if x1==x2 then --垂直于X轴的线
        return x1
    end
    if y1==y2 then
        return (x1+x2)*0.5
    end
    local k=(y1-y2)/(x1-x2)
    local b=(x1*y2-x2*y1)/(x1-x2)
    local x = (y-b)/k
    return x
end

local function innerAO(index, value)
    if type(value)~="number" then
        return AO(index, value)
    end
    if value<0 then value=0
    elseif value>10 then value=10
    end
    return AO(index, value)
end

-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
--【业务实现接口】-------------------------------------------------------------------------------------------------
local WelderControlDAnalogIO = WelderControlObject:new()
WelderControlDAnalogIO.__index = WelderControlDAnalogIO
WelderControlDAnalogIO.welderObject = nil --焊机对象，也就是`ImplementWelder`的派生类

-------------------------------------------------------------------------------------------------------------------
--【对内不公开接口，只给本身和派生类使用】-----------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------
--【对外公开接口】-------------------------------------------------------------------------------------------------
function WelderControlDAnalogIO:new(welderObj)
    local o = WelderControlObject:new()
    o.welderObject = welderObj
    setmetatable(o,self)
    return o
end

function WelderControlDAnalogIO:initWelder()
    --[[
    不仅要发机器人准备好信号，还要发灭弧信号,因为刚开机时可能存在有起弧信号，
    导致这个原因是正常起弧焊接时，在需要发送断弧的时没有发成功
    ]]--
    local welderName = self.welderObject.welderName
    MyWelderDebugLog(welderName..":initWelder->before write")
    local params = self.welderObject:getWelderParamObject():getAnalogIOSignalParam() or {}
    if type(params.controlBoxSignalParam)=="table" then
        local cbsp = params.controlBoxSignalParam
        if math.type(cbsp.arcStart)=="integer" and cbsp.arcStart>0 then
            DO(cbsp.arcStart,OFF) --灭弧
        end
    end
    params = self.welderObject.globalParamObject.getAnalogIOSignalParam() or {}
    if type(params.touchPositionParam)=="table" then
        local tpp = params.touchPositionParam
        if math.type(tpp.enableDO)=="integer" and tpp.enableDO>0 then
            DO(tpp.enableDO,OFF) --寻位使能关闭
        end
        if math.type(tpp.failDO)=="integer" and tpp.failDO>0 then
            DO(tpp.failDO,OFF) --寻位失败关闭
        end
    end
    MyWelderDebugLog(welderName..":initWelder->end write")
    return true
end

function WelderControlDAnalogIO:setTouchPostionEnable(bEnable)
    local welderName = self.welderObject.welderName
    --MyWelderDebugLog(welderName..":setTouchPostionEnable->write value="..tostring(bEnable))
    local params = self.welderObject.globalParamObject.getAnalogIOSignalParam() or {}
    if type(params.touchPositionParam)~="table" then
        --MyWelderDebugLog(welderName .. "-->setTouchPostionEnable:" .. Language.trLang("TOUCH_POSITION_PARAM_CFG_ERR"))
        return nil
    end
    local tpp = params.touchPositionParam
    if math.type(tpp.enableDO)~="integer" then
        --MyWelderDebugLog(welderName .. "-->setTouchPostionEnable:" .. Language.trLang("TOUCH_POSITION_PARAM_CFG_ERR"))
        return nil
    end
    if tpp.enableDO<1 then
        --MyWelderDebugLog(welderName .. "-->setTouchPostionEnable:" .. Language.trLang("TOUCH_POSITION_PARAM_CFG_ERR"))
        return nil
    end
    if bEnable then
        DO(tpp.enableDO,ON)
    else
        DO(tpp.enableDO,OFF)
    end
    return true
end

function WelderControlDAnalogIO:isTouchPositionSuccess()
    local welderName = self.welderObject.welderName
    local params = self.welderObject.globalParamObject.getAnalogIOSignalParam() or {}
    if type(params.touchPositionParam)~="table" then
        --MyWelderDebugLog(welderName .. "-->isTouchPositionSuccess:" .. Language.trLang("TOUCH_POSITION_PARAM_CFG_ERR"))
        return nil
    end
    local tpp = params.touchPositionParam
    if math.type(tpp.successDI)~="integer" then
        --MyWelderDebugLog(welderName .. "-->isTouchPositionSuccess:" .. Language.trLang("TOUCH_POSITION_PARAM_CFG_ERR"))
        return nil
    end
    if tpp.successDI<1 then
        --MyWelderDebugLog(welderName .. "-->isTouchPositionSuccess:" .. Language.trLang("TOUCH_POSITION_PARAM_CFG_ERR"))
        return nil
    end
    return DI(tpp.successDI)==ON
end

function WelderControlDAnalogIO:setTouchPositionFailStatus(bStatus)
    local welderName = self.welderObject.welderName
    --MyWelderDebugLog(welderName..":setTouchPositionFailStatus->write value="..tostring(bStatus))
    local params = self.welderObject.globalParamObject.getAnalogIOSignalParam() or {}
    if type(params.touchPositionParam)~="table" then
        --MyWelderDebugLog(welderName .. "-->setTouchPositionFailStatus:" .. Language.trLang("TOUCH_POSITION_PARAM_CFG_ERR"))
        return nil
    end
    local tpp = params.touchPositionParam
    if math.type(tpp.failDO)~="integer" then
        --MyWelderDebugLog(welderName .. "-->setTouchPositionFailStatus:" .. Language.trLang("TOUCH_POSITION_PARAM_CFG_ERR"))
        return nil
    end
    if tpp.failDO<1 then
        --MyWelderDebugLog(welderName .. "-->setTouchPositionFailStatus:" .. Language.trLang("TOUCH_POSITION_PARAM_CFG_ERR"))
        return nil
    end
    if bStatus then
        DO(tpp.failDO,ON)
    else
        DO(tpp.failDO,OFF)
    end
    return true
end

--[[
根据VA曲线计算一次方程 y=kx+b，y为焊机参数，x为控制器模拟数据，且该曲线不可能存在垂直于X轴的
k=(y1-y2)/(x1-x2)   b=(x1·y2-x2·y1)/(x1-x2)
]]--
function WelderControlDAnalogIO:setWeldCurrent(newVal)
    local welderName = self.welderObject.welderName
    local vaParams = self.welderObject:getWelderParamObject():getVAParams()
    if #vaParams.params < 2 then
        MyWelderDebugLog(welderName .. Language.trLang("WELDER_LESS2_NOVA_WELD_CURRENT"))
        return false
    end
    
    if nil == newVal then    
        local params = self.welderObject:getWelderParamObject():getNotJobModeParam()
        if #params.params < 1 or params.selectedId<1 or params.selectedId > #params.params then
            MyWelderDebugLog(welderName..Language.trLang("WELDER_SET_WELD_CURRENT"))
            return false
        end
        newVal = params.params[params.selectedId].weldCurrent
    end
    --焊机的值要转为控制器模拟值
    local x1=vaParams.params[1].voltage
    local x2=vaParams.params[2].voltage
    local y1=vaParams.params[1].weldCurrent
    local y2=vaParams.params[2].weldCurrent
    local strData = "x1="..tostring(x1)..",x2="..tostring(x2)..",y1="..tostring(y1)..",y2="..tostring(y2)
    local cvtNewVal = innerFuncCalcX(x1,y1,x2,y2,newVal)
    MyWelderDebugLog(string.format("%s:setWeldCurrent->(%s)newVal=%s,cvtNewVal=%s",welderName,strData,tostring(newVal),tostring(cvtNewVal)))
    innerAO(vaParams.indexAO, cvtNewVal)
    return true
end

function WelderControlDAnalogIO:setArcStartCurrent(newVal)
    local welderName = self.welderObject.welderName
    local vaParams = self.welderObject:getWelderParamObject():getVAParams()
    if #vaParams.params < 2 then
        MyWelderDebugLog(welderName .. Language.trLang("WELDER_LESS2_NOVA_ARC_CURRENT"))
        return false
    end
    if nil == newVal then
        local params = self.welderObject:getWelderParamObject():getNotJobModeParam()
        if #params.params < 1 or params.selectedId<1 or params.selectedId > #params.params then
            MyWelderDebugLog(welderName..Language.trLang("WELDER_SET_ARC_CURRENT"))
            return false
        end
        newVal = params.params[params.selectedId].arcStartCurrent
    end
    --焊机的值要转为控制器模拟值
    local x1=vaParams.params[1].voltage
    local x2=vaParams.params[2].voltage
    local y1=vaParams.params[1].weldCurrent
    local y2=vaParams.params[2].weldCurrent
    local strData = "x1="..tostring(x1)..",x2="..tostring(x2)..",y1="..tostring(y1)..",y2="..tostring(y2)
    local cvtNewVal = innerFuncCalcX(x1,y1,x2,y2,newVal)
    MyWelderDebugLog(string.format("%s:setArcStartCurrent->(%s)newVal=%s,cvtNewVal=%s",welderName,strData,tostring(newVal),tostring(cvtNewVal)))
    innerAO(vaParams.indexAO, cvtNewVal)
    return true
end

function WelderControlDAnalogIO:setArcEndCurrent(newVal)
    local welderName = self.welderObject.welderName
    local vaParams = self.welderObject:getWelderParamObject():getVAParams()
    if #vaParams.params < 2 then
        MyWelderDebugLog(welderName..Language.trLang("WELDER_LESS2_NOVA_END_CURRENT"))
        return false
    end
    if nil == newVal then
        local params = self.welderObject:getWelderParamObject():getNotJobModeParam()
        if #params.params < 1 or params.selectedId<1 or params.selectedId > #params.params then
            MyWelderDebugLog(welderName..Language.trLang("WELDER_SET_END_CURRENT"))
            return false
        end
        newVal = params.params[params.selectedId].arcStartCurrent
    end
    --焊机的值要转为控制器模拟值
    local x1=vaParams.params[1].voltage
    local x2=vaParams.params[2].voltage
    local y1=vaParams.params[1].weldCurrent
    local y2=vaParams.params[2].weldCurrent
    local strData = "x1="..tostring(x1)..",x2="..tostring(x2)..",y1="..tostring(y1)..",y2="..tostring(y2)
    local cvtNewVal = innerFuncCalcX(x1,y1,x2,y2,newVal)
    MyWelderDebugLog(string.format("%s:setArcEndCurrent->(%s)newVal=%s,cvtNewVal=%s",welderName,strData,tostring(newVal),tostring(cvtNewVal)))
    innerAO(vaParams.indexAO, cvtNewVal)
    return true
end

function WelderControlDAnalogIO:setWeldVoltage(newVal)
    local welderName = self.welderObject.welderName
    local vvParams = self.welderObject:getWelderParamObject():getVVParams()
    if #vvParams.params < 2 then
        MyWelderDebugLog(welderName..Language.trLang("WELDER_LESS2_NOVA_WELD_VOLTAGE"))
        return false
    end
    if nil == newVal then
        local params = self.welderObject:getWelderParamObject():getNotJobModeParam()
        if #params.params < 1 or params.selectedId<1 or params.selectedId > #params.params then
            MyWelderDebugLog(welderName..Language.trLang("WELDER_SET_WELD_VOLTAGE"))
            return false
        end
        newVal = params.params[params.selectedId].weldVoltage
    end
    --焊机的值要转为控制器模拟值
    local x1=vvParams.params[1].voltage
    local x2=vvParams.params[2].voltage
    local y1=vvParams.params[1].weldVoltage
    local y2=vvParams.params[2].weldVoltage
    local strData = "x1="..tostring(x1)..",x2="..tostring(x2)..",y1="..tostring(y1)..",y2="..tostring(y2)
    local cvtNewVal = innerFuncCalcX(x1,y1,x2,y2,newVal)
    MyWelderDebugLog(string.format("%s:setWeldVoltage->(%s)newVal=%s,cvtNewVal=%s",welderName,strData,tostring(newVal),tostring(cvtNewVal)))
    innerAO(vvParams.indexAO, cvtNewVal)
    return true
end

function WelderControlDAnalogIO:setArcStartVoltage(newVal)
    local welderName = self.welderObject.welderName
    local vvParams = self.welderObject:getWelderParamObject():getVVParams()
    if #vvParams.params < 2 then
        MyWelderDebugLog(welderName..Language.trLang("WELDER_LESS2_NOVA_ARC_VOLTAGE"))
        return false
    end
    if nil == newVal then
        local params = self.welderObject:getWelderParamObject():getNotJobModeParam()
        if #params.params < 1 or params.selectedId<1 or params.selectedId > #params.params then
            MyWelderDebugLog(welderName..Language.trLang("WELDER_SET_ARC_VOLTAGE"))
            return false
        end
        newVal = params.params[params.selectedId].arcStartVoltage
    end
    --焊机的值要转为控制器模拟值
    local x1=vvParams.params[1].voltage
    local x2=vvParams.params[2].voltage
    local y1=vvParams.params[1].weldVoltage
    local y2=vvParams.params[2].weldVoltage
    local strData = "x1="..tostring(x1)..",x2="..tostring(x2)..",y1="..tostring(y1)..",y2="..tostring(y2)
    local cvtNewVal = innerFuncCalcX(x1,y1,x2,y2,newVal)
    MyWelderDebugLog(string.format("%s:setArcStartVoltage->(%s)newVal=%s,cvtNewVal=%s",welderName,strData,tostring(newVal),tostring(cvtNewVal)))
    innerAO(vvParams.indexAO, cvtNewVal)
    return true
end

function WelderControlDAnalogIO:setArcEndVoltage(newVal)
    local welderName = self.welderObject.welderName
    local vvParams = self.welderObject:getWelderParamObject():getVVParams()
    if #vvParams.params < 2 then
        MyWelderDebugLog(welderName..Language.trLang("WELDER_LESS2_NOVA_END_VOLTAGE"))
        return false
    end
    if nil == newVal then
        local params = self.welderObject:getWelderParamObject():getNotJobModeParam()
        if #params.params < 1 or params.selectedId<1 or params.selectedId > #params.params then
            MyWelderDebugLog(welderName..Language.trLang("WELDER_SET_END_VOLTAGE"))
            return false
        end
        newVal = params.params[params.selectedId].arcEndVoltage
    end
    --焊机的值要转为控制器模拟值
    local x1=vvParams.params[1].voltage
    local x2=vvParams.params[2].voltage
    local y1=vvParams.params[1].weldVoltage
    local y2=vvParams.params[2].weldVoltage
    local strData = "x1="..tostring(x1)..",x2="..tostring(x2)..",y1="..tostring(y1)..",y2="..tostring(y2)
    local cvtNewVal = innerFuncCalcX(x1,y1,x2,y2,newVal)
    MyWelderDebugLog(string.format("%s:setArcEndVoltage->(%s)newVal=%s,cvtNewVal=%s",welderName,strData,tostring(newVal),tostring(cvtNewVal)))
    innerAO(vvParams.indexAO, cvtNewVal)
    return true
end

function WelderControlDAnalogIO:setWeldPower(newVal)
    local welderName = self.welderObject.welderName
    local vwParams = self.welderObject:getWelderParamObject():getLaserVWParams()
    if #vwParams.params < 2 then
        MyWelderDebugLog(welderName..Language.trLang("WELDER_LESS2_NOVW_WELD_POWER"))
        return false
    end
    if nil == newVal then
        local params = self.welderObject:getWelderParamObject():getLaserWeldParam()
        if #params.params < 1 or params.selectedId<1 or params.selectedId > #params.params then
            MyWelderDebugLog(welderName..Language.trLang("WELDER_SET_WELD_POWER"))
            return false
        end
        newVal = params.params[params.selectedId].weldPower
    end
    --焊机的值要转为控制器模拟值
    local x1=vwParams.params[1].voltage
    local x2=vwParams.params[2].voltage
    local y1=vwParams.params[1].weldPower
    local y2=vwParams.params[2].weldPower
    local strData = "x1="..tostring(x1)..",x2="..tostring(x2)..",y1="..tostring(y1)..",y2="..tostring(y2)
    local cvtNewVal = innerFuncCalcX(x1,y1,x2,y2,newVal)
    MyWelderDebugLog(string.format("%s:setWeldPower->(%s)newVal=%s,cvtNewVal=%s",welderName,strData,tostring(newVal),tostring(cvtNewVal)))
    innerAO(vwParams.indexAO, cvtNewVal)
    return true
end

function WelderControlDAnalogIO:setArcStartPower(newVal)
    local welderName = self.welderObject.welderName
    local vwParams = self.welderObject:getWelderParamObject():getLaserVWParams()
    if #vwParams.params < 2 then
        MyWelderDebugLog(welderName..Language.trLang("WELDER_LESS2_NOVW_ARC_POWER"))
        return false
    end
    if nil == newVal then
        local params = self.welderObject:getWelderParamObject():getLaserWeldParam()
        if #params.params < 1 or params.selectedId<1 or params.selectedId > #params.params then
            MyWelderDebugLog(welderName..Language.trLang("WELDER_SET_ARC_POWER"))
            return false
        end
        newVal = params.params[params.selectedId].arcStartPower
    end
    --焊机的值要转为控制器模拟值
    local x1=vwParams.params[1].voltage
    local x2=vwParams.params[2].voltage
    local y1=vwParams.params[1].weldPower
    local y2=vwParams.params[2].weldPower
    local strData = "x1="..tostring(x1)..",x2="..tostring(x2)..",y1="..tostring(y1)..",y2="..tostring(y2)
    local cvtNewVal = innerFuncCalcX(x1,y1,x2,y2,newVal)
    MyWelderDebugLog(string.format("%s:setArcStartPower->(%s)newVal=%s,cvtNewVal=%s",welderName,strData,tostring(newVal),tostring(cvtNewVal)))
    innerAO(vwParams.indexAO, cvtNewVal)
    return true
end

function WelderControlDAnalogIO:setArcEndPower(newVal)
    local welderName = self.welderObject.welderName
    local vwParams = self.welderObject:getWelderParamObject():getLaserVWParams()
    if #vwParams.params < 2 then
        MyWelderDebugLog(welderName..Language.trLang("WELDER_LESS2_NOVW_END_POWER"))
        return false
    end
    if nil == newVal then
        local params = self.welderObject:getWelderParamObject():getLaserWeldParam()
        if #params.params < 1 or params.selectedId<1 or params.selectedId > #params.params then
            MyWelderDebugLog(welderName..Language.trLang("WELDER_SET_END_POWER"))
            return false
        end
        newVal = params.params[params.selectedId].arcEndPower
    end
    --焊机的值要转为控制器模拟值
    local x1=vwParams.params[1].voltage
    local x2=vwParams.params[2].voltage
    local y1=vwParams.params[1].weldPower
    local y2=vwParams.params[2].weldPower
    local strData = "x1="..tostring(x1)..",x2="..tostring(x2)..",y1="..tostring(y1)..",y2="..tostring(y2)
    local cvtNewVal = innerFuncCalcX(x1,y1,x2,y2,newVal)
    MyWelderDebugLog(string.format("%s:setArcEndPower->(%s)newVal=%s,cvtNewVal=%s",welderName,strData,tostring(newVal),tostring(cvtNewVal)))
    innerAO(vwParams.indexAO, cvtNewVal)
    return true
end

function WelderControlDAnalogIO:arcStart()
    local welderName = self.welderObject.welderName
    local params = self.welderObject:getWelderParamObject():getAnalogIOSignalParam()
    MyWelderDebugLog(welderName..":arcStart->DO("..tostring(params.controlBoxSignalParam.arcStart)..",ON)")
    DO(params.controlBoxSignalParam.arcStart,ON)
    return true
end

function WelderControlDAnalogIO:isArcStarted()
    local welderName = self.welderObject.welderName
    local params = self.welderObject:getWelderParamObject():getAnalogIOSignalParam()
    if DI(params.controlBoxSignalParam.arcStartCheck) == ON then 
        MyWelderDebugLog(welderName..":isArcStarted->DI("..tostring(params.controlBoxSignalParam.arcStartCheck)..")=ON")
        return true
    else
        MyWelderDebugLog(welderName..":isArcStarted->DI("..tostring(params.controlBoxSignalParam.arcStartCheck)..")=OFF")
        return false
    end
end

function WelderControlDAnalogIO:arcEnd()
    local welderName = self.welderObject.welderName
    local params = self.welderObject:getWelderParamObject():getAnalogIOSignalParam()
    MyWelderDebugLog(welderName..":arcEnd->DO("..tostring(params.controlBoxSignalParam.arcStart)..",OFF)")
    DO(params.controlBoxSignalParam.arcStart,OFF)
    return true
end

function WelderControlDAnalogIO:isArcEnded()
    local welderName = self.welderObject.welderName
    local params = self.welderObject:getWelderParamObject():getAnalogIOSignalParam()
    if DI(params.controlBoxSignalParam.arcStartCheck) == OFF then 
        MyWelderDebugLog(welderName..":isArcEnded->DI("..tostring(params.controlBoxSignalParam.arcStartCheck)..")=OFF")
        return true
    else
        MyWelderDebugLog(welderName..":isArcEnded->DI("..tostring(params.controlBoxSignalParam.arcStartCheck)..")=ON")
        return false
    end
end

function WelderControlDAnalogIO:hasEndArcByMannual()
    local welderName = self.welderObject.welderName
    local params = self.welderObject:getWelderParamObject():getAnalogIOSignalParam()
    if GetDO(params.controlBoxSignalParam.arcStart) == OFF then 
        MyWelderDebugLog(welderName..":hasEndArcByMannual->GetDO("..tostring(params.controlBoxSignalParam.arcStart)..")=OFF")
        return true
    else
        MyWelderDebugLog(welderName..":hasEndArcByMannual->GetDO("..tostring(params.controlBoxSignalParam.arcStart)..")=ON")
        return false
    end
end

function WelderControlDAnalogIO:startWireFeed()
    local welderName = self.welderObject.welderName
    local params = self.welderObject:getWelderParamObject():getAnalogIOSignalParam()
    MyWelderDebugLog(welderName..":startWireFeed->DO("..tostring(params.controlBoxSignalParam.wireFeed)..",ON)")
    DO(params.controlBoxSignalParam.wireFeed,ON)
    return true
end
function WelderControlDAnalogIO:stopWireFeed()
    local welderName = self.welderObject.welderName
    local params = self.welderObject:getWelderParamObject():getAnalogIOSignalParam()
    MyWelderDebugLog(welderName..":stopWireFeed->DO("..tostring(params.controlBoxSignalParam.wireFeed)..",OFF)")
    DO(params.controlBoxSignalParam.wireFeed,OFF)
    return true
end

function WelderControlDAnalogIO:startWireBack()
    local welderName = self.welderObject.welderName
    local params = self.welderObject:getWelderParamObject():getAnalogIOSignalParam()
    MyWelderDebugLog(welderName..":startWireBack->DO("..tostring(params.controlBoxSignalParam.wireBack)..",ON)")
    DO(params.controlBoxSignalParam.wireBack,ON)
    return true
end
function WelderControlDAnalogIO:stopWireBack()
    local welderName = self.welderObject.welderName
    local params = self.welderObject:getWelderParamObject():getAnalogIOSignalParam()
    MyWelderDebugLog(welderName..":stopWireBack->DO("..tostring(params.controlBoxSignalParam.wireBack)..",OFF)")
    DO(params.controlBoxSignalParam.wireBack,OFF)
    return true
end

function WelderControlDAnalogIO:isWireHasSignal()
    local welderName = self.welderObject.welderName
    local params = self.welderObject:getWelderParamObject():getAnalogIOSignalParam()
    if GetDO(params.controlBoxSignalParam.wireFeed)==ON then
        MyWelderDebugLog(welderName..":isWireHasSignal->GetDO("..tostring(params.controlBoxSignalParam.wireFeed)..")=ON")
        return true
    else
        MyWelderDebugLog(welderName..":isWireHasSignal->GetDO("..tostring(params.controlBoxSignalParam.wireFeed)..")=OFF")
        return false
    end
end

function WelderControlDAnalogIO:startGasCheck()
    local welderName = self.welderObject.welderName
    local params = self.welderObject:getWelderParamObject():getAnalogIOSignalParam()
    MyWelderDebugLog(welderName..":startGasCheck->DO("..tostring(params.controlBoxSignalParam.gasCheck)..",ON)")
    DO(params.controlBoxSignalParam.gasCheck,ON)
    return true
end
function WelderControlDAnalogIO:stopGasCheck()
    local welderName = self.welderObject.welderName
    local params = self.welderObject:getWelderParamObject():getAnalogIOSignalParam()
    MyWelderDebugLog(welderName..":stopGasCheck->DO("..tostring(params.controlBoxSignalParam.gasCheck)..",OFF)")
    DO(params.controlBoxSignalParam.gasCheck,OFF)
    return true
end

function WelderControlDAnalogIO:isGasHasSignal()
    local params = self.welderObject:getWelderParamObject():getAnalogIOSignalParam()
    if GetDO(params.controlBoxSignalParam.gasCheck)==ON then
        MyWelderDebugLog(welderName..":isGasHasSignal->GetDO("..tostring(params.controlBoxSignalParam.gasCheck)..")=ON")
        return true
    else
        MyWelderDebugLog(welderName..":isGasHasSignal->GetDO("..tostring(params.controlBoxSignalParam.gasCheck)..")=OFF")
        return false
    end
end

function WelderControlDAnalogIO:getWelderRunStateInfo()
    local info = {connectState=true, --模拟量通信没有断开连接的状态，所以永远都是连接状态
                  weldState=0
                 }
    --之所以不用isArcStarted，是不想打印太多日志
    local params = self.welderObject:getWelderParamObject():getAnalogIOSignalParam() or {}
    if type(params.controlBoxSignalParam)~="table" then return info end
    if math.type(params.controlBoxSignalParam.arcStartCheck)~="integer" then return info end
    if params.controlBoxSignalParam.arcStartCheck<1 then return info end
    if DI(params.controlBoxSignalParam.arcStartCheck) == ON then 
        info.weldState = 1
    else
        info.weldState = 0
    end
    return info
end

return WelderControlDAnalogIO