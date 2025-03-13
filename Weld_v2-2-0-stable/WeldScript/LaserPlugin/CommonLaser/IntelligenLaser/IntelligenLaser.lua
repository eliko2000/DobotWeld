--[[
英莱激光传感器功能,继承自`ICommonLaser`
英莱的自动标定和寻位
]]--

--【本地私有接口】

---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
--【导出接口】
local IntelligenLaser = {
    sock = nil, --sock成功连接的句柄
    calibrate = IntelligenLaserCalibrateProtocol,
    position = IntelligenLaserPositionProtocol
}
IntelligenLaser.__index = IntelligenLaser
setmetatable(IntelligenLaser, ICommonLaser)

-------------------------------------------------------------------------------------------------------------------
--【对外公开接口，实现父类接口】-------------------------------------------------------------------------------------------------
function IntelligenLaser.connect(ip,port)
    local self = IntelligenLaser
    local tPort = port
    if nil==tPort then tPort=5020 end
    local err, sock = TCPCreate(false, ip, tPort)
    if 0==err then
        MyWelderDebugLog(Language.trLang("LASER_TCP_CONN_OK"))
    else 
        MyWelderDebugLog(Language.trLang("LASER_TCP_CONN_ERR")..":err="..tostring(err))
        return false
    end
    MyWelderDebugLog(Language.trLang("LASER_TCP_CONNECTING"))
    err = TCPStart(sock, 5)
    if 0~=err then
        TCPDestroy(sock)
        MyWelderDebugLog(Language.trLang("LASER_TCP_CONNECT_FAIL"))
        return false
    end
    MyWelderDebugLog(Language.trLang("LASER_TCP_CONNECT_SUCCESS"))
    self.sock = sock
    self.calibrate.connect(sock)
    self.position.connect(sock)
    return true
end

function IntelligenLaser.isConnected()
    local self = IntelligenLaser
    return nil~=self.sock
end

function IntelligenLaser.disconnect()
    local self = IntelligenLaser
    if nil~=self.sock then
        TCPDestroy(self.sock)
        self.sock = nil
    end
    self.calibrate.disconnect()
    self.position.disconnect()
end

function IntelligenLaser.openLaser()
    local self = IntelligenLaser
    return self.position.openLaser()
end

function IntelligenLaser.closeLaser()
    local self = IntelligenLaser
    return self.position.closeLaser()
end

function IntelligenLaser.autoLaserCalibrate(arrTeachPoint,optParams)
    local self = IntelligenLaser
    if #arrTeachPoint<5 then
        MyWelderDebugLog(Language.trLang("LASER_CALIBRATE_LESS5"))
        return false
    end
    MyWelderDebugLog(Language.trLang("LASER_READY_INIT"))
    if not self.calibrate.initLaser() then
        MyWelderDebugLog(Language.trLang("LASER_INIT_ERROR"))
        return false
    end
    MyWelderDebugLog(Language.trLang("LASER_AUTO_CALIBRATING"))
    local pose
    local pt = {}
    local pfnCall = {
        self.calibrate.recordTCPPose,
        self.calibrate.recordScanPose1,
        self.calibrate.recordScanPose2,
        self.calibrate.recordScanPose3,
        self.calibrate.recordScanPose4
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
        if not pfnCall[i](pt) then
            MyWelderDebugLog(Language.trLang("LASER_AUTO_CALIBRATE_PRG_ERR"))
            return false
        end
    end
    MyWelderDebugLog(Language.trLang("LASER_AUTO_CALIBRATE_OK"))
    return true
end

function IntelligenLaser.setTaskNumber(num)
    local self = IntelligenLaser
    return self.position.setTaskNumber(num)
end

function IntelligenLaser.getRobotPosePosition(robotPose)
    local self = IntelligenLaser
    local pos = robotPose.pose
    pos = self.position.getRobotPosePosition({x=pos[1],y=pos[2],z=pos[3],rx=pos[4],ry=pos[5],rz=pos[6]})
    if nil~=pos then --寻位的结果是没有姿态的，所以直接使用原始点的姿态
        pos.rx = robotPose.pose[4]
        pos.ry = robotPose.pose[5]
        pos.rz = robotPose.pose[6]
    end
    return pos
end

function IntelligenLaser.startTrack()
    return true --协议上无需此操作
end

function IntelligenLaser.stopTrack()
    return true --协议上无需此操作
end

function IntelligenLaser.getRobotPoseTrack(robotPose)
    local pos = robotPose.pose
    pos = IntelligenLaser.position.getRobotPoseTrack({x=pos[1],y=pos[2],z=pos[3],rx=pos[4],ry=pos[5],rz=pos[6]})
    if nil~=pos then
        pos.rx = robotPose.pose[4]
        pos.ry = robotPose.pose[5]
        pos.rz = robotPose.pose[6]
    end
    return pos
end

return IntelligenLaser