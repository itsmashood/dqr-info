local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer


local AbilityScanner = {}


local function getAbilityFromImage(image)

    for _,ability in ipairs(
        ReplicatedStorage.abilities:GetChildren()
    ) do

        local img =
            ability:FindFirstChild("imageId")


        if img and img.Value == image then

            return ability

        end

    end

end



function AbilityScanner:GetEquipped()

    local abilities = {}


    local slots = {
        {
            name = "q",
            gui =
            player.PlayerGui.inventory.mainBackground.innerBackground.leftSideFrame.qAbility
        },

        {
            name = "e",
            gui =
            player.PlayerGui.inventory.mainBackground.innerBackground.leftSideFrame.eAbility
        }
    }



    for _,slot in ipairs(slots) do


        local image =
            slot.gui:FindFirstChild("imageId")
            or slot.gui.itemType:FindFirstChild("imageId")


        if image then


            local ability =
                getAbilityFromImage(
                    image.Value
                )


            if ability then

                table.insert(
                    abilities,
                    {
                        Slot = slot.name,
                        Name = ability.Name,
                        Object = ability,
                        Cooldown =
                            ability.cooldownLength.Value
                    }
                )

            end

        end

    end


    return abilities

end



return AbilityScanner