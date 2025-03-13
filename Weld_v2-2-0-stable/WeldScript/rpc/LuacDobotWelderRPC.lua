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


local g_strKeyRpcNodeName = "Dobot_Weld_DaemonRPCServer_NodeName_584DC10CC18D" --RPC节点名称
local g_strRcpServerFuncName = "_CallbackOnExecuteLuaRPCServer" --RPC服务端接口名
local g_pfnRequestServerCallback = nil --回调函数，格式为 func(method,paramsList)，返回值是接口实际返回值组成的table数组

local function connectDeamon(obj)
    if not obj.rpcOk then
        local err,errMsg = RPCCreate(false,g_strKeyRpcNodeName)
        if 0==err then
            obj.rpcOk = true
            MyWelderDebugLog("rpc client create success!!!")
            return true
        elseif -1==err then MyWelderDebugLog("rpc client create fail,errmsg="..tostring(errMsg))
        elseif -2==err then MyWelderDebugLog("rpc client create fail because of connect fail,errmsg="..tostring(errMsg))
        elseif -3==err then MyWelderDebugLog("rpc client create fail because of invalid parameter,errmsg="..tostring(errMsg))
        elseif -4==err then MyWelderDebugLog("rpc client create fail because of repeat create,errmsg="..tostring(errMsg))
        else MyWelderDebugLog("rpc client create fail,errmsg="..tostring(errMsg))
        end
    end
    return false
end

local function rpcCallDeamon(obj,paramsArray,timeoutMs)
    connectDeamon(obj)
    local rpc = {}
    rpc.m = paramsArray.m
    rpc.p = {}
    for i=1,#paramsArray.p do
        table.insert(rpc.p, {v=paramsArray.p[i]})
    end
    local sendData = toJsonString(rpc)
    
    --timeoutMs的时间判断，结合上下文看此段逻辑
    if nil==timeoutMs then timeoutMs=10000
    elseif timeoutMs<0 or timeoutMs>10000 then timeoutMs=0
    end
    
    local callInfo={
        g_strKeyRpcNodeName, --rpc服务的节点名
        timeoutMs --最大的调用等待时间ms,填0或者不填表示无限等待直到返回,为(0,10000]表示等待的时间ms,其他值控制器不支持
    }
    --返回值只有一个有效的string数据
    local resultInfo,retStringData = RPCCall(callInfo, g_strRcpServerFuncName, sendData)
    if resultInfo.isErr~=0 then
        MyWelderDebugLog("rpcCallDeamon call fail,method:"..rpc.m .. ",errmsg:" .. tostring(resultInfo.errMsg))
        return nil
    end
    local isOk, retData = toLuaObject(retStringData)
    if not isOk then 
        MyWelderDebugLog("rpcCallDeamon parse data fail,method:"..rpc.m .. ",retData:" .. tostring(retStringData))
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
参数：strRequestParam-请求参数
说明：这个函数只能是全局函数，可以把函数名称定义特殊些，防止出现全局冲突
]]--
function _CallbackOnExecuteLuaRPCServer(strRequestParam)
    local isOk, obj = toLuaObject(strRequestParam)
    local params={}
    for i=1,#obj.p do
        table.insert(params,obj.p[i].v)
    end
    local retArray = g_pfnRequestServerCallback(obj.m, params)
    local retData = {}
    for i=1,#retArray do
        table.insert(retData,{v=retArray[i]})
    end
    return toJsonString(retData)
end

--============================================================================================================================================
--============================================================================================================================================
--rpc 接口封装
local WelderRPCInterface={
    rpcOk = nil, --rpc client是否创建ok
    useRPC = true, --true表示使用rpc方式调用modbus，否则使用直接方式调用modbus
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
function WelderRPCInterface.CreateScanner(ip, epath, sizes, rpi)
    if not WelderRPCInterface.useRPC then
        return EtherNetIPScanner.CreateScanner(ip, epath, sizes, rpi)
    end
    local rpc = {}
    rpc.m = "CreateScanner"
    rpc.p = {ip, epath, sizes, rpi}
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

function WelderRPCServer.rpcAPIServer(requestCallback)
    g_pfnRequestServerCallback = requestCallback
    local err,errMsg = RPCCreate(true,g_strKeyRpcNodeName,1) --此函数为服务端时，如果创建成功则阻塞，失败就立刻返回。
    if 0==err then
        MyWelderDebugLog("rpc server create success!!!")
    elseif -1==err then MyWelderDebugLog("rpc server create fail,errmsg="..tostring(errMsg))
    elseif -2==err then MyWelderDebugLog("rpc server create fail because of connect fail,errmsg="..tostring(errMsg))
    elseif -3==err then MyWelderDebugLog("rpc server create fail because of invalid parameter,errmsg="..tostring(errMsg))
    elseif -4==err then MyWelderDebugLog("rpc server create fail because of repeat create,errmsg="..tostring(errMsg))
    else MyWelderDebugLog("rpc server create fail,errmsg="..tostring(errMsg))
    end
end

--导出全局变量
DobotWelderRPC = {
    modbus = WelderRPCInterface,
    analog = WelderRPCInterface,
    eip = WelderRPCInterface,
    api = WelderRPCInterface,
    rpcServer = WelderRPCServer
}