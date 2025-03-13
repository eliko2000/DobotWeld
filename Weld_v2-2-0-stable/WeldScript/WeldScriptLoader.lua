--[[
lua脚本加载器配置文件。
该文件存在的主要目的是集中加载焊接所有需要的所有lua脚本。相当于c/c++中的include大集合
外部引用焊接的其他lua接口时，只需要将本文件require进去即可。
]]--

--[[
作用：保存焊接脚本自己所在的目录，配合`ReloadWelderScriptLuaEnvironmentPath`接口使用
说明：当此lua文件被生态框架加载完毕后，package.path会被还原，这样当需要动require lua文件时，会报错“找不到XXX文件”，
      所以在动态require lua文件前，先把此变量加载到环境变量中
]]--
gWelderScriptLuaEnvironmentPath = ""
do
    local currentDir = debug.getinfo(1,"S").source
    currentDir = string.sub(currentDir,2) --filter out '@'
    currentDir = string.reverse(currentDir)
    local pos = string.find(currentDir,"/",1,true)
    if nil==pos then pos = string.find(currentDir,"\\",1,true) end
    currentDir = string.sub(currentDir,pos)
    currentDir = string.reverse(currentDir).."?.lua"
    gWelderScriptLuaEnvironmentPath = currentDir
    pos = string.find(package.path, currentDir, 1, true)
    if nil==pos then
        package.path = currentDir .. ";" .. package.path
    end
end

--重新加载路径到环境变量中
function ReloadWelderScriptLuaEnvironmentPath()
    local pos = string.find(package.path, gWelderScriptLuaEnvironmentPath, 1, true)
    if nil==pos then
        package.path = gWelderScriptLuaEnvironmentPath .. ";" .. package.path
    end
end

--模拟信号DI、DO时，这个变量在deamon中没有，所以自定义
if nil==ON then ON=1 end
if nil==OFF then OFF=0 end

local function luaValue2StringValue(value)
    local printCache = {}
    local function inner_print(t,spaceCount)
        local tName = type(t)
        if "table"==tName then
            local key = tostring(t)
            if printCache[key] then
                return "*:" .. key
            else
                printCache[key] = true
                local spaceChar = string.rep(' ',spaceCount+2)
                local strBuffer = key .. "{\r\n"
                for k,v in pairs(t) do
                    strBuffer = strBuffer .. spaceChar .. k .. "=" .. inner_print(v,spaceCount+2) .. "\r\n"
                end
                strBuffer = strBuffer .. string.rep(' ',spaceCount) .. "}"
                return strBuffer
            end
        elseif "string"==tName then
            return t
        else
            return tostring(t)
        end
    end
    return inner_print(value,0)
end

--[[
全局函数，日志功能打印封装，满足自己的日志格式需求
]]--
function MyWelderDebugLog(...)
    local strPrefixLog = debug.traceback()
    local tabInfo = {}
    local cnt = 1
    local aimPos = 3
    for i=1,aimPos do
        local pos1,pos2 = string.find(strPrefixLog,'\n',1,true)
        if pos1 and pos1 == pos2 then
            tabInfo[cnt] = string.sub(strPrefixLog,1,pos1 - 1)
            strPrefixLog = string.sub(strPrefixLog,pos2 + 1)
            if cnt > aimPos then break end
            cnt = cnt + 1
        end
    end
    strPrefixLog = tabInfo[aimPos]
    if nil~=strPrefixLog then
        local strTmp = string.reverse(strPrefixLog)
        local pos = string.find(strTmp,"/",1,true)
        if nil==pos then pos = string.find(strTmp,"\\",1,true) end
        if nil~=pos then
            strTmp = string.sub(strTmp,1,pos-1)
            strPrefixLog = string.reverse(strTmp)
        end
    else
        strPrefixLog = "nil"
    end

    local strLogMsg = ""
    local paramsList = {...}
    if #paramsList>0 then
        for i=1,#paramsList-1 do
            strLogMsg = strLogMsg .. luaValue2StringValue(paramsList[i]) .. "\r\n"
        end
        strLogMsg = strLogMsg .. luaValue2StringValue(paramsList[#paramsList])
    end
    
    local printLogMsg = "["..strPrefixLog.."]WelderLog19:"..tostring(gDbgLogPrefixContentFlagXXX).."-->"..strLogMsg
    if "daemon"==gDbgLogPrefixContentFlagXXX then
        EcoLog(printLogMsg)
    elseif "httpAPI"==gDbgLogPrefixContentFlagXXX then
        EcoLog(printLogMsg)
    elseif "userAPI"==gDbgLogPrefixContentFlagXXX then
        print(printLogMsg)
    end
end

--[[
功能：抛错误并报警让脚本停下来
参数：strMsg-要抱出去的内容
返回值：无
说明：在systhread.create创建的线程函数中，通过lua的error方式是不能让脚本报错停止下来的，因此需要此函数。
      同时为了能够在daemon.lua进程中通知用户脚本停止运行并抛出错误信息，也需要此函数。
]]--
function WeldReportScriptStop(strMsg)
    print("ReportScriptError Stop:"..tostring(strMsg)) --把这个消息直接抛到打印窗口显示，这样能确认错误原因
    if type(Log)=="function" then pcall(Log,strMsg) end --将错误信息打印到Pro的“日志记录”窗口中
    local isOk,msg = pcall(ReportEcoStop, strMsg) --这个会告知控制器抛出错误信息并会让脚本停止运行
    if not isOk then
        if "daemon"==gDbgLogPrefixContentFlagXXX then
            EcoLog(msg)
        elseif "httpAPI"==gDbgLogPrefixContentFlagXXX then
            EcoLog(msg)
        elseif "userAPI"==gDbgLogPrefixContentFlagXXX then
            print(msg)
        end
    end
end
--此函数功能与`WeldReportScriptStop`类似，只不过是暂停脚本。
function WeldReportScriptPause(strMsg)
    print("ReportScriptError Pause:"..tostring(strMsg)) --把这个消息直接抛到打印窗口显示，这样能确认错误原因
    if type(Log)=="function" then pcall(Log,strMsg) end --将错误信息打印到Pro的“日志记录”窗口中
    local isOk,msg = pcall(ReportEcoError, strMsg) --这个会告知控制器抛出错误信息并会让脚本暂停运行
    if not isOk then
        if "daemon"==gDbgLogPrefixContentFlagXXX then
            EcoLog(msg)
        elseif "httpAPI"==gDbgLogPrefixContentFlagXXX then
            EcoLog(msg)
        elseif "userAPI"==gDbgLogPrefixContentFlagXXX then
            print(msg)
        end
    end
end

function WelderScriptStartHook()
    if "userAPI"==gDbgLogPrefixContentFlagXXX then
        require("debug").sethook(dobotTool.dobot_hook,"crl") 
    end
end
function WelderScriptStopHook()
    if "userAPI"==gDbgLogPrefixContentFlagXXX then
        require("debug").sethook()
    end
end
function WelderIsUserApiScript()
    return "userAPI"==gDbgLogPrefixContentFlagXXX
end
function WelderIsHttpApiScript()
    return "httpAPI"==gDbgLogPrefixContentFlagXXX
end
function WelderIsDaemonScript()
    return "daemon"==gDbgLogPrefixContentFlagXXX
end

----------------------------------------------------------------------------------------------------------
--清除缓存，重新加载各种模块
--[[加载焊接脚本，如果新增文件，可以配置在这里。
注意事项：通常越是不依赖其他lua脚本的文件，越是要放在这里，并且越靠前require
]]--
package.loaded["lang.LangWeldMode"] = nil
LangWeldMode = require("lang.LangWeldMode")

package.loaded["lang.Language"] = nil
require("lang.Language")

package.loaded["rpc.ThreadSafeModbus"] = nil
require("rpc.ThreadSafeModbus")

package.loaded["rpc.EtherNetIPScanner"] = nil
require("rpc.EtherNetIPScanner")

package.loaded["rpc.DobotWelderRPC"] = nil
require("rpc.DobotWelderRPC")

package.loaded["EnumConstant"] = nil
require("EnumConstant")

package.loaded["CHelperTools"] = nil
CHelperTools = require("CHelperTools")

package.loaded["MqttRobot"] = nil
MqttRobot = require("MqttRobot")

package.loaded["GlobalParameter"] = nil
GlobalParameter = require("GlobalParameter")

package.loaded["WelderParameter"] = nil
WelderParameter = require("WelderParameter")

package.loaded["IDobotIOStream"] = nil
IDobotIOStream = require("IDobotIOStream")

package.loaded["IDobotWelder"] = nil
IDobotWelder = require("IDobotWelder")

package.loaded["RobotManager"] = nil
RobotManager = require("RobotManager")

----------------------------------------------------------------------------------------------------------
--各种通信类
package.loaded["IOStream.DobotAnalog"] = nil
DobotAnalog = require("IOStream.DobotAnalog")

package.loaded["IOStream.DobotDeviceNet"] = nil
DobotDeviceNet = require("IOStream.DobotDeviceNet")

package.loaded["IOStream.DobotModbusTcpClient"] = nil
DobotModbusTcpClient = require("IOStream.DobotModbusTcpClient")

package.loaded["IOStream.DobotEtherNetIP"] = nil
DobotEtherNetIP = require("IOStream.DobotEtherNetIP")

----------------------------------------------------------------------------------------------------------
--焊接机接口实现以及通信接口实现
package.loaded["Welder.ImplementWelder"] = nil
ImplementWelder = require("Welder.ImplementWelder")

package.loaded["Welder.WelderControlObject"] = nil
WelderControlObject = require("Welder.WelderControlObject")

package.loaded["Welder.WelderControlModbus"] = nil
WelderControlModbus = require("Welder.WelderControlModbus")

package.loaded["Welder.WelderControlDeviceNet"] = nil
WelderControlDeviceNet = require("Welder.WelderControlDeviceNet")

package.loaded["Welder.WelderControlDAnalogIO"] = nil
WelderControlDAnalogIO = require("Welder.WelderControlDAnalogIO")

package.loaded["Welder.WelderControlEIP"] = nil
WelderControlEIP = require("Welder.WelderControlEIP")

----------------------------------------------------------------------------------------------------------
--各种焊接机
--奥太焊机
package.loaded["Welder.WeldScriptLoaderAotai"] = nil
require("Welder.WeldScriptLoaderAotai")

--EWM焊机
package.loaded["Welder.WeldScriptLoaderEWM"] = nil
require("Welder.WeldScriptLoaderEWM")

--福尼斯Fronius焊机
package.loaded["Welder.WeldScriptLoaderFronius"] = nil
require("Welder.WeldScriptLoaderFronius")

--林肯焊机
package.loaded["Welder.WeldScriptLoaderLincoln"] = nil
require("Welder.WeldScriptLoaderLincoln")

--和宗焊机
package.loaded["Welder.WeldScriptLoaderFlama"] = nil
require("Welder.WeldScriptLoaderFlama")

--麦格米特焊机
package.loaded["Welder.WeldScriptLoaderMegmeet"] = nil
require("Welder.WeldScriptLoaderMegmeet")

--松下焊机
package.loaded["Welder.WeldScriptLoaderPanasonic"] = nil
require("Welder.WeldScriptLoaderPanasonic")

--GYS焊机
package.loaded["Welder.WeldScriptLoaderGYS"] = nil
require("Welder.WeldScriptLoaderGYS")

--SKS焊机
package.loaded["Welder.WeldScriptLoaderSKS"] = nil
require("Welder.WeldScriptLoaderSKS")

--Kemppi焊机
package.loaded["Welder.WeldScriptLoaderKemppi"] = nil
require("Welder.WeldScriptLoaderKemppi")

--Lorch焊机
package.loaded["Welder.WeldScriptLoaderLorch"] = nil
require("Welder.WeldScriptLoaderLorch")

--OTC焊机
package.loaded["Welder.WeldScriptLoaderOTC"] = nil
require("Welder.WeldScriptLoaderOTC")

--Cloos焊机
package.loaded["Welder.WeldScriptLoaderCloos"] = nil
require("Welder.WeldScriptLoaderCloos")

--ESAB焊机
package.loaded["Welder.WeldScriptLoaderESAB"] = nil
require("Welder.WeldScriptLoaderESAB")

--Miller焊机
package.loaded["Welder.WeldScriptLoaderMiller"] = nil
require("Welder.WeldScriptLoaderMiller")

--Kolarc焊机
package.loaded["Welder.WeldScriptLoaderKolarc"] = nil
require("Welder.WeldScriptLoaderKolarc")

--激光焊机
package.loaded["Welder.WeldScriptLoaderLaser"] = nil
require("Welder.WeldScriptLoaderLaser")

--虚拟Virtual焊机
package.loaded["Welder.WeldScriptLoaderVirtual"] = nil
require("Welder.WeldScriptLoaderVirtual")

--其他焊机
package.loaded["Welder.WeldScriptLoaderOther"] = nil
require("Welder.WeldScriptLoaderOther")

----------------------------------------------------------------------------------------------------------
--各种激光器
package.loaded["LaserPluginParameter"] = nil
LaserPluginParameter = require("LaserPluginParameter")

package.loaded["LaserPlugin.LaserCVScriptLoader"] = nil
require("LaserPlugin.LaserCVScriptLoader")

----------------------------------------------------------------------------------------------------------
--各种手持式的控制器
package.loaded["HandheldController.HandheldControllerScriptLoader"] = nil
require("HandheldController.HandheldControllerScriptLoader")
