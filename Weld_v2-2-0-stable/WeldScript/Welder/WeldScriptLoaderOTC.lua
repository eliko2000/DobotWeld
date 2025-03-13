----------------------------------------------------------------------------------------------------------
--清除缓存
local requireModuleCacheList = {
    "Welder.OTC.OTCWelder",
    "Welder.OTC.OTCMigWelder",
    "Welder.OTC.OTCMigWelderControlDeviceNet",
    "Welder.OTC.OTCTigWelder",
    "Welder.OTC.OTCTigWelderControlDeviceNet"
}
for i=1,#requireModuleCacheList do
    package.loaded[requireModuleCacheList[i]] = nil
end

--重新加载各种模块
--[[加载焊接脚本，如果新增文件，可以配置在这里。
注意事项：通常越是不依赖其他lua脚本的文件，越是要放在这里，并且越靠前require
]]--
OTCWelder = require("Welder.OTC.OTCWelder")
OTCMigWelder = require("Welder.OTC.OTCMigWelder")
OTCMigWelderControlDeviceNet = require("Welder.OTC.OTCMigWelderControlDeviceNet")
OTCTigWelder = require("Welder.OTC.OTCTigWelder")
OTCTigWelderControlDeviceNet = require("Welder.OTC.OTCTigWelderControlDeviceNet")