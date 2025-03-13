--[[
激光器，将标定、寻位、跟踪这3大功能放到这里
]]--

--【本地私有接口】
local function innerInitLaserCV(self)
    if nil==self.globalLaserCfg then
        self.globalLaserCfg = LaserPluginParameter
    end
end

local function innerResetFunc(self,iType)
    if iType==self.funcType then return end
    self.funcType=iType
    if nil~=self.laser then
        self.disconnect()
    end
end

local function offset_in_0(corrdinate_para, offset)
  -- 输入参数：
  -- corrdinate_para：1 X 6 或 6 X 1 数组，  代表用户坐标系的参数：X Y Z Rx Ry Rz，单位为mm  和 °
  -- offset：      1 X 3 或 3 X 1 数组，  代表偏移量，单位为mm
  -- 输出参数：
  -- offset_value_in_0：1 X 3 数组，  代表在0坐标系下的偏移量，单位为mm
  local x = corrdinate_para[1];
  local y = corrdinate_para[2];
  local z = corrdinate_para[3];
  local A = math.rad(corrdinate_para[4]);
  local B = math.rad(corrdinate_para[5]);
  local C = math.rad(corrdinate_para[6]);

  local x_offset = offset[1];
  local y_offset = offset[2];
  local z_offset = offset[3];
  
  local x_obj = z_offset*math.sin(B) + x_offset*math.cos(B)*math.cos(C) - y_offset*math.cos(B)*math.sin(C);
  local y_obj = x_offset*(math.cos(A)*math.sin(C) + math.cos(C)*math.sin(A)*math.sin(B)) + y_offset*(math.cos(A)*math.cos(C) - math.sin(A)*math.sin(B)*math.sin(C)) - z_offset*math.cos(B)*math.sin(A);
  local z_obj = x_offset*(math.sin(A)*math.sin(C) - math.cos(A)*math.cos(C)*math.sin(B)) + y_offset*(math.cos(C)*math.sin(A) + math.cos(A)*math.sin(B)*math.sin(C)) + z_offset*math.cos(A)*math.cos(B);
  
  local offset_value_in_0 = {x_obj, y_obj, z_obj};
  return offset_value_in_0;
end
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
--循环执行激光跟踪
local function innerStartLoopTrack(self)
    local corrdinate_para = GetUser(self.userIndex) --调用控制器接口获取这个用户坐标系的参数
    local offset = offset_in_0(corrdinate_para, {self.xOffset,self.yOffset,self.zOffset})
    local offsetX,offsetY,offsetZ = offset[1],offset[2],offset[3]
    
    local pose,pt
    local begin,endtime
    while self.trackThdRunFlag do
        begin = Systime()
        pose = GetPose(0, self.toolIndex)
        pose.user = 0
        pose.tool = self.toolIndex
        pt = self.laser.getRobotPoseTrack(pose)
        if nil~= pt then
            if pt.x==0 and pt.y==0 and pt.z==0 then --这个值就是激光器还没进入焊缝跟踪得到的结果，则不做补偿处理，默认给0
                pt.rx = 0
                pt.ry = 0
                pt.rz = 0
            else
                pt.x = pt.x + offsetX
                pt.y = pt.y + offsetY
                pt.z = pt.z + offsetZ
            end
            SetLaserTrackPoint({pt.x,pt.y,pt.z,pt.rx,pt.ry,pt.rz})
        else
            local strErrLog = Language.trLang("LASER_TRACK_ERR")
            MyWelderDebugLog(strErrLog)
            WeldReportScriptStop(strErrLog)
            break
        end
        endtime = Systime()
        if endtime-begin<40 then
            Wait(40-(endtime-begin))
        end
    end
end

local function innerExecLoopTrack(self)
    local function innerpfnExec(self)
        while not self.waitingForStartTrack do
            Wait(5)
        end
        MyWelderDebugLog(Language.trLang("LASER_TRACK_RUNNING"))
        self.trackThdRunFlag = true
        innerStartLoopTrack(self)
        self.trackThdRunFlag = false
        
        MyWelderDebugLog(Language.trLang("LASER_TRACK_READY_END"))
        self.laser.stopTrack() --结束跟踪
        self.laser.closeLaser() --关闭激光器
        MyWelderDebugLog(Language.trLang("LASER_TRACK_HAS_END"))
    end
    local _ok,msg = pcall(innerpfnExec,self)
    if not _ok then
        MyWelderDebugLog(msg)
        WeldReportScriptStop(msg)
    end
end

-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
--【对外公开接口】-------------------------------------------------------------------------------------------------
local CommonLaserCV = {
    laser = nil, --激光器
    funcType = 0, --功能类型
    globalLaserCfg = nil, --激光器配置参数`LaserPluginParameter`
    waitingForStartTrack = false, --等待开始启动跟踪
    trackThdRunFlag = false, --跟踪线程运行标志
    trackThreadObject = nil, --跟踪线程对象
    xOffset = 0, --激光寻位/跟踪的x偏移补偿
    yOffset = 0, --激光寻位/跟踪的y偏移补偿
    zOffset = 0, --激光寻位/跟踪的z偏移补偿
    userIndex = 0, --激光寻位/跟踪偏移计算的用户坐标系
    toolIndex = 0 --焊缝跟踪的工具坐标系
}

--[[
功能：选择功能
参数：iType-功能类型，1-标定功能，2-寻位功能，3-跟踪功能
返回值：true-成功，false-失败            
]]--
function CommonLaserCV.selectFunction(iType)
    local self = CommonLaserCV
    innerInitLaserCV(self)
    innerResetFunc(self,iType) --如果切换了功能，则需要先主动断开释放
    
    local name = self.globalLaserCfg.getSelectedLaser() --当前选中的激光器
    self.laser = RobotManager.createCommonLaser(name)
    if not self.laser then
        if 1==iType then MyWelderDebugLog(Language.trLang("LASER_NOADAPTER_CALIBRATE")..":"..tostring(name))
        elseif 2==iType then MyWelderDebugLog(Language.trLang("LASER_NOADAPTER_POSITION")..":"..tostring(name))
        elseif 3==iType then MyWelderDebugLog(Language.trLang("LASER_NOADAPTER_TRACKING")..":"..tostring(name))
        else MyWelderDebugLog(Language.trLang("LASER_FUNC_SEL_OUT_RANGE"))
        end
        return false
    end
    return true
end

--[[
功能：连接、断开激光器
参数：ip-地址,port-端口
返回值：true表示成功，false表示失败
]]--
function CommonLaserCV.connect(ip,port)
    local self = CommonLaserCV
    innerInitLaserCV(self)
    local params = self.globalLaserCfg.getLaserAddrParam()
    if nil==ip then ip=params.ip end
    if nil==port then port=params.port end
    
    if self.laser.connect(ip,port) then
        MyWelderDebugLog(Language.trLang("LASER_CONNECT_OK"))
        return true
    else
        MyWelderDebugLog(Language.trLang("LASER_CONNECT_FAIL"))
        return false
    end
end
function CommonLaserCV.isConnected()
    local self = CommonLaserCV
    innerInitLaserCV(self)
    return self.laser.isConnected()
end
function CommonLaserCV.disconnect()
    local self = CommonLaserCV
    innerInitLaserCV(self)
    if self.laser then
        self.laser.disconnect()
    end
end

--[[
功能：打开、关闭激光
参数：无
返回值：true表示成功，false表示失败
]]--
function CommonLaserCV.openLaser()
    local self = CommonLaserCV
    innerInitLaserCV(self)
    return self.laser.openLaser()
end
function CommonLaserCV.closeLaser()
    local self = CommonLaserCV
    innerInitLaserCV(self)
    return self.laser.closeLaser()
end

---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
--[[
功能：激光自动标定
参数：参数请参考-`ICommonLaser.autoLaserCalibrate`
返回值：true-成功，false-失败
]]--
function CommonLaserCV.autoLaserCalibrate(arrTeachPoint, optParams)
    local self = CommonLaserCV
    innerInitLaserCV(self)
    if not self.laser.openLaser() then
        MyWelderDebugLog(Language.trLang("LASER_AUTO_CALIBRATE_FAIL"))
        return false
    end
    local ret = self.laser.autoLaserCalibrate(arrTeachPoint, optParams)
    if not ret then MyWelderDebugLog(Language.trLang("LASER_AUTO_CALIBRATE_FAIL")) end
    self.laser.closeLaser()
    return ret
end

-----------------------------------------------------------------------------------
--通用版激光偏移设置
function CommonLaserCV.setLaserOffset(xOffset, yOffset, zOffset, userIndex)
    local self = CommonLaserCV
    innerInitLaserCV(self)
    self.xOffset = xOffset or 0
    self.yOffset = yOffset or 0
    self.zOffset = zOffset or 0
    self.userIndex = userIndex
end

---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
--[[
功能：激光寻位获取结果值
参数：参数请参考-`ICommonLaser.getRobotPosePosition/setTaskNumber`
返回值：成功返回{x=1,y=1,z=1,rx=1,ry=1,rz=1}，失败返回nil
]]--
function CommonLaserCV.getLaserPositioning(robotPose, iTaskNumber)
    local self = CommonLaserCV
    innerInitLaserCV(self)
    
    if not self.laser.openLaser() then
        MyWelderDebugLog(Language.trLang("LASER_POSITION_FAIL"))
        return false
    end
    if not self.laser.setTaskNumber(iTaskNumber) then
        MyWelderDebugLog(Language.trLang("LASER_POSITION_FAIL"))
        self.laser.closeLaser()
        return false
    end
    Wait(200) --打开后需要延迟一段时间，否则大概率拿不到数据
    local retVal = self.laser.getRobotPosePosition(robotPose)
    if nil==retVal then MyWelderDebugLog(Language.trLang("LASER_POSITION_FAIL")) end
    self.laser.closeLaser()
    Wait(50)
    if retVal~=nil then
        retVal.x = retVal.x+self.xOffset
        retVal.y = retVal.y+self.yOffset
        retVal.z = retVal.z+self.zOffset
    end
    return retVal
end

---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
--[[
功能：启动、停止激光跟踪功能
参数：iTaskNumber-任务号
      toolIndex-焊缝工具坐标系索引
返回值：true表示成功，false表示失败
]]--
function CommonLaserCV.startTrack(iTaskNumber,toolIndex)
    local self = CommonLaserCV
    innerInitLaserCV(self)
    
    if self.trackThdRunFlag then
        WeldReportScriptStop(Language.trLang("LASER_TRACKING_NOT_AGAIN"))
        return true
    end
    MyWelderDebugLog(Language.trLang("LASER_TRACK_READY_START"))
    if not self.laser.openLaser() then
        MyWelderDebugLog(Language.trLang("LASER_START_TRACK_FAIL"))
        return false
    end
    if not self.laser.setTaskNumber(iTaskNumber) then
        self.laser.closeLaser()
        MyWelderDebugLog(Language.trLang("LASER_START_TRACK_FAIL"))
        return false
    end
    if not self.laser.startTrack() then
        self.laser.closeLaser()
        MyWelderDebugLog(Language.trLang("LASER_START_TRACK_FAIL"))
        return false
    end
    self.toolIndex = toolIndex
    
    self.waitingForStartTrack = false
    --启动线程,执行跟踪功能
    self.trackThreadObject = systhread.create(innerExecLoopTrack, self)
    if not self.trackThreadObject then
        MyWelderDebugLog(Language.trLang("LASER_TRACK_THD_START_FAIL"))
        self.laser.closeLaser()
        return false
    end
    --[[算法说，开始跟踪对第一个点实时性要求很高，应该先启动跟踪线程，然后在线程中一直等待，直到
    调用了DobotLaserTrackStart()接口后才开始进入跟踪。
    ]]--
    DobotLaserTrackStart() --调用算法接口开启激光跟踪功能,运动指令不能放到子线程中,这是生态决定的
    self.waitingForStartTrack = true
    
    MyWelderDebugLog(Language.trLang("LASER_TRACK_START_OK"))
    return true
end
function CommonLaserCV.stopTrack()
    local self = CommonLaserCV
    innerInitLaserCV(self)
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

return CommonLaserCV