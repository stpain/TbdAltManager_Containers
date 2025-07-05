

local addonName, addon = ...;

local playerUnitToken = "player";

local function ExtractLink(text)
	-- linkType: |H([^:]*): matches everything that's not a colon, up to the first colon.
	-- linkOptions: ([^|]*)|h matches everything that's not a |, up to the first |h.
	-- displayText: (.*)|h matches everything up to the second |h.
	-- Ex: |cffffffff|Htype:a:b:c:d|htext|h|r becomes type, a:b:c:d, text
	return string.match(text, [[|H([^:]*):([^|]*)|h(.*)|h]]);
end


if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then
	-- mainline
elseif WOW_PROJECT_ID == WOW_PROJECT_CATACLYSM_CLASSIC then
	-- cata
elseif WOW_PROJECT_ID == WOW_PROJECT_CLASSIC then
	-- vanilla
end






--Global namespace for the module so addons can interact with it
TbdAltManager_Containers = {}

--Callback registry
TbdAltManager_Containers.CallbackRegistry = CreateFromMixins(CallbackRegistryMixin)
TbdAltManager_Containers.CallbackRegistry:OnLoad()
TbdAltManager_Containers.CallbackRegistry:GenerateCallbackEvents({
    "Character_OnAdded",
    "Character_OnChanged",
    "Character_OnRemoved",

    "DataProvider_OnInitialized",
})



local characterDefaults = {
    uid = "",
    containers = {},
}


--Main DataProvider for the module
local CharacterDataProvider = CreateFromMixins(DataProviderMixin)

function CharacterDataProvider:InsertCharacter(characterUID)

    local character = self:FindElementDataByPredicate(function(characterData)
        return (characterData.uid == characterUID)
    end)

    if not character then        
        local newCharacter = {}
        for k, v in pairs(characterDefaults) do
            newCharacter[k] = v
        end

        newCharacter.uid = characterUID

        self:Insert(newCharacter)
        TbdAltManager_Containers.CallbackRegistry:TriggerEvent("Character_OnAdded")
    end
end

function CharacterDataProvider:FindCharacterByUID(characterUID)
    return self:FindElementDataByPredicate(function(character)
        return (character.uid == characterUID)
    end)
end

function CharacterDataProvider:GetContainerDataForItemID(itemID)

    local ret = {}

    for _, character in self:EnumerateEntireRange() do
        for _, container in pairs(character.containers) do
            if #container.items > 0 then
                for _, item in ipairs(container.items) do
                    if item.link:match("item:%d+", itemID) then
                        table.insert(ret, {
                            characterUID = character.uid,
                            bag = character.containers[0].name,
                            item = item,
                        })
                    end
                end
                -- local _itemID = C_Item.GetItemInfoInstant(item.link)
                -- if _itemID == itemID then
                --     table.insert(ret, {
                --         characterUID = character.uid,
                --         bag = character.containers[0].name,
                --         item = item,
                --     })
                -- end
            end
        end
    end

    return ret;
end

function CharacterDataProvider:GetContainerDataForItemLink(itemLink)

end

function CharacterDataProvider:GetContainerData(searchTerm, checkItemType, checkItemSubType)
    local ret = {}

    for _, character in self:EnumerateEntireRange() do
        for _, container in pairs(character.containers) do
            if #container.items > 0 then
                for _, item in ipairs(container.items) do
                    if item.link:find(searchTerm, nil, true) then
                        table.insert(ret, {
                            characterUID = character.uid,
                            bag = container.name,
                            item = item,
                        })
                    end

                    if checkItemType or checkItemSubType then
                        local itemID, itemType, itemSubType, equipLocation = C_Item.GetItemInfoInstant(item.link)
                        if checkItemType then
                            if itemType:find(searchTerm, nil, true) then
                                table.insert(ret, {
                                    characterUID = character.uid,
                                    bag = container.name,
                                    item = item,
                                })
                            end
                        end
                        if checkItemSubType then
                            if itemSubType:find(searchTerm, nil, true) then
                                table.insert(ret, {
                                    characterUID = character.uid,
                                    bag = container.name,
                                    item = item,
                                })
                            end
                        end
                    end
                end
            end
        end
    end

    return ret;
end

function CharacterDataProvider:GetContainerDataForItemName(itemName)
    return self:GetContainerData(itemName)
end







--Expose some api via the namespace
TbdAltManager_Containers.Api = {}

function TbdAltManager_Containers.Api.EnumerateCharacters()
    return CharacterDataProvider:EnumerateEntireRange()
end

function TbdAltManager_Containers.Api.GetCharacterContainerData(characterUID)
    return CharacterDataProvider:FindCharacterByUID(characterUID)
end

function TbdAltManager_Containers.Api.DeleteCharacterByCharacterUID(characterUID)
    CharacterDataProvider:RemoveByPredicate(function(character)
        return (character.uid == characterUID)
    end)
    TbdAltManager_Containers.CallbackRegistry:TriggerEvent("Character_OnRemoved", characterUID)
end

function TbdAltManager_Containers.Api.DeleteContainerDataForCharacter(characterUID)
    local character = CharacterDataProvider:FindCharacterByUID(characterUID)
    if character and character.containers then
        character.containers = {}
        TbdAltManager_Containers.CallbackRegistry:TriggerEvent("Character_OnChanged", character)
    end
end

function TbdAltManager_Containers.Api.GetContainerDataForItem(item)

    if tonumber(item) then
        return CharacterDataProvider:GetContainerDataForItemID(tonumber(item))
    else
        if item:find("|Hitem:", nil, true) then
            return CharacterDataProvider:GetContainerDataForItemLink(item)
        -- elseif item:find("#", nil, true) then
            -- local arg1, arg2 = strsplit(" ", item)
            -- arg1 = arg1:sub(2)
            -- if type(arg1) == "string" then
            --     if type(arg2) == "string" then
            --         return CharacterDataProvider:GetContainerData(item)
            --     end
            -- end
        else
            return CharacterDataProvider:GetContainerDataForItemName(item)
        end
    end
    
end







local eventsToRegister = {
    "ADDON_LOADED",
    "PLAYER_ENTERING_WORLD",
    "BAG_UPDATE_DELAYED",
    "BAG_UPDATE",
    "PLAYER_INTERACTION_MANAGER_FRAME_SHOW",
    "PLAYERBANKSLOTS_CHANGED"
}

--Frame to setup event listening
local ContainerEventFrame = CreateFrame("Frame")
for _, event in ipairs(eventsToRegister) do
    ContainerEventFrame:RegisterEvent(event)
end
ContainerEventFrame:SetScript("OnEvent", function(self, event, ...)
    if self[event] then
        self[event](self, ...)
    end
end)

function ContainerEventFrame:SetContainerData(bagIndex, data)
    if self.character and self.character.containers then
        self.character.containers[bagIndex] = data;
        TbdAltManager_Containers.CallbackRegistry:TriggerEvent("Character_OnChanged", self.character)
        --print("updated", bagIndex, data)
    end
end

function ContainerEventFrame:ADDON_LOADED(...)
    if (... == addonName) then
        if TbdAltManager_Containers_SavedVariables == nil then

            CharacterDataProvider:Init({})
            TbdAltManager_Containers_SavedVariables = CharacterDataProvider:GetCollection()
    
        else
    
            local data = TbdAltManager_Containers_SavedVariables
            CharacterDataProvider:Init(data)
            TbdAltManager_Containers_SavedVariables = CharacterDataProvider:GetCollection()
    
        end

        if not CharacterDataProvider:IsEmpty() then
            TbdAltManager_Containers.CallbackRegistry:TriggerEvent("DataProvider_OnInitialized")
        end
    end
end

function ContainerEventFrame:ResetCharacterData(characterUID)
    local character = CharacterDataProvider:FindCharacterByUID(characterUID)
    if character then
        for k, v in pairs(characterDefaults) do
            character[k] = v
        end
        self:ScanTradeskills()
        TbdAltManager_Containers.CallbackRegistry:TriggerEvent("Character_OnChanged")
    end
end

function ContainerEventFrame:PLAYER_ENTERING_WORLD()
    
    local account = "Default"
    local realm = GetRealmName()
    local name = UnitName(playerUnitToken)

    self.characterUID = string.format("%s.%s.%s", account, realm, name)

    CharacterDataProvider:InsertCharacter(self.characterUID)

    self.character = CharacterDataProvider:FindCharacterByUID(self.characterUID)

end

function ContainerEventFrame:BAG_UPDATE(...)
    local bagIndex = ...;
    if tonumber(bagIndex) then
        local containerData = self:GetContainerDataForBagIndex(bagIndex)
        if containerData then
            self:SetContainerData(bagIndex, containerData)
        end
    end
end

function ContainerEventFrame:PLAYER_INTERACTION_MANAGER_FRAME_SHOW(...)
    if ... == 8 then
        local bankIndex = -1;
        local containerData = self:GetContainerDataForBagIndex(bankIndex)
        if containerData then
            self:SetContainerData(bankIndex, containerData)
        end

        for bagIndex = 6, 12 do
            local containerData = self:GetContainerDataForBagIndex(bagIndex)
            if containerData then
                self:SetContainerData(bagIndex, containerData)
            end
        end
    end
end

function ContainerEventFrame:PLAYERBANKSLOTS_CHANGED(slotIndex)
    local bankIndex = -1;
    local containerData = self:GetContainerDataForBagIndex(bankIndex)
    if containerData then
        self:SetContainerData(bankIndex, containerData)
    end
end

function ContainerEventFrame:BAG_UPDATE_DELAYED()
    for bagIndex = 0, 4 do
        local containerData = self:GetContainerDataForBagIndex(bagIndex)
        if containerData then
            self:SetContainerData(bagIndex, containerData)
        end
    end
end

function ContainerEventFrame:GetContainerDataForBagIndex(bagIndex)

    local container = {}
    local bagName = ""

    if bagIndex == 0 then
        bagName = BACKPACK_TOOLTIP
    elseif bagIndex == -1 then
        bagName = BANK
    else
        bagName = C_Container.GetBagName(bagIndex)
    end

    local bagSlotCount = C_Container.GetContainerNumSlots(bagIndex)

    container = {
        name = bagName or bagName,
        numSlots = bagSlotCount,
        items = {},
    }

    for slot = 1, bagSlotCount do
    
        local slotInfo = C_Container.GetContainerItemInfo(bagIndex, slot)

        if slotInfo and slotInfo.hyperlink then
            table.insert(container.items, {
                link = slotInfo.hyperlink,
                count = slotInfo.stackCount,
            })

            --print(bagIndex, slot, slotInfo.hyperlink)
        end
    end

    return container;
end

function ContainerEventFrame:ScanPlayerReagentBank()
    
end

function ContainerEventFrame:ScanPlayerWarbandBank()
    
end










































TbdAltManagerContainersModuleTreeviewItemTemplateMixin = {}
function TbdAltManagerContainersModuleTreeviewItemTemplateMixin:OnLoad()
    self:SetScript("OnLeave", function()
        GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
    end)
end

function TbdAltManagerContainersModuleTreeviewItemTemplateMixin:UpdateToggledTextures(node)
    if node:IsCollapsed() then
        self.ParentRight:SetAtlas("Options_ListExpand_Right")
    else
        self.ParentRight:SetAtlas("Options_ListExpand_Right_Expanded")
    end
end

function TbdAltManagerContainersModuleTreeviewItemTemplateMixin:SetDataBinding(binding, height, node)

    self:SetHeight(height)

    if binding.isParent then
        self.ParentLeft:Show()
        self.ParentRight:Show()
        self.ParentMiddle:Show()

    else
        self.Background:SetAtlas(binding.backgroundAtlas)
    end

    if binding.label then
        self.LinkLabel:SetText(binding.label)
    end

    self:SetScript("OnMouseDown", function(_, button)
        if button == "RightButton" then
            --context menu
        else
            node:ToggleCollapsed()
            self:UpdateToggledTextures(node)
        end
    end)

    if binding.deleteContainerData then
        self.DeleteContainerDataButton:SetSize(height - 2, height - 2)
        self.DeleteContainerDataButton:SetScript("OnClick", binding.deleteContainerData)
        --self.DeleteContainerDataButton:Show()
    end

    if binding.link and not binding.isParent then

        self:SetScript("OnEnter", function()
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:SetHyperlink(binding.link)
            GameTooltip:Show()
        end)

        self.LinkLabel:SetText(string.format("%s %s", binding.slotStackCount, binding.link))

        self.ClassLabel:SetText(C_Item.GetItemClassInfo(binding.classID))
        self.SubClassLabel:SetText(C_Item.GetItemSubClassInfo(binding.classID, binding.subClassID))


        -- local item = Item:CreateFromItemLink(binding.link)
        -- if not item:IsItemEmpty() then
        --     item:ContinueOnItemLoad(function()

        --         local subType = item:GetInventoryType()
                
        --         self.typeLabel:SetText()
        --     end)
        -- end
    end

end
function TbdAltManagerContainersModuleTreeviewItemTemplateMixin:ResetDataBinding()
    self.ParentLeft:Hide()
    self.ParentRight:Hide()
    self.ParentMiddle:Hide()
    self.DeleteContainerDataButton:Hide()
    self.DeleteContainerDataButton:SetScript("OnClick", nil)
    self.onMouseDown = nil

    self:SetScript("OnEnter", nil)

    self.LinkLabel:SetText("")

    self.ClassLabel:SetText("")
    self.SubClassLabel:SetText("")

    self.Background:SetTexture(nil)
end






local function SortContainerItems(item1, item2)
    local a = item1:GetData()
    local b = item2:GetData()

    --DevTools_Dump({a, b})

    if a.name and a.quality and b.name and b.quality and a.classID and b.classID and a.subClassID and b.subClassID then
        if a.classID == b.classID then
            if a.subClassID == b.subClassID then
                if a.quality == b.quality then
                    return a.name < b.name;
                else
                    return a.quality > b.quality;
                end
            else
                return a.subClassID < b.subClassID
            end
        else
            return a.classID < b.classID
        end
    end
end





TbdAltManagerContainersMixin = {
    name = "Containers",
    menuEntry = {
        height = 40,
        template = "TbdAltManagerSideBarListviewItemTemplate",
        initializer = function(frame)
            frame.Label:SetText("Containers")
            frame.Icon:SetAtlas("bag-main")
            frame:SetScript("OnMouseUp", function()
                TbdAltsManager.Api.SelectModule("Containers")
            end)
            TbdAltsManager.Api.SetupSideMenuItem(frame, false, false)
        end,
    }
}

function TbdAltManagerContainersMixin:OnLoad()
    TbdAltsManager.Api.RegisterModule(self)

    self.dataProvider = CreateTreeDataProvider()
    self.dataProvider:Init({})
    self.Treeview.scrollView:SetDataProvider(self.dataProvider)

    self.treeviewNodes = {}

    self.dataReady = false;

    self.SearchEditBox.ok:SetScript("OnClick", function()
        self:SearchForItem(self.searchEditBox:GetText())
    end)
    self.SearchEditBox:SetScript("OnEnterPressed", function(editbox)
        self:SearchForItem(editbox:GetText())
    end)
    self.SearchEditBox.cancel:SetScript("OnClick", function(editbox)
        editbox:SetText("")
        self.Treeview.scrollView:SetDataProvider(self.dataProvider)
    end)

    TbdAltManager_Containers.CallbackRegistry:RegisterCallback("DataProvider_OnInitialized", self.OnDataInitialized, self)
    TbdAltManager_Containers.CallbackRegistry:RegisterCallback("Character_OnRemoved", self.LoadContainerData, self)
    TbdAltManager_Containers.CallbackRegistry:RegisterCallback("Character_OnChanged", self.UpdateDataProviderForCharacter, self)
end

function TbdAltManagerContainersMixin:OnShow()
    if (self.dataReady == true) and (next(self.treeviewNodes) == nil) then
        self:LoadContainerData()
    end
end

function TbdAltManagerContainersMixin:OnDataInitialized()
    self.dataReady = true;
    self:LoadContainerData()
end

function TbdAltManagerContainersMixin:SearchForItem(item)
    
    local data = TbdAltManager_Containers.Api.GetContainerDataForItem(item)

    local tempDataProvider = CreateTreeDataProvider()
    tempDataProvider:Init({})
    self.Treeview.scrollView:SetDataProvider(tempDataProvider)

    local charactersNodes = {}

    --ExtractLink(text)

    local characterItemsbyName = {}

    for _, result in ipairs(data) do
        --local account, realm, name = strsplit(".", result.characterUID)
        if not characterItemsbyName[result.characterUID] then
            characterItemsbyName[result.characterUID] = {}
        end
        local _, _, itemName = ExtractLink(result.item.link)
        if not characterItemsbyName[result.characterUID][itemName] then
            characterItemsbyName[result.characterUID][itemName] = result.item.count
        else
            characterItemsbyName[result.characterUID][itemName] = characterItemsbyName[result.characterUID][itemName] + result.item.count
        end
    end

    for k, result in ipairs(data) do

        local account, realm, name = strsplit(".", result.characterUID)

        if not charactersNodes[result.characterUID] then
            charactersNodes[result.characterUID] = tempDataProvider:Insert({
                label = name,
                isParent = true,
            })
        end

        local _item = Item:CreateFromItemLink(result.item.link)
        if not _item:IsItemEmpty() then
            _item:ContinueOnItemLoad(function()

                local itemID, itemType, itemSubType, itemEquipLoc, icon, classID, subClassID = C_Item.GetItemInfoInstant(result.item.link)

                charactersNodes[result.characterUID]:Insert({
                    link = result.item.link,
                    equipLocation =_G[itemEquipLoc] or "",
                    icon = icon,

                    slotStackCount = result.item.count,

                    backgroundAtlas = "uitools-row-background-02",

                    --sort data
                    classID = classID,
                    subClassID = subClassID,
                    quality = _item:GetItemQuality(),
                    name = _item:GetItemName(),
                })

                --tempDataProvider:Sort()
            end)
        end
    end
end

function TbdAltManagerContainersMixin:LoadItemsForBag(bagNode, bagItems)

    local numItems = #bagItems;

    local index = 1;

    local ticker = C_Timer.NewTicker(0.01, function()

        local itemInfo = bagItems[index]

        local item = Item:CreateFromItemLink(itemInfo.link)
        if not item:IsItemEmpty() then
            item:ContinueOnItemLoad(function()

                local itemID, itemType, itemSubType, itemEquipLoc, icon, classID, subClassID = C_Item.GetItemInfoInstant(itemInfo.link)

                bagNode:Insert({
                    link = itemInfo.link,
                    equipLocation =_G[itemEquipLoc] or "",
                    icon = icon,

                    slotStackCount = itemInfo.count,

                    backgroundAtlas = "uitools-row-background-02",

                    --sort data
                    classID = classID,
                    subClassID = subClassID,
                    quality = item:GetItemQuality(),
                    name = item:GetItemName(),
                })

            end)
        end

        index = index + 1;

        if index == numItems then
            bagNode:Sort()
        end
    
    end, numItems)
    
end


function TbdAltManagerContainersMixin:UpdateDataProviderForCharacter(character)
    
    if not self:IsVisible() then
        return
    end
    
    if self.treeviewNodes[character.uid] then
        self.treeviewNodes[character.uid]:Flush()

        for k, bag in pairs(character.containers) do

            if #bag.items > 0 then
            
                self.treeviewNodes[character.uid][k] = self.treeviewNodes[character.uid]:Insert({
                    label = bag.name,
                    isParent = true,

                })

                self.treeviewNodes[character.uid][k]:SetSortComparator(SortContainerItems)
                self.treeviewNodes[character.uid][k]:ToggleCollapsed()

                self:LoadItemsForBag(self.treeviewNodes[character.uid][k], bag.items)

            end
        end
    end
end

function TbdAltManagerContainersMixin:LoadContainerData()

    if not self:IsVisible() then
        return
    end

    self.dataProvider = CreateTreeDataProvider()
    self.dataProvider:Init({})
    self.Treeview.scrollView:SetDataProvider(self.dataProvider)

    self.treeviewNodes = {}

    for _, character in TbdAltManager_Containers.Api.EnumerateCharacters() do

        local account, realm, name = strsplit(".", character.uid)
        
        self.treeviewNodes[character.uid] = self.dataProvider:Insert({
            label = name,
            isParent = true,
            characterUID = character.uid,

            -- deleteContainerData = function()
            --     TbdAltManager_Containers.Api.DeleteContainerDataForCharacter(character.uid)
            -- end
        })

        self.treeviewNodes[character.uid]:ToggleCollapsed()

        self:UpdateDataProviderForCharacter(character)

    end
end