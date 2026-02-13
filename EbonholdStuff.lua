local ADDON_NAME = "EbonholdStuff"
local TARGET_NAME = "Goblin Merchant"
local PET_NAME = "Greedy scavenger"

local EHS_GetPlayerName
local EHS_IsAddonEnabledForChar

local EHS_greedyMessages = {}
local EHS_greedyFiltersInstalled = false

local function EHS_StripCodes(s)
    if type(s) ~= "string" then return nil end
    return s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h", ""):gsub("|h", "")
end

local PET_NAME_LC = PET_NAME:lower()
local function EHS_IsGreedyAuthor(author)
    if type(author) ~= "string" then return false end
    author = EHS_StripCodes(author)
    if not author or author == "" then return false end
    return author:lower() == PET_NAME_LC
end

local function EHS_TrackGreedySpeech(msg)
    msg = EHS_StripCodes(msg)
    if not msg or msg == "" then return end
    msg = msg:lower()
    EHS_greedyMessages[msg] = true
end

local function EHS_GreedyEventFilter(self, event, msg, author, ...)
    local hideChat = true
    local hideBubbles = true
    if DB then
        hideChat = (DB.muteGreedy == true) or (DB.hideGreedyChat == true)
        hideBubbles = (DB.muteGreedy == true) or (DB.hideGreedyBubbles == true)
    end

    if EHS_IsGreedyAuthor(author) then
        if hideBubbles and type(msg) == "string" then
            EHS_TrackGreedySpeech(msg)
        end
        if hideChat then
            return true
        end
    end

    if type(msg) == "string" then
        local clean = EHS_StripCodes(msg):lower()
        if clean:find("greedy scavenger", 1, true) and (clean:find(" says", 1, true) or clean:find(" yells", 1, true) or clean:find(" whispers", 1, true)) then
            if hideBubbles then
                local said = clean:match("greedy scavenger%s*says[:%s]*(.*)") or clean:match("greedy scavenger%s*yells[:%s]*(.*)") or clean:match("greedy scavenger%s*whispers[:%s]*(.*)")
                if said then EHS_TrackGreedySpeech(said) end
            end
            if hideChat then
                return true
            end
        end
    end

    return false
end

local function EHS_InstallGreedyMuteOnce()
    if EHS_greedyFiltersInstalled then return end
    EHS_greedyFiltersInstalled = true

    ChatFrame_AddMessageEventFilter("CHAT_MSG_MONSTER_SAY", EHS_GreedyEventFilter)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_MONSTER_YELL", EHS_GreedyEventFilter)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_MONSTER_WHISPER", EHS_GreedyEventFilter)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_MONSTER_EMOTE", EHS_GreedyEventFilter)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_MONSTER_PARTY", EHS_GreedyEventFilter)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_SAY", EHS_GreedyEventFilter)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_YELL", EHS_GreedyEventFilter)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_TEXT_EMOTE", EHS_GreedyEventFilter)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_EMOTE", EHS_GreedyEventFilter)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", EHS_GreedyEventFilter)
end

local EHS_bubbleFrame = CreateFrame("Frame")
local EHS_killedBubbles = setmetatable({}, { __mode = "k" })

local function EHS_KillBubbleFrame(frame)
    if not frame or frame.__EHS_killed then return end
    frame.__EHS_killed = true
    EHS_killedBubbles[frame] = true

    frame:SetAlpha(0)
    frame:EnableMouse(false)
    frame:Hide()

    if frame.HookScript then
        frame:HookScript("OnShow", function(self)
            self:SetAlpha(0)
            self:Hide()
        end)
    end
end
EHS_bubbleFrame.elapsed = 0
EHS_bubbleFrame:SetScript("OnUpdate", function(self, elapsed)
    local hideBubbles = true
    if DB then
        hideBubbles = (DB.muteGreedy == true) or (DB.hideGreedyBubbles == true)
    end
    if not hideBubbles then return end

    for bubble in pairs(EHS_killedBubbles) do
        if bubble and bubble.IsShown and bubble:IsShown() then
            bubble:SetAlpha(0)
            bubble:Hide()
        end
    end

    if not next(EHS_greedyMessages) then return end

    self.elapsed = (self.elapsed or 0) + elapsed
    if self.elapsed < 0.05 then return end
    self.elapsed = 0

    local numChildren = WorldFrame and WorldFrame.GetNumChildren and WorldFrame:GetNumChildren() or 0
    for i = 1, numChildren do
        local child = select(i, WorldFrame:GetChildren())
        if child and child.GetObjectType and child:GetObjectType() == "Frame" and child:IsVisible() then
            local numRegions = child.GetNumRegions and child:GetNumRegions() or 0
            for j = 1, numRegions do
                local region = select(j, child:GetRegions())
                if region and region.GetObjectType and region:GetObjectType() == "FontString" then
                    local text = region:GetText()
                    if text then
                        local clean = EHS_StripCodes(text):lower()
                        if EHS_greedyMessages[clean] then
                            EHS_KillBubbleFrame(child)
                            break
                        end
                    end
                end
            end
        end
    end
end)

local PET_CHAT_PREFIX = PET_NAME .. " says:"

local CHAT_FILTER_EVENTS = {
    "CHAT_MSG_SAY",
    "CHAT_MSG_YELL",
    "CHAT_MSG_EMOTE",
    "CHAT_MSG_TEXT_EMOTE",
}

local function GreedyScavengerChatFilter(self, event, msg, author, ...)
    if EHS_IsGreedyAuthor(author) then
        return true
    end
    return false
end

local function ApplyGreedyChatFilter()
    for i = 1, #CHAT_FILTER_EVENTS do
        local ev = CHAT_FILTER_EVENTS[i]
        if ChatFrame_RemoveMessageEventFilter then
            ChatFrame_RemoveMessageEventFilter(ev, GreedyScavengerChatFilter)
        end
        if DB and ((DB.muteGreedy == true) or (DB.hideGreedyChat == true)) and ChatFrame_AddMessageEventFilter then
            
ChatFrame_AddMessageEventFilter(ev, GreedyScavengerChatFilter)
        end
    end
end

local DB

local function EnsureDB()
    if EbonholdStuffDB == nil then EbonholdStuffDB = {} end
    DB = EbonholdStuffDB

    if type(DB.blacklist) ~= "table" then DB.blacklist = {} end
    if type(DB.deleteList) ~= "table" then DB.deleteList = {} end
    if type(DB.allowedChars) ~= "table" then DB.allowedChars = {} end

    if type(DB.totalCopper) ~= "number" then DB.totalCopper = 0 end


    if type(DB.totalItemsSold) ~= "number" then DB.totalItemsSold = 0 end
    if type(DB.totalItemsDeleted) ~= "number" then DB.totalItemsDeleted = 0 end
    if type(DB.totalRepairs) ~= "number" then DB.totalRepairs = 0 end
    if type(DB.totalRepairCopper) ~= "number" then DB.totalRepairCopper = 0 end

    if type(DB.soldItemCounts) ~= "table" then DB.soldItemCounts = {} end
    if type(DB.deletedItemCounts) ~= "table" then DB.deletedItemCounts = {} end

    if type(DB.repairGear) ~= "boolean" then DB.repairGear = true end

    if type(DB.enableAutoSell) ~= "boolean" then DB.enableAutoSell = true end
    if type(DB.preventSellEpics) ~= "boolean" then DB.preventSellEpics = true end
    if type(DB.preventSellRares) ~= "boolean" then DB.preventSellRares = false end
    if type(DB.preventSellUncommons) ~= "boolean" then DB.preventSellUncommons = false end
    if type(DB.enableDeletion) ~= "boolean" then DB.enableDeletion = true end
    if type(DB.summonGreedy) ~= "boolean" then DB.summonGreedy = true end
    if type(DB.summonDelay) ~= "number" then DB.summonDelay = 1.6 end

    if type(DB.vendorInterval) ~= "number" then DB.vendorInterval = 0.015 end

    if type(DB.muteGreedy) ~= "boolean" then DB.muteGreedy = true end
    if type(DB.hideGreedyChat) ~= "boolean" then DB.hideGreedyChat = DB.muteGreedy end
    if type(DB.hideGreedyBubbles) ~= "boolean" then DB.hideGreedyBubbles = DB.muteGreedy end

    if type(DB.enableOnlyListedChars) ~= "boolean" then DB.enableOnlyListedChars = false end

if not DB._seededLists then
    if DB.blacklist and not next(DB.blacklist) then
        DB.blacklist[6948] = true
    end
    if DB.deleteList and not next(DB.deleteList) then
        DB.deleteList[300581] = true
        DB.deleteList[300574] = true
    end
    DB._seededLists = true
end

end

EHS_GetPlayerName = function()
    local n = UnitName("player")
    if not n or n == "" then return "" end
    return n
end

local function EHS_IsCharacterAllowed()
    if not DB or not DB.enableOnlyListedChars then
        return true
    end
    local name = EHS_GetPlayerName()
    return DB.allowedChars and DB.allowedChars[name] == true
end

EHS_IsAddonEnabledForChar = function()
    return EHS_IsCharacterAllowed()
end

local function IsInSet(setTable, itemID)
    return itemID and setTable[itemID] == true
end

local function AddToSet(setTable, itemID)
    if itemID then setTable[itemID] = true end
end

local function RemoveFromSet(setTable, itemID)
    if itemID then setTable[itemID] = nil end
end

local function SortedKeys(setTable)
    local t = {}
    for k in pairs(setTable) do
        if type(k) == "number" then t[#t+1] = k end
    end
    table.sort(t)
    return t
end

local function CopperToColoredText(copper)
    if not copper or copper < 0 then copper = 0 end
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local cop = copper % 100

    local g = string.format("|cffF8D943%dg|r", gold)
    local s = string.format("|cffC0C0C0%ds|r", silver)
    local c = string.format("|cffB87333%dc|r", cop)
    return string.format("%s %s %s", g, s, c)
end

local function PrintNice(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff7fbfff[EbonholdStuff]|r " .. msg)
end

local EHS_activeIDBox = nil
local EHS_Original_ChatEdit_InsertLink = ChatEdit_InsertLink

local function EHS_ExtractItemID(link)
    if type(link) ~= "string" then return nil end
    local id = link:match("item:(%d+)")
    if id then return tonumber(id) end
    return nil
end

ChatEdit_InsertLink = function(link)
    if EHS_activeIDBox and EHS_activeIDBox:IsShown() then
        local id = EHS_ExtractItemID(link)
        if id then
            EHS_activeIDBox:SetText(tostring(id))
            EHS_activeIDBox:HighlightText()
            return true
        end
    end
    return EHS_Original_ChatEdit_InsertLink(link)
end

local function SummonGreedyScavenger()
    local num = GetNumCompanions("CRITTER")
    if not num or num <= 0 then return end

    for i = 1, num do
        local creatureID, creatureName, spellID, icon, isSummoned = GetCompanionInfo("CRITTER", i)
        if creatureName == PET_NAME then
            if not isSummoned then
                CallCompanion("CRITTER", i)
            end
            return
        end
    end
end

local function EHS_SummonGreedyWithDelay()
    if not DB or not DB.summonGreedy then return end
    local d = tonumber(DB.summonDelay) or 1.6
    if d < 0 then d = 0 end
    EHS_Delay(d, SummonGreedyScavenger)
end

local EHS_delayFrame = CreateFrame("Frame")
local EHS_timers = {}

local function EHS_Delay(seconds, func)
    if type(func) ~= "function" then return end
    seconds = tonumber(seconds) or 0
    if seconds <= 0 then
        func()
        return
    end
    EHS_timers[#EHS_timers + 1] = { t = seconds, f = func }
end

EHS_delayFrame:SetScript("OnUpdate", function(self, elapsed)
    if #EHS_timers == 0 then return end
    for i = #EHS_timers, 1, -1 do
        local item = EHS_timers[i]
        item.t = item.t - elapsed
        if item.t <= 0 then
            table.remove(EHS_timers, i)
            local ok, err = pcall(item.f)
        end
    end
end)

local function EHS_SummonGreedyWithDelay()
    if not DB or not DB.summonGreedy then return end
    EHS_Delay((DB and DB.summonDelay) or 1.6, SummonGreedyScavenger)
end


local pendingDelete = nil
local deletePopupHooked = false

local function HookDeletePopupOnce()
    if deletePopupHooked then return end
    deletePopupHooked = true

    local f = CreateFrame("Frame")
    f:SetScript("OnUpdate", function()
        local popup = StaticPopup1
        if popup and popup:IsShown() and popup.which == "DELETE_ITEM" and pendingDelete then
            local id = pendingDelete.itemID
            if id and IsInSet(DB.deleteList, id) then
                local editBox = StaticPopup1EditBox
                if editBox then
                    editBox:SetText("DELETE")
                    editBox:HighlightText()
                end
                local button1 = StaticPopup1Button1
                if button1 and button1:IsEnabled() then
                    button1:Click()
                    pendingDelete = nil
                end
            else
                pendingDelete = nil
            end
        end
    end)
end

local running = false
local queue = {}
local queueIndex = 1
local goldThisVendoring = 0

local worker = CreateFrame("Frame")
worker:Hide()

local function BuildQueue()
    wipe(queue)
    queueIndex = 1
    goldThisVendoring = 0
    if DB.enableAutoSell == true then
        for bag = 0, 4 do
            local slots = GetContainerNumSlots(bag)
            for slot = 1, slots do
                local itemID = GetContainerItemID(bag, slot)
                if itemID and not IsInSet(DB.blacklist, itemID) then
                    local texture, itemCount, locked = GetContainerItemInfo(bag, slot)
                    if itemCount and itemCount > 0 and not locked then
                        local name, link, quality, level, minLevel, itemType, subType, stackCount, equipLoc, icon, sellPrice = GetItemInfo(itemID)
                        local preventEpics = (DB and DB.preventSellEpics == true)
                        local preventRares = (DB and DB.preventSellRares == true)
                        local preventUncommons = (DB and DB.preventSellUncommons == true)
                        local blockedByQuality = (quality == 4 and preventEpics) or (quality == 3 and preventRares) or (quality == 2 and preventUncommons)
                        if blockedByQuality then
                        elseif sellPrice and sellPrice > 0 then

                            queue[#queue+1] = {
                                type = "sell",
                                bag = bag,
                                slot = slot,
                                itemID = itemID,
                                count = itemCount,
                                price = sellPrice
                            }
                            goldThisVendoring = goldThisVendoring + (sellPrice * itemCount)
                        end
                    end
                end
            end
        end
    end

    if DB.enableDeletion == true then
        for bag = 0, 4 do
            local slots = GetContainerNumSlots(bag)
            for slot = 1, slots do
                local itemID = GetContainerItemID(bag, slot)
                if itemID and IsInSet(DB.deleteList, itemID) then
                    local texture, itemCount, locked = GetContainerItemInfo(bag, slot)
                    if itemCount and itemCount > 0 and not locked then
                        queue[#queue+1] = {
                            type = "delete",
                            bag = bag,
                            slot = slot,
                            itemID = itemID,
                            count = itemCount
                        }
                    end
                end
            end
        end
    end
end

local function FinishRun()
    running = false
    worker:Hide()

    DB.totalCopper = (DB.totalCopper or 0) + (goldThisVendoring or 0)

    PrintNice("Vendoring complete! |cffb6ffb6Money Collected:|r " .. CopperToColoredText(goldThisVendoring))

    EHS_SummonGreedyWithDelay()
end

local function DoNextAction()
    if not MerchantFrame or not MerchantFrame:IsShown() then
        running = false
        worker:Hide()
        return
    end

    local action = queue[queueIndex]
    if not action then
        FinishRun()
        return
    end

    if action.type == "sell" then
        -- Track sold totals (best-effort; the game will reject unsellable items)
        DB.totalItemsSold = (DB.totalItemsSold or 0) + (action.count or 1)
        DB.soldItemCounts = DB.soldItemCounts or {}
        if action.itemID then
            DB.soldItemCounts[action.itemID] = (DB.soldItemCounts[action.itemID] or 0) + (action.count or 1)
        end
        UseContainerItem(action.bag, action.slot)

    elseif action.type == "delete" then
        -- Track deleted totals (best-effort; protected by delete-list + popup auto-confirm)
        DB.totalItemsDeleted = (DB.totalItemsDeleted or 0) + (action.count or 1)
        DB.deletedItemCounts = DB.deletedItemCounts or {}
        if action.itemID then
            DB.deletedItemCounts[action.itemID] = (DB.deletedItemCounts[action.itemID] or 0) + (action.count or 1)
        end
        ClearCursor()
        PickupContainerItem(action.bag, action.slot)
        local cursorType, cursorID = GetCursorInfo()

        if cursorType == "item" then
            pendingDelete = { bag = action.bag, slot = action.slot, itemID = action.itemID }
            DeleteCursorItem()
            ClearCursor()
        else
            ClearCursor()
            pendingDelete = nil
        end
    end

    queueIndex = queueIndex + 1
end

worker:SetScript("OnUpdate", function(self, elapsed)
    self.t = (self.t or 0) + elapsed
    local interval = (DB and DB.vendorInterval) or 0.015
    if interval < 0.005 then interval = 0.005 end
    if self.t >= interval then
        self.t = 0
        DoNextAction()
    end
end)

local function ShouldRunNow()
    if not UnitExists("target") then return false end
    local name = UnitName("target")
    if name ~= TARGET_NAME then return false end
    if not MerchantFrame or not MerchantFrame:IsShown() then return false end
    return true
end

local function StartRun()
    if not EHS_IsAddonEnabledForChar() then return end
    if running then return end
    if not ShouldRunNow() then return end

    HookDeletePopupOnce()

    running = true

    -- Repair first (Goblin Merchant gate is already satisfied by ShouldRunNow)
    if DB and DB.repairGear == true and CanMerchantRepair and CanMerchantRepair() and GetRepairAllCost and RepairAllItems then
        local repairCost, canRepair = GetRepairAllCost()
        if canRepair and repairCost and repairCost > 0 and GetMoney and GetMoney() >= repairCost then
            RepairAllItems()
            DB.totalRepairs = (DB.totalRepairs or 0) + 1
            DB.totalRepairCopper = (DB.totalRepairCopper or 0) + repairCost
        end
    end

    BuildQueue()

    if #queue == 0 then
        PrintNice("Found nothing to sell.")
        running = false
        if UnitExists("target") and UnitName("target") == TARGET_NAME and MerchantFrame and MerchantFrame:IsShown() then
            EHS_SummonGreedyWithDelay()
        end
        return
    end

    worker.t = 0
    worker:Show()
end

local MainOptions = CreateFrame("Frame", "EbonholdStuffOptionsMain", InterfaceOptionsFramePanelContainer)
MainOptions.name = "EbonholdStuff"

local function MakeHeader(parent, text, y)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    fs:SetPoint("TOPLEFT", 16, y)
    fs:SetText(text)
    return fs
end

local function MakeLabel(parent, text, x, y)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    fs:SetPoint("TOPLEFT", x, y)
    local w = (InterfaceOptionsFramePanelContainer and InterfaceOptionsFramePanelContainer:GetWidth()) or 640
    fs:SetWidth(math.max(200, w - 60))
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("TOP")
    if fs.SetWordWrap then fs:SetWordWrap(true) end
    fs:SetText(text)
    return fs
end

local function StyleInputBox(editBox)
    if not editBox then return end
    if editBox.SetTextInsets then
        editBox:SetTextInsets(6, 6, 0, 0)
    end
    -- In 3.3.5, InputBoxTemplate textures can sometimes overlap the text; force them behind.
    local n = editBox.GetName and editBox:GetName()
    if n then
        local left = _G[n .. "Left"]
        local mid  = _G[n .. "Middle"]
        local right= _G[n .. "Right"]
        if left and left.SetDrawLayer then left:SetDrawLayer("BACKGROUND") end
        if mid and mid.SetDrawLayer then mid:SetDrawLayer("BACKGROUND") end
        if right and right.SetDrawLayer then right:SetDrawLayer("BACKGROUND") end
    end
    editBox:SetFrameLevel((editBox:GetParent() and editBox:GetParent():GetFrameLevel() or editBox:GetFrameLevel()) + 2)
end


local function CreateListUI(parent, titleText, setTableName, x, y)
    local w = (InterfaceOptionsFramePanelContainer and InterfaceOptionsFramePanelContainer:GetWidth() or 640) - 60

    local box = CreateFrame("Frame", nil, parent)
    box:SetPoint("TOPLEFT", x, y)
    box:SetSize(w, 320)

    local title = box:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOPLEFT", 0, 0)
    title:SetText(titleText)

    local input = CreateFrame("EditBox", "EbonholdStuffIDInput_"..setTableName, box, "InputBoxTemplate")
    input:SetAutoFocus(false)
    input:SetSize(140, 20)
    input:SetPoint("TOPLEFT", 0, -24)
    input:SetNumeric(true)
    input:SetMaxLetters(10)
    input:SetText("")
    StyleInputBox(input)

    local addBtn = CreateFrame("Button", nil, box, "UIPanelButtonTemplate")
    addBtn:SetSize(60, 20)
    addBtn:SetPoint("LEFT", input, "RIGHT", 8, 0)
    addBtn:SetText("Add")

    input:SetScript("OnEditFocusGained", function(self) EHS_activeIDBox = self end)
    input:SetScript("OnEditFocusLost", function(self) if EHS_activeIDBox == self then EHS_activeIDBox = nil end end)
    input:SetScript("OnReceiveDrag", function(self)
        local ctype, cid = GetCursorInfo()
        if ctype == "item" and cid then
            self:SetText(tostring(cid))
            self:HighlightText()
            ClearCursor()
        end
    end)

    local searchLabel = box:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    searchLabel:SetPoint("TOPLEFT", 0, -52)
    searchLabel:SetText("Search:")

    local search = CreateFrame("EditBox", "EbonholdStuffSearchInput_"..setTableName, box, "InputBoxTemplate")
    search:SetAutoFocus(false)
    search:SetSize(180, 20)
    search:SetPoint("LEFT", searchLabel, "RIGHT", 8, 0)
    search:SetMaxLetters(40)
    search:SetText("")
    StyleInputBox(search)

    local clearSearch = CreateFrame("Button", nil, box, "UIPanelButtonTemplate")
    clearSearch:SetSize(46, 20)
    clearSearch:SetPoint("LEFT", search, "RIGHT", 8, 0)
    clearSearch:SetText("Clear")

    local scroll = CreateFrame("ScrollFrame", "EbonholdStuffListScroll_"..setTableName, box, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, -78)
    scroll:SetPoint("BOTTOMRIGHT", -26, 8)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)

    local rows = {}
    local function WipeRows()
        for i = 1, #rows do
            rows[i]:Hide()
            rows[i] = nil
        end
    end

    local function MatchesSearch(id, name, searchText)
        if not searchText or searchText == "" then return true end
        local idStr = tostring(id or "")
        if idStr:find(searchText, 1, true) then return true end
        local nameStr = tostring(name or ""):lower()
        if nameStr:find(searchText, 1, true) then return true end
        return false
    end

    local function Refresh()
        WipeRows()

        local searchText = ""
        if search and search.GetText then
            searchText = (search:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", ""):lower()
        end

        local setTable = DB[setTableName]
        local keys = {}
        for k in pairs(setTable) do
            if type(k) == "number" then keys[#keys+1] = k end
        end
        table.sort(keys)

        local shown = 0
        local rowY = -4
        for i = 1, #keys do
            local id = keys[i]
            local name = GetItemInfo(id) or ("ItemID: " .. id)

            if MatchesSearch(id, name, searchText) then
                local row = CreateFrame("Frame", nil, content)
                row:SetPoint("TOPLEFT", 0, rowY)
                row:SetSize(w - 30, 22)

                local text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
                text:SetPoint("LEFT", 2, 0)
                text:SetWidth(w - 120)
                text:SetJustifyH("LEFT")
                text:SetText(string.format("|cffb6ffb6%d|r  %s", id, name))

                local rm = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                rm:SetSize(72, 18)
                rm:SetPoint("RIGHT", -2, 0)
                rm:SetText("Remove")
                rm:SetScript("OnClick", function()
                    DB[setTableName][id] = nil
                    Refresh()
                end)

                rows[#rows+1] = row
                rowY = rowY - 22
                shown = shown + 1
            end
        end

        content:SetHeight(math.max(1, (shown * 22) + 8))
    end

    addBtn:SetScript("OnClick", function()
        local v = tonumber(input:GetText() or "")
        if not v or v <= 0 then
            PlaySound("igMainMenuOptionCheckBoxOff")
            return
        end
        DB[setTableName][v] = true
        input:SetText("")
        Refresh()
        PlaySound("igMainMenuOptionCheckBoxOn")
    end)

    input:SetScript("OnEnterPressed", function()
        addBtn:Click()
        input:ClearFocus()
    end)

    search:SetScript("OnTextChanged", function()
        Refresh()
    end)

    clearSearch:SetScript("OnClick", function()
        search:SetText("")
        Refresh()
    end)

    box.Refresh = Refresh
    return box
end

local function AddCheckbox(parent, name, anchor, labelText, getter, setter, yOff)
    local cb = CreateFrame("CheckButton", name, parent, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOff or -6)
    cb:SetChecked(getter())

    local t = _G[name .. "Text"]
    if t then
        t:SetText(labelText)
        t:SetWidth(420)
        t:SetJustifyH("LEFT")
    end

    cb:SetScript("OnClick", function()
        setter(cb:GetChecked() and true or false)
        PlaySound("igMainMenuOptionCheckBoxOn")
    end)
    return cb
end

local function ColorTextByQuality(quality, text)
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    local hex = (c and c.hex) or "|cffffffff"
    return hex .. text .. "|r"
end

local function AddSlider(parent, name, anchor, labelText, minVal, maxVal, step, getter, setter, yOff)
    local s = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    s:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOff or -16)
    s:SetMinMaxValues(minVal, maxVal)
    if s.SetValueStep then s:SetValueStep(step) end
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
    s:SetValue(getter())

    local low = _G[name .. "Low"]
    local high = _G[name .. "High"]
    local text = _G[name .. "Text"]

    if low then low:SetText(string.format("%.3fs", minVal)) end
    if high then high:SetText(string.format("%.3fs", maxVal)) end

    local function RefreshText(v)
        if text then
            text:SetText(labelText .. ": " .. string.format("%.3fs", v))
        end
    end
    RefreshText(getter())

    s:SetScript("OnValueChanged", function(self, value)
        value = tonumber(value) or minVal
        if step and step > 0 then
            value = math.floor((value / step) + 0.5) * step
        end
        if value < minVal then value = minVal end
        if value > maxVal then value = maxVal end
        setter(value)
        RefreshText(value)
    end)

    return s
end


MainOptions:SetScript("OnShow", function(self)
    EnsureDB()

    local function GetMostItem(countTable)
        local bestID, bestCount = nil, 0
        if type(countTable) ~= "table" then return nil, 0 end
        for id, cnt in pairs(countTable) do
            if type(id) == "number" and type(cnt) == "number" and cnt > bestCount then
                bestID, bestCount = id, cnt
            end
        end
        return bestID, bestCount
    end

    local function ItemLabel(id)
        if not id then return "None" end
        local name = GetItemInfo(id)
        if name then
            return string.format("|cff24ffb6%d|r - %s", id, name)
        end
        return "ItemID: " .. tostring(id)
    end

    local function RefreshStats()
        if not self.statsMoney then return end
        self.statsMoney:SetText("Total Money Made: " .. CopperToColoredText(DB.totalCopper or 0))
        self.statsSold:SetText("Total Items Sold: " .. tostring(DB.totalItemsSold or 0))
        self.statsDeleted:SetText("Total Items Deleted: " .. tostring(DB.totalItemsDeleted or 0))
        self.statsRepairs:SetText("Total Repairs: " .. tostring(DB.totalRepairs or 0))
        self.statsRepairCost:SetText("Total Repair Cost: " .. CopperToColoredText(DB.totalRepairCopper or 0))

        local mostID, mostCount = GetMostItem(DB.soldItemCounts)
        if mostID then
            self.statsMostSold:SetText("Most Sold Item: " .. ItemLabel(mostID) .. " (x" .. tostring(mostCount) .. ")")
        else
            self.statsMostSold:SetText("Most Sold Item: None")
        end
    end

    if self.inited then
        RefreshStats()
        return
    end
    self.inited = true

    MakeHeader(self, "EbonholdStuff v1.1.1", -16)

    MakeLabel(self, "Welcome to |cffb6ffb6EbonholdStuff|r!", 16, -44)
    MakeLabel(self, "To use, target and interact with any |cffb6ffb6Goblin Merchant|r.", 16, -64)
    MakeLabel(self, "The AddOn is specifically designed to only work with |cffb6ffb6Goblin Merchant|r, and will not activate in any other vendor window.", 16, -84)
    MakeLabel(self, "If you encounter any issues or have suggestions for improvements, feel free to message me on Discord @ |cff00ffaebadutski2|r", 16, -114)

    local money = self:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    money:SetPoint("TOPLEFT", 16, -160)
    self.statsMoney = money

    local sold = self:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    sold:SetPoint("TOPLEFT", money, "BOTTOMLEFT", 0, -6)
    self.statsSold = sold

    local deleted = self:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    deleted:SetPoint("TOPLEFT", sold, "BOTTOMLEFT", 0, -6)
    self.statsDeleted = deleted

    local repairs = self:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    repairs:SetPoint("TOPLEFT", deleted, "BOTTOMLEFT", 0, -6)
    self.statsRepairs = repairs

    local repairCost = self:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    repairCost:SetPoint("TOPLEFT", repairs, "BOTTOMLEFT", 0, -6)
    self.statsRepairCost = repairCost

    local mostSold = self:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    mostSold:SetPoint("TOPLEFT", repairCost, "BOTTOMLEFT", 0, -6)
    mostSold:SetWidth(560)
    mostSold:SetJustifyH("LEFT")
    self.statsMostSold = mostSold

    local resetBtn = CreateFrame("Button", "EbonholdStuffResetStatsBtn", self, "UIPanelButtonTemplate")
    resetBtn:SetSize(170, 22)
    resetBtn:SetPoint("TOPLEFT", mostSold, "BOTTOMLEFT", 0, -12)
    resetBtn:SetText("Reset All Stats")
    resetBtn:SetScript("OnClick", function()
        DB.totalCopper = 0
        DB.totalItemsSold = 0
        DB.totalItemsDeleted = 0
        DB.totalRepairs = 0
        DB.totalRepairCopper = 0
        wipe(DB.soldItemCounts)
        wipe(DB.deletedItemCounts)
        RefreshStats()
        PlaySound("igMainMenuOptionCheckBoxOn")
    end)

    RefreshStats()
end)

InterfaceOptions_AddCategory(MainOptions)

-- Merchant Settings (Vendoring + Repair)
local MerchantPanel = CreateFrame("Frame", "EbonholdStuffOptionsMerchant", InterfaceOptionsFramePanelContainer)
MerchantPanel.name = "Merchant Settings"
MerchantPanel.parent = "EbonholdStuff"

MerchantPanel:SetScript("OnShow", function(self)
    EnsureDB()
    if self.inited then
        if self.sellCB then self.sellCB:SetChecked(DB.enableAutoSell) end
        if self.repairCB then self.repairCB:SetChecked(DB.repairGear) end
        if self.epicCB then self.epicCB:SetChecked(DB.preventSellEpics) end
        if self.rareCB then self.rareCB:SetChecked(DB.preventSellRares) end
        if self.uncCB then self.uncCB:SetChecked(DB.preventSellUncommons) end
        if self.speedSlider then self.speedSlider:SetValue(DB.vendorInterval or 0.015) end
        return
    end
    self.inited = true

    MakeHeader(self, "Merchant Settings", -16)
    MakeLabel(self, "These settings control what happens when you interact with a |cffb6ffb6Goblin Merchant|r", 16, -44)

    local repairCB = CreateFrame("CheckButton", "EbonholdStuffRepairGearCB", self, "InterfaceOptionsCheckButtonTemplate")
    repairCB:SetPoint("TOPLEFT", 16, -90)
    repairCB:SetChecked(DB.repairGear)
    local rt = _G[repairCB:GetName() .. "Text"]
    if rt then
        rt:SetText("Repair Gear while Vendoring")
        rt:SetWidth(420)
        rt:SetJustifyH("LEFT")
    end
    repairCB:SetScript("OnClick", function()
        DB.repairGear = repairCB:GetChecked() and true or false
        PlaySound("igMainMenuOptionCheckBoxOn")
    end)
    self.repairCB = repairCB

    local sellCB = AddCheckbox(self, "EbonholdStuffEnableSellCB", repairCB, "Enable Automatic Vendoring",
        function() return DB.enableAutoSell end,
        function(v) DB.enableAutoSell = v end,
        -6)
    self.sellCB = sellCB

    local epicLabel = "Prevent selling " .. ColorTextByQuality(4, "Epic") .. " quality items"
    local rareLabel = "Prevent selling " .. ColorTextByQuality(3, "Rare") .. " quality items"
    local uncLabel  = "Prevent selling " .. ColorTextByQuality(2, "Uncommon") .. " quality items"

    local epicCB = AddCheckbox(self, "EbonholdStuffPreventSellEpicsCB", sellCB, epicLabel,
        function() return DB.preventSellEpics end,
        function(v) DB.preventSellEpics = v end,
        -6)
    self.epicCB = epicCB

    local rareCB = AddCheckbox(self, "EbonholdStuffPreventSellRaresCB", epicCB, rareLabel,
        function() return DB.preventSellRares end,
        function(v) DB.preventSellRares = v end,
        -6)
    self.rareCB = rareCB

    local uncCB = AddCheckbox(self, "EbonholdStuffPreventSellUncommonsCB", rareCB, uncLabel,
        function() return DB.preventSellUncommons end,
        function(v) DB.preventSellUncommons = v end,
        -6)
    self.uncCB = uncCB

    local speedSlider = AddSlider(self, "EbonholdStuffVendoringSpeedSlider", uncCB,
        "Vendoring Speed", 0.005, 0.250, 0.005,
        function() return DB.vendorInterval or 0.015 end,
        function(v) DB.vendorInterval = v end,
        -16)
    self.speedSlider = speedSlider
	speedSlider:SetWidth(200)
end)

InterfaceOptions_AddCategory(MerchantPanel)

local BlacklistPanel = CreateFrame("Frame", "EbonholdStuffOptionsBlacklist", InterfaceOptionsFramePanelContainer)
BlacklistPanel.name = "Blacklist Settings"
BlacklistPanel.parent = "EbonholdStuff"

BlacklistPanel:SetScript("OnShow", function(self)
    EnsureDB()
    if self.inited then
        if self.listUI then self.listUI:Refresh() end
        return
    end
    self.inited = true

    MakeHeader(self, "Blacklist Settings", -16)
    MakeLabel(self, "Items on this list will never be sold by Automatic Vendoring.", 16, -44)
    MakeLabel(self, "Add Items by Shift-Clicking an item, drag & drop into the text field below, or type the ItemID and press Add.", 16, -64)



    self.listUI = CreateListUI(self, "Item Blacklist", "blacklist", 16, -104)
    self.listUI:Refresh()
end)

InterfaceOptions_AddCategory(BlacklistPanel)

local DeletePanel = CreateFrame("Frame", "EbonholdStuffOptionsDeletion", InterfaceOptionsFramePanelContainer)
DeletePanel.name = "Deletion Settings"
DeletePanel.parent = "EbonholdStuff"

DeletePanel:SetScript("OnShow", function(self)
    EnsureDB()
    if self.inited then
        if self.listUI then self.listUI:Refresh() end
        return
    end
    self.inited = true

    MakeHeader(self, "Deletion Settings", -16)
    MakeLabel(self, "If enabled, items on this list will be deleted from your bags.", 16, -44)
    MakeLabel(self, "Add Items by Shift-Clicking an item, drag & drop into the text field below, or type the ItemID and press Add.", 16, -68)


    local delCB = CreateFrame("CheckButton", "EbonholdStuffEnableDeleteCB", self, "InterfaceOptionsCheckButtonTemplate")
    delCB:SetPoint("TOPLEFT", 16, -94)
    delCB:SetChecked(DB.enableDeletion)
    local dt = _G[delCB:GetName() .. "Text"]
    if dt then
        dt:SetText("Enable Item Deletion")
        dt:SetWidth(420)
        dt:SetJustifyH("LEFT")
    end
    delCB:SetScript("OnClick", function()
        DB.enableDeletion = delCB:GetChecked() and true or false
        PlaySound("igMainMenuOptionCheckBoxOn")
    end)


    self.listUI = CreateListUI(self, "Deletion List", "deleteList", 16, -124)
    self.listUI:Refresh()
end)

InterfaceOptions_AddCategory(DeletePanel)

local ScavengerPanel = CreateFrame("Frame", "EbonholdStuffOptionsScavenger", InterfaceOptionsFramePanelContainer)
ScavengerPanel.name = "Scavenger Settings"
ScavengerPanel.parent = "EbonholdStuff"

ScavengerPanel:SetScript("OnShow", function(self)
    EnsureDB()
    if self.inited then
        if self.sumCB then self.sumCB:SetChecked(DB.summonGreedy) end
        if self.delaySlider then self.delaySlider:SetValue(DB.summonDelay or 1.6) end
        if self.muteCB then self.muteCB:SetChecked(DB.muteGreedy) end
        if self.chatCB then self.chatCB:SetChecked(DB.hideGreedyChat) end
        if self.bubCB then self.bubCB:SetChecked(DB.hideGreedyBubbles) end
        return
    end
    self.inited = true

    MakeHeader(self, "Scavenger Settings", -16)
    MakeLabel(self, "Controls summoning and muting of |cffff7f7fGreedy Scavenger|r.", 16, -44)

    local sumCB = CreateFrame("CheckButton", "EbonholdStuffSummonGreedyCB", self, "InterfaceOptionsCheckButtonTemplate")
    sumCB:SetPoint("TOPLEFT", 16, -76)
    sumCB:SetChecked(DB.summonGreedy)
    local st = _G[sumCB:GetName() .. "Text"]
    if st then
        st:SetText("Summon |cffff7f7fGreedy Scavenger|r after Vendoring")
        st:SetWidth(420)
        st:SetJustifyH("LEFT")
    end
    sumCB:SetScript("OnClick", function()
        DB.summonGreedy = sumCB:GetChecked() and true or false
        PlaySound("igMainMenuOptionCheckBoxOn")
    end)
    self.sumCB = sumCB
    
--[[
    local muteCB = AddCheckbox(self, "EbonholdStuffMuteGreedyCB", delaySlider, "Mute |cffff7f7fGreedy Scavenger|r",
        function() return DB.muteGreedy end,
        function(v)
            DB.muteGreedy = v
            if v then
                DB.hideGreedyChat = true
                DB.hideGreedyBubbles = true
            end
            ApplyGreedyChatFilter()
        end,
        -12)
    self.muteCB = muteCB
--]]

    local chatCB = AddCheckbox(self, "EbonholdStuffHideGreedyChatCB", sumCB, "Hide |cffff7f7fGreedy Scavenger|r's chat messages",
        function() return DB.hideGreedyChat end,
        function(v) DB.hideGreedyChat = v; ApplyGreedyChatFilter() end,
        -8)
    self.chatCB = chatCB

    local bubCB = AddCheckbox(self, "EbonholdStuffHideGreedyBubblesCB", chatCB, "Hide |cffff7f7fGreedy Scavenger|r's chat bubbles",
        function() return DB.hideGreedyBubbles end,
        function(v) DB.hideGreedyBubbles = v end,
        -8)
    self.bubCB = bubCB

    local delaySlider = AddSlider(self, "EbonholdStuffSummonDelaySlider", bubCB, "Summon delay", 0.0, 3.0, 0.1,
        function() return DB.summonDelay or 1.6 end,
        function(v) DB.summonDelay = v end,
        -16)
    self.delaySlider = delaySlider
	delaySlider:SetWidth(200)
end)

InterfaceOptions_AddCategory(ScavengerPanel)


local CharPanel = CreateFrame("Frame", "EbonholdStuffOptionsCharacter", InterfaceOptionsFramePanelContainer)
CharPanel.name = "Character Settings"
CharPanel.parent = "EbonholdStuff"

local function CreateNameListUI(parent, titleText, setTableName, x, y)
    local w = (InterfaceOptionsFramePanelContainer and InterfaceOptionsFramePanelContainer:GetWidth() or 640) - 60

    local box = CreateFrame("Frame", nil, parent)
    box:SetPoint("TOPLEFT", x, y)
    box:SetSize(w, 320)

    local title = box:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOPLEFT", 0, 0)
    title:SetText(titleText)

    local input = CreateFrame("EditBox", "EbonholdStuffIDInput_"..setTableName, box, "InputBoxTemplate")
    input:SetAutoFocus(false)
    input:SetSize(180, 20)
    input:SetPoint("TOPLEFT", 0, -24)
    input:SetMaxLetters(24)
    input:SetText("")

    local addBtn = CreateFrame("Button", nil, box, "UIPanelButtonTemplate")
    addBtn:SetSize(60, 20)
    addBtn:SetPoint("LEFT", input, "RIGHT", 8, 0)
    addBtn:SetText("Add")

    local meBtn = CreateFrame("Button", nil, box, "UIPanelButtonTemplate")
    meBtn:SetSize(90, 20)
    meBtn:SetPoint("LEFT", addBtn, "RIGHT", 8, 0)
    meBtn:SetText("Add Me")
    meBtn:SetScript("OnClick", function()
        input:SetText(EHS_GetPlayerName())
        input:HighlightText()
    end)

    local scroll = CreateFrame("ScrollFrame", "EbonholdStuffNameListScroll_"..setTableName, box, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, -54)
    scroll:SetPoint("BOTTOMRIGHT", -26, 8)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)

    local rows = {}
    local function WipeRows()
        for i = 1, #rows do
            rows[i]:Hide()
            rows[i] = nil
        end
    end

    local function SortedNames(t)
        local names = {}
        for k in pairs(t) do
            if type(k) == "string" and k ~= "" then names[#names+1] = k end
        end
        table.sort(names)
        return names
    end

    local function Refresh()
        WipeRows()

        local setTable = DB[setTableName]
        local keys = SortedNames(setTable)

        local rowY = -4
        for i = 1, #keys do
            local name = keys[i]

            local row = CreateFrame("Frame", nil, content)
            row:SetPoint("TOPLEFT", 0, rowY)
            row:SetSize(w - 30, 22)

            local text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            text:SetPoint("LEFT", 2, 0)
            text:SetWidth(w - 120)
            text:SetJustifyH("LEFT")
            text:SetText("|cffb6ffb6"..name.."|r")

            local rm = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            rm:SetSize(72, 18)
            rm:SetPoint("RIGHT", -2, 0)
            rm:SetText("Remove")
            rm:SetScript("OnClick", function()
                DB[setTableName][name] = nil
                Refresh()
            end)

            rows[#rows+1] = row
            rowY = rowY - 22
        end

        content:SetHeight(math.max(1, (#keys * 22) + 8))
    end

    addBtn:SetScript("OnClick", function()
        local v = (input:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if v == "" then
            PlaySound("igMainMenuOptionCheckBoxOff")
            return
        end
        DB[setTableName][v] = true
        input:SetText("")
        Refresh()
        PlaySound("igMainMenuOptionCheckBoxOn")
    end)

    input:SetScript("OnEnterPressed", function()
        addBtn:Click()
        input:ClearFocus()
    end)

    box.Refresh = Refresh
    return box
end

CharPanel:SetScript("OnShow", function(self)
    EnsureDB()
    if self.inited then
        if self.onlyCB then self.onlyCB:SetChecked(DB.enableOnlyListedChars) end
        if self.listUI then self.listUI:Refresh() end
        return
    end
    self.inited = true

    MakeHeader(self, "Character Settings", -16)
    MakeLabel(self, "Prevents this addon from running on characters you didn't intend.", 16, -44)
    MakeLabel(self, "If enabled, EbonholdStuff runs only on characters listed below.", 16, -66)

    local cb = CreateFrame("CheckButton", "EbonholdStuffEnableOnlyListedCharsCB", self, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 16, -82)
    cb:SetChecked(DB.enableOnlyListedChars)

    local t = _G[cb:GetName() .. "Text"]
    if t then
        t:SetText("Enable Only for Listed Characters")
        t:SetWidth(420)
        t:SetJustifyH("LEFT")
    end

    cb:SetScript("OnClick", function()
        DB.enableOnlyListedChars = cb:GetChecked() and true or false
        PlaySound("igMainMenuOptionCheckBoxOn")
    end)
    self.onlyCB = cb

    MakeLabel(self, "Add names: Type + Enter, click Add, or use Add Me for the current character.", 16, -108)

    self.listUI = CreateNameListUI(self, "Allowed Characters", "allowedChars", 16, -138)
    self.listUI:Refresh()
end)

InterfaceOptions_AddCategory(CharPanel)

SLASH_EBONHOLDSTUFF1 = "/ehs"
SlashCmdList["EBONHOLDSTUFF"] = function()
    InterfaceOptionsFrame_OpenToCategory(MainOptions)
    InterfaceOptionsFrame_OpenToCategory(MainOptions)
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGOUT")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("MERCHANT_SHOW")
f:RegisterEvent("MERCHANT_CLOSED")

f:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        EnsureDB()
        HookDeletePopupOnce()
        if ApplyGreedyChatFilter then ApplyGreedyChatFilter() end
    elseif event == "PLAYER_LOGOUT" then
        if DB then EbonholdStuffDB = DB end
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        EnsureDB()
        if EHS_InstallGreedyMuteOnce then EHS_InstallGreedyMuteOnce() end

    elseif event == "MERCHANT_SHOW" then
        EnsureDB()
        if not EHS_IsAddonEnabledForChar() then
            return
        end
        EHS_InstallGreedyMuteOnce()
        if UnitExists("target") and UnitName("target") == TARGET_NAME then
            StartRun()
        end

    elseif event == "MERCHANT_CLOSED" then
        running = false
        worker:Hide()
        pendingDelete = nil
    end
    if event == "PLAYER_LOGIN" then
        EHS_Delay(1, function()
            DEFAULT_CHAT_FRAME:AddMessage("|cffffd100EbonholdStuff Enabled|r - Use |cff00ff00/ehs|r to configure.")
        end)
	end
end)
