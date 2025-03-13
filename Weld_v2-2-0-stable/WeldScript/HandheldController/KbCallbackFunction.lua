--[[
GT72操纵杆控制器的按钮业务封装
]]--

--【回调函数对象】-----------------------------------------------------------------------------------------
local KbCallbackFunction = {}

function KbCallbackFunction.registerCallback(kbSender) --kbSender==JoystickKeyboard
	local kbevt = KbEventListener
	kbevt.kbSender = kbSender
    kbevt.initID()
    kbevt.initEventInfo()
    kbevt.setClickEventCallback(kbevt.ID.btn1, KbCallbackFunction.onClickBtn1)
    kbevt.setClickEventCallback(kbevt.ID.btn2, KbCallbackFunction.onClickBtn2)
    kbevt.setClickEventCallback(kbevt.ID.btn3, KbCallbackFunction.onClickBtn3)
    kbevt.setClickEventCallback(kbevt.ID.btn4, KbCallbackFunction.onClickBtn4)
    kbevt.setClickEventCallback(kbevt.ID.btn5, KbCallbackFunction.onClickBtn5)
    kbevt.setClickEventCallback(kbevt.ID.btn6, KbCallbackFunction.onClickBtn6)
    kbevt.setClickEventCallback(kbevt.ID.btn7, KbCallbackFunction.onClickBtn7)
    kbevt.setPressEventCallback(kbevt.ID.btn8, KbCallbackFunction.onPressBtn8)
    kbevt.setReleaseEventCallback(kbevt.ID.btn8, KbCallbackFunction.onReleaseBtn8)
    kbevt.setClickEventCallback(kbevt.ID.btn8, KbCallbackFunction.onClickBtn8)
    kbevt.setPressEventCallback(kbevt.ID.btn9, KbCallbackFunction.onPressBtn9)
    kbevt.setReleaseEventCallback(kbevt.ID.btn9, KbCallbackFunction.onReleaseBtn9)
    kbevt.setClickEventCallback(kbevt.ID.btn9, KbCallbackFunction.onClickBtn9)
    kbevt.setPressEventCallback(kbevt.ID.btn10, KbCallbackFunction.onPressBtn10)
    kbevt.setReleaseEventCallback(kbevt.ID.btn10, KbCallbackFunction.onReleaseBtn10)
    kbevt.setClickEventCallback(kbevt.ID.btn10, KbCallbackFunction.onClickBtn10)
    kbevt.setClickEventCallback(kbevt.ID.btn11, KbCallbackFunction.onClickBtn11)
    kbevt.setClickEventCallback(kbevt.ID.btn12, KbCallbackFunction.onClickBtn12)
    kbevt.setClickEventCallback(kbevt.ID.btn13, KbCallbackFunction.onClickBtn13)
    kbevt.setClickEventCallback(kbevt.ID.btn14, KbCallbackFunction.onClickBtn14)
    kbevt.setClickEventCallback(kbevt.ID.btn15, KbCallbackFunction.onClickBtn15)
    kbevt.setPressEventCallback(kbevt.ID.btn16, KbCallbackFunction.onPressBtn16)
    kbevt.setReleaseEventCallback(kbevt.ID.btn16, KbCallbackFunction.onReleaseBtn16)
    kbevt.setClickEventCallback(kbevt.ID.btn16, KbCallbackFunction.onClickBtn16)
    kbevt.setClickEventCallback(kbevt.ID.manualEncoder, KbCallbackFunction.onShakeEncoder)
    kbevt.setClickEventCallback(kbevt.ID.manualXYZ, KbCallbackFunction.onShakeManualXYZ)
    kbevt.setKeyEventCallback(KbCallbackFunction.onKeyEvent)
end

function KbCallbackFunction.onClickBtn1(sender, evtId, newValue)
    sender.setVirtualRun()
end

function KbCallbackFunction.onClickBtn2(sender, evtId, newValue)
    sender.setStopProject()
end

function KbCallbackFunction.onClickBtn3(sender, evtId, newValue)
    sender.setRealRun()
end

function KbCallbackFunction.onClickBtn4(sender, evtId, newValue)
    sender.addApproachPoint()
end

function KbCallbackFunction.onClickBtn5(sender, evtId, newValue)
    sender.addArcStartPoint()
end

function KbCallbackFunction.onClickBtn6(sender, evtId, newValue)
    sender.addArcEndPoint()
end

function KbCallbackFunction.onClickBtn7(sender, evtId, newValue)
    sender.addLeavePoint()
end

function KbCallbackFunction.onPressBtn8(sender, evtId, newValue)
    if sender.isDebugMode() then
        sender.setWireBack(true)
    end
end
function KbCallbackFunction.onReleaseBtn8(sender, evtId, newValue)
    if sender.isDebugMode() then
        sender.setWireBack(false)
    end
end
function KbCallbackFunction.onClickBtn8(sender, evtId, newValue)
    if sender.isNormalMode() then
        sender.setEnableRobot()
    end
end

function KbCallbackFunction.onPressBtn9(sender, evtId, newValue)
    if sender.isDebugMode() then
        sender.setWireFeed(true)
    end
end
function KbCallbackFunction.onReleaseBtn9(sender, evtId, newValue)
    if sender.isDebugMode() then
        sender.setWireFeed(false)
    end
end
function KbCallbackFunction.onClickBtn9(sender, evtId, newValue)
    if sender.isNormalMode() then
        sender.clearWarn()
    end
end

function KbCallbackFunction.onPressBtn10(sender, evtId, newValue)
    if sender.isDebugMode() then
        sender.setGasCheck(true)
    end
end
function KbCallbackFunction.onReleaseBtn10(sender, evtId, newValue)
    if sender.isDebugMode() then
        sender.setGasCheck(false)
    end
end
function KbCallbackFunction.onClickBtn10(sender, evtId, newValue)
    if sender.isNormalMode() then
        sender.setDragMode()
    end
end

function KbCallbackFunction.onClickBtn11(sender, evtId, newValue)
    sender.addMiddleLinePoint()
end

function KbCallbackFunction.onClickBtn12(sender, evtId, newValue)
    if sender.isExtendFunctionMode() then
        sender.setExtendFunctionCode()
    elseif sender.isNormalMode() then
        sender.setWeldArcParamMode()
    end
end

function KbCallbackFunction.onClickBtn13(sender, evtId, newValue)
    if sender.isNormalMode() then
        sender.setWeldWeaveParamMode()
    elseif sender.isSpotMode() then
        sender.doSpotWeld()
    end
end

function KbCallbackFunction.onClickBtn14(sender, evtId, newValue)
    sender.setSwitchXYZMode()
end

function KbCallbackFunction.onClickBtn15(sender, evtId, newValue)
    sender.addMiddleArcPoint()
end

function KbCallbackFunction.onPressBtn16(sender, evtId, newValue)
    if nil==KbCallbackFunction.btn16PressInfo then
        KbCallbackFunction.btn16PressInfo = {}
        KbCallbackFunction.btn16PressInfo.timestamp = Systime()
    else
        if not KbCallbackFunction.btn16PressInfo.hasDone and
           Systime()-KbCallbackFunction.btn16PressInfo.timestamp>5000
        then
            sender.clearProject()
            KbCallbackFunction.btn16PressInfo.hasDone = true
        end
    end
end
function KbCallbackFunction.onReleaseBtn16(sender, evtId, newValue)
    KbCallbackFunction.btn16PressInfo = nil
end
function KbCallbackFunction.onClickBtn16(sender, evtId, newValue)
    sender.setExtendFunctionMode()
end

function KbCallbackFunction.onShakeManualXYZ(sender, evtId, newValue)
    sender.setRunRobot(newValue)
end

function KbCallbackFunction.onShakeEncoder(sender, evtId, newValue)
    if newValue~=0 then MyWelderDebugLog("==========>onShakeEncoder newValue="..tostring(newValue)) end
    if sender.isExtendFunctionMode() then
        sender.setExtendFunctionValue(newValue)
    elseif sender.isNormalMode() then
        sender.setWeldParams(newValue)
    end
end

function KbCallbackFunction.onKeyEvent(sender, keyValue)
	local kbevt = KbEventListener
    if (keyValue>>(kbevt.ID.btn16-1))&0x01==1 then
        KbCallbackFunction.onPressBtn16(sender, kbevt.ID.btn16, 1)
    end
end

return KbCallbackFunction