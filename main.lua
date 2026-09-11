local Players = game:GetService("Players")

local LP = Players.LocalPlayer

local ENV = (getgenv and getgenv()) or _G


local State = {

    Alive = true,

    Enabled = true,

    MainAccount = nil,

    FollowDistance = 12,

    HealThreshold = 60,

    Mode = "WAITING"

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


    local ok,mod = pcall(function()

        local url =
            BASE .. name .. ".lua"


        print(
            "Loading:",
            url
        )


        local source =
            game:HttpGet(url)


        local func =
            loadstring(source)


        return func()

    end)



    if ok and type(mod) == "table" then


        print(
            "Loaded:",
            name
        )


        for k,v in pairs(mod) do

            Support[k] = v

        end


    else


        warn(
            "FAILED:",
            name,
            mod
        )


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


    local p =
        self:GetMainPlayer()


    if not p then
        return nil
    end


    local c =
        p.Character


    if not c then
        return nil
    end


    return c:FindFirstChild(
        "HumanoidRootPart"
    )


end





function Support:GetCharacter()


    local c =
        LP.Character


    if not c then
        return
    end


    return
        c,
        c:FindFirstChild("HumanoidRootPart"),
        c:FindFirstChildOfClass("Humanoid")

end





function Support:Heal()


    if not self.AbilityScanner then
        return
    end


    local abilities =
        self.AbilityScanner:GetEquipped()


    print(
        "===== HEAL CHECK ====="
    )


    for _,ability in ipairs(abilities) do

        print(
            ability.Slot,
            ability.Name,
            ability.Cooldown
        )

    end


end





function Support:Start()


    task.wait(1)



    if self.UI and self.UI.Create then

        self.UI:Create()

    end



    if self.SetupRespawn then

        self:SetupRespawn()

    end



    -- Ability scanner test

    if self.AbilityScanner then


        print(
            "===== ABILITY TEST ====="
        )


        local abilities =
            self.AbilityScanner:GetEquipped()



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


        print(
            "===== END ABILITY TEST ====="
        )


    end





    task.spawn(function()


        while State.Alive do


            task.wait(0.25)



            if State.Enabled then



                local _,root,hum =
                    self:GetCharacter()



                if hum and hum.Health > 0 then



                    if self.Follow then

                        self:Follow()

                    end



                    if self.CheckHazards then

                        self:CheckHazards()

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


return Support
