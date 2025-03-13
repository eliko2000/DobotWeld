--[[
GT72操纵杆控制器的业务封装

以下的定义是按照实物的面板键盘来划分的
【按钮1~按钮16】是否按下状态只读
分别是：低速按键，      中速按键，    高速按键
        Z轴下微调，     Z轴上微调，   X轴左微调，   X轴右微调
        X轴锁定，       Y轴锁定，     Z轴锁定，     Y轴上微调
        F1按键，        F2按键，      F3按键，      Y轴下微调
        旋钮编码器按钮

【指示灯1~指示灯16】亮灭状态可读可写
分别是：低速按键灯，          中速按键灯，        高速按键灯
        Z轴下微调按键灯，     Z轴上微调按键灯，   X轴左微调按键灯，    X轴右微调按键灯
        X轴锁定按键灯，       Y轴锁定按键灯，     Z轴锁定按键灯，      Y轴上微调按键灯
        F1按键灯，            F2按键灯，          F3按键灯，           Y轴下微调灯
        Manual灯
        
【数码管灯1~4】可读可写
从左到右分别表示：LED1，LED2，LED3，LED4
]]--

--【本地私有接口】-----------------------------------------------------------------------------------------
local g_innerKeyboardLockerName = "KeyboardThdSafeLocker-E4B0EB78-B953-4624-B97C-2D951278E88D"
local function enterLock()
    Lock(g_innerKeyboardLockerName,8000,10000)
end
local function leaveLock()
    UnLock(g_innerKeyboardLockerName)
end

-----------------------------------------------------------------------------------------------------------
--【键盘事件处理】-----------------------------------------------------------------------------------------
local KbEventListener = {
    ID = {}, --事件id分配表
    EventInfo = {}, --事件信息表
    pfnKeyEvent = nil, --键盘按键事件统一处理回调函数，主要是一些需要长按的场景
    kbSender = nil --键盘控制器信号发送者，其实就是`JoystickKeyboard`对象
}

--线程安全的调用函数
function KbEventListener.safeCallFunc(pfn,...)
    enterLock()
    local isOk,v1,v2,v3,v4,v5,v6,v7,v8,v9,v10 = pcall(pfn,...)
    leaveLock()
    return isOk,v1,v2,v3,v4,v5,v6,v7,v8,v9,v10
end

--键盘事件id分配表初始化函数
function KbEventListener.initID()
    KbEventListener.ID = {
        btn1=1, btn2=2, btn3=3, 
        btn4=4, btn5=5, btn6=6, btn7=7, 
        btn8=8, btn9=9, btn10=10, btn11=11, 
        btn12=12, btn13=13, btn14=14, btn15=15, 
        btn16=16,  --编码器旋钮按钮
        manualEncoder=17,  --编码器旋钮方向
        manualXYZ=18  --摇杆XYY方向
    }
end

--键盘事件每个id对应的一些属性和状态值初始化函数
function KbEventListener.initEventInfo()
    for i=1,20 do --有多少个就初始化多少个
        KbEventListener.EventInfo[i]={
            value=nil, --当前值
            pressTime = 0, --按下时的时间
            releaseTime = 0, --弹起时的时间
            onPress=nil, --按下事件回调函数
            onRelease=nil, --弹起事件回调函数
            onClick=nil --单击事件回调函数
        }
    end
end

--设置按下、弹起、单击事件回调
--evtId表示对应事件id
--cb形如 function(sender,evtId,newValue)的回调函数,不同的事件，newValue的值含义不一样，具体看实现
function KbEventListener.setPressEventCallback(evtId,cb)
    if math.type(evtId) ~= "integer" then return false end
    if nil==KbEventListener.EventInfo[evtId] then return false end
    if cb==nil or type(cb)=="function" then
        KbEventListener.EventInfo[evtId].onPress = cb
        return true
    end
    return false
end
function KbEventListener.setReleaseEventCallback(evtId,cb)
    if math.type(evtId) ~= "integer" then return false end
    if nil==KbEventListener.EventInfo[evtId] then return false end
    if cb==nil or type(cb)=="function" then
        KbEventListener.EventInfo[evtId].onRelease = cb
        return true
    end
    return false
end
function KbEventListener.setClickEventCallback(evtId,cb)
    if math.type(evtId) ~= "integer" then return false end
    if nil==KbEventListener.EventInfo[evtId] then return false end
    if cb==nil or type(cb)=="function" then
        KbEventListener.EventInfo[evtId].onClick = cb
        return true
    end
    return false
end

--设置键盘按键事件统一处理回调函数，主要是一些需要长按的场景
function KbEventListener.setKeyEventCallback(cb)
    KbEventListener.pfnKeyEvent = cb
end

--键盘事件处理函数
function KbEventListener.processKeyboardEvent()
    local kbSender = KbEventListener.kbSender
    if not kbSender then return false end

    --读取键盘所有信息
    local _isScriptOk,_retValue = KbEventListener.safeCallFunc(kbSender.controller.readAllInfo)
    if not _isScriptOk then 
        MyWelderDebugLog(tostring(_retValue))
        return false
    end
    if not _retValue then return false end
    
    local evtinfo,newValue,deltaTime
    --按钮状态解析
    local value = kbSender.controller.getButtonPressState()
    for i=0,15 do
        evtinfo = KbEventListener.EventInfo[i+1]
        newValue = (value>>i)&0x01
        if (nil==evtinfo.value or 0==evtinfo.value) and 1==newValue then --按下
            evtinfo.pressTime = Systime()
            if nil ~= evtinfo.onPress then
                _isScriptOk,_retValue = pcall(evtinfo.onPress, kbSender, i+1, newValue)
                if not _isScriptOk then MyWelderDebugLog(tostring(_retValue)) end
            end
        elseif 1==evtinfo.value and 0==newValue then --弹起
            evtinfo.releaseTime = Systime()
            if nil ~= evtinfo.onRelease then
                _isScriptOk,_retValue = pcall(evtinfo.onRelease, kbSender, i+1, newValue)
                if not _isScriptOk then MyWelderDebugLog(tostring(_retValue)) end
            end
            deltaTime = evtinfo.releaseTime - evtinfo.pressTime --按下和弹起的时间差
            if deltaTime<1000 and nil~=evtinfo.onClick then
                _isScriptOk,_retValue = pcall(evtinfo.onClick, kbSender, i+1, newValue)
                if not _isScriptOk then MyWelderDebugLog(tostring(_retValue)) end
            end
        end
        evtinfo.value = newValue
    end
    
    --16个按钮的状态统一监控，有些场景需要按钮持续按下的事件处理
    if nil~=KbEventListener.pfnKeyEvent then
        _isScriptOk,_retValue = pcall(KbEventListener.pfnKeyEvent, kbSender, value)
        if not _isScriptOk then MyWelderDebugLog(tostring(_retValue)) end
    end
	
    --编码器旋钮方向
    evtinfo = KbEventListener.EventInfo[KbEventListener.ID.manualEncoder]
	newValue = kbSender.controller.getDirectionEncoder()
    if nil ~= evtinfo.onClick then
        _isScriptOk,_retValue = pcall(evtinfo.onClick, kbSender, KbEventListener.ID.manualEncoder, newValue)
        if not _isScriptOk then MyWelderDebugLog(tostring(_retValue)) end
    end
	evtinfo.value = newValue
    
    --摇杆XYZ方向
    evtinfo = KbEventListener.EventInfo[KbEventListener.ID.manualXYZ]
    newValue = {
        kbSender.controller.getDirectionX(),
        kbSender.controller.getDirectionY(),
        kbSender.controller.getDirectionZ()
    }
    if nil ~= evtinfo.onClick then
        _isScriptOk,_retValue = pcall(evtinfo.onClick, kbSender, KbEventListener.ID.manualXYZ, newValue)
        if not _isScriptOk then MyWelderDebugLog(tostring(_retValue)) end
    end
	evtinfo.value = newValue
    
    return true
end

return KbEventListener