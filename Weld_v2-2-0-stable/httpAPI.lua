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
gDbgLogPrefixContentFlagXXX = "httpAPI"

--http请求的日志是否打印标志
local function innerHttpDebugLog(isLogOn)
    if nil~=DobotSetHttpDebugLog and type(DobotSetHttpDebugLog)=="function" then
        pcall(DobotSetHttpDebugLog,isLogOn) --开启http日志
    end
end
innerHttpDebugLog(false) --默认关闭日志

--------------------------------------------------------------------------------------------------------
package.loaded["WeldScript.WeldScriptLoader"] = nil
require("WeldScript.WeldScriptLoader") --加载焊接脚本
DobotWelderRPC.modbus.initHttpAPI() --提前初始化，不要随便修改该接口调用的位置

--[[
功能：http返回数据
参数：isOk-表示执行结果是否ok，true表示ok，false表示ng，通常脚本报错才会返回false
      data-数据，当isOk=true时，则为返回的数据，为false则为错误信息
      errcode-错误码，当isOk=true时，则为返回的错误码，为false则无意义
返回值：{code=0,errmsg="",data=xxx}      
]]--
local function HttpResponse(isOk,data,errcode)
    local result = {}
    if isOk then
        result.code = errcode
        result.errmsg = ""
        result.data = data
    else
        result.code = ConstEnumApiErrCode.ScriptErr
        result.errmsg = data
        result.data = ""
    end
    return result
end

--[[
当选择为模拟量的时候，因为前端页面没有连接这个动作，导致守护进程不能进入正常的业务逻辑判断，特别是焊接中异常灭弧检测。
为了触发正常流程，所以加个这个函数
]]--
local function connectIfAnalogIOStream(httpPlugin)
    if nil == httpPlugin.welder then return end
    local data = httpPlugin.welder:getWelderParamObject():getIOStreamParam()
    if type(data)~="table" then return end
    if "analogIO"~=data.name then return end
    if httpPlugin.welder:isConnected() then return end
    httpPlugin.welder:connect()
end
--[[
httpAPI.lua脚本会根据文件修改时间来判断是否做了修改从而判断是否需要重新加载文件，但是Plugin.OnInstall()函数只会在安装插件时被调用，
然而，即使没有修改httpAPI.lua文件，第一次调用接口时，这个文件的_G全局变量也会被清掉，
因为嵌入式那边说：Plugin.OnInstall和Plugin.OnUninstall的调用与Plugin.xxx的调用是在不同进程中的。
所以为了让Plugin的变量生效，在调用http接口前需要调用一次初始化。
]]--
local function initWeldPlugin(httpPlugin)
    if nil~=httpPlugin.globalParams and nil~=httpPlugin.welder then
        connectIfAnalogIOStream(httpPlugin)
        return
    end
    if nil == httpPlugin.globalParams then
        httpPlugin.globalParams = GlobalParameter
    end
    if nil == httpPlugin.welder then
        httpPlugin.welder = RobotManager.createDobotWelder(httpPlugin.globalParams.getSelectedWelder())
    end
    local slog = string.format("name=%s,httpPlugin.globalParams=%s,httpPlugin.welder=%s",
        tostring(DobotWelderRPC.modbus.name),type(httpPlugin.globalParams),type(httpPlugin.welder))
    EcoLog(slog)
    connectIfAnalogIOStream(httpPlugin)
end

local function initLaserCVPlugin(httpPlugin)
    if nil==httpPlugin.globalLaserPluginParams then
        httpPlugin.globalLaserPluginParams = LaserPluginParameter
    end
    if nil==httpPlugin.laserPluginCV then
        httpPlugin.laserPluginCV = SmartLaserHttp
    end
end
---------------------------------------------------------------------------------------------------------------

--【生态导出接口】-------------------------------------------------------------------------
local Plugin = {
    globalParams = nil, --全局配置参数
    welder = nil, --当前选中的焊机
    globalLaserPluginParams = nil, --激光器配置参数 LaserPluginParameter
    laserPluginCV = nil, --激光寻位跟踪器
    spotWeldStateInfo = { --点焊状态信息
        running = false, --点焊运行中
        code = ConstEnumApiErrCode.OK --点焊返回状态码
    }
}

function Plugin.OnInstall()
    EcoLog("-------WeldScript httpAPI Plugin.OnInstall-------")
    GlobalParameter.saveWelderRunStateInfo({}) --安装插件时清空可能因为上次保存的焊机状态信息，防止出现连接的假象。
end

function Plugin.OnUninstall()
    --[[卸载插件之前做一次断开连接操作,用于释放焊机状态信息资源]]--
    if nil~=Plugin.welder then
        local function pfnExecute()
            Plugin.welder:disconnect()
        end
        pcall(pfnExecute)
    end
    EcoLog("-------WeldScript httpAPI Plugin.OnUninstall-------")
end

--生态固定接口，当机械臂按钮按下时，触发此函数
function Plugin.OnRegistHotKey()
    return {press={"addCurrentPoint"},longPress={}}
end

function Plugin.addCurrentPoint()
    MqttRobot.triggerAddCurrentPose()
end

---------------------------------------------------------------------------------------------------------------
--***********************************************************************************************************--
---------------------------------------------------------------------------------------------------------------
--调试日志开启与关闭
function Plugin.debugLogOn(isOn)
    isOn = true==isOn
    innerHttpDebugLog(isOn)
    return HttpResponse(true,"OK",ConstEnumApiErrCode.OK)
end

--全局参数获取、设置接口
function Plugin.getSelectedWelder()
    local function pfnExecute()
        initWeldPlugin(Plugin)
        local data = Plugin.globalParams.getSelectedWelder()
        return data,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute))
end
function Plugin.setSelectedWelder(welderName)
    local function pfnExecute(welderName)
        initWeldPlugin(Plugin)
        local tmpName = Plugin.globalParams.getSelectedWelder()
        if tmpName ~= welderName then
            if not Plugin.globalParams.setSelectedWelder(welderName) then
                return false,ConstEnumApiErrCode.Param_Err
            end
            Plugin.welder = RobotManager.createDobotWelder(welderName) --每当切换焊机时就重新创建焊机
        end
        MqttRobot.publish("/mqtt/weld/getSelectedWelder",welderName)
        return true,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute,welderName))
end

function Plugin.getSpecialHandleParams()
    local function pfnExecute()
        initWeldPlugin(Plugin)
        local data = Plugin.globalParams.getSpecialHandleParams()
        return data,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute))
end
function Plugin.setSpecialHandleParams(newValue)
    local function pfnExecute(newValue)
        initWeldPlugin(Plugin)
        local data = Plugin.globalParams.setSpecialHandleParams(newValue)
        return data,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute,newValue))
end

function Plugin.getWeaveParam()
    local function pfnExecute()
        initWeldPlugin(Plugin)
        local data = Plugin.globalParams.getWeaveParam()
        return data,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute))
end
function Plugin.setWeaveParam(newValue)
    local function pfnExecute(newValue)
        initWeldPlugin(Plugin)
        local data = Plugin.globalParams.setWeaveParam(newValue)
        if type(newValue)~="table" then
            return false,ConstEnumApiErrCode.Param_Err
        end
        if math.type(newValue.fileId)~="integer" or type(newValue.params)~="table" then
            return false,ConstEnumApiErrCode.Param_Err
        end
        if newValue.fileId<0 or newValue.fileId>#newValue.params then
            return false,ConstEnumApiErrCode.Param_Err
        end
        MqttRobot.publish("/mqtt/weld/getWeaveParam",newValue.params[newValue.fileId])
        return data,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute,newValue))
end

function Plugin.getMultipleWeldParam()
    local function pfnExecute()
        initWeldPlugin(Plugin)
        local data = Plugin.globalParams.getMultipleWeldParam()
        return data,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute))
end
function Plugin.setMultipleWeldParam(newValue)
    local function pfnExecute(newValue)
        initWeldPlugin(Plugin)
        local data = Plugin.globalParams.setMultipleWeldParam(newValue)
        return data,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute,newValue))
end

function Plugin.getMultipleWeldGroup()
    local function pfnExecute()
        initWeldPlugin(Plugin)
        local data = Plugin.globalParams.getMultipleWeldGroup()
        return data,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute))
end
function Plugin.setMultipleWeldGroup(newValue)
    local function pfnExecute(newValue)
        initWeldPlugin(Plugin)
        local data = Plugin.globalParams.setMultipleWeldGroup(newValue)
        return data,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute,newValue))
end

function Plugin.getArcTrackParam()
    local function pfnExecute()
        initWeldPlugin(Plugin)
        local data = Plugin.globalParams.getArcTrackParam()
        return data,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute))
end
function Plugin.setArcTrackParam(newValue)
    local function pfnExecute(newValue)
        initWeldPlugin(Plugin)
        local data = Plugin.globalParams.setArcTrackParam(newValue)
        return data,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute,newValue))
end

function Plugin.getSpotWeldParam()
    local function pfnExecute()
        initWeldPlugin(Plugin)
        local data = Plugin.globalParams.getSpotWeldParam()
        return data,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute))
end
function Plugin.setSpotWeldParam(newValue)
    local function pfnExecute(newValue)
        initWeldPlugin(Plugin)
        local data = Plugin.globalParams.setSpotWeldParam(newValue)
        MqttRobot.publish("/mqtt/weld/getSpotWeldParam",newValue)
        return data,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute,newValue))
end

function Plugin.getVirtualWeld()
    local function pfnExecute()
        initWeldPlugin(Plugin)
        local data={}
        data["isVirtual"] = Plugin.globalParams.isVirtualWeld()
        data["hasWelder"] = Plugin.globalParams.isHasWelder()
        return data,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute))
end
function Plugin.setVirtualWeld(newValue)
    local function pfnExecute(newValue)
        initWeldPlugin(Plugin)
        local data = Plugin.globalParams.setVirtualWeld(newValue["isVirtual"])
        data = Plugin.globalParams.setHasWelder(newValue["hasWelder"])
        MqttRobot.publish("/mqtt/weld/getVirtualWeld",newValue)
        return data,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute,newValue))
end

function Plugin.getPointsSignalParam()
    local function pfnExecute()
        initWeldPlugin(Plugin)
        local data = Plugin.globalParams.getPointsSignalParam()
        return data,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute))
end
function Plugin.setPointsSignalParam(newValue)
    local function pfnExecute(newValue)
        initWeldPlugin(Plugin)
        local data = Plugin.globalParams.setPointsSignalParam(newValue)
        return data,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute,newValue))
end

function Plugin.getGlobalAnalogIOSignalParam()
    local function pfnExecute()
        initWeldPlugin(Plugin)
        local data = Plugin.globalParams.getAnalogIOSignalParam()
        return data,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute))
end
function Plugin.setGlobalAnalogIOSignalParam(newValue)
    local function pfnExecute(newValue)
        initWeldPlugin(Plugin)
        local data = Plugin.globalParams.setAnalogIOSignalParam(newValue)
        return data,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute,newValue))
end
---------------------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------------------
--焊机连接断开连接
function Plugin.connect()
    local function pfnExecute()
        initWeldPlugin(Plugin)
        local data = Plugin.welder:connect()
        return data,Plugin.welder:getApiErrCode()
    end
    return HttpResponse(pcall(pfnExecute))
end
function Plugin.disconnect()
    local function pfnExecute()
        initWeldPlugin(Plugin)
        Plugin.welder:disconnect()
        return true,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute))
end
function Plugin.getConnected()
    local function pfnExecute()
        initWeldPlugin(Plugin)
        local data = Plugin.welder:isConnected()
        return data,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute))
end

--焊机参数获取、设置接口
function Plugin.getWelderIOStreamParam()
    local function pfnExecute()
        initWeldPlugin(Plugin)
        local data = Plugin.welder:getWelderParamObject():getIOStreamParam()
        return data,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute))
end
function Plugin.setWelderIOStreamParam(newValue)
    local function pfnExecute(newValue)
        initWeldPlugin(Plugin)
        Plugin.welder:disconnect() --切换通信方式时，主动断开连接，防止daemon.lua一直在请求焊机
        if Plugin.welder:getWelderParamObject():setIOStreamParam(newValue) then
            MqttRobot.publish("/mqtt/weld/getWelderIOStreamParam",newValue)
            return true,ConstEnumApiErrCode.OK
        end
        return false,ConstEnumApiErrCode.Param_Err
    end
    return HttpResponse(pcall(pfnExecute,newValue))
end

function Plugin.getWelderAnalogIOSignalParam()
    local function pfnExecute()
        initWeldPlugin(Plugin)
        local data = Plugin.welder:getWelderParamObject():getAnalogIOSignalParam()
        return data,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute))
end
function Plugin.setWelderAnalogIOSignalParam(newValue)
    local function pfnExecute(newValue)
        initWeldPlugin(Plugin)
        local data = Plugin.welder:getWelderParamObject():setAnalogIOSignalParam(newValue)
        return data,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute,newValue))
end

function Plugin.getWelderVAParams()
    local function pfnExecute()
        initWeldPlugin(Plugin)
        local data = Plugin.welder:getWelderParamObject():getVAParams()
        return data,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute))
end
function Plugin.setWelderVAParams(newValue)
    local function pfnExecute(newValue)
        initWeldPlugin(Plugin)
        local data = Plugin.welder:getWelderParamObject():setVAParams(newValue)
        return data,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute,newValue))
end

function Plugin.getWelderVVParams()
    local function pfnExecute()
        initWeldPlugin(Plugin)
        local data = Plugin.welder:getWelderParamObject():getVVParams()
        return data,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute))
end
function Plugin.setWelderVVParams(newValue)
    local function pfnExecute(newValue)
        initWeldPlugin(Plugin)
        local data = Plugin.welder:getWelderParamObject():setVVParams(newValue)
        return data,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute,newValue))
end

function Plugin.getWelderLaserVWParams()
    local function pfnExecute()
        initWeldPlugin(Plugin)
        local data = Plugin.welder:getWelderParamObject():getLaserVWParams()
        return data,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute))
end
function Plugin.setWelderLaserVWParams(newValue)
    local function pfnExecute(newValue)
        initWeldPlugin(Plugin)
        local data = Plugin.welder:getWelderParamObject():setLaserVWParams(newValue)
        return data,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute,newValue))
end

function Plugin.getWelderLaserWeldParam()
    local function pfnExecute()
        initWeldPlugin(Plugin)
        local data = Plugin.welder:getWelderParamObject():getLaserWeldParamHttp()
        return data,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute))
end
function Plugin.setWelderLaserWeldParam(newValue)
    local function pfnExecute(newValue)
        initWeldPlugin(Plugin)
        Plugin.welder:getWelderParamObject():setLaserWeldParam(newValue)
        if nil==newValue or #newValue.params<newValue.selectedId then
            return false,ConstEnumApiErrCode.Param_Err
        end
        if not Plugin.welder:isConnected() then
            return false,ConstEnumApiErrCode.Not_Connected
        end
        local paramSelected = newValue.params[newValue.selectedId]
        if not Plugin.welder:setWeldPower(paramSelected.weldPower) then
            return false,ConstEnumApiErrCode.SetWeldPower_Err
        end
        MqttRobot.publish("/mqtt/weld/getWelderLaserWeldParamId",newValue.selectedId)
        MqttRobot.publish("/mqtt/weld/getWelderLaserWeldParam",paramSelected)
        return true,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute,newValue))
end

function Plugin.getWelderWeldMode()
    local function pfnExecute()
        initWeldPlugin(Plugin)
        local data = Plugin.welder:getWelderParamObject():getWeldMode()
        return data,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute))
end
function Plugin.setWelderWeldMode(newValue)
    local function pfnExecute(newValue)
        initWeldPlugin(Plugin)
        if not Plugin.welder:getWelderParamObject():setWeldMode(newValue) then
            return false,ConstEnumApiErrCode.Param_Err
        end
        if not Plugin.welder:isConnected() then
            return false,ConstEnumApiErrCode.Not_Connected
        end
        if not Plugin.welder:setWeldMode(newValue) then
            return false,ConstEnumApiErrCode.SetWeldMode_Err
        end
        MqttRobot.publish("/mqtt/weld/getWelderWeldMode",newValue)
        return true,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute,newValue))
end

function Plugin.getWelderWorkMode()
    local function pfnExecute()
        initWeldPlugin(Plugin)
        local data = Plugin.welder:getWelderParamObject():getWorkMode()
        return data,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute))
end

function Plugin.setWelderWorkMode(newValue)
    local function pfnExecute(newValue)
        initWeldPlugin(Plugin)
        Plugin.welder:getWelderParamObject():setWorkMode(newValue)
        if not Plugin.welder:setWorkMode(newValue) then
            return false,ConstEnumApiErrCode.SetWeldMode_Err
        end
        MqttRobot.publish("/mqtt/weld/getWelderWorkMode",newValue)
        return true,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute,newValue))
end

function Plugin.getWelderNotJobModeParam()
    local function pfnExecute()
        initWeldPlugin(Plugin)
        local data = Plugin.welder:getWelderParamObject():getNotJobModeParamHttp()
        return data,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute))
end
function Plugin.setWelderNotJobModeParam(newValue)
    local function pfnExecute(newValue)
        initWeldPlugin(Plugin)
        Plugin.welder:getWelderParamObject():setNotJobModeParam(newValue)
        if nil==newValue or #newValue.params<newValue.selectedId then
            return false,ConstEnumApiErrCode.Param_Err
        end
        if not Plugin.welder:isConnected() then
            return false,ConstEnumApiErrCode.Not_Connected
        end
        local paramSelected = newValue.params[newValue.selectedId]
        if type(paramSelected.otc)=="table" then --OTC焊机的特有设置，先设置工艺参数再设置电流电压
            local ok1 = Plugin.welder:setOTCParameter(OTCWelder.keyWeldConfig,paramSelected.otc)
            local ok2 = Plugin.welder:setOTCFunctionView(OTCWelder.keyWeldConfig,paramSelected.otc)
            if not ok1 or not ok2 then
                return false,ConstEnumApiErrCode.SetWeldParam_Err
            end
            --OTC焊机修改了工艺参数后，如果保持寄存器中的电流没有变化，那么焊机显示可能有问题。
            --所以先设置为0是为了让焊机的值有变化,下面再设置实际的值。
            Plugin.welder:setWeldCurrent(0)
        end
        if not Plugin.welder:setWeldCurrent(paramSelected.weldCurrent) then
            return false,ConstEnumApiErrCode.SetWeldCurrent_Err
        end
        if not Plugin.welder:setWeldVoltage(paramSelected.weldVoltage) then
            return false,ConstEnumApiErrCode.SetWeldVoltage_Err
        end
        MqttRobot.publish("/mqtt/weld/getWelderNotJobModeParamId",newValue.selectedId)
        MqttRobot.publish("/mqtt/weld/getWelderNotJobModeParam",paramSelected)
        return true,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute,newValue))
end

function Plugin.getWelderJobModeParam()
    local function pfnExecute()
        initWeldPlugin(Plugin)
        local data = Plugin.welder:getWelderParamObject():getJobModeParamHttp()
        return data,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute))
end
function Plugin.setWelderJobModeParam(newValue)
    local function pfnExecute(newValue)
        initWeldPlugin(Plugin)
        Plugin.welder:getWelderParamObject():setJobModeParam(newValue)
        if not Plugin.welder:isConnected() then
            return false,ConstEnumApiErrCode.Not_Connected
        end
        if not Plugin.welder:setProcessNumber(newValue.processNumber) then
            return false,ConstEnumApiErrCode.SetProcessNum_Err
        end
        if not Plugin.welder:setJobId(newValue.jobId) then
            return false,ConstEnumApiErrCode.SetJob_Err
        end
        MqttRobot.publish("/mqtt/weld/getWelderJobModeParam",newValue)
        return true,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute,newValue))
end

function Plugin.getWelderSupportParams()
    local function pfnExecute()
        initWeldPlugin(Plugin)
        local data = Plugin.welder:getSupportParams()
        return data,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute))
end

function Plugin.setMmiLockUI(newValue)
    local function pfnExecute(newValue)
        initWeldPlugin(Plugin)
        if not Plugin.welder:isConnected() then
            return false,ConstEnumApiErrCode.Not_Connected
        end
        if Plugin.welder:setMmiLockUI(newValue) then
            return true,ConstEnumApiErrCode.OK
        end
        return false,ConstEnumApiErrCode.Comm_Err
    end
    return HttpResponse(pcall(pfnExecute,newValue))
end

--OTC焊机相关操作----------------------------------------------------------------------------------------
function Plugin.getOTCMigWelderCtrlParam()
    local function pfnExecute()
        initWeldPlugin(Plugin)
        local data = Plugin.welder:getWelderParamObject():getOTCMigCtrlParam()
        return data,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute))
end
function Plugin.setOTCMigWelderCtrlParam(newValue)
    local function pfnExecute(newValue)
        initWeldPlugin(Plugin)
        Plugin.welder:getWelderParamObject():setOTCMigCtrlParam(newValue)
        if not Plugin.welder:isConnected() then
            return false,ConstEnumApiErrCode.Not_Connected
        end
        local ok1 = Plugin.welder:setOTCParameter(OTCWelder.keyMigGasCtrlConfig,newValue)
        local ok2 = Plugin.welder:setOTCFunctionView(OTCWelder.keyMigGasCtrlConfig,newValue)
        if not ok1 or not ok2 then
            return false,ConstEnumApiErrCode.SetWeldParam_Err
        end
        
        return true,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute,newValue))
end

function Plugin.getOTCTigWelderCtrlParam()
    local function pfnExecute()
        initWeldPlugin(Plugin)
        local data = Plugin.welder:getWelderParamObject():getOTCTigCtrlParam()
        return data,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute))
end
function Plugin.setOTCTigWelderCtrlParam(newValue)
    local function pfnExecute(newValue)
        initWeldPlugin(Plugin)
        Plugin.welder:getWelderParamObject():setOTCTigCtrlParam(newValue)
        if not Plugin.welder:isConnected() then
            return false,ConstEnumApiErrCode.Not_Connected
        end
        local ok1 = Plugin.welder:setOTCParameter(OTCWelder.keyTigCtrlConfig,newValue)
        local ok2 = Plugin.welder:setOTCFunctionView(OTCWelder.keyTigCtrlConfig,newValue)
        if not ok1 or not ok2 then
            return false,ConstEnumApiErrCode.SetWeldParam_Err
        end
        return true,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute,newValue))
end

function Plugin.getOTCTigWelderF45Param()
    local function pfnExecute()
        initWeldPlugin(Plugin)
        local data = Plugin.welder:getWelderParamObject():getOTCTigF45Param()
        return data,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute))
end
function Plugin.setOTCTigWelderF45Param(newValue)
    local function pfnExecute(newValue)
        initWeldPlugin(Plugin)
        Plugin.welder:getWelderParamObject():setOTCTigF45Param(newValue)
        if not Plugin.welder:isConnected() then
            return false,ConstEnumApiErrCode.Not_Connected
        end
        if not Plugin.welder:setOTCFunctionView(OTCWelder.keyTigF45Config,newValue) then
            return false,ConstEnumApiErrCode.SetWeldParam_Err
        end
        return true,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute,newValue))
end
---------------------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------------------
--焊机的操作（http中通常都是手动操作焊机）
function Plugin.setWireFeedSpeed(newValue)
    local function pfnExecute(newValue)
        initWeldPlugin(Plugin)
        if not Plugin.welder:isConnected() then
            return false,ConstEnumApiErrCode.Not_Connected
        end
        if Plugin.welder:setWeldWireFeedSpeed(newValue) then
            return true,ConstEnumApiErrCode.OK
        end
        return false,ConstEnumApiErrCode.Comm_Err
    end
    return HttpResponse(pcall(pfnExecute,newValue))
end

function Plugin.setWireFeed(isOn)
    local function pfnExecute(newValue)
        initWeldPlugin(Plugin)
        if not Plugin.welder:isConnected() then
            return false,ConstEnumApiErrCode.Not_Connected
        end
        if Plugin.welder:setWireFeed(newValue) then
            return true,ConstEnumApiErrCode.OK
        end
        return false,ConstEnumApiErrCode.Comm_Err
    end
    return HttpResponse(pcall(pfnExecute,isOn))
end

function Plugin.setWireBack(isOn)
    local function pfnExecute(newValue)
        initWeldPlugin(Plugin)
        if not Plugin.welder:isConnected() then
            return false,ConstEnumApiErrCode.Not_Connected
        end
        if Plugin.welder:setWireBack(newValue) then
            return true,ConstEnumApiErrCode.OK
        end
        return false,ConstEnumApiErrCode.Comm_Err
    end
    return HttpResponse(pcall(pfnExecute,isOn))
end

function Plugin.setGasCheck(isOn)
    local function pfnExecute(newValue)
        initWeldPlugin(Plugin)
        if not Plugin.welder:isConnected() then
            return false,ConstEnumApiErrCode.Not_Connected
        end
        if Plugin.welder:setGasCheck(newValue) then
            return true,ConstEnumApiErrCode.OK
        end
        return false,ConstEnumApiErrCode.Comm_Err
    end
    return HttpResponse(pcall(pfnExecute,isOn))
end

--[[点焊时由于可能出现点焊检测很长时间（比如OTC焊机可以设置预送气）或者是点焊时间长，这样的情况下导致
焊接执行时间很长，http请求发生严重阻塞，最终导致部分http请求失败，所以把点焊放到子线程中处理。
然后通过轮询状态方式来判断点焊是否执行成功。
]]--
local function innerExecSpotWeld(plugin,newValue)
    local function pfnExecute(plugin,newValue)
        if plugin.welder:doSpotWeld(newValue) then
            return true,ConstEnumApiErrCode.OK
        end
        return false,plugin.welder:getApiErrCode()
    end
    local isOk,state,code = pcall(pfnExecute,plugin,newValue)
    plugin.spotWeldStateInfo.running = false
    if isOk then
        plugin.spotWeldStateInfo.code = code
    else
        plugin.spotWeldStateInfo.code = ConstEnumApiErrCode.ScriptErr
    end
end
function Plugin.doSpotWeld()
    local function pfnExecute()
        initWeldPlugin(Plugin)
        if not Plugin.welder:isConnected() then
            return false,ConstEnumApiErrCode.Not_Connected
        end
        local newValue = Plugin.globalParams.getSpotWeldParam()
        if type(newValue)~="table" then
            return false,ConstEnumApiErrCode.Param_Err
        end
        systhread.create(innerExecSpotWeld, Plugin, newValue) --启动线程执行点焊操作
        Plugin.spotWeldStateInfo.running = true
        return true,ConstEnumApiErrCode.OK
    end
    if true~=Plugin.spotWeldStateInfo.running then --点焊不在运行中则启动点焊
        Plugin.spotWeldStateInfo.code = ConstEnumApiErrCode.OK --复位一次code
        return HttpResponse(pcall(pfnExecute))
    else
        return HttpResponse(true,true,ConstEnumApiErrCode.OK)
    end
end
function Plugin.getSpotWeldState()
    return HttpResponse(true,Plugin.spotWeldStateInfo,ConstEnumApiErrCode.OK)
end

function Plugin.getWelderStateInfo()
    local function pfnExecute()
        initWeldPlugin(Plugin)
        if not Plugin.welder:isConnected() then
            return {},ConstEnumApiErrCode.OK
        end
        local data = Plugin.globalParams.getWelderRunStateInfo()
        return data,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute))
end

function Plugin.getWeldCostTimeInfo()
    local function pfnExecute()
        initWeldPlugin(Plugin)
        local data = Plugin.globalParams.getWeldCostTimeInfo()
        return data,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute))
end

function Plugin.clearWeldCostTimeInfo()
    local function pfnExecute()
        initWeldPlugin(Plugin)
        local data = Plugin.globalParams.clearWeldCostTimeInfo()
        return data,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute))
end
---------------------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------------------
--激光寻位器相关接口
function Plugin.getSelectedLaserCV()
    local function pfnExecute()
        initLaserCVPlugin(Plugin)
        local data = Plugin.globalLaserPluginParams.getSelectedLaser()
        return data,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute))
end
function Plugin.setSelectedLaserCV(newValue)
    local function pfnExecute(newValue)
        initLaserCVPlugin(Plugin)
        local data = Plugin.globalLaserPluginParams.setSelectedLaser(newValue)
        return data,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute,newValue))
end

function Plugin.getLaserCVIOStreamParam()
    local function pfnExecute()
        initLaserCVPlugin(Plugin)
        local data = Plugin.globalLaserPluginParams.getLaserAddrParam()
        return data,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute))
end
function Plugin.setLaserCVIOStreamParam(newValue)
    local function pfnExecute(newValue)
        initLaserCVPlugin(Plugin)
        local data = Plugin.globalLaserPluginParams.setLaserAddrParam(newValue)
        return data,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute,newValue))
end

function Plugin.openLaserCV()
    local function pfnExecute()
        if not Plugin.laserPluginCV.connect() then
            return false,ConstEnumApiErrCode.ConnectLaser_Err
        end
        if not Plugin.laserPluginCV.openLaser() then
            Plugin.laserPluginCV.disconnect()
            return false,ConstEnumApiErrCode.OpenLaser_Err
        end
        Plugin.laserPluginCV.disconnect()
        return true,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute))
end
function Plugin.closeLaserCV()
    local function pfnExecute()
        if not Plugin.laserPluginCV.connect() then
            return false,ConstEnumApiErrCode.ConnectLaser_Err
        end
        if not Plugin.laserPluginCV.closeLaser() then
            Plugin.laserPluginCV.disconnect()
            return false,ConstEnumApiErrCode.CloseLaser_Err
        end
        Plugin.laserPluginCV.disconnect()
        return true,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute))
end
--[[ --废弃不要了
function Plugin.getConnectedLaserCV()
    local function pfnExecute()
        return true,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute))
end
]]--
function Plugin.setLanguage(strLang)
    local function pfnExecute(newValue)
        Language.setLang(newValue)
        return true,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute,strLang))
end

--[[
功能：获取/设置按钮盒子的开关状态
参数：isOn-true表示开，false表示关
返回值：
说明：临时用用，功能完成后再规范
]]--
function Plugin.getButtonBoxOnOff()
    local function pfnExecute()
        if nil == Plugin.globalParams then
            Plugin.globalParams = GlobalParameter
        end
        local data = Plugin.globalParams.getButtonBoxOnOff()
        return data,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute))
end
function Plugin.setButtonBoxOnOff(isOn)
    local function pfnExecute(newValue)
        if nil == Plugin.globalParams then
            Plugin.globalParams = GlobalParameter
        end
        Plugin.globalParams.setButtonBoxOnOff(isOn)
        if isOn then
            isOn = DobotWelderRPC.api.StartHandeldControllerServer(true)
            Wait(1000) --减少RPC的阻塞，等待真正完成操作
            if true==isOn then
                return true,ConstEnumApiErrCode.OK
            else
                return false,ConstEnumApiErrCode.Comm_Err
            end
        else
            DobotWelderRPC.api.StartHandeldControllerServer(false)
            Wait(4000) --减少RPC的阻塞，等待真正完成操作
        end
        return true,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute,isOn))
end


--判断工程是否存在
function Plugin.isProjectExist(strProjectName)
    local function pfnExecute(newValue)
        local scriptFile = string.format("/dobot/userdata/user_project/project/%s/src0.lua",newValue)
        local file,errmsg = io.open (scriptFile,"r")
        if nil==file then
            MyWelderDebugLog("open read file fail:"..tostring(errmsg))
            return false,ConstEnumApiErrCode.OK
        end
        file:close()
        return true,ConstEnumApiErrCode.OK
    end
    return HttpResponse(pcall(pfnExecute,strProjectName))
end

---------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------
--[[
功能：获取当前插件所配置的所有IO情况
参数：无
返回值：形如{"in":{},"out":{},"toolIn":{},"toolOut":{}}
说明：特殊接口，与焊机本身没有关联，但是又是要读取某个焊机配置的IO信号(如果存在的话)
]]--
function Plugin.GetPluginIOCtrl()
    local function pfnExecute(newValue)
        if nil == Plugin.globalParams then
            Plugin.globalParams = GlobalParameter
        end
        
        local boxIn = {}
        local boxOut = {}
        local toolIn = {}
        local toolOut = {}
        
        --全局IO模拟信号-----------------------------------------
        local data = Plugin.globalParams.getAnalogIOSignalParam() or {}
        --寻位相关的
        data.touchPositionParam = data.touchPositionParam or {}
        boxOut.enableDO = data.touchPositionParam.enableDO
        boxIn.successDI = data.touchPositionParam.successDI
        boxOut.failDO = data.touchPositionParam.failDO
        --碰撞相关的
        data.collisionDetectionParam = data.collisionDetectionParam or {}
        if 1==data.collisionDetectionParam.detectType then
            boxIn.collisionDetection = data.collisionDetectionParam.signalDI
        elseif 2==data.collisionDetectionParam.detectType then
            toolIn.collisionDetection = data.collisionDetectionParam.signalDI
        end
        --示教存点相关的
        data.teachPointParam = data.teachPointParam or {}
        if 1==data.teachPointParam.detectType then
            boxIn.teachPoint = data.teachPointParam.signalDI
        elseif 2==data.teachPointParam.detectType then
            toolIn.teachPoint = data.teachPointParam.signalDI
        end
        --拖拽检测相关的
        data.dragDetectionParam = data.dragDetectionParam or {}
        if 1==data.dragDetectionParam.detectType then
            boxIn.dragDetection = data.dragDetectionParam.signalDI
        elseif 2==data.dragDetectionParam.detectType then
            toolIn.dragDetection = data.dragDetectionParam.signalDI
        end
        
        --点位信号配置---------------------------------------------
        data = Plugin.globalParams.getPointsSignalParam() or {}
        --接近点DI信号位
        data.approachDI = data.approachDI or {}
        if 1==data.approachDI.detectType then
            boxIn.approachDI = data.approachDI.signalDI
        elseif 2==data.approachDI.detectType then
            toolIn.approachDI = data.approachDI.signalDI
        end
        --起弧点DI信号位
        data.arcStartDI = data.arcStartDI or {}
        if 1==data.arcStartDI.detectType then
            boxIn.arcStartDI = data.arcStartDI.signalDI
        elseif 2==data.arcStartDI.detectType then
            toolIn.arcStartDI = data.arcStartDI.signalDI
        end
        --灭弧点DI信号位
        data.arcEndDI = data.arcEndDI or {}
        if 1==data.arcEndDI.detectType then
            boxIn.arcEndDI = data.arcEndDI.signalDI
        elseif 2==data.arcEndDI.detectType then
            toolIn.arcEndDI = data.arcEndDI.signalDI
        end
        --中间圆弧点DI信号位
        data.middleArcDI = data.middleArcDI or {}
        if 1==data.middleArcDI.detectType then
            boxIn.middleArcDI = data.middleArcDI.signalDI
        elseif 2==data.middleArcDI.detectType then
            toolIn.middleArcDI = data.middleArcDI.signalDI
        end
        --中间直线点DI信号位
        data.middleLineDI = data.middleLineDI or {}
        if 1==data.middleLineDI.detectType then
            boxIn.middleLineDI = data.middleLineDI.signalDI
        elseif 2==data.middleLineDI.detectType then
            toolIn.middleLineDI = data.middleLineDI.signalDI
        end
        --离开DI信号位
        data.leaveDI = data.leaveDI or {}
        if 1==data.leaveDI.detectType then
            boxIn.leaveDI = data.leaveDI.signalDI
        elseif 2==data.leaveDI.detectType then
            toolIn.leaveDI = data.leaveDI.signalDI
        end
        
        --跟焊机有关的模拟IO-------------------------------------------------------------------
        if nil ~= Plugin.welder then
            data = Plugin.welder:getWelderParamObject():getIOStreamParam() or {}
            if "analogIO"==data.name then --只有选择模拟量通信时的才需要
                data = Plugin.welder:getWelderParamObject():getAnalogIOSignalParam() or {}
                data = data.controlBoxSignalParam or {}
                boxOut.arcStart = data.arcStart
                boxOut.wireFeed = data.wireFeed
                boxOut.wireBack = data.wireBack
                boxOut.gasCheck = data.gasCheck
                boxIn.arcStartCheck = data.arcStartCheck
            end
        end
        
        if "Cloos" == Plugin.globalParams.getSelectedWelder() then
            --Cloos焊机当前只有模拟量的,所以选择了Cloos焊机基本就是肯定有这些固定DO
            --DO的编号参考`CloosWelderControlDAnalogIO:setJobId()`的设置
            boxOut.cloosWelder1=1
            boxOut.cloosWelder2=2
            boxOut.cloosWelder3=3
            boxOut.cloosWelder4=4
            boxOut.cloosWelder5=5
            boxOut.cloosWelder6=6
            boxOut.cloosWelder7=7
            boxOut.cloosWelder8=8
        end
        
        local retData = {}
        retData["in"]=boxIn
        retData["out"]=boxOut
        retData["toolIn"]=toolIn
        retData["toolOut"]=toolOut
        return retData
    end
    local _isOk,result = pcall(pfnExecute)
    if type(result)=="table" then 
        return result
    else
        return {}
    end
end

---------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------
--[[
【提供给积木编程特有的接口】
]]--
--[[
功能：在积木中返回当前焊机支持的焊接模式
参数：无
返回值：形如{{"a":"b"},{"c":"d"},...{"m":"n"}}
]]--
function Plugin.getWeldModeMapper()
    initWeldPlugin(Plugin)
    local data = Plugin.welder:getSupportParams()
    if nil==data then return {} end
    if nil==data.weldMode then return {} end
    local arr = {}
    for i=1,#data.weldMode do
        table.insert(arr,{Language.tr(data.weldMode[i]),data.weldMode[i]})
    end
    return arr
end

--积木获取target1~50列表，固定写死
function Plugin.getLaserTargetList()
    local arr = {}
    for i= 1,50 do
        table.insert(arr,{"target"..i, "laser_target"..i})
    end
    return arr
end

--根据strKey获取数据
function Plugin.getBasePointDataByKey(strKey)
    if type(strKey)~="string" then return nil end
    return GetVal(strKey)
end

return Plugin