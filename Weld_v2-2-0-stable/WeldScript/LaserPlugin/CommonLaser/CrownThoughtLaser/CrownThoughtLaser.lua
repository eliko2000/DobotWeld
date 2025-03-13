--[[
北京创想智控激光传感器功能,继承自`ICommonLaser`
]]--

--【本地私有接口】

---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
--【导出接口】
local CrownThoughtLaser = {
    laser = CrownThoughtProtocol
}
CrownThoughtLaser.__index = CrownThoughtLaser
setmetatable(CrownThoughtLaser, ICommonLaser)

-------------------------------------------------------------------------------------------------------------------
--【对外公开接口，实现父类接口】-------------------------------------------------------------------------------------------------
function CrownThoughtLaser.connect(ip,port)
    local self = CrownThoughtLaser
    return self.laser.connect(ip,port)
end

function CrownThoughtLaser.isConnected()
    local self = CrownThoughtLaser
    return self.laser.isConnected()
end

function CrownThoughtLaser.disconnect()
    local self = CrownThoughtLaser
    self.laser.disconnect()
end

function CrownThoughtLaser.openLaser()
    local self = CrownThoughtLaser
    return self.laser.openLaser()
end

function CrownThoughtLaser.closeLaser()
    local self = CrownThoughtLaser
    return self.laser.closeLaser()
end

function CrownThoughtLaser.autoLaserCalibrate(arrTeachPoint,optParams)
    MyWelderDebugLog(Language.trLang("LASER_NOADAPTER_CALIBRATE"))
    return false
end

function CrownThoughtLaser.setTaskNumber(num)
    local self = CrownThoughtLaser
    return self.laser.setTaskNumber(num)
end

function CrownThoughtLaser.getRobotPosePosition(robotPose)
    --[[
    local self = CrownThoughtLaser
    local pos =  self.laser.getLaserRobotPose()
    return pos
    ]]--
    MyWelderDebugLog(Language.trLang("LASER_NOADAPTER_POSITION"))
    return nil
end

function CrownThoughtLaser.startTrack()
    local self = CrownThoughtLaser
    return self.laser.startTrack()
end

function CrownThoughtLaser.stopTrack()
    local self = CrownThoughtLaser
    return self.laser.stopTrack()
end

function CrownThoughtLaser.getRobotPoseTrack(robotPose)
    --[[
    local self = CrownThoughtLaser
    local pos =  self.laser.getLaserRobotPose()
    return pos
    ]]--
    MyWelderDebugLog(Language.trLang("LASER_NOADAPTER_TRACKING"))
    return nil
end

return CrownThoughtLaser