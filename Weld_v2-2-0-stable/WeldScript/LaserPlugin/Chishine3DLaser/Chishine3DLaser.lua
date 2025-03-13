--[[
知象光电
]]--
local Chishine3DLaser = {
    ip = nil,
    port = nil
}

--设置IP端口
function Chishine3DLaser.setAddress(ip, port)
    local self = Chishine3DLaser
    self.ip = ip
    self.port = port
end

--[[
功能：内参标定
参数：beginPointInfo-开始拍照点信息
      continuePointInfoArray-继续拍照点信息数组
      endPointInfo-结束拍照点信息
返回值：true-成功，false-失败
说明：beginPointInfo与endPointInfo数据结构完全相同，continuePointInfoArray的每个元素与beginPointInfo相同。
      beginPointInfo的数据结构如下：{P,ExposureValue}
      其中P为示教点，等同存点列表中点的结构，ExposureValue为相机曝光值。
      {
          {
            name = "name",
            pose = {x, y, z, rx, ry, rz},
            joint = {j1, j2, j3, j4, j5, j6},
            tool = index,
            user = index
          },
          4000
      }
]]--
function Chishine3DLaser.internalParamCalibrate(beginPointInfo, continuePointInfoArray, endPointInfo)
    local self = Chishine3DLaser
    if not Chishine3DProtocol.connect(self.ip,self.port) then
        return false
    end
    --因为标定软件的“TCP字符串”通信模式无法设置结束符参数，所以去掉结束符判断
    Chishine3DProtocol.setEndChar()
    
    local bIsSuccess = false --是否成功
    local delayTimes = 1000 --延迟ms时间，让机器稳定下来
    
    --开始标定
    MovL(beginPointInfo[1])
    Wait(delayTimes)
    if not Chishine3DProtocol.beginCalibrate(beginPointInfo[2]) then
        goto labelExit
    end
    
    --继续标定
    for i=1,#continuePointInfoArray do
        MovL(continuePointInfoArray[i][1])
        Wait(delayTimes)
        if not Chishine3DProtocol.continueCalibrate(continuePointInfoArray[i][2]) then
            goto labelExit
        end
    end
    
    --结束标定
    MovL(endPointInfo[1])
    Wait(delayTimes)
    if not Chishine3DProtocol.endCalibrate(endPointInfo[2]) then
        goto labelExit
    end
    
    bIsSuccess = true --成功了
    
::labelExit::
    Chishine3DProtocol.disconnect()
    return bIsSuccess
end

--[[
功能：手眼标定
参数：safePoint-安全过渡点，数据结构等同存点列表中点的结构
      beginPointInfo-开始拍照点信息
      continuePointInfoArray-继续拍照点信息数组
      touchPointInfoArray--触碰拍照点信息数组
      endPointInfo-结束拍照点信息
返回值：true-成功，false-失败
说明：几个拍照点的参数数据结构等同`internalParamCalibrate(...)`，请参考它
]]--
function Chishine3DLaser.eyeHandleCalibrate(safePoint, beginPointInfo, continuePointInfoArray, touchPointInfoArray, endPointInfo)
    local self = Chishine3DLaser
    if not Chishine3DProtocol.connect(self.ip,self.port) then
        return false
    end
    --因为标定软件的“TCP字符串”通信模式无法设置结束符参数，所以去掉结束符判断
    Chishine3DProtocol.setEndChar()
    
--[[一定要看这段话：
知象光电最后一个触碰点才表示结束点，也就是那标定结果的点。
而这里的最后一个点实际就是在继续点里面
]]--
    table.insert(continuePointInfoArray,endPointInfo)
    endPointInfo = table.remove(touchPointInfoArray,#touchPointInfoArray)
    
    local bIsSuccess = false --是否成功
    local delayTimes = 1000 --延迟ms时间，让机器稳定下来
    local robotPose={x=0,y=0,z=0,rx=0,ry=0,rz=0}
    local pt --点位
    local value --曝光值
    
    MovL(safePoint) --运动至安全过渡点
    
    --开始标定
    pt = beginPointInfo[1]
    value = beginPointInfo[2]
    MovL(pt)
    Wait(delayTimes)
    robotPose={x=pt.pose[1],y=pt.pose[2],z=pt.pose[3],rx=pt.pose[4],ry=pt.pose[5],rz=pt.pose[6]}
    if not Chishine3DProtocol.photoPointEyeHandleCalibrate(robotPose,value) then
        goto labelExit
    end

    --继续拍照点
    for i=1,#continuePointInfoArray do
        MovL(safePoint) --运动至安全过渡点
        pt = continuePointInfoArray[i][1]
        value = continuePointInfoArray[i][2]
        MovL(pt)
        Wait(delayTimes)
        robotPose={x=pt.pose[1],y=pt.pose[2],z=pt.pose[3],rx=pt.pose[4],ry=pt.pose[5],rz=pt.pose[6]}
        if not Chishine3DProtocol.continueEyeHandleCalibrate(robotPose,value) then
            goto labelExit
        end
    end

    --触摸拍照点
    for i=1,#touchPointInfoArray do
        MovL(safePoint) --运动至安全过渡点
        pt = touchPointInfoArray[i][1]
        value = touchPointInfoArray[i][2]
        MovL(pt)
        Wait(delayTimes)
        robotPose={x=pt.pose[1],y=pt.pose[2],z=pt.pose[3],rx=pt.pose[4],ry=pt.pose[5],rz=pt.pose[6]}
        if not Chishine3DProtocol.touchPointEyeHandleCalibrate(robotPose,value) then
            goto labelExit
        end
    end
    
    MovL(safePoint) --运动至安全过渡点
    
    --结束标定
    pt = endPointInfo[1]
    value = endPointInfo[2]
    MovL(pt)
    Wait(delayTimes)
    robotPose={x=pt.pose[1],y=pt.pose[2],z=pt.pose[3],rx=pt.pose[4],ry=pt.pose[5],rz=pt.pose[6]}
    if not Chishine3DProtocol.endEyeHandleCalibrate(robotPose,value) then
        goto labelExit
    end
    
    MovL(safePoint) --运动至安全过渡点
    
    bIsSuccess = true --成功了
    
::labelExit::
    Chishine3DProtocol.disconnect()
    return bIsSuccess
end

--[[
功能：单步拍照模式
参数：takePhotoPoint-拍照点，数据结构等同存点列表中点的结构
      visionNumber-视觉模板号
返回值：焊缝点位信息数组对象，参考`Chishine3DProtocol.lua的WeldPathData`
]]--
function Chishine3DLaser.singleStepTakePhoto(takePhotoPoint, visionNumber)
    local self = Chishine3DLaser
    if not Chishine3DProtocol.connect(self.ip,self.port) then
        return nil
    end
    --因为标定软件的“TCP字符串”通信模式无法设置结束符参数，所以去掉结束符判断
    Chishine3DProtocol.setEndChar()
    
    local delayTimes = 1500 --延迟ms时间，让机器稳定下来
    local robotPose=nil
    local moduleNumber = visionNumber --视觉模板编号
    local allWeldPathData = nil --单步拍照模式的结果数据
    
    if not Chishine3DProtocol.startControlVisionService() then
        goto labelExit
    end

    --单步拍照模式
    MovL(takePhotoPoint)
    Wait(delayTimes)
    robotPose={x=takePhotoPoint.pose[1],y=takePhotoPoint.pose[2],z=takePhotoPoint.pose[3],
               rx=takePhotoPoint.pose[4],ry=takePhotoPoint.pose[5],rz=takePhotoPoint.pose[6]}
    allWeldPathData = Chishine3DProtocol.weldPathByOneStep(robotPose, moduleNumber) or {}
    if #allWeldPathData<1 then
        allWeldPathData = nil
        goto labelExit
    end
    print(allWeldPathData)
    
::labelExit::
    Chishine3DProtocol.stopControlVisionService()
    Chishine3DProtocol.disconnect()
    
    return allWeldPathData
end

--[[
功能：多步融合拍照模式
参数：beginPointInfo-开始拍照点信息
      continuePointInfoArray-继续拍照点信息数组
      endPointInfo-结束拍照点信息
返回值：焊缝点位信息数组对象，参考`Chishine3DProtocol.lua的WeldPathData`
      `beginPointInfo`与`endPointInfo`数据结构完全相同，`continuePointInfoArray`的每个元素与`beginPointInfo`相同。
      beginPointInfo的数据结构如下：{P,visionNumber,photoType}
      其中photoType=0表示拍照点，photoType=1表示过渡点，这个字段在`continuePointInfoArray`中有意义。
      其中P为示教点，等同存点列表中点的结构，visionNumber为视觉模板编号。
      {
          {
            name = "name",
            pose = {x, y, z, rx, ry, rz},
            joint = {j1, j2, j3, j4, j5, j6},
            tool = index,
            user = index
          },
          1
      }
]]--
function Chishine3DLaser.multipleStepTakePhoto(beginPointInfo, continuePointInfoArray, endPointInfo)
    local self = Chishine3DLaser
    if not Chishine3DProtocol.connect(self.ip,self.port) then
        return nil
    end
    --因为标定软件的“TCP字符串”通信模式无法设置结束符参数，所以去掉结束符判断
    Chishine3DProtocol.setEndChar()
    
    local delayTimes = 1500 --延迟ms时间，让机器稳定下来
    local robotPose=nil
    local pt --点位
    local moduleNumber --视觉模板编号
    local photoType --点类型
    local allWeldPathData = nil --多步融合拍照模式的结果数据
    
    if not Chishine3DProtocol.startControlVisionService() then
        goto labelExit
    end
    
    --融合拍照开始
    pt = beginPointInfo[1]
    moduleNumber = beginPointInfo[2]
    MovL(pt)
    Wait(delayTimes)
    robotPose={x=pt.pose[1],y=pt.pose[2],z=pt.pose[3],rx=pt.pose[4],ry=pt.pose[5],rz=pt.pose[6]}
    if not Chishine3DProtocol.beginWeldPathByMultiStep(robotPose,moduleNumber) then
        goto labelExit
    end
    
    --继续拍照点
    for i=1, #continuePointInfoArray do
        pt = continuePointInfoArray[i][1]
        moduleNumber = continuePointInfoArray[i][2]
        photoType = continuePointInfoArray[i][3]
        MovL(pt)
        if 0==photoType then
            Wait(delayTimes)
            robotPose={x=pt.pose[1],y=pt.pose[2],z=pt.pose[3],rx=pt.pose[4],ry=pt.pose[5],rz=pt.pose[6]}
            if not Chishine3DProtocol.continueWeldPathByMultiStep(robotPose,moduleNumber) then
                goto labelExit
            end
        end
    end
    
    --结束拍照点
    pt = endPointInfo[1]
    moduleNumber = endPointInfo[2]
    MovL(pt)
    Wait(delayTimes)
    robotPose={x=pt.pose[1],y=pt.pose[2],z=pt.pose[3],rx=pt.pose[4],ry=pt.pose[5],rz=pt.pose[6]}
    allWeldPathData = Chishine3DProtocol.endWeldPathByMultiStep(robotPose, moduleNumber) or {}
    if #allWeldPathData<1 then
        allWeldPathData = nil
        goto labelExit
    end
    print(allWeldPathData)
    
::labelExit::
    Chishine3DProtocol.stopControlVisionService()
    Chishine3DProtocol.disconnect()
    
    return allWeldPathData
end

return Chishine3DLaser