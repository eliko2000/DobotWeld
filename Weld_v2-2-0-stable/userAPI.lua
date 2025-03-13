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
gDbgLogPrefixContentFlagXXX = "userAPI"

--------------------------------------------------------------------------------------------------------
package.loaded["WeldScript.WeldScriptLoader"] = nil
require("WeldScript.WeldScriptLoader") --加载焊接脚本
DobotWelderRPC.modbus.initUserAPI() --提前初始化，不要随便修改该接口调用的位置
--------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------

--统一封装error报错信息接口
local function myerror(msg)
    GlobalParameter.setWeldScriptRunErrorCode()
    error(msg,2)
end

--内部封装的api
local InnerAPIWrapper = {
    strSafeGuardMultiThreadLockerName="ExportFunction-9744E49D-7271-00BC-1D34-9E7B1D1FE74F",
    globalParams = nil, --全局配置参数
    welder = nil, --当前选中的焊机
    isRegisteCallbackEvent = false, --是否已经注册了回调事件
    isLaserTrackStarting = nil, --激光跟踪是否已开启
    isArcTrackStarting = nil --电弧跟踪是否已开启
}

function InnerAPIWrapper.enterLock()
    Lock(InnerAPIWrapper.strSafeGuardMultiThreadLockerName,3000,9000)
end
function InnerAPIWrapper.leaveLock()
    UnLock(InnerAPIWrapper.strSafeGuardMultiThreadLockerName)
end

--[[
功能：userAPI.lua脚本运行状态改变回调入口
参数：eventName-事件名称
      response-table类型,输出值,返回给控制器使用。约定好的字段有：res=true表示业务执行成功
返回值：无
说明：该接口不对外公布
]]--
function InnerAPIWrapper.OnEventUserScriptRunStateChanged(eventName,response)
    --这个回调事件是由控制器触发的，且不在src0线程中，所以抛错误要用控制器提供的报错函数而不能用error
    MyWelderDebugLog("userAPI had trigger callback,event="..tostring(eventName))
    if "pause"==eventName then
        if InnerAPIWrapper.isLaserTrackStarting then --激光跟踪过程中不允许出现脚本暂停现象，因此强制停止脚本
            WeldReportScriptStop(Language.trLang("LASER_TRACK_PAUSE"))
        elseif InnerAPIWrapper.isArcTrackStarting then --电弧跟踪过程中不允许出现脚本暂停现象，因此强制停止脚本
            WeldReportScriptStop(Language.trLang("ARC_TRACK_PAUSE"))
        elseif 0~=DobotWelderRPC.api.OnEventUserScriptPause() then
            WeldReportScriptStop(Language.trLang("SCRIPT_PAUSE_DO_FAIL"))
        end
        MyWelderDebugLog("============>>userAPI had finished pause event...")
    elseif "continue"==eventName then
        MyWelderDebugLog("============>>DobotPathRecovery starting...")
        if 0~=DobotPathRecovery() then --调用控制器通知机器人移动到焊枪抬起前的后方位置
            MyWelderDebugLog("The robot did not arrive at the target location!!!!")
            return --返回非0表示还未到达暂停点时，又点击了暂停脚本，此时不能做起弧相关动作
        end
        MyWelderDebugLog("============>>DobotPathRecovery had finished...")
        local ret = DobotWelderRPC.api.OnEventUserScriptContinue()
        if nil==ret then --调用RPC失败返回了nil
            WeldReportScriptStop(Language.trLang("SCRIPT_CONTINUE_DO_FAIL"))
        elseif 0~=ret then --断弧再引弧执行失败了返回非0
            if type(response)=="table" then response.res=false end
        end
        MyWelderDebugLog("============>>userAPI had finished continue event...")
    else
        MyWelderDebugLog("not support event：eventName="..tostring(eventName))
    end
end

function InnerAPIWrapper.registerUserScriptCallbackEvent()
    --注册回调事件
    if not InnerAPIWrapper.isRegisteCallbackEvent then
        InnerAPIWrapper.enterLock()
        if not InnerAPIWrapper.isRegisteCallbackEvent then
            InnerAPIWrapper.isRegisteCallbackEvent = true
            local callbackName = "_OnEventUserScriptRunStateChanged_Callback"
            ExportFunction(callbackName,InnerAPIWrapper.OnEventUserScriptRunStateChanged)
            RegistePauseHandler(callbackName) --调用生态框架接口注册回调函数
            RegisteContinueHandler(callbackName)
        end
        InnerAPIWrapper.leaveLock()
    end
end

--true表示有焊机，false表示无焊机
function InnerAPIWrapper.hasWelder()
    if nil == InnerAPIWrapper.globalParams then
        InnerAPIWrapper.enterLock()
        if nil == InnerAPIWrapper.globalParams then
            InnerAPIWrapper.globalParams = GlobalParameter --加载全局配置参数
        end
        InnerAPIWrapper.leaveLock()
    end
    if not InnerAPIWrapper.globalParams.isVirtualWeld() then
        return true --如果不是虚拟焊，则一定按照有焊机来操作
    end
    return InnerAPIWrapper.globalParams.isHasWelder()
end

function InnerAPIWrapper.initWeldPlugin()
    --注册用户脚本回调事件
    InnerAPIWrapper.registerUserScriptCallbackEvent()
    
    if not InnerAPIWrapper.hasWelder() then
        return --无焊机则直接返回
    end
    
    --初始化参数
    if nil == InnerAPIWrapper.globalParams then
        InnerAPIWrapper.enterLock()
        if nil == InnerAPIWrapper.globalParams then
            InnerAPIWrapper.globalParams = GlobalParameter --加载全局配置参数
        end
        InnerAPIWrapper.leaveLock()
    end
    if nil == InnerAPIWrapper.welder then
        InnerAPIWrapper.enterLock()
        if nil == InnerAPIWrapper.welder then
            InnerAPIWrapper.welder = RobotManager.createDobotWelder(InnerAPIWrapper.globalParams.getSelectedWelder())
        end
        InnerAPIWrapper.leaveLock()
    end

    --连接焊机
    if nil == InnerAPIWrapper.welder then
        myerror(Language.trLang("WELDER_OBJ_IS_NULL"))
        return
    end
    if not InnerAPIWrapper.welder:isConnected() then
        InnerAPIWrapper.enterLock()
        if not InnerAPIWrapper.welder:isConnected() then
            if not InnerAPIWrapper.welder:connect() then --焊机连接初始化
                InnerAPIWrapper.leaveLock()
                myerror("userAPI->"..tostring(DobotWelderRPC.modbus.name)..","..Language.trLang("WELDER_NOT_CONNECT"))
                return
            end
            pcall(InnerAPIWrapper.globalParams.recordWeldScriptStarted) --连接成功记录焊接脚本在运行
        end
        InnerAPIWrapper.leaveLock()
    end
end

--定制版激光器初始化连接--
function InnerAPIWrapper.initLaserCVPlugin(funcType)
    --注册用户脚本回调事件
    InnerAPIWrapper.registerUserScriptCallbackEvent()

    --为nil则表示断开连接
    if nil==funcType then
        SmartLaserCV.disconnect()
        return
    end
    
    if not SmartLaserCV.selectFunction(funcType) then
        myerror(Language.trLang("LASER_SELECTED_FAIL"))
        return
    end
    if not SmartLaserCV.isConnected() then
        if not SmartLaserCV.connect() then
            myerror(Language.trLang("LASER_CONNECT_FAIL"))
            return
        end
    end
end

--通用版激光器初始化连接--
function InnerAPIWrapper.initCommonLaserCVPlugin(funcType)
    --注册用户脚本回调事件
    InnerAPIWrapper.registerUserScriptCallbackEvent()

    --为nil则表示断开连接
    if nil==funcType then
        CommonLaserCV.disconnect()
        return
    end
    
    if not CommonLaserCV.selectFunction(funcType) then
        myerror(Language.trLang("LASER_SELECTED_FAIL"))
        return
    end
    if not CommonLaserCV.isConnected() then
        if not CommonLaserCV.connect() then
            myerror(Language.trLang("LASER_CONNECT_FAIL"))
            return
        end
    end
end

function InnerAPIWrapper.setWeldMode(strWeldMode)
    InnerAPIWrapper.initWeldPlugin()
    if not InnerAPIWrapper.hasWelder() then return end --无焊机直接返回
    
    if type(strWeldMode)=="string" then
        if not InnerAPIWrapper.welder:getWelderParamObject():setWeldMode(strWeldMode) then
            myerror(Language.trLang("SET_WELD_MODE_FAIL"))
            return
        end
        if not InnerAPIWrapper.welder:setWeldMode(strWeldMode) then
            myerror(Language.trLang("SEND_WELD_MODE_FAIL"))
            return
        end
        MqttRobot.publish("/mqtt/weld/getWelderWeldMode",strWeldMode)
    end
end

--取消该接口
--[[
function InnerAPIWrapper.setVirtualWeld(bIsVirtual)
    InnerAPIWrapper.initWeldPlugin()
    InnerAPIWrapper.globalParams.setVirtualWeld(bIsVirtual)
end
]]--

function InnerAPIWrapper.SetWeldJobId(id)
    InnerAPIWrapper.initWeldPlugin()
    if not InnerAPIWrapper.hasWelder() then return end --无焊机直接返回
    
    if type(id)=="number" and math.type(id)=="integer" and id>=0 then
        local param = InnerAPIWrapper.welder:getWelderParamObject():getJobModeParam()
        param.jobId = id
        if not InnerAPIWrapper.welder:getWelderParamObject():setJobModeParam(param) then
            myerror(Language.trLang("SET_JOB_FAIL"))
            return
        end
        if not InnerAPIWrapper.welder:setJobId(id) then
            myerror(Language.trLang("SEND_JOB_FAIL"))
            return
        end
        MqttRobot.publish("/mqtt/weld/getWelderJobModeParam",param)
    end
end

function InnerAPIWrapper.selectWeldArcParams(index)
    InnerAPIWrapper.initWeldPlugin()
    if not InnerAPIWrapper.hasWelder() then return end --无焊机直接返回
    
    local param = InnerAPIWrapper.welder:getWelderParamObject():getNotJobModeParamHttp()
    if math.type(index)~="integer" then myerror(Language.trLang("SET_ARC_PRM_INDEX_NOT_EXIST")) return end
    if type(param)~="table" then myerror(Language.trLang("SET_ARC_PRM_INDEX_NOT_EXIST")) return end
    if type(param.params)~="table" then myerror(Language.trLang("SET_ARC_PRM_INDEX_NOT_EXIST")) return end
    if index<1 or index>#param.params then myerror(Language.trLang("SET_ARC_PRM_INDEX_NOT_EXIST")) return end
    param.selectedId = index
    if not InnerAPIWrapper.welder:getWelderParamObject():setNotJobModeParam(param) then
        myerror(Language.trLang("SET_ARC_PRM_INDEX_FAIL"))
    else
        MqttRobot.publish("/mqtt/weld/getWelderNotJobModeParamId",index)
        MqttRobot.publish("/mqtt/weld/getWelderNotJobModeParam",param.params[index])
    end
end

function InnerAPIWrapper.selectWeldWeaveParams(index)
    InnerAPIWrapper.initWeldPlugin()
    local dataParam = {}
    if nil==index or index<1 then
        dataParam.weaveType = "line"
        dataParam.alias = ""
        dataParam.frequency = 0
        dataParam.startDirection = 0
        dataParam.amplitudeLeft = 0
        dataParam.amplitudeRight = 0
        dataParam.amplitude = 0
        dataParam.radius = 0
        dataParam.stopMode = {
            checked = false,
            mode = 0,
            stopTime = {0,0,0,0}
        }
    else
        param = InnerAPIWrapper.globalParams.getWeaveParam()
        if type(param)~="table" then myerror(Language.trLang("SET_WAVE_PRM_INDEX_NOT_EXIST")) return end
        if type(param.params)~="table" then myerror(Language.trLang("SET_WAVE_PRM_INDEX_NOT_EXIST")) return end
        if index>#param.params then myerror(Language.trLang("SET_WAVE_PRM_INDEX_NOT_EXIST")) return end
        param.fileId = index
        InnerAPIWrapper.globalParams.setWeaveParam(param)
        dataParam = param.params[index]
        MqttRobot.publish("/mqtt/weld/getWeaveParam",dataParam)
    end

    --调用生态接口，将参数设置给算法
    local waveOpt = {}
    if "line" == dataParam.weaveType then waveOpt.weaveStyle=0
    elseif "triangle" == dataParam.weaveType then waveOpt.weaveStyle=1
    elseif "spiral" == dataParam.weaveType then waveOpt.weaveStyle=2
    elseif "trapezoid" == dataParam.weaveType then waveOpt.weaveStyle=3
    elseif "sine" == dataParam.weaveType then waveOpt.weaveStyle=4
    elseif "crescent" == dataParam.weaveType then waveOpt.weaveStyle=5
    elseif "triangle3D" == dataParam.weaveType then waveOpt.weaveStyle=6
    else waveOpt.weaveStyle=0
    end
    waveOpt.frequency = dataParam.frequency
    waveOpt.direction = dataParam.startDirection
    if "spiral" == dataParam.weaveType or "crescent" == dataParam.weaveType then
        waveOpt.leftAmplitude = dataParam.amplitude
        waveOpt.rightAmplitude = dataParam.amplitude
    else
        waveOpt.leftAmplitude = dataParam.amplitudeLeft
        waveOpt.rightAmplitude = dataParam.amplitudeRight
    end
    waveOpt.radius = dataParam.radius
    waveOpt.radian = dataParam.radian
    waveOpt.angle = dataParam.angle
    if dataParam.stopMode.checked then
        waveOpt.stopMode = dataParam.stopMode.mode
        waveOpt.stopTime1 = dataParam.stopMode.stopTime[1]
        waveOpt.stopTime2 = dataParam.stopMode.stopTime[2]
        waveOpt.stopTime3 = dataParam.stopMode.stopTime[3]
        waveOpt.stopTime4 = dataParam.stopMode.stopTime[4]
    else
        waveOpt.stopMode = 0
        waveOpt.stopTime1 = 0
        waveOpt.stopTime2 = 0
        waveOpt.stopTime3 = 0
        waveOpt.stopTime4 = 0
    end
    MyWelderDebugLog("Wave parameters:",waveOpt)
    WeaveParams(waveOpt) --调用生态接口，将参数设置给算法
end

function InnerAPIWrapper.setWeldProcessNumber(iProcessNumber)
    InnerAPIWrapper.initWeldPlugin()
    if not InnerAPIWrapper.hasWelder() then return end --无焊机直接返回
    
    if type(iProcessNumber)=="number" and math.type(iProcessNumber)=="integer" and iProcessNumber>=0 then
        local param = InnerAPIWrapper.welder:getWelderParamObject():getJobModeParam()
        param.processNumber = iProcessNumber
        if not InnerAPIWrapper.welder:getWelderParamObject():setJobModeParam(param) then
            myerror(Language.trLang("SET_PROG_NUMBER_FAIL"))
            return
        end
        if not InnerAPIWrapper.welder:setProcessNumber(iProcessNumber) then
            myerror(Language.trLang("SEND_PROG_NUMBER_FAIL"))
            return
        end
        MqttRobot.publish("/mqtt/weld/getWelderJobModeParam",param)
    end
end

function InnerAPIWrapper.weaveStart()
    InnerAPIWrapper.initWeldPlugin()
    WeaveStart() --调用生态接口，启动摆弧
end
function InnerAPIWrapper.weaveEnd()
    InnerAPIWrapper.initWeldPlugin()
    WeaveEnd() --调用生态接口，停止摆弧
end

function InnerAPIWrapper.setWeldCurrentAndVoltage(current,voltage)
    InnerAPIWrapper.initWeldPlugin()
    if not InnerAPIWrapper.hasWelder() then return end --无焊机直接返回
    
    if "number"==type(current) then
        if not InnerAPIWrapper.welder:setWeldCurrent(current) then
            myerror(Language.trLang("SEND_CURRENT_FAIL"))
            return
        end
    end
    if "number"==type(voltage) then
        if not InnerAPIWrapper.welder:setWeldVoltage(voltage) then
            myerror(Language.trLang("SEND_VOLTAGE_FAIL"))
            return
        end
    end
end

function InnerAPIWrapper.setWireFeed(durationMiliseconds)
    InnerAPIWrapper.initWeldPlugin()
    if not InnerAPIWrapper.hasWelder() then return end --无焊机直接返回
    if "integer"==math.type(durationMiliseconds) and durationMiliseconds>=1 then
        durationMiliseconds = math.floor(durationMiliseconds) --毫秒单位，一定是整数且一定是>=1的
        if durationMiliseconds>=1 then
            InnerAPIWrapper.welder:execWireFeed(durationMiliseconds)
        end
    else
        myerror(Language.trLang("WELDER_TIME_PARAM_FAIL"))
    end
end
function InnerAPIWrapper.setWireBack(durationMiliseconds)
    InnerAPIWrapper.initWeldPlugin()
    if not InnerAPIWrapper.hasWelder() then return end --无焊机直接返回
    if "integer"==math.type(durationMiliseconds) and durationMiliseconds>=1 then
        durationMiliseconds = math.floor(durationMiliseconds) --毫秒单位，一定是整数且一定是>=1的
        if durationMiliseconds>=1 then
            InnerAPIWrapper.welder:execWireBack(durationMiliseconds)
        end
    else
        myerror(Language.trLang("WELDER_TIME_PARAM_FAIL"))
    end
end
function InnerAPIWrapper.setGasCheck(durationMiliseconds)
    InnerAPIWrapper.initWeldPlugin()
    if not InnerAPIWrapper.hasWelder() then return end --无焊机直接返回
    if "integer"==math.type(durationMiliseconds) and durationMiliseconds>=1 then
        durationMiliseconds = math.floor(durationMiliseconds) --毫秒单位，一定是整数且一定是>=1的
        if durationMiliseconds>=1 then
            InnerAPIWrapper.welder:execGasCheck(durationMiliseconds)
        end
    else
        myerror(Language.trLang("WELDER_TIME_PARAM_FAIL"))
    end
end

function InnerAPIWrapper.setWeldAbsSpeed(speed,unit)
    local range = {1,20} --默认为弧焊范围mm/s
    if "Laser"==GlobalParameter.getSelectedWelder() then
        range = {1,200} --激光焊范围mm/s
    end
    local tmpSpeed = speed
    if "mm/min"==unit then
        range[1] = range[1]*60
        range[2] = range[2]*60
        speed = speed/60
    elseif "cm/min"==unit then
        range[1] = range[1]*6
        range[2] = range[2]*6
        speed = speed/6
    else
        unit = "mm/s"
    end
    if tmpSpeed<range[1] or tmpSpeed>range[2] then
        myerror(string.format("%s(%g%s~%g%s): %g",Language.trLang("WELD_SPEED_OUT_RANGE"),range[1],unit,range[2],unit,tmpSpeed))
        return
    end
    WeldArcSpeed(speed)
end

function InnerAPIWrapper.arcStart()
    InnerAPIWrapper.initWeldPlugin()
    WeldArcSpeedStart() --调用生态接口让控制器通知算法“焊接速度WeldArcSpeed(number)”起作用
    
    --调用控制器设置断弧再引弧时回退的距离
    local params = InnerAPIWrapper.globalParams.getSpecialHandleParams().arcAbnormalStop
    if params.isRetry and params.backDistance>0 then
        DobotSetResumeOffset(params.backDistance)
    else
        DobotSetResumeOffset(0)
    end

    if not InnerAPIWrapper.hasWelder() then return end --无焊机直接返回
    
    InnerAPIWrapper.globalParams.setArcStarting(true) --进入到起弧流程
    if not InnerAPIWrapper.welder:arcStart() then
        --起弧失败时，为了能够让脚本继续运行，并且还能继续重试起弧，所以开启子线程，在子线程中进行重试起弧。
        local params = InnerAPIWrapper.globalParams.getSpecialHandleParams().arcRetry
        if not params.isRetry or params.retryCount<1 then --起弧重试未开启或者重试次数少于1
            myerror(Language.trLang("WELDER_START_ARC_FAIL"))
            return
        end
        DobotSetMoveForwardDistance(params.forwardDistance) --设置机器人在当前位置向前移动的距离
        MyWelderDebugLog("============>>Starting arc retry...")
        systhread.create(InnerAPIWrapper.arcStartLoopRetry)
    end
end

--起弧失败时，在这这个线程函数中进行重试
function InnerAPIWrapper.arcStartLoopRetry()
    MyWelderDebugLog("============>>Enter the arc starting retry process...")
    local params = InnerAPIWrapper.globalParams.getSpecialHandleParams().arcRetry
    local wireBackTime = math.floor(params.wireBackTime)
    local tryCount = 0
    repeat
        --通知焊机回抽丝
        if wireBackTime>0 then
            MyWelderDebugLog("============>>execWireBack.....")
            InnerAPIWrapper.welder:execWireBack(wireBackTime)
            MyWelderDebugLog("============>>execWireBack end.....")
        end
        
        --调用控制器接口，通知机器人向前移动，此函数阻塞，直到运动结束
        --累计移动距离都超过了焊缝，此接口内部会暂停脚本，并返回非1
        MyWelderDebugLog("============>>DobotMoveForward,starting.....")
        local retTmp = DobotMoveForward()
        MyWelderDebugLog("============>>DobotMoveForward:retValue="..tostring(retTmp))
        if 1~=retTmp then
            WeldReportScriptStop(Language.trLang("WELDER_ARC_RETRY_LENGTH"))
            return
        end
        
        --如果已经起弧成功了
        if InnerAPIWrapper.globalParams.isWelding() then
            MyWelderDebugLog("============>>it's arc welding and back to arc start position...")
            DobotBackToArcStart() --通知算法回退到起始起弧点
            return
        end
        
        --退出了起弧流程，那么也没必要起弧重试
        if not InnerAPIWrapper.globalParams.isArcStarting() then
            MyWelderDebugLog("============>>no arc retry because of arc end by mannual and back to arc start position....")
            DobotBackToArcStart()
            return
        end
        
        if InnerAPIWrapper.welder:arcStart() then
            MyWelderDebugLog("============>>it's arc success and back to arc start position...")
            DobotBackToArcStart()
            return
        end
        
        tryCount = tryCount+1
        if tryCount>=params.retryCount then
            WeldReportScriptStop(Language.trLang("WELDER_ARC_AGAIN_ERR"))
        end
    until(tryCount>=params.retryCount)
end

function InnerAPIWrapper.arcEnd()
    InnerAPIWrapper.initWeldPlugin()
    WeldArcSpeedEnd() --调用生态接口让控制器通知算法“焊接速度WeldArcSpeed(number)”失去作用
    
    if not InnerAPIWrapper.hasWelder() then return end --无焊机直接返回
    
    InnerAPIWrapper.globalParams.setArcStarting(false) --退出起弧流程
    if not InnerAPIWrapper.welder:arcEnd() then
        myerror(Language.trLang("WELDER_END_ARC_FAIL"))
    end
end

function InnerAPIWrapper.getWeldMultiPassGroup(index)
    InnerAPIWrapper.initWeldPlugin()
    
    local param = InnerAPIWrapper.globalParams.getMultipleWeldGroup()
    if type(param)~="table" then myerror(Language.trLang("SET_MULTI_WELD_PRM_INDEX_NOT_EXIST")) return end
    local dataParam = param[index]
    if type(dataParam)~="table" then myerror(Language.trLang("SET_MULTI_WELD_PRM_INDEX_NOT_EXIST")) return end
    return dataParam
end

function InnerAPIWrapper.selectWeldMultiPassParams(index)
    InnerAPIWrapper.initWeldPlugin()
    
    local dataParam = {}
    local param = InnerAPIWrapper.globalParams.getMultipleWeldParam()
    if type(param)~="table" then myerror(Language.trLang("SET_MULTI_WELD_PRM_INDEX_NOT_EXIST")) return end
    if type(param.params)~="table" then myerror(Language.trLang("SET_MULTI_WELD_PRM_INDEX_NOT_EXIST")) return end
    if index>#param.params then myerror(Language.trLang("SET_MULTI_WELD_PRM_INDEX_NOT_EXIST")) return end
    param.fileId = index
    InnerAPIWrapper.globalParams.setMultipleWeldParam(param)
    MqttRobot.publish("/mqtt/weld/getMultipleWeldParam",newValue)
    dataParam = param.params[index]
    
    --调用控制器接口下发参数
    local prmOpt = {}
    prmOpt.startX=dataParam.startX
    prmOpt.endX=dataParam.endX
    prmOpt.y=dataParam.y
    prmOpt.z=dataParam.z
    prmOpt.workAngle=dataParam.workAngle
    prmOpt.travelAngle=dataParam.travelAngle
    prmOpt.plane=dataParam.plane
    MyWelderDebugLog("MultiPass parameters:",prmOpt)
    DobotWeldMultiPassParams(prmOpt)
    DobotWeldMultiPassStart()
end

function InnerAPIWrapper.setTouchPostionEnable(bEnable)
    InnerAPIWrapper.initWeldPlugin()
    if not InnerAPIWrapper.hasWelder() then return true end --无焊机直接返回
    local ret = InnerAPIWrapper.welder:setTouchPostionEnable(bEnable)
    return ret
end

function InnerAPIWrapper.isTouchPositionSuccess()
    InnerAPIWrapper.initWeldPlugin()
    if not InnerAPIWrapper.hasWelder() then return true end --无焊机直接返回
    local isOk = InnerAPIWrapper.welder:isTouchPositionSuccess()
    if nil==isOk then
        myerror(Language.trLang("TOUCH_POSITION_PARAM_CFG_ERR"))
        return
    end
    return isOk
end

function InnerAPIWrapper.setTouchPositionFailStatus(bStatus)
    InnerAPIWrapper.initWeldPlugin()
    if not InnerAPIWrapper.hasWelder() then return true end --无焊机直接返回
    local ret = InnerAPIWrapper.welder:setTouchPositionFailStatus(bStatus)
    return ret
end

function InnerAPIWrapper.selectWeldLaserParams(index)
    InnerAPIWrapper.initWeldPlugin()
    if not InnerAPIWrapper.hasWelder() then return end --无焊机直接返回
    
    local param = InnerAPIWrapper.welder:getWelderParamObject():getLaserWeldParamHttp()
    if math.type(index)~="integer" then myerror(Language.trLang("SET_LASER_PRM_INDEX_NOT_EXIST")) return end
    if type(param)~="table" then myerror(Language.trLang("SET_LASER_PRM_INDEX_NOT_EXIST")) return end
    if type(param.params)~="table" then myerror(Language.trLang("SET_LASER_PRM_INDEX_NOT_EXIST")) return end
    if index<1 or index>#param.params then myerror(Language.trLang("SET_LASER_PRM_INDEX_NOT_EXIST")) return end
    param.selectedId = index
    if not InnerAPIWrapper.welder:getWelderParamObject():setLaserWeldParam(param) then
        myerror(Language.trLang("LASER_WELD_PARAMS_FAIL"))
    else
        MqttRobot.publish("/mqtt/weld/getWelderLaserWeldParamId",index)
        MqttRobot.publish("/mqtt/weld/getWelderLaserWeldParam",param.params[index])
    end
end

function InnerAPIWrapper.weldLaserStart()
    InnerAPIWrapper.arcStart() --激光焊接的启动就是起弧的过程
end

function InnerAPIWrapper.weldLaserEnd()
    InnerAPIWrapper.arcEnd() --激光焊接的结束就是灭弧的过程
end

-------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------
--定制版的激光标定、寻位、跟踪功能----------------------------------------------------------------------------
--[[
功能：激光自动标定
参数：arrTeachPoint-提前示教的点位信息数组，每个点位结构等同存点列表中点的结构
说明：内部会根据点位自动MovL到对应位置，然后上传数据给激光器
]]--
function InnerAPIWrapper.YLAutoLaserCalibrate(arrTeachPoint, optParams)
    InnerAPIWrapper.initCommonLaserCVPlugin() --定制版和通用版不能同时连接激光器，必须关闭一个。
    InnerAPIWrapper.initLaserCVPlugin(1)
    if not SmartLaserCV.intelligenAutoLaserCalibrate(arrTeachPoint, optParams) then
        myerror(Language.trLang("LASER_AUTO_CALIBRATE_FAIL"))
    end
end

--[[
功能：激光寻位，返回结果值
参数：robotPose-拍照点，结构等同存点列表中点的结构
     iTaskNumber-任务号，不同焊缝类型可能使用不同的寻位任务号
返回值：成功返回{x=1,y=1,z=1,rx=1,ry=1,rz=1}，失败返回nil
]]--
function InnerAPIWrapper.getLaserPositioning(robotPose, iTaskNumber)
    InnerAPIWrapper.initCommonLaserCVPlugin() --定制版和通用版不能同时连接激光器，必须关闭一个。
    InnerAPIWrapper.initLaserCVPlugin(2)
    local pos = SmartLaserCV.getLaserPositioning(robotPose, iTaskNumber)
    if nil==pos then
        myerror(Language.trLang("LASER_POSITION_FAIL"))
    end
    return pos
end

--激光开启、停止跟踪
function InnerAPIWrapper.startLaserTrack(iTaskNumber)
    InnerAPIWrapper.initCommonLaserCVPlugin() --定制版和通用版不能同时连接激光器，必须关闭一个。
    InnerAPIWrapper.initLaserCVPlugin(3)
    if not SmartLaserCV.startTrack(iTaskNumber) then
        myerror(Language.trLang("LASER_TRACK_START_FAIL"))
    else
        InnerAPIWrapper.isLaserTrackStarting = true --激光跟踪已经开始
    end
end
function InnerAPIWrapper.stopLaserTrack()
    if not SmartLaserCV.stopTrack() then
        myerror(Language.trLang("LASER_TRACK_STOP_FAIL"))
    else
        InnerAPIWrapper.isLaserTrackStarting = nil --激光跟踪结束
    end
end
-------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------------------
--通用版的激光标定、寻位、跟踪功能----------------------------------------------------------------------------
--[[
功能：激光自动标定
参数：arrTeachPoint-提前示教的点位信息数组，每个点位结构等同存点列表中点的结构
说明：内部会根据点位自动MovL到对应位置，然后上传数据给激光器
]]--
function InnerAPIWrapper.autoCommonLaserCalibrate(arrTeachPoint,optParams)
    InnerAPIWrapper.initLaserCVPlugin() --定制版和通用版不能同时连接激光器，必须关闭一个。
    InnerAPIWrapper.initCommonLaserCVPlugin(1)
    if not CommonLaserCV.autoLaserCalibrate(arrTeachPoint, optParams) then
        myerror(Language.trLang("LASER_AUTO_CALIBRATE_FAIL"))
    end
end

--[[
功能：激光寻位
参数：robotPose-机器人点位信息,格式与全局变量P相同：
      {
        name = "name",
        pose = {x, y, z, rx, ry, rz},
        joint = {j1, j2, j3, j4, j5, j6},
        tool = index,
        user = index
      }点位信息是指：拍照时，机器人所处的位姿
      iTaskNumber-任务号，不同的寻位阶段使用不同的任务号
返回值：成功返回{x=1,y=1,z=1,rx=1,ry=1,rz=1}，失败返回nil
]]--
function InnerAPIWrapper.getCommonLaserPositioning(robotPose, iTaskNumber)
    InnerAPIWrapper.initLaserCVPlugin() --定制版和通用版不能同时连接激光器，必须关闭一个。
    InnerAPIWrapper.initCommonLaserCVPlugin(2)
    local pos = CommonLaserCV.getLaserPositioning(robotPose, iTaskNumber)
    if nil==pos then
        myerror(Language.trLang("LASER_POSITION_FAIL"))
        return nil
    end
    return pos
end

--通用版激光偏移设置、开启、停止跟踪
function InnerAPIWrapper.setCommonLaserOffset(xOffset, yOffset, zOffset, userIndex)
    CommonLaserCV.setLaserOffset(xOffset, yOffset, zOffset, userIndex)
end
function InnerAPIWrapper.startCommonLaserTrackStart(iTaskNumber, toolIndex)
    InnerAPIWrapper.initLaserCVPlugin() --定制版和通用版不能同时连接激光器，必须关闭一个。
    InnerAPIWrapper.initCommonLaserCVPlugin(3)
    if not CommonLaserCV.startTrack(iTaskNumber, toolIndex) then
        myerror(Language.trLang("LASER_TRACK_START_FAIL"))
    else
        InnerAPIWrapper.isLaserTrackStarting = true --激光跟踪已经开始
    end
end
function InnerAPIWrapper.stopCommonLaserTrackEnd()
    if not CommonLaserCV.stopTrack() then
        myerror(Language.trLang("LASER_TRACK_STOP_FAIL"))
    else
        InnerAPIWrapper.isLaserTrackStarting = nil --激光跟踪结束
    end
end
-------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------

--电弧开启、停止跟踪
function InnerAPIWrapper.startArcTrack(index)
    InnerAPIWrapper.initWeldPlugin()
    
    local dataParam = {}
    local param = InnerAPIWrapper.globalParams.getArcTrackParam()
    if type(param)~="table" then myerror(Language.trLang("SET_ARC_TRACK_PRM_INDEX_NOT_EXIST")) return end
    if type(param.params)~="table" then myerror(Language.trLang("SET_ARC_TRACK_PRM_INDEX_NOT_EXIST")) return end
    if index>#param.params then myerror(Language.trLang("SET_ARC_TRACK_PRM_INDEX_NOT_EXIST")) return end
    param.fileId = index
    InnerAPIWrapper.globalParams.setArcTrackParam(param)
    dataParam = param.params[index]
    
    --调用控制器接口下发参数
    local prmOpt = {}
    prmOpt.trackType = 2 -- 跟踪类型 1:laser 2:arc (1 ~ 2)
    prmOpt.weaveDirectionDO = param.svp0DO
    prmOpt.weavePositionDO = param.svp1DO

    --上下相关参数
    prmOpt.coordinateType = dataParam.upDownCoordinateType
    prmOpt.upDownCompensationSwitch = dataParam.upDownCompensationSwitch
    prmOpt.upDownDatumCurrentSetting = dataParam.upDownDatumCurrentSetting
    prmOpt.upDownDatumCurrent = dataParam.upDownDatumCurrent
    prmOpt.upDownSampleTime = dataParam.upDownSampleTime
    prmOpt.upDownAmplification = dataParam.upDownAmplification
    prmOpt.upDownCompensationOffset = dataParam.upDownCompensationOffset
    prmOpt.upDownPeriodCompensationMin = dataParam.upDownPeriodCompensationMin
    prmOpt.upDownPeriodCompensationMax = dataParam.upDownPeriodCompensationMax
    prmOpt.upDownCompensationMax = dataParam.upDownCompensationMax
    prmOpt.upDownCompensationStartCount = dataParam.upDownCompensationStartCount
    prmOpt.upDownSampleStartCount = dataParam.upDownSampleStartCount
    prmOpt.upDownDatumCurrentSampleCount = dataParam.upDownDatumCurrentSampleCount
    
    --左右相关参数
    prmOpt.leftRightCompensationSwitch = dataParam.leftRightCompensationSwitch
    prmOpt.leftRightAmplification = dataParam.leftRightAmplification
    prmOpt.leftRightCompensationOffset = dataParam.leftRightCompensationOffset
    prmOpt.leftRightPeriodCompensationMin = dataParam.leftRightPeriodCompensationMin
    prmOpt.leftRightPeriodCompensationMax = dataParam.leftRightPeriodCompensationMax
    prmOpt.leftRightCompensationMax = dataParam.leftRightCompensationMax
    prmOpt.leftRightCompensationStartCount = dataParam.leftRightCompensationStartCount

    MyWelderDebugLog("ArcTrackStart parameters:",prmOpt)
    DobotArcTrackParams(prmOpt) --调用控制器接口下发电弧跟踪参数
    DobotArcTrackStart() --调用控制器接口启动电弧跟踪
    SmartArcTrack.setWelder(InnerAPIWrapper.welder)
    SmartArcTrack.setGlobalParams(InnerAPIWrapper.globalParams)
    SmartArcTrack.startTrack()
    InnerAPIWrapper.isArcTrackStarting = true --电弧跟踪开始
end
function InnerAPIWrapper.stopArcTrack()
    SmartArcTrack.stopTrack()
    DobotArcTrackEnd() --调用控制器接口停止电弧跟踪
    InnerAPIWrapper.isArcTrackStarting = nil --电弧跟踪结束
end

--知象光电的几个接口：“内参标定”，“手眼标定”，“单步拍照模式”，“多步融合模式”
function InnerAPIWrapper.chishine3DSetAddress(ip, port)
    return Chishine3DLaser.setAddress(ip, port)
end
function InnerAPIWrapper.chishine3DInternalParamCalibrate(beginPointInfo, continuePointInfoArray, endPointInfo)
    return Chishine3DLaser.internalParamCalibrate(beginPointInfo, continuePointInfoArray, endPointInfo)
end
function InnerAPIWrapper.chishine3DEyeHandleCalibrate(safePoint, beginPointInfo, continuePointInfoArray, touchPointInfoArray, endPointInfo)
    return Chishine3DLaser.eyeHandleCalibrate(safePoint, beginPointInfo, continuePointInfoArray, touchPointInfoArray, endPointInfo)
end
function InnerAPIWrapper.chishine3DSingleStepTakePhoto(takePhotoPoint, visionNumber, cameraDO)
    DO(cameraDO, OFF) --拍摄前先关闭气体，打开相机阀门
    local _isOk,data = pcall(Chishine3DLaser.singleStepTakePhoto,takePhotoPoint, visionNumber)
    DO(cameraDO, ON) --拍摄后打开气体，关闭相机阀门
    if _isOk then return data
    else return nil
    end
end
function InnerAPIWrapper.chishine3DMultiStepTakePhoto(beginPointInfo, continuePointInfoArray, endPointInfo, cameraDO)
    DO(cameraDO, OFF) --拍摄前先关闭气体，打开相机阀门
    local _isOk,data = pcall(Chishine3DLaser.multipleStepTakePhoto,beginPointInfo, continuePointInfoArray, endPointInfo)
    DO(cameraDO, ON) --拍摄后打开气体，关闭相机阀门
    if _isOk then return data
    else return nil
    end
end

--【生态导出接口】-------------------------------------------------------------------------
local Plugin = {
    api = InnerAPIWrapper
}

--[[此函数不公开，也不导出，只供给白名单修改焊机参数处理使用
1. void DobotAddTask(tableParam)，添加一个白名单任务到队列，这个接口由控制器提供，通常是给用户直接使用。
   tableParam为参数，是一个表,格式为：{"key","value"}，例如{"WeldJobNumber","1"}。
2. tableParam DobotTakeTask(isWait)，从队列头中取出一个白名单，如果没有则返回nil
    isWait：0-非阻塞返回，任务队列为空时返回nil，1-阻塞返回，任务队列为空时阻塞
   返回值同`DobotAddTask`入参，这个接口由控制器提供，通常不提供给用使用。
]]--
function Plugin.OnThreadInnerWhiteListDoDobotTask()
    local function pfnExecute()
        local cmd,value
        while true do
            cmd = DobotTakeTask(1) --1表示队列为空时阻塞
            if type(cmd)~="table" then
                Wait(100)
            else
                if "WeldJobNumber"==cmd[1] then
                    value = math.tointeger(cmd[2])
                    if nil~=value then Plugin.WeldJobNumber(value)
                    else print(">>>[weld script DobotTakeTask]:the WeldJobNumber parameter must be integer")
                    end
                elseif "WeldProcessNumber"==cmd[1] then
                    value = math.tointeger(cmd[2])
                    if nil~=value then Plugin.WeldProcessNumber(value)
                    else print(">>>[weld script DobotTakeTask]:the WeldProcessNumber parameter must be integer")
                    end
                elseif "WeldArcCurrent"==cmd[1] then
                    value = tonumber(cmd[2])
                    if nil~=value then Plugin.WeldThroughArc(value,nil)
                    else print(">>>[weld script DobotTakeTask]:the WeldArcCurrent parameter must be number")
                    end
                elseif "WeldArcVoltage"==cmd[1] then
                    value = tonumber(cmd[2])
                    if nil~=value then Plugin.WeldThroughArc(nil,value)
                    else print(">>>[weld script DobotTakeTask]:the WeldArcVoltage parameter must be number")
                    end
                elseif "synchronize"==cmd[1] then
                    Plugin.isSyncFlag = true
                else
                    print(">>>[weld script DobotTakeTask]:\""..tostring(cmd[1]).."\" is unknow cmd,do nothing...")
                end
            end
        end
    end
    --[[在systhread.create创建的线程函数中运行脚本时，无论是因为语法报错还是主动调用lua的error进行报错，都无法停止脚本,
    所以只能通过pcall捕捉错误并使用控制器提供的报错接口，这样才可以停止脚本]]--
    local _isOk,msg = pcall(pfnExecute)
    if not _isOk then --_isOk通常是因为脚本运行报错才会返回false
        WeldReportScriptStop(msg)
    end
end

--[[
功能：同步执行
说明：积木/脚本编程时，存在一种可能如下：
DobotAddTask({"WeldJobNumber","1"})
DobotAddTask({"WeldProcessNumber","1"})
WeldArcStart()
MovL(P1)
WeldArcEnd()
因为前面2行是在子线程中执行，WeldArcStart在主线程执行，这就导致可能先执行了起弧，而job号和程序号都还没来得及下发，
最终的结果就是2个参数设置像是无效一样，所以为了避免这种现象发生，添加一个同步等待器。因为同步等待器也是入队并且通
过设置变量标志来通知主线程继续往下执行，所以整个过程看起来像是顺序执行一样。
目前只有以下的才需要添加同步等待: 
WeldArcStart,WeldArcEnd
]]--
function Plugin.synchronize()
    Plugin.isSyncFlag = nil
    DobotAddTask({"synchronize",""})
    repeat
        Wait(50)
    until(Plugin.isSyncFlag)
end

function Plugin.OnRegist()
    print("-------WeldScript userAPI Plugin.OnRegist-------")
    --ExportFunction("WeldVRMode",Plugin.WeldVRMode) or
    local isErr = ExportFunction("GetWelderPluginObject",Plugin.GetWelderPluginObject) or
                ExportFunction("WeldMethod",Plugin.WeldMethod) or
                ExportFunction("WeldJobNumber",Plugin.WeldJobNumber) or
                ExportFunction("WeldArcParams",Plugin.WeldArcParams) or
                ExportFunction("WeldWeaveParams",Plugin.WeldWeaveParams) or
                ExportFunction("WeldArcStart",Plugin.WeldArcStart) or
                ExportFunction("WeldArcEnd",Plugin.WeldArcEnd) or
                ExportFunction("WeldWeaveStart",Plugin.WeldWeaveStart) or
                ExportFunction("WeldWeaveEnd",Plugin.WeldWeaveEnd) or
                ExportFunction("WeldProcessNumber",Plugin.WeldProcessNumber) or
                ExportFunction("WeldThroughArc",Plugin.WeldThroughArc) or
                ExportFunction("WeldWireFeed",Plugin.WeldWireFeed) or
                ExportFunction("WeldWireBack",Plugin.WeldWireBack) or
                ExportFunction("WeldGasFeed",Plugin.WeldGasFeed) or
                ExportFunction("WeldAbsSpeed",Plugin.WeldAbsSpeed) or
                ExportFunction("GetWeldMultiPassGroup",Plugin.GetWeldMultiPassGroup) or --获取多层多道焊的组合索引
                ExportFunction("WeldMultiPassStart",Plugin.WeldMultiPassStart) or --多层多道焊开始
                ExportFunction("WeldMultiPassEnd",Plugin.WeldMultiPassEnd) or --多层多道焊结束
                ExportFunction("SetTouchPostionEnable",Plugin.SetTouchPostionEnable) or --设置焊丝接触寻位开关使能
                ExportFunction("GetTouchPositionStatus",Plugin.GetTouchPositionStatus) or --获取焊丝接触寻位状态
                ExportFunction("SetTouchPositionFailStatus",Plugin.SetTouchPositionFailStatus) or --设置焊丝接触寻位失败的状态
                ExportFunction("WeldLaserParams",Plugin.WeldLaserParams) or
                ExportFunction("WeldLaserStart",Plugin.WeldLaserStart) or
                ExportFunction("WeldLaserEnd",Plugin.WeldLaserEnd)

    ExportFunction("ArcTrackStart",Plugin.ArcTrackStart) --电弧跟踪开始
    ExportFunction("ArcTrackEnd",Plugin.ArcTrackEnd) --电弧跟踪结束

    --'激光器:标定、寻位、跟踪'
    ExportFunction("YLLaserCalibrate",Plugin.CommonLaserCalibrate) --`YLLaserCalibrate`激光标定
    ExportFunction("FullVLaserCalibrate",Plugin.CommonLaserCalibrate) --激光标定
    ExportFunction("LaserPositioning",Plugin.CommonLaserPositioning) --`LaserPositioning`激光寻位，与通用版的一样。
    ExportFunction("LaserTrackStart",Plugin.LaserTrackStart) --定制版激光跟踪开始
    ExportFunction("LaserTrackEnd",Plugin.LaserTrackEnd) --定制版激光跟踪停止
    ExportFunction("CommonLaserOffset",Plugin.CommonLaserOffset) --通用版激光寻位/跟踪偏移补偿
    ExportFunction("CommonLaserTrackStart",Plugin.CommonLaserTrackStart) --通用版激光跟踪开始
    ExportFunction("CommonLaserTrackEnd",Plugin.CommonLaserTrackEnd) --通用版激光跟踪停止
    
    --'知象光电'
    ExportFunction("Chishine3DSetAddress",Plugin.Chishine3DSetAddress)
    ExportFunction("Chishine3DInternalParamCalibrate",Plugin.Chishine3DInternalParamCalibrate)
    ExportFunction("Chishine3DEyeHandleCalibrate",Plugin.Chishine3DEyeHandleCalibrate)
    ExportFunction("Chishine3DSingleStepTakePhoto",Plugin.Chishine3DSingleStepTakePhoto)
    ExportFunction("Chishine3DMultiStepTakePhoto",Plugin.Chishine3DMultiStepTakePhoto)
    
    if isErr then
        print(" ---ERR to register WeldScript userAPI.... --- ",isErr)
        SetError(0)
    end
    GlobalParameter.setArcStarting(false) --防止脚本直接停止导致参数没复位，所以每次启动脚本提前复位
    --[[在焊接中途，可能需要修改焊机的电流电压等等相关参数，但是因为这些接口都不是白名单，这就导致调用这些函数时，会打断运动的连续性。
    所以为了解决这个问题，需要开启线程，并通过白名单函数`DobotAddTask`来设置焊机相关参数，然后在线程中通过`DobotTakeTask`轮询获取这些
    参数并下发给焊机。]]--
    --执行前先清空任务队列，防止上一次脚本运行还有未执行完的操作，
    --同时线程可能启动慢，导致入队的命令又被清空，所以先清空一次。
    DobotCleanupTask()
    systhread.create(Plugin.OnThreadInnerWhiteListDoDobotTask)
    
    GlobalParameter.recordScriptStartTimestamp() --记录程序启动时的时间戳
end

--调试用的接口，不对外公布
function Plugin.GetWelderPluginObject()
    return Plugin.api
end

--[[
功能：焊机焊接模式设置
参数：strWeldMode-焊机焊接模式
返回值：无
说明：不同焊机，所支持的焊接模式是不一样的（job也是焊接模式的一种）
      具体请结合EnumConstant.ConstEnumWelderWeldMode枚举和welder:getSupportParams()支持列表来看
]]--
function Plugin.WeldMethod(strWeldMode)
    Plugin.api.setWeldMode(strWeldMode)
end

--[[
功能：虚拟/真实焊接设置
参数：iType-焊接类型，0表示真实焊接，1表示虚拟焊接
返回值：无
说明：虚拟焊接，该模式下起弧指令不会给焊机下发起弧标志
]]--
--[[
function Plugin.WeldVRMode(iType)
    local isVR = 1==iType
    Plugin.api.setVirtualWeld(isVR)
end
]]--

--[[
功能：job号id设置
参数：id-job号值，在job模式时这个值才有意义
返回值：无
说明：
]]--
function Plugin.WeldJobNumber(id)
    Plugin.api.SetWeldJobId(id)
end

--[[
功能：起弧参数索引设置
参数：index-参数索引号，1,2,3...
返回值：无
说明：
]]--
function Plugin.WeldArcParams(index)
    Plugin.api.selectWeldArcParams(index)
end

--[[
功能：摆弧参数索引设置
参数：index-参数索引号，1,2,3...
返回值：无
说明：
]]--
function Plugin.WeldWeaveParams(index)
    Plugin.api.selectWeldWeaveParams(index)
end

--[[
功能：起弧
参数：无
返回值：无
说明：
]]--
function Plugin.WeldArcStart()
    Plugin.synchronize()
    Plugin.api.arcStart()
end

--[[
功能：灭弧
参数：无
返回值：无
说明：
]]--
function Plugin.WeldArcEnd()
    Plugin.synchronize()
    Plugin.api.arcEnd()
end

--[[
功能：摆弧启动
参数：无
返回值：无
说明：
]]--
function Plugin.WeldWeaveStart()
    Plugin.api.weaveStart()
end

--[[
功能：摆弧停止
参数：无
返回值：无
说明：
]]--
function Plugin.WeldWeaveEnd()
    Plugin.api.weaveEnd()
end

--[[
功能：程序号设置
参数：iProcessNumber-程序号
返回值：无
说明：脚本运行过程中设置焊机参数中的程序号，只有部分焊机有此功能。
]]--
function Plugin.WeldProcessNumber(iProcessNumber)
    Plugin.api.setWeldProcessNumber(iProcessNumber)
end

--[[
功能：运行过程中设置焊机的电流电压
参数：current-电流值,voltage-电压值
返回值：无
说明：
]]--
function Plugin.WeldThroughArc(current,voltage)
    Plugin.api.setWeldCurrentAndVoltage(current,voltage)
end

--[[
功能：送丝、退丝、送气
参数：durationMiliseconds持续时间,毫秒单位
返回值：无
说明：
]]--
function Plugin.WeldWireFeed(durationMiliseconds)
    Plugin.api.setWireFeed(durationMiliseconds)
end
function Plugin.WeldWireBack(durationMiliseconds)
    Plugin.api.setWireBack(durationMiliseconds)
end
function Plugin.WeldGasFeed(durationMiliseconds)
    Plugin.api.setGasCheck(durationMiliseconds)
end

--[[
功能：为了满足可以修改焊接中的速度，特此增加次函数
参数：speed-焊接速度值,number类型
      unit-速度单位,string类型
返回值：无
说明：此函数就是封装控制器提供的接口`WeldArcSpeed`
      所有单位都转为`mm/s`
]]--
function Plugin.WeldAbsSpeed(speed,unit)
    Plugin.api.setWeldAbsSpeed(speed,unit)
end

--[[
功能：获取多层多道焊的组合索引
参数：index-获取的索引
返回值：多层多道焊参数索引编号的数组，形如：{1,3,4}
]]--
function Plugin.GetWeldMultiPassGroup(index)
    return Plugin.api.getWeldMultiPassGroup(index)
end

--[[
功能：多层多道焊参数设置并开启多层多道焊
参数：index-参数索引号，1,2,3...
返回值：无
说明：
]]--
function Plugin.WeldMultiPassStart(index)
    Plugin.api.selectWeldMultiPassParams(index)
end

--[[
功能：结束多层多道焊
参数：无
返回值：无
说明：
]]--
function Plugin.WeldMultiPassEnd()
    DobotWeldMultiPassEnd() --调用控制器接口结束多层多道焊
end

--[[
功能：设置焊丝接触寻位开关使能
参数：bEnable-true表示使能打开，false表示使能关闭
返回值：无
说明：
]]--
function Plugin.SetTouchPostionEnable(bEnable)
    Plugin.api.setTouchPostionEnable(bEnable)
end

--[[
功能：获取焊丝接触寻位状态
参数：无
返回值：true表示寻位成功，false表示寻位失败
说明：
]]--
function Plugin.GetTouchPositionStatus()
    return Plugin.api.isTouchPositionSuccess()
end

--[[
功能：设置焊丝接触寻位失败的状态
参数：bStatus-true表示ON，false表示OFF
返回值：无
说明：
]]--
function Plugin.SetTouchPositionFailStatus(bStatus)
    Plugin.api.setTouchPositionFailStatus(bStatus)
end
                
--==========================================================
--[[
功能：激光焊参数设置
参数：index-参数索引号，1,2,3...
返回值：无
说明：
]]--
function Plugin.WeldLaserParams(index)
    Plugin.api.selectWeldLaserParams(index)
end

--[[
功能：激光焊启动
参数：无
返回值：无
说明：
]]--
function Plugin.WeldLaserStart()
    Plugin.api.weldLaserStart()
end

--[[
功能：激光焊停止
参数：无
返回值：无
说明：
]]--
function Plugin.WeldLaserEnd()
    Plugin.api.weldLaserEnd()
end

--[[
功能：激光寻位
参数：robotPose-机器人点位信息,格式与全局变量P相同：
      {
        name = "name",
        pose = {x, y, z, rx, ry, rz},
        joint = {j1, j2, j3, j4, j5, j6},
        tool = index,
        user = index
      }点位信息是指：拍照时，机器人所处的位姿
      iTaskNumber-任务号，不同的寻位阶段使用不同的任务号
返回值：偏移值{x,y,z,rx,ry,rz}
说明: 内部调用了运动指令，会先运动到对应点，再开启寻位
]]--
function Plugin.LaserPositioning(robotPose, iTaskNumber)
    local pos = Plugin.api.getLaserPositioning(robotPose, iTaskNumber)
    if nil~=pos then
        return {pos.x,pos.y,pos.z,pos.rx,pos.ry,pos.rz}
    end
    return nil
end

--[[
功能：英莱激光标定
参数：arrTeachPoint-示教点数组(5个点)，每个点数据结构等同存点列表的P相同
     optParams-可选参数{v = 50, a = 50}
返回值：无
]]--
function Plugin.YLLaserCalibrate(arrTeachPoint,optParams)
    Plugin.api.YLAutoLaserCalibrate(arrTeachPoint,optParams)
end

--[[
功能：激光跟踪开始与停止
参数：iTaskNumber-任务号
返回值：无
]]--
function Plugin.LaserTrackStart(iTaskNumber)
    Plugin.api.startLaserTrack(iTaskNumber)
end
function Plugin.LaserTrackEnd()
    Plugin.api.stopLaserTrack()
end

------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------
--同`YLLaserCalibrate`
function Plugin.CommonLaserCalibrate(arrTeachPoint,optParams)
    Plugin.api.autoCommonLaserCalibrate(arrTeachPoint,optParams)
end
--[[
功能：激光寻位
参数：robotPose-机器人点位信息,格式与全局变量P相同：
      {
        name = "name",
        pose = {x, y, z, rx, ry, rz},
        joint = {j1, j2, j3, j4, j5, j6},
        tool = index,
        user = index
      }点位信息是指：拍照时，机器人所处的位姿
      iTaskNumber-任务号，不同的寻位阶段使用不同的任务号
返回值：pose的值{x,y,z,rx,ry,rz}
]]--
function Plugin.CommonLaserPositioning(robotPose, iTaskNumber)
    local pos = Plugin.api.getCommonLaserPositioning(robotPose, iTaskNumber)
    if nil~=pos then
        return {pos.x,pos.y,pos.z,pos.rx,pos.ry,pos.rz}
    end
    return nil
end
--[[
通用版激光寻位/跟踪偏移补偿
    xOffset,yOffset,zOffset为xyz方向的补偿偏移值
    userIndex-为用户坐标系索引
]]--
function Plugin.CommonLaserOffset(xOffset, yOffset, zOffset, userIndex)
    Plugin.api.setCommonLaserOffset(xOffset, yOffset, zOffset, userIndex)
end
--[[
通用版的激光跟踪开始
    iTaskNumber-任务号
    toolIndex-为工具坐标系索引
]]--
function Plugin.CommonLaserTrackStart(iTaskNumber, toolIndex)
    Plugin.api.startCommonLaserTrackStart(iTaskNumber, toolIndex)
end
function Plugin.CommonLaserTrackEnd()
    Plugin.api.stopCommonLaserTrackEnd()
end
------------------------------------------------------------------------------------------------------------------

--[[
功能：电弧跟踪开始与停止
参数：iParamNumber-参数号
返回值：无
]]--
function Plugin.ArcTrackStart(iParamNumber)
    Plugin.api.startArcTrack(iParamNumber)
end
function Plugin.ArcTrackEnd()
    Plugin.api.stopArcTrack()
end

------------------------------------------------------------------------------------------------------------------
--[[
功能：设置知象光电相机的ip和端口
参数：ip和port
返回值：无
]]--
function Plugin.Chishine3DSetAddress(ip, port)
    return Plugin.api.chishine3DSetAddress(ip, port)
end

--[[
功能：知象光电内参标定
参数：beginPointInfo-开始拍照点信息
      continuePointInfoArray-继续拍照点信息数组
      endPointInfo-结束拍照点信息
返回值：true-成功，false-失败
说明：beginPointInfo与endPointInfo数据结构完全相同，continuePointInfoArray的每个元素与beginPointInfo相同。
      beginPointInfo的数据结构如下：{P,ExposureValue}
      其中P为示教点，等同存点列表中点的结构，ExposureValue为相机曝光值。
      {
          {
            name = "name",
            pose = {x, y, z, rx, ry, rz},
            joint = {j1, j2, j3, j4, j5, j6},
            tool = index,
            user = index
          },
          4000
      }
]]--
function Plugin.Chishine3DInternalParamCalibrate(beginPointInfo, continuePointInfoArray, endPointInfo)
    return Plugin.api.chishine3DInternalParamCalibrate(beginPointInfo, continuePointInfoArray, endPointInfo)
end
--[[
功能：知象光电手眼标定
参数：safePoint-安全过渡点，数据结构等同存点列表中点的结构
      beginPointInfo-开始拍照点信息
      continuePointInfoArray-继续拍照点信息数组
      touchPointInfoArray--触碰拍照点信息数组
      endPointInfo-结束拍照点信息
返回值：true-成功，false-失败
说明：几个拍照点的参数数据结构等同上，请参考它
]]--
function Plugin.Chishine3DEyeHandleCalibrate(safePoint, beginPointInfo, continuePointInfoArray, touchPointInfoArray, endPointInfo)
    return Plugin.api.chishine3DEyeHandleCalibrate(safePoint, beginPointInfo, continuePointInfoArray, touchPointInfoArray, endPointInfo)
end
--[[
功能：知象光电单步拍照模式
参数：takePhotoPoint-拍照点，数据结构等同存点列表中点的结构
      {
        name = "name",
        pose = {x, y, z, rx, ry, rz},
        joint = {j1, j2, j3, j4, j5, j6},
        tool = index,
        user = index
      }
      visionNumber-视觉模板号
      cameraDO-3D相机开关阀门DO
返回值：焊缝点位信息数组对象，参考`Chishine3DProtocol.lua的WeldPathData`
]]--
function Plugin.Chishine3DSingleStepTakePhoto(takePhotoPoint, visionNumber, cameraDO)
    return Plugin.api.chishine3DSingleStepTakePhoto(takePhotoPoint, visionNumber, cameraDO)
end
--[[
功能：知象光电多步融合拍照模式
参数：beginPointInfo-开始拍照点信息
      continuePointInfoArray-继续拍照点信息数组
      endPointInfo-结束拍照点信息
      cameraDO-3D相机开关阀门DO
返回值：焊缝点位信息数组对象，参考`Chishine3DProtocol.lua的WeldPathData`。
      `beginPointInfo`与`endPointInfo`数据结构完全相同，`continuePointInfoArray`的每个元素与`beginPointInfo`相同。
      beginPointInfo的数据结构如下：{P,visionNumber,photoType}
      其中photoType=0表示拍照点，photoType=1表示过渡点，这个字段在`continuePointInfoArray`中有意义。
      其中P为示教点，等同存点列表中点的结构，visionNumber为视觉模板编号。
      {
          {
            name = "name",
            pose = {x, y, z, rx, ry, rz},
            joint = {j1, j2, j3, j4, j5, j6},
            tool = index,
            user = index
          },
          1
      }
]]--
function Plugin.Chishine3DMultiStepTakePhoto(beginPointInfo, continuePointInfoArray, endPointInfo, cameraDO)
    return Plugin.api.chishine3DMultiStepTakePhoto(beginPointInfo, continuePointInfoArray, endPointInfo, cameraDO)
end

return Plugin 
