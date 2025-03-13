----------------------------------------------------------------------------------------------------------
--清除缓存
local requireModuleCacheList = {
    "LaserPlugin.CommonLaser.ICommonLaser",
    "LaserPlugin.CommonLaser.CrownThoughtLaser.CrownThoughtProtocol",
    "LaserPlugin.CommonLaser.CrownThoughtLaser.CrownThoughtLaser",
    "LaserPlugin.CommonLaser.FullVisionLaser.FullVisionProtocol",
    "LaserPlugin.CommonLaser.FullVisionLaser.FullVisionLaser",
    "LaserPlugin.CommonLaser.IntelligenLaser.IntelligenLaserCalibrateProtocol",
    "LaserPlugin.CommonLaser.IntelligenLaser.IntelligenLaserPositionProtocol",
    "LaserPlugin.CommonLaser.IntelligenLaser.IntelligenLaser",
    "LaserPlugin.CommonLaser.MingTuLaser.MingTuProtocol",
    "LaserPlugin.CommonLaser.MingTuLaser.MingTuLaser",
    "LaserPlugin.CommonLaser.CommonLaserCV" --放到最后面
}
for i=1,#requireModuleCacheList do
    package.loaded[requireModuleCacheList[i]] = nil
end

--重新加载各种模块
--[[加载焊接脚本，如果新增文件，可以配置在这里。
注意事项：通常越是不依赖其他lua脚本的文件，越是要放在这里，并且越靠前require
]]--
--这个是接口类
ICommonLaser = require("LaserPlugin.CommonLaser.ICommonLaser")

--北京创想智控激光器
CrownThoughtProtocol = require("LaserPlugin.CommonLaser.CrownThoughtLaser.CrownThoughtProtocol")
CrownThoughtLaser = require("LaserPlugin.CommonLaser.CrownThoughtLaser.CrownThoughtLaser")

--苏州全视激光器
FullVisionProtocol = require("LaserPlugin.CommonLaser.FullVisionLaser.FullVisionProtocol")
FullVisionLaser = require("LaserPlugin.CommonLaser.FullVisionLaser.FullVisionLaser")

--唐山英莱激光器
IntelligenLaserCalibrateProtocol = require("LaserPlugin.CommonLaser.IntelligenLaser.IntelligenLaserCalibrateProtocol")
IntelligenLaserPositionProtocol = require("LaserPlugin.CommonLaser.IntelligenLaser.IntelligenLaserPositionProtocol")
IntelligenLaser = require("LaserPlugin.CommonLaser.IntelligenLaser.IntelligenLaser")

--苏州明图激光器
MingTuProtocol = require("LaserPlugin.CommonLaser.MingTuLaser.MingTuProtocol")
MingTuLaser = require("LaserPlugin.CommonLaser.MingTuLaser.MingTuLaser")


-------------------------------------------------------------------------------------------------
--特殊定制化：统一封装接口需求
CommonLaserCV = require("LaserPlugin.CommonLaser.CommonLaserCV")
