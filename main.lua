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



-- IMPORTANT:
-- support-companion branch
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


    task.spawn(function()


        local url =
            BASE .. name .. ".lua"


        print(
            "Loading:",
            url
        )


        local ok,mod = pcall(function()


            local source =
                game:HttpGet(url)


            local func =
                loadstring(source)


            if not func then
                error(
                    "loadstring failed"
                )
            end


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


    end)

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


    local char =
        player.Character


    if not char then
        return nil
    end


    return char:FindFirstChild(
        "HumanoidRootPart"
    )


end




function Support:GetCharacter()


    local char =
        LP.Character


    if not char then
        return
    end


    return
        char,
        char:FindFirstChild("HumanoidRootPart"),
        char:FindFirstChildOfClass("Humanoid")

end




function Support:Heal()


    if not self.AbilityScanner then
        return
    end


    if not self.CastHeal then
        return
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
