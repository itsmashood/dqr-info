local Follow = {}

local last = 0

function Follow:Follow()
    local State = self.State
    if not State or not State.MainAccount then return end

    local target = self:GetMainRoot()
    local _, root, hum = self:GetCharacter()
    if not target or not root or not hum then return end

    local distance = (target.Position-root.Position).Magnitude
    local desired = State.FollowDistance or 12

    if distance <= desired then
        hum:Move(Vector3.zero)
        return
    end

    if os.clock()-last < 0.15 then return end
    last=os.clock()

    hum:Move((target.Position-root.Position).Unit)
end

return Follow
