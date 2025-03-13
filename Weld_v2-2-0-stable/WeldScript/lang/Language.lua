-- 此文件用于封装中文的翻译

--数据库保存的key，不要轻易修改------------------------------------------------------------------------------
local keySelectedLangName = "Dobot_Weld_Parameter_Language_SelectedName"

--【语言导出表】
Language = {
    selLangTab = nil, --当前选中的语言翻译表
    logLangObject = nil, --当前日志翻译语言对象
    logLangFilePath = nil --当前日志翻译语言对象文件require路径
}

--内部使用，设置语言表********************************************
local function innerSetLangTab(strLang)
    if "zh" == strLang then
        Language.selLangTab = LangWeldMode.zh
    elseif "ja" == strLang then
        Language.selLangTab = LangWeldMode.ja
    elseif "de" == strLang then
        Language.selLangTab = LangWeldMode.de
    else
        Language.selLangTab = LangWeldMode.en
    end
end
local function innerSetLogLangObject(strLang)
    local requirePath = nil
    if "zh" == strLang then
        requirePath = "lang.TrLangZh"
    elseif "ja" == strLang then
        requirePath = "lang.TrLangJa"
    elseif "de" == strLang then
        requirePath = "lang.TrLangDe"
    else
        requirePath = "lang.TrLangEn"
    end
    --卸载不用的语言列表，释放一些内存
    if nil~=Language.logLangFilePath and Language.logLangFilePath~=requirePath then
        package.preload[Language.logLangFilePath] = nil
        package.loaded[Language.logLangFilePath] = nil
    end
    ReloadWelderScriptLuaEnvironmentPath()
    Language.logLangFilePath = requirePath
    Language.logLangObject = require(requirePath)
end
--*****************************************************************

--[[
功能：设置语言
参数：strLang-语言字符串，只能是`EnumConstant.ConstEnumLanguage`的值
返回值：无
]]--
function Language.setLang(strLang)
    if type(strLang)~="string" then return end
    if not ConstEnumLanguage[strLang] then return end
    innerSetLangTab(strLang)
    innerSetLogLangObject(strLang)
    SetVal(keySelectedLangName,strLang)
end

--[[
功能：语言翻译
参数：strKey-要翻译的关键字
返回值：翻译后的内容
]]--
function Language.tr(strKey)
    if type(strKey)~="string" then return strKey end
    if nil == Language.selLangTab then
        local strLang = GetVal(keySelectedLangName)
        innerSetLangTab(strLang)
    end
    
    local val = Language.selLangTab[strKey]
    if nil == val then return strKey end
    return val
end

--功能等同`Language.tr`，只是这个是用来专门处理日志打印的翻译内容
function Language.trLang(strKey)
    if type(strKey)~="string" then return strKey end
    if nil == Language.logLangObject then
        local strLang = GetVal(keySelectedLangName)
        innerSetLogLangObject(strLang)
    end
    
    local val = Language.logLangObject[strKey]
    if nil == val then return strKey end
    return val
end
