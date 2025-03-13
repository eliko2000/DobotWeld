--[[DobotDeviceNet通信，继承`IDobotIOStream`]]--
local DobotDeviceNet = IDobotIOStream:new()
DobotDeviceNet.__index = DobotDeviceNet

function DobotDeviceNet:new()
    local o = IDobotIOStream:new()
    setmetatable(o,self)
    return o
end

function DobotDeviceNet:setConnectParam(ip,port)
    self.ip = ip
    self.port = port
end

function DobotDeviceNet:connect()
    self:disconnect()
    MyWelderDebugLog(Language.trLang("CONNECTING_DEVICENET").."("..tostring(self.ip)..":"..tostring(self.port)..")")
    local err,id = DobotWelderRPC.modbus.ModbusCreate(self.ip, self.port,1)
    self.errid = err
    if 0~= err then
        if 1==err then
            MyWelderDebugLog(Language.trLang("DEVICENET_CONNECT_MAX_ERR"))
        elseif 2==err then
            MyWelderDebugLog(Language.trLang("DEVICENET_INIT_ERR"))
        elseif 3==err then
            MyWelderDebugLog(Language.trLang("DEVICENET_MASTER_ERR"))
        else
            MyWelderDebugLog(Language.trLang("DEVICENET_UNKNOW_ERR").."err="..tostring(err))
        end
        return false
    end
    MyWelderDebugLog(Language.trLang("DEVICENET_OK"))
    
    self.id = id
    self.hasConnected = true
    
    return true
end

function DobotDeviceNet:disconnect()
    if self.hasConnected then
        DobotWelderRPC.modbus.ModbusClose(self.id)
        MyWelderDebugLog(Language.trLang("DEVICENET_DISCONNECT"))
    end
    self.id = -1
    self.errid = -1
    self.hasConnected = false
end

function DobotDeviceNet:getConnector()
    return self.id
end

function DobotDeviceNet:getErrorId()
    return self.errid
end

function DobotDeviceNet:isConnected()
    return self.hasConnected
end

return DobotDeviceNet