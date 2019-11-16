local aMageSpellsReport, globFunc = ... -- 跨 lua 文件调用函数
local sellPriceValue = 500 -- 设置摧毁灰色物品价值最大值为：500铜
local tempItemListText = nil
local optMarkerEnum = globFunc.variable.optMarkerEnum
local Defaults = globFunc.variable.Defaults
-- local MSR_DB = globFunc.variable.MSR_DB
local function tooltipOfPanel_OnEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
    GameTooltip:SetText(self.Name)
    GameTooltip:AddLine(self.Description, 1, 1, 1)
    GameTooltip:Show()
end

--[[
    常用函数
]]
-- 处理输入的字符串
local function stringSplit(input)
    --[[
    // 用指定字符或字符串分割输入字符串，返回包含分割结果的数组
    // @function [parent=#string] split
    // @param string input 输入字符串
    // @param string delimiter 分割标记字符或字符串
    // @return array#array  包含分割结果的数组

    /*
    用指定字符或字符串分割输入字符串，返回包含分割结果的数组
    local input = "Hello,World"
    local res = string.split(input, ",")
    -- res = {"Hello", "World"}
    local input = "Hello-+-World-+-Quick"
    local res = string.split(input, "-+-")
    -- res = {"Hello", "World", "Quick"}
    */
    ]]
    input = tostring(string.gsub(input, "[，;；.]+", ","))
    -- print(input)
    local delimiter = tostring(",")
    local pos, arr = 0, {}
    -- for each divider found
    for st, sp in function()
        return string.find(input, delimiter, pos, true)
    end do
        table.insert(arr, string.sub(input, pos, st - 1))
        pos = sp + 1
    end
    table.insert(arr, string.sub(input, pos))
    return arr
end

-- table数组合并
local function tableMerge(tabA, tabB)
    local result = {}
    local flag
    for _, v in pairs(tabA) do
        flag = false
        for _, value in pairs(result) do
            if value == v then
                flag = true
            end
        end
        if flag == false then
            table.insert(result, v)
        end
    end
    for _, v in pairs(tabB) do
        flag = false
        for _, value in pairs(result) do
            if value == v then
                flag = true
            end
        end
        if flag == false then
            table.insert(result, v)
        end
    end
    -- table.sort(
    --     result,
    --     function(a, b)
    --         return a < b
    --     end
    -- )
    return result
end

-- table数组元素清理
local function tableDelete(tabA, tabB)
    --[[
        tabA是大table，tabB是小table
        遍历tabA，如果该元素在tabB中，就不把该元素插入 result 中
    ]]
    local result = {}
    local flag
    for _, v in pairs(tabA) do
        flag = false
        for _, value in pairs(tabB) do
            if value == v then
                flag = true
            end
        end
        if flag == false then
            table.insert(result, v)
        end
    end
    return result
end

-- table数组转成去括号的字符串
local function tableToString(tableName)
    local retstr = ""
    if next(tableName) == nil then
        return retstr
    end
    if type(tableName) == "table" then
        for key, value in pairs(tableName) do
            local signal = ","
            if key == 1 then
                signal = ""
            end
            retstr = retstr .. signal .. value
        end
    end
    return retstr
end

-- 通过名称字符串或ID，获取物品的ID，物品链接等信息
local function getItemInfoByName(...)
    -- str, 字符串
    -- convertGold，布尔类型
    local str, convertGold = ...
    local toConvertGold = convertGold or false
    local result = {}
    local itemID = select(1, GetItemInfoInstant(str))
    -- print("getItemInfoByName：".. itemID)
    if itemID then
        local itemName, itemLink, itemRarity, _, _, _, _, _, _, _, itemSellPrice = GetItemInfo(itemID)
        -- print("getItemInfoByName：".. itemLink)
        if toConvertGold then
            itemSellPrice = globFunc.core.convertGoldValue(itemSellPrice)
        end
        result = {itemID, itemName, itemLink, itemRarity, itemSellPrice}
    end
    return result
end

-- 处理物品ID数组
local function itemIDArrayToStr(tabName)
    local showText = ""
    if next(tabName) ~= nil then
        for key, value in pairs(tabName) do
            local signal = ";"
            if key == 1 then
                signal = ""
            end
            local itemResult = getItemInfoByName(value, true)
            if itemResult then
                showText = showText .. signal .. tableToString(itemResult)
            end
        end
    end
    return showText
end

-- 清理输入的字符串
-- 添加需要被限制，物品品质，售卖价格等限制
-- 删除物品函数需要重构与拆分
local function itemInputTextToItemIDArray(str)
    local Unqualified, qualifiedItemIDArray = {}, {}
    local tempItemInput = stringSplit(str)
    for _, value in pairs(tempItemInput) do
        -- print(value)
        local itemResult = getItemInfoByName(value)
        if itemResult then
            local itemID, _, itemLink, itemRarity, itemSellPrice = unpack(itemResult)
            -- 物品品质低于优秀，售卖NPC单价低于 500 铜
            if itemRarity <= 1 and itemSellPrice <= sellPriceValue then
                table.insert(qualifiedItemIDArray, itemID)
            else
                table.insert(Unqualified, itemLink)
            end
        end
    end
    return Unqualified, qualifiedItemIDArray
end

--[[
    。。。。。。。。。。。
]]
local fScrollEdit
local MSRAddon = {}
local pFrame = MSRAddon.panel
pFrame = CreateFrame("Frame", "MSRAddonPanel", UIParent)
pFrame.name = "aMageSpellsReport"
pFrame:Hide()
pFrame:SetScript(
    "OnShow",
    function(pFrame)
        local title = pFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -12)
        title:SetText(GetAddOnMetadata(pFrame.name, "Title") .. " v" .. GetAddOnMetadata(pFrame.name, "Version"))

        local introduce = pFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        introduce:SetPoint("TOP", title, "BOTTOM", 0, -8)
        introduce:SetText("用于设置消息发送频道，标记类型等")

        --[[
            消息发送频道
        ]]
        local checkButtonTitle = pFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        checkButtonTitle:SetPoint("TOPLEFT", 10, -72)
        checkButtonTitle:SetText("选择发送消息的频道（可单选或多选，进行任意搭配）：")

        local optSayCheckButton =
            CreateFrame("CheckButton", "optSayCheckButton_GlobalName", pFrame, "ChatConfigSmallCheckButtonTemplate")
        optSayCheckButton:SetPoint("BOTTOMLEFT", checkButtonTitle, 50, -30)
        _G[optSayCheckButton:GetName() .. "Text"]:SetText("说")
        optSayCheckButton.tooltip = "把消息发送到：say \n类似命令：/s 消息内容"
        optSayCheckButton:SetScript(
            "OnClick",
            function(self, value)
                local isChecked = optSayCheckButton:GetChecked()
                if isChecked then
                    MSR_DB.opt_channel.opt_say = true
                else
                    MSR_DB.opt_channel.opt_say = false
                end
            end
        )

        local optYellCheckButton =
            CreateFrame("CheckButton", "optYellCheckButton_GlobalName", pFrame, "ChatConfigSmallCheckButtonTemplate")
        optYellCheckButton:SetPoint("RIGHT", optSayCheckButton, 100, 0)
        _G[optYellCheckButton:GetName() .. "Text"]:SetText("吼")
        optYellCheckButton.tooltip = "把消息发送到：吼 \n类似命令：/y 消息内容"
        optYellCheckButton:SetScript(
            "OnClick",
            function(self, value)
                local isChecked = optYellCheckButton:GetChecked()
                if isChecked then
                    MSR_DB.opt_channel.opt_yell = true
                else
                    MSR_DB.opt_channel.opt_yell = false
                end
            end
        )

        local optPartyCheckButton =
            CreateFrame("CheckButton", "optPartyCheckButton_GlobalName", pFrame, "ChatConfigSmallCheckButtonTemplate")
        optPartyCheckButton:SetPoint("RIGHT", optSayCheckButton, 200, 0)
        _G[optPartyCheckButton:GetName() .. "Text"]:SetText("队伍")
        optPartyCheckButton.tooltip = "把消息发送到：队伍 \n类似命令：/p 消息内容"
        optPartyCheckButton:SetScript(
            "OnClick",
            function(self, value)
                local isChecked = optPartyCheckButton:GetChecked()
                if isChecked then
                    MSR_DB.opt_channel.opt_party = true
                else
                    MSR_DB.opt_channel.opt_party = false
                end
            end
        )

        local optRaidCheckButton =
            CreateFrame("CheckButton", "optRaidCheckButton_GlobalName", pFrame, "ChatConfigSmallCheckButtonTemplate")
        optRaidCheckButton:SetPoint("RIGHT", optSayCheckButton, 300, 0)
        _G[optRaidCheckButton:GetName() .. "Text"]:SetText("团队")
        optRaidCheckButton.tooltip = "把消息发送到：raid \n类似命令：/团队 消息内容"
        optRaidCheckButton:SetScript(
            "OnClick",
            function(self, value)
                local isChecked = optRaidCheckButton:GetChecked()
                if isChecked then
                    MSR_DB.opt_channel.opt_raid = true
                else
                    MSR_DB.opt_channel.opt_raid = false
                end
            end
        )

        --[[
            标记类型
        ]]
        local dropDownTitle = pFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        dropDownTitle:SetPoint("TOPLEFT", 10, -130)
        dropDownTitle:SetText("选择标记类型：")

        local selectedValue = optMarkerEnum[MSR_DB.opt_marker]
        local valueTable = optMarkerEnum
        local optMarkerDropDown = CreateFrame("Frame", "WPDemoDropDown", pFrame, "UIDropDownMenuTemplate")
        -- optMarkerDropDown:SetPoint("LEFT", dropDownTitle, 110, 0);
        optMarkerDropDown:SetPoint("LEFT", dropDownTitle, dropDownTitle:GetStringWidth(), 0)
        UIDropDownMenu_SetWidth(optMarkerDropDown, 125)
        UIDropDownMenu_SetText(optMarkerDropDown, selectedValue)
        UIDropDownMenu_Initialize(
            optMarkerDropDown,
            function(self, level, menuList)
                local info = UIDropDownMenu_CreateInfo()
                info.func = self.SetValue
                for k, v in pairs(valueTable) do
                    info.text, info.arg1 = v, k
                    info.checked = selectedValue == v
                    UIDropDownMenu_AddButton(info)
                end
            end
        )

        function optMarkerDropDown:SetValue(key)
            selectedValue = valueTable[key]
            UIDropDownMenu_SetText(optMarkerDropDown, selectedValue)
            CloseDropDownMenus()
            -- print(selectedValue .. " : " .. key);
            MSR_DB.opt_marker = key
        end

        --[[
            其它杂项
        ]]
        local otherCheckButtonTitle = pFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        otherCheckButtonTitle:SetPoint("TOPLEFT", 10, -150)
        otherCheckButtonTitle:SetText("设置其它杂项：")

        local optSpellAuraBrokenCheckButton =
            CreateFrame(
            "CheckButton",
            "optSpellAuraBrokenCheckButton_GlobalName",
            pFrame,
            "ChatConfigSmallCheckButtonTemplate"
        )
        optSpellAuraBrokenCheckButton:SetPoint("BOTTOMLEFT", otherCheckButtonTitle, 50, -24)
        _G[optSpellAuraBrokenCheckButton:GetName() .. "Text"]:SetText("破控消息推送")
        optSpellAuraBrokenCheckButton.tooltip = "若勾选，羊的怪被打醒了，将发送消息"
        optSpellAuraBrokenCheckButton:SetScript(
            "OnClick",
            function(self, value)
                local isChecked = optSpellAuraBrokenCheckButton:GetChecked()
                if isChecked then
                    MSR_DB.opt_spellAuraBroken = true
                else
                    MSR_DB.opt_spellAuraBroken = false
                end
            end
        )

        local optCheckButton1 =
            CreateFrame("CheckButton", "optCheckButton1_GlobalName", pFrame, "ChatConfigSmallCheckButtonTemplate")
        optCheckButton1:SetPoint("BOTTOMLEFT", otherCheckButtonTitle, 50, -48)
        _G[optCheckButton1:GetName() .. "Text"]:SetText("法力值低于 15% 消息提醒")
        optCheckButton1.tooltip = "若勾选，脱离战斗后，当自己的法力值低于 15% 时，进行消息推送。"
        optCheckButton1:SetScript(
            "OnClick",
            function(self, value)
                local isChecked = optCheckButton1:GetChecked()
                if isChecked then
                    MSR_DB.opt_mageManaWaring = true
                else
                    MSR_DB.opt_mageManaWaring = false
                end
            end
        )

        local optCheckButton2 =
            CreateFrame("CheckButton", "optCheckButton2_GlobalName", pFrame, "ChatConfigSmallCheckButtonTemplate")
        optCheckButton2:SetPoint("BOTTOMLEFT", otherCheckButtonTitle, 50, -72)
        _G[optCheckButton2:GetName() .. "Text"]:SetText("开启变形术预读条时标记目标***")
        optCheckButton2.tooltip = "若勾选：会标记正在被玩家进行预读条的目标，适合高玩！未勾选时：读条结束，且目标被变形成功之后才会进行标记。"
        optCheckButton2:SetScript(
            "OnClick",
            function(self, value)
                local isChecked = optCheckButton2:GetChecked()
                if isChecked then
                    MSR_DB.opt_advanceMarker = true
                else
                    MSR_DB.opt_advanceMarker = false
                end
            end
        )

        -- 是否开启摧毁灰色物品
        local optCheckButton3 =
            CreateFrame("CheckButton", "optCheckButton3_GlobalName", pFrame, "ChatConfigSmallCheckButtonTemplate")
        optCheckButton3:SetPoint("BOTTOMLEFT", otherCheckButtonTitle, 50, -96)
        _G[optCheckButton3:GetName() .. "Text"]:SetText("摧毁背包内的灰色物品")
        optCheckButton3.tooltip = "若勾选：将允许摧毁背包内的灰色物品"
        optCheckButton3:SetScript(
            "OnClick",
            function()
                local isChecked = optCheckButton3:GetChecked()
                if isChecked then
                    MSR_DB.opt_deleteJunk = true
                else
                    MSR_DB.opt_deleteJunk = false
                end
            end
        )

        --[[
            清理低价值灰色物品
        ]]
        local itemDelPriceButtonTitle = pFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        itemDelPriceButtonTitle:SetPoint("TOPLEFT", 10, -270)
        itemDelPriceButtonTitle:SetText("设置被清理的物品售卖NPC价格最大值(单位：铜)：")

        -- 输入框
        local itemDeleteEditBox = CreateFrame("EditBox", nil, pFrame, "InputBoxTemplate")
        local itemDeleteEditBoxXPoint = 10
        itemDeleteEditBox:SetPoint("BOTTOMLEFT", itemDelPriceButtonTitle, itemDeleteEditBoxXPoint, -30)
        itemDeleteEditBox:SetSize(120, 24)
        itemDeleteEditBox:SetMultiLine(false)
        itemDeleteEditBox:SetAutoFocus(false) -- dont automatically focus
        itemDeleteEditBox:SetFontObject("GameFontWhite")
        itemDeleteEditBox:SetJustifyH("CENTER")
        itemDeleteEditBox:SetNumeric()
        itemDeleteEditBox:SetNumber(MSR_DB.opt_itemDeletePrice)
        itemDeleteEditBox.Name = "注意事项："
        itemDeleteEditBox.Description = "可设置的最大值为 500，即 5 银币!\n当输入无效值时，会自动设置为0；\n点击重置按钮，会设置为5铜。"
        itemDeleteEditBox:SetScript("OnEnter", tooltipOfPanel_OnEnter)
        itemDeleteEditBox:SetScript("OnLeave", GameTooltip_Hide)
        itemDeleteEditBox:SetScript(
            "OnTextChanged",
            function()
                local sellPrice = itemDeleteEditBox:GetNumber()
                if sellPrice >= sellPriceValue or sellPrice < 0 then
                    message("警告：你设置的物品单价无效，请重新设置！")
                    itemDeleteEditBox:SetNumber(Defaults.opt_itemDeletePrice)
                    itemDeleteEditBox:SetAutoFocus()
                else
                    MSR_DB.opt_itemDeletePrice = sellPrice
                end
            end
        )

        -- 输入框的应用按钮
        local itemDeletePriceOkButton =
            CreateFrame("Button", "itemDeletePriceOkButton_GlobalName", pFrame, "UIPanelButtonTemplate")
        local itemDeletePriceOkButtonXPoint = itemDeleteEditBoxXPoint + 120
        itemDeletePriceOkButton:SetPoint("LEFT", itemDeleteEditBox, itemDeletePriceOkButtonXPoint, 0)
        itemDeletePriceOkButton:SetSize(50, 24) -- width, height
        itemDeletePriceOkButton:SetText("应用")
        itemDeletePriceOkButton:SetScript(
            "OnClick",
            function()
                itemDeleteEditBox:SetNumber(MSR_DB.opt_itemDeletePrice)
                SendChatMessage(
                    "限制需要被摧毁的物品售卖NPC最大价格值为：" .. globFunc.core.convertGoldValue(MSR_DB.opt_itemDeletePrice),
                    "say"
                )
            end
        )

        -- 输入框的重置按钮
        local itemDeletePriceCancelButton =
            CreateFrame("Button", "itemDeletePriceCancelButton_GlobalName", pFrame, "UIPanelButtonTemplate")
        itemDeletePriceCancelButton:SetPoint("LEFT", itemDeleteEditBox, itemDeletePriceOkButtonXPoint + 60, 0)
        itemDeletePriceCancelButton:SetSize(50, 24) -- width, height
        itemDeletePriceCancelButton:SetText("重置")
        itemDeletePriceCancelButton:SetScript(
            "OnClick",
            function()
                itemDeleteEditBox:SetNumber(Defaults.opt_itemDeletePrice)
                SendChatMessage("已经重置限制值为默认值：" .. globFunc.core.convertGoldValue(Defaults.opt_itemDeletePrice), "say")
            end
        )

        -- 清理低价值灰色物品
        local lowPriceItemDeleteButton =
            CreateFrame("Button", "lowPriceItemDeleteButton_GlobalName", pFrame, "UIPanelButtonTemplate")
        lowPriceItemDeleteButton:SetPoint("LEFT", itemDeleteEditBox, itemDeletePriceOkButtonXPoint + 120, 0)
        lowPriceItemDeleteButton:SetSize(100, 24) -- width, height
        lowPriceItemDeleteButton:SetText("手动清理")
        lowPriceItemDeleteButton:SetScript(
            "OnClick",
            function()
                if MSR_DB.opt_deleteJunk then
                    globFunc.core.deleteBagItem() -- 跨 lua 文件调用函数
                else
                    message("未开启摧毁低价值物品功能!")
                end
            end
        )

        -- 开启是否自动摧毁低价值物品
        local optCheckButton4 =
            CreateFrame("CheckButton", "optCheckButton4_GlobalName", pFrame, "ChatConfigSmallCheckButtonTemplate")
        optCheckButton4:SetPoint("LEFT", itemDeleteEditBox, itemDeletePriceOkButtonXPoint + 120 + 110, 0)
        _G[optCheckButton4:GetName() .. "Text"]:SetText("自动摧毁开关")
        optCheckButton4.tooltip = "若勾选：将自动摧毁背包内的低价值物品"
        optCheckButton4:SetScript(
            "OnClick",
            function()
                local isChecked = optCheckButton4:GetChecked()
                if isChecked then
                    MSR_DB.opt_autoDeleteJunk = true
                else
                    MSR_DB.opt_autoDeleteJunk = false
                end
            end
        )

        local Refresh
        function Refresh()
            if not pFrame:IsVisible() then
                return
            end
            optSayCheckButton:SetChecked(MSR_DB.opt_channel.opt_say)
            optYellCheckButton:SetChecked(MSR_DB.opt_channel.opt_yell)
            optPartyCheckButton:SetChecked(MSR_DB.opt_channel.opt_party)
            optRaidCheckButton:SetChecked(MSR_DB.opt_channel.opt_raid)
            optSpellAuraBrokenCheckButton:SetChecked(MSR_DB.opt_spellAuraBroken)
            optCheckButton1:SetChecked(MSR_DB.opt_mageManaWaring)
            optCheckButton2:SetChecked(MSR_DB.opt_advanceMarker)
            optCheckButton3:SetChecked(MSR_DB.opt_deleteJunk)
            optCheckButton4:SetChecked(MSR_DB.opt_autoDeleteJunk)
            itemDeleteEditBox:SetNumber(MSR_DB.opt_itemDeletePrice)
            fScrollEdit.Text:SetText(itemIDArrayToStr(MSR_DB.opt_deleteItemList))
        end
        pFrame:SetScript("OnShow", Refresh)
        Refresh()
    end
)

-- 需要摧毁的白色物品清单

local backdrop = {
    bgFile = "Interface/BUTTONS/WHITE8X8",
    edgeFile = "Interface/GLUES/Common/Glue-Tooltip-Border",
    tile = true,
    edgeSize = 8,
    tileSize = 8,
    insets = {
        left = 3,
        right = 3,
        top = 3,
        bottom = 3
    }
}

local itemDelPriceButtonTitle2 = pFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
itemDelPriceButtonTitle2:SetPoint("TOPLEFT", 10, -325)
itemDelPriceButtonTitle2:SetText("将需要被摧毁的物品ID添加到下面的清单中：")
-- 输入框
local itemDeleteEditBox2 = CreateFrame("EditBox", nil, pFrame, "InputBoxTemplate")
local itemDeleteEditBoxXPoint2 = 10
itemDeleteEditBox2:SetPoint("BOTTOMLEFT", itemDelPriceButtonTitle2, itemDeleteEditBoxXPoint2, -30)
itemDeleteEditBox2:SetSize(120, 24)
itemDeleteEditBox2:SetMultiLine(false)
itemDeleteEditBox2:SetAutoFocus(false) -- dont automatically focus
itemDeleteEditBox2:SetFontObject("GameFontWhite")
itemDeleteEditBox2.Name = "注意事项："
itemDeleteEditBox2.Description = "可输入物品ID或名称，用逗号分隔"
itemDeleteEditBox2:SetScript("OnEnter", tooltipOfPanel_OnEnter)
itemDeleteEditBox2:SetScript("OnLeave", GameTooltip_Hide)
itemDeleteEditBox2:SetScript(
    "OnTextChanged",
    function()
        local box2Text = itemDeleteEditBox2:GetText()
        if box2Text then
            tempItemListText = box2Text
        end
    end
)

fScrollEdit = CreateFrame("Frame", "MyScrollMessageTextFrame", pFrame)
fScrollEdit:SetSize(300, 150)
fScrollEdit:SetPoint("BOTTOMLEFT", itemDelPriceButtonTitle2, 0, -185)
fScrollEdit:SetFrameStrata("BACKGROUND")
fScrollEdit:SetBackdrop(backdrop)
fScrollEdit:SetBackdropColor(0, 0, 0)
fScrollEdit.SF = CreateFrame("ScrollFrame", "$parent_DF", fScrollEdit, "UIPanelScrollFrameTemplate")
fScrollEdit.SF:SetPoint("TOPLEFT", fScrollEdit, 12, -8)
fScrollEdit.SF:SetPoint("BOTTOMRIGHT", fScrollEdit, -28, 10)
fScrollEdit.Text = CreateFrame("EditBox", nil, fScrollEdit)
fScrollEdit.Text:SetMultiLine(true)
fScrollEdit.Text:SetSize(265, 200)
fScrollEdit.Text:SetPoint("TOPLEFT", fScrollEdit.SF)
fScrollEdit.Text:SetPoint("BOTTOMRIGHT", fScrollEdit.SF)
fScrollEdit.Text:SetMaxLetters(1999)
fScrollEdit.Text:SetFontObject("GameFontWhite")
fScrollEdit.Text:SetAutoFocus(false)
-- fScrollEdit.Text:EnableKeyboard(false)
-- fScrollEdit.Text:EnableMouse(false)
fScrollEdit.Text:SetScript(
    "OnEscapePressed",
    function(self)
        self:ClearFocus()
    end
)
fScrollEdit.SF:SetScrollChild(fScrollEdit.Text)
-- fScrollEdit.Text:SetText(itemIDArrayToStr(MSR_DB.opt_deleteItemList))
fScrollEdit.Text:SetText("")

-- 输入框的查询按钮
local itemIDQueryButton2 = CreateFrame("Button", "itemIDQueryButton2_GlobalName", pFrame, "UIPanelButtonTemplate")
local itemDeletePriceOkButtonXPoint2 = itemDeleteEditBoxXPoint2 + 120
itemIDQueryButton2:SetPoint("LEFT", itemDeleteEditBox2, itemDeletePriceOkButtonXPoint2, 0)
itemIDQueryButton2:SetSize(110, 24) -- width, height
itemIDQueryButton2:SetText("查询物品ID")
itemIDQueryButton2.Name = "查询功能提示："
itemIDQueryButton2.Description =
    "输入需要被查询物品的名称，查询物品ID，然后点击添加即可；\n注意：每次只能查询一个名称！\n另经过验证，API GetItemInfoInstant 只能查询背包与银行内已有物品的ID。"
itemIDQueryButton2:SetScript("OnEnter", tooltipOfPanel_OnEnter)
itemIDQueryButton2:SetScript("OnLeave", GameTooltip_Hide)
itemIDQueryButton2:SetScript(
    "OnClick",
    function()
        -- print(tempItemListText)
        itemID = select(1, GetItemInfoInstant(tempItemListText))
        if itemID then
            local _, itemName, itemLink, _, _ = unpack(getItemInfoByName(itemID))
            -- print(itemName, itemLink)
            SendChatMessage(string.format("查询：%s，链接：%s，物品ID：%d", itemName, itemLink, itemID), "say")
            itemDeleteEditBox2:SetText(itemID)
        else
            message(string.format("未查询到“%s”的物品ID", tempItemListText))
            itemDeleteEditBox2:SetAutoFocus()
        end
    end
)

-- 输入框的添加按钮
local itemDeletePriceOkButton2 =
    CreateFrame("Button", "itemDeletePriceOkButton2_GlobalName", pFrame, "UIPanelButtonTemplate")
itemDeletePriceOkButton2:SetPoint("LEFT", itemDeleteEditBox2, itemDeletePriceOkButtonXPoint2 + 120, 0)
itemDeletePriceOkButton2:SetSize(50, 24) -- width, height
itemDeletePriceOkButton2:SetText("添加")
itemDeletePriceOkButton2.Name = "添加功能提示："
itemDeletePriceOkButton2.Description = "灰色物品会自动摧毁，不需要添加；\n这里要添加的是除了灰色物品以外的低价值物品！\n售卖NPC单价高于 5 银的不符合添加条件!"
itemDeletePriceOkButton2:SetScript("OnEnter", tooltipOfPanel_OnEnter)
itemDeletePriceOkButton2:SetScript("OnLeave", GameTooltip_Hide)
itemDeletePriceOkButton2:SetScript(
    "OnClick",
    function()
        local unqualifiedItem, ItemIDArray = itemInputTextToItemIDArray(tempItemListText)
        if MSR_DB.opt_deleteItemList then
            local tempMergeArrayOk = tableMerge(ItemIDArray, MSR_DB.opt_deleteItemList)
            MSR_DB.opt_deleteItemList = tempMergeArrayOk
        else
            MSR_DB.opt_deleteItemList = ItemIDArray
        end
        fScrollEdit.Text:SetText(itemIDArrayToStr(MSR_DB.opt_deleteItemList))
        itemDeleteEditBox2:SetText("") --重置为空
        local msgUnqualifiedItem = tableToString(unqualifiedItem)
        if msgUnqualifiedItem ~= "" then
            SendChatMessage(string.format("以下物品不符合被添加到摧毁清单的条件：%s", msgUnqualifiedItem), "say")
        end
    end
)

-- 输入框的删除按钮
local itemDeletePriceCancelButton2 =
    CreateFrame("Button", "itemDeletePriceCancelButton2_GlobalName", pFrame, "UIPanelButtonTemplate")
itemDeletePriceCancelButton2:SetPoint("LEFT", itemDeleteEditBox2, itemDeletePriceOkButtonXPoint2 + 120 + 60, 0)
itemDeletePriceCancelButton2:SetSize(50, 24) -- width, height
itemDeletePriceCancelButton2:SetText("删除")
itemDeletePriceCancelButton2.Name = "删除功能提示："
itemDeletePriceCancelButton2.Description = "在输入框中填入需要被删除的物品ID，然后点击“删除”按钮即可"
itemDeletePriceCancelButton2:SetScript("OnEnter", tooltipOfPanel_OnEnter)
itemDeletePriceCancelButton2:SetScript("OnLeave", GameTooltip_Hide)
itemDeletePriceCancelButton2:SetScript(
    "OnClick",
    function()
        local _, ItemIDArray = itemInputTextToItemIDArray(tempItemListText)
        local tempNewItemListArray = tableDelete(MSR_DB.opt_deleteItemList, ItemIDArray)
        MSR_DB.opt_deleteItemList = tempNewItemListArray
        fScrollEdit.Text:SetText(itemIDArrayToStr(MSR_DB.opt_deleteItemList))
        itemDeleteEditBox2:SetText("") --重置为空
    end
)

InterfaceOptions_AddCategory(pFrame)
