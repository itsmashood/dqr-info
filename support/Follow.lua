local M = {}

function M:Follow()
    local root = self:GetMainRoot()
    local c,myRoot,hum = self:GetCharacter()

    if not root or not myRoot or not hum then return end

    local distance = (root.Position - myRoot.Position).Magnitude

    if distance > self.State.FollowDistance then
        hum:MoveTo(root.Position)
    end
end

return M
