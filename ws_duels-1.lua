--[[
    WS DUELS  BY @KaZuDev and ghost  FIXED Bugs
    - Theme picker   Added by @KaZuDev (theme switch bug FIXED)
    - GUI Scale     Added by @KaZuDev
    - Keybinds      Added By @KaZuDev
    - Auto Config   Made By @KaZuDev
    - Auto Grab   Fixed By @Ghost    (radius + delay settings)
    - Inf Jump    Fixed respawn-on-steal bug

    FIX SUMMARY:
    1. startPatrol / stopPatrol / startStealLoop / stopStealLoop moved to
       module scope so they survive GUI rebuilds on theme/scale change.
    2. globalKeybindConn / heartbeatConn / statusBarConn are disconnected
       before every rebuild, preventing duplicate listeners.
    3. ApplyTheme no longer sets _savedConfig.toggles = nil, so active
       toggles are preserved visually after a theme switch.
    4. Toggle state-setter upvalues (ssF, ssAR, ...) are always valid
       because they are module-level and reassigned inside BuildMainGUI.
    5. Inf Jump no longer forces Freefall state override during steal
       interactions, preventing accidental respawn triggers.
]]

if not game:IsLoaded() then game.Loaded:Wait() end

local UIS          = game:GetService("UserInputService")
local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService  = game:GetService("HttpService")
local Lighting     = game:GetService("Lighting")
local player       = Players.LocalPlayer
local ParentUI     = (gethui and gethui()) or game:GetService("CoreGui")

-- ============================================================
--  THEMES
-- ============================================================
local Themes = {
    Blue = {
        bg0=Color3.fromRGB(4,6,16), bg1=Color3.fromRGB(7,12,28),
        bg2=Color3.fromRGB(10,18,40), bg3=Color3.fromRGB(16,26,56),
        ac0=Color3.fromRGB(100,180,255), ac1=Color3.fromRGB(60,140,245),
        ac2=Color3.fromRGB(30,90,200), ac3=Color3.fromRGB(14,42,110),
        acOff=Color3.fromRGB(8,20,58), border=Color3.fromRGB(50,120,240),
        borderDim=Color3.fromRGB(20,44,100), dot=Color3.fromRGB(60,130,230),
        dotBright=Color3.fromRGB(110,180,255), cyan=Color3.fromRGB(110,220,255),
        cyanDim=Color3.fromRGB(35,110,165), name="BLUE",
    },
    Green = {
        bg0=Color3.fromRGB(4,10,8), bg1=Color3.fromRGB(6,16,12),
        bg2=Color3.fromRGB(9,22,16), bg3=Color3.fromRGB(12,30,20),
        ac0=Color3.fromRGB(0,255,150), ac1=Color3.fromRGB(0,220,120),
        ac2=Color3.fromRGB(0,165,82), ac3=Color3.fromRGB(0,80,45),
        acOff=Color3.fromRGB(4,20,12), border=Color3.fromRGB(0,160,80),
        borderDim=Color3.fromRGB(8,44,28), dot=Color3.fromRGB(0,155,90),
        dotBright=Color3.fromRGB(0,235,145), cyan=Color3.fromRGB(70,255,210),
        cyanDim=Color3.fromRGB(12,110,78), name="GREEN",
    },
    Red = {
        bg0=Color3.fromRGB(16,4,4), bg1=Color3.fromRGB(24,7,7),
        bg2=Color3.fromRGB(34,10,10), bg3=Color3.fromRGB(48,14,14),
        ac0=Color3.fromRGB(255,90,90), ac1=Color3.fromRGB(230,55,55),
        ac2=Color3.fromRGB(185,28,28), ac3=Color3.fromRGB(100,14,14),
        acOff=Color3.fromRGB(38,8,8), border=Color3.fromRGB(215,45,45),
        borderDim=Color3.fromRGB(75,18,18), dot=Color3.fromRGB(195,45,45),
        dotBright=Color3.fromRGB(255,100,100), cyan=Color3.fromRGB(255,170,110),
        cyanDim=Color3.fromRGB(150,65,32), name="RED",
    },
    Dark = {
        bg0=Color3.fromRGB(4,4,6), bg1=Color3.fromRGB(8,8,12),
        bg2=Color3.fromRGB(13,13,18), bg3=Color3.fromRGB(20,20,28),
        ac0=Color3.fromRGB(200,205,220), ac1=Color3.fromRGB(155,162,182),
        ac2=Color3.fromRGB(100,107,130), ac3=Color3.fromRGB(48,52,66),
        acOff=Color3.fromRGB(16,16,24), border=Color3.fromRGB(90,97,125),
        borderDim=Color3.fromRGB(30,33,48), dot=Color3.fromRGB(78,84,112),
        dotBright=Color3.fromRGB(145,152,180), cyan=Color3.fromRGB(190,210,240),
        cyanDim=Color3.fromRGB(75,86,118), name="DARK",
    },
}
local txtPrime  = Color3.fromRGB(225,236,252)
local txtSub    = Color3.fromRGB(135,152,180)
local txtMute   = Color3.fromRGB(65,78,108)
local inactive  = Color3.fromRGB(44,54,84)
local warn      = Color3.fromRGB(255,200,60)

-- ============================================================
--  ALL GLOBAL STATE
-- ============================================================
local T                    = Themes.Dark
local currentThemeName     = "Dark"
local isMobile             = false
local guiScale             = 1.0
local floating             = false
local heartbeatConn        = nil
local statusBarConn        = nil
local globalKeybindConn    = nil
local waitingForCountdownL = false
local waitingForCountdownR = false
local AUTO_START_DELAY     = 0.7
local batAimbotActive      = false
local batAimbotConn        = nil
local AimbotRadius         = 100
local BatAimbotSpeed       = 55
local spinActive           = false
local spinAngle            = 0
local spinSpeed            = 20
local spinAlign, spinAttachment, spinConn = nil,nil,nil
local stealSpeedActive     = false
local stealSpeedConn       = nil
local STEAL_SPEED_VALUE    = 29
local STEAL_DST            = 10
local STEAL_SPD            = 29
local antiRagdollActive    = false
local antiRagdollConn      = nil
local unwalkActive         = false
local unwalkConn           = nil
local antiFlingActive      = false
local antiFlingConn        = nil
local infJumpActive        = false
local infJumpConn          = nil
local infJumpFallConn      = nil
local stealActive          = false
local isStealing           = false
local stealLoopRunning     = false
local stealThread          = nil
local stealConn            = nil
local autoGrabActive       = false
local autoGrabConn         = nil
local AUTO_GRAB_RADIUS     = 15
local AUTO_GRAB_DELAY      = 0.3
local _wfConns             = {}
local _wfActive            = false
local tauntActive          = false
local tauntLoop            = nil
local autoTpDownActive     = false
local autoTpDownConn       = nil
local ssATD                = function()end
local HideKeybind          = Enum.KeyCode.RightControl
local patrolRightSpeed     = 60
local patrolLeftSpeed      = 60
local FeatureKeybinds      = {}
local MobileShortcuts      = {}
local FeatureStates        = {}

local ssF, ssAR, ssAL, ssAim, ssDr, ssAF, ssARag, ssSp, ssUw, ssSt, ssSspd, ssTnt, ssGrab, ssIJ =
    function()end, function()end, function()end, function()end, function()end,
    function()end, function()end, function()end, function()end, function()end,
    function()end, function()end, function()end, function()end

-- Forward declarations so they are valid locals at module scope
local startPatrol, stopPatrol, startStealLoop, stopStealLoop

local toggleSetState = {}
local SBStatus, SBFill, sbDots, SBRadVal, SBSecVal
local isSt = false
local bindCallbacks = {}
local registeredDotSets = {}

local SlapList = {
    {1,"Bat"},{2,"Slap"},{3,"Iron Slap"},{4,"Gold Slap"},{5,"Diamond Slap"},
    {6,"Emerald Slap"},{7,"Ruby Slap"},{8,"Dark Matter Slap"},{9,"Flame Slap"},
    {10,"Nuclear Slap"},{11,"Galaxy Slap"},{12,"Glitched Slap"}
}

-- ============================================================
--  SCALE HELPER
-- ============================================================
local function S(v) return math.floor(v * guiScale) end

-- ============================================================
--  CONFIG
-- ============================================================
local CONFIG_FILE = "WsDuels_config.json"

local function SaveConfig()
    if not writefile then return end
    local keybindNames = {}
    for id, kc in pairs(FeatureKeybinds) do keybindNames[id] = kc.Name end
    local data = {
        theme      = currentThemeName,
        scale      = guiScale,
        rightSpeed = patrolRightSpeed,
        leftSpeed  = patrolLeftSpeed,
        toggles    = {
            antiFling = antiFlingActive,
            antiRag   = antiRagdollActive,
            infJump   = infJumpActive,
            spinBot   = spinActive,
            unwalk    = unwalkActive,
            stealSpd  = stealSpeedActive,
            taunt     = tauntActive,
            autoGrab  = autoGrabActive,
            optimizer = optimizerActive,
            autoTpDown= autoTpDownActive,
        },
        autoGrabRadius = AUTO_GRAB_RADIUS,
        autoGrabDelay  = AUTO_GRAB_DELAY,
        stealDst       = STEAL_DST,
        stealSpd       = STEAL_SPD,
        keybinds  = keybindNames,
        shortcuts = MobileShortcuts,
    }
    pcall(function() writefile(CONFIG_FILE, HttpService:JSONEncode(data)) end)
end

local _savedConfig = nil
local function LoadConfig()
    if not readfile then return end
    pcall(function()
        local raw = readfile(CONFIG_FILE)
        if raw and raw ~= "" then _savedConfig = HttpService:JSONDecode(raw) end
    end)
end

local function ApplyConfigToState(cfg)
    if not cfg then return end
    if cfg.theme and Themes[cfg.theme] then T = Themes[cfg.theme]; currentThemeName = cfg.theme end
    if cfg.scale then guiScale = math.clamp(cfg.scale, 0.5, 2.0) end
    if cfg.rightSpeed then patrolRightSpeed = cfg.rightSpeed end
    if cfg.leftSpeed  then patrolLeftSpeed  = cfg.leftSpeed  end
    if cfg.toggles then
        if cfg.toggles.antiFling then antiFlingActive   = cfg.toggles.antiFling end
        if cfg.toggles.antiRag   then antiRagdollActive = cfg.toggles.antiRag   end
        if cfg.toggles.infJump   then infJumpActive     = cfg.toggles.infJump   end
        if cfg.toggles.spinBot   then spinActive        = cfg.toggles.spinBot   end
        if cfg.toggles.unwalk    then unwalkActive      = cfg.toggles.unwalk    end
        if cfg.toggles.stealSpd  then stealSpeedActive  = cfg.toggles.stealSpd  end
        if cfg.toggles.taunt     then tauntActive       = cfg.toggles.taunt     end
        if cfg.toggles.autoGrab  then autoGrabActive    = cfg.toggles.autoGrab  end
        if cfg.toggles.optimizer  then optimizerActive   = cfg.toggles.optimizer  end
        if cfg.toggles.autoTpDown then autoTpDownActive = cfg.toggles.autoTpDown end
    end
    if cfg.autoGrabRadius then AUTO_GRAB_RADIUS = math.clamp(cfg.autoGrabRadius, 1, 100) end
    if cfg.autoGrabDelay  then AUTO_GRAB_DELAY  = math.clamp(cfg.autoGrabDelay, 0.05, 5) end
    if cfg.stealDst       then STEAL_DST        = math.clamp(cfg.stealDst, 1, 200) end
    if cfg.stealSpd       then STEAL_SPD        = math.clamp(cfg.stealSpd, 1, 200) end
    if cfg.keybinds then
        for id, name in pairs(cfg.keybinds) do
            local ok, kc = pcall(function() return Enum.KeyCode[name] end)
            if ok and kc then FeatureKeybinds[id] = kc end
        end
    end
    if cfg.shortcuts and type(cfg.shortcuts) == "table" then MobileShortcuts = cfg.shortcuts end
end

LoadConfig()
ApplyConfigToState(_savedConfig)

-- ============================================================
--  WAYPOINTS
-- ============================================================
local rightWaypoints = {
    Vector3.new(-470.6,-5.9,34.4),
    Vector3.new(-484.2,-3.9,21.4),
    Vector3.new(-475.6,-5.8,29.3),
    Vector3.new(-474.24,-7.09,93.00),
    Vector3.new(-482.57,-5.13,94.51),
}
local leftWaypoints = {
    Vector3.new(-474.7,-5.9,91.0),
    Vector3.new(-483.4,-3.9,97.3),
    Vector3.new(-474.7,-5.9,91.0),
    Vector3.new(-472.31,-7.09,26.70),
    Vector3.new(-482.74,-5.13,24.12),
}
local patrolMode      = "none"
local currentWaypoint = 1

-- ============================================================
--  CUSTOM WAYPOINTS  (set by the user via the editor panel)
-- ============================================================
local customRight = {nil,nil,nil,nil}
local customLeft  = {nil,nil,nil,nil}
local wpMarkerParts = {}  -- neon spheres shown in workspace

local function getEffectiveWaypoints(side)
    local defaults = side=="right" and rightWaypoints or leftWaypoints
    local customs  = side=="right" and customRight   or customLeft
    local result   = {}
    for i=1,math.min(4,#defaults) do
        result[i] = customs[i] or defaults[i]
    end
    -- include extra default waypoints beyond 4
    for i=5,#defaults do result[i]=defaults[i] end
    return result
end

local function updatePatrolWaypoints()
    rightWaypoints = getEffectiveWaypoints("right")
    leftWaypoints  = getEffectiveWaypoints("left")
end

local function clearWpMarkers()
    for _,p in pairs(wpMarkerParts) do pcall(function() p:Destroy() end) end
    wpMarkerParts={}
end

local function makeWpMarker(pos,label,col)
    local part=Instance.new("Part")
    part.Name="WS_WpMarker"; part.Shape=Enum.PartType.Ball
    part.Material=Enum.Material.Neon; part.Color=col
    part.Size=Vector3.new(1.5,1.5,1.5); part.Position=pos
    part.Anchored=true; part.CanCollide=false; part.CastShadow=false
    part.Transparency=0.1; part.Parent=workspace
    local bb=Instance.new("BillboardGui",part)
    bb.Size=UDim2.new(0,60,0,22); bb.StudsOffset=Vector3.new(0,1.4,0); bb.AlwaysOnTop=true
    local lbl=Instance.new("TextLabel",bb)
    lbl.Size=UDim2.new(1,0,1,0); lbl.BackgroundTransparency=1; lbl.Text=label
    lbl.TextColor3=Color3.fromRGB(255,255,255); lbl.Font=Enum.Font.GothamBlack; lbl.TextSize=14
    return part
end

local function refreshWpMarkers()
    clearWpMarkers()
    local rCol=Color3.fromRGB(255,90,90)
    local lCol=Color3.fromRGB(90,180,255)
    local effR=getEffectiveWaypoints("right")
    local effL=getEffectiveWaypoints("left")
    for i=1,4 do
        if effR[i] then wpMarkerParts["R"..i]=makeWpMarker(effR[i],"R"..i,rCol) end
        if effL[i] then wpMarkerParts["L"..i]=makeWpMarker(effL[i],"L"..i,lCol) end
    end
end

local function saveCustomWaypoints()
    pcall(function()
        if not writefile then return end
        local data={right={},left={}}
        for i=1,4 do
            if customRight[i] then data.right[i]={customRight[i].X,customRight[i].Y,customRight[i].Z} end
            if customLeft[i]  then data.left[i] ={customLeft[i].X, customLeft[i].Y, customLeft[i].Z}  end
        end
        writefile("WsDuels_waypoints.json",game:GetService("HttpService"):JSONEncode(data))
    end)
end

local function loadCustomWaypoints()
    pcall(function()
        if not readfile or not isfile or not isfile("WsDuels_waypoints.json") then return end
        local raw=readfile("WsDuels_waypoints.json")
        if not raw or raw=="" then return end
        local data=game:GetService("HttpService"):JSONDecode(raw)
        for i=1,4 do
            if data.right and data.right[i] then
                local v=data.right[i]; customRight[i]=Vector3.new(v[1],v[2],v[3])
            end
            if data.left and data.left[i] then
                local v=data.left[i]; customLeft[i]=Vector3.new(v[1],v[2],v[3])
            end
        end
        updatePatrolWaypoints()
    end)
end
loadCustomWaypoints()

-- ============================================================
--  TWEEN
-- ============================================================
local function Tw(obj,t,props,style,dir)
    style = style or Enum.EasingStyle.Quint
    dir   = dir   or Enum.EasingDirection.Out
    pcall(function() TweenService:Create(obj,TweenInfo.new(t,style,dir),props):Play() end)
end

-- ============================================================
--  LOGIC HELPERS
-- ============================================================
local function GetChar()  return player.Character end
local function GetHum()   local c=GetChar(); return c and c:FindFirstChildOfClass("Humanoid") end
local function GetRoot()  local c=GetChar(); return c and (c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("UpperTorso")) end

-- ============================================================
--  DISCORD LABEL ABOVE PLAYER
-- ============================================================
local function CreateDiscordLabel()
    local char = player.Character or player.CharacterAdded:Wait()
    local head = char:WaitForChild("Head", 5)
    if not head then return end

    local existing = head:FindFirstChild("DiscordBillboard")
    if existing then existing:Destroy() end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "DiscordBillboard"
    billboard.Size = UDim2.new(0, 400, 0, 80)
    billboard.StudsOffset = Vector3.new(0, 2.0, 0)
    billboard.AlwaysOnTop = false
    billboard.ResetOnSpawn = false
    billboard.Parent = head

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, 0, 0.5, 0)
    titleLabel.Position = UDim2.new(0, 0, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "WS Duels"
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.TextTransparency = 0.45
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 28
    titleLabel.TextXAlignment = Enum.TextXAlignment.Center
    titleLabel.TextScaled = false
    titleLabel.Parent = billboard

    local dcLabel = Instance.new("TextLabel")
    dcLabel.Size = UDim2.new(1, 0, 0.5, 0)
    dcLabel.Position = UDim2.new(0, 0, 0.5, 0)
    dcLabel.BackgroundTransparency = 1
    dcLabel.Text = "discord.gg/PqnZjmgg6"
    dcLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    dcLabel.TextTransparency = 0.45
    dcLabel.Font = Enum.Font.GothamBold
    dcLabel.TextSize = 24
    dcLabel.TextXAlignment = Enum.TextXAlignment.Center
    dcLabel.TextScaled = false
    dcLabel.Parent = billboard
end

CreateDiscordLabel()
player.CharacterAdded:Connect(function()
    task.wait(1)
    CreateDiscordLabel()
end)

-- ============================================================
--  SPIN BOT / STEAL SPEED / ANTI RAGDOLL / UNWALK / ANTI FLING / INF JUMP
-- ============================================================
local function setupSpinBot()
    local hrp=GetRoot(); if not hrp then return end
    if spinAlign then pcall(function() spinAlign:Destroy() end) end
    if spinAttachment then pcall(function() spinAttachment:Destroy() end) end
    spinAttachment=Instance.new("Attachment"); spinAttachment.Parent=hrp
    spinAlign=Instance.new("AlignOrientation")
    spinAlign.Attachment0=spinAttachment
    spinAlign.Mode=Enum.OrientationAlignmentMode.OneAttachment
    spinAlign.Responsiveness=30; spinAlign.MaxTorque=math.huge
    spinAlign.RigidityEnabled=false; spinAlign.Enabled=false; spinAlign.Parent=hrp
end
local function startSpinBot()
    setupSpinBot(); if spinAlign then spinAlign.Enabled=true end
    if spinConn then spinConn:Disconnect() end
    spinConn=RunService.Heartbeat:Connect(function(dt)
        if not spinActive then return end
        if not spinAlign or not spinAlign.Parent then setupSpinBot(); if spinAlign then spinAlign.Enabled=true end return end
        spinAngle=spinAngle+spinSpeed*dt; spinAlign.CFrame=CFrame.Angles(0,spinAngle,0)
    end)
end
local function stopSpinBot()
    spinActive=false
    if spinConn then spinConn:Disconnect(); spinConn=nil end
    if spinAlign then pcall(function() spinAlign.Enabled=false end) end
end
local function startStealSpeed()
    if stealSpeedConn then stealSpeedConn:Disconnect() end
    stealSpeedConn=RunService.Heartbeat:Connect(function()
        if not stealSpeedActive then return end
        local hum=GetHum(); local root=GetRoot(); if not hum or not root then return end
        if hum.MoveDirection.Magnitude>0.1 then
            local md=hum.MoveDirection.Unit
            root.AssemblyLinearVelocity=Vector3.new(md.X*STEAL_SPEED_VALUE,root.AssemblyLinearVelocity.Y,md.Z*STEAL_SPEED_VALUE)
        end
    end)
end
local function stopStealSpeed() if stealSpeedConn then stealSpeedConn:Disconnect(); stealSpeedConn=nil end end
local function startAntiRagdoll()
    if antiRagdollConn then antiRagdollConn:Disconnect() end
    antiRagdollConn=RunService.Heartbeat:Connect(function()
        if not antiRagdollActive then return end
        local c=GetChar(); if not c then return end
        local root=c:FindFirstChild("HumanoidRootPart")
        local hum=c:FindFirstChildOfClass("Humanoid")
        if hum then
            local s=hum:GetState()
            if s==Enum.HumanoidStateType.Physics or s==Enum.HumanoidStateType.Ragdoll or s==Enum.HumanoidStateType.FallingDown then
                hum:ChangeState(Enum.HumanoidStateType.Running)
                if workspace.CurrentCamera then workspace.CurrentCamera.CameraSubject=hum end
                pcall(function()
                    local pm=player.PlayerScripts:FindFirstChild("PlayerModule")
                    if pm then require(pm:FindFirstChild("ControlModule")):Enable() end
                end)
                if root then root.Velocity=Vector3.zero; root.RotVelocity=Vector3.zero end
            end
        end
        for _,obj in ipairs(c:GetDescendants()) do
            if obj:IsA("Motor6D") and not obj.Enabled then obj.Enabled=true end
        end
    end)
end
local function stopAntiRagdoll() if antiRagdollConn then antiRagdollConn:Disconnect(); antiRagdollConn=nil end end
local function startUnwalk()
    if unwalkConn then unwalkConn:Disconnect(); unwalkConn=nil end
    -- Immediately stop all current tracks
    local hum=GetHum()
    if hum then
        local anim=hum:FindFirstChildOfClass("Animator")
        if anim then for _,t in pairs(anim:GetPlayingAnimationTracks()) do pcall(function() t:Stop(0) end) end end
    end
    -- Keep stopping any that sneak back while active
    unwalkConn=RunService.Heartbeat:Connect(function()
        if not unwalkActive then return end
        local h=GetHum(); if not h then return end
        local a=h:FindFirstChildOfClass("Animator"); if not a then return end
        for _,t in pairs(a:GetPlayingAnimationTracks()) do pcall(function() t:Stop(0) end) end
    end)
end
local function stopUnwalk()
    if unwalkConn then unwalkConn:Disconnect(); unwalkConn=nil end
    -- Resume animations by re-loading the Animate script
    pcall(function()
        local c=GetChar(); if not c then return end
        local hum=c:FindFirstChildOfClass("Humanoid"); if not hum then return end
        -- Force humanoid to re-evaluate its idle animation by briefly poking it
        local existingAnimate=c:FindFirstChild("Animate")
        if existingAnimate then
            existingAnimate.Disabled=true
            task.wait()
            existingAnimate.Disabled=false
        end
    end)
end
local function startAntiFling()
    if antiFlingConn then antiFlingConn:Disconnect() end
    antiFlingConn=RunService.Heartbeat:Connect(function()
        if not antiFlingActive then return end
        local root=GetRoot(); if not root then return end
        local vel=root.AssemblyLinearVelocity
        if vel.Magnitude>100 then root.AssemblyLinearVelocity=vel.Unit*100 end
    end)
end
local function stopAntiFling() if antiFlingConn then antiFlingConn:Disconnect(); antiFlingConn=nil end end

-- ============================================================
--  OPTIMIZER  (from AntiLooser Duels)
-- ============================================================
local optimizerActive    = false
local xrayOrigTrans      = {}
local xrayEnabled        = false
local function enableOptimizer()
    if getgenv and getgenv().OPTIMIZER_ACTIVE then return end
    if getgenv then getgenv().OPTIMIZER_ACTIVE=true end
    optimizerActive=true

    -- Graphics quality to minimum
    pcall(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        settings().Rendering.EagerBulkExecution = true
    end)

    -- Lighting: no shadows, no fog, no atmosphere
    pcall(function()
        local L = game:GetService("Lighting")
        L.GlobalShadows   = false
        L.FogEnd          = 9e9
        L.FogStart        = 9e9
        L.Brightness      = 2
        L.Ambient         = Color3.fromRGB(178,178,178)
        L.OutdoorAmbient  = Color3.fromRGB(178,178,178)
        for _,obj in ipairs(L:GetChildren()) do
            if obj:IsA("Atmosphere") or obj:IsA("Sky") or obj:IsA("BloomEffect")
            or obj:IsA("BlurEffect") or obj:IsA("ColorCorrectionEffect")
            or obj:IsA("SunRaysEffect") or obj:IsA("DepthOfFieldEffect") then
                pcall(function() obj:Destroy() end)
            end
        end
    end)

    -- Workspace: no wind, no terrain decorations
    pcall(function()
        workspace.StreamingEnabled = false
        workspace:FindFirstChildOfClass("Terrain").WaterWaveSize    = 0
        workspace:FindFirstChildOfClass("Terrain").WaterWaveSpeed   = 0
        workspace:FindFirstChildOfClass("Terrain").Decoration       = false
    end)

    -- Remove all visual effects and simplify parts
    pcall(function()
        for _,obj in ipairs(workspace:GetDescendants()) do
            pcall(function()
                if obj:IsA("ParticleEmitter") or obj:IsA("Trail")
                or obj:IsA("Beam")           or obj:IsA("Fire")
                or obj:IsA("Smoke")          or obj:IsA("Sparkles")
                or obj:IsA("Explosion") then
                    obj:Destroy()
                elseif obj:IsA("Decal") or obj:IsA("Texture") then
                    obj:Destroy()
                elseif obj:IsA("SpecialMesh") then
                    -- keep mesh but remove texture
                    obj.TextureId = ""
                elseif obj:IsA("BasePart") then
                    obj.CastShadow  = false
                    obj.Material    = Enum.Material.Plastic
                    obj.Reflectance = 0
                elseif obj:IsA("Sound") then
                    obj.Volume = 0
                elseif obj:IsA("Animation") then
                    pcall(function() obj:Destroy() end)
                end
            end)
        end
    end)

    -- Stop all animations on all characters
    pcall(function()
        for _,p in ipairs(game:GetService("Players"):GetPlayers()) do
            if p.Character then
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                local anim = hum and hum:FindFirstChildOfClass("Animator")
                if anim then
                    for _,t in ipairs(anim:GetPlayingAnimationTracks()) do
                        pcall(function() t:Stop(0) end)
                    end
                end
                -- Disable the Animate script to stop future animations loading
                local animScript = p.Character:FindFirstChild("Animate")
                if animScript then animScript.Enabled = false end
            end
        end
    end)

    -- Mute all sounds in the game
    pcall(function()
        for _,s in ipairs(workspace:GetDescendants()) do
            if s:IsA("Sound") then s.Volume=0 end
        end
        game:GetService("SoundService").AmbientReverb = Enum.ReverbType.NoReverb
        game:GetService("SoundService").Volume = 0
    end)

    -- Disable all ScreenGui blur/effects
    pcall(function()
        for _,gui in ipairs(player.PlayerGui:GetDescendants()) do
            if gui:IsA("BlurEffect") or gui:IsA("DepthOfFieldEffect") then
                gui.Enabled = false
            end
        end
    end)

    -- Reduce workspace physics quality
    pcall(function()
        workspace.StreamingEnabled     = false
        workspace.GlobalWindSpeed      = 0
        workspace.GlobalWindDirection  = Vector3.new(0,0,0)
    end)

    xrayEnabled=true
    pcall(function()
        for _,obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") and obj.Anchored and (obj.Name:lower():find("base") or (obj.Parent and obj.Parent.Name:lower():find("base"))) then
                xrayOrigTrans[obj]=obj.LocalTransparencyModifier; obj.LocalTransparencyModifier=0.85
            end
        end
    end)
end
local function disableOptimizer()
    optimizerActive=false
    if getgenv then getgenv().OPTIMIZER_ACTIVE=false end
    if xrayEnabled then
        for part,v in pairs(xrayOrigTrans) do pcall(function() if part and part.Parent then part.LocalTransparencyModifier=v end end) end
        xrayOrigTrans={}; xrayEnabled=false
    end
end


-- ============================================================
--  INF JUMP FIX
--  Root cause: the Heartbeat loop was calling ChangeState(Freefall)
--  on EVERY frame when the humanoid was in FallingDown / Ragdoll.
--  In "Steal a Brainrot" the game uses those states to signal a
--  respawn / death event.  Overriding them every frame prevented
--  the respawn from completing, leaving the character stuck, or
--  caused the game's own respawn timer to fire repeatedly.
--
--  Fix applied:
--  1. Only override FallingDown/Ragdoll once per state transition
--     (tracked with `lastOverrideState`), not on every heartbeat.
--  2. Never set AutoJumpEnabled = false globally; let the game
--     manage it - we only force the jump velocity ourselves.
--  3. Fall-speed clamp raised slightly (-90 -> gives more room)
--     and is only applied when the player is actually in Freefall,
--     not in other states the game may need intact.
-- ============================================================
local infJumpHealthConn = nil
local ssAutoTp          = function()end

local function startInfJump()
    if infJumpConn       then infJumpConn:Disconnect();       infJumpConn=nil       end
    if infJumpFallConn   then infJumpFallConn:Disconnect();   infJumpFallConn=nil   end
    if infJumpHealthConn then infJumpHealthConn:Disconnect(); infJumpHealthConn=nil end

    local jumping = false
    local lastOverrideState = nil
    local FALL_CAP = -40  -- tight cap so velocity never reaches fatal threshold

    -- Death prevention: lock health to max while inf jump is active
    local function attachHealthLock()
        if infJumpHealthConn then pcall(function() infJumpHealthConn:Disconnect() end); infJumpHealthConn=nil end
        local hum = GetHum(); if not hum then return end
        -- Set MaxHealth very high so damage is never fatal
        pcall(function() hum.MaxHealth = math.huge; hum.Health = math.huge end)
        infJumpHealthConn = hum.HealthChanged:Connect(function(hp)
            if not infJumpActive then return end
            pcall(function()
                if hum.MaxHealth ~= math.huge then hum.MaxHealth = math.huge end
                if hp < 100 then hum.Health = math.huge end
            end)
        end)
    end
    attachHealthLock()

    infJumpConn = UIS.JumpRequest:Connect(function()
        if not infJumpActive then return end
        if jumping then return end
        jumping = true
        local root = GetRoot(); local hum = GetHum()
        if not root or not hum then jumping = false; return end
        local vel = root.AssemblyLinearVelocity
        if vel.Y < FALL_CAP then
            root.AssemblyLinearVelocity = Vector3.new(vel.X, FALL_CAP, vel.Z)
            task.wait(0.05)
        end
        root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 50, root.AssemblyLinearVelocity.Z)
        hum:ChangeState(Enum.HumanoidStateType.Jumping)
        task.delay(0.1, function() jumping = false end)
    end)

    infJumpFallConn = RunService.Heartbeat:Connect(function()
        if not infJumpActive then return end
        local root = GetRoot(); local hum = GetHum()
        if not root or not hum then return end

        -- Secondary health restore every frame as extra safety net
        pcall(function()
            if hum.Health > 0 and hum.Health < 50 then
                if hum.MaxHealth ~= math.huge then hum.MaxHealth = math.huge end
                hum.Health = math.huge
            end
        end)

        local state = hum:GetState()
        if state == Enum.HumanoidStateType.Freefall then
            lastOverrideState = nil
            local vel = root.AssemblyLinearVelocity
            if vel.Y < FALL_CAP then
                root.AssemblyLinearVelocity = Vector3.new(vel.X, FALL_CAP, vel.Z)
            end
        elseif state == Enum.HumanoidStateType.FallingDown then
            if lastOverrideState ~= Enum.HumanoidStateType.FallingDown then
                lastOverrideState = Enum.HumanoidStateType.FallingDown
                hum:ChangeState(Enum.HumanoidStateType.Freefall)
            end
        elseif state == Enum.HumanoidStateType.Ragdoll then
            if lastOverrideState ~= Enum.HumanoidStateType.Ragdoll then
                lastOverrideState = Enum.HumanoidStateType.Ragdoll
                hum:ChangeState(Enum.HumanoidStateType.Freefall)
            end
        else
            lastOverrideState = nil
        end
    end)
end

local function stopInfJump()
    if infJumpConn       then infJumpConn:Disconnect();       infJumpConn=nil       end
    if infJumpFallConn   then infJumpFallConn:Disconnect();   infJumpFallConn=nil   end
    if infJumpHealthConn then infJumpHealthConn:Disconnect(); infJumpHealthConn=nil end
    local hum = GetHum()
    if hum then
        hum.AutoJumpEnabled = true
        pcall(function() hum.MaxHealth = 100; hum.Health = 100 end)
    end
end

local function getPromptPos(prompt)
    local p=prompt.Parent
    if p:IsA("BasePart") then return p.Position
    elseif p:IsA("Model") then local pp=p.PrimaryPart or p:FindFirstChildWhichIsA("BasePart"); return pp and pp.Position
    elseif p:IsA("Attachment") then return p.WorldPosition
    else local part=p:FindFirstChildWhichIsA("BasePart",true); return part and part.Position end
end

local function firePrompt(prompt)
    if not prompt then return end
    task.spawn(function()
        pcall(function() fireproximityprompt(prompt,10000); prompt:InputHoldBegin(); task.wait(0.05); prompt:InputHoldEnd() end)
    end)
end

local function startAutoGrab()
    if autoGrabConn then pcall(task.cancel, autoGrabConn); autoGrabConn=nil end
    autoGrabConn = task.spawn(function()
        while autoGrabActive do
            pcall(function()
                local root = GetRoot()
                if root then
                    local myPos = root.Position
                    for _, obj in ipairs(workspace:GetDescendants()) do
                        if obj:IsA("ProximityPrompt") and obj.Enabled then
                            local at = obj.ActionText:lower()
                            if at == "grab" or at == "pick up" or at == "collect" or at == "take" then
                                local pos = getPromptPos(obj)
                                if pos and (myPos - pos).Magnitude <= AUTO_GRAB_RADIUS then
                                    firePrompt(obj)
                                end
                            end
                        end
                    end
                end
            end)
            task.wait(AUTO_GRAB_DELAY)
        end
    end)
end
local function stopAutoGrab()
    autoGrabActive = false
    if autoGrabConn then pcall(task.cancel, autoGrabConn); autoGrabConn = nil end
end

local function findNearestSteal()
    local root=GetRoot(); if not root then return nil end
    local plots=workspace:FindFirstChild("Plots"); if not plots then return nil end
    local myPos=root.Position; local np,nd=nil,math.huge
    for _,plot in ipairs(plots:GetChildren()) do
        for _,obj in ipairs(plot:GetDescendants()) do
            if obj:IsA("ProximityPrompt") and obj.Enabled and obj.ActionText=="Steal" then
                local pos=getPromptPos(obj)
                if pos then local d=(myPos-pos).Magnitude; if d<=obj.MaxActivationDistance and d<nd then np=obj;nd=d end end
            end
        end
    end
    return np
end
local function findClosestStealAny()
    local root=GetRoot(); if not root then return nil,math.huge,10 end
    local plots=workspace:FindFirstChild("Plots"); if not plots then return nil,math.huge,10 end
    local myPos=root.Position; local np,nd,mad=nil,math.huge,10
    for _,plot in ipairs(plots:GetChildren()) do
        for _,obj in ipairs(plot:GetDescendants()) do
            if obj:IsA("ProximityPrompt") and obj.Enabled and obj.ActionText=="Steal" then
                local pos=getPromptPos(obj)
                if pos then local d=(myPos-pos).Magnitude; if d<nd then np=obj;nd=d;mad=obj.MaxActivationDistance end end
            end
        end
    end
    return np,nd,mad
end

-- DROP  (Eclipse Duels walk-fling method)
local _wfConns={} local _wfActive=false
local function startWalkFling()
    _wfActive=true
    table.insert(_wfConns,RunService.Stepped:Connect(function()
        if not _wfActive then return end
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=player and p.Character then
                for _,part in ipairs(p.Character:GetChildren()) do
                    if part:IsA("BasePart") then part.CanCollide=false end
                end
            end
        end
    end))
    local co=coroutine.create(function()
        while _wfActive do
            RunService.Heartbeat:Wait()
            local c=player.Character
            local root=c and c:FindFirstChild("HumanoidRootPart")
            if not root then RunService.Heartbeat:Wait() continue end
            local vel=root.Velocity
            root.Velocity=vel*10000+Vector3.new(0,10000,0)
            RunService.RenderStepped:Wait()
            if root and root.Parent then root.Velocity=vel end
            RunService.Stepped:Wait()
            if root and root.Parent then root.Velocity=vel+Vector3.new(0,0.1,0) end
        end
    end)
    coroutine.resume(co) table.insert(_wfConns,co)
end
local function stopWalkFling()
    _wfActive=false
    for _,c in ipairs(_wfConns) do
        if typeof(c)=="RBXScriptConnection" then c:Disconnect()
        elseif typeof(c)=="thread" then pcall(task.cancel,c) end
    end
    _wfConns={}
end
local function doDrop() startWalkFling() task.delay(0.4,stopWalkFling) end

local function findBat()
    local c=GetChar(); if not c then return end
    local bp=player:FindFirstChildOfClass("Backpack")
    for _,ch in ipairs(c:GetChildren()) do if ch:IsA("Tool") and ch.Name:lower():find("bat") then return ch end end
    if bp then for _,ch in ipairs(bp:GetChildren()) do if ch:IsA("Tool") and ch.Name:lower():find("bat") then return ch end end end
    for _,i in ipairs(SlapList) do local t=c:FindFirstChild(i[2]) or (bp and bp:FindFirstChild(i[2])); if t then return t end end
end
local function findNearestEnemy(myHRP)
    local nearest,nearestDist,nearestTorso=nil,math.huge,nil
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=player and p.Character then
            local eh=p.Character:FindFirstChild("HumanoidRootPart")
            local torso=p.Character:FindFirstChild("UpperTorso") or p.Character:FindFirstChild("Torso")
            local hum=p.Character:FindFirstChildOfClass("Humanoid")
            if eh and hum and hum.Health>0 then
                local d=(eh.Position-myHRP.Position).Magnitude
                if d<nearestDist and d<=AimbotRadius then nearestDist=d;nearest=eh;nearestTorso=torso or eh end
            end
        end
    end
    return nearest,nearestDist,nearestTorso
end
-- ============================================================
--  BAT AIMBOT  (Rick's Duel by Prince - exact)
-- ============================================================
local function findNearestEnemy(myHRP)
    local nearest, nearestDist, nearestTorso = nil, math.huge, nil
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=player and p.Character then
            local eh    = p.Character:FindFirstChild("HumanoidRootPart")
            local torso = p.Character:FindFirstChild("UpperTorso") or p.Character:FindFirstChild("Torso")
            local hum   = p.Character:FindFirstChildOfClass("Humanoid")
            if eh and hum and hum.Health>0 then
                local d=(eh.Position-myHRP.Position).Magnitude
                if d<nearestDist then
                    nearestDist=d; nearest=eh; nearestTorso=torso or eh
                end
            end
        end
    end
    return nearest, nearestDist, nearestTorso
end

local function startBatAimbot()
    if batAimbotConn then return end
    batAimbotConn=RunService.Heartbeat:Connect(function()
        if not batAimbotActive then return end
        local c=GetChar(); if not c then return end
        local h  =c:FindFirstChild("HumanoidRootPart")
        local hum=c:FindFirstChildOfClass("Humanoid")
        if not h or not hum then return end
        local bat=findBat()
        if bat and bat.Parent~=c then
            pcall(function() hum:EquipTool(bat) end)
        end
        local target,_,torso=findNearestEnemy(h)
        if target and torso then
            local dir     =torso.Position-h.Position
            local flatDir =Vector3.new(dir.X,0,dir.Z)
            local flatDist=flatDir.Magnitude
            local spd     =BatAimbotSpeed
            if flatDist>1.5 then
                local moveDir=flatDir.Unit
                h.AssemblyLinearVelocity=Vector3.new(moveDir.X*spd,h.AssemblyLinearVelocity.Y,moveDir.Z*spd)
            else
                local tv=target.AssemblyLinearVelocity
                h.AssemblyLinearVelocity=Vector3.new(tv.X,h.AssemblyLinearVelocity.Y,tv.Z)
            end
        end
    end)
end

local function stopBatAimbot()
    if batAimbotConn then batAimbotConn:Disconnect(); batAimbotConn=nil end
end

local function isCountdownNum(text) local n=tonumber(text); return n and n>=1 and n<=5, n end
local function isTimerCountdown(label)
    if not label then return false end
    local ok,n=isCountdownNum(label.Text); return ok and n>=1 and n<=5
end
-- ============================================================
--  MODULE-LEVEL startPatrol / stopPatrol  (original waypoint system)
-- ============================================================
local function getCurrentSpeed()
    if patrolMode=="right" then return (currentWaypoint>=3) and 29.4 or patrolRightSpeed
    elseif patrolMode=="left" then return (currentWaypoint>=3) and 29.4 or patrolLeftSpeed end
    return 0
end
local function getCurrentWaypoints()
    if patrolMode=="right" then return getEffectiveWaypoints("right")
    elseif patrolMode=="left" then return getEffectiveWaypoints("left") end
    return {}
end

local function updateWalking()
    local root=GetRoot(); if not root then return end
    local vel=root.AssemblyLinearVelocity
    if floating then
        local rp=RaycastParams.new(); rp.FilterType=Enum.RaycastFilterType.Blacklist
        rp.FilterDescendantsInstances={GetChar()}
        local res=workspace:Raycast(root.Position,Vector3.new(0,-50,0),rp)
        if res then
            local diff=(res.Position.Y+8)-root.Position.Y
            if math.abs(diff)>0.3 then root.AssemblyLinearVelocity=Vector3.new(vel.X,diff*15,vel.Z)
            else root.AssemblyLinearVelocity=Vector3.new(vel.X,0,vel.Z) end
        end
    end
end

local _bARref, _bALref   = nil, nil
local patrolDedicatedConn = nil  -- separate from heartbeatConn so rebuilds can't kill it

local function startPatrolDedicated()
    if patrolDedicatedConn then patrolDedicatedConn:Disconnect(); patrolDedicatedConn=nil end
    patrolDedicatedConn = RunService.Heartbeat:Connect(function()
        if patrolMode=="none" then return end
        local root=GetRoot(); if not root then return end
        local wp=getCurrentWaypoints()
        if #wp==0 then return end
        local tgt=wp[currentWaypoint]
        local tXZ=Vector3.new(tgt.X,0,tgt.Z)
        local cXZ=Vector3.new(root.Position.X,0,root.Position.Z)
        local dXZ=(tXZ-cXZ).Magnitude
        if dXZ>3 then
            local md=(tXZ-cXZ).Unit
            local spd=getCurrentSpeed()
            root.AssemblyLinearVelocity=Vector3.new(md.X*spd,root.AssemblyLinearVelocity.Y,md.Z*spd)
        else
            if currentWaypoint==#wp then
                currentWaypoint=1
                root.AssemblyLinearVelocity=Vector3.new(0,root.AssemblyLinearVelocity.Y,0)
            else
                currentWaypoint=currentWaypoint+1
            end
        end
    end)
end

startPatrol = function(mode)
    patrolMode=mode; currentWaypoint=1
    if mode=="right" then
        pcall(ssAR,true); FeatureStates.autoR=true
        if _bARref then local l=_bARref:FindFirstChild("Label"); if l then l.Text="Auto Right" end end
    else
        pcall(ssAL,true); FeatureStates.autoL=true
        if _bALref then local l=_bALref:FindFirstChild("Label"); if l then l.Text="Auto Left" end end
    end
    startPatrolDedicated()
end
stopPatrol = function()
    patrolMode="none"; currentWaypoint=1; waitingForCountdownL=false; waitingForCountdownR=false
    if patrolDedicatedConn then patrolDedicatedConn:Disconnect(); patrolDedicatedConn=nil end
    pcall(ssAR,false); pcall(ssAL,false)
    FeatureStates.autoR=false; FeatureStates.autoL=false
    if _bARref then local l=_bARref:FindFirstChild("Label"); if l then l.Text="Auto Right" end end
    if _bALref then local l=_bALref:FindFirstChild("Label"); if l then l.Text="Auto Left"  end end
    local root=GetRoot(); if root then root.AssemblyLinearVelocity=Vector3.new(0,root.AssemblyLinearVelocity.Y,0) end
end

-- ============================================================
--  MODULE-LEVEL startStealLoop / stopStealLoop
-- ============================================================
local function indicateGrab()
    isSt=true; isStealing=true
    if SBStatus then SBStatus.Text="GRAB!"; SBStatus.TextColor3=T.ac0 end
    if sbDots then for _,d in ipairs(sbDots) do d.BackgroundColor3=T.ac0; d.BackgroundTransparency=0 end end
    if SBFill then Tw(SBFill,0.1,{Size=UDim2.new(1,0,1,0)}) end
    task.delay(0.25,function() isSt=false; isStealing=false end)
end

local function stealLoopFn()
    while stealActive do
        local hum=GetHum()
        if hum and hum.WalkSpeed>=STEAL_SPD then
            local prompt=findNearestSteal()
            if prompt then
                local pos=getPromptPos(prompt); local root=GetRoot()
                local dist=root and pos and (root.Position-pos).Magnitude or math.huge
                if dist<=STEAL_DST then task.wait(0.1); firePrompt(prompt); indicateGrab() end
            end
        end
        task.wait(0.3)
    end
    stealLoopRunning=false
end

startStealLoop = function()
    if stealLoopRunning then return end
    stealLoopRunning=true; stealThread=task.spawn(stealLoopFn)
end
stopStealLoop = function()
    stealLoopRunning=false
    if stealThread then task.cancel(stealThread); stealThread=nil end
    if stealConn then stealConn:Disconnect(); stealConn=nil end
    isStealing=false; isSt=false
end

-- ============================================================
--  DRAG
-- ============================================================
local function MakeDraggable(frame, handle)
    handle = handle or frame
    local dragging, dragStart, startPos, lastInput
    local DragThreshold = 6
    handle.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            dragging=false; dragStart=i.Position; startPos=frame.Position
        end
    end)
    handle.InputChanged:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch then
            lastInput=i
            if dragStart and not dragging then
                local d=i.Position-dragStart
                if math.abs(d.X)>DragThreshold or math.abs(d.Y)>DragThreshold then dragging=true end
            end
            if dragging and lastInput then
                local d=lastInput.Position-dragStart
                frame.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
            end
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if dragging and lastInput and i==lastInput then
            local d=i.Position-dragStart
            frame.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
        end
    end)
    handle.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            dragging=false; dragStart=nil
        end
    end)
end

-- ============================================================
--  DOTS BACKGROUND
-- ============================================================
local function MakeDotsBackground(parent)
    local canvas=Instance.new("Frame",parent)
    canvas.Size=UDim2.new(1,0,1,0); canvas.BackgroundTransparency=1
    canvas.ZIndex=0; canvas.Name="DotsCanvas"; canvas.ClipsDescendants=true; canvas.Interactable=false
    local DOT_COUNT = isMobile and 14 or 22
    local dots={}
    for i=1,DOT_COUNT do
        local sz=math.random(2,5)
        local dot=Instance.new("Frame",canvas)
        dot.Size=UDim2.new(0,sz,0,sz)
        dot.Position=UDim2.new(math.random(0,100)/100,0,math.random(0,100)/100,0)
        dot.BackgroundColor3=(math.random()>0.5) and T.dot or T.dotBright
        dot.BackgroundTransparency=math.random(40,75)/100
        dot.BorderSizePixel=0; dot.Interactable=false
        Instance.new("UICorner",dot).CornerRadius=UDim.new(1,0)
        local dirX=(math.random()-0.5)*0.0018; local dirY=(math.random()-0.5)*0.0018
        local phase=math.random(0,628)/100; local pulseS=math.random(7,15)/10
        table.insert(dots,{frame=dot,dirX=dirX,dirY=dirY,phase=phase,pulseS=pulseS,px=dot.Position.X.Scale,py=dot.Position.Y.Scale})
    end
    local t=0
    local conn=RunService.Heartbeat:Connect(function(dt)
        if not canvas.Parent then return end
        t=t+dt
        for _,d in ipairs(dots) do
            d.px=d.px+d.dirX*dt*6; d.py=d.py+d.dirY*dt*6
            if d.px>1.05 then d.px=-0.05 elseif d.px<-0.05 then d.px=1.05 end
            if d.py>1.05 then d.py=-0.05 elseif d.py<-0.05 then d.py=1.05 end
            local pulse=0.5+0.4*math.sin(t*d.pulseS+d.phase)
            d.frame.Position=UDim2.new(d.px,0,d.py,0)
            d.frame.BackgroundTransparency=0.15+pulse*0.7
        end
    end)
    canvas.AncestryChanged:Connect(function() if not canvas.Parent then pcall(function() conn:Disconnect() end) end end)
    table.insert(registeredDotSets,dots)
    return canvas,dots
end


-- ============================================================
--  AUTO TP  (teleports player down when Y >= yValue threshold)
-- ============================================================
local AUTO_TP_Y_VALUE = -20  -- teleport when Y >= abs of this

local function startAutoTpDown()
    if autoTpDownConn then autoTpDownConn:Disconnect(); autoTpDownConn=nil end
    autoTpDownConn = task.spawn(function()
        while autoTpDownActive do
            task.wait(0.1)
            local root = GetRoot()
            if root and root.Parent then
                if root.Position.Y >= math.abs(AUTO_TP_Y_VALUE) then
                    root.CFrame = CFrame.new(root.Position.X, -8.80, root.Position.Z)
                end
            end
        end
    end)
end

local function stopAutoTpDown()
    autoTpDownActive = false
    if autoTpDownConn then pcall(task.cancel, autoTpDownConn); autoTpDownConn = nil end
end

local function doJumpTpDown() end
local function startJumpTpDown() end
local function stopJumpTpDown() end


-- ============================================================
--  BuildMainGUI forward declaration
-- ============================================================
local BuildMainGUI

-- ============================================================
--  APPLY THEME
-- ============================================================
local function ApplyTheme(name)
    T = Themes[name]; currentThemeName = name
    SaveConfig()
    task.spawn(function()
        task.wait(0.08)
        if heartbeatConn    then heartbeatConn:Disconnect();    heartbeatConn=nil    end
        if statusBarConn    then statusBarConn:Disconnect();    statusBarConn=nil    end
        if globalKeybindConn then globalKeybindConn:Disconnect(); globalKeybindConn=nil end
        pcall(function() ParentUI:FindFirstChild("WsDuels"):Destroy() end)
        BuildMainGUI()
    end)
end

-- ============================================================
--  UI BUILDERS
-- ============================================================
local function MakeSectionLabel(parent,text)
    local wrap=Instance.new("Frame",parent)
    wrap.Size=UDim2.new(1,0,0,S(18)); wrap.BackgroundTransparency=1
    local lbl=Instance.new("TextLabel",wrap)
    lbl.Size=UDim2.new(1,-8,1,0); lbl.Position=UDim2.new(0,4,0,0)
    lbl.BackgroundTransparency=1; lbl.Text="** "..text
    lbl.Font=Enum.Font.GothamBold; lbl.TextSize=S(isMobile and 8 or 9)
    lbl.TextColor3=T.ac1; lbl.TextXAlignment=Enum.TextXAlignment.Left
    local line=Instance.new("Frame",wrap)
    line.Size=UDim2.new(1,0,0,1); line.Position=UDim2.new(0,0,1,-1)
    line.BackgroundColor3=T.ac3; line.BackgroundTransparency=0.1; line.BorderSizePixel=0
    Instance.new("UICorner",line).CornerRadius=UDim.new(1,0)
    return wrap
end

local function MakeToggle(parent,labelText,featureId)
    local BTN_H=S(isMobile and 36 or 42); local FS=S(isMobile and 10 or 11)
    local card=Instance.new("TextButton",parent)
    card.Size=UDim2.new(1,0,0,BTN_H); card.BackgroundColor3=T.bg0; card.Text=""; card.BorderSizePixel=0; card.AutoButtonColor=false
    Instance.new("UICorner",card).CornerRadius=UDim.new(0,S(10))
    local stroke=Instance.new("UIStroke",card); stroke.Color=T.borderDim; stroke.Thickness=1; stroke.Transparency=0.35
    local acBar=Instance.new("Frame",card)
    acBar.Size=UDim2.new(0,S(3),0,BTN_H-S(12)); acBar.Position=UDim2.new(0,0,0,S(6))
    acBar.BackgroundColor3=T.ac0; acBar.BackgroundTransparency=1; acBar.BorderSizePixel=0
    Instance.new("UICorner",acBar).CornerRadius=UDim.new(1,0)
    local trackW=Instance.new("Frame",card)
    trackW.Size=UDim2.new(0,S(30),0,S(16)); trackW.Position=UDim2.new(1,-S(38),0.5,-S(8))
    trackW.BackgroundColor3=T.bg3; trackW.BorderSizePixel=0
    Instance.new("UICorner",trackW).CornerRadius=UDim.new(1,0)
    local trackS=Instance.new("UIStroke",trackW); trackS.Color=T.borderDim; trackS.Thickness=1; trackS.Transparency=0.4
    local thumb=Instance.new("Frame",trackW)
    thumb.Size=UDim2.new(0,S(10),0,S(10)); thumb.Position=UDim2.new(0,S(3),0.5,-S(5))
    thumb.BackgroundColor3=inactive; thumb.BorderSizePixel=0
    Instance.new("UICorner",thumb).CornerRadius=UDim.new(1,0)
    local dot=Instance.new("Frame",card)
    dot.Size=UDim2.new(0,S(4),0,S(4)); dot.Position=UDim2.new(0,S(10),0.5,-S(2))
    dot.BackgroundColor3=inactive; dot.BackgroundTransparency=0.5; dot.BorderSizePixel=0
    Instance.new("UICorner",dot).CornerRadius=UDim.new(1,0)
    local kbBadge=Instance.new("TextLabel",card)
    kbBadge.Size=UDim2.new(0,S(32),0,S(13)); kbBadge.Position=UDim2.new(1,-S(74),0.5,-S(7))
    kbBadge.BackgroundColor3=T.bg3; kbBadge.Text=""; kbBadge.Font=Enum.Font.GothamBold
    kbBadge.TextSize=S(7); kbBadge.TextColor3=T.ac1; kbBadge.BackgroundTransparency=1
    kbBadge.BorderSizePixel=0; kbBadge.Visible=false
    Instance.new("UICorner",kbBadge).CornerRadius=UDim.new(0,3)
    Instance.new("UIStroke",kbBadge).Color=T.borderDim
    local lbl=Instance.new("TextLabel",card)
    lbl.Name="Label"; lbl.Size=UDim2.new(1,-S(54),1,0); lbl.Position=UDim2.new(0,S(18),0,0)
    lbl.BackgroundTransparency=1; lbl.Text=labelText; lbl.Font=Enum.Font.GothamBold
    lbl.TextSize=FS; lbl.TextColor3=txtSub; lbl.TextXAlignment=Enum.TextXAlignment.Left
    card.MouseEnter:Connect(function() Tw(card,0.12,{BackgroundColor3=T.bg1}); Tw(stroke,0.12,{Transparency=0.05,Color=T.ac2}) end)
    card.MouseLeave:Connect(function() Tw(card,0.15,{BackgroundColor3=T.bg0}); Tw(stroke,0.15,{Transparency=0.35,Color=T.borderDim}) end)
    local function updateKbBadge()
        if featureId and FeatureKeybinds[featureId] then
            kbBadge.Text=FeatureKeybinds[featureId].Name; kbBadge.BackgroundTransparency=0.3; kbBadge.Visible=true
            lbl.Size=UDim2.new(1,-S(90),1,0)
        else
            kbBadge.Visible=false; kbBadge.BackgroundTransparency=1; lbl.Size=UDim2.new(1,-S(54),1,0)
        end
    end
    updateKbBadge()
    local function SetState(on)
        Tw(acBar,0.2,{BackgroundTransparency=on and 0 or 1})
        Tw(trackW,0.2,{BackgroundColor3=on and T.ac3 or T.bg3})
        Tw(trackS,0.2,{Color=on and T.ac1 or T.borderDim,Transparency=on and 0.1 or 0.4})
        Tw(thumb,0.2,{Position=on and UDim2.new(0,S(17),0.5,-S(5)) or UDim2.new(0,S(3),0.5,-S(5)),BackgroundColor3=on and T.ac0 or inactive})
        Tw(dot,0.2,{BackgroundColor3=on and T.ac0 or inactive,BackgroundTransparency=on and 0 or 0.5})
        Tw(lbl,0.2,{TextColor3=on and txtPrime or txtSub})
        Tw(card,0.2,{BackgroundColor3=on and T.acOff or T.bg0})
        Tw(stroke,0.2,{Color=on and T.ac2 or T.ac3,Transparency=on and 0.15 or 0.5})
    end
    return card,SetState,lbl,updateKbBadge
end

local function MakeSpeedRow(parent,labelText,defaultSpeed,onChanged)
    local ROW_H=S(isMobile and 34 or 38); local FS=S(isMobile and 9 or 10); local BSIZE=S(isMobile and 20 or 22)
    local row=Instance.new("Frame",parent)
    row.Size=UDim2.new(1,0,0,ROW_H); row.BackgroundColor3=T.bg2; row.BorderSizePixel=0
    Instance.new("UICorner",row).CornerRadius=UDim.new(0,S(9))
    Instance.new("UIStroke",row).Color=T.borderDim
    local acB=Instance.new("Frame",row)
    acB.Size=UDim2.new(0,S(3),0,ROW_H-S(10)); acB.Position=UDim2.new(0,0,0,S(5))
    acB.BackgroundColor3=T.cyan; acB.BackgroundTransparency=0.3; acB.BorderSizePixel=0
    Instance.new("UICorner",acB).CornerRadius=UDim.new(1,0)
    local nameL=Instance.new("TextLabel",row)
    nameL.Size=UDim2.new(0.42,0,1,0); nameL.Position=UDim2.new(0,S(10),0,0)
    nameL.BackgroundTransparency=1; nameL.Text=labelText; nameL.Font=Enum.Font.GothamBold
    nameL.TextSize=FS; nameL.TextColor3=txtSub; nameL.TextXAlignment=Enum.TextXAlignment.Left
    local mBtn=Instance.new("TextButton",row)
    mBtn.Size=UDim2.new(0,BSIZE,0,BSIZE); mBtn.Position=UDim2.new(0.48,0,0.5,-BSIZE/2)
    mBtn.BackgroundColor3=T.bg3; mBtn.Text="-"; mBtn.Font=Enum.Font.GothamBold
    mBtn.TextSize=FS+S(1); mBtn.TextColor3=T.ac1; mBtn.BorderSizePixel=0; mBtn.AutoButtonColor=false
    Instance.new("UICorner",mBtn).CornerRadius=UDim.new(0,S(5)); Instance.new("UIStroke",mBtn).Color=T.borderDim
    local vBox=Instance.new("TextBox",row)
    vBox.Size=UDim2.new(0,S(isMobile and 36 or 40),0,BSIZE); vBox.Position=UDim2.new(0.48,BSIZE+S(3),0.5,-BSIZE/2)
    vBox.BackgroundColor3=T.bg3; vBox.BorderSizePixel=0; vBox.Text=tostring(defaultSpeed)
    vBox.Font=Enum.Font.GothamBold; vBox.TextSize=FS; vBox.TextColor3=T.ac0; vBox.ClearTextOnFocus=false
    Instance.new("UICorner",vBox).CornerRadius=UDim.new(0,S(5)); Instance.new("UIStroke",vBox).Color=T.ac3
    local pBtn=Instance.new("TextButton",row)
    pBtn.Size=UDim2.new(0,BSIZE,0,BSIZE); pBtn.Position=UDim2.new(0.48,BSIZE+S(isMobile and 42 or 46),0.5,-BSIZE/2)
    pBtn.BackgroundColor3=T.bg3; pBtn.Text="+"; pBtn.Font=Enum.Font.GothamBold
    pBtn.TextSize=FS+S(1); pBtn.TextColor3=T.ac1; pBtn.BorderSizePixel=0; pBtn.AutoButtonColor=false
    Instance.new("UICorner",pBtn).CornerRadius=UDim.new(0,S(5)); Instance.new("UIStroke",pBtn).Color=T.borderDim
    for _,btn in ipairs({mBtn,pBtn}) do
        btn.MouseEnter:Connect(function() Tw(btn,0.1,{BackgroundColor3=T.ac3,TextColor3=T.ac0}) end)
        btn.MouseLeave:Connect(function() Tw(btn,0.1,{BackgroundColor3=T.bg3,TextColor3=T.ac1}) end)
    end
    local curVal=defaultSpeed
    local function clamp(v) v=math.clamp(math.floor(v),1,500); curVal=v; vBox.Text=tostring(v); if onChanged then onChanged(v) end end
    mBtn.MouseButton1Click:Connect(function() clamp(curVal-5) end)
    pBtn.MouseButton1Click:Connect(function() clamp(curVal+5) end)
    vBox.FocusLost:Connect(function() local n=tonumber(vBox.Text); if n then clamp(n) else vBox.Text=tostring(curVal) end end)
    return row
end

local function MakeThemePicker(parent)
    local ROW_H=S(isMobile and 38 or 42)
    local wrap=Instance.new("Frame",parent)
    wrap.Size=UDim2.new(1,0,0,ROW_H); wrap.BackgroundColor3=T.bg2; wrap.BorderSizePixel=0
    Instance.new("UICorner",wrap).CornerRadius=UDim.new(0,S(10))
    Instance.new("UIStroke",wrap).Color=T.borderDim
    local acB=Instance.new("Frame",wrap)
    acB.Size=UDim2.new(0,S(3),0,ROW_H-S(10)); acB.Position=UDim2.new(0,0,0,S(5))
    acB.BackgroundColor3=T.ac0; acB.BackgroundTransparency=0.3; acB.BorderSizePixel=0
    Instance.new("UICorner",acB).CornerRadius=UDim.new(1,0)
    local lbl=Instance.new("TextLabel",wrap)
    lbl.Size=UDim2.new(0,S(50),1,0); lbl.Position=UDim2.new(0,S(12),0,0)
    lbl.BackgroundTransparency=1; lbl.Text="THEME"; lbl.Font=Enum.Font.GothamBold
    lbl.TextSize=S(isMobile and 9 or 10); lbl.TextColor3=txtSub; lbl.TextXAlignment=Enum.TextXAlignment.Left
    local themeList={"Blue","Green","Red","Dark"}
    local swatchColors={Blue=Color3.fromRGB(100,180,255),Green=Color3.fromRGB(0,235,145),Red=Color3.fromRGB(255,90,90),Dark=Color3.fromRGB(175,182,205)}
    local SW=S(isMobile and 30 or 36); local SH=S(isMobile and 20 or 24); local startX=S(62); local GAP=S(4)
    for i,name in ipairs(themeList) do
        local sw=Instance.new("TextButton",wrap)
        sw.Size=UDim2.new(0,SW,0,SH); sw.Position=UDim2.new(0,startX+(i-1)*(SW+GAP),0.5,-SH/2)
        sw.BackgroundColor3=swatchColors[name]; sw.BackgroundTransparency=name==currentThemeName and 0.15 or 0.35
        sw.Text=name:sub(1,2); sw.Font=Enum.Font.GothamBlack; sw.TextSize=S(7)
        sw.TextColor3=Color3.fromRGB(255,255,255); sw.BorderSizePixel=0; sw.AutoButtonColor=false
        Instance.new("UICorner",sw).CornerRadius=UDim.new(0,S(6))
        local swS=Instance.new("UIStroke",sw); swS.Color=swatchColors[name]
        swS.Thickness=name==currentThemeName and 2 or 0.5; swS.Transparency=name==currentThemeName and 0 or 0.5
        sw.MouseButton1Click:Connect(function() ApplyTheme(name) end)
        sw.MouseEnter:Connect(function() Tw(sw,0.1,{BackgroundTransparency=0.05}) end)
        sw.MouseLeave:Connect(function() sw.BackgroundTransparency=name==currentThemeName and 0.15 or 0.35 end)
    end
    return wrap
end

local function MakeScaleRow(parent)
    local ROW_H=S(isMobile and 34 or 38); local FS=S(isMobile and 9 or 10); local BSIZE=S(isMobile and 20 or 22)
    local row=Instance.new("Frame",parent)
    row.Size=UDim2.new(1,0,0,ROW_H); row.BackgroundColor3=T.bg2; row.BorderSizePixel=0
    Instance.new("UICorner",row).CornerRadius=UDim.new(0,S(9))
    Instance.new("UIStroke",row).Color=T.borderDim
    local acB=Instance.new("Frame",row)
    acB.Size=UDim2.new(0,S(3),0,ROW_H-S(10)); acB.Position=UDim2.new(0,0,0,S(5))
    acB.BackgroundColor3=T.ac0; acB.BackgroundTransparency=0.4; acB.BorderSizePixel=0
    Instance.new("UICorner",acB).CornerRadius=UDim.new(1,0)
    local nameL=Instance.new("TextLabel",row)
    nameL.Size=UDim2.new(0.38,0,1,0); nameL.Position=UDim2.new(0,S(10),0,0)
    nameL.BackgroundTransparency=1; nameL.Text="GUI SCALE"; nameL.Font=Enum.Font.GothamBold
    nameL.TextSize=FS; nameL.TextColor3=txtSub; nameL.TextXAlignment=Enum.TextXAlignment.Left
    local mBtn=Instance.new("TextButton",row)
    mBtn.Size=UDim2.new(0,BSIZE,0,BSIZE); mBtn.Position=UDim2.new(0.44,0,0.5,-BSIZE/2)
    mBtn.BackgroundColor3=T.bg3; mBtn.Text="-"; mBtn.Font=Enum.Font.GothamBold
    mBtn.TextSize=FS+S(1); mBtn.TextColor3=T.ac1; mBtn.BorderSizePixel=0; mBtn.AutoButtonColor=false
    Instance.new("UICorner",mBtn).CornerRadius=UDim.new(0,S(5)); Instance.new("UIStroke",mBtn).Color=T.borderDim
    local valLbl=Instance.new("TextLabel",row)
    valLbl.Size=UDim2.new(0,S(38),0,BSIZE); valLbl.Position=UDim2.new(0.44,BSIZE+S(3),0.5,-BSIZE/2)
    valLbl.BackgroundColor3=T.bg3; valLbl.BorderSizePixel=0
    valLbl.Text=string.format("%.1f",guiScale); valLbl.Font=Enum.Font.GothamBold
    valLbl.TextSize=FS; valLbl.TextColor3=T.ac0
    Instance.new("UICorner",valLbl).CornerRadius=UDim.new(0,S(5)); Instance.new("UIStroke",valLbl).Color=T.ac3
    local pBtn=Instance.new("TextButton",row)
    pBtn.Size=UDim2.new(0,BSIZE,0,BSIZE); pBtn.Position=UDim2.new(0.44,BSIZE+S(isMobile and 44 or 48),0.5,-BSIZE/2)
    pBtn.BackgroundColor3=T.bg3; pBtn.Text="+"; pBtn.Font=Enum.Font.GothamBold
    pBtn.TextSize=FS+S(1); pBtn.TextColor3=T.ac1; pBtn.BorderSizePixel=0; pBtn.AutoButtonColor=false
    Instance.new("UICorner",pBtn).CornerRadius=UDim.new(0,S(5)); Instance.new("UIStroke",pBtn).Color=T.borderDim
    local applyBtn=Instance.new("TextButton",row)
    applyBtn.Size=UDim2.new(0,S(isMobile and 36 or 44),0,BSIZE)
    applyBtn.Position=UDim2.new(1,-S(isMobile and 40 or 50),0.5,-BSIZE/2)
    applyBtn.BackgroundColor3=T.ac3; applyBtn.Text="APPLY"; applyBtn.Font=Enum.Font.GothamBold
    applyBtn.TextSize=S(7); applyBtn.TextColor3=T.ac0; applyBtn.BorderSizePixel=0; applyBtn.AutoButtonColor=false
    Instance.new("UICorner",applyBtn).CornerRadius=UDim.new(0,S(5)); Instance.new("UIStroke",applyBtn).Color=T.ac2
    for _,btn in ipairs({mBtn,pBtn}) do
        btn.MouseEnter:Connect(function() Tw(btn,0.1,{BackgroundColor3=T.ac3,TextColor3=T.ac0}) end)
        btn.MouseLeave:Connect(function() Tw(btn,0.1,{BackgroundColor3=T.bg3,TextColor3=T.ac1}) end)
    end
    applyBtn.MouseEnter:Connect(function() Tw(applyBtn,0.1,{BackgroundColor3=T.ac2}) end)
    applyBtn.MouseLeave:Connect(function() Tw(applyBtn,0.1,{BackgroundColor3=T.ac3}) end)
    local pendingScale=guiScale
    local function updateVal()
        pendingScale=math.clamp(math.floor(pendingScale*10+0.5)/10,0.5,2.0)
        valLbl.Text=string.format("%.1f",pendingScale)
    end
    mBtn.MouseButton1Click:Connect(function() pendingScale=pendingScale-0.1; updateVal() end)
    pBtn.MouseButton1Click:Connect(function() pendingScale=pendingScale+0.1; updateVal() end)
    applyBtn.MouseButton1Click:Connect(function()
        guiScale=pendingScale
        SaveConfig()
        task.spawn(function()
            task.wait(0.1)
            if heartbeatConn    then heartbeatConn:Disconnect();    heartbeatConn=nil    end
            if statusBarConn    then statusBarConn:Disconnect();    statusBarConn=nil    end
            if globalKeybindConn then globalKeybindConn:Disconnect(); globalKeybindConn=nil end
            pcall(function() ParentUI:FindFirstChild("WsDuels"):Destroy() end)
            BuildMainGUI()
        end)
    end)
    return row
end

-- ============================================================
--  KEYBIND ROW (PC only)
-- ============================================================
local function MakeKeybindRow(parent, featureId, featureLabel)
    local ROW_H=S(34); local FS=S(9)
    local row=Instance.new("Frame",parent)
    row.Size=UDim2.new(1,0,0,ROW_H); row.BackgroundColor3=T.bg2; row.BorderSizePixel=0
    Instance.new("UICorner",row).CornerRadius=UDim.new(0,S(8))
    local rowS=Instance.new("UIStroke",row); rowS.Color=T.borderDim; rowS.Thickness=1; rowS.Transparency=0.5
    local nameLbl=Instance.new("TextLabel",row)
    nameLbl.Size=UDim2.new(0.45,0,1,0); nameLbl.Position=UDim2.new(0,S(8),0,0)
    nameLbl.BackgroundTransparency=1; nameLbl.Text=featureLabel
    nameLbl.Font=Enum.Font.GothamBold; nameLbl.TextSize=FS; nameLbl.TextColor3=txtSub; nameLbl.TextXAlignment=Enum.TextXAlignment.Left
    local keyBtn=Instance.new("TextButton",row)
    keyBtn.Size=UDim2.new(0,S(84),0,ROW_H-S(8)); keyBtn.Position=UDim2.new(0.45,S(4),0.5,-(ROW_H-S(8))/2)
    keyBtn.BackgroundColor3=T.bg3; keyBtn.BorderSizePixel=0
    keyBtn.Font=Enum.Font.GothamBold; keyBtn.TextSize=FS; keyBtn.TextColor3=T.ac1; keyBtn.AutoButtonColor=false
    local kb=FeatureKeybinds[featureId]
    keyBtn.Text=kb and ("["..kb.Name.."]") or "[ None ]"
    Instance.new("UICorner",keyBtn).CornerRadius=UDim.new(0,S(5))
    local keyBtnStroke=Instance.new("UIStroke",keyBtn); keyBtnStroke.Color=T.borderDim
    local clrBtn=Instance.new("TextButton",row)
    clrBtn.Size=UDim2.new(0,S(22),0,ROW_H-S(8)); clrBtn.Position=UDim2.new(1,-S(26),0.5,-(ROW_H-S(8))/2)
    clrBtn.BackgroundColor3=T.bg3; clrBtn.Text="X"; clrBtn.Font=Enum.Font.GothamBold
    clrBtn.TextSize=S(8); clrBtn.TextColor3=T.ac2; clrBtn.BorderSizePixel=0; clrBtn.AutoButtonColor=false
    Instance.new("UICorner",clrBtn).CornerRadius=UDim.new(0,S(5)); Instance.new("UIStroke",clrBtn).Color=T.borderDim
    local binding=false
    keyBtn.MouseButton1Click:Connect(function()
        if binding then return end
        binding=true; keyBtn.Text="[press key...]"; keyBtn.TextColor3=warn
        Tw(row,0.1,{BackgroundColor3=T.bg3}); Tw(rowS,0.1,{Color=T.ac1,Transparency=0.2})
        local c2; c2=UIS.InputBegan:Connect(function(inp,gpe)
            if gpe then return end
            if inp.UserInputType==Enum.UserInputType.Keyboard then
                FeatureKeybinds[featureId]=inp.KeyCode
                keyBtn.Text="["..inp.KeyCode.Name.."]"; keyBtn.TextColor3=T.ac0
                Tw(keyBtn,0.15,{BackgroundColor3=T.acOff}); Tw(keyBtnStroke,0.15,{Color=T.ac1})
                Tw(row,0.15,{BackgroundColor3=T.bg2}); Tw(rowS,0.15,{Color=T.borderDim,Transparency=0.5})
                binding=false; c2:Disconnect()
                if bindCallbacks[featureId] then bindCallbacks[featureId]() end
                SaveConfig()
            end
        end)
    end)
    clrBtn.MouseButton1Click:Connect(function()
        FeatureKeybinds[featureId]=nil; keyBtn.Text="[ None ]"; keyBtn.TextColor3=T.ac1
        Tw(keyBtn,0.15,{BackgroundColor3=T.bg3}); Tw(keyBtnStroke,0.15,{Color=T.borderDim})
        if bindCallbacks[featureId] then bindCallbacks[featureId]() end
        SaveConfig()
    end)
    keyBtn.MouseEnter:Connect(function() if not binding then Tw(keyBtn,0.1,{BackgroundColor3=T.ac3}) end end)
    keyBtn.MouseLeave:Connect(function() if not binding then Tw(keyBtn,0.1,{BackgroundColor3=T.bg3}) end end)
    clrBtn.MouseEnter:Connect(function() Tw(clrBtn,0.1,{TextColor3=T.ac0}) end)
    clrBtn.MouseLeave:Connect(function() Tw(clrBtn,0.1,{TextColor3=T.ac2}) end)
    return row
end

-- ============================================================
--  MOBILE SHORTCUTS EDITOR
-- ============================================================
local shortcutBarRef = nil
local RebuildShortcutBar = function() end
local savedBtnPositions = {}  -- stores dragged positions per id, survives rebuilds
local savedMainPos      = nil -- main GUI position saved across rebuilds
-- Load saved button positions from file on startup
pcall(function()
    if readfile and isfile and isfile("WsDuels_btnpos.json") then
        local raw=readfile("WsDuels_btnpos.json")
        if raw and raw~="" then
            local data=game:GetService("HttpService"):JSONDecode(raw)
            for id,pos in pairs(data.btns or {}) do
                savedBtnPositions[id]=UDim2.new(pos[1],pos[2],pos[3],pos[4])
            end
            if data.main then
                savedMainPos=UDim2.new(data.main[1],data.main[2],data.main[3],data.main[4])
            end
        end
    end
end)

local function MakeShortcutEditor(parent, allFeatures)
    local wrap=Instance.new("Frame",parent)
    wrap.Size=UDim2.new(1,0,0,S(0)); wrap.BackgroundTransparency=1; wrap.BorderSizePixel=0
    local WL=Instance.new("UIListLayout",wrap)
    WL.Padding=UDim.new(0,S(3)); WL.SortOrder=Enum.SortOrder.LayoutOrder
    local headerH=S(20)
    local hdr=Instance.new("TextLabel",wrap)
    hdr.Size=UDim2.new(1,0,0,headerH); hdr.LayoutOrder=0; hdr.BackgroundTransparency=1
    hdr.Text="TAP SHORTCUTS"; hdr.Font=Enum.Font.GothamBold
    hdr.TextSize=S(8); hdr.TextColor3=T.cyanDim; hdr.TextXAlignment=Enum.TextXAlignment.Left
    local ITEM_H=S(28); local cols=2
    local rows2=math.ceil(#allFeatures/cols)
    local gridH=rows2*ITEM_H+rows2*S(3)
    local grid=Instance.new("Frame",wrap)
    grid.Size=UDim2.new(1,0,0,gridH); grid.LayoutOrder=1; grid.BackgroundTransparency=1; grid.BorderSizePixel=0
    for i,feat in ipairs(allFeatures) do
        local col=(i-1)%cols; local row2=math.floor((i-1)/cols)
        local item=Instance.new("TextButton",grid)
        item.Size=UDim2.new(0.5,-S(2),0,ITEM_H)
        item.Position=UDim2.new(col*0.5,col==0 and 0 or S(2),0,row2*(ITEM_H+S(3)))
        local isOn=false
        for _,s in ipairs(MobileShortcuts) do if s==feat.id then isOn=true break end end
        item.BackgroundColor3=isOn and T.acOff or T.bg3; item.BorderSizePixel=0; item.AutoButtonColor=false; item.Text=""
        Instance.new("UICorner",item).CornerRadius=UDim.new(0,S(7))
        local iS=Instance.new("UIStroke",item); iS.Color=isOn and T.ac1 or T.borderDim; iS.Thickness=1; iS.Transparency=isOn and 0.2 or 0.5
        local chk=Instance.new("TextLabel",item)
        chk.Size=UDim2.new(0,S(14),0,S(14)); chk.Position=UDim2.new(0,S(5),0.5,-S(7))
        chk.BackgroundColor3=isOn and T.ac0 or T.bg2; chk.BorderSizePixel=0
        chk.Text=isOn and "V" or ""; chk.Font=Enum.Font.GothamBold; chk.TextSize=S(7); chk.TextColor3=T.bg0
        Instance.new("UICorner",chk).CornerRadius=UDim.new(0,S(3))
        local lbl2=Instance.new("TextLabel",item)
        lbl2.Size=UDim2.new(1,-S(24),1,0); lbl2.Position=UDim2.new(0,S(22),0,0)
        lbl2.BackgroundTransparency=1; lbl2.Text=feat.label; lbl2.Font=Enum.Font.GothamBold
        lbl2.TextSize=S(8); lbl2.TextColor3=isOn and txtPrime or txtSub; lbl2.TextXAlignment=Enum.TextXAlignment.Left
        item.MouseButton1Click:Connect(function()
            local idx=nil
            for j,s in ipairs(MobileShortcuts) do if s==feat.id then idx=j break end end
            if idx then table.remove(MobileShortcuts,idx); isOn=false
            else table.insert(MobileShortcuts,feat.id); isOn=true end
            Tw(item,0.15,{BackgroundColor3=isOn and T.acOff or T.bg3})
            Tw(iS,0.15,{Color=isOn and T.ac1 or T.borderDim,Transparency=isOn and 0.2 or 0.5})
            Tw(chk,0.15,{BackgroundColor3=isOn and T.ac0 or T.bg2})
            chk.Text=isOn and "V" or ""
            Tw(lbl2,0.15,{TextColor3=isOn and txtPrime or txtSub})
            RebuildShortcutBar()
            SaveConfig()
        end)
    end
    wrap.Size=UDim2.new(1,0,0,headerH+S(3)+gridH+S(4))
    return wrap
end

-- ============================================================
--  MAIN GUI BUILDER
-- ============================================================
BuildMainGUI = function()
    if heartbeatConn     then heartbeatConn:Disconnect();     heartbeatConn=nil     end
    if statusBarConn     then statusBarConn:Disconnect();     statusBarConn=nil     end
    if globalKeybindConn then globalKeybindConn:Disconnect(); globalKeybindConn=nil end

    pcall(function() ParentUI:FindFirstChild("WsDuels"):Destroy() end)
    registeredDotSets={}; bindCallbacks={}; toggleSetState={}

    local BASE_W  = isMobile and 224 or 260
    local W       = S(BASE_W)
    local PAD     = S(isMobile and 7 or 10)
    local HDR     = S(isMobile and 46 or 52)
    local GAP     = S(isMobile and 3 or 5)
    local BTN_H   = S(isMobile and 36 or 42)
    local SPD_H   = S(isMobile and 34 or 38)
    local SECT_H  = S(isMobile and 16 or 18)
    local THM_H   = S(isMobile and 38 or 42)
    local SCL_H   = S(isMobile and 34 or 38)
    local KB_ROW_H= S(34)

    local allFeatures = {
        {id="float",     label="Float"},
        {id="autoR",     label="Auto Right"},
        {id="autoL",     label="Auto Left"},
        {id="aimbot",    label="Bat Aimbot"},
        {id="dropFling", label="Drop Fling"},
        {id="antiFling", label="Anti Fling"},
        {id="antiRag",   label="Anti Ragdoll"},
        {id="infJump",   label="Inf Jump"},
        {id="jumpTpDown",label="Jump TP Down"},
        {id="autoTpDown",label="Auto TP"},
        {id="spinBot",   label="Spin Bot"},
        {id="unwalk",    label="Unwalk"},
        {id="steal",     label="Auto Steal"},
        {id="stealSpd",  label="Steal Speed"},
        {id="taunt",     label="Taunt Spam"},
        {id="autoGrab",  label="Auto Grab"},
        {id="optimizer", label="Optimizer"},
    }

    local TOGGLE_COUNT=17; local SECT_COUNT=5; local SPEED_COUNT=2; local EXTRA_H=S(isMobile and 34 or 38)+S(5)
    local GRAB_ROW_H = S(isMobile and 34 or 38)
    local KEYBIND_SECTION_H=(not isMobile) and (S(18)+GAP + #allFeatures*(KB_ROW_H+GAP)+GAP) or 0
    local SHORTCUT_H=isMobile and (S(18)+GAP + S(20)+GAP + math.ceil(#allFeatures/2)*(S(28)+S(3))+S(8)) or 0
    local HIDE_KB_H=(not isMobile) and (S(34)+GAP) or 0

    local CONTENT_H=PAD*2
        +SECT_COUNT*(SECT_H+GAP)
        +TOGGLE_COUNT*(BTN_H+GAP)
        +SPEED_COUNT*(SPD_H+GAP)
        +2*(GRAB_ROW_H+GAP)
        +THM_H+GAP+SCL_H+GAP
        +KEYBIND_SECTION_H+SHORTCUT_H+HIDE_KB_H+S(20)+S(isMobile and 39 or 43)

    local screenH=workspace.CurrentCamera.ViewportSize.Y
    local shortcutBarH=isMobile and S(42) or 0
    local FULL_H=math.min(HDR+CONTENT_H, screenH-60-shortcutBarH)

    local Screen=Instance.new("ScreenGui")
    Screen.Name="WsDuels"; Screen.ResetOnSpawn=false
    Screen.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; Screen.Parent=ParentUI

    local Main=Instance.new("Frame",Screen)
    Main.Name="Main"; Main.Size=UDim2.new(0,W,0,HDR)
    Main.Position=savedMainPos or UDim2.new(0,S(8),0,S(50))
    Main.BackgroundColor3=T.bg0; Main.BorderSizePixel=0; Main.ClipsDescendants=true
    Instance.new("UICorner",Main).CornerRadius=UDim.new(0,S(16))
    local mainStroke=Instance.new("UIStroke",Main)
    mainStroke.Color=T.border; mainStroke.Thickness=1.2; mainStroke.Transparency=0.2
    local BG=Instance.new("UIGradient",Main)
    BG.Color=ColorSequence.new{ColorSequenceKeypoint.new(0,T.bg0),ColorSequenceKeypoint.new(1,Color3.fromRGB(3,3,7))}
    BG.Rotation=135
    MakeDotsBackground(Main)

    local Header=Instance.new("Frame",Main)
    Header.Size=UDim2.new(1,0,0,HDR); Header.BackgroundColor3=T.bg1; Header.BorderSizePixel=0
    Instance.new("UICorner",Header).CornerRadius=UDim.new(0,S(16))
    local HG=Instance.new("UIGradient",Header)
    HG.Color=ColorSequence.new{ColorSequenceKeypoint.new(0,T.bg2),ColorSequenceKeypoint.new(1,T.bg0)}; HG.Rotation=90
    MakeDraggable(Main,Header)
    -- Save main GUI position whenever it's dragged so it survives theme rebuilds
    UIS.InputEnded:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then
            if Main and Main.Parent then savedMainPos=Main.Position end
        end
    end)

    local TopLine=Instance.new("Frame",Header)
    TopLine.Size=UDim2.new(1,0,0,2); TopLine.BackgroundColor3=T.ac1; TopLine.BorderSizePixel=0
    local TLG=Instance.new("UIGradient",TopLine)
    TLG.Color=ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(0,0,0)),ColorSequenceKeypoint.new(0.2,T.ac0),ColorSequenceKeypoint.new(0.8,T.ac0),ColorSequenceKeypoint.new(1,Color3.fromRGB(0,0,0))}

    local logoSz=S(isMobile and 28 or 32)
    local LogoBox=Instance.new("Frame",Header)
    LogoBox.Size=UDim2.new(0,logoSz,0,logoSz); LogoBox.Position=UDim2.new(0,S(12),0.5,-logoSz/2)
    LogoBox.BackgroundColor3=T.acOff; LogoBox.BorderSizePixel=0
    Instance.new("UICorner",LogoBox).CornerRadius=UDim.new(0,S(8))
    local LBS=Instance.new("UIStroke",LogoBox); LBS.Color=T.ac1; LBS.Thickness=1.2; LBS.Transparency=0.2
    local LogoTxt=Instance.new("TextLabel",LogoBox)
    LogoTxt.Size=UDim2.new(1,0,1,0); LogoTxt.BackgroundTransparency=1; LogoTxt.Text="KZ"
    LogoTxt.Font=Enum.Font.GothamBlack; LogoTxt.TextSize=S(isMobile and 10 or 11); LogoTxt.TextColor3=T.ac0

    for i=1,4 do
        local ang=(i-1)*math.pi/2
        local cx=S(12)+logoSz/2+math.cos(ang)*(logoSz/2+S(5))
        local cy=HDR/2+math.sin(ang)*(logoSz/2+S(5))
        local cd=Instance.new("Frame",Header)
        cd.Size=UDim2.new(0,S(3),0,S(3)); cd.Position=UDim2.new(0,cx-S(1),0,cy-S(1))
        cd.BackgroundColor3=T.ac0; cd.BackgroundTransparency=0.3; cd.BorderSizePixel=0
        Instance.new("UICorner",cd).CornerRadius=UDim.new(1,0)
        local delay=i*0.2
        task.spawn(function()
            while cd.Parent do
                Tw(cd,0.8,{BackgroundTransparency=0.8},Enum.EasingStyle.Sine); task.wait(0.85+delay)
                Tw(cd,0.8,{BackgroundTransparency=0.05},Enum.EasingStyle.Sine); task.wait(0.85+delay)
            end
        end)
    end

    local xOff=S(isMobile and 48 or 54)
    local TitleLbl=Instance.new("TextLabel",Header)
    TitleLbl.Size=UDim2.new(1,-S(100),0,S(17)); TitleLbl.Position=UDim2.new(0,xOff,0,S(isMobile and 6 or 8))
    TitleLbl.BackgroundTransparency=1; TitleLbl.Text="WS DUELS"
    TitleLbl.Font=Enum.Font.GothamBlack; TitleLbl.TextSize=S(isMobile and 11 or 13)
    TitleLbl.TextColor3=T.ac0; TitleLbl.TextXAlignment=Enum.TextXAlignment.Left

    local SubLbl=Instance.new("TextLabel",Header)
    SubLbl.Size=UDim2.new(1,-S(100),0,S(12)); SubLbl.Position=UDim2.new(0,xOff,0,S(isMobile and 24 or 27))
    SubLbl.BackgroundTransparency=1
    SubLbl.Text=(isMobile and "MOBILE" or "PC").."  -  "..T.name
    SubLbl.Font=Enum.Font.Gotham; SubLbl.TextSize=S(isMobile and 8 or 9)
    SubLbl.TextColor3=txtMute; SubLbl.TextXAlignment=Enum.TextXAlignment.Left

    local MinBtn=Instance.new("TextButton",Header)
    MinBtn.Size=UDim2.new(0,S(isMobile and 24 or 28),0,S(isMobile and 24 or 28))
    MinBtn.Position=UDim2.new(1,-S(isMobile and 32 or 38),0.5,-S(isMobile and 12 or 14))
    MinBtn.BackgroundColor3=T.bg3; MinBtn.Text="-"; MinBtn.Font=Enum.Font.GothamBold
    MinBtn.TextColor3=txtSub; MinBtn.TextSize=S(isMobile and 13 or 15); MinBtn.BorderSizePixel=0; MinBtn.AutoButtonColor=false
    Instance.new("UICorner",MinBtn).CornerRadius=UDim.new(0,S(7))
    Instance.new("UIStroke",MinBtn).Color=T.borderDim
    MinBtn.MouseEnter:Connect(function() Tw(MinBtn,0.12,{BackgroundColor3=T.ac3,TextColor3=T.ac0}) end)
    MinBtn.MouseLeave:Connect(function() Tw(MinBtn,0.12,{BackgroundColor3=T.bg3,TextColor3=txtSub}) end)

    local SF=Instance.new("ScrollingFrame",Main)
    SF.Name="ContentScroll"
    SF.Size=UDim2.new(1,0,1,-HDR); SF.Position=UDim2.new(0,0,0,HDR)
    SF.BackgroundTransparency=1; SF.BorderSizePixel=0
    SF.ScrollBarThickness=S(isMobile and 3 or 2); SF.ScrollBarImageColor3=T.ac2
    SF.ScrollingDirection=Enum.ScrollingDirection.Y
    SF.CanvasSize=UDim2.new(0,0,0,CONTENT_H)
    SF.ElasticBehavior=Enum.ElasticBehavior.WhenScrollable; SF.ScrollingEnabled=true

    if isMobile then
        local touchStart=nil; local canvasStart=0
        local maxScroll=math.max(0,CONTENT_H-(FULL_H-HDR))
        SF.InputBegan:Connect(function(inp)
            if inp.UserInputType==Enum.UserInputType.Touch then touchStart=inp.Position; canvasStart=SF.CanvasPosition.Y end
        end)
        SF.InputChanged:Connect(function(inp)
            if inp.UserInputType==Enum.UserInputType.Touch and touchStart then
                local dy=touchStart.Y-inp.Position.Y
                SF.CanvasPosition=Vector2.new(0,math.clamp(canvasStart+dy,0,maxScroll))
            end
        end)
        SF.InputEnded:Connect(function(inp)
            if inp.UserInputType==Enum.UserInputType.Touch then touchStart=nil end
        end)
    end

    local Content=Instance.new("Frame",SF)
    Content.Size=UDim2.new(1,0,0,CONTENT_H); Content.BackgroundTransparency=1
    local CL=Instance.new("UIListLayout",Content)
    CL.Padding=UDim.new(0,GAP); CL.HorizontalAlignment=Enum.HorizontalAlignment.Center
    CL.VerticalAlignment=Enum.VerticalAlignment.Top; CL.SortOrder=Enum.SortOrder.LayoutOrder
    local CP=Instance.new("UIPadding",Content)
    CP.PaddingTop=UDim.new(0,PAD); CP.PaddingBottom=UDim.new(0,PAD)
    CP.PaddingLeft=UDim.new(0,PAD); CP.PaddingRight=UDim.new(0,PAD)

    local lo=0; local function A(obj) lo=lo+1; obj.LayoutOrder=lo; return obj end

    A(MakeSectionLabel(Content,"APPEARANCE"))
    A(MakeThemePicker(Content))
    A(MakeScaleRow(Content))

    A(MakeSectionLabel(Content,"MOVEMENT"))
    local bF,_ssF,_,ubF     = MakeToggle(Content,"Float",      not isMobile and "float"    or nil)
    local bAR,_ssAR,_,ubAR  = MakeToggle(Content,"Auto Right", not isMobile and "autoR"    or nil)
    ssF=_ssF; ssAR=_ssAR
    _bARref=bAR
    A(bF); A(bAR)
    A(MakeSpeedRow(Content,"Right Speed",patrolRightSpeed,function(v) patrolRightSpeed=v; SaveConfig() end))
    local bAL,_ssAL,_,ubAL  = MakeToggle(Content,"Auto Left",  not isMobile and "autoL"    or nil)
    ssAL=_ssAL
    _bALref=bAL
    A(bAL)
    A(MakeSpeedRow(Content,"Left Speed",patrolLeftSpeed,function(v) patrolLeftSpeed=v; SaveConfig() end))

    -- Waypoint Editor Button
    do
        local wpBtnH=S(isMobile and 34 or 38)
        local wpBtn=Instance.new("TextButton",Content)
        wpBtn.Size=UDim2.new(1,0,0,wpBtnH); wpBtn.BackgroundColor3=T.bg0
        wpBtn.Text=""; wpBtn.BorderSizePixel=0; wpBtn.AutoButtonColor=false
        Instance.new("UICorner",wpBtn).CornerRadius=UDim.new(0,S(10))
        local wpS=Instance.new("UIStroke",wpBtn); wpS.Color=T.ac1; wpS.Thickness=1.2; wpS.Transparency=0.2
        local wpL=Instance.new("TextLabel",wpBtn)
        wpL.Size=UDim2.new(1,-S(20),1,0); wpL.Position=UDim2.new(0,S(14),0,0)
        wpL.BackgroundTransparency=1; wpL.Text="** Change Waypoints"
        wpL.Font=Enum.Font.GothamBold; wpL.TextSize=S(isMobile and 10 or 11)
        wpL.TextColor3=T.ac0; wpL.TextXAlignment=Enum.TextXAlignment.Left
        local wpArrow=Instance.new("TextLabel",wpBtn)
        wpArrow.Size=UDim2.new(0,S(20),1,0); wpArrow.Position=UDim2.new(1,-S(22),0,0)
        wpArrow.BackgroundTransparency=1; wpArrow.Text=">"
        wpArrow.Font=Enum.Font.GothamBold; wpArrow.TextSize=S(12); wpArrow.TextColor3=T.ac0
        wpBtn.MouseEnter:Connect(function() Tw(wpBtn,0.1,{BackgroundColor3=T.bg1}) end)
        wpBtn.MouseLeave:Connect(function() Tw(wpBtn,0.1,{BackgroundColor3=T.bg0}) end)
        lo=lo+1; wpBtn.LayoutOrder=lo

        -- POPUP PANEL
        local PW=S(isMobile and 230 or 260); local PH=S(isMobile and 250 or 268)
        local wpPanel=Instance.new("Frame",Screen)
        wpPanel.Name="WpEditorPanel"; wpPanel.Size=UDim2.new(0,PW,0,PH)
        wpPanel.Position=UDim2.new(0,S(8)+W+S(6),0,S(50))
        wpPanel.BackgroundColor3=T.bg0; wpPanel.BorderSizePixel=0; wpPanel.Visible=false
        Instance.new("UICorner",wpPanel).CornerRadius=UDim.new(0,S(14))
        local wpPS=Instance.new("UIStroke",wpPanel); wpPS.Color=T.ac1; wpPS.Thickness=1.4; wpPS.Transparency=0.15
        local wpPG=Instance.new("UIGradient",wpPanel)
        wpPG.Color=ColorSequence.new{ColorSequenceKeypoint.new(0,T.bg1),ColorSequenceKeypoint.new(1,T.bg0)}; wpPG.Rotation=135
        MakeDotsBackground(wpPanel)
        MakeDraggable(wpPanel,wpPanel)

        -- Title
        local wpTit=Instance.new("TextLabel",wpPanel)
        wpTit.Size=UDim2.new(1,-S(32),0,S(28)); wpTit.Position=UDim2.new(0,S(10),0,S(4))
        wpTit.BackgroundTransparency=1; wpTit.Text="WAYPOINT EDITOR"
        wpTit.Font=Enum.Font.GothamBlack; wpTit.TextSize=S(isMobile and 10 or 11)
        wpTit.TextColor3=T.ac0; wpTit.TextXAlignment=Enum.TextXAlignment.Left

        -- Close
        local wpCl=Instance.new("TextButton",wpPanel)
        wpCl.Size=UDim2.new(0,S(22),0,S(22)); wpCl.Position=UDim2.new(1,-S(26),0,S(5))
        wpCl.BackgroundColor3=T.bg2; wpCl.Text="X"; wpCl.Font=Enum.Font.GothamBold
        wpCl.TextSize=S(9); wpCl.TextColor3=T.ac0; wpCl.BorderSizePixel=0; wpCl.AutoButtonColor=false
        Instance.new("UICorner",wpCl).CornerRadius=UDim.new(0,S(5))
        wpCl.MouseButton1Click:Connect(function() wpPanel.Visible=false end)

        local div=Instance.new("Frame",wpPanel); div.Size=UDim2.new(1,-S(16),0,1)
        div.Position=UDim2.new(0,S(8),0,S(34)); div.BackgroundColor3=T.ac3
        div.BackgroundTransparency=0.3; div.BorderSizePixel=0

        -- LEFT / RIGHT tabs
        local TY=S(38); local TH=S(26)
        local tabR=Instance.new("TextButton",wpPanel)
        tabR.Size=UDim2.new(0.5,-S(4),0,TH); tabR.Position=UDim2.new(0,S(4),0,TY)
        tabR.BackgroundColor3=T.ac2; tabR.Text="RIGHT"; tabR.Font=Enum.Font.GothamBold
        tabR.TextSize=S(9); tabR.TextColor3=T.bg0; tabR.BorderSizePixel=0; tabR.AutoButtonColor=false
        Instance.new("UICorner",tabR).CornerRadius=UDim.new(0,S(7))
        local tabL=Instance.new("TextButton",wpPanel)
        tabL.Size=UDim2.new(0.5,-S(4),0,TH); tabL.Position=UDim2.new(0.5,0,0,TY)
        tabL.BackgroundColor3=T.bg2; tabL.Text="LEFT"; tabL.Font=Enum.Font.GothamBold
        tabL.TextSize=S(9); tabL.TextColor3=T.ac0; tabL.BorderSizePixel=0; tabL.AutoButtonColor=false
        Instance.new("UICorner",tabL).CornerRadius=UDim.new(0,S(7))

        local curSide="right"; local selIdx=1
        local ptBtns={}
        local PY=TY+TH+S(6); local PBH=S(26)
        local ptRow=Instance.new("Frame",wpPanel)
        ptRow.Size=UDim2.new(1,-S(8),0,PBH); ptRow.Position=UDim2.new(0,S(4),0,PY)
        ptRow.BackgroundTransparency=1; ptRow.BorderSizePixel=0
        for i=1,4 do
            local pb=Instance.new("TextButton",ptRow)
            pb.Size=UDim2.new(0.25,-S(2),1,0); pb.Position=UDim2.new((i-1)*0.25,(i==1 and 0 or S(2)),0,0)
            pb.BackgroundColor3=i==1 and T.ac2 or T.bg2
            pb.Text="R"..i; pb.Font=Enum.Font.GothamBold
            pb.TextSize=S(9); pb.TextColor3=i==1 and T.bg0 or T.ac0
            pb.BorderSizePixel=0; pb.AutoButtonColor=false
            Instance.new("UICorner",pb).CornerRadius=UDim.new(0,S(6))
            ptBtns[i]=pb
        end

        -- Coord label
        local CY=PY+PBH+S(6)
        local coordLbl=Instance.new("TextLabel",wpPanel)
        coordLbl.Size=UDim2.new(1,-S(8),0,S(30)); coordLbl.Position=UDim2.new(0,S(4),0,CY)
        coordLbl.BackgroundColor3=T.bg2; coordLbl.BorderSizePixel=0
        Instance.new("UICorner",coordLbl).CornerRadius=UDim.new(0,S(7))
        Instance.new("UIStroke",coordLbl).Color=T.borderDim
        coordLbl.Font=Enum.Font.Gotham; coordLbl.TextSize=S(isMobile and 8 or 9)
        coordLbl.TextColor3=T.cyanDim; coordLbl.Text="R1: using default"

        -- Set Point button
        local BY=CY+S(34)
        local setBtn=Instance.new("TextButton",wpPanel)
        setBtn.Size=UDim2.new(1,-S(8),0,S(32)); setBtn.Position=UDim2.new(0,S(4),0,BY)
        setBtn.BackgroundColor3=T.ac2; setBtn.Text="SET POINT (stand here)"
        setBtn.Font=Enum.Font.GothamBold; setBtn.TextSize=S(9); setBtn.TextColor3=T.bg0
        setBtn.BorderSizePixel=0; setBtn.AutoButtonColor=false
        Instance.new("UICorner",setBtn).CornerRadius=UDim.new(0,S(8))

        -- Clear button
        local clearBtn=Instance.new("TextButton",wpPanel)
        clearBtn.Size=UDim2.new(1,-S(8),0,S(26)); clearBtn.Position=UDim2.new(0,S(4),0,BY+S(36))
        clearBtn.BackgroundColor3=T.bg2; clearBtn.Text="CLEAR (reset to default)"
        clearBtn.Font=Enum.Font.GothamBold; clearBtn.TextSize=S(9); clearBtn.TextColor3=T.ac0
        clearBtn.BorderSizePixel=0; clearBtn.AutoButtonColor=false
        Instance.new("UICorner",clearBtn).CornerRadius=UDim.new(0,S(8))
        Instance.new("UIStroke",clearBtn).Color=T.borderDim

        -- Show markers button
        local markBtn=Instance.new("TextButton",wpPanel)
        markBtn.Size=UDim2.new(1,-S(8),0,S(26)); markBtn.Position=UDim2.new(0,S(4),0,BY+S(66))
        markBtn.BackgroundColor3=T.bg2; markBtn.Text="Show Markers: OFF"
        markBtn.Font=Enum.Font.GothamBold; markBtn.TextSize=S(8); markBtn.TextColor3=T.ac0
        markBtn.BorderSizePixel=0; markBtn.AutoButtonColor=false
        Instance.new("UICorner",markBtn).CornerRadius=UDim.new(0,S(7))
        Instance.new("UIStroke",markBtn).Color=T.borderDim
        local markersOn=false

        -- helpers
        local function refreshCoord()
            local cArr=curSide=="right" and customRight or customLeft
            local lbl=(curSide=="right" and "R" or "L")..selIdx
            local pos=cArr[selIdx]
            if pos then
                coordLbl.Text=lbl..": ("..math.floor(pos.X)..", "..math.floor(pos.Y)..", "..math.floor(pos.Z)..")"
            else
                coordLbl.Text=lbl..": using default"
            end
        end

        local function selectPoint(idx)
            selIdx=idx
            for i=1,4 do
                ptBtns[i].BackgroundColor3=i==idx and T.ac2 or T.bg2
                ptBtns[i].TextColor3=i==idx and T.bg0 or T.ac0
            end
            refreshCoord()
        end

        local function selectSide(side)
            curSide=side
            local isR=side=="right"
            Tw(tabR,0.15,{BackgroundColor3=isR and T.ac2 or T.bg2}); tabR.TextColor3=isR and T.bg0 or T.ac0
            Tw(tabL,0.15,{BackgroundColor3=isR and T.bg2 or T.ac2}); tabL.TextColor3=isR and T.ac0 or T.bg0
            for i=1,4 do ptBtns[i].Text=(side=="right" and "R" or "L")..i end
            selectPoint(1)
        end

        -- wire buttons
        tabR.MouseButton1Click:Connect(function() selectSide("right") end)
        tabL.MouseButton1Click:Connect(function() selectSide("left")  end)
        for i=1,4 do
            local ii=i
            ptBtns[i].MouseButton1Click:Connect(function() selectPoint(ii) end)
        end

        setBtn.MouseButton1Click:Connect(function()
            local root=GetRoot(); if not root then return end
            local pos=root.Position
            if curSide=="right" then customRight[selIdx]=pos
            else customLeft[selIdx]=pos end
            updatePatrolWaypoints()
            saveCustomWaypoints()
            refreshCoord()
            if markersOn then refreshWpMarkers() end
            Tw(setBtn,0.15,{BackgroundColor3=T.ac0})
            task.delay(0.8,function() Tw(setBtn,0.2,{BackgroundColor3=T.ac2}) end)
        end)

        clearBtn.MouseButton1Click:Connect(function()
            if curSide=="right" then customRight[selIdx]=nil
            else customLeft[selIdx]=nil end
            updatePatrolWaypoints()
            saveCustomWaypoints()
            refreshCoord()
            if markersOn then refreshWpMarkers() end
        end)

        markBtn.MouseButton1Click:Connect(function()
            markersOn=not markersOn
            markBtn.Text="Show Markers: "..(markersOn and "ON" or "OFF")
            markBtn.TextColor3=markersOn and T.ac0 or T.ac0
            Tw(markBtn,0.15,{BackgroundColor3=markersOn and T.acOff or T.bg2})
            if markersOn then refreshWpMarkers() else clearWpMarkers() end
        end)

        wpBtn.MouseButton1Click:Connect(function()
            wpPanel.Visible=not wpPanel.Visible
        end)
        selectSide("right")
    end

    A(MakeSectionLabel(Content,"COMBAT"))
    local bAim,_ssAim,_,ubAim = MakeToggle(Content,"Bat Aimbot",  not isMobile and "aimbot"    or nil)
    local bDr,_ssDr,_,ubDr   = MakeToggle(Content,"Drop Fling",  not isMobile and "dropFling" or nil)
    ssAim=_ssAim; ssDr=_ssDr
    A(bAim); A(bDr)

    A(MakeSectionLabel(Content,"UTILITIES"))
    local bAF,_ssAF,_,ubAF         = MakeToggle(Content,"Anti Fling",   not isMobile and "antiFling" or nil)
    local bARag,_ssARag,_,ubARag   = MakeToggle(Content,"Anti Ragdoll", not isMobile and "antiRag"   or nil)
    local bIJ,_ssIJ,_,ubIJ         = MakeToggle(Content,"Inf Jump",     not isMobile and "infJump"   or nil)
    local bJTp,_ssJTp,_,ubJTp      = MakeToggle(Content,"Jump TP Down", not isMobile and "jumpTpDown" or nil)
    local bAtp,_ssAtp,_,ubAtp      = MakeToggle(Content,"Auto TP",      not isMobile and "autoTpDown"  or nil)
    local bSp,_ssSp,_,ubSp         = MakeToggle(Content,"Spin Bot",     not isMobile and "spinBot"   or nil)
    local bUw,_ssUw,_,ubUw         = MakeToggle(Content,"Unwalk",       not isMobile and "unwalk"    or nil)
    local bSt,_ssSt,_,ubSt         = MakeToggle(Content,"Auto Steal",   not isMobile and "steal"     or nil)
    local bSspd,_ssSspd,_,ubSspd   = MakeToggle(Content,"Steal Speed",  not isMobile and "stealSpd"  or nil)
    local bTnt,_ssTnt,_,ubTnt      = MakeToggle(Content,"Taunt Spam",   not isMobile and "taunt"     or nil)
    local bGrab,_ssGrab,_,ubGrab   = MakeToggle(Content,"Auto Grab",    not isMobile and "autoGrab"  or nil)
    local bOpt,_ssOpt,_,ubOpt       = MakeToggle(Content,"Optimizer",     not isMobile and "optimizer" or nil)
    ssAF=_ssAF; ssARag=_ssARag; ssIJ=_ssIJ; ssSp=_ssSp; ssUw=_ssUw
    ssSt=_ssSt; ssSspd=_ssSspd; ssTnt=_ssTnt; ssGrab=_ssGrab
    local ssOpt=_ssOpt; ssATD=_ssAtp; ssAutoTp=_ssAtp
    A(bAF); A(bARag); A(bIJ); A(bJTp); A(bAtp); A(bSp); A(bUw); A(bSt); A(bSspd); A(bTnt); A(bGrab); A(bOpt)
    A(MakeSpeedRow(Content,"Grab Radius",AUTO_GRAB_RADIUS,function(v) AUTO_GRAB_RADIUS=v; SaveConfig() end))
    A(MakeSpeedRow(Content,"Grab Delay (x100ms)",math.floor(AUTO_GRAB_DELAY*10),function(v) AUTO_GRAB_DELAY=v/10; SaveConfig() end))
    A(MakeSpeedRow(Content,"Grab Delay (x100ms)",math.floor(AUTO_GRAB_DELAY*10),function(v) AUTO_GRAB_DELAY=v/10; SaveConfig() end))

    toggleSetState={
        float=ssF,autoR=ssAR,autoL=ssAL,aimbot=ssAim,dropFling=ssDr,
        antiFling=ssAF,antiRag=ssARag,infJump=ssIJ,spinBot=ssSp,unwalk=ssUw,
        autoTpDown=ssAutoTp,
        steal=ssSt,stealSpd=ssSspd,taunt=ssTnt,autoGrab=ssGrab,
        optimizer=ssOpt,
    }
    bindCallbacks={
        float=ubF,autoR=ubAR,autoL=ubAL,aimbot=ubAim,dropFling=ubDr,
        antiFling=ubAF,antiRag=ubARag,infJump=ubIJ,jumpTpDown=ubJTp,spinBot=ubSp,unwalk=ubUw,
        steal=ubSt,stealSpd=ubSspd,taunt=ubTnt,autoGrab=ubGrab,
        optimizer=ubOpt,
        autoTpDown=ubAtp,
    }
    FeatureStates={
        float=false,autoR=false,autoL=false,aimbot=false,dropFling=false,
        antiFling=false,antiRag=false,infJump=false,jumpTpDown=false,spinBot=false,unwalk=false,
        steal=false,stealSpd=false,taunt=false,autoGrab=false,
        optimizer=false,autoTpDown=false
    }

    if antiFlingActive   then FeatureStates.antiFling=true;   ssAF(true)    end
    if antiRagdollActive then FeatureStates.antiRag=true;     ssARag(true)  end
    if infJumpActive     then FeatureStates.infJump=true;     ssIJ(true)    end
    if spinActive        then FeatureStates.spinBot=true;     ssSp(true)    end
    if unwalkActive      then FeatureStates.unwalk=true;      ssUw(true)    end
    if stealSpeedActive  then FeatureStates.stealSpd=true;    ssSspd(true)  end
    if autoGrabActive    then FeatureStates.autoGrab=true;    ssGrab(true)  end
    if optimizerActive   then FeatureStates.optimizer=true;   ssOpt(true)   end
    if tauntActive       then FeatureStates.taunt=true;       ssTnt(true)   end
    if stealActive       then FeatureStates.steal=true;       ssSt(true)    end
    if floating          then FeatureStates.float=true;       ssF(true)     end
    if batAimbotActive   then FeatureStates.aimbot=true;      ssAim(true)   end
    if autoTpDownActive  then FeatureStates.autoTpDown=true;  ssAutoTp(true) end
    if patrolMode=="right" then FeatureStates.autoR=true; ssAR(true) end
    if patrolMode=="left"  then FeatureStates.autoL=true; ssAL(true) end

    -- Apply saved config: set visual state AND start backends
    -- This runs inside BuildMainGUI so all ssX setters are valid
    if _savedConfig and _savedConfig.toggles then
        local t2=_savedConfig.toggles
        task.defer(function()
            if t2.antiFling  then antiFlingActive=true;   ssAF(true);   startAntiFling()   end
            if t2.antiRag    then antiRagdollActive=true; ssARag(true); startAntiRagdoll() end
            if t2.infJump    then infJumpActive=true;     ssIJ(true);   startInfJump()     end
            if t2.spinBot    then spinActive=true;        ssSp(true);   startSpinBot()     end
            if t2.unwalk     then unwalkActive=true;      ssUw(true);   startUnwalk()      end
            if t2.stealSpd   then stealSpeedActive=true;  ssSspd(true); startStealSpeed()  end
            if t2.autoGrab   then autoGrabActive=true;    ssGrab(true); startAutoGrab()    end
            if t2.optimizer  then optimizerActive=true;   ssOpt(true);  enableOptimizer()  end
            if t2.steal      then stealActive=true;       ssSt(true);   startStealLoop()   end
            if t2.autoTpDown then autoTpDownActive=true;  ssAutoTp(true); startAutoTpDown() end
            if t2.taunt      then
                tauntActive=true; ssTnt(true)
                tauntLoop=task.spawn(function()
                    while tauntActive do
                        pcall(function() local ch=game:GetService("TextChatService").TextChannels:FindFirstChild("RBXGeneral"); if ch then ch:SendAsync("/ws duels") end end)
                        task.wait(0.5)
                    end
                end)
            end
            FeatureStates.antiFling  = antiFlingActive
            FeatureStates.antiRag    = antiRagdollActive
            FeatureStates.infJump    = infJumpActive
            FeatureStates.spinBot    = spinActive
            FeatureStates.unwalk     = unwalkActive
            FeatureStates.stealSpd   = stealSpeedActive
            FeatureStates.autoGrab   = autoGrabActive
            FeatureStates.optimizer  = optimizerActive
            FeatureStates.steal      = stealActive
            FeatureStates.taunt      = tauntActive
        end)
    end

    if not isMobile then
        A(MakeSectionLabel(Content,"KEYBINDS"))
        for _,feat in ipairs(allFeatures) do A(MakeKeybindRow(Content,feat.id,feat.label)) end
    end

    if isMobile then
        A(MakeSectionLabel(Content,"SHORTCUTS"))
        A(MakeShortcutEditor(Content,allFeatures))
    end

    if not isMobile then
        local kRow=Instance.new("Frame",Content)
        kRow.Size=UDim2.new(1,0,0,S(34)); kRow.BackgroundColor3=T.bg2; kRow.BorderSizePixel=0; A(kRow)
        Instance.new("UICorner",kRow).CornerRadius=UDim.new(0,S(10))
        Instance.new("UIStroke",kRow).Color=T.borderDim
        local KL=Instance.new("TextLabel",kRow)
        KL.Size=UDim2.new(0,S(80),1,0); KL.Position=UDim2.new(0,S(12),0,0)
        KL.BackgroundTransparency=1; KL.Text="HIDE KEY"; KL.Font=Enum.Font.Gotham; KL.TextSize=S(9)
        KL.TextColor3=txtMute; KL.TextXAlignment=Enum.TextXAlignment.Left
        local KVBtn=Instance.new("TextButton",kRow)
        KVBtn.Size=UDim2.new(0,S(120),0,S(22)); KVBtn.Position=UDim2.new(1,-S(128),0.5,-S(11))
        KVBtn.BackgroundColor3=T.bg3; KVBtn.Text="[ "..HideKeybind.Name.." ]"
        KVBtn.Font=Enum.Font.GothamBold; KVBtn.TextSize=S(9); KVBtn.TextColor3=T.ac1
        KVBtn.BorderSizePixel=0; KVBtn.AutoButtonColor=false
        Instance.new("UICorner",KVBtn).CornerRadius=UDim.new(0,S(6))
        local bindingH=false
        KVBtn.MouseButton1Click:Connect(function()
            if bindingH then return end; bindingH=true; KVBtn.Text="[press...]"; KVBtn.TextColor3=warn
            local c2; c2=UIS.InputBegan:Connect(function(inp,gpe)
                if gpe then return end
                if inp.UserInputType==Enum.UserInputType.Keyboard then
                    HideKeybind=inp.KeyCode; KVBtn.Text="[ "..inp.KeyCode.Name.." ]"
                    KVBtn.TextColor3=T.ac1; bindingH=false; c2:Disconnect()
                end
            end)
        end)
    end

    local SB_W=S(isMobile and 240 or 280); local SB_H=S(isMobile and 38 or 42)
    local StealBar=Instance.new("Frame",Screen)
    StealBar.Size=UDim2.new(0,SB_W,0,SB_H)
    StealBar.Position=UDim2.new(0.5,-SB_W/2,1,-(SB_H+(isMobile and S(52) or S(10))))
    StealBar.BackgroundColor3=T.bg1; StealBar.BorderSizePixel=0
    Instance.new("UICorner",StealBar).CornerRadius=UDim.new(0,S(13))
    local SBS=Instance.new("UIStroke",StealBar); SBS.Color=T.border; SBS.Thickness=1; SBS.Transparency=0.3
    local SBTopL=Instance.new("Frame",StealBar)
    SBTopL.Size=UDim2.new(1,0,0,isMobile and S(10) or S(4)); SBTopL.BackgroundColor3=T.ac1; SBTopL.BorderSizePixel=0
    local SBTG=Instance.new("UIGradient",SBTopL)
    SBTG.Color=ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(0,0,0)),ColorSequenceKeypoint.new(0.5,T.ac0),ColorSequenceKeypoint.new(1,Color3.fromRGB(0,0,0))}
    SBTopL.ZIndex=10
    MakeDraggable(StealBar, SBTopL)
    if isMobile then
        local sbDragStart, sbCanvasStart
        StealBar.InputBegan:Connect(function(inp)
            if inp.UserInputType==Enum.UserInputType.Touch then sbDragStart=inp.Position; sbCanvasStart=StealBar.Position end
        end)
        StealBar.InputChanged:Connect(function(inp)
            if inp.UserInputType==Enum.UserInputType.Touch and sbDragStart then
                local dx=inp.Position.X-sbDragStart.X; local dy=inp.Position.Y-sbDragStart.Y
                StealBar.Position=UDim2.new(sbCanvasStart.X.Scale,sbCanvasStart.X.Offset+dx,sbCanvasStart.Y.Scale,sbCanvasStart.Y.Offset+dy)
            end
        end)
        StealBar.InputEnded:Connect(function(inp)
            if inp.UserInputType==Enum.UserInputType.Touch then sbDragStart=nil end
        end)
    end
    sbDots={}
    for i=1,3 do
        local d=Instance.new("Frame",StealBar)
        d.Size=UDim2.new(0,S(5),0,S(5)); d.Position=UDim2.new(0,S(8)+(i-1)*S(9),0.5,-S(2))
        d.BackgroundColor3=inactive; d.BackgroundTransparency=0.4; d.BorderSizePixel=0
        Instance.new("UICorner",d).CornerRadius=UDim.new(1,0); table.insert(sbDots,d)
    end
    SBStatus=Instance.new("TextLabel",StealBar)
    SBStatus.Size=UDim2.new(0,S(80),0,S(14)); SBStatus.Position=UDim2.new(0,S(36),0.5,-S(7))
    SBStatus.BackgroundTransparency=1; SBStatus.Text="IDLE"; SBStatus.Font=Enum.Font.GothamBold
    SBStatus.TextSize=S(isMobile and 9 or 10); SBStatus.TextColor3=txtMute; SBStatus.TextXAlignment=Enum.TextXAlignment.Left
    local SBTrack=Instance.new("Frame",StealBar)
    SBTrack.Size=UDim2.new(1,-S(122),0,S(3)); SBTrack.Position=UDim2.new(0,S(10),1,-S(7))
    SBTrack.BackgroundColor3=T.bg3; SBTrack.BorderSizePixel=0
    Instance.new("UICorner",SBTrack).CornerRadius=UDim.new(1,0)
    SBFill=Instance.new("Frame",SBTrack)
    SBFill.Size=UDim2.new(0,0,1,0); SBFill.BackgroundColor3=T.ac1; SBFill.BorderSizePixel=0
    Instance.new("UICorner",SBFill).CornerRadius=UDim.new(1,0)
    local FLG=Instance.new("UIGradient",SBFill)
    FLG.Color=ColorSequence.new{ColorSequenceKeypoint.new(0,T.ac2),ColorSequenceKeypoint.new(1,T.ac0)}

    local function MakeStatControl(xOff, labelTxt, initVal, minV, maxV, step, onChange)
        local BOX_W=S(52); local BOX_H=SB_H-S(8); local FS=S(isMobile and 8 or 9)
        local box=Instance.new("Frame",StealBar)
        box.Size=UDim2.new(0,BOX_W,0,BOX_H); box.Position=UDim2.new(1,xOff,0,S(4))
        box.BackgroundColor3=T.bg3; box.BorderSizePixel=0
        Instance.new("UICorner",box).CornerRadius=UDim.new(0,S(6))
        Instance.new("UIStroke",box).Color=T.borderDim
        local tl=Instance.new("TextLabel",box)
        tl.Size=UDim2.new(1,0,0,S(11)); tl.Position=UDim2.new(0,0,0,S(1))
        tl.BackgroundTransparency=1; tl.Text=labelTxt; tl.Font=Enum.Font.Gotham
        tl.TextSize=S(7); tl.TextColor3=txtMute
        local vl=Instance.new("TextLabel",box)
        vl.Size=UDim2.new(1,-S(22),0,S(13)); vl.Position=UDim2.new(0,0,0,S(13))
        vl.BackgroundTransparency=1; vl.Text=tostring(initVal)
        vl.Font=Enum.Font.GothamBold; vl.TextSize=FS; vl.TextColor3=T.ac0
        local mB=Instance.new("TextButton",box)
        mB.Size=UDim2.new(0,S(10),0,S(12)); mB.Position=UDim2.new(0,S(1),1,-S(14))
        mB.BackgroundColor3=T.bg2; mB.Text="-"; mB.Font=Enum.Font.GothamBold
        mB.TextSize=S(8); mB.TextColor3=T.ac1; mB.BorderSizePixel=0; mB.AutoButtonColor=false
        Instance.new("UICorner",mB).CornerRadius=UDim.new(0,S(3))
        local pB=Instance.new("TextButton",box)
        pB.Size=UDim2.new(0,S(10),0,S(12)); pB.Position=UDim2.new(1,-S(11),1,-S(14))
        pB.BackgroundColor3=T.bg2; pB.Text="+"; pB.Font=Enum.Font.GothamBold
        pB.TextSize=S(8); pB.TextColor3=T.ac1; pB.BorderSizePixel=0; pB.AutoButtonColor=false
        Instance.new("UICorner",pB).CornerRadius=UDim.new(0,S(3))
        local curVal=initVal
        local function set(v)
            curVal=math.clamp(math.floor(v),minV,maxV); vl.Text=tostring(curVal); if onChange then onChange(curVal) end
        end
        mB.MouseButton1Click:Connect(function() set(curVal-step) end)
        pB.MouseButton1Click:Connect(function() set(curVal+step) end)
        for _,b in ipairs({mB,pB}) do
            b.MouseEnter:Connect(function() Tw(b,0.1,{BackgroundColor3=T.ac3,TextColor3=T.ac0}) end)
            b.MouseLeave:Connect(function() Tw(b,0.1,{BackgroundColor3=T.bg2,TextColor3=T.ac1}) end)
        end
        return vl, set
    end
    SBRadVal = MakeStatControl(-S(110),"DST",STEAL_DST,1,200,1,function(v) STEAL_DST=v; SaveConfig() end)
    SBSecVal = MakeStatControl(-S(56),"SPD",STEAL_SPD,1,200,1,function(v) STEAL_SPD=v; SaveConfig() end)

    local dotT=0; local lastLU=0
    statusBarConn = RunService.Heartbeat:Connect(function(dt)
        dotT=dotT+dt; if isSt then return end
        local hum=GetHum()
        local now=tick()
        if stealActive then
            for i,d in ipairs(sbDots) do d.BackgroundColor3=T.ac0; d.BackgroundTransparency=0.1+0.55*math.abs(math.sin(dotT*2.8-(i-1)*0.8)) end
            local prompt,dist,maxDist=findClosestStealAny()
            local speedOk=hum and hum.WalkSpeed>=STEAL_SPD
            local inRange=prompt and dist<=STEAL_DST
            if speedOk and inRange then
                Tw(SBFill,0.1,{Size=UDim2.new(math.clamp(1-(dist/STEAL_DST),0,1),0,1,0)})
                if now-lastLU>=0.12 then lastLU=now; SBStatus.Text="STEALING"; SBStatus.TextColor3=T.ac0 end
            else
                Tw(SBFill,0.15,{Size=UDim2.new(0,0,1,0)})
                if now-lastLU>=0.3 then lastLU=now; SBStatus.Text="SCANNING"; SBStatus.TextColor3=T.cyanDim end
            end
        else
            for _,d in ipairs(sbDots) do d.BackgroundColor3=inactive; d.BackgroundTransparency=0.5 end
            Tw(SBFill,0.15,{Size=UDim2.new(0,0,1,0)})
            if now-lastLU>=0.3 then lastLU=now; SBStatus.Text="IDLE"; SBStatus.TextColor3=txtMute end
        end
    end)

    local shortcutBar=nil
    if isMobile then
        shortcutBar=Instance.new("Frame",Screen)
        shortcutBar.Name="ShortcutBar"
        shortcutBar.Size=UDim2.new(0,S(200),1,-S(20))
        shortcutBar.Position=UDim2.new(1,-S(210),0,S(10))
        shortcutBar.BackgroundTransparency=1; shortcutBar.BorderSizePixel=0
        local noScLbl=Instance.new("TextLabel",shortcutBar)
        noScLbl.Size=UDim2.new(1,0,0,S(20)); noScLbl.Position=UDim2.new(0,0,0,0)
        noScLbl.BackgroundTransparency=1; noScLbl.Text=""
        noScLbl.Font=Enum.Font.Gotham; noScLbl.TextSize=S(9); noScLbl.TextColor3=txtMute
        shortcutBarRef=shortcutBar


        -- Save Position button (restores dragged positions next rebuild)
        local savePosBtn=Instance.new("TextButton",shortcutBar)
        savePosBtn.Size=UDim2.new(0,S(78),0,S(22))
        savePosBtn.Position=UDim2.new(0,S(4),1,-S(26))
        savePosBtn.BackgroundColor3=T.bg2; savePosBtn.BorderSizePixel=0; savePosBtn.ZIndex=25
        savePosBtn.Text="Save Pos"; savePosBtn.Font=Enum.Font.GothamBold
        savePosBtn.TextSize=S(9); savePosBtn.TextColor3=T.ac0; savePosBtn.AutoButtonColor=false
        Instance.new("UICorner",savePosBtn).CornerRadius=UDim.new(0,S(6))
        Instance.new("UIStroke",savePosBtn).Color=T.borderDim
        savePosBtn.MouseButton1Click:Connect(function()
            for _,ch in ipairs(shortcutBar:GetChildren()) do
                if ch.Name=="ShortcutBtn" then
                    local fid=ch:GetAttribute("FeatureId")
                    if fid then savedBtnPositions[fid]=ch.Position end
                end
            end
            -- Persist to file so positions survive rejoin
            pcall(function()
                if not writefile then return end
                local btnData={}
                for bid,bpos in pairs(savedBtnPositions) do
                    btnData[bid]={bpos.X.Scale,bpos.X.Offset,bpos.Y.Scale,bpos.Y.Offset}
                end
                local mainData=nil
                if savedMainPos then
                    mainData={savedMainPos.X.Scale,savedMainPos.X.Offset,savedMainPos.Y.Scale,savedMainPos.Y.Offset}
                end
                writefile("WsDuels_btnpos.json",game:GetService("HttpService"):JSONEncode({btns=btnData,main=mainData}))
            end)
            savePosBtn.Text="Saved!"; savePosBtn.TextColor3=T.ac0
            Tw(savePosBtn,0.15,{BackgroundColor3=T.acOff})
            task.delay(1.5,function()
                savePosBtn.Text="Save Pos"; Tw(savePosBtn,0.15,{BackgroundColor3=T.bg2})
            end)
        end)

        local labelMap={float="Float",autoR="Auto Right",autoL="Auto Left",aimbot="Aimbot",dropFling="Drop",
            antiFling="Anti Fling",antiRag="Anti Ragdoll",infJump="Inf Jump",jumpTpDown="Jump TPv",autoTpDown="Auto TP",spinBot="Spin Bot",unwalk="Unwalk",
            steal="Steal",stealSpd="Steal Spd",taunt="Taunt",autoGrab="Auto Grab",optimizer="Optimizer"}

        local function dispatchToggle(id)
            if id=="float" then
                floating=not floating; ssF(floating); FeatureStates.float=floating
                if not floating then local root=GetRoot(); if root then root.AssemblyLinearVelocity=Vector3.new(root.AssemblyLinearVelocity.X,0,root.AssemblyLinearVelocity.Z) end end
            elseif id=="autoR" then if patrolMode=="right" or waitingForCountdownR then stopPatrol() else startPatrol("right") end
            elseif id=="autoL" then if patrolMode=="left" or waitingForCountdownL then stopPatrol() else startPatrol("left") end
            elseif id=="aimbot" then batAimbotActive=not batAimbotActive; ssAim(batAimbotActive); FeatureStates.aimbot=batAimbotActive; if batAimbotActive then startBatAimbot() else stopBatAimbot() end
            elseif id=="dropFling" then doDrop(); ssDr(true); task.delay(0.5,function() ssDr(false) end)
            elseif id=="antiFling" then antiFlingActive=not antiFlingActive; ssAF(antiFlingActive); FeatureStates.antiFling=antiFlingActive; if antiFlingActive then startAntiFling() else stopAntiFling() end; SaveConfig()
            elseif id=="antiRag" then antiRagdollActive=not antiRagdollActive; ssARag(antiRagdollActive); FeatureStates.antiRag=antiRagdollActive; if antiRagdollActive then startAntiRagdoll() else stopAntiRagdoll() end; SaveConfig()
            elseif id=="infJump" then infJumpActive=not infJumpActive; ssIJ(infJumpActive); FeatureStates.infJump=infJumpActive; if infJumpActive then startInfJump() else stopInfJump() end; SaveConfig()
            elseif id=="jumpTpDown" then doJumpTpDown()
            elseif id=="autoTpDown" then autoTpDownActive=not autoTpDownActive; ssAutoTp(autoTpDownActive); FeatureStates.autoTpDown=autoTpDownActive; if autoTpDownActive then startAutoTpDown() else stopAutoTpDown() end; SaveConfig()
            elseif id=="spinBot" then spinActive=not spinActive; ssSp(spinActive); FeatureStates.spinBot=spinActive; if spinActive then startSpinBot() else stopSpinBot() end; SaveConfig()
            elseif id=="unwalk" then unwalkActive=not unwalkActive; ssUw(unwalkActive); FeatureStates.unwalk=unwalkActive; if unwalkActive then startUnwalk() else stopUnwalk() end; SaveConfig()
            elseif id=="steal" then stealActive=not stealActive; ssSt(stealActive); FeatureStates.steal=stealActive; if stealActive then startStealLoop() else stopStealLoop() end
            elseif id=="stealSpd" then stealSpeedActive=not stealSpeedActive; ssSspd(stealSpeedActive); FeatureStates.stealSpd=stealSpeedActive; if stealSpeedActive then startStealSpeed() else stopStealSpeed() end; SaveConfig()
            elseif id=="taunt" then
                tauntActive=not tauntActive; ssTnt(tauntActive); FeatureStates.taunt=tauntActive
                if tauntActive then tauntLoop=task.spawn(function() while tauntActive do pcall(function() local ch=game:GetService("TextChatService").TextChannels:FindFirstChild("RBXGeneral"); if ch then ch:SendAsync("/ws duels") end end); task.wait(0.5) end end)
                else if tauntLoop then task.cancel(tauntLoop); tauntLoop=nil end end; SaveConfig()
            elseif id=="autoGrab" then autoGrabActive=not autoGrabActive; ssGrab(autoGrabActive); FeatureStates.autoGrab=autoGrabActive; if autoGrabActive then startAutoGrab() else stopAutoGrab() end; SaveConfig()
            elseif id=="optimizer" then optimizerActive=not optimizerActive; ssOpt(optimizerActive); FeatureStates.optimizer=optimizerActive; if optimizerActive then enableOptimizer() else disableOptimizer() end; SaveConfig()
            elseif id=="autoTpDown" then autoTpDownActive=not autoTpDownActive; ssAutoTp(autoTpDownActive); FeatureStates.autoTpDown=autoTpDownActive; if autoTpDownActive then startAutoTpDown() else stopAutoTpDown() end; SaveConfig()
            end
        end

        RebuildShortcutBar=function()
            -- clear old shortcut buttons
            for _,c in ipairs(shortcutBar:GetChildren()) do
                if c.Name=="ShortcutBtn" then c:Destroy() end
            end
            noScLbl.Visible=#MobileShortcuts==0
            local n=#MobileShortcuts; if n==0 then return end
            local BTN_W=S(180); local BTN_H2=S(44); local GAP2=S(8)
            local totalH=n*BTN_H2+(n-1)*GAP2
            local startY=S(4)
            for i,id in ipairs(MobileShortcuts) do
                -- Outer container Frame (holds button + drag dot, is what moves)
                local container=Instance.new("Frame",shortcutBar)
                container.Name="ShortcutBtn"
                container:SetAttribute("FeatureId", id)
                container.Size=UDim2.new(0,BTN_W,0,BTN_H2)
                local _defPos=UDim2.new(0,0,0,startY+(i-1)*(BTN_H2+GAP2))
                container.Position=savedBtnPositions[id] or _defPos
                container.BackgroundTransparency=1; container.BorderSizePixel=0

                -- Main toggle button (takes up full container minus drag dot area)
                local btn=Instance.new("TextButton",container)
                btn.Size=UDim2.new(1,0,1,0)
                btn.Position=UDim2.new(0,0,0,0)
                local isOn=FeatureStates[id] or false
                btn.BackgroundColor3=isOn and T.bg1 or T.bg0
                btn.BorderSizePixel=0; btn.AutoButtonColor=false; btn.Text=""
                Instance.new("UICorner",btn).CornerRadius=UDim.new(0,S(12))
                local bS2=Instance.new("UIStroke",btn)
                bS2.Color=isOn and T.ac0 or T.borderDim
                bS2.Thickness=2; bS2.Transparency=isOn and 0 or 0.3

                -- Floating dots background (same as main GUI)
                MakeDotsBackground(btn)

                -- Status dot (left side indicator)
                local statusDot=Instance.new("Frame",btn)
                statusDot.Size=UDim2.new(0,S(7),0,S(7))
                statusDot.Position=UDim2.new(0,S(10),0.5,-S(3))
                statusDot.BackgroundColor3=isOn and T.ac0 or T.borderDim
                statusDot.BorderSizePixel=0
                Instance.new("UICorner",statusDot).CornerRadius=UDim.new(1,0)

                -- Label
                local lbl3=Instance.new("TextLabel",btn)
                lbl3.Size=UDim2.new(1,-S(40),1,0); lbl3.Position=UDim2.new(0,S(22),0,0)
                lbl3.BackgroundTransparency=1
                lbl3.Text=labelMap[id] or id; lbl3.Font=Enum.Font.GothamBold
                lbl3.TextSize=S(12); lbl3.TextColor3=txtPrime
                lbl3.TextXAlignment=Enum.TextXAlignment.Center

                -- DRAG DOT  - top-right corner, only this moves the button
                local DOT_SZ=S(18)
                local dragDot=Instance.new("TextButton",container)
                dragDot.Name="DragDot"
                dragDot.Size=UDim2.new(0,DOT_SZ,0,DOT_SZ)
                dragDot.Position=UDim2.new(1,-DOT_SZ+S(2),0,-S(2))
                dragDot.BackgroundColor3=T.ac1
                dragDot.BackgroundTransparency=0.25
                dragDot.Text=""; dragDot.BorderSizePixel=0
                dragDot.ZIndex=20; dragDot.AutoButtonColor=false
                Instance.new("UICorner",dragDot).CornerRadius=UDim.new(1,0)
                -- Three tiny lines inside dot to hint it's draggable
                for di=1,3 do
                    local line=Instance.new("Frame",dragDot)
                    line.Size=UDim2.new(0.55,0,0,S(1))
                    line.Position=UDim2.new(0.22,0,0,(di-1)*S(4)+S(3))
                    line.BackgroundColor3=T.bg0; line.BackgroundTransparency=0.2
                    line.BorderSizePixel=0
                    Instance.new("UICorner",line).CornerRadius=UDim.new(1,0)
                end

                -- Drag logic: only dragDot moves the whole container
                local isDragging=false; local dragStartPos; local containerStart
                dragDot.InputBegan:Connect(function(inp)
                    if inp.UserInputType==Enum.UserInputType.Touch or inp.UserInputType==Enum.UserInputType.MouseButton1 then
                        isDragging=true
                        dragStartPos=inp.Position
                        containerStart=container.Position
                    end
                end)
                UIS.InputChanged:Connect(function(inp)
                    if not isDragging then return end
                    if inp.UserInputType==Enum.UserInputType.Touch or inp.UserInputType==Enum.UserInputType.MouseMovement then
                        local dx=inp.Position.X-dragStartPos.X
                        local dy=inp.Position.Y-dragStartPos.Y
                        container.Position=UDim2.new(
                            containerStart.X.Scale, containerStart.X.Offset+dx,
                            containerStart.Y.Scale, containerStart.Y.Offset+dy
                        )
                    end
                end)
                UIS.InputEnded:Connect(function(inp)
                    if inp.UserInputType==Enum.UserInputType.Touch or inp.UserInputType==Enum.UserInputType.MouseButton1 then
                        if isDragging then
                            -- Auto-save position the moment the user lifts their finger
                            savedBtnPositions[id]=container.Position
                        end
                        isDragging=false
                    end
                end)

                -- Toggle on button click (not drag dot)
                btn.MouseButton1Click:Connect(function()
                    dispatchToggle(id)
                    local on2=FeatureStates[id] or false
                    if id=="dropFling" or id=="jumpTpDown" then on2=false end
                    Tw(btn,0.15,{BackgroundColor3=on2 and T.bg1 or T.bg0})
                    Tw(bS2,0.15,{Color=on2 and T.ac0 or T.borderDim,Transparency=on2 and 0 or 0.3})
                    Tw(statusDot,0.15,{BackgroundColor3=on2 and T.ac0 or T.borderDim})
                end)
            end
        end
        RebuildShortcutBar()
    end

    -- BUTTON CONNECTIONS
    bF.MouseButton1Click:Connect(function()
        floating=not floating; ssF(floating); FeatureStates.float=floating
        if not floating then local root=GetRoot(); if root then root.AssemblyLinearVelocity=Vector3.new(root.AssemblyLinearVelocity.X,0,root.AssemblyLinearVelocity.Z) end end
    end)
    bAR.MouseButton1Click:Connect(function()
        if patrolMode=="right" or waitingForCountdownR then stopPatrol(); return end
        local ok,label=pcall(function() return player.PlayerGui.DuelsMachineTopFrame.DuelsMachineTopFrame.Timer.Label end)
        if ok and label and isTimerCountdown(label) then waitingForCountdownR=true; local l=bAR:FindFirstChild("Label"); if l then l.Text="Waiting..." end
        else startPatrol("right") end
    end)
    bAL.MouseButton1Click:Connect(function()
        if patrolMode=="left" or waitingForCountdownL then stopPatrol(); return end
        local ok,label=pcall(function() return player.PlayerGui.DuelsMachineTopFrame.DuelsMachineTopFrame.Timer.Label end)
        if ok and label and isTimerCountdown(label) then waitingForCountdownL=true; local l=bAL:FindFirstChild("Label"); if l then l.Text="Waiting..." end
        else startPatrol("left") end
    end)
    bAim.MouseButton1Click:Connect(function()
        batAimbotActive=not batAimbotActive; ssAim(batAimbotActive); FeatureStates.aimbot=batAimbotActive
        if batAimbotActive then startBatAimbot() else stopBatAimbot() end
    end)
    bDr.MouseButton1Click:Connect(function()
        doDrop()
        ssDr(true); task.delay(0.5,function() ssDr(false) end)
    end)
    bAF.MouseButton1Click:Connect(function()
        antiFlingActive=not antiFlingActive; ssAF(antiFlingActive); FeatureStates.antiFling=antiFlingActive
        if antiFlingActive then startAntiFling() else stopAntiFling() end; SaveConfig()
    end)
    bARag.MouseButton1Click:Connect(function()
        antiRagdollActive=not antiRagdollActive; ssARag(antiRagdollActive); FeatureStates.antiRag=antiRagdollActive
        if antiRagdollActive then startAntiRagdoll() else stopAntiRagdoll() end; SaveConfig()
    end)
    bIJ.MouseButton1Click:Connect(function()
        infJumpActive=not infJumpActive; ssIJ(infJumpActive); FeatureStates.infJump=infJumpActive
        if infJumpActive then startInfJump() else stopInfJump() end; SaveConfig()
    end)
    bJTp.MouseButton1Click:Connect(function()
        -- Jump TP Down: manual one-shot, no toggle state
    end)
    bAtp.MouseButton1Click:Connect(function()
        autoTpDownActive=not autoTpDownActive; ssAutoTp(autoTpDownActive); FeatureStates.autoTpDown=autoTpDownActive
        if autoTpDownActive then startAutoTpDown() else stopAutoTpDown() end; SaveConfig()
    end)
    bSp.MouseButton1Click:Connect(function()
        spinActive=not spinActive; ssSp(spinActive); FeatureStates.spinBot=spinActive
        if spinActive then startSpinBot() else stopSpinBot() end; SaveConfig()
    end)
    bUw.MouseButton1Click:Connect(function()
        unwalkActive=not unwalkActive; ssUw(unwalkActive); FeatureStates.unwalk=unwalkActive
        if unwalkActive then startUnwalk() else stopUnwalk() end; SaveConfig()
    end)
    bSt.MouseButton1Click:Connect(function()
        stealActive=not stealActive; ssSt(stealActive); FeatureStates.steal=stealActive
        if stealActive then startStealLoop() else stopStealLoop() end
    end)
    bSspd.MouseButton1Click:Connect(function()
        stealSpeedActive=not stealSpeedActive; ssSspd(stealSpeedActive); FeatureStates.stealSpd=stealSpeedActive
        if stealSpeedActive then startStealSpeed() else stopStealSpeed() end; SaveConfig()
    end)
    bTnt.MouseButton1Click:Connect(function()
        tauntActive=not tauntActive; ssTnt(tauntActive); FeatureStates.taunt=tauntActive
        if tauntActive then tauntLoop=task.spawn(function() while tauntActive do pcall(function() local ch=game:GetService("TextChatService").TextChannels:FindFirstChild("RBXGeneral"); if ch then ch:SendAsync("/ws duels") end end); task.wait(0.5) end end)
        else if tauntLoop then task.cancel(tauntLoop); tauntLoop=nil end end; SaveConfig()
    end)
    bGrab.MouseButton1Click:Connect(function()
        autoGrabActive=not autoGrabActive; ssGrab(autoGrabActive); FeatureStates.autoGrab=autoGrabActive
        if autoGrabActive then startAutoGrab() else stopAutoGrab() end; SaveConfig()
    end)
    bOpt.MouseButton1Click:Connect(function()
        optimizerActive=not optimizerActive; ssOpt(optimizerActive); FeatureStates.optimizer=optimizerActive
        if optimizerActive then enableOptimizer() else disableOptimizer() end; SaveConfig()
    end)

    if not isMobile then
        globalKeybindConn = UIS.InputBegan:Connect(function(inp,gpe)
            if gpe then return end
            if inp.KeyCode==HideKeybind then
                local minimized2=Main.Size.Y.Offset<=HDR+5
                MinBtn.Text=minimized2 and "-" or "+"
                Tw(Main,0.3,{Size=UDim2.new(0,W,0,minimized2 and FULL_H or HDR)})
                return
            end
            if inp.UserInputType~=Enum.UserInputType.Keyboard then return end
            for id,kc in pairs(FeatureKeybinds) do
                if inp.KeyCode==kc then
                    if id=="float" then floating=not floating; ssF(floating); FeatureStates.float=floating; if not floating then local root=GetRoot(); if root then root.AssemblyLinearVelocity=Vector3.new(root.AssemblyLinearVelocity.X,0,root.AssemblyLinearVelocity.Z) end end
                    elseif id=="autoR" then if patrolMode=="right" or waitingForCountdownR then stopPatrol() else startPatrol("right") end
                    elseif id=="autoL" then if patrolMode=="left" or waitingForCountdownL then stopPatrol() else startPatrol("left") end
                    elseif id=="aimbot" then batAimbotActive=not batAimbotActive; ssAim(batAimbotActive); FeatureStates.aimbot=batAimbotActive; if batAimbotActive then startBatAimbot() else stopBatAimbot() end
                    elseif id=="dropFling" then doDrop(); ssDr(true); task.delay(0.5,function() ssDr(false) end)
                    elseif id=="antiFling" then antiFlingActive=not antiFlingActive; ssAF(antiFlingActive); FeatureStates.antiFling=antiFlingActive; if antiFlingActive then startAntiFling() else stopAntiFling() end; SaveConfig()
                    elseif id=="antiRag" then antiRagdollActive=not antiRagdollActive; ssARag(antiRagdollActive); FeatureStates.antiRag=antiRagdollActive; if antiRagdollActive then startAntiRagdoll() else stopAntiRagdoll() end; SaveConfig()
                    elseif id=="infJump" then infJumpActive=not infJumpActive; ssIJ(infJumpActive); FeatureStates.infJump=infJumpActive; if infJumpActive then startInfJump() else stopInfJump() end; SaveConfig()
                    elseif id=="jumpTpDown" then -- manual one-shot, no keybind action needed
                    elseif id=="autoTpDown" then autoTpDownActive=not autoTpDownActive; ssAutoTp(autoTpDownActive); FeatureStates.autoTpDown=autoTpDownActive; if autoTpDownActive then startAutoTpDown() else stopAutoTpDown() end; SaveConfig()
                    elseif id=="spinBot" then spinActive=not spinActive; ssSp(spinActive); FeatureStates.spinBot=spinActive; if spinActive then startSpinBot() else stopSpinBot() end; SaveConfig()
                    elseif id=="unwalk" then unwalkActive=not unwalkActive; ssUw(unwalkActive); FeatureStates.unwalk=unwalkActive; if unwalkActive then startUnwalk() else stopUnwalk() end; SaveConfig()
                    elseif id=="steal" then stealActive=not stealActive; ssSt(stealActive); FeatureStates.steal=stealActive; if stealActive then startStealLoop() else stopStealLoop() end
                    elseif id=="stealSpd" then stealSpeedActive=not stealSpeedActive; ssSspd(stealSpeedActive); FeatureStates.stealSpd=stealSpeedActive; if stealSpeedActive then startStealSpeed() else stopStealSpeed() end; SaveConfig()
                    elseif id=="taunt" then tauntActive=not tauntActive; ssTnt(tauntActive); FeatureStates.taunt=tauntActive; if tauntActive then tauntLoop=task.spawn(function() while tauntActive do pcall(function() local ch=game:GetService("TextChatService").TextChannels:FindFirstChild("RBXGeneral"); if ch then ch:SendAsync("/ws duels") end end); task.wait(0.5) end end) else if tauntLoop then task.cancel(tauntLoop); tauntLoop=nil end end; SaveConfig()
                    elseif id=="autoGrab" then autoGrabActive=not autoGrabActive; ssGrab(autoGrabActive); FeatureStates.autoGrab=autoGrabActive; if autoGrabActive then startAutoGrab() else stopAutoGrab() end; SaveConfig()
                    elseif id=="optimizer" then optimizerActive=not optimizerActive; ssOpt(optimizerActive); FeatureStates.optimizer=optimizerActive; if optimizerActive then enableOptimizer() else disableOptimizer() end; SaveConfig()

                    end
                end
            end
        end)
    end

    local minimized=false
    Tw(Main,0.45,{Size=UDim2.new(0,W,0,FULL_H)})
    MinBtn.MouseButton1Click:Connect(function()
        minimized=not minimized; MinBtn.Text=minimized and "+" or "-"
        Tw(Main,0.3,{Size=UDim2.new(0,W,0,minimized and HDR or FULL_H)})
    end)

    local function onTextChanged(label)
        local ok,number=isCountdownNum(label.Text)
        if ok and number==1 then
            if waitingForCountdownL then task.wait(AUTO_START_DELAY); waitingForCountdownL=false; startPatrol("left") end
            if waitingForCountdownR then task.wait(AUTO_START_DELAY); waitingForCountdownR=false; startPatrol("right") end
        end
    end
    task.spawn(function()
        local ok,label=pcall(function() return player.PlayerGui.DuelsMachineTopFrame.DuelsMachineTopFrame.Timer.Label end)
        if ok and label then onTextChanged(label); label:GetPropertyChangedSignal("Text"):Connect(function() onTextChanged(label) end) end
    end)

    player.CharacterAdded:Connect(function()
        task.wait(1)
        patrolMode="none"; currentWaypoint=1; waitingForCountdownL=false; waitingForCountdownR=false
        floating=false; batAimbotActive=false
        ssF(false); ssAR(false); ssAL(false); ssAim(false)
        FeatureStates.float=false; FeatureStates.autoR=false; FeatureStates.autoL=false; FeatureStates.aimbot=false
        stopBatAimbot()
        if antiRagdollActive then startAntiRagdoll() end
        if infJumpActive     then startInfJump()     end
        if autoTpDownActive  then startAutoTpDown()  end
        if unwalkActive      then startUnwalk()      end
        if stealSpeedActive  then startStealSpeed()  end
        if spinActive        then startSpinBot()     end
        if antiFlingActive   then startAntiFling()   end
        if stealActive       then startStealLoop()   end
        if autoGrabActive    then startAutoGrab()    end
        -- Restart aimbot on new character (AlignOrientation was on old character)
        if batAimbotActive then task.spawn(startBatAimbot) end
    end)

    heartbeatConn=RunService.Heartbeat:Connect(updateWalking)
    Screen.Destroying:Connect(function()
        if heartbeatConn then heartbeatConn:Disconnect(); heartbeatConn=nil end
        if statusBarConn then statusBarConn:Disconnect(); statusBarConn=nil end
    end)

    print("[WS Duels]: "..(isMobile and "Mobile" or "PC").." | Scale:"..guiScale.." | Theme:"..T.name)
end

-- ============================================================
--  MODE SELECT
-- ============================================================
pcall(function() ParentUI:FindFirstChild("WsDuels"):Destroy() end)
pcall(function() ParentUI:FindFirstChild("ND_Select"):Destroy() end)

local SelGui=Instance.new("ScreenGui")
SelGui.Name="ND_Select"; SelGui.ResetOnSpawn=false
SelGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; SelGui.Parent=ParentUI

local Backdrop=Instance.new("Frame",SelGui)
Backdrop.Size=UDim2.new(1,0,1,0); Backdrop.BackgroundColor3=Color3.fromRGB(2,3,8)
Backdrop.BackgroundTransparency=1; Backdrop.BorderSizePixel=0

local CW,CH=310,300
local Card=Instance.new("Frame",SelGui)
Card.Size=UDim2.new(0,CW,0,0); Card.Position=UDim2.new(0.5,-CW/2,0.5,0)
Card.BackgroundColor3=T.bg0; Card.BorderSizePixel=0; Card.ClipsDescendants=true
Instance.new("UICorner",Card).CornerRadius=UDim.new(0,18)
local CS=Instance.new("UIStroke",Card); CS.Color=T.border; CS.Thickness=1.4; CS.Transparency=0.2
local CG=Instance.new("UIGradient",Card)
CG.Color=ColorSequence.new{ColorSequenceKeypoint.new(0,T.bg1),ColorSequenceKeypoint.new(1,T.bg0)}; CG.Rotation=135
MakeDotsBackground(Card)

local SelTopBar=Instance.new("Frame",Card)
SelTopBar.Size=UDim2.new(1,0,0,2); SelTopBar.BackgroundColor3=T.ac1; SelTopBar.BorderSizePixel=0
local STBG=Instance.new("UIGradient",SelTopBar)
STBG.Color=ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(0,0,0)),ColorSequenceKeypoint.new(0.4,T.ac0),ColorSequenceKeypoint.new(0.6,T.ac0),ColorSequenceKeypoint.new(1,Color3.fromRGB(0,0,0))}

local LBig=Instance.new("Frame",Card)
LBig.Size=UDim2.new(0,48,0,48); LBig.Position=UDim2.new(0.5,-24,0,18)
LBig.BackgroundColor3=T.acOff; LBig.BorderSizePixel=0
Instance.new("UICorner",LBig).CornerRadius=UDim.new(0,12)
local LBS2=Instance.new("UIStroke",LBig); LBS2.Color=T.ac1; LBS2.Thickness=1.5; LBS2.Transparency=0.15
local LIcon=Instance.new("TextLabel",LBig)
LIcon.Size=UDim2.new(1,0,1,0); LIcon.BackgroundTransparency=1; LIcon.Text="KZ"
LIcon.Font=Enum.Font.GothamBlack; LIcon.TextSize=19; LIcon.TextColor3=T.ac0

local SelTitle=Instance.new("TextLabel",Card)
SelTitle.Size=UDim2.new(1,0,0,26); SelTitle.Position=UDim2.new(0,0,0,74)
SelTitle.BackgroundTransparency=1; SelTitle.Text="WS DUELS"
SelTitle.Font=Enum.Font.GothamBlack; SelTitle.TextSize=22; SelTitle.TextColor3=T.ac0

local SDW=Instance.new("Frame",Card)
SDW.Size=UDim2.new(0.8,0,0,1); SDW.Position=UDim2.new(0.1,0,0,106)
SDW.BackgroundColor3=T.ac2; SDW.BackgroundTransparency=0.35; SDW.BorderSizePixel=0
Instance.new("UICorner",SDW).CornerRadius=UDim.new(1,0)

local function MakeModeCard(yPos,iconTxt,titleTxt)
    local btn=Instance.new("TextButton",Card)
    btn.Size=UDim2.new(1,-28,0,66); btn.Position=UDim2.new(0,14,0,yPos)
    btn.BackgroundColor3=T.bg2; btn.Text=""; btn.BorderSizePixel=0; btn.AutoButtonColor=false
    Instance.new("UICorner",btn).CornerRadius=UDim.new(0,13)
    local bS=Instance.new("UIStroke",btn); bS.Color=T.borderDim; bS.Thickness=1.2; bS.Transparency=0.4
    local bG=Instance.new("UIGradient",btn)
    bG.Color=ColorSequence.new{ColorSequenceKeypoint.new(0,T.bg2),ColorSequenceKeypoint.new(1,T.bg1)}; bG.Rotation=90
    local lBar=Instance.new("Frame",btn)
    lBar.Size=UDim2.new(0,3,0.5,0); lBar.Position=UDim2.new(0,0,0.25,0)
    lBar.BackgroundColor3=T.ac0; lBar.BackgroundTransparency=0.25; lBar.BorderSizePixel=0
    Instance.new("UICorner",lBar).CornerRadius=UDim.new(1,0)
    local ic=Instance.new("Frame",btn)
    ic.Size=UDim2.new(0,40,0,40); ic.Position=UDim2.new(0,12,0.5,-20)
    ic.BackgroundColor3=T.acOff; ic.BackgroundTransparency=0.3; ic.BorderSizePixel=0
    Instance.new("UICorner",ic).CornerRadius=UDim.new(1,0)
    local icS=Instance.new("UIStroke",ic); icS.Color=T.ac1; icS.Thickness=1; icS.Transparency=0.3
    local iL=Instance.new("TextLabel",ic)
    iL.Size=UDim2.new(1,0,1,0); iL.BackgroundTransparency=1; iL.Text=iconTxt
    iL.Font=Enum.Font.GothamBlack; iL.TextSize=13; iL.TextColor3=T.ac0
    local tl=Instance.new("TextLabel",btn)
    tl.Size=UDim2.new(1,-72,1,0); tl.Position=UDim2.new(0,62,0,0)
    tl.BackgroundTransparency=1; tl.Text=titleTxt; tl.Font=Enum.Font.GothamBold
    tl.TextSize=14; tl.TextColor3=txtPrime; tl.TextXAlignment=Enum.TextXAlignment.Left
    local ar=Instance.new("TextLabel",btn)
    ar.Size=UDim2.new(0,18,1,0); ar.Position=UDim2.new(1,-22,0,0)
    ar.BackgroundTransparency=1; ar.Text=">"; ar.Font=Enum.Font.GothamBold
    ar.TextSize=20; ar.TextColor3=T.ac0; ar.TextTransparency=0.5
    btn.MouseEnter:Connect(function() Tw(btn,0.14,{BackgroundColor3=T.bg3}); Tw(bS,0.14,{Transparency=0.05,Color=T.ac0}); Tw(ar,0.14,{TextTransparency=0}) end)
    btn.MouseLeave:Connect(function() Tw(btn,0.14,{BackgroundColor3=T.bg2}); Tw(bS,0.14,{Transparency=0.4,Color=T.borderDim}); Tw(ar,0.14,{TextTransparency=0.5}) end)
    return btn
end

local MobileBtn=MakeModeCard(118,"MB","Mobile Mode")
local PCBtn    =MakeModeCard(196,"PC","PC Mode")

Tw(Card,0.42,{Size=UDim2.new(0,CW,0,CH),Position=UDim2.new(0.5,-CW/2,0.5,-CH/2)},Enum.EasingStyle.Back)

local function Launch(mobile)
    isMobile=mobile
    Tw(Card,0.26,{Size=UDim2.new(0,CW,0,0),Position=UDim2.new(0.5,-CW/2,0.5,0)})
    Tw(Backdrop,0.26,{BackgroundTransparency=1})
    task.delay(0.3,function() pcall(function() SelGui:Destroy() end); task.wait(1); BuildMainGUI() end)
end

MobileBtn.MouseButton1Click:Connect(function() Launch(true) end)
PCBtn.MouseButton1Click:Connect(function() Launch(false) end)

getgenv().StopWsDuels=function()
    pcall(function() SelGui:Destroy() end)
    pcall(function() ParentUI:FindFirstChild("WsDuels"):Destroy() end)
    if heartbeatConn    then heartbeatConn:Disconnect()    end
    if statusBarConn    then statusBarConn:Disconnect()    end
    if globalKeybindConn then globalKeybindConn:Disconnect() end
    stopAutoTpDown()
end