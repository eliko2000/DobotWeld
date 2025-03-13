--[[
通过modbus控制器机器人，读写机器人的相关信息，这个是控制器内置的功能
]]--

--【本地私有接口】-----------------------------------------------------------------------------------------
local g_innerRobotModbusControlLockerName = "RobotModbusControlLocker-2F232894-51B7-4981-9A6B-36FE59D25DC1"
local function enterLock()
    Lock(g_innerRobotModbusControlLockerName,8000,10000)
end
local function leaveLock()
    UnLock(g_innerRobotModbusControlLockerName)
end

--线程安全的调用函数
local function safeCallFunc(pfn,...)
    enterLock()
    local isOk,v1,v2,v3,v4,v5,v6,v7,v8,v9,v10 = pcall(pfn,...)
    leaveLock()
    return isOk,v1,v2,v3,v4,v5,v6,v7,v8,v9,v10
end
-----------------------------------------------------------------------------------------------------------

--生成一个短暂“低-高-低”脉冲信号
local function triggerSetCoils(id,addr)
    SetCoils(id, addr, 1, {0})
    Wait(100)
    SetCoils(id, addr, 1, {1})
    Wait(100)
    SetCoils(id, addr, 1, {0})
end

-----------------------------------------------------------------------------------------------------------
--【机器人运动控制对象】-----------------------------------------------------------------------------------
--重要说明：
--在脚本中通过modbustcp控制机器人运动，需要在Pro的连接界面，将“IO/modbus配置”打开。
local RobotModbusControl = {
    id = nil --modbus成功连接的句柄id
}

--返回true表示成功，false表示失败
function RobotModbusControl.connect()
    local self = RobotModbusControl
    if self.isConnected() then return true end
    local err, id = ModbusCreate("127.0.0.1", 502, 1)
    if 0==err then
        MyWelderDebugLog("RobotModbusControl ModbusCreate success")
        self.id = id
    else
        MyWelderDebugLog("RobotModbusControl ModbusCreate fail,err="..tostring(err))
        self.id = nil
    end
    return 0==err
end

--返回true-已连接，false-未连接
function RobotModbusControl.isConnected()
    local self = RobotModbusControl
    return nil~=self.id
end

--断开连接
function RobotModbusControl.disconnect()
    local self = RobotModbusControl
    if nil~=self.id then
        ModbusClose(self.id)
        self.id = nil
        MyWelderDebugLog("RobotModbusControl ModbusCreate has close")
    end
end

--获取当前用户坐标和工具坐标索引，返回：user,tool
function RobotModbusControl.getUserToolIndex()
    local tv = GetInRegs(RobotModbusControl.id, 1506, 1, "U16") or {0}
    local user = tv[1]&0xFF
    local tool = (tv[1]>>8)&0xFF
    return user,tool
end

--启动虚拟焊
function RobotModbusControl.startVirtualWeld()
    if true~=WelderHandleControl.isVirtualWeld() then --不是虚拟则设置虚拟焊
        WelderHandleControl.setVirtualWeld(true)
    end
    triggerSetCoils(RobotModbusControl.id, 0)
end
--继续虚拟焊
function RobotModbusControl.continueVirtualWeld()
    triggerSetCoils(RobotModbusControl.id, 0)
end
--暂停虚拟焊
function RobotModbusControl.pauseVirtualWeld()
    triggerSetCoils(RobotModbusControl.id, 2)
end

--启动真实焊
function RobotModbusControl.startRealWeld()
    if false~=WelderHandleControl.isVirtualWeld() then --不是真实则设置真实焊
        WelderHandleControl.setVirtualWeld(false)
    end
    triggerSetCoils(RobotModbusControl.id, 0)
end
--继续真实焊
function RobotModbusControl.continueRealWeld()
    triggerSetCoils(RobotModbusControl.id, 0)
end
--暂停真实焊
function RobotModbusControl.pauseRealWeld()
    triggerSetCoils(RobotModbusControl.id, 2)
end

--停止脚本工程
function RobotModbusControl.stopProject()
    triggerSetCoils(RobotModbusControl.id, 1)
end

--丄使能
function RobotModbusControl.enableRobot()
    triggerSetCoils(RobotModbusControl.id, 3)
end
--下使能
function RobotModbusControl.disableRobot()
    triggerSetCoils(RobotModbusControl.id, 4)
end

--清除报警
function RobotModbusControl.clearWarn()
    triggerSetCoils(RobotModbusControl.id, 5)
end

--进入拖拽
function RobotModbusControl.enableDrag()
    triggerSetCoils(RobotModbusControl.id, 6)
end
--退出拖拽
function RobotModbusControl.disableDrag()
    triggerSetCoils(RobotModbusControl.id, 7)
end

--获取/设置当前全局速度比例
function RobotModbusControl.getSpeedFactor()
    local tv = GetInRegs(RobotModbusControl.id, 1032, 4, "U16") or {}
    if #tv~=4 then return 1 end
    local v1 = tv[1]&0xFF
    local v2 = (tv[1]>>8)&0xFF
    local v3 = tv[2]&0xFF
    local v4 = (tv[2]>>8)&0xFF
    local v5 = tv[3]&0xFF
    local v6 = (tv[3]>>8)&0xFF
    local v7 = tv[4]&0xFF
    local v8 = (tv[4]>>8)&0xFF
    local f = string.unpack("<d",string.char(v1,v2,v3,v4,v5,v6,v7,v8))
    return math.modf(f)
end
function RobotModbusControl.setSpeedFactor(speed)
    local s = {speed&0xFFFF}
    return 0==SetHoldRegs(RobotModbusControl.id, 2048, #s, s, "U16")
end

function RobotModbusControl.runRobot(name)
    if not RobotModbusControl.isConnected() then return false end
    
    local start,value,lsh = 8,1,0
    if "x+"==name then
        lsh = 9-start
    elseif "x-"==name then
        lsh = 10-start
    elseif "y+"==name then
        lsh = 11-start
    elseif "y-"==name then
        lsh = 12-start
    elseif "z+"==name then
        lsh = 13-start
    elseif "z-"==name then
        lsh = 14-start
    elseif "rx+"==name then
        lsh = 15-start
    elseif "rx-"==name then
        lsh = 16-start
    elseif "ry+"==name then
        lsh = 17-start
    elseif "ry-"==name then
        lsh = 18-start
    elseif "rz+"==name then
        lsh = 19-start
    elseif "rz-"==name then
        lsh = 20-start
    elseif "stop"==name then
        lsh = 8-start
    else
        value = 0
    end
    value = value<<lsh
    local data={}
    for i=0,12 do
        table.insert(data,(value>>i)&0x01)
    end
    return 0==SetCoils(RobotModbusControl.id, start, #data, data)
end

--[[获取/设置点动类型
返回值：1-关节点动,2-笛卡尔点动,3-工具点动
]]--
function RobotModbusControl.getJogMode()
    local tv = GetInRegs(RobotModbusControl.id, 2049, 1, "U16") or {1}
    return tv[1]&0xFF
end
function RobotModbusControl.setJogModeJoint()
    return 0==SetHoldRegs(RobotModbusControl.id, 2049, 1, {1}, "U16")
end
function RobotModbusControl.setJogModeCartesian()
    return 0==SetHoldRegs(RobotModbusControl.id, 2049, 1, {2}, "U16")
end
function RobotModbusControl.setJogModeTool()
    return 0==SetHoldRegs(RobotModbusControl.id, 2049, 1, {3}, "U16")
end

return RobotModbusControl