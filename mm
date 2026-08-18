local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local currentTarget = nil
local aimbotConnection = nil

-- 1. Function Auto Equip Gun
local function equipGun()
    local myChar = LocalPlayer.Character
    if not myChar then return nil end

    local gun = LocalPlayer.Backpack:FindFirstChild("Gun") or myChar:FindFirstChild("Gun")
    if gun then
        if gun.Parent == LocalPlayer.Backpack then
            gun.Parent = myChar
        end
        return gun
    end
    return nil
end

-- 2. Function Lock Camera & Face Character
local function startAimbot()
    if aimbotConnection then aimbotConnection:Disconnect() end
    
    aimbotConnection = RunService.RenderStepped:Connect(function()
        local myChar = LocalPlayer.Character
        if myChar and currentTarget and currentTarget.Character then
            local myHRP = myChar:FindFirstChild("HumanoidRootPart")
            local targetHRP = currentTarget.Character:FindFirstChild("HumanoidRootPart")
            local targetHead = currentTarget.Character:FindFirstChild("Head") or targetHRP
            
            if myHRP and targetHRP then
                -- បែរមុខចុះក្រោមចំ Target
                myHRP.CFrame = CFrame.lookAt(myHRP.Position, targetHRP.Position)

                if targetHead then
                    Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, targetHead.Position)
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

-- 3. Function ស្វែងរក Player ដែលនៅរស់ និងនៅជិតបំផុត
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

-- 4. Function គណនាទីតាំង Prediction
local function getPredictedCFrame(targetChar)
    local head = targetChar:FindFirstChild("Head") or targetChar:FindFirstChild("HumanoidRootPart")
    if not head then return nil end

    local hrp = targetChar:FindFirstChild("HumanoidRootPart")
    if hrp then
        local velocity = hrp.AssemblyLinearVelocity
        local predictedPosition = head.Position + (velocity * 0.08)
        return CFrame.new(predictedPosition)
    end

    return head.CFrame
end

-- 5. Function បាញ់ចំ Target Direct Remote
local function shootTargetDirect(gun, targetPlayer)
    local myChar = LocalPlayer.Character
    if not myChar or not targetPlayer.Character then return end

    local predictedCFrame = getPredictedCFrame(targetPlayer.Character)
    if not predictedCFrame then return end

    local hrp = myChar:FindFirstChild("HumanoidRootPart")
    local attachment = hrp and hrp:FindFirstChild("GunRaycastAttachment")
    local originCFrame = attachment and attachment.WorldCFrame or (hrp and hrp.CFrame)

    local remoteShoot = gun:FindFirstChild("Shoot")
    if remoteShoot and originCFrame then
        remoteShoot:FireServer(originCFrame, predictedCFrame)
    end
    
    gun:Activate()
end

-- 6. Main Loop: Tween ទៅលើក្បាល -> តាមអណ្តែតពីលើក្បាល និងបាញ់អូតូ
local function startAutoKillAboveHead()
    startAimbot()

    while true do
        local myChar = LocalPlayer.Character
        if not myChar or not myChar:FindFirstChild("HumanoidRootPart") then break end

        local targetPlayer = getClosestLivingPlayer()
        
        if not targetPlayer then
            print("--- អស់ Target ត្រូវបាញ់ហើយ! ---")
            stopAimbot()
            break
        end

        currentTarget = targetPlayer
        local targetChar = targetPlayer.Character
        local targetHRP = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
        local targetHumanoid = targetChar and targetChar:FindFirstChildOfClass("Humanoid")

        print("កំពុង Tween ទៅលើក្បាល: " .. targetPlayer.DisplayName)

        -- Bướcទី១៖ Tween ទៅទីតាំងចំពីលើក្បាល (Vector3.new(0, 4.5, 0))
        if targetHRP and targetHumanoid and targetHumanoid.Health > 0 then
            local distance = (myChar.HumanoidRootPart.Position - targetHRP.Position).Magnitude
            if distance > 6 then
                local topCFrame = CFrame.lookAt(targetHRP.Position + Vector3.new(0, 4.5, 0), targetHRP.Position)
                local tweenInfo = TweenInfo.new(distance / 130, Enum.EasingStyle.Linear)
                local tween = TweenService:Create(myChar.HumanoidRootPart, tweenInfo, {CFrame = topCFrame})
                tween:Play()
                tween.Completed:Wait()
            end
        end

        -- Bướcទី២៖ អណ្តែតតាមពីលើក្បាលរហូត (ទោះគេដើរ/រត់) និងបាញ់អូតូ
        while targetHumanoid and targetHumanoid.Health > 0 and myChar:FindFirstChild("HumanoidRootPart") do
            local gun = equipGun()
            
            if targetHRP then
                -- ដាក់ CFrame ឱ្យនៅចំពីលើក្បាល Target 4.5 Studs ជានិច្ច និងមើលចុះក្រោម
                local aboveHeadPosition = targetHRP.Position + Vector3.new(0, 4.5, 0)
                myChar.HumanoidRootPart.CFrame = CFrame.lookAt(aboveHeadPosition, targetHRP.Position)
                
                if gun then
                    shootTargetDirect(gun, targetPlayer)
                end
            end
            
            task.wait(0.05)
        end

        task.wait(0.1)
    end
end

-- ហៅ Function ដំណើរការ
startAutoKillAboveHead()
