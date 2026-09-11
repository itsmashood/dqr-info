local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Heal = {}

local cooldowns = {}



local function isHeal(name)

    if not name then
        return false
    end


    local lower =
        string.lower(name)



    return
        string.find(lower,"heal")
        or string.find(lower,"life")
        or string.find(lower,"rejuven")
        or string.find(lower,"revitalize")
        or string.find(lower,"aura")

end





function Heal:TryHeal(scanner)


    if not scanner then

        warn(
            "Heal: scanner missing"
        )

        return

    end




    local abilities =
        scanner:GetEquipped()



    print(
        "===== HEAL SCAN ====="
    )



    for _,ability in ipairs(abilities) do



        print(
            "FOUND:",
            ability.Name,
            "SLOT:",
            ability.Slot,
            "CD:",
            ability.Cooldown
        )



        if isHeal(ability.Name) then



            local last =
                cooldowns[ability.Name] or 0



            if os.clock() - last >= ability.Cooldown then



                print(
                    "CASTING HEAL:",
                    ability.Name
                )



                local object =
                    ability.Object



                local event =
                    object and object:FindFirstChild(
                        "abilityEvent"
                    )



                if event and event:IsA("RemoteEvent") then



                    event:FireServer()



                    cooldowns[ability.Name] =
                        os.clock()


                    return true


                else


                    warn(
                        "No abilityEvent for",
                        ability.Name
                    )


                end


            end


        end


    end



    print(
        "===== END HEAL SCAN ====="
    )



end



return Heal
