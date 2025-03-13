--[[ModbusTcp通信，继承`IDobotIOStream`]]--
local DobotModbusTcpClient = IDobotIOStream:new()
DobotModbusTcpClient.__index = DobotModbusTcpClient

function DobotModbusTcpClient:new()
    local o = IDobotIOStream:new()
    setmetatable(o,self)
    return o
end

function DobotModbusTcpClient:setConnectParam(ip,port)
    self.ip = ip
    self.port = port
end

function DobotModbusTcpClient:connect()
    self:disconnect()
    MyWelderDebugLog(Language.trLang("CONNECTING_MODBUS").."("..tostring(self.ip)..":"..tostring(self.port)..")")
    local err,id = DobotWelderRPC.modbus.ModbusCreate(self.ip, self.port,1)
    self.errid = err
    if 0~= err then
        if 1==err then
            MyWelderDebugLog(Language.trLang("MODBUS_CONNECT_MAX_ERR"))
        elseif 2==err then
            MyWelderDebugLog(Language.trLang("MODBUS_INIT_ERR"))
        elseif 3==err then
            MyWelderDebugLog(Language.trLang("MODBUS_MASTER_ERR"))
        else
            MyWelderDebugLog(Language.trLang("MODBUS_UNKNOW_ERR").."err="..tostring(err))
        end
        return false
    end
    MyWelderDebugLog(Language.trLang("MODBUS_OK"))
    
    self.id = id
    self.hasConnected = true
    
    return true
end

function DobotModbusTcpClient:disconnect()
    if self.hasConnected then
        DobotWelderRPC.modbus.ModbusClose(self.id)
        MyWelderDebugLog(Language.trLang("MODBUS_DISCONNECT"))
    end
    self.id = -1
    self.errid = -1
    self.hasConnected = false
end

function DobotModbusTcpClient:getConnector()
    return self.id
end

function DobotModbusTcpClient:getErrorId()
    return self.errid
end

function DobotModbusTcpClient:isConnected()
    return self.hasConnected
end

return DobotModbusTcpClient