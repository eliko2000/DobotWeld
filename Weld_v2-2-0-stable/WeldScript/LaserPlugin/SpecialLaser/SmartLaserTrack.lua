--[[
激光跟踪功能封装
说明：因为各大厂家激光器跟踪功能还不了解，所以暂时不要封装那么深，简单粗暴就可以。
]]--

--【本地私有接口】
--循环执行激光跟踪
local function innerStartLoopTrack(self)
    --**从算法读取的数据**-----------------------
    local predictTime = 40 --算法规划时间，毫秒单位
    local predictData --是否下发成功,获取规划点位信息
    local currentPoint --当前点,{x,y,z,rx,ry,rz}
    local predictPoint --规划点,{x,y,z,rx,ry,rz}
    local speed --机器人速度
    local heartBeat --算法心跳
    
    --**激光器的数据**-----------------------
    local robotPose = {x=0,y=0,z=0,rx=0,ry=0,rz=0} --设置机器人点给激光器
    local nextPredictPose = {x=0,y=0,z=0,rx=0,ry=0,rz=0} --设置下一个规划点给激光器
    local robotTagPose = {x=0,y=0,z=0,rx=0,ry=0,rz=0} --获取激光器返回的机器人目标值
    local offsetPredictPose = {x=0,y=0,z=0,rx=0,ry=0,rz=0} --获取激光器返回的偏移值
    
    --*算法需要的数据*-----------------------
    local trackOffsetData = {} --将激光器返回的数据回传给算法
    
    local beginTime,remainTime = 0,0
    while self.trackThdRunFlag do
        beginTime = Systime()
        predictData = GetPredictPoint(predictTime) --调用算法接口获取规划点位信息
        if type(predictData)~="table" then
            --获取算法的数据出问题了，则再获取一次
            Wait(5)
        else
            currentPoint = predictData["currentPoint"]
            predictPoint = predictData["predictPoint"]
            speed = predictData["speed"]
            heartBeat = predictData["heartBeat"]
            if type(currentPoint)~="table" then
                MyWelderDebugLog(Language.trLang("LASER_ALG_NO_DATA"))
            end
            if type(predictPoint)~="table" then
                MyWelderDebugLog(Language.trLang("LASER_ALG_NO_PRIDECT"))
            end
            
            robotPose.x = currentPoint[1]
            robotPose.y = currentPoint[2]
            robotPose.z = currentPoint[3]
            robotPose.rx = currentPoint[4]
            robotPose.ry = currentPoint[5]
            robotPose.rz = currentPoint[6]
            self.selLaserObj.setRobotPose(robotPose) --设置机器人点给激光器
            
            nextPredictPose.x = predictPoint[1]
            nextPredictPose.y = predictPoint[2]
            nextPredictPose.z = predictPoint[3]
            nextPredictPose.rx = predictPoint[4]
            nextPredictPose.ry = predictPoint[5]
            nextPredictPose.rz = predictPoint[6]
            self.selLaserObj.setNextPredictPose(nextPredictPose) --设置下一个规划点给激光器
            
            --启动跟踪，获取目标机器人坐标和偏差值
            if not self.selLaserObj.startTrack(robotTagPose,offsetPredictPose) then
                --在子线程中，error不起作用，所以调用系统接口，让脚本停下来
                local strErrLog = Language.trLang("LASER_TRACK_ERR")
                MyWelderDebugLog(strErrLog)
                WeldReportScriptStop(strErrLog)
                break
            else
                --对返回的结果值`robotTagPose,offsetPredictPose`进行处理
                trackOffsetData["predictPoint"] = predictPoint
                trackOffsetData["targetPoint"] = {robotTagPose.x,robotTagPose.y,robotTagPose.z,
                                                  robotTagPose.rx,robotTagPose.ry,robotTagPose.rz}
                trackOffsetData["trackOffset"] = {offsetPredictPose.x,offsetPredictPose.y,offsetPredictPose.z,
                                                  offsetPredictPose.rx,offsetPredictPose.ry,offsetPredictPose.rz}
                trackOffsetData["heartBeat"] = heartBeat
                SetLaserTrackOffset(trackOffsetData) --调用算法接口将激光传感器返回的偏移值下发给算法
                
                --等待一段时间进行下一次获取激光器数据并计算
                remainTime = predictTime-(Systime()-beginTime)
                if remainTime>0 then --激光器推荐40ms发一次，如果整个通信超过了40ms就没必要Wait
                    Wait(remainTime)
                end
            end
        end
    end
end
local function innerExecLoopTrack(self)
    local function innerpfnExec(self)
        MyWelderDebugLog(Language.trLang("LASER_TRACK_RUNNING"))
        self.trackThdRunFlag = true
        innerStartLoopTrack(self)
        self.trackThdRunFlag = false
        
        MyWelderDebugLog(Language.trLang("LASER_TRACK_READY_END"))
        self.selLaserObj.stopTrack() --结束跟踪
        self.selLaserObj.closeLaser() --关闭激光器
        MyWelderDebugLog(Language.trLang("LASER_TRACK_HAS_END"))
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
local SmartLaserTrack = {
    selLaserObj = nil, --当前选中的激光器
    trackThdRunFlag = false, --跟踪线程运行标志
    trackThreadObject = nil --跟踪线程对象
}

---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
--[[
功能：选择激光器
参数：name-激光器名称，只能是`EnumConstant.ConstEnumLaserPluginName`的值
返回值：无
]]--
function SmartLaserTrack.selectLaser(name)
    local self = SmartLaserTrack
    if "Intelligen"==name then
        self.selLaserObj = SMTIntelligenLaserTrack
        return true
    else
        MyWelderDebugLog(Language.trLang("LASER_NOADAPTER_TRACKING")..":"..tostring(name))
        return false
    end
end

--[[
功能：连接激光器
参数：ip-地址,
      port-端口
返回值：true表示成功，false表示失败
]]--
function SmartLaserTrack.connect(ip,port)
    local self = SmartLaserTrack
    return self.selLaserObj.connect(ip,port)
end

--[[
功能：断开是否已连接
参数：无
返回值：true-已连接，false-未连接
]]--
function SmartLaserTrack.isConnected()
    local self = SmartLaserTrack
    return self.selLaserObj.isConnected()
end

--[[
功能：断开激光器的连接
参数：无
返回值：无
]]--
function SmartLaserTrack.disconnect()
    local self = SmartLaserTrack
    self.stopTrack()
    self.selLaserObj.disconnect()
end

--[[
功能：设置待切换的焊缝类型编号
参数：iNumber-编号，范围1-30
返回值：true表示成功，false表示失败
]]--
function SmartLaserTrack.setTaskNumber(iTaskNumber)
    local self = SmartLaserTrack
    return self.selLaserObj.setTaskNumber(iTaskNumber)
end

--[[
功能：启动跟踪功能
参数：无
返回值：true表示成功，false表示失败
]]--
function SmartLaserTrack.startTrack()
    local self = SmartLaserTrack
    if self.trackThdRunFlag then
        WeldReportScriptStop(Language.trLang("LASER_TRACKING_NOT_AGAIN"))
        return true
    end
    MyWelderDebugLog(Language.trLang("LASER_TRACK_READY_START"))
    if not self.selLaserObj.openLaser() then
        return false
    end
    if not self.selLaserObj.changeGapType() then
        self.selLaserObj.closeLaser()
        return false
    end
    if not self.selLaserObj.initTrack() then
        self.selLaserObj.closeLaser()
        return false
    end
    DobotLaserTrackStart() --调用算法接口开启激光跟踪功能,运动指令不能放到子线程中,这是生态决定的
    --启动线程,执行跟踪功能
    self.trackThreadObject = systhread.create(innerExecLoopTrack, self)
    if not self.trackThreadObject then
        MyWelderDebugLog(Language.trLang("LASER_TRACK_THD_START_FAIL"))
        self.selLaserObj.closeLaser()
        return false
    end
    MyWelderDebugLog(Language.trLang("LASER_TRACK_START_OK"))
    return true
end

function SmartLaserTrack.stopTrack()
    local self = SmartLaserTrack
    self.trackThdRunFlag = false
    if self.trackThreadObject then
        MyWelderDebugLog(Language.trLang("LASER_TRACK_READY_END"))
        self.trackThreadObject:wait()
        self.trackThreadObject = nil
        DobotLaserTrackEnd() --调用算法接口关闭激光跟踪功能,运动指令不能放到子线程中,这是生态决定的
        MyWelderDebugLog(Language.trLang("LASER_TRACK_HAS_END"))
    end
    return true
end

return SmartLaserTrack