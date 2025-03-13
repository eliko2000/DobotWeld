--[[
【暂时保留不使用】
唐山英莱激光传感器通用版tcp协议封装
]]--

--【本地私有接口】
--获取下一个编号
local function innerGetNextIdx(self)
    self.packIndex = self.packIndex+1
    if self.packIndex>255 then
        self.packIndex = 0
    end
    return self.packIndex
end

--组装协议数据包
local function innerBuildCmd(self)
    local v = 0x00
    self.packAllCmd[1] = 0x49 --包头
    self.packAllCmd[2] = innerGetNextIdx(self)&0xFF --数据包编号
    self.packAllCmd[3] = 0x00 --功能类型(简版功能)，固定值
    self.packAllCmd[4] = self.cmd&0xFF --指令字节
    self.packAllCmd[5] = self.gapNumberCmd&0xFF
    for i=6,67 do --预留值，填充为0
        self.packAllCmd[i] = 0x00
    end
    self.packAllCmd[68] = 0x4C --包尾
end

--发送数据给激光器，成功返回true，失败false
local function innerSendData(self)
    if nil==self.sock then return false end
    local err = TCPWrite(self.sock, self.packAllCmd, 4)
    if err~=0 then
        MyWelderDebugLog("TCPWrite send laser data fail")
        return false
    end
    return true
end

--读取激光器数据，成功返回字节数据数组,失败返回nil
local function innerReadData(self)
    --[[协议文档说：通信周期不可小于10ms,推荐40ms，激光器回复79个字节，激光器超过200ms未回复可认为超时]]--
    if nil==self.sock then
        return nil
    end
    local recvBuf = {}
    local err,data
    local begTime = Systime()
    local endTime = begTime
    while endTime-begTime<=3000 do
        err,data = TCPRead(self.sock, 1)
        if err~=0 then
            --MyWelderDebugLog("TCPRead read laser data fail")
            Wait(10)
        else
            for i=1,#data do
                table.insert(recvBuf,data[i])
            end
            if #recvBuf>=79 then
                return recvBuf
            end
        end
        endTime = Systime()
    end
    return nil
end

--根据错误码返回错误信息
local function innerGetErrCodeMsg(code)
    if 0x00==code then return Language.trLang("LASER_CODE_NO")
    elseif 0x03==code then return Language.trLang("LASER_CODE_IDERR")
    elseif 0x04==code then return Language.trLang("LASER_CODE_OUT_RANGE")
    elseif 0x05==code then return Language.trLang("LASER_CODE_IMG")
    elseif 0x06==code then return Language.trLang("LASER_CODE_SAVE_ERR")
    elseif 0x07==code then return Language.trLang("LASER_CODE_NO_ID")
    elseif 0x08==code then return Language.trLang("LASER_CODE_TP_ERR")
    elseif 0x09==code then return Language.trLang("LASER_CODE_TCP_ERR")
    elseif 0x0A==code then return Language.trLang("LASER_CODE_NO_FILE")
    elseif 0x0B==code then return Language.trLang("LASER_CODE_OFFSET_ERR")
    elseif 0x0C==code then return Language.trLang("LASER_CODE_INPUT_ERR")
    elseif 0x0D==code then return Language.trLang("LASER_CODE_NO_PRG")
    elseif 0x0E==code then return Language.trLang("LASER_CODE_FILE_NODATA")
    elseif 0x0F==code then return Language.trLang("LASER_CODE_COORD_ERR")
    elseif 0x10==code then return Language.trLang("LASER_CODE_STEP_ERR")
    elseif 0x11==code then return Language.trLang("LASER_CODE_COORD_ERR")
    elseif 0x12==code then return Language.trLang("LASER_CODE_NO_GRAP")
    elseif 0x13==code then return Language.trLang("LASER_CODE_LOST_GRAP")
    elseif 0x14==code then return Language.trLang("LASER_CODE_EULER")
    elseif 0x15==code then return Language.trLang("LASER_CODE_CALC_FAIL")
    elseif 0x66==code then return Language.trLang("LASER_CODE_PACK_ERR")
    elseif 0x67==code then return Language.trLang("LASER_CODE_PTRO_ERR")
    elseif 0x70==code then return Language.trLang("LASER_CODE_SENSOR_ERR")
    elseif 0x71==code then return Language.trLang("LASER_CODE_NO_INSTALL")
    elseif 0x72==code then return Language.trLang("LASER_CODE_TEMP_ERR")
    else return Language.trLang("LASER_CODE_RESERVE")..string.format(":%X",code)
    end
end

---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
--【导出接口】
local IntelligenLaserSimpleProtocol = {
    sock = nil, --sock成功连接的句柄
    packIndex = 0, --包计数编号，单字节，0~255
    cmd = 0xF0, --指令，单字节，不同功能值不一样
    gapNumberCmd = 0x01, --焊缝编号，单字节，不同焊缝编号值不一样，范围1-30
    packAllCmd = {} --打包命令，固定68字节，待发送的所有数据存在这里
}

---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
--[[
功能：通过tcp方式连接激光器
参数：ip-地址,
      port-端口，传nil或不传则默认为5020
返回值：true表示成功，false表示失败
]]--
function IntelligenLaserSimpleProtocol.connect(ip,port)
    local self = IntelligenLaserSimpleProtocol
    local tPort = port
    if nil==tPort then tPort=5020 end
    local err, sock = TCPCreate(false, ip, tPort)
    if 0==err then
        MyWelderDebugLog(Language.trLang("LASER_TCP_CONN_OK"))
    else 
        MyWelderDebugLog(Language.trLang("LASER_TCP_CONN_ERR")..":err="..tostring(err))
        return false
    end
    MyWelderDebugLog(Language.trLang("LASER_TCP_CONNECTING"))
    err = TCPStart(sock, 5)
    if 0~=err then
        TCPDestroy(sock)
        MyWelderDebugLog(Language.trLang("LASER_TCP_CONNECT_FAIL"))
        return false
    end
    MyWelderDebugLog(Language.trLang("LASER_TCP_CONNECT_SUCCESS"))
    self.sock = sock
    return true
end

--[[
功能：断开是否已连接
参数：无
返回值：true-已连接，false-未连接
]]--
function IntelligenLaserSimpleProtocol.isConnected()
    local self = IntelligenLaserSimpleProtocol
    return nil~=self.sock
end

--[[
功能：断开激光器的连接
参数：无
返回值：无
]]--
function IntelligenLaserSimpleProtocol.disconnect()
    local self = IntelligenLaserSimpleProtocol
    if nil~=self.sock then
        TCPDestroy(self.sock)
        self.sock = nil
    end
end

---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
--[[
功能：设置待切换的焊缝类型编号（就是任务号）
参数：num任务号，0~63
返回值：true表示成功，false表示失败
]]--
function IntelligenLaserSimpleProtocol.setTaskNumber(num)
    local self = IntelligenLaserSimpleProtocol
    if iNumber<1 or iNumber>30 then
        return false
    end
    self.gapNumberCmd = iNumber
    self.cmd = 0xF3
    innerBuildCmd(self)
    if not innerSendData(self) then
        MyWelderDebugLog(Language.trLang("LASER_GRAP_CHANGE_SEND_ERR"))
        return false
    end
    local recvData = innerReadData(self)
    if nil==recvData then
        MyWelderDebugLog(Language.trLang("LASER_GRAP_CHANGE_READ_ERR"))
        return false
    end
    if 0xFF==recvData[3] then
        MyWelderDebugLog(Language.trLang("LASER_GRAP_CHANGE_ERR") .. string.format("d[3]=0x%02X,d[4]=0x%02X,%s",recvData[3],recvData[4],innerGetErrCodeMsg(recvData[4])))
        return false
    end
    return true
end

--[[
功能：打开、关闭激光
参数：无
返回值：true表示成功，false表示失败
]]--
function IntelligenLaserSimpleProtocol.openLaser()
    local self = IntelligenLaserSimpleProtocol
    self.cmd = 0xF1
    innerBuildCmd(self)
    if not innerSendData(self) then
        MyWelderDebugLog(Language.trLang("LASER_OPEN_SEND_ERR"))
        return false
    end
    local recvData = innerReadData(self)
    if nil==recvData then
        MyWelderDebugLog(Language.trLang("LASER_OPEN_READ_ERR"))
        return false
    end
    if 0xFF==recvData[3] then
        MyWelderDebugLog(Language.trLang("LASER_OPEN_ERR") .. string.format(":d[3]=0x%02X,d[4]=0x%02X,%s",recvData[3],recvData[4],innerGetErrCodeMsg(recvData[4])))
        return false
    end
    return true
end
function IntelligenLaserSimpleProtocol.closeLaser()
    local self = IntelligenLaserSimpleProtocol
    self.cmd = 0xF2
    innerBuildCmd(self)
    if not innerSendData(self) then
        MyWelderDebugLog(Language.trLang("LASER_CLOSE_SEND_ERR"))
        return false
    end
    local recvData = innerReadData(self)
    if nil==recvData then
        MyWelderDebugLog(Language.trLang("LASER_CLOSE_READ_ERR"))
        return false
    end
    if 0xFF==recvData[3] then
        MyWelderDebugLog(Language.trLang("LASER_CLOSE_ERR") .. string.format(":d[3]=0x%02X,d[4]=0x%02X,%s",recvData[3],recvData[4],innerGetErrCodeMsg(recvData[4])))
        return false
    end
    return true
end

--[[
功能：获取传感器测量数据(基于传感器坐标系)X、Y、Z、Rx、Ry、Rz值
参数：无
返回值：成功返回坐标值{x=1,y=1,z=1,rx=1,ry=1,rz=1}，xyz单位mm,Rxyz单位是角度deg，失败返回nil
]]--
function IntelligenLaserSimpleProtocol.getLaserSensorPose()
    local self = IntelligenLaserSimpleProtocol
    self.cmd = 0x01
    innerBuildCmd(self)
    if not innerSendData(self) then
        MyWelderDebugLog("send data fail")
        return nil
    end
    local recvData = innerReadData(self)
    if nil==recvData then
        MyWelderDebugLog("read data fail")
        return nil
    end
    if 0xFF==recvData[3] then
        MyWelderDebugLog("result error:" .. string.format("d[3]=0x%02X,d[4]=0x%02X,%s",recvData[3],recvData[4],innerGetErrCodeMsg(recvData[4])))
        return nil
    end
    --7~18为原始数据，short类型，依此是 X、Y、Z、焊缝间隙(GAP)、错边量(MISMATCH)、面积(AREA)
    local resultValue = {0,0,0,0,0,0}
    local v = 0
    local idx = 7
    for i=1,6 do
        v = recvData[idx]&0xFF
        v = v<<8
        v = v | (recvData[idx+1]&0xFF)
        resultValue[i] = CHelperTools.ToInt16(v)*0.01
        idx = idx+2
    end
    --返回结果值
    local resultPose = {}
    resultPose.x = resultValue[1]
    resultPose.y = resultValue[2]
    resultPose.z = resultValue[3]
    resultPose.rx = 0 --姿态值没有
    resultPose.ry = 0
    resultPose.rz = 0
    --resultValue[4] 焊缝间隙(GAP)
    --resultValue[5] 错边量(MISMATCH)
    --resultValue[6] 面积(AREA)
    return resultPose
end

--[[
功能：停止获取传感器测量数据
参数：无
返回值：true表示成功，false表示失败
]]--
function IntelligenLaserSimpleProtocol.stopGetLaserSensorPose()
    local self = IntelligenLaserSimpleProtocol
    self.cmd = 0x00
    innerBuildCmd(self)
    if not innerSendData(self) then
        MyWelderDebugLog("send data fail")
        return false
    end
    local recvData = innerReadData(self)
    if nil==recvData then
        MyWelderDebugLog("read data fail")
        return false
    end
    if 0xFF==recvData[3] then
        MyWelderDebugLog("result error:" .. string.format("d[3]=0x%02X,d[4]=0x%02X,%s",recvData[3],recvData[4],innerGetErrCodeMsg(recvData[4])))
        return false
    end
    return true
end

return IntelligenLaserSimpleProtocol