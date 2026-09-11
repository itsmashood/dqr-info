-- Dungeon Quest Support Companion
-- Main loader

local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local ENV = (getgenv and getgenv()) or _G

local State = {
    Alive = true,
    Enabled = true,
    MainAccount = nil,
    FollowDistance = 12,
    HealThreshold = 60,
    HealInterval = 2,
    AvoidHazards = true,
    ReturnAfterDeath = true,
    Mode = "WAITING",
    Connections = {}
}

ENV.DQ_SUPPORT_V1 = State

local Support = {State = State}

local BASE = "https://raw.githubusercontent.com/itsmashood/dqr-info/main/support/"

for _, name in ipairs({
    "Movement",
    "Follow",
    "Heal",
    "Recovery",
    "Dodge",
    "UI"
}) do
    pcall(function()
        local src = game:HttpGet(BASE .. name .. ".lua")
        local fn = loadstring(src)
        if fn then
            local module = fn()
            if type(module) == "table" then
                for k,v in pairs(module) do
                    Support[k] = v
                end
            end
        end
    end)
end

function Support:GetMainPlayer()
    if not State.MainAccount then return nil end
    return Players:FindFirstChild(State.MainAccount)
end

function Support:GetMainRoot()
    local p = self:GetMainPlayer()
    if not p or not p.Character then return nil end
    return p.Character:FindFirstChild("HumanoidRootPart")
end

function Support:GetCharacter()
    local c = LP.Character
    if not c then return end
    local r = c:FindFirstChild("HumanoidRootPart")
    local h = c:FindFirstChildOfClass("Humanoid")
    return c,r,h
end

function Support:Start()
    if self.UI then self.UI:Create() end

    task.spawn(function()
        while State.Alive do
            task.wait(.25)

            if State.Enabled then
                local c,r,h = self:GetCharacter()

                if not c or not h or h.Health <= 0 then
                    State.Mode = "DEAD"
                    if self:ReturnToMain then
                        self:ReturnToMain()
                    end
                else
                    if self.Follow then self:Follow() end
                    if self.Heal then self:Heal() end
                    if self.CheckHazards then self:CheckHazards() end
                    State.Mode = "FOLLOWING"
                end
            end
        end
    end)
end

Support:Start()
return Support
