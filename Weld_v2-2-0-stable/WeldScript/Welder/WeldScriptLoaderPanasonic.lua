----------------------------------------------------------------------------------------------------------
--清除缓存
local requireModuleCacheList = {
    "Welder.Panasonic.PanasonicWelder",
    "Welder.Panasonic.PanasonicWelderControlDeviceNet",
    "Welder.Panasonic.PanasonicWTDEUWelder",
    "Welder.Panasonic.PanasonicWTDEUControlEIP"
}
for i=1,#requireModuleCacheList do
    package.loaded[requireModuleCacheList[i]] = nil
end

--重新加载各种模块
--[[加载焊接脚本，如果新增文件，可以配置在这里。
注意事项：通常越是不依赖其他lua脚本的文件，越是要放在这里，并且越靠前require
]]--
PanasonicWelder = require("Welder.Panasonic.PanasonicWelder")
PanasonicWelderControlDeviceNet = require("Welder.Panasonic.PanasonicWelderControlDeviceNet")
PanasonicWTDEUWelder = require("Welder.Panasonic.PanasonicWTDEUWelder")
PanasonicWTDEUControlEIP = require("Welder.Panasonic.PanasonicWTDEUControlEIP")