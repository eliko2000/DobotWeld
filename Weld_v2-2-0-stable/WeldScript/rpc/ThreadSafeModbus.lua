--[[
线程安全的modbus操作指令，就是对生态框架的modbus进行封装
]]--

local g_innerModbusLockerName = "ThreadSafeModbusLocker-3B384C50-B4E8-4011-8B1B-EC339A988970" --锁的名称
local g_innerModbusLockTimeout = 3000 --获取锁后，拥有锁资源的持续时长，毫秒单位
local g_innerModbusLockWaitTimeout = 10000 --等待获取锁资源的最大时间，毫秒单位
local g_maxDeltaTimeLog = 10000 --modbus请求的最大超时时间

local function innerEnterModbusLock()
    Lock(g_innerModbusLockerName,g_innerModbusLockTimeout,g_innerModbusLockWaitTimeout)
end

local function innerLeaveModbusLock()
    UnLock(g_innerModbusLockerName)
end

local MyModbusWrapperInner = {
    ip = nil,
    port = nil,
    slaveId = nil,
    baud = nil,
    parity = nil,
    data_bit = nil,
    stop_bit = nil,
    isTcp = nil,
    id = nil
}

function MyModbusWrapperInner.clear()
    MyModbusWrapperInner.ip = nil
    MyModbusWrapperInner.port = nil
    MyModbusWrapperInner.slaveId = nil
    MyModbusWrapperInner.baud = nil
    MyModbusWrapperInner.parity = nil
    MyModbusWrapperInner.data_bit = nil
    MyModbusWrapperInner.stop_bit = nil
    MyModbusWrapperInner.isTcp = nil
    MyModbusWrapperInner.id = nil
end

--自动连接，当modbus读写发生错误时，尝试连接一次，因为modbus断开了连接，lua接口是不知道的
function MyModbusWrapperInner.tryConnect()
    local err,id
    if true==MyModbusWrapperInner.isTcp then
        local slaveId = MyModbusWrapperInner.slaveId
        local ip = MyModbusWrapperInner.ip
        local port = MyModbusWrapperInner.port
        local beginTime = Systime()
        err,id = ModbusCreate(ip,port,slaveId)
        local deltaTime = Systime()-beginTime
        if deltaTime>=g_maxDeltaTimeLog then EcoLog("==========>>ModbusCreate cost time:"..deltaTime) end
        if 0==err then
            MyModbusWrapperInner.id = id
            Wait(100)
            return true
        end
    elseif false==MyModbusWrapperInner.isTcp then
        local slaveId = MyModbusWrapperInner.slaveId
        local baud = MyModbusWrapperInner.baud
        local parity = MyModbusWrapperInner.parity
        local data_bit = MyModbusWrapperInner.data_bit
        local stop_bit = MyModbusWrapperInner.stop_bit
        local beginTime = Systime()
        err,id = ModbusRTUCreate(slaveId,baud,parity,data_bit,stop_bit)
        local deltaTime = Systime()-beginTime
        if deltaTime>=g_maxDeltaTimeLog then EcoLog("==========>>ModbusRTUCreate cost time:"..deltaTime) end
        if 0==err then
            MyModbusWrapperInner.id = id
            Wait(100)
            return true
        end
    end
    return false
end

function MyModbusWrapperInner.ModbusCreate(IP, port, slaveId, isRTU)
    if IP~=MyModbusWrapperInner.ip or port~=MyModbusWrapperInner.port or 
        slaveId~=MyModbusWrapperInner.slaveId
    then
        if nil~=MyModbusWrapperInner.id then
            local beginTime = Systime()
            ModbusClose(MyModbusWrapperInner.id)
            local deltaTime = Systime()-beginTime
            if deltaTime>=g_maxDeltaTimeLog then EcoLog("==========>>ModbusClose cost time:"..deltaTime) end
            MyModbusWrapperInner.id = nil
        end
    end
    
    --去掉末尾是nil的元素，否则生态接口会报错.
    local params = {IP, port, slaveId, isRTU}
    local beginTime = Systime()
    local err,id = ModbusCreate(table.unpack(params))
    local deltaTime = Systime()-beginTime
    if deltaTime>=g_maxDeltaTimeLog then EcoLog("==========>>ModbusCreate cost time:"..deltaTime) end
    if 0==err then
        MyModbusWrapperInner.isTcp = true
        MyModbusWrapperInner.id = id
        MyModbusWrapperInner.slaveId = slaveId
        MyModbusWrapperInner.ip = IP
        MyModbusWrapperInner.port = port
    end
    return err,id
end

function MyModbusWrapperInner.ModbusRTUCreate(slaveId, baud, parity, data_bit, stop_bit)
    if baud~=MyModbusWrapperInner.baud or parity~=MyModbusWrapperInner.parity or 
       data_bit~=MyModbusWrapperInner.data_bit or stop_bit~=MyModbusWrapperInner.stop_bit or
       slaveId~=MyModbusWrapperInner.slaveId
    then
        if nil~=MyModbusWrapperInner.id then
            local beginTime = Systime()
            ModbusClose(MyModbusWrapperInner.id)
            local deltaTime = Systime()-beginTime
            if deltaTime>=g_maxDeltaTimeLog then EcoLog("==========>>ModbusClose cost time:"..deltaTime) end
            MyModbusWrapperInner.id = nil
        end
    end
    
    local params = {slaveId, baud, parity, data_bit, stop_bit}
    local beginTime = Systime()
    local err,id = ModbusRTUCreate(table.unpack(params))
    local deltaTime = Systime()-beginTime
    if deltaTime>=g_maxDeltaTimeLog then EcoLog("==========>>ModbusRTUCreate cost time:"..deltaTime) end
    if 0==err then
        MyModbusWrapperInner.isTcp = false
        MyModbusWrapperInner.id = id
        MyModbusWrapperInner.slaveId = slaveId
        MyModbusWrapperInner.baud = baud
        MyModbusWrapperInner.parity = parity
        MyModbusWrapperInner.data_bit = data_bit
        MyModbusWrapperInner.stop_bit = stop_bit
    end
    return err,id
end

function MyModbusWrapperInner.ModbusClose(id)
    local err = nil
    if nil~=MyModbusWrapperInner.id then
        local beginTime = Systime()
        err = ModbusClose(MyModbusWrapperInner.id)
        local deltaTime = Systime()-beginTime
        if deltaTime>=g_maxDeltaTimeLog then EcoLog("==========>>ModbusClose cost time:"..deltaTime) end
        MyModbusWrapperInner.clear()
    end
    return err
end

function MyModbusWrapperInner.GetInBits(id, addr, count)
    local beginTime = Systime()
    local val = GetInBits(MyModbusWrapperInner.id, addr, count)
    local deltaTime = Systime()-beginTime
    if deltaTime>=g_maxDeltaTimeLog then EcoLog("==========>>GetInBits cost time:"..deltaTime) end
    --[[
    if nil==val then
        if MyModbusWrapperInner.tryConnect() then
            val = GetInBits(MyModbusWrapperInner.id, addr, count)
        end
    elseif #val<count then
        if MyModbusWrapperInner.tryConnect() then
            val = GetInBits(MyModbusWrapperInner.id, addr, count)
        end
    end]]--
    return val
end

function MyModbusWrapperInner.GetInRegs(id, addr, count, _type)
    local beginTime = Systime()
    local val = GetInRegs(MyModbusWrapperInner.id, addr, count, _type)
    local deltaTime = Systime()-beginTime
    if deltaTime>=g_maxDeltaTimeLog then EcoLog("==========>>GetInRegs cost time:"..deltaTime) end
    --[[
    if nil==val then
        if MyModbusWrapperInner.tryConnect() then
            val = GetInRegs(MyModbusWrapperInner.id, addr, count, _type)
        end
    elseif #val<count then
        if MyModbusWrapperInner.tryConnect() then
            val = GetInRegs(MyModbusWrapperInner.id, addr, count, _type)
        end
    end]]--
    return val
end

function MyModbusWrapperInner.GetCoils(id, addr, count)
    local beginTime = Systime()
    local val = GetCoils(MyModbusWrapperInner.id, addr, count)
    local deltaTime = Systime()-beginTime
    if deltaTime>=g_maxDeltaTimeLog then EcoLog("==========>>GetCoils cost time:"..deltaTime) end
    --[[
    if nil==val then
        if MyModbusWrapperInner.tryConnect() then
            val = GetCoils(MyModbusWrapperInner.id, addr, count)
        end
    elseif #val<count then
        if MyModbusWrapperInner.tryConnect() then
            val = GetCoils(MyModbusWrapperInner.id, addr, count)
        end
    end]]--
    return val
end

function MyModbusWrapperInner.SetCoils(id, addr, count, _table)
    local beginTime = Systime()
    local val = SetCoils(MyModbusWrapperInner.id, addr, count, _table)
    local deltaTime = Systime()-beginTime
    if deltaTime>=g_maxDeltaTimeLog then EcoLog("==========>>SetCoils cost time:"..deltaTime) end
    --[[
    if 0~=val then
        if MyModbusWrapperInner.tryConnect() then
            val = SetCoils(MyModbusWrapperInner.id, addr, count, _table)
        end
    end]]--
    return val
end

function MyModbusWrapperInner.GetHoldRegs(id, addr, count, _type)
    local beginTime = Systime()
    local val = GetHoldRegs(MyModbusWrapperInner.id, addr, count, _type)
    local deltaTime = Systime()-beginTime
    if deltaTime>=g_maxDeltaTimeLog then EcoLog("==========>>GetHoldRegs cost time:"..deltaTime) end
    --[[
    if nil==val then
        if MyModbusWrapperInner.tryConnect() then
            val = GetHoldRegs(MyModbusWrapperInner.id, addr, count, _type)
        end
    elseif #val<count then
        if MyModbusWrapperInner.tryConnect() then
            val = GetHoldRegs(MyModbusWrapperInner.id, addr, count, _type)
        end
    end]]--
    return val
end

function MyModbusWrapperInner.SetHoldRegs(id, addr, count, _table, _type)
    local beginTime = Systime()
    local val = SetHoldRegs(MyModbusWrapperInner.id, addr, count, _table, _type)
    local deltaTime = Systime()-beginTime
    if deltaTime>=g_maxDeltaTimeLog then EcoLog("==========>>SetHoldRegs cost time:"..deltaTime) end
    --[[
    if 0~=val then
        if MyModbusWrapperInner.tryConnect() then
            val = SetHoldRegs(MyModbusWrapperInner.id, addr, count, _table, _type)
        end
    end]]--
    return val
end

--modbus线程安全的操作
ThreadSafeModbus = {}

function ThreadSafeModbus.ModbusCreate(IP, port, slaveId, isRTU)
    innerEnterModbusLock()
    local isOk,err,id = pcall(MyModbusWrapperInner.ModbusCreate,IP, port, slaveId, isRTU)
    innerLeaveModbusLock()
    if false==isOk then return -1,0 end
    return err,id
end

function ThreadSafeModbus.ModbusRTUCreate(slaveId, baud, parity, data_bit, stop_bit)
    innerEnterModbusLock()
    local isOk,err,id = pcall(MyModbusWrapperInner.ModbusRTUCreate,slaveId, baud, parity, data_bit, stop_bit)
    innerLeaveModbusLock()
    if false==isOk then return -1,0 end
    return err,id
end

function ThreadSafeModbus.ModbusClose(id)
    innerEnterModbusLock()
    local isOk,err = pcall(MyModbusWrapperInner.ModbusClose,id)
    innerLeaveModbusLock()
    if false==isOk then return 0 end
    return err
end

function ThreadSafeModbus.GetInBits(id, addr, count)
    innerEnterModbusLock()
    local isOk,val = pcall(MyModbusWrapperInner.GetInBits,id, addr, count)
    innerLeaveModbusLock()
    if false==isOk then return {} end
    return val
end

function ThreadSafeModbus.GetInRegs(id, addr, count, _type)
    innerEnterModbusLock()
    local isOk,val = pcall(MyModbusWrapperInner.GetInRegs,id, addr, count, _type)
    innerLeaveModbusLock()
    if false==isOk then return {} end
    return val
end

function ThreadSafeModbus.GetCoils(id, addr, count)
    innerEnterModbusLock()
    local isOk,val = pcall(MyModbusWrapperInner.GetCoils,id, addr, count)
    innerLeaveModbusLock()
    if false==isOk then return {} end
    return val
end

function ThreadSafeModbus.SetCoils(id, addr, count, _table)
    innerEnterModbusLock()
    local isOk,val = pcall(MyModbusWrapperInner.SetCoils,id, addr, count, _table)
    innerLeaveModbusLock()
    if false==isOk then return -1 end
    return val
end

function ThreadSafeModbus.GetHoldRegs(id, addr, count, _type)
    innerEnterModbusLock()
    local isOk,val = pcall(MyModbusWrapperInner.GetHoldRegs,id, addr, count, _type)
    innerLeaveModbusLock()
    if false==isOk then return {} end
    return val
end

function ThreadSafeModbus.SetHoldRegs(id, addr, count, _table, _type)
    innerEnterModbusLock()
    local isOk,val = pcall(MyModbusWrapperInner.SetHoldRegs,id, addr, count, _table, _type)
    innerLeaveModbusLock()
    if false==isOk then return -1 end
    return val
end
