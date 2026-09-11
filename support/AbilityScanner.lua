local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Scanner = {}
local player = Players.LocalPlayer

local function resolve(image)
    local folder = ReplicatedStorage:FindFirstChild("abilities")
    if not folder then return end

    for _,a in ipairs(folder:GetChildren()) do
        local id=a:FindFirstChild("imageId")
        if id and id.Value==image then
            return a
        end
    end
end

function Scanner:GetEquipped()
    local out={}
    local gui=player:FindFirstChild("PlayerGui")
    local inv=gui and gui:FindFirstChild("inventory")
    local left=inv and inv:FindFirstChild("mainBackground")
        and inv.mainBackground:FindFirstChild("innerBackground")
        and inv.mainBackground.innerBackground:FindFirstChild("leftSideFrame")

    if not left then return out end

    for _,slot in ipairs({"qAbility","eAbility","qAbility2","eAbility2"}) do
        local obj=left:FindFirstChild(slot)
        if obj then
            local img=obj:FindFirstChild("imageId") or obj:FindFirstChild("itemImage")
            if img then
                local a=resolve(img.Value)
                if a then
                    table.insert(out,{
                        Slot=slot:sub(1,1),
                        Name=a.Name,
                        Object=a,
                        Cooldown=(a:FindFirstChild("cooldownLength") and a.cooldownLength.Value or 0)
                    })
                end
            end
        end
    end

    return out
end

return Scanner
