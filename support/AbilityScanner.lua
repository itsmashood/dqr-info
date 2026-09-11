local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local AbilityScanner = {}



local function getAbilitiesFolder()

    return ReplicatedStorage:FindFirstChild("abilities")

end





local function findAbility(image)

    local folder = getAbilitiesFolder()

    if not folder then
        return nil
    end



    for _,ability in ipairs(folder:GetChildren()) do


        local img =
            ability:FindFirstChild("imageId")


        if img and img.Value == image then

            return ability

        end


    end


    return nil

end






local function scanSlot(name,gui)


    if not gui then
        return nil
    end



    local image =
        gui:FindFirstChild("imageId")



    if not image then
        return nil
    end



    local ability =
        findAbility(image.Value)



    if not ability then
        return nil
    end



    local cooldown = 0


    local cd =
        ability:FindFirstChild("cooldownLength")


    if cd then
        cooldown = cd.Value
    end



    return {

        Slot = name,

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
        return results
    end



    local left =
        inventory
        :FindFirstChild("mainBackground")
        and inventory.mainBackground
        :FindFirstChild("innerBackground")
        and inventory.mainBackground.innerBackground
        :FindFirstChild("leftSideFrame")



    if not left then
        return results
    end




    local slots = {

        {"q", left:FindFirstChild("qAbility")},

        {"e", left:FindFirstChild("eAbility")},

        {"q2", left:FindFirstChild("qAbility2")},

        {"e2", left:FindFirstChild("eAbility2")}

    }




    for _,slot in ipairs(slots) do


        local data =
            scanSlot(
                slot[1],
                slot[2]
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
