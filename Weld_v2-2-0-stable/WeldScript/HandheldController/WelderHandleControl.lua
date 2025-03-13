--【摇杆控制焊机对象】-----------------------------------------------------------------------------------
local WelderHandleControl = {
}

--设置按钮盒子示教器是否真正的已经启动，运行的状态标记
function WelderHandleControl.setButtonBoxOnOff(isOn)
    GlobalParameter.setButtonBoxOnOff(isOn)
end

function WelderHandleControl.setWireFeed(bIsOn)
    local welder = RobotManager.getDobotCurrentWelder()
    if not welder then return false end
    return welder:setWireFeed(bIsOn)
end

function WelderHandleControl.setWireBack(bIsOn)
    local welder = RobotManager.getDobotCurrentWelder()
    if not welder then return false end
    return welder:setWireBack(bIsOn)
end

function WelderHandleControl.setGasCheck(bIsOn)
    local welder = RobotManager.getDobotCurrentWelder()
    if not welder then return false end
    return welder:setGasCheck(bIsOn)
end

function WelderHandleControl.isVirtualWeld()
    return GlobalParameter.isVirtualWeld()
end
function WelderHandleControl.setVirtualWeld(bVirtual)
    GlobalParameter.setVirtualWeld(bVirtual)
    local data={}
    data["isVirtual"] = bVirtual
    data["hasWelder"] = GlobalParameter.isHasWelder()
    MqttRobot.publish("/mqtt/weld/getVirtualWeld",data)
end

function WelderHandleControl.isJobMode()
    local welder = RobotManager.getDobotCurrentWelder()
    if not welder then return false end
    return welder:isJobMode()
end

function WelderHandleControl.getWeldMultiPassGroup(index)
    if math.type(index)~="integer" then return nil end
    local param = GlobalParameter.getMultipleWeldGroup()
    if type(param)~="table" then return nil end
    local dataParam = param[index]
    if type(dataParam)~="table" then return nil end
    if #dataParam<1 then return nil end
    for i=1,#dataParam do
        if math.type(dataParam[i])~="integer" then
            return nil
        end
    end
    return dataParam
end

function WelderHandleControl.doSpotWeld()
    local welder = RobotManager.getDobotCurrentWelder()
    if not welder then return false end
    local newValue = GlobalParameter.getSpotWeldParam()
    if type(newValue)~="table" then return false end
    return welder:doSpotWeld(newValue)
end

--返回0表示脚本没有报错
function WelderHandleControl.getScriptErrCode()
    return GlobalParameter.getWeldScriptRunErrorCode()
end
function WelderHandleControl.clearScriptErrCode()
    GlobalParameter.clearWeldScriptRunErrorCode()
end

return WelderHandleControl