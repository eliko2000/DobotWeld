--[[
激光寻位功能封装
说明：因为各大厂家激光器寻位功能还不了解，所以暂时不要封装那么深，简单粗暴就可以。
]]--

--【本地私有接口】
--明图激光寻位
local function innerMingTuLaserPosition(self, robotPose, iTaskNumber)
    local pos = nil
    if not self.selLaserObj.setTaskNumber(iTaskNumber) then --设置任务号
        return pos
    end
    self.selLaserObj.openLaser()
    Wait(200) --打开后需要延迟一段时间，否则大概率拿不到数据
    pos = self.selLaserObj.getToolPose()
    if nil~=pos then --明图激光器得到的是相对于工具坐标系的偏移值，所以要转换为用户坐标系下的值
        --pos.rx,pos.ry,pos.rz,激光器目前返回的姿态应该是无用的，置0会安全些
        local offsetPose = RelPointTool(robotPose,{pos.x,pos.y,pos.z,0,0,0})
        pos.x = offsetPose.pose[1]
        pos.y = offsetPose.pose[2]
        pos.z = offsetPose.pose[3]
        pos.rx = offsetPose.pose[4]
        pos.ry = offsetPose.pose[5]
        pos.rz = offsetPose.pose[6]
    end
    self.selLaserObj.closeLaser()
    Wait(50)
    return pos
end

--英莱激光寻位
local function innerIntelligenLaserPosition(self, robotPose, iTaskNumber)
    local pos = nil
    local sendPose = {}
    sendPose.x = robotPose.pose[1]
    sendPose.y = robotPose.pose[2]
    sendPose.z = robotPose.pose[3]
    sendPose.rx = robotPose.pose[4]
    sendPose.ry = robotPose.pose[5]
    sendPose.rz = robotPose.pose[6]
    if not self.selLaserObj.setTaskNumber(iTaskNumber) then return pos end
    self.selLaserObj.setRobotPose(sendPose) --设置当前机器人位置
    if not self.selLaserObj.openLaser() then return pos end
    if not self.selLaserObj.changeGapType() then
        self.selLaserObj.closeLaser()
        return pos
    end
    Wait(200)
    pos = self.selLaserObj.getRobotPose()
    self.selLaserObj.closeLaser()
    Wait(50)
    if nil~=pos then --寻位的结果是没有姿态的，所以直接使用原始点的姿态
        pos.rx = robotPose.pose[4]
        pos.ry = robotPose.pose[5]
        pos.rz = robotPose.pose[6]
    end
    return pos
end

---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
--【导出接口】
local SmartLaserPosition = {
    selLaserObj = nil, --当前选中的激光器
    pfnLaserPosition = nil --当前选中的激光寻位函数
}

---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
--[[
功能：选择激光器
参数：name-激光器名称，只能是`EnumConstant.ConstEnumLaserPluginName`的值
返回值：无
]]--
function SmartLaserPosition.selectLaser(name)
    local self = SmartLaserPosition
    if "MingTu"==name then
        self.selLaserObj = SMTMingTuLaserPosition
        self.pfnLaserPosition = innerMingTuLaserPosition
        return true
    elseif "Intelligen"==name then
        self.selLaserObj = SMTIntelligenLaserPosition
        self.pfnLaserPosition = innerIntelligenLaserPosition
        return true
    else
        self.pfnLaserPosition = nil
        MyWelderDebugLog(Language.trLang("LASER_NOADAPTER_POSITION")..":"..tostring(name))
        return false
    end
end

--[[
功能：连接激光器
参数：ip-地址,
      port-端口
返回值：true表示成功，false表示失败
]]--
function SmartLaserPosition.connect(ip,port)
    local self = SmartLaserPosition
    return self.selLaserObj.connect(ip,port)
end

--[[
功能：断开是否已连接
参数：无
返回值：true-已连接，false-未连接
]]--
function SmartLaserPosition.isConnected()
    local self = SmartLaserPosition
    return self.selLaserObj.isConnected()
end

--[[
功能：断开激光器的连接
参数：无
返回值：无
]]--
function SmartLaserPosition.disconnect()
    local self = SmartLaserPosition
    self.selLaserObj.disconnect()
end

--[[
功能：激光寻位，返回结果值
参数：robotPose-拍照点位信息，结构等同存点列表中点的结构
     iTaskNumber-任务/焊缝类型编号，不同厂家这个值范围不一样
返回值：成功返回{x=1,y=1,z=1,rx=1,ry=1,rz=1}，失败返回nil
说明：点位信息是指：拍照时，机器人所处的位姿，robotPose参数结构如下
        {
        name = "name",
        pose = {x, y, z, rx, ry, rz},
        joint = {j1, j2, j3, j4, j5, j6},
        tool = index,
        user = index
       }
]]--
function SmartLaserPosition.getLaserPositioning(robotPose, iTaskNumber)
    local self = SmartLaserPosition
    local pos = nil
    MyWelderDebugLog(Language.trLang("LASER_START_POSITION"))
    if nil~=self.pfnLaserPosition then
        pos = self.pfnLaserPosition(self, robotPose, iTaskNumber)
        MyWelderDebugLog(Language.trLang("LASER_END_POSITION"))
    else
        MyWelderDebugLog(Language.trLang("LASER_NOADAPTER_NO_POSITION"))
    end
    return pos
end

return SmartLaserPosition