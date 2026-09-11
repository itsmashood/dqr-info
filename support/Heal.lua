local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Heal = {}
local cooldowns = {}

local function isHeal(name)
    return name and (
        name:find("Heal") or
        name == "Life Pulse" or
        name == "Aura of Life" or
        name == "Revitalize" or
        name == "Rejuvenating Spray"
    )
end

function Heal:TryHeal(scanner)
    if not scanner then return false end

    local abilities = scanner:GetEquipped()

    for _,a in ipairs(abilities) do
        if isHeal(a.Name) then
            local last = cooldowns[a.Name] or 0
            if os.clock()-last >= (a.Cooldown or 0) then
                local remotes = ReplicatedStorage:FindFirstChild("remotes")
                local remote = remotes and remotes:FindFirstChild("abilityUsed")

                if remote then
                    remote:FireServer(a.Slot,a.Name)
                    cooldowns[a.Name]=os.clock()
                    return true
                end
            end
        end
    end

    return false
end

return Heal
