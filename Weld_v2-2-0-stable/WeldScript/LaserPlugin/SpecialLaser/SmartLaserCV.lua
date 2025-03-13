--[[
激光器，将标定、寻位、跟踪这3大功能放到这里吧，目前也不知道该怎么很好的封装接口。
]]--

local function innerInitSmartLaserCV(self)
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
---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
local SmartLaserCV = {
    laser = nil, --激光器
    funcType = 0, --功能类型
    globalLaserCfg = nil --激光器配置参数`LaserPluginParameter`
}

---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
--[[
功能：选择功能
参数：iType-功能类型，1-标定功能，2-寻位功能，3-跟踪功能
返回值：true-成功，false-失败
说明：目前支持标定功能的只适配了英莱激光器
          支持寻位功能的只适配了明图激光器
          支持跟踪功能的只适配了英莱激光器            
]]--
function SmartLaserCV.selectFunction(iType)
    local self = SmartLaserCV
    innerInitSmartLaserCV(self)
    innerResetFunc(self,iType) --如果切换了功能，则需要先主动断开释放
    local selLaserName = self.globalLaserCfg.getSelectedLaser() --当前选中的激光器
    if 1==iType then
        self.laser = SmartLaserCalibrate
        return self.laser.selectLaser(selLaserName)
    elseif 2==iType then
        self.laser = SmartLaserPosition
        return self.laser.selectLaser(selLaserName)
    elseif 3==iType then
        self.laser = SmartLaserTrack
        return self.laser.selectLaser(selLaserName)
    end
    MyWelderDebugLog(Language.trLang("LASER_FUNC_SEL_OUT_RANGE"))
    return false
end

--[[
功能：连接、断开激光器
参数：无
返回值：成功true，失败false
]]--
function SmartLaserCV.connect(ip,port)
    local self = SmartLaserCV
    innerInitSmartLaserCV(self)
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
function SmartLaserCV.isConnected()
    local self = SmartLaserCV
    innerInitSmartLaserCV(self)
    return self.laser.isConnected()
end
function SmartLaserCV.disconnect()
    local self = SmartLaserCV
    innerInitSmartLaserCV(self)
    if self.laser then
        self.laser.disconnect()
    end
end

---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
--[[
功能：英莱激光自动标定
参数：请参考内部实现函数的参数说明
返回值：true-成功，false-失败
]]--
function SmartLaserCV.intelligenAutoLaserCalibrate(arrTeachPoint, optParams)
    local self = SmartLaserCV
    innerInitSmartLaserCV(self)
    if not self.laser.intelligenAutoLaserCalibrate(arrTeachPoint, optParams) then
        MyWelderDebugLog(Language.trLang("LASER_AUTO_CALIBRATE_FAIL"))
        return false
    end
    return true
end

---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
--[[
功能：激光寻位获取结果值
参数：请参考内部实现函数的参数说明
返回值：成功返回{x=1,y=1,z=1,rx=1,ry=1,rz=1}，失败返回nil
]]--
function SmartLaserCV.getLaserPositioning(robotPose, iTaskNumber)
    local self = SmartLaserCV
    innerInitSmartLaserCV(self)
    local retVal = self.laser.getLaserPositioning(robotPose, iTaskNumber)
    if not retVal then
        MyWelderDebugLog(Language.trLang("LASER_POSITION_FAIL"))
        return nil
    end
    return retVal
end

---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
--[[
功能：启动、停止激光跟踪功能
参数：请参考内部实现函数的参数说明
返回值：true表示成功，false表示失败
]]--
function SmartLaserCV.startTrack(iTaskNumber)
    local self = SmartLaserCV
    innerInitSmartLaserCV(self)
    if not self.laser.setTaskNumber(iTaskNumber) then
        return false
    end
    if not self.laser.startTrack() then
        MyWelderDebugLog(Language.trLang("LASER_START_TRACK_FAIL"))
        return false
    end
    return true
end
function SmartLaserCV.stopTrack()
    local self = SmartLaserCV
    innerInitSmartLaserCV(self)
    if not self.laser.stopTrack() then
        MyWelderDebugLog(Language.trLang("LASER_END_TRACK_FAIL"))
        return false
    end
    return true
end

return SmartLaserCV