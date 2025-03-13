--[[
说明：
有的焊机仅仅支持单个modbus连接，而我们的实际应用场景就是 httpAPI.lua、userAPI.lua、deamon.lua都存在要与焊机进行modbus通信，
这就导致产生各种冲突问题。
为了解决这个问题，需要将deamon.lua当做服务端，httpAPI和userAPI当做客户端，进行类似于RPC的方式通信，因此需要对生态Modbus指令做
二次封装，并转为字符串，通过tcp发给deamon，然后deamon解析再发送给焊机。

此文件是对生态框架Modbus几个指令进行二次封装，主要目的是将生态的Modbus转为字符串
]]--

-- lua的table与json互转
local jsonLuaUtils = require("luaJson")

local function toJsonString(luaObject)
    local dataString = jsonLuaUtils.encode(luaObject)
    return dataString
end

local function toLuaObject(jsonStr)
    local isOk, resResult = pcall(jsonLuaUtils.decode, jsonStr)
    return isOk, resResult
end

--将arr2数组一个一个追加到arr1后面
local function append2Buffer(arr1,arr2)
    for i=1,#arr2 do
        table.insert(arr1,arr2[i])
    end
    return arr1
end

-- 因为TCPWrite发送string时没有将'\0'发出去，导致接收端无法判断一包完整数据，所以需要将string转为table
local function string2Table(str)
    local objTable = {}
    if str == nil or type(str) ~= "string" then
    else
        local strlen = string.len(str)
        for idx = 1, strlen, 1 do
            objTable[idx] = string.byte(str, idx)
        end
    end
    table.insert(objTable, 0)
    return objTable
end
-- 将table数组转为字符串，与string2Table相反，如果table最后一个是0，则去掉
local function table2String(tab)
    if tab[#tab] == 0 then table.remove(tab) end
    local str = ""
    for i=1,#tab do
        str = str .. string.char(tab[i])
    end
    return str
end

local g_keyTcpServerPortName = "Dobot_Weld_Parameter_DaemonRPCServer_"

local function connectDeamon(obj)
    if nil == obj.sock then
        local ip = "127.0.0.1"
        --因为服务端创建时，可能存在端口被占用，所以这里面不要将端口写死，而是服务端进行配置
        local port = GetVal(g_keyTcpServerPortName .. obj.name)
        if nil==port or type(port)~="string" then return false end
        port = math.tointeger(port)
        local err, sock = TCPCreate(false, ip, port)
        if err ~= 0 then
            MyWelderDebugLog("TCPCreate " .. obj.name .. " client fail(" .. ip .. ":" .. port .. ")")
            return false
        end
        MyWelderDebugLog(obj.name .. " TCP Client is connecting(" .. ip .. ":" .. port .. ")")
        err = TCPStart(sock, 5)
        if err ~= 0 then
            MyWelderDebugLog(obj.name .. " TCPStart Client connect fail,err=" .. err)
            TCPDestroy(sock)
            return false
        end
        MyWelderDebugLog(obj.name .. " TCP Client has connected(" .. ip .. ":" .. port .. ")")
        obj.sock = sock
    end
    return true
end

local function disconnectDeamon(obj)
    if nil ~= obj.sock then
        TCPDestroy(obj.sock)
        obj.sock = nil
    end
end

local function rpcCallDeamon(obj,paramsArray,timeoutMs)
    if nil == obj.sock then
        if not connectDeamon(obj) then
            MyWelderDebugLog("rpcCallDeamon:tcp connect fail,cannot to communicate!!")
            return nil
        end
    end
    
    local rpc = {}
    rpc.m = paramsArray.m
    rpc.p = {}
    for i=1,#paramsArray.p do
        table.insert(rpc.p, {v=paramsArray.p[i]})
    end
    local sendData = toJsonString(rpc)
    local err = TCPWrite(obj.sock, string2Table(sendData), 5)
    if err ~= 0 then
        disconnectDeamon(obj)
        MyWelderDebugLog("rpcCallDeamon:TCPWrite fail,errcode=" .. tostring(err) .. "," .. sendData)
        return nil
    end
    
    if nil==timeoutMs or timeoutMs<=0 then timeoutMs=10000 end
    
    local retStringData = ""
    local recvDataBuffer,data = {},{}
    local start_time = Systime()
    local end_time = start_time
    while (end_time - start_time <= timeoutMs) do
        err, data = TCPRead(obj.sock, 1)
        if err ~= 0 then
            MyWelderDebugLog("rpcCallDeamon:TCPRead fail,errcode=" .. tostring(err) .. ",method:"..rpc.m)
            Wait(200)
        else
            if #data > 0 then
                recvDataBuffer = append2Buffer(recvDataBuffer,data)
                if data[#data]==0 then 
                    retStringData = table2String(recvDataBuffer)
                    break 
                end
            end
        end
        end_time = Systime()
    end
    if #retStringData <= 0 then
        MyWelderDebugLog("rpcCallDeamon:TCPRead fail maybe timeout!!!method:"..rpc.m)
        return nil
    end
    local isOk, retData = toLuaObject(retStringData)
    if not isOk then 
        MyWelderDebugLog("rpcCallDeamon parse data fail,method:"..rpc.m .. ",retData:" .. retStringData)
        return nil
    end
    local resResult={}
    for i=1,#retData do
        table.insert(resResult, retData[i].v)
    end
    if #resResult < 2 then
        MyWelderDebugLog("rpcCallDeamon parse data fail,response data length cannot less than 2!!!method:"..rpc.m)
        return nil
    end
    if not resResult[1] then --请求错误，打印错误信息，这样在userAPI中调用rpc接口，deamon.lua的报错信息也能知道
        MyWelderDebugLog(resResult[2])
    end
    return resResult[3],resResult[4],resResult[5],resResult[6],resResult[7],resResult[8],resResult[9],resResult[10]
end

--[[
提供一个rpc-server服务供httpAPI和userAPI使用，做一些特殊操作，比如modbus。
参数：callback-回调函数，格式为 func(method,paramsList)，返回值是接口实际返回值组成的数组
      strName-请参考`WelderRPCInterface.name`的说明
]]--
local function executeRPCServer(callback,strName)
    --动态寻找可用的端口并建立tcpserver，同时将端口保存起来
    local strPortDBName = g_keyTcpServerPortName .. strName
    SetVal(strPortDBName,nil)
    local step = 1
    if "httpAPI.port"==strName then step = 1
    elseif "userAPI.port"==strName then step = -1
    end
    
    local port = 39528+step
    local err,socket
    for i=1,50 do
        err,socket = TCPCreate(true,"127.0.0.1",port) --create tcpserver
        --[[tcp创建成功并不代表就能正确使用，因为了解到TCPCreate只是把参数保存起来，基本都会成功，
        实际在TCPStart的时候才会使用这些参数，而且还可能存在失败情况，所以只有TCPStart成功才能表示ok。
        但是TCPStart可能真的成功了，会阻塞，因此每次在TCPStart之前保存端口，失败了就清掉端口]]--
        if 0 == err then 
            SetVal(strPortDBName,tostring(port)) --坑的要死，int存进去，取出来的时候变成了float类型，导致TCPCreate时报错
            MyWelderDebugLog(strName .. " tcpserver waitting for connecting......port:"..port)
            err = TCPStart(socket, 0) --tcp服务端一直等待接收连接
            if 0 == err then
                break
            else
                SetVal(strPortDBName,nil)
                if 1==err then MyWelderDebugLog(strName .. " server-TCPStart fail：input parameter fail")
                elseif 2==err then MyWelderDebugLog(strName .. " server-TCPStart fail:socket not exist")
                elseif 3==err then MyWelderDebugLog(strName .. " server-TCPStart fail:set timeout fail")
                elseif 4==err then MyWelderDebugLog(strName .. " server-TCPStart fail:recv fail")
                else MyWelderDebugLog(strName .. " server-TCPStart fail:errcode="..tostring(err))
                end
                TCPDestroy(socket)
                port = port+step --建立连接失败了，继续寻找下一个端口号
            end
        else 
            port = port+step
        end
    end
    if 0 ~= err then
        MyWelderDebugLog(strName .. " daemon.lua create tcp server fail,port="..port)
        return
    end
    
    MyWelderDebugLog(strName .. " tcpserver-> a new client has connected......")

    local _isOk,_data = pcall(function()
        local recvDataBuffer,data = {},{}
        while true do
            err, data = TCPRead(socket, 0)
            if err ~= 0 then
                MyWelderDebugLog(strName .. " tcpserver TCPRead fail,and than exit loop and will start again,err=" .. tostring(err))
                break
            elseif #data>0 then
                recvDataBuffer = append2Buffer(recvDataBuffer,data)
                if data[#data]==0 then
                    recvDataBuffer = table2String(recvDataBuffer)
                    local isOk, obj = toLuaObject(recvDataBuffer)
                    local params={}
                    for i=1,#obj.p do
                        table.insert(params,obj.p[i].v)
                    end
                    local retArray = callback(obj.m, params)
                    local retData = {}
                    for i=1,#retArray do
                        table.insert(retData,{v=retArray[i]})
                    end
                    local sendData = toJsonString(retData)
                    err = TCPWrite(socket, string2Table(sendData), 5)
                    if err ~= 0 then
                        MyWelderDebugLog(strName .. " tcpserver TCPWrite fail,and than exit loop and will start again,err=" .. tostring(err))
                        break
                    end
                    recvDataBuffer = {}
                end
                data = {}
            end
        end
    end)
    TCPDestroy(socket)
    if not _isOk then MyWelderDebugLog(tostring(_data)) end
end

--============================================================================================================================================
--============================================================================================================================================
--rpc 接口封装
local WelderRPCInterface={
    sock = nil,
    useRPC = true, --true表示使用rpc方式调用modbus，否则使用直接方式调用modbus
    --因为服务端创建时，可能存在端口被占用，所以这里面不要将端口写死，而是服务端进行配置，然后根据这个name来取端口
    --这个值是httpAPI.port或者userAPI.port
    name = nil
}

function WelderRPCInterface.initHttpAPI()
    WelderRPCInterface.name = "httpAPI.port"
end

function WelderRPCInterface.initUserAPI()
    WelderRPCInterface.name = "userAPI.port"
end

------------------------------------------------------------------------------------------------------------------------------------------------
--modbus相关的接口rpc封装
function WelderRPCInterface.ModbusCreate(IP, port, slave_id, isRTU)
    if not WelderRPCInterface.useRPC then
        return ThreadSafeModbus.ModbusCreate(IP, port, slave_id, isRTU)
    end
    local rpc = {}
    rpc.m = "ModbusCreate"
    rpc.p = {IP, port, slave_id, isRTU}
    return rpcCallDeamon(WelderRPCInterface,rpc)
end

function WelderRPCInterface.ModbusRTUCreate(slave_id, baud, parity, data_bit, stop_bit)
    if not WelderRPCInterface.useRPC then
        return ThreadSafeModbus.ModbusRTUCreate(slave_id, baud, parity, data_bit, stop_bit)
    end
    local rpc = {}
    rpc.m = "ModbusRTUCreate"
    rpc.p = {slave_id, baud, parity, data_bit, stop_bit}
    return rpcCallDeamon(WelderRPCInterface,rpc)
end

function WelderRPCInterface.ModbusClose(id)
    if not WelderRPCInterface.useRPC then
        return ThreadSafeModbus.ModbusClose(id)
    end
    local rpc = {}
    rpc.m = "ModbusClose"
    rpc.p = {id}
    return rpcCallDeamon(WelderRPCInterface,rpc)
end

function WelderRPCInterface.GetInBits(id, addr, count)
    if not WelderRPCInterface.useRPC then
        return ThreadSafeModbus.GetInBits(id, addr, count)
    end
    local rpc = {}
    rpc.m = "GetInBits"
    rpc.p = {id, addr, count}
    return rpcCallDeamon(WelderRPCInterface,rpc)
end

function WelderRPCInterface.GetInRegs(id, addr, count, _type)
    if not WelderRPCInterface.useRPC then
        return ThreadSafeModbus.GetInRegs(id, addr, count, _type)
    end
    local rpc = {}
    rpc.m = "GetInRegs"
    rpc.p = {id, addr, count, _type}
    return rpcCallDeamon(WelderRPCInterface,rpc)
end

function WelderRPCInterface.GetCoils(id, addr, count)
    if not WelderRPCInterface.useRPC then
        return ThreadSafeModbus.GetCoils(id, addr, count)
    end
    local rpc = {}
    rpc.m = "GetCoils"
    rpc.p = {id, addr, count}
    return rpcCallDeamon(WelderRPCInterface,rpc)
end

function WelderRPCInterface.SetCoils(id, addr, count, _table)
    if not WelderRPCInterface.useRPC then
        return ThreadSafeModbus.SetCoils(id, addr, count, _table)
    end
    local rpc = {}
    rpc.m = "SetCoils"
    rpc.p = {id, addr, count, _table}
    return rpcCallDeamon(WelderRPCInterface,rpc)
end

function WelderRPCInterface.GetHoldRegs(id, addr, count, _type)
    if not WelderRPCInterface.useRPC then
        return ThreadSafeModbus.GetHoldRegs(id, addr, count, _type)
    end
    local rpc = {}
    rpc.m = "GetHoldRegs"
    rpc.p = {id, addr, count, _type}
    return rpcCallDeamon(WelderRPCInterface,rpc)
end

function WelderRPCInterface.SetHoldRegs(id, addr, count, _table, _type)
    if not WelderRPCInterface.useRPC then
        return ThreadSafeModbus.SetHoldRegs(id, addr, count, _table, _type)
    end
    local rpc = {}
    rpc.m = "SetHoldRegs"
    rpc.p = {id, addr, count, _table, _type}
    return rpcCallDeamon(WelderRPCInterface,rpc)
end

------------------------------------------------------------------------------------------------------------------------------------------------
--模拟量相关的接口rpc封装
function WelderRPCInterface.AnalogCreate()
    if not WelderRPCInterface.useRPC then
        return 0,0
    end
    local rpc = {}
    rpc.m = "AnalogCreate"
    rpc.p = {}
    return rpcCallDeamon(WelderRPCInterface,rpc)
end
function WelderRPCInterface.AnalogClose()
    if not WelderRPCInterface.useRPC then
        return 0
    end
    local rpc = {}
    rpc.m = "AnalogClose"
    rpc.p = {}
    return rpcCallDeamon(WelderRPCInterface,rpc)
end

------------------------------------------------------------------------------------------------------------------------------------------------
--EtherNet IP相关的接口rpc封装
function WelderRPCInterface.CreateScanner(ip, epath, sizes)
    if not WelderRPCInterface.useRPC then
        return EtherNetIPScanner.CreateScanner(ip, epath, sizes)
    end
    local rpc = {}
    rpc.m = "CreateScanner"
    rpc.p = {ip, epath, sizes}
    return rpcCallDeamon(WelderRPCInterface,rpc)
end

function WelderRPCInterface.ScannerDestroy(sc)
    if not WelderRPCInterface.useRPC then
        return EtherNetIPScanner.ScannerDestroy(sc)
    end
    local rpc = {}
    rpc.m = "ScannerDestroy"
    rpc.p = {sc}
    return rpcCallDeamon(WelderRPCInterface,rpc)
end

function WelderRPCInterface.ScannerReadInput(sc, address, size)
    if not WelderRPCInterface.useRPC then
        return EtherNetIPScanner.ScannerReadInput(sc, address, size)
    end
    local rpc = {}
    rpc.m = "ScannerReadInput"
    rpc.p = {sc, address, size}
    return rpcCallDeamon(WelderRPCInterface,rpc)
end

function WelderRPCInterface.ScannerReadOutput(sc, address, size)
    if not WelderRPCInterface.useRPC then
        return EtherNetIPScanner.ScannerReadOutput(sc, address, size)
    end
    local rpc = {}
    rpc.m = "ScannerReadOutput"
    rpc.p = {sc, address, size}
    return rpcCallDeamon(WelderRPCInterface,rpc)
end

function WelderRPCInterface.ScannerWrite(sc, address, values)
    if not WelderRPCInterface.useRPC then
        return EtherNetIPScanner.ScannerWrite(sc, address, values)
    end
    local rpc = {}
    rpc.m = "ScannerWrite"
    rpc.p = {sc, address, values}
    return rpcCallDeamon(WelderRPCInterface,rpc)
end


------------------------------------------------------------------------------------------------------------------------------------------------
--其他相关的接口rpc封装
--[[
功能：当userAPI.lua脚本暂停时，该事件函数被触发调用
参数：无
返回值：0-表示成功，其他表示失败
说明：该函数只能在userAPI.lua进程中被触发调用，具体参考生态提供的注册接口`RegistePauseHandler`
]]--
function WelderRPCInterface.OnEventUserScriptPause()
    if not WelderRPCInterface.useRPC then
        MyWelderDebugLog("OnEventUserScriptPause has trigger but not use,because cannot support RPC")
        return
    end
    local rpc = {}
    rpc.m = "OnEventUserScriptPause"
    rpc.p = {}
    return rpcCallDeamon(WelderRPCInterface,rpc,60000) --60s超时
end

--[[
功能：当userAPI.lua脚本继续运行时，该事件函数被触发调用
参数：无
返回值：0-表示成功，其他表示失败
说明：该函数只能在userAPI.lua进程中被触发调用，具体参考生态提供的注册接口`RegisteContinueHandler`
]]--
function WelderRPCInterface.OnEventUserScriptContinue()
    if not WelderRPCInterface.useRPC then
        MyWelderDebugLog("OnEventUserScriptContinue has trigger but not use,because cannot support RPC")
        return
    end
    local rpc = {}
    rpc.m = "OnEventUserScriptContinue"
    rpc.p = {}
    return rpcCallDeamon(WelderRPCInterface,rpc,60000) --60s超时
end

--[[
功能：通过rpc方式发送起弧相关动作，包括起弧、起弧检测。
参数：无
返回值：返回2个参数，第一个是bool，第二个是string
        true-表示成功起弧，false-表示失败
        string-表示成功/失败的原因
]]--
function WelderRPCInterface.StartArc()
    local rpc = {}
    rpc.m = "StartArc"
    rpc.p = {}
    return rpcCallDeamon(WelderRPCInterface,rpc,60000) --60s超时
end

--[[
功能：通过rpc方式发送灭弧相关动作，包括灭弧、灭弧检测。
参数：无
返回值：返回2个参数，第一个是bool，第二个是string
        true-表示成功灭弧，false-表示失败
        string-表示成功/失败的原因
]]--
function WelderRPCInterface.EndArc()
    local rpc = {}
    rpc.m = "EndArc"
    rpc.p = {}
    return rpcCallDeamon(WelderRPCInterface,rpc,60000) --60s超时
end

--[[
功能：通过rpc方式执行一段时间的送丝、退丝、吹气
参数：durationMiliseconds-执行的时间，毫秒单位
返回值：true-表示成功，false表示失败
]]--
function WelderRPCInterface.ExecWireFeed(durationMiliseconds)
    local rpc = {}
    rpc.m = "ExecWireFeed"
    rpc.p = {durationMiliseconds}
    return rpcCallDeamon(WelderRPCInterface,rpc)
end
function WelderRPCInterface.ExecWireBack(durationMiliseconds)
    local rpc = {}
    rpc.m = "ExecWireBack"
    rpc.p = {durationMiliseconds}
    return rpcCallDeamon(WelderRPCInterface,rpc)
end
function WelderRPCInterface.ExecGasCheck(durationMiliseconds)
    local rpc = {}
    rpc.m = "ExecGasCheck"
    rpc.p = {durationMiliseconds}
    return rpcCallDeamon(WelderRPCInterface,rpc)
end

--[[
功能：通过rpc方式控制按钮盒子的服务是否启动
参数：bRun-为true表示启动，false表示停止
返回值：true-表示成功，false表示失败
]]--
function WelderRPCInterface.StartHandeldControllerServer(bRun)
    local rpc = {}
    rpc.m = "StartHandeldControllerServer"
    rpc.p = {bRun}
    rpcCallDeamon(WelderRPCInterface,rpc,500)
    return true
end
--============================================================================================================================================
--============================================================================================================================================
--rpc-server 封装
local WelderRPCServer = {}

function WelderRPCServer.httpAPIServer(requestCallback)
    executeRPCServer(requestCallback,"httpAPI.port")
end

function WelderRPCServer.userAPIServer(requestCallback)
    executeRPCServer(requestCallback,"userAPI.port")
end

--导出全局变量
DobotWelderRPC = {
    modbus = WelderRPCInterface,
    analog = WelderRPCInterface,
    api = WelderRPCInterface,
    rpcServer = WelderRPCServer
}