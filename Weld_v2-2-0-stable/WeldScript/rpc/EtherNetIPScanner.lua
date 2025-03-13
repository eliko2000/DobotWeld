--[[
对EtherNet IP接口的封装
]]--
local dobot = require("pluginLua")

local g_innerEIPLockerName = "ThreadSafeEIPLocker-1A9FA45F-93E1-4421-AF45-25282E614179" --锁的名称
local g_innerEIPLockTimeout = 3000 --获取锁后，拥有锁资源的持续时长，毫秒单位
local g_innerEIPLockWaitTimeout = 10000 --等待获取锁资源的最大时间，毫秒单位
local g_maxDeltaTimeLog = 10000 --EIP请求的最大超时时间

local function innerEnterEIPLock()
    Lock(g_innerEIPLockerName,g_innerEIPLockTimeout,g_innerEIPLockWaitTimeout)
end

local function innerLeaveEIPLock()
    UnLock(g_innerEIPLockerName)
end

local MyEIPWrapperInner = {
    sc = nil,
    epath = {},
    sizes = {}
}

function MyEIPWrapperInner.clear()
    MyEIPWrapperInner.sc = nil
    MyEIPWrapperInner.epath = {}
    MyEIPWrapperInner.sizes = {}
    MyEIPWrapperInner.rpi = 80
end
--[[
功能：创建Ethernet/IP Scanner, 并和Ethernet/IP Adapter建立连接
参数：ip-连接的Adapter网络地址
      epath-Adapter地址数据,为table类型{configAssemblyId,outputAssemblyId,inputAssemblyId},分别表示配置组件id，输出组件id，输入组件id
      sizes-Adapter地址对应大小,为table类型{outputAssemblySize,inputAssemblySize},分别表示输出组件大小，输入组件大小。
      rpi-类型integer,数据包请求周期，单位毫秒，默认1秒，返回为大于0的值,不建议小于50
返回值：2个值，分别是：err,sc
        err-0：创建成功
            1：创建失败,epath里的值无效，id的数据类型为uint8
            2：创建失败,sizes里的值无效，大小范围为[0, 511]
            3：创建失败,rpi值无效，数值范围大于0
            4：创建失败,控制器中开启了EIP服务，需关闭才可使用
            5：创建失败,连接Adapter失败，检查是否开启服务，ip是否正常
        sc-为创建的句柄，是userdata类型的数据,在lua中无法操作
]]--

function MyEIPWrapperInner.CreateScanner(ip, epath, sizes, rpi)
    local beginTime = Systime()
    local isok,err,sc = pcall(dobot.CreateScanner, ip, epath, sizes, rpi)
    local deltaTime = Systime()-beginTime
    if deltaTime>=g_maxDeltaTimeLog then EcoLog("==========>>CreateScanner cost time:"..deltaTime) end
    if not isok then
        EcoLog("==========>>[EIP]CreateScanner throw msg:"..tostring(err))
        return -1,0
    end
    if 0==err then
        MyEIPWrapperInner.sc = sc
        MyEIPWrapperInner.epath[1] = epath[1]
        MyEIPWrapperInner.epath[2] = epath[2]
        MyEIPWrapperInner.epath[3] = epath[3]
        MyEIPWrapperInner.sizes[1] = sizes[1]
        MyEIPWrapperInner.sizes[2] = sizes[2]
        MyEIPWrapperInner.rpi = rpi
    end
    return err,sc
end

--关闭scanner
function MyEIPWrapperInner.ScannerDestroy(sc)
    if nil~=MyEIPWrapperInner.sc then
        local beginTime = Systime()
        pcall(dobot.ScannerDestroy, MyEIPWrapperInner.sc)
        local deltaTime = Systime()-beginTime
        if deltaTime>=g_maxDeltaTimeLog then EcoLog("==========>>ScannerDestroy cost time:"..deltaTime) end
        MyEIPWrapperInner.clear()
    end
end

--[[
功能：读取Input Assembly数据
参数：sc-句柄对象，
      address-起始数据地址，需小于创建的Input大小
      size-获取数据的大小，地址加大小需不大于创建的Input大小
返回值：成功返回长度为size的数组(也就是table数据),失败返回长度为0的数组
]]--
function MyEIPWrapperInner.ScannerReadInput(sc, address, size)
    if nil~=MyEIPWrapperInner.sc then
        local beginTime = Systime()
        local isok,data = pcall(dobot.ScannerReadInput, MyEIPWrapperInner.sc, address, size)
        local deltaTime = Systime()-beginTime
        if deltaTime>=g_maxDeltaTimeLog then EcoLog("==========>>ScannerReadInput cost time:"..deltaTime) end
        if not isok then
            EcoLog("==========>>[EIP]ScannerReadInput throw msg:"..tostring(data))
            return {}
        end
        return data
    end
    return {}
end

--[[
功能：读取Output Assembly数据
参数：sc-句柄对象，
      address-起始数据地址，需小于创建的Output大小
      size-获取数据的大小，地址加大小需不大于创建的Output大小
返回值：成功返回长度为size的数组(也就是table数据),失败返回长度为0的数组
]]--
function MyEIPWrapperInner.ScannerReadOutput(sc, address, size)
    if nil~=MyEIPWrapperInner.sc then
        local beginTime = Systime()
        local isok,data = pcall(dobot.ScannerReadOutput, MyEIPWrapperInner.sc, address, size)
        local deltaTime = Systime()-beginTime
        if deltaTime>=g_maxDeltaTimeLog then EcoLog("==========>>ScannerReadOutput cost time:"..deltaTime) end
        if not isok then
            EcoLog("==========>>[EIP]ScannerReadOutput throw msg:"..tostring(data))
            return {}
        end
        return data
    end
    return {}
end

--[[
功能：写入Output Assembly数据
参数：sc-句柄对象，
      address-起始数据地址，需小于创建的Output大小
      values-需要写入的数据，格式为字节数组{uint8,uint8,uint8,.....}
返回值：0: 写入成功
        1: 写入失败，服务不存在或关闭
        2: 写入失败，写入地址或数据数量
]]--
function MyEIPWrapperInner.ScannerWrite(sc, address, values)
    if nil~=MyEIPWrapperInner.sc then
        local beginTime = Systime()
        local isok,data = pcall(dobot.ScannerWrite, MyEIPWrapperInner.sc, address, values)
        local deltaTime = Systime()-beginTime
        if deltaTime>=g_maxDeltaTimeLog then EcoLog("==========>>ScannerWrite cost time:"..deltaTime) end
        if not isok then
            EcoLog("==========>>[EIP]ScannerWrite throw msg:"..tostring(data))
            return {}
        end
        return data
    end
    return 1
end

--------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------
--EIP线程安全的操作*******************************************************************************************
EtherNetIPScanner = {}

function EtherNetIPScanner.CreateScanner(ip, epath, sizes, rpi)
    innerEnterEIPLock()
    local isOk,err,sc = pcall(MyEIPWrapperInner.CreateScanner,ip, epath, sizes, rpi)
    innerLeaveEIPLock()
    if false==isOk then return -1,0 end
    return err,sc
end

function EtherNetIPScanner.ScannerDestroy(sc)
    innerEnterEIPLock()
    local isOk,err = pcall(MyEIPWrapperInner.ScannerDestroy,sc)
    innerLeaveEIPLock()
    if false==isOk then return 0 end
    return err
end

function EtherNetIPScanner.ScannerReadInput(sc, address, size)
    innerEnterEIPLock()
    local isOk,val = pcall(MyEIPWrapperInner.ScannerReadInput,sc, address, size)
    innerLeaveEIPLock()
    if false==isOk then return {} end
    return val
end

function EtherNetIPScanner.ScannerReadOutput(sc, address, size)
    innerEnterEIPLock()
    local isOk,val = pcall(MyEIPWrapperInner.ScannerReadOutput,sc, address, size)
    innerLeaveEIPLock()
    if false==isOk then return {} end
    return val
end

function EtherNetIPScanner.ScannerWrite(sc, address, values)
    innerEnterEIPLock()
    local isOk,val = pcall(MyEIPWrapperInner.ScannerWrite,sc, address, values)
    innerLeaveEIPLock()
    if false==isOk then return 1 end
    return val
end