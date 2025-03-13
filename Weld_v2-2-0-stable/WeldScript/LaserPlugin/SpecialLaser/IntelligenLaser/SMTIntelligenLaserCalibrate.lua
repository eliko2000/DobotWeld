--[[
英莱激光传感器tcp协议，标定协议封装
标定使用步骤
laserObj.connect(ip,port)
laserObj.setTaskNumber(编号)
if not laserObj.initLaser() then goto labelExit end
laserObj.setRobotPose(机器人位置)
if not laserObj.recordTCPPose() then goto labelExit end
laserObj.setRobotPose(机器人位置)
if not laserObj.recordScanPose1() then goto labelExit end
laserObj.setRobotPose(机器人位置)
if not laserObj.recordScanPose2() then goto labelExit end
laserObj.setRobotPose(机器人位置)
if not laserObj.recordScanPose3() then goto labelExit end
laserObj.setRobotPose(机器人位置)
if not laserObj.recordScanPose4() then goto labelExit end
laserObj.setRobotPose(机器人位置)
local resultPose = laserObj.checkRobotPose()
if nil==resultPose then goto labelExit end
MovL(resultPose) --记得这个要修改为运动指令对应的参数格式哦
::labelExit::
laserObj.disconnect()
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
    self.packAllCmd[3] = 0x01 --标定功能，固定值
    self.packAllCmd[4] = self.cmd&0xFF --指令字节
    self.packAllCmd[5] = self.gapNumberCmd&0xFF
    self.packAllCmd[6] = self.eulerAngleCmd&0xFF
    for i=7,30 do
        v = self.robotPoseCmd[i-6]
        if nil==v then
            self.packAllCmd[i] = 0x00
        else
            self.packAllCmd[i] = v&0xFF
        end
    end
    for i=31,67 do --预留值，填充为0
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
    elseif 0x05==code then return Language.trLang("LASER_CODE_IMG")
    elseif 0x10==code then return Language.trLang("LASER_CODE_STEP_ERR")
    elseif 0x14==code then return Language.trLang("LASER_CODE_EULER")
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
local SMTIntelligenLaserCalibrate = {
    sock = nil, --sock成功连接的句柄
    packIndex = 0, --包计数编号，单字节，0~255
    cmd = 0xF0, --指令，单字节，不同功能值不一样
    gapNumberCmd = 0x01, --焊缝编号，单字节，不同焊缝编号值不一样，范围1-30
    eulerAngleCmd = 0x01, --欧拉角类型，固定为0x01，单字节。0x00表示XYZ，0x01表示ZYX，0x02表示ZYZ'。
    robotPoseCmd = {}, --机器人当前坐标值，24个字节
    packAllCmd = {} --打包命令，固定68字节，待发送的所有数据存在这里
}

---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
---激光器的连接与断开操作--------------------------------------------------------
function SMTIntelligenLaserCalibrate.connect(ip,port)
    local self = SMTIntelligenLaserCalibrate
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

function SMTIntelligenLaserCalibrate.isConnected()
    local self = SMTIntelligenLaserCalibrate
    return nil~=self.sock
end

function SMTIntelligenLaserCalibrate.disconnect()
    local self = SMTIntelligenLaserCalibrate
    if nil~=self.sock then
        TCPDestroy(self.sock)
        self.sock = nil
    end
end

---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
---以下是一些参数的设置，仅仅只是参数的设置不与激光器通信------------------------
--[[
功能：设置待切换的焊缝类型编号
参数：iNumber-编号，范围1-30
返回值：true表示成功，false表示失败
]]--
function SMTIntelligenLaserCalibrate.setTaskNumber(iNumber)
    local self = SMTIntelligenLaserCalibrate
    if iNumber<1 or iNumber>30 then
        MyWelderDebugLog(Language.trLang("LASER_GRAP_OUT_RANGE").."[1,30]")
        return false
    else
        self.gapNumberCmd = iNumber
        return true
    end
end

--[[
功能：设置机器人当前坐标位置
参数：pose-位置，值为：{x=1,y=1,z=1,rx=1,ry=1,rz=1}
返回值：无
]]--
function SMTIntelligenLaserCalibrate.setRobotPose(pose)
    local self = SMTIntelligenLaserCalibrate
    local x = math.modf(pose.x*100)
    local y = math.modf(pose.y*100)
    local z = math.modf(pose.z*100)
    local rx = math.modf(pose.rx*100)
    local ry = math.modf(pose.ry*100)
    local rz = math.modf(pose.rz*100)
    --因为欧拉角选择的是ZYX旋转顺序的，所以字节顺序是rz,ry,rx
    local tpoint = {x,y,z,rz,ry,rx}
    local idx = 1
    for i=1,#tpoint do
        local v = tpoint[i]
        self.robotPoseCmd[idx] = (v>>24)&0xFF
        idx = idx+1
        self.robotPoseCmd[idx] = (v>>16)&0xFF
        idx = idx+1
        self.robotPoseCmd[idx] = (v>>8)&0xFF
        idx = idx+1
        self.robotPoseCmd[idx] = v&0xFF
        idx = idx+1
    end
end

---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
---以下是一些命令的操作，与激光器通信--------------------------------------------
--[[
功能：打开、关闭激光
参数：无
返回值：true表示成功，false表示失败
]]--
function SMTIntelligenLaserCalibrate.openLaser()
    local self = SMTIntelligenLaserCalibrate
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
function SMTIntelligenLaserCalibrate.closeLaser()
    local self = SMTIntelligenLaserCalibrate
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
功能：切换焊缝类型
参数：无
返回值：true表示成功，false表示失败
]]--
function SMTIntelligenLaserCalibrate.changeGapType()
    local self = SMTIntelligenLaserCalibrate
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
功能：初始化激光器
参数：无
返回值：true表示成功，false表示失败
]]--
function SMTIntelligenLaserCalibrate.initLaser()
    local self = SMTIntelligenLaserCalibrate
    self.cmd = 0x10
    innerBuildCmd(self)
    if not innerSendData(self) then
        MyWelderDebugLog(Language.trLang("LASER_INIT_SEND_ERR"))
        return false
    end
    local recvData = innerReadData(self)
    if nil==recvData then
        MyWelderDebugLog(Language.trLang("LASER_INIT_READ_ERR"))
        return false
    end
    if 0xFF==recvData[3] then
        MyWelderDebugLog(Language.trLang("LASER_INIT_ERR") .. string.format("d[3]=0x%02X,d[4]=0x%02X,%s",recvData[3],recvData[4],innerGetErrCodeMsg(recvData[4])))
        return false
    end
    return true
end

--[[
功能：记录tcp尖点坐标
参数：无
返回值：true表示成功，false表示失败
说明：调用此接口前，先要调用`setRobotPose`接口传入机器人当前位姿
]]--
function SMTIntelligenLaserCalibrate.recordTCPPose()
    local self = SMTIntelligenLaserCalibrate
    self.cmd = 0x11
    innerBuildCmd(self)
    if not innerSendData(self) then
        MyWelderDebugLog(Language.trLang("LASER_TCP_COORD_SEND_ERR"))
        return false
    end
    local recvData = innerReadData(self)
    if nil==recvData then
        MyWelderDebugLog(Language.trLang("LASER_TCP_COORD_READ_ERR"))
        return false
    end
    if 0xFF==recvData[3] then
        MyWelderDebugLog(Language.trLang("LASER_TCP_COORD_ERR") .. string.format("d[3]=0x%02X,d[4]=0x%02X,%s",recvData[3],recvData[4],innerGetErrCodeMsg(recvData[4])))
        return false
    end
    return true
end

--[[
功能：记录传感器扫描位置1坐标
参数：无
返回值：true表示成功，false表示失败
说明：调用此接口前，先要调用`setRobotPose`接口传入机器人当前位姿
]]--
function SMTIntelligenLaserCalibrate.recordScanPose1()
    local self = SMTIntelligenLaserCalibrate
    self.cmd = 0x12
    innerBuildCmd(self)
    if not innerSendData(self) then
        MyWelderDebugLog(Language.trLang("LASER_SCAN1_SEND_ERR"))
        return false
    end
    local recvData = innerReadData(self)
    if nil==recvData then
        MyWelderDebugLog(Language.trLang("LASER_SCAN1_READ_ERR"))
        return false
    end
    if 0xFF==recvData[3] then
        MyWelderDebugLog(Language.trLang("LASER_SCAN1_ERR") .. string.format("d[3]=0x%02X,d[4]=0x%02X,%s",recvData[3],recvData[4],innerGetErrCodeMsg(recvData[4])))
        return false
    end
    return true
end

--[[
功能：记录传感器扫描位置2坐标
参数：无
返回值：true表示成功，false表示失败
说明：调用此接口前，先要调用`setRobotPose`接口传入机器人当前位姿
]]--
function SMTIntelligenLaserCalibrate.recordScanPose2()
    local self = SMTIntelligenLaserCalibrate
    self.cmd = 0x13
    innerBuildCmd(self)
    if not innerSendData(self) then
        MyWelderDebugLog(Language.trLang("LASER_SCAN2_SEND_ERR"))
        return false
    end
    local recvData = innerReadData(self)
    if nil==recvData then
        MyWelderDebugLog(Language.trLang("LASER_SCAN2_READ_ERR"))
        return false
    end
    if 0xFF==recvData[3] then
        MyWelderDebugLog(Language.trLang("LASER_SCAN2_ERR") .. string.format("d[3]=0x%02X,d[4]=0x%02X,%s",recvData[3],recvData[4],innerGetErrCodeMsg(recvData[4])))
        return false
    end
    return true
end

--[[
功能：记录传感器扫描位置3坐标
参数：无
返回值：true表示成功，false表示失败
说明：调用此接口前，先要调用`setRobotPose`接口传入机器人当前位姿
]]--
function SMTIntelligenLaserCalibrate.recordScanPose3()
    local self = SMTIntelligenLaserCalibrate
    self.cmd = 0x14
    innerBuildCmd(self)
    if not innerSendData(self) then
        MyWelderDebugLog(Language.trLang("LASER_SCAN3_SEND_ERR"))
        return false
    end
    local recvData = innerReadData(self)
    if nil==recvData then
        MyWelderDebugLog(Language.trLang("LASER_SCAN3_READ_ERR"))
        return false
    end
    if 0xFF==recvData[3] then
        MyWelderDebugLog(Language.trLang("LASER_SCAN3_ERR") .. string.format("d[3]=0x%02X,d[4]=0x%02X,%s",recvData[3],recvData[4],innerGetErrCodeMsg(recvData[4])))
        return false
    end
    return true
end

--[[
功能：记录传感器扫描位置4坐标
参数：无
返回值：true表示成功，false表示失败
说明：调用此接口前，先要调用`setRobotPose`接口传入机器人当前位姿
]]--
function SMTIntelligenLaserCalibrate.recordScanPose4()
    local self = SMTIntelligenLaserCalibrate
    self.cmd = 0x15
    innerBuildCmd(self)
    if not innerSendData(self) then
        MyWelderDebugLog(Language.trLang("LASER_SCAN4_SEND_ERR"))
        return false
    end
    local recvData = innerReadData(self)
    if nil==recvData then
        MyWelderDebugLog(Language.trLang("LASER_SCAN4_READ_ERR"))
        return false
    end
    if 0xFF==recvData[3] then
        MyWelderDebugLog(Language.trLang("LASER_SCAN4_ERR") .. string.format("d[3]=0x%02X,d[4]=0x%02X,%s",recvData[3],recvData[4],innerGetErrCodeMsg(recvData[4])))
        return false
    end
    return true
end

--[[
功能：计算得到机器人正确的目标点坐标值
参数：无
返回值：成功返回{x=1,y=2,z=3,rx=4,ry=5,rz=6},失败返回nil
说明：主要是用来在标定结束后，校验标定结果是否正确
]]--
function SMTIntelligenLaserCalibrate.checkRobotPose()
    local self = SMTIntelligenLaserCalibrate
    self.cmd = 0x16
    innerBuildCmd(self)
    if not innerSendData(self) then
        MyWelderDebugLog(Language.trLang("LASER_CALC_SEND_ERR"))
        return nil
    end
    local recvData = innerReadData(self)
    if nil==recvData then
        MyWelderDebugLog(Language.trLang("LASER_CALC_READ_ERR"))
        return nil
    end
    if 0xFF==recvData[3] then
        MyWelderDebugLog(Language.trLang("LASER_CALC_ERR") .. string.format("d[3]=0x%02X,d[4]=0x%02X,%s",recvData[3],recvData[4],innerGetErrCodeMsg(recvData[4])))
        return nil
    end
    --43~66为目标机器人坐标，int类型，其中姿态顺序依此是 rz,ry,rx，因为算法说用的欧拉角是ZYX顺序的
    local pose = {0,0,0,0,0,0} --注意顺序是: x,y,z,rz,ry,rx
    local v = 0
    local idx = 43
    for i=1,6 do
        v = recvData[idx]&0xFF
        v = v<<8
        v = v | (recvData[idx+1]&0xFF)
        v = v<<8
        v = v | (recvData[idx+2]&0xFF)
        v = v<<8
        v = v | (recvData[idx+3]&0xFF)
        pose[i] = CHelperTools.ToInt32(v)*0.01
        idx = idx+4
    end
    --返回结果值
    local resultPose = {}
    resultPose.x = pose[1]
    resultPose.y = pose[2]
    resultPose.z = pose[3]
    resultPose.rx = pose[6] --注意这里的顺序
    resultPose.ry = pose[5]
    resultPose.rz = pose[4]
    return resultPose
end

return SMTIntelligenLaserCalibrate