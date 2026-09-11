local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Heal = {}


local healingAbilities = {

    ["Universal Heal"] = true,
    ["Chain Heal"] = true,
    ["Rejuvenating Spray"] = true,
    ["Life Pulse"] = true,
    ["Aura of Life"] = true,
    ["Revitalize"] = true,
    ["Guardian's Blessing"] = true,
    ["Innervate"] = true

}



local cooldowns = {}



function Heal:IsHealingAbility(ability)

    return healingAbilities[ability.Name] == true

end



function Heal:GetBestHeal(abilities)

    for _,ability in ipairs(abilities) do

        if self:IsHealingAbility(ability) then

            return ability

        end

    end

    return nil

end



function Heal:CanCast(ability)

    local last =
        cooldowns[ability.Name]
        or 0


    local now =
        os.clock()


    return (
        now - last
    ) >= ability.Cooldown

end



function Heal:Cast(ability)

    if not self:CanCast(ability) then
        return false
    end


    local remote =
        ReplicatedStorage
        .remotes
        .abilityUsed


    remote:FireServer(
        ability.Slot,
        ability.Name
    )


    cooldowns[ability.Name] =
        os.clock()


    return true

end



return Heal