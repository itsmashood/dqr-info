local UI = {}

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")


function UI:Create()

    local State = self.State


    pcall(function()
        local old = CoreGui:FindFirstChild("DQSupportUI")

        if old then
            old:Destroy()
        end
    end)



    local gui = Instance.new("ScreenGui")

    gui.Name = "DQSupportUI"

    gui.Parent = CoreGui



    local frame = Instance.new("Frame")

    frame.Size =
        UDim2.new(0,300,0,260)

    frame.Position =
        UDim2.new(0,20,0,200)

    frame.BackgroundColor3 =
        Color3.fromRGB(25,25,25)

    frame.Parent = gui



    local title = Instance.new("TextLabel")

    title.Size =
        UDim2.new(1,0,0,35)

    title.Text =
        "Dungeon Quest Support"

    title.TextColor3 =
        Color3.new(1,1,1)

    title.BackgroundTransparency = 1

    title.Parent = frame



    local selected = Instance.new("TextLabel")

    selected.Size =
        UDim2.new(1,-20,0,30)

    selected.Position =
        UDim2.new(0,10,0,45)

    selected.Text =
        "Main Account: None"

    selected.TextColor3 =
        Color3.new(1,1,1)

    selected.BackgroundTransparency = 1

    selected.Parent = frame



    local y = 80


    for _,player in ipairs(
        Players:GetPlayers()
    ) do


        if player ~= Players.LocalPlayer then


            local button =
                Instance.new("TextButton")


            button.Size =
                UDim2.new(1,-20,0,30)


            button.Position =
                UDim2.new(0,10,0,y)


            button.Text =
                player.Name


            button.Parent =
                frame



            button.MouseButton1Click:Connect(function()

                State.MainAccount =
                    player.Name


                selected.Text =
                    "Main Account: "
                    ..player.Name

            end)


            y = y + 35

        end

    end



    local refresh =
        Instance.new("TextButton")


    refresh.Size =
        UDim2.new(1,-20,0,30)


    refresh.Position =
        UDim2.new(0,10,0,y)


    refresh.Text =
        "Refresh Players"


    refresh.Parent =
        frame



    refresh.MouseButton1Click:Connect(function()

        gui:Destroy()

        self:Create()

    end)



end


return UI