local UI = {}

local Players = game:GetService("Players")


local WIND_URL =
    "https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"



function UI:Create()


    local State =
        self.State or _G.DQ_SUPPORT_V1



    local ok,WindUI = pcall(function()

        return loadstring(
            game:HttpGet(WIND_URL)
        )()

    end)



    if not ok then

        warn(
            "WindUI failed:",
            WindUI
        )

        return

    end




    local Window = WindUI:CreateWindow({

        Title = "DUNGEON QUEST",

        Author = "XYNERIA",

        Version = "SUPPORT",

        Folder = "Xyneria_DQSupport",

        Size = UDim2.fromOffset(
            600,
            420
        ),

        Theme = "Dark"

    })



    State.Interface = Window



    local Tab = Window:Tab({

        Title = "Companion",

        Icon = "heart"

    })



    Tab:Section({

        Title = "Main Account"

    })



    local players = {}


    for _,player in ipairs(
        Players:GetPlayers()
    ) do


        if player ~= Players.LocalPlayer then

            table.insert(
                players,
                player.Name
            )

        end

    end




    Tab:Dropdown({

        Title = "Select Main Account",

        Values = players,

        Callback = function(value)

            State.MainAccount = value

        end

    })





    Tab:Button({

        Title = "Refresh Players",

        Callback = function()


            local list = {}


            for _,player in ipairs(
                Players:GetPlayers()
            ) do


                if player ~= Players.LocalPlayer then

                    table.insert(
                        list,
                        player.Name
                    )

                end

            end


            WindUI:Notify({

                Title = "Players",

                Content =
                    tostring(#list)
                    .. " found",

                Duration = 3

            })


        end

    })






    Tab:Section({

        Title = "Settings"

    })




    Tab:Toggle({

        Title = "Enable Helper",

        Value = State.Enabled,


        Callback = function(v)

            State.Enabled = v

        end

    })




    Tab:Slider({

        Title = "Follow Distance",

        Step = 1,

        Value = {

            Min = 5,

            Max = 50,

            Default = State.FollowDistance

        },


        Callback = function(v)

            State.FollowDistance = v

        end

    })





    Tab:Slider({

        Title = "Heal Threshold",

        Step = 1,

        Value = {

            Min = 10,

            Max = 95,

            Default = State.HealThreshold

        },


        Callback = function(v)

            State.HealThreshold = v

        end

    })




    Tab:Paragraph({

        Title = "Status",

        Content = function()

            return "Mode: "
                .. tostring(State.Mode)

        end

    })



end




return UI
