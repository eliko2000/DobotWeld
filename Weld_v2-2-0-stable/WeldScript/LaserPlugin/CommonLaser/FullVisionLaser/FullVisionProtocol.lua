--[[
苏州全视激光传感器modbus协议
]]--

--【本地私有接口】

---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
--【导出接口】
local FullVisionProtocol = {
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
function FullVisionProtocol.connect(ip,port)
    local self = FullVisionProtocol
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
function FullVisionProtocol.isConnected()
    local self = FullVisionProtocol
    return nil~=self.id
end

--[[
功能：断开激光器的连接
参数：无
返回值：无
]]--
function FullVisionProtocol.disconnect()
    local self = FullVisionProtocol
    if nil~=self.id then
        ModbusClose(self.id)
        self.id = nil
        MyWelderDebugLog(Language.trLang("LASER_HAS_CLOSE"))
    end
end

---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
--[[
功能：焊道样式选择（就是任务号）
参数：num任务号，0~63
返回值：true表示成功，false表示失败
]]--
function FullVisionProtocol.setTaskNumber(num)
    local self = FullVisionProtocol
    if type(num)~="number" then return false end
    if num<0 or num>255 then
        return false
    end
    local ret = SetHoldRegs(self.id, 0x0102, 1, {num}, "U16")
    return 0==ret
end

--[[
功能：打开、关闭激光
参数：无
返回值：true表示成功，false表示失败
]]--
function FullVisionProtocol.openLaser()
    local self = FullVisionProtocol
    local ret = SetHoldRegs(self.id, 0x0100, 1, {0x00FF}, "U16")
    return 0==ret
end
function FullVisionProtocol.closeLaser()
    local self = FullVisionProtocol
    local ret = SetHoldRegs(self.id, 0x0100, 1, {0x0000}, "U16")
    return 0==ret
end

--[[
功能：开始、停止跟踪
参数：无
返回值：true表示成功，false表示失败
]]--
function FullVisionProtocol.startTrack()
    local self = FullVisionProtocol
    local ret = SetHoldRegs(self.id, 0x0101, 1, {0x00FF}, "U16")
    return 0==ret
end
function FullVisionProtocol.stopTrack()
    local self = FullVisionProtocol
    local ret = SetHoldRegs(self.id, 0x0101, 1, {0x0000}, "U16")
    return 0==ret
end

--[[
功能：获取识别点在激光平面坐标系下的X、Y、Z、Rx、Ry、Rz值
参数：无
返回值：成功返回坐标值{x=1,y=1,z=1,rx=1,ry=1,rz=1}，xyz单位mm,Rxyz单位是角度deg，失败返回nil
]]--
function FullVisionProtocol.getLaserPose()
    local self = FullVisionProtocol
    local data = GetHoldRegs(self.id, 0x0002, 5, "U16") or {}
    if #data~=5 then
        MyWelderDebugLog("GetHoldRegs read fail")
        return nil 
    end
    if 0xFF ~= data[1] then --焊缝找不到
        MyWelderDebugLog("Weld seam not found")
        return nil
    end
    local pose={}
    pose.x = 0
    pose.y = CHelperTools.ToInt16(data[2])*0.01
    pose.z = CHelperTools.ToInt16(data[3])*0.01
    pose.rx = 0
    pose.ry = 0
    pose.rz = 0
    local width = CHelperTools.ToInt16(data[4])*0.01
    local height = CHelperTools.ToInt16(data[5])*0.01
    return pose
end

--[[
功能：获取识别点在工具坐标系下X、Y、Z、Rx、Ry、Rz值
参数：robotPose-机器人当前(激光照射)坐标位置，值为：{x=1,y=1,z=1,rx=1,ry=1,rz=1}
      bIsTrack-为true表示跟踪时候获取的值
返回值：成功返回坐标值{x=1,y=1,z=1,rx=1,ry=1,rz=1}，xyz单位mm,Rxyz单位是角度deg，失败返回nil
]]--
function FullVisionProtocol.getToolPose(robotPose, bIsTrack)
    local self = FullVisionProtocol
    local x = math.modf(robotPose.x*1000)
    local y = math.modf(robotPose.y*1000)
    local z = math.modf(robotPose.z*1000)
    local rx = math.modf(robotPose.rx*1000)
    local ry = math.modf(robotPose.ry*1000)
    local rz = math.modf(robotPose.rz*1000)
    local cmd = {}
    cmd[1] = x&0xFFFF
    cmd[2] = (x>>16)&0xFFFF
    cmd[3] = y&0xFFFF
    cmd[4] = (y>>16)&0xFFFF
    cmd[5] = z&0xFFFF
    cmd[6] = (z>>16)&0xFFFF
    cmd[7] = rx&0xFFFF
    cmd[8] = (rx>>16)&0xFFFF
    cmd[9] = ry&0xFFFF
    cmd[10] = (ry>>16)&0xFFFF
    cmd[11] = rz&0xFFFF
    cmd[12] = (rz>>16)&0xFFFF
    
    --先写入当前机器人坐标值
    local ret = SetHoldRegs(self.id, 350, #cmd, cmd, "U16")
    if ret~=0 then
        MyWelderDebugLog("SetHoldRegs write fail")
        return nil
    end
    
    --再获取焊缝坐标值
    cmd = GetHoldRegs(self.id, 400, 13, "U16") or {}
    if #cmd~=13 then
        MyWelderDebugLog("GetHoldRegs read fail")
        return nil 
    end
    
    --解析数据
    if 0xFF ~= cmd[1] then --焊缝坐标值无效
        MyWelderDebugLog("Weld seam not found")
        if true==bIsTrack then --表示跟踪时候想要获取的值
            return {x=0,y=0,z=0,rx=0,ry=0,rz=0} --图像识别失败默认给0，算法自己处理，主要是为了解决焊缝末端，激光扫描到焊缝外面的问题。
        end
        return nil
    end
    x = cmd[3]&0xFFFF
    x = x<<16
    x = x | (cmd[2]&0xFFFF)
    y = cmd[5]&0xFFFF
    y = y<<16
    y = y | (cmd[4]&0xFFFF)
    z = cmd[7]&0xFFFF
    z = z<<16
    z = z | (cmd[6]&0xFFFF)
    rx = cmd[9]&0xFFFF
    rx = x<<16
    rx = rx | (cmd[8]&0xFFFF)
    ry = cmd[11]&0xFFFF
    ry = ry<<16
    ry = ry | (cmd[10]&0xFFFF)
    rz = cmd[13]&0xFFFF
    rz = rz<<16
    rz = rz | (cmd[12]&0xFFFF)
    
    --转换计算
    local pose={}
    pose.x = CHelperTools.ToInt32(x)*0.001
    pose.y = CHelperTools.ToInt32(y)*0.001
    pose.z = CHelperTools.ToInt32(z)*0.001
    pose.rx = CHelperTools.ToInt32(rx)*0.001
    pose.ry = CHelperTools.ToInt32(ry)*0.001
    pose.rz = CHelperTools.ToInt32(rz)*0.001
    return pose
end

---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
--标定相关的
local function innerRecordCalibrate(self, robotPose, id)
    local x = math.modf(robotPose.x*1000)
    local y = math.modf(robotPose.y*1000)
    local z = math.modf(robotPose.z*1000)
    local rx = math.modf(robotPose.rx*1000)
    local ry = math.modf(robotPose.ry*1000)
    local rz = math.modf(robotPose.rz*1000)
    local cmd = {}
    cmd[1] = id
    cmd[2] = x&0xFFFF
    cmd[3] = (x>>16)&0xFFFF
    cmd[4] = y&0xFFFF
    cmd[5] = (y>>16)&0xFFFF
    cmd[6] = z&0xFFFF
    cmd[7] = (z>>16)&0xFFFF
    cmd[8] = rx&0xFFFF
    cmd[9] = (rx>>16)&0xFFFF
    cmd[10] = ry&0xFFFF
    cmd[11] = (ry>>16)&0xFFFF
    cmd[12] = rz&0xFFFF
    cmd[13] = (rz>>16)&0xFFFF
    local ret = SetHoldRegs(self.id, 300, #cmd, cmd, "U16")
    return 0==ret
end
--[[
功能：记录tcp尖点坐标
参数：robotPose-机器人当前(激光照射)坐标位置，值为：{x=1,y=1,z=1,rx=1,ry=1,rz=1}
返回值：true表示成功，false表示失败
]]--
function FullVisionProtocol.recordTCPPose(robotPose)
    local self = FullVisionProtocol
    return innerRecordCalibrate(self, robotPose, 1)
end

--[[
功能：记录传感器扫描位置1坐标
参数：robotPose-机器人当前(激光照射)坐标位置，值为：{x=1,y=1,z=1,rx=1,ry=1,rz=1}
返回值：true表示成功，false表示失败
]]--
function FullVisionProtocol.recordScanPose1(robotPose)
    local self = FullVisionProtocol
    return innerRecordCalibrate(self, robotPose, 2)
end

--[[
功能：记录传感器扫描位置2坐标
参数：robotPose-机器人当前(激光照射)坐标位置，值为：{x=1,y=1,z=1,rx=1,ry=1,rz=1}
返回值：true表示成功，false表示失败
]]--
function FullVisionProtocol.recordScanPose2(robotPose)
    local self = FullVisionProtocol
    return innerRecordCalibrate(self, robotPose, 3)
end

--[[
功能：记录传感器扫描位置3坐标
参数：robotPose-机器人当前(激光照射)坐标位置，值为：{x=1,y=1,z=1,rx=1,ry=1,rz=1}
返回值：true表示成功，false表示失败
]]--
function FullVisionProtocol.recordScanPose3(robotPose)
    local self = FullVisionProtocol
    return innerRecordCalibrate(self, robotPose, 4)
end

--[[
功能：记录传感器扫描位置4坐标
参数：robotPose-机器人当前(激光照射)坐标位置，值为：{x=1,y=1,z=1,rx=1,ry=1,rz=1}
返回值：true表示成功，false表示失败
]]--
function FullVisionProtocol.recordScanPose4(robotPose)
    local self = FullVisionProtocol
    return innerRecordCalibrate(self, robotPose, 5)
end

return FullVisionProtocol