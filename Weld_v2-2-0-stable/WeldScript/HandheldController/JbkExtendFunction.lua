--【扩展功能的展示导出接口】
local JbkExtendFunction = {
    jkb = nil,
    funcId = 1, --扩展功能当前的索引
    funcMap = {}, --扩展功能的函数映射表
    mapperId = {"J","S","G","dbG","SPot","M"} --扩展功能函数映射表的id索引值，通过这个来调整执行显示的顺序
}
function JbkExtendFunction.showNextCode(jkb,funcId)
    local self = JbkExtendFunction
    if nil~=funcId then
        self.funcId = funcId
    else
        self.funcId = self.funcId+1
        if self.funcId>#self.mapperId then
            self.funcId = 1
        end
    end
    self.jkb = jkb
    
    local retData = self.funcMap[self.mapperId[self.funcId]]()
    if nil~=retData then
        local led = jkb.controller.getButtonLedState()
        led = JbkLightID.getOnExtendFunctionCode(led) --亮灯
        jkb.controller.setButtonLedState(led)
        jkb.controller.setLedString(retData)
        jkb.controller.writeAllInfo()
    end
end

function JbkExtendFunction.showNewValue(jkb,value)
    local self = JbkExtendFunction
    self.jkb = jkb
    local retData = self.funcMap[self.mapperId[self.funcId]](value)
    if nil~=retData then
        jkb.controller.setLedString(retData)
        jkb.controller.writeAllInfo()
    end
end

--****************************************************************************************************
--****************************************************************************************************
--设置脚本的全局速度比例数值
JbkExtendFunction.funcMap["G"]=function()
    local preValue = 10
    return function(v)
        if nil~=v then
            preValue = preValue+v
        else
            preValue = JoystickArcTemplate.getSpeedFactor()
        end
        if preValue>100 then preValue=100
        elseif preValue<1 then preValue=1
        end
        JoystickArcTemplate.setSpeedFactor(preValue)
        if preValue>=100 then
            return "G"..preValue
        elseif preValue>=10 then
            return "G\x00"..preValue
        else
            return "G\x00\x00"..preValue
        end
    end
end
JbkExtendFunction.funcMap["G"]=JbkExtendFunction.funcMap["G"]()

--设置点动全局速度比例数值
JbkExtendFunction.funcMap["J"]=function()
    local preValue = 1
    return function(v)
        if nil~=v then
            preValue = preValue+v
        else
            preValue = RobotModbusControl.getSpeedFactor()
        end
        if preValue>100 then preValue=100
        elseif preValue<1 then preValue=1
        end
        RobotModbusControl.setSpeedFactor(preValue)
        if preValue>=100 then
            return "J"..preValue
        elseif preValue>=10 then
            return "J\x00"..preValue
        else
            return "J\x00\x00"..preValue
        end
    end
end
JbkExtendFunction.funcMap["J"]=JbkExtendFunction.funcMap["J"]()

--设置多层多道组合索引
JbkExtendFunction.funcMap["M"]=function()
    local preValue = 0
    return function(v)
        if nil~=v then
            preValue = preValue+v
        else
            preValue = JoystickArcTemplate.getMultiPassParam()
        end
        if preValue>99 then preValue=99
        elseif preValue<0 then preValue=0
        end
        JoystickArcTemplate.setMultiPassParam(preValue)
        if preValue>=100 then
            return "M"..preValue
        elseif preValue>=10 then
            return "M\x00"..preValue
        else
            return "M\x00\x00"..preValue
        end
    end
end
JbkExtendFunction.funcMap["M"]=JbkExtendFunction.funcMap["M"]()

--设置焊接速度
JbkExtendFunction.funcMap["S"]=function()
    local preValue = 0
    return function(v)
        if nil~=v then
            preValue = preValue+v
        else
            preValue = JoystickArcTemplate.getWeldArcSpeed()
        end
        if preValue>20 then preValue=20
        elseif preValue<1 then preValue=1
        end
        JoystickArcTemplate.setWeldArcSpeed(preValue)
        if preValue>=100 then
            return "S"..preValue
        elseif preValue>=10 then
            return "S\x00"..preValue
        else
            return "S\x00\x00"..preValue
        end
    end
end
JbkExtendFunction.funcMap["S"]=JbkExtendFunction.funcMap["S"]()

--设置为调试模式
JbkExtendFunction.funcMap["dbG"]=function()
    return function(v)
        JbkExtendFunction.jkb.setDebugMode()
    end
end
JbkExtendFunction.funcMap["dbG"]=JbkExtendFunction.funcMap["dbG"]()

--设置为点焊功能模式
JbkExtendFunction.funcMap["SPot"]=function()
    return function(v)
        JbkExtendFunction.jkb.setSpotMode()
    end
end
JbkExtendFunction.funcMap["SPot"]=JbkExtendFunction.funcMap["SPot"]()

return JbkExtendFunction