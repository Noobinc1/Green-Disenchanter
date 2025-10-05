local ADDON_NAME = ...
local SPELL_NAME = GetSpellInfo(13262) or "Disenchant" -- 13262 = Disenchant

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("BAG_UPDATE")
f:RegisterEvent("SKILL_LINES_CHANGED")

local candidates = {}
local showBase = true

local function BaseItemIDFromLink(link)
    if not link then return nil end
    local id = tonumber(string.match(link, "item:(%d+)"))
    return id
end

local function IsGreenEquippableByItemID(itemID)
    if not itemID then return false end
    local name, baseLink, quality, _, _, itemType, _, _, equipLoc, icon = GetItemInfo(itemID)
    if not name then return false end
    if quality ~= 2 then return false end -- Uncommon
    if not IsEquippableItem(itemID) then return false end
    if itemType ~= "Armor" and itemType ~= "Weapon" then return false end
    return true, icon, baseLink or name
end

local function GetBagItemTexture(bag, slot, itemID, fallbackIcon)
    local tex
    if GetContainerItemInfo then
        local a,b,c,d,e,f,g,h,i,j = GetContainerItemInfo(bag, slot)
        tex = a or j
    end
    if not tex and itemID and GetItemIcon then
        tex = GetItemIcon(itemID)
    end
    if not tex then
        tex = fallbackIcon
    end
    return tex
end

local function ScanBags()
    wipe(candidates)
    for bag = 0, 4 do
        local slots = GetContainerNumSlots(bag)
        if slots and slots > 0 then
            for slot = 1, slots do
                local link = GetContainerItemLink(bag, slot)
                if link then
                    local itemID = BaseItemIDFromLink(link)
                    local ok, icon, baseDisplay = IsGreenEquippableByItemID(itemID)
                    if ok then
                        local texture = GetBagItemTexture(bag, slot, itemID, icon)
                        table.insert(candidates, { bag=bag, slot=slot, baseLink=baseDisplay, bagLink=link, icon=texture })
                    end
                end
            end
        end
    end
    table.sort(candidates, function(a,b) return (a.baseLink or a.bagLink or "") < (b.baseLink or b.bagLink or "") end)
end

-- ================= UI =================
local main = CreateFrame("Frame", "GreenDisenchanterFrame", UIParent)
main:SetWidth(520); main:SetHeight(560)
main:SetPoint("CENTER")
main:SetMovable(true)
main:EnableMouse(true)
main:RegisterForDrag("LeftButton")
main:SetScript("OnDragStart", main.StartMoving)
main:SetScript("OnDragStop", main.StopMovingOrSizing)

if main.SetBackdrop then
    main:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    main:SetBackdropColor(0, 0, 0, 0.85)
    main:SetBackdropBorderColor(0.7, 0.7, 0.7, 1)
end
main:Hide()

-- Title
main.title = main:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
main.title:SetPoint("TOP", 0, -12)
main.title:SetText("Green Disenchanter")

-- Close X
local close = CreateFrame("Button", nil, main, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -4, -4)

-- Controls row
local refreshBtn = CreateFrame("Button", nil, main, "UIPanelButtonTemplate")
refreshBtn:SetWidth(80); refreshBtn:SetHeight(22)
refreshBtn:SetPoint("TOPLEFT", 14, -38)
refreshBtn:SetText("Refresh")

local toggleTextBtn = CreateFrame("Button", nil, main, "UIPanelButtonTemplate")
toggleTextBtn:SetWidth(150); toggleTextBtn:SetHeight(22)
toggleTextBtn:SetPoint("LEFT", refreshBtn, "RIGHT", 8, 0)
local function UpdateToggleLabel()
    toggleTextBtn:SetText(showBase and "Show: Base Name" or "Show: Scaled Name")
end
UpdateToggleLabel()

-- Help text
local helpText = main:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
helpText:SetPoint("TOPLEFT", 14, -66)
helpText:SetPoint("RIGHT", -14, 0)
helpText:SetJustifyH("LEFT")
helpText:SetNonSpaceWrap(true)
helpText:SetWordWrap(true)
helpText:SetText("Click an item to cast Disenchant on it.")

-- Scroll area
local scrollFrame = CreateFrame("ScrollFrame", ADDON_NAME.."Scroll", main, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", 14, -92)
scrollFrame:SetPoint("BOTTOMRIGHT", -30, 54)

local content = CreateFrame("Frame", nil, scrollFrame)
content:SetWidth(1); content:SetHeight(1)
scrollFrame:SetScrollChild(content)

local BUTTON_HEIGHT = 28
local buttons = {}

local function MakeItemButton(i)
    local btn = CreateFrame("Button", ADDON_NAME.."ItemButton"..i, content, "SecureActionButtonTemplate, UIPanelButtonTemplate")
    btn:SetWidth(440); btn:SetHeight(BUTTON_HEIGHT)
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetWidth(24); btn.icon:SetHeight(24)
    btn.icon:SetPoint("LEFT", 4, 0)
    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    btn.text:SetPoint("LEFT", btn.icon, "RIGHT", 6, 0)
    btn.text:SetPoint("RIGHT", -6, 0)
    btn.text:SetJustifyH("LEFT")
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetBagItem(self.bag, self.slot) -- KEEP tooltips as-is
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return btn
end

local function UpdateList()
    local total = #candidates
    content:SetHeight(total * (BUTTON_HEIGHT + 4) + 8)
    content:SetWidth(1)
    for i = 1, total do
        local row = buttons[i]
        if not row then
            row = MakeItemButton(i)
            buttons[i] = row
            if i == 1 then
                row:SetPoint("TOPLEFT", 6, -6)
            else
                row:SetPoint("TOPLEFT", buttons[i-1], "BOTTOMLEFT", 0, -4)
            end
        end
        local data = candidates[i]
        row:Show()
        row.bag = data.bag
        row.slot = data.slot
        row.bagLink = data.bagLink
        row.baseLink = data.baseLink
        row.icon:SetTexture(data.icon)
        row.text:SetText(showBase and (data.baseLink or data.bagLink) or data.bagLink)
        local macro = string.format([[/cast %s
/use %d %d]], SPELL_NAME or "Disenchant", data.bag, data.slot)
        row:SetAttribute("type", "macro")
        row:SetAttribute("macrotext", macro)
        row:RegisterForClicks("AnyUp")
    end
    for i = total + 1, #buttons do
        buttons[i]:Hide()
    end
end

local function Rebuild()
    ScanBags()
    UpdateList()
end

refreshBtn:SetScript("OnClick", Rebuild)
toggleTextBtn:SetScript("OnClick", function()
    showBase = not showBase
    UpdateToggleLabel()
    UpdateList()
end)

-- Single OK button
local okBtn = CreateFrame("Button", "GreenDisenchanterOK", main, "UIPanelButtonTemplate")
okBtn:SetText("Okay")
okBtn:SetWidth(120); okBtn:SetHeight(24)
okBtn:SetPoint("BOTTOM", 0, 18)
okBtn:SetScript("OnClick", function() main:Hide() end)

SLASH_GREENDISENCHANTER1 = "/gd"
SLASH_GREENDISENCHANTER2 = "/greende"
SlashCmdList["GREENDISENCHANTER"] = function(msg)
    if main:IsShown() then main:Hide() else
        Rebuild()
        main:Show()
    end
end

f:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
    elseif event == "BAG_UPDATE" or event == "SKILL_LINES_CHANGED" then
        if main:IsShown() then Rebuild() end
    end
end)

