-- 此文件用于封装一些公用的帮助函数

local CHelperTools={}

--深度复制lua对象
function CHelperTools.DeepCopy(tab)
    local lookupTable = {} --防止表中某个字段指向自己，最终陷入死递归
    local function inner_copy(obj)
        if type(obj) ~= "table" then 
            return obj
        elseif lookupTable[obj] then 
            return lookupTable[obj] 
        end
        local newTab = {}
        lookupTable[obj] = newTab
        for k,v in pairs(obj) do
            newTab[inner_copy(k)] = inner_copy(v)
        end
        return setmetatable(newTab, getmetatable(obj))
    end
    return inner_copy(tab)
end

--[[
在lua中整数都是number，且是int64位的，因为没有字节说法，所以无法表示单字节、双字节、4字节的有符号和无符号的数据。
例如：-1的单字节是0xFF，但是lua中会把0xFF当作是int64来处理，结果就是255，为了解决这个问题，就添加了以下接口。
以下函数说明：
--1.以下参数都是整数，否则不适合
--2.参数num认为是“单字节、双字节、4字节”的情况下进行转换的。
    例如：toInt8则认为num是0xXX这样的数据
]]--
function CHelperTools.ToInt8(num)
    if (num&0x80)==0x80 then --最高位是1，说明是负数
        num = num|(~0xFF)
    end
    return num
end
function CHelperTools.ToUInt8(num)
    num = num&0xFF
    return num
end
function CHelperTools.ToInt16(num)
    if (num&0x8000)==0x8000 then
        num = num|(~0xFFFF)
    end
    return num   
end
function CHelperTools.ToUInt16(num)
    num = num&0xFFFF
    return num
end
function CHelperTools.ToInt32(num)
    if (num&0x80000000)==0x80000000 then
        num = num|(~0xFFFFFFFF)
    end
    return num  
end
function CHelperTools.ToUInt32(num)
    num = num&0xFFFFFFFF
    return num
end

--[[
功能：将num做一个四舍五入处理成整数,
      例如：1.2-->1，1.5-->2，1.6-->2
            -1.2-->-1，-1.5-->-2，-1.6-->-2
返回整数
]]--
function CHelperTools.Float2IntegerRoundHalf(num)
    if math.type(num)=="integer" then
        return num
    elseif math.type(num)=="float" then
        local intV,floatV = math.modf(num) --modf返回的整数和小数部分是同符号的，比如：-1.2被拆分位-1和-0.2
        if intV>0 then
            if floatV>=0.5 then intV=intV+1 end
        elseif intV==0 then
            if floatV>=0.5 then intV=1
            elseif floatV<=-0.5 then intV=-1 
            end
        else
            if floatV<=-0.5 then intV=intV-1 end
        end
        return intV
    else
        return num
    end
end

--判断所有数值是否都为0，如果是则返回true
function CHelperTools.IsAllDataZero(arrData)
    if nil==arrData then return true end
    local isOk = true
    for i=1,#arrData do
        if 0~=arrData[i] then
            isOk = false
            break
        end
    end
    return isOk
end

return CHelperTools