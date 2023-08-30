local ItemSplit = CreateFrame("Frame","ItemSplit",UIParent)
ItemSplit:RegisterEvent("ITEM_LOCK_CHANGED")

-----------------------------------------------------------

local progressbarFrame = CreateFrame("Frame", "ItemSplitBorder", UIParent)
progressbarFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
progressbarFrame:SetWidth(256)
progressbarFrame:SetHeight(64)
progressbarTexture = progressbarFrame:CreateTexture(nil, "OVERLAY")
progressbarTexture:SetPoint("CENTER", progressbarFrame, "CENTER", 0, 0)
progressbarTexture:SetTexture("Interface\\CastingBar\\UI-CastingBar-Border")
progressbarTexture:SetWidth(256)
progressbarTexture:SetHeight(64)

local progressbar = CreateFrame("StatusBar", "ItemSplitProgressBar", progressbarFrame)
progressbar:SetPoint("CENTER", progressbarFrame, "CENTER", 0, 0)
progressbar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
progressbar:SetStatusBarColor(1, .8, 0, 1)
progressbar:SetWidth(195)
progressbar:SetHeight(13)

progressbarSpark = progressbar:CreateTexture(nil, "OVERLAY")
progressbarSpark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
progressbarSpark:SetWidth(32)
progressbarSpark:SetHeight(32)
progressbarSpark:SetBlendMode("ADD")

progressbarText = progressbar:CreateFontString(nil, "HIGH", "GameFontWhite")
progressbarText:SetPoint("CENTER", progressbar, "CENTER", 0, 0)
local font, size, opts = progressbarText:GetFont()
progressbarText:SetFont(font, size - 2, "THINOUTLINE")
progressbarText:SetText("ItemSplit: Pickup any item to cancel")

-----------------------------------------------------------

local OngoingProcess = false
local OngoingitemName = nil
local OngoingStackSize = 0
local OngoingDoneCount = 0
local OngoingTotalCount = 0
local itemSplitTick = -1
progressbarFrame:Hide()

-----------------------------------------------------------

local function PlaceInEmptySlot()
	for bag = 0, 4 do
		for slot = 1, GetContainerNumSlots(bag) do
			local _, itemCount, locked, _, _ = GetContainerItemInfo(bag, slot)
			if not itemCount or itemCount == 0 then
				PickupContainerItem(bag, slot)
				return true
			end
		end
	end
	return false
end

-----------------------------------------------------------

local function LargestStack(name)

	local itemLink = nil
	local LargestStackSize = 0
	local LargestStackBag = nil
	local LargestStackSlot = nil
	local isLocked = 0
	local TotalCount = 0
	
    for bag = 4, 0, -1 do
        for slot = GetContainerNumSlots(bag), 1, -1 do
		
            local _, bagitemCount, bagitemLocked, _, _ = GetContainerItemInfo(bag, slot)
			local bagitemLink = GetContainerItemLink(bag, slot)
            if bagitemLink then
                local _, _, bagitemName = string.find(string.lower(bagitemLink), "%[(.+)%]")
				if bagitemName == name then
					TotalCount = TotalCount + bagitemCount
					if bagitemCount > LargestStackSize then
						itemLink = bagitemLink
						LargestStackSize = bagitemCount
						LargestStackBag = bag
						LargestStackSlot = slot
						if bagitemLocked then isLocked = true else isLocked = false end
					end
				end
            end
        end
    end
	return itemLink, LargestStackBag, LargestStackSlot, LargestStackSize, isLocked, TotalCount
end

--------------------------------------------------

function AbortItemSplit()
	ClearCursor()
	OngoingProcess = false
	OngoingitemName = nil
	OngoingStackSize = 0
	OngoingDoneCount = 0
	OngoingTotalCount = 0
	itemSplitTick = -1
	progressbarFrame:Hide()
end
--------------------------------------------------

function SplitItems_OnUpdate()

	if OngoingProcess == false then
		return
	end
	
	if itemSplitTick < 1 and itemSplitTick > -1 then
		itemSplitTick = itemSplitTick + arg1
		return
	end

	local itemLink, LargestStackBag, LargestStackSlot, LargestStackSize, isLocked, TotalCount = LargestStack(OngoingitemName)
	
	if CursorHasItem() then
		AbortItemSplit()
		DEFAULT_CHAT_FRAME:AddMessage("|cffFF0000ItemSplit|cffFFFFFF: Aborted. You picked up an item.")
		return
	end
	
	if isLocked then -- wait item to unlock
		return 
	end
	
	-- Terminate split if no more stacks
	if LargestStackSize <= OngoingStackSize then
		AbortItemSplit()
		DEFAULT_CHAT_FRAME:AddMessage("|cffFF0000ItemSplit|cffFFFFFF: No more stacks to split")
		return
	end

	SplitContainerItem(LargestStackBag,LargestStackSlot,OngoingStackSize)

	if CursorHasItem() then
		if PlaceInEmptySlot() then
			OngoingDoneCount = OngoingDoneCount + OngoingStackSize
			progressbar:SetValue(OngoingDoneCount)
			local sparkpoint = 195 * OngoingDoneCount / OngoingTotalCount
			progressbarSpark:SetPoint("CENTER", progressbar, "LEFT", sparkpoint, 0)
		else
			AbortItemSplit()
			DEFAULT_CHAT_FRAME:AddMessage("|cffFF0000ItemSplit|cffFFFFFF: Inventory is full!")
		end
	end
	itemSplitTick = -1

end

-----------------------------------------------------------

function SplitItems_OnEvent()
	if OngoingProcess == false then
		return
	end
	itemSplitTick = 0
end

-----------------------------------------------------------

local function InitiateSplit(name, stacksize)
	local itemLink, LargestStackBag, LargestStackSlot, LargestStackSize, isLocked, TotalCount = LargestStack(name)
	if TotalCount > 0 then
	
		OngoingProcess = true
		OngoingitemName = name
		OngoingStackSize = stacksize
		OngoingTotalCount = TotalCount
		OngoingDoneCount = 0
		progressbar:SetMinMaxValues(0, OngoingTotalCount)
		progressbar:SetValue(OngoingDoneCount)
		progressbarFrame:Show()

		DEFAULT_CHAT_FRAME:AddMessage("|cffFF0000ItemSplit|cffFFFFFF: Splitting "..itemLink.." (count: "..TotalCount..") into stacks of " ..stacksize)
		SplitItems_OnEvent()
	else
		DEFAULT_CHAT_FRAME:AddMessage("|cffFF0000ItemSplit|cffFFFFFF: Found no item named "..name)
	end
end

-----------------------------------------------------------

function SplitCommand(cmd)
	AbortItemSplit()
	if cmd == nil or cmd == "" then
		DEFAULT_CHAT_FRAME:AddMessage("/split {stacksize} {itemname}")
		return
	end
	
	cmd = string.lower(cmd)
	local _, _, sizearg, namearg = string.find(cmd, "(%d+)%s(.+)")
	sizearg = tonumber(sizearg)
	if sizearg and namearg then
		local x, y, z = string.find(namearg, "%[(.+)%]") -- If the player types an item link, converts it to raw item name.
		if x then namearg = z end
		InitiateSplit(namearg, sizearg)
	else
		DEFAULT_CHAT_FRAME:AddMessage("/split {stacksize} {itemname}")
	end
end

SLASH_ITEMSPLIT1 = '/split'
SlashCmdList.ITEMSPLIT = SplitCommand

-----------------------------------------------------------

function MergeCommand(cmd)
	AbortItemSplit()
	if cmd == nil or cmd == "" then
		DEFAULT_CHAT_FRAME:AddMessage("/merge {itemname}")
		return
	end
	
	cmd = string.lower(cmd)
	local x, y, z = string.find(cmd, "%[(.+)%]") -- If the player types an item link, converts it to raw item name.
	if x then cmd = z end
	
	local itemLink, LargestStackBag, LargestStackSlot, LargestStackSize, isLocked, TotalCount = LargestStack(cmd)
	if TotalCount > 0 then
		DEFAULT_CHAT_FRAME:AddMessage("|cffFF0000ItemSplit|cffFFFFFF: merging stacks of "..itemLink)
		for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
			local bagitemLink = GetContainerItemLink(bag, slot)
			if bagitemLink then
				local _, _, bagitemName = string.find(string.lower(bagitemLink), "%[(.+)%]")
				if bagitemName == cmd then
					PickupContainerItem(bag, slot)
					if bag == 0 then PutItemInBag(20) else PutItemInBackpack() end
				end
			end
		end
	end
	else
		DEFAULT_CHAT_FRAME:AddMessage("|cffFF0000ItemSplit|cffFFFFFF: Found no item named "..cmd)
	end
end

SLASH_ITEMMERGE1 = '/merge'
SlashCmdList.ITEMMERGE = MergeCommand

-----------------------------------------------------------

ItemSplit:SetScript("OnEvent", function() SplitItems_OnEvent() end)
ItemSplit:SetScript("OnUpdate", function() SplitItems_OnUpdate() end)