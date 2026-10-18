local addonName, addonTable = ...

-------------------------------------------------------------------------------
-- 1. DATA TRACKING & SAVED VARIABLES
-------------------------------------------------------------------------------
local sessionStartTime = (type(GetTime) == "function") and GetTime() or 0

local function GetPlayerKey()
    if type(UnitName) ~= "function" or type(GetRealmName) ~= "function" then return nil end
    local name = UnitName("player")
    local realm = GetRealmName()
    if name and realm and name ~= "" and realm ~= "" then
        return name .. "-" .. realm
    end
    return nil
end

local function InitDB()
    if not K1StatFrameDB then K1StatFrameDB = {} end
    if not K1StatFrameDB.chars then K1StatFrameDB.chars = {} end
    if not K1StatFrameDB.minimap then K1StatFrameDB.minimap = { hide = false, angle = 220 } end
    if not K1StatFrameDB.sortKey then K1StatFrameDB.sortKey = "level" end
    if K1StatFrameDB.sortAsc == nil then K1StatFrameDB.sortAsc = false end
end

-- Helper: Calculate fallback item level manually if GetAverageItemLevel returns 0
local function GetCalculatedItemLevel()
    local avgItemLevel, avgItemLevelEquipped = 0, 0
    if type(GetAverageItemLevel) == "function" then
        pcall(function()
            avgItemLevel, avgItemLevelEquipped = GetAverageItemLevel()
        end)
    end

    if avgItemLevelEquipped and avgItemLevelEquipped > 0 then
        return math.floor(avgItemLevelEquipped)
    end

    -- Fallback: Scan equipped inventory slots (1-17 excluding tabard/shirt)
    local totalLevel, itemCount = 0, 0
    if type(GetInventoryItemLink) == "function" and type(GetDetailedItemLevelInfo) == "function" then
        for slot = 1, 17 do
            if slot ~= 4 and slot ~= 19 then -- Ignore Shirt & Tabard
                local link = GetInventoryItemLink("player", slot)
                if link then
                    local effectiveLevel = GetDetailedItemLevelInfo(link)
                    if effectiveLevel and effectiveLevel > 0 then
                        totalLevel = totalLevel + effectiveLevel
                        itemCount = itemCount + 1
                    end
                end
            end
        end
    end

    if itemCount > 0 then
        return math.floor(totalLevel / itemCount)
    end

    return 0
end

local function SaveCurrentCharacterData()
    InitDB()
    local pKey = GetPlayerKey()
    if not pKey then return end

    if not K1StatFrameDB.chars[pKey] then
        K1StatFrameDB.chars[pKey] = { playedTotal = 0, ilvl = 0, gold = 0 }
    end

    local char = K1StatFrameDB.chars[pKey]
    char.name = (type(UnitName) == "function") and UnitName("player") or "Unknown"
    char.realm = (type(GetRealmName) == "function") and GetRealmName() or ""
    char.level = (type(UnitLevel) == "function") and UnitLevel("player") or 1
    char.class = (type(UnitClass) == "function") and select(2, UnitClass("player")) or "WARRIOR"
    char.className = (type(UnitClass) == "function") and UnitClass("player") or "Warrior"
    char.lastSeen = time()

    -- Only overwrite Gold if a valid amount > 0 is returned or if no gold is recorded yet
    local currentGold = (type(GetMoney) == "function") and GetMoney() or 0
    if currentGold > 0 or not char.gold then
        char.gold = currentGold
    end

    -- Only overwrite iLvl if valid > 0 value is parsed or if no iLvl is recorded yet
    local currentIlvl = GetCalculatedItemLevel()
    if currentIlvl > 0 or not char.ilvl then
        char.ilvl = currentIlvl
    end
end

local function GetCurrentPlayTime(char, isCurrentChar)
    if not char then return 0 end
    local basePlayed = char.playedTotal or 0
    if isCurrentChar then
        local currentTime = (type(GetTime) == "function") and GetTime() or sessionStartTime
        local sessionPlayed = math.floor(currentTime - sessionStartTime)
        return basePlayed + sessionPlayed
    end
    return basePlayed
end

local function FormatGold(amount)
    if not amount or amount == 0 then return "0g" end
    local gold = math.floor(amount / 10000)
    local silver = math.floor((amount % 10000) / 100)
    local copper = amount % 100
    local formattedGold = (type(BreakUpLargeNumbers) == "function") and BreakUpLargeNumbers(gold) or tostring(gold)
    return (formattedGold or "0") .. "|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:0:0|t " .. silver .. "|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:0:0|t " .. copper .. "|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:0:0|t"
end

local function FormatTime(seconds)
    if not seconds or seconds == 0 then return "0d 0h 0m" end
    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local mins = math.floor((seconds % 3600) / 60)
    if days > 0 then
        return days .. "d " .. hours .. "h " .. mins .. "m"
    elseif hours > 0 then
        return hours .. "h " .. mins .. "m"
    else
        return mins .. "m"
    end
end

-------------------------------------------------------------------------------
-- 2. ACCOUNT SUMMARY WINDOW
-------------------------------------------------------------------------------
local summaryFrame = CreateFrame("Frame", "K1SummaryWindow", UIParent, "BackdropTemplate")
summaryFrame:SetSize(620, 360)

if type(summaryFrame.SetResizeBounds) == "function" then
    summaryFrame:SetResizeBounds(520, 220)
end

summaryFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
summaryFrame:SetMovable(true)
summaryFrame:SetResizable(true)
summaryFrame:EnableMouse(true)
summaryFrame:RegisterForDrag("LeftButton")
summaryFrame:SetScript("OnDragStart", summaryFrame.StartMoving)
summaryFrame:SetScript("OnDragStop", summaryFrame.StopMovingOrSizing)
summaryFrame:Hide()

summaryFrame:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeSize = 1,
    insets = { left = 0, right = 0, top = 0, bottom = 0 }
})
summaryFrame:SetBackdropColor(0.06, 0.06, 0.06, 0.95)
summaryFrame:SetBackdropBorderColor(0.12, 0.12, 0.12, 1)

local header = summaryFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalMed3")
header:SetPoint("TOPLEFT", summaryFrame, "TOPLEFT", 12, -10)
header:SetText("|cff00a8ffK1|r Character Summary")

local closeBtn = CreateFrame("Button", nil, summaryFrame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", summaryFrame, "TOPRIGHT", -2, -2)

local resizeGrip = CreateFrame("Button", nil, summaryFrame)
resizeGrip:SetSize(16, 16)
resizeGrip:SetPoint("BOTTOMRIGHT", summaryFrame, "BOTTOMRIGHT", -2, 2)
resizeGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
resizeGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
resizeGrip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")

resizeGrip:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" then
        summaryFrame:StartSizing("BOTTOMRIGHT")
    end
end)

resizeGrip:SetScript("OnMouseUp", function(self)
    summaryFrame:StopMovingOrSizing()
end)

local columnHeaderFrame = CreateFrame("Frame", nil, summaryFrame)
columnHeaderFrame:SetPoint("TOPLEFT", summaryFrame, "TOPLEFT", 10, -32)
columnHeaderFrame:SetPoint("TOPRIGHT", summaryFrame, "TOPRIGHT", -30, -32)
columnHeaderFrame:SetHeight(20)

local RefreshSummaryWindow

local columns = {
    { key = "name", label = "Character (Realm)", width = 190, align = "LEFT" },
    { key = "level", label = "Lvl", width = 45, align = "CENTER" },
    { key = "ilvl", label = "iLvl", width = 50, align = "CENTER" },
    { key = "time", label = "Play Time", width = 110, align = "LEFT" },
    { key = "gold", label = "Gold", width = 140, align = "LEFT" },
}

local columnBtns = {}
local currentOffsetX = 5

for i, col in ipairs(columns) do
    local btn = CreateFrame("Button", nil, columnHeaderFrame)
    btn:SetSize(col.width, 20)
    btn:SetPoint("LEFT", columnHeaderFrame, "LEFT", currentOffsetX, 0)

    local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    txt:SetAllPoints()
    txt:SetJustifyH(col.align)
    txt:SetText(col.label)
    btn.txt = txt

    btn:SetScript("OnClick", function()
        InitDB()
        if K1StatFrameDB.sortKey == col.key then
            K1StatFrameDB.sortAsc = not K1StatFrameDB.sortAsc
        else
            K1StatFrameDB.sortKey = col.key
            K1StatFrameDB.sortAsc = (col.key == "name")
        end
        RefreshSummaryWindow()
    end)

    btn:SetScript("OnEnter", function() txt:SetTextColor(0, 0.66, 1) end)
    btn:SetScript("OnLeave", function() 
        if K1StatFrameDB and K1StatFrameDB.sortKey == col.key then
            txt:SetTextColor(1, 0.82, 0)
        else
            txt:SetTextColor(1, 1, 1)
        end
    end)

    columnBtns[col.key] = btn
    currentOffsetX = currentOffsetX + col.width + 5
end

local scrollFrame = CreateFrame("ScrollFrame", nil, summaryFrame, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", columnHeaderFrame, "BOTTOMLEFT", 0, -5)
scrollFrame:SetPoint("BOTTOMRIGHT", summaryFrame, "BOTTOMRIGHT", -30, 45)

local scrollContent = CreateFrame("Frame", nil, scrollFrame)
scrollContent:SetSize(560, 100)
scrollFrame:SetScrollChild(scrollContent)

summaryFrame:SetScript("OnSizeChanged", function(self, width, height)
    scrollContent:SetWidth(math.max(100, width - 60))
end)

local footerBg = CreateFrame("Frame", nil, summaryFrame, "BackdropTemplate")
footerBg:SetPoint("BOTTOMLEFT", summaryFrame, "BOTTOMLEFT", 10, 10)
footerBg:SetPoint("BOTTOMRIGHT", summaryFrame, "BOTTOMRIGHT", -10, 10)
footerBg:SetHeight(30)
footerBg:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeSize = 1,
})
footerBg:SetBackdropColor(0.03, 0.03, 0.03, 0.8)
footerBg:SetBackdropBorderColor(0.15, 0.15, 0.15, 1)

local footerText = footerBg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
footerText:SetPoint("CENTER", footerBg, "CENTER", 0, 0)

local rows = {}

RefreshSummaryWindow = function()
    InitDB()
    SaveCurrentCharacterData()

    for _, row in ipairs(rows) do row:Hide() end

    local currentPKey = GetPlayerKey()

    for key, btn in pairs(columnBtns) do
        if K1StatFrameDB.sortKey == key then
            local arrow = K1StatFrameDB.sortAsc and " ^" or " v"
            local baseLabel = ""
            for _, col in ipairs(columns) do if col.key == key then baseLabel = col.label end end
            btn.txt:SetText("|cffffd100" .. baseLabel .. arrow .. "|r")
        else
            for _, col in ipairs(columns) do if col.key == key then btn.txt:SetText(col.label) end end
        end
    end

    local sortedKeys = {}
    for k in pairs(K1StatFrameDB.chars) do
        table.insert(sortedKeys, k)
    end

    local sortKey = K1StatFrameDB.sortKey
    local sortAsc = K1StatFrameDB.sortAsc

    table.sort(sortedKeys, function(a, b)
        local cA, cB = K1StatFrameDB.chars[a], K1StatFrameDB.chars[b]
        local vA, vB

        if sortKey == "name" then
            vA, vB = cA.name or "", cB.name or ""
        elseif sortKey == "level" then
            vA, vB = cA.level or 0, cB.level or 0
        elseif sortKey == "ilvl" then
            vA, vB = cA.ilvl or 0, cB.ilvl or 0
        elseif sortKey == "time" then
            vA = GetCurrentPlayTime(cA, a == currentPKey)
            vB = GetCurrentPlayTime(cB, b == currentPKey)
        elseif sortKey == "gold" then
            vA, vB = cA.gold or 0, cB.gold or 0
        end

        if vA ~= vB then
            if sortAsc then return vA < vB else return vA > vB end
        end
        return (cA.name or "") < (cB.name or "")
    end)

    local index = 0
    local totalGold = 0
    local totalPlayTime = 0
    local totalLevels = 0

    for _, key in ipairs(sortedKeys) do
        local char = K1StatFrameDB.chars[key]
        if char then
            index = index + 1
            local row = rows[index]
            if not row then
                row = CreateFrame("Button", nil, scrollContent)
                row:SetHeight(20)

                row.cols = {}
                local colOffsetX = 0
                for _, col in ipairs(columns) do
                    local colFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    colFS:SetSize(col.width, 20)
                    colFS:SetPoint("LEFT", row, "LEFT", colOffsetX, 0)
                    colFS:SetJustifyH(col.align)
                    row.cols[col.key] = colFS
                    colOffsetX = colOffsetX + col.width + 5
                end

                local highlight = row:CreateTexture(nil, "HIGHLIGHT")
                highlight:SetAllPoints()
                highlight:SetColorTexture(1, 1, 1, 0.08)

                rows[index] = row
            end

            row:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 5, -((index - 1) * 22))
            row:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", -5, -((index - 1) * 22))

            local isCurrent = (key == currentPKey)
            local classColorHex = (RAID_CLASS_COLORS and char.class and RAID_CLASS_COLORS[char.class]) and RAID_CLASS_COLORS[char.class].colorStr or "ffffffff"
            local charPlayed = GetCurrentPlayTime(char, isCurrent)
            local statusTag = isCurrent and " |cff00ff00[Online]|r" or ""

            row.cols["name"]:SetText("|c" .. classColorHex .. (char.name or "Unknown") .. "|r |cff888888(" .. (char.realm or "") .. ")|r" .. statusTag)
            row.cols["level"]:SetText("|cffffffff" .. (char.level or 0) .. "|r")
            row.cols["ilvl"]:SetText("|cff00ff96" .. (char.ilvl or 0) .. "|r")
            row.cols["time"]:SetText(FormatTime(charPlayed))
            row.cols["gold"]:SetText(FormatGold(char.gold or 0))

            row.charKey = key
            row.charName = char.name or "Unknown"

            row:RegisterForClicks("RightButtonUp", "LeftButtonUp")
            row:SetScript("OnClick", function(self, button)
                if button == "RightButton" then
                    if MenuUtil and type(MenuUtil.CreateContextMenu) == "function" then
                        MenuUtil.CreateContextMenu(self, function(owner, rootDescription)
                            rootDescription:CreateTitle("Delete " .. self.charName)
                            rootDescription:CreateButton("|cffff0000Delete Character Data|r", function()
                                K1StatFrameDB.chars[self.charKey] = nil
                                RefreshSummaryWindow()
                            end)
                        end)
                    end
                end
            end)

            row:Show()

            totalGold = totalGold + (char.gold or 0)
            totalPlayTime = totalPlayTime + charPlayed
            totalLevels = totalLevels + (char.level or 0)
        end
    end

    scrollContent:SetHeight(math.max(100, index * 22))
    local footerStr = "Characters: " .. index .. "  |  Total Levels: " .. totalLevels .. "  |  Total Gold: " .. FormatGold(totalGold) .. "  |  Total Time Played: " .. FormatTime(totalPlayTime)
    footerText:SetText(footerStr)
end

-------------------------------------------------------------------------------
-- 3. MINIMAP BUTTON
-------------------------------------------------------------------------------
local minimapBtn = CreateFrame("Button", "K1SummaryMinimapButton", Minimap)
minimapBtn:SetSize(31, 31)
minimapBtn:SetFrameLevel(Minimap:GetFrameLevel() + 10)
minimapBtn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-Button-Highlight")

local icon = minimapBtn:CreateTexture(nil, "BACKGROUND")
icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_02")
icon:SetSize(20, 20)
icon:SetPoint("CENTER")

local border = minimapBtn:CreateTexture(nil, "OVERLAY")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetSize(53, 53)
border:SetPoint("TOPLEFT")

local function UpdateMinimapPos()
    InitDB()
    local angle = math.rad(K1StatFrameDB.minimap.angle or 220)
    local x = math.cos(angle) * 80
    local y = math.sin(angle) * 80
    minimapBtn:ClearAllPoints()
    minimapBtn:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

minimapBtn:RegisterForDrag("LeftButton")
minimapBtn:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
        if type(Minimap.GetCenter) ~= "function" or type(GetCursorPosition) ~= "function" then return end
        local mx, my = Minimap:GetCenter()
        local cx, cy = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        cx, cy = cx / scale, cy / scale
        local angle = math.deg(math.atan2(cy - my, cx - mx))
        InitDB()
        K1StatFrameDB.minimap.angle = angle
        UpdateMinimapPos()
    end)
end)

minimapBtn:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
end)

minimapBtn:SetScript("OnClick", function(self, button)
    if summaryFrame:IsShown() then
        summaryFrame:Hide()
    else
        RefreshSummaryWindow()
        summaryFrame:Show()
    end
end)

minimapBtn:SetScript("OnEnter", function(self)
    if GameTooltip and type(GameTooltip.SetOwner) == "function" then
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("|cff00a8ffK1 Summary|r")
        GameTooltip:AddLine("Click to open Character Summary.", 1, 1, 1)
        GameTooltip:Show()
    end
end)

minimapBtn:SetScript("OnLeave", function()
    if GameTooltip and type(GameTooltip.Hide) == "function" then
        GameTooltip:Hide()
    end
end)

-------------------------------------------------------------------------------
-- 4. EVENT LISTENERS
-------------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("TIME_PLAYED_MSG")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:RegisterEvent("PLAYER_MONEY")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == addonName then
            InitDB()
            UpdateMinimapPos()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        InitDB()
        SaveCurrentCharacterData()
        -- Re-save after 3 seconds to capture gold/item level after character caches finish
        C_Timer.After(3, function()
            SaveCurrentCharacterData()
        end)
    elseif event == "TIME_PLAYED_MSG" then
        local totalTime = ...
        InitDB()
        local pKey = GetPlayerKey()
        if pKey and K1StatFrameDB.chars and K1StatFrameDB.chars[pKey] then
            K1StatFrameDB.chars[pKey].playedTotal = totalTime
            sessionStartTime = (type(GetTime) == "function") and GetTime() or sessionStartTime
        end
    elseif event == "PLAYER_LOGOUT" then
        InitDB()
        SaveCurrentCharacterData()
        local pKey = GetPlayerKey()
        if pKey and K1StatFrameDB.chars and K1StatFrameDB.chars[pKey] then
            K1StatFrameDB.chars[pKey].playedTotal = GetCurrentPlayTime(K1StatFrameDB.chars[pKey], true)
        end
    else
        SaveCurrentCharacterData()
    end
end)


-------------------------------------------------------------------------------
-- 5. SLASH COMMANDS
-------------------------------------------------------------------------------
SLASH_K1SUMMARY1 = "/k1s"
SLASH_K1SUMMARY2 = "/k1summary"

SlashCmdList["K1SUMMARY"] = function(msg)
    if summaryFrame:IsShown() then
        summaryFrame:Hide()
    else
        RefreshSummaryWindow()
        summaryFrame:Show()
    end
end
