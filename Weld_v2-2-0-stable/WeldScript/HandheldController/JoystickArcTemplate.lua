--[[
焊接模板
]]--

--判断2点是否为同一个点
--pt1和pt2的结构与存点的数据结构一致
local function isSamePoint(pt1, pt2)
    if nil==pt1 or nil==pt2 then return false end
    if pt1.user~=pt2.user or pt1.tool~=pt2.tool then
        return false --不在同一个坐标系下，认为是不同点
    end
    local x = (pt1.pose[1]-pt2.pose[1])^2
    local y = (pt1.pose[2]-pt2.pose[2])^2
    local z = (pt1.pose[3]-pt2.pose[3])^2
    local d = math.sqrt(x+y+z)
    if d <= 1e-5 then return true
    else return false
    end
end

--编辑多层多道焊组合
local function buildGroupScript(self, file, multiIdx)
    local str = ""
    local pt = self.getWeldArcSpeed()
    if nil~=pt and pt>0 then
        str = string.format("WeldAbsSpeed(%s, \"mm/s\")\n", tostring(pt)) --设置焊接速度
        file:write(str)
    end
    
    pt = self.getWeldArcParam()
    if nil~=pt and pt>0 then --设置起弧索引/job号
        if WelderHandleControl.isJobMode() then
            str = string.format("WeldJobNumber(%s)\n", tostring(pt))
        else
            str = string.format("WeldArcParams(%s)\n", tostring(pt))
        end
        file:write(str)
    end
    
    pt = self.getWeldWeaveParam()
    if nil~=pt and pt>0 then --设置摆弧索引
        str = string.format("WeldWeaveParams(%s)\n", tostring(pt))
        file:write(str)
    end

    pt = self.getApproachPoint() --移动到接近点
    if pt then
        str = string.format("MovL({pose={%f,%f,%f,%f,%f,%f}},{user=%d,tool=%d})\n", 
                           pt.pose[1],pt.pose[2],pt.pose[3],pt.pose[4],pt.pose[5],pt.pose[6],pt.user,pt.tool)
        file:write(str)
    end
    
    if multiIdx>0 then --启动多层多道焊
        str = string.format("WeldMultiPassStart(%s)\n", tostring(multiIdx))
        file:write(str)
        --预读点通常是起弧点的下一个点
        local ptArr = self.getMiddlePoint()
        if ptArr and #ptArr>0 then --添加预读点,中间点的第一个直线点/圆弧点是预读点
            pt = ptArr[1][2]
            if 0==ptArr[1][1] then --直线
                str = string.format("PreMovL({pose={%f,%f,%f,%f,%f,%f}},{user=%d,tool=%d,r=5})\n", 
                                    pt.pose[1],pt.pose[2],pt.pose[3],pt.pose[4],pt.pose[5],pt.pose[6],pt.user,pt.tool)
                file:write(str)
            elseif 1==ptArr[1][1] then --圆弧，圆弧必须2个点相邻
                if #ptArr>1 and 1==ptArr[2][1] then
                    local p2 = ptArr[1][2]
                    str = string.format("PreArc({pose={%f,%f,%f,%f,%f,%f}},{pose={%f,%f,%f,%f,%f,%f}},{user=%d,tool=%d,r=5})\n",
                                         pt.pose[1],pt.pose[2],pt.pose[3],pt.pose[4],pt.pose[5],pt.pose[6],
                                         p2.pose[1],p2.pose[2],p2.pose[3],p2.pose[4],p2.pose[5],p2.pose[6],
                                         pt.user,pt.tool)
                    file:write(str)
                end
            end
        elseif nil~=self.getArcEndPoint() then --没有中间点则预读点是灭弧点
            pt = self.getArcEndPoint()
            str = string.format("PreMovL({pose={%f,%f,%f,%f,%f,%f}},{user=%d,tool=%d,r=5})\n", 
                                 pt.pose[1],pt.pose[2],pt.pose[3],pt.pose[4],pt.pose[5],pt.pose[6],pt.user,pt.tool)
            file:write(str)
        end
    end

    pt = self.getArcStartPoint() --移动到起弧点
    if pt then
        str = string.format("MovL({pose={%f,%f,%f,%f,%f,%f}},{user=%d,tool=%d})\n", 
                           pt.pose[1],pt.pose[2],pt.pose[3],pt.pose[4],pt.pose[5],pt.pose[6],pt.user,pt.tool)
        file:write(str)
    end
    
    pt = self.getWeldWeaveParam()
    if nil~=pt and pt>0 then --启动摆弧
        file:write("WeldWeaveStart()\n")
    end
    
    file:write("WeldArcStart()\n") --起弧
    
    --中间点的操作
    local ptArr = self.getMiddlePoint()
    if ptArr then
        local i=1
        while i<=#ptArr do
            if 0==ptArr[i][1] then --直线
                pt = ptArr[i][2]
                str = string.format("MovL({pose={%f,%f,%f,%f,%f,%f}},{user=%d,tool=%d,r=5})\n", 
                                    pt.pose[1],pt.pose[2],pt.pose[3],pt.pose[4],pt.pose[5],pt.pose[6],pt.user,pt.tool)
                file:write(str)
            elseif 1==ptArr[i][1] then --圆弧，圆弧必须2个点相邻
                pt = ptArr[i][2]
                i = i+1
                if i<=#ptArr then --说明有下一个点
                    if 1==ptArr[i][1] then --相邻的下一个点是圆弧
                        local pnext = ptArr[i][2]
                        str = string.format("Arc({pose={%f,%f,%f,%f,%f,%f}},{pose={%f,%f,%f,%f,%f,%f}},{user=%d,tool=%d,r=5})\n",
                                            pt.pose[1],pt.pose[2],pt.pose[3],pt.pose[4],pt.pose[5],pt.pose[6],
                                            pnext.pose[1],pnext.pose[2],pnext.pose[3],pnext.pose[4],pnext.pose[5],pnext.pose[6],
                                            pt.user,pt.tool)
                        file:write(str)
                    else
                        file:close()
                        MyWelderDebugLog("create Arc_Box_Template src0.lua file fail,because of the middle arc point less then 2")
                        return false
                    end
                else
                    file:close()
                    MyWelderDebugLog("create Arc_Box_Template src0.lua file fail,because of the middle arc point less then 2")
                    return false
                end
            end
            i = i+1
        end
    end
    
    local bShouldMov2ArcEndPoint = true --是否需要运行到灭弧点
    --在多层多道焊中，如果相邻的两点是同一个点(距离不大于1e-7mm认为是同一个点)，则会报错。
    --特殊处理：中间点的最后一个点如果与灭弧点是同一个点则不用再运动到灭弧点。
    if multiIdx>0 then --启动了多层多道焊
        ptArr = self.getMiddlePoint() or {}
        ptArr = ptArr[#ptArr] or {}
        if isSamePoint(ptArr[2], self.getArcEndPoint()) then
            bShouldMov2ArcEndPoint = false
        end
    end
    
    if bShouldMov2ArcEndPoint then
        pt = self.getArcEndPoint() --运动到灭弧点
        if pt then
            str = string.format("MovL({pose={%f,%f,%f,%f,%f,%f}},{user=%d,tool=%d})\n", 
                               pt.pose[1],pt.pose[2],pt.pose[3],pt.pose[4],pt.pose[5],pt.pose[6],pt.user,pt.tool)
            file:write(str)
        end
    end
    
    file:write("WeldArcEnd()\n") --灭弧
    
    pt = self.getWeldWeaveParam()
    if nil~=pt and pt>0 then --停止摆弧
        file:write("WeldWeaveEnd()\n")
    end
    
    if multiIdx>0 then --停止多层多道焊
        file:write("WeldMultiPassEnd()\n")
    end
    
    ptArr = self.getLeavePoint() --运动到离开点
    if ptArr then
        for i=1,#ptArr do
            pt = ptArr[i]
            str = string.format("MovL({pose={%f,%f,%f,%f,%f,%f}},{user=%d,tool=%d})\n", 
                                pt.pose[1],pt.pose[2],pt.pose[3],pt.pose[4],pt.pose[5],pt.pose[6],pt.user,pt.tool)
            file:write(str)
        end
    end
    return true
end

--编辑并生成脚本文件
local function buildScript(self)
    local file,errmsg = io.open(self.scriptFile,"w")
    if nil==file then
        MyWelderDebugLog("create Arc_Box_Template src0.lua file fail:"..tostring(errmsg))
        return false
    end
    
    local str = string.format("SpeedFactor(%s)\n", tostring(self.getSpeedFactor())) --设置全局速率
    file:write(str)
    
    local group = WelderHandleControl.getWeldMultiPassGroup(self.getMultiPassParam())
    if group then table.insert(group,1,0) --在最前面插入0，因为多层多道的最开始一道是不做偏移处理，不算一道
    else group = {0}
    end
    for i=1,#group do
        if not buildGroupScript(self, file, group[i]) then
            return false
        end
    end
    
    file:close()
    return true
end

--[[
获取机器人当前点,返回值如下（其实就是全局存点的结构）：
    {
        name="",
        joint={j1,j2,j3,j4,j5,j6},
        pose={x,y,z,rx,ry,rz},
        user=1,
        tool=2
    }
如果失败则返回nil
]]--
local function getCurrentRobotPose()
    local function pfnExec()
        --[[
        local _,info = GetRealTimeFeedback()
        if type(info)~="table" then return nil end
        local user = info["UserCoordinate"]
        local tool = info["ToolCoordinate"]
        if math.type(user)~="integer" or math.type(tool)~="integer" then return nil end
        ]]--
        local user,tool = RobotModbusControl.getUserToolIndex()
        local pose = GetPose(user,tool) --返回值为{pose={x,y,z,rx,ry,rz}}
        local angle = GetAngle() --返回值为{joint={j1,j2,j3,j4,j5,j6}}
        
        local p = {}
        p.name = ""
        p.joint = angle.joint
        p.pose = pose.pose
        p.user = user
        p.tool = tool
        return p
    end
    local bErr,p = pcall(pfnExec)
    if not bErr then
        MyWelderDebugLog(tostring(p))
        return nil
    end
    return p
end

-------------------------------------------------------------------------------------------------------------
--数据库保存的key，不要轻易修改------------------------------------------------------------------------------
local keyJkArcTmpWeldArcSpeed = "Dobot_Weld_Parameter_JoystickArcTemplate_WeldArcSpeed"
local keyJkArcTmpWeldArcIndex = "Dobot_Weld_Parameter_JoystickArcTemplate_WeldArcIndex"
local keyJkArcTmpWeldWaveIndex = "Dobot_Weld_Parameter_JoystickArcTemplate_WeldWaveIndex"
local keyJkArcTmpSpeedFactor = "Dobot_Weld_Parameter_JoystickArcTemplate_SpeedFactor"
local keyJkArcTmpMultiPassIndex = "Dobot_Weld_Parameter_JoystickArcTemplate_MultiPassIndex"

local keyJkArcTmpApproachPoint = "Dobot_Weld_Parameter_JoystickArcTemplate_ApproachPoint"
local keyJkArcTmpArcStartPoint = "Dobot_Weld_Parameter_JoystickArcTemplate_ArcStartPoint"
local keyJkArcTmpArcEndPoint = "Dobot_Weld_Parameter_JoystickArcTemplate_ArcEndPoint"
local keyJkArcTmpLeavePoint = "Dobot_Weld_Parameter_JoystickArcTemplate_LeavePoint"
local keyJkArcTmpMiddlePoint = "Dobot_Weld_Parameter_JoystickArcTemplate_MiddlePoint"
--【导出函数】-------------------------------------------------------------------------------------------
local JoystickArcTemplate = {
    scriptFile = "/dobot/userdata/user_project/project/Arc_Box_Template/src0.lua",
    approachPoint = nil, --接近点
    arcStartPoint = nil, --起弧点
    arcEndPoint = nil, --灭弧点
    leavePoint = nil, --离开点
    middlePoint = nil, --中间点，有多个
    weldArcSpeed = nil, --焊接速度
    weldArcIndex = nil, --起弧索引/job
    weldWaveIndex = nil, --摆弧索引
    speedFactor = nil, --全局比例数值
    multiPassIndex = nil --多层多道焊组合索引
}

function JoystickArcTemplate.clear()
    pcall(os.remove,JoystickArcTemplate.scriptFile)
    JoystickArcTemplate.clearApproachPoint()
    JoystickArcTemplate.clearArcStartPoint()
    JoystickArcTemplate.clearArcEndPoint()
    JoystickArcTemplate.clearLeavePoint()
    JoystickArcTemplate.clearMiddlePoint()
    JoystickArcTemplate.setWeldArcSpeed(nil,false)
    JoystickArcTemplate.setWeldArcParam(nil,false)
    JoystickArcTemplate.setWeldWeaveParam(nil,false)
    JoystickArcTemplate.setSpeedFactor(nil,false)
    JoystickArcTemplate.setMultiPassParam(nil,false)
end

function JoystickArcTemplate.initWeldParams(speed,arcIndex,waveIndex)
    JoystickArcTemplate.setWeldArcSpeed(speed,false)
    JoystickArcTemplate.setWeldArcParam(arcIndex,false)
    JoystickArcTemplate.setWeldWeaveParam(waveIndex,false)
end

function JoystickArcTemplate.setWeldArcSpeed(speed, isBuild)
    JoystickArcTemplate.weldArcSpeed = speed
    SetVal(keyJkArcTmpWeldArcSpeed,speed)
    if false==isBuild then return true end
    return JoystickArcTemplate.build()
end
function JoystickArcTemplate.getWeldArcSpeed()
    if nil==JoystickArcTemplate.weldArcSpeed then
        JoystickArcTemplate.weldArcSpeed = GetVal(keyJkArcTmpWeldArcSpeed) or 10
    end
    return JoystickArcTemplate.weldArcSpeed
end

function JoystickArcTemplate.setWeldArcParam(idx, isBuild)
    JoystickArcTemplate.weldArcIndex = idx
    SetVal(keyJkArcTmpWeldArcIndex,idx)
    if false==isBuild then return true end
    return JoystickArcTemplate.build()
end
function JoystickArcTemplate.getWeldArcParam()
    if nil==JoystickArcTemplate.weldArcIndex then
        JoystickArcTemplate.weldArcIndex = GetVal(keyJkArcTmpWeldArcIndex) or 1
    end
    return JoystickArcTemplate.weldArcIndex
end

function JoystickArcTemplate.setWeldWeaveParam(idx, isBuild)
    JoystickArcTemplate.weldWaveIndex = idx
    SetVal(keyJkArcTmpWeldWaveIndex,idx)
    if false==isBuild then return true end
    return JoystickArcTemplate.build()
end
function JoystickArcTemplate.getWeldWeaveParam()
    if nil==JoystickArcTemplate.weldWaveIndex then
        JoystickArcTemplate.weldWaveIndex = GetVal(keyJkArcTmpWeldWaveIndex) or 0
    end
    return JoystickArcTemplate.weldWaveIndex
end

function JoystickArcTemplate.setMultiPassParam(idx, isBuild)
    JoystickArcTemplate.multiPassIndex = idx
    SetVal(keyJkArcTmpMultiPassIndex,idx)
    if false==isBuild then return true end
    return JoystickArcTemplate.build()
end
function JoystickArcTemplate.getMultiPassParam()
    if nil==JoystickArcTemplate.multiPassIndex then
        JoystickArcTemplate.multiPassIndex = GetVal(keyJkArcTmpMultiPassIndex) or 0
    end
    return JoystickArcTemplate.multiPassIndex
end

function JoystickArcTemplate.setSpeedFactor(speed, isBuild)
    JoystickArcTemplate.speedFactor = speed
    SetVal(keyJkArcTmpSpeedFactor,speed)
    if false==isBuild then return true end
    return JoystickArcTemplate.build()
end
function JoystickArcTemplate.getSpeedFactor()
    if nil==JoystickArcTemplate.speedFactor then
        JoystickArcTemplate.speedFactor = GetVal(keyJkArcTmpSpeedFactor) or 10
    end
    return JoystickArcTemplate.speedFactor
end

function JoystickArcTemplate.setApproachPoint()
    JoystickArcTemplate.approachPoint = getCurrentRobotPose()
    SetVal(keyJkArcTmpApproachPoint,JoystickArcTemplate.approachPoint)
    return nil~=JoystickArcTemplate.approachPoint
end
function JoystickArcTemplate.getApproachPoint()
    if nil==JoystickArcTemplate.approachPoint then
        JoystickArcTemplate.approachPoint = GetVal(keyJkArcTmpApproachPoint)
    end
    return JoystickArcTemplate.approachPoint
end
function JoystickArcTemplate.clearApproachPoint()
    JoystickArcTemplate.approachPoint = nil
    SetVal(keyJkArcTmpApproachPoint,nil)
end

function JoystickArcTemplate.setArcStartPoint()
    JoystickArcTemplate.arcStartPoint = getCurrentRobotPose()
    SetVal(keyJkArcTmpArcStartPoint,JoystickArcTemplate.arcStartPoint)
    return nil~=JoystickArcTemplate.arcStartPoint
end
function JoystickArcTemplate.getArcStartPoint()
    if nil==JoystickArcTemplate.arcStartPoint then
        JoystickArcTemplate.arcStartPoint = GetVal(keyJkArcTmpArcStartPoint)
    end
    return JoystickArcTemplate.arcStartPoint
end
function JoystickArcTemplate.clearArcStartPoint()
    JoystickArcTemplate.arcStartPoint = nil
    SetVal(keyJkArcTmpArcStartPoint,nil)
end

function JoystickArcTemplate.addMiddleLinePoint()
    local p = getCurrentRobotPose()
    if nil==p then return false end
    JoystickArcTemplate.middlePoint = JoystickArcTemplate.middlePoint or {}
    table.insert(JoystickArcTemplate.middlePoint,{0,p})
    return true
end
function JoystickArcTemplate.addMiddleArcPoint()
    local p = getCurrentRobotPose()
    if nil==p then return false end
    
    JoystickArcTemplate.middlePoint = JoystickArcTemplate.middlePoint or {}
    table.insert(JoystickArcTemplate.middlePoint,{1,p})
    
    --圆弧点必须是偶数个，且两两相邻
    local iPreArcIdx = -1 --上一个圆弧点的位置，这个值如果不为0则表明点不够
    for i=1,#JoystickArcTemplate.middlePoint do
        if 1==JoystickArcTemplate.middlePoint[i][1] then --找到了一个圆弧点
            if i==(iPreArcIdx+1) then --说明相邻的点也是圆弧
                iPreArcIdx = -1
            else
                iPreArcIdx = i --相邻的前一个点不是圆弧，则记录当前圆弧点位置
            end
        end
    end
    if -1==iPreArcIdx then --当前点足够
        return 2 --JoystickArcTemplate.build()
    end
    return 1 --表示当前点不够
end
function JoystickArcTemplate.getMiddlePoint()
    if nil==JoystickArcTemplate.middlePoint then
        JoystickArcTemplate.middlePoint = GetVal(keyJkArcTmpMiddlePoint)
    end
    return JoystickArcTemplate.middlePoint
end
function JoystickArcTemplate.clearMiddlePoint()
    JoystickArcTemplate.middlePoint = nil
    SetVal(keyJkArcTmpMiddlePoint,nil)
end

function JoystickArcTemplate.setArcEndPoint()
    JoystickArcTemplate.arcEndPoint = getCurrentRobotPose()
    SetVal(keyJkArcTmpArcEndPoint,JoystickArcTemplate.arcEndPoint)
    return nil~=JoystickArcTemplate.arcEndPoint
end
function JoystickArcTemplate.getArcEndPoint()
    if nil==JoystickArcTemplate.arcEndPoint then
        JoystickArcTemplate.arcEndPoint = GetVal(keyJkArcTmpArcEndPoint)
    end
    return JoystickArcTemplate.arcEndPoint
end
function JoystickArcTemplate.clearArcEndPoint()
    JoystickArcTemplate.arcEndPoint = nil
    SetVal(keyJkArcTmpArcEndPoint,nil)
end

--在离开点时生成文件
function JoystickArcTemplate.addLeavePoint()
    local p = getCurrentRobotPose()
    if nil==p then return false end
    if nil==JoystickArcTemplate.leavePoint then
        JoystickArcTemplate.leavePoint = {}
    end
    table.insert(JoystickArcTemplate.leavePoint, p)
    SetVal(keyJkArcTmpLeavePoint,JoystickArcTemplate.leavePoint)
    return JoystickArcTemplate.build()
end
function JoystickArcTemplate.getLeavePoint()
    if nil==JoystickArcTemplate.leavePoint then
        JoystickArcTemplate.leavePoint = GetVal(keyJkArcTmpLeavePoint)
    end
    return JoystickArcTemplate.leavePoint
end
function JoystickArcTemplate.clearLeavePoint()
    JoystickArcTemplate.leavePoint = nil
    SetVal(keyJkArcTmpLeavePoint,nil)
end

function JoystickArcTemplate.build()
    local ok,msg = pcall(buildScript, JoystickArcTemplate)
    if not ok then
        MyWelderDebugLog(tostring(msg))
        os.remove(JoystickArcTemplate.scriptFile)
        return false
    end
    if msg ~= true then --创建文件失败，则需要将文件删掉，防止跑脚本出事故
        os.remove(JoystickArcTemplate.scriptFile)
        return false
    end
    return true
end

return JoystickArcTemplate