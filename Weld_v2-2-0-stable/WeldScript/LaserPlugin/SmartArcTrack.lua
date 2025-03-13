--[[
电弧跟踪功能封装
]]--

--【本地私有接口】
local function GetDigitalOutputs(signalSVP0,signalSVP1)
    --[[
    local tv={}
    local _isOk,info = GetRealTimeFeedback()
    if not _isOk then return tv end
    if type(info)~="table" then return tv end
    local v = info["DigitalOutputs"]
    if math.type(v)~="integer" then return tv end
    tv[1] = (v>>(signalSVP0-1))&0x01
    tv[2] = (v>>(signalSVP1-1))&0x01
    return tv
    ]]--
    return GetDOGroup(signalSVP0,signalSVP1)
end

--循环执行电弧跟踪,点采样
local function innerStartLoopTrackDot(self)
    local arcTrackParam = self.globalParams.getArcTrackParam()
    
    local signalSVP0 = arcTrackParam.svp0DO --SVP0的DO信号索引
    local signalSVP1 = arcTrackParam.svp1DO --SVP1的DO信号索引
    local preSVP0 = OFF --SVP0的上一次状态
    local preSVP1 = OFF --SVP1的上一次状态
    local curSVP = nil --svp0\1当前状态
    local current = nil --电流值
    
    local bIsVirtual = self.globalParams.isVirtualWeld()
    
    local iStep = 0
    local welder = self.welder.welderControlObject
    while self.trackThdRunFlag do
        curSVP = GetDigitalOutputs(signalSVP0,signalSVP1)
        --[[
        svp0高电平,svp1上升沿,此时是点1
        svp0下降沿,svp1高电平,此时是点2
        svp0低电平,svp1下降沿,此时是点1
        svp0上升沿,svp1低电平,此时是点3
        ]]--
        --边沿触发,电平信号发生跳变时获取一次电流
        if preSVP0 ~= curSVP[1] and preSVP1 ~= curSVP[2] then
            preSVP0 = curSVP[1]
            preSVP1 = curSVP[2]
            if bIsVirtual then current = 0
            else current = welder:getWeldCurrent()
            end
            if ON == preSVP0 then
                iStep = 4 --EcoLog("====================>st-svp0 rise pt3:"..tostring(current))
            else
                iStep = 2 --EcoLog("====================>st-svp0 desc pt2:"..tostring(current))
            end
            if ON == preSVP1 then
                iStep = 1 --EcoLog("====================>st-svp1 rise pt1:"..tostring(current))
            else
                iStep = 3 --EcoLog("====================>st-svp1 desc pt1:"..tostring(current))
            end
        elseif preSVP0 ~= curSVP[1] then
            preSVP0 = curSVP[1]
            if bIsVirtual then current = 0
            else current = welder:getWeldCurrent()
            end
            if ON == preSVP0 then
                iStep = 4 --EcoLog("====================>svp0 rise pt3:"..tostring(current))
            else
                iStep = 2 --EcoLog("====================>svp0 desc pt2:"..tostring(current))
            end
        elseif preSVP1 ~= curSVP[2] then
            preSVP1 = curSVP[2]
            if bIsVirtual then current = 0
            else current = welder:getWeldCurrent()
            end
            if ON == preSVP1 then
                iStep = 1 --EcoLog("====================>svp1 rise pt1:"..tostring(current))
            else
                iStep = 3 --EcoLog("====================>svp1 desc pt1:"..tostring(current))
            end
        else
            Wait(10)
        end
        if iStep~=0 and nil~=current then
            DobotSetSampleCurrent(current, iStep) --调用控制器接口将参数下发给算法
            iStep = 0
            current = nil
        end
    end
end

--循环执行电弧跟踪,线采样
local function innerStartLoopTrackLine(self)
    local arcTrackParam = self.globalParams.getArcTrackParam()
    local selectParam = arcTrackParam.params[arcTrackParam.fileId]
    
    local signalSVP0 = selectParam.svp0DO --SVP0的DO信号索引
    local signalSVP1 = selectParam.svp1DO --SVP1的DO信号索引
    local preSVP0 = OFF --SVP0的上一次状态
    local preSVP1 = OFF --SVP1的上一次状态
    local curSVP = nil --svp0\1当前状态
    local current = nil --电流值
    
    local bIsVirtual = self.globalParams.isVirtualWeld()
    
    local lineName = ""
    local iStep = 0
    local welder = self.welder.welderControlObject
    while self.trackThdRunFlag do
        curSVP = GetDigitalOutputs(signalSVP0,signalSVP1)
        --[[
        svp0高电平,svp1上升沿,此时是t1
        svp0下降沿,svp1高电平,此时是t2
        svp0低电平,svp1下降沿,此时是t3
        svp0上升沿,svp1低电平,此时是t4
        ]]--
        --边沿触发,电平信号发生跳变时修改一次线段名称
        if preSVP0 ~= curSVP[1] and preSVP1 ~= curSVP[2] then
            --EcoLog("====================>SVP0&1 Change")
            preSVP0 = curSVP[1]
            preSVP1 = curSVP[2]
            if ON == preSVP0 then
                iStep = 4 --lineName = "====================>T4:"
            else
                
                iStep = 2 --lineName = "====================>T2:"
            end
            if ON == preSVP1 then
                
                iStep = 1 --lineName = "====================>T1:"
            else
                
                iStep = 3 --lineName = "====================>T3:"
            end
        elseif preSVP0 ~= curSVP[1] then
            --EcoLog("====================>SVP0 Change")
            preSVP0 = curSVP[1]
            if ON == preSVP0 then
                iStep = 4 --lineName = "====================>T4:"
            else
                iStep = 2 --lineName = "====================>T2:"
            end
        elseif preSVP1 ~= curSVP[2] then
            --EcoLog("====================>SVP1 Change")
            preSVP1 = curSVP[2]
            if ON == preSVP1 then
                iStep = 1 --lineName = "====================>T1:"
            else
                iStep = 3 --lineName = "====================>T3:"
            end
        else
            Wait(10)
        end
        if iStep~=0 then
            if bIsVirtual then current = 0
            else current = welder:getWeldCurrent()
            end
            if nil~=current then
                DobotSetSampleCurrent(current, iStep) --调用控制器接口将参数下发给算法
            end
            --EcoLog(lineName..tostring(current))
        end
    end
end

local function innerExecLoopTrack(self)
    local function innerpfnExec(self)
        MyWelderDebugLog(Language.trLang("ARC_TRACK_RUNNING"))
        self.trackThdRunFlag = true
        innerStartLoopTrackDot(self)
        self.trackThdRunFlag = false
        MyWelderDebugLog(Language.trLang("ARC_TRACK_HAS_END"))
    end
    local _ok,msg = pcall(innerpfnExec,self)
    if not _ok then
        MyWelderDebugLog(msg)
        WeldReportScriptStop(msg)
    end
end

---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
--【导出接口】
local SmartArcTrack = {
    welder = nil, --当前的焊机对象
    globalParams = nil, --global全局参数
    trackThdRunFlag = false, --跟踪线程运行标志
    trackThreadObject = nil --跟踪线程对象
}

---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
--设置当前焊机
function SmartArcTrack.setWelder(welder)
    SmartArcTrack.welder = welder
end

--设置全局global参数
function SmartArcTrack.setGlobalParams(param)
    SmartArcTrack.globalParams = param
end

--[[
功能：启动跟踪功能
参数：无
返回值：true表示成功，false表示失败
]]--
function SmartArcTrack.startTrack()
    local self = SmartArcTrack
    if nil==self.welder or nil==self.globalParams then
        return false
    end
    if self.trackThdRunFlag then
        WeldReportScriptStop(Language.trLang("ARC_TRACKING_NOT_AGAIN"))
        return true
    end
    MyWelderDebugLog(Language.trLang("ARC_TRACK_READY_START"))
    --启动线程,执行跟踪功能
    self.trackThreadObject = systhread.create(innerExecLoopTrack, self)
    if not self.trackThreadObject then
        MyWelderDebugLog(Language.trLang("ARC_TRACK_THD_START_FAIL"))
        return false
    end
    MyWelderDebugLog(Language.trLang("ARC_TRACK_START_OK"))
    return true
end

function SmartArcTrack.stopTrack()
    local self = SmartArcTrack
    self.trackThdRunFlag = false
    if self.trackThreadObject then
        MyWelderDebugLog(Language.trLang("ARC_TRACK_READY_END"))
        self.trackThreadObject:wait()
        self.trackThreadObject = nil
        MyWelderDebugLog(Language.trLang("ARC_TRACK_HAS_END"))
    end
    return true
end

return SmartArcTrack