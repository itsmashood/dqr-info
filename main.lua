--// Dungeon Quest Combat Pilot V7.5
--// Left/right committed dodge + expanding hazard prediction
--// Dense mob-cluster aim + full respawn combat reset
--// Continuous close-range Q/E spam enabled by default
--// Maximum WalkSpeed = 20
--// Startup-safe hazard scan + corrected Beam tracking
--//
--// Q = Inner Focus
--// E = Geyser

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local PathfindingService = game:GetService("PathfindingService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LP = Players.LocalPlayer
local ENV = (getgenv and getgenv()) or _G

--------------------------------------------------
-- SETTINGS
--------------------------------------------------

local ENABLED = true
local AUTO_Q = true
local AUTO_E = true
local AUTO_START = false
local AUTO_REPLAY = false
local AUTO_LOBBY = false

local MAX_SPEED = 20

local CHASE_SPEED = 20
local ORBIT_SPEED = 19.8
local SPACE_SPEED = 20
local EVADE_SPEED = 20
local DODGE_SPEED = 20
local PATH_SPEED = 20
local NEXT_ROOM_SPEED = 20

local DESIRED_DISTANCE = 18
local FORCE_SPACE_ENTER = 14
local FORCE_SPACE_EXIT = 17

local MOB_CLUSTER_RADIUS = 24
local MOB_CLUSTER_STICK_RADIUS = 13

local TARGET_LEASH_DISTANCE = 30
local BOB_LEASH_DISTANCE = 26
local LEASH_INWARD_START = 4
local LEASH_MAX_INWARD = 0.72

local ABILITY_RANGE = 30
local REMOTE_ABILITY_RANGE = 160
local REMOTE_PROGRESS_TIMEOUT = 1.35
local REMOTE_PROGRESS_STEP = 2.0
local REMOTE_CAST_HOLD = 5.0
local FACE_DOT_REQUIRED = 0.93

local PACK_CLEAR_GRACE = 0.55
local SPELL_FALLBACK_COOLDOWN = 8.5
local SPELL_SPAM_INTERVAL = 0.25
local OWN_BUFF_IGNORE_TIME = 1.35
local OWN_BUFF_IGNORE_RADIUS = 16
local SHOW_HAZARD_BOXES = false

local DUNGEON_PROFILE_BASE_URL =
    ENV.DQ_DUNGEON_PROFILE_BASE_URL
    or "https://raw.githubusercontent.com/itsmashood/dungeon-quest-info/main"

--------------------------------------------------
-- PREDICTION
--------------------------------------------------

local BODY_RADIUS = 2.2

local PREDICT_NEAR = 0.24
local PREDICT_FAR = 0.55
local EXPAND_PREDICT = 0.72

local HAZARD_UPDATE_INTERVAL = 0.025
local PLAYER_MOTION_PREDICTION = 0.65
local MAX_ACCEL_PREDICT_OFFSET = 8
local MAX_SIZE_ACCELERATION = 48
local THREAT_PREDICTION_SAMPLES = 7
local EMERGENCY_IMPACT_TIME = 0.28
local FAST_HAZARD_SPEED = 28
local FAST_WARNING_EXTRA = 3.5

local EXPAND_RATE_MIN = 1.25
local EXPAND_WARNING_EXTRA = 9.5
local EXPAND_EMERGENCY_EXTRA = 3.0
local EXPAND_OUTWARD_WEIGHT = 0.32

local WARNING_EXTRA = 7.0
local EMERGENCY_EXTRA = 2.2

local EXIT_EXTRA = 0.8
local ROUTE_EXTRA = 1.2
local DESTINATION_EXTRA = 2.0

--------------------------------------------------
-- HAZARD LIFETIME
--------------------------------------------------

local PRECAST_LIFE = 1.05
local HITBOX_LIFE = 0.50
local ATTACK_LIFE = 0.85
local GENERIC_LIFE = 0.65

local PROJECTILE_LIFE = 1.20
local LASER_PART_LIFE = 5.0

local LASER_PART_MAX_LIFE = 12

local VISUAL_LIFE = 0.35

--------------------------------------------------
-- DODGE
--------------------------------------------------

local DODGE_LOCK = 0.36
local DODGE_REPLAN = 0.05
local EVADE_REPLAN = 0.07
local DODGE_SIDE_RELEASE = 0.65
local QUICK_DODGE_DISTANCE = 10

local DODGE_RADII = {
    8,
    13,
    19,
    27,
    34
}

local EVADE_RADII = {
    7,
    11,
    16
}

local ROUTE_SAMPLES = 7
local TOP_CANDIDATES = 24

--------------------------------------------------
-- PATHING
--------------------------------------------------

local PATH_RECALC = 0.60
local BLOCKED_DELAY = 0.16

local WAYPOINT_DISTANCE = 4

local STUCK_INTERVAL = 0.55
local MIN_PROGRESS = 0.80
local STUCK_RESET_LIMIT = 5
local STATIONARY_DISTANCE = 0.15

--------------------------------------------------
-- CLEAN OLD VERSIONS
--------------------------------------------------

local function stopOld(name)
    local old = ENV[name]

    if not old then
        return
    end

    old.Alive = false

    for _, connection in ipairs(
        old.Connections or {}
    ) do
        pcall(function()
            connection:Disconnect()
        end)
    end

    if old.RenderName then
        pcall(function()
            RunService:UnbindFromRenderStep(
                old.RenderName
            )
        end)
    end

    if old.Interface then
        pcall(function()
            old.Interface:Destroy()
        end)
    end
end

local oldStates = {
    "DQ_AUTO_DODGE_V2",
    "DQ_AUTO_DODGE_V3",
    "DQ_MOVEMENT_V35",
    "DQ_COMBAT_V4",
    "DQ_DODGE_MOVEMENT_V3M",
    "DQ_COMBAT_V5",
    "DQ_COMBAT_V51",
    "DQ_COMBAT_V6",
    "DQ_COMBAT_V61",
    "DQ_COMBAT_V62",
    "DQ_COMBAT_V7",
    "DQ_COMBAT_V71",
    "DQ_COMBAT_V72",
    "DQ_COMBAT_V73",
    "DQ_COMBAT_V74",
    "DQ_COMBAT_V75"
}

for _, name in ipairs(oldStates) do
    stopOld(name)
end

local oldRenderNames = {
    "DQCombatMovement",
    "DQ_DODGE_MOVEMENT_V3M_RENDER",
    "DQ_COMBAT_V5_RENDER",
    "DQ_COMBAT_V51_RENDER",
    "DQ_COMBAT_V6_RENDER",
    "DQ_COMBAT_V61_RENDER",
    "DQ_COMBAT_V62_RENDER",
    "DQ_COMBAT_V7_RENDER",
    "DQ_COMBAT_V71_RENDER",
    "DQ_COMBAT_V72_RENDER",
    "DQ_COMBAT_V73_RENDER",
    "DQ_COMBAT_V74_RENDER",
    "DQ_COMBAT_V75_RENDER"
}

for _, name in ipairs(oldRenderNames) do
    pcall(function()
        RunService:UnbindFromRenderStep(name)
    end)
end

local State = {
    Alive = true,
    Connections = {},
    RenderName = "DQ_COMBAT_V75_RENDER",
    OwnAbilityIgnoreUntil = 0,
    SpacingActive = false,
    SpamSpells = true,
    TargetIsBoss = false,
    BossCheckTarget = nil,
    BossCheckResult = false,
    BossCheckTime = 0
}

ENV.DQ_COMBAT_V75 = State

--------------------------------------------------
-- CLEAN GUI
--------------------------------------------------

pcall(function()
    local names = {
        "DQCombatV4",
        "DQCombatV5",
        "DQCombatV51",
        "DQCombatV6",
        "DQCombatV61",
        "DQCombatV62",
        "DQCombatV7",
        "DQCombatV71",
        "DQCombatV72",
        "DQCombatV73",
        "DQCombatV74",
        "DQCombatV75",
        "XyneriaUI",
        "WindUI"
    }

    for _, name in ipairs(names) do
        local object =
            CoreGui:FindFirstChild(name)

        if object then
            object:Destroy()
        end
    end
end)

--------------------------------------------------
-- HELPERS
--------------------------------------------------

local function connect(signal, callback)
    local connection =
        signal:Connect(callback)

    table.insert(
        State.Connections,
        connection
    )

    return connection
end

local function flat(vector)
    return Vector3.new(
        vector.X,
        0,
        vector.Z
    )
end

local function getCharacter()
    local character =
        LP.Character

    if not character then
        return
    end

    local root =
        character:FindFirstChild(
            "HumanoidRootPart"
        )

    local humanoid =
        character:FindFirstChildOfClass(
            "Humanoid"
        )

    if not root
        or not humanoid
        or humanoid.Health <= 0 then

        return
    end

    return character, root, humanoid
end

local function isPlayerObject(object)
    for _, player in ipairs(
        Players:GetPlayers()
    ) do
        local character =
            player.Character

        if character
            and object:IsDescendantOf(
                character
            ) then

            return true
        end
    end

    return false
end

--------------------------------------------------
-- IGNORE OUR Q / E EFFECTS
--------------------------------------------------

local function isOwnAbility(object)
    local current = object

    for _ = 1, 7 do
        if not current then
            break
        end

        local name =
            string.lower(
                current.Name
            )

        if name:find(
            "geyser",
            1,
            true
        )
            or name:find(
                "innerfocus",
                1,
                true
            )
            or name:find(
                "inner focus",
                1,
                true
            ) then

            return true
        end

        current = current.Parent
    end

    return false
end

local function isRecentOwnBuffEffect(object, kind)
    if kind ~= "GENERIC"
        or os.clock() > State.OwnAbilityIgnoreUntil
        or not object:IsA("BasePart")
        or object.CanCollide then

        return false
    end

    local character, root = getCharacter()

    if not character or not root then
        return false
    end

    return (
        flat(object.Position - root.Position)
    ).Magnitude <= OWN_BUFF_IGNORE_RADIUS
end

--------------------------------------------------
-- DUNGEON
--------------------------------------------------

local dungeon =
    Workspace:FindFirstChild(
        "dungeon"
    )

--------------------------------------------------
-- OPTIONAL DUNGEON PROFILE REPOSITORY
-- manifest.lua chooses a profile by PlaceId/name.
-- A missing repository/profile keeps universal mode.
--------------------------------------------------

local DungeonData = (function()
    local result = {
        Name = "Universal",
        Profile = nil,
        Loaded = false
    }

    local function joinUrl(...)
        local pieces = {...}

        for index, value in ipairs(pieces) do
            value = tostring(value or "")

            if index > 1 then
                value = value:gsub("^/+", "")
            end

            if index < #pieces then
                value = value:gsub("/+$", "")
            end

            pieces[index] = value
        end

        return table.concat(pieces, "/")
    end

    local function compileTable(source, label)
        local compile, compileError =
            loadstring(source)

        if not compile then
            error(
                label
                .. " compile error: "
                .. tostring(compileError)
            )
        end

        local value = compile()

        if type(value) ~= "table" then
            error(label .. " must return a table")
        end

        return value
    end

    local function detectionText()
        local values = {
            tostring(game.PlaceId)
        }

        local function add(value)
            if value ~= nil then
                table.insert(
                    values,
                    string.lower(tostring(value))
                )
            end
        end

        add(Workspace:GetAttribute("DungeonName"))
        add(Workspace:GetAttribute("Dungeon"))

        if dungeon then
            add(dungeon:GetAttribute("DungeonName"))
            add(dungeon:GetAttribute("Name"))
        end

        local playerGui =
            LP:FindFirstChildOfClass("PlayerGui")

        if playerGui then
            for _, object in ipairs(
                playerGui:GetDescendants()
            ) do
                if object:IsA("TextLabel")
                    or object:IsA("TextButton") then

                    local textValue =
                        tostring(object.Text or "")

                    if #textValue > 2
                        and #textValue < 80 then

                        add(textValue)
                    end
                end
            end
        end

        return table.concat(values, " ")
    end

    pcall(function()
        local manifest =
            compileTable(
                game:HttpGet(
                    joinUrl(
                        DUNGEON_PROFILE_BASE_URL,
                        "manifest.lua"
                    )
                ),
                "Dungeon manifest"
            )

        local profileName =
            manifest.PlaceIds
            and (
                manifest.PlaceIds[game.PlaceId]
                or manifest.PlaceIds[
                    tostring(game.PlaceId)
                ]
            )

        if not profileName then
            local blob = detectionText()

            for name, aliases in pairs(
                manifest.Aliases or {}
            ) do
                local candidates = {name}

                if type(aliases) == "table" then
                    for _, alias in ipairs(aliases) do
                        table.insert(candidates, alias)
                    end
                end

                for _, candidate in ipairs(candidates) do
                    if blob:find(
                        string.lower(tostring(candidate)),
                        1,
                        true
                    ) then
                        profileName = name
                        break
                    end
                end

                if profileName then
                    break
                end
            end
        end

        if not profileName then
            return
        end

        local fileName =
            manifest.Profiles
            and manifest.Profiles[profileName]
            or tostring(profileName) .. ".lua"

        fileName = tostring(fileName):gsub(" ", "%%20")

        local profile =
            compileTable(
                game:HttpGet(
                    joinUrl(
                        DUNGEON_PROFILE_BASE_URL,
                        "dungeons",
                        fileName
                    )
                ),
                tostring(profileName)
            )

        result.Name =
            profile.Name
            or tostring(profileName)

        result.Profile = profile
        result.Loaded = true

        local movement = profile.Movement or {}

        DESIRED_DISTANCE =
            tonumber(movement.DesiredDistance)
            or DESIRED_DISTANCE

        FORCE_SPACE_ENTER =
            tonumber(movement.ForceSpaceEnter)
            or FORCE_SPACE_ENTER

        FORCE_SPACE_EXIT =
            math.max(
                tonumber(movement.ForceSpaceExit)
                    or FORCE_SPACE_EXIT,
                FORCE_SPACE_ENTER + 1
            )

        TARGET_LEASH_DISTANCE =
            tonumber(movement.TargetLeashDistance)
            or TARGET_LEASH_DISTANCE

        BOB_LEASH_DISTANCE =
            tonumber(movement.BobLeashDistance)
            or BOB_LEASH_DISTANCE
    end)

    return result
end)()

--------------------------------------------------
-- ENEMY CACHE
--------------------------------------------------

local Enemies = {}
local EnemyFolders = {}

local lastEnemyFallback = 0

local function validEnemy(model)
    if not model
        or not model:IsA("Model")
        or not model.Parent
        or model.Parent.Name
            ~= "enemyFolder" then

        return false
    end

    local humanoid =
        model:FindFirstChildOfClass(
            "Humanoid"
        )

    local root =
        model:FindFirstChild(
            "HumanoidRootPart"
        )

    return humanoid ~= nil
        and humanoid.Health > 0
        and root ~= nil
end

function State:IsBossEnemy(enemy)
    if not validEnemy(enemy) then
        return false
    end

    local now = os.clock()

    if self.BossCheckTarget == enemy
        and now - self.BossCheckTime < 0.50 then

        return self.BossCheckResult
    end

    self.BossCheckTarget = enemy
    self.BossCheckResult = false
    self.BossCheckTime = now

    local profileBosses =
        DungeonData.Profile
        and DungeonData.Profile.BossNames

    if type(profileBosses) == "table" then
        for key, value in pairs(profileBosses) do
            local bossName =
                type(key) == "number"
                and value
                or key

            if string.lower(tostring(bossName))
                == string.lower(enemy.Name) then

                self.BossCheckResult = true
                return true
            end
        end
    end

    local current = enemy

    for _ = 1, 7 do
        if not current then
            break
        end

        local lowerName =
            string.lower(current.Name or "")

        if lowerName:find("boss", 1, true)
            or current:GetAttribute("IsBoss") == true
            or current:GetAttribute("Boss") == true then

            self.BossCheckResult = true
            return true
        end

        local marker =
            current:FindFirstChild("IsBoss")
            or current:FindFirstChild("Boss")

        if marker
            and marker:IsA("BoolValue")
            and marker.Value then

            self.BossCheckResult = true
            return true
        end

        current = current.Parent
    end

    local isTagged = false

    pcall(function()
        isTagged =
            game:GetService("CollectionService"):
            HasTag(enemy, "Boss")
    end)

    if isTagged then
        self.BossCheckResult = true
        return true
    end

    local playerGui =
        LP:FindFirstChildOfClass("PlayerGui")

    if playerGui then
        for _, object in ipairs(
            playerGui:GetDescendants()
        ) do
            if object:IsA("TextLabel")
                and object.Visible
                and string.lower(
                    tostring(object.Text or "")
                ) == string.lower(enemy.Name)
                and object.AbsoluteSize.X >= 140 then

                self.BossCheckResult = true
                return true
            end
        end
    end

    return false
end

local function registerEnemy(model)
    if not model:IsA("Model") then
        return
    end

    task.spawn(function()
        for _ = 1, 50 do
            if not State.Alive
                or not model.Parent then

                return
            end

            if validEnemy(model) then
                Enemies[model] = true
                return
            end

            task.wait(0.04)
        end
    end)
end

local function watchEnemyFolder(folder)
    if EnemyFolders[folder] then
        return
    end

    EnemyFolders[folder] = true

    for _, object in ipairs(
        folder:GetChildren()
    ) do
        registerEnemy(object)
    end

    connect(
        folder.ChildAdded,
        registerEnemy
    )

    connect(
        folder.ChildRemoved,
        function(object)
            Enemies[object] = nil
        end
    )
end

local function setupDungeon()
    if not dungeon then
        dungeon =
            Workspace:FindFirstChild(
                "dungeon"
            )
    end

    if not dungeon then
        return
    end

    for _, object in ipairs(
        dungeon:GetDescendants()
    ) do
        if object:IsA("Folder")
            and object.Name
                == "enemyFolder" then

            watchEnemyFolder(object)
        end
    end

    connect(
        dungeon.DescendantAdded,
        function(object)
            if object:IsA("Folder")
                and object.Name
                    == "enemyFolder" then

                watchEnemyFolder(object)

            elseif object:IsA("Model")
                and object.Parent
                and object.Parent.Name
                    == "enemyFolder" then

                registerEnemy(object)
            end
        end
    )
end

pcall(setupDungeon)

local function fallbackEnemyScan()
    if not dungeon then
        dungeon =
            Workspace:FindFirstChild(
                "dungeon"
            )
    end

    if not dungeon then
        return
    end

    local now = os.clock()

    if now - lastEnemyFallback < 0.08 then
        return
    end

    lastEnemyFallback = now

    for _, object in ipairs(
        dungeon:GetDescendants()
    ) do
        if validEnemy(object) then
            Enemies[object] = true
        end
    end
end

local function nearestEnemy(position)
    local best = nil
    local bestDistance = math.huge

    for enemy in pairs(Enemies) do
        if not validEnemy(enemy) then
            Enemies[enemy] = nil

        else
            local enemyRoot =
                enemy:FindFirstChild(
                    "HumanoidRootPart"
                )

            local distance =
                (
                    flat(enemyRoot.Position)
                    - flat(position)
                ).Magnitude

            if distance < bestDistance then
                best = enemy
                bestDistance = distance
            end
        end
    end

    if not best then
        fallbackEnemyScan()

        for enemy in pairs(Enemies) do
            if validEnemy(enemy) then
                local enemyRoot =
                    enemy:FindFirstChild(
                        "HumanoidRootPart"
                    )

                local distance =
                    (
                        flat(enemyRoot.Position)
                        - flat(position)
                    ).Magnitude

                if distance < bestDistance then
                    best = enemy
                    bestDistance = distance
                end
            end
        end
    end

    return best, bestDistance
end

--------------------------------------------------
-- DENSE MOB-CLUSTER TARGETING
--------------------------------------------------

local function enemyWorldPosition(enemy)
    if not validEnemy(enemy) then
        return nil
    end

    local root =
        enemy:FindFirstChild(
            "HumanoidRootPart"
        )

    return root and root.Position or nil
end

local function exactTargetResult(
    position,
    target
)
    local targetPosition =
        enemyWorldPosition(target)

    if not targetPosition then
        return nil, math.huge, nil, 0
    end

    return target,
        (
            flat(targetPosition)
            - flat(position)
        ).Magnitude,
        targetPosition,
        1
end

local function chooseTarget(
    position,
    currentTarget
)
    local closest,
        closestDistance =
            nearestEnemy(position)

    if not closest then
        return nil, math.huge, nil, 0
    end

    -- A boss that has already been acquired remains the
    -- direct target. A newly encountered nearest boss is
    -- also attacked head-on rather than averaged with mobs.
    if validEnemy(currentTarget)
        and State:IsBossEnemy(currentTarget) then

        return exactTargetResult(
            position,
            currentTarget
        )
    end

    if State:IsBossEnemy(closest) then
        return exactTargetResult(
            position,
            closest
        )
    end

    -- Only consider enemies in the nearest active enemy
    -- folder. This keeps room progression intact while still
    -- preferring three grouped mobs over one isolated mob.
    local activeFolder = closest.Parent
    local candidates = {}

    for enemy in pairs(Enemies) do
        if not validEnemy(enemy) then
            Enemies[enemy] = nil

        elseif enemy.Parent == activeFolder then
            local enemyPosition =
                enemyWorldPosition(enemy)

            if enemyPosition then
                table.insert(
                    candidates,
                    {
                        Enemy = enemy,
                        Position = enemyPosition
                    }
                )
            end
        end
    end

    if #candidates == 0 then
        return closest,
            closestDistance,
            enemyWorldPosition(closest),
            1
    end

    local bestMembers = nil
    local bestCentre = nil
    local bestCount = 0
    local bestDistance = math.huge

    for _, seed in ipairs(candidates) do
        local members = {}
        local total = Vector3.zero

        for _, candidate in ipairs(candidates) do
            if (
                flat(candidate.Position)
                - flat(seed.Position)
            ).Magnitude <= MOB_CLUSTER_RADIUS then

                table.insert(members, candidate)
                total = total + candidate.Position
            end
        end

        local centre = total / #members
        local centreDistance =
            (
                flat(centre)
                - flat(position)
            ).Magnitude

        if #members > bestCount
            or (
                #members == bestCount
                and centreDistance < bestDistance
            ) then

            bestMembers = members
            bestCentre = centre
            bestCount = #members
            bestDistance = centreDistance
        end
    end

    local selected = nil
    local selectedDistance = math.huge

    -- Preserve target stickiness when the current target is
    -- actually part of the winning group, but immediately
    -- abandon an isolated target for the denser cluster.
    if validEnemy(currentTarget)
        and currentTarget.Parent == activeFolder then

        local currentPosition =
            enemyWorldPosition(currentTarget)

        if currentPosition
            and (
                flat(currentPosition)
                - flat(bestCentre)
            ).Magnitude <= MOB_CLUSTER_STICK_RADIUS then

            selected = currentTarget
        end
    end

    if not selected then
        for _, member in ipairs(bestMembers) do
            local distance =
                (
                    flat(member.Position)
                    - flat(bestCentre)
                ).Magnitude

            if distance < selectedDistance then
                selected = member.Enemy
                selectedDistance = distance
            end
        end
    end

    return selected or closest,
        bestDistance,
        bestCentre,
        bestCount
end

--------------------------------------------------
-- ROOM PROGRESSION
--------------------------------------------------

local LastRoomOrder = 0

local function enemyRoomOrder(enemy)
    if not enemy
        or not enemy.Parent then

        return nil
    end

    local room =
        enemy.Parent.Parent

    if not room then
        return nil
    end

    local order =
        room:FindFirstChild(
            "order"
        )

    if order
        and order:IsA(
            "ValueBase"
        ) then

        return order.Value
    end

    return nil
end

local function findNextRoom(order)
    if not dungeon then
        return nil
    end

    local bestRoom = nil
    local bestOrder = math.huge

    for _, room in ipairs(
        dungeon:GetChildren()
    ) do
        local value =
            room:FindFirstChild(
                "order"
            )

        if value
            and value:IsA(
                "ValueBase"
            )
            and value.Value > order
            and value.Value < bestOrder then

            bestRoom = room
            bestOrder = value.Value
        end
    end

    return bestRoom,
        bestOrder
end

local function nearestRoomSpawn(
    room,
    position
)
    local folder =
        room:FindFirstChild(
            "enemyFolder"
        )

    if not folder then
        return nil
    end

    local best = nil
    local bestDistance = math.huge

    for _, object in ipairs(
        folder:GetChildren()
    ) do
        if object:IsA("BasePart")
            and string.lower(
                object.Name
            ) == "spawn" then

            local distance =
                (
                    flat(object.Position)
                    - flat(position)
                ).Magnitude

            if distance < bestDistance then
                best = object
                bestDistance = distance
            end
        end
    end

    return best
end

local function roomProgressPoint(
    room,
    position
)
    if not room then
        return nil
    end

    local checkpoint =
        room:FindFirstChild(
            "checkPoint"
        )

    if checkpoint
        and checkpoint:IsA(
            "BasePart"
        ) then

        local distance =
            (
                flat(checkpoint.Position)
                - flat(position)
            ).Magnitude

        if distance > 6 then
            return checkpoint
        end
    end

    local spawn =
        nearestRoomSpawn(
            room,
            position
        )

    if spawn then
        return spawn
    end

    return checkpoint
end

--------------------------------------------------
-- HAZARDS
--------------------------------------------------

local Hazards = {}

local watchedParts = {}
local watchedBeams = {}

local lastHazardUpdate = 0

--------------------------------------------------
-- CLASSIFICATION
--------------------------------------------------

local function nameBlob(object)
    local names = {}
    local current = object

    for _ = 1, 6 do
        if not current then
            break
        end

        table.insert(
            names,
            string.lower(
                current.Name
            )
        )

        current = current.Parent
    end

    return table.concat(
        names,
        " "
    )
end

local function classifyPart(
    part,
    genericAllowed
)
    local name =
        string.lower(
            part.Name
        )

    local blob =
        nameBlob(part)

    local profileHazards =
        DungeonData.Profile
        and DungeonData.Profile.Hazards

    if profileHazards then
        for _, pattern in ipairs(
            profileHazards.IgnorePatterns or {}
        ) do
            if blob:find(
                string.lower(tostring(pattern)),
                1,
                true
            ) then
                return nil
            end
        end

        for pattern, kind in pairs(
            profileHazards.KindByPattern or {}
        ) do
            if blob:find(
                string.lower(tostring(pattern)),
                1,
                true
            ) then
                return string.upper(tostring(kind))
            end
        end
    end

    if name == "precast"
        or blob:find(
            "precast",
            1,
            true
        ) then

        return "PRECAST"
    end

    if name == "hitbox"
        or blob:find(
            "hitbox",
            1,
            true
        )
        or blob:find(
            "hurtbox",
            1,
            true
        ) then

        return "HITBOX"
    end

    if blob:find(
        "laser",
        1,
        true
    )
        or blob:find(
            "beam",
            1,
            true
        ) then

        return "LASER"
    end

    if blob:find(
        "projectile",
        1,
        true
    )
        or blob:find(
            "shuriken",
            1,
            true
        )
        or blob:find(
            "missile",
            1,
            true
        )
        or blob:find(
            "fireball",
            1,
            true
        )
        or blob:find(
            "orb",
            1,
            true
        )
        or blob:find(
            "shot",
            1,
            true
        ) then

        return "PROJECTILE"
    end

    if blob:find(
        "strike",
        1,
        true
    )
        or blob:find(
            "slam",
            1,
            true
        )
        or blob:find(
            "wave",
            1,
            true
        )
        or blob:find(
            "aoe",
            1,
            true
        )
        or blob:find(
            "warning",
            1,
            true
        )
        or blob:find(
            "telegraph",
            1,
            true
        )
        or blob:find(
            "explosion",
            1,
            true
        )
        or blob:find(
            "circle",
            1,
            true
        )
        or blob:find(
            "cricle",
            1,
            true
        )
        or blob:find(
            "damage",
            1,
            true
        )
        or blob:find(
            "danger",
            1,
            true
        )
        or blob:find(
            "meteor",
            1,
            true
        )
        or blob:find(
            "sweep",
            1,
            true
        )
        or blob:find(
            "cone",
            1,
            true
        ) then

        return "ATTACK"
    end

    if genericAllowed then
        local size =
            math.max(
                part.Size.X,
                part.Size.Z
            )

        if size >= 6
            and not part.CanCollide
            and (
                part.CanTouch
                or part.Transparency < 0.9
            ) then

            return "GENERIC"
        end
    end

    return nil
end

local function hazardLife(kind)
    if kind == "PRECAST" then
        return PRECAST_LIFE
    end

    if kind == "HITBOX" then
        return HITBOX_LIFE
    end

    if kind == "LASER" then
        return LASER_PART_LIFE
    end

    if kind == "PROJECTILE" then
        return PROJECTILE_LIFE
    end

    if kind == "ATTACK" then
        return ATTACK_LIFE
    end

    return GENERIC_LIFE
end

--------------------------------------------------
-- VISUAL
--------------------------------------------------

local function createVisual(
    part,
    kind
)
    if not SHOW_HAZARD_BOXES then
        return nil
    end

    local box =
        Instance.new(
            "SelectionBox"
        )

    box.Name =
        "DQ_V75_Hazard"

    box.Adornee = part
    box.LineThickness = 0.04
    box.SurfaceTransparency = 0.90

    if kind == "PRECAST" then
        box.Color3 =
            Color3.fromRGB(
                255,
                170,
                0
            )
    else
        box.Color3 =
            Color3.fromRGB(
                255,
                60,
                60
            )
    end

    box.SurfaceColor3 =
        box.Color3

    box.Parent = part

    return box
end

--------------------------------------------------
-- REGISTER PART
--------------------------------------------------

local function registerHazardPart(
    part,
    kind
)
    if not part
        or not part:IsA(
            "BasePart"
        )
        or not part.Parent
        or isPlayerObject(part)
        or isOwnAbility(part)
        or isRecentOwnBuffEffect(part, kind) then

        return
    end

    local existing =
        Hazards[part]

    local now = os.clock()

    if existing then
        existing.Expires =
            math.max(
                existing.Expires,
                now + hazardLife(kind)
            )

        return
    end

    Hazards[part] = {
        Type = "PART",
        Kind = kind,
        Object = part,
        Name = nameBlob(part),

        Created = now,

        Expires =
            now + hazardLife(kind),

        PrevPosition =
            part.Position,

        PrevSize =
            part.Size,

        PrevTime = now,

        Velocity =
            Vector3.zero,

        Acceleration =
            Vector3.zero,

        SizeVelocity =
            Vector3.zero,

        SizeAcceleration =
            Vector3.zero,

        Expanding = false,
        ExpandRate = 0,

        Visual =
            createVisual(
                part,
                kind
            ),

        VisualUntil =
            now + VISUAL_LIFE
    }

    if not watchedParts[part] then
        watchedParts[part] = true
    end
end

--------------------------------------------------
-- REGISTER BEAM
--------------------------------------------------

local function registerBeam(beam)
    if not beam
        or not beam:IsA("Beam")
        or isOwnAbility(beam) then

        return
    end

    if Hazards[beam] then
        return
    end

    if not beam.Enabled then
        return
    end

    local now = os.clock()

    local a0 = nil
    local a1 = nil

    if beam.Attachment0 then
        a0 = beam.Attachment0.WorldPosition
    end

    if beam.Attachment1 then
        a1 = beam.Attachment1.WorldPosition
    end

    Hazards[beam] = {
        Type = "BEAM",
        Kind = "LASER",
        Object = beam,

        Created = now,

        A0 = a0,
        A1 = a1,

        V0 = Vector3.zero,
        V1 = Vector3.zero,

        A0Acceleration = Vector3.zero,
        A1Acceleration = Vector3.zero,

        PrevTime = now
    }

    if not watchedBeams[beam] then
        watchedBeams[beam] = true

        connect(
            beam:GetPropertyChangedSignal("Enabled"),
            function()
                if beam.Parent and beam.Enabled then
                    if not Hazards[beam] then
                        registerBeam(beam)
                    end
                else
                    Hazards[beam] = nil
                end
            end
        )
    end
end

--------------------------------------------------
-- NEW WORKSPACE OBJECTS
--------------------------------------------------

local function discoverNewHazardPart(part)
    local kind =
        classifyPart(
            part,
            true
        )

    if kind then
        registerHazardPart(
            part,
            kind
        )

        return
    end

    task.spawn(function()
        for _ = 1, 7 do
            task.wait(0.03)

            if not State.Alive
                or not part.Parent
                or Hazards[part] then

                return
            end

            local delayedKind =
                classifyPart(
                    part,
                    true
                )

            if delayedKind then
                registerHazardPart(
                    part,
                    delayedKind
                )

                return
            end
        end
    end)
end

connect(
    Workspace.DescendantAdded,
    function(object)
        if object:IsA(
            "BasePart"
        ) then

            discoverNewHazardPart(
                object
            )

        elseif object:IsA(
            "Beam"
        ) then

            registerBeam(object)
        end
    end
)

--------------------------------------------------
-- EXISTING KNOWN HAZARDS
--------------------------------------------------

task.spawn(function()
    for _, object in ipairs(Workspace:GetDescendants()) do
        if not State.Alive then
            return
        end

        pcall(function()
            if object:IsA("Beam") then
                registerBeam(object)

            elseif object:IsA("BasePart") then
                local kind = classifyPart(object, false)

                if kind then
                    registerHazardPart(object, kind)
                end
            end
        end)
    end
end)

--------------------------------------------------
-- UPDATE HAZARD MOTION
--------------------------------------------------

local function updateHazards()
    local now = os.clock()

    if now - lastHazardUpdate
        < HAZARD_UPDATE_INTERVAL then

        return
    end

    lastHazardUpdate = now

    for object, hazard in pairs(
        Hazards
    ) do
        if hazard.Type == "PART" then
            local part =
                hazard.Object

            if not part
                or not part.Parent then

                if hazard.Visual then
                    pcall(function()
                        hazard.Visual:
                            Destroy()
                    end)
                end

                Hazards[object] = nil

            else
                local dt =
                    math.max(
                        now - hazard.PrevTime,
                        0.001
                    )

                local velocity =
                    (
                        part.Position
                        - hazard.PrevPosition
                    ) / dt

                local sizeVelocity =
                    (
                        part.Size
                        - hazard.PrevSize
                    ) / dt

                local previousVelocity =
                    hazard.Velocity

                local previousSizeVelocity =
                    hazard.SizeVelocity

                hazard.Velocity =
                    hazard.Velocity:Lerp(
                        velocity,
                        0.72
                    )

                hazard.SizeVelocity =
                    hazard.SizeVelocity:Lerp(
                        sizeVelocity,
                        0.70
                    )

                local acceleration =
                    (
                        hazard.Velocity
                        - previousVelocity
                    ) / dt

                local sizeAcceleration =
                    (
                        hazard.SizeVelocity
                        - previousSizeVelocity
                    ) / dt

                hazard.Acceleration =
                    hazard.Acceleration:Lerp(
                        acceleration,
                        0.32
                    )

                hazard.SizeAcceleration =
                    hazard.SizeAcceleration:Lerp(
                        sizeAcceleration,
                        0.30
                    )

                local horizontalGrowth =
                    math.max(
                        hazard.SizeVelocity.X,
                        hazard.SizeVelocity.Z,
                        0
                    )

                local horizontalGrowthAcceleration =
                    math.max(
                        hazard.SizeAcceleration.X,
                        hazard.SizeAcceleration.Z,
                        0
                    )

                hazard.ExpandRate =
                    horizontalGrowth
                    + horizontalGrowthAcceleration
                        * 0.10

                hazard.Expanding =
                    hazard.ExpandRate
                        >= EXPAND_RATE_MIN

                if hazard.Expanding then
                    hazard.Expires =
                        math.max(
                            hazard.Expires,
                            now + 0.35
                        )
                end

                local speed =
                    flat(
                        hazard.Velocity
                    ).Magnitude

                hazard.PrevPosition =
                    part.Position

                hazard.PrevSize =
                    part.Size

                hazard.PrevTime =
                    now

                if hazard.Kind
                    == "PROJECTILE"
                    and speed > 0.5 then

                    hazard.Expires =
                        now + 0.75
                end

                if hazard.Kind
                    == "LASER"
                    and speed > 0.15 then

                    hazard.Expires =
                        math.min(
                            now + 1.25,
                            hazard.Created
                                + LASER_PART_MAX_LIFE
                        )
                end

                if hazard.Visual
                    and now
                        >= hazard.VisualUntil then

                    pcall(function()
                        hazard.Visual:
                            Destroy()
                    end)

                    hazard.Visual = nil
                end

                if now >= hazard.Expires then
                    if hazard.Visual then
                        pcall(function()
                            hazard.Visual:
                                Destroy()
                        end)
                    end

                    Hazards[object] = nil
                end
            end

        elseif hazard.Type
            == "BEAM" then

            local beam =
                hazard.Object

            if not beam
                or not beam.Parent
                or not beam.Enabled
                or not beam.Attachment0
                or not beam.Attachment1 then

                Hazards[object] = nil

            else
                local a0 = beam.Attachment0.WorldPosition
                local a1 = beam.Attachment1.WorldPosition

                local dt =
                    math.max(
                        now - hazard.PrevTime,
                        0.001
                    )

                if hazard.A0
                    and hazard.A1 then

                    local velocity0 =
                        (
                            a0 - hazard.A0
                        ) / dt

                    local velocity1 =
                        (
                            a1 - hazard.A1
                        ) / dt

                    local previousV0 =
                        hazard.V0

                    local previousV1 =
                        hazard.V1

                    hazard.V0 =
                        hazard.V0:Lerp(
                            velocity0,
                            0.72
                        )

                    hazard.V1 =
                        hazard.V1:Lerp(
                            velocity1,
                            0.72
                        )

                    hazard.A0Acceleration =
                        hazard.A0Acceleration:Lerp(
                            (
                                hazard.V0
                                - previousV0
                            ) / dt,

                            0.32
                        )

                    hazard.A1Acceleration =
                        hazard.A1Acceleration:Lerp(
                            (
                                hazard.V1
                                - previousV1
                            ) / dt,

                            0.32
                        )
                end

                hazard.A0 = a0
                hazard.A1 = a1
                hazard.PrevTime = now
            end
        end
    end
end

--------------------------------------------------
-- DISTANCE TO PART
--------------------------------------------------

local function accelerationOffset(
    acceleration,
    future
)
    local offset =
        (acceleration or Vector3.zero)
        * 0.5
        * future
        * future

    local horizontal =
        flat(offset)

    if horizontal.Magnitude
        > MAX_ACCEL_PREDICT_OFFSET then

        horizontal =
            horizontal.Unit
            * MAX_ACCEL_PREDICT_OFFSET

        offset =
            Vector3.new(
                horizontal.X,
                offset.Y,
                horizontal.Z
            )
    end

    return offset
end

local function partDistance(
    position,
    hazard,
    future
)
    local part =
        hazard.Object

    if not part
        or not part.Parent then

        return math.huge
    end

    local predictedPosition =
        part.Position
        + hazard.Velocity
            * future
        + accelerationOffset(
            hazard.Acceleration,
            future
        )

    local rotation =
        part.CFrame
        - part.CFrame.Position

    local predictedCF =
        CFrame.new(
            predictedPosition
        ) * rotation

    local sizeVelocity =
        hazard.SizeVelocity
        or Vector3.zero

    local sizeAcceleration =
        hazard.SizeAcceleration
        or Vector3.zero

    local predictedSize =
        part.Size
        + Vector3.new(
            math.max(sizeVelocity.X, 0),
            math.max(sizeVelocity.Y, 0),
            math.max(sizeVelocity.Z, 0)
        ) * future
        + Vector3.new(
            math.clamp(
                sizeAcceleration.X,
                0,
                MAX_SIZE_ACCELERATION
            ),

            math.clamp(
                sizeAcceleration.Y,
                0,
                MAX_SIZE_ACCELERATION
            ),

            math.clamp(
                sizeAcceleration.Z,
                0,
                MAX_SIZE_ACCELERATION
            )
        ) * 0.5
            * future
            * future

    local localPosition =
        predictedCF:
        PointToObjectSpace(
            position
        )

    local dx =
        math.max(
            math.abs(
                localPosition.X
            )
            - predictedSize.X / 2,
            0
        )

    local dz =
        math.max(
            math.abs(
                localPosition.Z
            )
            - predictedSize.Z / 2,
            0
        )

    return math.sqrt(
        dx * dx
        + dz * dz
    )
end

--------------------------------------------------
-- DISTANCE TO BEAM
--------------------------------------------------

local function distanceSegment(
    point,
    a,
    b
)
    local ab = b - a

    local length =
        ab:Dot(ab)

    if length <= 0.0001 then
        return
            (point - a).Magnitude
    end

    local t =
        math.clamp(
            (point - a):
                Dot(ab)
            / length,
            0,
            1
        )

    local closest =
        a + ab * t

    return
        (point - closest).Magnitude
end

local function beamDistance(
    position,
    hazard,
    future
)
    local beam =
        hazard.Object

    if not beam
        or not beam.Parent
        or not beam.Enabled
        or not beam.Attachment0
        or not beam.Attachment1 then

        return math.huge
    end

    local a0 = hazard.A0 or beam.Attachment0.WorldPosition
    local a1 = hazard.A1 or beam.Attachment1.WorldPosition

    a0 =
        a0
        + hazard.V0
            * future
        + accelerationOffset(
            hazard.A0Acceleration,
            future
        )

    a1 =
        a1
        + hazard.V1
            * future
        + accelerationOffset(
            hazard.A1Acceleration,
            future
        )

    local point =
        Vector2.new(
            position.X,
            position.Z
        )

    local start =
        Vector2.new(
            a0.X,
            a0.Z
        )

    local finish =
        Vector2.new(
            a1.X,
            a1.Z
        )

    local distance =
        distanceSegment(
            point,
            start,
            finish
        )

    local width =
        math.max(
            beam.Width0,
            beam.Width1,
            1
        )

    return math.max(
        distance - width / 2,
        0
    )
end

local function hazardDistance(
    position,
    hazard,
    future
)
    if hazard.Type == "PART" then
        return partDistance(
            position,
            hazard,
            future
        )
    end

    if hazard.Type == "BEAM" then
        return beamDistance(
            position,
            hazard,
            future
        )
    end

    return math.huge
end

--------------------------------------------------
-- FIND MAIN THREAT
--------------------------------------------------

local function hazardSpeed(hazard)
    if hazard.Type == "PART" then
        return flat(
            hazard.Velocity
            or Vector3.zero
        ).Magnitude
    end

    if hazard.Type == "BEAM" then
        return math.max(
            flat(
                hazard.V0
                or Vector3.zero
            ).Magnitude,

            flat(
                hazard.V1
                or Vector3.zero
            ).Magnitude
        )
    end

    return 0
end

local function getThreat(
    position,
    playerVelocity
)
    playerVelocity =
        flat(
            playerVelocity
            or Vector3.zero
        )

    local maximumPredictedSpeed =
        MAX_SPEED * 1.25

    if playerVelocity.Magnitude
        > maximumPredictedSpeed then

        playerVelocity =
            playerVelocity.Unit
            * maximumPredictedSpeed
    end

    local bestHazard = nil
    local bestLevel = nil

    local bestCurrent =
        math.huge

    local bestFuture =
        math.huge

    local bestScore =
        math.huge

    for _, hazard in pairs(
        Hazards
    ) do
        local expansionHorizon =
            hazard.Expanding
            and EXPAND_PREDICT
            or PREDICT_FAR

        local name =
            hazard.Name or ""

        local bobStyleCircle =
            hazard.Expanding
            and (
                name:find("circle", 1, true)
                or name:find("cricle", 1, true)
                or name:find("bob", 1, true)
                or name:find("slam", 1, true)
            ) ~= nil

        local current =
            hazardDistance(
                position,
                hazard,
                0
            )

        local nearFuture =
            hazardDistance(
                position
                    + playerVelocity
                        * PREDICT_NEAR
                        * PLAYER_MOTION_PREDICTION,

                hazard,
                PREDICT_NEAR
            )

        local predicted =
            math.min(
                current,
                nearFuture
            )

        local impactTime = nil

        local impactClearance =
            BODY_RADIUS
            + 1.0
            + (
                bobStyleCircle
                and EXPAND_EMERGENCY_EXTRA
                or 0
            )

        for sample = 1,
            THREAT_PREDICTION_SAMPLES do

            local future =
                expansionHorizon
                * sample
                / THREAT_PREDICTION_SAMPLES

            local futurePosition =
                position
                + playerVelocity
                    * future
                    * PLAYER_MOTION_PREDICTION

            local distance =
                hazardDistance(
                    futurePosition,
                    hazard,
                    future
                )

            predicted =
                math.min(
                    predicted,
                    distance
                )

            if not impactTime
                and distance
                    <= impactClearance then

                impactTime = future
            end
        end

        hazard.TimeToImpact =
            impactTime

        local closing =
            current - predicted

        local speed =
            hazardSpeed(hazard)

        local fastFactor =
            math.clamp(
                (
                    speed
                    - FAST_HAZARD_SPEED
                ) / FAST_HAZARD_SPEED,

                0,
                1
            )

        local emergency =
            current
                <= BODY_RADIUS
                    + EMERGENCY_EXTRA
                    + (
                        bobStyleCircle
                        and EXPAND_EMERGENCY_EXTRA
                        or 0
                    )
            or nearFuture
                <= BODY_RADIUS
                    + 0.7
                    + (
                        bobStyleCircle
                        and EXPAND_EMERGENCY_EXTRA
                        or 0
                    )
            or impactTime
                and impactTime
                    <= EMERGENCY_IMPACT_TIME

        local warning =
            false

        if not emergency then
            warning =
                predicted
                    <= BODY_RADIUS
                        + WARNING_EXTRA
                        + (
                            bobStyleCircle
                            and EXPAND_WARNING_EXTRA
                            or hazard.Expanding
                                and 3.5
                                or 0
                        )
                        + fastFactor
                            * FAST_WARNING_EXTRA
        end

        local level = nil
        local score = nil

        if emergency then
            level = "EMERGENCY"

            score =
                -1000
                + predicted
                + current
                + (
                    impactTime
                    or expansionHorizon
                ) * 18

        elseif warning then
            level = "WARNING"

            score =
                -100
                + predicted
                + current
                - math.max(
                    closing,
                    0
                ) * 3
                + (
                    impactTime
                    or expansionHorizon
                ) * 8
        end

        if score
            and score < bestScore then

            bestScore = score

            bestHazard =
                hazard

            bestLevel =
                level

            bestCurrent =
                current

            bestFuture =
                predicted
        end
    end

    return
        bestHazard,
        bestLevel,
        bestCurrent,
        bestFuture
end

--------------------------------------------------
-- RAYCAST
--------------------------------------------------

local function rayParams(character)
    local params =
        RaycastParams.new()

    params.FilterType =
        Enum.RaycastFilterType.Exclude

    local ignore = {
        character
    }

    for _, hazard in pairs(
        Hazards
    ) do
        if hazard.Type == "PART"
            and hazard.Object
            and hazard.Object.Parent then

            table.insert(
                ignore,
                hazard.Object
            )
        end
    end

    params.FilterDescendantsInstances =
        ignore

    return params
end

local function groundAt(
    position,
    character
)
    local result =
        Workspace:Raycast(
            position
            + Vector3.new(
                0,
                13,
                0
            ),

            Vector3.new(
                0,
                -45,
                0
            ),

            rayParams(
                character
            )
        )

    if not result then
        return nil
    end

    return Vector3.new(
        position.X,
        result.Position.Y + 3,
        position.Z
    )
end

--------------------------------------------------
-- STATIC WALL CHECK
--------------------------------------------------

local function staticRouteClear(
    startPosition,
    destination,
    character
)
    local delta =
        destination
        - startPosition

    if flat(delta).Magnitude < 1 then
        return true
    end

    local params =
        rayParams(
            character
        )

    local low =
        Workspace:Raycast(
            startPosition
            + Vector3.new(
                0,
                1.3,
                0
            ),

            delta,

            params
        )

    local high =
        Workspace:Raycast(
            startPosition
            + Vector3.new(
                0,
                3.5,
                0
            ),

            delta,

            params
        )

    local function blocked(result)
        return result
            and result.Instance
            and result.Instance:
                IsA("BasePart")
            and result.Instance.CanCollide
    end

    return
        not blocked(low)
        and not blocked(high)
end

--------------------------------------------------
-- WALL SLIDE
--------------------------------------------------

local function wallSteer(
    desired,
    root,
    character
)
    desired = flat(desired)

    if desired.Magnitude < 0.01 then
        return Vector3.zero
    end

    desired = desired.Unit

    local params =
        rayParams(character)

    local hit =
        Workspace:Raycast(
            root.Position
            + Vector3.new(
                0,
                2.2,
                0
            ),

            desired * 6,

            params
        )

    if not hit
        or not hit.Instance
        or not hit.Instance.CanCollide then

        return desired
    end

    local normal =
        flat(hit.Normal)

    if normal.Magnitude > 0.1 then
        normal = normal.Unit

        local tangent1 =
            Vector3.new(
                -normal.Z,
                0,
                normal.X
            )

        local tangent2 =
            -tangent1

        local chosen

        if tangent1:Dot(
            desired
        )
            > tangent2:Dot(
                desired
            ) then

            chosen = tangent1
        else
            chosen = tangent2
        end

        local result =
            chosen * 0.90
            + normal * 0.10

        if result.Magnitude > 0.01 then
            return result.Unit
        end
    end

    return desired
end

--------------------------------------------------
-- WALL PENALTY
--------------------------------------------------

local function wallPenalty(
    position,
    character
)
    local params =
        rayParams(character)

    local penalty = 0

    local directions = {
        Vector3.new(1,0,0),
        Vector3.new(-1,0,0),
        Vector3.new(0,0,1),
        Vector3.new(0,0,-1)
    }

    for _, direction in ipairs(
        directions
    ) do
        local hit =
            Workspace:Raycast(
                position
                + Vector3.new(
                    0,
                    2,
                    0
                ),

                direction * 5,

                params
            )

        if hit
            and hit.Instance
            and hit.Instance.CanCollide then

            penalty =
                penalty
                + math.max(
                    5 - hit.Distance,
                    0
                )
        end
    end

    return penalty
end

--------------------------------------------------
-- SMART ROUTE TEST
--
-- IMPORTANT:
-- if we're ALREADY inside a hazard,
-- we're allowed to travel through it until
-- we've escaped it.
--------------------------------------------------

local function routeSafe(
    startPosition,
    destination,
    speed
)
    local travelDistance =
        (
            flat(destination)
            - flat(startPosition)
        ).Magnitude

    local eta =
        travelDistance
        / math.max(
            speed,
            1
        )

    local minimumClearance =
        math.huge

    for _, hazard in pairs(
        Hazards
    ) do
        local startDistance =
            hazardDistance(
                startPosition,
                hazard,
                0
            )

        local startedInside =
            startDistance
            <= BODY_RADIUS
                + EXIT_EXTRA

        local escaped =
            not startedInside

        for sample = 1,
            ROUTE_SAMPLES do

            local alpha =
                sample
                / ROUTE_SAMPLES

            local point =
                startPosition:
                Lerp(
                    destination,
                    alpha
                )

            local future =
                math.min(
                    eta * alpha,
                    hazard.Expanding
                        and EXPAND_PREDICT
                        or PREDICT_FAR
                )

            local distance =
                hazardDistance(
                    point,
                    hazard,
                    future
                )

            if not escaped then
                if distance
                    > BODY_RADIUS
                        + EXIT_EXTRA then

                    escaped = true
                end

            else
                if distance
                    <= BODY_RADIUS
                        + ROUTE_EXTRA then

                    return false, 0
                end

                minimumClearance =
                    math.min(
                        minimumClearance,
                        distance
                    )
            end
        end

        local destinationDistance =
            hazardDistance(
                destination,
                hazard,
                math.min(
                    eta,
                    hazard.Expanding
                        and EXPAND_PREDICT
                        or PREDICT_FAR
                )
            )

        if destinationDistance
            <= BODY_RADIUS
                + DESTINATION_EXTRA then

            return false, 0
        end

        if startedInside
            and not escaped then

            return false, 0
        end
    end

    if minimumClearance
        == math.huge then

        minimumClearance = 50
    end

    return true,
        minimumClearance
end

--------------------------------------------------
-- THREAT DIRECTION
--------------------------------------------------

local function threatEscapeDirection(
    position,
    hazard
)
    if not hazard then
        return nil
    end

    if hazard.Type == "PART" then
        local part =
            hazard.Object

        if not part
            or not part.Parent then

            return nil
        end

        local localPosition =
            part.CFrame:
            PointToObjectSpace(
                position
            )

        local halfX =
            part.Size.X / 2

        local halfZ =
            part.Size.Z / 2

        local exits = {
            {
                Distance =
                    math.abs(
                        halfX
                        - localPosition.X
                    ),

                Direction =
                    part.CFrame.
                        RightVector
            },

            {
                Distance =
                    math.abs(
                        -halfX
                        - localPosition.X
                    ),

                Direction =
                    -part.CFrame.
                        RightVector
            },

            {
                Distance =
                    math.abs(
                        halfZ
                        - localPosition.Z
                    ),

                Direction =
                    part.CFrame.
                        LookVector
            },

            {
                Distance =
                    math.abs(
                        -halfZ
                        - localPosition.Z
                    ),

                Direction =
                    -part.CFrame.
                        LookVector
            }
        }

        table.sort(
            exits,
            function(a, b)
                return
                    a.Distance
                    < b.Distance
            end
        )

        return flat(
            exits[1].
                Direction
        ).Unit
    end

    if hazard.Type == "BEAM" then
        local beam =
            hazard.Object

        if not beam
            or not beam.Attachment0
            or not beam.Attachment1 then

            return nil
        end

        local a = hazard.A0 or beam.Attachment0.WorldPosition
        local b = hazard.A1 or beam.Attachment1.WorldPosition

        a =
            a
            + hazard.V0
                * PREDICT_NEAR

        b =
            b
            + hazard.V1
                * PREDICT_NEAR

        local point =
            Vector2.new(
                position.X,
                position.Z
            )

        local start =
            Vector2.new(
                a.X,
                a.Z
            )

        local finish =
            Vector2.new(
                b.X,
                b.Z
            )

        local line =
            finish - start

        local length =
            line:Dot(line)

        if length <= 0.0001 then
            return nil
        end

        local t =
            math.clamp(
                (point - start):
                    Dot(line)
                / length,

                0,
                1
            )

        local closest =
            start
            + line * t

        local away =
            Vector3.new(
                point.X
                    - closest.X,

                0,

                point.Y
                    - closest.Y
            )

        if away.Magnitude > 0.05 then
            return away.Unit
        end

        line = line.Unit

        return Vector3.new(
            -line.Y,
            0,
            line.X
        )
    end

    return nil
end

--------------------------------------------------
-- CANDIDATES
--------------------------------------------------

local CurrentDodgeDirection =
    nil

local DodgeSide = "NONE"
local LastThreatSeen = 0

local function targetLeashDistance(enemy)
    if not validEnemy(enemy) then
        return math.huge
    end

    local name =
        string.lower(
            enemy.Name or ""
        )

    if name:find(
        "bob",
        1,
        true
    ) then

        return BOB_LEASH_DISTANCE
    end

    return TARGET_LEASH_DISTANCE
end

local function candidateDirections(
    root,
    threat,
    enemy
)
    local directions = {}

    local function add(
        direction,
        side,
        outwardFallback
    )
        direction =
            flat(direction)

        if direction.Magnitude < 0.05 then
            return
        end

        direction = direction.Unit

        for _, existing in ipairs(
            directions
        ) do
            if existing.Direction:Dot(
                direction
            ) > 0.985 then

                return
            end
        end

        table.insert(
            directions,
            {
                Direction = direction,
                Side = side,
                OutwardFallback =
                    outwardFallback == true
            }
        )
    end

    ------------------------------------------------
    -- LEFT / RIGHT RELATIVE TO THE ENEMY
    ------------------------------------------------

    if validEnemy(enemy) then
        local enemyRoot =
            enemy:FindFirstChild(
                "HumanoidRootPart"
            )

        if enemyRoot then
            local toward =
                flat(
                    enemyRoot.Position
                    - root.Position
                )

            if toward.Magnitude > 0.05 then
                local enemyDistance =
                    toward.Magnitude

                toward = toward.Unit

                local baseLeft =
                    Vector3.new(
                        -toward.Z,
                        0,
                        toward.X
                    )

                local baseRight = -baseLeft
                local outward = -toward

                local leash =
                    targetLeashDistance(
                        enemy
                    )

                local leashPressure =
                    math.clamp(
                        (
                            enemyDistance
                            - (
                                leash
                                - LEASH_INWARD_START
                            )
                        )
                        / LEASH_INWARD_START,

                        0,
                        1
                    )

                local inward =
                    toward
                    * leashPressure
                    * LEASH_MAX_INWARD

                local left =
                    baseLeft + inward

                local right =
                    baseRight + inward

                local allowOutwardFallback =
                    enemyDistance
                    < leash - 2

                if DodgeSide == "NONE"
                    or DodgeSide == "LEFT" then

                    add(left, "LEFT", false)

                    if threat
                        and threat.Expanding
                        and allowOutwardFallback then

                        add(
                            baseLeft
                            + outward
                                * EXPAND_OUTWARD_WEIGHT,
                            "LEFT",
                            true
                        )
                    end
                end

                if DodgeSide == "NONE"
                    or DodgeSide == "RIGHT" then

                    add(right, "RIGHT", false)

                    if threat
                        and threat.Expanding
                        and allowOutwardFallback then

                        add(
                            baseRight
                            + outward
                                * EXPAND_OUTWARD_WEIGHT,
                            "RIGHT",
                            true
                        )
                    end
                end
            end
        end
    end

    ------------------------------------------------
    -- NO ENEMY FALLBACK: STILL MOVE SIDEWAYS TO THREAT
    ------------------------------------------------

    if #directions == 0 then
        local away =
            threatEscapeDirection(
                root.Position,
                threat
            )

        if away then
            local left =
                Vector3.new(
                    -away.Z,
                    0,
                    away.X
                )

            if DodgeSide == "NONE"
                or DodgeSide == "LEFT" then

                add(left, "LEFT", false)
            end

            if DodgeSide == "NONE"
                or DodgeSide == "RIGHT" then

                add(-left, "RIGHT", false)
            end
        end
    end

    if #directions == 0
        and CurrentDodgeDirection then

        add(
            CurrentDodgeDirection,
            DodgeSide,
            false
        )
    end

    return directions
end

local function committedLateralFallback(
    root,
    enemy,
    threat
)
    if validEnemy(enemy) then
        local enemyRoot =
            enemy:FindFirstChild(
                "HumanoidRootPart"
            )

        if enemyRoot then
            local toward =
                flat(
                    enemyRoot.Position
                    - root.Position
                )

            if toward.Magnitude > 0.05 then
                local enemyDistance =
                    toward.Magnitude

                toward = toward.Unit

                local left =
                    Vector3.new(
                        -toward.Z,
                        0,
                        toward.X
                    )

                if DodgeSide == "NONE" then
                    local away =
                        threatEscapeDirection(
                            root.Position,
                            threat
                        )

                    if away
                        and (-left):Dot(away)
                            > left:Dot(away) then

                        DodgeSide = "RIGHT"
                    else
                        DodgeSide = "LEFT"
                    end
                end

                local direction =
                    DodgeSide == "RIGHT"
                    and -left
                    or left

                if threat
                    and threat.Expanding
                    and enemyDistance
                        < targetLeashDistance(enemy)
                            - 2 then

                    direction =
                        direction
                        - toward
                            * EXPAND_OUTWARD_WEIGHT
                end

                local leash =
                    targetLeashDistance(
                        enemy
                    )

                local leashPressure =
                    math.clamp(
                        (
                            enemyDistance
                            - (
                                leash
                                - LEASH_INWARD_START
                            )
                        )
                        / LEASH_INWARD_START,

                        0,
                        1
                    )

                if leashPressure > 0 then
                    direction =
                        direction
                        + toward
                            * leashPressure
                            * LEASH_MAX_INWARD
                end

                return direction.Unit
            end
        end
    end

    local away =
        threatEscapeDirection(
            root.Position,
            threat
        )

    if away then
        if DodgeSide == "NONE" then
            DodgeSide = "LEFT"
        end

        local left =
            Vector3.new(
                -away.Z,
                0,
                away.X
            )

        return (
            DodgeSide == "RIGHT"
            and -left
            or left
        ).Unit
    end

    return CurrentDodgeDirection
end

local function quickDodgeDirection(
    character,
    root,
    enemy,
    threat
)
    local directions =
        candidateDirections(
            root,
            threat,
            enemy
        )

    local away =
        threatEscapeDirection(
            root.Position,
            threat
        )

    local bestDirection = nil
    local bestSide = nil
    local bestScore = -math.huge

    for _, entry in ipairs(
        directions
    ) do
        local destination =
            root.Position
            + entry.Direction
                * QUICK_DODGE_DISTANCE

        local safe,
            clearance =
                routeSafe(
                    root.Position,
                    destination,
                    DODGE_SPEED
                )

        if safe
            and staticRouteClear(
                root.Position,
                destination,
                character
            ) then

            local score =
                math.min(
                    clearance,
                    30
                )

            if away then
                score =
                    score
                    + entry.Direction:Dot(
                        away
                    ) * 6
            end

            if entry.OutwardFallback then
                score = score - 8
            end

            if CurrentDodgeDirection then
                score =
                    score
                    + math.max(
                        entry.Direction:Dot(
                            CurrentDodgeDirection
                        ),
                        0
                    ) * 3
            end

            if validEnemy(enemy) then
                local enemyRoot =
                    enemy:FindFirstChild(
                        "HumanoidRootPart"
                    )

                if enemyRoot then
                    local enemyDistance =
                        (
                            flat(destination)
                            - flat(
                                enemyRoot.Position
                            )
                        ).Magnitude

                    local leash =
                        targetLeashDistance(
                            enemy
                        )

                    if enemyDistance > leash then
                        score =
                            score
                            - 60
                            - (
                                enemyDistance
                                - leash
                            ) * 10
                    end
                end
            end

            if score > bestScore then
                bestScore = score
                bestDirection =
                    entry.Direction
                bestSide = entry.Side
            end
        end
    end

    if bestDirection then
        DodgeSide =
            bestSide or DodgeSide

        return bestDirection
    end

    return committedLateralFallback(
        root,
        enemy,
        threat
    )
end

--------------------------------------------------
-- SMART ESCAPE
--------------------------------------------------

local function findEscape(
    character,
    root,
    enemy,
    threat,
    soft
)
    local directions =
        candidateDirections(
            root,
            threat,
            enemy
        )

    local radii

    if soft then
        radii = EVADE_RADII
    else
        radii = DODGE_RADII
    end

    local options = {}

    for _, entry in ipairs(
        directions
    ) do
        local direction =
            entry.Direction

        for _, radius in ipairs(
            radii
        ) do
            local candidate =
                root.Position
                + direction
                    * radius

            local safe,
                clearance =
                    routeSafe(
                        root.Position,
                        candidate,

                        soft
                        and EVADE_SPEED
                        or DODGE_SPEED
                    )

            if safe then
                local distance =
                    radius

                local score =
                    distance * 0.20
                    - math.min(
                        clearance,
                        25
                    ) * 1.0

                if entry.OutwardFallback then
                    score = score + 100
                end

                if validEnemy(enemy) then
                    local enemyRoot =
                        enemy:FindFirstChild(
                            "HumanoidRootPart"
                        )

                    if enemyRoot then
                        local enemyDistance =
                            (
                                flat(candidate)
                                - flat(
                                    enemyRoot.Position
                                )
                            ).Magnitude

                        if enemyDistance < 8 then
                            score =
                                score + 30

                        elseif soft then
                            score =
                                score
                                + math.abs(
                                    enemyDistance
                                    - DESIRED_DISTANCE
                                ) * 0.18

                        elseif enemyDistance
                            > targetLeashDistance(
                                enemy
                            ) then

                            local excess =
                                enemyDistance
                                - targetLeashDistance(
                                    enemy
                                )

                            score =
                                score
                                + 180
                                + excess * 14
                        end
                    end
                end

                if CurrentDodgeDirection then
                    score =
                        score
                        - math.max(
                            direction:Dot(
                                CurrentDodgeDirection
                            ),
                            0
                        ) * 3
                end

                table.insert(
                    options,
                    {
                        Point =
                            candidate,

                        Score =
                            score,

                        Side =
                            entry.Side,

                        OutwardFallback =
                            entry.OutwardFallback
                    }
                )
            end
        end
    end

    table.sort(
        options,
        function(a, b)
            return
                a.Score
                < b.Score
        end
    )

    local checks =
        math.min(
            #options,
            TOP_CANDIDATES
        )

    local best = nil
    local bestSide = nil
    local bestScore =
        math.huge

    for index = 1, checks do
        local option =
            options[index]

        local grounded =
            groundAt(
                option.Point,
                character
            )

        if grounded
            and staticRouteClear(
                root.Position,
                grounded,
                character
            ) then

            local safe =
                routeSafe(
                    root.Position,
                    grounded,

                    soft
                    and EVADE_SPEED
                    or DODGE_SPEED
                )

            if safe then
                local score =
                    option.Score
                    + wallPenalty(
                        grounded,
                        character
                    )

                if score < bestScore then
                    bestScore = score
                    best = grounded
                    bestSide = option.Side
                end
            end
        end
    end

    return best, bestSide
end

--------------------------------------------------
-- DESTINATION SAFE?
--------------------------------------------------

local function dodgeDestinationSafe(
    root,
    destination,
    speed
)
    if not destination then
        return false
    end

    local safe =
        routeSafe(
            root.Position,
            destination,
            speed
        )

    return safe == true
end

--------------------------------------------------
-- PATHFINDING
--------------------------------------------------

local Waypoints = nil
local WaypointIndex = 1

local LastPathBuild = 0
local PathDestination = nil

local function clearPath()
    Waypoints = nil
    WaypointIndex = 1
    PathDestination = nil
end

local function buildPath(
    startPosition,
    destination,
    force
)
    local now = os.clock()

    if not force
        and now - LastPathBuild
            < PATH_RECALC then

        return false
    end

    LastPathBuild = now

    local path =
        PathfindingService:
        CreatePath({
            AgentRadius = 2.3,
            AgentHeight = 5,
            AgentCanJump = true,
            AgentCanClimb = true,
            WaypointSpacing = 4
        })

    local success =
        pcall(function()
            path:ComputeAsync(
                startPosition,
                destination
            )
        end)

    if not success
        or path.Status
            ~= Enum.PathStatus.Success then

        clearPath()
        return false
    end

    Waypoints =
        path:GetWaypoints()

    WaypointIndex = 2
    PathDestination =
        destination

    return true
end

local function pathDirection(
    root,
    humanoid
)
    if not Waypoints then
        return nil
    end

    local waypoint =
        Waypoints[
            WaypointIndex
        ]

    if not waypoint then
        clearPath()
        return nil
    end

    if (
        flat(
            waypoint.Position
            - root.Position
        )
    ).Magnitude
        <= WAYPOINT_DISTANCE then

        WaypointIndex =
            WaypointIndex + 1

        waypoint =
            Waypoints[
                WaypointIndex
            ]

        if not waypoint then
            clearPath()
            return nil
        end
    end

    if waypoint.Action
        == Enum.PathWaypointAction.Jump then

        humanoid.Jump = true
    end

    return flat(
        waypoint.Position
        - root.Position
    )
end

--------------------------------------------------
-- FACING
--------------------------------------------------

local FacingRoot = nil
local FacingAttachment = nil
local FacingAlign = nil

local function createFacing(root)
    if FacingRoot == root
        and FacingAlign
        and FacingAlign.Parent then

        return
    end

    if FacingAlign then
        pcall(function()
            FacingAlign:Destroy()
        end)
    end

    if FacingAttachment then
        pcall(function()
            FacingAttachment:
                Destroy()
        end)
    end

    FacingAttachment =
        Instance.new(
            "Attachment"
        )

    FacingAttachment.Name =
        "DQ_V75_FacingAttachment"

    FacingAttachment.Parent =
        root

    FacingAlign =
        Instance.new(
            "AlignOrientation"
        )

    FacingAlign.Name =
        "DQ_V75_Facing"

    FacingAlign.Mode =
        Enum.OrientationAlignmentMode.
            OneAttachment

    FacingAlign.Attachment0 =
        FacingAttachment

    FacingAlign.RigidityEnabled =
        true

    FacingAlign.Responsiveness =
        200

    FacingAlign.MaxTorque =
        1000000000

    FacingAlign.MaxAngularVelocity =
        100

    FacingAlign.Parent =
        root

    FacingRoot = root
end

local function faceTarget(
    root,
    target,
    aimPosition
)
    createFacing(root)

    if not validEnemy(target) then
        FacingAlign.Enabled = false
        return false
    end

    local enemyRoot =
        target:FindFirstChild(
            "HumanoidRootPart"
        )

    if not enemyRoot then
        FacingAlign.Enabled = false
        return false
    end

    local direction =
        flat(
            (
                aimPosition
                or enemyRoot.Position
            )
            - root.Position
        )

    if direction.Magnitude < 0.05 then
        return true
    end

    direction = direction.Unit

    FacingAlign.Enabled = true

    FacingAlign.CFrame =
        CFrame.lookAt(
            Vector3.zero,
            direction
        )

    local current =
        flat(
            root.CFrame.
                LookVector
        )

    if current.Magnitude < 0.05 then
        return false
    end

    return
        current.Unit:
        Dot(direction)
        >= FACE_DOT_REQUIRED
end

--------------------------------------------------
-- Q / E: ONCE PER MOB PACK + COOLDOWN GATE
--------------------------------------------------

local SpellFlow = (function()
    local flow = {
        ActiveKey = nil,
        PendingKey = nil,
        PackActive = false,
        Waiting = false,
        QUsed = false,
        EUsed = false,
        LastQ = -math.huge,
        LastE = -math.huge,
        ClearedAt = 0,
        KeyBusy = {}
    }

    local function packKey(target)
        if not validEnemy(target) then
            return nil
        end

        local order = enemyRoomOrder(target)

        if order ~= nil then
            return "ROOM:" .. tostring(order)
        end

        local current = target

        while current and current.Parent do
            if current.Parent == dungeon then
                return current
            end

            current = current.Parent
        end

        return target.Parent or target
    end

    local function pressKey(key, fallback)
        if flow.KeyBusy[key] then
            return
        end

        flow.KeyBusy[key] = true

        task.spawn(function()
            local success = pcall(function()
                VirtualInputManager:SendKeyEvent(
                    true,
                    key,
                    false,
                    game
                )

                task.wait(0.035)

                VirtualInputManager:SendKeyEvent(
                    false,
                    key,
                    false,
                    game
                )
            end)

            if not success
                and keypress
                and keyrelease then

                pcall(function()
                    keypress(fallback)
                    task.wait(0.035)
                    keyrelease(fallback)
                end)
            end

            flow.KeyBusy[key] = nil
        end)
    end

    local function cooldownState(letter)
        local playerGui = LP:FindFirstChildOfClass(
            "PlayerGui"
        )

        if not playerGui then
            return false, false
        end

        local keyLabel = nil

        for _, object in ipairs(
            playerGui:GetDescendants()
        ) do
            if (
                object:IsA("TextLabel")
                or object:IsA("TextButton")
            ) then
                local textValue =
                    string.upper(
                        tostring(object.Text or "")
                    ):gsub("%s+", "")

                if textValue == letter then
                    keyLabel = object
                    break
                end
            end
        end

        if not keyLabel then
            return false, false
        end

        local container = keyLabel.Parent

        for _ = 1, 3 do
            if not container
                or container == playerGui then

                break
            end

            for _, object in ipairs(
                container:GetDescendants()
            ) do
                if object ~= keyLabel
                    and (
                        object:IsA("TextLabel")
                        or object:IsA("TextButton")
                    )
                    and object.Visible then

                    local numberText =
                        tostring(
                            object.Text or ""
                        ):match(
                            "^%s*(%d+%.?%d*)%s*$"
                        )

                    local seconds =
                        numberText
                        and tonumber(numberText)

                    if seconds then
                        return seconds > 0.05, true
                    end
                end
            end

            container = container.Parent
        end

        return false, true
    end

    local function spellReady(
        letter,
        enabled,
        used,
        castAt,
        now
    )
        if not enabled or not used then
            return true
        end

        local onCooldown, detected =
            cooldownState(letter)

        if detected then
            return not onCooldown
        end

        return now - castAt
            >= SPELL_FALLBACK_COOLDOWN
    end

    function flow:Ready(now)
        if now - self.ClearedAt
            < PACK_CLEAR_GRACE then

            return false
        end

        return spellReady(
            "Q",
            AUTO_Q,
            self.QUsed,
            self.LastQ,
            now
        )
            and spellReady(
                "E",
                AUTO_E,
                self.EUsed,
                self.LastE,
                now
            )
    end

    function flow:BeginPack(key)
        self.ActiveKey = key
        self.PendingKey = nil
        self.PackActive = key ~= nil
        self.Waiting = false
        self.QUsed = false
        self.EUsed = false
    end

    function flow:Reset()
        self.ActiveKey = nil
        self.PendingKey = nil
        self.PackActive = false
        self.Waiting = false
        self.QUsed = false
        self.EUsed = false
        self.LastQ = -math.huge
        self.LastE = -math.huge
        self.ClearedAt = 0
        self.KeyBusy = {}
    end

    function flow:Observe(target, now)
        local key = packKey(target)

        if self.Waiting then
            self.PendingKey = key

            if self:Ready(now) then
                self:BeginPack(key)
            end

            return
        end

        if not key then
            if self.PackActive then
                self.PackActive = false
                self.ActiveKey = nil

                if self.QUsed or self.EUsed then
                    self.Waiting = true
                    self.ClearedAt = now
                else
                    self.QUsed = false
                    self.EUsed = false
                end
            end

            return
        end

        if not self.PackActive then
            self:BeginPack(key)
            return
        end

        if key ~= self.ActiveKey then
            if self.QUsed or self.EUsed then
                self.PackActive = false
                self.PendingKey = key
                self.Waiting = true
                self.ClearedAt = now
            else
                self:BeginPack(key)
            end
        end
    end

    function flow:ShouldHold()
        if State.SpamSpells then
            return false
        end

        return self.Waiting
    end

    function flow:Status()
        if State.SpamSpells then
            return "SPAM MODE"
        end

        if State.TargetIsBoss then
            return "BOSS RECAST"
        end

        if self.Waiting then
            return "WAIT COOLDOWN"
        end

        if self.PackActive
            and (self.QUsed or self.EUsed) then

            return "Q:"
                .. (
                    self.QUsed
                    and "USED"
                    or "READY"
                )
                .. " E:"
                .. (
                    self.EUsed
                    and "USED"
                    or "READY"
                )
        end

        return "READY"
    end

    function flow:Use(
        target,
        distance,
        facing,
        mode,
        remoteCast
    )
        local extendedCast =
            remoteCast
            and not State.SpamSpells

        local allowedRange =
            extendedCast
            and REMOTE_ABILITY_RANGE
            or ABILITY_RANGE

        local now = os.clock()

        if State.SpamSpells
            or State.TargetIsBoss then
            if not validEnemy(target)
                or distance > allowedRange then

                return
            end

            if AUTO_Q
                and now - self.LastQ
                    >= SPELL_SPAM_INTERVAL then

                self.LastQ = now

                State.OwnAbilityIgnoreUntil =
                    now + OWN_BUFF_IGNORE_TIME

                pressKey(
                    Enum.KeyCode.Q,
                    0x51
                )
            end

            if AUTO_E
                and facing
                and now - self.LastE
                    >= SPELL_SPAM_INTERVAL then

                self.LastE = now

                pressKey(
                    Enum.KeyCode.E,
                    0x45
                )
            end

            return
        end

        if not self.PackActive
            and not self.Waiting
            and validEnemy(target) then

            self:BeginPack(
                packKey(target)
            )
        end

        if not self.PackActive
            or self.Waiting
            or not validEnemy(target)
            or distance > allowedRange
            or mode == "DODGE" then

            return
        end

        if AUTO_Q and not self.QUsed then
            self.QUsed = true
            self.LastQ = now

            State.OwnAbilityIgnoreUntil =
                now + OWN_BUFF_IGNORE_TIME

            pressKey(
                Enum.KeyCode.Q,
                0x51
            )
        end

        if AUTO_E
            and not self.EUsed
            and facing then

            self.EUsed = true
            self.LastE = now

            pressKey(
                Enum.KeyCode.E,
                0x45
            )
        end
    end

    return flow
end)()

--------------------------------------------------
-- AI STATE
--------------------------------------------------

local Mode = "STARTING"

local Target = nil
local TargetDistance =
    math.huge

local TargetAimPosition = nil
local TargetClusterCount = 0

local DesiredDirection =
    Vector3.zero

local DesiredSpeed =
    CHASE_SPEED

local FacingOkay = false

local ThreatLevel = "NONE"
local ThreatKind = "NONE"

local ThreatCurrent =
    math.huge

local ThreatFuture =
    math.huge

local HadThreat = false
local PreviousThreatLevel = "NONE"

local RemoteCastMode = false
local RemoteCastTarget = nil
local RemoteBestDistance = math.huge
local RemoteLastProgress = 0
local RemoteCastStarted = 0

local DodgePoint = nil
local DodgeUntil = 0
local LastDodgePlan = 0

local EvadePoint = nil
local LastEvadePlan = 0

local OrbitSide = 1

local BlockedSince = nil

--------------------------------------------------
-- STUCK
--------------------------------------------------

local LastPosition = nil
local LastPositionTime =
    os.clock()

local StuckCount = 0
local StationaryCount = 0
local StationaryRoot = nil
local StationaryPosition = nil
local StationaryTime = os.clock()

local function resetStuckCharacter(root)
    local character =
        root and root.Parent

    local humanoid =
        character
        and character:FindFirstChildOfClass(
            "Humanoid"
        )

    StuckCount = 0
    StationaryCount = 0
    StationaryRoot = nil
    StationaryPosition = nil
    StationaryTime = os.clock()
    LastPosition = nil
    LastPositionTime = os.clock()
    DesiredDirection = Vector3.zero
    Mode = "RESETTING"

    clearPath()

    if not humanoid
        or humanoid.Health <= 0 then

        return
    end

    pcall(function()
        humanoid.Health = 0
    end)

    pcall(function()
        humanoid:ChangeState(
            Enum.HumanoidStateType.Dead
        )
    end)

    pcall(function()
        character:BreakJoints()
    end)
end

local function stuckCheck(root)
    local now = os.clock()

    if not LastPosition then
        LastPosition =
            root.Position

        LastPositionTime =
            now

        return false
    end

    if now - LastPositionTime
        < STUCK_INTERVAL then

        return false
    end

    local displacement =
        flat(root.Position)
        - flat(LastPosition)

    local intended =
        flat(DesiredDirection)

    local progress =
        intended.Magnitude > 0.3
        and math.max(
            displacement:Dot(
                intended.Unit
            ),
            0
        )
        or displacement.Magnitude

    LastPosition =
        root.Position

    LastPositionTime =
        now

    local shouldBeMoving =
        ENABLED
        and DesiredSpeed > 1
        and intended.Magnitude > 0.3
        and Mode ~= "OFF"
        and Mode ~= "COOLDOWN"
        and Mode ~= "RANGED"
        and Mode ~= "RESETTING"

    if shouldBeMoving
        and progress < MIN_PROGRESS then

        StuckCount =
            StuckCount + 1

        if StuckCount
            > STUCK_RESET_LIMIT then

            resetStuckCharacter(root)
            return false
        end

        return true
    end

    if progress >= MIN_PROGRESS then
        StuckCount = 0
    end

    return false
end

local function stationaryResetCheck(root)
    local now = os.clock()

    local intentionallyStill =
        not ENABLED
        or Mode == "OFF"
        or Mode == "COOLDOWN"
        or Mode == "RANGED"
        or Mode == "BOSS HOLD"
        or Mode == "RESETTING"

    local movementExpected =
        not intentionallyStill
        and (
            validEnemy(Target)
            or (
                DesiredSpeed > 1
                and DesiredDirection.Magnitude > 0.3
            )
        )

    if StationaryRoot ~= root then
        StationaryRoot = root
        StationaryPosition = root.Position
        StationaryTime = now
        StationaryCount = 0
        return false
    end

    if not movementExpected then
        StationaryPosition = root.Position
        StationaryTime = now
        StationaryCount = 0
        return false
    end

    if now - StationaryTime
        < STUCK_INTERVAL then

        return false
    end

    local moved =
        (
            flat(root.Position)
            - flat(
                StationaryPosition
                    or root.Position
            )
        ).Magnitude

    StationaryPosition = root.Position
    StationaryTime = now

    if moved <= STATIONARY_DISTANCE then
        StationaryCount =
            StationaryCount + 1
    else
        StationaryCount = 0
    end

    if StationaryCount
        > STUCK_RESET_LIMIT then

        resetStuckCharacter(root)
        return true
    end

    return false
end

local function updateRemoteCastMode(
    target,
    distance,
    now
)
    if target ~= RemoteCastTarget then
        RemoteCastTarget = target
        RemoteCastMode = false
        RemoteBestDistance = distance
        RemoteLastProgress = now
        RemoteCastStarted = 0
    end

    if not validEnemy(target)
        or distance <= ABILITY_RANGE - 4
        or distance > REMOTE_ABILITY_RANGE then

        RemoteCastMode = false

        if validEnemy(target) then
            RemoteBestDistance = distance
            RemoteLastProgress = now
        end

        return false
    end

    if RemoteCastMode then
        if now - RemoteCastStarted
            >= REMOTE_CAST_HOLD then

            RemoteCastMode = false
            RemoteBestDistance = distance
            RemoteLastProgress = now
        end

        return RemoteCastMode
    end

    if distance
        <= RemoteBestDistance
            - REMOTE_PROGRESS_STEP then

        RemoteBestDistance = distance
        RemoteLastProgress = now

    elseif now - RemoteLastProgress
        >= REMOTE_PROGRESS_TIMEOUT then

        RemoteCastMode = true
        RemoteCastStarted = now
    end

    return RemoteCastMode
end

--------------------------------------------------
-- CHARACTER DEATH / RESPAWN RESET
--------------------------------------------------

local BoundCharacters = {}

local function resetCombatCycle(nextMode)
    SpellFlow:Reset()

    Target = nil
    TargetDistance = math.huge
    TargetAimPosition = nil
    TargetClusterCount = 0

    Mode = nextMode or "RESPAWN"
    DesiredDirection = Vector3.zero
    DesiredSpeed = CHASE_SPEED
    FacingOkay = false

    ThreatLevel = "NONE"
    ThreatKind = "NONE"
    ThreatCurrent = math.huge
    ThreatFuture = math.huge
    HadThreat = false
    PreviousThreatLevel = "NONE"

    State.OwnAbilityIgnoreUntil = 0
    State.SpacingActive = false
    State.TargetIsBoss = false
    State.BossCheckTarget = nil
    State.BossCheckResult = false
    State.BossCheckTime = 0

    RemoteCastMode = false
    RemoteCastTarget = nil
    RemoteBestDistance = math.huge
    RemoteLastProgress = os.clock()
    RemoteCastStarted = 0

    DodgePoint = nil
    DodgeUntil = 0
    LastDodgePlan = 0
    EvadePoint = nil
    LastEvadePlan = 0
    CurrentDodgeDirection = nil
    DodgeSide = "NONE"
    LastThreatSeen = 0
    BlockedSince = nil

    LastPosition = nil
    LastPositionTime = os.clock()
    StuckCount = 0
    StationaryCount = 0
    StationaryRoot = nil
    StationaryPosition = nil
    StationaryTime = os.clock()

    clearPath()

    pcall(function()
        if FacingAlign then
            FacingAlign.Enabled = false
        end
    end)
end

local function bindCharacterLifecycle(character)
    if BoundCharacters[character] then
        return
    end

    BoundCharacters[character] = true
    resetCombatCycle("RESPAWN")

    task.spawn(function()
        local humanoid =
            character:FindFirstChildOfClass(
                "Humanoid"
            )
            or character:WaitForChild(
                "Humanoid",
                10
            )

        if humanoid
            and humanoid:IsA("Humanoid") then

            connect(
                humanoid.Died,
                function()
                    resetCombatCycle("DEAD")
                end
            )
        end
    end)
end

connect(
    LP.CharacterAdded,
    bindCharacterLifecycle
)

if LP.Character then
    bindCharacterLifecycle(LP.Character)
end

--------------------------------------------------
-- MAIN AI
--------------------------------------------------

connect(
    RunService.Heartbeat,
    function()
        if not State.Alive then
            return
        end

        updateHazards()

        local character,
            root,
            humanoid =
                getCharacter()

        if not root then
            return
        end

        if not ENABLED then
            Mode = "OFF"

            DesiredDirection =
                Vector3.zero

            return
        end

        --------------------------------------------------
        -- TARGET IMMEDIATELY
        --------------------------------------------------

        if next(Hazards) ~= nil then
            fallbackEnemyScan()
        end

        Target,
            TargetDistance,
            TargetAimPosition,
            TargetClusterCount =
                chooseTarget(
                    root.Position,
                    Target
                )

        State.TargetIsBoss =
            State:IsBossEnemy(Target)

        if Target then
            local order =
                enemyRoomOrder(
                    Target
                )

            if order then
                LastRoomOrder =
                    math.max(
                        LastRoomOrder,
                        order
                    )
            end
        end

        --------------------------------------------------
        -- THREAT
        --------------------------------------------------

        local threat,
            level,
            currentDistance,
            futureDistance =
                getThreat(
                    root.Position,

                    flat(
                        root.AssemblyLinearVelocity
                        or Vector3.zero
                    ) * 0.60
                    + DesiredDirection
                        * DesiredSpeed
                        * 0.40
                )

        ThreatLevel =
            level or "NONE"

        ThreatKind =
            threat
            and (
                threat.Expanding
                and "EXPANDING-"
                    .. threat.Kind
                or threat.Kind
            )
            or "NONE"

        ThreatCurrent =
            currentDistance

        ThreatFuture =
            futureDistance

        local now = os.clock()

        SpellFlow:Observe(
            Target,
            now
        )

        updateRemoteCastMode(
            Target,
            TargetDistance,
            now
        )

        local threatAppeared =
            threat ~= nil
            and not HadThreat

        local threatEscalated =
            level == "EMERGENCY"
            and PreviousThreatLevel
                ~= "EMERGENCY"

        HadThreat =
            threat ~= nil

        PreviousThreatLevel =
            level or "NONE"

        if threat then
            LastThreatSeen = now
        elseif now - LastThreatSeen
            >= DODGE_SIDE_RELEASE then

            DodgeSide = "NONE"
        end

        --------------------------------------------------
        -- ZERO-DELAY FIRST REACTION
        -- Move immediately, then solve the longer route
        -- on the following heartbeat.
        --------------------------------------------------

        if threat
            and (
                threatAppeared
                or threatEscalated
            ) then

            local immediateDirection =
                quickDodgeDirection(
                    character,
                    root,
                    Target,
                    threat
                )

            if immediateDirection then
                CurrentDodgeDirection =
                    immediateDirection.Unit

                Mode =
                    level == "EMERGENCY"
                    and "DODGE"
                    or "EVADE"

                DesiredSpeed =
                    level == "EMERGENCY"
                    and DODGE_SPEED
                    or EVADE_SPEED

                DesiredDirection =
                    wallSteer(
                        immediateDirection,
                        root,
                        character
                    )

                if level == "EMERGENCY" then
                    DodgeUntil =
                        math.max(
                            DodgeUntil,
                            now + DODGE_LOCK
                        )
                end

                return
            end
        end

        if stationaryResetCheck(root) then
            return
        end

        --------------------------------------------------
        -- EMERGENCY
        --------------------------------------------------

        if level == "EMERGENCY" then
            local needsPlan =
                not DodgePoint

            if DodgePoint
                and not dodgeDestinationSafe(
                    root,
                    DodgePoint,
                    DODGE_SPEED
                ) then

                needsPlan = true
            end

            if needsPlan
                and now - LastDodgePlan
                    >= DODGE_REPLAN then

                local point,
                    side =
                    findEscape(
                        character,
                        root,
                        Target,
                        threat,
                        false
                    )

                if point then
                    DodgePoint = point
                    DodgeSide =
                        side or DodgeSide

                    local direction =
                        flat(
                            point
                            - root.Position
                        )

                    if direction.Magnitude > 0.05 then
                        CurrentDodgeDirection =
                            direction.Unit
                    end
                end

                LastDodgePlan = now
            end

            DodgeUntil =
                math.max(
                    DodgeUntil,
                    now + DODGE_LOCK
                )

            --------------------------------------------------
            -- EVEN IF SOLVER FAILS, NEVER FREEZE
            --------------------------------------------------

            if not DodgePoint then
                Mode = "DODGE"
                DesiredSpeed = DODGE_SPEED

                local fallback =
                    committedLateralFallback(
                        root,
                        Target,
                        threat
                    )

                if fallback then
                    CurrentDodgeDirection =
                        fallback.Unit

                    DesiredDirection =
                        wallSteer(
                            fallback,
                            root,
                            character
                        )
                end

                return
            end
        end

        --------------------------------------------------
        -- COMMITTED DODGE
        --------------------------------------------------

        if DodgePoint
            and (
                now < DodgeUntil
                or level == "EMERGENCY"
            ) then

            Mode = "DODGE"
            DesiredSpeed = DODGE_SPEED

            if not dodgeDestinationSafe(
                root,
                DodgePoint,
                DODGE_SPEED
            )
                and now - LastDodgePlan
                    >= DODGE_REPLAN then

                local newPoint,
                    newSide =
                    findEscape(
                        character,
                        root,
                        Target,
                        threat,
                        false
                    )

                if newPoint then
                    DodgePoint = newPoint
                    DodgeSide =
                        newSide or DodgeSide

                    local direction =
                        flat(
                            newPoint
                            - root.Position
                        )

                    if direction.Magnitude > 0.05 then
                        CurrentDodgeDirection =
                            direction.Unit
                    end
                end

                LastDodgePlan = now
            end

            local delta =
                flat(
                    DodgePoint
                    - root.Position
                )

            if delta.Magnitude > 2.2 then
                DesiredDirection =
                    wallSteer(
                        delta,
                        root,
                        character
                    )

                return
            end

            if level ~= "EMERGENCY" then
                DodgePoint = nil
                CurrentDodgeDirection = nil
            end

        else
            DodgePoint = nil

            if level ~= "EMERGENCY" then
                CurrentDodgeDirection = nil
            end
        end

        --------------------------------------------------
        -- WARNING
        --
        -- DO NOT RUN FROM BOSS.
        -- Reposition while staying aggressive.
        --------------------------------------------------

        if level == "WARNING" then
            Mode = "EVADE"
            DesiredSpeed = EVADE_SPEED

            local replan =
                not EvadePoint

            if EvadePoint
                and not dodgeDestinationSafe(
                    root,
                    EvadePoint,
                    EVADE_SPEED
                ) then

                replan = true
            end

            if EvadePoint
                and (
                    flat(
                        EvadePoint
                        - root.Position
                    )
                ).Magnitude < 2.5 then

                replan = true
            end

            if replan
                and now - LastEvadePlan
                    >= EVADE_REPLAN then

                local side

                EvadePoint,
                    side =
                    findEscape(
                        character,
                        root,
                        Target,
                        threat,
                        true
                    )

                if EvadePoint then
                    DodgeSide =
                        side or DodgeSide
                end

                LastEvadePlan = now
            end

            if EvadePoint then
                DesiredDirection =
                    wallSteer(
                        EvadePoint
                        - root.Position,

                        root,
                        character
                    )

                return
            end

            --------------------------------------------------
            -- FALLBACK STRAFE
            --------------------------------------------------

            local fallback =
                committedLateralFallback(
                    root,
                    Target,
                    threat
                )

            if fallback then
                CurrentDodgeDirection =
                    fallback

                DesiredDirection =
                    wallSteer(
                        fallback,
                        root,
                        character
                    )

                return
            end

        else
            EvadePoint = nil
        end

        --------------------------------------------------
        -- PACK CLEARED: WAIT FOR Q/E TO BE READY
        --------------------------------------------------

        if SpellFlow:ShouldHold() then
            Mode = "COOLDOWN"
            DesiredSpeed = 0
            DesiredDirection = Vector3.zero

            StuckCount = 0
            LastPosition = root.Position
            LastPositionTime = now

            clearPath()
            return
        end

        --------------------------------------------------
        -- UNREACHABLE LONG-RANGE TARGET
        -- Hold a safe casting position instead of forcing
        -- movement into a wall or off the arena.
        --------------------------------------------------

        if RemoteCastMode
            and validEnemy(Target) then

            Mode = "RANGED"
            DesiredSpeed = 0
            DesiredDirection = Vector3.zero

            StuckCount = 0
            LastPosition = root.Position
            LastPositionTime = now

            clearPath()
            return
        end

        --------------------------------------------------
        -- NO TARGET
        --------------------------------------------------

        if not Target then
            State.SpacingActive = false

            fallbackEnemyScan()

            local room =
                findNextRoom(
                    LastRoomOrder
                )

            local point =
                roomProgressPoint(
                    room,
                    root.Position
                )

            if point then
                Mode = "NEXT ROOM"
                DesiredSpeed = NEXT_ROOM_SPEED

                local delta =
                    flat(
                        point.Position
                        - root.Position
                    )

                if delta.Magnitude > 2.5 then
                    if staticRouteClear(
                        root.Position,
                        point.Position,
                        character
                    ) then

                        clearPath()

                        DesiredDirection =
                            wallSteer(
                                delta,
                                root,
                                character
                            )

                    else
                        local pathChanged =
                            not PathDestination
                            or (
                                flat(
                                    PathDestination
                                    - point.Position
                                )
                            ).Magnitude > 6

                        if pathChanged
                            or not Waypoints then

                            buildPath(
                                root.Position,
                                point.Position,
                                true
                            )
                        end

                        local direction =
                            pathDirection(
                                root,
                                humanoid
                            )

                        if direction then
                            DesiredDirection =
                                wallSteer(
                                    direction,
                                    root,
                                    character
                                )
                        else
                            DesiredDirection =
                                wallSteer(
                                    delta,
                                    root,
                                    character
                                )
                        end
                    end
                else
                    DesiredDirection =
                        Vector3.zero
                end

                if stuckCheck(root) then
                    buildPath(
                        root.Position,
                        point.Position,
                        true
                    )
                end

                return
            end

            Mode = "SCANNING"
            DesiredSpeed = NEXT_ROOM_SPEED
            DesiredDirection = Vector3.zero

            return
        end

        --------------------------------------------------
        -- ENEMY MOVEMENT
        --------------------------------------------------

        local enemyRoot =
            Target:FindFirstChild(
                "HumanoidRootPart"
            )

        if not enemyRoot then
            return
        end

        local navigationPosition =
            TargetAimPosition
            or enemyRoot.Position

        local toward =
            flat(
                navigationPosition
                - root.Position
            )

        if toward.Magnitude < 0.05 then
            toward =
                flat(
                    enemyRoot.Position
                    - root.Position
                )
        end

        if toward.Magnitude < 0.05 then
            toward =
                flat(root.CFrame.LookVector)
        end

        --------------------------------------------------
        -- STUCK
        --------------------------------------------------

        if stuckCheck(root) then
            buildPath(
                root.Position,
                navigationPosition,
                true
            )
        end

        --------------------------------------------------
        -- PROACTIVE PATH AROUND WALLS
        --------------------------------------------------

        if TargetDistance
            > DESIRED_DISTANCE + 3 then

                local direct =
                staticRouteClear(
                    root.Position,
                    navigationPosition,
                    character
                )

            if not direct then
                if not BlockedSince then
                    BlockedSince = now
                end

                if now - BlockedSince
                    >= BLOCKED_DELAY then

                    local changed =
                        not PathDestination
                        or (
                            flat(
                                PathDestination
                                - navigationPosition
                            )
                        ).Magnitude > 7

                    if changed
                        or not Waypoints then

                        buildPath(
                            root.Position,
                            navigationPosition,
                            changed
                        )
                    end

                    local direction =
                        pathDirection(
                            root,
                            humanoid
                        )

                    if direction then
                        Mode = "PATH"
                        DesiredSpeed = PATH_SPEED

                        DesiredDirection =
                            wallSteer(
                                direction,
                                root,
                                character
                            )

                        return
                    end
                end

            else
                BlockedSince = nil

                if StuckCount == 0 then
                    clearPath()
                end
            end

        else
            BlockedSince = nil
        end

        if TargetDistance < FORCE_SPACE_ENTER then
            State.SpacingActive = true
        elseif TargetDistance >= FORCE_SPACE_EXIT then
            State.SpacingActive = false
        end

        --------------------------------------------------
        -- FORCED PERSONAL SPACE WITH HYSTERESIS
        --------------------------------------------------

        if State.TargetIsBoss then
            local radial = toward.Unit

            if TargetDistance
                < FORCE_SPACE_ENTER then

                Mode = "BOSS SPACE"
                DesiredSpeed = SPACE_SPEED
                DesiredDirection =
                    wallSteer(
                        -radial,
                        root,
                        character
                    )

            elseif TargetDistance
                > DESIRED_DISTANCE + 2 then

                Mode = "BOSS CHASE"
                DesiredSpeed = CHASE_SPEED
                DesiredDirection =
                    wallSteer(
                        radial,
                        root,
                        character
                    )

            else
                Mode = "BOSS HOLD"
                DesiredSpeed = 0
                DesiredDirection = Vector3.zero
            end

        elseif State.SpacingActive then

            Mode = "SPACE"
            DesiredSpeed = SPACE_SPEED

            local radial =
                toward.Unit

            local tangent =
                Vector3.new(
                    -radial.Z,
                    0,
                    radial.X
                )
                * OrbitSide

            DesiredDirection =
                wallSteer(
                    -radial
                    + tangent * 0.10,

                    root,
                    character
                )

        --------------------------------------------------
        -- CHASE
        --------------------------------------------------

        elseif TargetDistance
            > DESIRED_DISTANCE + 4 then

            Mode = "CHASE"
            DesiredSpeed = CHASE_SPEED

            DesiredDirection =
                wallSteer(
                    toward,
                    root,
                    character
                )

        --------------------------------------------------
        -- ATTACK ORBIT
        --------------------------------------------------

        else
            Mode = "ORBIT"
            DesiredSpeed = ORBIT_SPEED

            local radial =
                toward.Unit

            local tangent =
                Vector3.new(
                    -radial.Z,
                    0,
                    radial.X
                )
                * OrbitSide

            local correction =
                math.clamp(
                    (
                        TargetDistance
                        - DESIRED_DISTANCE
                    ) / 7,

                    -0.35,
                    0.35
                )

            DesiredDirection =
                wallSteer(
                    tangent
                    + radial
                        * correction,

                    root,
                    character
                )
        end
    end
)

--------------------------------------------------
-- MOVEMENT + FACING
--------------------------------------------------

RunService:BindToRenderStep(
    State.RenderName,

    Enum.RenderPriority.Character.Value + 2,

    function()
        if not State.Alive then
            return
        end

        local character,
            root,
            humanoid =
                getCharacter()

        if not root then
            return
        end

        if not ENABLED then
            humanoid.AutoRotate = true

            humanoid:Move(
                Vector3.zero,
                false
            )

            if FacingAlign then
                FacingAlign.Enabled =
                    false
            end

            return
        end

        humanoid.WalkSpeed =
            math.clamp(
                DesiredSpeed,
                0,
                MAX_SPEED
            )

        humanoid.AutoRotate = false

        humanoid:Move(
            DesiredDirection,
            false
        )

        --------------------------------------------------
        -- ALWAYS FACE ENEMY
        --------------------------------------------------

        FacingOkay =
            faceTarget(
                root,
                Target,
                TargetAimPosition
            )

        --------------------------------------------------
        -- STILL ATTACK WHILE EVADE
        --------------------------------------------------

        SpellFlow:Use(
            Target,
            TargetDistance,
            FacingOkay,
            Mode,
            RemoteCastMode
        )
    end
)

--------------------------------------------------
-- ORBIT SWITCH
--------------------------------------------------

task.spawn(function()
    while State.Alive do
        task.wait(4)

        if Mode == "ORBIT" then

            OrbitSide =
                -OrbitSide
        end
    end
end)

--------------------------------------------------
-- RUN AUTOMATION
--------------------------------------------------

local function startRunAutomation()

local function isVisibleGuiObject(object)
    local current = object

    while current do
        if current:IsA("GuiObject")
            and not current.Visible then

            return false
        end

        if current:IsA("LayerCollector")
            and not current.Enabled then

            return false
        end

        current = current.Parent
    end

    return true
end

local function isOwnInterfaceObject(object)
    local current = object

    for _ = 1, 10 do
        if not current then
            break
        end

        local name =
            string.lower(
                current.Name or ""
            )

        if name:find("xyneria", 1, true)
            or name:find("dqcombat", 1, true)
            or name:find("combatpilot", 1, true) then

            return true
        end

        current = current.Parent
    end

    return false
end

local function guiButtonBlob(button)
    local pieces = {}
    local current = button

    for _ = 1, 5 do
        if not current then
            break
        end

        table.insert(
            pieces,
            string.lower(
                current.Name or ""
            )
        )

        if current:IsA("TextButton")
            or current:IsA("TextLabel") then

            table.insert(
                pieces,
                string.lower(
                    current.Text or ""
                )
            )
        end

        current = current.Parent
    end

    for _, descendant in ipairs(
        button:GetDescendants()
    ) do
        if descendant:IsA("TextLabel")
            or descendant:IsA("TextButton") then

            table.insert(
                pieces,
                string.lower(
                    descendant.Text or ""
                )
            )
        else
            table.insert(
                pieces,
                string.lower(
                    descendant.Name or ""
                )
            )
        end
    end

    return table.concat(pieces, " ")
end

local ACTION_WORDS = {
    START = {
        "start dungeon",
        "startgame",
        "startbutton",
        "start button",
        "begin dungeon",
        "play dungeon",
        "start"
    },

    REPLAY = {
        "replay",
        "restart dungeon",
        "retry dungeon",
        "play again",
        "retry"
    },

    LOBBY = {
        "back to lobby",
        "return to lobby",
        "leave dungeon",
        "lobbybutton",
        "lobby button",
        "lobby",
        "leave"
    },

    CONFIRM = {
        "yes",
        "confirm",
        "accept"
    }
}

local function actionMatches(blob, action)
    for _, word in ipairs(
        ACTION_WORDS[action]
        or {}
    ) do
        if blob:find(
            word,
            1,
            true
        ) then

            return true
        end
    end

    return false
end

local function getPlayerGui()
    return LP:FindFirstChildOfClass(
        "PlayerGui"
    )
end

local function findNamedActionButton(action)
    local playerGui = getPlayerGui()

    if not playerGui then
        return nil
    end

    for _, object in ipairs(
        playerGui:GetDescendants()
    ) do
        if object:IsA("GuiButton")
            and isVisibleGuiObject(object)
            and not isOwnInterfaceObject(object) then

            local blob =
                guiButtonBlob(object)

            if action == "START"
                and (
                    blob:find("restart", 1, true)
                    or blob:find("replay", 1, true)
                    or blob:find("retry", 1, true)
                ) then

                -- Never confuse replay with the start button.

            elseif actionMatches(
                blob,
                action
            ) then

                return object
            end
        end
    end

    return nil
end

local function findEndIconButton(action)
    local playerGui = getPlayerGui()
    local camera = Workspace.CurrentCamera

    if not playerGui
        or not camera then

        return nil
    end

    local viewport =
        camera.ViewportSize

    local candidates = {}

    for _, object in ipairs(
        playerGui:GetDescendants()
    ) do
        if object:IsA("GuiButton")
            and isVisibleGuiObject(object)
            and not isOwnInterfaceObject(object) then

            local size = object.AbsoluteSize
            local position = object.AbsolutePosition

            local centerX =
                position.X + size.X / 2

            local centerY =
                position.Y + size.Y / 2

            local ratio =
                size.Y > 0
                and size.X / size.Y
                or 0

            if size.X >= 28
                and size.X <= 92
                and size.Y >= 28
                and size.Y <= 92
                and ratio >= 0.70
                and ratio <= 1.35
                and centerX
                    >= viewport.X * 0.75
                and centerY
                    >= viewport.Y * 0.64 then

                table.insert(
                    candidates,
                    {
                        Button = object,
                        X = centerX,
                        Y = centerY
                    }
                )
            end
        end
    end

    table.sort(
        candidates,
        function(a, b)
            if math.abs(a.Y - b.Y) > 22 then
                return a.Y < b.Y
            end

            return a.X < b.X
        end
    )

    if action == "REPLAY" then
        return candidates[1]
            and candidates[1].Button
            or nil
    end

    if action == "LOBBY" then
        return candidates[2]
            and candidates[2].Button
            or nil
    end

    return nil
end

local function clickGuiButton(button)
    if not button
        or not button.Parent
        or not isVisibleGuiObject(button) then

        return false
    end

    local activated =
        pcall(function()
            button:Activate()
        end)

    if activated then
        return true
    end

    local position = button.AbsolutePosition
    local size = button.AbsoluteSize

    local x = position.X + size.X / 2
    local y = position.Y + size.Y / 2

    local success =
        pcall(function()
            VirtualInputManager:
                SendMouseButtonEvent(
                    x,
                    y,
                    0,
                    true,
                    game,
                    0
                )

            VirtualInputManager:
                SendMouseButtonEvent(
                    x,
                    y,
                    0,
                    false,
                    game,
                    0
                )
        end)

    return success
end

local function confirmGameAction()
    task.spawn(function()
        for _ = 1, 10 do
            task.wait(0.20)

            local confirm =
                findNamedActionButton(
                    "CONFIRM"
                )

            if confirm
                and clickGuiButton(confirm) then

                return
            end
        end
    end)
end

local function triggerGameAction(action)
    local button =
        findNamedActionButton(action)

    if not button
        and (
            action == "REPLAY"
            or action == "LOBBY"
        ) then

        button =
            findEndIconButton(action)
    end

    if not clickGuiButton(button) then
        return false
    end

    if action ~= "START" then
        confirmGameAction()
    end

    return true
end

local function visibleCompletionSignal()
    local playerGui = getPlayerGui()

    if not playerGui then
        return false
    end

    local signals = {
        "dungeon complete",
        "dungeon completed",
        "victory",
        "completion rewards",
        "run complete"
    }

    for _, object in ipairs(
        playerGui:GetDescendants()
    ) do
        if (
            object:IsA("TextLabel")
            or object:IsA("TextButton")
        )
            and isVisibleGuiObject(object) then

            local text =
                string.lower(
                    object.Text or ""
                )

            for _, signal in ipairs(signals) do
                if text:find(
                    signal,
                    1,
                    true
                ) then

                    return true
                end
            end
        end
    end

    return false
end

local RunSawEnemy = false
local EmptyRunSince = nil
local PostRunActionTaken = false
local LastPostRunAttempt = 0
local LastAutoStartAttempt = 0
local LastAutomationTick = 0

connect(
    RunService.Heartbeat,
    function()
        if not State.Alive then
            return
        end

        local now = os.clock()

        if now - LastAutomationTick < 0.25 then
            return
        end

        LastAutomationTick = now

        if AUTO_START
            and now - LastAutoStartAttempt
                >= 1.25 then

            if triggerGameAction("START") then
                LastAutoStartAttempt = now
            end
        end

        local aliveEnemies = 0

        for enemy in pairs(Enemies) do
            if validEnemy(enemy) then
                aliveEnemies =
                    aliveEnemies + 1
            end
        end

        if aliveEnemies > 0 then
            RunSawEnemy = true
            EmptyRunSince = nil
            PostRunActionTaken = false

            return
        end

        if not RunSawEnemy then
            return
        end

        if not EmptyRunSince then
            EmptyRunSince = now
        end

        local completionReady =
            visibleCompletionSignal()
            or (
                now - EmptyRunSince >= 4
                and not findNextRoom(
                    LastRoomOrder
                )
            )

        if not completionReady
            or PostRunActionTaken
            or now - LastPostRunAttempt < 0.75 then

            return
        end

        local action =
            AUTO_LOBBY
            and "LOBBY"
            or AUTO_REPLAY
                and "REPLAY"
                or nil

        if not action then
            return
        end

        LastPostRunAttempt = now

        if triggerGameAction(action) then
            PostRunActionTaken = true
        end
    end
)

end

startRunAutomation()

--------------------------------------------------
-- GUI
--------------------------------------------------

local XYNERIA_WIND_URL =
    "https://raw.githubusercontent.com/itsmashood/xyneria-Ui/main/XyneriaUI_Wind.lua"

local function createInterface()
    local success, interfaceError =
        pcall(function()
            local source =
                game:HttpGet(
                    XYNERIA_WIND_URL
                )

            local compile, compileError =
                loadstring(source)

            if not compile then
                error(compileError)
            end

            local XyneriaUI = compile()

            if not XyneriaUI then
                error(
                    "Xyneria WindUI adapter returned no library"
                )
            end

            local app =
                XyneriaUI:CreateWindow({
                    Title = "DUNGEON QUEST",
                    Author = "XYNERIA",
                    Version = "V7.5",
                    Live = true,
                    StatusTitle = "COMBAT PILOT",
                    Folder = "Xyneria_DungeonQuest",
                    Size = UDim2.fromOffset(
                        720,
                        470
                    ),
                    MinSize = Vector2.new(
                        560,
                        350
                    ),
                    MaxSize = Vector2.new(
                        960,
                        680
                    ),
                    Theme = "Xyneria",
                    HideSearchBar = true,
                    ScrollBarEnabled = false,
                    OpenButton = {
                        Title = "DQ",
                        Enabled = true,
                        Draggable = true,
                        OnlyMobile = false,
                        Scale = 0.46,
                        CornerRadius = UDim.new(1, 0),
                        StrokeThickness = 2
                    }
                })

            if not app then
                error(
                    "Xyneria WindUI window was not created"
                )
            end

            State.Interface = app

            local combatSidebar =
                app:Section({
                    Title = "COMBAT",
                    Opened = true
                })

            local combatTab =
                combatSidebar:Tab({
                    Title = "Combat Pilot",
                    Icon = "swords",
                    Desc = "Targeting, spells and dodging"
                })

            local combatControls =
                combatTab:Section({
                    Title = "Main controls",
                    Icon = "crosshair",
                    Opened = true,
                    Box = true
                })

            combatControls:Toggle({
                Title = "Combat Pilot",
                Desc = "Movement, targeting and smart dodging",
                Value = ENABLED,
                Flag = "DQCombatPilot",
                Callback = function(value)
                    ENABLED = value

                    if not value then
                        DesiredDirection =
                            Vector3.zero
                    end
                end
            })

            combatControls:Toggle({
                Title = "Auto Q — Inner Focus",
                Desc = "Cast once at the start of each mob pack",
                Value = AUTO_Q,
                Flag = "DQAutoQ",
                Callback = function(value)
                    AUTO_Q = value
                end
            })

            combatControls:Toggle({
                Title = "Auto E — Geyser",
                Desc = "Cast once at the start of each mob pack",
                Value = AUTO_E,
                Flag = "DQAutoE",
                Callback = function(value)
                    AUTO_E = value
                end
            })

            combatControls:Toggle({
                Title = "Spam Spells",
                Desc = "Use Q/E repeatedly near enemies; skip pack waiting",
                Value = State.SpamSpells,
                Flag = "DQSpamSpells",
                Callback = function(value)
                    State.SpamSpells = value
                end
            })

            combatTab:Paragraph({
                Title = "Forced mob spacing",
                Desc = "Retreat inside 14 studs; resume at 17 studs.",
                Icon = "move-horizontal"
            })

            local automationSidebar =
                app:Section({
                    Title = "AUTOMATION",
                    Opened = true
                })

            local automationTab =
                automationSidebar:Tab({
                    Title = "Dungeon Flow",
                    Icon = "repeat-2",
                    Desc = "Start and completion actions"
                })

            local flowControls =
                automationTab:Section({
                    Title = "Run automation",
                    Icon = "route",
                    Opened = true,
                    Box = true
                })

            flowControls:Toggle({
                Title = "Auto Start",
                Desc = "Press Start when the dungeon button appears",
                Value = AUTO_START,
                Flag = "DQAutoStart",
                Callback = function(value)
                    AUTO_START = value
                end
            })

            local replayToggle = nil
            local lobbyToggle = nil

            replayToggle =
                flowControls:Toggle({
                    Title = "Auto Replay",
                    Desc = "Use the curly-arrow button after completion",
                    Value = AUTO_REPLAY,
                    Flag = "DQAutoReplay",
                    Callback = function(value)
                        AUTO_REPLAY = value

                        if value then
                            AUTO_LOBBY = false

                            if lobbyToggle then
                                lobbyToggle:Set(false)
                            end
                        end
                    end
                })

            lobbyToggle =
                flowControls:Toggle({
                    Title = "Auto Back to Lobby",
                    Desc = "Use the door button after completion",
                    Value = AUTO_LOBBY,
                    Flag = "DQAutoLobby",
                    Callback = function(value)
                        AUTO_LOBBY = value

                        if value then
                            AUTO_REPLAY = false

                            if replayToggle then
                                replayToggle:Set(false)
                            end
                        end
                    end
                })

            local informationSidebar =
                app:Section({
                    Title = "INFORMATION",
                    Opened = true
                })

            local statusTab =
                informationSidebar:Tab({
                    Title = "Live Status",
                    Icon = "activity",
                    Desc = "Combat and hazard telemetry"
                })

            local statusPanel =
                statusTab:Section({
                    Title = "Combat telemetry",
                    Icon = "radar",
                    Opened = true,
                    Box = true
                })

            local statusCode =
                statusPanel:Code({
                    Title = "live_status.txt",
                    Code = "Combat Pilot is starting...",
                    CodeSize = 14,
                    Height = 285
                })

            local settingsTab =
                informationSidebar:Tab({
                    Title = "Settings",
                    Icon = "settings",
                    Desc = "Configuration"
                })

            local settingsControls =
                settingsTab:Section({
                    Title = "Configuration",
                    Opened = true,
                    Box = true
                })

            settingsControls:Button({
                Title = "Save configuration",
                Icon = "save",
                Callback = function()
                    local ok =
                        app:SaveConfig(
                            "dungeon_quest"
                        )

                    app:Notify(
                        "Configuration",
                        ok
                            and "Saved."
                            or "Could not save.",
                        ok and "check" or "x",
                        2
                    )
                end
            })

            settingsControls:Button({
                Title = "Load configuration",
                Icon = "folder-open",
                Callback = function()
                    local ok =
                        app:LoadConfig(
                            "dungeon_quest"
                        )

                    app:Notify(
                        "Configuration",
                        ok
                            and "Loaded."
                            or "Could not load.",
                        ok and "check" or "x",
                        2
                    )
                end
            })

            local statusElapsed = 0

            connect(
                RunService.Heartbeat,
                function(dt)
                    statusElapsed =
                        statusElapsed + dt

                    if statusElapsed < 0.10 then
                        return
                    end

                    statusElapsed = 0

                    local hazardCount = 0
                    local expandingCount = 0
                    local laserCount = 0
                    local projectileCount = 0
                    local enemyCount = 0

                    for _, hazard in pairs(
                        Hazards
                    ) do
                        hazardCount =
                            hazardCount + 1

                        if hazard.Expanding then
                            expandingCount =
                                expandingCount + 1
                        end

                        if hazard.Kind == "LASER" then
                            laserCount =
                                laserCount + 1
                        elseif hazard.Kind
                            == "PROJECTILE" then

                            projectileCount =
                                projectileCount + 1
                        end
                    end

                    for enemy in pairs(Enemies) do
                        if validEnemy(enemy) then
                            enemyCount =
                                enemyCount + 1
                        end
                    end

                    local targetName =
                        Target
                        and Target.Name
                        or "NONE"

                    local distanceText =
                        TargetDistance < math.huge
                        and string.format(
                            "%.1f",
                            TargetDistance
                        )
                        or "-"

                    local dangerNow =
                        ThreatCurrent
                        and string.format(
                            "%.1f",
                            ThreatCurrent
                        )
                        or "-"

                    local dangerFuture =
                        ThreatFuture
                        and string.format(
                            "%.1f",
                            ThreatFuture
                        )
                        or "-"

                    local pathText =
                        Waypoints
                        and (
                            tostring(CurrentWaypoint)
                            .. "/"
                            .. tostring(#Waypoints)
                        )
                        or "NO"

                    local content =
                        "Mode: "
                        .. Mode
                        .. "\nTarget: "
                        .. targetName
                        .. "\nDistance: "
                        .. distanceText
                        .. "\nFacing: "
                        .. (
                            FacingOkay
                            and "YES"
                            or "NO"
                        )
                        .. " | Type:"
                        .. (
                            State.TargetIsBoss
                            and "BOSS"
                            or "MOB"
                        )
                        .. " | Cluster:"
                        .. tostring(
                            TargetClusterCount
                        )
                        .. "\nThreat: "
                        .. ThreatLevel
                        .. " / "
                        .. ThreatKind
                        .. "\nDanger now/future: "
                        .. dangerNow
                        .. " / "
                        .. dangerFuture
                        .. "\nDodge side: "
                        .. DodgeSide
                        .. " | Expand:"
                        .. expandingCount
                        .. "\nHazards: "
                        .. hazardCount
                        .. " | Lasers:"
                        .. laserCount
                        .. " | Proj:"
                        .. projectileCount
                        .. "\nEnemies: "
                        .. enemyCount
                        .. " | Room:"
                        .. tostring(LastRoomOrder)
                        .. "\nPath: "
                        .. pathText
                        .. " | Stuck:"
                        .. tostring(StuckCount)
                        .. " | Still:"
                        .. tostring(StationaryCount)
                        .. "\nSpells: "
                        .. SpellFlow:Status()
                        .. "\nProfile: "
                        .. DungeonData.Name
                        .. "\nStart:"
                        .. (
                            AUTO_START
                            and "ON"
                            or "OFF"
                        )
                        .. " Replay:"
                        .. (
                            AUTO_REPLAY
                            and "ON"
                            or "OFF"
                        )
                        .. " Lobby:"
                        .. (
                            AUTO_LOBBY
                            and "ON"
                            or "OFF"
                        )

                    statusCode:SetCode(content)
                end
            )

            app:Notify(
                "Combat Pilot V7.5",
                "Footagesus WindUI loaded with the Xyneria theme.",
                "check",
                2
            )
        end)

    if not success and warn then
        warn(
            "Combat Pilot WindUI error: "
            .. tostring(interfaceError)
        )
    end
end

createInterface()

print(
    "Dungeon Quest Combat Pilot V7.5 loaded"
)
