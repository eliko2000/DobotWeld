--[[DobotEtherNetIP通信，继承`IDobotIOStream`]]--
local DobotEtherNetIP = IDobotIOStream:new()
DobotEtherNetIP.__index = DobotEtherNetIP

function DobotEtherNetIP:new()
    local o = IDobotIOStream:new()
    setmetatable(o,self)
    return o
end

function DobotEtherNetIP:setConnectParam(ip,port,eip)
    self.ip = ip
    self.port = port
    self.configAssemblyId = eip.configAssemblyId
    self.outputAssemblyId = eip.outputAssemblyId
    self.outputAssemblySize = eip.outputAssemblySize
    self.inputAssemblyId = eip.inputAssemblyId
    self.inputAssemblySize = eip.inputAssemblySize
end

function DobotEtherNetIP:connect()
    self:disconnect()
    local rpi = 80 --不建议小于50
    local strlog = string.format("(ip=%s,{cfgId=%s,oid=%s,iid=%s},{osize=%s,isize=%s},rpi=%s)",tostring(self.ip),
                                tostring(self.configAssemblyId),tostring(self.outputAssemblyId),tostring(self.inputAssemblyId),
                                tostring(self.outputAssemblySize),tostring(self.inputAssemblySize),tostring(rpi))
    MyWelderDebugLog(Language.trLang("CONNECTING_ETHERNETIP")..strlog)
    local err,id
    for i=1,3 do
        err,id = DobotWelderRPC.eip.CreateScanner(self.ip, {self.configAssemblyId,self.outputAssemblyId,self.inputAssemblyId}, {self.outputAssemblySize,self.inputAssemblySize},rpi)
        if err==0 then
            break
        else
            if WelderIsDaemonScript() then
                Wait(300)
            else
                break
            end
        end
    end
    self.errid = err
    if 0 ~= err then
        if 1==err then
            MyWelderDebugLog(Language.trLang("ETHERNETIP_INVALID_EPATH"))
        elseif 2==err then
            MyWelderDebugLog(Language.trLang("ETHERNETIP_INVALID_SIZES").."[0, 511]")
        elseif 3==err then
            MyWelderDebugLog(Language.trLang("ETHERNETIP_INVALID_RPI"))
        elseif 4==err then
            MyWelderDebugLog(Language.trLang("ETHERNETIP_OPEN_AGAIN"))
        elseif 5==err then
            MyWelderDebugLog(Language.trLang("ETHERNETIP_CONNECT_FAIL"))
        else
            MyWelderDebugLog(Language.trLang("ETHERNETIP_UNKNOW_ERR").."err="..tostring(err))
        end
        return false
    end
    if WelderIsDaemonScript() then
        Wait(500) --连接成功后需要等待一段时间才有数据返回，这个时间需要大于CreateScanner的rpi值
    end
    MyWelderDebugLog(Language.trLang("ETHERNETIP_OK"))
    
    self.id = id
    self.hasConnected = true
    
    return true
end

function DobotEtherNetIP:disconnect()
    if self.hasConnected then
        DobotWelderRPC.eip.ScannerDestroy(self.id)
        if WelderIsDaemonScript() then
            Wait(400) --断开连接后需要等待一段时间才能让连接完全释放
        end
        MyWelderDebugLog(Language.trLang("ETHERNETIP_DISCONNECT"))
    end
    self.id = -1
    self.errid = -1
    self.hasConnected = false
end

function DobotEtherNetIP:getConnector()
    return self.id
end

function DobotEtherNetIP:getErrorId()
    return self.errid
end

function DobotEtherNetIP:isConnected()
    return self.hasConnected
end

return DobotEtherNetIP