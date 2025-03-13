--[[
激光标定功能封装
说明：不同厂家激光器标定的逻辑不一样，有的支持通过交互协议方式标定，有的不支持，而且对各个厂家激光器标定功能不太
      了解，所以暂时不要封装那么深，简单粗暴就可以。
]]--

--【本地私有接口】

---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
--【导出接口】
local SmartLaserCalibrate = {
    selLaserObj = nil --当前选中的激光器
}

---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
--[[
功能：选择激光器
参数：name-激光器名称，只能是`EnumConstant.ConstEnumLaserPluginName`的值
返回值：true-成功，false-失败
]]--
function SmartLaserCalibrate.selectLaser(name)
    local self = SmartLaserCalibrate
    if "Intelligen"==name then
        self.selLaserObj = SMTIntelligenLaserCalibrate
        return true
    else
        MyWelderDebugLog(Language.trLang("LASER_NOADAPTER_CALIBRATE")..":"..tostring(name))
        return false
    end
end

--[[
功能：连接激光器
参数：ip-地址,
      port-端口
返回值：true表示成功，false表示失败
]]--
function SmartLaserCalibrate.connect(ip,port)
    local self = SmartLaserCalibrate
    return self.selLaserObj.connect(ip,port)
end

--[[
功能：断开是否已连接
参数：无
返回值：true-已连接，false-未连接
]]--
function SmartLaserCalibrate.isConnected()
    local self = SmartLaserCalibrate
    return self.selLaserObj.isConnected()
end

--[[
功能：断开激光器的连接
参数：无
返回值：无
]]--
function SmartLaserCalibrate.disconnect()
    local self = SmartLaserCalibrate
    self.selLaserObj.disconnect()
end

--[[
功能：英莱自动标定
参数：arrTeachPoint-标定时示教点数组，数组中每个点结构等同存点列表中点的结构，如下：
      {
        name = "name",
        pose = {x, y, z, rx, ry, rz},
        joint = {j1, j2, j3, j4, j5, j6},
        tool = index,
        user = index
      }
      optParams-可选参数{v = 50, a = 50}
返回值：true-成功，false-失败
]]--
function SmartLaserCalibrate.intelligenAutoLaserCalibrate(arrTeachPoint,optParams)
    local self = SmartLaserCalibrate
    if #arrTeachPoint<5 then
        MyWelderDebugLog(Language.trLang("LASER_CALIBRATE_LESS5"))
        return false
    end
    MyWelderDebugLog(Language.trLang("LASER_READY_INIT"))
    if not self.selLaserObj.initLaser() then
        MyWelderDebugLog(Language.trLang("LASER_INIT_ERROR"))
        return false
    end
    MyWelderDebugLog(Language.trLang("LASER_AUTO_CALIBRATING"))
    local pose
    local pt = {}
    local pfnCall = {
        self.selLaserObj.recordTCPPose,
        self.selLaserObj.recordScanPose1,
        self.selLaserObj.recordScanPose2,
        self.selLaserObj.recordScanPose3,
        self.selLaserObj.recordScanPose4
    }
    
    for i=1,5 do
        if type(optParams)=="table" then --可选参数
            MovL(arrTeachPoint[i],optParams) --先运动到该位置
        else
            MovL(arrTeachPoint[i]) --先运动到该位置
        end
        Wait(2000) --让机械臂稳定下来，防止抖动
        pose = arrTeachPoint[i].pose
        pt.x=pose[1]
        pt.y=pose[2]
        pt.z=pose[3]
        pt.rx=pose[4]
        pt.ry=pose[5]
        pt.rz=pose[6]
        self.selLaserObj.setRobotPose(pt)
        if not pfnCall[i]() then
            MyWelderDebugLog(Language.trLang("LASER_AUTO_CALIBRATE_PRG_ERR"))
            return false
        end
    end
    MyWelderDebugLog(Language.trLang("LASER_AUTO_CALIBRATE_OK"))
    return true
end

--[[
功能：英莱测试标定结果是否准确
参数：testPoint-测试点，数据结构与存点P相同，请参考`SmartLaserCalibrate.autoLaserCalibrate`接口
返回值：成功返回{x=1,y=2,z=3,rx=4,ry=5,rz=6},失败返回nil
]]--
function SmartLaserCalibrate.intelligenTestCalibrateResult(testPoint)
    local self = SmartLaserCalibrate
    MovL(testPoint)
    local pt = {}
    pt.x=testPoint.pose[1]
    pt.y=testPoint.pose[2]
    pt.z=testPoint.pose[3]
    pt.rx=testPoint.pose[4]
    pt.ry=testPoint.pose[5]
    pt.rz=testPoint.pose[6]
    self.selLaserObj.setRobotPose(pt)
    return self.selLaserObj.checkRobotPose()
end

return SmartLaserCalibrate