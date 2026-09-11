local Movement = {}

local PathfindingService =
    game:GetService("PathfindingService")


local currentPath = nil
local waypointIndex = 0
local lastDestination = nil
local lastProgress = 0
local lastPosition = nil



function Movement:MoveTo(position)

    local character,
        root,
        humanoid =
            self:GetCharacter()


    if not character
        or not root
        or not humanoid then

        return

    end



    if not position then
        return
    end



    local distance =
        (
            position
            -
            root.Position
        ).Magnitude



    -- close enough

    if distance < 5 then

        humanoid:Move(
            Vector3.zero
        )

        return

    end



    -- create a new path if destination changed

    if not lastDestination
        or (
            lastDestination
            -
            position
        ).Magnitude > 8 then


        currentPath =
            PathfindingService:CreatePath({

                AgentRadius = 3,

                AgentHeight = 6,

                AgentCanJump = true,

                WaypointSpacing = 4

            })



        currentPath:ComputeAsync(
            root.Position,
            position
        )


        waypointIndex = 1

        lastDestination = position


    end



    if currentPath
        and currentPath.Status
            == Enum.PathStatus.Success then


        local waypoints =
            currentPath:GetWaypoints()


        local waypoint =
            waypoints[waypointIndex]


        if waypoint then


            if waypoint.Action
                ==
                Enum.PathWaypointAction.Jump then

                humanoid.Jump = true

            end



            humanoid:MoveTo(
                waypoint.Position
            )



            if (
                waypoint.Position
                -
                root.Position
            ).Magnitude < 4 then

                waypointIndex += 1

            end


        end

    else

        -- fallback

        humanoid:MoveTo(position)

    end



    -- stuck detection

    if lastPosition then

        local moved =
            (
                root.Position
                -
                lastPosition
            ).Magnitude


        if moved < 0.5 then

            currentPath = nil

        end

    end



    lastPosition =
        root.Position


end



return Movement
