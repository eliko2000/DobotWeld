----------------------------------------------------------------------------------------------------------
--清除缓存
local requireModuleCacheList = {
    "Welder.Aotai.AotaiWelder",
    "Welder.Aotai.AotaiWelderControlDeviceNet",
    "Welder.Aotai.AotaiWelderControlModbus",
    "Welder.Aotai.AotaiWelderMigLst",
    "Welder.Aotai.AotaiWelderMigLstControlDeviceNet",
    "Welder.Aotai.AotaiWelderMigLstControlModbus",
    "Welder.Aotai.AotaiWelderMigPlus",
    "Welder.Aotai.AotaiWelderMigPlusControlDeviceNet",
    "Welder.Aotai.AotaiWelderMigPlusControlModbus"
}
for i=1,#requireModuleCacheList do
    package.loaded[requireModuleCacheList[i]] = nil
end

--重新加载各种模块
--[[加载焊接脚本，如果新增文件，可以配置在这里。
注意事项：通常越是不依赖其他lua脚本的文件，越是要放在这里，并且越靠前require
]]--
AotaiWelder = require("Welder.Aotai.AotaiWelder")
AotaiWelderControlDeviceNet = require("Welder.Aotai.AotaiWelderControlDeviceNet")
AotaiWelderControlModbus = require("Welder.Aotai.AotaiWelderControlModbus")
AotaiWelderMigLst = require("Welder.Aotai.AotaiWelderMigLst")
AotaiWelderMigLstControlDeviceNet = require("Welder.Aotai.AotaiWelderMigLstControlDeviceNet")
AotaiWelderMigLstControlModbus = require("Welder.Aotai.AotaiWelderMigLstControlModbus")
AotaiWelderMigPlus = require("Welder.Aotai.AotaiWelderMigPlus")
AotaiWelderMigPlusControlDeviceNet = require("Welder.Aotai.AotaiWelderMigPlusControlDeviceNet")
AotaiWelderMigPlusControlModbus = require("Welder.Aotai.AotaiWelderMigPlusControlModbus")