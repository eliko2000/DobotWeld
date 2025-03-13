-- 因为TCPWrite发送string时没有将'\0'发出去，导致接收端无法判断一包完整数据，所以需要将string转为table
local function string2Table(str)
    local objTable = {}
    if str == nil or type(str) ~= "string" then
    else
        local strlen = string.len(str)
        for idx = 1, strlen, 1 do
            objTable[idx] = string.byte(str, idx)
        end
    end
    table.insert(objTable, 0)
    return objTable
end
-- 将table数组转为字符串，与string2Table相反，如果table最后一个是0，则去掉
local function table2String(tab)
    if tab[#tab] == 0 then table.remove(tab) end
    local str = ""
    for i=1,#tab do
        str = str .. string.char(tab[i])
    end
    return str
end

--字符串分割，返回字符串数组
local function SplitString(input, delimiter,funcConvert)
    if type(input) ~= "string" then
        return nil
    end
    if type(delimiter) ~= "string" then
        --return input
        delimiter = ","
    end
    
    local pos,arr = 0, {}
    for st,sp in function() return string.find(input,delimiter,pos,true) end do
        local strTmp = string.sub(input, pos, st-1)
        if nil == funcConvert then
            table.insert(arr, strTmp)
        else
            table.insert(arr, funcConvert(strTmp))
        end
        pos = sp+1
    end
    local strTmp = string.sub(input, pos)
    if nil == funcConvert then
        table.insert(arr, strTmp)
    else
        table.insert(arr, funcConvert(strTmp))
    end
    return arr
end

--发送数据，成功返回true，失败false
local function innerSendData(self, strData)
    if nil==self.sock then return false end
    MyWelderDebugLog("tcp send:"..strData)
    --local err = TCPWrite(self.sock, string2Table(strData), 4)
    local err = TCPWrite(self.sock, strData, 4)
    if err~=0 then
        MyWelderDebugLog("Send tcp data fail:"..strData)
        return false
    end
    return true
end

--读取数据，成功返回字符串,失败返回nil
local function innerReadData(self)
    if nil==self.sock then
        return nil
    end
    local recvBuf = nil
    local err,data
    local begTime = Systime()
    local endTime = begTime
    while endTime-begTime<=15000 do
        err,data = TCPRead(self.sock, 1, "string")
        if err~=0 then
            Wait(10)
        else
            if nil==recvBuf then
                recvBuf = data
            else
                recvBuf = recvBuf..data
            end
            if nil~=self.endChar then --有判断结束符
                local pos = string.find(recvBuf,self.endChar,1,true)
                if pos>0 then
                    recvBuf = string.sub(recvBuf,1,pos-1)
                    break
                end
            else
                break --没有判断结束符,那么接收到数据就认为接收完毕
            end
        end
        endTime = Systime()
    end
    if recvBuf then
        MyWelderDebugLog("tcp recv:"..recvBuf)
    else
        MyWelderDebugLog("tcp recv empty!")
    end
    return recvBuf
end
--[[
local function innerReadData(self)
    if nil==self.sock then
        return nil
    end
    local recvBuf = {}
    local err,data
    local begTime = Systime()
    local endTime = begTime
    while endTime-begTime<=5000 do
        err,data = TCPRead(self.sock, 1)
        if err~=0 then
            Wait(10)
        else
            for i=1,#data do
                table.insert(recvBuf,data[i])
            end
            if 0x00==data[#data] then
                return table2String(recvBuf)
            end
        end
        endTime = Systime()
    end
    return nil
end
]]--

--根据错误码返回错误信息
local function innerGetErrCodeMsg(code)
    if "0"==code then return "OK"
    else return tostring(code)
    end
--[[
    if "0"==code then return "处理成功"
    elseif "1"==code then return "未初始化"
    elseif "2"==code then return "点云法线处理失败"
    elseif "3"==code then return "点云分割失败"
    elseif "4"==code then return "检测/拟合（平面、圆柱）失败"
    elseif "5"==code then return "拟合偏差过大"
    elseif "6"==code then return "钢筋不垂直交叉"
    elseif "7"==code then return "钢筋间距太远"
    elseif "8"==code then return "未知异常"
    elseif "9"==code then return "点云创建失败"
    elseif "10"==code then return "点云太少"
    elseif "11"==code then return "拟合形状不符合期望"
    elseif "12"==code then return "无数据"
    elseif "13"==code then return "弧形骨架线提取失败"
    elseif "14"==code then return "弧形骨架线筛选点失败"
    elseif "15"==code then return "获取计算结果为空"
    elseif "16"==code then return "点云预处理失败"
    elseif "17"==code then return "焊接参数为空"
    elseif "18"==code then return "手眼转换失败"
    elseif "19"==code then return "点云非有序点云"
    elseif "20"==code then return "边界提取失败"
    elseif "21"==code then return "数据（平面等）的角度非法"
    elseif "22"==code then return "数据合并失败"
    elseif "23"==code then return "数据在点云后面（可能撞枪）"
    elseif "24"==code then return "数据错误"
    elseif "25"==code then return "请求数据错误"
    elseif "26"==code then return "机器人位姿数据错误"
    elseif "27"==code then return "未找到工艺包"
    elseif "28"==code then return "特征结果为空"
    elseif "29"==code then return "未授权"
    else return "未定义错误码:"..tostring(code)
    end
]]--
end

--焊缝轨迹数据结构
local WeldPathData = {
    weldType = 0, --焊缝平立类型
    thickness = 0, --板厚
    gap = 0, --焊缝间隙
    startPoint = nil, --起始过渡点，形如：{x=1,y=1,z=1,rx=1,ry=1,rz=1}
    arcStartPoint = nil, --起弧点，形如：{x=1,y=1,z=1,rx=1,ry=1,rz=1}
    middlePoint = nil,  --焊接中间点，可能存在多个，所以是一个数组,数组中每个元素就是一个点，点的格式也是形如：{x=1,y=1,z=1,rx=1,ry=1,rz=1}
    arcEndPoint = nil, --收弧点，形如：{x=1,y=1,z=1,rx=1,ry=1,rz=1}
    endPoint = nil --结束过渡点，形如：{x=1,y=1,z=1,rx=1,ry=1,rz=1}
}

--解析焊缝的信息，返回值是一个数组，每个元素查看`WeldPathData`
local function innerParseWeldPathData(retData)
    local allWeldPathData = {} --所有焊缝的信息
    local pathCount = retData[2] --焊缝数量
    local idx = 3
    for i=1,pathCount do
        local weldData = {}
        weldData.weldType = retData[idx] --焊缝平立类型
        idx = idx+1
        weldData.thickness = retData[idx] --板厚
        idx = idx+1
        local dotCount = retData[idx] --焊缝的焊点数量,不包含起始过渡点和结束过渡点
        idx = idx+1
        weldData.gap = retData[idx] --焊缝间隙
        idx = idx+1
        weldData.startPoint = { --起始过渡点
            x=retData[idx],y=retData[idx+1],z=retData[idx+2],
            rx=retData[idx+3],ry=retData[idx+4],rz=retData[idx+5]
        }
        idx = idx+6
        weldData.arcStartPoint = { --起弧点
            x=retData[idx],y=retData[idx+1],z=retData[idx+2],
            rx=retData[idx+3],ry=retData[idx+4],rz=retData[idx+5]
        }
        idx = idx+6
        weldData.middlePoint = {}
        for k=1,dotCount-2 do
            local middlePoint = { --焊接中间点
                x=retData[idx],y=retData[idx+1],z=retData[idx+2],
                rx=retData[idx+3],ry=retData[idx+4],rz=retData[idx+5]
            }
            table.insert(weldData.middlePoint, middlePoint)
            idx = idx+6
        end
        weldData.arcEndPoint = { --收弧点
            x=retData[idx],y=retData[idx+1],z=retData[idx+2],
            rx=retData[idx+3],ry=retData[idx+4],rz=retData[idx+5]
        }
        idx = idx+6
        weldData.endPoint = { --结束过渡点
            x=retData[idx],y=retData[idx+1],z=retData[idx+2],
            rx=retData[idx+3],ry=retData[idx+4],rz=retData[idx+5]
        }
        idx = idx+6
        table.insert(allWeldPathData, weldData)
    end
    return allWeldPathData
end

-------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------
--【导出接口】
local Chishine3DProtocol = {
    sock = nil, --sock成功连接的句柄
    endChar = ";" --协议完整包的结束符
}

--设置协议包的结束符
--endChar为string类型,当值为nil时则表示去掉检测结束符,否则为实际的结束符
function Chishine3DProtocol.setEndChar(endChar)
    local self = Chishine3DProtocol
    self.endChar = endChar
end

--连接3D相机
--返回：true-成功，false-失败
function Chishine3DProtocol.connect(ip,port)
    local self = Chishine3DProtocol
    local err, sock = TCPCreate(false, ip, port)
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

--true表示连接了，false表示未连接
function Chishine3DProtocol.isConnected()
    local self = Chishine3DProtocol
    return nil~=self.sock
end

--断开连接
function Chishine3DProtocol.disconnect()
    local self = Chishine3DProtocol
    if nil~=self.sock then
        TCPDestroy(self.sock)
        self.sock = nil
    end
end

--启动、停止视觉服务控制
--返回值：true-成功，false-失败
function Chishine3DProtocol.startControlVisionService()
    local self = Chishine3DProtocol
    local cmd = "000,1"
    if not innerSendData(self, cmd) then
        MyWelderDebugLog(Language.trLang("LASER_START_SEND_SVSC"))
        return false
    end
    local recvData = innerReadData(self)
    if not recvData then
        MyWelderDebugLog(Language.trLang("LASER_START_RECV_SVSC"))
        return false
    end
    local retData = SplitString(recvData)
    if "900"==retData[1] then
        return true
    else
        MyWelderDebugLog(Language.trLang("LASER_START_EXEC_SVSC")..",errmsg="..innerGetErrCodeMsg(retData[2]))
        return false
    end
    return true
end
function Chishine3DProtocol.stopControlVisionService()
    local self = Chishine3DProtocol
    local cmd = "000,0"
    if not innerSendData(self, cmd) then
        MyWelderDebugLog(Language.trLang("LASER_STOP_SEND_SVSC"))
        return false
    end
    local recvData = innerReadData(self)
    if not recvData then
        MyWelderDebugLog(Language.trLang("LASER_STOP_RECV_SVSC"))
        return false
    end
    local retData = SplitString(recvData)
    if "900"==retData[1] then
        return true
    else
        MyWelderDebugLog(Language.trLang("LASER_STOP_EXEC_SVSC")..",errmsg="..innerGetErrCodeMsg(retData[2]))
        return false
    end
    return true
end

--[[
--设置相机参数
--groupNumber-参数组号
--返回值：true-成功，false-失败
]]--
function Chishine3DProtocol.setCameraParam(groupNumber)
    local self = Chishine3DProtocol
    local cmd = "200,"..tostring(groupNumber)
    if not innerSendData(self, cmd) then
        MyWelderDebugLog(Language.trLang("LASER_SEND_CAMERA_PRM"))
        return false
    end
    local recvData = innerReadData(self)
    if not recvData then
        MyWelderDebugLog(Language.trLang("LASER_RECV_CAMERA_PRM"))
        return false
    end
    local retData = SplitString(recvData)
    if "900"==retData[1] then
        return true
    else
        MyWelderDebugLog(Language.trLang("LASER_EXEC_CAMERA_PRM")..",errmsg="..innerGetErrCodeMsg(retData[2]))
        return false
    end
    return true
end

--[[
--内参标定：开始标定，继续标定，结束标定
--value-相机曝光值
--返回值：true-成功，false-失败
--使用案例如下
beginCalibrate()
for i=1,n do
    continueCalibrate()
end
endCalibrate()
]]--
local function innerCalibrate(self, id, value)
    local strlog,strlog1,strlog2 = "","",""
    if 0==id then
        strlog=Language.trLang("LASER_SEND_START_PRM_CALIBRATE")
        strlog1=Language.trLang("LASER_RECV_START_PRM_CALIBRATE")
        strlog2=Language.trLang("LASER_EXEC_START_PRM_CALIBRATE")
    elseif 1==id then
        strlog=Language.trLang("LASER_SEND_CONTINUE_PRM_CALIBRATE")
        strlog1=Language.trLang("LASER_RECV_CONTINUE_PRM_CALIBRATE")
        strlog2=Language.trLang("LASER_EXEC_CONTINUE_PRM_CALIBRATE")
    elseif 99==id then
        strlog=Language.trLang("LASER_SEND_END_PRM_CALIBRATE")
        strlog1=Language.trLang("LASER_RECV_END_PRM_CALIBRATE")
        strlog2=Language.trLang("LASER_EXEC_END_PRM_CALIBRATE")
    else return false
    end
    
    local cmd = {"101",tostring(id),tostring(value)}
    cmd = table.concat(cmd,",")
    if not innerSendData(self, cmd) then
        MyWelderDebugLog(strlog)
        return false
    end
    local recvData = innerReadData(self)
    if not recvData then
        MyWelderDebugLog(strlog1)
        return false
    end
    local retData = SplitString(recvData)
    if "900"==retData[1] then
        return true
    else
        MyWelderDebugLog(strlog2..",errmsg="..innerGetErrCodeMsg(retData[2]))
        return false
    end
    return true
end
function Chishine3DProtocol.beginCalibrate(value)
    local self = Chishine3DProtocol
    return innerCalibrate(self,0,value)
end
function Chishine3DProtocol.continueCalibrate(value)
    local self = Chishine3DProtocol
    return innerCalibrate(self,1,value)
end
function Chishine3DProtocol.endCalibrate(value)
    local self = Chishine3DProtocol
    return innerCalibrate(self,99,value)
end

--[[
--手眼标定：重置，拍照点，触碰点，继续，结束
--robotPose-机器人当前位置{x=1,y=1,z=1,rx=1,ry=1,rz=1}
  value-相机曝光值
--返回值：true-成功，false-失败
--使用案例如下
resetEyeHandleCalibrate()
photoPointEyeHandleCalibrate()
for i=1,n do
    continueEyeHandleCalibrate()
end
for i=1,n do
    touchPointEyeHandleCalibrate()
end
endEyeHandleCalibrate()
]]--
local function innerEyeHandleCalibrate(self,id,robotPose,value)
    local strlog,strlog1,strlog2 = "","",""
    if 0==id then
        strlog=Language.trLang("LASER_SEND_EYE_HANDLE_TKP")
        strlog1=Language.trLang("LASER_RECV_EYE_HANDLE_TKP")
        strlog2=Language.trLang("LASER_EXEC_EYE_HANDLE_TKP")
    elseif 1==id then
        strlog=Language.trLang("LASER_SEND_EYE_HANDLE_CONTINUE")
        strlog1=Language.trLang("LASER_RECV_EYE_HANDLE_CONTINUE")
        strlog2=Language.trLang("LASER_EXEC_EYE_HANDLE_CONTINUE")
    elseif 2==id then
        strlog=Language.trLang("LASER_SEND_EYE_HANDLE_TOUCH")
        strlog1=Language.trLang("LASER_RECV_EYE_HANDLE_TOUCH")
        strlog2=Language.trLang("LASER_EXEC_EYE_HANDLE_TOUCH")
    elseif 99==id then
        strlog=Language.trLang("LASER_SEND_EYE_HANDLE_END")
        strlog1=Language.trLang("LASER_RECV_EYE_HANDLE_END")
        strlog2=Language.trLang("LASER_EXEC_EYE_HANDLE_END")
    else return false
    end

    local cmd = {"102",tostring(id),
                 tostring(robotPose.x),tostring(robotPose.y),tostring(robotPose.z),
                 tostring(robotPose.rx),tostring(robotPose.ry),tostring(robotPose.rz),
                 tostring(value)
                }
    cmd = table.concat(cmd,",")
    if not innerSendData(self, cmd) then
        MyWelderDebugLog(strlog)
        return false
    end
    local recvData = innerReadData(self)
    if not recvData then
        MyWelderDebugLog(strlog1)
        return false
    end
    local retData = SplitString(recvData)
    if "900"==retData[1] then
        return true
    else
        MyWelderDebugLog(strlog2..",errmsg="..innerGetErrCodeMsg(retData[2]))
        return false
    end
    return true
end
function Chishine3DProtocol.photoPointEyeHandleCalibrate(robotPose,value)
    local self = Chishine3DProtocol
    return innerEyeHandleCalibrate(self,0, robotPose, value)
end
function Chishine3DProtocol.continueEyeHandleCalibrate(robotPose,value)
    local self = Chishine3DProtocol
    return innerEyeHandleCalibrate(self,1, robotPose, value)
end
function Chishine3DProtocol.touchPointEyeHandleCalibrate(robotPose,value)
    local self = Chishine3DProtocol
    return innerEyeHandleCalibrate(self,2, robotPose, value)
end
function Chishine3DProtocol.endEyeHandleCalibrate(robotPose,value)
    local self = Chishine3DProtocol
    return innerEyeHandleCalibrate(self,99, robotPose, value)
end

--[[
--焊接特征识别单步模式
--robotPose-机器人当前位置{x=1,y=1,z=1,rx=1,ry=1,rz=1}
  productType-当前所拍摄的工件类型，具体请查看《Tracer3D焊接视觉系统手册V1.8.pdf》，
              P84表2“工件类型与焊缝特征表”，注意这张表的“支持模式”的描述。
--返回值：true-成功，false-失败
]]--
function Chishine3DProtocol.weldFeatureByOneStep(robotPose, productType)
    local self = Chishine3DProtocol
    local cmd = {"001",tostring(productType),
                 tostring(robotPose.x),tostring(robotPose.y),tostring(robotPose.z),
                 tostring(robotPose.rx),tostring(robotPose.ry),tostring(robotPose.rz)
                }
    cmd = table.concat(cmd,",")
    if not innerSendData(self, cmd) then
        MyWelderDebugLog(Language.trLang("LASER_SEND_SR_WELD_DATA"))
        return false
    end
    local recvData = innerReadData(self)
    if not recvData then
        MyWelderDebugLog(Language.trLang("LASER_RECV_SR_WELD_DATA"))
        return false
    end
    local retData = SplitString(recvData)
    if "001"~=retData[1] then
        MyWelderDebugLog(Language.trLang("LASER_EXEC_SR_WELD_DATA")..",errmsg="..innerGetErrCodeMsg(retData[2]))
        return false
    end
    --retData[2] --目标拼接类型
    --retData[3] --焊缝识别结果
    return true
end

--[[
--焊接特征识别融合多步模式
--robotPose-机器人当前位置{x=1,y=1,z=1,rx=1,ry=1,rz=1}
  productType-当前所拍摄的工件类型，具体请查看《Tracer3D焊接视觉系统手册V1.8.pdf》，
              P84表2“工件类型与焊缝特征表”，注意这张表的“支持模式”的描述。
--返回值：true-成功，false-失败
--使用案例如下
beginWeldFeatureByMultiStep()
for i=1,n do
    continueWeldFeatureByMultiStep()
end
endWeldFeatureByMultiStep()
]]--
local function innerWeldFeatureByMultiStep(self, id, robotPose, productType)
    local strlog,strlog1,strlog2 = "","",""
    if 0==id then
        strlog=Language.trLang("LASER_SEND_MR_WELD_DATA_START")
        strlog1=Language.trLang("LASER_RECV_MR_WELD_DATA_START")
        strlog2=Language.trLang("LASER_EXEC_MR_WELD_DATA_START")
    elseif 1==id then
        strlog=Language.trLang("LASER_SEND_MR_WELD_DATA_CONTINUE")
        strlog1=Language.trLang("LASER_RECV_MR_WELD_DATA_CONTINUE")
        strlog2=Language.trLang("LASER_EXEC_MR_WELD_DATA_CONTINUE")
    elseif 2==id then
        strlog=Language.trLang("LASER_SEND_MR_WELD_DATA_STOP")
        strlog1=Language.trLang("LASER_RECV_MR_WELD_DATA_STOP")
        strlog2=Language.trLang("LASER_EXEC_MR_WELD_DATA_STOP")
    else return false
    end
    
    local cmd = {"002",tostring(id),tostring(productType),
                 tostring(robotPose.x),tostring(robotPose.y),tostring(robotPose.z),
                 tostring(robotPose.rx),tostring(robotPose.ry),tostring(robotPose.rz)
                }
    cmd = table.concat(cmd,",")
    if not innerSendData(self, cmd) then
        MyWelderDebugLog(strlog)
        return nil
    end
    local recvData = innerReadData(self)
    if not recvData then
        MyWelderDebugLog(strlog1)
        return nil
    end
    local retData = SplitString(recvData)
    if "999"==retData[1] then
        MyWelderDebugLog(strlog2..",errmsg="..innerGetErrCodeMsg(retData[2]))
        return nil
    end
    return retData
end
function Chishine3DProtocol.beginWeldFeatureByMultiStep(robotPose, productType)
    local self = Chishine3DProtocol
    local retData = innerWeldFeatureByMultiStep(self,0,robotPose, productType) or {}
    return retData[1]=="900"
end
function Chishine3DProtocol.continueWeldFeatureByMultiStep(robotPose, productType)
    local self = Chishine3DProtocol
    local retData = innerWeldFeatureByMultiStep(self,1,robotPose, productType) or {}
    return retData[1]=="900"
end
function Chishine3DProtocol.endWeldFeatureByMultiStep(robotPose, productType)
    local self = Chishine3DProtocol
    local retData = innerWeldFeatureByMultiStep(self,2,robotPose, productType) or {}
    --retData[2] --目标拼接类型
    --retData[3] --焊缝识别结果
    return retData[1]=="001"
end

--[[
--焊缝轨迹计算单步模式
--robotPose-机器人当前位置{x=1,y=1,z=1,rx=1,ry=1,rz=1}
  moduleNumber-轨迹模板编号
--返回值：所有焊缝的信息
]]--
function Chishine3DProtocol.weldPathByOneStep(robotPose, moduleNumber)
    local self = Chishine3DProtocol
    local cmd = {"11",tostring(moduleNumber),
                 tostring(robotPose.x),tostring(robotPose.y),tostring(robotPose.z),
                 tostring(robotPose.rx),tostring(robotPose.ry),tostring(robotPose.rz)
                }
    cmd = table.concat(cmd,",")
    if not innerSendData(self, cmd) then
        MyWelderDebugLog(Language.trLang("LASER_SEND_SR_WELD_PATH"))
        return nil
    end
    local recvData = innerReadData(self)
    if not recvData then
        MyWelderDebugLog(Language.trLang("LASER_RECV_SR_WELD_PATH"))
        return nil
    end
    local retData = SplitString(recvData)
    if "002"~=retData[1] then
        MyWelderDebugLog(Language.trLang("LASER_EXEC_SR_WELD_PATH")..",errmsg="..innerGetErrCodeMsg(retData[2]))
        return nil
    end
    local allWeldPathData = innerParseWeldPathData(retData) --所有焊缝的信息
    return allWeldPathData
end

--[[
--焊缝轨迹计算多步融合模式
--robotPose-机器人当前位置{x=1,y=1,z=1,rx=1,ry=1,rz=1}
  moduleNumber-轨迹模板编号
--返回值：
--使用案例如下
beginWeldPathByMultiStep()
for i=1,n do
    continueWeldPathByMultiStep()
end
endWeldPathByMultiStep()
]]--
local function innerWeldPathByMultiStep(self, id, robotPose, moduleNumber)
    local strlog,strlog1,strlog2 = "","",""
    if 0==id then
        strlog=Language.trLang("LASER_SEND_MR_WELD_PATH_START")
        strlog1=Language.trLang("LASER_RECV_MR_WELD_PATH_START")
        strlog2=Language.trLang("LASER_EXEC_MR_WELD_PATH_START")
    elseif 1==id then
        strlog=Language.trLang("LASER_SEND_MR_WELD_PATH_CONTINUE")
        strlog1=Language.trLang("LASER_RECV_MR_WELD_PATH_CONTINUE")
        strlog2=Language.trLang("LASER_EXEC_MR_WELD_PATH_CONTINUE")
    elseif 2==id then
        strlog=Language.trLang("LASER_SEND_MR_WELD_PATH_STOP")
        strlog1=Language.trLang("LASER_RECV_MR_WELD_PATH_STOP")
        strlog2=Language.trLang("LASER_EXEC_MR_WELD_PATH_STOP")
    else return false
    end
    
    local cmd = {"12",tostring(id),tostring(moduleNumber),
                 tostring(robotPose.x),tostring(robotPose.y),tostring(robotPose.z),
                 tostring(robotPose.rx),tostring(robotPose.ry),tostring(robotPose.rz)
                }
    cmd = table.concat(cmd,",")
    if not innerSendData(self, cmd) then
        MyWelderDebugLog(strlog)
        return nil
    end
    local recvData = innerReadData(self)
    if not recvData then
        MyWelderDebugLog(strlog1)
        return nil
    end
    local retData = SplitString(recvData)
    if "999"==retData[1] then
        MyWelderDebugLog(strlog2..",errmsg="..innerGetErrCodeMsg(retData[2]))
        return nil
    end
    return retData
end
function Chishine3DProtocol.beginWeldPathByMultiStep(robotPose, productType)
    local self = Chishine3DProtocol
    local retData = innerWeldPathByMultiStep(self,0,robotPose, productType) or {}
    return retData[1]=="900"
end
function Chishine3DProtocol.continueWeldPathByMultiStep(robotPose, productType)
    local self = Chishine3DProtocol
    local retData = innerWeldPathByMultiStep(self,1,robotPose, productType) or {}
    return retData[1]=="900"
end
function Chishine3DProtocol.endWeldPathByMultiStep(robotPose, productType)
    local self = Chishine3DProtocol
    local retData = innerWeldPathByMultiStep(self,2,robotPose, productType) or {}
    if retData[1]~="002" then
        return nil
    end
    local allWeldPathData = innerParseWeldPathData(retData) --所有焊缝的信息
    return allWeldPathData
end

--[[
--请求工件定位偏差
--robotPose-机器人当前位置{x=1,y=1,z=1,rx=1,ry=1,rz=1}
  baseNumber-基准编号
--返回值：true-成功，false-失败
]]--
function Chishine3DProtocol.workpiecePositionDeviation(robotPose, baseNumber)
    local self = Chishine3DProtocol
    local cmd = {"030",tostring(baseNumber),
                 tostring(robotPose.x),tostring(robotPose.y),tostring(robotPose.z),
                 tostring(robotPose.rx),tostring(robotPose.ry),tostring(robotPose.rz)
                }
    cmd = table.concat(cmd,",")
    if not innerSendData(self, cmd) then
        MyWelderDebugLog(Language.trLang("LASER_SEND_WORKPIECE_OFFSET"))
        return false
    end
    local recvData = innerReadData(self)
    if not recvData then
        MyWelderDebugLog(Language.trLang("LASER_RECV_WORKPIECE_OFFSET"))
        return false
    end
    local retData = SplitString(recvData)
    if "030"~=retData[1] then
        MyWelderDebugLog(Language.trLang("LASER_EXEC_WORKPIECE_OFFSET")..",errmsg="..innerGetErrCodeMsg(retData[2]))
        return false
    end
    --机器人位姿，工件定位偏差
    --retData[2]
    --retData[3]
    --retData[4]
    --retData[5]
    --retData[6]
    --retData[7]
    return true
end

return Chishine3DProtocol