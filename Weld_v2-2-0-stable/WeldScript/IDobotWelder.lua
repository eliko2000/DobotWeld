--[[
焊机接口类，为了统一描述对外接口，让子类去实现具体功能
]]--

local IDobotWelder = {}
IDobotWelder.__index = IDobotWelder

function IDobotWelder:new()
    return setmetatable({},self)
end


--[[
功能：设置/获取api调用接口错误码
参数：code-错误码
返回值：错误码值，请参考`EnumConstant.ConstEnumApiErrCode`说明
]]--
function IDobotWelder:setApiErrCode(code)
    self.apiCode = code
end
function IDobotWelder:getApiErrCode()
    return self.apiCode or ConstEnumApiErrCode.OK
end

--[[
功能：获取焊机参数对象类
参数：无
返回值：为WelderParameter的子类对象
]]--
function IDobotWelder:getWelderParamObject()
    return nil
end

--[[
功能：获取焊机通信对象
参数：无
返回值：返回iostream对象
]]--
function IDobotWelder:getIOStreamObject()
    return nil
end

--[[
功能：获取焊机支持的参数列表，不同焊机，因为参数不一样，界面要显示不同，该接口主要列出焊机参数的差异性
参数：无
返回值：请参考 WelderParameter.innerWelderSupportParams
]]--
function IDobotWelder:getSupportParams()
    return {}
end

--[[
功能：焊机连接，包括焊机的通信方式创建、连接、以及一些准备焊接，让子类去实现
参数：无
返回值：true表示连接成功，false表示连接失败
]]--
function IDobotWelder:connect()
    return false
end

--[[
功能：焊机断开连接
参数：无
返回值：无
]]--
function IDobotWelder:disconnect()
end

--[[
功能：是否连接了焊机
参数：无
返回值：true-表示连接了，false表示没有连接
]]--
function IDobotWelder:isConnected()
    return false
end

--[[
功能：使能打开、关闭焊丝接触寻位功能
参数：bEnable-true表示使能打开，false表示使能关闭
返回值：true表示设置成功，false表示设置失败，nil表示通信异常
]]--
function IDobotWelder:setTouchPostionEnable(bEnable)
    return false
end

--[[
功能：焊丝接触寻位成功状态
参数：无
返回值：true表示寻位成功，false表示寻位失败，nil表示通信异常
]]--
function IDobotWelder:isTouchPositionSuccess()
    return false
end

--[[
功能：设置寻位失败时的状态
参数：bStatus-true表示ON，false表示OFF
返回值：true表示设置成功，false表示设置失败，nil表示通信异常
]]--
function IDobotWelder:setTouchPositionFailStatus(bStatus)
    return false
end

--[[
功能：判断焊机是否为job焊接模式
参数：无
返回值：true为job模式，false为非job模式
]]--
function IDobotWelder:isJobMode()
    return false
end

--[[
功能：设置工作模式（分别模式、一元化模式）
参数：newVal-工作模式，请参考`EnumConstant.ConstEnumWelderWorkMode`
返回值：true表示设置成功，false表示设置失败
说明：有的没有这些值，所以默认返回true
]]--
function IDobotWelder:setWorkMode(newVal)
    return true
end

--[[
功能：设置焊接模式
参数：newVal-焊接模式，请参考`EnumConstant.ConstEnumWelderWeldMode`
返回值：true表示设置成功，false表示设置失败
说明：如果焊机没有该功能，则子类不用重写此函数。（默认就返回true）
]]--
function IDobotWelder:setWeldMode(newVal)
    return true
end

--[[
功能：设置程序号
参数：newVal-程序号
返回值：true表示设置成功，false表示设置失败
说明：如果焊机没有该功能，则子类不用重写此函数。（默认就返回true）
]]--
function IDobotWelder:setProcessNumber(newVal)
    return true
end

--[[
功能：设置job号
参数：newVal-job号
返回值：true表示设置成功，false表示设置失败
]]--
function IDobotWelder:setJobId(newVal)
    return true
end

--[[
功能：设置焊机电流
参数：newVal-电流值
返回值：true表示设置成功，false表示设置失败
]]--
function IDobotWelder:setWeldCurrent(newVal)
    return true
end

--[[
功能：设置焊机电压
参数：newVal-电压值
返回值：true表示设置成功，false表示设置失败
]]--
function IDobotWelder:setWeldVoltage(newVal)
    return true
end

--[[
功能：设置送丝速度
参数：newVal-送丝速度值
返回值：true表示设置成功，false表示设置失败
说明：有的没有这些值，所以默认返回true
]]--
function IDobotWelder:setWeldWireFeedSpeed(newVal)
    return true
end

--[[
功能：设置焊接功率
参数：newVal-功率值
返回值：true表示设置成功，false表示设置失败
说明：有的没有这些值，所以默认返回true
]]--
function IDobotWelder:setWeldPower(newVal)
    return true
end

--[[
功能：起弧
参数：无
返回值：true表示起弧成功，false表示起弧失败
]]--
function IDobotWelder:arcStart()
    return true
end

--[[
功能：灭弧
参数：无
返回值：true表示灭弧成功，false表示灭弧失败
]]--
function IDobotWelder:arcEnd()
    return true
end

--[[
功能：实时读取焊机当前起弧状态
参数：无
返回值：true表示为起弧状态，false表示为灭弧状态，nil表示通信异常
]]--
function IDobotWelder:readArcStateRealtime()
    return nil
end

--[[
功能：读取是否是人工主动灭弧
参数：无
返回值：true表示为人工主动灭弧，false表示为非人工主动灭弧，nil表示通信异常
]]--
function IDobotWelder:hasEndArcByMannual()
    return nil
end

--[[
功能：手动送丝开启、关闭(手动调试功能)
参数：isOn=true表示开启，false表示关闭
返回值：true表示成功，false表示失败
]]--
function IDobotWelder:setWireFeed(isOn)
    return true
end

--[[
功能：手动退丝开启、关闭(手动调试功能)
参数：isOn=true表示开启，false表示关闭
返回值：true表示成功，false表示失败
]]--
function IDobotWelder:setWireBack(isOn)
    return true
end

--[[
功能：气检信号开启、关闭(手动调试功能)
参数：isOn=true表示开启，false表示关闭
返回值：true表示成功，false表示失败
]]--
function IDobotWelder:setGasCheck(isOn)
    return true
end

--[[
功能：执行点焊
参数：参数请参考`GlobalParameter.SpotWeldParams`
返回值：true表示成功，false表示失败
]]--
function IDobotWelder:doSpotWeld(spotWeldParam)
    return true
end

--[[
功能：设置是否锁住焊机的操作面板
参数：bIsLock-true表示锁住，false-表示解锁
返回值：true表示成功，false表示失败
说明：部分焊机没有此功能
]]--
function IDobotWelder:setMmiLockUI(bIsLock)
    return true
end

--[[
功能：读焊机当前的运行状况信息，读取了焊机信息后需要保存起来，方便http接口实时调用
参数：无
返回值：请参考`GlobalParameter.innerWeldRunStateInfo`
]]--
function IDobotWelder:readWelderRunStateInfo()
    return {}
end
function IDobotWelder:clearWelderRunStateInfo()
end

--[[
功能：当userAPI.lua脚本停止时的处理，在deamon.lua调用
参数：无
返回值：true表示执行成功，false表示失败
]]--
function IDobotWelder:doWhenUserLuaHasStoped()
    return true
end

--[[
功能：当userAPI.lua脚本暂停时的处理，在deamon.lua调用
参数：无
返回值：true表示执行成功，false表示失败
]]--
function IDobotWelder:doWhenUserLuaHasPause()
    return true
end

--[[
功能：当userAPI.lua脚本继续运行时的处理，在deamon.lua调用
参数：无
返回值：true表示执行成功，false表示失败
]]--
function IDobotWelder:doWhenUserLuaHasContinue()
    return true
end

--=============================================================================================================================
--=============================================================================================================================
--OTC焊机特有的接口************************************************************************************************************
--[[
功能：设置OTC焊接相关参数
参数：strKeyName-关键字名称，通过这个来决定要设置什么参数
      value-参数值。
返回值：true表示执行成功，false表示失败
说明：1. 拥有独立寄存器存储空间的参数设置。
      2. 关于`strKeyName`和`value`的详细介绍,请统一查看`OTC/OTCWelder.lua`的规则详细说明
]]--
function IDobotWelder:setOTCParameter(strKeyName,value)
    return true
end

--[[
功能：设置OTC视图函数相关参数
参数：strKeyName-关键字名称，通过这个来决定要设置什么参数
      value-参数值。
返回值：true表示执行成功，false表示失败
说明：1. 多个焊接参数共享同一个寄存器地址的参数设置。
      2. 关于`strKeyName`和`value`的详细介绍,请统一查看`OTC/OTCWelder.lua`的规则详细说明
]]--
function IDobotWelder:setOTCFunctionView(strKeyName,value)
    return true
end

return IDobotWelder