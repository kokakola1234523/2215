local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local SAFE_HEIGHT = 100
local currentTarget = nil
local aimbotConnection = nil

-- 1. ពិនិត្យអាវុធ (Gun/Knife)
local function getMyWeaponStatus()
    local myChar = LocalPlayer.Character
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    
    local hasGun = (backpack and backpack:FindFirstChild("Gun")) or (myChar and myChar:FindFirstChild("Gun"))
    local hasKnife = (backpack and backpack:FindFirstChild("Knife")) or (myChar and myChar:FindFirstChild("Knife"))
    
    return hasGun ~= nil, hasKnife ~= nil
end

-- 2. Fast Auto Equip Functions
local function equipTool(toolName)
    local myChar = LocalPlayer.Character
    if not myChar then return nil end
    local humanoid = myChar:FindFirstChildOfClass("Humanoid")
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    
    local tool = myChar:FindFirstChild(toolName) or (backpack and backpack:FindFirstChild(toolName))
    if tool and tool.Parent == backpack and humanoid then
        humanoid:EquipTool(tool)
    end
    return tool
end

-- 3. Functions ស្វែងរក Targets
local function playerHasKnife(player)
    if not player then return false end
    return (player:FindFirstChild("Backpack") and player.Backpack:FindFirstChild("Knife")) or (player.Character and player.Character:FindFirstChild("Knife"))
end

local function getClosestPlayerWithKnife()
    local myChar = LocalPlayer.Character
    if not myChar or not myChar:FindFirstChild("HumanoidRootPart") then return nil end
    local myPos = myChar.HumanoidRootPart.Position
    local closestPlayer = nil
    local shortestDistance = math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health > 0 and playerHasKnife(player) then
                local distance = (myPos - player.Character.HumanoidRootPart.Position).Magnitude
                if distance < shortestDistance then
                    shortestDistance = distance
                    closestPlayer = player
                end
            end
        end
    end
    return closestPlayer
end

local function getClosestLivingPlayer()
    local myChar = LocalPlayer.Character
    if not myChar or not myChar:FindFirstChild("HumanoidRootPart") then return nil end
    local myPos = myChar.HumanoidRootPart.Position
    local closestPlayer = nil
    local shortestDistance = math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health > 0 then
                local distance = (myPos - player.Character.HumanoidRootPart.Position).Magnitude
                if distance < shortestDistance then
                    shortestDistance = distance
                    closestPlayer = player
                end
            end
        end
    end
    return closestPlayer
end

local function findGunDrop()
    return workspace:FindFirstChild("GunDrop", true)
end

-- 4. Smooth Aimbot System (សម្រាប់ Knife Mode)
local function startAimbot()
    if aimbotConnection then aimbotConnection:Disconnect() end
    aimbotConnection = RunService.RenderStepped:Connect(function()
        local myChar = LocalPlayer.Character
        if myChar and currentTarget and currentTarget.Character then
            local myHRP = myChar:FindFirstChild("HumanoidRootPart")
            local targetHRP = currentTarget.Character:FindFirstChild("HumanoidRootPart")
            local targetPart = currentTarget.Character:FindFirstChild("UpperTorso") or targetHRP
            
            if myHRP and targetHRP then
                local targetPosForChar = Vector3.new(targetHRP.Position.X, myHRP.Position.Y, targetHRP.Position.Z)
                myHRP.CFrame = CFrame.lookAt(myHRP.Position, targetPosForChar)

                if targetPart then
                    Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, targetPart.Position)
                end
            end
        end
    end)
end

local function stopAimbot()
    if aimbotConnection then
        aimbotConnection:Disconnect()
        aimbotConnection = nil
    end
    currentTarget = nil
end

-- 5. Precision Bullet Prediction System
local function getPredictedCFrame(targetChar, shooterHRP)
    if not targetChar then return nil end
    local targetPart = targetChar:FindFirstChild("Head") or targetChar:FindFirstChild("UpperTorso") or targetChar:FindFirstChild("HumanoidRootPart")
    local targetHRP = targetChar:FindFirstChild("HumanoidRootPart")
    if not targetPart or not targetHRP then return nil end

    local velocity = targetHRP.AssemblyLinearVelocity
    local distance = shooterHRP and (shooterHRP.Position - targetPart.Position).Magnitude or 0
    local predictionFactor = math.clamp(distance / 1800, 0.015, 0.08)

    return CFrame.new(targetPart.Position + (velocity * predictionFactor))
end

local function shootTargetDirect(gun, targetPlayer)
    local myChar = LocalPlayer.Character
    if not myChar or not targetPlayer or not targetPlayer.Character then return end
    local myHRP = myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return end

    local gunAttachment = myHRP:FindFirstChild("GunRaycastAttachment")
    local originCFrame = gunAttachment and gunAttachment.WorldCFrame or myHRP.CFrame
    local targetCFrame = getPredictedCFrame(targetPlayer.Character, myHRP)

    if targetCFrame and gun:FindFirstChild("Shoot") then
        gun.Shoot:FireServer(originCFrame, targetCFrame)
    end
end

-- 6. Main Master Loop
local function masterLoop()
    while true do
        local myChar = LocalPlayer.Character
        local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
        
        if not myChar or not myHRP then 
            stopAimbot()
            task.wait(0.5)
            continue 
        end

        local hasGun, hasKnife = getMyWeaponStatus()

        -- ** MODE 1: គ្មាន Gun និងគ្មាន Knife **
        if not hasGun and not hasKnife then
            stopAimbot()
            local gunDrop = findGunDrop()

            if gunDrop then
                local dropCFrame = gunDrop:IsA("BasePart") and gunDrop.CFrame or gunDrop:GetPivot()
                myHRP.CFrame = dropCFrame + Vector3.new(0, 1.5, 0)
                task.wait(0.15)
            else
                local currentRotation = myHRP.CFrame - myHRP.CFrame.Position
                local targetPosition = Vector3.new(myHRP.Position.X, SAFE_HEIGHT, myHRP.Position.Z)
                myHRP.CFrame = CFrame.new(targetPosition) * currentRotation
                myHRP.AssemblyLinearVelocity = Vector3.zero
            end
            task.wait(0.03)
            continue
        end

        -- ** MODE 2: មាន Gun (Teleport ទៅក្រោមបាតជើង + បាញ់ចំ 100%) **
        if hasGun then
            stopAimbot()
            local targetPlayer = getClosestPlayerWithKnife()
            if not targetPlayer then
                task.wait(0.3)
                continue
            end

            local targetChar = targetPlayer.Character
            local targetHRP = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
            local targetHumanoid = targetChar and targetChar:FindFirstChildOfClass("Humanoid")

            while targetPlayer.Parent and targetChar and targetHumanoid and targetHumanoid.Health > 0 and playerHasKnife(targetPlayer) and myHRP do
                local currentGun = equipTool("Gun")
                if not currentGun then break end
                
                local currentHRP = targetChar:FindFirstChild("HumanoidRootPart")
                if not currentHRP then break end

                -- Teleport ទៅក្រោមបាតជើង 3.2 Studs (ចំលម្អៀងល្អឥតខ្ចោះ)
                local currentRotation = myHRP.CFrame - myHRP.CFrame.Position
                myHRP.CFrame = CFrame.new(currentHRP.Position - Vector3.new(0, 3.2, 0)) * currentRotation
                myHRP.AssemblyLinearVelocity = Vector3.zero

                shootTargetDirect(currentGun, targetPlayer)
                task.wait(0.02)
            end
            continue
        end

        -- ** MODE 3: មាន Knife (Aimbot & Teleport កាប់ភ្លាមៗ) **
        if hasKnife then
            startAimbot()
            local targetPlayer = getClosestLivingPlayer()
            if not targetPlayer then
                stopAimbot()
                task.wait(0.3)
                continue
            end

            currentTarget = targetPlayer
            local targetChar = targetPlayer.Character
            local targetHRP = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
            local targetHumanoid = targetChar and targetChar:FindFirstChildOfClass("Humanoid")

            while targetPlayer.Parent and targetChar and targetHumanoid and targetHumanoid.Health > 0 and myHRP do
                local knife = equipTool("Knife")
                local currentTargetHRP = targetChar:FindFirstChild("HumanoidRootPart")
                
                if currentTargetHRP then
                    -- Teleport ទៅជិតបំផុត (1.5 Studs) និងបង្វែរមុខទៅចំ Target
                    local targetPosition = currentTargetHRP.Position + (currentTargetHRP.CFrame.LookVector * 1.5)
                    myHRP.CFrame = CFrame.lookAt(targetPosition, currentTargetHRP.Position)
                    myHRP.AssemblyLinearVelocity = Vector3.zero
                    
                    if knife then
                        knife:Activate()
                    end
                else
                    break
                end
                task.wait(0.03)
            end
        end

        task.wait(0.05)
    end
end

masterLoop()
