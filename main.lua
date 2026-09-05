--// Dungeon Quest Combat Pilot V7.21
--// Build: V7.21-AGGRESSIVE-ADAPTIVE-UNSTUCK-20260905
--// Safe-gap committed dodge + expanding hazard prediction
--// Global enemyProjectiles hazard registry + safe/context exclusions
--// PRECAST warning zones + strict no-contact live-hazard envelopes
--// Dense mob-cluster aim + full respawn combat reset
--// Dynamic spell data + buff-first paired casting
--// Low-overhead combat loop + cached boss detection
--// Close-chaser priority + route-guided distant targets
--// Shared enemy spacing + optional live adaptive pathfinding
--// Long-range boss cast/retreat cycle + boss-only death spacing
--// Nearest-body mob spacing + party-safe far-target routing
--// Walking-only dodge; no teleport, flight, or tween movement
--// Persistent live-target facing through dodge, route, and target refresh gaps
--// Utility-based Adaptive Director owns movement and spell timing when enabled
--// True Spam Spells: independent instant Q/E attempts, including while dodging
--// True Spam survives respawn and never waits for a target, pack, or range gate
--// Warning casts continue while moving; emergency attacks resume after first dodge
--// Fast dodge-stall recovery discards blocked points and reverses escape side
--// Walls-only noclip; floors and platforms remain collidable
--// Maximum WalkSpeed = 20
--// Startup-safe hazard scan + corrected Beam tracking
--// Soft profile routes: combat/dodging free-roam, then forward route rejoin
--//
--// Q / E are detected from their live abilitySlot values

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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

local DESIRED_DISTANCE = 48
local FORCE_SPACE_ENTER = 46
local FORCE_SPACE_EXIT = 47

local MOB_CLUSTER_RADIUS = 24
local MOB_CLUSTER_STICK_RADIUS = 13
local MOB_CLUSTER_SEARCH_EXTRA = 55
local MOB_CLUSTER_MAX_DISTANCE = 120
local MOB_CLUSTER_DENSITY_BONUS = 12
local MOB_CLUSTER_VERTICAL_LIMIT = 28

local TARGET_LEASH_DISTANCE = 30
local BOB_LEASH_DISTANCE = 26
local LEASH_INWARD_START = 4
local LEASH_MAX_INWARD = 0.72

local Q_ABILITY_RANGE = 40
local E_ABILITY_RANGE = 40
local TAUNT_ABILITY_RANGE = 22
local REMOTE_PROGRESS_TIMEOUT = 1.35
local REMOTE_PROGRESS_STEP = 2.0
local REMOTE_CAST_HOLD = 5.0
local FACE_DOT_REQUIRED = 0.93
local BOSS_RANGE_BUFFER = 0.75

local PACK_CLEAR_GRACE = 0.55
local SPELL_FALLBACK_COOLDOWN = 8.5
local SPELL_SPAM_INTERVAL = 0.50
local ABILITY_SCAN_INTERVAL = 0.20
local PAIR_CAST_START_TIMEOUT = 0.55
local PAIR_CAST_CLEAR_TIMEOUT = 1.60
local PAIR_CAST_POLL = 0.025
local PAIR_CAST_FALLBACK_GAP = 0.10
local OWN_BUFF_IGNORE_TIME = 1.35
local OWN_BUFF_IGNORE_RADIUS = 16
local SHOW_HAZARD_BOXES = false

local DUNGEON_PROFILE_BASE_URL =
    ENV.DQ_DUNGEON_PROFILE_BASE_URL
    or "https://raw.githubusercontent.com/itsmashood/dqr-info/main"

--------------------------------------------------
-- PREDICTION / HAZARDS / DODGE / PATHING
--------------------------------------------------

local CFG = {
    MIN_ENEMY_DISTANCE = 39,
    ENEMY_DEATH_DISTANCE_STEP = 4,
    ENEMY_DEATH_DISTANCE_MAX = 16,
    ENEMY_CAST_RANGE_BUFFER = 1,
    MOB_CAST_RANGE_CAP = 48,
    MOB_SPACING_ENTER_OFFSET = 2,
    MOB_SPACING_EXIT_OFFSET = 1,
    BOSS_PREFERRED_DISTANCE = 70,
    BOSS_MINIMUM_CAST_DISTANCE = 55,
    BOSS_TARGET_RADIUS_CAP = 22,
    BOSS_CAST_PROBE_EXTRA = 14,
    BOSS_SPELL_SPAM_INTERVAL = 0.30,
    BOSS_DEATH_DISTANCE_STEP = 8,
    BOSS_DEATH_DISTANCE_MAX = 24,
    BOSS_CAST_RANGE_BUFFER = 1,
    BOSS_OUTER_ENTER_OFFSET = 5,
    BOSS_OUTER_EXIT_OFFSET = 2,
    BOSS_CAST_ENTER_OFFSET = 2,
    BOSS_CAST_EXIT_OFFSET = 0.75,
    POST_DODGE_CAST_WINDOW = 0.45,
    FACING_TARGET_GRACE = 0.30,
    TRUE_SPAM_INPUT_INTERVAL = 0.05,
    ADAPTIVE_THINK_INTERVAL = 1 / 15,
    ADAPTIVE_FIRST_DODGE_TIME = 0.16,
    ADAPTIVE_DAMAGE_MEMORY = 1.25,
    ADAPTIVE_DAMAGE_SPIKE_RATIO = 0.012,
    ADAPTIVE_LOW_HEALTH_RATIO = 0.42,
    ADAPTIVE_CRITICAL_HEALTH_RATIO = 0.22,
    ADAPTIVE_DISTANCE_BONUS_MAX = 10,
    ADAPTIVE_HEALTH_DISTANCE_BONUS = 5,
    ADAPTIVE_DAMAGE_DISTANCE_BONUS = 5,
    ADAPTIVE_PROGRESS_STEP = 1.5,
    ADAPTIVE_STALL_TIME = 1.10,
    ADAPTIVE_LOCAL_PATH_EXTRA = 7,
    ADAPTIVE_CAST_RISK_LIMIT = 0.92,
    DODGE_PROGRESS_INTERVAL = 0.28,
    DODGE_PROGRESS_MIN = 0.35,
    COMBAT_DEATH_STREAK_WINDOW = 180,
    BODY_RADIUS = 2.2,
    PREDICT_NEAR = 0.24,
    PREDICT_FAR = 0.55,
    EXPAND_PREDICT = 0.72,
    AI_UPDATE_INTERVAL = 1 / 30,
    TARGET_UPDATE_INTERVAL = 0.075,
    HAZARD_UPDATE_INTERVAL = 1 / 30,
    ENEMY_FALLBACK_INTERVAL = 1.00,
    PARTY_IGNORE_REFRESH = 0.35,
    SPELL_DECISION_INTERVAL = 0.05,
    CLOSE_DANGER_DISTANCE = 15,
    CHASER_PRIORITY_DISTANCE = 28,
    CHASER_APPROACH_SPEED = 2.0,
    CHASER_FACING_DOT = 0.55,
    DANGER_CLUSTER_RADIUS = 20,
    ROUTE_TARGET_DISTANCE = 40,
    ADAPTIVE_TARGET_CHANGE = 5,
    PLAYER_MOTION_PREDICTION = 0.65,
    MAX_ACCEL_PREDICT_OFFSET = 8,
    MAX_SIZE_ACCELERATION = 48,
    THREAT_PREDICTION_SAMPLES = 7,
    EMERGENCY_IMPACT_TIME = 0.28,
    FAST_HAZARD_SPEED = 28,
    FAST_WARNING_EXTRA = 3.5,
    EXPAND_RATE_MIN = 1.25,
    EXPAND_WARNING_EXTRA = 9.5,
    EXPAND_EMERGENCY_EXTRA = 3.0,
    EXPAND_OUTWARD_WEIGHT = 0.32,
    WARNING_EXTRA = 7.0,
    EMERGENCY_EXTRA = 2.2,
    PRECAST_WARNING_EXTRA = 8.5,
    PRECAST_EMERGENCY_EXTRA = 1.0,
    LIVE_WARNING_EXTRA = 12.0,
    LIVE_EMERGENCY_EXTRA = 5.0,
    LIVE_IMPACT_EXTRA = 4.0,
    EXIT_EXTRA = 0.8,
    ROUTE_EXTRA = 1.2,
    DESTINATION_EXTRA = 2.0,
    LIVE_EXIT_EXTRA = 3.0,
    LIVE_ROUTE_EXTRA = 4.5,
    LIVE_DESTINATION_EXTRA = 6.0,
    PRECAST_LIFE = 1.05,
    HITBOX_LIFE = 0.50,
    ATTACK_LIFE = 0.85,
    GENERIC_LIFE = 0.65,
    PROJECTILE_LIFE = 1.20,
    LASER_PART_LIFE = 5.0,
    LASER_PART_MAX_LIFE = 12,
    VISUAL_LIFE = 0.35,
    DODGE_LOCK = 0.36,
    DODGE_REPLAN = 0.05,
    EVADE_REPLAN = 0.07,
    DODGE_SIDE_RELEASE = 0.65,
    QUICK_DODGE_DISTANCE = 10,
    DODGE_RADII = {8, 13, 19, 27, 34},
    EVADE_RADII = {7, 11, 16},
    SAFE_GAP_DIRECTIONS = 20,
    SAFE_GAP_FALLBACK_PENALTY = 10,
    SAFE_GAP_SIDE_SWITCH_PENALTY = 8,
    BOSS_SAFE_RING_INNER = 15,
    BOSS_SAFE_RING_OUTER = 23,
    ROUTE_SAMPLES = 9,
    TOP_CANDIDATES = 24,
    PATH_RECALC = 0.45,
    BLOCKED_DELAY = 0.16,
    WAYPOINT_DISTANCE = 4,
    STUCK_INTERVAL = 0.55,
    MIN_PROGRESS = 0.80,
    STUCK_RESET_LIMIT = 5,
    STATIONARY_DISTANCE = 0.15,
    WALL_NOCLIP_RAY_DISTANCE = 6,
    WALL_NOCLIP_HOLD = 0.75,
    WALL_NOCLIP_RESTORE_MARGIN = 3
}

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

    if old.RestoreWalls then
        pcall(old.RestoreWalls, old)
    end

    if old.DestroyCombatHover then
        pcall(old.DestroyCombatHover, old)
    end

    if old.DestroyFacing then
        pcall(old.DestroyFacing, old)
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
    "DQ_COMBAT_V75",
    "DQ_COMBAT_V76",
    "DQ_COMBAT_V77",
    "DQ_COMBAT_V78",
    "DQ_COMBAT_V79",
    "DQ_COMBAT_V710",
    "DQ_COMBAT_V711",
    "DQ_COMBAT_V712",
    "DQ_COMBAT_V713",
    "DQ_COMBAT_V714",
    "DQ_COMBAT_V715",
    "DQ_COMBAT_V716",
    "DQ_COMBAT_V717",
    "DQ_COMBAT_V718",
    "DQ_COMBAT_V719",
    "DQ_COMBAT_V720",
    "DQ_COMBAT_V721"
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
    "DQ_COMBAT_V75_RENDER",
    "DQ_COMBAT_V76_RENDER",
    "DQ_COMBAT_V78_RENDER",
    "DQ_COMBAT_V79_RENDER",
    "DQ_COMBAT_V710_RENDER",
    "DQ_COMBAT_V711_RENDER",
    "DQ_COMBAT_V712_RENDER",
    "DQ_COMBAT_V713_RENDER",
    "DQ_COMBAT_V714_RENDER",
    "DQ_COMBAT_V715_RENDER",
    "DQ_COMBAT_V716_RENDER",
    "DQ_COMBAT_V717_RENDER",
    "DQ_COMBAT_V718_RENDER",
    "DQ_COMBAT_V719_RENDER",
    "DQ_COMBAT_V720_RENDER",
    "DQ_COMBAT_V721_RENDER"
}

for _, name in ipairs(oldRenderNames) do
    pcall(function()
        RunService:UnbindFromRenderStep(name)
    end)
end

local State = {
    Alive = true,
    Connections = {},
    RenderName = "DQ_COMBAT_V721_RENDER",
    OwnAbilityIgnoreUntil = 0,
    SpacingActive = false,
    SpamSpells = true,
    WallNoclip = true,
    AdaptiveBossRange = true,
    AdaptiveModel = false,
    AdaptivePathActive = false,
    AdaptiveMovementOwner = false,
    AdaptiveIntent = "LEGACY",
    AdaptiveReason = "TOGGLE OFF",
    AdaptiveSpellReason = "LEGACY",
    AdaptiveRisk = 0,
    AdaptiveHealthRatio = 1,
    AdaptiveDamagePressure = 0,
    AdaptiveDistanceBonus = 0,
    AdaptiveCastAllowed = true,
    AdaptivePathWanted = false,
    AdaptiveRouteWanted = false,
    AdaptiveDecisionChanges = 0,
    AdaptiveLastIntentAt = -math.huge,
    AdaptiveLastThinkAt = -math.huge,
    AdaptiveLastHealth = nil,
    AdaptiveLastDamageAt = -math.huge,
    AdaptiveEmergencySince = nil,
    AdaptiveTrackedTarget = nil,
    AdaptiveBestTargetDistance = math.huge,
    AdaptiveLastProgressAt = -math.huge,
    DodgeProgressPosition = nil,
    DodgeProgressAt = -math.huge,
    DodgeStallChain = 0,
    DodgeStallRecoveries = 0,
    BossEngagementRange = DESIRED_DISTANCE,
    BossSpaceDistance = FORCE_SPACE_ENTER,
    BossRangeMode = "FALLBACK",
    BossRangeSlot = "-",
    TargetIsBoss = false,
    TargetBodyRadius = 0,
    TargetPriority = "NONE",
    NearestEnemy = nil,
    NearestEnemyDistance = math.huge,
    EnemySpacingBonus = 0,
    EnemySpacingDistance = DESIRED_DISTANCE,
    EnemySpacingEnter = FORCE_SPACE_ENTER,
    EnemySpacingExit = FORCE_SPACE_EXIT,
    EnemySpacingCastRange = 0,
    CombatDeathStreak = 0,
    LastCombatDeathAt = -math.huge,
    BossSpacingBonus = 0,
    BossOuterDistance = CFG.BOSS_PREFERRED_DISTANCE,
    BossSpacingDistance = CFG.BOSS_PREFERRED_DISTANCE,
    BossCastDistance = 0,
    BossSpacingMode = "OUTER",
    BossDeathStreak = 0,
    LastBossDeathAt = -math.huge,
    LastOffensiveQCastAt = -math.huge,
    LastOffensiveECastAt = -math.huge,
    PostDodgeCastPending = false,
    PostDodgeCastExpires = 0,
    PostDodgeCastRequests = 0,
    PostDodgeCastAttempts = 0,
    DodgeCastIssuedForThreat = false,
    FacingLastTarget = nil,
    FacingLastAimPosition = nil,
    FacingLastSeenAt = -math.huge,
    CloseThreatCount = 0,
    RouteGuidedTarget = false,
    FarTargetRouting = false,
    RouteNavigationMode = "LOCAL",
    PlayerCharacterIgnore = {},
    LastPlayerIgnoreRefresh = -math.huge,
    PartyMemberCount = 0,
    OpenWallCount = 0,
    OpenWallParts = setmetatable({}, {__mode = "k"}),
    BossIdentityCache = setmetatable({}, {__mode = "k"}),
    EnemyRadiusCache = setmetatable({}, {__mode = "k"}),
    VisibleBossNames = {},
    LastVisibleBossScan = -math.huge,
    ProfileBossNames = {},
    AbilityButtonCache = {},
    AbilityButtonLastScan = {
        Q = -math.huge,
        E = -math.huge
    },
    SpellRespawnGeneration = 0,
    SpellRespawnRebinds = 0,
    AbilityTemplateCache = {},
    LastAITick = -math.huge,
    LastTargetUpdate = -math.huge
}

ENV.DQ_COMBAT_V721 = State

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
        "DQCombatV76",
        "DQCombatV711",
        "DQCombatV712",
        "DQCombatV713",
        "DQCombatV714",
        "DQCombatV715",
        "DQCombatV716",
        "DQCombatV717",
        "DQCombatV718",
        "DQCombatV719",
        "DQCombatV720",
        "DQCombatV721",
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

function State:PlayerCharactersForNavigation(force)
    local now = os.clock()

    if not force
        and now - self.LastPlayerIgnoreRefresh
            < CFG.PARTY_IGNORE_REFRESH then

        return self.PlayerCharacterIgnore
    end

    local characters = {}
    local partyCount = 0

    for _, player in ipairs(Players:GetPlayers()) do
        local playerCharacter = player.Character

        if playerCharacter
            and playerCharacter.Parent then

            table.insert(characters, playerCharacter)

            if player ~= LP then
                partyCount = partyCount + 1
            end
        end
    end

    self.PlayerCharacterIgnore = characters
    self.LastPlayerIgnoreRefresh = now
    self.PartyMemberCount = partyCount

    return characters
end

local function isPlayerObject(object)
    if not object then
        return false
    end

    for _, playerCharacter in ipairs(
        State:PlayerCharactersForNavigation(false)
    ) do
        if object:IsDescendantOf(
            playerCharacter
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
            )
            or name:find(
                "innerrage",
                1,
                true
            )
            or name:find(
                "inner rage",
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
        Loaded = false,
        HazardRegistry = nil,
        HazardRegistryLoaded = false,
        HazardRegistryError = nil,
        HazardFamilyCount = 0
    }

    local cacheBuster =
        tostring(
            ENV.DQ_DUNGEON_PROFILE_CACHE
            or os.time()
        )

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

    local function freshUrl(url)
        return tostring(url)
            .. (
                tostring(url):find("?", 1, true)
                and "&cache="
                or "?cache="
            )
            .. cacheBuster
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

    local registryOk, registryOrError =
        pcall(function()
            local registry =
                compileTable(
                    game:HttpGet(
                        freshUrl(
                            joinUrl(
                                DUNGEON_PROFILE_BASE_URL,
                                "hazards.lua"
                            )
                        )
                    ),
                    "Global hazard registry"
                )

            if type(registry.Families) ~= "table"
                or type(registry.Classify) ~= "function" then

                error(
                    "Global hazard registry has an invalid interface"
                )
            end

            return registry
        end)

    if registryOk then
        result.HazardRegistry = registryOrError
        result.HazardRegistryLoaded = true

        for _ in pairs(
            registryOrError.Families
        ) do
            result.HazardFamilyCount =
                result.HazardFamilyCount + 1
        end
    else
        result.HazardRegistryError =
            tostring(registryOrError)

        if warn then
            warn(
                "Combat Pilot hazard registry fallback: "
                .. result.HazardRegistryError
            )
        end
    end

    pcall(function()
        local manifest =
            compileTable(
                game:HttpGet(
                    freshUrl(
                        joinUrl(
                            DUNGEON_PROFILE_BASE_URL,
                            "manifest.lua"
                        )
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
                    freshUrl(
                        joinUrl(
                            DUNGEON_PROFILE_BASE_URL,
                            fileName
                        )
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
            math.max(
                tonumber(movement.DesiredDistance)
                    or DESIRED_DISTANCE,
                DESIRED_DISTANCE,
                CFG.MIN_ENEMY_DISTANCE
            )

        FORCE_SPACE_ENTER =
            math.max(
                tonumber(movement.ForceSpaceEnter)
                    or FORCE_SPACE_ENTER,
                FORCE_SPACE_ENTER,
                DESIRED_DISTANCE - 2
            )

        FORCE_SPACE_EXIT =
            math.max(
                tonumber(movement.ForceSpaceExit)
                    or FORCE_SPACE_EXIT,
                FORCE_SPACE_EXIT,
                FORCE_SPACE_ENTER + 1,
                DESIRED_DISTANCE - 1
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

do
    local profileBosses =
        DungeonData.Profile
        and DungeonData.Profile.BossNames

    if type(profileBosses) == "table" then
        for key, value in pairs(profileBosses) do
            local bossName =
                type(key) == "number"
                and value
                or key

            State.ProfileBossNames[
                string.lower(tostring(bossName))
            ] = true
        end
    end
end

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

function State:RefreshVisibleBossNames(now)
    if now - self.LastVisibleBossScan < 0.75 then
        return
    end

    self.LastVisibleBossScan = now
    self.VisibleBossNames = {}

    local playerGui =
        LP:FindFirstChildOfClass("PlayerGui")

    if not playerGui then
        return
    end

    -- One shared GUI pass replaces the old per-enemy pass.
    -- Wide visible text is normally the Dungeon Quest boss bar.
    for _, object in ipairs(
        playerGui:GetDescendants()
    ) do
        if object:IsA("TextLabel")
            and object.Visible
            and object.AbsoluteSize.X >= 140 then

            local textValue =
                string.lower(
                    tostring(object.Text or "")
                )

            if #textValue > 2 then
                self.VisibleBossNames[textValue] = true
            end
        end
    end
end

function State:IsBossEnemy(enemy)
    if not validEnemy(enemy) then
        return false
    end

    local now = os.clock()
    local cached = self.BossIdentityCache[enemy]

    if cached
        and now - cached.Time
            < (
                cached.Result
                and 10
                or 1.25
            ) then

        return cached.Result
    end

    local enemyName =
        string.lower(enemy.Name or "")
    local result =
        self.ProfileBossNames[enemyName] == true

    local current = enemy

    for _ = 1, 7 do
        if result then
            break
        end

        if not current then
            break
        end

        local lowerName =
            string.lower(current.Name or "")

        if lowerName:find("boss", 1, true)
            or current:GetAttribute("IsBoss") == true
            or current:GetAttribute("Boss") == true then

            result = true
            break
        end

        local marker =
            current:FindFirstChild("IsBoss")
            or current:FindFirstChild("Boss")

        if marker
            and marker:IsA("BoolValue")
            and marker.Value then

            result = true
            break
        end

        current = current.Parent
    end

    if not result then
        pcall(function()
            result =
                game:GetService("CollectionService"):
                HasTag(enemy, "Boss")
        end)
    end

    if not result then
        self:RefreshVisibleBossNames(now)
        result =
            self.VisibleBossNames[enemyName] == true
    end

    self.BossIdentityCache[enemy] = {
        Result = result,
        Time = now
    }

    return result
end

function State:EstimateEnemyHorizontalRadius(enemy)
    if not validEnemy(enemy) then
        return 0
    end

    local now = os.clock()
    local cached = self.EnemyRadiusCache[enemy]

    if cached
        and now - cached.Time < 1.5 then

        return cached.Radius
    end

    local radius = 0

    pcall(function()
        local _, size = enemy:GetBoundingBox()

        radius =
            math.max(size.X, size.Z) * 0.5
    end)

    radius = math.clamp(
        radius,
        0,
        CFG.BOSS_TARGET_RADIUS_CAP
    )

    self.EnemyRadiusCache[enemy] = {
        Radius = radius,
        Time = now
    }

    return radius
end

function State:BossCastReachBonus()
    return
        math.clamp(
            self.TargetBodyRadius or 0,
            0,
            CFG.BOSS_TARGET_RADIUS_CAP
        )
        + CFG.BOSS_CAST_PROBE_EXTRA
end

function State:BossEffectiveCastRange(range)
    if range == math.huge then
        return math.huge
    end

    range = tonumber(range) or 0

    if range <= 0 then
        return 0
    end

    return range + self:BossCastReachBonus()
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

    if now - lastEnemyFallback
        < CFG.ENEMY_FALLBACK_INTERVAL then
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

function State:CloseChaserTarget(position)
    local threats = {}

    for enemy in pairs(Enemies) do
        if not validEnemy(enemy) then
            Enemies[enemy] = nil

        else
            local enemyRoot =
                enemy:FindFirstChild(
                    "HumanoidRootPart"
                )

            local humanoid =
                enemy:FindFirstChildOfClass(
                    "Humanoid"
                )

            if enemyRoot and humanoid then
                local offset =
                    flat(
                        position
                        - enemyRoot.Position
                    )

                local distance = offset.Magnitude

                if distance > 0.05
                    and distance
                        <= CFG.CHASER_PRIORITY_DISTANCE
                    and math.abs(
                        enemyRoot.Position.Y
                        - position.Y
                    ) <= 18 then

                    local towardPlayer = offset.Unit
                    local velocity =
                        flat(
                            enemyRoot.AssemblyLinearVelocity
                            or Vector3.zero
                        )

                    local approachSpeed =
                        velocity:Dot(towardPlayer)

                    local facingVector =
                        flat(
                            enemyRoot.CFrame.LookVector
                        )

                    local facingDot =
                        facingVector.Magnitude > 0.05
                        and facingVector.Unit:Dot(
                            towardPlayer
                        )
                        or -1

                    local moveDirection =
                        flat(
                            humanoid.MoveDirection
                            or Vector3.zero
                        )

                    local moveDot =
                        moveDirection.Magnitude > 0.05
                        and moveDirection.Unit:Dot(
                            towardPlayer
                        )
                        or -1

                    local pursuing =
                        approachSpeed
                            >= CFG.CHASER_APPROACH_SPEED
                        or moveDot >= 0.40
                        or (
                            distance <= 20
                            and facingDot
                                >= CFG.CHASER_FACING_DOT
                        )

                    if distance
                        <= CFG.CLOSE_DANGER_DISTANCE
                        or pursuing then

                        local score =
                            distance
                            - math.max(
                                approachSpeed,
                                0
                            ) * 0.8
                            - math.max(
                                facingDot,
                                0
                            ) * 2
                            - (
                                distance
                                    <= CFG.CLOSE_DANGER_DISTANCE
                                and 25
                                or 0
                            )

                        table.insert(
                            threats,
                            {
                                Enemy = enemy,
                                Position = enemyRoot.Position,
                                Distance = distance,
                                Score = score
                            }
                        )
                    end
                end
            end
        end
    end

    State.CloseThreatCount = #threats

    if #threats == 0 then
        return nil
    end

    table.sort(
        threats,
        function(a, b)
            return a.Score < b.Score
        end
    )

    local primary = threats[1]
    local total = Vector3.zero
    local memberCount = 0

    for _, threat in ipairs(threats) do
        if (
            flat(
                threat.Position
                - primary.Position
            )
        ).Magnitude <= CFG.DANGER_CLUSTER_RADIUS then

            total = total + threat.Position
            memberCount = memberCount + 1
        end
    end

    local centre =
        memberCount > 0
        and total / memberCount
        or primary.Position

    return primary.Enemy,
        (
            flat(centre)
            - flat(position)
        ).Magnitude,
        centre,
        math.max(memberCount, 1)
end

local function chooseTarget(
    position,
    currentTarget
)
    local closest,
        closestDistance =
            nearestEnemy(position)

    State.NearestEnemy = closest
    State.NearestEnemyDistance =
        closestDistance or math.huge

    local dangerTarget,
        dangerDistance,
        dangerAim,
        dangerCount =
            State:CloseChaserTarget(position)

    if dangerTarget then
        State.TargetPriority = "DANGER"

        return dangerTarget,
            dangerDistance,
            dangerAim,
            dangerCount
    end

    if not closest then
        State.TargetPriority = "NONE"
        return nil, math.huge, nil, 0
    end

    -- A visible boss health bar means the encounter is active.
    -- Keep that boss acquired even when it is across the arena
    -- or a spawned add happens to be physically closer.
    State:RefreshVisibleBossNames(os.clock())

    local visibleBoss = nil
    local visibleBossDistance = math.huge

    for enemy in pairs(Enemies) do
        if validEnemy(enemy)
            and State.VisibleBossNames[
                string.lower(enemy.Name or "")
            ]
            and State:IsBossEnemy(enemy) then

            local bossPosition =
                enemyWorldPosition(enemy)

            local distance =
                bossPosition
                and (
                    flat(bossPosition)
                    - flat(position)
                ).Magnitude
                or math.huge

            if distance < visibleBossDistance then
                visibleBoss = enemy
                visibleBossDistance = distance
            end
        end
    end

    if visibleBoss then
        State.TargetPriority = "BOSS"

        return exactTargetResult(
            position,
            visibleBoss
        )
    end

    -- A boss that has already been acquired remains the
    -- direct target. A newly encountered nearest boss is
    -- also attacked head-on rather than averaged with mobs.
    if validEnemy(currentTarget)
        and State:IsBossEnemy(currentTarget) then

        State.TargetPriority = "BOSS"

        return exactTargetResult(
            position,
            currentTarget
        )
    end

    if State:IsBossEnemy(closest) then
        State.TargetPriority = "BOSS"

        return exactTargetResult(
            position,
            closest
        )
    end

    -- Build clusters from every nearby enemy rather than
    -- locking combat to the nearest enemy folder or a mapped
    -- pack order. Distance still limits acquisition so a huge
    -- group across the dungeon cannot pull the player away.
    local candidates = {}
    local searchLimit =
        math.min(
            closestDistance
                + MOB_CLUSTER_SEARCH_EXTRA,
            MOB_CLUSTER_MAX_DISTANCE
        )

    for enemy in pairs(Enemies) do
        if not validEnemy(enemy) then
            Enemies[enemy] = nil

        elseif not State:IsBossEnemy(enemy) then
            local enemyPosition =
                enemyWorldPosition(enemy)

            local enemyDistance =
                enemyPosition
                and (
                    flat(enemyPosition)
                    - flat(position)
                ).Magnitude
                or math.huge

            if enemyPosition
                and enemyDistance <= searchLimit
                and math.abs(
                    enemyPosition.Y
                    - position.Y
                ) <= MOB_CLUSTER_VERTICAL_LIMIT then

                table.insert(
                    candidates,
                    {
                        Enemy = enemy,
                        Position = enemyPosition,
                        Distance = enemyDistance
                    }
                )
            end
        end
    end

    if #candidates == 0 then
        State.TargetPriority = "MOB"

        return closest,
            closestDistance,
            enemyWorldPosition(closest),
            1
    end

    local bestMembers = nil
    local bestCentre = nil
    local bestCount = 0
    local bestDistance = math.huge
    local bestScore = math.huge

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

        local score =
            centreDistance
            - math.max(
                #members - 1,
                0
            ) * MOB_CLUSTER_DENSITY_BONUS

        if score < bestScore
            or (
                math.abs(score - bestScore) < 0.01
                and centreDistance < bestDistance
            ) then

            bestMembers = members
            bestCentre = centre
            bestCount = #members
            bestDistance = centreDistance
            bestScore = score
        end
    end

    local selected = nil
    local selectedDistance = math.huge

    -- Preserve target stickiness when the current target is
    -- actually part of the winning group, but immediately
    -- abandon an isolated target for the denser cluster.
    if validEnemy(currentTarget)
        and not State:IsBossEnemy(currentTarget) then

        local currentPosition =
            enemyWorldPosition(currentTarget)

        if currentPosition
            and (
                flat(currentPosition)
                - flat(position)
            ).Magnitude <= searchLimit
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

    State.TargetPriority = "PACK"

    return selected or closest,
        bestDistance,
        bestCentre,
        bestCount
end

--------------------------------------------------
-- ROOM PROGRESSION
--------------------------------------------------

local LastRoomOrder = 0

State.ProfileRouteFlow = (function()
    local flow = {
        Route =
            DungeonData.Profile
            and DungeonData.Profile.Route
            or {},
        Cursor = nil,
        Complete = false
    }

    if type(flow.Route) ~= "table" then
        flow.Route = {}
    end

    local movement =
        DungeonData.Profile
        and DungeonData.Profile.Movement
        or {}

    local reachedDistance =
        tonumber(movement.RouteReachedDistance)
        or 5.5

    local forwardScan =
        math.max(
            math.floor(
                tonumber(movement.RouteForwardScan)
                or 30
            ),
            1
        )

    local rejoinLimit =
        tonumber(movement.RouteRejoinLimit)
        or 70

    local function routePosition(point)
        local value =
            type(point) == "table"
            and (
                point.Position
                or point.position
                or point
            )
            or nil

        if typeof(value) == "Vector3" then
            return value
        end

        if type(value) ~= "table" then
            return nil
        end

        local x =
            tonumber(
                value.X
                or value.x
                or value[1]
            )

        local y =
            tonumber(
                value.Y
                or value.y
                or value[2]
            )

        local z =
            tonumber(
                value.Z
                or value.z
                or value[3]
            )

        if not x or not y or not z then
            return nil
        end

        return Vector3.new(x, y, z)
    end

    local function nearestIndex(
        position,
        firstIndex,
        lastIndex
    )
        local bestIndex = nil
        local bestDistance = math.huge

        firstIndex =
            math.max(
                firstIndex or 1,
                1
            )

        lastIndex =
            math.min(
                lastIndex or #flow.Route,
                #flow.Route
            )

        for index = firstIndex, lastIndex do
            local waypoint =
                routePosition(
                    flow.Route[index]
                )

            if waypoint then
                local distance =
                    (
                        flat(waypoint)
                        - flat(position)
                    ).Magnitude

                if distance < bestDistance then
                    bestIndex = index
                    bestDistance = distance
                end
            end
        end

        return bestIndex, bestDistance
    end

    function flow:ResetForRespawn()
        self.Cursor = nil
        self.Complete = false
        State.RouteIndex = 0
    end

    function flow:ProgressPoint(position)
        if #self.Route == 0
            or self.Complete then

            return nil
        end

        if not self.Cursor then
            self.Cursor =
                nearestIndex(position)
                or 1
        end

        self.Cursor =
            math.clamp(
                self.Cursor,
                1,
                #self.Route
            )

        -- Combat may pull the character away from the line.
        -- Rejoin only at the current point or a forward point,
        -- never by walking a completed section backwards.
        local forwardIndex,
            forwardDistance =
                nearestIndex(
                    position,
                    self.Cursor,
                    self.Cursor + forwardScan
                )

        if forwardIndex
            and forwardIndex > self.Cursor
            and forwardDistance <= rejoinLimit then

            self.Cursor = forwardIndex
        end

        while self.Cursor < #self.Route do
            local currentPosition =
                routePosition(
                    self.Route[self.Cursor]
                )

            local nextPosition =
                routePosition(
                    self.Route[self.Cursor + 1]
                )

            if not currentPosition then
                self.Cursor = self.Cursor + 1

            elseif nextPosition then
                local currentDistance =
                    (
                        flat(currentPosition)
                        - flat(position)
                    ).Magnitude

                local nextDistance =
                    (
                        flat(nextPosition)
                        - flat(position)
                    ).Magnitude

                if currentDistance <= reachedDistance
                    or nextDistance + 1.25
                        < currentDistance then

                    self.Cursor = self.Cursor + 1
                else
                    break
                end
            else
                break
            end
        end

        local routeEntry =
            self.Route[self.Cursor]

        local waypoint =
            routePosition(routeEntry)

        if not waypoint then
            self.Complete = true
            State.RouteIndex = #self.Route
            return nil
        end

        local distance =
            (
                flat(waypoint)
                - flat(position)
            ).Magnitude

        if self.Cursor == #self.Route
            and distance <= reachedDistance then

            self.Complete = true
            State.RouteIndex = #self.Route
            return nil
        end

        State.RouteIndex = self.Cursor

        return {
            Position = waypoint,
            RouteIndex = self.Cursor,
            RoomOrder =
                type(routeEntry) == "table"
                and routeEntry.RoomOrder
                or nil,
            WaitForMobs =
                type(routeEntry) == "table"
                and routeEntry.WaitForMobs == true
                or false
        }
    end

    function flow:TargetApproachPoint(
        position,
        targetPosition,
        targetRoomOrder
    )
        if not targetPosition then
            return nil
        end

        local point = self:ProgressPoint(position)

        if not point then
            return nil
        end

        local pointOrder =
            tonumber(point.RoomOrder)
        local targetOrder =
            tonumber(targetRoomOrder)

        -- Never follow the route beyond the target's room.
        if pointOrder
            and targetOrder
            and pointOrder > targetOrder then

            return nil
        end

        return point
    end

    State.RouteIndex = 0
    State.RouteCount = #flow.Route

    return flow
end)()

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

function State:ProfileIgnoresHazard(object)
    local profileHazards =
        DungeonData.Profile
        and DungeonData.Profile.Hazards

    if not profileHazards then
        return false
    end

    local blob = nameBlob(object)

    for _, pattern in ipairs(
        profileHazards.IgnorePatterns or {}
    ) do
        if blob:find(
            string.lower(tostring(pattern)),
            1,
            true
        ) then
            return true
        end
    end

    return false
end

local function classifyGlobalHazard(object)
    local registry =
        DungeonData.HazardRegistry

    if not registry
        or type(registry.Classify) ~= "function" then

        return nil, false, nil
    end

    local ok, kind, family =
        pcall(
            registry.Classify,
            registry,
            object
        )

    if not ok or not family then
        return nil, false, nil
    end

    if kind ~= nil then
        kind = string.upper(tostring(kind))

        if kind ~= "PRECAST"
            and kind ~= "HITBOX"
            and kind ~= "LASER"
            and kind ~= "PROJECTILE"
            and kind ~= "ATTACK" then

            kind = nil
        end
    end

    -- A matched family with no kind is intentional. The registry uses
    -- this for safe regions, anchors, harmless visuals, and context-only
    -- templates; do not let generic detection add them back as hazards.
    return kind, true, family
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

    if State:ProfileIgnoresHazard(part) then
        return nil
    end

    local registryKind, registryMatched =
        classifyGlobalHazard(part)

    if registryMatched then
        return registryKind
    end

    if profileHazards then
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
        return CFG.PRECAST_LIFE
    end

    if kind == "HITBOX" then
        return CFG.HITBOX_LIFE
    end

    if kind == "LASER" then
        return CFG.LASER_PART_LIFE
    end

    if kind == "PROJECTILE" then
        return CFG.PROJECTILE_LIFE
    end

    if kind == "ATTACK" then
        return CFG.ATTACK_LIFE
    end

    return CFG.GENERIC_LIFE
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
        "DQ_V721_Hazard"

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
            now + CFG.VISUAL_LIFE
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
        or isOwnAbility(beam)
        or State:ProfileIgnoresHazard(beam) then

        return
    end

    local registryKind, registryMatched =
        classifyGlobalHazard(beam)

    if registryMatched
        and registryKind ~= "LASER" then

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
        < CFG.HAZARD_UPDATE_INTERVAL then

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
                        >= CFG.EXPAND_RATE_MIN

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
                                + CFG.LASER_PART_MAX_LIFE
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
        > CFG.MAX_ACCEL_PREDICT_OFFSET then

        horizontal =
            horizontal.Unit
            * CFG.MAX_ACCEL_PREDICT_OFFSET

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
                CFG.MAX_SIZE_ACCELERATION
            ),

            math.clamp(
                sizeAcceleration.Y,
                0,
                CFG.MAX_SIZE_ACCELERATION
            ),

            math.clamp(
                sizeAcceleration.Z,
                0,
                CFG.MAX_SIZE_ACCELERATION
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

local function isLiveHazard(hazard)
    local kind =
        hazard and hazard.Kind

    return kind == "HITBOX"
        or kind == "ATTACK"
        or kind == "PROJECTILE"
        or kind == "LASER"
end

local function hazardSafetyMargins(hazard)
    if isLiveHazard(hazard) then
        return
            CFG.LIVE_EXIT_EXTRA,
            CFG.LIVE_ROUTE_EXTRA,
            CFG.LIVE_DESTINATION_EXTRA
    end

    return
        CFG.EXIT_EXTRA,
        CFG.ROUTE_EXTRA,
        CFG.DESTINATION_EXTRA
end

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
            and CFG.EXPAND_PREDICT
            or CFG.PREDICT_FAR

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

        local liveHazard =
            isLiveHazard(hazard)

        local precast =
            hazard.Kind == "PRECAST"

        local emergencyExtra =
            liveHazard
            and CFG.LIVE_EMERGENCY_EXTRA
            or precast
                and CFG.PRECAST_EMERGENCY_EXTRA
            or CFG.EMERGENCY_EXTRA

        local warningExtra =
            liveHazard
            and CFG.LIVE_WARNING_EXTRA
            or precast
                and CFG.PRECAST_WARNING_EXTRA
            or CFG.WARNING_EXTRA

        local livePriority =
            liveHazard and -4000 or 0

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
                        * CFG.PREDICT_NEAR
                        * CFG.PLAYER_MOTION_PREDICTION,

                hazard,
                CFG.PREDICT_NEAR
            )

        local predicted =
            math.min(
                current,
                nearFuture
            )

        local impactTime = nil

        local impactClearance =
            CFG.BODY_RADIUS
            + (
                liveHazard
                and CFG.LIVE_IMPACT_EXTRA
                or 1.0
            )
            + (
                bobStyleCircle
                and CFG.EXPAND_EMERGENCY_EXTRA
                or 0
            )

        for sample = 1,
            CFG.THREAT_PREDICTION_SAMPLES do

            local future =
                expansionHorizon
                * sample
                / CFG.THREAT_PREDICTION_SAMPLES

            local futurePosition =
                position
                + playerVelocity
                    * future
                    * CFG.PLAYER_MOTION_PREDICTION

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
                    - CFG.FAST_HAZARD_SPEED
                ) / CFG.FAST_HAZARD_SPEED,

                0,
                1
            )

        local emergency =
            current
                <= CFG.BODY_RADIUS
                    + emergencyExtra
                    + (
                        bobStyleCircle
                        and CFG.EXPAND_EMERGENCY_EXTRA
                        or 0
                    )
            or nearFuture
                <= CFG.BODY_RADIUS
                    + emergencyExtra
                    + (
                        bobStyleCircle
                        and CFG.EXPAND_EMERGENCY_EXTRA
                        or 0
                    )
            or impactTime
                and impactTime
                    <= CFG.EMERGENCY_IMPACT_TIME

        local warning =
            false

        if not emergency then
            warning =
                predicted
                    <= CFG.BODY_RADIUS
                        + warningExtra
                        + (
                            bobStyleCircle
                            and CFG.EXPAND_WARNING_EXTRA
                            or hazard.Expanding
                                and 3.5
                                or 0
                        )
                        + fastFactor
                            * CFG.FAST_WARNING_EXTRA
        end

        local level = nil
        local score = nil

        if emergency then
            level = "EMERGENCY"

            score =
                -1000
                + livePriority
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
                + livePriority
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

    -- Other players are dynamic actors, not dungeon walls or valid
    -- ground. Ignoring them prevents party members from breaking
    -- route visibility, wall steering, and walk-dodge validation.
    for _, playerCharacter in ipairs(
        State:PlayerCharactersForNavigation(false)
    ) do
        if playerCharacter ~= character then
            table.insert(ignore, playerCharacter)
        end
    end

    -- NPC bodies are moving actors as well.  They must not become
    -- fake floors for combat hover or fake walls for route checks.
    for enemyFolder in pairs(EnemyFolders) do
        if enemyFolder.Parent then
            table.insert(ignore, enemyFolder)
        end
    end

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

function State:RestoreWalls()
    for part, record in pairs(self.OpenWallParts) do
        if part and part.Parent then
            pcall(function()
                part.CanCollide =
                    record.CanCollide
            end)
        end

        self.OpenWallParts[part] = nil
    end

    self.OpenWallCount = 0
end

function State:RootOverlapsWall(root, part)
    if not root
        or not part
        or not part.Parent then

        return false
    end

    local localPosition =
        part.CFrame:PointToObjectSpace(
            root.Position
        )
    local margin =
        CFG.WALL_NOCLIP_RESTORE_MARGIN

    return math.abs(localPosition.X)
            <= part.Size.X / 2 + margin
        and math.abs(localPosition.Y)
            <= part.Size.Y / 2 + margin
        and math.abs(localPosition.Z)
            <= part.Size.Z / 2 + margin
end

function State:MaintainWallNoclip(root)
    local now = os.clock()
    local count = 0

    for part, record in pairs(self.OpenWallParts) do
        if not part or not part.Parent then
            self.OpenWallParts[part] = nil

        elseif now >= record.Expires then
            if self:RootOverlapsWall(root, part) then
                record.Expires =
                    now + CFG.WALL_NOCLIP_HOLD
                count = count + 1
            else
                pcall(function()
                    part.CanCollide =
                        record.CanCollide
                end)

                self.OpenWallParts[part] = nil
            end
        else
            count = count + 1
        end
    end

    self.OpenWallCount = count
end

function State:OpenWallForNoclip(
    hit,
    character
)
    if not self.WallNoclip
        or not hit
        or not hit.Instance
        or not hit.Instance:IsA("BasePart")
        or math.abs(hit.Normal.Y) > 0.35 then

        return false
    end

    local part = hit.Instance
    local minimumHorizontal =
        math.min(part.Size.X, part.Size.Z)
    local wallShaped =
        part.Size.Y >= 3
        and part.Size.Y
            >= minimumHorizontal * 1.25

    if not part.CanCollide
        or not part.Anchored
        or not wallShaped
        or part:IsDescendantOf(character)
        or part:FindFirstAncestor("enemyFolder")
        or Hazards[part]
        or isPlayerObject(part) then

        return false
    end

    local record = self.OpenWallParts[part]

    if not record then
        record = {
            CanCollide = part.CanCollide,
            Expires = 0
        }

        self.OpenWallParts[part] = record
    end

    record.Expires =
        os.clock() + CFG.WALL_NOCLIP_HOLD

    pcall(function()
        part.CanCollide = false
    end)

    return true
end

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

            desired
                * CFG.WALL_NOCLIP_RAY_DISTANCE,

            params
        )

    if not hit
        or not hit.Instance
        or not hit.Instance.CanCollide then

        return desired
    end

    -- The ray is horizontal and the hit normal must also be
    -- horizontal, so floors, ramps and platforms stay solid.
    if State:OpenWallForNoclip(
        hit,
        character
    ) then
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
        local exitExtra,
            routeExtra,
            destinationExtra =
                hazardSafetyMargins(hazard)

        local startDistance =
            hazardDistance(
                startPosition,
                hazard,
                0
            )

        local startedInside =
            startDistance
            <= CFG.BODY_RADIUS
                + exitExtra

        local escaped =
            not startedInside

        for sample = 1,
            CFG.ROUTE_SAMPLES do

            local alpha =
                sample
                / CFG.ROUTE_SAMPLES

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
                        and CFG.EXPAND_PREDICT
                        or CFG.PREDICT_FAR
                )

            local distance =
                hazardDistance(
                    point,
                    hazard,
                    future
                )

            if not escaped then
                if distance
                    > CFG.BODY_RADIUS
                        + exitExtra then

                    escaped = true
                end

            else
                if distance
                    <= CFG.BODY_RADIUS
                        + routeExtra then

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
                        and CFG.EXPAND_PREDICT
                        or CFG.PREDICT_FAR
                )
            )

        if destinationDistance
            <= CFG.BODY_RADIUS
                + destinationExtra then

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
                * CFG.PREDICT_NEAR

        b =
            b
            + hazard.V1
                * CFG.PREDICT_NEAR

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

    local desiredDistance =
        State.EnemySpacingDistance
        or DESIRED_DISTANCE

    if State.TargetIsBoss then
        desiredDistance =
            math.max(
                desiredDistance,
                State.BossOuterDistance
                    or CFG.BOSS_PREFERRED_DISTANCE
            )
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

        return math.max(
            BOB_LEASH_DISTANCE,
            desiredDistance + 5
        )
    end

    return math.max(
        TARGET_LEASH_DISTANCE,
        desiredDistance + 8
    )
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

                -- A dodge remains primarily LEFT / RIGHT, but it
                -- may not preserve a dangerous body-distance.  Add
                -- a bounded outward component whenever the nearest
                -- physical enemy is already inside the safe ring.
                local minimumSpacing =
                    State.EnemySpacingEnter
                    or FORCE_SPACE_ENTER
                local closePressure =
                    math.clamp(
                        (
                            minimumSpacing
                            - enemyDistance
                        ) / 6,
                        0,
                        1
                    )
                local outwardCorrection =
                    outward
                    * closePressure
                    * 0.60

                local left =
                    baseLeft
                    + inward
                    + outwardCorrection

                local right =
                    baseRight
                    + inward
                    + outwardCorrection

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
                                * CFG.EXPAND_OUTWARD_WEIGHT,
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
                                * CFG.EXPAND_OUTWARD_WEIGHT,
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

--------------------------------------------------
-- SAFE-GAP DIRECTIONS
--
-- The fast first reaction above remains a committed
-- left/right strafe.  The full solver can then use a
-- nearby diagonal gap when overlapping or radial
-- telegraphs make pure lateral movement unsafe.
--------------------------------------------------

local function safeGapDirections(
    root,
    threat,
    enemy
)
    local directions =
        candidateDirections(
            root,
            threat,
            enemy
        )

    local enemyLeft = nil

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
                toward = toward.Unit

                enemyLeft =
                    Vector3.new(
                        -toward.Z,
                        0,
                        toward.X
                    )
            end
        end
    end

    local function addGap(direction)
        direction = flat(direction)

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

        local side = DodgeSide

        if enemyLeft then
            side =
                direction:Dot(enemyLeft) >= 0
                and "LEFT"
                or "RIGHT"
        elseif side == "NONE" then
            side = "LEFT"
        end

        table.insert(
            directions,
            {
                Direction = direction,
                Side = side,
                OutwardFallback = false,
                SafeGapFallback = true
            }
        )
    end

    local baseAngle = 0

    if CurrentDodgeDirection then
        baseAngle = math.atan2(
            CurrentDodgeDirection.Z,
            CurrentDodgeDirection.X
        )
    end

    for index = 0,
        CFG.SAFE_GAP_DIRECTIONS - 1 do

        local angle =
            baseAngle
            + math.pi * 2
                * index
                / CFG.SAFE_GAP_DIRECTIONS

        addGap(
            Vector3.new(
                math.cos(angle),
                0,
                math.sin(angle)
            )
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

                local minimumSpacing =
                    State.EnemySpacingEnter
                    or FORCE_SPACE_ENTER
                local closePressure =
                    math.clamp(
                        (
                            minimumSpacing
                            - enemyDistance
                        ) / 6,
                        0,
                        1
                    )
                local outwardWeight =
                    closePressure * 0.60

                if threat
                    and threat.Expanding
                    and enemyDistance
                        < targetLeashDistance(enemy)
                            - 2 then

                    outwardWeight =
                        math.max(
                            outwardWeight,
                            CFG.EXPAND_OUTWARD_WEIGHT
                        )
                end

                if outwardWeight > 0 then
                    direction =
                        direction
                        - toward * outwardWeight
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
                * CFG.QUICK_DODGE_DISTANCE

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

                    local minimumSpacing =
                        State.EnemySpacingEnter
                        or FORCE_SPACE_ENTER

                    if enemyDistance
                        < minimumSpacing then

                        score =
                            score
                            - 12
                            - (
                                minimumSpacing
                                - enemyDistance
                            ) * 8
                    end

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
        safeGapDirections(
            root,
            threat,
            enemy
        )

    local radii

    if soft then
        radii = CFG.EVADE_RADII
    else
        radii = CFG.DODGE_RADII
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

                if entry.SafeGapFallback then
                    score =
                        score
                        + CFG.SAFE_GAP_FALLBACK_PENALTY
                end

                if DodgeSide ~= "NONE"
                    and entry.Side ~= DodgeSide then

                    score =
                        score
                        + CFG.SAFE_GAP_SIDE_SWITCH_PENALTY
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

                        local minimumSpacing =
                            State.EnemySpacingEnter
                            or FORCE_SPACE_ENTER

                        if enemyDistance
                            < minimumSpacing then

                            score =
                                score
                                + 45
                                + (
                                    minimumSpacing
                                    - enemyDistance
                                ) * 6
                        end

                        if enemyDistance < 8 then
                            score =
                                score + 30

                        elseif soft then
                            score =
                                score
                                + math.abs(
                                    enemyDistance
                                    - (
                                        State.EnemySpacingDistance
                                        or DESIRED_DISTANCE
                                    )
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
            CFG.TOP_CANDIDATES
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
            < CFG.PATH_RECALC then

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
        <= CFG.WAYPOINT_DISTANCE then

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

function State:DestroyFacing()
    if FacingAlign then
        pcall(function()
            FacingAlign:Destroy()
        end)
    end

    if FacingAttachment then
        pcall(function()
            FacingAttachment:Destroy()
        end)
    end

    FacingRoot = nil
    FacingAttachment = nil
    FacingAlign = nil
end

local function createFacing(root)
    if FacingRoot == root
        and FacingAttachment
        and FacingAttachment.Parent == root
        and FacingAlign
        and FacingAlign.Parent == root
        and FacingAlign.Attachment0
            == FacingAttachment then

        return
    end

    State:DestroyFacing()

    -- Versions before V7.19 did not expose a teardown hook, so an
    -- update could leave a live orientation constraint on the same
    -- root. Remove every legacy Combat Pilot facing object before
    -- creating the single authoritative controller.
    for _, object in ipairs(
        root:GetChildren()
    ) do
        if string.match(
            object.Name or "",
            "^DQ_V%d+_Facing"
        ) then
            pcall(function()
                object:Destroy()
            end)
        end
    end

    FacingAttachment =
        Instance.new(
            "Attachment"
        )

    FacingAttachment.Name =
        "DQ_V721_FacingAttachment"

    FacingAttachment.Parent =
        root

    FacingAlign =
        Instance.new(
            "AlignOrientation"
        )

    FacingAlign.Name =
        "DQ_V721_Facing"

    FacingAlign.Mode =
        Enum.OrientationAlignmentMode.
            OneAttachment

    FacingAlign.Attachment0 =
        FacingAttachment

    FacingAlign.RigidityEnabled =
        false

    FacingAlign.Responsiveness =
        200

    FacingAlign.MaxTorque =
        math.huge

    FacingAlign.MaxAngularVelocity =
        math.huge

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

    local now = os.clock()
    local activeTarget = target
    local activeAim = aimPosition
    local currentTargetValid =
        validEnemy(target)

    -- A target can disappear for one acquisition tick while enemy
    -- folders are reparented or refreshed. Keep the last live target
    -- for a very short grace period so route/dodge movement cannot
    -- steal the character's facing during that transient gap.
    if not currentTargetValid then
        if now - (
            State.FacingLastSeenAt
                or -math.huge
        ) <= CFG.FACING_TARGET_GRACE
            and validEnemy(
                State.FacingLastTarget
            ) then

            activeTarget =
                State.FacingLastTarget
            activeAim =
                State.FacingLastAimPosition

        elseif validEnemy(
            State.NearestEnemy
        ) then

            activeTarget =
                State.NearestEnemy
            activeAim = nil
        else
            FacingAlign.Enabled = false
            return false
        end
    end

    local enemyRoot =
        activeTarget:FindFirstChild(
            "HumanoidRootPart"
        )

    if not enemyRoot then
        FacingAlign.Enabled = false
        return false
    end

    if currentTargetValid
        or activeTarget
            == State.NearestEnemy then

        State.FacingLastTarget =
            activeTarget
        State.FacingLastSeenAt = now
        State.FacingLastAimPosition =
            activeAim or enemyRoot.Position
    end

    local direction =
        flat(
            (
                activeAim
                or enemyRoot.Position
            )
            - root.Position
        )

    -- The player can stand exactly on a pack's averaged centre even
    -- though the selected mob is beside them. Never return with a
    -- zero aim vector; fall back to that live enemy body instead.
    if direction.Magnitude < 0.05 then
        direction =
            flat(
                enemyRoot.Position
                - root.Position
            )
    end

    if direction.Magnitude < 0.05 then
        FacingAlign.Enabled = true
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

local BUFF_ABILITY_NAMES = {
    ["inner focus"] = true,
    ["enhanced inner focus"] = true,
    ["inner rage"] = true,
    ["enhanced inner rage"] = true
}

local TAUNT_ABILITY_NAMES = {
    ["taunt"] = true,
    ["guardian roar"] = true
}

local KNOWN_ABILITY_RANGES = {
    -- Confirmed by the focused spell impact capture.
    ["geyser"] = 40
}

local AbilityRuntime = {
    Q = nil,
    E = nil,
    LastScan = -math.huge
}

local function normalizedAbilityName(value)
    return string.lower(
        tostring(value or ""):
            gsub("_", " "):
            gsub("%s+", " "):
            match("^%s*(.-)%s*$")
    )
end

function State:AbilityRangeOverride(
    name,
    normalized
)
    local overrides =
        ENV.DQ_ABILITY_RANGES

    if type(overrides) ~= "table" then
        return nil
    end

    local value =
        overrides[name]
        or overrides[normalized]

    if value == nil then
        for key, candidate in pairs(overrides) do
            if normalizedAbilityName(key)
                == normalized then

                value = candidate
                break
            end
        end
    end

    if type(value) == "table" then
        value =
            value.Range
            or value.range
            or value.CastRange
            or value.castRange
    end

    value = tonumber(value)

    if value and value > 0.5 then
        return value
    end

    return nil
end

function State:GetAbilityTemplate(
    name,
    normalized
)
    local cached =
        self.AbilityTemplateCache[normalized]

    if cached and cached.Parent then
        return cached
    end

    local abilities =
        ReplicatedStorage:
        FindFirstChild("abilities")

    if not abilities then
        for _, child in ipairs(
            ReplicatedStorage:GetChildren()
        ) do
            if string.lower(child.Name)
                == "abilities" then

                abilities = child
                break
            end
        end
    end

    if not abilities then
        return nil
    end

    local template =
        abilities:FindFirstChild(name)

    if not template then
        for _, candidate in ipairs(
            abilities:GetChildren()
        ) do
            if normalizedAbilityName(
                candidate.Name
            ) == normalized then

                template = candidate
                break
            end
        end
    end

    if template then
        self.AbilityTemplateCache[normalized] =
            template
    end

    return template
end

local function directValueObject(
    container,
    name
)
    if not container then
        return nil
    end

    local object =
        container:FindFirstChild(name)

    if object
        and object:IsA("ValueBase") then

        return object
    end

    return nil
end

local function numericAbilityValue(
    container,
    names,
    recursive
)
    for _, name in ipairs(names) do
        local object = nil

        if container then
            object =
                container:FindFirstChild(
                    name,
                    recursive == true
                )
        end

        if object
            and object:IsA("ValueBase")
            and type(object.Value) == "number" then

            return object.Value
        end

        local attribute = nil

        pcall(function()
            attribute =
                container:GetAttribute(name)
        end)

        if type(attribute) == "number" then
            return attribute
        end
    end

    return nil
end

local function classifyAbility(name)
    local normalized =
        normalizedAbilityName(name)

    if BUFF_ABILITY_NAMES[normalized] then
        return "BUFF"
    end

    if TAUNT_ABILITY_NAMES[normalized]
        or normalized:find(
            "taunt",
            1,
            true
        ) then

        return "TAUNT"
    end

    return "ATTACK"
end

local function makeAbilityInfo(
    letter,
    object
)
    if not object then
        return nil
    end

    local name = object.Name
    local normalized =
        normalizedAbilityName(name)
    local kind = classifyAbility(name)

    local range =
        State:AbilityRangeOverride(
            name,
            normalized
        )
    local rangeSource =
        range and "OVERRIDE" or nil
    local template =
        State:GetAbilityTemplate(
            name,
            normalized
        )

    local rangeNames = {
        "range",
        "Range",
        "castRange",
        "CastRange",
        "maxRange",
        "MaxRange",
        "abilityRange",
        "AbilityRange",
        "distance",
        "Distance",
        "maxDistance",
        "MaxDistance",
        "reach",
        "Reach"
    }

    if not range then
        range =
        numericAbilityValue(
            object,
            rangeNames,
            true
        )

        if type(range) == "number"
            and range > 0.5 then

            rangeSource = "LIVE"
        else
            range = nil
        end
    end

    if not range and template then
        range =
            numericAbilityValue(
                template,
                rangeNames,
                true
            )

        if type(range) == "number"
            and range > 0.5 then

            rangeSource = "TEMPLATE"
        else
            range = nil
        end
    end

    if not range then
        if KNOWN_ABILITY_RANGES[normalized] then
            range =
                KNOWN_ABILITY_RANGES[normalized]
            rangeSource = "KNOWN"
        elseif kind == "BUFF" then
            range = math.huge
            rangeSource = "BUFF"
        else
            rangeSource = "FALLBACK"

            range =
                kind == "TAUNT"
                and TAUNT_ABILITY_RANGE
                or letter == "Q"
                    and Q_ABILITY_RANGE
                or E_ABILITY_RANGE
        end
    end

    if type(range) ~= "number" then
        range =
            letter == "Q"
            and Q_ABILITY_RANGE
            or E_ABILITY_RANGE
        rangeSource = "FALLBACK"
    end

    return {
        Letter = letter,
        Object = object,
        Name = name,
        NormalizedName = normalized,
        Kind = kind,
        Range = range,
        RangeSource = rangeSource,
        RangeKnown =
            rangeSource == "OVERRIDE"
            or rangeSource == "LIVE"
            or rangeSource == "TEMPLATE"
            or rangeSource == "KNOWN",
        Cooldown =
            directValueObject(
                object,
                "cooldown"
            ),
        CooldownLength =
            numericAbilityValue(
                object,
                {
                    "cooldownLength",
                    "CooldownLength"
                },
                true
            )
            or (
                template
                and numericAbilityValue(
                    template,
                    {
                        "cooldownLength",
                        "CooldownLength"
                    },
                    true
                )
            )
    }
end

local function refreshAbilityRuntime(force)
    local now = os.clock()

    if not force
        and now - AbilityRuntime.LastScan
            < ABILITY_SCAN_INTERVAL then

        local qValid =
            not AbilityRuntime.Q
            or AbilityRuntime.Q.Object.Parent

        local eValid =
            not AbilityRuntime.E
            or AbilityRuntime.E.Object.Parent

        if qValid and eValid then
            return
        end
    end

    AbilityRuntime.LastScan = now
    AbilityRuntime.Q = nil
    AbilityRuntime.E = nil

    local roots = {
        LP:FindFirstChildOfClass(
            "Backpack"
        ),
        LP.Character
    }

    for _, root in ipairs(roots) do
        if root then
            for _, candidate in ipairs(
                root:GetChildren()
            ) do
                local slotObject =
                    directValueObject(
                        candidate,
                        "abilitySlot"
                    )

                local slot =
                    slotObject
                    and string.upper(
                        tostring(
                            slotObject.Value
                        )
                    )

                if slot == "Q"
                    or slot == "E" then

                    AbilityRuntime[slot] =
                        makeAbilityInfo(
                            slot,
                            candidate
                        )
                end
            end
        end
    end
end

local function currentAbility(letter)
    refreshAbilityRuntime(false)
    return AbilityRuntime[letter]
end

local function currentAbilityReady(letter)
    local ability =
        currentAbility(letter)

    if not ability then
        return true, false
    end

    local cooldown = ability.Cooldown

    if cooldown
        and cooldown.Parent
        and type(cooldown.Value)
            == "number" then

        return cooldown.Value <= 0.05, true
    end

    return true, false
end

local function currentCooldownLength(letter)
    local ability =
        currentAbility(letter)

    return ability
        and ability.CooldownLength
        or SPELL_FALLBACK_COOLDOWN
end

local function currentAbilityRange(letter)
    local ability =
        currentAbility(letter)

    return ability
        and ability.Range
        or letter == "Q"
            and Q_ABILITY_RANGE
        or E_ABILITY_RANGE
end

local function currentAbilityKind(letter)
    local ability =
        currentAbility(letter)

    return ability
        and ability.Kind
        or "ATTACK"
end

local function currentAbilityName(letter)
    local ability =
        currentAbility(letter)

    return ability
        and ability.Name
        or letter
end

local function pairedAbilityRanges()
    local qRange = currentAbilityRange("Q")
    local eRange = currentAbilityRange("E")
    local qBuff =
        currentAbilityKind("Q") == "BUFF"
    local eBuff =
        currentAbilityKind("E") == "BUFF"

    if qBuff and eBuff then
        qRange = Q_ABILITY_RANGE
        eRange = E_ABILITY_RANGE
    elseif qBuff then
        qRange = eRange
    elseif eBuff then
        eRange = qRange
    end

    return qRange, eRange, qBuff, eBuff
end

local function maximumOffensiveRange()
    local maximum = 0
    local qReady = currentAbilityReady("Q")
    local eReady = currentAbilityReady("E")

    if AUTO_Q
        and qReady
        and currentAbilityKind("Q")
            ~= "BUFF" then

        maximum = math.max(
            maximum,
            currentAbilityRange("Q")
        )
    end

    if AUTO_E
        and eReady
        and currentAbilityKind("E")
            ~= "BUFF" then

        maximum = math.max(
            maximum,
            currentAbilityRange("E")
        )
    end

    return maximum
end

function State:MaximumEquippedOffensiveRange()
    local maximum = 0

    for _, entry in ipairs({
        {"Q", AUTO_Q, Q_ABILITY_RANGE},
        {"E", AUTO_E, E_ABILITY_RANGE}
    }) do
        local letter = entry[1]
        local enabled = entry[2]
        local fallbackRange = entry[3]

        if enabled then
            local ability =
                currentAbility(letter)

            if not ability then
                maximum =
                    math.max(
                        maximum,
                        fallbackRange
                    )
            elseif ability.Kind == "ATTACK" then
                maximum =
                    math.max(
                        maximum,
                        ability.Range
                            or fallbackRange
                    )
            end
        end
    end

    return maximum
end

function State:MaximumReadyOffensiveRange()
    local maximum = 0
    local now = os.clock()

    for _, entry in ipairs({
        {"Q", AUTO_Q, "LastOffensiveQCastAt"},
        {"E", AUTO_E, "LastOffensiveECastAt"}
    }) do
        local letter = entry[1]
        local enabled = entry[2]
        local timestampKey = entry[3]
        local ability =
            enabled
            and currentAbility(letter)
            or nil
        local kind =
            ability
            and ability.Kind
            or "ATTACK"

        if enabled and kind == "ATTACK" then
            local ready, detected =
                currentAbilityReady(letter)
            local lastCast =
                self[timestampKey]
                or -math.huge

            if detected then
                ready = ready
                    and now - lastCast
                        >= (
                            self.TargetIsBoss
                            and CFG.BOSS_SPELL_SPAM_INTERVAL
                            or SPELL_SPAM_INTERVAL
                        )
            else
                ready = now - lastCast
                    >= currentCooldownLength(letter)
            end

            if ready then
                maximum =
                    math.max(
                        maximum,
                        currentAbilityRange(letter)
                    )
            end
        end
    end

    return maximum
end

function State:MarkOffensiveCast(letter, now)
    if currentAbilityKind(letter) ~= "ATTACK" then
        return
    end

    if letter == "Q" then
        self.LastOffensiveQCastAt = now
    elseif letter == "E" then
        self.LastOffensiveECastAt = now
    end
end

function State:RequestPostDodgeCast(now)
    if self.DodgeCastIssuedForThreat then
        return false
    end

    self.DodgeCastIssuedForThreat = true
    self.PostDodgeCastPending = true
    self.PostDodgeCastExpires =
        now + CFG.POST_DODGE_CAST_WINDOW
    self.PostDodgeCastRequests =
        (self.PostDodgeCastRequests or 0) + 1

    return true
end

function State:CurrentEnemySpacingPlan()
    local castRange =
        self:MaximumEquippedOffensiveRange()

    if self.TargetIsBoss then
        local requestedOuter =
            CFG.BOSS_PREFERRED_DISTANCE
            + math.clamp(
                self.BossSpacingBonus or 0,
                0,
                CFG.BOSS_DEATH_DISTANCE_MAX
            )
            + (
                self.AdaptiveModel
                and math.clamp(
                    self.AdaptiveDistanceBonus or 0,
                    0,
                    CFG.ADAPTIVE_DISTANCE_BONUS_MAX
                )
                or 0
            )

        local readyRange =
            self:BossEffectiveCastRange(
                self:MaximumReadyOffensiveRange()
            )
        local effectiveCastRange =
            self:BossEffectiveCastRange(
                castRange
            )
        local desiredDistance =
            requestedOuter
        local castDistance =
            effectiveCastRange > 0
            and effectiveCastRange < math.huge
            and math.max(
                effectiveCastRange
                    - CFG.BOSS_CAST_RANGE_BUFFER,
                CFG.BOSS_MINIMUM_CAST_DISTANCE
            )
            or requestedOuter
        local furthestUsableDistance =
            math.max(
                CFG.BOSS_MINIMUM_CAST_DISTANCE,
                math.min(
                    requestedOuter,
                    castDistance
                )
            )
        local furthestRangeReady =
            readyRange > 0
            and readyRange
                >= furthestUsableDistance
                    + CFG.BOSS_CAST_RANGE_BUFFER

        -- Bosses never use the normal mob ring.  Their physical size
        -- and a conservative AoE probe allowance extend effective
        -- reach, while the hard boss floor prevents melee-distance
        -- casting even when the equipped spell reports a short range.
        if furthestRangeReady then
            desiredDistance =
                furthestUsableDistance
            self.BossSpacingMode =
                desiredDistance
                    < requestedOuter - 0.5
                and "MAX-RANGE CAST"
                or "LONG CAST"
        else
            self.BossSpacingMode =
                readyRange > 0
                and "WAIT LONG RANGE"
                or "OUTER RETREAT"
        end

        local enterOffset =
            furthestRangeReady
            and CFG.BOSS_CAST_ENTER_OFFSET
            or CFG.BOSS_OUTER_ENTER_OFFSET
        local exitOffset =
            furthestRangeReady
            and CFG.BOSS_CAST_EXIT_OFFSET
            or CFG.BOSS_OUTER_EXIT_OFFSET
        local spacingEnter =
            math.max(
                desiredDistance
                    - enterOffset,
                4
            )
        local spacingExit =
            math.max(
                desiredDistance
                    - exitOffset,
                spacingEnter + 1
            )

        self.BossSpacingDistance =
            desiredDistance
        self.BossOuterDistance =
            requestedOuter
        self.BossCastDistance =
            furthestUsableDistance
        self.EnemySpacingDistance =
            desiredDistance
        self.EnemySpacingEnter =
            spacingEnter
        self.EnemySpacingExit =
            spacingExit
        self.EnemySpacingCastRange =
            effectiveCastRange

        return
            desiredDistance,
            spacingEnter,
            spacingExit,
            desiredDistance + 4
    end

    local requestedDistance =
        DESIRED_DISTANCE
        + math.clamp(
            self.EnemySpacingBonus or 0,
            0,
            CFG.ENEMY_DEATH_DISTANCE_MAX
        )
        + (
            self.AdaptiveModel
            and math.clamp(
                self.AdaptiveDistanceBonus or 0,
                0,
                CFG.ADAPTIVE_DISTANCE_BONUS_MAX
            )
            or 0
        )

    local desiredDistance =
        requestedDistance
    local spacingCastRange = castRange

    -- The adaptive director waits farther out while attacks are on
    -- cooldown, then approaches only as far as a currently ready
    -- offensive ability requires. Legacy mode keeps the equipped-
    -- range behaviour from V7.19.
    if self.AdaptiveModel then
        spacingCastRange =
            math.min(
                self:MaximumReadyOffensiveRange(),
                CFG.MOB_CAST_RANGE_CAP
            )
    end

    -- Stay inside a usable ranged spell when that spell can already
    -- support the safe baseline. Short-range skills never drag the
    -- character closer than the global minimum enemy distance.
    if spacingCastRange >= CFG.MIN_ENEMY_DISTANCE
            + CFG.ENEMY_CAST_RANGE_BUFFER
        and spacingCastRange < math.huge then

        desiredDistance =
            math.min(
                requestedDistance,
                spacingCastRange
                    - CFG.ENEMY_CAST_RANGE_BUFFER
            )
    end

    desiredDistance =
        math.max(
            desiredDistance,
            CFG.MIN_ENEMY_DISTANCE
        )

    local spacingEnter =
        math.max(
            desiredDistance
                - CFG.MOB_SPACING_ENTER_OFFSET,
            4
        )

    local spacingExit =
        math.max(
            desiredDistance
                - CFG.MOB_SPACING_EXIT_OFFSET,
            spacingEnter + 1
        )

    self.EnemySpacingDistance =
        desiredDistance
    self.EnemySpacingEnter =
        spacingEnter
    self.EnemySpacingExit =
        spacingExit
    self.EnemySpacingCastRange =
        spacingCastRange
    self.BossSpacingMode =
        desiredDistance
            < requestedDistance - 0.5
        and "MOB MAX RANGE"
        or "MOB OUTER"

    return
        desiredDistance,
        spacingEnter,
        spacingExit,
        desiredDistance + 4
end

function State:AbilityRangeStatus(letter)
    local ability = currentAbility(letter)

    if not ability then
        return letter .. ":? [FALLBACK]"
    end

    if ability.Kind == "BUFF" then
        return letter
            .. ":BUFF ["
            .. tostring(ability.Name)
            .. "]"
    end

    return letter
        .. ":"
        .. string.format(
            "%.1f",
            ability.Range
        )
        .. " ["
        .. tostring(
            ability.RangeSource
            or "FALLBACK"
        )
        .. "]"
end

function State:RefreshBossRangePlan()
    local safeFloor =
        math.max(
            FORCE_SPACE_EXIT,
            CFG.BOSS_SAFE_RING_OUTER,
            CFG.BOSS_MINIMUM_CAST_DISTANCE
        )
    local preferredOuter =
        CFG.BOSS_PREFERRED_DISTANCE
        + math.clamp(
            self.BossSpacingBonus or 0,
            0,
            CFG.BOSS_DEATH_DISTANCE_MAX
        )
        + (
            self.AdaptiveModel
            and math.clamp(
                self.AdaptiveDistanceBonus or 0,
                0,
                CFG.ADAPTIVE_DISTANCE_BONUS_MAX
            )
            or 0
        )

    if not self.TargetIsBoss then
        self.BossEngagementRange = safeFloor
        self.BossSpaceDistance =
            math.max(
                FORCE_SPACE_ENTER,
                safeFloor - 3
            )
        self.BossRangeMode = "IDLE"
        self.BossRangeSlot = "-"
        return self.BossEngagementRange
    end

    if not self.AdaptiveBossRange then
        self.BossEngagementRange = safeFloor
        self.BossSpaceDistance =
            math.max(
                FORCE_SPACE_ENTER,
                safeFloor - 3
            )
        self.BossRangeMode = "SAFE FIXED"
        self.BossRangeSlot = "-"
        return self.BossEngagementRange
    end

    local readyRange = 0
    local readySlot = "-"
    local knownRange = 0
    local knownSlot = "-"
    local unknownReady = false

    for _, entry in ipairs({
        {"Q", AUTO_Q},
        {"E", AUTO_E}
    }) do
        local letter = entry[1]
        local enabled = entry[2]
        local ability =
            enabled
            and currentAbility(letter)
            or nil

        if ability
            and ability.Kind == "ATTACK" then

            local ready =
                currentAbilityReady(letter)
            local effectiveRange =
                self:BossEffectiveCastRange(
                    ability.Range
                )

            if ability.RangeKnown then
                if effectiveRange > knownRange then
                    knownRange = effectiveRange
                    knownSlot = letter
                end

                if ready
                    and effectiveRange > readyRange then

                    readyRange = effectiveRange
                    readySlot = letter
                end

            elseif ready then
                unknownReady = true
            end
        end
    end

    local selectedRange = 0

    if readyRange > 0 then
        selectedRange = readyRange
        self.BossRangeMode = "READY"
        self.BossRangeSlot = readySlot

    elseif unknownReady then
        -- Unknown spells are tested from the safe ring instead of
        -- making the character repeatedly enter lethal melee range.
        selectedRange = preferredOuter
        self.BossRangeMode = "SAFE PROBE"
        self.BossRangeSlot = "?"

    elseif knownRange > 0 then
        selectedRange = knownRange
        self.BossRangeMode = "COOLDOWN"
        self.BossRangeSlot = knownSlot

    else
        selectedRange = preferredOuter
        self.BossRangeMode = "SAFE FALLBACK"
        self.BossRangeSlot = "-"
    end

    local requestedRange =
        math.min(
            preferredOuter,
            math.max(
                safeFloor,
                selectedRange - BOSS_RANGE_BUFFER
            )
        )

    self.BossEngagementRange = requestedRange

    if readyRange > 0
        and readyRange
            < safeFloor + BOSS_RANGE_BUFFER then

        self.BossRangeMode = "SAFE PROBE"
    end

    self.BossSpaceDistance =
        math.max(
            FORCE_SPACE_ENTER,
            self.BossEngagementRange - 3
        )

    return self.BossEngagementRange
end

local function characterBusyCasting()
    local character = LP.Character
    local value =
        character
        and character:FindFirstChild(
            "busyCasting"
        )

    return value
        and value:IsA("BoolValue")
        and value.Value == true
        or false
end

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
        KeyBusy = {},
        PairBusy = false,
        PairToken = 0,
        PairOrder = nil,
        QAttempts = 0,
        EAttempts = 0,
        LastUseCheck = -math.huge
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

    local function activateAbilityButton(letter)
        local playerGui =
            LP:FindFirstChildOfClass(
                "PlayerGui"
            )

        if not playerGui then
            return false
        end

        local cached =
            State.AbilityButtonCache[letter]

        if cached and cached.Parent then
            local success =
                pcall(function()
                    cached:Activate()
                end)

            if success then
                return true
            end

            State.AbilityButtonCache[letter] = nil
        end

        -- A missing mobile ability button used to trigger a full
        -- PlayerGui descendant scan after almost every spam input.
        -- Limit only that discovery scan; cached buttons, executor
        -- input, and VirtualInputManager still run on every attempt.
        local buttonScanNow = os.clock()
        local lastButtonScan =
            State.AbilityButtonLastScan[letter]
            or -math.huge

        if buttonScanNow - lastButtonScan < 0.75 then
            return false
        end

        State.AbilityButtonLastScan[letter] =
            buttonScanNow

        for _, object in ipairs(
            playerGui:GetDescendants()
        ) do
            if object:IsA("TextLabel")
                or object:IsA("TextButton") then

                local textValue =
                    string.upper(
                        tostring(object.Text or "")
                    ):gsub("%s+", "")

                if textValue == letter then
                    local current = object

                    for _ = 1, 5 do
                        if not current
                            or current == playerGui then

                            break
                        end

                        if current:IsA("GuiButton") then
                            local success =
                                pcall(function()
                                    current:Activate()
                                end)

                            if success then
                                State.AbilityButtonCache[letter] =
                                    current
                                return true
                            end
                        end

                        current = current.Parent
                    end
                end
            end
        end

        return false
    end

    local function pressKey(
        key,
        fallback,
        letter
    )
        if flow.KeyBusy[key] then
            return false
        end

        flow.KeyBusy[key] = true

        if letter then
            State:MarkOffensiveCast(
                letter,
                os.clock()
            )
        end

        task.spawn(function()
            -- Delta and other mobile executors can report a
            -- successful VirtualInputManager call even when the
            -- game ignores it.  Send the executor input first,
            -- then VIM, and finally activate the visible ability
            -- button when one exists.
            if keypress and keyrelease then
                pcall(function()
                    keypress(fallback)
                    task.wait(0.060)
                    keyrelease(fallback)
                end)
            end

            pcall(function()
                VirtualInputManager:SendKeyEvent(
                    true,
                    key,
                    false,
                    game
                )

                task.wait(0.060)

                VirtualInputManager:SendKeyEvent(
                    false,
                    key,
                    false,
                    game
                )
            end)

            if letter then
                activateAbilityButton(letter)
            end

            flow.KeyBusy[key] = nil
        end)

        return true
    end

    local function keyData(letter)
        if letter == "Q" then
            return Enum.KeyCode.Q, 0x51
        end

        return Enum.KeyCode.E, 0x45
    end

    local function pressPaired(
        firstLetter,
        secondLetter
    )
        local firstKey, firstFallback =
            keyData(firstLetter)
        local secondKey, secondFallback =
            keyData(secondLetter)

        if flow.PairBusy
            or flow.KeyBusy[firstKey]
            or flow.KeyBusy[secondKey] then

            return false
        end

        flow.PairBusy = true
        flow.PairToken = flow.PairToken + 1
        flow.PairOrder =
            firstLetter .. ">" .. secondLetter

        local token = flow.PairToken

        task.spawn(function()
            local accepted =
                pressKey(
                    firstKey,
                    firstFallback,
                    firstLetter
                )

            if not accepted then
                if token == flow.PairToken then
                    flow.PairBusy = false
                end
                return
            end

            local startedDeadline =
                os.clock()
                + PAIR_CAST_START_TIMEOUT
            local busyObserved = false
            local cooldownObservedAt = nil

            while State.Alive
                and token == flow.PairToken
                and os.clock()
                    < startedDeadline do

                local ready, detected =
                    currentAbilityReady(
                        firstLetter
                    )

                if characterBusyCasting() then
                    busyObserved = true
                    break
                end

                if detected
                    and not ready
                    and not cooldownObservedAt then

                    cooldownObservedAt =
                        os.clock()
                end

                if cooldownObservedAt
                    and os.clock()
                        - cooldownObservedAt
                        >= 0.12 then

                    break
                end

                task.wait(PAIR_CAST_POLL)
            end

            if not State.Alive
                or token ~= flow.PairToken then

                return
            end

            if not busyObserved
                and not cooldownObservedAt then

                task.wait(
                    PAIR_CAST_FALLBACK_GAP
                )
            end

            local clearDeadline =
                os.clock()
                + PAIR_CAST_CLEAR_TIMEOUT

            while State.Alive
                and token == flow.PairToken
                and characterBusyCasting()
                and os.clock()
                    < clearDeadline do

                task.wait(PAIR_CAST_POLL)
            end

            if State.Alive
                and token == flow.PairToken then

                pressKey(
                    secondKey,
                    secondFallback,
                    secondLetter
                )

                task.wait(0.10)
            end

            if token == flow.PairToken then
                flow.PairBusy = false
            end
        end)

        return true
    end

    local function preferredPairOrder()
        local qBuff =
            currentAbilityKind("Q")
                == "BUFF"
        local eBuff =
            currentAbilityKind("E")
                == "BUFF"

        if eBuff and not qBuff then
            return "E", "Q"
        end

        return "Q", "E"
    end

    local function pressBoth()
        local first, second =
            preferredPairOrder()

        return pressPaired(
            first,
            second
        )
    end

    local function pressBothImmediate()
        local qKey, qFallback =
            keyData("Q")
        local eKey, eFallback =
            keyData("E")

        if flow.PairBusy
            or flow.KeyBusy[qKey]
            or flow.KeyBusy[eKey] then

            return false
        end

        -- pressKey marks each key busy synchronously before its input
        -- task starts, so both calls below begin on the same decision
        -- tick without creating duplicate Q or E input workers.
        local qAccepted =
            pressKey(
                qKey,
                qFallback,
                "Q"
            )
        local eAccepted =
            pressKey(
                eKey,
                eFallback,
                "E"
            )

        return qAccepted or eAccepted
    end

    local function cooldownState(letter)
        local ready, detected =
            currentAbilityReady(letter)

        return not ready, detected
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
            >= currentCooldownLength(
                letter
            )
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
        self.PairToken = self.PairToken + 1
        self.PairBusy = false
        self.PairOrder = nil
        self.QAttempts = 0
        self.EAttempts = 0
        self.LastUseCheck = -math.huge
        State.AbilityButtonCache = {}
        State.AbilityButtonLastScan = {
            Q = -math.huge,
            E = -math.huge
        }

        refreshAbilityRuntime(true)
    end

    function flow:RebindAfterRespawn(character)
        State.SpellRespawnGeneration =
            (State.SpellRespawnGeneration or 0) + 1

        local generation =
            State.SpellRespawnGeneration

        task.spawn(function()
            local root =
                character:FindFirstChild(
                    "HumanoidRootPart"
                )
                or character:WaitForChild(
                    "HumanoidRootPart",
                    10
                )

            if not root
                or not State.Alive
                or LP.Character ~= character
                or generation
                    ~= State.SpellRespawnGeneration then

                return
            end

            -- The first retry makes spam eligible immediately. The
            -- later retries catch Backpack/abilitySlot and mobile UI
            -- objects that Dungeon Quest recreates after the body.
            self.LastQ = -math.huge
            self.LastE = -math.huge
            self.LastUseCheck = -math.huge
            self.KeyBusy = {}
            self.PairToken = self.PairToken + 1
            self.PairBusy = false

            local retryDelays = {
                0,
                0.20,
                0.45,
                0.80,
                1.20
            }

            for _, delay in ipairs(retryDelays) do
                if delay > 0 then
                    task.wait(delay)
                end

                if not State.Alive
                    or LP.Character ~= character
                    or generation
                        ~= State.SpellRespawnGeneration then

                    return
                end

                State.AbilityButtonCache = {}
                State.AbilityButtonLastScan = {
                    Q = -math.huge,
                    E = -math.huge
                }
                AbilityRuntime.LastScan = -math.huge
                refreshAbilityRuntime(true)
                State.SpellRespawnRebinds =
                    (State.SpellRespawnRebinds or 0)
                    + 1
            end
        end)
    end

    function flow:CastNow(letter)
        local now = os.clock()

        if letter == "Q" then
            self.LastQ = now
            self.QAttempts =
                self.QAttempts + 1

            State.OwnAbilityIgnoreUntil =
                now + OWN_BUFF_IGNORE_TIME

            pressKey(
                Enum.KeyCode.Q,
                0x51,
                "Q"
            )

        elseif letter == "E" then
            self.LastE = now
            self.EAttempts =
                self.EAttempts + 1

            pressKey(
                Enum.KeyCode.E,
                0x45,
                "E"
            )
        end
    end

    function flow:CastBothNow()
        local now = os.clock()

        if not pressBoth() then
            return false
        end

        self.LastQ = now
        self.LastE = now
        self.QAttempts =
            self.QAttempts + 1
        self.EAttempts =
            self.EAttempts + 1

        State.OwnAbilityIgnoreUntil =
            now + OWN_BUFF_IGNORE_TIME

        return true
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
        if self.PairBusy then
            return "PAIR "
                .. tostring(
                    self.PairOrder or "Q>E"
                )
        end

        if State.SpamSpells then
            return "TRUE SPAM Q:"
                .. tostring(self.QAttempts)
                .. " E:"
                .. tostring(self.EAttempts)
        end

        if State.AdaptiveModel then
            return "AI "
                .. tostring(
                    State.AdaptiveSpellReason
                        or "THINK"
                )
                .. " Q:"
                .. tostring(self.QAttempts)
                .. " E:"
                .. tostring(self.EAttempts)
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
        local now = os.clock()

        if now - self.LastUseCheck
            < CFG.SPELL_DECISION_INTERVAL then

            return
        end

        self.LastUseCheck = now

        local qRange,
            eRange,
            qBuff,
            eBuff =
                pairedAbilityRanges()
        local qAbilityReady =
            currentAbilityReady("Q")
        local eAbilityReady =
            currentAbilityReady("E")
        local buffPair =
            AUTO_Q
            and AUTO_E
            and (qBuff or eBuff)
        local spamInterval =
            State.SpamSpells
            and CFG.TRUE_SPAM_INPUT_INTERVAL
            or State.TargetIsBoss
            and CFG.BOSS_SPELL_SPAM_INTERVAL
            or SPELL_SPAM_INTERVAL

        -- Mobs use a deliberately shorter cast cap around their
        -- mob ring. Bosses add their measured body radius and the
        -- conservative AoE probe allowance, so attacks begin much
        -- farther away without changing normal-mob casting.
        if State.TargetIsBoss then
            qRange =
                State:BossEffectiveCastRange(
                    qRange
                )
            eRange =
                State:BossEffectiveCastRange(
                    eRange
                )
        else
            qRange =
                math.min(
                    qRange,
                    CFG.MOB_CAST_RANGE_CAP
                )
            eRange =
                math.min(
                    eRange,
                    CFG.MOB_CAST_RANGE_CAP
                )
        end

        --------------------------------------------------
        -- ONE COMMITTED DODGE, THEN ONE CAST ATTEMPT
        -- Movement is never paused here. The next AI heartbeat
        -- immediately continues/replans the dodge.
        --------------------------------------------------

        if State.PostDodgeCastPending
            and not State.SpamSpells then
            if now > State.PostDodgeCastExpires
                or not validEnemy(target) then

                State.PostDodgeCastPending = false
            else
                local dodgeQReady =
                    AUTO_Q
                    and qAbilityReady
                    and not self.PairBusy
                    and distance <= qRange
                    and now - self.LastQ
                        >= spamInterval
                local dodgeEReady =
                    AUTO_E
                    and eAbilityReady
                    and not self.PairBusy
                    and distance <= eRange
                    and now - self.LastE
                        >= spamInterval
                local attempted = false

                if dodgeQReady
                    and dodgeEReady then

                    attempted = pressBoth()

                    if attempted then
                        self.LastQ = now
                        self.LastE = now
                        self.QAttempts =
                            self.QAttempts + 1
                        self.EAttempts =
                            self.EAttempts + 1
                        State.OwnAbilityIgnoreUntil =
                            now + OWN_BUFF_IGNORE_TIME
                    end

                elseif not buffPair
                    and dodgeQReady then

                    attempted =
                        pressKey(
                            Enum.KeyCode.Q,
                            0x51,
                            "Q"
                        )

                    if attempted then
                        self.LastQ = now
                        self.QAttempts =
                            self.QAttempts + 1
                        State.OwnAbilityIgnoreUntil =
                            now + OWN_BUFF_IGNORE_TIME
                    end

                elseif not buffPair
                    and dodgeEReady then

                    attempted =
                        pressKey(
                            Enum.KeyCode.E,
                            0x45,
                            "E"
                        )

                    if attempted then
                        self.LastE = now
                        self.EAttempts =
                            self.EAttempts + 1
                    end
                end

                if attempted then
                    State.PostDodgeCastPending = false
                    State.PostDodgeCastAttempts =
                        (State.PostDodgeCastAttempts or 0)
                        + 1
                    return
                end
            end
        end

        local dodgingNow =
            type(mode) == "string"
            and (
                mode:find("DODGE", 1, true) == 1
                or mode:find("EVADE", 1, true) == 1
            )

        -- Normal/adaptive casting reserves the first movement
        -- reaction for escape. True Spam deliberately bypasses this
        -- gate and keeps attempting every ready ability.
        if dodgingNow
            and not State.SpamSpells
            and not (
                State.AdaptiveModel
                and State.AdaptiveCastAllowed
            ) then

            return
        end

        if State.SpamSpells then
            State.PostDodgeCastPending = false

            -- True Spam is deliberately independent from targeting.
            -- Once the player is alive, ready Q/E are retried even
            -- while the target list, range estimate, route, or dodge
            -- state is rebuilding after a death.
            local qReady =
                AUTO_Q
                and qAbilityReady
                and not self.PairBusy
                and now - self.LastQ
                    >= spamInterval

            local eReady =
                AUTO_E
                and eAbilityReady
                and not self.PairBusy
                and now - self.LastE
                    >= spamInterval

            if buffPair then
                if qReady
                    and eReady
                    and pressBoth() then

                    self.LastQ = now
                    self.LastE = now
                    self.QAttempts =
                        self.QAttempts + 1
                    self.EAttempts =
                        self.EAttempts + 1

                    State.OwnAbilityIgnoreUntil =
                        now
                        + OWN_BUFF_IGNORE_TIME
                end

                return
            end

            if qReady and eReady then
                if pressBothImmediate() then
                    self.LastQ = now
                    self.LastE = now
                    self.QAttempts =
                        self.QAttempts + 1
                    self.EAttempts =
                        self.EAttempts + 1

                    State.OwnAbilityIgnoreUntil =
                        now
                        + OWN_BUFF_IGNORE_TIME
                end

            else
                if qReady then
                    if pressKey(
                        Enum.KeyCode.Q,
                        0x51,
                        "Q"
                    ) then
                        self.LastQ = now
                        self.QAttempts =
                            self.QAttempts + 1

                        State.OwnAbilityIgnoreUntil =
                            now
                            + OWN_BUFF_IGNORE_TIME
                    end
                end

                if eReady then
                    if pressKey(
                        Enum.KeyCode.E,
                        0x45,
                        "E"
                    ) then
                        self.LastE = now
                        self.EAttempts =
                            self.EAttempts + 1
                    end
                end
            end

            return
        end

        --------------------------------------------------
        -- ADAPTIVE SPELL POLICY
        --
        -- The director, rather than pack order, decides when to
        -- attack. Range and live cooldown checks remain hard guards.
        --------------------------------------------------

        if State.AdaptiveModel then
            if not State.AdaptiveCastAllowed
                or not validEnemy(target) then

                return
            end

            local qReady =
                AUTO_Q
                and qAbilityReady
                and not self.PairBusy
                and distance <= qRange
                and now - self.LastQ
                    >= spamInterval

            local eReady =
                AUTO_E
                and eAbilityReady
                and not self.PairBusy
                and distance <= eRange
                and now - self.LastE
                    >= spamInterval

            if buffPair then
                if qReady
                    and eReady
                    and pressBoth() then

                    self.LastQ = now
                    self.LastE = now
                    self.QAttempts =
                        self.QAttempts + 1
                    self.EAttempts =
                        self.EAttempts + 1
                    State.OwnAbilityIgnoreUntil =
                        now + OWN_BUFF_IGNORE_TIME
                end

                return
            end

            if qReady and eReady then
                if pressBothImmediate() then
                    self.LastQ = now
                    self.LastE = now
                    self.QAttempts =
                        self.QAttempts + 1
                    self.EAttempts =
                        self.EAttempts + 1
                    State.OwnAbilityIgnoreUntil =
                        now + OWN_BUFF_IGNORE_TIME
                end
            else
                if qReady then
                    if pressKey(
                        Enum.KeyCode.Q,
                        0x51,
                        "Q"
                    ) then
                        self.LastQ = now
                        self.QAttempts =
                            self.QAttempts + 1
                        State.OwnAbilityIgnoreUntil =
                            now + OWN_BUFF_IGNORE_TIME
                    end
                end

                if eReady then
                    if pressKey(
                        Enum.KeyCode.E,
                        0x45,
                        "E"
                    ) then
                        self.LastE = now
                        self.EAttempts =
                            self.EAttempts + 1
                    end
                end
            end

            return
        end

        if State.TargetIsBoss then
            if not validEnemy(target) then
                return
            end

            local qReady =
                AUTO_Q
                and qAbilityReady
                and not self.PairBusy
                and distance <= qRange
                and now - self.LastQ
                    >= spamInterval
            local eReady =
                AUTO_E
                and eAbilityReady
                and not self.PairBusy
                and distance <= eRange
                and now - self.LastE
                    >= spamInterval

            if buffPair then
                if qReady
                    and eReady
                    and pressBoth() then

                    self.LastQ = now
                    self.LastE = now
                    self.QAttempts =
                        self.QAttempts + 1
                    self.EAttempts =
                        self.EAttempts + 1
                    State.OwnAbilityIgnoreUntil =
                        now + OWN_BUFF_IGNORE_TIME
                end

                return
            end

            if qReady and eReady then
                if pressBothImmediate() then
                    self.LastQ = now
                    self.LastE = now
                    self.QAttempts =
                        self.QAttempts + 1
                    self.EAttempts =
                        self.EAttempts + 1
                    State.OwnAbilityIgnoreUntil =
                        now + OWN_BUFF_IGNORE_TIME
                end
            else
                if qReady then
                    if pressKey(
                        Enum.KeyCode.Q,
                        0x51,
                        "Q"
                    ) then
                        self.LastQ = now
                        self.QAttempts =
                            self.QAttempts + 1
                        State.OwnAbilityIgnoreUntil =
                            now + OWN_BUFF_IGNORE_TIME
                    end
                end

                if eReady then
                    if pressKey(
                        Enum.KeyCode.E,
                        0x45,
                        "E"
                    ) then
                        self.LastE = now
                        self.EAttempts =
                            self.EAttempts + 1
                    end
                end
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
            or mode == "DODGE" then

            return
        end

        local qReady =
            AUTO_Q
            and qAbilityReady
            and not self.PairBusy
            and not self.QUsed
            and distance <= qRange

        local eReady =
            AUTO_E
            and eAbilityReady
            and not self.PairBusy
            and not self.EUsed
            and distance <= eRange

        if buffPair then
            if qReady
                and eReady
                and pressBoth() then

                self.QUsed = true
                self.EUsed = true
                self.LastQ = now
                self.LastE = now
                self.QAttempts =
                    self.QAttempts + 1
                self.EAttempts =
                    self.EAttempts + 1

                State.OwnAbilityIgnoreUntil =
                    now
                    + OWN_BUFF_IGNORE_TIME
            end

            return
        end

        if qReady and eReady then
            if pressBoth() then
                self.QUsed = true
                self.EUsed = true
                self.LastQ = now
                self.LastE = now
                self.QAttempts =
                    self.QAttempts + 1
                self.EAttempts =
                    self.EAttempts + 1

                State.OwnAbilityIgnoreUntil =
                    now
                    + OWN_BUFF_IGNORE_TIME
            end

        elseif qReady then
            if pressKey(
                Enum.KeyCode.Q,
                0x51,
                "Q"
            ) then
                self.QUsed = true
                self.LastQ = now
                self.QAttempts =
                    self.QAttempts + 1

                State.OwnAbilityIgnoreUntil =
                    now
                    + OWN_BUFF_IGNORE_TIME
            end
        elseif eReady then
            if pressKey(
                Enum.KeyCode.E,
                0x45,
                "E"
            ) then
                self.EUsed = true
                self.LastE = now
                self.EAttempts =
                    self.EAttempts + 1
            end
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
-- ADAPTIVE DIRECTOR
--------------------------------------------------

function State:ResetAdaptiveDirector(reason)
    self.AdaptiveMovementOwner = false
    self.AdaptiveIntent = "LEGACY"
    self.AdaptiveReason =
        reason or "TOGGLE OFF"
    self.AdaptiveSpellReason = "LEGACY"
    self.AdaptiveRisk = 0
    self.AdaptiveHealthRatio = 1
    self.AdaptiveDamagePressure = 0
    self.AdaptiveDistanceBonus = 0
    self.AdaptiveCastAllowed = true
    self.AdaptivePathWanted = false
    self.AdaptiveRouteWanted = false
    self.AdaptiveLastThinkAt = -math.huge
    self.AdaptiveLastHealth = nil
    self.AdaptiveLastDamageAt = -math.huge
    self.AdaptiveEmergencySince = nil
    self.AdaptiveTrackedTarget = nil
    self.AdaptiveBestTargetDistance = math.huge
    self.AdaptiveLastProgressAt = -math.huge
    self.DodgeProgressPosition = nil
    self.DodgeProgressAt = -math.huge
    self.DodgeStallChain = 0
end

function State:SetAdaptiveIntent(
    intent,
    reason,
    now
)
    if self.AdaptiveIntent ~= intent then
        self.AdaptiveDecisionChanges =
            (self.AdaptiveDecisionChanges or 0)
            + 1
        self.AdaptiveLastIntentAt = now
    end

    self.AdaptiveIntent = intent
    self.AdaptiveReason = reason
end

function State:AdaptiveThink(
    root,
    humanoid,
    target,
    distance,
    clusterCount,
    level,
    now
)
    if not self.AdaptiveModel then
        if self.AdaptiveMovementOwner then
            self:ResetAdaptiveDirector(
                "TOGGLE OFF"
            )
        end

        return
    end

    self.AdaptiveMovementOwner = true

    if now - self.AdaptiveLastThinkAt
        < CFG.ADAPTIVE_THINK_INTERVAL then

        return
    end

    self.AdaptiveLastThinkAt = now

    local maximumHealth =
        math.max(
            tonumber(humanoid.MaxHealth) or 0,
            1
        )
    local currentHealth =
        math.max(
            tonumber(humanoid.Health) or 0,
            0
        )
    local healthRatio =
        math.clamp(
            currentHealth / maximumHealth,
            0,
            1
        )

    if self.AdaptiveLastHealth
        and self.AdaptiveLastHealth
            - currentHealth
            >= maximumHealth
                * CFG.ADAPTIVE_DAMAGE_SPIKE_RATIO then

        self.AdaptiveLastDamageAt = now
    end

    self.AdaptiveLastHealth = currentHealth
    self.AdaptiveHealthRatio = healthRatio

    local damagePressure =
        math.clamp(
            1
            - (
                now
                - (
                    self.AdaptiveLastDamageAt
                    or -math.huge
                )
            ) / CFG.ADAPTIVE_DAMAGE_MEMORY,
            0,
            1
        )
    local healthPressure =
        math.clamp(
            (
                CFG.ADAPTIVE_LOW_HEALTH_RATIO
                - healthRatio
            ) / math.max(
                CFG.ADAPTIVE_LOW_HEALTH_RATIO
                    - CFG.ADAPTIVE_CRITICAL_HEALTH_RATIO,
                0.01
            ),
            0,
            1
        )

    self.AdaptiveDamagePressure =
        damagePressure
    self.AdaptiveDistanceBonus =
        math.clamp(
            healthPressure
                * CFG.ADAPTIVE_HEALTH_DISTANCE_BONUS
                + damagePressure
                    * CFG.ADAPTIVE_DAMAGE_DISTANCE_BONUS,
            0,
            CFG.ADAPTIVE_DISTANCE_BONUS_MAX
        )

    local hazardRisk =
        level == "EMERGENCY"
        and 1
        or level == "WARNING"
            and 0.72
        or 0
    local proximityRisk = 0
    local spacingEnter =
        self.EnemySpacingEnter
        or FORCE_SPACE_ENTER

    if self.NearestEnemyDistance
        < math.huge
        and self.NearestEnemyDistance
            < spacingEnter then

        proximityRisk =
            math.clamp(
                (
                    spacingEnter
                    - self.NearestEnemyDistance
                ) / math.max(spacingEnter, 1),
                0,
                1
            )
    end

    self.AdaptiveRisk =
        math.clamp(
            math.max(
                hazardRisk,
                proximityRisk * 0.80
            )
                + healthPressure * 0.12
                + damagePressure * 0.18,
            0,
            1
        )

    if level == "EMERGENCY" then
        if not self.AdaptiveEmergencySince then
            self.AdaptiveEmergencySince = now
        end
    else
        self.AdaptiveEmergencySince = nil
    end

    if target ~= self.AdaptiveTrackedTarget then
        self.AdaptiveTrackedTarget = target
        self.AdaptiveBestTargetDistance =
            distance or math.huge
        self.AdaptiveLastProgressAt = now

    elseif validEnemy(target)
        and distance
        and distance < math.huge then

        if distance
            <= self.AdaptiveBestTargetDistance
                - CFG.ADAPTIVE_PROGRESS_STEP then

            self.AdaptiveBestTargetDistance =
                distance
            self.AdaptiveLastProgressAt = now

        elseif distance
            < self.AdaptiveBestTargetDistance then

            self.AdaptiveBestTargetDistance =
                distance
        end
    end

    local desiredDistance,
        adaptiveEnter,
        _,
        movementStopDistance =
            self:CurrentEnemySpacingPlan()
    local stalled =
        validEnemy(target)
        and distance > movementStopDistance + 1
        and now - self.AdaptiveLastProgressAt
            >= CFG.ADAPTIVE_STALL_TIME

    self.AdaptivePathWanted =
        validEnemy(target)
        and (
            stalled
            or distance
                > math.max(
                    CFG.ROUTE_TARGET_DISTANCE,
                    movementStopDistance
                        + CFG.ADAPTIVE_LOCAL_PATH_EXTRA
                )
        )
    self.AdaptiveRouteWanted =
        not validEnemy(target)
        or self.AdaptivePathWanted

    local readyRange =
        self:MaximumReadyOffensiveRange()

    if self.TargetIsBoss then
        readyRange =
            self:BossEffectiveCastRange(
                readyRange
            )
    else
        readyRange =
            math.min(
                readyRange,
                CFG.MOB_CAST_RANGE_CAP
            )
    end

    local castInRange =
        validEnemy(target)
        and readyRange > 0
        and distance <= readyRange

    if self.SpamSpells then
        self.AdaptiveCastAllowed =
            validEnemy(target)
        self.AdaptiveSpellReason =
            "TRUE SPAM OVERRIDE"

    elseif not validEnemy(target) then
        self.AdaptiveCastAllowed = false
        self.AdaptiveSpellReason = "NO TARGET"

    elseif level == "EMERGENCY" then
        local firstDodgeComplete =
            self.AdaptiveEmergencySince
            and now
                - self.AdaptiveEmergencySince
                >= CFG.ADAPTIVE_FIRST_DODGE_TIME

        self.AdaptiveCastAllowed =
            firstDodgeComplete
            and castInRange
            and FacingOkay
            or false
        self.AdaptiveSpellReason =
            firstDodgeComplete
            and (
                self.AdaptiveCastAllowed
                and "ATTACK WHILE DODGING"
                or "DODGE / FIND RANGE"
            )
            or "FIRST DODGE"

    elseif level == "WARNING" then
        self.AdaptiveCastAllowed =
            castInRange
            and FacingOkay
        self.AdaptiveSpellReason =
            self.AdaptiveCastAllowed
            and "CAST WHILE EVADING"
            or "EVADE / FIND RANGE"

    elseif not FacingOkay then
        self.AdaptiveCastAllowed = false
        self.AdaptiveSpellReason = "TURNING"

    elseif not castInRange then
        self.AdaptiveCastAllowed = false
        self.AdaptiveSpellReason =
            readyRange > 0
            and "CLOSE TO CAST"
            or "COOLDOWN"

    elseif self.AdaptiveRisk
        > CFG.ADAPTIVE_CAST_RISK_LIMIT
        and self.NearestEnemyDistance
            < adaptiveEnter then

        self.AdaptiveCastAllowed = false
        self.AdaptiveSpellReason = "CREATE SPACE"
    else
        self.AdaptiveCastAllowed = true
        self.AdaptiveSpellReason = "CAST NOW"
    end

    if level == "EMERGENCY" then
        self:SetAdaptiveIntent(
            "DODGE",
            "LIVE HAZARD",
            now
        )

    elseif level == "WARNING" then
        self:SetAdaptiveIntent(
            "EVADE",
            "PRECAST / PREDICTED HAZARD",
            now
        )

    elseif not validEnemy(target) then
        self:SetAdaptiveIntent(
            "ADVANCE",
            "FOLLOW DUNGEON ROUTE",
            now
        )

    elseif self.NearestEnemyDistance
            < adaptiveEnter
        or (
            healthRatio
                <= CFG.ADAPTIVE_CRITICAL_HEALTH_RATIO
            and self.NearestEnemyDistance
                < desiredDistance + 4
        ) then

        self:SetAdaptiveIntent(
            "RETREAT",
            damagePressure > 0
            and "DAMAGE PRESSURE"
            or "ENEMY TOO CLOSE",
            now
        )

    elseif castInRange
        and self.AdaptiveCastAllowed then

        self:SetAdaptiveIntent(
            "CAST",
            clusterCount and clusterCount > 1
            and "AOE PACK CENTRE"
            or "ABILITY IN RANGE",
            now
        )

    elseif self.AdaptivePathWanted then
        self:SetAdaptiveIntent(
            "PATH",
            stalled
            and "NO APPROACH PROGRESS"
            or "DISTANT TARGET",
            now
        )

    elseif distance > movementStopDistance then
        self:SetAdaptiveIntent(
            "APPROACH",
            self.AdaptiveSpellReason,
            now
        )
    else
        self:SetAdaptiveIntent(
            "ORBIT",
            self.AdaptiveSpellReason,
            now
        )
    end
end

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
        < CFG.STUCK_INTERVAL then

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
        and progress < CFG.MIN_PROGRESS then

        StuckCount =
            StuckCount + 1

        if StuckCount
            > CFG.STUCK_RESET_LIMIT then

            resetStuckCharacter(root)
            return false
        end

        return true
    end

    if progress >= CFG.MIN_PROGRESS then
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
        or Mode == "DODGE HOLD"
        or Mode == "EVADE HOLD"
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
        < CFG.STUCK_INTERVAL then

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

    if moved <= CFG.STATIONARY_DISTANCE then
        StationaryCount =
            StationaryCount + 1
    else
        StationaryCount = 0
    end

    if StationaryCount
        > CFG.STUCK_RESET_LIMIT then

        resetStuckCharacter(root)
        return true
    end

    return false
end

function State:RecoverDodgeStall(
    character,
    root,
    enemy,
    threat,
    level,
    now
)
    if not threat then
        self.DodgeProgressPosition = nil
        self.DodgeProgressAt = now
        self.DodgeStallChain = 0
        return false
    end

    local intended =
        flat(DesiredDirection)

    if not self.DodgeProgressPosition then
        self.DodgeProgressPosition =
            root.Position
        self.DodgeProgressAt = now
        return false
    end

    if now - self.DodgeProgressAt
        < CFG.DODGE_PROGRESS_INTERVAL then

        return false
    end

    local moved =
        (
            flat(root.Position)
            - flat(
                self.DodgeProgressPosition
            )
        ).Magnitude

    self.DodgeProgressPosition =
        root.Position
    self.DodgeProgressAt = now

    if intended.Magnitude < 0.25
        or moved >= CFG.DODGE_PROGRESS_MIN then

        self.DodgeStallChain = 0
        return false
    end

    self.DodgeStallChain =
        (self.DodgeStallChain or 0) + 1
    self.DodgeStallRecoveries =
        (self.DodgeStallRecoveries or 0)
        + 1

    DodgePoint = nil
    EvadePoint = nil
    CurrentDodgeDirection = nil
    LastDodgePlan = now
    LastEvadePlan = now
    clearPath()

    -- A committed side is useful until a wall blocks it. Once actual
    -- movement stops, reverse the commitment immediately rather than
    -- repeatedly steering into the same obstacle.
    if DodgeSide == "LEFT" then
        DodgeSide = "RIGHT"
    elseif DodgeSide == "RIGHT" then
        DodgeSide = "LEFT"
    else
        OrbitSide = -OrbitSide
        DodgeSide =
            OrbitSide > 0
            and "RIGHT"
            or "LEFT"
    end

    local fallback =
        committedLateralFallback(
            root,
            enemy,
            threat
        )

    if not fallback
        or fallback.Magnitude < 0.05 then

        fallback =
            flat(root.CFrame.RightVector)
            * (
                DodgeSide == "RIGHT"
                and 1
                or -1
            )
    end

    if fallback.Magnitude > 0.05 then
        CurrentDodgeDirection =
            fallback.Unit
        DesiredDirection =
            wallSteer(
                fallback,
                root,
                character
            )
    end

    Mode =
        level == "EMERGENCY"
        and "DODGE UNSTUCK"
        or "EVADE UNSTUCK"
    DesiredSpeed =
        level == "EMERGENCY"
        and DODGE_SPEED
        or EVADE_SPEED
    DodgeUntil =
        math.max(
            DodgeUntil,
            now + CFG.DODGE_LOCK
        )

    if self.DodgeStallChain
        > CFG.STUCK_RESET_LIMIT then

        resetStuckCharacter(root)
    end

    return true
end

local function updateRemoteCastMode(
    target,
    distance,
    now
)
    local castRange =
        maximumOffensiveRange()
    local plannedRange =
        State.BossEngagementRange
        or math.max(
            DESIRED_DISTANCE,
            CFG.BOSS_SAFE_RING_OUTER
        )
    local reliableCastLimit =
        State:IsBossEnemy(target)
        and State:BossEffectiveCastRange(
            castRange
        )
        or castRange

    if target ~= RemoteCastTarget then
        RemoteCastTarget = target
        RemoteCastMode = false
        RemoteBestDistance = distance
        RemoteLastProgress = now
        RemoteCastStarted = 0
    end

    if not validEnemy(target)
        or not State:IsBossEnemy(target)
        or reliableCastLimit <= 0
        or distance > reliableCastLimit
        or distance
            <= math.max(
                (
                    State.EnemySpacingDistance
                    or DESIRED_DISTANCE
                ) + 2,
                plannedRange + 0.5
            ) then

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

function State:RecordCombatDeath()
    if Mode == "RESETTING" then
        return
    end

    local now = os.clock()
    local combatActive =
        validEnemy(Target)
        or self.TargetIsBoss
        or now - LastThreatSeen <= 2

    if not combatActive then
        return
    end

    local bossDeath =
        self.TargetIsBoss
        or (
            validEnemy(Target)
            and self:IsBossEnemy(Target)
        )

    if bossDeath then
        if now - (
            self.LastBossDeathAt
            or -math.huge
        ) <= CFG.COMBAT_DEATH_STREAK_WINDOW then

            self.BossDeathStreak =
                (self.BossDeathStreak or 0) + 1
        else
            self.BossDeathStreak = 1
        end

        self.LastBossDeathAt = now
        self.BossSpacingBonus =
            math.min(
                CFG.BOSS_DEATH_DISTANCE_MAX,
                self.BossDeathStreak
                    * CFG.BOSS_DEATH_DISTANCE_STEP
            )

        return
    end

    if now - (
        self.LastCombatDeathAt
        or -math.huge
    ) <= CFG.COMBAT_DEATH_STREAK_WINDOW then

        self.CombatDeathStreak =
            (self.CombatDeathStreak or 0) + 1
    else
        self.CombatDeathStreak = 1
    end

    self.LastCombatDeathAt = now
    self.EnemySpacingBonus =
        math.min(
            CFG.ENEMY_DEATH_DISTANCE_MAX,
            self.CombatDeathStreak
                * CFG.ENEMY_DEATH_DISTANCE_STEP
        )
end

local function resetCombatCycle(nextMode)
    if nextMode == "DEAD" then
        -- Cancel any delayed ability/UI scans that still belong to
        -- the character that just died. CharacterAdded starts a new
        -- generation and performs a clean five-pass rebind.
        State.SpellRespawnGeneration =
            (State.SpellRespawnGeneration or 0) + 1
    end

    SpellFlow:Reset()
    State.ProfileRouteFlow:ResetForRespawn()

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
    State.TargetBodyRadius = 0
    State.TargetPriority = "NONE"
    State.CloseThreatCount = 0
    State.RouteGuidedTarget = false
    State.FarTargetRouting = false
    State.RouteNavigationMode = "RESPAWN"
    State.NearestEnemy = nil
    State.NearestEnemyDistance = math.huge
    State.AdaptivePathActive = false
    State:ResetAdaptiveDirector(
        nextMode or "RESPAWN"
    )
    State.BossEngagementRange =
        math.max(
            DESIRED_DISTANCE,
            CFG.BOSS_SAFE_RING_OUTER
        )
    State.BossSpaceDistance =
        math.max(
            FORCE_SPACE_ENTER,
            State.BossEngagementRange - 3
        )
    State.BossRangeMode = "RESPAWN"
    State.BossRangeSlot = "-"
    State.LastOffensiveQCastAt = -math.huge
    State.LastOffensiveECastAt = -math.huge
    State.PostDodgeCastPending = false
    State.PostDodgeCastExpires = 0
    State.DodgeCastIssuedForThreat = false
    State.FacingLastTarget = nil
    State.FacingLastAimPosition = nil
    State.FacingLastSeenAt = -math.huge

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
    State.LastAITick = -math.huge
    State.LastTargetUpdate = -math.huge

    LastPosition = nil
    LastPositionTime = os.clock()
    StuckCount = 0
    StationaryCount = 0
    StationaryRoot = nil
    StationaryPosition = nil
    StationaryTime = os.clock()

    clearPath()
    State:RestoreWalls()

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
    SpellFlow:RebindAfterRespawn(character)

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
                    State:RecordCombatDeath()
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

        local now = os.clock()

        if now - State.LastAITick
            < CFG.AI_UPDATE_INTERVAL then

            return
        end

        State.LastAITick = now

        local character,
            root,
            humanoid =
                getCharacter()

        if not root then
            return
        end

        updateHazards()

        if not ENABLED then
            Mode = "OFF"

            DesiredDirection =
                Vector3.zero

            return
        end

        --------------------------------------------------
        -- TARGET IMMEDIATELY
        --------------------------------------------------

        if not validEnemy(Target)
            or now - State.LastTargetUpdate
                >= CFG.TARGET_UPDATE_INTERVAL then

            Target,
                TargetDistance,
                TargetAimPosition,
                TargetClusterCount =
                    chooseTarget(
                        root.Position,
                        Target
                    )

            State.LastTargetUpdate = now

        elseif TargetAimPosition then
            TargetDistance =
                (
                    flat(TargetAimPosition)
                    - flat(root.Position)
                ).Magnitude
        end

        local nearestPhysicalRoot =
            validEnemy(State.NearestEnemy)
            and State.NearestEnemy:FindFirstChild(
                "HumanoidRootPart"
            )
            or nil

        State.NearestEnemyDistance =
            nearestPhysicalRoot
            and (
                flat(nearestPhysicalRoot.Position)
                - flat(root.Position)
            ).Magnitude
            or math.huge

        State.TargetIsBoss =
            State:IsBossEnemy(Target)

        State.TargetBodyRadius =
            State.TargetIsBoss
            and State:EstimateEnemyHorizontalRadius(
                Target
            )
            or 0

        State:RefreshBossRangePlan()

        if not State.AdaptiveModel then
            State:CurrentEnemySpacingPlan()
        end

        -- Pack-centre targeting is useful for aiming AoE, but dodge
        -- geometry must reference the body that can actually touch
        -- the player first.
        local dodgeEnemy =
            validEnemy(State.NearestEnemy)
            and State.NearestEnemy
            or Target

        if Target then
            local order =
                enemyRoomOrder(
                    Target
                )

            if order
                and TargetDistance
                    <= CFG.ROUTE_TARGET_DISTANCE then

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

        State:AdaptiveThink(
            root,
            humanoid,
            Target,
            TargetDistance,
            TargetClusterCount,
            level,
            now
        )

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

        if threatAppeared then
            State.DodgeCastIssuedForThreat = false
            State.PostDodgeCastPending = false
        end

        HadThreat =
            threat ~= nil

        PreviousThreatLevel =
            level or "NONE"

        if threat then
            LastThreatSeen = now
        elseif now - LastThreatSeen
            >= CFG.DODGE_SIDE_RELEASE then

            DodgeSide = "NONE"
        end

        if State:RecoverDodgeStall(
            character,
            root,
            dodgeEnemy,
            threat,
            level,
            now
        ) then
            return
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
                    dodgeEnemy,
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
                            now + CFG.DODGE_LOCK
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
                    >= CFG.DODGE_REPLAN then

                local point,
                    side =
                    findEscape(
                        character,
                        root,
                        dodgeEnemy,
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
                    now + CFG.DODGE_LOCK
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
                        dodgeEnemy,
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
                    >= CFG.DODGE_REPLAN then

                local newPoint,
                    newSide =
                    findEscape(
                        character,
                        root,
                        dodgeEnemy,
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

            if level == "EMERGENCY" then
                State:RequestPostDodgeCast(now)
                DodgePoint = nil
                Mode = "DODGE CAST"
                DesiredSpeed = DODGE_SPEED

                local fallback =
                    committedLateralFallback(
                        root,
                        dodgeEnemy,
                        threat
                    )

                DesiredDirection =
                    fallback
                    and wallSteer(
                        fallback,
                        root,
                        character
                    )
                    or Vector3.zero
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

            if replan
                and now - LastEvadePlan
                    >= CFG.EVADE_REPLAN then

                local side

                EvadePoint,
                    side =
                    findEscape(
                        character,
                        root,
                        dodgeEnemy,
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
                local delta =
                    flat(
                        EvadePoint
                        - root.Position
                    )

                if delta.Magnitude < 2.2 then
                    State:RequestPostDodgeCast(now)
                    EvadePoint = nil
                    Mode = "EVADE CAST"

                    local fallback =
                    committedLateralFallback(
                        root,
                        dodgeEnemy,
                        threat
                    )

                    DesiredDirection =
                        fallback
                        and wallSteer(
                            fallback,
                            root,
                            character
                        )
                        or Vector3.zero

                else
                    DesiredDirection =
                        wallSteer(
                            delta,
                            root,
                            character
                        )
                end

                return
            end

            --------------------------------------------------
            -- FALLBACK STRAFE
            --------------------------------------------------

            local fallback =
                committedLateralFallback(
                    root,
                    dodgeEnemy,
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

        if not State.AdaptiveModel
            and SpellFlow:ShouldHold() then
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
            and validEnemy(Target)
            and (
                not State.AdaptiveModel
                or State.AdaptiveIntent
                    == "CAST"
            ) then

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
            State.RouteGuidedTarget = false
            State.FarTargetRouting = false
            State.RouteNavigationMode = "NO TARGET"
            State.AdaptivePathActive = false

            fallbackEnemyScan()

            -- A mapped route is only a navigation spine. It is
            -- consulted when combat is clear; attacking and every
            -- dodge branch above retain completely free movement.
            local routePoint =
                State.ProfileRouteFlow:ProgressPoint(
                    root.Position
                )

            local room = nil
            local point = routePoint

            if routePoint
                and routePoint.RoomOrder then

                LastRoomOrder =
                    math.max(
                        LastRoomOrder,
                        routePoint.RoomOrder
                    )
            end

            if not point then
                room =
                    findNextRoom(
                        LastRoomOrder
                    )

                point =
                    roomProgressPoint(
                        room,
                        root.Position
                    )
            end

            if point then
                State.RouteNavigationMode =
                    State.AdaptiveModel
                    and (
                        routePoint
                        and "ADAPTIVE RECORDED ROUTE"
                        or "ADAPTIVE ROOM FALLBACK"
                    )
                    or routePoint
                    and "RECORDED PROGRESS"
                    or "ROOM FALLBACK"
                Mode =
                    State.AdaptiveModel
                    and "ADAPT ADVANCE"
                    or routePoint
                    and "ROUTE"
                    or "NEXT ROOM"

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

        local combatNavigationPosition =
            TargetAimPosition
            or enemyRoot.Position

        local navigationPosition =
            combatNavigationPosition

        -- Aim may use the middle of a pack, but personal spacing must
        -- use the nearest physical enemy. A cluster centre can look
        -- safely distant while one member is touching the player.
        local desiredEnemyDistance,
            spacingEnter,
            spacingExit,
            movementStopDistance =
                State:CurrentEnemySpacingPlan()

        local nearestSpacingRoot =
            validEnemy(State.NearestEnemy)
            and State.NearestEnemy:FindFirstChild(
                "HumanoidRootPart"
            )
            or nil
        local spacingDistance = TargetDistance
        local spacingThreatPosition =
            combatNavigationPosition

        if nearestSpacingRoot
            and State.NearestEnemyDistance
                < spacingDistance then

            spacingDistance =
                State.NearestEnemyDistance
            spacingThreatPosition =
                nearestSpacingRoot.Position
        end

        if State.AdaptiveModel then
            State.SpacingActive =
                State.AdaptiveIntent
                    == "RETREAT"
                or spacingDistance
                    < spacingEnter
        else
            if spacingDistance < spacingEnter then
                State.SpacingActive = true
            elseif spacingDistance >= spacingExit then
                State.SpacingActive = false
            end
        end

        local needsApproach =
            not State.SpacingActive
            and (
                State.AdaptiveModel
                and (
                    State.AdaptiveIntent
                        == "APPROACH"
                    or State.AdaptiveIntent
                        == "PATH"
                )
                or (
                    not State.AdaptiveModel
                    and TargetDistance
                        > movementStopDistance + 0.5
                )
            )
        local farTarget =
            needsApproach
            and (
                State.AdaptiveModel
                and State.AdaptivePathWanted
                or (
                    not State.AdaptiveModel
                    and TargetDistance
                        > math.max(
                            CFG.ROUTE_TARGET_DISTANCE,
                            movementStopDistance + 8
                        )
                )
            )

        State.RouteGuidedTarget = false
        State.AdaptivePathActive = false
        State.FarTargetRouting = farTarget
        State.RouteNavigationMode =
            farTarget
            and "SEEKING ROUTE"
            or "LOCAL"

        -- Distant enemies and bosses are approached along the
        -- recorded dungeon spine. Combat and every dodge branch
        -- above still have unrestricted local movement.
        if State.TargetPriority ~= "DANGER"
            and farTarget then

            local routeApproach =
                State.ProfileRouteFlow:
                TargetApproachPoint(
                    root.Position,
                    combatNavigationPosition,
                    enemyRoomOrder(Target)
                )

            if routeApproach
                and routeApproach.Position
                and (
                    flat(
                        routeApproach.Position
                        - root.Position
                    )
                ).Magnitude > 2.5 then

                navigationPosition =
                    routeApproach.Position
                State.RouteGuidedTarget = true
                State.RouteNavigationMode =
                    "RECORDED ROUTE"

                if routeApproach.RoomOrder then
                    LastRoomOrder =
                        math.max(
                            LastRoomOrder,
                            routeApproach.RoomOrder
                        )
                end
            end
        end

        -- Recorded walk points take priority for distant targets even
        -- when Adaptive Model is enabled. Live pathfinding is used
        -- only when no recorded point is available.
        -- All threat/dodge branches have already run above, so they
        -- always override this path on the same heartbeat.
        if State.AdaptiveModel
            and State.TargetPriority ~= "DANGER"
            and needsApproach
            and not State.RouteGuidedTarget then

            local adaptiveDestination =
                combatNavigationPosition

            local pathChanged =
                not PathDestination
                or (
                    flat(
                        PathDestination
                        - adaptiveDestination
                    )
                ).Magnitude
                    > CFG.ADAPTIVE_TARGET_CHANGE

            if pathChanged or not Waypoints then
                buildPath(
                    root.Position,
                    adaptiveDestination,
                    false
                )
            end

            if stuckCheck(root) then
                buildPath(
                    root.Position,
                    adaptiveDestination,
                    true
                )
            end

            local adaptiveDirection =
                pathDirection(
                    root,
                    humanoid
                )

            if adaptiveDirection then
                State.AdaptivePathActive = true
                State.RouteNavigationMode =
                    farTarget
                    and "LIVE FAR PATH"
                    or "ADAPTIVE PATH"
                Mode =
                    State.TargetIsBoss
                    and "BOSS ADAPT"
                    or "ADAPTIVE PATH"
                DesiredSpeed = PATH_SPEED
                DesiredDirection =
                    wallSteer(
                        adaptiveDirection,
                        root,
                        character
                    )
                return
            end
        end

        -- If the profile has no usable walk point, a distant target
        -- still gets a real PathfindingService route. Never fall back
        -- immediately to a straight line across walls or rooms.
        if farTarget
            and State.TargetPriority ~= "DANGER"
            and not State.RouteGuidedTarget then

            local pathChanged =
                not PathDestination
                or (
                    flat(
                        PathDestination
                        - combatNavigationPosition
                    )
                ).Magnitude > 7

            if pathChanged or not Waypoints then
                buildPath(
                    root.Position,
                    combatNavigationPosition,
                    false
                )
            end

            if not State.AdaptiveModel
                and stuckCheck(root) then
                buildPath(
                    root.Position,
                    combatNavigationPosition,
                    true
                )
            end

            local farDirection =
                pathDirection(
                    root,
                    humanoid
                )

            if farDirection then
                State.AdaptivePathActive = true
                State.RouteNavigationMode =
                    "LIVE FAR PATH"
                Mode =
                    State.TargetIsBoss
                    and "BOSS FAR PATH"
                    or "FAR TARGET PATH"
                DesiredSpeed = PATH_SPEED
                DesiredDirection =
                    wallSteer(
                        farDirection,
                        root,
                        character
                    )
                return
            end

            State.RouteNavigationMode =
                "FAR PATH RETRY"
            Mode = "FAR PATH RETRY"
            DesiredSpeed = 0
            DesiredDirection = Vector3.zero
            return
        end

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
            > movementStopDistance + 0.5 then

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
                    >= CFG.BLOCKED_DELAY then

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

        --------------------------------------------------
        -- FORCED PERSONAL SPACE WITH HYSTERESIS
        --------------------------------------------------

        if State.SpacingActive then

            Mode =
                State.AdaptiveModel
                and "ADAPT RETREAT"
                or State.TargetIsBoss
                and "BOSS RETREAT"
                or "SPACE"
            DesiredSpeed = SPACE_SPEED

            local nearestAway =
                flat(
                    spacingThreatPosition
                    - root.Position
                )
            local radial =
                nearestAway.Magnitude > 0.05
                and nearestAway.Unit
                or toward.Unit

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

        elseif (
            State.AdaptiveModel
            and (
                State.AdaptiveIntent
                    == "APPROACH"
                or State.AdaptiveIntent
                    == "PATH"
            )
        )
            or (
                not State.AdaptiveModel
                and TargetDistance
                    > movementStopDistance
            ) then

            Mode =
                State.AdaptiveModel
                and (
                    State.RouteGuidedTarget
                    and "ADAPT ROUTE"
                    or "ADAPT APPROACH"
                )
                or State.RouteGuidedTarget
                and (
                    State.TargetIsBoss
                    and "BOSS ROUTE"
                    or "TARGET ROUTE"
                )
                or State.TargetIsBoss
                    and "BOSS CAST APPROACH"
                    or "CHASE"
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
            Mode =
                State.AdaptiveModel
                and (
                    State.AdaptiveIntent
                        == "CAST"
                    and "ADAPT CAST"
                    or "ADAPT ORBIT"
                )
                or State.TargetIsBoss
                and "BOSS RANGE"
                or "ORBIT"
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
                        - desiredEnemyDistance
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

        State:MaintainWallNoclip(root)

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
                    Version = "V7.21-AA",
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
                    ENABLED = value ~= false

                    if not ENABLED then
                        DesiredDirection =
                            Vector3.zero
                    end
                end
            })

            combatControls:Toggle({
                Title = "Walls-only Noclip",
                Desc = "Pass vertical walls when needed; floors stay solid",
                Value = State.WallNoclip,
                Flag = "DQWallsOnlyNoclip",
                Callback = function(value)
                    State.WallNoclip =
                        value ~= false

                    if not State.WallNoclip then
                        State:RestoreWalls()
                    end
                end
            })

            combatControls:Toggle({
                Title = "Adaptive Boss Casting",
                Desc = "Cast farther using spell reach, boss body size and a safe AoE probe",
                Value = State.AdaptiveBossRange,
                Flag = "DQAdaptiveBossRange",
                Callback = function(value)
                    State.AdaptiveBossRange =
                        value ~= false
                    State:RefreshBossRangePlan()
                    clearPath()
                end
            })

            combatControls:Toggle({
                Title = "Adaptive Model",
                Desc = "Utility AI owns walking, spacing, path choice and spell timing; hazards remain highest priority",
                Value = State.AdaptiveModel,
                Flag = "DQAdaptiveModel",
                Callback = function(value)
                    State.AdaptiveModel =
                        value ~= false
                    State:ResetAdaptiveDirector(
                        State.AdaptiveModel
                        and "INITIALIZING"
                        or "TOGGLE OFF"
                    )
                    State.AdaptivePathActive = false
                    clearPath()
                end
            })

            combatControls:Toggle({
                Title = "Auto Q — "
                    .. currentAbilityName("Q"),
                Desc = "Automatically cast the equipped Q ability",
                Value = AUTO_Q,
                Flag = "DQAutoQ",
                Callback = function(value)
                    AUTO_Q = value ~= false
                end
            })

            combatControls:Toggle({
                Title = "Auto E — "
                    .. currentAbilityName("E"),
                Desc = "Automatically cast the equipped E ability",
                Value = AUTO_E,
                Flag = "DQAutoE",
                Callback = function(value)
                    AUTO_E = value ~= false
                end
            })

            combatControls:Toggle({
                Title = "Spam Spells",
                Desc = "Retry every ready Q/E while alive—even after death, without waiting for a target, pack, range, route, or dodge",
                Value = State.SpamSpells,
                Flag = "DQSpamSpells",
                Callback = function(value)
                    State.SpamSpells =
                        value ~= false

                    if State.SpamSpells then
                        State.PostDodgeCastPending = false
                    end
                end
            })

            combatControls:Button({
                Title = "Cast Q + E now",
                Desc = "Buff first, then second power after casting unlocks",
                Icon = "sparkles",
                Callback = function()
                    SpellFlow:CastBothNow()
                end
            })

            combatControls:Button({
                Title = "Cast Q now",
                Desc = "Test the equipped Q input immediately",
                Icon = "zap",
                Callback = function()
                    SpellFlow:CastNow("Q")
                end
            })

            combatControls:Button({
                Title = "Cast E now",
                Desc = "Test the equipped E input immediately",
                Icon = "waves",
                Callback = function()
                    SpellFlow:CastNow("E")
                end
            })

            combatTab:Paragraph({
                Title = "Split mob / boss spacing",
                Desc = "Mobs prefer 48 studs and use the nearest physical mob, never the pack centre. Bosses use a separate 70-stud outer ring, never cast closer than 55, and add measured boss size plus a safe AoE probe to spell reach. Boss deaths add 8 up to a 94-stud outer ring.",
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

                    if statusElapsed < 0.35 then
                        return
                    end

                    statusElapsed = 0

                    local hazardCount = 0
                    local precastCount = 0
                    local liveHazardCount = 0
                    local expandingCount = 0
                    local laserCount = 0
                    local projectileCount = 0
                    local enemyCount = 0

                    for _, hazard in pairs(
                        Hazards
                    ) do
                        hazardCount =
                            hazardCount + 1

                        if hazard.Kind == "PRECAST" then
                            precastCount =
                                precastCount + 1
                        elseif isLiveHazard(hazard) then
                            liveHazardCount =
                                liveHazardCount + 1
                        end

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

                    local nearestDistanceText =
                        State.NearestEnemyDistance
                            < math.huge
                        and string.format(
                            "%.1f",
                            State.NearestEnemyDistance
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
                            tostring(WaypointIndex)
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
                        .. " | Nearest physical:"
                        .. nearestDistanceText
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
                        .. " | Priority:"
                        .. tostring(
                            State.TargetPriority
                                or "NONE"
                        )
                        .. "\nThreat: "
                        .. ThreatLevel
                        .. " / "
                        .. ThreatKind
                        .. "\nDanger now/future: "
                        .. dangerNow
                        .. " / "
                        .. dangerFuture
                        .. "\nAdaptive:"
                        .. (
                            State.AdaptiveModel
                            and "ON/"
                                .. tostring(
                                    State.AdaptiveIntent
                                        or "THINK"
                                )
                            or "OFF/LEGACY"
                        )
                        .. " | Risk:"
                        .. string.format(
                            "%.2f",
                            State.AdaptiveRisk or 0
                        )
                        .. " | HP:"
                        .. string.format(
                            "%.0f%%",
                            (State.AdaptiveHealthRatio or 1)
                                * 100
                        )
                        .. " | Safety:+"
                        .. string.format(
                            "%.1f",
                            State.AdaptiveDistanceBonus or 0
                        )
                        .. "\nAI reason:"
                        .. tostring(
                            State.AdaptiveReason
                                or "LEGACY"
                        )
                        .. " | Spell:"
                        .. tostring(
                            State.AdaptiveSpellReason
                                or "LEGACY"
                        )
                        .. "\nDodge side: "
                        .. DodgeSide
                        .. " | Expand:"
                        .. expandingCount
                        .. "\nHazards: "
                        .. hazardCount
                        .. " | Live:"
                        .. liveHazardCount
                        .. " | Pre:"
                        .. precastCount
                        .. "\nLasers:"
                        .. laserCount
                        .. " | Proj:"
                        .. projectileCount
                        .. "\nEnemies: "
                        .. enemyCount
                        .. " | Room:"
                        .. tostring(LastRoomOrder)
                        .. "\nPath: "
                        .. pathText
                        .. " | Route:"
                        .. tostring(State.RouteIndex or 0)
                        .. "/"
                        .. tostring(State.RouteCount or 0)
                        .. " | Guide:"
                        .. (
                            State.RouteGuidedTarget
                            and "ON"
                            or "OFF"
                        )
                        .. "\nRoute mode:"
                        .. tostring(
                            State.RouteNavigationMode
                                or "LOCAL"
                        )
                        .. " | Party:"
                        .. tostring(
                            State.PartyMemberCount or 0
                        )
                        .. " | Stuck:"
                        .. tostring(StuckCount)
                        .. " | Still:"
                        .. tostring(StationaryCount)
                        .. "\nClose threats: "
                        .. tostring(
                            State.CloseThreatCount or 0
                        )
                        .. " | Wall noclip:"
                        .. (
                            State.WallNoclip
                            and "ON/"
                            or "OFF/"
                        )
                        .. tostring(
                            State.OpenWallCount or 0
                        )
                        .. "\nSpells: "
                        .. SpellFlow:Status()
                        .. "\nRanges: "
                        .. State:AbilityRangeStatus("Q")
                        .. " | "
                        .. State:AbilityRangeStatus("E")
                        .. "\nTarget spacing: "
                        .. string.format(
                            "%.1f",
                            State.EnemySpacingDistance
                                or DESIRED_DISTANCE
                        )
                        .. " | Retreat<"
                        .. string.format(
                            "%.1f",
                            State.EnemySpacingEnter
                                or FORCE_SPACE_ENTER
                        )
                        .. " | Type:"
                        .. (
                            State.TargetIsBoss
                            and "BOSS"
                            or "MOB"
                        )
                        .. "\nSpacing mode:"
                        .. tostring(
                            State.BossSpacingMode or "MOB"
                        )
                        .. " | Bonus:+"
                        .. tostring(
                            State.TargetIsBoss
                            and (State.BossSpacingBonus or 0)
                            or (State.EnemySpacingBonus or 0)
                        )
                        .. " ("
                        .. tostring(
                            State.TargetIsBoss
                            and (State.BossDeathStreak or 0)
                            or (State.CombatDeathStreak or 0)
                        )
                        .. ")"
                        .. "\nUsable attack reach: "
                        .. string.format(
                            "%.1f",
                            State.EnemySpacingCastRange
                                or 0
                        )
                        .. " | Boss outer:"
                        .. tostring(
                            State.BossOuterDistance or 0
                        )
                        .. " | Body:+"
                        .. string.format(
                            "%.1f",
                            State.TargetBodyRadius or 0
                        )
                        .. "\nDodge movement:WALK"
                        .. " | Unstuck:"
                        .. tostring(
                            State.DodgeStallRecoveries or 0
                        )
                        .. " | Post-dodge casts:"
                        .. tostring(
                            State.PostDodgeCastAttempts or 0
                        )
                        .. "\nSpell respawn rebinds:"
                        .. tostring(
                            State.SpellRespawnRebinds or 0
                        )
                        .. "\nNavigation: "
                        .. (
                            State.AdaptiveModel
                            and "ADAPTIVE"
                            or DungeonData.Loaded
                                and "PROFILE"
                            or "UNIVERSAL"
                        )
                        .. " | Live path:"
                        .. (
                            State.AdaptivePathActive
                            and "ON"
                            or "OFF"
                        )
                        .. "\nProfile: "
                        .. DungeonData.Name
                        .. "\nHazard DB: "
                        .. (
                            DungeonData.HazardRegistryLoaded
                            and (
                                "ON/"
                                .. tostring(
                                    DungeonData.HazardFamilyCount
                                )
                            )
                            or "FALLBACK"
                        )
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
                "Combat Pilot V7.21-AA",
                DungeonData.HazardRegistryLoaded
                    and (
                        "Xyneria WindUI loaded with "
                        .. tostring(
                            DungeonData.HazardFamilyCount
                        )
                        .. " hazard families."
                    )
                    or (
                        "Xyneria WindUI loaded; hazard DB unavailable, "
                        .. "using universal fallback."
                    ),
                DungeonData.HazardRegistryLoaded
                    and "check"
                    or "triangle-alert",
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
    "Dungeon Quest Combat Pilot V7.21-AA loaded"
)
