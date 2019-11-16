local aMageSpellsReport, globFunc = ...
globFunc.variable = {}

local Defaults = {
    opt_channel = {
        opt_say = true,
        opt_yell = false,
        opt_party = false,
        opt_raid = false
    },
    opt_marker = 1,
    opt_itemDeletePrice = 5,
    opt_spellAuraBroken = false,
    opt_mageManaWaring = false,
    opt_advanceMarker = false,
    opt_deleteJunk = false,
    opt_autoDeleteJunk = false,
    opt_deleteItemList = {}
}

local optMarkerEnum = {
    [0] = "取消图标",
    [1] = "星星",
    [2] = "大饼",
    [3] = "菱形",
    [4] = "倒三角",
    [5] = "月亮",
    [6] = "方块",
    [7] = "叉X",
    [8] = "骷髅"
}

-- This function will make sure your saved table contains all the same
-- keys as your table, and that each key's value is of the same type
-- as the value of the same key in the default table.
local function CopyDefaults(src, dst)
    if type(src) ~= "table" then
        return {}
    end
    if type(dst) ~= "table" then
        dst = {}
    end
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = CopyDefaults(v, dst[k])
        elseif type(v) ~= type(dst[k]) then
            dst[k] = v
        end
    end
    return dst
end

local msrLoadFrame = CreateFrame("Frame")
msrLoadFrame:RegisterEvent("ADDON_LOADED")
msrLoadFrame:SetScript(
    "OnEvent",
    function(self, event, arg1)
        if event == "ADDON_LOADED" and arg1 == "aMageSpellsReport" then
            -- Call the function to update your saved table:
            MSR_DB = CopyDefaults(Defaults, MSR_DB)
            -- print(MSR_DB.opt_channel.opt_say)
            -- print("test: " .. MSR_DB.opt_itemDeletePrice)
            -- Unregister this event, since there is no further use for it:
            self:UnregisterEvent("ADDON_LOADED")
        -- globFunc.variable.MSR_DB = MSR_DB
        end
    end
)

globFunc.variable.optMarkerEnum = optMarkerEnum
globFunc.variable.Defaults = Defaults