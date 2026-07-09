-- ──────────────────────────────────────────────
--  LIBRARY
-- ──────────────────────────────────────────────
local repo = 'https://raw.githubusercontent.com/regardments/lib/main/'

local Library      = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'ThemeManager.lua'))()
local SaveManager  = loadstring(game:HttpGet(repo .. 'SaveManager.lua'))()

-- ──────────────────────────────────────────────
--  WINDOW
-- ──────────────────────────────────────────────
local Window = Library:CreateWindow({
    Title = 'Bloodlines',
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0.2
})

-- ──────────────────────────────────────────────
--  TABS
-- ──────────────────────────────────────────────
local Tabs = {
    Main = Window:AddTab('Main'),
    Combat = Window:AddTab('Combat'),
    Teleports = Window:AddTab('Teleports'),
    ESP = Window:AddTab('ESP'),
    ['UI Settings'] = Window:AddTab('UI Settings'),
}

-- ──────────────────────────────────────────────
--  SERVICES / GLOBALS
-- ──────────────────────────────────────────────
local Players = game:GetService('Players')
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService('Workspace')
local RunService = game:GetService('RunService')
local VirtualInputManager = game:GetService('VirtualInputManager')
local Camera = workspace.CurrentCamera
local ReplicatedStorage = game:GetService('ReplicatedStorage')

-- ──────────────────────────────────────────────
--  CHAKRA SENSE
-- ──────────────────────────────────────────────
local ChakraSenseEnabled = false
local ChakraSenseConnection = nil
local ChakraSenseCount = 0

local function CountChakraSenseUsers()
    local count = 0
    local Cooldowns = ReplicatedStorage:FindFirstChild("Cooldowns")
    if not Cooldowns then return 0 end
    
    for _, Player in pairs(Players:GetPlayers()) do
        local PlayerCooldowns = Cooldowns:FindFirstChild(Player.Name)
        if PlayerCooldowns then
            local ChakraSense = PlayerCooldowns:FindFirstChild("Chakra Sense")
            if ChakraSense then
                count = count + 1
            end
        end
    end
    
    return count
end

local function UpdateChakraSenseWatermark()
    if not ChakraSenseEnabled then
        Library:SetWatermark("")
        return
    end
    
    ChakraSenseCount = CountChakraSenseUsers()
    local WatermarkText = "Chakra Sense Users: " .. ChakraSenseCount
    Library:SetWatermark(WatermarkText)
end

local function ToggleChakraSense(State)
    ChakraSenseEnabled = State
    
    if ChakraSenseEnabled then
        UpdateChakraSenseWatermark()
        if not ChakraSenseConnection then
            ChakraSenseConnection = RunService.Heartbeat:Connect(function()
                UpdateChakraSenseWatermark()
            end)
        end
        Library:SetWatermarkVisibility(true)
    else
        if ChakraSenseConnection then
            ChakraSenseConnection:Disconnect()
            ChakraSenseConnection = nil
        end
        Library:SetWatermark("")
        Library:SetWatermarkVisibility(false)
    end
end

-- ──────────────────────────────────────────────
--  AUTO PARRY
-- ──────────────────────────────────────────────
local AutoParryEnabled = false
local AutoParryConnection = nil
local ParryCooldown = false
local PARRY_DISTANCE = 20
local ParriedPlayers = {}
local ParryResetDelay = 1

-- LISTA DE ANIMACIONES
local AnimationIDs = {
    "11330795390",
    "83279463673214",
    "6360969229",
    "11330785444",
    "6904596529"
}

-- CONFIGURACIÓN POR ANIMACIÓN
local AnimationConfigs = {}

for _, AnimID in pairs(AnimationIDs) do
    AnimationConfigs[AnimID] = {
        Enabled = true,
        Delay = 0.15,
        HoldTime = 1.5
    }
end

local SelectedAnimation = AnimationIDs[1]

local function ResetParriedPlayer(PlayerName)
    task.wait(ParryResetDelay)
    ParriedPlayers[PlayerName] = nil
end

local function PressF(HoldTime)
    if ParryCooldown then return end
    
    ParryCooldown = true
    
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
    task.wait(HoldTime or 1.0)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
    
    task.wait(0.5)
    ParryCooldown = false
end

local function IsAttacking(Character)
    if not Character then return false end
    
    local Humanoid = Character:FindFirstChild('Humanoid')
    if not Humanoid then return false end
    
    local LocalCharacter = LocalPlayer.Character
    if not LocalCharacter then return false end
    
    local RootPart = LocalCharacter:FindFirstChild('HumanoidRootPart')
    if not RootPart then return false end
    
    local TargetRoot = Character:FindFirstChild('HumanoidRootPart')
    if not TargetRoot then return false end
    
    local Distance = (RootPart.Position - TargetRoot.Position).Magnitude
    if Distance > PARRY_DISTANCE then return false end
    
    local Animator = Humanoid:FindFirstChild('Animator')
    if not Animator then return false end
    
    for _, Track in pairs(Animator:GetPlayingAnimationTracks()) do
        local Animation = Track.Animation
        if Animation then
            local AnimId = Animation.AnimationId
            if AnimId then
                for AnimID, Config in pairs(AnimationConfigs) do
                    if Config.Enabled and string.find(AnimId, AnimID) then
                        return true, Config.Delay, Config.HoldTime, AnimID
                    end
                end
            end
        end
    end
    
    return false
end

local function CheckForAttackingEnemies()
    if not AutoParryEnabled then return end
    
    for _, Player in pairs(Players:GetPlayers()) do
        if Player ~= LocalPlayer then
            local Character = Player.Character
            if Character then
                local IsAttacking, Delay, HoldTime, AnimID = IsAttacking(Character)
                if IsAttacking then
                    if not ParriedPlayers[Player.Name] then
                        ParriedPlayers[Player.Name] = true
                        task.wait(Delay or 0.15)
                        PressF(HoldTime or 1.5)
                        task.spawn(function()
                            ResetParriedPlayer(Player.Name)
                        end)
                        break
                    end
                else
                    ParriedPlayers[Player.Name] = nil
                end
            end
        end
    end
end

local function AutoParryLoop()
    CheckForAttackingEnemies()
end

local function ToggleAutoParry(State)
    AutoParryEnabled = State
    
    if AutoParryEnabled then
        ParriedPlayers = {}
        if not AutoParryConnection then
            AutoParryConnection = RunService.Heartbeat:Connect(AutoParryLoop)
        end
    else
        if AutoParryConnection then
            AutoParryConnection:Disconnect()
            AutoParryConnection = nil
        end
        ParriedPlayers = {}
    end
end

-- ──────────────────────────────────────────────
--  TELEPORT FUNCTIONS
-- ──────────────────────────────────────────────
local function getRoot()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild('HumanoidRootPart')
end

local function tpTo(pos)
    local r = getRoot()
    if r then
        r.CFrame = CFrame.new(pos)
    end
end

local function TeleportToNPC(name)
    local n = workspace:FindFirstChild(name)
    if not n then return end
    local t = n:FindFirstChild('HumanoidRootPart') or n:FindFirstChildWhichIsA('BasePart')
    if t then
        tpTo(t.Position + Vector3.new(0, 5, 0))
    end
end

local function TeleportToWeapon(name)
    local w = workspace:FindFirstChild(name)
    if not w then return end
    local t = w:FindFirstChild('HumanoidRootPart') or w:FindFirstChildWhichIsA('BasePart')
    if t then
        tpTo(t.Position + Vector3.new(0, 5, 0))
    end
end

local function TeleportToChakraPoint(pt)
    local p = pt:FindFirstChildWhichIsA('BasePart')
    if p then
        tpTo(p.Position)
    end
end

local function TeleportToClothing(m)
    local c = m:FindFirstChild('Clothing')
    local torso = c and c:FindFirstChild('Torso')
    local p = (torso and torso:FindFirstChildWhichIsA('BasePart')) or m:FindFirstChildWhichIsA('BasePart')
    if p then
        tpTo(p.Position + Vector3.new(0, 5, 0))
    end
end

local function TeleportToPlayer(player)
    local c = player.Character
    local t = c and c:FindFirstChild('HumanoidRootPart')
    if t then
        tpTo(t.Position + Vector3.new(0, 0, 5))
    end
end

-- ──────────────────────────────────────────────
--  ESP LOGIC (ORIGINAL CON DRAWING LINES)
-- ──────────────────────────────────────────────
local C_WHITE  = Color3.new(1, 1, 1)
local C_BLACK  = Color3.new(0, 0, 0)

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local ESPs      = {}
local visCache  = {}
local frameIdx  = 0
local ESPEnabled = false
local ESPBoxEnabled = true
local ESPHealthBarEnabled = true
local ESPNamesEnabled = true

local function hpColor(pct)
    -- Transición suave de verde (100%) a rojo (0%)
    local red = (1 - pct) * 255
    local green = pct * 255
    local blue = 0
    
    return Color3.fromRGB(
        math.floor(red),
        math.floor(green),
        blue
    )
end

local function createESP(character)
    if ESPs[character] then return end
    local root     = character:FindFirstChild('HumanoidRootPart')
    local humanoid = character:FindFirstChildOfClass('Humanoid')
    if not root or not humanoid then return end

    local bb = Instance.new('BillboardGui')
    bb.Name = 'ESP'
    bb.Adornee = root
    bb.Size = UDim2.new(0, 150, 0, 55)
    bb.StudsOffset = Vector3.new(0, 3.2, 0)
    bb.AlwaysOnTop = true
    bb.Enabled = false
    bb.Parent = root

    local lbl = Instance.new('TextLabel')
    lbl.Size = UDim2.fromScale(1, 1)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = C_WHITE
    lbl.TextStrokeTransparency = 0
    lbl.TextScaled = false
    lbl.TextSize = 13
    lbl.Font = Enum.Font.Code
    lbl.Parent = bb

    local lines = {}
    for i = 1, 4 do
        local l = Drawing.new('Line')
        l.Visible = false
        l.Color = C_WHITE
        l.Thickness = 1.5
        l.ZIndex = 2
        lines[i] = l
    end

    local hpBorderL = Drawing.new('Line')
    hpBorderL.Visible = false
    hpBorderL.Color = C_WHITE
    hpBorderL.Thickness = 1
    hpBorderL.ZIndex = 1

    local hpBorderR = Drawing.new('Line')
    hpBorderR.Visible = false
    hpBorderR.Color = C_WHITE
    hpBorderR.Thickness = 1
    hpBorderR.ZIndex = 1

    local hpBorderT = Drawing.new('Line')
    hpBorderT.Visible = false
    hpBorderT.Color = C_WHITE
    hpBorderT.Thickness = 1
    hpBorderT.ZIndex = 1

    local hpBorderB = Drawing.new('Line')
    hpBorderB.Visible = false
    hpBorderB.Color = C_WHITE
    hpBorderB.Thickness = 1
    hpBorderB.ZIndex = 1

    local hpBar = Drawing.new('Line')
    hpBar.Visible = false
    hpBar.Color = Color3.fromRGB(0, 255, 0)
    hpBar.Thickness = 3
    hpBar.ZIndex = 2

    ESPs[character] = {
        root = root,
        humanoid = humanoid,
        bb = bb,
        lbl = lbl,
        lines = lines,
        hpBorderL = hpBorderL,
        hpBorderR = hpBorderR,
        hpBorderT = hpBorderT,
        hpBorderB = hpBorderB,
        hpBar = hpBar,
    }
end

local function removeESP(char)
    local e = ESPs[char]
    if not e then return end
    e.bb:Destroy()
    for _, l in ipairs(e.lines) do
        l:Remove()
    end
    e.hpBorderL:Remove()
    e.hpBorderR:Remove()
    e.hpBorderT:Remove()
    e.hpBorderB:Remove()
    e.hpBar:Remove()
    ESPs[char] = nil
    visCache[char] = nil
end

local function hideDrawings(e)
    for _, l in ipairs(e.lines) do
        l.Visible = false
    end
    e.hpBorderL.Visible = false
    e.hpBorderR.Visible = false
    e.hpBorderT.Visible = false
    e.hpBorderB.Visible = false
    e.hpBar.Visible = false
end

local function getBox2D(root, humanoid)
    local pos  = root.Position
    local hipH = humanoid.HipHeight
    local top  = hipH + 1.2
    local bot  = -(hipH + 0.5)
    local h    = 1.2

    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    local any = false

    for _, dx in ipairs({h, -h}) do
        for _, dy in ipairs({top, bot}) do
            for _, dz in ipairs({h, -h}) do
                local sp = Camera:WorldToViewportPoint(
                    Vector3.new(pos.X + dx, pos.Y + dy, pos.Z + dz)
                )
                if sp.Z > 0 then
                    any = true
                    if sp.X < minX then minX = sp.X end
                    if sp.Y < minY then minY = sp.Y end
                    if sp.X > maxX then maxX = sp.X end
                    if sp.Y > maxY then maxY = sp.Y end
                end
            end
        end
    end

    if not any or (maxX - minX) < 2 or (maxY - minY) < 2 then
        return nil
    end
    return minX, minY, maxX, maxY
end

local function updateESPHeartbeat()
    local localChar = LocalPlayer.Character
    if not localChar then return end
    local localRoot = localChar:FindFirstChild('HumanoidRootPart')
    if not localRoot then return end

    if not ESPEnabled then
        for _, e in pairs(ESPs) do
            e.bb.Enabled = false
            hideDrawings(e)
        end
        return
    end

    frameIdx = frameIdx + 1
    local doRaycast = (frameIdx % 4 == 0)
    rayParams.FilterDescendantsInstances = {localChar}

    local active = {}

    for _, model in ipairs(workspace:GetChildren()) do
        if not model:IsA('Model') then continue end
        if model == localChar then continue end
        if not Players:FindFirstChild(model.Name) then continue end

        local e = ESPs[model]
        if not e then
            createESP(model)
            e = ESPs[model]
            if not e then continue end
        end

        if not e.root.Parent then
            removeESP(model)
            continue
        end
        active[model] = true

        local root     = e.root
        local humanoid = e.humanoid
        local dist     = (root.Position - localRoot.Position).Magnitude
        local hp       = math.clamp(humanoid.Health, 0, humanoid.MaxHealth)
        local maxHp    = humanoid.MaxHealth
        local pct      = maxHp > 0 and (hp / maxHp) or 0

        if doRaycast then
            local origin = Camera.CFrame.Position
            local result = workspace:Raycast(origin, root.Position - origin, rayParams)
            visCache[model] = (result == nil)
        end

        local showNames = ESPNamesEnabled
        e.bb.Enabled = showNames
        if showNames then
            e.lbl.Text = string.format('[%s] [%dm]\n[%d/%d] [%d%%]',
                model.Name, math.floor(dist), math.floor(hp), math.floor(maxHp), math.floor(pct * 100))
            e.lbl.TextSize = math.floor(14 - 4 * math.clamp((dist - 10) / 290, 0, 1))
        end

        local x1, y1, x2, y2 = getBox2D(root, humanoid)
        if x1 then
            x1 = x1 - 2
            y1 = y1 - 2
            x2 = x2 + 2
            y2 = y2 + 2

            local showBox = ESPBoxEnabled
            local bl = e.lines
            local boxCol = C_WHITE
            for _, l in ipairs(bl) do
                l.Color = boxCol
                l.Visible = showBox
            end
            if showBox then
                bl[1].From = Vector2.new(x1, y1)
                bl[1].To = Vector2.new(x2, y1)
                bl[2].From = Vector2.new(x1, y2)
                bl[2].To = Vector2.new(x2, y2)
                bl[3].From = Vector2.new(x1, y1)
                bl[3].To = Vector2.new(x1, y2)
                bl[4].From = Vector2.new(x2, y1)
                bl[4].To = Vector2.new(x2, y2)
            end

            local showHp = ESPHealthBarEnabled
            e.hpBorderL.Visible = showHp
            e.hpBorderR.Visible = showHp
            e.hpBorderT.Visible = showHp
            e.hpBorderB.Visible = showHp
            e.hpBar.Visible = showHp
            if showHp then
                local bx = x1 - 6
                local bh = y2 - y1
                e.hpBorderL.From = Vector2.new(bx - 2, y1)
                e.hpBorderL.To = Vector2.new(bx - 2, y2)
                e.hpBorderR.From = Vector2.new(bx + 2, y1)
                e.hpBorderR.To = Vector2.new(bx + 2, y2)
                e.hpBorderT.From = Vector2.new(bx - 2, y1)
                e.hpBorderT.To = Vector2.new(bx + 2, y1)
                e.hpBorderB.From = Vector2.new(bx - 2, y2)
                e.hpBorderB.To = Vector2.new(bx + 2, y2)
                local fillTop = y2 - bh * pct + 1
                local fillBot = y2 - 1
                if fillTop > fillBot then
                    fillTop = fillBot
                end
                e.hpBar.From = Vector2.new(bx, fillTop)
                e.hpBar.To = Vector2.new(bx, fillBot)
                e.hpBar.Color = hpColor(pct)
                e.hpBar.Thickness = 2
            end
        else
            hideDrawings(e)
        end
    end

    for char in pairs(ESPs) do
        if not char.Parent or not active[char] then
            removeESP(char)
        end
    end
end

-- ──────────────────────────────────────────────
--  UI - MAIN TAB
-- ──────────────────────────────────────────────
local MainGroup = Tabs.Main:AddLeftGroupbox('Main')

MainGroup:AddToggle('ChakraSenseToggle', {
    Text = 'Chakra Sense',
    Default = false,
    Tooltip = 'Show Chakra Sense users count in watermark',
    Callback = function(Value)
        ToggleChakraSense(Value)
    end
})

-- ──────────────────────────────────────────────
--  UI - COMBAT TAB
-- ──────────────────────────────────────────────
local CombatGroup = Tabs.Combat:AddLeftGroupbox('Auto Parry')

CombatGroup:AddToggle('AutoParryToggle', {
    Text = 'Auto Parry',
    Default = false,
    Tooltip = 'Automatically parry when enemy attacks within the set distance',
    Callback = function(Value)
        ToggleAutoParry(Value)
    end
})

CombatGroup:AddSlider('ParryDistance', {
    Text = 'Detection Distance',
    Default = 20,
    Min = 5,
    Max = 50,
    Rounding = 0,
    Suffix = ' studs',
    Tooltip = 'Distance to detect enemy attacks',
    Callback = function(Value)
        PARRY_DISTANCE = Value
    end
})

CombatGroup:AddSlider('ParryResetDelay', {
    Text = 'Parry Reset Delay',
    Default = 1,
    Min = 0.5,
    Max = 3,
    Rounding = 1,
    Suffix = ' s',
    Tooltip = 'Time to wait before allowing another parry on the same player',
    Callback = function(Value)
        ParryResetDelay = Value
    end
})

-- Animation Config
local AnimConfigGroup = Tabs.Combat:AddRightGroupbox('Animation Config')

AnimConfigGroup:AddDropdown('AnimationSelect', {
    Text = 'Select Animation',
    Values = AnimationIDs,
    Multi = false,
    Default = 1,
    Tooltip = 'Select an animation to configure',
    Callback = function(Value)
        SelectedAnimation = Value
        local Config = AnimationConfigs[SelectedAnimation]
        if Config then
            Options.AnimDelay:SetValue(Config.Delay)
            Options.AnimHold:SetValue(Config.HoldTime)
            Options.AnimToggle:SetValue(Config.Enabled)
        end
    end
})

AnimConfigGroup:AddToggle('AnimToggle', {
    Text = 'Enabled',
    Default = true,
    Tooltip = 'Enable/disable detection for selected animation',
    Callback = function(Value)
        if SelectedAnimation then
            AnimationConfigs[SelectedAnimation].Enabled = Value
        end
    end
})

AnimConfigGroup:AddSlider('AnimDelay', {
    Text = 'Delay',
    Default = 0.15,
    Min = 0.0,
    Max = 1.0,
    Rounding = 2,
    Suffix = ' s',
    Tooltip = 'Delay after detecting this animation',
    Callback = function(Value)
        if SelectedAnimation then
            AnimationConfigs[SelectedAnimation].Delay = Value
        end
    end
})

AnimConfigGroup:AddSlider('AnimHold', {
    Text = 'Hold Time',
    Default = 1.5,
    Min = 0.5,
    Max = 3.0,
    Rounding = 1,
    Suffix = ' s',
    Tooltip = 'How long to hold F for this animation',
    Callback = function(Value)
        if SelectedAnimation then
            AnimationConfigs[SelectedAnimation].HoldTime = Value
        end
    end
})

-- ──────────────────────────────────────────────
--  UI - TELEPORTS TAB
-- ──────────────────────────────────────────────
-- Chakra Points
local ChakraGroup = Tabs.Teleports:AddLeftGroupbox('Chakra Points')
local cpts = workspace:FindFirstChild('ChakraPoints')
if cpts then
    local pts = cpts:GetChildren()
    table.sort(pts, function(a, b)
        local na, nb = a:FindFirstChild('PointName'), b:FindFirstChild('PointName')
        return na and nb and na.Value < nb.Value or false
    end)
    for _, pt in ipairs(pts) do
        local pn = pt:FindFirstChild('PointName')
        if pn then
            ChakraGroup:AddButton({
                Text = pn.Value,
                Func = function()
                    TeleportToChakraPoint(pt)
                end
            })
        end
    end
else
    ChakraGroup:AddLabel('No ChakraPoints found', true)
end

-- NPCs
local NPCGroup = Tabs.Teleports:AddLeftGroupbox('NPCs')
for _, n in ipairs({'Might Guy', 'Danzo', 'Crabuto', 'Hyuga Elder'}) do
    NPCGroup:AddButton({
        Text = n,
        Func = function()
            TeleportToNPC(n)
        end
    })
end

-- Players
local PlayersGroup = Tabs.Teleports:AddLeftGroupbox('Players')
local selectedPlayer = nil
local playerNames = {}
local playerList = {}

local function rebuildPlayerList()
    playerNames = {}
    playerList = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            table.insert(playerNames, p.Name)
            table.insert(playerList, p)
        end
    end
    if Options.TpPlayerSelect then
        Options.TpPlayerSelect:SetValues(playerNames)
        Options.TpPlayerSelect:SetValue(nil)
        selectedPlayer = nil
    end
end
rebuildPlayerList()

PlayersGroup:AddDropdown('TpPlayerSelect', {
    Text = 'Player',
    Values = playerNames,
    Default = 1,
    Callback = function(val)
        for i, n in ipairs(playerNames) do
            if n == val then
                selectedPlayer = playerList[i]
                break
            end
        end
    end,
})

PlayersGroup:AddButton({
    Text = 'Teleport',
    Func = function()
        if selectedPlayer then
            TeleportToPlayer(selectedPlayer)
        end
    end
})

Players.PlayerAdded:Connect(function()
    task.wait(0.5)
    rebuildPlayerList()
end)

Players.PlayerRemoving:Connect(function()
    task.wait(0.5)
    rebuildPlayerList()
end)

-- Armors
local ArmorGroup = Tabs.Teleports:AddRightGroupbox('Armors')
local clothingModels = {}
for _, ch in ipairs(workspace:GetChildren()) do
    if ch.Name == 'ClothingModel' then
        table.insert(clothingModels, ch)
    end
end
table.sort(clothingModels, function(a, b)
    return a.Name < b.Name
end)
if #clothingModels > 0 then
    for _, m in ipairs(clothingModels) do
        local label = m.Name
        local torso = m:FindFirstChild('Clothing') and m.Clothing:FindFirstChild('Torso')
        local b = torso and torso:FindFirstChild('Buyable')
        if b and b:IsA('StringValue') and b.Value ~= '' then
            label = b.Value
        end
        ArmorGroup:AddButton({
            Text = label,
            Func = function()
                TeleportToClothing(m)
            end
        })
    end
else
    ArmorGroup:AddLabel('No armors found', true)
end

-- Weapons
local WeaponsGroup = Tabs.Teleports:AddRightGroupbox('Weapons')
for _, w in ipairs({
    {'Hallowed Kusanagi', 'Hallowed Kusanagi'},
    {'Jingle Bell Staff', 'Jingle Bell Staff'},
    {'Onyx Zabunagi', 'Onyx Zabunagi1'},
    {'Golden Zabunagi', 'Golden Zabunagi'},
    {'Golden Halberd', 'Golden Halberd'},
    {'Golden Asumai', 'Golden Asumai'},
    {'Golden Kunai', 'Golden Kunai'},
    {'Silver Resanagi', 'Silver Resanagi1'},
    {'Silver Halberd', 'Silver Halberd1'},
    {'Silver Asumai', 'Silver Asumai'},
    {'Silver Kunai', 'Silver Kunai3'},
}) do
    WeaponsGroup:AddButton({
        Text = w[1],
        Func = function()
            TeleportToWeapon(w[2])
        end
    })
end

-- ──────────────────────────────────────────────
--  UI - ESP TAB
-- ──────────────────────────────────────────────
local ESPGroup = Tabs.ESP:AddLeftGroupbox('ESP')

ESPGroup:AddToggle('ESPEnabled', {
    Text = 'ESP',
    Default = false,
    Callback = function(Value)
        ESPEnabled = Value
    end
})

ESPGroup:AddToggle('ESPBox', {
    Text = 'Bounding Box',
    Default = true,
    Callback = function(Value)
        ESPBoxEnabled = Value
    end
})

ESPGroup:AddToggle('ESPHealthBar', {
    Text = 'Health Bar',
    Default = true,
    Callback = function(Value)
        ESPHealthBarEnabled = Value
    end
})

ESPGroup:AddToggle('ESPNames', {
    Text = 'Name / Distance',
    Default = true,
    Callback = function(Value)
        ESPNamesEnabled = Value
    end
})

-- ──────────────────────────────────────────────
--  UI SETTINGS
-- ──────────────────────────────────────────────
local MenuGroup = Tabs['UI Settings']:AddLeftGroupbox('Menu')

MenuGroup:AddButton('Unload', function()
    Library:Unload()
end)

MenuGroup:AddLabel('Menu keybind'):AddKeyPicker('MenuKeybind', {
    Default = 'RightShift',
    NoUI = true,
    Text = 'Menu keybind',
})

Library.ToggleKeybind = Options.MenuKeybind

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({'MenuKeybind'})
ThemeManager:SetFolder('BloodlinesHub')
SaveManager:SetFolder('BloodlinesHub/bloodlines')
SaveManager:BuildConfigSection(Tabs['UI Settings'])
ThemeManager:ApplyToTab(Tabs['UI Settings'])
SaveManager:LoadAutoloadConfig()

Library:OnUnload(function()
    if AutoParryConnection then
        AutoParryConnection:Disconnect()
        AutoParryConnection = nil
    end
    if ChakraSenseConnection then
        ChakraSenseConnection:Disconnect()
        ChakraSenseConnection = nil
    end
    ParriedPlayers = {}
    for char in pairs(ESPs) do
        removeESP(char)
    end
    Library.Unloaded = true
end)

-- ──────────────────────────────────────────────
--  MAIN HEARTBEAT
-- ──────────────────────────────────────────────
RunService.Heartbeat:Connect(function()
    if Library.Unloaded then return end
    updateESPHeartbeat()
end)
