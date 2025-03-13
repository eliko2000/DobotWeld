--[[
苏州全视激光传感器功能,继承自`ICommonLaser`
]]--

--【本地私有接口】

---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
--【导出接口】
local FullVisionLaser = {
    laser = FullVisionProtocol
}
FullVisionLaser.__index = FullVisionLaser
setmetatable(FullVisionLaser, ICommonLaser)

-------------------------------------------------------------------------------------------------------------------
--【对外公开接口，实现父类接口】-------------------------------------------------------------------------------------------------
function FullVisionLaser.connect(ip,port)
    local self = FullVisionLaser
    return self.laser.connect(ip,port)
end

function FullVisionLaser.isConnected()
    local self = FullVisionLaser
    return self.laser.isConnected()
end

function FullVisionLaser.disconnect()
    local self = FullVisionLaser
    self.laser.disconnect()
end

function FullVisionLaser.openLaser()
    local self = FullVisionLaser
    return self.laser.openLaser()
end

function FullVisionLaser.closeLaser()
    local self = FullVisionLaser
    return self.laser.closeLaser()
end

function FullVisionLaser.autoLaserCalibrate(arrTeachPoint,optParams)
    local self = FullVisionLaser
    if #arrTeachPoint<5 then
        MyWelderDebugLog(Language.trLang("LASER_CALIBRATE_LESS5"))
        return false
    end
    MyWelderDebugLog(Language.trLang("LASER_AUTO_CALIBRATING"))
    local pose
    local pt = {}
    local pfnCall = {
        self.laser.recordTCPPose,
        self.laser.recordScanPose1,
        self.laser.recordScanPose2,
        self.laser.recordScanPose3,
        self.laser.recordScanPose4
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

function FullVisionLaser.setTaskNumber(num)
    local self = FullVisionLaser
    return self.laser.setTaskNumber(num)
end

function FullVisionLaser.getRobotPosePosition(robotPose)
    local self = FullVisionLaser
    local pos = robotPose.pose
    pos = self.laser.getToolPose({x=pos[1],y=pos[2],z=pos[3],rx=pos[4],ry=pos[5],rz=pos[6]})
    if nil~=pos then --拿到的值就是实际的目标点
        pos.rx = robotPose.pose[4]
        pos.ry = robotPose.pose[5]
        pos.rz = robotPose.pose[6]
    end
    return pos
end

function FullVisionLaser.startTrack()
    local self = FullVisionLaser
    return self.laser.startTrack()
end

function FullVisionLaser.stopTrack()
    local self = FullVisionLaser
    return self.laser.stopTrack()
end

function FullVisionLaser.getRobotPoseTrack(robotPose)
    local self = FullVisionLaser
    local pos = robotPose.pose
    pos = self.laser.getToolPose({x=pos[1],y=pos[2],z=pos[3],rx=pos[4],ry=pos[5],rz=pos[6]},true)
    if nil~=pos then --拿到的值就是实际的目标点
        pos.rx = robotPose.pose[4]
        pos.ry = robotPose.pose[5]
        pos.rz = robotPose.pose[6]
    end
    return pos
end

return FullVisionLaser