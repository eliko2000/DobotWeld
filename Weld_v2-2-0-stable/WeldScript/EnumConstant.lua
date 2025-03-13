--[[
枚举常量配置表，所有常量都需要放到这里封装
说明：每个枚举对象中的key默认都给true，这个主要目的就是为了方便table快速查找该枚举中是否含有某个变量，而不需要通过遍历的方式一个一个判断。
      例如：
           local a = "deviceNet"
           if ConstEnumIOStreamName[a] then print("yes") end
]]--

----------------------------------------------------------------------------
--通信方式枚举类型
local innerEnumIOStreamName = {
    modbus = true,
    deviceNet = true,
    analogIO = true,
    eip = true --EtherNet IP
}
innerEnumIOStreamName.__index = innerEnumIOStreamName
innerEnumIOStreamName.__newindex = function(t,k,v)
    print(Language.trLang("NO_SUPPORT_COMM_ENUM")..":k="..tostring(k)..",v="..tostring(v))
end
ConstEnumIOStreamName = setmetatable({},innerEnumIOStreamName)


----------------------------------------------------------------------------
--不同厂家焊机枚举类型
local innerEnumWelderName = {
    Aotai_MIG_LST = true, --奥太
    Aotai_MIG_PLUS = true,
    Megmeet = true, --麦格米特
    Fronius = true, --福尼斯
    Ewm = true, --伊达
    Panasonic = true, --松下
    PanasonicWTDEU = true, --唐山松下WTDEUxxxZZ系列
    Lorch = true, --洛驰
    Lincoln_Digiwave = true, --林肯沙福
    Lincoln_Powerwave = true, --林肯红色powerwave
    Flama = true, --和宗
    GYS = true, --GYS焊机
    SKS = true, --SKS焊机
    Kemppi = true, --Kemppi焊机DCM
    KemppiAX = true, --Kemppi AX焊机
    OTCMig = true, --OTC-MIG/MAG/CO2焊机
    OTCTig = true, --OTC-Tig焊机
    Cloos = true, --Cloos焊机
    ESAB = true, --ESAB焊机
    ESABChina = true, --国内版的ESAB焊机
    Miller = true, --米勒焊机
    Kolarc = true, --Kolarc焊机
    Laser = true, --激光焊机
    Virtual = true, --虚拟焊机,用于演示功能，无实际焊机
    Other = true --其他焊机，除了上述之外的焊机
}
innerEnumWelderName.__index = innerEnumWelderName
innerEnumWelderName.__newindex = function(t,k,v)
    print(Language.trLang("NO_SUPPORT_WELDER_ENUM")..":k="..tostring(k)..",v="..tostring(v))
end
ConstEnumWelderName = setmetatable({},innerEnumWelderName)


----------------------------------------------------------------------------
--不同厂家激光器寻位跟踪插件枚举类型
local innerEnumLaserPluginName = {
    MingTu = true, --苏州明图
    Intelligen = true, --唐山英莱
    FullVision = true, --苏州全视
    CrownThought = true --北京创想
}
innerEnumLaserPluginName.__index = innerEnumLaserPluginName
innerEnumLaserPluginName.__newindex = function(t,k,v)
    print(Language.trLang("NO_SUPPORT_LASER_PLUGIN_ENUM")..":k="..tostring(k)..",v="..tostring(v))
end
ConstEnumLaserPluginName = setmetatable({},innerEnumLaserPluginName)


----------------------------------------------------------------------------
--摆弧类型枚举
local innerEnumWeaveType = {
    line = true, --直线形
    triangle = true, --锯齿焊
    spiral = true, --螺旋形摆焊
    trapezoid = true, --梯形摆焊
    sine = true, --正弦形摆焊
    crescent = true, --月牙形摆焊
    triangle3D = true --立体3D三角摆焊
}
innerEnumWeaveType.__index = innerEnumWeaveType
innerEnumWeaveType.__newindex = function(t,k,v)
    print(Language.trLang("NO_SUPPORT_WAVE_ENUM")..":k="..tostring(k)..",v="..tostring(v))
end
ConstEnumWeaveType = setmetatable({},innerEnumWeaveType)


----------------------------------------------------------------------------
--工作模式
local innerEnumWelderWorkMode = {
    monization = true, --一元化模式，默认值
    respectively = true --分别模式
}
innerEnumWelderWorkMode.__index = innerEnumWelderWorkMode
innerEnumWelderWorkMode.__newindex = function(t,k,v)
    print(Language.trLang("NO_SUPPORT_WORK_MODE_ENUM")..":k="..tostring(k)..",v="..tostring(v))
end
ConstEnumWelderWorkMode = setmetatable({},innerEnumWelderWorkMode)

--焊接模式
local innerEnumWelderWeldMode = {
    job = true, --job号模式(好多焊机共用这个，对于奥太焊机这个就是callState调用模式)
    
    --奥太焊机专属属性
    flat = true, --平特性
    pulseProcess = true, --脉冲程序
    --callState = true, 就是job模式，沿用上面job字段名称
    lowSplash = true, --低飞溅模式
    flatSpotWeld = true, --平特性点焊
    pulseSpotWeld = true, --脉冲点焊
    lowSplashSpotWeld = true, --低飞溅点焊
    bigPenetration = true, --大熔深
    fastPulse = true, --快速脉冲
    
    --EWM焊机专属属性
    twoStepDCWeld = true, --两步常规直流焊（操作模式：两步，焊接方法：常规直流焊）
    twoStepPulseWeld = true, --两步脉冲焊（操作模式：两步，焊接方法：脉冲焊）
    specialTwoStepDCWeld = true, --特殊两步常规直流焊（操作模式：特殊两步，焊接方法：常规直流焊）
    specialTwoStepPulseWeld = true, --特殊两步脉冲焊（操作模式：特殊两步，焊接方法：脉冲焊）
    
    --福尼斯Fronius焊机专属属性，目前暂不支持这个，先屏蔽掉
    --internalParamSelect = true, --内部参数选择
    --specialTwoStepModeChar = true, --特殊两步模式特性
    --twoStepModeChar = true, --两步模式特性
    
    --松下Panasonic焊机专属属性，目前暂不支持的先屏蔽
    independentCurrentMode = true, --独立调节/电流优先模式
    --idenpendentWireFeedMode = true, --独立调节/送丝速度优先模式
    monizationCurrentMode = true, --一元化调节/电流优先模式
    --monizationWireFeedMode = true, --一元化调节/送丝速度优先模式
    
    --OTC焊机的一些属性
    dcPulse = true, --直流脉冲
    dc = true, --直流电
    dcLowSplash = true, --直流低溅射
    dcWavePulse = true, --直流波脉冲
    acPulse = true, --交流脉冲
    acWavePulse = true, --交流波脉冲
    dArc = true, --D-Arc
    msMig = true, --MS-MIG
    -------
    dcTig = true, --直流TIG
    acTig = true, --交流TIG
    adcTig = true, --AC-DC TIG
    plasma = true, --等离子体
    
    --ESABChina焊机的一些属性
    dcMig = true, --恒压
    dpt = true, --深熔焊
    singlePulse = true, --单脉冲
    doublePulse = true, --双脉冲
    dpp = true, --熔深脉冲
    hybridPulse = true, --混合脉冲
    --callJobState = true, 就是job模式，沿用上面job字段名称
    
    --部分焊机支持的属性
    monizationDC = true, --直流一元化
    singlePulseMonization = true, --单脉冲一元化
    pulseMonization = true, --脉冲一元化
    proximityMode = true, --近控模式
    respectivelyMode = true, --分别模式
    cccvMode = true, --CC/CV模式
    tigMode = true, --TIG模式
    cmtMode = true --CMT模式
}
innerEnumWelderWeldMode.__index = innerEnumWelderWeldMode
innerEnumWelderWeldMode.__newindex = function(t,k,v)
    print(Language.trLang("NO_SUPPORT_WELD_MODE_ENUM")..":k="..tostring(k)..",v="..tostring(v))
end
ConstEnumWelderWeldMode = setmetatable({},innerEnumWelderWeldMode)


----------------------------------------------------------------------------
--多语言
local innerEnumLanguage = {
    zh = true,
    en = true,
    ja = true,
    de = true
}
innerEnumLanguage.__index = innerEnumLanguage
innerEnumLanguage.__newindex = function(t,k,v)
    print(Language.trLang("NO_SUPPORT_LANGUAGE_ENUM")..":k="..tostring(k)..",v="..tostring(v))
end
ConstEnumLanguage = setmetatable({},innerEnumLanguage)

----------------------------------------------------------------------------
--接口错误码定义
local innerEnumApiErrCode = {
    OK = 0, --OK，没有错误
    ScriptErr = -1, --内部错误、脚本报错
    Comm_Err = 1, --通信错误
    Param_Err = 2, --参数错误
    Not_Connected = 3, --焊机未连接
    ConnectWelder_Err = 4, --连接焊机失败
    InitWelder_Err = 5, --初始化焊机失败
    WelderNoReady_Err = 6, --焊机没有准备好
    SetWeldMode_Err = 7, --设置焊接模式失败
    SetJob0_Err = 8, --非job模式参数设置为0失败
    SetJob_Err = 9, --设置job号失败
    SetProcessNum_Err = 10, --设置程序号失败
    SetArcCurrent_Err = 11, --设置起弧电流失败
    SetArcVoltage_Err = 12, --设置起弧电压失败
    SetWeldCurrent_Err = 13, --设置焊接电流失败
    SetWeldVoltage_Err = 14, --设置焊接电压失败
    SetArcParam_Err = 15, --设置起弧相关参数失败
    SetWeldParam_Err = 16, --设置焊接相关参数失败
    TriggerArc_Err = 17, --发起起弧指令失败
    CheckArc_Err = 18, --未检测到起弧成功反馈信号
    EndArc_Err = 19, --灭弧失败
    ConnectLaser_Err = 20, --连接激光器失败
    OpenLaser_Err = 21, --打开激光器失败
    CloseLaser_Err = 22, --关闭激光器失败
    SetWeldPower_Err = 23 --设置焊接功率失败
}
innerEnumApiErrCode.__index = innerEnumApiErrCode
innerEnumApiErrCode.__newindex = function(t,k,v)
    print(Language.trLang("NO_SUPPORT_ERRCODE_ENUM")..":k="..tostring(k)..",v="..tostring(v))
end
ConstEnumApiErrCode = setmetatable({},innerEnumApiErrCode)