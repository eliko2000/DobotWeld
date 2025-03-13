--[[
北京创想智控激光传感器modbus协议
]]--

--【本地私有接口】

---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
--【导出接口】
local CrownThoughtProtocol = {
    id = nil --modbus成功连接的句柄id
}

---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
--[[
功能：通过modbus方式连接激光器
参数：ip-地址,
      port-端口，传nil或不传则默认为502
返回值：true表示成功，false表示失败
]]--
function CrownThoughtProtocol.connect(ip,port)
    local self = CrownThoughtProtocol
    local tPort = port
    if nil==tPort then tPort=502 end
    local err, id = ModbusCreate(ip, tPort, 1)
    if 0==err then
        MyWelderDebugLog(Language.trLang("LASER_TCP_CONNECT_SUCCESS"))
        self.id = id
    elseif 1==err then
        MyWelderDebugLog(Language.trLang("LASER_MODBUS_CONNECT_MAX_ERR"))
    elseif 2==err then
        MyWelderDebugLog(Language.trLang("LASER_MODBUS_INIT_ERR"))
    elseif 3==err then
        MyWelderDebugLog(Language.trLang("LASER_MODBUS_MASTER_ERR"))
    else
        MyWelderDebugLog(Language.trLang("LASER_MODBUS_UNKNOW_ERR").."err="..tostring(err))
    end
    return 0==err
end

--[[
功能：断开是否已连接
参数：无
返回值：true-已连接，false-未连接
]]--
function CrownThoughtProtocol.isConnected()
    local self = CrownThoughtProtocol
    return nil~=self.id
end

--[[
功能：断开激光器的连接
参数：无
返回值：无
]]--
function CrownThoughtProtocol.disconnect()
    local self = CrownThoughtProtocol
    if nil~=self.id then
        ModbusClose(self.id)
        self.id = nil
        MyWelderDebugLog(Language.trLang("LASER_HAS_CLOSE"))
    end
end

---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
--[[
功能：焊缝多段模式选择（就是任务号）
参数：num任务号，0~63
返回值：true表示成功，false表示失败
]]--
function CrownThoughtProtocol.setTaskNumber(num)
    local self = CrownThoughtProtocol
    if type(num)~="number" then return false end
    if num<0 or num>63 then
        return false
    end
    local ret = SetHoldRegs(self.id, 0x1009, 1, {num}, "U16")
    return 0==ret
end

--[[
功能：打开、关闭激光
参数：无
返回值：true表示成功，false表示失败
]]--
function CrownThoughtProtocol.openLaser()
    local self = CrownThoughtProtocol
    local ret = SetHoldRegs(self.id, 0x1005, 1, {0x0000}, "U16")
    return 0==ret
end
function CrownThoughtProtocol.closeLaser()
    local self = CrownThoughtProtocol
    local ret = SetHoldRegs(self.id, 0x1005, 1, {0x00FF}, "U16")
    return 0==ret
end

--[[
功能：开始、停止跟踪
参数：无
返回值：true表示成功，false表示失败
]]--
function CrownThoughtProtocol.startTrack()
    local self = CrownThoughtProtocol
    local ret = SetHoldRegs(self.id, 0x1007, 1, {0x00FF}, "U16")
    return 0==ret
end
function CrownThoughtProtocol.stopTrack()
    local self = CrownThoughtProtocol
    local ret = SetHoldRegs(self.id, 0x1007, 1, {0x0000}, "U16")
    return 0==ret
end

--[[
功能：获取传感器的X、Y、Z、Rx、Ry、Rz值
参数：无
返回值：成功返回坐标值{x=1,y=1,z=1,rx=1,ry=1,rz=1}，xyz单位mm,Rxyz单位是角度deg，失败返回nil
]]--
function CrownThoughtProtocol.getLaserSensorPose()
    local self = CrownThoughtProtocol
    local data = GetHoldRegs(self.id, 0x1010, 3, "U16") or {}
    if #data~=3 then
        MyWelderDebugLog("GetHoldRegs read fail")
        return nil 
    end
    if CHelperTools.IsAllDataZero(data) then
        MyWelderDebugLog("Weld seam not found")
        return nil
    end
    local pose={}
    pose.x = CHelperTools.ToInt16(data[1])*0.1
    pose.y = CHelperTools.ToInt16(data[2])*0.1
    pose.z = CHelperTools.ToInt16(data[3])*0.1
    pose.rx = 0 --姿态值没有
    pose.ry = 0
    pose.rz = 0
    return pose
end

--[[
功能：获取经过标定转换机器人的X、Y、Z、Rx、Ry、Rz值
参数：无
返回值：成功返回坐标值{x=1,y=1,z=1,rx=1,ry=1,rz=1}，xyz单位mm,Rxyz单位是角度deg，失败返回nil
]]--
function CrownThoughtProtocol.getLaserRobotPose()
    local self = CrownThoughtProtocol
    local data = GetHoldRegs(self.id, 0x1018, 6, "U16") or {}
    if #data~=6 then
        MyWelderDebugLog("GetHoldRegs read fail")
        return nil 
    end
    if CHelperTools.IsAllDataZero(data) then
        MyWelderDebugLog("Weld seam not found")
        return nil
    end
    local pose={}
    pose.x = CHelperTools.ToInt16(data[1])*0.1
    pose.y = CHelperTools.ToInt16(data[2])*0.1
    pose.z = CHelperTools.ToInt16(data[3])*0.1
    pose.rx = CHelperTools.ToInt16(data[4])*0.01
    pose.ry = CHelperTools.ToInt16(data[5])*0.01
    pose.rz = CHelperTools.ToInt16(data[6])*0.01
    return pose
end

---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
--[[
功能：获取传感器状态
参数：无
返回值：true表示传感器有效，false表示传感器无效
]]--
function CrownThoughtProtocol.getSensorStatus()
    local self = CrownThoughtProtocol
    local data = GetHoldRegs(self.id, 0x1000, 1, "U16") or {}
    if #data<1 then
        MyWelderDebugLog("GetHoldRegs read fail")
        return false 
    end
    return data[1]&0x00FF==0x0000
end

--[[
功能：获取传感器曝光值
参数：无
返回值：成功返回实际值，失败返回nil
]]--
function CrownThoughtProtocol.getSensorExposureValue()
    local self = CrownThoughtProtocol
    local data = GetHoldRegs(self.id, 0x1001, 1, "U16") or {}
    if #data<1 then
        MyWelderDebugLog("GetHoldRegs read fail")
        return nil 
    end
    return data[1]&0x00FF
end

--[[
功能：获取传感器能力值
参数：无
返回值：成功返回实际值，失败返回nil
]]--
function CrownThoughtProtocol.getSensorAbilityValue()
    local self = CrownThoughtProtocol
    local data = GetHoldRegs(self.id, 0x1002, 1, "U16") or {}
    if #data<1 then
        MyWelderDebugLog("GetHoldRegs read fail")
        return nil 
    end
    return data[1]&0x00FF
end

--[[
功能：获取传感器输出比例值
参数：无
返回值：成功返回实际值，失败返回nil
]]--
function CrownThoughtProtocol.getSensorOutputRateValue()
    local self = CrownThoughtProtocol
    local data = GetHoldRegs(self.id, 0x1003, 1, "U16") or {}
    if #data<1 then
        MyWelderDebugLog("GetHoldRegs read fail")
        return nil 
    end
    return data[1]&0x00FF
end

--[[
功能：获取传感器检测模式值
参数：无
返回值：成功返回实际值，失败返回nil
]]--
function CrownThoughtProtocol.getSensorCheckModeValue()
    local self = CrownThoughtProtocol
    local data = GetHoldRegs(self.id, 0x1004, 1, "U16") or {}
    if #data<1 then
        MyWelderDebugLog("GetHoldRegs read fail")
        return nil 
    end
    return data[1]&0x00FF
end

--[[
功能：传感器输出值控制
参数：bOriginData-true表示传感器数据输出，false表示经过标定转换后的数据输出
返回值：true表示成功，false表示失败
]]--
function CrownThoughtProtocol.setSensorOutputCtrl(bSensorData)
    local self = CrownThoughtProtocol
    local num
    if bSensorData then
        num = 0x0000
    else
        num = 0x00FF
    end
    local ret = SetHoldRegs(self.id, 0x1008, 1, {num}, "U16")
    return 0==ret
end

--[[
功能：获取焊缝检测模式值
参数：无
返回值：成功返回实际值，失败返回nil
]]--
function CrownThoughtProtocol.getWeldLineCheckModeValue()
    local self = CrownThoughtProtocol
    local data = GetHoldRegs(self.id, 0x100A, 1, "U16") or {}
    if #data<1 then
        MyWelderDebugLog("GetHoldRegs read fail")
        return nil 
    end
    return data[1]&0x00FF
end

--[[
功能：获取焊缝宽度值
参数：无
返回值：成功返回float类型值，失败返回nil
]]--
function CrownThoughtProtocol.getWeldLineWidthValue()
    local self = CrownThoughtProtocol
    local data = GetHoldRegs(self.id, 0x1013, 1, "U16") or {}
    if #data<1 then
        MyWelderDebugLog("GetHoldRegs read fail")
        return nil 
    end
    return CHelperTools.ToInt16(data[1])*0.1
end

--[[
功能：获取焊缝根部间隙值
参数：无
返回值：成功返回float类型值，失败返回nil
]]--
function CrownThoughtProtocol.getWeldLineGapValue()
    local self = CrownThoughtProtocol
    local data = GetHoldRegs(self.id, 0x1014, 1, "U16") or {}
    if #data<1 then
        MyWelderDebugLog("GetHoldRegs read fail")
        return nil 
    end
    return CHelperTools.ToInt16(data[1])*0.1
end

--[[
功能：获取焊缝深度值
参数：无
返回值：成功返回float类型值，失败返回nil
]]--
function CrownThoughtProtocol.getWeldLineDeepValue()
    local self = CrownThoughtProtocol
    local data = GetHoldRegs(self.id, 0x1015, 1, "U16") or {}
    if #data<1 then
        MyWelderDebugLog("GetHoldRegs read fail")
        return nil 
    end
    return CHelperTools.ToInt16(data[1])*0.1
end

--[[
功能：获取焊缝左侧深度值
参数：无
返回值：成功返回float类型值，失败返回nil
]]--
function CrownThoughtProtocol.getWeldLineLeftDeepValue()
    local self = CrownThoughtProtocol
    local data = GetHoldRegs(self.id, 0x1016, 1, "U16") or {}
    if #data<1 then
        MyWelderDebugLog("GetHoldRegs read fail")
        return nil 
    end
    return CHelperTools.ToInt16(data[1])*0.1
end

--[[
功能：获取焊缝右侧深度值
参数：无
返回值：成功返回float类型值，失败返回nil
]]--
function CrownThoughtProtocol.getWeldLineRightDeepValue()
    local self = CrownThoughtProtocol
    local data = GetHoldRegs(self.id, 0x1017, 1, "U16") or {}
    if #data<1 then
        MyWelderDebugLog("GetHoldRegs read fail")
        return nil 
    end
    return CHelperTools.ToInt16(data[1])*0.1
end

return CrownThoughtProtocol