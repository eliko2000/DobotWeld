--[[
激光器插件公共全局变量配置参数表
]]--
--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
--激光器插件连接地址信息
local innerLaserAddrConfig = {
    ip = "192.168.5.10",
    port = 5020
}

--数据库保存的key，不要轻易修改------------------------------------------------------------------------------
local keySelectedLaserName = "Dobot_Weld_Parameter_LaserPluginParameter_SelectedLaserName"
local keyLaserAddrConfigName = "Dobot_Weld_Parameter_LaserPluginParameter_LaserAddrConfigName"

-------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------
--【激光器插件全局变量操作接口导出】-------------------------------------------------------------------------------
local LaserPluginParameter = {
    SelectedLaserName = "", --当前选择的激光器插件（只能是EnumConstant.ConstEnumLaserPluginName的值）
    LaserAddrParam = {} --激光器插件连接地址的配置参数，请参考 innerLaserAddrConfig
}

--获取、设置选择的激光器，请参考`EnumConstant.ConstEnumLaserPluginName`表
function LaserPluginParameter.getSelectedLaser()
    local param = GetVal(keySelectedLaserName)
    if nil~=param then return param end
    return ""
end
function LaserPluginParameter.setSelectedLaser(newValue)
    if ConstEnumLaserPluginName[newValue] then
        SetVal(keySelectedLaserName,newValue)
        return true
    end
    MyWelderDebugLog(Language.trLang("SET_LASER_PRM_ERROR").."laserName="..tostring(newValue))
    return false
end

--获取、设置激光器地址ip信息，请参考`innerLaserAddrConfig`表
function LaserPluginParameter.getLaserAddrParam()
    local param = GetVal(keyLaserAddrConfigName)
    if nil~=param then return param end
    return innerLaserAddrConfig
end
function LaserPluginParameter.setLaserAddrParam(newValue)
    SetVal(keyLaserAddrConfigName,newValue)
    return true
end

return LaserPluginParameter