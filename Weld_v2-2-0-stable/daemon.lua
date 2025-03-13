EcoLog(" ----------------WeldScript daemon called --------------")
--此段代码是加载脚本配置环境，尽量不要在这段代码的前面添加其他代码块
do
    local currentDir = debug.getinfo(1,"S").source
    currentDir = string.sub(currentDir,2) --filter out '@'
    currentDir = string.reverse(currentDir)
    local pos = string.find(currentDir,"/",1,true)
    if nil==pos then pos = string.find(currentDir,"\\",1,true) end
    currentDir = string.sub(currentDir,pos)
    currentDir = string.reverse(currentDir).."?.lua"
    pos = string.find(package.path, currentDir, 1, true)
    if nil==pos then
        package.path = currentDir .. ";" .. package.path
    end
end
--------------------------------------------------------------------------------------------------------
--[[
lua自带的print打印的日志会输出到上位机控制台，而EcoLog却有不会打印到上位机控制台，为了方便日志管理和查看，
故而需要有一个特殊标志来判断到底是用print还是EcoLog，所以自己在WeldScript.lua中封装了一个全局的日志打印
函数 MyWelderDebugLog,在它里面判断用print还是EcoLog
]]--
gDbgLogPrefixContentFlagXXX = "daemon"

--------------------------------------------------------------------------------------------------------
package.loaded["WeldScript.WeldScriptLoader"] = nil
require("WeldScript.WeldScriptLoader") --加载焊接脚本

--===================================================================================================================
--主应用对象，前置声明，让本脚本的其他地方也能够调用该table中的一些属性方法
local MainApplication = {
    bIsMonitorWeldingState = true, --当前是否需要检测起弧状态，默认是
    bIsAbnormalEndArc = false, --是否为异常断弧。true为异常断弧，false为正常断弧
    bIsWeldingException = false, --焊接过程中出现焊接异常：暂停、急停、出错、报警
    oldTeachSignal = OFF --示教点信号之前的DI状态
}

---==================================================================================================================
local MyRPCHandler = {}
function MyRPCHandler.ModbusCreate(params)
    local err,id = MainApplication.connect()
    return {err,id}
end
function MyRPCHandler.ModbusClose(params)
    --[[因为daemon.lua会一直在运行，且一直与焊机通信，所以不要随便断开连接]]--
    --强制断开吧，降低处理的复杂度，因为在userAPI脚本运行时，都、没有主动断开的操作
    local _isOk,_data = pcall(MainApplication.disconnect)
    if not _isOk then MyWelderDebugLog(tostring(_data)) end
    _isOk,_data = pcall(function() ThreadSafeModbus.ModbusClose(params[1]) end)
    if not _isOk then MyWelderDebugLog(tostring(_data)) end
    return {0}
end
function MyRPCHandler.CreateScanner(params)
    local err,id = MainApplication.connect()
    return {err,id}
end
function MyRPCHandler.ScannerDestroy(params)
    local _isOk,_data = pcall(MainApplication.disconnect)
    if not _isOk then MyWelderDebugLog(tostring(_data)) end
    _isOk,_data = pcall(function() EtherNetIPScanner.ScannerDestroy(params[1]) end)
    if not _isOk then MyWelderDebugLog(tostring(_data)) end
    return {0}
end
function MyRPCHandler.AnalogCreate(params)
    local err,id = MainApplication.connect()
    return {err,id}
end
function MyRPCHandler.AnalogClose(params)
    local _isOk,_data = pcall(MainApplication.disconnect)
    if not _isOk then MyWelderDebugLog(tostring(_data)) end
    return {0}
end
--modbus
function MyRPCHandler.GetInRegs(params)
    return {ThreadSafeModbus.GetInRegs(params[1],params[2],params[3],params[4])}
end
function MyRPCHandler.GetHoldRegs(params)
    return {ThreadSafeModbus.GetHoldRegs(params[1],params[2],params[3],params[4])}
end
function MyRPCHandler.SetHoldRegs(params)
    return {ThreadSafeModbus.SetHoldRegs(params[1],params[2],params[3],params[4],params[5])}
end
--ethernetip
function MyRPCHandler.ScannerReadInput(params)
    return {EtherNetIPScanner.ScannerReadInput(params[1],params[2],params[3])}
end
function MyRPCHandler.ScannerReadOutput(params)
    return {EtherNetIPScanner.ScannerReadOutput(params[1],params[2],params[3])}
end
function MyRPCHandler.ScannerWrite(params)
    return {EtherNetIPScanner.ScannerWrite(params[1],params[2],params[3])}
end
function MyRPCHandler.OnEventUserScriptPause(params)
    return {MainApplication.doWhenUserLuaHasPause()}
end
function MyRPCHandler.OnEventUserScriptContinue(params)
    return {MainApplication.doWhenUserLuaHasContinue()}
end
function MyRPCHandler.StartArc(params)
    return {MainApplication.startArc()}
end
function MyRPCHandler.EndArc(params)
    return {MainApplication.endArc()}
end
function MyRPCHandler.ExecWireFeed(params)
    return {MainApplication.execWireFeed(params[1])}
end
function MyRPCHandler.ExecWireBack(params)
    return {MainApplication.execWireBack(params[1])}
end
function MyRPCHandler.ExecGasCheck(params)
    return {MainApplication.execGasCheck(params[1])}
end
function MyRPCHandler.StartHandeldControllerServer(params)
    return {MainApplication.startHandeldControllerServer(params[1])}
end

function MyRPCHandler.rpcServerResponse(method,paramsArray)
    if not MyRPCHandler[method] then
        return {}
    end
    if "ModbusCreate" == method then return MyRPCHandler.ModbusCreate(paramsArray)
    elseif "ModbusClose" == method then return MyRPCHandler.ModbusClose(paramsArray)
    elseif "AnalogCreate" == method then return MyRPCHandler.AnalogCreate(paramsArray)
    elseif "AnalogClose" == method then return MyRPCHandler.AnalogClose(paramsArray)
    elseif "GetInRegs" == method then return MyRPCHandler.GetInRegs(paramsArray)
    elseif "GetHoldRegs" == method then return MyRPCHandler.GetHoldRegs(paramsArray)
    elseif "SetHoldRegs" == method then return MyRPCHandler.SetHoldRegs(paramsArray)
    elseif "CreateScanner" == method then return MyRPCHandler.CreateScanner(paramsArray)
    elseif "ScannerDestroy" == method then return MyRPCHandler.ScannerDestroy(paramsArray)
    elseif "ScannerReadInput" == method then return MyRPCHandler.ScannerReadInput(paramsArray)
    elseif "ScannerReadOutput" == method then return MyRPCHandler.ScannerReadOutput(paramsArray)
    elseif "ScannerWrite" == method then return MyRPCHandler.ScannerWrite(paramsArray)
    elseif "OnEventUserScriptPause" == method then return MyRPCHandler.OnEventUserScriptPause(paramsArray)
    elseif "OnEventUserScriptContinue" == method then return MyRPCHandler.OnEventUserScriptContinue(paramsArray)
    elseif "StartArc" == method then return MyRPCHandler.StartArc(paramsArray)
    elseif "EndArc" == method then return MyRPCHandler.EndArc(paramsArray)
    elseif "ExecWireFeed" == method then return MyRPCHandler.ExecWireFeed(paramsArray)
    elseif "ExecWireBack" == method then return MyRPCHandler.ExecWireBack(paramsArray)
    elseif "ExecGasCheck" == method then return MyRPCHandler.ExecGasCheck(paramsArray)
    elseif "StartHandeldControllerServer" == method then return MyRPCHandler.StartHandeldControllerServer(paramsArray)
    end
end

---==================================================================================================================
local g_innerTaskLockerName = "DaemonWelderThdSafeLocker-5C03E153-9E13-4FE2-9713-9B7CAB52B5C0"
local function enterSafeLock()
    Lock(g_innerTaskLockerName,8000,10000)
end
local function leaveSafeLock()
    UnLock(g_innerTaskLockerName)
end

local function responseRPCThreadSafe(method, paramsArray)
    local isOk,data = pcall(MyRPCHandler.rpcServerResponse,method,paramsArray) --执行函数
    if not isOk then
        MyWelderDebugLog(tostring(data))
        return {false,data} --将错误信息返回给tcp客户端
    end
    table.insert(data,1,true)
    table.insert(data,2,"")
    return data
end

--------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------
--[[
重要说明：
1. 此处为备份说明，目前控制器的RPC机制还在完善中，为了兼容2种rpc方式，故此保留2种实现方式。
2. `MainApplication.rpcAPIServer()`与`httpAPIServer()|userAPIServer()`都是提供RPC服务的，但是二者不能同时使用。
3. 选择不同的方式时，要在`MainApplication.run()`中切换对应的方式，同时也要在`DobotWelderRPC.lua`中切换对应的方式。
4. 后期控制器的rpc机制稳定后再删除遗留的代码。
]]--
--控制器提供的rpc线程服务，提供给userAPI.lua和httpAPI.lua的响应请求
function MainApplication.rpcAPIServer()
    MyWelderDebugLog("daemon rcp server thread has running.......")
    local _isOk,_data = pcall(DobotWelderRPC.rpcServer.rpcAPIServer,responseRPCThreadSafe)
    if not _isOk then MyWelderDebugLog(tostring(_data)) end
    MyWelderDebugLog("daemon rcp server thread has finished!!!")
end
--[[
--httpAPI.lua的服务响应请求函数
local function httpAPIServer()
    local _isOk,_data
    while true do
        _isOk,_data = pcall(DobotWelderRPC.rpcServer.httpAPIServer,responseRPCThreadSafe)
        if not _isOk then MyWelderDebugLog(tostring(_data)) end
        MyWelderDebugLog("httpAPI.lua tcp has disconnect")
        Wait(1000) --刚开始启动时，没有参数，tcp连接肯定会失败，所以不要那么频繁的操作
    end
end

--userAPI.lua的服务响应请求函数
local function userAPIServer()
    local _isOk,_data
    while true do
        _isOk,_data = pcall(DobotWelderRPC.rpcServer.userAPIServer,responseRPCThreadSafe)
        if not _isOk then MyWelderDebugLog(tostring(_data)) end
        MyWelderDebugLog("userAPI.lua tcp has disconnect")
        Wait(1000) --刚开始启动时，没有参数，tcp连接肯定会失败，所以不要那么频繁的操作
    end
end
]]--
--------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------
--连接modbus并创建焊机
--返回值第一个数据为0表示成功，此时第二个参数表示连接的句柄id
function MainApplication.connect()
    local function inner_connect()
        MainApplication.welder = RobotManager.createDobotWelder(MainApplication.globalParams.getSelectedWelder())
        MainApplication.welder:connect() --焊机连接初始化
    end
    local function inner_isConnected()
        if MainApplication.welder:isConnected() then
            return 0,MainApplication.welder:getIOStreamObject():getConnector()
        end
        return MainApplication.welder:getIOStreamObject():getErrorId(),-1
    end
    local _dOk,errConn
    local isConnectedOk,err,id
    enterSafeLock()
    _dOk,errConn = pcall(inner_connect)
    isConnectedOk,err,id = pcall(inner_isConnected)
    leaveSafeLock()
    if type(errConn)=="string" then MyWelderDebugLog(errConn) end
    if type(err)=="string" then MyWelderDebugLog(err) end
    if true==isConnectedOk then return err,id end
    return -1,-1
end
--断开连接
function MainApplication.disconnect()
    enterSafeLock()
    if nil~=MainApplication.welder then
        pcall(function() MainApplication.welder:disconnect() end)
        MainApplication.welder = nil
    end
    leaveSafeLock()
end

--当userAPI.lua停止时做的处理
function MainApplication.doWhenUserLuaHasStoped()
    enterSafeLock()
    if nil~=MainApplication.welder then
        pcall(function() MainApplication.welder:doWhenUserLuaHasStoped() end)
    end
    leaveSafeLock()
    MainApplication.setMonitorWeldingState(true)
    MainApplication.setAbnormalEndArc(false)
    MainApplication.setWeldingException(false)
end

--当userAPI.lua暂停时做的处理
function MainApplication.doWhenUserLuaHasPause()
    enterSafeLock()
    if nil~=MainApplication.welder then
        if MainApplication.globalParams.isWelding() then
            MainApplication.setWeldingException(true,false) --在焊接中暂停认为是焊接异常
        end
        pcall(function() MainApplication.welder:doWhenUserLuaHasPause() end)
        MainApplication.setMonitorWeldingState(true,false)
    end
    leaveSafeLock()
    return 0
end

--当userAPI.lua继续运行时做的处理
function MainApplication.doWhenUserLuaHasContinue()
    local params = MainApplication.getArcAbnormalStopParam()
    local _scriptOk,rOk,strErrMsg,isContinue
    local retValue = 0
    isContinue = MainApplication.isArcStarting() --处于焊接流程中被暂停后，点击继续则需要重新起弧。
              or MainApplication.isAbnormalEndArc() --处于焊接过程中因为异常断弧导致的暂停，点击继续则需要重新起弧。
    if isContinue and nil~=MainApplication.welder then
        if not MainApplication.isAbnormalEndArc() then
            params.retryCount = 1
        end
        for i=1,params.retryCount do
            --尝试多次再引弧
            enterSafeLock()
            _scriptOk,rOk,strErrMsg = pcall(function() return MainApplication.welder:doWhenUserLuaHasContinue() end)
            leaveSafeLock()
            if true==rOk then break end
        end
        if true==rOk then
            MainApplication.setAbnormalEndArc(false)
        else
            retValue = -1
            strErrMsg = strErrMsg or rOk or "" --scriptOk为false时则rOk就是错误信息，此时strErrMsg是nil,所以使用这种多路表达式
            WeldReportScriptPause(strErrMsg) --抛出错误信息并让用户脚本暂停运行
        end
    end
    return retValue
end

function MainApplication.startArc()
    local isOk,returnValue,msg
    enterSafeLock()
    if nil~=MainApplication.welder then
        isOk,returnValue,msg = pcall(function() return MainApplication.welder:rpcStartArc() end)
    end
    leaveSafeLock()
    if true==isOk then return returnValue,msg end
    return isOk,returnValue
end

function MainApplication.endArc()
    local isOk,returnValue,msg
    enterSafeLock()
    if nil~=MainApplication.welder then
        isOk,returnValue,msg = pcall(function() return MainApplication.welder:rpcEndArc() end)
    end
    leaveSafeLock()
    if true==isOk then return returnValue,msg end
    return isOk,returnValue
end

function MainApplication.execWireFeed(msTimeout)
    local isOk,returnValue
    enterSafeLock()
    if nil~=MainApplication.welder then
        isOk,returnValue = pcall(function() return MainApplication.welder:setWireFeed(true) end)
    end
    leaveSafeLock()
    
    if math.type(msTimeout)=="integer" and msTimeout>0 then Wait(msTimeout) end
    
    enterSafeLock()
    if nil~=MainApplication.welder then
        isOk,returnValue = pcall(function() return MainApplication.welder:setWireFeed(false) end)
    end
    leaveSafeLock()
    
    if true==isOk then return returnValue end
    return isOk
end
function MainApplication.execWireBack(msTimeout)
    local isOk,returnValue
    enterSafeLock()
    if nil~=MainApplication.welder then
        isOk,returnValue = pcall(function() return MainApplication.welder:setWireBack(true) end)
    end
    leaveSafeLock()
    
    if math.type(msTimeout)=="integer" and msTimeout>0 then Wait(msTimeout) end
    
    enterSafeLock()
    if nil~=MainApplication.welder then
        isOk,returnValue = pcall(function() return MainApplication.welder:setWireBack(false) end)
    end
    leaveSafeLock()
    
    if true==isOk then return returnValue end
    return isOk
end
function MainApplication.execGasCheck(msTimeout)
    local isOk,returnValue
    enterSafeLock()
    if nil~=MainApplication.welder then
        isOk,returnValue = pcall(function() return MainApplication.welder:setGasCheck(true) end)
    end
    leaveSafeLock()
    
    if math.type(msTimeout)=="integer" and msTimeout>0 then Wait(msTimeout) end
    
    enterSafeLock()
    if nil~=MainApplication.welder then
        isOk,returnValue = pcall(function() return MainApplication.welder:setGasCheck(false) end)
    end
    leaveSafeLock()
    
    if true==isOk then return returnValue end
    return isOk
end

--断弧再引弧的相关配置参数获取
function MainApplication.getArcAbnormalStopParam()
    local returnValue
    local params = MainApplication.globalParams.getSpecialHandleParams()
    if type(params)~="table" then
        params = {}
        params.arcAbnormalStop = {isRetry=false, retryCount=1, backDistance=0}
    elseif type(params.arcAbnormalStop)~="table" then
        params.arcAbnormalStop = {isRetry=false, retryCount=1, backDistance=0}
    else
        if type(params.arcAbnormalStop.isRetry)~="boolean" then params.arcAbnormalStop.isRetry=false end
        if math.type(params.arcAbnormalStop.retryCount)~="integer" then params.arcAbnormalStop.retryCount=1 end
        if type(params.arcAbnormalStop.backDistance)~="number" then params.arcAbnormalStop.backDistance=0 end
    end
    returnValue = params.arcAbnormalStop
    return returnValue
end

function MainApplication.isWeldingException()
    local v = false
    enterSafeLock()
    v = MainApplication.bIsWeldingException
    leaveSafeLock()
    return v
end
function MainApplication.setWeldingException(bState,bLock)
    if true==bLock then enterSafeLock() end
    MainApplication.bIsWeldingException = bState
    if true==bLock then leaveSafeLock() end
end

function MainApplication.isAbnormalEndArc()
    local v = false
    enterSafeLock()
    v = MainApplication.bIsAbnormalEndArc
    leaveSafeLock()
    return v
end
function MainApplication.setAbnormalEndArc(bState,bLock)
    if true==bLock then enterSafeLock() end
    MainApplication.bIsAbnormalEndArc = bState
    if true==bLock then leaveSafeLock() end
end

function MainApplication.isMonitorWeldingState()
    local v = true
    enterSafeLock()
    v = MainApplication.bIsMonitorWeldingState
    leaveSafeLock()
    return v
end
function MainApplication.setMonitorWeldingState(bState,bLock)
    if true==bLock then enterSafeLock() end
    MainApplication.bIsMonitorWeldingState = bState
    if true==bLock then leaveSafeLock() end
end

function MainApplication.isNull()
    local val = true
    enterSafeLock()
    if nil~=MainApplication.welder then
        val = false
    end
    leaveSafeLock()
    return val
end
function MainApplication.readArcStateRealtime()
    local isOk,returnValue
    enterSafeLock()
    if nil~=MainApplication.welder then
        isOk,returnValue = pcall(function() return MainApplication.welder:readArcStateRealtime() end)
    end
    leaveSafeLock()
    if true==isOk then return returnValue end
    return nil
end
function MainApplication.hasEndArcByMannual()
    local isOk,returnValue
    enterSafeLock()
    if nil~=MainApplication.welder then
        isOk,returnValue = pcall(function() return MainApplication.welder:hasEndArcByMannual() end)
    end
    leaveSafeLock()
    if true==isOk then return returnValue end
    return nil
end
function MainApplication.isArcStarting()
    local returnValue = false
    returnValue = MainApplication.globalParams.isArcStarting()
    return returnValue
end
function MainApplication.setEndArcStarting()
    MainApplication.globalParams.setArcStarting(false)
end
function MainApplication.isWelding()
    local returnValue = false
    returnValue = MainApplication.globalParams.isWelding()
    return returnValue
end
function MainApplication.setEndWelding()
    MainApplication.globalParams.setWelding(false)
end
function MainApplication.readWelderRunStateInfo()
    local isOk,returnValue
    enterSafeLock()
    if nil~=MainApplication.welder then
        isOk,returnValue = pcall(function() return MainApplication.welder:readWelderRunStateInfo() end)
    end
    leaveSafeLock()
    if true==isOk then return returnValue end
    return nil
end
function MainApplication.hasCollision()
    local function innerExectue()
        local params = MainApplication.globalParams.getAnalogIOSignalParam() or {}
        local signalIO = params.collisionDetectionParam
        if nil==signalIO then return false end
        if math.type(signalIO.detectType)~="integer" or math.type(signalIO.signalDI)~="integer" then return false end
        if signalIO.signalDI<1 then return false end
        if 1==signalIO.detectType then
            return ON==DI(signalIO.signalDI)
        elseif 2==signalIO.detectType then
            return ON==ToolDI(signalIO.signalDI)
        end
        return false
    end

    local isOk,returnValue = pcall(innerExectue)
    if true==isOk then return returnValue end
    return nil
end
function MainApplication.checkPushButtonPressTrigger()
    local function innerExectue()
        local params = MainApplication.globalParams.getAnalogIOSignalParam() or {}
        local signalIO = params.teachPointParam
        if nil==signalIO then return false end
        if math.type(signalIO.detectType)~="integer" or math.type(signalIO.signalDI)~="integer" then return false end
        if signalIO.signalDI<1 then return false end
        
        local state
        if 1==signalIO.detectType then
            state = DI(signalIO.signalDI)
        elseif 2==signalIO.detectType then
            state = ToolDI(signalIO.signalDI)
        else
            return
        end
        if ON~=state then
            MainApplication.oldTeachSignal = OFF
            return false
        end
        --上升沿触发
        if nil==MainApplication.oldTeachSignal or OFF==MainApplication.oldTeachSignal then
            MainApplication.oldTeachSignal = ON
            MqttRobot.triggerAddCurrentPose()
        end
        return true
    end

    local isOk,returnValue = pcall(innerExectue)
    if true==isOk then return returnValue end
    return nil
end

--焊接过程中状态的监控
function MainApplication.monitorWeldingState()
    local arcState = nil --起弧状态true/false
    local isManualArc = nil --是否为主动灭弧true/false
    local _isOk,controllerStateInfo = nil --控制器状态信息
    while true do
        if not MainApplication.isNull() and MainApplication.isWelding() and MainApplication.isMonitorWeldingState() then
            arcState = MainApplication.readArcStateRealtime()
            if true==arcState then --起弧状态,不用处理
                --do nothing
                MainApplication.setWeldingException(false) --正常焊接中，认为没有异常
            else --灭弧状态,说明焊接过程中灭弧了或者通信异常了
                isManualArc = MainApplication.hasEndArcByMannual() or not MainApplication.isWelding()
                if true==isManualArc then --主动灭弧的，则不作任何处理
                    MainApplication.setWeldingException(false) --主动灭弧的，认为没有异常
                    MainApplication.setEndWelding() --强制复位，否则会一直进入这里判断
                else
                    MyWelderDebugLog(Language.trLang("DAEMON_CHECK_END_WELD")..",arcState="..tostring(arcState)..",isManualArc="..tostring(isManualArc))
                    MainApplication.setMonitorWeldingState(false) --强制复位，否则会一直进入这里判断
                    MainApplication.setWeldingException(true) --在焊接中异常断弧认为是焊接异常

                    --勾选了异常断弧处理，则需要特殊处理
                    if MainApplication.getArcAbnormalStopParam().isRetry then
                        MainApplication.setAbnormalEndArc(true) --异常断弧标志
                        MyWelderDebugLog(Language.trLang("DAEMON_CHECK_END_WELD_PAUSE"))
                    else
                        MyWelderDebugLog(Language.trLang("DAEMON_CHECK_END_WELD_FINISHED"))
                    end
                    WeldReportScriptPause(Language.trLang("CHECK_EXCEPT_ARC_END")) --抛出错误信息并让用户脚本暂停运行
                    --异常灭弧时`WeldReportScriptPause`会告知控制器抛出错误信息并会让脚本暂停运行，所以下面的逻辑就没什么意义，直接去掉
                    --[[
                    _isOk,controllerStateInfo = GetRealTimeFeedback()
                    if type(controllerStateInfo)=="table" then
                        if 2~=controllerStateInfo["ProgramState"] then --当前脚本不是暂停状态，则暂停
                            Pause() --暂停userAPI.lua脚本
                        end
                    else
                        Pause() --暂停userAPI.lua脚本
                    end
                    ]]--
                end
            end
        end
        Wait(200)
    end
end

--轮询各种状态检测
function MainApplication.loopDetectState()
    local isCollisionReported = false --碰撞状态是否已经报告
    local welderStateInfo = nil --焊机状态信息
    local heartbeatTime,scriptrunTime,endTime = 0,0,0
    while true do
        --碰撞状态检测--------------
        if true==MainApplication.hasCollision() then
            if false==isCollisionReported then
                isCollisionReported = true
                local strErr = Language.trLang("HAS_COLLISION")
                MyWelderDebugLog(strErr)
                WeldReportScriptStop(strErr) --抛出错误信息并让用户脚本停止运行
            end
        else
            isCollisionReported = false
        end
        
        MainApplication.checkPushButtonPressTrigger() --按键触发检测

        --焊机心跳状态读取检测
        endTime = Systime()
        if (endTime-heartbeatTime)>=500 then
            welderStateInfo = MainApplication.readWelderRunStateInfo()
            if true==MainApplication.isWeldingException() then --焊接过程中有异常则
                welderStateInfo.weldState = 2 --具体参考`GlobalParameter.lua`文件的`innerWeldRunStateInfo`
            end
            MqttRobot.publish("/mqtt/weld/getWelderStateInfo",welderStateInfo)
            --[[
            if nil==welderStateInfo or not welderStateInfo.connectState then
                MyWelderDebugLog(Language.trLang("DAEMON_READ_WELD_ERR"))
            end
            ]]--
            heartbeatTime = endTime
        end
        
        --脚本运行时长推送
        endTime = Systime()
        if (endTime-scriptrunTime)>=1000 then
            local timeObject = GlobalParameter.getScriptStartTimeInfo()
            if nil~=timeObject then --不为空则发布消息出去
                MqttRobot.publish("/mqtt/weld/getWeldCostTimeInfo",timeObject)
            end
            scriptrunTime = endTime
        end

        Wait(100)
    end
end

--插件启动时按照需要是否启动按钮盒子服务
function MainApplication.startHandeldController()
    local function pfnExecute()
        if GlobalParameter.getButtonBoxOnOff() then
            JoystickKeyboard.startServer()
        end
    end
    local bOk,msg = pcall(pfnExecute)
    if not bOk then MyWelderDebugLog(tostring(msg)) end
end
--控制按钮盒子服务的启动与停止,成功返回true，失败返回false
function MainApplication.startHandeldControllerServer(bRun)
    local function pfnExecute(bRun)
        if bRun then
            return JoystickKeyboard.startServer()
        else
            JoystickKeyboard.stopServer()
            return true
        end
    end
    local bErr,bOk = pcall(pfnExecute,bRun)
    if not bErr then MyWelderDebugLog(tostring(bOk)) end
    if bErr then
        return bOk
    else
        return false
    end
end

--[[
功能：监控userAPI.lua脚本停止的事件回调函数
参数：无
返回值：无
说明：1. 当userAPI.lua脚本停止时，该回调函数被触发
      2. 该函数只能是全局函数，因为底层会从_G表中查找这个函数的
      3. 为了防止出现_G表中出现同名函数覆盖问题，该函数名称要特殊些
]]--
function _DaemonMonitorUserScriptStopChangedCallback()
    MyWelderDebugLog(Language.trLang("DAEMON_USER_PAUSE_BEGIN"))
    MainApplication.doWhenUserLuaHasStoped()
    MainApplication.setEndWelding()
    MainApplication.setEndArcStarting()
    MyWelderDebugLog(Language.trLang("DAEMON_USER_PAUSE_END"))
    
    local timeObject = GlobalParameter.updateWeldCostTime() --脚本停止运行时更新焊接程序运行的统计时间
    if nil~=timeObject then --不为空则发布消息出去
        MqttRobot.publish("/mqtt/weld/getWeldCostTimeInfo",timeObject)
    end
end

function MainApplication.run()
    DobotWelderRPC.modbus.useRPC = false --让daemon.lua脚本自己调用modbus时不走rpc方式调用，而是直接方式调用。
    MainApplication.globalParams = GlobalParameter --加载全局配置参数
    
    --特殊处理：通常控制器直接关机，然后再开机后，打开插件就出现连接上了焊机的假象。
    --然而只有daemon.lua在控制器重启时才会被调用，因此在这里添加清空数据比较合适。
    GlobalParameter.saveWelderRunStateInfo({})
    GlobalParameter.setArcStarting(false) --防止脚本直接停止导致参数没复位，所以每次启动脚本提前复位
    
    RegisteStopHandler("_DaemonMonitorUserScriptStopChangedCallback") --调用生态接口注册回调函数
    MainApplication.startHandeldController() --根据需要是否启动按钮盒子
    local thdAPI = {}
--[[
    thdAPI[1] = systhread.create(httpAPIServer)
    thdAPI[2] = systhread.create(userAPIServer)
    thdAPI[3] = systhread.create(MainApplication.loopDetectState)
    MainApplication.monitorWeldingState()
    thdAPI[1]:wait()
    thdAPI[2]:wait()
    thdAPI[3]:wait()
]]--
    thdAPI[1] = systhread.create(MainApplication.loopDetectState)
    thdAPI[2] = systhread.create(MainApplication.rpcAPIServer)
    MainApplication.monitorWeldingState()
    thdAPI[1]:wait()
    thdAPI[2]:wait()
end

MainApplication.run()