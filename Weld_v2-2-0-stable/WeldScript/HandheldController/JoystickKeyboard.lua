--[[
GT72操纵杆控制器的业务封装
]]--

--【本地私有接口】-----------------------------------------------------------------------------------------
local EnumMode = {
    Normal = 0, --常规普通模式
    Extend = 1, --扩展模式，以下的模式都是进入扩展模式才能设置的，因此以下模式也认为是扩展模式的子模式
    Debug = 2, --调试模式
    Spot = 3 --点焊模式
}

--循环执行键盘监控,self==JoystickKeyboard
local function keyboardMonitorLoop(self)
    WelderHandleControl.setButtonBoxOnOff(true) --按钮盒子示教器运行的状态标记
    
	local bErr,msgErr = pcall(KbCallbackFunction.registerCallback,self)
    if not bErr then MyWelderDebugLog(tostring(msgErr)) end
    
    --刚启动线程，则建立连接
    bErr,msgErr = KbEventListener.safeCallFunc(self.connect)
    if not bErr then MyWelderDebugLog(tostring(msgErr)) end
    
    --初始化示教器数据
    bErr,msgErr = KbEventListener.safeCallFunc(self.initKeyboardInfo, self)
    if not bErr then MyWelderDebugLog(tostring(msgErr)) end
    
    bErr,msgErr = pcall(RobotModbusControl.setJogModeTool) --初始化机器人点动模式
    if not bErr then MyWelderDebugLog(tostring(msgErr)) end
    
    self.setThreadRun(true)
    local beginTime,deta = 0,0
    while self.isThreadRun() do
        if self.isConnected() then
            beginTime = Systime()
            
            bErr,msgErr = pcall(KbEventListener.processKeyboardEvent)
            if not bErr then
                MyWelderDebugLog(tostring(msgErr))
                Wait(400)
            elseif false==msgErr then
                --从代码中可以看出，这个为false只有一种可能：读取摇杆数据失败(modbusrtu基本是不可能创建失败的)
                Wait(200) --防止用户插拔按钮盒子后cpu一直飙升。
            end
            
            bErr,msgErr = pcall(self.scriptRunStateMonitor)
            if not bErr then
                MyWelderDebugLog(tostring(msgErr))
                Wait(400)
            end
            
            deta = Systime()-beginTime
            if deta<80 then
                Wait(80-deta)
            end
        else
            Wait(2000)
            KbEventListener.safeCallFunc(self.connect) --没有连接，则重新连接，防止用户插拔按钮盒子摇杆
        end
    end

    KbEventListener.safeCallFunc(self.disconnect) --线程结束则断开连接
    WelderHandleControl.setButtonBoxOnOff(false) --按钮盒子示教器运行的状态标记
end

--获取焊接索引、摆弧索引、焊接速度的组合integer值
local function getNormalWeldValue()
    local v = JoystickArcTemplate.getWeldArcParam()*100
    v = v+JoystickArcTemplate.getWeldWeaveParam()
    return string.format("%04d",v)
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------
--【导出接口】
local JoystickKeyboard = {
    controller = JoystickKeyboardProtocol,
    bIsThdRun = false,
    thdObj = nil,
    userScriptRunState = nil, --脚本当前的运行状态反馈：0-停止状态，1-运行状态，2-暂停状态
    bIsUserScriptRun = false, --true表示脚本工程处于运行状态（只要不是停止运行，都属于运行状态）
    bEnableRobot = false, --上下使能反馈：true为上使能，false为下使能
    bDragState = false, --拖拽状态反馈：true为拖拽状态，false为非拖拽状态
    bIsRxyz = false,--true为rxyz模式，否则为xyz模式
    bHasError = false, --true表示有报警/错误
    preAxisName = nil, --上一个轴运动方向名
    funcSelectedMode = EnumMode.Normal --当前选择的模式，只有常规模式和其他模式可以互相切换
}

--启动按钮盒子服务
function JoystickKeyboard.startServer()
    local self = JoystickKeyboard
    if not self.thdObj then
        self.thdObj = systhread.create(keyboardMonitorLoop,self)
        if not self.thdObj then
            MyWelderDebugLog("create joystick keyboard monitor server thread fail")
            return false
        end
    end
    return true
end

--停止按钮盒子服务
function JoystickKeyboard.stopServer()
    local self = JoystickKeyboard
    self.setThreadRun(false)
    if self.thdObj then
        MyWelderDebugLog("waiting for destroy joystick keyboard server")
        self.thdObj:wait()
        self.thdObj = nil
        MyWelderDebugLog("joystick keyboard server has destroy")
    end
end

function JoystickKeyboard.connect()
    local self = JoystickKeyboard
    if not self.isConnected() then
        if not self.controller.connect(115200,"N",8,1) then
            MyWelderDebugLog("connect keyboard modbus fail")
            return false
        end
    end
    if not RobotModbusControl.connect() then
        return false
    end
    return true
end

function JoystickKeyboard.isConnected()
    local self = JoystickKeyboard
    return self.controller.isConnected()
end

function JoystickKeyboard.disconnect()
    local self = JoystickKeyboard
    self.controller.disconnect()
    RobotModbusControl.disconnect()
end

-------------------------------------------------------------------------------------------------------------------
function JoystickKeyboard.isThreadRun()
    local bRet
    Lock("JKThdSafeLocker-FB098412-1B41-47B6-B612-3AC75B1A46C9",3000,5000)
    bRet = JoystickKeyboard.bIsThdRun
    UnLock("JKThdSafeLocker-FB098412-1B41-47B6-B612-3AC75B1A46C9")
    return bRet
end
function JoystickKeyboard.setThreadRun(bRun)
    Lock("JKThdSafeLocker-FB098412-1B41-47B6-B612-3AC75B1A46C9",3000,5000)
    JoystickKeyboard.bIsThdRun = bRun
    UnLock("JKThdSafeLocker-FB098412-1B41-47B6-B612-3AC75B1A46C9")
end

--初始化状态值
function JoystickKeyboard.initKeyboardInfo(self)
    local self = JoystickKeyboard
    self.bIsRxyz = false
    self.preAxisName = nil
    self.funcSelectedMode = EnumMode.Normal
    self.bIsUserScriptRun = false
    self.controller.setButtonLedState(0)
    self.controller.setLedString(getNormalWeldValue())
    return self.controller.writeAllInfo()
end

--清空工程
function JoystickKeyboard.clearProject()
    local self = JoystickKeyboard
    if self.isUserScriptRun() then
        return
    end
    
    local function pfnExec(self)
        local led = self.controller.getButtonLedState()
        led = JbkLightID.getOnApproachPoint(led) --接近点亮灯
        led = JbkLightID.getOffArcStartPoint(led) --起弧点灭灯
        led = JbkLightID.getOffMiddleLinePoint(led) --直线点灭灯
        led = JbkLightID.getOffMiddleArcPoint(led) --圆弧点灭灯
        led = JbkLightID.getOffArcEndPoint(led) --灭弧点灭灯
        led = JbkLightID.getOffLeavePoint(led) --离开点灭灯
        self.controller.setButtonLedState(led)
        self.controller.setLedString("0100")
        self.controller.writeAllInfo()
    end
    local bErr,msgErr = KbEventListener.safeCallFunc(pfnExec,self)
    if not bErr then MyWelderDebugLog(tostring(msgErr)) end
    
    JoystickArcTemplate.clear()
    JoystickArcTemplate.initWeldParams(10,1,0)
end

--显示普通模式下的led值和一些状态
function JoystickKeyboard.showNomalMode()
    local self = JoystickKeyboard
    local function pfnExec(self)
        local led = self.controller.getButtonLedState()
        led = JbkLightID.getOffExtendFunctionCode(led) --灭灯
        self.controller.setButtonLedState(led)
        self.controller.setLedString(getNormalWeldValue()) --恢复普通模式下的led值
        self.controller.writeAllInfo()
    end
    local bErr,msgErr = KbEventListener.safeCallFunc(pfnExec,self)
    if not bErr then MyWelderDebugLog(tostring(msgErr)) end
end

--显示扩展模式下的led值和一些状态
function JoystickKeyboard.showExtendFunctionMode()
    local self = JoystickKeyboard
    local function pfnExec(self)
        --显示扩展的一些信息和功能码
        JbkExtendFunction.showNextCode(self,1)
    end
    local bErr,msgErr = KbEventListener.safeCallFunc(pfnExec,self)
    if not bErr then MyWelderDebugLog(tostring(msgErr)) end
end

function JoystickKeyboard.isNormalMode()
    local self = JoystickKeyboard
    return EnumMode.Normal==self.funcSelectedMode
end

--进入/退出扩展功能模式
function JoystickKeyboard.setExtendFunctionMode()
    local self = JoystickKeyboard
    if self.isUserScriptRun() then
        return
    end
    if EnumMode.Normal~=self.funcSelectedMode then
        self.funcSelectedMode = EnumMode.Normal
        self.showNomalMode()
    else
        self.funcSelectedMode = EnumMode.Extend
        self.showExtendFunctionMode()
    end
    return
end

function JoystickKeyboard.isExtendFunctionMode()
    local self = JoystickKeyboard
    return EnumMode.Normal~=self.funcSelectedMode --不为Normal认为是Extend模式
end

--设置扩展功能代码,不同功能代码表示不同功能,此时的`setExtendFunctionValue`设置的参数含义不一样
function JoystickKeyboard.setExtendFunctionCode()
    local self = JoystickKeyboard
    if self.isUserScriptRun() then
        return
    end
    local function pfnExec(self)
        self.funcSelectedMode = EnumMode.Extend --在扩展功能里面涉及到其他模式的切换，所以每次在扩展模式切换时都先复位为扩展模式
        JbkExtendFunction.showNextCode(self)
    end
    local bErr,msgErr = KbEventListener.safeCallFunc(pfnExec,self)
    if not bErr then MyWelderDebugLog(tostring(msgErr)) end
end

--设置扩展功能的参数值
function JoystickKeyboard.setExtendFunctionValue(value)
    local self = JoystickKeyboard
    if self.isUserScriptRun() then
        return
    end
    if math.abs(value)<1 then return end
    local function pfnExec(self)
        JbkExtendFunction.showNewValue(self,value)
    end
    local bErr,msgErr = KbEventListener.safeCallFunc(pfnExec,self)
    if not bErr then MyWelderDebugLog(tostring(msgErr)) end
end

--进入调试模式
function JoystickKeyboard.setDebugMode()
    local self = JoystickKeyboard
    if self.isUserScriptRun() then
        return
    end
    local function pfnExec(self)
        local led = self.controller.getButtonLedState()
        led = JbkLightID.getOffEnableRobot(led) --灭灯
        led = JbkLightID.getOffClearWarn(led) --灭灯
        led = JbkLightID.getOffDragMode(led) --灭灯
        self.controller.setButtonLedState(led)
        self.controller.setLedString("dbG") --显示dbG
        self.controller.writeAllInfo()
    end
    self.funcSelectedMode = EnumMode.Debug
    local bErr,msgErr = KbEventListener.safeCallFunc(pfnExec,self)
    if not bErr then MyWelderDebugLog(tostring(msgErr)) end
end
function JoystickKeyboard.isDebugMode()
    local self = JoystickKeyboard
    return self.funcSelectedMode == EnumMode.Debug
end

--进入点焊模式
function JoystickKeyboard.setSpotMode()
    local self = JoystickKeyboard
    if self.isUserScriptRun() then
        return
    end
    local function pfnExec(self)
        self.controller.setLedString("SPot") --显示dbG
        self.controller.writeAllInfo()
    end
    self.funcSelectedMode = EnumMode.Spot
    local bErr,msgErr = KbEventListener.safeCallFunc(pfnExec,self)
    if not bErr then MyWelderDebugLog(tostring(msgErr)) end
end
function JoystickKeyboard.isSpotMode()
    local self = JoystickKeyboard
    return self.funcSelectedMode == EnumMode.Spot
end
--执行点焊
function JoystickKeyboard.doSpotWeld()
    local self = JoystickKeyboard
    local function pfnExec(self)
        local led = self.controller.getButtonLedState()
        led = JbkLightID.getOnWeldSpot(led)
        self.controller.setButtonLedState(led)
        self.controller.writeAllInfo()
        
        local bErr,msgErr = pcall(WelderHandleControl.doSpotWeld) --执行点焊
        if not bErr then MyWelderDebugLog(tostring(msgErr)) end
        
        led = JbkLightID.getOffWeldSpot(led)
        self.controller.setButtonLedState(led)
        self.controller.writeAllInfo()
    end
    local bErr,msgErr = KbEventListener.safeCallFunc(pfnExec,self)
    if not bErr then MyWelderDebugLog(tostring(msgErr)) end
end

----------------------------------------------------------------------------------------------------
--停止工程运行
function JoystickKeyboard.setStopProject()
    local self = JoystickKeyboard
    
    local function pfnExec(self)
        local led = self.controller.getButtonLedState()
        led = JbkLightID.getOffLeavePoint(led) --离开点灭掉灯
        self.controller.setButtonLedState(led)
        self.controller.writeAllInfo()
    end
    local bErr,msgErr = KbEventListener.safeCallFunc(pfnExec,self)
    if not bErr then MyWelderDebugLog(tostring(msgErr)) end
    
    RobotModbusControl.stopProject()
end

--工程是否为运行状态
function JoystickKeyboard.isUserScriptRun()
    local self = JoystickKeyboard
    return self.bIsUserScriptRun
end

--虚拟运行
function JoystickKeyboard.setVirtualRun()
    local self = JoystickKeyboard
    if not self.isNormalMode() then --不是普通模式下，不可运行
        return
    end
    local led = self.controller.getButtonLedState()
    if JbkLightID.isOnRealRun(led) then --真实焊灯亮，则虚拟焊按钮不处理
        return
    end
    
    --闪烁一次灯，有个动画效果
    local function pfnExec(self)
        local led = self.controller.getButtonLedState()
        led = JbkLightID.getOnVirtualRun(led)
        led = JbkLightID.getOffLeavePoint(led) --离开点灭掉灯
        self.controller.setButtonLedState(led)
        self.controller.writeAllInfo()
    end
    local bErr,msgErr = KbEventListener.safeCallFunc(pfnExec,self)
    if not bErr then MyWelderDebugLog(tostring(msgErr)) end
    
    if 0==self.userScriptRunState then --脚本是停止状态则
        RobotModbusControl.startVirtualWeld()
    elseif 1==self.userScriptRunState then --脚本是运行状态则
        RobotModbusControl.pauseVirtualWeld()
    elseif 2==self.userScriptRunState then  --脚本是暂停状态则
        RobotModbusControl.continueVirtualWeld()
    end
end

--切换XYZ与Rxyz模式
function JoystickKeyboard.setSwitchXYZMode()
    local self = JoystickKeyboard
    if self.isUserScriptRun() then
        return
    end
    local function pfnExec(self)
        local led = self.controller.getButtonLedState()
        if self.bIsRxyz then --为true表示为Rxyz模式，则灭灯
            led = JbkLightID.getOffSwitchXYZMode(led)
            self.bIsRxyz = false
        else
            led = JbkLightID.getOnSwitchXYZMode(led)
            self.bIsRxyz = true
        end
        self.controller.setButtonLedState(led)
        return self.controller.writeAllInfo()
    end
    local bErr,msgErr = KbEventListener.safeCallFunc(pfnExec,self)
    if not bErr then MyWelderDebugLog(tostring(msgErr)) end
end

--真实运行
function JoystickKeyboard.setRealRun()
    local self = JoystickKeyboard
    if not self.isNormalMode() then --不是普通模式下，不可运行
        return
    end
    local led = self.controller.getButtonLedState()
    if JbkLightID.isOnVirtualRun(led) then --虚拟焊灯亮，则真实焊按钮不处理
        return
    end
    
    --闪烁一次灯，有个动画效果
    local function pfnExec(self)
        local led = self.controller.getButtonLedState()
        led = JbkLightID.getOnRealRun(led)
        led = JbkLightID.getOffLeavePoint(led) --离开点灭掉灯
        self.controller.setButtonLedState(led)
        self.controller.writeAllInfo()
    end
    local bErr,msgErr = KbEventListener.safeCallFunc(pfnExec,self)
    if not bErr then MyWelderDebugLog(tostring(msgErr)) end
    
    if 0==self.userScriptRunState then --脚本是停止状态则
        RobotModbusControl.startRealWeld()
    elseif 1==self.userScriptRunState then --脚本是运行状态则
        RobotModbusControl.pauseRealWeld()
    elseif 2==self.userScriptRunState then  --脚本是暂停状态则
        RobotModbusControl.continueRealWeld()
    end
end

----------------------------------------------------------------------------------------------------
function JoystickKeyboard.addApproachPoint()
    local self = JoystickKeyboard
    if self.isUserScriptRun() then
        return
    end

    local function pfnExec(self)
        local led = self.controller.getButtonLedState()
        if not JbkLightID.isOnApproachPoint(led) then --接近灯没亮
            return nil
        end
        if not JoystickArcTemplate.setApproachPoint() then
            return false --添加失败则不处理
        end
        led = JbkLightID.getOffApproachPoint(led) --接近点灭掉灯
        led = JbkLightID.getOnArcStartPoint(led) --点亮起弧点灯
        self.controller.setButtonLedState(led)
        return self.controller.writeAllInfo()
    end
    local bErr,msgErr = KbEventListener.safeCallFunc(pfnExec,self)
    if not bErr then MyWelderDebugLog(tostring(msgErr)) end
end

function JoystickKeyboard.addArcStartPoint()
    local self = JoystickKeyboard
    if self.isUserScriptRun() then
        return
    end

    local function pfnExec(self)
        local led = self.controller.getButtonLedState()
        if not JbkLightID.isOnArcStartPoint(led) then --起弧灯没亮
            return nil
        end
        if not JoystickArcTemplate.setArcStartPoint() then
            return false
        end
        led = JbkLightID.getOffArcStartPoint(led) --起弧点灭掉灯
        led = JbkLightID.getOnMiddleLinePoint(led) --点亮直线点灯
        led = JbkLightID.getOnMiddleArcPoint(led) --点亮圆弧点灯
        led = JbkLightID.getOnArcEndPoint(led) --点亮灭弧点灯
        self.controller.setButtonLedState(led)
        return self.controller.writeAllInfo()
    end
    local bErr,msgErr = KbEventListener.safeCallFunc(pfnExec,self)
    if not bErr then MyWelderDebugLog(tostring(msgErr)) end
end

function JoystickKeyboard.addMiddleLinePoint()
    local self = JoystickKeyboard
    if self.isUserScriptRun() then
        return
    end

    local function pfnExec(self)
        local led = self.controller.getButtonLedState()
        if not JbkLightID.isOnMiddleLinePoint(led) then --直线灯没亮
            return nil
        end
        if not JoystickArcTemplate.addMiddleLinePoint() then
            return false
        end
        led = JbkLightID.getOffMiddleLinePoint(led) --直线点灭掉灯
        led = JbkLightID.getOnMiddleArcPoint(led) --点亮圆弧点灯
        led = JbkLightID.getOnArcEndPoint(led) --点亮灭弧点灯
        self.controller.setButtonLedState(led)
        self.controller.writeAllInfo()
        Wait(250)
        led = JbkLightID.getOnMiddleLinePoint(led) --点亮直线点灯
        self.controller.setButtonLedState(led)
        return self.controller.writeAllInfo()
    end
    local bErr,msgErr = KbEventListener.safeCallFunc(pfnExec,self)
    if not bErr then MyWelderDebugLog(tostring(msgErr)) end
end

function JoystickKeyboard.addMiddleArcPoint()
    local self = JoystickKeyboard
    if self.isUserScriptRun() then
        return
    end

    local function pfnExec(self)
        local led = self.controller.getButtonLedState()
        if not JbkLightID.isOnMiddleArcPoint(led) then --圆弧灯没亮
            return nil
        end
        local state = JoystickArcTemplate.addMiddleArcPoint()
        if false==state then --生成点失败
            return
        end
        if 1==state then --点数还不够
            led = JbkLightID.getOffMiddleLinePoint(led) --直线点灭灯
            led = JbkLightID.getOffArcEndPoint(led) --灭弧点灭掉灯
        else --点数够2个
            led = JbkLightID.getOnMiddleLinePoint(led) --点亮直线点灯
            led = JbkLightID.getOnArcEndPoint(led) --点亮灭弧点灯
        end
        self.controller.setButtonLedState(led)
        return self.controller.writeAllInfo()
    end
    local bErr,msgErr = KbEventListener.safeCallFunc(pfnExec,self)
    if not bErr then MyWelderDebugLog(tostring(msgErr)) end
end

function JoystickKeyboard.addArcEndPoint()
    local self = JoystickKeyboard
    if self.isUserScriptRun() then
        return
    end

    local function pfnExec(self)
        local led = self.controller.getButtonLedState()
        if not JbkLightID.isOnArcEndPoint(led) then --灭弧灯没亮
            return nil
        end
        if not JoystickArcTemplate.setArcEndPoint() then
            return false
        end
        led = JbkLightID.getOffMiddleLinePoint(led) --直线点灭灯
        led = JbkLightID.getOffMiddleArcPoint(led) --圆弧点灭灯
        led = JbkLightID.getOffArcEndPoint(led) --灭弧点灭掉灯
        led = JbkLightID.getOnLeavePoint(led) --点亮离开点灯
        self.controller.setButtonLedState(led)
        return self.controller.writeAllInfo()
    end
    local bErr,msgErr = KbEventListener.safeCallFunc(pfnExec,self)
    if not bErr then MyWelderDebugLog(tostring(msgErr)) end
end

function JoystickKeyboard.addLeavePoint()
    local self = JoystickKeyboard
    if self.isUserScriptRun() then
        return
    end

    local function pfnExec(self)
        local led = self.controller.getButtonLedState()
        if not JbkLightID.isOnLeavePoint(led) then --离开灯没亮
            return nil
        end
        if not JoystickArcTemplate.addLeavePoint() then
            return false
        end
        led = JbkLightID.getOnLeavePoint(led) --点亮离开点灯
        self.controller.setButtonLedState(led)
        return self.controller.writeAllInfo()
    end
    local bErr,msgErr = KbEventListener.safeCallFunc(pfnExec,self)
    if not bErr then MyWelderDebugLog(tostring(msgErr)) end
end
----------------------------------------------------------------------------------------------------

--设置/停止送丝、退丝、气检
function JoystickKeyboard.setWireFeed(bIsOn)
    local self = JoystickKeyboard
    local function pfnExec(self)
        local led = self.controller.getButtonLedState()
        if bIsOn then
            led = JbkLightID.getOnWireFeed(led)
        else
            led = JbkLightID.getOffWireFeed(led)
        end
        self.controller.setButtonLedState(led)
        return self.controller.writeAllInfo()
    end
    local bErr,msgErr = KbEventListener.safeCallFunc(pfnExec,self)
    if not bErr then MyWelderDebugLog(tostring(msgErr)) end
    return WelderHandleControl.setWireFeed(bIsOn)
end

function JoystickKeyboard.setWireBack(bIsOn)
    local self = JoystickKeyboard
    local function pfnExec(self)
        local led = self.controller.getButtonLedState()
        if bIsOn then
            led = JbkLightID.getOnWireBack(led)
        else
            led = JbkLightID.getOffWireBack(led)
        end
        self.controller.setButtonLedState(led)
        return self.controller.writeAllInfo()
    end
    local bErr,msgErr = KbEventListener.safeCallFunc(pfnExec,self)
    if not bErr then MyWelderDebugLog(tostring(msgErr)) end
    return WelderHandleControl.setWireBack(bIsOn)
end

function JoystickKeyboard.setGasCheck(bIsOn)
    local self = JoystickKeyboard
    local function pfnExec(self)
        local led = self.controller.getButtonLedState()
        if bIsOn then
            led = JbkLightID.getOnGasCheck(led)
        else
            led = JbkLightID.getOffGasCheck(led)
        end
        self.controller.setButtonLedState(led)
        return self.controller.writeAllInfo()
    end
    local bErr,msgErr = KbEventListener.safeCallFunc(pfnExec,self)
    if not bErr then MyWelderDebugLog(tostring(msgErr)) end
    return WelderHandleControl.setGasCheck(bIsOn)
end

--上下使能
function JoystickKeyboard.setEnableRobot()
    local self = JoystickKeyboard
    if true==self.bEnableRobot then
        RobotModbusControl.disableRobot()
    elseif false==self.bEnableRobot then
        RobotModbusControl.enableRobot()
    end
end

--清除报警
function JoystickKeyboard.clearWarn()
    local self = JoystickKeyboard
    local function pfnExec(self)
        local led = self.controller.getButtonLedState()
        if JbkLightID.isOnClearWarn(led) then --led灯是亮的
            led = JbkLightID.getOffClearWarn(led) --灭掉灯
            self.controller.setButtonLedState(led)
            self.controller.setLedString(getNormalWeldValue()) --恢复普通模式下的led值
            return self.controller.writeAllInfo()
        end
    end
    local bErr,msgErr = KbEventListener.safeCallFunc(pfnExec,self)
    if not bErr then MyWelderDebugLog(tostring(msgErr)) end
    RobotModbusControl.clearWarn()
    WelderHandleControl.clearScriptErrCode()
end

--设置拖拽模式
function JoystickKeyboard.setDragMode()
    local self = JoystickKeyboard
    if true==self.bDragState then
        RobotModbusControl.disableDrag()
    elseif false==self.bDragState then
        RobotModbusControl.enableDrag()
    end
end

--设置/退出焊接参数索引模式
function JoystickKeyboard.setWeldArcParamMode()
    local self = JoystickKeyboard
    if self.isUserScriptRun() then
        return
    end
    local function pfnExec(self)
        local led = self.controller.getButtonLedState()
        if JbkLightID.isOnWeldArcParam(led) then --led灯是亮的
            led = JbkLightID.getOffWeldArcParam(led)
        else
            led = JbkLightID.getOnWeldArcParam(led)
            led = JbkLightID.getOffWeldWeaveParam(led)
        end
        self.controller.setButtonLedState(led)
        return self.controller.writeAllInfo()
    end
    local bErr,msgErr = KbEventListener.safeCallFunc(pfnExec,self)
    if not bErr then MyWelderDebugLog(tostring(msgErr)) end
end
--设置焊接参数值
function JoystickKeyboard.setWeldArcParam(value)
    local self = JoystickKeyboard
    if self.isUserScriptRun() then
        return
    end
    local function pfnExec(self)
        local v = JoystickArcTemplate.getWeldArcParam()
        v=v+value
        if v>=99 then v=99
        elseif v<=1 then v=1
        end
        JoystickArcTemplate.setWeldArcParam(v)
        self.controller.setLedString(getNormalWeldValue())
        return self.controller.writeAllInfo()
    end
    local bErr,msgErr = KbEventListener.safeCallFunc(pfnExec,self)
    if not bErr then MyWelderDebugLog(tostring(msgErr)) end
end

--设置/退出摆弧参数索引
function JoystickKeyboard.setWeldWeaveParamMode()
    local self = JoystickKeyboard
    if self.isUserScriptRun() then
        return
    end
    local function pfnExec(self)
        local led = self.controller.getButtonLedState()
        if JbkLightID.isOnWeldWeaveParam(led) then --led灯是亮的
            led = JbkLightID.getOffWeldWeaveParam(led)
        else
            led = JbkLightID.getOnWeldWeaveParam(led)
            led = JbkLightID.getOffWeldArcParam(led)
        end
        self.controller.setButtonLedState(led)
        return self.controller.writeAllInfo()
    end
    local bErr,msgErr = KbEventListener.safeCallFunc(pfnExec,self)
    if not bErr then MyWelderDebugLog(tostring(msgErr)) end
end
--设置摆弧参数值
function JoystickKeyboard.setWeldWeaveParam(value)
    local self = JoystickKeyboard
    if self.isUserScriptRun() then
        return
    end
    local function pfnExec(self)
        local v = JoystickArcTemplate.getWeldWeaveParam()
        v=v+value
        if v>=99 then v=99
        elseif v<=0 then v=0
        end
        JoystickArcTemplate.setWeldWeaveParam(v)
        self.controller.setLedString(getNormalWeldValue())
        return self.controller.writeAllInfo()
    end
    local bErr,msgErr = KbEventListener.safeCallFunc(pfnExec,self)
    if not bErr then MyWelderDebugLog(tostring(msgErr)) end
end

--设置焊接相关的参数，value是增量值
function JoystickKeyboard.setWeldParams(value)
    local self = JoystickKeyboard
    if self.isUserScriptRun() then
        return
    end
    if self.hasError() then --这个报警值在normal模式下才会被修改
        return
    end
    if math.abs(value)<1 then return end
    local led = self.controller.getButtonLedState()
    if JbkLightID.isOnWeldArcParam(led) then
        self.setWeldArcParam(value)
    elseif JbkLightID.isOnWeldWeaveParam(led) then
        self.setWeldWeaveParam(value)
    end
end

function JoystickKeyboard.setRunRobot(value)
    local self = JoystickKeyboard
    --value={x,y,z}分别表示xyz三个方向值，每个值的含义：0停止，>0正向，<0负向；需要根据当前的xyzmode来决定是运动xyz还是rxyz；并且同时只能控制一个轴运动
    local x,y,z = value[1],value[2],value[3]
    
    local name = ""
    if self.bIsRxyz then name = "r" end
    if x>0 then name = name.."x+"
    elseif x<0 then name = name.."x-"
    elseif y>0 then name = name.."y+"
    elseif y<0 then name = name.."y-"
    elseif z>0 then name = name.."z+"
    elseif z<0 then name = name.."z-"
    else name = "stop"
    end
    
    if self.preAxisName~=name then
        self.preAxisName = name
        RobotModbusControl.runRobot("") --因为是上升沿触发，所以先将信号置0
        Wait(50)
        RobotModbusControl.runRobot(name)
    end
end

--控制器或者脚本是否有报警
function JoystickKeyboard.hasError()
    return JoystickKeyboard.bHasError
end

--运行状态的监控，控制按钮指示灯
function JoystickKeyboard.scriptRunStateMonitor()
    local self = JoystickKeyboard
    
    local value,info = GetRealTimeFeedback()
    if type(info)~="table" then return end
    
    local led = self.controller.getButtonLedState()
    -----------------------------------------------------
    value = info["ProgramState"] --0:脚本停止, 1:脚本运行中, 2:脚本暂停
    self.userScriptRunState = value
    if 0==value then
        led = JbkLightID.getOnAutoManual(led)
        self.bIsUserScriptRun = false
        led = JbkLightID.getOffVirtualRun(led) --虚拟灯灭
        led = JbkLightID.getOffRealRun(led) --真实灯灭
        led = JbkLightID.getOffStopProject(led) --停止灯灭
    else
        if 1==value then
            led = JbkLightID.getOffAutoManual(led)
        else
            --暂停时交替闪烁
            if JbkLightID.isOnAutoManual(led) then
                led = JbkLightID.getOffAutoManual(led)
            else
                led = JbkLightID.getOnAutoManual(led)
            end
        end
        self.bIsUserScriptRun = true
        led = JbkLightID.getOnStopProject(led) --运行时停止灯亮
        if not JbkLightID.isOnVirtualRun(led) and
           not JbkLightID.isOnRealRun(led) then
           --运行状态时，虚拟和真实肯定有一个灯是要亮的
           if WelderHandleControl.isVirtualWeld() then
               led = JbkLightID.getOnVirtualRun(led)
           else
               led = JbkLightID.getOnRealRun(led)
           end
        end
    end
    
    value = info["EnableStatus"] --0:下使能状态, 1:上使能状态
    if 0==value then self.bEnableRobot = false
    else self.bEnableRobot = true
    end
    
    value = info["DragStatus"] --0:不在拖拽, 1:关节拖拽, 2:力控拖拽
    if 0==value then self.bDragState = false
    else self.bDragState = true
    end
    
    if self.isNormalMode() then --普通模式下才控制led按钮灯
        if self.bEnableRobot then led = JbkLightID.getOnEnableRobot(led)
        else led = JbkLightID.getOffEnableRobot(led)
        end
        
        if self.bDragState then led = JbkLightID.getOnDragMode(led)
        else led = JbkLightID.getOffDragMode(led)
        end
        
        -----------------------------------------------------
        value = info["ErrorStatus"] --0:无报警, 1:有报警
        local collision = info["CollisionState"] --0:无碰撞, 1:有碰撞
        if 0==value and 0==collision then
            value = WelderHandleControl.getScriptErrCode() --无报警状态下，判断脚本是否运行报错
            if value==0 then
                self.bHasError = false
                led = JbkLightID.getOffClearWarn(led)
                self.controller.setLedString(getNormalWeldValue()) --恢复正常值
            else
                self.bHasError = true
                led = JbkLightID.getOnClearWarn(led)
                self.controller.setLedString("Err")
            end
        else
            self.bHasError = true
            led = JbkLightID.getOnClearWarn(led)
            self.controller.setLedString("ALAM")
        end
    end
    
    --执行操作--------------------------------------------
    self.controller.setButtonLedState(led)
    KbEventListener.safeCallFunc(self.controller.writeAllInfo)
end

return JoystickKeyboard