--[[
激光器的一些简单操作，只给http接口使用
]]--

local function innerInitLaserCV(self)
    if nil==self.globalLaserCfg then
        self.globalLaserCfg = LaserPluginParameter
    end
    local name = self.globalLaserCfg.getSelectedLaser()
    self.laser = RobotManager.createCommonLaser(name)
    --[[
    if "MingTu"==name then
        self.laser = SMTMingTuLaserPosition
    elseif "Intelligen"==name then
        self.laser = SMTIntelligenLaserPosition
    end
    ]]--
end

---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
local SmartLaserHttp = {
    laser = nil, --激光器
    globalLaserCfg = nil --激光器配置参数`LaserPluginParameter`
}

---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
--[[
功能：连接、断开激光器
参数：无
返回值：成功true，失败false
]]--
function SmartLaserHttp.connect()
    local self = SmartLaserHttp
    innerInitLaserCV(self)
    local params = self.globalLaserCfg.getLaserAddrParam()
    if self.laser.connect(params.ip,params.port) then
        MyWelderDebugLog(Language.trLang("LASER_CONNECT_OK"))
        return true
    else
        MyWelderDebugLog(Language.trLang("LASER_CONNECT_FAIL"))
        return false
    end
end
function SmartLaserHttp.isConnected()
    local self = SmartLaserHttp
    innerInitLaserCV(self)
    return self.laser.isConnected()
end
function SmartLaserHttp.disconnect()
    local self = SmartLaserHttp
    innerInitLaserCV(self)
    self.laser.disconnect()
end

function SmartLaserHttp.openLaser()
    local self = SmartLaserHttp
    innerInitLaserCV(self)
    return self.laser.openLaser()
end

function SmartLaserHttp.closeLaser()
    local self = SmartLaserHttp
    innerInitLaserCV(self)
    return self.laser.closeLaser()
end

return SmartLaserHttp