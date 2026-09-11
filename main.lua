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

for _,name in ipairs({"Movement","AbilityScanner","Heal","Follow","Recovery","Dodge","UI"}) do
    local ok,mod = pcall(function()
        local src = game:HttpGet(BASE..name..".lua")
        local fn = loadstring(src)
        if not fn then error("loadstring failed") end
        return fn()
    end)

    if ok and type(mod)=="table" then
        Support[name] = mod
        print("Loaded:",name)
    else
        warn("FAILED:",name,mod)
    end
end

function Support:GetMainPlayer()
    return State.MainAccount and Players:FindFirstChild(State.MainAccount)
end

function Support:GetMainRoot()
    local p = self:GetMainPlayer()
    return p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
end

function Support:GetCharacter()
    local c = LP.Character
    if not c then return end
    return c, c:FindFirstChild("HumanoidRootPart"), c:FindFirstChildOfClass("Humanoid")
end

-- Give every module access to the shared controller functions/state.
for _,name in ipairs({"Follow","Movement","Recovery","Dodge","Heal"}) do
    local mod = Support[name]
    if type(mod) == "table" then
        mod.State = State
        mod.GetCharacter = function()
            return Support:GetCharacter()
        end
        mod.GetMainRoot = function()
            return Support:GetMainRoot()
        end
        mod.GetMainPlayer = function()
            return Support:GetMainPlayer()
        end
    end
end

function Support:Start()
    task.wait(2)

    if self.UI then
        self.UI.State = State
        local ok,err = pcall(function()
            self.UI:Create()
        end)
        if not ok then
            warn("UI CREATE FAILED:", err)
        end
    else
        warn("UI MODULE MISSING")
    end

    task.spawn(function()
        while State.Alive do
            task.wait(.25)

            if State.Enabled then
                local _,root,hum = self:GetCharacter()

                if hum and hum.Health > 0 then

                    if self.Follow and self.Follow.Follow then
                        self.Follow:Follow()
                    end

                    if self.Heal and self.Heal.TryHeal then
                        pcall(function()
                            self.Heal:TryHeal(self.AbilityScanner)
                        end)
                    end

                    if self.Dodge and self.Dodge.CheckHazards then
                        pcall(function()
                            self.Dodge:CheckHazards()
                        end)
                    end

                    State.Mode = "FOLLOWING"
                else
                    State.Mode = "DEAD"
                end
            end
        end
    end)
end

Support:Start()
return Support
