local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Heal={}
local cd={}
local names={Universal=true}

local function isHeal(n)
    return n:find("Heal") or n=="Life Pulse" or n=="Aura of Life" or n=="Revitalize" or n=="Rejuvenating Spray"
end

function Heal:TryHeal(scanner)
    local abilities=scanner:GetEquipped()
    for _,a in ipairs(abilities) do
        if isHeal(a.Name) then
            if not cd[a.Name] or os.clock()-cd[a.Name]>=a.Cooldown then
                ReplicatedStorage.remotes.abilityUsed:FireServer(a.Slot,a.Name)
                cd[a.Name]=os.clock()
                return true
            end
        end
    end
end
return Heal
