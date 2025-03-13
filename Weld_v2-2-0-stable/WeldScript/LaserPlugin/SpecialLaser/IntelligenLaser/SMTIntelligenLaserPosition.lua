--[[
英莱激光传感器tcp协议，激光寻位功能封装
寻位使用步骤
laserObj.connect(ip,port)
laserObj.setTaskNumber(编号)
laserObj.setRobotPose(pose)
if not laserObj.openLaser() then goto labelExit end
if not laserObj.changeGapType() then goto labelCloseLaser end
laserObj.getRobotPose()
::labelCloseLaser::
laserObj.closeLaser()
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
    self.packAllCmd[3] = 0x03 --寻位功能，固定值
    self.packAllCmd[4] = self.cmd&0xFF --指令字节
    self.packAllCmd[5] = self.gapNumberCmd&0xFF
    self.packAllCmd[6] = self.eulerAngleCmd&0xFF
    self.packAllCmd[7] = (self.gapIdCmd>>8)&0xFF --焊缝对应的ID号,范围 1-500
    self.packAllCmd[8] = self.gapIdCmd&0xFF
    self.packAllCmd[9] = (self.maxOffsetValue>>8)&0xFF --最大偏差限制0-100mm
    self.packAllCmd[10] = self.maxOffsetValue&0xFF
    for i=11,18 do --预留值，填充为0
        self.packAllCmd[i] = 0x00
    end
    self.packAllCmd[19] = (self.offsetIdX>>8)&0xFF --X方向偏差对应的ID号
    self.packAllCmd[20] = self.offsetIdX&0xFF
    self.packAllCmd[21] = (self.offsetIdY>>8)&0xFF --Y方向偏差对应的ID号
    self.packAllCmd[22] = self.offsetIdY&0xFF
    self.packAllCmd[23] = (self.offsetIdZ>>8)&0xFF --Z方向偏差对应的ID号
    self.packAllCmd[24] = self.offsetIdZ&0xFF
    for i=25,42 do --预留值，填充为0
        self.packAllCmd[i] = 0x00
    end
    for i=43,66 do --机器人发送的位置坐标
        v = self.robotPoseCmd[i-42]
        if nil==v then
            self.packAllCmd[i] = 0x00
        else
            self.packAllCmd[i] = v&0xFF
        end
    end
    for i=67,138 do --预留值，填充为0
        self.packAllCmd[i] = 0x00
    end
    for i=139,150 do --机器人执行最后一个运动指令所在程序的名称
        v = self.programName[i-138]
        if nil==v then
            self.packAllCmd[i] = 0x00
        else
            self.packAllCmd[i] = v&0xFF
        end
    end
    for i=151,162 do --预留值，填充为0
        self.packAllCmd[i] = 0x00
    end
    self.packAllCmd[163] = 0x4C --包尾
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
    --[[协议文档说：回复173个字节，寻位通信周期为 10-500ms，根据执行的功能不同，服务器超过 700ms 未回复，可认为超时]]--
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
            Wait(20)
        else
            for i=1,#data do
                table.insert(recvBuf,data[i])
            end
            if #recvBuf>=173 then
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
    elseif 0x11==code then return Language.trLang("LASER_CODE_COORD_ERR")
    elseif 0x14==code then return Language.trLang("LASER_CODE_PRM_ERR")
    elseif 0x15==code then return Language.trLang("LASER_CODE_CALC_FAIL")
    elseif 0x66==code then return Language.trLang("LASER_CODE_PACK_ERR")
    elseif 0x67==code then return Language.trLang("LASER_CODE_PTRO_ERR")
    elseif 0x70==code then return Language.trLang("LASER_CODE_SENSOR_ERR")
    elseif 0x71==code then return Language.trLang("LASER_CODE_NO_INSTALL")
    elseif 0x72==code then return Language.trLang("LASER_CODE_TEMP_ERR")
    else return Language.trLang("LASER_CODE_RESERVE")..string.format(":%X",code)
    end
end

--设置焊缝对应的ID号，范围1-500
local function innerSetGapId(self,id)
    if id<1 or id>500 then
        MyWelderDebugLog(Language.trLang("LASER_GRAPID_OUT_RANGE").."[1,500]")
        return false
    else
        self.gapIdCmd = id
        return true
    end
end

--设置最大偏差限制，范围0-100
local function innerSetMaxOffsetValue(self,offsetVal)
    if offsetVal<0 or offsetVal>100 then
        MyWelderDebugLog(Language.trLang("LASER_MAXOFFSET_OUT_RANGE").."[0,100]")
        return false
    else
        self.maxOffsetValue = offsetVal
        return true
    end
end

--设置三个方向偏差对应的ID号，范围1-500
local function innerSetXYZOffsetId(self,offsetIdX,offsetIdY,offsetIdZ)
    if offsetIdX<1 or offsetIdX>500 then
        MyWelderDebugLog(Language.trLang("LASER_XOFFSETID_OUT_RANGE").."[1,500]")
        return false
    elseif offsetIdY<1 or offsetIdY>500 then
        MyWelderDebugLog(Language.trLang("LASER_YOFFSETID_OUT_RANGE").."[1,500]")
        return false
    elseif offsetIdZ<1 or offsetIdZ>500 then
        MyWelderDebugLog(Language.trLang("LASER_ZOFFSETID_OUT_RANGE").."[1,500]")
        return false
    else
        self.offsetIdX = offsetIdX
        self.offsetIdY = offsetIdY
        self.offsetIdZ = offsetIdZ
        return true
    end
end

--设置程序名称，最大长度12，首字符只能是字母，后面字符只能是字母或数字
local function innerSetProgramName(self,strName)
    if type(strName)~="string" then strName="dobot" end
    local strLen = math.min(string.len(strName),12)
    local v=0
    for i=1,12 do
        if i<=strLen then
            v = string.byte(strName, i)
            if v>=48 and v<=57 then
            elseif v>=65 and v<=90 then
            elseif v>=97 and v<=122 then
            else
                v=97 --字母a
            end
        else
            v=0 --不足的填充0
        end
        self.programName[i] = v&0xFF
    end
end

---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
--【导出接口】
local SMTIntelligenLaserPosition = {
    sock = nil, --sock成功连接的句柄
    packIndex = 0, --包计数编号，单字节，0~255
    cmd = 0xF0, --指令，单字节，不同功能值不一样
    gapNumberCmd = 0x01, --焊缝编号，单字节，不同焊缝编号值不一样，范围1-30
    gapIdCmd = 1, --焊缝对应的ID号，2字节，范围 1-500
    eulerAngleCmd = 0x01, --欧拉角类型，固定为0x01，单字节。0x00表示XYZ，0x01表示ZYX，0x02表示ZYZ'。
    maxOffsetValue = 15, --最大偏差限制，2字节，范围0-100mm
    offsetIdX = 1, --X方向偏差对应的ID号，2字节，范围 1-500
    offsetIdY = 1, --Y方向偏差对应的ID号，2字节，范围 1-500
    offsetIdZ = 1, --Z方向偏差对应的ID号，2字节，范围 1-500
    robotPoseCmd = {}, --机器人当前坐标值，24个字节
    --12字节，不足12字节的填0x00,机器人执行最后一个运动指令所在程序的名称，首字符只能是字母，后面字符只能是字母或数字
    programName = {0x64,0x6F,0x62,0x6F,0x74,0x00,0x00,0x00,0x00,0x00,0x00,0x00}, --默认是dobot
    packAllCmd = {} --打包命令，固定长度字节，待发送的所有数据存在这里
}

---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
---激光器的连接与断开操作--------------------------------------------------------
function SMTIntelligenLaserPosition.connect(ip,port)
    local self = SMTIntelligenLaserPosition
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

function SMTIntelligenLaserPosition.isConnected()
    local self = SMTIntelligenLaserPosition
    return nil~=self.sock
end

function SMTIntelligenLaserPosition.disconnect()
    local self = SMTIntelligenLaserPosition
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
function SMTIntelligenLaserPosition.setTaskNumber(iNumber)
    local self = SMTIntelligenLaserPosition
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
function SMTIntelligenLaserPosition.setRobotPose(pose)
    local self = SMTIntelligenLaserPosition
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
function SMTIntelligenLaserPosition.openLaser()
    local self = SMTIntelligenLaserPosition
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
function SMTIntelligenLaserPosition.closeLaser()
    local self = SMTIntelligenLaserPosition
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
function SMTIntelligenLaserPosition.changeGapType()
    local self = SMTIntelligenLaserPosition
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
功能：得到机器人正确的目标点坐标值
参数：无
返回值：成功返回坐标值{x=1,y=1,z=1,rx=1,ry=1,rz=1}，xyz单位mm,Rxyz单位是角度deg，失败返回nil
]]--
function SMTIntelligenLaserPosition.getRobotPose()
    local self = SMTIntelligenLaserPosition
    self.cmd = 0x30
    innerBuildCmd(self)
    if not innerSendData(self) then
        MyWelderDebugLog(Language.trLang("LASER_TARGET_POSE_SEND_ERR"))
        return nil
    end
    local recvData = innerReadData(self)
    if nil==recvData then
        MyWelderDebugLog(Language.trLang("LASER_TARGET_POSE_READ_ERR"))
        return nil
    end
    if 0xFF==recvData[3] then
        MyWelderDebugLog(Language.trLang("LASER_TARGET_POSE_ERR") .. string.format("d[3]=0x%02X,d[4]=0x%02X,%s",recvData[3],recvData[4],innerGetErrCodeMsg(recvData[4])))
        return nil
    end
    --29~52为目标机器人坐标，int类型，其中姿态顺序依此是 rz,ry,rx，因为算法说用的欧拉角是ZYX顺序的
    local pose = {0,0,0,0,0,0} --注意顺序是: x,y,z,rz,ry,rx
    local v = 0
    local idx = 29
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

return SMTIntelligenLaserPosition