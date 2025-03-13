--[[
通用激光器接口类，为了统一描述对外接口，让子类去实现具体功能
]]--


local ICommonLaser = {}
ICommonLaser.__index = ICommonLaser

---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
--[[
功能：连接激光器
参数：ip-地址,port-端口
返回值：true表示成功，false表示失败
]]--
function ICommonLaser.connect(ip,port)
    return false
end

--[[
功能：是否已连接
参数：无
返回值：true-已连接，false-未连接
]]--
function ICommonLaser.isConnected()
    return false
end

--[[
功能：断开激光器的连接
参数：无
返回值：无
]]--
function ICommonLaser.disconnect()
end

--[[
功能：打开、关闭激光
参数：无
返回值：true表示成功，false表示失败
]]--
function ICommonLaser.openLaser()
    return false
end
function ICommonLaser.closeLaser()
    return false
end

--[[
功能：自动标定
参数：arrTeachPoint-标定时示教点数组，数组中每个点结构等同存点列表中点的结构，如下：
      {
        name = "name",
        pose = {x, y, z, rx, ry, rz},
        joint = {j1, j2, j3, j4, j5, j6},
        tool = index,
        user = index
      }
      optParams-可选参数{v = 50, a = 50}
返回值：true-成功，false-失败
]]--
function ICommonLaser.autoLaserCalibrate(arrTeachPoint,optParams)
    return false
end

--[[
功能：焊道样式(任务号)选择
参数：num任务号
返回值：true表示成功，false表示失败
]]--
function ICommonLaser.setTaskNumber(num)
    return false
end

--[[
功能：获取机器人寻位目标点位置
参数：robotPose-激光照射时机器人当前的点位信息，格式与全局变量P相同：
      {
        name = "name",
        pose = {x, y, z, rx, ry, rz},
        joint = {j1, j2, j3, j4, j5, j6},
        tool = index,
        user = index
      }
返回值：成功返回坐标值{x=1,y=1,z=1,rx=1,ry=1,rz=1}，xyz单位mm,Rxyz单位是角度deg，失败返回nil
说明：该返回值为机器人目标坐标值，可以直接运动到该点。
]]--
function ICommonLaser.getRobotPosePosition(robotPose)
    return nil
end

--[[
功能：开始、停止跟踪
参数：无
返回值：true表示成功，false表示失败
]]--
function ICommonLaser.startTrack()
    return false
end
function ICommonLaser.stopTrack()
    return false
end

--[[
功能：获取机器人跟踪目标点位置
参数：robotPose-激光照射时机器人当前的点位信息，格式与全局变量P相同：
      {
        name = "name",
        pose = {x, y, z, rx, ry, rz},
        joint = {j1, j2, j3, j4, j5, j6},
        tool = index,
        user = index
      }
返回值：成功返回坐标值{x=1,y=1,z=1,rx=1,ry=1,rz=1}，xyz单位mm,Rxyz单位是角度deg，失败返回nil
说明：该返回值为机器人目标坐标值，可以直接运动到该点。
]]--
function ICommonLaser.getRobotPoseTrack(robotPose)
    return nil
end

return ICommonLaser