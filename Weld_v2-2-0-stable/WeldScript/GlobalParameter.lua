--焊机公共全局变量配置参数表
--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
--【异常特殊处理】--
local innerSpecialHandle = {}
--起弧重试
innerSpecialHandle.arcRetry = {
    isRetry = false, --是否勾选该功能，true表示该功能起作用，否则不起作用
    retryCount = 1, --重试次数
    forwardDistance = 5, --前进距离，单位mm
    wireBackTime = 1000 --再起弧时焊丝回缩的时间，单位ms
}
--断弧再起弧
innerSpecialHandle.arcAbnormalStop = {
    isRetry = false, --是否勾选该功能，true表示该功能起作用，否则不起作用
    retryCount = 1, --重试次数
    backDistance = 5 --中途断弧回退距离，单位mm
}
--粘丝解除
innerSpecialHandle.stickRelease = {
    isRelease=false, --是否勾选该功能，true表示该功能起作用，否则不起作用
    voltage=3, --粘丝电压，单位V
    current=20, --粘丝电流，单位A
    durationTime=1000 --电流保持时间，单位ms
}

--------------------------------------------------------------------------------------------
--【摆弧工艺参数】--
local innerWeaveParams = {
    weaveType = "line", --摆弧类型，只能是 EnumConstant.ConstEnumWeaveType中的值
    alias = "", --参数别名
    frequency = 1.0, --摆动频率
    startDirection = 1, --摆弧启动方向：左摆=0，右摆=1
    amplitudeLeft = 1.0, --左振幅，单位mm
    amplitudeRight = 1.0, --右振幅，单位mm
    amplitude = 1.0, --摆动振幅，单位mm
    radius = 1.0, --半径，单位mm
    radian = 0.0, --月牙摆弧度，单位%
    angle = 0.0, --角度，单位° 范围[0,180]
    stopMode = { --停止方式
        checked = false, --是否勾选了停止方式，true表示勾选，当为false时，mode需要强制设置为0并发给控制器
        mode = 0, --停止方式：机器人停止=0，摆焊停止焊枪可动=1
        stopTime = {0,0,0,0} --4个点停止时间，单位s
    } 
}

--------------------------------------------------------------------------------------------
--【点焊的配置参数】--
local innerSpotWeldParams = {
    switch = false, --点焊开关，true表示开启点焊，false表示关闭点焊
    voltage = 0, --点焊下发电压，单位V
    current = 0, --点焊下发电流，单位A
    durationTime = 0, --点焊持续时间，单位ms
    jobId = 0, --job编号
    processNumber = 0 --程序号，部分焊机有此参数
}

--------------------------------------------------------------------------------------------
--【点位信号配置】--
local innerPointsSignalParam = {
    approachDI = { --接近点DI信号位
        detectType = 1, --检测方式，控制柜=1，末端=2
        signalDI = 0 --DI信号位
    },
    arcStartDI = { --起弧点DI信号位
        detectType = 1, --检测方式，控制柜=1，末端=2
        signalDI = 0 --DI信号位
    },
    arcEndDI = { --灭弧点DI信号位
        detectType = 1, --检测方式，控制柜=1，末端=2
        signalDI = 0 --DI信号位
    },
    middleArcDI = { --中间圆弧点DI信号位
        detectType = 1, --检测方式，控制柜=1，末端=2
        signalDI = 0 --DI信号位
    },
    middleLineDI = { --中间直线点DI信号位
        detectType = 1, --检测方式，控制柜=1，末端=2
        signalDI = 0 --DI信号位
    },
    leaveDI = { --离开DI信号位
        detectType = 1, --检测方式，控制柜=1，末端=2
        signalDI = 0 --DI信号位
    }
}

--------------------------------------------------------------------------------------------
--全局碰撞检测信号
local innerGlobalCollisionDetection = {
    detectType = 1, --检测方式，控制柜=1，末端=2
    signalDI = 0 --DI信号位
}
--示教存点检测信号
local innerGlobalTeachPointDetection = {
    detectType = 1, --检测方式，控制柜=1，末端=2
    signalDI = 0 --DI信号位
}
--全局接触寻位信号
local innerTouchPositionSignal = {
    enableDO = 0, --寻位使能DO
    successDI = 0, --寻位成功DI
    failDO =0 --寻位失败DO
}
--全局IO模拟信号
local innerGlobalAnalogIOSignalConfig = {
    touchPositionParam = innerTouchPositionSignal, --接触寻位信号
    collisionDetectionParam = innerGlobalCollisionDetection, --碰撞检测信号
    teachPointParam = innerGlobalTeachPointDetection --示教存点检测信号
}

--------------------------------------------------------------------------------------------
--【焊机实时运行状态信息，并不是所有焊机都有下列参数，也并不是所有通信方式都能获取下列参数，无法获取值的不管】
local innerWeldRunStateInfo = {
    connectState = false, --true表示连接，false表示断开了连接
    weldVoltage = 0.0, --焊接电压
    weldCurrent = 0.0, --焊接电流
    wireFeedSpeed = 0.0, --送丝速度
    weldSpeed = 0.0, --焊接速度
    weldState = 0, --焊接状态，0-焊接结束/待机、1-焊接中、2-焊接异常
    wireState = 0, --焊丝状态，0-正常、1-焊丝粘结
    errcode = 0 --错误码
}

--------------------------------------------------------------------------------------------
--【焊接运行时间的统计】
local innerWeldCostTimeInfo = {
    totalTime = 0, --所有次数累计总时间，单位ms
    costTime = 0, --本此焊接耗时，单位ms
    scriptTimestamp = nil, --脚本启动开始计时的时间戳，不为nil表示开始计时，为nil表示没有开始计时
    isWeld = nil --为nil表示不是焊接的程序，非nil表示焊接的程序启动的计时
}

--------------------------------------------------------------------------------------------
--【多层多道焊】
local innerMultipleWeld = {
    alias = "", --参数别名
    startX = 0.0, --起点沿焊道坐标系X方向偏移距离，正值为延长,单位: mm
    endX = 0.0, --终点沿焊道坐标系X方向偏移距离，正值为延长,单位: mm
    y = 0.0, --起点和终点沿焊道坐标系Y方向的偏移距离,单位: mm
    z = 0.0, --起点和终点沿焊道坐标系Z方向的偏移距离,单位: mm
    workAngle = 0.0, --焊枪沿焊道坐标系X方向旋转，正值沿X负方向,单位: 度°
    travelAngle = 0.0, --焊枪沿焊道坐标系Z方向旋转，正值沿Z正方向,单位: 度°
    waitTime = 0, --等待时间,单位: ms
    plane = 1 --参考坐标系,1,2,3分别表示X,Y,Z方向，X为焊接指令前进方向，Z为参考坐标系Z向，Y为垂直于XZ平面的方向
}

--【多层多道焊的索引组合】
--可以通过组合索引，选择多个“多层多道焊”分别依次执行，是一个int类型的二维数组，数据结构如下，
local innerMultipleWeldGroup = {
    {1},{1,2},{1,2,3}
}

--------------------------------------------------------------------------------------------
--【电弧跟踪】
local innerArcTrackParams = {
    alias = "", --参数别名
    --上下跟踪参数-------
    upDownCoordinateType = 0, --坐标系类型：1-用户坐标，2-工具坐标，3-焊接/道坐标
    upDownCompensationSwitch = 1, --上下补偿开关 0：关 1：开
    upDownDatumCurrentSetting = 0, --上下基准电流设定(常数/反馈) 0：反馈 1：常数 默认反馈
    upDownDatumCurrent = 100, --上下基准电流 A (>= 0)
    upDownSampleTime = 500, --上下采样时间 ms (0 ~ 10 000)
    upDownAmplification = 20, --上下增益系数 (0 ~ 999)
    upDownCompensationOffset = 0, --上下补偿偏移量 % (-100 ~ 100)
    upDownPeriodCompensationMin = 0, --上下周期最小补偿量 mm (0 ~ 999)
    upDownPeriodCompensationMax = 10, --上下周期最大补偿量 mm (0 ~ 9999) 
    upDownCompensationMax = 100, --上下累计最大补偿量 mm (0 ~ 9999)
    upDownCompensationStartCount = 4, --上下补偿开始计数 pcs (>=0)
    upDownSampleStartCount = 3, --上下反馈基准电流采样开始计数 pcs (>=0)
    upDownDatumCurrentSampleCount = 1, --上下反馈基准电流采样计数 pcs (>=1)
    --左右跟踪参数-------
    leftRightCompensationSwitch = 1, --左右补偿开关 0：关 1：开
    leftRightAmplification = 20, --左右增益系数 (0 ~ 999)
    leftRightCompensationOffset = 0, --左右补偿偏移量 % (-100 ~ 100)
    leftRightPeriodCompensationMin = 0, --左右周期最小补偿量 mm (0 ~ 999)
    leftRightPeriodCompensationMax = 10, --左右周期最大补偿量 mm (0 ~ 9999)
    leftRightCompensationMax = 100, --左右累计最大补偿量 mm (0 ~ 9999)
    leftRightCompensationStartCount = 2 --左右补偿开始计数 pcs (>=0)
}

-------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------
--数据库保存的key，不要轻易修改------------------------------------------------------------------------------
local keySelectedWelderName = "Dobot_Weld_Parameter_GlobalParameter_SelectedWelderName"
local keyVirtualWeldName = "Dobot_Weld_Parameter_GlobalParameter_VirtualWeld"
local keyHasWelderName = "Dobot_Weld_Parameter_GlobalParameter_HasWelder"
local keySpecialHandleParams = "Dobot_Weld_Parameter_GlobalParameter_SpecialHandleParams"
local keyWeaveParams = "Dobot_Weld_Parameter_GlobalParameter_WeaveParams"
local keySpotWeldParams = "Dobot_Weld_Parameter_GlobalParameter_SpotWeldParams"
local keyPointsSignalParam = "Dobot_Weld_Parameter_GlobalParameter_PointsSignalParam"
local keyGlobalAnalogIOSignalParam = "Dobot_Weld_Parameter_GlobalParameter_AnalogIOSignalParam"
local keyWeldRunStateInfoParams = "Dobot_Weld_Parameter_GlobalParameter_WeldRunStateInfoParams"
local keyIsWeldingFlagParams = "Dobot_Weld_Parameter_GlobalParameter_IsWeldingFlagParams"
local keyIsArcStartingFlagParams = "Dobot_Weld_Parameter_GlobalParameter_IsArcStartingFlagParams"
local keyMultipleWeldParams = "Dobot_Weld_Parameter_GlobalParameter_MultipleWeldParams"
local keyMultipleWeldGroup = "Dobot_Weld_Parameter_GlobalParameter_MultipleWeldGroup"
local keyArcTrackParams = "Dobot_Weld_Parameter_GlobalParameter_ArcTrackParams"
local keyWeldCostTimeInfoParams = "Dobot_Weld_Parameter_GlobalParameter_WeldCostTimeInfoParams"
local keyButtonBoxOnOffParams = "Dobot_Weld_Parameter_GlobalParameter_ButtonBoxOnOff"
local keyWeldScriptRunErrorCode = "Dobot_Weld_Parameter_GlobalParameter_WeldScriptRunErrorCode"

-------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------
--【焊接全局变量操作接口导出】-------------------------------------------------------------------------------
local GlobalParameter = {
    currentSelectedWelder = nil, --当前选中的焊机（焊机只能是EnumConstant.ConstEnumWelderName的值）
    virtualWeld = true, --是否为虚拟焊接，true为虚拟焊，false不是
    hasWelder = false, --是否有焊机，true有焊机，false无焊机
    SpecialHandleParam = {}, --异常特殊处理，参数请参考 innerSpecialHandle
    WeaveParam = nil,
    MultiWeldParam = nil,
    MultipleWeldGroup = nil,
    ArcTrackParam = {
        svp0DO = 0, --svp0的DO信号
        svp1DO = 0, --svp1的DO信号
        fileId = nil, --当前选择的通道，通过 params[fileId] 来选择当前的参数
        params = nil --电弧跟踪参数,为数组,每个对象数据参考 innerArcTrackParams
    },
    SpotWeldParam = {}, --点焊的配置参数，请参考 innerSpotWeldParams
    PointsSignalParam = {}, --点焊的配置参数，请参考 innerPointsSignalParam
    GlobalAnalogIOSignalParam = {}, --全局IO模拟量信号，请参考 innerGlobalAnalogIOSignalConfig
    buttonBoxOnOff = false --按钮盒子的开关状态
}
--[[
    WeaveParam = {
        fileId = 1, --摆动文件参数号，通过 params[fileId] 来选择当前的摆焊参数
        params = {} --摆弧数据,为数组,每个对象数据参考 innerWeaveParams
    },
    MultiWeldParam = {
        fileId = 1, --多层多道参数号，通过 params[fileId] 来选择当前的参数
        params = {} --数据,为数组,每个对象数据参考 innerMultipleWeld
    },
    MultipleWeldGroup = {{1,2,3},{4,5,6},{1,2}} --参考 innerMultipleWeldGroup
]]--

--获取、设置当前选中的焊机（焊机只能是EnumConstant.ConstEnumWelderName的值）
function GlobalParameter.getSelectedWelder()
    if WelderIsUserApiScript() then
        if nil==GlobalParameter.currentSelectedWelder then
            GlobalParameter.currentSelectedWelder = GetVal(keySelectedWelderName)
        end
    else
        GlobalParameter.currentSelectedWelder = GetVal(keySelectedWelderName)
    end
    if nil~=GlobalParameter.currentSelectedWelder then return GlobalParameter.currentSelectedWelder end
    return ""
end
function GlobalParameter.setSelectedWelder(newValue)
    if ConstEnumWelderName[newValue] then
        SetVal(keySelectedWelderName,newValue)
        GlobalParameter.currentSelectedWelder = newValue
        return true
    end
    MyWelderDebugLog(Language.trLang("SET_WELDER_PRM_ERROR").."newValue="..tostring(newValue))
    return false
end

--获取、设置虚拟焊
function GlobalParameter.isVirtualWeld()
    local param = GetVal(keyVirtualWeldName)
    if nil~=param then return param end
    return true
end
function GlobalParameter.setVirtualWeld(newValue)
    SetVal(keyVirtualWeldName,newValue)
    return true
end

--获取、设置有无焊机
function GlobalParameter.isHasWelder()
    local param = GetVal(keyHasWelderName)
    if nil~=param then return param end
    return false
end
function GlobalParameter.setHasWelder(newValue)
    SetVal(keyHasWelderName,newValue)
    return true
end

--获取、设置特殊处理参数，请参考SpecialHandle表
function GlobalParameter.getSpecialHandleParams()
    local param = GetVal(keySpecialHandleParams)
    if nil~=param then return param end
    return innerSpecialHandle
end
function GlobalParameter.setSpecialHandleParams(newValue)
    SetVal(keySpecialHandleParams,newValue)
    return true
end

--获取、设置WeaveParams参数
function GlobalParameter.getWeaveParam()
    if WelderIsUserApiScript() then
        if nil==GlobalParameter.WeaveParam then
            WelderScriptStopHook()
            GlobalParameter.WeaveParam = GetVal(keyWeaveParams)
            WelderScriptStartHook()
        end
    else
        GlobalParameter.WeaveParam = GetVal(keyWeaveParams)
    end
    return GlobalParameter.WeaveParam
end
function GlobalParameter.setWeaveParam(newValue)
    WelderScriptStopHook()
    SetVal(keyWeaveParams,newValue)
    WelderScriptStartHook()
    GlobalParameter.WeaveParam = newValue
    return true
end

--获取、设置MultiWeldParams参数
function GlobalParameter.getMultipleWeldParam()
    if WelderIsUserApiScript() then
        if nil==GlobalParameter.MultiWeldParam then
            WelderScriptStopHook()
            GlobalParameter.MultiWeldParam = GetVal(keyMultipleWeldParams)
            WelderScriptStartHook()
        end
    else
        GlobalParameter.MultiWeldParam = GetVal(keyMultipleWeldParams)
    end
    return GlobalParameter.MultiWeldParam
end
function GlobalParameter.setMultipleWeldParam(newValue)
    WelderScriptStopHook()
    SetVal(keyMultipleWeldParams,newValue)
    WelderScriptStartHook()
    GlobalParameter.MultiWeldParam = newValue
    return true
end

--获取、设置innerMultipleWeldGroup参数
function GlobalParameter.getMultipleWeldGroup()
    if WelderIsUserApiScript() then
        if nil==GlobalParameter.MultipleWeldGroup then
            WelderScriptStopHook()
            GlobalParameter.MultipleWeldGroup = GetVal(keyMultipleWeldGroup)
            WelderScriptStartHook()
        end
    else
        GlobalParameter.MultipleWeldGroup = GetVal(keyMultipleWeldGroup)
    end
    return GlobalParameter.MultipleWeldGroup
end
function GlobalParameter.setMultipleWeldGroup(newValue)
    WelderScriptStopHook()
    SetVal(keyMultipleWeldGroup,newValue)
    WelderScriptStartHook()
    GlobalParameter.MultipleWeldGroup = newValue
    return true
end

--获取、设置ArcTrackParams参数
function GlobalParameter.getArcTrackParam()
    WelderScriptStopHook()
    GlobalParameter.ArcTrackParam = GetVal(keyArcTrackParams)
    WelderScriptStartHook()
    if type(GlobalParameter.ArcTrackParam)=="table" then
        GlobalParameter.ArcTrackParam.svp0DO = 51
        GlobalParameter.ArcTrackParam.svp1DO = 52
    end
    return GlobalParameter.ArcTrackParam
end
function GlobalParameter.setArcTrackParam(newValue)
    WelderScriptStopHook()
    SetVal(keyArcTrackParams,newValue)
    WelderScriptStartHook()
    GlobalParameter.ArcTrackParam = newValue
    if type(GlobalParameter.ArcTrackParam)=="table" then
        GlobalParameter.ArcTrackParam.svp0DO = 51
        GlobalParameter.ArcTrackParam.svp1DO = 52
    end
    return true
end

--获取、设置点焊配置参数，请参考SpotWeldParam表
function GlobalParameter.getSpotWeldParam()
    local param = GetVal(keySpotWeldParams)
    --[[
    if nil~=param then return param end
    return innerSpotWeldParams
    ]]--
    return param
end
function GlobalParameter.setSpotWeldParam(newValue)
    SetVal(keySpotWeldParams,newValue)
    return true
end

--获取、设置点位信号配置，请参考PointsSignalParam表
function GlobalParameter.getPointsSignalParam()
    local param = GetVal(keyPointsSignalParam)
    if nil~=param then return param end
    return innerPointsSignalParam
end
function GlobalParameter.setPointsSignalParam(newValue)
    SetVal(keyPointsSignalParam,newValue)
    return true
end

--获取、设置点位信号配置，请参考GlobalAnalogIOSignalParam表
function GlobalParameter.getAnalogIOSignalParam()
    local param = GetVal(keyGlobalAnalogIOSignalParam)
    if nil~=param then return param end
    return innerGlobalAnalogIOSignalConfig
end
function GlobalParameter.setAnalogIOSignalParam(newValue)
    SetVal(keyGlobalAnalogIOSignalParam,newValue)
    return true
end

--[[
--获取焊机当前的运行状况信息，请参考本文的`innerWeldRunStateInfo`说明
--这里之所以直接从数据库中获取，是因为saveWelderRunStateInfo是在deamon.lua进程中操作的，
--而getWelderRunStateInfo是在httpAPI进程调用的，不同进程数据共享只能折中操作
]]--
function GlobalParameter.getWelderRunStateInfo()
    return GetVal(keyWeldRunStateInfoParams)
end
--保存焊机状态信息
function GlobalParameter.saveWelderRunStateInfo(newValue)
    SetVal(keyWeldRunStateInfoParams,newValue)
    return true
end

--获取焊接的总时长、单次时长,具体参考`innerWeldCostTimeInfo`
function GlobalParameter.getWeldCostTimeInfo()
    local v = GetVal(keyWeldCostTimeInfoParams) or {totalTime=0,costTime=0}
    if type(v)~="table" then
        return {totalTime=0,costTime=0}
    else
        return {totalTime=v.totalTime,costTime=v.costTime}
    end
end
--清空数据
function GlobalParameter.clearWeldCostTimeInfo()
    SetVal(keyWeldCostTimeInfoParams,nil)
    return true
end
--记录脚本启动时的时间戳
function GlobalParameter.recordScriptStartTimestamp()
    local v = GetVal(keyWeldCostTimeInfoParams) or {totalTime=0,costTime=0}
    v.scriptTimestamp = Systime()
    SetVal(keyWeldCostTimeInfoParams,v)
    return true
end
--获取脚本启动时到现在的时间差信息，返回nil表示脚本没启动
function GlobalParameter.getScriptStartTimeInfo()
    local v = GetVal(keyWeldCostTimeInfoParams)
    if type(v)~="table" then return nil end
    if math.type(v.totalTime)~="integer" or math.type(v.scriptTimestamp)~="integer" then return nil end
    v.costTime = Systime() - v.scriptTimestamp
    v.totalTime = v.totalTime + v.costTime
    return {totalTime=v.totalTime,costTime=v.costTime}
end

--记录是焊接脚本的程序在跑
function GlobalParameter.recordWeldScriptStarted()
    local v = GetVal(keyWeldCostTimeInfoParams) or {totalTime=0,costTime=0}
    v.isWeld = true
    SetVal(keyWeldCostTimeInfoParams,v)
    return true
end
--更新本此焊接程序消耗的时间和总时间,通常是在脚本停止运行时调用,也就是在守护进程中使用
function GlobalParameter.updateWeldCostTime()
    local tv = nil
    local v = GetVal(keyWeldCostTimeInfoParams) or {totalTime=0,costTime=0}
    if true==v.isWeld and v.scriptTimestamp~=nil then --是焊接程序才会记录时间
        tv = {}
        tv.costTime = Systime() - v.scriptTimestamp
        tv.totalTime = v.totalTime + tv.costTime
        SetVal(keyWeldCostTimeInfoParams,tv) --只保留2个参数即可
    else --如果脚本发生了崩溃，可能上述条件还不满足，那么需要将数据还原
        tv = {totalTime=v.totalTime,costTime=v.costTime}
        SetVal(keyWeldCostTimeInfoParams,tv)
    end
    return tv
end

--当前是否为起弧焊接中的状态实时读取，true-表示成功起弧了并处于焊接中，false-表示没有起弧成功不是焊接中
function GlobalParameter.isWelding()
    local param = GetVal(keyIsWeldingFlagParams)
    if nil~=param then return param end
    return false
end
function GlobalParameter.setWelding(isStarted)
    SetVal(keyIsWeldingFlagParams,isStarted)
    return true
end

--[[
当前进入/退出起弧流程的态实时读取，true-表示进入起弧流程，false-表示退出起弧流程
`isArcStarting()`仅仅只是代表是否进入起弧流程，不代表是否需要起弧焊接，也不代表是否处于起弧焊接中。
`isWelding()`代表是否起弧成功并处于焊接中。
]]--
function GlobalParameter.isArcStarting()
    local param = GetVal(keyIsArcStartingFlagParams)
    if nil~=param then return param end
    return false
end
function GlobalParameter.setArcStarting(isStarted)
    SetVal(keyIsArcStartingFlagParams,isStarted)
    return true
end

--获取/设置按钮盒子的开关状态
function GlobalParameter.getButtonBoxOnOff()
    local param = GetVal(keyButtonBoxOnOffParams)
    if nil~=param then return param end
    return false
end
function GlobalParameter.setButtonBoxOnOff(newValue)
    SetVal(keyButtonBoxOnOffParams,newValue)
    return true
end

--[[
为了按钮盒子示教器而增加的脚本报错信息记录的交互接口
]]--
function GlobalParameter.setWeldScriptRunErrorCode(code)
    if not code then code = 4192 end
    SetVal(keyWeldScriptRunErrorCode, code)
    return true
end
function GlobalParameter.getWeldScriptRunErrorCode()
    local param = GetVal(keyWeldScriptRunErrorCode)
    if nil==param or 0==param then
        return 0
    end
    return param
end
function GlobalParameter.clearWeldScriptRunErrorCode()
    SetVal(keyWeldScriptRunErrorCode, 0)
    return true
end

return GlobalParameter