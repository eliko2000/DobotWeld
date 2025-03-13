----------------------------------------------------------------------------------------------------------
--清除缓存
local requireModuleCacheList = {
    "Welder.ESAB.ESABWelder",
    "Welder.ESAB.ESABWelderControlDeviceNet",
    "Welder.ESAB.ESABChinaWelder",
    "Welder.ESAB.ESABChinaWelderControlDeviceNet"
}
for i=1,#requireModuleCacheList do
    package.loaded[requireModuleCacheList[i]] = nil
end

--重新加载各种模块
--[[加载焊接脚本，如果新增文件，可以配置在这里。
注意事项：通常越是不依赖其他lua脚本的文件，越是要放在这里，并且越靠前require
]]--
ESABWelder = require("Welder.ESAB.ESABWelder")
ESABWelderControlDeviceNet = require("Welder.ESAB.ESABWelderControlDeviceNet")
ESABChinaWelder = require("Welder.ESAB.ESABChinaWelder")
ESABChinaWelderControlDeviceNet = require("Welder.ESAB.ESABChinaWelderControlDeviceNet")