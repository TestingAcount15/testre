local Config = _G.Config

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local function grantPermissions(targetId)
    local foundTarget = Players:GetPlayerByUserId(targetId)
    
    if foundTarget then
        local myIsland = nil
        local islands = Workspace:FindFirstChild("Islands")
        
        if islands then
            for _, island in pairs(islands:GetChildren()) do
                local owners = island:FindFirstChild("Owners")
                if owners then
                    if owners:FindFirstChild(tostring(player.UserId)) then
                        myIsland = island
                        break
                    else
                        for _, val in pairs(owners:GetChildren()) do
                            if val:IsA("NumberValue") and val.Value == player.UserId then
                                myIsland = island
                                break
                            end
                        end
                    end
                end
            end
        end
        
        if not myIsland then 
            local character = player.Character or player.CharacterAdded:Wait()
            local hrp = character:WaitForChild("HumanoidRootPart", 10)
            if hrp and islands then
                local dist = math.huge
                for _, island in pairs(islands:GetChildren()) do
                    if island.PrimaryPart then
                        local mag = (hrp.Position - island.PrimaryPart.Position).Magnitude
                        if mag < dist then
                            dist = mag
                            myIsland = island
                        end
                    end
                end
            end
        end
        
        if myIsland then
            local accessFolder = myIsland:FindFirstChild("AccessBuild")
            local hasPerms = false
            
            if accessFolder then
                if accessFolder:FindFirstChild(tostring(targetId)) then
                    hasPerms = true
                else
                    for _, child in pairs(accessFolder:GetChildren()) do
                        if child:IsA("NumberValue") and child.Value == targetId then
                            hasPerms = true
                            break
                        end
                    end
                end
            end
            
            if not hasPerms then
                local NetManaged = ReplicatedStorage:WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged")
                NetManaged:WaitForChild("GetPermissionAgreementId"):FireServer(HttpService:GenerateGUID(false), {{userId = targetId}})
                NetManaged:WaitForChild("CLIENT_CHANGE_ISLAND_ACCESS_LEVEL"):InvokeServer({player = foundTarget, accessRank = 3})
                NetManaged:WaitForChild("GetVisitorHardcoreMode"):FireServer(HttpService:GenerateGUID(false), {{visitor = foundTarget}})
                NetManaged:WaitForChild("RenderIconIndicator"):FireServer(HttpService:GenerateGUID(false), {{overheadIcon = "BUILDER", player = foundTarget}})
                NetManaged:WaitForChild("GET_PLAYER_ICON_SET"):InvokeServer({player = foundTarget})
            end
        end
    end
end

if player.UserId == Config.CoinAccountId then
    task.spawn(function()
        while true do
            grantPermissions(Config.CrateAccountId)
            task.wait(3)
        end
    end)
end

if player.UserId == Config.CrateAccountId then
    task.spawn(function()
        while true do
            grantPermissions(Config.CoinAccountId)
            task.wait(3)
        end
    end)

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.KeyCode == Config.ActivationKey then
            task.spawn(function()
                local coinPlayer = Players:GetPlayerByUserId(Config.CoinAccountId)
                if not coinPlayer then return end

                local rawIslandId = coinPlayer:GetAttribute("OwnedIslandId")
                if not rawIslandId then return end

                local targetIslandStr = rawIslandId .. "-island"

                local character = player.Character or player.CharacterAdded:Wait()
                local hrp = character:WaitForChild("HumanoidRootPart")
                local humanoid = character:WaitForChild("Humanoid")

                local NetManaged = ReplicatedStorage:WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged")
                local OpenRemote = NetManaged:WaitForChild("yqfxgkl/gnwsxLwKexyMytpl")
                local BuyRemote = NetManaged:WaitForChild("CLIENT_MERCHANT_ORDER_REQUEST")

                local function ensureStanding()
                    if humanoid and humanoid.Sit then
                        humanoid.Sit = false
                        humanoid.Jump = true
                    end
                end

                local function getClosestSeat(pos)
                    local closestSeat = nil
                    local minDst = 20
                    local region = Region3.new(pos - Vector3.new(20, 20, 20), pos + Vector3.new(20, 20, 20))
                    local parts = Workspace:FindPartsInRegion3(region, nil, 100)
                    for _, part in ipairs(parts) do
                        if part:IsA("Seat") then
                            local dst = (part.Position - pos).Magnitude
                            if dst < minDst then
                                minDst = dst
                                closestSeat = part
                            end
                        end
                    end
                    return closestSeat
                end

                local function smoothTeleportAndSit(targetPos)
                    if not character or not hrp then return end
                    ensureStanding()
                    hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0))
                    task.wait(Config.Delays.TeleportBuffer)
                    
                    local seat = getClosestSeat(targetPos)
                    if seat then
                        local sitStart = tick()
                        while not humanoid.Sit and tick() - sitStart < 3 do
                            seat:Sit(humanoid)
                            RunService.Heartbeat:Wait()
                        end
                        
                        if humanoid.Sit then
                            task.wait(Config.Delays.SitDuration)
                            ensureStanding()
                        end
                    end
                end

                local function walkTo(targetPart)
                    if not targetPart or not hrp then return end
                    
                    local noclip = RunService.Stepped:Connect(function()
                        for _, v in ipairs(character:GetDescendants()) do
                            if v:IsA("BasePart") then
                                v.CanCollide = false
                            end
                        end
                    end)
                    
                    hrp.CFrame = hrp.CFrame + Vector3.new(0, 5, 0)
                    local timeout = tick()
                    
                    while (targetPart.Position - hrp.Position).Magnitude > 4 do
                        if tick() - timeout > 8 then break end
                        ensureStanding()
                        local dir = (targetPart.Position - hrp.Position).Unit
                        hrp.CFrame = hrp.CFrame + (dir * 3)
                        hrp.Velocity = Vector3.new(0, 0, 0)
                        task.wait(0.1)
                    end
                    
                    if noclip then noclip:Disconnect() end
                end

                local function checkAndSell(merchantId, isMechanic)
                    local soldSomething = true
                    while soldSomething do
                        soldSomething = false
                        local itemsToSell = {}
                        
                        local containers = {player.Backpack, character}
                        for _, container in ipairs(containers) do
                            for _, tool in ipairs(container:GetChildren()) do
                                if tool:IsA("Tool") then
                                    local validItem = false
                                    local offerId = nil
                                    
                                    if isMechanic then
                                        if tool.Name == "gearbox" then
                                            validItem = true
                                            offerId = 2
                                        end
                                    else
                                        if Config.Items[tool.Name] then
                                            validItem = true
                                            offerId = Config.Items[tool.Name]
                                        end
                                    end
                                    
                                    if validItem then
                                        local amountObj = tool:FindFirstChild("Amount")
                                        if amountObj and amountObj.Value > 0 then
                                            table.insert(itemsToSell, {tool = tool, offer = offerId, amt = amountObj.Value})
                                        end
                                    end
                                end
                            end
                        end
                        
                        if #itemsToSell > 0 then
                            OpenRemote:FireServer(HttpService:GenerateGUID(false), {{merchantId = merchantId}})
                            task.wait(Config.Delays.SellDelay)
                            
                            for _, itemData in ipairs(itemsToSell) do
                                if itemData.tool and itemData.tool.Parent then
                                    BuyRemote:InvokeServer({
                                        merchant = merchantId,
                                        offerId = itemData.offer,
                                        amount = itemData.amt
                                    })
                                    soldSomething = true
                                    task.wait(0.1)
                                end
                            end
                        end
                        task.wait(Config.Delays.SellDelay)
                    end
                end

                local function hasGearbox()
                    local containers = {player.Backpack, character}
                    for _, container in ipairs(containers) do
                        if container:FindFirstChild("gearbox") then
                            return true
                        end
                    end
                    return false
                end

                local function hasWholesalerItems()
                    local containers = {player.Backpack, character}
                    for _, container in ipairs(containers) do
                        for _, tool in ipairs(container:GetChildren()) do
                            if tool:IsA("Tool") and Config.Items[tool.Name] then
                                return true
                            end
                        end
                    end
                    return false
                end
                
                local attempts = 0
                while hasGearbox() and attempts < 5 do
                    attempts = attempts + 1
                    smoothTeleportAndSit(Config.Positions.Mechanic)
                    local mechanicNPC = Workspace.spawnPrefabs.merchants:FindFirstChild("mechanic")
                    if mechanicNPC and mechanicNPC:FindFirstChild("HumanoidRootPart") then
                        walkTo(mechanicNPC.HumanoidRootPart)
                        checkAndSell("mechanic", true)
                    end
                    task.wait(Config.Delays.MerchantCheck)
                end
                
                attempts = 0
                while hasWholesalerItems() and attempts < 5 do
                    attempts = attempts + 1
                    smoothTeleportAndSit(Config.Positions.Wholesaler)
                    local wholesalerNPC = Workspace.spawnPrefabs.merchants:FindFirstChild("wholesaler")
                    if wholesalerNPC and wholesalerNPC:FindFirstChild("HumanoidRootPart") then
                        walkTo(wholesalerNPC.HumanoidRootPart)
                        checkAndSell("wholesaler", false)
                    end
                    task.wait(Config.Delays.MerchantCheck)
                end

                task.wait(0.5)

                local visitArgs = {
                    {
                        island = Workspace:WaitForChild("Islands"):WaitForChild(targetIslandStr)
                    }
                }
                NetManaged:WaitForChild("CLIENT_VISIT_ISLAND_REQUEST"):InvokeServer(unpack(visitArgs))

                task.wait(Config.Delays.IslandLoad)
                repeat task.wait(1) until Workspace:FindFirstChild("Islands")

                local function handleVending()
                    local maxWait = 10
                    local waittime = 0
                    repeat 
                        task.wait(0.5) 
                        waittime = waittime + 0.5
                    until player:GetAttribute("Coins") or waittime > maxWait
                    
                    local targetIsland = Workspace.Islands:WaitForChild(targetIslandStr, 10)
                    if not targetIsland then return end
                    
                    local blocks = targetIsland:WaitForChild("Blocks", 10)
                    if not blocks then return end

                    local processed = {}
                    
                    for _, block in pairs(blocks:GetChildren()) do
                        if (block.Name == "vendingMachine" or block.Name == "vendingMachine1") and not processed[block] then
                            processed[block] = true
                            task.spawn(function()
                                local vendingData = { [1] = { ["vendingMachine"] = block } }
                                NetManaged[Config.Vending.Remotes.Open]:FireServer(Config.Vending.Remotes.Open, vendingData)
                                NetManaged[Config.Vending.Remotes.Edit]:FireServer(Config.Vending.Remotes.Edit, vendingData)
                                NetManaged[Config.Vending.Remotes.Deposit]:FireServer(Config.Vending.Remotes.Deposit, { 
                                    [1] = { 
                                        ["vendingMachine"] = block, 
                                        ["amount"] = Config.Vending.DepositAmount
                                    } 
                                })
                                local closeData = { ["vendingMachine"] = block }
                                NetManaged[Config.Vending.Remotes.Close]:FireServer(closeData)
                            end)
                        end
                    end

                    if targetIsland.PrimaryPart and hrp then
                        hrp.CFrame = targetIsland.PrimaryPart.CFrame + Vector3.new(0, 5, 0)
                    end

                    local rsTools = ReplicatedStorage:WaitForChild("Tools")
                    for _, v in pairs(game:GetDescendants()) do
                        if v:IsA("Tool") and not v:IsDescendantOf(rsTools) then
                            v.Parent = Workspace.Terrain
                            character.Humanoid:EquipTool(v)
                            task.wait()
                        end
                    end
                end
                
                handleVending()
            end)
        end
    end)
end
