----------------------------------------------------------------------------------------------------------
--清除缓存
local requireModuleCacheList = {
    "LaserPlugin.SpecialLaser.IntelligenLaser.SMTIntelligenLaserCalibrate",
    "LaserPlugin.SpecialLaser.IntelligenLaser.SMTIntelligenLaserTrack",
    "LaserPlugin.SpecialLaser.IntelligenLaser.SMTIntelligenLaserPosition",
    "LaserPlugin.SpecialLaser.MingTuLaser.SMTMingTuLaserPosition",
    "LaserPlugin.SpecialLaser.SmartLaserCalibrate",
    "LaserPlugin.SpecialLaser.SmartLaserPosition",
    "LaserPlugin.SpecialLaser.SmartLaserTrack",
    "LaserPlugin.SpecialLaser.SmartLaserCV"
}
for i=1,#requireModuleCacheList do
    package.loaded[requireModuleCacheList[i]] = nil
end

--重新加载各种模块
--[[加载焊接脚本，如果新增文件，可以配置在这里。
注意事项：通常越是不依赖其他lua脚本的文件，越是要放在这里，并且越靠前require
]]--
--特殊定制化：英莱激光器
SMTIntelligenLaserCalibrate = require("LaserPlugin.SpecialLaser.IntelligenLaser.SMTIntelligenLaserCalibrate")
SMTIntelligenLaserTrack = require("LaserPlugin.SpecialLaser.IntelligenLaser.SMTIntelligenLaserTrack")
SMTIntelligenLaserPosition = require("LaserPlugin.SpecialLaser.IntelligenLaser.SMTIntelligenLaserPosition")

--特殊定制化：明图激光器
SMTMingTuLaserPosition = require("LaserPlugin.SpecialLaser.MingTuLaser.SMTMingTuLaserPosition")

-------------------------------------------------------------------------------------------------
--特殊定制化：激光器的业务封装
SmartLaserCalibrate = require("LaserPlugin.SpecialLaser.SmartLaserCalibrate")
SmartLaserPosition = require("LaserPlugin.SpecialLaser.SmartLaserPosition")
SmartLaserTrack = require("LaserPlugin.SpecialLaser.SmartLaserTrack")

-------------------------------------------------------------------------------------------------
--特殊定制化：统一封装接口需求
SmartLaserCV = require("LaserPlugin.SpecialLaser.SmartLaserCV")
