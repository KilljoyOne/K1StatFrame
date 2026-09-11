local addonName, addonTable = ...

-- Create parent anchor container inside CharacterFrame
local frame = CreateFrame("Frame", "K1StatFramePanel", CharacterFrame, "BackdropTemplate")
frame:SetSize(200, 90)

-- Anchor directly to the right side of the Character Frame
frame:SetPoint("TOPLEFT", CharacterFrame, "TOPRIGHT", 4, -30)

-- EllesmereUI Aesthetic (Dark background, pixel-perfect thin border)
frame:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeSize = 1,
    insets = { left = 0, right = 0, top = 0, bottom = 0 }
})
frame:SetBackdropColor(0.06, 0.06, 0.06, 0.9)
frame:SetBackdropBorderColor(0.12, 0.12, 0.12, 1)

-- Title Header
local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
title:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -8)
title:SetText("SECONDARY STATS")
title:SetTextColor(0.5, 0.5, 0.5)

-- Stat Labels Setup
local stats = {}
local statNames = { "Crit", "Haste", "Mastery", "Vers" }

for i, name in ipairs(statNames) do
    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -22 - ((i - 1) * 16))
    text:SetJustifyH("LEFT")
    stats[name] = text
end

local function UpdateStats()
    if not CharacterFrame:IsShown() then return end

    -- Raw Ratings
    local critRating = GetCombatRating(CR_CRIT_SPELL)
    local hasteRating = GetCombatRating(CR_HASTE_MELEE)
    local masteryRating = GetCombatRating(CR_MASTERY)
    local versRating = GetCombatRating(CR_VERSATILITY_DAMAGE_DONE)

    -- Percentages
    local critPercent = GetCritChance()
    local hastePercent = GetHaste()
    local masteryPercent = GetMasteryEffect()
    local versPercent = GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE) + GetVersatilityBonus(CR_VERSATILITY_DAMAGE_DONE)

    -- Formatted Strings
    stats["Crit"]:SetFormattedText("|cffc41f3bCrit:|r  %s (|cff00ff96%.2f%%|r)", BreakUpLargeNumbers(critRating), critPercent)
    stats["Haste"]:SetFormattedText("|cff00a8ffHaste:|r %s (|cff00ff96%.2f%%|r)", BreakUpLargeNumbers(hasteRating), hastePercent)
    stats["Mastery"]:SetFormattedText("|cffa335eeMast:|r  %s (|cff00ff96%.2f%%|r)", BreakUpLargeNumbers(masteryRating), masteryPercent)
    stats["Vers"]:SetFormattedText("|cff00ff00Vers:|r  %s (|cff00ff96%.2f%%|r)", BreakUpLargeNumbers(versRating), versPercent)
end

-- Update stats on events while panel is active
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("COMBAT_RATING_UPDATE")
frame:RegisterEvent("MASTERY_UPDATE")
frame:RegisterEvent("SPELL_POWER_CHANGED")

frame:SetScript("OnEvent", function(self, event, ...)
    UpdateStats()
end)

-- Hook CharacterFrame show/hide events
CharacterFrame:HookScript("OnShow", function()
    frame:Show()
    UpdateStats()
end)

CharacterFrame:HookScript("OnHide", function()
    frame:Hide()
end)
