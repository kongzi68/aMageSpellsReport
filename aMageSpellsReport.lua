local aMageSpellsReport, globFunc = ... -- 跨 lua 文件调用函数
globFunc.core = {}
local playerGUID = UnitGUID("player")
local playerName = UnitName("player")
local enemyGuidList = {}
local checkSpellName = "变形术"
local gIcon = nil
-- local MSR_DB = globFunc.variable.MSR_DB

-- 消息发送到设定的 channel
local function newSendChatMessage(msg)
    -- print(args);
    for key, value in pairs(MSR_DB.opt_channel) do
        if key == "opt_say" and value then
            -- 发送到队伍
            SendChatMessage(msg, "say")
        elseif key == "opt_party" and IsInGroup() and value then
            SendChatMessage(msg, "party")
        elseif key == "opt_yell" and value then
            -- 发送到团队
            SendChatMessage(msg, "yell")
        elseif key == "opt_raid" and IsInRaid() and value then
            SendChatMessage(msg, "raid")
        end
    end
end

-- 处理战斗日志信息，进行消息通报
local f = CreateFrame("Frame")
f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
-- f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
-- f:RegisterEvent("RAID_TARGET_UPDATE")
-- f:RegisterEvent("DUEL_FINISHED")
f:SetScript(
    "OnEvent",
    function(self, event)
        -- pass a variable number of arguments
        self:OnEvent(event, CombatLogGetCurrentEventInfo())
    end
)

function f:OnEvent(event, ...)
    -- if (event == "PLAYER_REGEN_ENABLED" or event == "DUEL_FINISHED") and MSR_DB.opt_mageManaWaring then
    if event == "PLAYER_REGEN_ENABLED" then
        -- 战斗结束后，重置变量
        enemyGuidList = {}
        gIcon = nil
        local isDead = UnitIsDead("player")
        -- Returns 1 if "unit" is dead, nil otherwise.
        if not isDead then
            --法力低于 15% 报警
            if MSR_DB.opt_mageManaWaring then
                self:mageManaWaringReport()
            end
            -- 战斗结束后，自动摧毁背包内的低价值物品
            if MSR_DB.opt_autoDeleteJunk then
                globFunc.core.deleteBagItem()
            end
        end
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local _, subevent, _, sourceGUID, sourceName, _, _, destGUID, destName, _, _, _, spellName = ...
        local sSpellName, dSpellName
        if subevent == "SPELL_AURA_APPLIED" or subevent == "SPELL_AURA_REFRESH" then
            -- print("test: " .. enemyGuidList[destGUID]["sourceGUID"])
            self:mageSpellPolymorph(subevent, sourceGUID, sourceName, destGUID, destName, spellName)
        elseif subevent == "SPELL_CAST_START" and sourceGUID == playerGUID and MSR_DB.opt_advanceMarker then
            if spellName == checkSpellName then
                -- 预读条标记目标
                gIcon = self:targetMark()
            end
        elseif subevent == "SPELL_CAST_SUCCESS" then
            if spellName == checkSpellName then
                -- 记录战斗开始后，日志中每个目标的 debuff-变形术 最后的施放者 GUID，用于破控提醒
                enemyGuidList[destGUID] = {["sourceGUID"] = sourceGUID}
                if sourceGUID == playerGUID then
                    enemyGuidList[destGUID]["icon"] = gIcon
                end
            end
        elseif subevent == "SPELL_AURA_BROKEN_SPELL" and MSR_DB.opt_spellAuraBroken then
            dSpellName, _, _, sSpellName = select(13, ...)
            self:mageSpellPolymorphBroken(sourceName, destGUID, destName, sSpellName, dSpellName)
        elseif subevent == "SPELL_INTERRUPT" then
            sSpellName, _, _, dSpellName = select(13, ...)
            self:spellInterruptEvent(sourceGUID, sourceName, destName, sSpellName, dSpellName)
        end
    end
end

-- 法师法术反制
function f:spellInterruptEvent(...)
    local MSG_INTERRUP1 = "%s→%s 打断了 >>> %s→%s!"
    local sourceGUID, sourceName, destName, sSpellName, dSpellName = ...
    if sourceGUID == playerGUID and destName ~= nil then
        -- SendChatMessage(MSG_INTERRUP1:format(sourceName, sSpellName, destName, dSpellName), "say");
        newSendChatMessage(MSG_INTERRUP1:format(sourceName, sSpellName, destName, dSpellName))
    end
end

-- 法师施放变形术消息
function f:mageSpellPolymorph(subevent, ...)
    local MSG_SPELLNAME1 = "%s→%s 对 >>> {rt%d}%s <<< 施放成功!"
    local MSG_SPELLNAME11 = "%s→%s 对 >>> %s <<< 施放成功!"
    local MSG_SPELLNAME2 = "%s→%s 对 >>> {rt%d}%s <<< 补羊成功!"
    local MSG_SPELLNAME22 = "%s→%s 对 >>> %s <<< 补羊成功!"
    local sourceGUID, sourceName, destGUID, destName, spellName = ...
    if sourceGUID == playerGUID and destName ~= nil and spellName == checkSpellName then
        -- 未开启预读条标记目标时执行
        if not MSR_DB.opt_advanceMarker then
            gIcon = self:targetMark()
            enemyGuidList[destGUID]["icon"] = gIcon
        end
        -- 发送消息
        if subevent == "SPELL_AURA_APPLIED" then
            -- print(MSG_SPELLNAME1:format(sourceName, destName, spellName));
            -- SendChatMessage(MSG_SPELLNAME1:format(sourceName, destName, spellName), "say");
            if gIcon then
                newSendChatMessage(MSG_SPELLNAME1:format(sourceName, spellName, gIcon, destName))
            else
                newSendChatMessage(MSG_SPELLNAME11:format(sourceName, spellName, destName))
            end
        elseif subevent == "SPELL_AURA_REFRESH" then
            if gIcon then
                newSendChatMessage(MSG_SPELLNAME2:format(sourceName, spellName, gIcon, destName))
            else
                newSendChatMessage(MSG_SPELLNAME22:format(sourceName, spellName, destName))
            end
        end
    end
end

-- 变形术破控
function f:mageSpellPolymorphBroken(...)
    local sourceName, destGUID, destName, sSpellName, dSpellName = ...
    local MSG_SPELLNAME1 = "%s→%s 破控 >>> {rt%d}%s <<< %s→%s!!!"
    local MSG_SPELLNAME11 = "%s→%s 破控 >>> %s <<< %s→%s!!!"
    local sourceGUID = enemyGuidList[destGUID]["sourceGUID"]
    local icon = enemyGuidList[destGUID]["icon"]
    if sourceGUID == playerGUID and dSpellName == checkSpellName then
        if icon then
            newSendChatMessage(MSG_SPELLNAME1:format(sourceName, sSpellName, icon, destName, playerName, dSpellName))
        else
            newSendChatMessage(MSG_SPELLNAME11:format(sourceName, sSpellName, destName, playerName, dSpellName))
        end
    end
end

-- 法力值低于 15% 发送消息
function f:mageManaWaringReport()
    local pType, powertype = UnitPowerType("player") --获取自身能量类型
    local power, maxpower = UnitPower("player", pType), UnitPowerMax("player", pType) --获取自身能量及最大能量
    if powertype == "MANA" then
        perh = power / maxpower * 100 + 0.5 --计算MP百分比
        -- print(perh);
        if perh <= 15 then
            newSendChatMessage("警告：法力值低于15%，需要恢复！！！")
        end
    end
end

-- 检查玩家是否具有标记权限
function f:raidMarkCanMark()
    if IsInRaid() then
        if UnitIsGroupLeader("player") or UnitIsGroupAssistant("player") then
            return true
        else
            return false
        end
    else
        return true
    end
end

-- 标记
function f:targetMark()
    --[[
        判断标记状态
        当目标被标记过（无论与自己设定的是否为相同标记），都不重复进行标记，且消息通报带该标记
        当目标未被标记过，标记目标，且消息通报带设定的标记
    ]]
    local icon = GetRaidTargetIndex("target")
    local isRaidMarkCanMark = self:raidMarkCanMark()
    local t_icon = MSR_DB.opt_marker
    if icon and icon ~= t_icon then
        t_icon = icon
    elseif icon == nil then
        if isRaidMarkCanMark then
            SetRaidTarget("target", t_icon)
        else
            t_icon = nil
        end
    end
    return t_icon
end

-- 转换金币显示
local function convertGoldValue(arg)
    local x, y, z, result
    x = math.floor(arg / 10000)
    y = math.floor((arg % 10000) / 100)
    z = math.floor(arg % 100)
    if x > 0 then
        result = string.format("%d金%d银%d铜", x, y, z)
    elseif x == 0 and y ~= 0 then
        result = string.format("%d银%d铜", y, z)
    elseif x == 0 and y == 0 then
        result = string.format("%d铜", z)
    end
    return result
end

-- 用条件限制被清理的物品
local function isEligibleItem(itemID)
    -- 限制条件：1、开启可摧毁功能，2、售卖NPC单价低于限制值，3、物品品质低于优秀
    local _, _, itemRarity, _, _, _, _, _, _, _, itemSellPrice = GetItemInfo(itemID)
    if MSR_DB.opt_deleteJunk and itemSellPrice <= MSR_DB.opt_itemDeletePrice then
        if itemRarity == 1 then
            local tempItemList = MSR_DB.opt_deleteItemList
            if tempItemList == {} then
                return false
            end
            local flags = false
            for _, value in pairs(tempItemList) do
                if value == itemID then
                    flags = true
                end
            end
            if flags then
                return true
            else
                return false
            end
        elseif itemRarity == 0 then
            return true
        else
            return false
        end
    else
        return false
    end
end

-- 获取背包内，可摧毁物品数据
local function getBagCanDeleteItem()
    local canDeleteItemArray = {}
    for bagID = 0, NUM_BAG_SLOTS do
        for slot = 1, GetContainerNumSlots(bagID) do
            local _, itemCount, _, _, _, _, itemLink, _, _, itemID = GetContainerItemInfo(bagID, slot)
            if itemID then
                local isCanDelete = isEligibleItem(itemID)
                if isCanDelete then
                    local arrayID = string.format("ID%d%d", bagID, slot)
                    local price = select(11, GetItemInfo(itemID))
                    canDeleteItemArray[arrayID] = {bagID, slot, itemCount, itemLink, price}
                end
            end
        end
    end
    return canDeleteItemArray
end

-- 摧毁符合条件的物品
local MSG_ITEMINFO = "摧毁物品：%s, 数量：%d, 价值: %s"
local function deleteBagItem()
    local allValue, oneValue = 0
    local canDeleteItemArray = getBagCanDeleteItem()
    if next(canDeleteItemArray) ~= nil then
        print("当前被摧毁物品的最高价值限制为：" .. convertGoldValue(MSR_DB.opt_itemDeletePrice))
        print("开始摧毁低价值物品！")
        for _, value in pairs(canDeleteItemArray) do
            local bagID, slot, itemCount, itemLink, price = unpack(value)
            local locked, quality = select(3, GetContainerItemInfo(bagID, slot))
            -- 再次验证物品等级与价格
            if not locked and quality <= 1 and price <= MSR_DB.opt_itemDeletePrice then
                PickupContainerItem(bagID, slot)
                DeleteCursorItem()
                -- ClearCursor()
                oneValue = price * itemCount
                allValue = allValue + oneValue
                print(MSG_ITEMINFO:format(itemLink, itemCount, convertGoldValue(oneValue)))
            end
        end
        print("摧毁低价值物品结束...")
        print("本次摧毁低价值物品的总价值: " .. convertGoldValue(allValue))
    else
        if not MSR_DB.opt_autoDeleteJunk then
            print("没有需要被摧毁的垃圾物品！")
        end
    end
end

-- 用于跨 lua 调用 deleteBagItem 函数
globFunc.core.deleteBagItem = deleteBagItem
globFunc.core.convertGoldValue = convertGoldValue
