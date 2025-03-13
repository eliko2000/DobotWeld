----------------------------------------------------------------------------------------------------------
--清除缓存
local requireModuleCacheList = {
    "LaserPlugin.SpecialLaser.SmartLaserCVScriptLoader",
    "LaserPlugin.CommonLaser.CommonLaserCVScriptLoader",
    "LaserPlugin.Chishine3DLaser.Chishine3DLaserScriptLoader",
    "LaserPlugin.SmartArcTrack",
    "LaserPlugin.SmartLaserHttp"
}
for i=1,#requireModuleCacheList do
    package.loaded[requireModuleCacheList[i]] = nil
end

--重新加载各种模块
--[[加载焊接脚本，如果新增文件，可以配置在这里。
注意事项：通常越是不依赖其他lua脚本的文件，越是要放在这里，并且越靠前require
]]--
--定制化的激光器
require("LaserPlugin.SpecialLaser.SmartLaserCVScriptLoader")

--通用激光器方案
require("LaserPlugin.CommonLaser.CommonLaserCVScriptLoader")

--知象光电3D视觉方案
require("LaserPlugin.Chishine3DLaser.Chishine3DLaserScriptLoader")

--电弧跟踪
SmartArcTrack = require("LaserPlugin.SmartArcTrack")

--http导出接口
SmartLaserHttp = require("LaserPlugin.SmartLaserHttp")
