--[[焊机`WelderControlDeviceNet`接口，继承`WelderControlObject`]]--

-------------------------------------------------------------------------------------------------------------------
--【本地私有接口】-------------------------------------------------------------------------------------------------
--[[
功能：将2字节的数据高低字节交换
参数：arrUInt16为short类型的数组
返回值：返回转换后的数组
]]--
local function innerExchangeBytes(arrUInt16)
    local newArray = {}
    for i=1,#arrUInt16 do
        local t = arrUInt16[i]
        local low = (t<<8)&0xFF00
        local hight = (t>>8)&0x00FF
        t = low|hight
        table.insert(newArray,t)
    end
    return newArray
end

-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
--【业务实现接口】-------------------------------------------------------------------------------------------------
local WelderControlDeviceNet = WelderControlObject:new()
WelderControlDeviceNet.__index = WelderControlDeviceNet
WelderControlDeviceNet.welderObject = nil --焊机对象，也就是`ImplementWelder`的派生类

-------------------------------------------------------------------------------------------------------------------
--【对内不公开接口，只给本身和派生类使用】-----------------------------------------------------------------------
--[[
功能：修改保存寄存器的值
      按照某几个字节位来修改地址为XXX的保存寄存器的值，操作步骤:(读取-->修改-->)写入
参数：addr-寄存器地址
      newValue-设置的值
      pfnConvertBit-位操作转换函数,为nil表示不转换，否则为 pfnConvertBit(srcVal,newVal),其中newVal为函数传入的newValue
返回值：true表示成功，false表示失败
]]--
local function updateHoldRegsValue_Address(self,addr,newValue,pfnConvertBit)
    local connector = self.welderObject:getIOStreamObject():getConnector()
    local ret = 0
    if nil==pfnConvertBit then
        local value = innerExchangeBytes({newValue})
        ret = DobotWelderRPC.modbus.SetHoldRegs(connector,addr,#value,value,"U16")
    else
        local value = DobotWelderRPC.modbus.GetHoldRegs(connector,addr,1,"U16")
        if nil==value then
            local welderName = self.welderObject.welderName
            self.welderObject:setApiErrCode(ConstEnumApiErrCode.Comm_Err)
            MyWelderDebugLog(welderName..":GetHoldRegs return fail, the return value is nil") 
            return nil 
        end
        if #value<1 then
            local welderName = self.welderObject.welderName
            self.welderObject:setApiErrCode(ConstEnumApiErrCode.Comm_Err)
            MyWelderDebugLog(welderName..":GetHoldRegs return fail, the return value's length less than 1")
            return nil
        end
        local beforeValue = value[1] --保留读出来的第一个值
        value = innerExchangeBytes(value)
        value[1] = pfnConvertBit(value[1],newValue)
        value = innerExchangeBytes(value)
        if beforeValue~=value[1] then --读出来的值与要写下去的值不一样才发送设置，否则没必要
            ret = DobotWelderRPC.modbus.SetHoldRegs(connector,addr,#value,value,"U16")
        end
    end
    if 0~=ret then
        local welderName = self.welderObject.welderName
        self.welderObject:setApiErrCode(ConstEnumApiErrCode.Comm_Err)
        MyWelderDebugLog(welderName..string.format(":SetHoldRegs return fail,ret=%s",tostring(ret)))
        return nil
    end
    self.welderObject:setApiErrCode(ConstEnumApiErrCode.OK)
    return true
end
function WelderControlDeviceNet:innerUpdateHoldRegsValue_Address(addr,newValue,pfnConvertBit)
    if nil~=pfnConvertBit then self:enterLock() end --为nil时只有写一个操作，无需加锁
    local isOk,value = pcall(updateHoldRegsValue_Address,self,addr,newValue,pfnConvertBit)
    if nil~=pfnConvertBit then self:leaveLock() end --为nil时只有写一个操作，无需加锁
    if isOk then return value end
    return nil
end

--[[
功能：设置保存寄存器的值
参数：addr-寄存器起始地址
      newValues-要设置的值，为table，每个值是uint16，寄存器地址必须是连续的
返回值：true表示成功，false表示失败
]]--
function WelderControlDeviceNet:innerSetHoldRegsValue_Address(addr,newValues)
    local connector = self.welderObject:getIOStreamObject():getConnector()
    local value = innerExchangeBytes(newValues)
    local ret = DobotWelderRPC.modbus.SetHoldRegs(connector,addr,#value,value,"U16")
    if 0~= ret then
        local welderName = self.welderObject.welderName
        self.welderObject:setApiErrCode(ConstEnumApiErrCode.Comm_Err)
        MyWelderDebugLog(welderName..string.format(":SetHoldRegs return fail,ret=%s",tostring(ret)))
        return nil
    end
    self.welderObject:setApiErrCode(ConstEnumApiErrCode.OK)
    return true
end

--[[
功能：读取保存寄存器的值
参数：addr-寄存器地址
      count-要读取的个数，如果为nil则表示默认1个
返回值：成功返回值，失败返回nil
]]--
function WelderControlDeviceNet:innerGetHoldRegsValue_Address(addr,count)
    local connector = self.welderObject:getIOStreamObject():getConnector()
    if nil==count then count = 1 end
    local value = DobotWelderRPC.modbus.GetHoldRegs(connector,addr,count,"U16")
    if nil==value then
        local welderName = self.welderObject.welderName
        self.welderObject:setApiErrCode(ConstEnumApiErrCode.Comm_Err)
        MyWelderDebugLog(welderName..":GetHoldRegs return fail, the return value is nil")
        return nil
    end
    if #value<count then
        local welderName = self.welderObject.welderName
        self.welderObject:setApiErrCode(ConstEnumApiErrCode.Comm_Err) 
        MyWelderDebugLog(welderName..":GetHoldRegs return fail, the return value's length less than " .. count) 
        return nil
    end
    value = innerExchangeBytes(value)
    self.welderObject:setApiErrCode(ConstEnumApiErrCode.OK)
    return value
end

--[[
功能：读取输入寄存器的值
参数：addr-寄存器起始地址
      count-要读取的个数，如果为nil则表示默认1个
返回值：成功返回值，失败返回nil
]]--
function WelderControlDeviceNet:innerGetInRegsValue_Address(addr,count)
    local connector = self.welderObject:getIOStreamObject():getConnector()
    if nil==count then count = 1 end
    local value = DobotWelderRPC.modbus.GetInRegs(connector,addr,count,"U16") --只读数据，无需加锁
    if nil==value then
        local welderName = self.welderObject.welderName
        self.welderObject:setApiErrCode(ConstEnumApiErrCode.Comm_Err)
        MyWelderDebugLog(welderName..":GetInRegs return fail, the return value is nil")
        return nil
    end
    if #value<count then
        local welderName = self.welderObject.welderName
        self.welderObject:setApiErrCode(ConstEnumApiErrCode.Comm_Err) 
        MyWelderDebugLog(welderName..":GetInRegs return fail, the return value's length less than " .. count) 
        return nil
    end
    value = innerExchangeBytes(value)
    self.welderObject:setApiErrCode(ConstEnumApiErrCode.OK)
    return value
end

-------------------------------------------------------------------------------------------------------------------
--【对外公开接口】-------------------------------------------------------------------------------------------------
function WelderControlDeviceNet:new()
    local o = WelderControlObject:new()
    setmetatable(o,self)
    return o
end

return WelderControlDeviceNet