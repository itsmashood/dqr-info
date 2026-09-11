local UI = {}

local Players = game:GetService("Players")


local WIND_URL =
    "https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"



function UI:Create()

    local State = self.State

    if not State then
        warn("UI missing State")
        return
    end


    local WindUI =
        loadstring(
            game:HttpGet(WIND_URL)
        )()



    local Window =
        WindUI:CreateWindow({

            Title = "DUNGEON QUEST",

            Author = "XYNERIA",

            Version = "SUPPORT",

            Folder = "DQ_SUPPORT",

            Size = UDim2.fromOffset(
                600,
                420
            ),

            Theme = "Dark",

            OpenButton = {
                Title = "DQ",
                Enabled = true,
                Draggable = true
            }

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



    local function GetPlayers()

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

        return list

    end



    Tab:Dropdown({

        Title = "Select Main Account",

        Values = GetPlayers(),

        Callback = function(value)

            State.MainAccount = value

            print(
                "Main Account:",
                value
            )

        end

    })



    Tab:Button({

        Title = "Refresh Players",

        Callback = function()

            WindUI:Notify({

                Title = "Players",

                Content =
                    "Player list refreshed",

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

        Callback = function(value)

            State.Enabled = value

            print(
                "Enabled:",
                value
            )

        end

    })



    Tab:Slider({

        Title = "Follow Distance",

        Value = {

            Min = 5,

            Max = 50,

            Default = State.FollowDistance

        },

        Callback = function(value)

            State.FollowDistance = value

        end

    })



    Tab:Slider({

        Title = "Heal Threshold",

        Value = {

            Min = 10,

            Max = 95,

            Default = State.HealThreshold

        },

        Callback = function(value)

            State.HealThreshold = value

        end

    })



    Tab:Section({

        Title = "Status"

    })



    Tab:Paragraph({

        Title = "Current Mode",

        Content = function()

            return State.Mode or "WAITING"

        end

    })



    print(
        "FULL UI CREATED"
    )


end



return UI
