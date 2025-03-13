--[[
请读以下内容：
1. 该文件描述了焊机所需要的基本参数，也就是说大部分焊机都可能需要用到的参数。
2. 各自厂家焊机，如果有特殊的配置参数需要添加，那么可以在自己的参数配置文件中新增，而不要在这个公共通用的参数中添加。
3. 因为lua生态api的SetVal底层是用luaJson.lua库对table转为字符串处理的，而这个json库在转换时如果发现数据不是number、string、boolean、table，那么就会报错导致无法存储
   所以我们在保存table时候，尽量不要在table中添加function。
]]--

--------------------------------------------------------------------------------------------
--通信方式相关参数
local innerIOStreamControlConfig = {
    name = "", --通信控制模式,只能是 EnumConstant.ConstEnumIOStreamName的值
    ip = "192.168.5.101",
    port = 502,
    eip = {
        --以下参数都是int类型
        configAssemblyId = 151, --范围[0,255]
        outputAssemblyId = 150, --范围[0,255]
        outputAssemblySize = 224, --范围[0,511]
        inputAssemblyId = 100, --范围[0,255]
        inputAssemblySize = 472 --范围[0,511]
    }
}

--------------------------------------------------------------------------------------------
--控制柜信号参数
local innerControlBoxSignal = {
    arcStart = 0, --起弧DO信号位
    wireFeed = 0, --送丝DO信号位
    wireBack = 0, --退丝DO信号位
    gasCheck = 0, --气检开关DO信号位
    arcStartCheck = 0 --起弧检测DI信号位
}

--IO模拟信号
local innerAnalogIOSignalConfig = {
    controlBoxSignalParam = innerControlBoxSignal --控制柜信号参数，参数请参考 innerControlBoxSignal
}
--------------------------------------------------------------------------------------------

--V-A曲线参数
local innerVAConfig = {
    voltage = 0, --控制器模拟输出电压，单位V
    weldCurrent = 0 --焊机对应的电流，单位A
}

--V-V曲线参数
local innerVVConfig = {
    voltage = 0, --控制器模拟输出电压，单位V
    weldVoltage = 0 --焊机对应的电压，单位V
}

--V-W激光焊曲线参数
local innerLaserVWConfig = {
    voltage = 0, --控制器模拟输出电压，单位V
    weldPower = 0 --焊机对应的功率，单位W
}
--------------------------------------------------------------------------------------------

--激光焊接参数配置
local innerLaserWeldConfig = {
    alias = "", --参数别名
    arcStartPower = 0, --起弧功率，单位W
    arcStartDurationTime = 0, --起弧持续时间，单位ms
    arcEndPower = 0, --收弧功率，单位W
    arcEndDurationTime = 0, --收弧持续时间，单位ms
    weldPower = 0 --焊接功率，单位W
    --[[
    weldSpeed = 0, --焊接速度，单位mm/s
    notWeldSpeed = 0, --空走速度，单位mm/s
    gasSwitch = false, --送气时间是否勾选，true勾选则gasTime起作用，否则不起作用
    gasStartTime = 0, --开关打开的情况下，提前送气时间，单位ms
    gasStopTime = 0 --开关打开的情况下，滞后送气时间，单位ms
    ]]--
}
--------------------------------------------------------------------------------------------

--OTC-MIG/MAG/CO2的控制参数
local innerOTCMigGasCtrlConfig = {
    penetration = false, --渗透控制，true表示ON，false表示OFF
    waterCooledTorch = false, --水冷焊枪，true表示ON，false表示OFF
    waveFreq = 0.0, --摆动频率，0.5~32Hz
    arcValue = 0.0 --电弧控制(调节)参数值
}

--OTC-TIG的控制参数
local innerOTCTigCtrlConfig = {
    clearWidth = 0, --清理宽度，单位：%
    wireFeedDelayTime = 0.0, --延迟送丝时间，单位：秒
    wireFeedIntervalTime = 0.0, --送丝时间（间歇），单位：秒
    stopWireFeedIntervalTime = 0.0, --停止送丝时间（间歇），单位：秒
    wireFeedSpeed = 0.0, --送丝速度，单位：cm/min
    pulseConfig = 0, --脉冲设置，0-无脉冲，1-有脉冲
    pulseFreq = 0.0, --脉冲频率，单位：Hz
    peakCurrent = 0.0, --峰值电流，单位：A
    acFreq = 0.0, --交流频率，单位：Hz
    adcSwitchFreq = 0.0 --AC-DC开关频率，单位：Hz
}

--OTC-TIG的F45参数
local innerOTCTigF45Config = {
    enable = false, --使能开关，true-表示该功能起作用，false-表示不起作用
    slowUpTime = 0.0, --缓升时间，单位：秒
    slowDownTime = 0.0 --缓降时间，单位：秒
}

-------------------------------------------------------------------------------------------
--OTC焊机特有的参数
local innerOTCWeldConfig = {
    preGasTime = 0.0, --预送气时间，单位：秒
    afterGasTime = 0.0, --滞后关气时间，单位：秒
    gasNumber = 0, --气体编号
    wireMaterialNumber = 0, --焊接材料编号
    wireDiameterNumber = 0 --焊丝直径编号
}

--普通焊接非job模式的参数
local innerWeldNotJobModeConfig = {
    alias = "", --参数别名
    arcStartCurrent = 0, --起弧电流，单位A
    arcStartVoltage = 0, --起弧电压，单位V
    arcStartDurationTime = 0, --起弧持续时间，单位ms
    arcEndCurrent = 0, --收弧电流，单位A
    arcEndVoltage = 0, --收弧电压，单位V
    arcEndDurationTime = 0, --收弧持续时间，单位ms
    weldCurrent = 0, --焊接电流，单位A
    weldVoltage = 0, --焊接电压，单位V
    weldSpeed = 0, --焊接速度，单位mm/s
    notWeldSpeed = 0, --空走速度，单位mm/s
    plateThickness = "", --板厚，实际不会用到，仅做显示
    material = "", --材质，实际不会用到，仅做显示
    otc = innerOTCWeldConfig --OTC焊机特有的参数，参考`innerOTCWeldConfig`
}

--普通焊接job模式的参数
local innerWeldJobModeConfig = {
    jobId = 0, --job编号
    processNumber = 0, --程序号，部分焊机有此参数
    weldSpeed = 0, --焊接速度，单位mm/s
    notWeldSpeed = 0 --空走速度，单位mm/s
}
--------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------
--焊机参数数据
local innerWelderParameterData = {
    IOStreamParam = {}, --通信控制模式,参数请参考 innerIOStreamControlConfig
    AnalogIOSignalParam = {}, --控制柜信号，参数请参考 innerAnalogIOSignalConfig
    VAParams = {
        indexAO = 1, --控制器模拟输出AO端口号
        params = {} --VA曲线参数，长度为2的数组，每个对象请参考 innerVAConfig
    },
    VVParams = {
        indexAO = 1, --控制器模拟输出AO端口号
        params = {} --VV曲线参数，长度为2的数组，每个对象请参考 innerVVConfig
    },
    LaserVWParams = {
        indexAO = 1, --控制器模拟输出AO端口号
        params = {} --激光焊VW曲线参数，长度为2的数组，每个对象请参考 innerLaserVWConfig
    },
    LaserWeldParam = nil,
    WeldMode = "", --焊接模式，具体值请参考EnumConstant.ConstEnumWelderWeldMode的值
    WorkMode = "", --工作模式，具体请参考`EnumConstant.ConstEnumWelderWorkMode`的值
    NotJobModeParam = nil,
    JobModeParam = {}, --job模式下的焊接参数，请参考 innerWeldJobModeConfig
    OTCMigCtrlParam = {}, --OTC-MIG/MAG/CO2的控制参数，具体值请参考 innerOTCMigGasCtrlConfig
    OTCTigCtrlParam = {}, --OTC-TIG的控制参数，具体值请参考 innerOTCTigCtrlConfig
    OTCTigF45Param = {}, --OTC-TIG的F45参数，具体值请参考 innerOTCTigF45Config
}
--[[
    LaserWeldParam = {
        selectedId = 1, --当前选中的自定义参数号，通过 params[selectedId] 来选择选中的激光焊参数
        params = {} --激光焊参数，为数组，每个对象请参考 innerLaserWeldConfig
    },
    NotJobModeParam = {
        selectedId = 1, --当前选中的自定义参数号，通过 params[selectedId] 来选择选中的参数
        params = {} --非job模式下的焊接参数，为数组，每个对象请参考 innerWeldNotJobModeConfig
    }
]]--
--------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------
--焊机支持的参数，为了界面根据不同焊机显示不同UI的需要，只作为模板参考，不保存到数据库
local innerWelderSupportParams = {
    communicationType = nil, --所支持的通信类型，为arraystring，每个string值只能是 EnumConstant.ConstEnumIOStreamName 的值
    weldMode = nil, --所支持的焊接模式，为arraystring，每个string值只能是 EnumConstant.ConstEnumWelderWeldMode 的值
    wireSpeedEnable = nil, --焊机是否支持修改送丝机送丝速度，bool类型
    wireStickEnable = nil --焊接是否支持粘丝解除功能,bool类型
}

--【焊机参数配置接口导出】-----------------------------
local WelderParameter = {
    WelderParameterData = {} --参考 innerWelderParameterData
}
WelderParameter.__index = WelderParameter

function WelderParameter:new(className)
    if "string" ~= type(className) then className="" end
    local newObj = {}
    newObj.WelderParameterData = {}
    newObj.databaseKeyConfig = {
        keyIOStreamParam = "Dobot_Weld_Parameter_"..className.."_IOStreamParam",
        keyAnalogIOSignalParam = "Dobot_Weld_Parameter_"..className.."_AnalogIOSignalParam",
        keyVAParams = "Dobot_Weld_Parameter_"..className.."_VAParams",
        keyVVParams = "Dobot_Weld_Parameter_"..className.."_VVParams",
        keyLaserVWParams = "Dobot_Weld_Parameter_"..className.."_LaserVWParams",
        keyLaserWeldParams = "Dobot_Weld_Parameter_"..className.."_LaserWeldParams",
        keyWelderWeldMode = "Dobot_Weld_Parameter_"..className.."_WelderWeldMode",
        keyWelderWorkMode = "Dobot_Weld_Parameter_"..className.."_WelderWorkMode",
        keyNotJobModeParams = "Dobot_Weld_Parameter_"..className.."_NotJobModeParams",
        keyJobModeParams = "Dobot_Weld_Parameter_"..className.."_JobModeParams",
        keyOTCMigCtrlParams = "Dobot_Weld_Parameter_"..className.."_OTCMigCtrlParams",
        keyOTCTigCtrlParams = "Dobot_Weld_Parameter_"..className.."_OTCTigCtrlParams",
        keyOTCTigF45Params = "Dobot_Weld_Parameter_"..className.."_OTCTigF45Params"
    }
    setmetatable(newObj,self)
    return newObj
end

--获取、设置通信控制模式
function WelderParameter:getIOStreamParam()
    local param = GetVal(self.databaseKeyConfig.keyIOStreamParam)
    if nil~=param then return param end
    return innerIOStreamControlConfig
end
function WelderParameter:setIOStreamParam(newValue)
    if nil~=newValue and nil~=newValue.name and ConstEnumIOStreamName[newValue.name] then
        SetVal(self.databaseKeyConfig.keyIOStreamParam, newValue)
        return true
    end
    MyWelderDebugLog(Language.trLang("SET_COMM_MODE_PRM_ERROR"))
    return false
end

--获取、设置模拟通信信号参数
function WelderParameter:getAnalogIOSignalParam()
    local param = GetVal(self.databaseKeyConfig.keyAnalogIOSignalParam)
    if nil~=param then return param end
    return innerAnalogIOSignalConfig
end
function WelderParameter:setAnalogIOSignalParam(newValue)
    SetVal(self.databaseKeyConfig.keyAnalogIOSignalParam, newValue)
    return true
end

--获取、设置VA曲线参数
function WelderParameter:getVAParams()
    local param = GetVal(self.databaseKeyConfig.keyVAParams)
    if nil==param then
        param = {}
        param.indexAO = 1
        param.params = {}
        param.params[1] = innerVAConfig
        param.params[2] = innerVAConfig
    end
    return param
end
function WelderParameter:setVAParams(newValue)
    SetVal(self.databaseKeyConfig.keyVAParams, newValue)
    return true
end

--获取、设置VV曲线参数
function WelderParameter:getVVParams()
    local param = GetVal(self.databaseKeyConfig.keyVVParams)
    if nil==param then
        param = {}
        param.indexAO = 1
        param.params = {}
        param.params[1] = innerVVConfig
        param.params[2] = innerVVConfig
    end
    return param
end
function WelderParameter:setVVParams(newValue)
    SetVal(self.databaseKeyConfig.keyVVParams, newValue)
    return true
end

--获取、设置激光焊VW曲线参数
function WelderParameter:getLaserVWParams()
    local param = GetVal(self.databaseKeyConfig.keyLaserVWParams)
    if nil==param then
        param = {}
        param.indexAO = 1
        param.params = {}
        param.params[1] = innerLaserVWConfig
        param.params[2] = innerLaserVWConfig
    end
    return param
end
function WelderParameter:setLaserVWParams(newValue)
    SetVal(self.databaseKeyConfig.keyLaserVWParams, newValue)
    return true
end

--获取、设置激光焊参数
function WelderParameter:getLaserWeldParam()
    if WelderIsUserApiScript() then
        if nil==self.WelderParameterData.LaserWeldParam then
            WelderScriptStopHook()
            self.WelderParameterData.LaserWeldParam = GetVal(self.databaseKeyConfig.keyLaserWeldParams)
            WelderScriptStartHook()
        end
    else
        self.WelderParameterData.LaserWeldParam = GetVal(self.databaseKeyConfig.keyLaserWeldParams)
    end
    if nil == self.WelderParameterData.LaserWeldParam then
        self.WelderParameterData.LaserWeldParam = {}
        self.WelderParameterData.LaserWeldParam.selectedId = 1
        self.WelderParameterData.LaserWeldParam.params = {}
        self.WelderParameterData.LaserWeldParam.params[1] = innerLaserWeldConfig
    end
    return self.WelderParameterData.LaserWeldParam
end
--满足http接口，没有数据就给个空对象
function WelderParameter:getLaserWeldParamHttp()
    if WelderIsUserApiScript() then
        if nil==self.WelderParameterData.LaserWeldParam then
            WelderScriptStopHook()
            self.WelderParameterData.LaserWeldParam = GetVal(self.databaseKeyConfig.keyLaserWeldParams)
            WelderScriptStartHook()
        end
    else
        self.WelderParameterData.LaserWeldParam = GetVal(self.databaseKeyConfig.keyLaserWeldParams)
        if nil == self.WelderParameterData.LaserWeldParam then
            return {}
        end
    end
    return self.WelderParameterData.LaserWeldParam
end
function WelderParameter:setLaserWeldParam(newValue)
    WelderScriptStopHook()
    SetVal(self.databaseKeyConfig.keyLaserWeldParams, newValue)
    WelderScriptStartHook()
    self.WelderParameterData.LaserWeldParam = newValue
    return true
end

--获取、设置焊接模式（就是一些：平特性、脉冲程序、低飞溅模式.....）
function WelderParameter:getWeldMode()
    local param = GetVal(self.databaseKeyConfig.keyWelderWeldMode)
    if nil~=param then return param end
    return ""
end
function WelderParameter:setWeldMode(newValue)
    if ConstEnumWelderWeldMode[newValue] then
        SetVal(self.databaseKeyConfig.keyWelderWeldMode, newValue)
        return true
    end
    MyWelderDebugLog(Language.trLang("SET_WELD_MODE_PRM_ERROR").."newValue="..tostring(newValue))
    return false
end

--获取、设置工作接模式，只能是`EnumConstant.ConstEnumWelderWorkMode`中的一种
function WelderParameter:getWorkMode()
    local param = GetVal(self.databaseKeyConfig.keyWelderWorkMode)
    if nil==param then param = "monization"
    elseif nil==ConstEnumWelderWorkMode[param] then param = "monization"
    end
    return param
end
function WelderParameter:setWorkMode(newValue)
    if ConstEnumWelderWorkMode[newValue] then
        SetVal(self.databaseKeyConfig.keyWelderWorkMode, newValue)
        return true
    end
    MyWelderDebugLog(Language.trLang("SET_WORK_MODE_PRM_ERROR").."newValue="..tostring(newValue))
    return false
end

--获取、设置非job模式下的焊接参数
function WelderParameter:getNotJobModeParam()
    if WelderIsUserApiScript() then
        if nil==self.WelderParameterData.NotJobModeParam then
            WelderScriptStopHook()
            self.WelderParameterData.NotJobModeParam = GetVal(self.databaseKeyConfig.keyNotJobModeParams)
            WelderScriptStartHook()
        end
    else
        self.WelderParameterData.NotJobModeParam = GetVal(self.databaseKeyConfig.keyNotJobModeParams)
    end
    if nil == self.WelderParameterData.NotJobModeParam then
        self.WelderParameterData.NotJobModeParam = {}
        self.WelderParameterData.NotJobModeParam.selectedId = 1
        self.WelderParameterData.NotJobModeParam.params = {}
        self.WelderParameterData.NotJobModeParam.params[1] = innerWeldNotJobModeConfig
    end
    return self.WelderParameterData.NotJobModeParam
end
--满足http接口，没有数据就给个空对象
function WelderParameter:getNotJobModeParamHttp()
    if WelderIsUserApiScript() then
        if nil==self.WelderParameterData.NotJobModeParam then
            WelderScriptStopHook()
            self.WelderParameterData.NotJobModeParam = GetVal(self.databaseKeyConfig.keyNotJobModeParams)
            WelderScriptStartHook()
        end
    else
        self.WelderParameterData.NotJobModeParam = GetVal(self.databaseKeyConfig.keyNotJobModeParams)
        if nil == self.WelderParameterData.NotJobModeParam then
            return {}
        end
    end
    return self.WelderParameterData.NotJobModeParam
end
function WelderParameter:setNotJobModeParam(newValue)
    WelderScriptStopHook()
    SetVal(self.databaseKeyConfig.keyNotJobModeParams, newValue)
    WelderScriptStartHook()
    self.WelderParameterData.NotJobModeParam = newValue
    return true
end

--获取、设置job模式下的焊接参数
function WelderParameter:getJobModeParam()
    local param = GetVal(self.databaseKeyConfig.keyJobModeParams)
    if nil~=param then return param end
    return innerWeldJobModeConfig
end
--满足http接口，没有数据就给个空对象
function WelderParameter:getJobModeParamHttp()
    local param = GetVal(self.databaseKeyConfig.keyJobModeParams)
    if nil ~= param then return param end
    return {}
end
function WelderParameter:setJobModeParam(newValue)
    SetVal(self.databaseKeyConfig.keyJobModeParams, newValue)
    return true
end

--获取、设置OTC-MIG/MAG/CO2的控制参数
function WelderParameter:getOTCMigCtrlParam()
    local param = GetVal(self.databaseKeyConfig.keyOTCMigCtrlParams)
    if nil~=param then return param end
    return {} --innerOTCMigGasCtrlConfig
end
function WelderParameter:setOTCMigCtrlParam(newValue)
    SetVal(self.databaseKeyConfig.keyOTCMigCtrlParams, newValue)
    return true
end

--获取、设置OTC-TIG的控制参数
function WelderParameter:getOTCTigCtrlParam()
    local param = GetVal(self.databaseKeyConfig.keyOTCTigCtrlParams)
    if nil~=param then return param end
    return {} --innerOTCTigCtrlConfig
end
function WelderParameter:setOTCTigCtrlParam(newValue)
    SetVal(self.databaseKeyConfig.keyOTCTigCtrlParams, newValue)
    return true
end

--获取、设置OTC-TIG的F45参数
function WelderParameter:getOTCTigF45Param()
    local param = GetVal(self.databaseKeyConfig.keyOTCTigF45Params)
    if nil~=param then return param end
    return {} --innerOTCTigF45Config
end
function WelderParameter:setOTCTigF45Param(newValue)
    SetVal(self.databaseKeyConfig.keyOTCTigF45Params, newValue)
    return true
end

return WelderParameter