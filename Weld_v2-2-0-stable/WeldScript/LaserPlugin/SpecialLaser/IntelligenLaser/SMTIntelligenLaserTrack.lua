--[[
英莱激光传感器tcp协议，跟踪协议封装
跟踪使用步骤
local robotPose={}
local offsetPredictPose={}
laserObj.connect(ip,port)
laserObj.setTaskNumber(编号)
if not laserObj.openLaser() then goto labelExit end
if not laserObj.changeGapType() then goto labelCloseLaser end
if not laserObj.initTrack() then goto labelCloseLaser end
local beginTime = Systime()
while isTrackFlag do
    laserObj.setRobotPose(机器人位置)
    laserObj.setNextPredictPose(下个规划点位置)
    if not laserObj.startTrack(robotPose,offsetPredictPose) then
        break
    else
        --对返回的结果值robotPose,offsetPredictPose进行处理
        local endTime = Systime()
        if (endTime-beginTime)<40 then --激光器推荐40ms发一次，如果整个通信超过了40ms就没必要Wait
            local wt = 40-(endTime-beginTime)
            Wait(wt)
        end
    end
end
laserObj.stopTrack()

::labelCloseLaser::
laserObj.closeLaser()
::labelExit::
laserObj.disconnect()
]]--

--【为了优化一定丁点儿性能，修改本文件的一些写法，虽然简陋了写，但是性能确实提高了】

--【本地私有接口】
--获取下一个编号
local gInnerPackIndex = 0 --包计数编号，单字节，0~255
local function innerGetNextIdx()
    if gInnerPackIndex>255 then
        gInnerPackIndex = 0
    else
        gInnerPackIndex = gInnerPackIndex+1
    end
    return gInnerPackIndex
end

--组装协议数据包
local function innerBuildCmd(self)
    local v = 0x00
    self.packAllCmd[1] = 0x49 --包头
    self.packAllCmd[2] = innerGetNextIdx()&0xFF --数据包编号
    self.packAllCmd[3] = 0x02 --跟踪功能，固定值
    self.packAllCmd[4] = self.cmd&0xFF --指令字节
    self.packAllCmd[5] = self.gapNumberCmd&0xFF
    self.packAllCmd[6] = self.eulerAngleCmd&0xFF
    for i=7,30 do
        self.packAllCmd[i] = self.robotPoseCmd[i-6]
    end
    for i=31,54 do
        self.packAllCmd[i] = self.robotPredictPoseCmd[i-30]
    end
    self.packAllCmd[55] = self.robotSpeedCmd&0xFF
    for i=56,67 do --预留值，填充为0
        self.packAllCmd[i] = 0x00
    end
    self.packAllCmd[68] = 0x4C --包尾
end

--发送数据给激光器，成功返回true，失败false
local function innerSendData(self)
    --if nil==self.sock then return false end
    local err = TCPWrite(self.sock, self.packAllCmd, 4)
    if err~=0 then
        --MyWelderDebugLog("TCPWrite send laser data fail")
        return false
    end
    return true
end

--读取激光器数据，成功返回字节数据数组,失败返回nil
--为了提升实时跟踪的性能，也为了减少频繁的分配内存，就写固定大小
local gTcpReadBuffer={ --至少79个长度，预分配好
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
}
local gTcpReadBufferCount = 0 --gTcpReadBuffer中数据个数
local function innerReadData(sock)
    --[[协议文档说：通信周期不可小于10ms,推荐40ms，激光器回复79个字节，激光器超过200ms未回复可认为超时]]--
    -- if nil==self.sock then return nil end
    gTcpReadBufferCount=0
    local err,recvData,recvDataCount
    local begTime = Systime()
    local endTime = begTime
    while endTime-begTime<=3000 do
        err,recvData = TCPRead(sock, 1)
        if err~=0 then
            --MyWelderDebugLog("TCPRead read laser data fail")
            Wait(5)
        else
            recvDataCount = #recvData
            for i=1,recvDataCount do
                gTcpReadBuffer[gTcpReadBufferCount+i] = recvData[i]
            end
            gTcpReadBufferCount = gTcpReadBufferCount+recvDataCount
            if gTcpReadBufferCount>=79 then
                return gTcpReadBuffer
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
    elseif 0x12==code then return Language.trLang("LASER_CODE_NO_GRAP")
    elseif 0x13==code then return Language.trLang("LASER_CODE_LOST_GRAP")
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
local SMTIntelligenLaserTrack = {
    sock = nil, --sock成功连接的句柄
    packIndex = 0, --包计数编号，单字节，0~255
    cmd = 0xF0, --指令，单字节，不同功能值不一样
    gapNumberCmd = 0x01, --焊缝编号，单字节，不同焊缝编号值不一样，范围1-30
    eulerAngleCmd = 0x01, --欧拉角类型，固定为0x01，单字节。0x00表示XYZ，0x01表示ZYX，0x02表示ZYZ'。
    robotPoseCmd = {0,0,0,0,0,0,0,0,0,0,
                    0,0,0,0,0,0,0,0,0,0,
                    0,0,0,0}, --机器人当前坐标值，24个字节
    robotPredictPoseCmd = {0,0,0,0,0,0,0,0,0,0,
                           0,0,0,0,0,0,0,0,0,0,
                           0,0,0,0}, --机器人下一个规划位置值，24字节
    robotSpeedCmd = 0x00, --机器人速度，单字节，用不上，目前固定为0.
    packAllCmd = {} --打包命令，固定68字节，待发送的所有数据存在这里
}

---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
---激光器的连接与断开操作--------------------------------------------------------
function SMTIntelligenLaserTrack.connect(ip,port)
    local self = SMTIntelligenLaserTrack
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
    innerBuildCmd(self) --先把数据位都填充好
    return true
end

function SMTIntelligenLaserTrack.isConnected()
    local self = SMTIntelligenLaserTrack
    return nil~=self.sock
end

function SMTIntelligenLaserTrack.disconnect()
    local self = SMTIntelligenLaserTrack
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
function SMTIntelligenLaserTrack.setTaskNumber(iNumber)
    local self = SMTIntelligenLaserTrack
    if iNumber<1 or iNumber>30 then
        MyWelderDebugLog(Language.trLang("LASER_GRAP_OUT_RANGE").."[1,30]")
        return false
    else
        self.gapNumberCmd = iNumber
        self.packAllCmd[5] = iNumber&0xFF
        return true
    end
end

--[[
功能：设置机器人当前坐标位置
参数：pose-位置，值为：{x=1,y=1,z=1,rx=1,ry=1,rz=1}
返回值：无
]]--
function SMTIntelligenLaserTrack.setRobotPose(pose)
    local self = SMTIntelligenLaserTrack
    local x = math.modf(pose.x*100)
    local y = math.modf(pose.y*100)
    local z = math.modf(pose.z*100)
    local rx = math.modf(pose.rx*100)
    local ry = math.modf(pose.ry*100)
    local rz = math.modf(pose.rz*100)
    --因为欧拉角选择的是ZYX旋转顺序的，所以字节顺序是rz,ry,rx
    --为了提高一点点性能，直接赋值
    self.packAllCmd[7] = (x>>24)&0xFF
    self.packAllCmd[8] = (x>>16)&0xFF
    self.packAllCmd[9] = (x>>8)&0xFF
    self.packAllCmd[10] = x&0xFF
    self.packAllCmd[11] = (y>>24)&0xFF
    self.packAllCmd[12] = (y>>16)&0xFF
    self.packAllCmd[13] = (y>>8)&0xFF
    self.packAllCmd[14] = y&0xFF
    self.packAllCmd[15] = (z>>24)&0xFF
    self.packAllCmd[16] = (z>>16)&0xFF
    self.packAllCmd[17] = (z>>8)&0xFF
    self.packAllCmd[18] = z&0xFF
    self.packAllCmd[19] = (rz>>24)&0xFF
    self.packAllCmd[20] = (rz>>16)&0xFF
    self.packAllCmd[21] = (rz>>8)&0xFF
    self.packAllCmd[22] = rz&0xFF
    self.packAllCmd[23] = (ry>>24)&0xFF
    self.packAllCmd[24] = (ry>>16)&0xFF
    self.packAllCmd[25] = (ry>>8)&0xFF
    self.packAllCmd[26] = ry&0xFF
    self.packAllCmd[27] = (rx>>24)&0xFF
    self.packAllCmd[28] = (rx>>16)&0xFF
    self.packAllCmd[29] = (rx>>8)&0xFF
    self.packAllCmd[30] = rx&0xFF
end

--[[
功能：设置下一个规划位置坐标
参数：pose-位置，值为：{x=1,y=1,z=1,rx=1,ry=1,rz=1}
返回值：无
]]--
function SMTIntelligenLaserTrack.setNextPredictPose(pose)
    local self = SMTIntelligenLaserTrack
    local x = math.modf(pose.x*100)
    local y = math.modf(pose.y*100)
    local z = math.modf(pose.z*100)
    local rx = math.modf(pose.rx*100)
    local ry = math.modf(pose.ry*100)
    local rz = math.modf(pose.rz*100)
    --因为欧拉角选择的是ZYX旋转顺序的，所以字节顺序是rz,ry,rx
    --为了提高一点点性能，直接赋值
    self.packAllCmd[31] = (x>>24)&0xFF
    self.packAllCmd[32] = (x>>16)&0xFF
    self.packAllCmd[33] = (x>>8)&0xFF
    self.packAllCmd[34] = x&0xFF
    self.packAllCmd[35] = (y>>24)&0xFF
    self.packAllCmd[36] = (y>>16)&0xFF
    self.packAllCmd[37] = (y>>8)&0xFF
    self.packAllCmd[38] = y&0xFF
    self.packAllCmd[39] = (z>>24)&0xFF
    self.packAllCmd[40] = (z>>16)&0xFF
    self.packAllCmd[41] = (z>>8)&0xFF
    self.packAllCmd[42] = z&0xFF
    self.packAllCmd[43] = (rz>>24)&0xFF
    self.packAllCmd[44] = (rz>>16)&0xFF
    self.packAllCmd[45] = (rz>>8)&0xFF
    self.packAllCmd[46] = rz&0xFF
    self.packAllCmd[47] = (ry>>24)&0xFF
    self.packAllCmd[48] = (ry>>16)&0xFF
    self.packAllCmd[49] = (ry>>8)&0xFF
    self.packAllCmd[50] = ry&0xFF
    self.packAllCmd[51] = (rx>>24)&0xFF
    self.packAllCmd[52] = (rx>>16)&0xFF
    self.packAllCmd[53] = (rx>>8)&0xFF
    self.packAllCmd[54] = rx&0xFF
end

---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
---以下是一些命令的操作，与激光器通信--------------------------------------------
--[[
功能：打开、关闭激光
参数：无
返回值：true表示成功，false表示失败
]]--
function SMTIntelligenLaserTrack.openLaser()
    local self = SMTIntelligenLaserTrack
    self.cmd = 0xF1
    innerBuildCmd(self)
    if not innerSendData(self) then
        MyWelderDebugLog(Language.trLang("LASER_OPEN_SEND_ERR"))
        return false
    end
    local recvData = innerReadData(self.sock)
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
function SMTIntelligenLaserTrack.closeLaser()
    local self = SMTIntelligenLaserTrack
    self.cmd = 0xF2
    innerBuildCmd(self)
    if not innerSendData(self) then
        MyWelderDebugLog(Language.trLang("LASER_CLOSE_SEND_ERR"))
        return false
    end
    local recvData = innerReadData(self.sock)
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
function SMTIntelligenLaserTrack.changeGapType()
    local self = SMTIntelligenLaserTrack
    self.cmd = 0xF3
    innerBuildCmd(self)
    if not innerSendData(self) then
        MyWelderDebugLog(Language.trLang("LASER_GRAP_CHANGE_SEND_ERR"))
        return false
    end
    local recvData = innerReadData(self.sock)
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
功能：跟踪初始化
参数：无
返回值：true表示成功，false表示失败
]]--
function SMTIntelligenLaserTrack.initTrack()
    local self = SMTIntelligenLaserTrack
    self.cmd = 0x20
    innerBuildCmd(self)
    if not innerSendData(self) then
        MyWelderDebugLog(Language.trLang("LASER_INIT_TRACK_SEND_ERR"))
        return false
    end
    local recvData = innerReadData(self.sock)
    if nil==recvData then
        MyWelderDebugLog(Language.trLang("LASER_INIT_TRACK_READ_ERR"))
        return false
    end
    if 0xFF==recvData[3] then
        MyWelderDebugLog(Language.trLang("LASER_INIT_TRACK_ERR") .. string.format("d[3]=0x%02X,d[4]=0x%02X,%s",recvData[3],recvData[4],innerGetErrCodeMsg(recvData[4])))
        return false
    end
    return true
end

--[[
功能：开始、结束跟踪
参数：robotPose->输出参数,格式为{x=0,y=0,z=0,rx=0,ry=0,rz=0},表示获取的目标机器人坐标
      offsetPredictPose->输出参数,格式为{x=0,y=0,z=0,rx=0,ry=0,rz=0},表示获取的目标点相距于下一规划轨迹的偏差值
返回值：true表示成功，false表示失败
说明：英莱的激光器，需要周期性的调用此接口来获取跟踪结果数据，推荐间隔40ms获取一次
]]--
function SMTIntelligenLaserTrack.startTrack(robotPose,offsetPredictPose)
    SMTIntelligenLaserTrack.packAllCmd[4] = 0x22 --self.cmd = 0x22
    SMTIntelligenLaserTrack.packAllCmd[2] = innerGetNextIdx() --innerBuildCmd(self)
    if 0~=TCPWrite(SMTIntelligenLaserTrack.sock, SMTIntelligenLaserTrack.packAllCmd, 4) then
        MyWelderDebugLog(Language.trLang("LASER_START_TRACK_SEND_ERR"))
        return false
    end
    local recvData = innerReadData(SMTIntelligenLaserTrack.sock)
    if nil==recvData then
        MyWelderDebugLog(Language.trLang("LASER_START_TRACK_READ_ERR"))
        return false
    end
    if 0xFF==recvData[3] then -- r[3]==0x22表示寻找焊缝中,r[3]==0x2D/0x2E表示焊缝已经找到并跟踪中
        MyWelderDebugLog(Language.trLang("LASER_START_TRACK_ERR") .. string.format("d[3]=0x%02X,d[4]=0x%02X,%s",recvData[3],recvData[4],innerGetErrCodeMsg(recvData[4])))
        return false
    end
    --43~66为目标机器人坐标，int类型，其中rx,rx,rz姿态的激光器目前没有给，那就写死为0吧。
    --如果激光器有姿态值，那么顺序依此是 rz,ry,rx，因为算法说用的欧拉角是ZYX顺序的
    --注意顺序是: x,y,z,rz,ry,rx
    local v = recvData[43]&0xFF
    v = v<<8
    v = v | (recvData[44]&0xFF)
    v = v<<8
    v = v | (recvData[45]&0xFF)
    v = v<<8
    v = v | (recvData[46]&0xFF)
    robotPose.x = CHelperTools.ToInt32(v)*0.01
    
    v = recvData[47]&0xFF
    v = v<<8
    v = v | (recvData[48]&0xFF)
    v = v<<8
    v = v | (recvData[49]&0xFF)
    v = v<<8
    v = v | (recvData[50]&0xFF)
    robotPose.y = CHelperTools.ToInt32(v)*0.01
    
    v = recvData[51]&0xFF
    v = v<<8
    v = v | (recvData[52]&0xFF)
    v = v<<8
    v = v | (recvData[53]&0xFF)
    v = v<<8
    v = v | (recvData[54]&0xFF)
    robotPose.z = CHelperTools.ToInt32(v)*0.01
    
    v = recvData[55]&0xFF
    v = v<<8
    v = v | (recvData[56]&0xFF)
    v = v<<8
    v = v | (recvData[57]&0xFF)
    v = v<<8
    v = v | (recvData[58]&0xFF)
    robotPose.rz = CHelperTools.ToInt32(v)*0.01
    
    v = recvData[59]&0xFF
    v = v<<8
    v = v | (recvData[60]&0xFF)
    v = v<<8
    v = v | (recvData[61]&0xFF)
    v = v<<8
    v = v | (recvData[62]&0xFF)
    robotPose.ry = CHelperTools.ToInt32(v)*0.01

    v = recvData[63]&0xFF
    v = v<<8
    v = v | (recvData[64]&0xFF)
    v = v<<8
    v = v | (recvData[65]&0xFF)
    v = v<<8
    v = v | (recvData[66]&0xFF)
    robotPose.rx = CHelperTools.ToInt32(v)*0.01
    
    --67~72为目标点相距于下一规划轨迹的偏差值，short类型，只有xyz值
    v = recvData[67]&0xFF
    v = v<<8
    v = v | (recvData[68]&0xFF)
    offsetPredictPose.x = CHelperTools.ToInt16(v)*0.01
    
    v = recvData[69]&0xFF
    v = v<<8
    v = v | (recvData[70]&0xFF)
    offsetPredictPose.y = CHelperTools.ToInt16(v)*0.01
    
    v = recvData[71]&0xFF
    v = v<<8
    v = v | (recvData[72]&0xFF)
    offsetPredictPose.z = CHelperTools.ToInt16(v)*0.01
    
    offsetPredictPose.rx = 0
    offsetPredictPose.ry = 0
    offsetPredictPose.rz = 0
    
    return true
end
function SMTIntelligenLaserTrack.stopTrack()
    local self = SMTIntelligenLaserTrack
    self.cmd = 0x21
    innerBuildCmd(self)
    if not innerSendData(self) then
        MyWelderDebugLog(Language.trLang("LASER_END_TRACK_SEND_ERR"))
        return false
    end
    local recvData = innerReadData(self.sock)
    if nil==recvData then
        MyWelderDebugLog(Language.trLang("LASER_END_TRACK_READ_ERR"))
        return false
    end
    if 0xFF==recvData[3] then
        MyWelderDebugLog(Language.trLang("LASER_END_TRACK_ERR") .. string.format("d[3]=0x%02X,d[4]=0x%02X,%s",recvData[3],recvData[4],innerGetErrCodeMsg(recvData[4])))
        return false
    end
    return true
end

return SMTIntelligenLaserTrack