----------------------------------------------------------------------------------------------------------
--清除缓存
local requireModuleCacheList = {
    "Welder.Cloos.CloosWelder",
    "Welder.Cloos.CloosWelderControlDAnalogIO"
}
for i=1,#requireModuleCacheList do
    package.loaded[requireModuleCacheList[i]] = nil
end

--重新加载各种模块
--[[加载焊接脚本，如果新增文件，可以配置在这里。
注意事项：通常越是不依赖其他lua脚本的文件，越是要放在这里，并且越靠前require
]]--
CloosWelder = require("Welder.Cloos.CloosWelder")
CloosWelderControlDAnalogIO = require("Welder.Cloos.CloosWelderControlDAnalogIO")