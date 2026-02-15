local RSGCore = exports['rsg-core']:GetCoreObject()

-- Wagon Storage Variables
local storagePath = 'wagon_storage.json'
local wagonData = {}

-- Helper function to count table entries
local function GetTableLength(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

local function IsPlayerUndertaker(source)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player or not Player.PlayerData.job then return false end

    return Player.PlayerData.job.name == Config.JobName
end

local function LogUndertakerActivity(source, action, details)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return end
    
    print(('[UNDERTAKER LOG] %s (%s) - %s: %s'):format(
        Player.PlayerData.name or 'Unknown',
        Player.PlayerData.job.name or 'Unknown',
        action,
        details
    ))
end

-- Get player identifier
local function GetPlayerIdentifier(source)
    local Player = RSGCore.Functions.GetPlayer(source)
    if Player then
        local identifier = Player.PlayerData.citizenid
        return identifier
    end
    return nil
end

-- Callback: Check if player has shovel
RSGCore.Functions.CreateCallback('undertaker:hasShovel', function(source, cb)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then
        cb(false)
        return
    end
    
    local shovelItem = Config.AnywhereBurial and Config.AnywhereBurial.ShovelItem or 'shovel'
    local hasItem = Player.Functions.GetItemByName(shovelItem)
    
    cb(hasItem ~= nil)
end)

-- Initialize JSON file
local function InitializeStorage()
    local file = LoadResourceFile(GetCurrentResourceName(), storagePath)
    
    if not file then
        wagonData = { wagons = {} }
        local success = SaveResourceFile(GetCurrentResourceName(), storagePath, json.encode(wagonData, {indent = true}), -1)
        if success then
            print('[UNDERTAKER] Created new wagon_storage.json')
        else
            print('[UNDERTAKER] ERROR: Failed to create wagon_storage.json')
        end
    else
        wagonData = json.decode(file)
        if not wagonData then
            wagonData = { wagons = {} }
            print('[UNDERTAKER] WARNING: wagon_storage.json was invalid, reset to empty')
        end
        if not wagonData.wagons then
            wagonData.wagons = {}
        end
        print('[UNDERTAKER] Loaded wagon_storage.json with ' .. GetTableLength(wagonData.wagons) .. ' entries')
    end
end

-- Save data to JSON
local function SaveStorage()
    local jsonData = json.encode(wagonData, {indent = true})
    local success = SaveResourceFile(GetCurrentResourceName(), storagePath, jsonData, -1)
    if success then
        print('[UNDERTAKER] Saved wagon_storage.json')
    else
        print('[UNDERTAKER] ERROR: Failed to save wagon_storage.json')
    end
end

-- Get player wagon data
local function GetPlayerWagonData(identifier)
    if not identifier then return nil end
    
    if not wagonData.wagons[identifier] then
        wagonData.wagons[identifier] = {
            bodies = {},
            lastUpdated = os.time()
        }
    end
    
    -- Ensure bodies is a table (fix for old data format)
    if type(wagonData.wagons[identifier].bodies) ~= "table" then
        wagonData.wagons[identifier].bodies = {}
    end
    
    return wagonData.wagons[identifier]
end

-- Get stored body count for player
local function GetStoredBodies(identifier)
    if not identifier then
        return 0
    end
    
    local playerData = GetPlayerWagonData(identifier)
    if playerData and playerData.bodies and type(playerData.bodies) == "table" then
        return #playerData.bodies
    end
    
    return 0
end

-- Generate random name
local function GenerateRandomName()
    local firstNames = Config.RandomNames.FirstNames
    local lastNames = Config.RandomNames.LastNames
    
    local firstName = firstNames[math.random(#firstNames)]
    local lastName = lastNames[math.random(#lastNames)]
    
    return firstName .. ' ' .. lastName
end

-- Initialize on resource start
CreateThread(function()
    Wait(100)
    math.randomseed(os.time())
    InitializeStorage()
    print('[UNDERTAKER] Server initialized')
end)

-- Callback: Get wagon body count
RSGCore.Functions.CreateCallback('undertaker:getWagonBodies', function(source, cb)
    local identifier = GetPlayerIdentifier(source)
    
    if not identifier then
        cb(0)
        return
    end
    
    local bodies = GetStoredBodies(identifier)
    cb(bodies)
end)

-- Callback: Get wagon body list with details
RSGCore.Functions.CreateCallback('undertaker:getWagonBodyList', function(source, cb)
    local identifier = GetPlayerIdentifier(source)
    
    if not identifier then
        cb({})
        return
    end
    
    local playerData = GetPlayerWagonData(identifier)
    if playerData and playerData.bodies and type(playerData.bodies) == "table" then
        cb(playerData.bodies)
    else
        cb({})
    end
end)

RegisterNetEvent('undertaker:storeBodyInWagon', function(bodyData)
    local src = source
    
    if not IsPlayerUndertaker(src) then
        return
    end
    
    local identifier = GetPlayerIdentifier(src)
    if not identifier then
        return
    end
    
    local playerData = GetPlayerWagonData(identifier)
    local currentBodies = #playerData.bodies
    local maxBodies = Config.WagonStorage.MaxBodies or 6
    
    if currentBodies >= maxBodies then
        TriggerClientEvent('undertaker:wagonStorageResult', src, false, 'full', currentBodies)
        return
    end
    
    -- Generate name based on entity type
    local entityType = bodyData.entityType or 'human'
    local name
    if entityType == 'animal' then
        name = 'Animal Remains'
    else
        name = GenerateRandomName()
    end
    
    local newBody = {
        id = os.time() .. '_' .. math.random(1000, 9999),
        name = name,
        location = bodyData.location or 'Unknown',
        storedAt = os.date('%Y-%m-%d %H:%M'),
        entityType = entityType,
    }
    
    table.insert(playerData.bodies, newBody)
    wagonData.wagons[identifier].lastUpdated = os.time()
    SaveStorage()
    
    local newCount = #playerData.bodies
    
    LogUndertakerActivity(src, 'WAGON_STORE', 'Stored ' .. entityType .. ': ' .. newBody.name .. ' from ' .. newBody.location .. '. Total: ' .. newCount)
    TriggerClientEvent('undertaker:wagonStorageResult', src, true, 'stored', newCount)
end)

-- Event: Retrieve body from wagon
RegisterNetEvent('undertaker:retrieveBodyFromWagon', function(bodyId)
    local src = source
    
    
    
    if not IsPlayerUndertaker(src) then
        
        return
    end
    
    local identifier = GetPlayerIdentifier(src)
    if not identifier then
        
        return
    end
    
    
    
    local playerData = GetPlayerWagonData(identifier)
    
    if not playerData or not playerData.bodies then
       
        TriggerClientEvent('undertaker:wagonStorageResult', src, false, 'empty', 0)
        return
    end
    
    local currentBodies = #playerData.bodies
   
    
    if currentBodies <= 0 then
       
        TriggerClientEvent('undertaker:wagonStorageResult', src, false, 'empty', 0)
        return
    end
    
   
    local removedBody = nil
    if bodyId then
       
        for i, body in ipairs(playerData.bodies) do
           
            if body.id == bodyId then
                removedBody = table.remove(playerData.bodies, i)
                
                break
            end
        end
    end
    
   
    if not removedBody then
       
        removedBody = table.remove(playerData.bodies)
    end
    
    if not removedBody then
      
        TriggerClientEvent('undertaker:wagonStorageResult', src, false, 'empty', 0)
        return
    end
    
    wagonData.wagons[identifier].lastUpdated = os.time()
    SaveStorage()
    
    local newCount = #playerData.bodies
    
    
    LogUndertakerActivity(src, 'WAGON_RETRIEVE', 'Retrieved body: ' .. (removedBody and removedBody.name or 'Unknown') .. '. Remaining: ' .. newCount)
    TriggerClientEvent('undertaker:wagonStorageResult', src, true, 'retrieved', newCount)
end)


RegisterNetEvent('undertaker:buryBody', function(entityType)
    local src = source
    
    if not IsPlayerUndertaker(src) then
        return
    end
    
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    
    -- Different payment for animals vs humans
    local payment
    if entityType == 'animal' then
        payment = Config.AnimalBurialPayment or 15
    else
        payment = Config.BurialPayment or 25
    end
    
    Player.Functions.AddMoney('cash', payment, 'undertaker-burial')
    
    LogUndertakerActivity(src, 'BURIAL', 'Buried a ' .. (entityType or 'human') .. ' and received $' .. payment)
    
    TriggerClientEvent('undertaker:burialSuccess', src, payment)
end)


RegisterNetEvent('undertaker:reportDeath', function(data)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
   
    
   
    local players = RSGCore.Functions.GetPlayers()
    for _, playerId in ipairs(players) do
        local targetPlayer = RSGCore.Functions.GetPlayer(playerId)
        if targetPlayer and targetPlayer.PlayerData.job and targetPlayer.PlayerData.job.name == Config.JobName then
            TriggerClientEvent('undertaker:deathReportReceived', playerId, {
                coords = data.coords,
                location = data.location
            })
        end
    end
    
    
    if Config.DeathReport and Config.DeathReport.RewardReporter then
        local reward = Config.DeathReport.RewardAmount or 5
        Player.Functions.AddMoney('cash', reward, 'death-report-reward')
        TriggerClientEvent('undertaker:reportReward', src, reward)
        LogUndertakerActivity(src, 'DEATH_REPORT', 'Reported a death at ' .. data.location .. ' and received $' .. reward)
    else
        LogUndertakerActivity(src, 'DEATH_REPORT', 'Reported a death at ' .. data.location)
    end
end)
