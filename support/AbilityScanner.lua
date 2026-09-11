local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local AbilityScanner = {}


local function getAbilityFromImage(imageId)

    for _, ability in ipairs(
        ReplicatedStorage.abilities:GetChildren()
    ) do

        local img =
            ability:FindFirstChild("imageId")


        if img and img.Value == imageId then

            return ability

        end

    end

    return nil

end



local function getSlotData(slotName, gui)

    if not gui then
        return nil
    end


    local image =
        gui:FindFirstChild("imageId")


    if not image then

        local itemType =
            gui:FindFirstChild("itemType")

        if itemType then
            image =
                itemType:FindFirstChild("imageId")
        end

    end


    if not image then
        return nil
    end


    local ability =
        getAbilityFromImage(
            image.Value
        )


    if not ability then
        return nil
    end



    local cooldown = 0


    local cooldownValue =
        ability:FindFirstChild("cooldownLength")


    if cooldownValue then
        cooldown =
            cooldownValue.Value
    end



    return {

        Slot = slotName,

        Name = ability.Name,

        Object = ability,

        Cooldown = cooldown

    }

end



function AbilityScanner:GetEquipped()

    local results = {}


    local inventory =
        player.PlayerGui:FindFirstChild("inventory")


    if not inventory then
        return results
    end



    local left =
        inventory
        .mainBackground
        .innerBackground
        .leftSideFrame



    local slots = {

        {
            Name = "q",
            Gui = left.qAbility
        },

        {
            Name = "e",
            Gui = left.eAbility
        }

    }



    for _,slot in ipairs(slots) do


        local data =
            getSlotData(
                slot.Name,
                slot.Gui
            )


        if data then

            table.insert(
                results,
                data
            )

        end

    end



    return results

end



return AbilityScanner