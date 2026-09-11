local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Scanner={}
local player=Players.LocalPlayer

local function resolve(image)
    for _,a in ipairs(ReplicatedStorage.abilities:GetChildren()) do
        local id=a:FindFirstChild("imageId")
        if id and id.Value==image then return a end
    end
end

function Scanner:GetEquipped()
    local out={}
    local left=player.PlayerGui.inventory.mainBackground.innerBackground.leftSideFrame
    for _,s in ipairs({{"q",left.qAbility},{"e",left.eAbility}}) do
        local img=s[2]:FindFirstChild("imageId")
        if img then
            local a=resolve(img.Value)
            if a then
                table.insert(out,{Slot=s[1],Name=a.Name,Object=a,Cooldown=(a.cooldownLength and a.cooldownLength.Value or 0)})
            end
        end
    end
    return out
end

return Scanner
