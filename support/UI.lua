local UI = {}

local Players = game:GetService("Players")

local WIND_URL =
    "https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"

function UI:Create()
    local State = self.State or {}

    local src = game:HttpGet(WIND_URL)
    local loader = loadstring(src)

    if not loader then
        error("WindUI loadstring failed")
    end

    local WindUI = loader()

    local Window = WindUI:CreateWindow({
        Title = "DUNGEON QUEST",
        Author = "XYNERIA",
        Version = "SUPPORT",
        Folder = "Xyneria_DQSupport",
        Size = UDim2.fromOffset(600, 420),
        Theme = "Dark",
        HideSearchBar = true,
        OpenButton = {
            Title = "DQ",
            Enabled = true,
            Draggable = true
        }
    })

    State.Interface = Window

    local tab = Window:Tab({
        Title = "Companion",
        Icon = "heart"
    })

    local playerSection = tab:Section({
        Title = "Main Account",
        Box = true
    })

    local function getPlayers()
        local list = {}

        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= Players.LocalPlayer then
                table.insert(list, player.Name)
            end
        end

        return list
    end

    playerSection:Dropdown({
        Title = "Select Main Account",
        Values = getPlayers(),
        Value = State.MainAccount,
        Callback = function(value)
            State.MainAccount = value
        end
    })

    playerSection:Button({
        Title = "Refresh Players",
        Callback = function()
            WindUI:Notify({
                Title = "Players",
                Content = tostring(#getPlayers()) .. " found",
                Duration = 3
            })
        end
    })

    local settings = tab:Section({
        Title = "Settings",
        Box = true
    })

    settings:Toggle({
        Title = "Enable Helper",
        Value = State.Enabled ~= false,
        Callback = function(v)
            State.Enabled = v
        end
    })

    settings:Slider({
        Title = "Follow Distance",
        Value = {
            Min = 5,
            Max = 50,
            Default = State.FollowDistance or 12
        },
        Callback = function(v)
            State.FollowDistance = v
        end
    })

    settings:Slider({
        Title = "Heal Threshold",
        Value = {
            Min = 10,
            Max = 95,
            Default = State.HealThreshold or 60
        },
        Callback = function(v)
            State.HealThreshold = v
        end
    })

    local status = tab:Section({
        Title = "Status",
        Box = true
    })

    status:Paragraph({
        Title = "Mode",
        Content = function()
            return State.Mode or "WAITING"
        end
    })
end

return UI