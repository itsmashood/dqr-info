local Follow = {}


local lastMove = 0



function Follow:Follow()


    local State = self.State


    if not State.MainAccount then
        return
    end



    local mainRoot =
        self:GetMainRoot()


    if not mainRoot then
        return
    end



    local character,
        myRoot,
        humanoid =
            self:GetCharacter()



    if not character
        or not myRoot
        or not humanoid then

        return

    end



    local distance =
        (
            mainRoot.Position
            -
            myRoot.Position
        ).Magnitude



    local desired =
        State.FollowDistance



    -- already close enough

    if distance <= desired then

        humanoid:Move(
            Vector3.zero
        )

        return

    end



    -- throttle movement updates

    if os.clock() - lastMove < 0.5 then

        return

    end


    lastMove = os.clock()



    local direction =
        (
            mainRoot.Position
            -
            myRoot.Position
        ).Unit



    humanoid:Move(
        direction
    )


end



return Follow
