--[[
通信接口类
1. 该类是为了规范描述与对端实现通信的几个主要功能，具体实现以及需要哪些参数，由派生类去实现
2. 结合lua本身的特性，以及生态接口的局限性，此类设计如下
]]--

local IDobotIOStream = {}
IDobotIOStream.__index = IDobotIOStream

function IDobotIOStream:new()
    return setmetatable({},self)
end

function IDobotIOStream:setConnectParam(ip,port,extParams)
end

function IDobotIOStream:connect()
    return false
end

function IDobotIOStream:disconnect()
end

--返回连接对象，具体收发消息时，结合各自的通信方式使用该对象
function IDobotIOStream:getConnector()
    return nil
end
--返回连接时的errid，值的具体类型每个接口可能不一样
function IDobotIOStream:getErrorId()
    return 0
end

--true表示连接，false表示未连接
function IDobotIOStream:isConnected()
    return false
end

return IDobotIOStream