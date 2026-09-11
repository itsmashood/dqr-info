local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local AbilityScanner = {}



local function getAbilitiesFolder()

    local folder =
        ReplicatedStorage:FindFirstChild("abilities")


    if not folder then

        warn(
            "AbilityScanner: ReplicatedStorage.abilities missing"
        )

        return nil

    end


    return folder

end





local function getAbilityFromImage(imageId)


    local folder =
        getAbilitiesFolder()


    if not folder then
        return nil
    end



    for _,ability in ipairs(folder:GetChildren()) do


        local img =
            ability:FindFirstChild("imageId")


        if img and img.Value == imageId then

            return ability

        end


    end


    return nil

end





local function readSlot(slotName, gui)


    if not gui then
        return nil
    end



    local image =
        gui:FindFirstChild("imageId")



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


    local cd =
        ability:FindFirstChild("cooldownLength")


    if cd then

        cooldown =
            cd.Value

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



    local gui =
        player:FindFirstChild("PlayerGui")


    if not gui then

        return results

    end




    local inventory =
        gui:FindFirstChild("inventory")


    if not inventory then

        warn(
            "AbilityScanner: inventory missing"
        )

        return results

    end





    local main =
        inventory:FindFirstChild("mainBackground")


    if not main then
        return results
    end



    local inner =
        main:FindFirstChild("innerBackground")


    if not inner then
        return results
    end



    local left =
        inner:FindFirstChild("leftSideFrame")


    if not left then
        return results
    end




    local slots = {

        {
            Name = "q",
            Gui = left:FindFirstChild("qAbility")
        },


        {
            Name = "e",
            Gui = left:FindFirstChild("eAbility")
        }

    }





    for _,slot in ipairs(slots) do


        local data =
            readSlot(
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
