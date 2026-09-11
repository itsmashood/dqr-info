local M = {}

function M:Heal()
    local main = self:GetMainPlayer()
    if not main or not main.Character then return end

    local hum = main.Character:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    local hp = hum.Health / hum.MaxHealth * 100

    if hp <= self.State.HealThreshold then
        -- Ability casting hook goes here.
        -- Uses live ability detection from the original project.
    end
end

return M
