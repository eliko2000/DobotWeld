--[[焊机`WelderControlEIP`接口，继承`WelderControlObject`]]--

-------------------------------------------------------------------------------------------------------------------
--【本地私有接口】-------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
--【业务实现接口】-------------------------------------------------------------------------------------------------
local WelderControlEIP = WelderControlObject:new()
WelderControlEIP.__index = WelderControlEIP
WelderControlEIP.welderObject = nil --焊机对象，也就是`ImplementWelder`的派生类

-------------------------------------------------------------------------------------------------------------------
--【对内不公开接口，只给本身和派生类使用】-----------------------------------------------------------------------
--[[
功能：修改Output Assembly数据
      按照某几个字节位来修改地址为XXX的Output Assembly数据的值，操作步骤:(读取-->修改-->写入)
参数：addr-起始地址
      newValues-设置的值,为数组
      pfnConvertBit-位操作转换函数,为nil表示不转换，否则为 pfnConvertBit(srcVals,newVals),其中newVals为函数传入的newValues
返回值：true表示成功，false表示失败
]]--
local function updateHoldRegsValue_Address(self,addr,newValues,pfnConvertBit)
    local connector = self.welderObject:getIOStreamObject():getConnector()
    local ret = 0
    if nil==pfnConvertBit then
        ret = DobotWelderRPC.eip.ScannerWrite(connector,addr,newValues)
    else
        local readCount = #newValues
        local value = DobotWelderRPC.eip.ScannerReadOutput(connector,addr,readCount)
        if nil==value then
            local welderName = self.welderObject.welderName
            self.welderObject:setApiErrCode(ConstEnumApiErrCode.Comm_Err)
            MyWelderDebugLog(welderName..":ScannerReadOutput return fail, the return value is nil") 
            return nil 
        end
        if #value<readCount then
            local welderName = self.welderObject.welderName
            self.welderObject:setApiErrCode(ConstEnumApiErrCode.Comm_Err)
            MyWelderDebugLog(welderName..":ScannerReadOutput return fail, the return value's length less than "..readCount)
            return nil
        end
        local writeValues = pfnConvertBit(value,newValues)
        for i=1,readCount do
            if writeValues[i]~=value[i] then --读出来的值与要写下去的值不一样才发送设置，否则没必要
                ret = DobotWelderRPC.eip.ScannerWrite(connector,addr,writeValues)
                break
            end
        end
    end
    if 0~= ret then
        local welderName = self.welderObject.welderName
        self.welderObject:setApiErrCode(ConstEnumApiErrCode.Comm_Err)
        MyWelderDebugLog(welderName..string.format(":ScannerWrite return fail,ret=%s",tostring(ret)))
        return nil
    end
    self.welderObject:setApiErrCode(ConstEnumApiErrCode.OK)
    return true
end
function WelderControlEIP:innerUpdateOutputValue_Address(addr,newValues,pfnConvertBit)
    if nil~=pfnConvertBit then self:enterLock() end --为nil时只有写一个操作，无需加锁
    local isOk,value = pcall(updateHoldRegsValue_Address,self,addr,newValues,pfnConvertBit)
    if nil~=pfnConvertBit then self:leaveLock() end --为nil时只有写一个操作，无需加锁
    if isOk then return value end
    return nil
end

--[[
功能：写入Output Assembly数据
参数：addr-起始地址
      newValues-要设置的值，为table，每个值是uint8，地址必须是连续的
返回值：true表示成功，false表示失败
]]--
function WelderControlEIP:innerWriteOutputValue_Address(addr,newValues)
    local connector = self.welderObject:getIOStreamObject():getConnector()
    local ret = DobotWelderRPC.eip.ScannerWrite(connector,addr,newValues)
    if 0~= ret then
        local welderName = self.welderObject.welderName
        self.welderObject:setApiErrCode(ConstEnumApiErrCode.Comm_Err)
        MyWelderDebugLog(welderName..string.format(":ScannerWrite return fail,ret=%s",tostring(ret)))
        return nil
    end
    self.welderObject:setApiErrCode(ConstEnumApiErrCode.OK)
    return true
end

--[[
功能：读取Output Assembly数据
参数：addr-起始地址
      count-要读取的个数，如果为nil则表示默认1个
返回值：成功返回值，失败返回nil
]]--
function WelderControlEIP:innerReadOutputValue_Address(addr,count)
    local connector = self.welderObject:getIOStreamObject():getConnector()
    if nil==count then count = 1 end
    local value = DobotWelderRPC.eip.ScannerReadOutput(connector,addr,count)
    if nil==value then
        local welderName = self.welderObject.welderName
        self.welderObject:setApiErrCode(ConstEnumApiErrCode.Comm_Err)
        MyWelderDebugLog(welderName..":ScannerReadOutput return fail, the return value is nil")
        return nil
    end
    if #value<count then
        local welderName = self.welderObject.welderName
        self.welderObject:setApiErrCode(ConstEnumApiErrCode.Comm_Err) 
        MyWelderDebugLog(welderName..":ScannerReadOutput return fail, the return value's length less than " .. count) 
        return nil
    end
    self.welderObject:setApiErrCode(ConstEnumApiErrCode.OK)
    return value
end

--[[
功能：读取Input Assembly数据
参数：addr-起始地址
      count-要读取的个数，如果为nil则表示默认1个
返回值：成功返回值，失败返回nil
]]--
function WelderControlEIP:innerReadInputValue_Address(addr,count)
    local connector = self.welderObject:getIOStreamObject():getConnector()
    if nil==count then count = 1 end
    local value = DobotWelderRPC.eip.ScannerReadInput(connector,addr,count)
    if nil==value then
        local welderName = self.welderObject.welderName
        self.welderObject:setApiErrCode(ConstEnumApiErrCode.Comm_Err)
        MyWelderDebugLog(welderName..":ScannerReadInput return fail, the return value is nil")
        return nil
    end
    if #value<count then
        local welderName = self.welderObject.welderName
        self.welderObject:setApiErrCode(ConstEnumApiErrCode.Comm_Err) 
        MyWelderDebugLog(welderName..":ScannerReadInput return fail, the return value's length less than " .. count) 
        return nil
    end
    self.welderObject:setApiErrCode(ConstEnumApiErrCode.OK)
    return value
end

-------------------------------------------------------------------------------------------------------------------
--【对外公开接口】-------------------------------------------------------------------------------------------------
function WelderControlEIP:new()
    local o = WelderControlObject:new()
    setmetatable(o,self)
    return o
end

return WelderControlEIP