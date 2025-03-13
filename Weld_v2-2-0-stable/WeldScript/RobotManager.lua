--【焊机管理类，类似于工厂类，负责对象创建】
---------------------------------------------------------------------------------
--旧的对象，每当重新创建焊机时，需要释放之前焊机的一些资源，因为lua没有析构的概念，所以记录释放
local g_innerOldIOStream = nil
local g_ioName = nil

local g_innerOldWelder = nil
local g_welderName = nil

---------------------------------------------------------------------------------
--导出接口
local RobotManager = {}

--[[
功能：创建通信方式对象
参数：ioName-通信类型，只能是`EnumConstant.ConstEnumIOStreamName`的一种
      ip、port分别是IP地址和端口号
      extParams-扩展特殊参数，不同的协议可能不一样
返回值：IDobotIOStream子对象，也就是通信对象，为nil表示失败
]]--
function RobotManager.createIOStream(ioName, ip, port, extParams)
    if not ConstEnumIOStreamName[ioName] then
        MyWelderDebugLog(Language.trLang("NOT_RECOGNIZE_COMM")..",ioName="..tostring(ioName))
        return nil 
    end
    
    if nil ~= g_innerOldIOStream then
        pcall(function() g_innerOldWelder:disconnect() end)
        if ioName == g_ioName then
            g_innerOldIOStream:setConnectParam(ip, port, extParams)
            return g_innerOldIOStream
        end
    end
    
    MyWelderDebugLog("it\'s creating "..tostring(ioName).." connector object....")
    local newObj = nil
    if "modbus" == ioName then
        newObj = DobotModbusTcpClient:new()
    elseif "deviceNet" == ioName then
        newObj = DobotDeviceNet:new()
    elseif "analogIO" == ioName then
        newObj = DobotAnalog:new()
    elseif "eip" == ioName then
        newObj = DobotEtherNetIP:new()
    end
    newObj:setConnectParam(ip, port, extParams)
    g_innerOldIOStream = newObj
    g_ioName = ioName
    return newObj
end

--[[
功能：创建/获取焊接机对象
参数：welderName-焊机名称，只能是`EnumConstant.ConstEnumWelderName`的一种
返回值：IDobotWelder的子对象，也就是焊机对象，为nil表示失败
]]--
function RobotManager.createDobotWelder(welderName)
    if not ConstEnumWelderName[welderName] then
        MyWelderDebugLog(Language.trLang("NOT_RECOGNIZE_WELDER")..",welderName="..tostring(welderName))
        return nil 
    end
    
    if nil ~= g_innerOldWelder then
        if welder == g_welderName then
            return g_innerOldWelder
        end
        pcall(function() g_innerOldWelder:disconnect() end)
    end
    
    MyWelderDebugLog("it\'s creating "..tostring(welderName).." welder object....")
    local newObj = nil
    if "Aotai_MIG_LST" == welderName then
        newObj = AotaiWelderMigLst:new(GlobalParameter,welderName)
    elseif "Aotai_MIG_PLUS" == welderName then
        newObj = AotaiWelderMigPlus:new(GlobalParameter,welderName)
    elseif "Ewm" == welderName then
        newObj = EWMWelder:new(GlobalParameter,welderName)
    elseif "Fronius" == welderName then
        newObj = FroniusWelder:new(GlobalParameter,welderName)
    elseif "Lincoln_Digiwave" == welderName then
        newObj = LincolnWelder:new(GlobalParameter,welderName)
    elseif "Lincoln_Powerwave" == welderName then
        newObj = LincolnPowerWaveWelder:new(GlobalParameter,welderName)
    elseif "Flama" == welderName then
        newObj = FlamaWelder:new(GlobalParameter,welderName)
    elseif "Megmeet" == welderName then
        newObj = MegmeetWelder:new(GlobalParameter,welderName)
    elseif "Panasonic" == welderName then
        newObj = PanasonicWelder:new(GlobalParameter,welderName)
    elseif "PanasonicWTDEU" == welderName then
        newObj = PanasonicWTDEUWelder:new(GlobalParameter,welderName)
    elseif "GYS" == welderName then
        newObj = GYSWelder:new(GlobalParameter,welderName)
    elseif "SKS" == welderName then
        newObj = SKSWelder:new(GlobalParameter,welderName)
    elseif "Kemppi" == welderName then
        newObj = KemppiWelder:new(GlobalParameter,welderName)
    elseif "KemppiAX" == welderName then
        newObj = KemppiAXWelder:new(GlobalParameter,welderName)
    elseif "Lorch" == welderName then
        newObj = LorchWelder:new(GlobalParameter,welderName)
    elseif "OTCMig" == welderName then
        newObj = OTCMigWelder:new(GlobalParameter,welderName)
    elseif "OTCTig" == welderName then
        newObj = OTCTigWelder:new(GlobalParameter,welderName)
    elseif "Cloos" == welderName then
        newObj = CloosWelder:new(GlobalParameter,welderName)
    elseif "ESAB" == welderName then
        newObj = ESABWelder:new(GlobalParameter,welderName)
    elseif "ESABChina" == welderName then
        newObj = ESABChinaWelder:new(GlobalParameter,welderName)
    elseif "Miller" == welderName then
        newObj = MillerWelder:new(GlobalParameter,welderName)
    elseif "Kolarc" == welderName then
        newObj = KolarcWelder:new(GlobalParameter,welderName)
    elseif "Laser" == welderName then
        newObj = LaserWelder:new(GlobalParameter,welderName)
    elseif "Virtual" == welderName then
        newObj = VirtualWelder:new(GlobalParameter,welderName)
    elseif "Other" == welderName then
        newObj = OtherWelder:new(GlobalParameter,welderName)
    else
        MyWelderDebugLog(Language.trLang("NOT_SUPPORT_WELDER")..",welderName="..tostring(welderName))
    end
    g_innerOldWelder = newObj
    g_welderName = welderName
    return newObj
end
function RobotManager.getDobotCurrentWelder()
    return g_innerOldWelder
end

--[[
功能：创建通用激光器
参数：name-激光器名称，只能是`EnumConstant.ConstEnumLaserPluginName`的一种
返回值：ICommonLaser子对象，为nil表示失败
]]--
function RobotManager.createCommonLaser(name)
    if not ConstEnumLaserPluginName[name] then
        MyWelderDebugLog(Language.trLang("NO_SUPPORT_LASER_PLUGIN_ENUM")..",name="..tostring(name))
        return nil 
    end
    MyWelderDebugLog("it\'s creating "..tostring(name).." laser object....")
    local newObj = nil
    if "MingTu" == name then
        newObj = MingTuLaser
    elseif "Intelligen" == name then
        newObj = IntelligenLaser
    elseif "FullVision" == name then
        newObj = FullVisionLaser
    elseif "CrownThought" == name then
        newObj = CrownThoughtLaser
    end
    return newObj
end

return RobotManager