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

            Folder = "Xyneria_DQSupport",

            Size = UDim2.fromOffset(
                600,
                420
            ),
OpenButton = {
    Title = "DQ",
    Enabled = true,
    Draggable = true
}

            Theme = "Xyneria",

            HideSearchBar = true,

            OpenButton = {
                Title = "DQ",
                Enabled = true,
                Draggable = true
            }
        })

State.Interface = Window


local main =
    Window:Section({
        Title = "SUPPORT",
        Opened = true
    })


local tab =
    main:Tab({
        Title = "Companion",
        Icon = "heart"
    })



local playerSection =
    tab:Section({
        Title = "Main Account",
        Box = true,
        Opened = true
    })



local dropdownPlayers = {}

for _,player in ipairs(
    Players:GetPlayers()
) do

    if player ~= Players.LocalPlayer then

        table.insert(
            dropdownPlayers,
            player.Name
        )

    end
end



playerSection:Dropdown({

    Title = "Select Main Account",

    Values = dropdownPlayers,

    Value = State.MainAccount,

    Callback = function(value)

        State.MainAccount = value

    end
})



    playerSection:Button({

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

                Title = "Players refreshed",

                Content =
                    tostring(#list)
                    .. " players found",

                Duration = 3

            })

        end
    })




    local settings =
        tab:Section({

            Title = "Settings",

            Box = true,

            Opened = true

        })



    settings:Toggle({

        Title = "Enable Helper",

Value = State.Enabled,

        Callback = function()

State.Enabled = v

        end

    })



local settings = tab:Section({
    Title = "Settings"
})

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



settings:Slider({

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



local status =
    tab:Section({

        Title = "Status",

        Box = true

    })


status:Paragraph({

    Title = "Current Mode",

    Content = function()

        return State.Mode or "WAITING"

    end

})

        end

    })
print(
    "FULL UI CREATED"
)


end



return UI
