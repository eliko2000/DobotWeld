--[[DobotAnalog通信，继承`IDobotIOStream`]]--
local DobotAnalog = IDobotIOStream:new()
DobotAnalog.__index = DobotAnalog

function DobotAnalog:new()
    local o = IDobotIOStream:new()
    setmetatable(o,self)
    o.hasConnected = false
    return o
end

function DobotAnalog:connect()
    --模拟连接是通过io去做的，不存在连接断开这一说法，所以默认永远都是连接上的
    MyWelderDebugLog(Language.trLang("CONNECTING_ANALOG"))
    DobotWelderRPC.analog.AnalogCreate()
    self.hasConnected = true
    return true
end

function DobotAnalog:disconnect()
    if self.hasConnected then
        DobotWelderRPC.analog.AnalogClose()
        MyWelderDebugLog(Language.trLang("DISCONNECT_ANALOG"))
    end
    self.hasConnected = false
end

function DobotAnalog:getConnector()
    return 0
end

function DobotAnalog:getErrorId()
    return 0
end

function DobotAnalog:isConnected()
    return self.hasConnected
end

return DobotAnalog