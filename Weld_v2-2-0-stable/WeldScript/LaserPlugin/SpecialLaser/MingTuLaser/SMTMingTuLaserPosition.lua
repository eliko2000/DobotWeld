--[[
苏州明图智能激光传感器modbus协议，激光寻位功能封装
]]--

--【本地私有接口】

---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
--【导出接口】
local SMTMingTuLaserPosition = {
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
function SMTMingTuLaserPosition.connect(ip,port)
    local self = SMTMingTuLaserPosition
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
function SMTMingTuLaserPosition.isConnected()
    local self = SMTMingTuLaserPosition
    return nil~=self.id
end

--[[
功能：断开激光器的连接
参数：无
返回值：无
]]--
function SMTMingTuLaserPosition.disconnect()
    local self = SMTMingTuLaserPosition
    if nil~=self.id then
        ModbusClose(self.id)
        self.id = nil
        MyWelderDebugLog(Language.trLang("LASER_HAS_CLOSE"))
    end
end

---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
--[[
功能：检查识别结果是否正常
参数：无
返回值：true表示检测成功，false表示检测失败
]]--
function SMTMingTuLaserPosition.isDetectSuccess()
    local self = SMTMingTuLaserPosition
    local data = GetHoldRegs(self.id, 0x0010, 1, "U16") or {}
    if #data<1 then
        MyWelderDebugLog(Language.trLang("LASER_COMM_ERR_NO_RESULT"))
        return false 
    end
    return 0x0001==data[1]
end

--[[
功能：获取识别点在激光平面坐标系下的X、Y、Z、Rx、Ry、Rz值
参数：无
返回值：成功返回坐标值{x=1,y=1,z=1,rx=1,ry=1,rz=1}，xyz单位mm,Rxyz单位是角度deg，失败返回nil
]]--
function SMTMingTuLaserPosition.getLaserPose()
    local self = SMTMingTuLaserPosition
    local data = GetHoldRegs(self.id, 0x0011, 6, "U16") or {}
    if #data~=6 then
        MyWelderDebugLog(Language.trLang("LASER_COMM_ERR_NO_COORD"))
        return nil 
    end
    if CHelperTools.IsAllDataZero(data) then
        MyWelderDebugLog(Language.trLang("LASER_NO_LASER_COORD"))
        return nil
    end
    local pose={}
    pose.x = CHelperTools.ToInt16(data[1])*0.01
    pose.y = CHelperTools.ToInt16(data[2])*0.01
    pose.z = CHelperTools.ToInt16(data[3])*0.01
    pose.rx = CHelperTools.ToInt16(data[4])*0.001
    pose.ry = CHelperTools.ToInt16(data[5])*0.001
    pose.rz = CHelperTools.ToInt16(data[6])*0.001
    return pose
end

--[[
功能：获取识别点在工具坐标系下X、Y、Z、Rx、Ry、Rz值
参数：无
返回值：成功返回坐标值{x=1,y=1,z=1,rx=1,ry=1,rz=1}，xyz单位mm,Rxyz单位是角度deg，失败返回nil
]]--
function SMTMingTuLaserPosition.getToolPose()
    local self = SMTMingTuLaserPosition
    local data = GetHoldRegs(self.id, 0x0017, 6, "U16") or {}
    if #data~=6 then
        MyWelderDebugLog(Language.trLang("LASER_COMM_ERR_NO_TOOL"))
        return nil 
    end
    if CHelperTools.IsAllDataZero(data) then
        MyWelderDebugLog(Language.trLang("LASER_NO_TOOL_COORD"))
        return nil
    end
    local pose={}
    pose.x = CHelperTools.ToInt16(data[1])*0.01
    pose.y = CHelperTools.ToInt16(data[2])*0.01
    pose.z = CHelperTools.ToInt16(data[3])*0.01
    pose.rx = CHelperTools.ToInt16(data[4])*0.001
    pose.ry = CHelperTools.ToInt16(data[5])*0.001
    pose.rz = CHelperTools.ToInt16(data[6])*0.001
    return pose
end

--[[
功能：获取间隙值
参数：无
返回值：成功值，单位mm，失败返回nil
]]--
function SMTMingTuLaserPosition.getGapValue()
    local self = SMTMingTuLaserPosition
    local data = GetHoldRegs(self.id, 0x001D, 1, "U16") or {}
    if #data<1 then
        MyWelderDebugLog(Language.trLang("LASER_COMM_ERR_NO_GRAP"))
        return nil 
    end
    return CHelperTools.ToInt16(data[1])*0.01
end

--[[
功能：获取错边偏移值
参数：无
返回值：成功值，单位mm，失败返回nil
]]--
function SMTMingTuLaserPosition.getOffsetValue()
    local self = SMTMingTuLaserPosition
    local data = GetHoldRegs(self.id, 0x001E, 1, "U16") or {}
    if #data<1 then
        MyWelderDebugLog(Language.trLang("LASER_COMM_ERR_NO_OFFSET"))
        return nil 
    end
    return CHelperTools.ToInt16(data[1])*0.01
end

--[[
功能：获取面积值
参数：无
返回值：成功值，单位mm2，失败返回nil
]]--
function SMTMingTuLaserPosition.getSqureValue()
    local self = SMTMingTuLaserPosition
    local data = GetHoldRegs(self.id, 0x001F, 1, "U16") or {}
    if #data<1 then
        MyWelderDebugLog(Language.trLang("LASER_COMM_ERR_NO_AREA"))
        return nil 
    end
    return CHelperTools.ToInt16(data[1])*0.01
end

---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
--[[
功能：设置任务号
参数：num任务号，0~199
返回值：true表示成功，false表示失败
]]--
function SMTMingTuLaserPosition.setTaskNumber(num)
    local self = SMTMingTuLaserPosition
    if type(num)~="number" then return false end
    if num<0 or num>199 then
        MyWelderDebugLog(Language.trLang("LASER_TASK_NUMBER_ERR").."0~199")
        return false
    end
    local ret = SetHoldRegs(self.id, 0x0000, 1, {num}, "U16")
    return 0==ret
end

--[[
功能：打开、关闭激光
参数：无
返回值：true表示成功，false表示失败
]]--
function SMTMingTuLaserPosition.openLaser()
    local self = SMTMingTuLaserPosition
    local ret = SetHoldRegs(self.id, 0x0001, 1, {0x00FF}, "U16")
    return 0==ret
end
function SMTMingTuLaserPosition.closeLaser()
    local self = SMTMingTuLaserPosition
    local ret = SetHoldRegs(self.id, 0x0001, 1, {0x0000}, "U16")
    return 0==ret
end

--[[
功能：开始、停止寻位
参数：无
返回值：true表示成功，false表示失败
]]--
function SMTMingTuLaserPosition.startPosition()
    local self = SMTMingTuLaserPosition
    local ret = SetHoldRegs(self.id, 0x0002, 1, {0x00FF}, "U16")
    return 0==ret
end
function SMTMingTuLaserPosition.stopPosition()
    local self = SMTMingTuLaserPosition
    local ret = SetHoldRegs(self.id, 0x0002, 1, {0x0000}, "U16")
    return 0==ret
end

--[[
功能：开始、停止跟踪
参数：无
返回值：true表示成功，false表示失败
]]--
function SMTMingTuLaserPosition.startTrack()
    local self = SMTMingTuLaserPosition
    local ret = SetHoldRegs(self.id, 0x0003, 1, {0x00FF}, "U16")
    return 0==ret
end
function SMTMingTuLaserPosition.stopTrack()
    local self = SMTMingTuLaserPosition
    local ret = SetHoldRegs(self.id, 0x0003, 1, {0x0000}, "U16")
    return 0==ret
end

---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
--[[
功能：设置机器人坐标X、Y、Z、Rx、Ry、Rz值
参数：pose-机器人位姿，格式为：{x=1,y=1,z=1,rx=1,ry=1,rz=1}
返回值：true表示成功，false表示失败
]]--
function SMTMingTuLaserPosition.setRobotPose(pose)
    local self = SMTMingTuLaserPosition
    local sendData = {}
    local tmpPose = {pose.x,pose.y,pose.z,pose.rx,pose.ry,pose.rz}
    for i=1,#tmpPose do
        local v = math.modf(tmpPose[i]*1000) --取整数部分，舍掉小数
        local vL = v&0x0000FFFF
        local vH = (v>>16)&0x0000FFFF
        table.insert(sendData,vL)
        table.insert(sendData,vH)
    end
    local ret = SetHoldRegs(self.id, 0x0020, 12, sendData, "U16")
    return 0==ret
end

return SMTMingTuLaserPosition