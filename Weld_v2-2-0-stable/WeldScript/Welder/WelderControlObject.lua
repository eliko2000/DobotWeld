--[[
焊机`WelderControlObject`接口
说明：
1. 为了统一描述对外接口，让子类去实现具体功能。
2. 该文件主要是与焊机协议通信。
3. 所有通信异常的都返回nil
]]--

local g_innerControlObjectLockerName = "ThreadSafeControlObjectLocker-D37882E8-FDFF-4344-B2C8-D8C6537D1746" --锁的名称
local g_innerControlObjectLockTimeout = 8000 --获取锁后，拥有锁资源的持续时长，毫秒单位
local g_innerControlObjectLockWaitTimeout = 10000 --等待获取锁资源的最大时间，毫秒单位


local WelderControlObject = {}
WelderControlObject.__index = WelderControlObject

-------------------------------------------------------------------------------------------------------------------
--【对内不公开接口，只给本身和派生类使用】-------------------------------------------------------------------------
--有些场景是需要先读数据，然后修改数据，最后写输入。这几个步骤是一致性的，所以可能需要加锁。
--进入锁
function WelderControlObject:enterLock()
    Lock(g_innerControlObjectLockerName,g_innerControlObjectLockTimeout,g_innerControlObjectLockWaitTimeout)
end
--离开锁
function WelderControlObject:leaveLock()
    UnLock(g_innerControlObjectLockerName)
end

-------------------------------------------------------------------------------------------------------------------
--【对外公开接口】-------------------------------------------------------------------------------------------------
function WelderControlObject:new()
    return setmetatable({},self)
end

--[[
功能：初始化焊机，做一些准备焊接
参数：无
返回值：true表示成功，false表示失败
说明：默认返回true
]]--
function WelderControlObject:initWelder()
    return true
end

--[[
功能：通知焊接机,机器人已经准备就绪
参数：无
返回值：true表示通知成功，false表示通知失败
说明：有的没有这些值，所以默认返回true
]]--
function WelderControlObject:notifyWelderThatRobotHasReady()
    return true
end

--[[
功能：通知焊接机,机器人还没有准备就绪
参数：无
返回值：true表示通知成功，false表示通知失败
说明：有的没有这些值，所以默认返回true
]]--
function WelderControlObject:notifyWelderThatRobotNotReady()
    return true
end

--[[
功能：判断焊机是否准备就绪
参数：无
返回值：true表示焊接机准备就绪，false表示未就绪
说明：有的没有这些值，所以默认返回true
]]--
function WelderControlObject:isWelderReady()
    return true
end

--[[
功能：设置是否锁住焊机的操作面板
参数：bIsLock-true表示锁住，false-表示解锁
返回值：true表示成功，false表示失败
说明：部分焊机没有此功能
]]--
function WelderControlObject:setMmiLockUI(bIsLock)
    return true
end

--[[
功能：使能打开、关闭焊丝接触寻位功能
参数：bEnable-true表示使能打开，false表示使能关闭
返回值：true表示设置成功，false表示设置失败，nil表示通信异常
]]--
function WelderControlObject:setTouchPostionEnable(bEnable)
    return false
end

--[[
功能：焊丝接触寻位成功状态
参数：无
返回值：true表示寻位成功，false表示寻位失败，nil表示通信异常
]]--
function WelderControlObject:isTouchPositionSuccess()
    return false
end

--[[
功能：设置寻位失败时的状态
参数：bStatus-true表示ON，false表示OFF
返回值：true表示设置成功，false表示设置失败，nil表示通信异常
]]--
function WelderControlObject:setTouchPositionFailStatus(bStatus)
    return false
end

--[[
功能：设置焊接电流
参数：newVal如果为nil则表示使用配置中参数，否则就是用传入的参数
返回值：true表示设置成功，false表示设置失败
说明：有的没有这些值，所以默认返回true
]]--
function WelderControlObject:setWeldCurrent(newVal)
    return true
end

--[[
功能：设置起弧电流
参数：newVal如果为nil则表示使用配置中参数，否则就是用传入的参数
返回值：true表示设置成功，false表示设置失败
说明：有的没有这些值，所以默认返回true
]]--
function WelderControlObject:setArcStartCurrent(newVal)
    return true
end

--[[
功能：设置收弧电流
参数：newVal如果为nil则表示使用配置中参数，否则就是用传入的参数
返回值：true表示设置成功，false表示设置失败
说明：有的没有这些值，所以默认返回true
]]--
function WelderControlObject:setArcEndCurrent(newVal)
    return true
end

--[[
功能：获取焊接电流
参数：无
返回值：成功返回电流值，失败返回nil
说明：有的没有这些值，所以默认返回0
]]--
function WelderControlObject:getWeldCurrent()
    return 0
end

--[[
功能：设置焊接电压
参数：newVal如果为nil则表示使用配置中参数，否则就是用传入的参数
返回值：true表示设置成功，false表示设置失败
说明：有的没有这些值，所以默认返回true
]]--
function WelderControlObject:setWeldVoltage(newVal)
    return true
end

--[[
功能：设置起弧电压
参数：newVal如果为nil则表示使用配置中参数，否则就是用传入的参数
返回值：true表示设置成功，false表示设置失败
说明：有的没有这些值，所以默认返回true
]]--
function WelderControlObject:setArcStartVoltage(newVal)
    return true
end

--[[
功能：设置收弧电压
参数：newVal如果为nil则表示使用配置中参数，否则就是用传入的参数
返回值：true表示设置成功，false表示设置失败
说明：有的没有这些值，所以默认返回true
]]--
function WelderControlObject:setArcEndVoltage(newVal)
    return true
end

--[[
功能：获取焊接电压
参数：无
返回值：成功返回电压值，失败返回nil
说明：有的没有这些值，所以默认返回0
]]--
function WelderControlObject:getWeldVoltage()
    return 0
end

--[[
功能：设置焊接功率
参数：newVal如果为nil则表示使用配置中参数，否则就是用传入的参数
返回值：true表示设置成功，false表示设置失败
说明：有的没有这些值，所以默认返回true
]]--
function WelderControlObject:setWeldPower(newVal)
    return true
end

--[[
功能：设置起弧功率
参数：newVal如果为nil则表示使用配置中参数，否则就是用传入的参数
返回值：true表示设置成功，false表示设置失败
说明：有的没有这些值，所以默认返回true
]]--
function WelderControlObject:setArcStartPower(newVal)
    return true
end

--[[
功能：设置收弧功率
参数：newVal如果为nil则表示使用配置中参数，否则就是用传入的参数
返回值：true表示设置成功，false表示设置失败
说明：有的没有这些值，所以默认返回true
]]--
function WelderControlObject:setArcEndPower(newVal)
    return true
end

--[[
功能：获取焊接功率
参数：无
返回值：成功返回功率值，失败返回nil
说明：有的没有这些值，所以默认返回0
]]--
function WelderControlObject:getWeldPower()
    return 0
end

--[[
功能：设置焊接送丝速度
参数：newVal如果为nil则表示使用配置中参数，否则就是用传入的参数
返回值：true表示设置成功，false表示设置失败
说明：有的没有这些值，所以默认返回true
]]--
function WelderControlObject:setWeldWireFeedSpeed(newVal)
    return true
end

--[[
功能：获取焊接送丝速度
参数：无
返回值：成功返值，失败返回nil
说明：有的没有这些值，所以默认返回0
]]--
function WelderControlObject:getWeldWireFeedSpeed()
    return 0
end

--[[
功能：设置工作模式（分别模式、一元化模式）
参数：newVal如果为nil则表示使用配置中参数，否则就是用传入的参数
返回值：true表示设置成功，false表示设置失败
说明：有的没有这些值，所以默认返回true
]]--
function WelderControlObject:setWorkMode(newVal)
    return true
end

--[[
功能：设置焊接模式
参数：newVal如果为nil则表示使用配置中参数，否则就是用传入的参数
返回值：true表示设置成功，false表示设置失败
说明：有的没有这些值，所以默认返回true
]]--
function WelderControlObject:setWeldMode(newVal)
    return true
end

--[[
功能：设置job号
参数：newVal如果为nil则表示使用配置中参数，否则就是用传入的参数
返回值：true表示设置成功，false表示设置失败
说明：有的没有这些值，所以默认返回true
]]--
function WelderControlObject:setJobId(newVal)
    return true
end

--[[
功能：设置程序号
参数：newVal如果为nil则表示使用配置中参数，否则就是用传入的参数
返回值：true表示设置成功，false表示设置失败
说明：有的没有这些值，所以默认返回true
]]--
function WelderControlObject:setProcessNumber(newVal)
    return true
end

--[[
功能：起弧
参数：无
返回值：true表示设置成功，false表示设置失败
说明：有的没有这些值，所以默认返回true
]]--
function WelderControlObject:arcStart()
    return true
end

--[[
功能：起弧是否成功
参数：无
返回值：true表示成功，false表示失败，nil表示通信异常
说明：有的没有这些值，所以默认返回true
]]--
function WelderControlObject:isArcStarted()
    return true
end

--[[
功能：灭弧
参数：无
返回值：true表示设置成功，false表示设置失败
说明：有的没有这些值，所以默认返回true
]]--
function WelderControlObject:arcEnd()
    return true
end

--[[
功能：灭弧是否成功
参数：无
返回值：true表示成功，false表示失败，nil表示通信异常
说明：有的没有这些值，所以默认返回true
]]--
function WelderControlObject:isArcEnded()
    return true
end

--[[
功能：读取是否是人工主动灭弧
参数：无
返回值：true表示为人工主动灭弧，false表示为非人工主动灭弧，nil表示通信异常
说明：有的没有这些值，所以默认返回true
]]--
function WelderControlObject:hasEndArcByMannual()
    return true
end

--[[
功能：清错误
参数：无
返回值：true表示设置成功，false表示设置失败
说明：有的没有这些值，所以默认返回true
]]--
function WelderControlObject:clearError()
    return true
end

--[[
功能：启动、停止手动送丝
参数：无
返回值：true表示设置成功，false表示设置失败
说明：有的没有这些值，所以默认返回true
]]--
function WelderControlObject:startWireFeed()
    return true
end
function WelderControlObject:stopWireFeed()
    return true
end

--[[
功能：启动、停止手动退丝
参数：无
返回值：true表示设置成功，false表示设置失败
说明：有的没有这些值，所以默认返回true
]]--
function WelderControlObject:startWireBack()
    return true
end
function WelderControlObject:stopWireBack()
    return true
end

--[[
功能：送丝信号检测
参数：无
返回值：true表示有信号，false表示无信号
说明：有的没有这些值，所以默认返回true
]]--
function WelderControlObject:isWireHasSignal()
    return true
end

--[[
功能：粘丝检测，粘丝是否解除
参数：无
返回值：true表示解除，false表示粘丝未解除
说明：有的没有这些功能，所以默认返回true，表示粘丝解除了。
]]--
function WelderControlObject:isStickRelease()
    return true
end

--[[
功能：启动、停止手动气检
参数：无
返回值：true表示设置成功，false表示设置失败
说明：有的没有这些值，所以默认返回true
]]--
function WelderControlObject:startGasCheck()
    return true
end
function WelderControlObject:stopGasCheck()
    return true
end

--[[
功能：送气信号检测
参数：无
返回值：true表示有信号，false表示无信号
说明：有的没有这些值，所以默认返回true
]]--
function WelderControlObject:isGasHasSignal()
    return true
end

--[[
功能：获取焊机的实时运行状态信息
参数：无
返回值：成功返值请参考GlobalParameter.innerWeldRunStateInfo，失败返回{}
]]--
function WelderControlObject:getWelderRunStateInfo()
    return {}
end

--[[
功能：获取焊机错误码
参数：无
返回值：成功返回错误码值，失败返回nil
]]--
function WelderControlObject:getWelderErrCode()
    return nil
end

return WelderControlObject