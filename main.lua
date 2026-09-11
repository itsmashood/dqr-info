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

local Support = {State = State}
ENV.DQ_SUPPORT_V1 = State

local BASE = "https://raw.githubusercontent.com/itsmashood/dqr-info/support-companion/support/"

for _,name in ipairs({
    "Movement",
    "AbilityScanner",
    "Heal",
    "Follow",
    "Recovery",
    "Dodge",
    "UI"
}) do
    local ok,mod = pcall(function()
        local src = game:HttpGet(BASE..name..".lua")
        return loadstring(src)()
    end)
    if ok and type(mod)=="table" then
        for k,v in pairs(mod) do
            Support[k]=v
        end
    end
end

function Support:GetMainPlayer()
    return State.MainAccount and Players:FindFirstChild(State.MainAccount)
end

function Support:GetMainRoot()
    local p=self:GetMainPlayer()
    return p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
end

function Support:GetCharacter()
    local c=LP.Character
    if not c then return end
    return c,c:FindFirstChild("HumanoidRootPart"),c:FindFirstChildOfClass("Humanoid")
end

function Support:Heal()
    if not self.AbilityScanner or not self.HealCast then return end
end

function Support:Start()
    if self.UI then self.UI:Create() end
    if self.SetupRespawn then self:SetupRespawn() end

    task.spawn(function()
        while State.Alive do
            task.wait(.25)
            if State.Enabled then
                local _,root,hum=self:GetCharacter()
                if hum and hum.Health>0 then
                    if self.Follow then self:Follow() end
                    if self.CheckHazards then self:CheckHazards() end
                    State.Mode="FOLLOWING"
                else
                    State.Mode="DEAD"
                end
            end
        end
    end)
end

Support:Start()
return Support
