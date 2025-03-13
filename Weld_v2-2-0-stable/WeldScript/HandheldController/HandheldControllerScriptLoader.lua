----------------------------------------------------------------------------------------------------------
--清除缓存
local requireModuleCacheList = {
    "HandheldController.WelderHandleControl",
    "HandheldController.RobotModbusControl",
    "HandheldController.JbkLightID",
    "HandheldController.JoystickKeyboardProtocol",
    "HandheldController.KbEventListener",
    "HandheldController.KbCallbackFunction",
    "HandheldController.JbkExtendFunction",
    "HandheldController.JoystickKeyboard",
    "HandheldController.JoystickArcTemplate"
}
for i=1,#requireModuleCacheList do
    package.loaded[requireModuleCacheList[i]] = nil
end

--重新加载各种模块
--[[加载焊接脚本，如果新增文件，可以配置在这里。
注意事项：通常越是不依赖其他lua脚本的文件，越是要放在这里，并且越靠前require
]]--
--GT72操纵杆控制器
WelderHandleControl = require("HandheldController.WelderHandleControl")
RobotModbusControl = require("HandheldController.RobotModbusControl")
JbkLightID = require("HandheldController.JbkLightID")
JoystickKeyboardProtocol = require("HandheldController.JoystickKeyboardProtocol")
KbEventListener = require("HandheldController.KbEventListener")
KbCallbackFunction = require("HandheldController.KbCallbackFunction")
JbkExtendFunction = require("HandheldController.JbkExtendFunction")
JoystickKeyboard = require("HandheldController.JoystickKeyboard")
JoystickArcTemplate = require("HandheldController.JoystickArcTemplate")


