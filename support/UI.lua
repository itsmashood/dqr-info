local UI = {}

local Players = game:GetService("Players")


local WIND_URL =
"https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"



function UI:Create()

    print("UI START")


    local State = self.State or {}


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


    print("WindUI loaded")



    local ok2,Window = pcall(function()

        return WindUI:CreateWindow({

            Title = "DUNGEON QUEST",

            Author = "XYNERIA",

            Version = "SUPPORT",

            Folder = "DQ_SUPPORT",

            Size = UDim2.fromOffset(
                600,
                400
            )

        })

    end)


    if not ok2 then

        warn(
            "Window failed:",
            Window
        )

        return

    end


    print("Window created")



    local Tab =
        Window:Tab({

            Title = "Companion",

            Icon = "heart"

        })


    print("Tab created")



    Tab:Button({

        Title = "Test Button",

        Callback = function()

            print(
                "GUI WORKS"
            )

        end

    })


    Tab:Dropdown({

        Title = "Main Account",

        Values = {},

        Callback = function(v)

            State.MainAccount = v

        end

    })


    print(
        "UI COMPLETE"
    )


end


return UI
