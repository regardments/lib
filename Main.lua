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
    Title = 'Bloodlines | Regardments',
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
    ['Quality Of Life'] = Window:AddTab('Quality Of Life'),
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
local ESPMaxDistance = 7500

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
    bb.MaxDistance = ESPMaxDistance
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
        
        -- Actualizar MaxDistance del BillboardGui
        if e.bb.MaxDistance ~= ESPMaxDistance then
            e.bb.MaxDistance = ESPMaxDistance
        end
        
        -- Ocultar si está fuera del rango
        if dist > ESPMaxDistance then
            e.bb.Enabled = false
            hideDrawings(e)
            continue
        end
        
        local hp       = math.clamp(humanoid.Health, 0, humanoid.MaxHealth)
        local maxHp    = humanoid.MaxHealth
        local pct      = maxHp > 0 and (hp / maxHp) or 0

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

            local closeEnough = dist <= 150

            local showBox = ESPBoxEnabled and closeEnough
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

            local showHp = ESPHealthBarEnabled and closeEnough
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
--  MOVEMENT / UTILITY LOGIC
-- ──────────────────────────────────────────────
local UIS = game:GetService('UserInputService')

-- No Fall Damage
local noFallDmgConn = nil
local function setNoFallDamage(enabled)
    local function patchChar(char)
        local h = char:WaitForChild('Humanoid', 5)
        if not h then return end
        -- Use FallingDown state disable + HealthChanged immunity approach
        h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, not enabled)
        if enabled then
            -- Zero out fall damage by keeping health on landing
            local lastHp = h.Health
            h.HealthChanged:Connect(function(hp)
                if h:GetState() == Enum.HumanoidStateType.Landed and hp < lastHp then
                    h.Health = lastHp
                end
                lastHp = h.Health
            end)
        end
    end
    if enabled then
        local char = LocalPlayer.Character
        if char then patchChar(char) end
        noFallDmgConn = LocalPlayer.CharacterAdded:Connect(patchChar)
    else
        if noFallDmgConn then noFallDmgConn:Disconnect(); noFallDmgConn = nil end
        local char = LocalPlayer.Character
        if char then
            local h = char:FindFirstChildOfClass('Humanoid')
            if h then h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true) end
        end
    end
end

-- WalkSpeed
local walkspeedConn = nil
local function setWalkSpeed(enabled, speed)
    if walkspeedConn then walkspeedConn:Disconnect(); walkspeedConn = nil end
    local function applySpeed(char)
        local h = char:FindFirstChildOfClass('Humanoid')
        if h then h.WalkSpeed = enabled and speed or 16 end
    end
    if enabled then
        local char = LocalPlayer.Character
        if char then applySpeed(char) end
        walkspeedConn = LocalPlayer.CharacterAdded:Connect(applySpeed)
    else
        local char = LocalPlayer.Character
        if char then applySpeed(char) end
    end
end

-- Fly
local flyConn = nil
local flyBodyVel = nil
local flyBodyGyro = nil
local flyEnabled = false
local FLY_SPEED = 50

local function stopFly()
    flyEnabled = false
    if flyBodyVel  then flyBodyVel:Destroy();  flyBodyVel  = nil end
    if flyBodyGyro then flyBodyGyro:Destroy(); flyBodyGyro = nil end
    if flyConn     then flyConn:Disconnect();  flyConn     = nil end
    local char = LocalPlayer.Character
    if char then
        local root = char:FindFirstChild('HumanoidRootPart')
        if root then root.AssemblyLinearVelocity = Vector3.zero end
        local h = char:FindFirstChildOfClass('Humanoid')
        if h then h:ChangeState(Enum.HumanoidStateType.GettingUp) end
    end
end

local function startFly(speed)
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild('HumanoidRootPart')
    local hum  = char:FindFirstChildOfClass('Humanoid')
    if not root or not hum then return end

    flyEnabled = true
    hum:ChangeState(Enum.HumanoidStateType.Flying)

    flyBodyVel = Instance.new('BodyVelocity')
    flyBodyVel.MaxForce = Vector3.new(1e5,1e5,1e5)
    flyBodyVel.Velocity  = Vector3.zero
    flyBodyVel.Parent    = root

    flyBodyGyro = Instance.new('BodyGyro')
    flyBodyGyro.MaxTorque = Vector3.new(1e5,1e5,1e5)
    flyBodyGyro.P          = 1e4
    flyBodyGyro.CFrame     = root.CFrame
    flyBodyGyro.Parent     = root

    flyConn = RunService.RenderStepped:Connect(function()
        if not flyEnabled then return end
        local cam = workspace.CurrentCamera
        local dir = Vector3.zero
        if UIS:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.Space)    then dir = dir + Vector3.yAxis end
        if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.yAxis end
        if dir.Magnitude > 0 then dir = dir.Unit end
        flyBodyVel.Velocity  = dir * speed
        flyBodyGyro.CFrame   = cam.CFrame
    end)
end

local function setFly(enabled, speed)
    if enabled then startFly(speed) else stopFly() end
end

-- NoClip
local noclipConn = nil
local noclipOriginalCollision = {}

local function saveCollisionState(char)
    noclipOriginalCollision = {}
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA('BasePart') then
            noclipOriginalCollision[p] = p.CanCollide
        end
    end
end

local function restoreCollisionState(char)
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA('BasePart') then
            local original = noclipOriginalCollision[p]
            if original ~= nil then
                p.CanCollide = original
            end
        end
    end
    noclipOriginalCollision = {}
end

local function setNoClip(enabled)
    if enabled then
        local char = LocalPlayer.Character
        if char then saveCollisionState(char) end
        noclipConn = RunService.Stepped:Connect(function()
            local char = LocalPlayer.Character
            if not char then return end
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA('BasePart') then
                    p.CanCollide = false
                end
            end
        end)
    else
        if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
        local char = LocalPlayer.Character
        if char then restoreCollisionState(char) end
    end
end

-- No Kill Bricks
local noKillBricksConn = nil
local voidParts = {}

local function setNoKillBricks(enabled)
    if enabled then
        -- Desactivar CanTouch en todos los Void parts
        voidParts = {}
        for _, child in ipairs(workspace:GetDescendants()) do
            if child:IsA('BasePart') and string.lower(child.Name) == 'void' then
                child.CanTouch = false
                table.insert(voidParts, child)
            end
        end
        -- Monitorear nuevos void parts que aparezcan
        noKillBricksConn = workspace.DescendantAdded:Connect(function(child)
            if child:IsA('BasePart') and string.lower(child.Name) == 'void' then
                child.CanTouch = false
                table.insert(voidParts, child)
            end
        end)
    else
        if noKillBricksConn then noKillBricksConn:Disconnect(); noKillBricksConn = nil end
        -- Restaurar CanTouch
        for _, part in ipairs(voidParts) do
            if part and part.Parent then
                part.CanTouch = true
            end
        end
        voidParts = {}
    end
end

-- ──────────────────────────────────────────────
--  CHAKRA SENSE SPOOF
-- ──────────────────────────────────────────────
local chakraSpoofValue = nil
local chakraSpoofConn  = nil

local function startChakraSpoof()
    local Cooldowns = game:GetService('ReplicatedStorage'):FindFirstChild('Cooldowns')
    if not Cooldowns then Library:Notify('Cooldowns folder not found!', 3) return end
    local myPC = Cooldowns:FindFirstChild(LocalPlayer.Name)
    if not myPC then Library:Notify('Your cooldowns folder not found!', 3) return end

    chakraSpoofValue = myPC:FindFirstChild('Chakra Sense')
    if not chakraSpoofValue then
        chakraSpoofValue = Instance.new('NumberValue')
        chakraSpoofValue.Name   = 'Chakra Sense'
        chakraSpoofValue.Parent = myPC
    end

    chakraSpoofConn = RunService.Heartbeat:Connect(function()
        if chakraSpoofValue and chakraSpoofValue.Parent then
            chakraSpoofValue.Value = os.time() + 9999
        end
    end)
end

local function stopChakraSpoof()
    if chakraSpoofConn then chakraSpoofConn:Disconnect(); chakraSpoofConn = nil end
    if chakraSpoofValue and chakraSpoofValue.Parent then
        chakraSpoofValue:Destroy(); chakraSpoofValue = nil
    end
end

-- Spectate a player by changing CameraSubject (like real Chakra Sense)
local spectateTarget = nil
local originalCamSubject = nil
local originalCamType    = nil

local function spectatePlayer(player)
    if not player then return end
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass('Humanoid')
    if not hum then return end

    local cam = workspace.CurrentCamera
    originalCamSubject = cam.CameraSubject
    originalCamType    = cam.CameraType
    spectateTarget     = player

    cam.CameraSubject = hum
    cam.CameraType    = Enum.CameraType.Custom
end

local function stopSpectate()
    if not spectateTarget then return end
    local cam = workspace.CurrentCamera
    local myChar = LocalPlayer.Character
    cam.CameraSubject = (myChar and myChar:FindFirstChildOfClass('Humanoid')) or originalCamSubject
    cam.CameraType    = originalCamType or Enum.CameraType.Custom
    spectateTarget = nil
end

-- ──────────────────────────────────────────────
--  CHAKRA SENSE DETECT (who is sensing YOU)
-- ──────────────────────────────────────────────
local chakraSenseDetectConn = nil
local notifiedSensers = {}

local function startChakraSenseDetect()
    local Cooldowns = game:GetService('ReplicatedStorage'):FindFirstChild('Cooldowns')
    if not Cooldowns then return end

    chakraSenseDetectConn = RunService.Heartbeat:Connect(function()
        for _, p in ipairs(Players:GetPlayers()) do
            if p == LocalPlayer then continue end
            local pc = Cooldowns:FindFirstChild(p.Name)
            if pc then
                local cs = pc:FindFirstChild('Chakra Sense')
                -- They are actively sensing (value = future timestamp)
                if cs and cs.Value > os.time() then
                    if not notifiedSensers[p.Name] then
                        notifiedSensers[p.Name] = true
                        Library:Notify(p.Name .. ' is Chakra Sensing you!', 4)
                    end
                else
                    notifiedSensers[p.Name] = nil
                end
            end
        end
    end)
end

local function stopChakraSenseDetect()
    if chakraSenseDetectConn then
        chakraSenseDetectConn:Disconnect()
        chakraSenseDetectConn = nil
    end
    notifiedSensers = {}
end

-- ──────────────────────────────────────────────
--  UI - MAIN TAB
-- ──────────────────────────────────────────────
local MainGroupLeft  = Tabs.Main:AddLeftGroupbox('Movement')
local MainGroupRight = Tabs.Main:AddRightGroupbox('Utility')

-- WalkSpeed
MainGroupLeft:AddToggle('WalkSpeedEnabled', {
    Text = 'WalkSpeed', Default = false,
    Callback = function(v)
        setWalkSpeed(v, Options.WalkSpeedValue.Value)
    end
}):AddKeyPicker('WalkSpeedKey', { Default = 'None', NoUI = false, Text = 'WalkSpeed keybind', Mode = 'Toggle',
    Callback = function(v)
        Toggles.WalkSpeedEnabled:SetValue(v)
    end
})

local WalkSpeedDepbox = MainGroupLeft:AddDependencyBox()
WalkSpeedDepbox:AddSlider('WalkSpeedValue', {
    Text = 'Speed', Default = 50, Min = 16, Max = 200, Rounding = 0,
    Callback = function(v)
        if Toggles.WalkSpeedEnabled.Value then setWalkSpeed(true, v) end
    end
})
WalkSpeedDepbox:SetupDependencies({{Toggles.WalkSpeedEnabled, true}})

-- Fly
MainGroupLeft:AddToggle('FlyEnabled', {
    Text = 'Fly', Default = false,
    Callback = function(v)
        setFly(v, Options.FlySpeedValue.Value)
    end
}):AddKeyPicker('FlyKey', { Default = 'None', NoUI = false, Text = 'Fly keybind', Mode = 'Toggle',
    Callback = function(v)
        Toggles.FlyEnabled:SetValue(v)
    end
})

local FlySpeedDepbox = MainGroupLeft:AddDependencyBox()
FlySpeedDepbox:AddSlider('FlySpeedValue', {
    Text = 'Fly Speed', Default = 50, Min = 10, Max = 300, Rounding = 0,
    Callback = function(v)
        FLY_SPEED = v
        if Toggles.FlyEnabled.Value then setFly(true, v) end
    end
})
FlySpeedDepbox:SetupDependencies({{Toggles.FlyEnabled, true}})

-- NoClip
MainGroupLeft:AddToggle('NoClipEnabled', {
    Text = 'No Clip', Default = false,
    Callback = function(v) setNoClip(v) end
}):AddKeyPicker('NoClipKey', { Default = 'None', NoUI = false, Text = 'NoClip keybind', Mode = 'Toggle',
    Callback = function(v)
        Toggles.NoClipEnabled:SetValue(v)
    end
})

-- No Fall Damage
MainGroupLeft:AddToggle('NoFallDamage', {
    Text = 'No Fall Damage', Default = false,
    Tooltip = 'Disables fall damage',
    Callback = function(v) setNoFallDamage(v) end
})

-- No Kill Bricks (MOVED TO MAIN TAB - UTILITY)
MainGroupRight:AddToggle('NoKillBricks', {
    Text = 'No Kill Bricks',
    Default = false,
    Tooltip = 'Prevents instant kill from lava and kill bricks',
    Callback = function(v) setNoKillBricks(v) end
})

-- Respawn
-- Chakra Sense (spoof)
MainGroupRight:AddToggle('ChakraSenseToggle', {
    Text = 'Chakra Sense',
    Default = false,
    Tooltip = 'Spoof Chakra Sense so you appear as using it to others',
    Callback = function(v)
        if v then startChakraSpoof() else stopChakraSpoof() end
        ToggleChakraSense(v)
    end
})

-- Chakra Sense Spectate — click directo en la lista de jugadores del juego
-- Hookear los PlayerTemplates de la lista nativa del juego
local playerListConnections = {}

local function hookPlayerTemplate(template)
    if playerListConnections[template] then return end
    local nameLabel = template:FindFirstChild('PlayerName')
    if not nameLabel then return end

    local conn = template.MouseButton1Click:Connect(function()
        if not Toggles.ChakraSenseToggle.Value then return end
        local pname = nameLabel.Text
        local target = Players:FindFirstChild(pname)
        if not target or target == LocalPlayer then return end

        if spectateTarget == target then
            stopSpectate()
            Library:Notify('Stopped Chakra Sense', 2)
        else
            spectatePlayer(target)
            Library:Notify('Chakra Sensing: ' .. pname, 2)
        end
    end)
    playerListConnections[template] = conn
end

local function hookAllPlayerTemplates()
    local gui = LocalPlayer.PlayerGui:FindFirstChild('ClientGui')
    if not gui then return end
    local mainframe = gui:FindFirstChild('Mainframe')
    if not mainframe then return end
    local playerList = mainframe:FindFirstChild('PlayerList')
    if not playerList then return end
    local list = playerList:FindFirstChild('List')
    if not list then return end

    for _, child in ipairs(list:GetChildren()) do
        if child:IsA('ImageButton') and child.Name == 'PlayerTemplate' then
            hookPlayerTemplate(child)
        end
    end

    list.ChildAdded:Connect(function(child)
        if child:IsA('ImageButton') and child.Name == 'PlayerTemplate' then
            task.wait(0.1)
            hookPlayerTemplate(child)
        end
    end)
end

task.spawn(function()
    task.wait(2)
    hookAllPlayerTemplates()
end)

-- Detect who is sensing you
MainGroupRight:AddToggle('ChakraSenseDetect', {
    Text = 'Sense Detector',
    Default = false,
    Tooltip = 'Notify when someone is Chakra Sensing you',
    Callback = function(v)
        if v then startChakraSenseDetect() else stopChakraSenseDetect() end
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

ESPGroup:AddSlider('ESPMaxDistance', {
    Text = 'Max Distance',
    Default = 7500,
    Min = 100,
    Max = 7500,
    Rounding = 0,
    Suffix = ' studs',
    Tooltip = 'Maximum distance to show ESP',
    Callback = function(Value)
        ESPMaxDistance = Value
    end
})

-- ──────────────────────────────────────────────
--  QUALITY OF LIFE
-- ──────────────────────────────────────────────
local DataEvent    = game:GetService('ReplicatedStorage'):WaitForChild('Events'):WaitForChild('DataEvent')
local DataFunction = game:GetService('ReplicatedStorage'):WaitForChild('Events'):WaitForChild('DataFunction')
local wipeConfirm  = false
local wipeConfirmTimer = nil

local QoLGroupLeft  = Tabs['Quality Of Life']:AddLeftGroupbox('Character')
local QoLGroupRight = Tabs['Quality Of Life']:AddRightGroupbox('Account')

QoLGroupLeft:AddButton({
    Text = 'Respawn',
    Func = function()
        local char = LocalPlayer.Character
        local h = char and char:FindFirstChildOfClass('Humanoid')
        if h then h.Health = 0 end
    end,
    Tooltip = 'Kill and respawn your character'
})

QoLGroupLeft:AddButton({
    Text = 'Open Wipe Shop',
    Func = function()
        local gui = LocalPlayer.PlayerGui:FindFirstChild('ClientGui')
        local mainframe = gui and gui:FindFirstChild('Mainframe')
        local rest = mainframe and mainframe:FindFirstChild('Rest')
        if rest then
            local df = rest:FindFirstChild('DestroyFrame')
            if df then df.Visible = true end
        end
    end,
    Tooltip = 'Opens the Wipe Shop UI'
})

QoLGroupLeft:AddButton({
    Text = 'Unlock Burrow',
    Func = function()
        DataFunction:InvokeServer('UnlockSkill', 'Burrow')
        task.wait(0.1)
        DataFunction:InvokeServer('UnlockSkill', 'Burrow Teleport')
        Library:Notify('Unlocked Burrow & Burrow Teleport!', 3)
    end,
    Tooltip = 'Unlocks Burrow and Burrow Teleport skills'
})

QoLGroupRight:AddDropdown('ReincarnationGender', {
    Text = 'Gender',
    Values = {'Male', 'Female'},
    Default = 1,
})

QoLGroupRight:AddButton({
    Text = 'Wipe',
    Func = function()
        if not wipeConfirm then
            wipeConfirm = true
            local gender = Options.ReincarnationGender.Value or 'Male'
            Library:Notify('Click again to wipe as ' .. gender .. '!', 3)
            if wipeConfirmTimer then task.cancel(wipeConfirmTimer) end
            wipeConfirmTimer = task.delay(3, function()
                wipeConfirm = false
            end)
        else
            wipeConfirm = false
            if wipeConfirmTimer then task.cancel(wipeConfirmTimer) end
            local gender = Options.ReincarnationGender.Value or 'Male'
            DataEvent:FireServer('NewGame')
            task.wait(0.5)
            DataFunction:InvokeServer('RequestReincarnation', gender)
            Library:Notify('Wiped and created ' .. gender .. ' slot!', 3)
        end
    end,
    Tooltip = 'Wipe and create new slot with selected gender (double click)'
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
    if AutoParryConnection then AutoParryConnection:Disconnect(); AutoParryConnection = nil end
    if ChakraSenseConnection then ChakraSenseConnection:Disconnect(); ChakraSenseConnection = nil end
    if noFallDmgConn then noFallDmgConn:Disconnect(); noFallDmgConn = nil end
    if walkspeedConn then walkspeedConn:Disconnect(); walkspeedConn = nil end
    if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
    if noKillBricksConn then noKillBricksConn:Disconnect(); noKillBricksConn = nil end
    stopChakraSenseDetect()
    stopChakraSpoof()
    stopSpectate()
    stopFly()
    -- limpiar hooks de la lista de jugadores
    for template, conn in pairs(playerListConnections) do
        conn:Disconnect()
    end
    playerListConnections = {}
    local char = LocalPlayer.Character
    if char then
        local h = char:FindFirstChildOfClass('Humanoid')
        if h then h.WalkSpeed = 16 end
    end
    ParriedPlayers = {}
    for char in pairs(ESPs) do removeESP(char) end
    Library.Unloaded = true
end)

-- ──────────────────────────────────────────────
--  MAIN HEARTBEAT
-- ──────────────────────────────────────────────
RunService.Heartbeat:Connect(function()
    if Library.Unloaded then return end
    updateESPHeartbeat()
end)
