

local addonName, addon = ...;

local playerUnitToken = "player";


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