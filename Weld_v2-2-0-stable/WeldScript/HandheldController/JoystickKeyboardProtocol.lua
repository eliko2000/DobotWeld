--[[
北京智联电控GT72操纵杆控制器 modbus rtu 协议的封装
重要说明：
        明面上是modbus rtu协议，实际是一个伪装的modbus，每次收发，都需要把所有地址的数据下发和接收上来，否则出错。
]]--

--【本地私有接口】
--数码管显示对应内容的代码
local DigitalCode = {}
DigitalCode["0"] = 0x3f
DigitalCode["1"] = 0x06
DigitalCode["2"] = 0x5b
DigitalCode["3"] = 0x4f
DigitalCode["4"] = 0x66
DigitalCode["5"] = 0x6d
DigitalCode["6"] = 0x7d
DigitalCode["7"] = 0x27
DigitalCode["8"] = 0x7f
DigitalCode["9"] = 0x6f
DigitalCode["-"] = 0x40
DigitalCode["A"] = 0x77
DigitalCode["b"] = 0x7c
DigitalCode["c"] = 0x39
DigitalCode["d"] = 0x5e
DigitalCode["E"] = 0x79
DigitalCode["F"] = 0x71
DigitalCode["G"] = 0x3d
DigitalCode["H"] = 0x76
DigitalCode["I"] = 0x0f
DigitalCode["J"] = 0x0e
DigitalCode["K"] = 0x75
DigitalCode["L"] = 0x38
DigitalCode["M"] = 0x37
DigitalCode["n"] = 0x54
DigitalCode["o"] = 0x5c
DigitalCode["P"] = 0x73
DigitalCode["q"] = 0x67
DigitalCode["r"] = 0x31
DigitalCode["S"] = 0x49
DigitalCode["t"] = 0x78
DigitalCode["U"] = 0x3e
DigitalCode["v"] = 0x1c
DigitalCode["W"] = 0x7e
DigitalCode["X"] = 0x64
DigitalCode["Y"] = 0x6e
DigitalCode["Z"] = 0x5a

--数码管的代码上要显示小数点
local function cvtShowFloat(ledCode,bShow)
    if bShow then
        return ledCode|0x80
    else
        return ledCode&0x7f
    end
end

local function tryConnectAgain(self)
    --[[
    if self.isConnected() then
        self.disconnect()
    end
    return self.connect(self.baud,self.parity,self.databit,self.stopbit)
    ]]--
end

--[[
功能：读取操纵杆所有信息
参数：无
返回值：true表示成功，false表示失败
]]--
local function readAllInfo(self)
    self.readdata = GetHoldRegs(self.id, 0x4001, 5, "U16") or {}
    if 5~=#self.readdata then
        --MyWelderDebugLog("GetHoldRegs fail")
        self.readdata = nil
        tryConnectAgain(self)
        return false
    end
    return true
end

--[[
功能：发送所有值
参数：无
返回值：true-成功，false-失败
]]--
local function writeAllInfo(self)
    if nil==self.ledCode1 then self.ledCode1 = 0x00 end
    if nil==self.ledCode2 then self.ledCode2 = 0x00 end
    if nil==self.ledCode3 then self.ledCode3 = 0x00 end
    if nil==self.ledCode4 then self.ledCode4 = 0x00 end
    local tv={}
    tv[1] = self.ledValue
    tv[2] = ((self.ledCode1<<8)|self.ledCode2)&0xffff
    tv[3] = ((self.ledCode3<<8)|self.ledCode4)&0xffff
    local ret = SetHoldRegs(self.id, 0x4005, #tv, tv, "U16")
    if 0~=ret then
        --MyWelderDebugLog("SetHoldRegs fail")
        tryConnectAgain(self)
        return false
    end
    return true
end

--------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------
--【导出接口】
local JoystickKeyboardProtocol = {
    id = nil, --modbus成功连接的句柄id
    baud = 115200,
    parity = "N",
    databit = 8,
    stopbit = 1,
    --重要说明：此产品明面上是modbus rtu协议，实际上只不过是披着modbus rtu外衣的伪modbus，
    --          因为它仅仅只是按照modbus协议做数据收发，却没有modbus协议的表概念，每次的读写(收发)必须是全量数据操作，
    --          也就是不能对单个寄存器地址做操作，而是所有地址数据要么全读，要么全写。
    readdata = nil, --操纵杆读到的寄存器所有数据
    ledValue = 0, --16个led灯的值。
    ledCode1 = DigitalCode["0"], --4个数码管显示的代码。
    ledCode2 = DigitalCode["0"],
    ledCode3 = DigitalCode["0"],
    ledCode4 = DigitalCode["0"],
    LedCodeTab = DigitalCode
}

--------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------
--[[
功能：通过modbus rtu方式连接
参数：baud-波特率，parity-是否校验位
      databit-数据位，stopbit-停止位
返回值：true表示成功，false表示失败
]]--
function JoystickKeyboardProtocol.connect(baud,parity,databit,stopbit)
    local self = JoystickKeyboardProtocol
    self.baud = baud or 115200
    self.parity = parity or "N"
    self.databit = databit or 8
    self.stopbit = stopbit or 1
    if nil==ModbusRTUCreate then
        ModbusRTUCreate = require("pluginLua").ModbusRTUCreate
    end
    local err, id = ModbusRTUCreate(1,self.baud,self.parity,self.databit,self.stopbit)
    if 0==err then
        MyWelderDebugLog("JoystickKeyboardProtocol ModbusRTU create success")
        self.id = id
        return true
    else
        MyWelderDebugLog("JoystickKeyboardProtocol ModbusRTU create fail,err="..tostring(err))
        self.id = nil
        return false
    end
end

--[[
功能：断开是否已连接
参数：无
返回值：true-已连接，false-未连接
]]--
function JoystickKeyboardProtocol.isConnected()
    local self = JoystickKeyboardProtocol
    return nil~=self.id
end

--[[
功能：断开连接
参数：无
返回值：无
]]--
function JoystickKeyboardProtocol.disconnect()
    local self = JoystickKeyboardProtocol
    if nil~=self.id then
        ModbusClose(self.id)
        self.id = nil
        MyWelderDebugLog("JoystickKeyboardProtocol ModbusRTU has close")
    end
end

--------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------
--[[
功能：读取操纵杆所有信息
参数：无
返回值：true表示成功，false表示失败
]]--
function JoystickKeyboardProtocol.readAllInfo()
    local self = JoystickKeyboardProtocol
    for i=1,3 do
        if readAllInfo(self) then
            return true
        else
            Wait(50)
        end
    end
    return false
end

--解析16个按钮是否被按下的状态,bit0~bit15分别代表“按钮1~按钮16”，bit位为1表示按下，0表示松开
function JoystickKeyboardProtocol.getButtonPressState()
    local self = JoystickKeyboardProtocol
    if self.readdata then
        return self.readdata[1]
    end
    return 0
end

--解析操纵杆X方向：0表示停止，小于0表示负方向，大于0表示正方向
function JoystickKeyboardProtocol.getDirectionX()
    local self = JoystickKeyboardProtocol
    if not self.readdata then return 0 end
    local v = self.readdata[2]&0xFFFF
    local deta = 300 --加个偏差，防止误碰, 有效范围值 0x0060~0x0800~0x0FA0
    if v < 0x0800-deta then --这个越小，表示越向右，特殊些。
        return 1
    elseif v > 0x800+deta then
        return -1
    else
        return 0
    end
end

--解析操纵杆Y方向：0表示停止，小于0表示负方向，大于0表示正方向
function JoystickKeyboardProtocol.getDirectionY()
    local self = JoystickKeyboardProtocol
    if not self.readdata then return 0 end
    local v = self.readdata[3]&0xFFFF
    local deta = 300 --加个偏差，防止误碰, 有效范围值 0x0060~0x0800~0x0FA0
    if v > 0x800+deta then
        return 1
    elseif v < 0x0800-deta then
        return -1
    else
        return 0
    end
end

--解析操纵杆Z方向：0表示停止，小于0表示负方向，大于0表示正方向
function JoystickKeyboardProtocol.getDirectionZ()
    local self = JoystickKeyboardProtocol
    if not self.readdata then return 0 end
    local v = self.readdata[4]&0xFFFF
    local deta = 300 --加个偏差，防止误碰, 有效范围值 0x0200~0x0800~0x0E00
    if v > 0x800+deta then
        return 1
    elseif v < 0x0800-deta then
        return -1
    else
        return 0
    end
end

--解析编码器旋转方向：0表示未旋转，小于0表示逆时针旋转，大于0表示顺时针旋转，返回值可以代表旋转了多少个刻度
function JoystickKeyboardProtocol.getDirectionEncoder()
    local self = JoystickKeyboardProtocol
    if not self.readdata then return 0 end
    local v = CHelperTools.ToInt16(self.readdata[5])
    return v
end

--------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------
--[[
功能：获取/设置16个按钮指示灯状态
参数：无
返回值：按钮状态uint16值，bit0~bit15分别代表“按钮1~按钮16”的指示灯，bit位为1表示灯亮，0表示灯灭
]]--
function JoystickKeyboardProtocol.getButtonLedState()
    local self = JoystickKeyboardProtocol
    return self.ledValue
end

function JoystickKeyboardProtocol.setButtonLedState(state)
    local self = JoystickKeyboardProtocol
    if math.type(state)=="integer" then
        self.ledValue = state&0xFFFF
    end
end

--[[
功能：获取/设置1,2,3,4数码管的显示值
参数：无
返回值：数码管1值,数码管2值,数码管3值,数码管4值
]]--
function JoystickKeyboardProtocol.getDigitalLedCode()
    local self = JoystickKeyboardProtocol
    return self.ledCode1,self.ledCode2,self.ledCode3,self.ledCode4
end
--设置数码管led显示的字符串,长度为4,超出部分将截断，不足的补\x00
function JoystickKeyboardProtocol.setLedString(str)
    local self = JoystickKeyboardProtocol
    local v1,v2,v3,v4 = string.byte(str, 1, #str)
    self.ledCode1 = DigitalCode[string.char(v1 or 0)] or 0x00
    self.ledCode2 = DigitalCode[string.char(v2 or 0)] or 0x00
    self.ledCode3 = DigitalCode[string.char(v3 or 0)] or 0x00
    self.ledCode4 = DigitalCode[string.char(v4 or 0)] or 0x00
end

--设置led显示整数（正数、0、负数）
--因为只有4段数码管，所以最大只能显示9999，最小只能显示-999，超出的部分高位丢弃。
--高位无意义的0将不显示。
function JoystickKeyboardProtocol.setDigitalIntValue(intValue)
    local self = JoystickKeyboardProtocol
    local tb = {DigitalCode["0"], DigitalCode["1"], DigitalCode["2"], DigitalCode["3"],
                DigitalCode["4"], DigitalCode["5"], DigitalCode["6"], DigitalCode["7"],
                DigitalCode["8"], DigitalCode["9"]}

    if intValue>0 then
        intValue = intValue%10000
    elseif intValue<0 then
        intValue = -(-intValue%1000)
    end
    local strValue = string.reverse(string.format("%d",intValue))
    local v4,v3,v2,v1 = string.byte(strValue,1,#strValue)
    -- '0'==48, '-'==45
    local tv={v1,v2,v3,v4}
    local ledv={}
    for i=1,4 do
        if nil==tv[i] then ledv[i] = DigitalCode.NIL
        elseif 45==tv[i] then ledv[i] = DigitalCode.minus
        else ledv[i] = tb[tv[i]-48+1]
        end
    end
    self.ledCode1 = ledv[1]
    self.ledCode2 = ledv[2]
    self.ledCode3 = ledv[3]
    self.ledCode4 = ledv[4]
end

--设置led显示小数（正数、负数），超出部分丢弃尾巴
function JoystickKeyboardProtocol.setDigitalFloatValue(floatValue)
    local self = JoystickKeyboardProtocol
    local tb = {DigitalCode["0"], DigitalCode["1"], DigitalCode["2"], DigitalCode["3"],
                DigitalCode["4"], DigitalCode["5"], DigitalCode["6"], DigitalCode["7"],
                DigitalCode["8"], DigitalCode["9"]}

    if floatValue>0 then
        floatValue = floatValue+0.0005 --四舍五入
    elseif floatValue<0 then
        floatValue = -(-floatValue+0.005)
    end
    local strValue = string.format("%.3f",floatValue)
    local v1,v2,v3,v4,v5 = string.byte(strValue,1,#strValue)
    local tv={v1,v2,v3,v4,v5}
    local ledv={}
    
    -- '0'==48, '-'==45, '.'==46
    local ledvIdx,i = 1,1
    while nil~=tv[i] do
        if 45==tv[i] then ledv[ledvIdx] = DigitalCode.minus
        elseif 46==tv[i] then --小数点
            ledvIdx = ledvIdx-1 --小数点的前一个数据肯定也是数字，所以不用担心nil问题。
            ledv[ledvIdx] = cvtShowFloat(ledv[ledvIdx],true)
        else ledv[ledvIdx] = tb[tv[i]-48+1]
        end
        i = i+1
        ledvIdx = ledvIdx+1
    end
    for i=1,4-(ledvIdx-1) do
        table.insert(ledv[i],1,DigitalCode.NIL)
    end
    self.ledCode1 = ledv[1]
    self.ledCode2 = ledv[2]
    self.ledCode3 = ledv[3]
    self.ledCode4 = ledv[4]
end

--将数值写入到设备中
function JoystickKeyboardProtocol.writeAllInfo()
    local self = JoystickKeyboardProtocol
    for i=1,3 do
        if writeAllInfo(self) then
            return true
        else
            Wait(50)
        end
    end
    return false
end

return JoystickKeyboardProtocol