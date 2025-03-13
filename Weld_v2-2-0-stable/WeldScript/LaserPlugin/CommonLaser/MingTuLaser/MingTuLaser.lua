--[[
苏州明图智能激光传感器功能,继承自`ICommonLaser`
]]--

--【本地私有接口】

---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
--【导出接口】
local MingTuLaser = {
    laser = MingTuProtocol
}
MingTuLaser.__index = MingTuLaser
setmetatable(MingTuLaser, ICommonLaser)

-------------------------------------------------------------------------------------------------------------------
--【对外公开接口，实现父类接口】-------------------------------------------------------------------------------------------------
function MingTuLaser.connect(ip,port)
    local self = MingTuLaser
    return self.laser.connect(ip,port)
end

function MingTuLaser.isConnected()
    local self = MingTuLaser
    return self.laser.isConnected()
end

function MingTuLaser.disconnect()
    local self = MingTuLaser
    self.laser.disconnect()
end

function MingTuLaser.openLaser()
    local self = MingTuLaser
    return self.laser.openLaser()
end

function MingTuLaser.closeLaser()
    local self = MingTuLaser
    return self.laser.closeLaser()
end

function MingTuLaser.autoLaserCalibrate(arrTeachPoint,optParams)
    MyWelderDebugLog(Language.trLang("LASER_NOADAPTER_CALIBRATE"))
    return false
end

function MingTuLaser.setTaskNumber(num)
    local self = MingTuLaser
    return self.laser.setTaskNumber(num)
end

function MingTuLaser.getRobotPosePosition(robotPose)
    local self = MingTuLaser
    local pos = self.selLaserObj.getToolPose()
    if nil~=pos then --激光器得到的是相对于工具坐标系的偏移值，所以要转换为用户坐标系下的值
        --pos.rx,pos.ry,pos.rz,激光器目前返回的姿态应该是无用的，置0会安全些
        local offsetPose = RelPointTool(robotPose,{pos.x,pos.y,pos.z,0,0,0})
        pos.x = offsetPose.pose[1]
        pos.y = offsetPose.pose[2]
        pos.z = offsetPose.pose[3]
        pos.rx = offsetPose.pose[4]
        pos.ry = offsetPose.pose[5]
        pos.rz = offsetPose.pose[6]
    end
    return pos
end

function MingTuLaser.startTrack()
    local self = MingTuLaser
    return self.laser.startTrack()
end

function MingTuLaser.stopTrack()
    local self = MingTuLaser
    return self.laser.stopTrack()
end

function MingTuLaser.getRobotPoseTrack(robotPose)
    MyWelderDebugLog(Language.trLang("LASER_NOADAPTER_TRACKING"))
    return nil
end

return MingTuLaser