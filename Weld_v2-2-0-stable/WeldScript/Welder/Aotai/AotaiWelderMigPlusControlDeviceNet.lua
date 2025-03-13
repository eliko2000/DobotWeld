--[[焊机MIG-PLUS型号接口DeviceNet类，继承`AotaiWelderControlDeviceNet`]]--

local AotaiWelderMigPlusControlDeviceNet = AotaiWelderControlDeviceNet:new()
AotaiWelderMigPlusControlDeviceNet.__index = AotaiWelderMigPlusControlDeviceNet

function AotaiWelderMigPlusControlDeviceNet:new(welderObj)
    local o = AotaiWelderControlDeviceNet:new(welderObj)
    return setmetatable(o,self)
end

function AotaiWelderMigPlusControlDeviceNet:setWeldMode(newVal)
    local welderName = self.welderObject.welderName
    local params = newVal
    if nil == params then
        params = self.welderObject:getWelderParamObject():getWeldMode()
    end
    if not ConstEnumWelderWeldMode[params] then
        MyWelderDebugLog(welderName..Language.trLang("WELDER_WELD_MODE_NO_RECOGNIZE")..tostring(params))
        return false
    end
    local mapper = {
        flat = 0x00, --平特性
        pulseProcess = 0x01, --脉冲程序
        job = 0x02, --调用状态(对于奥太焊机这个就是callState调用模式)
        bigPenetration = 0x03, --大熔深
        fastPulse = 0x04 --快速脉冲
    }
    if mapper[params] then
        newVal = (mapper[params]<<2)&0x1C
        
        MyWelderDebugLog(welderName..":setWeldMode->before write,mode="..tostring(params))
        return self:innerUpdateHoldRegsValue_Address(0,newVal,function(oldV,newV) 
                                                                local tmp=0xFFE3&oldV
                                                                tmp=tmp|newV
                                                                MyWelderDebugLog(welderName..":setWeldMode->write value="..tmp)
                                                                return tmp
                                                            end)
    else
        MyWelderDebugLog(welderName..Language.trLang("WELDER_WELD_MODE_FAIL")..params)
        return false
    end
end

return AotaiWelderMigPlusControlDeviceNet