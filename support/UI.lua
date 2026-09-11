local UI = {}

local Players = game:GetService("Players")


local WIND_URL =
"https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"



function UI:Create()


    local State = self.State or {}


    local WindUI =
        loadstring(
            game:HttpGet(WIND_URL)
        )()



    local Window =
        WindUI:CreateWindow({

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



    local Tab =
        Window:Tab({

            Title = "Companion",

            Icon = "heart"

        })



    Tab:Section({
        Title = "Main Account"
    })



    local players = {}

    for _,p in ipairs(Players:GetPlayers()) do

        if p ~= Players.LocalPlayer then

            table.insert(
                players,
                p.Name
            )

        end

    end



    Tab:Dropdown({

        Title = "Select Main Account",

        Values = players,

        Callback = function(v)

            State.MainAccount = v

        end

    })



    Tab:Button({

        Title = "Refresh",

        Callback = function()

            WindUI:Notify({

                Title = "Players",

                Content = "Refreshed",

                Duration = 3

            })

        end

    })



    Tab:Section({
        Title = "Settings"
    })



    Tab:Toggle({

        Title = "Enable Helper",

        Default = State.Enabled,

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


    print("UI CREATED SUCCESSFULLY")


end



return UI
