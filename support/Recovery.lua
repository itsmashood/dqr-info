local Recovery = {}


local Players = game:GetService("Players")

local LP = Players.LocalPlayer



local recovering = false



function Recovery:ReturnToMain()

    local State = self.State


    if recovering then
        return
    end


    if not State.MainAccount then
        return
    end



    recovering = true

    State.Mode = "RETURNING"



    task.spawn(function()


        while State.Alive do


            local character =
                LP.Character


            local humanoid =
                character
                and character:FindFirstChildOfClass(
                    "Humanoid"
                )


            local root =
                character
                and character:FindFirstChild(
                    "HumanoidRootPart"
                )



            local mainRoot =
                self:GetMainRoot()



            if humanoid
                and root
                and humanoid.Health > 0
                and mainRoot then


                local distance =
                    (
                        mainRoot.Position
                        -
                        root.Position
                    ).Magnitude



                if distance <= State.FollowDistance then

                    State.Mode =
                        "FOLLOWING"

                    recovering = false

                    return

                end



                self:MoveTo(
                    mainRoot.Position
                )


            end


            task.wait(.5)

        end


    end)

end





function Recovery:SetupRespawn()


    LP.CharacterAdded:Connect(function()


        task.wait(3)


        if self.State.ReturnAfterDeath then

            self:ReturnToMain()

        end


    end)

end



return Recovery
