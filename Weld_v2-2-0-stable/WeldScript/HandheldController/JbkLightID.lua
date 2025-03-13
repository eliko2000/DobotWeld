--[[
GT72操纵杆控制器的业务封装
]]--

--按钮指示灯的id值
local JbkLightIDValue = {
    VirtualRun = 1,
    StopProject = 2,
    RealRun = 3,
    ApproachPoint = 4,
    ArcStartPoint = 5,
    ArcEndPoint = 6,
    LeavePoint = 7,
    WireBack = 8,
    EnableRobot = 8,
    WireFeed = 9,
    ClearWarn = 9,
    GasCheck = 10,
    DragMode = 10,
    MiddleLinePoint = 11,
    ExtendFunctionCode = 12,
    WeldArcParam = 12,
    WeldWeaveParam = 13,
    WeldSpot = 13,
    SwitchXYZMode = 14,
    MiddleArcPoint = 15,
    AutoManual = 16
}

--获取按钮指示灯的设置值
local JbkLightID = {
}
function JbkLightID.getOnVirtualRun(led)
    led = led | (1<<(JbkLightIDValue.VirtualRun-1))
    return led
end
function JbkLightID.getOffVirtualRun(led)
    led = led & (~(1<<(JbkLightIDValue.VirtualRun-1)))
    return led
end
function JbkLightID.isOnVirtualRun(led)
    local r = (led>>(JbkLightIDValue.VirtualRun-1))&0x01==0x01
    return r
end

function JbkLightID.getOnStopProject(led)
    led = led | (1<<(JbkLightIDValue.StopProject-1))
    return led
end
function JbkLightID.getOffStopProject(led)
    led = led & (~(1<<(JbkLightIDValue.StopProject-1)))
    return led
end
function JbkLightID.isOnStopProject(led)
    local r = (led>>(JbkLightIDValue.StopProject-1))&0x01==0x01
    return r
end

function JbkLightID.getOnRealRun(led)
    led = led | (1<<(JbkLightIDValue.RealRun-1))
    return led
end
function JbkLightID.getOffRealRun(led)
    led = led & (~(1<<(JbkLightIDValue.RealRun-1)))
    return led
end
function JbkLightID.isOnRealRun(led)
    local r = (led>>(JbkLightIDValue.RealRun-1))&0x01==0x01
    return r
end

function JbkLightID.getOnApproachPoint(led)
    led = led | (1<<(JbkLightIDValue.ApproachPoint-1))
    return led
end
function JbkLightID.getOffApproachPoint(led)
    led = led & (~(1<<(JbkLightIDValue.ApproachPoint-1)))
    return led
end
function JbkLightID.isOnApproachPoint(led)
    local r = (led>>(JbkLightIDValue.ApproachPoint-1))&0x01==0x01
    return r
end

function JbkLightID.getOnArcStartPoint(led)
    led = led | (1<<(JbkLightIDValue.ArcStartPoint-1))
    return led
end
function JbkLightID.getOffArcStartPoint(led)
    led = led & (~(1<<(JbkLightIDValue.ArcStartPoint-1)))
    return led
end
function JbkLightID.isOnArcStartPoint(led)
    local r = (led>>(JbkLightIDValue.ArcStartPoint-1))&0x01==0x01
    return r
end

function JbkLightID.getOnArcEndPoint(led)
    led = led | (1<<(JbkLightIDValue.ArcEndPoint-1))
    return led
end
function JbkLightID.getOffArcEndPoint(led)
    led = led & (~(1<<(JbkLightIDValue.ArcEndPoint-1)))
    return led
end
function JbkLightID.isOnArcEndPoint(led)
    local r = (led>>(JbkLightIDValue.ArcEndPoint-1))&0x01==0x01
    return r
end

function JbkLightID.getOnLeavePoint(led)
    led = led | (1<<(JbkLightIDValue.LeavePoint-1))
    return led
end
function JbkLightID.getOffLeavePoint(led)
    led = led & (~(1<<(JbkLightIDValue.LeavePoint-1)))
    return led
end
function JbkLightID.isOnLeavePoint(led)
    local r = (led>>(JbkLightIDValue.LeavePoint-1))&0x01==0x01
    return r
end

function JbkLightID.getOnWireBack(led)
    led = led | (1<<(JbkLightIDValue.WireBack-1))
    return led
end
function JbkLightID.getOffWireBack(led)
    led = led & (~(1<<(JbkLightIDValue.WireBack-1)))
    return led
end
function JbkLightID.isOnWireBack(led)
    local r = (led>>(JbkLightIDValue.WireBack-1))&0x01==0x01
    return r
end

function JbkLightID.getOnEnableRobot(led)
    led = led | (1<<(JbkLightIDValue.EnableRobot-1))
    return led
end
function JbkLightID.getOffEnableRobot(led)
    led = led & (~(1<<(JbkLightIDValue.EnableRobot-1)))
    return led
end
function JbkLightID.isOnEnableRobot(led)
    local r = (led>>(JbkLightIDValue.EnableRobot-1))&0x01==0x01
    return r
end

function JbkLightID.getOnWireFeed(led)
    led = led | (1<<(JbkLightIDValue.WireFeed-1))
    return led
end
function JbkLightID.getOffWireFeed(led)
    led = led & (~(1<<(JbkLightIDValue.WireFeed-1)))
    return led
end
function JbkLightID.isOnWireFeed(led)
    local r = (led>>(JbkLightIDValue.WireFeed-1))&0x01==0x01
    return r
end

function JbkLightID.getOnClearWarn(led)
    led = led | (1<<(JbkLightIDValue.ClearWarn-1))
    return led
end
function JbkLightID.getOffClearWarn(led)
    led = led & (~(1<<(JbkLightIDValue.ClearWarn-1)))
    return led
end
function JbkLightID.isOnClearWarn(led)
    local r = (led>>(JbkLightIDValue.ClearWarn-1))&0x01==0x01
    return r
end

function JbkLightID.getOnGasCheck(led)
    led = led | (1<<(JbkLightIDValue.GasCheck-1))
    return led
end
function JbkLightID.getOffGasCheck(led)
    led = led & (~(1<<(JbkLightIDValue.GasCheck-1)))
    return led
end
function JbkLightID.isOnGasCheck(led)
    local r = (led>>(JbkLightIDValue.GasCheck-1))&0x01==0x01
    return r
end

function JbkLightID.getOnDragMode(led)
    led = led | (1<<(JbkLightIDValue.DragMode-1))
    return led
end
function JbkLightID.getOffDragMode(led)
    led = led & (~(1<<(JbkLightIDValue.DragMode-1)))
    return led
end
function JbkLightID.isOnDragMode(led)
    local r = (led>>(JbkLightIDValue.DragMode-1))&0x01==0x01
    return r
end

function JbkLightID.getOnMiddleLinePoint(led)
    led = led | (1<<(JbkLightIDValue.MiddleLinePoint-1))
    return led
end
function JbkLightID.getOffMiddleLinePoint(led)
    led = led & (~(1<<(JbkLightIDValue.MiddleLinePoint-1)))
    return led
end
function JbkLightID.isOnMiddleLinePoint(led)
    local r = (led>>(JbkLightIDValue.MiddleLinePoint-1))&0x01==0x01
    return r
end

function JbkLightID.getOnExtendFunctionCode(led)
    led = led | (1<<(JbkLightIDValue.ExtendFunctionCode-1))
    return led
end
function JbkLightID.getOffExtendFunctionCode(led)
    led = led & (~(1<<(JbkLightIDValue.ExtendFunctionCode-1)))
    return led
end
function JbkLightID.isOnExtendFunctionCode(led)
    local r = (led>>(JbkLightIDValue.ExtendFunctionCode-1))&0x01==0x01
    return r
end

function JbkLightID.getOnWeldArcParam(led)
    led = led | (1<<(JbkLightIDValue.WeldArcParam-1))
    return led
end
function JbkLightID.getOffWeldArcParam(led)
    led = led & (~(1<<(JbkLightIDValue.WeldArcParam-1)))
    return led
end
function JbkLightID.isOnWeldArcParam(led)
    local r = (led>>(JbkLightIDValue.WeldArcParam-1))&0x01==0x01
    return r
end

function JbkLightID.getOnWeldWeaveParam(led)
    led = led | (1<<(JbkLightIDValue.WeldWeaveParam-1))
    return led
end
function JbkLightID.getOffWeldWeaveParam(led)
    led = led & (~(1<<(JbkLightIDValue.WeldWeaveParam-1)))
    return led
end
function JbkLightID.isOnWeldWeaveParam(led)
    local r = (led>>(JbkLightIDValue.WeldWeaveParam-1))&0x01==0x01
    return r
end

function JbkLightID.getOnWeldSpot(led)
    led = led | (1<<(JbkLightIDValue.WeldSpot-1))
    return led
end
function JbkLightID.getOffWeldSpot(led)
    led = led & (~(1<<(JbkLightIDValue.WeldSpot-1)))
    return led
end
function JbkLightID.isOnWeldSpot(led)
    local r = (led>>(JbkLightIDValue.WeldSpot-1))&0x01==0x01
    return r
end

function JbkLightID.getOnSwitchXYZMode(led)
    led = led | (1<<(JbkLightIDValue.SwitchXYZMode-1))
    return led
end
function JbkLightID.getOffSwitchXYZMode(led)
    led = led & (~(1<<(JbkLightIDValue.SwitchXYZMode-1)))
    return led
end
function JbkLightID.isOnSwitchXYZMode(led)
    local r = (led>>(JbkLightIDValue.SwitchXYZMode-1))&0x01==0x01
    return r
end

function JbkLightID.getOnMiddleArcPoint(led)
    led = led | (1<<(JbkLightIDValue.MiddleArcPoint-1))
    return led
end
function JbkLightID.getOffMiddleArcPoint(led)
    led = led & (~(1<<(JbkLightIDValue.MiddleArcPoint-1)))
    return led
end
function JbkLightID.isOnMiddleArcPoint(led)
    local r = (led>>(JbkLightIDValue.MiddleArcPoint-1))&0x01==0x01
    return r
end

function JbkLightID.getOnAutoManual(led)
    led = led | (1<<(JbkLightIDValue.AutoManual-1))
    return led
end
function JbkLightID.getOffAutoManual(led)
    led = led & (~(1<<(JbkLightIDValue.AutoManual-1)))
    return led
end
function JbkLightID.isOnAutoManual(led)
    local r = (led>>(JbkLightIDValue.AutoManual-1))&0x01==0x01
    return r
end

return JbkLightID