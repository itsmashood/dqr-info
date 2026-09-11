local Players = game:GetService("Players")

local LP = Players.LocalPlayer

local ENV = (getgenv and getgenv()) or _G


local State = {

    Alive = true,
    Enabled = true,
    MainAccount = nil,
    FollowDistance = 12,
    HealThreshold = 60,
    Mode = "WAITING",
    Interface = nil

}



local Support = {
    State = State
}


ENV.DQ_SUPPORT_V1 = State



local BASE =
    "https://raw.githubusercontent.com/itsmashood/dqr-info/support-companion/support/"



local Modules = {

    "Movement",
    "AbilityScanner",
    "Heal",
    "Follow",
    "Recovery",
    "Dodge",
    "UI"

}




for _,name in ipairs(Modules) do


    local success,mod = pcall(function()


        local url =
            BASE .. name .. ".lua"



        print(
            "Loading:",
            url
        )



        local source =
            game:HttpGet(url)



        local chunk =
            loadstring(source)



        if not chunk then

            error(
                "loadstring failed"
            )

        end



        return chunk()



    end)




    if success and type(mod) == "table" then


        print(
            "Loaded:",
            name
        )



        -- give every module access to shared state

        mod.State = State



        Support[name] = mod



    else


        warn(
            "FAILED MODULE:",
            name
        )


        warn(mod)


    end


end





function Support:GetMainPlayer()


    if not State.MainAccount then
        return nil
    end


    return Players:FindFirstChild(
        State.MainAccount
    )


end





function Support:GetMainRoot()


    local player =
        self:GetMainPlayer()


    if not player then
        return nil
    end



    local character =
        player.Character


    if not character then
        return nil
    end



    return character:FindFirstChild(
        "HumanoidRootPart"
    )


end





function Support:GetCharacter()


    local character =
        LP.Character


    if not character then
        return nil
    end



    return
        character,
        character:FindFirstChild("HumanoidRootPart"),
        character:FindFirstChildOfClass("Humanoid")


end





function Support:Heal()


    if not self.AbilityScanner then
        return
    end



    local ok,abilities =
        pcall(function()

            return self.AbilityScanner:GetEquipped()

        end)



    if not ok then

        warn(
            "Ability scan failed:",
            abilities
        )

        return

    end



    print(
        "===== HEAL CHECK ====="
    )



    for _,ability in ipairs(abilities) do


        print(
            "SLOT:",
            ability.Slot,
            "NAME:",
            ability.Name,
            "COOLDOWN:",
            ability.Cooldown
        )


    end



end






function Support:DebugAbilities()


    print(
        "===== ABILITY DEBUG ====="
    )



    if not self.AbilityScanner then


        warn(
            "AbilityScanner missing"
        )


        return


    end




    local ok,abilities =
        pcall(function()

            return self.AbilityScanner:GetEquipped()

        end)




    if ok and abilities then


        print(
            "FOUND:",
            #abilities
        )



        for _,ability in ipairs(abilities) do


            print(
                "SLOT:",
                ability.Slot,
                "NAME:",
                ability.Name,
                "COOLDOWN:",
                ability.Cooldown
            )


        end



    else


        warn(
            "Ability scan failed:",
            abilities
        )


    end



    print(
        "===== END ABILITY DEBUG ====="
    )


end






function Support:Start()



    task.wait(1)



    if self.UI and self.UI.Create then


        local ok,err =
            pcall(function()

                self.UI:Create()

            end)



        if not ok then


            warn(
                "UI failed:",
                err
            )


        end


    end





    if self.SetupRespawn then


        pcall(function()

            self:SetupRespawn()

        end)


    end





    task.spawn(function()


        task.wait(3)


        self:DebugAbilities()


    end)







    task.spawn(function()



        while State.Alive do



            task.wait(0.25)




            if State.Enabled then



                local _,root,hum =
                    self:GetCharacter()



                if hum and hum.Health > 0 then



                    if self.Follow then


                        pcall(function()

                            self:Follow()

                        end)


                    end





                    if self.CheckHazards then


                        pcall(function()

                            self:CheckHazards()

                        end)


                    end




                    self:Heal()



                    State.Mode =
                        "FOLLOWING"



                else



                    State.Mode =
                        "DEAD"



                end



            end



        end



    end)



end





Support:Start()


print(
    "DQ Support loaded successfully"
)


return Support
