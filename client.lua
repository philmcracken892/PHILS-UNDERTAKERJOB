local RSGCore = exports['rsg-core']:GetCoreObject()

local isDigging = false
local isPraying = false
local shovelProp = nil
local cachedDeadBody = nil
local lastBodyCheck = 0
local createdDirtPiles = {}
local wagonBodyCount = 0
local notifiedBodies = {}
local lastNotifyTime = 0  
local currentGPSBody = nil
local gpsActive = false
local wagonSpawnedBodies = {}
local lastReportTime = 0
local reportedBodies = {}
local targetedEntities = {}
local createdZones = {}
local graveTexts = {}
local currentBurialName = nil
local currentBurialType = nil

local function DebugPrint(msg)
    if Config and Config.Debug then
        print('[UNDERTAKER DEBUG] ' .. msg)
    end
end

local function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = GetScreenCoordFromWorldCoord(x, y, z)
    if not onScreen then return end
    
    local scale = Config.GraveText.Scale or 0.35
    local font = Config.GraveText.Font or 1
    
    SetTextScale(scale, scale)
    SetTextFontForCurrentCommand(font)
    SetTextColor(255, 255, 255, 255)
    SetTextCentre(true)
    SetTextDropshadow(1, 0, 0, 0, 255)
    
    DisplayText(CreateVarString(10, "LITERAL_STRING", text), _x, _y)
end

local function AddGraveText(coords, name, entityType)
    if not Config.GraveText or not Config.GraveText.Enabled then
        return
    end
    
    local graveId = GetGameTimer() .. '_' .. math.random(1000, 9999)
    local displayName = name or Config.GraveText.DefaultText
    
    local textLine1 = "R.I.P."
    local textLine2 = displayName
    local textLine3
    
    if entityType == 'animal' then
        textLine2 = "Pet"
        textLine3 = displayName or "Animal Companion"
    else
        local humanEpitaphs = {
            "Taken too early",
            "Rest in Peace",
            "Gone but not forgotten",
            "Forever in our hearts",
            "May they find peace",
            "Until we meet again",
            "Born a loser",
            "Should have ducked",
            "Died owing me money",
            "Finally shut up",
            "Told you I was sick",
            "Here lies trouble",
            "At least he tried",
            "Oops",
            "Well that was stupid",
            "No refunds",
            "Shouldnt have said that",
            "He had it coming",
            "Wrong place wrong time",
            "Never lucky",
            "Died doing what he loved",
            "It was the whiskey",
            "Bet he regrets that",
            "Talk less next time",
            "Probably deserved it"
        }
        textLine3 = humanEpitaphs[math.random(#humanEpitaphs)]
    end
    
    graveTexts[graveId] = {
        coords = coords,
        name = displayName,
        entityType = entityType or 'human',
        textLine1 = textLine1,
        textLine2 = textLine2,
        textLine3 = textLine3,
        createdAt = GetGameTimer(),
        duration = (Config.GraveText.Duration or 300) * 1000
    }
    
    DebugPrint('Added grave text: ' .. displayName .. ' at ' .. tostring(coords))
    
    return graveId
end

local function CleanupGraveTexts()
    local currentTime = GetGameTimer()
    
    for graveId, data in pairs(graveTexts) do
        if currentTime - data.createdAt > data.duration then
            graveTexts[graveId] = nil
            DebugPrint('Removed expired grave text: ' .. data.name)
        end
    end
end

CreateThread(function()
    while true do
        local hasGraveTexts = next(graveTexts) ~= nil
        
        if hasGraveTexts and Config.GraveText and Config.GraveText.Enabled then
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local displayDistance = Config.GraveText.DisplayDistance or 15.0
            
            for graveId, data in pairs(graveTexts) do
                local dist = #(playerCoords - data.coords)
                
                if dist < displayDistance then
                    DrawText3D(data.coords.x, data.coords.y, data.coords.z + 1.2, data.textLine1)
                    DrawText3D(data.coords.x, data.coords.y, data.coords.z + 1.0, data.textLine2)
                    DrawText3D(data.coords.x, data.coords.y, data.coords.z + 0.8, data.textLine3)
                end
            end
            
            Wait(0)
        else
            Wait(1000)
        end
    end
end)

CreateThread(function()
    while true do
        Wait(30000)
        CleanupGraveTexts()
    end
end)

local function GetLocationName(coords)
    if not coords then return 'Unknown' end
    
    local closestLocation = 'Wilderness'
    local closestDist = 999999
    
    for _, location in ipairs(Config.LocationNames) do
        local dist = #(vector3(coords.x, coords.y, coords.z) - location.coords)
        if dist < location.radius and dist < closestDist then
            closestDist = dist
            closestLocation = location.name
        end
    end
    
    return closestLocation
end

local function LoadAnimDict(dict)
    if not DoesAnimDictExist(dict) then
        DebugPrint('Animation dict does not exist: ' .. dict)
        return false
    end

    if HasAnimDictLoaded(dict) then
        return true
    end

    RequestAnimDict(dict)
    local timeout = 0
    while not HasAnimDictLoaded(dict) and timeout < 100 do
        Wait(10)
        timeout = timeout + 1
    end

    return HasAnimDictLoaded(dict)
end

local function LoadModel(model)
    local modelHash = GetHashKey(model)

    if HasModelLoaded(modelHash) then
        return modelHash
    end

    RequestModel(modelHash)
    local timeout = 0
    while not HasModelLoaded(modelHash) and timeout < 100 do
        Wait(10)
        timeout = timeout + 1
    end

    return HasModelLoaded(modelHash) and modelHash or nil
end

local function IsUndertaker()
    local PlayerData = RSGCore.Functions.GetPlayerData()
    
    if not PlayerData then
        DebugPrint('IsUndertaker: PlayerData is nil')
        return false
    end
    
    if not PlayerData.job then
        DebugPrint('IsUndertaker: PlayerData.job is nil')
        return false
    end
    
    local playerJob = PlayerData.job.name
    local requiredJob = Config.JobName
    
    DebugPrint('IsUndertaker: Player job = ' .. tostring(playerJob) .. ', Required = ' .. tostring(requiredJob))
    
    return playerJob == requiredJob
end

local function Notify(title, message, type)
    local icon = 'warning'
    if type == 'success' then
        icon = 'awards_set_a_009'
    elseif type == 'error' then
        icon = 'warning'
    elseif type == 'info' then
        icon = 'awards_set_c_001'
    end

    TriggerEvent('bln_notify:send', {
        title = title,
        description = message,
        icon = icon,
        duration = 5000,
        placement = 'top-right'
    })
end

local function SetBodyWaypoint(pos, label)
    if pos and pos.x and pos.y and pos.z then
        ClearGpsMultiRoute()
        StartGpsMultiRoute(6, true, true)
        AddPointToGpsMultiRoute(pos.x, pos.y, pos.z)
        SetGpsMultiRouteRender(true)
        
        gpsActive = true
        currentGPSBody = pos

        Notify('Undertaker', label or Config.Texts.GPSSet, 'success')

        CreateThread(function()
            local playerPed = PlayerPedId()
            local arrived = false
            while not arrived and gpsActive do
                local coords = GetEntityCoords(playerPed)
                local dist = #(vector3(pos.x, pos.y, pos.z) - coords)
                if dist < 5.0 then 
                    ClearGpsMultiRoute()
                    SetGpsMultiRouteRender(false)
                    arrived = true
                    gpsActive = false
                    currentGPSBody = nil
                    Notify('Undertaker', Config.Texts.BodyCollected, 'info')
                end
                Wait(1000)
            end
        end)
    end
end

local function ClearBodyWaypoint()
    if gpsActive then
        ClearGpsMultiRoute()
        SetGpsMultiRouteRender(false)
        gpsActive = false
        currentGPSBody = nil
    end
end

local function GetNearestDeadBody()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local closestBody = nil
    local closestDist = 999.0
    local entityType = 'human'

    local searchRadius = Config.BodySearchRadius or 15.0
    local peds = GetGamePool('CPed')
    
    DebugPrint('Total peds in pool: ' .. #peds)

    local deadCount = 0

    for _, ped in ipairs(peds) do
        if DoesEntityExist(ped) and ped ~= playerPed then
            local isPlayer = IsPedAPlayer(ped)
            
            if not isPlayer then
                local isDead = IsEntityDead(ped)
                local isDeadOrDying = IsPedDeadOrDying(ped, true)
                local pedHealth = GetEntityHealth(ped)
                
                if isDead or isDeadOrDying or pedHealth <= 0 then
                    deadCount = deadCount + 1
                    local pedCoords = GetEntityCoords(ped)
                    local dist = #(playerCoords - pedCoords)

                    if dist <= searchRadius and dist < closestDist then
                        closestDist = dist
                        closestBody = ped
                        
                        local pedType = GetPedType(ped)
                        if pedType == 28 then
                            entityType = 'animal'
                        else
                            entityType = 'human'
                        end
                        
                        DebugPrint('Dead ped #' .. deadCount .. ': Type=' .. entityType)
                    end
                end
            end
        end
    end

    return closestBody, closestDist, entityType
end

local function IsDeadBodyNearby()
    local currentTime = GetGameTimer()

    if currentTime - lastBodyCheck > 1000 then
        lastBodyCheck = currentTime
        cachedDeadBody = GetNearestDeadBody()
    end

    return cachedDeadBody ~= nil and DoesEntityExist(cachedDeadBody)
end

local function CleanupNotifiedBodies()
    local currentTime = GetGameTimer()
    local cleanupTime = 300000
    
    for bodyId, timestamp in pairs(notifiedBodies) do
        if currentTime - timestamp > cleanupTime then
            notifiedBodies[bodyId] = nil
        end
    end
end

local function CleanupWagonSpawnedBodies()
    for body, _ in pairs(wagonSpawnedBodies) do
        if not DoesEntityExist(body) then
            wagonSpawnedBodies[body] = nil
            DebugPrint('Removed non-existent body from wagon spawned list: ' .. tostring(body))
        end
    end
end

local function CleanupReportedBodies()
    local currentTime = GetGameTimer()
    local cleanupTime = 300000
    
    for bodyId, timestamp in pairs(reportedBodies) do
        if currentTime - timestamp > cleanupTime then
            reportedBodies[bodyId] = nil
        end
    end
end

local function ReportDeath()
    if not Config.DeathReport or not Config.DeathReport.Enabled then
        return
    end
    
    local currentTime = GetGameTimer()
    local cooldown = Config.DeathReport.Cooldown or 60000
    
    if currentTime - lastReportTime < cooldown then
        Notify('Death Report', Config.Texts.ReportCooldown, 'error')
        return
    end
    
    local body, dist = GetNearestDeadBody()
    
    if not body or not DoesEntityExist(body) then
        Notify('Death Report', Config.Texts.NoBodyToReport, 'error')
        return
    end
    
    local bodyCoords = GetEntityCoords(body)
    local bodyId = string.format("%.1f_%.1f_%.1f", bodyCoords.x, bodyCoords.y, bodyCoords.z)
    
    if reportedBodies[bodyId] then
        Notify('Death Report', Config.Texts.AlreadyReported, 'error')
        return
    end
    
    reportedBodies[bodyId] = currentTime
    lastReportTime = currentTime
    
    local locationName = GetLocationName(bodyCoords)
    
    TriggerServerEvent('undertaker:reportDeath', {
        coords = bodyCoords,
        location = locationName
    })
    
    Notify('Death Report', Config.Texts.DeathReported, 'success')
end

local function CheckForDeadBodies()
    if not Config.BodyDetection or not Config.BodyDetection.Enabled then
        return
    end
    
    if not IsUndertaker() then
        return
    end
    
    local currentTime = GetGameTimer()
    
    if currentTime - lastNotifyTime < (Config.BodyDetection.MinNotifyInterval or 60000) then
        return
    end
    
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local notifyRadius = Config.BodyDetection.NotifyRadius or 200.0
    
    local peds = GetGamePool('CPed')
    
    for _, ped in ipairs(peds) do
        if DoesEntityExist(ped) and ped ~= playerPed then
            local isPlayer = IsPedAPlayer(ped)
            
            if wagonSpawnedBodies[ped] then
                DebugPrint('Skipping wagon-spawned body: ' .. tostring(ped))
                goto continue
            end
            
            if not isPlayer then
                local isDead = IsEntityDead(ped)
                local isDeadOrDying = IsPedDeadOrDying(ped, true)
                local pedHealth = GetEntityHealth(ped)
                
                if isDead or isDeadOrDying or pedHealth <= 0 then
                    local pedCoords = GetEntityCoords(ped)
                    local dist = #(playerCoords - pedCoords)
                    
                    if dist <= notifyRadius then
                        local bodyId = string.format("%.1f_%.1f_%.1f", pedCoords.x, pedCoords.y, pedCoords.z)
                        
                        if not notifiedBodies[bodyId] then
                            notifiedBodies[bodyId] = currentTime
                            lastNotifyTime = currentTime
                            
                            Notify('Undertaker', Config.Texts.BodyDetected, 'info')
                            
                            SetTimeout(1000, function()
                                SetBodyWaypoint(pedCoords, Config.Texts.GPSSet)
                            end)
                            
                            DebugPrint('Body detected at: ' .. tostring(pedCoords))
                            
                            return
                        end
                    end
                end
            end
            
            ::continue::
        end
    end
    
    CleanupNotifiedBodies()
end

CreateThread(function()
    while true do
        Wait(Config.BodyDetection and Config.BodyDetection.CheckInterval or 10000)
        
        if Config.BodyDetection and Config.BodyDetection.Enabled then
            CleanupWagonSpawnedBodies()
            CleanupReportedBodies()
            
            if Config.BodyDetection.AutoNotify then
                CheckForDeadBodies()
            end
        end
    end
end)

local function GetNearbyWagon()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local searchRadius = Config.WagonStorage.StoreRadius or 5.0
    
    local vehicles = GetGamePool('CVehicle')
    local closestWagon = nil
    local closestDist = searchRadius
    
    for _, vehicle in ipairs(vehicles) do
        if DoesEntityExist(vehicle) then
            local vehCoords = GetEntityCoords(vehicle)
            local dist = #(playerCoords - vehCoords)
            
            if dist <= searchRadius and dist < closestDist then
                local model = GetEntityModel(vehicle)
                
                for _, wagonName in ipairs(Config.WagonStorage.WagonModels) do
                    if model == GetHashKey(wagonName) then
                        closestDist = dist
                        closestWagon = vehicle
                        break
                    end
                end
            end
        end
    end
    
    return closestWagon, closestDist
end

local function SpawnDeadBody()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    
    local wagon = GetNearbyWagon()
    local spawnX, spawnY, spawnZ
    
    if wagon and DoesEntityExist(wagon) then
        local wagonCoords = GetEntityCoords(wagon)
        local wagonForward = GetEntityForwardVector(wagon)
        
        spawnX = wagonCoords.x - wagonForward.x * 5.0
        spawnY = wagonCoords.y - wagonForward.y * 5.0
        spawnZ = wagonCoords.z
    else
        local forwardVector = GetEntityForwardVector(playerPed)
        spawnX = playerCoords.x + forwardVector.x * 5.0
        spawnY = playerCoords.y + forwardVector.y * 5.0
        spawnZ = playerCoords.z
    end
    
    local bodyModels = {
        `a_m_m_rancher_01`,
        `gc_skinnertorture_males_01`,
        `mes_finale2_females_01`,
        `mes_finale3_males_01`,
        `u_m_m_valbutcher_01`,
        `cs_fishcollector`,
    }
    
    math.randomseed(GetGameTimer() + math.random(1, 1000))
    math.random()
    math.random()
    math.random()
    
    local modelHash = bodyModels[math.random(#bodyModels)]
    
    if not HasModelLoaded(modelHash) then
        RequestModel(modelHash)
        local timeout = 0
        while not HasModelLoaded(modelHash) and timeout < 100 do
            Wait(10)
            timeout = timeout + 1
        end
    end
    
    if not HasModelLoaded(modelHash) then
        return
    end
    
    local body = CreatePed(modelHash, spawnX, spawnY, spawnZ, 0.0, true, true, true, true)
    
    if not body or body == 0 or not DoesEntityExist(body) then
        SetModelAsNoLongerNeeded(modelHash)
        return
    end
    
    Wait(100)
    
    Citizen.InvokeNative(0x77FF8D35EEC6BBC4, body, 0, false)
    SetEntityHealth(body, 0, 0)
    
    Wait(100)
    
    if not IsEntityDead(body) then
        ApplyDamageToPed(body, 1000, true)
    end
    
    SetEntityAsMissionEntity(body, true, true)
    SetEntityVisible(body, true)
    SetEntityAlpha(body, 255, false)
    PlaceObjectOnGroundProperly(body)
    SetEntityHeading(body, math.random(0, 359) + 0.0)
    
    SetModelAsNoLongerNeeded(modelHash)
    
    wagonSpawnedBodies[body] = true
    DebugPrint('Added body ' .. tostring(body) .. ' to wagon spawned list')
    
    cachedDeadBody = nil
    lastBodyCheck = 0
end

local function StoreBodyInWagon()
    if isDigging or isPraying then return end
    
    local body, dist, entityType = GetNearestDeadBody()
    cachedDeadBody = body
    
    if not body or not DoesEntityExist(body) then
        Notify('Undertaker', Config.Texts.NoBodyNearby, 'error')
        return
    end
    
    local bodyCoords = GetEntityCoords(body)
    local locationName = GetLocationName(bodyCoords)
    
    RSGCore.Functions.TriggerCallback('undertaker:getWagonBodies', function(count)
        if count >= Config.WagonStorage.MaxBodies then
            Notify('Undertaker', Config.Texts.WagonFull, 'error')
            return
        end
        
        if body and DoesEntityExist(body) then
            if wagonSpawnedBodies[body] then
                wagonSpawnedBodies[body] = nil
            end
            
            SetEntityAsMissionEntity(body, true, true)
            DeleteEntity(body)
        end
        
        cachedDeadBody = nil
        lastBodyCheck = 0
        
        TriggerServerEvent('undertaker:storeBodyInWagon', {
            location = locationName,
            entityType = entityType or 'human'
        })
    end)
end

local function RetrieveBodyFromWagon(bodyId)
    if isDigging or isPraying then return end
    
    TriggerServerEvent('undertaker:retrieveBodyFromWagon', bodyId)
end

local function AttachShovel()
    local playerPed = PlayerPedId()

    local shovelModel = Config.Dig.shovel
    local boneName = Config.Dig.bone
    local pos = Config.Dig.pos

    local modelHash = LoadModel(shovelModel)

    if not modelHash then
        DebugPrint('Failed to load shovel model')
        return nil
    end

    local coords = GetEntityCoords(playerPed)
    local prop = CreateObject(modelHash, coords.x, coords.y, coords.z, true, true, false)

    if prop and DoesEntityExist(prop) then
        local boneIndex = GetEntityBoneIndexByName(playerPed, boneName)
        AttachEntityToEntity(
            prop,
            playerPed,
            boneIndex,
            pos[1], pos[2], pos[3],
            pos[4], pos[5], pos[6],
            true, true, false, true, 2, true
        )
        return prop
    end

    return nil
end

local function DetachShovel()
    if shovelProp and DoesEntityExist(shovelProp) then
        DeleteEntity(shovelProp)
        shovelProp = nil
    end
end

local function PlayDiggingAnimation(duration, callback)
    local playerPed = PlayerPedId()

    local animDict = Config.Dig.anim[1]
    local animName = Config.Dig.anim[2]

    if not LoadAnimDict(animDict) then
        if callback then callback(false) end
        return
    end

    isDigging = true

    shovelProp = AttachShovel()

    TaskPlayAnim(playerPed, animDict, animName, 8.0, -8.0, -1, 1, 0, false, false, false)

    Notify('Undertaker', Config.Texts.DiggingGrave, 'info')

    CreateThread(function()
        local startTime = GetGameTimer()
        local endTime = startTime + (duration * 1000)

        while GetGameTimer() < endTime and isDigging do
            Wait(100)

            if not IsEntityPlayingAnim(playerPed, animDict, animName, 3) then
                TaskPlayAnim(playerPed, animDict, animName, 8.0, -8.0, -1, 1, 0, false, false, false)
            end
        end

        ClearPedTasks(playerPed)
        DetachShovel()
        isDigging = false

        if callback then callback(true) end
    end)
end

local function PlayPrayAnimation(duration, callback)
    local playerPed = PlayerPedId()

    local prayAnim = Config.PrayAnim[math.random(#Config.PrayAnim)]

    if not LoadAnimDict(prayAnim[1]) then
        if callback then callback() end
        return
    end

    isPraying = true

    TaskPlayAnim(playerPed, prayAnim[1], prayAnim[2], 8.0, -8.0, -1, 1, 0, false, false, false)

    Notify('Undertaker', Config.Texts.Praying, 'info')

    CreateThread(function()
        Wait(duration * 1000)
        ClearPedTasks(playerPed)
        isPraying = false
        if callback then callback() end
    end)
end

local function CleanupDirtPiles()
    for _, pile in ipairs(createdDirtPiles) do
        if DoesEntityExist(pile) then
            DeleteEntity(pile)
        end
    end
    createdDirtPiles = {}
    DebugPrint('All dirt piles cleaned up')
end

-- NEW FUNCTION: Perform the actual grave burial (extracted from BuryBody)
local function PerformGraveBurial(graveData, body)
    local playerPed = PlayerPedId()

    DebugPrint('Burying body: ' .. tostring(body) .. ' at grave: ' .. (graveData.name or 'Unknown'))

    local bodyToDelete = body
    
    cachedDeadBody = nil
    lastBodyCheck = 0

    SetEntityHeading(playerPed, graveData.heading or 0.0)
    Wait(300)

    PlayDiggingAnimation(Config.DiggingTimer, function(completed)
        if completed then
            if bodyToDelete and DoesEntityExist(bodyToDelete) then
                if wagonSpawnedBodies[bodyToDelete] then
                    wagonSpawnedBodies[bodyToDelete] = nil
                    DebugPrint('Removed body from wagon spawned list (buried)')
                end
                
                SetEntityAsMissionEntity(bodyToDelete, true, true)
                DeleteEntity(bodyToDelete)
                DebugPrint('Body deleted after digging')
            end
            
            local pCoords = GetEntityCoords(playerPed)
            local forwardVector = GetEntityForwardVector(playerPed)
            local playerHeading = GetEntityHeading(playerPed)
            
            -- Calculate grave position for grave text
            local graveOffsetFwd = Config.DirtPile and Config.DirtPile.OffsetForward or 0.6
            local graveX = pCoords.x + forwardVector.x * graveOffsetFwd
            local graveY = pCoords.y + forwardVector.y * graveOffsetFwd
            local graveZ = pCoords.z
            local graveCoords = vector3(graveX, graveY, graveZ)
            
            -- Create dirt pile
            if Config.DirtPile and Config.DirtPile.Enabled then
                local dirtModel = Config.DirtPile.Model
                local dirtHash = GetHashKey(dirtModel)
                RequestModel(dirtHash)
                local timeout = 0
                while not HasModelLoaded(dirtHash) and timeout < 100 do
                    Wait(10)
                    timeout = timeout + 1
                end

                if HasModelLoaded(dirtHash) then
                    local offsetFwd = Config.DirtPile.OffsetForward or 0.6
                    local offsetZ = Config.DirtPile.OffsetZ or -1.0

                    local objX = pCoords.x + forwardVector.x * offsetFwd
                    local objY = pCoords.y + forwardVector.y * offsetFwd
                    local objZ = pCoords.z + offsetZ

                    local dirtPile = CreateObject(dirtHash, objX, objY, objZ, true, true, false)
                    SetEntityHeading(dirtPile, playerHeading)
                    table.insert(createdDirtPiles, dirtPile)
                    SetModelAsNoLongerNeeded(dirtHash)
                    
                    DebugPrint('Dirt pile created: ' .. tostring(dirtPile))
                end
            end
            
            -- Create grave marker
            if Config.GraveMarker and Config.GraveMarker.Enabled then
                local markerModel = Config.GraveMarker.Model
                local markerHash = GetHashKey(markerModel)
                RequestModel(markerHash)
                local timeout = 0
                while not HasModelLoaded(markerHash) and timeout < 100 do
                    Wait(10)
                    timeout = timeout + 1
                end

                if HasModelLoaded(markerHash) then
                    local offsetFwd = Config.GraveMarker.OffsetForward or 1.2
                    local offsetZ = Config.GraveMarker.OffsetZ or -1.0

                    local objX = pCoords.x + forwardVector.x * offsetFwd
                    local objY = pCoords.y + forwardVector.y * offsetFwd
                    local objZ = pCoords.z + offsetZ

                    local graveMarker = CreateObject(markerHash, objX, objY, objZ, true, true, false)
                    SetEntityHeading(graveMarker, playerHeading + 180.0)
                    PlaceObjectOnGroundProperly(graveMarker)
                    table.insert(createdDirtPiles, graveMarker)
                    SetModelAsNoLongerNeeded(markerHash)
                    
                    DebugPrint('Grave marker created: ' .. tostring(graveMarker))
                end
            end
            
            -- Generate name for grave text
            local bodyName = nil
            if currentBurialName then
                bodyName = currentBurialName
                currentBurialName = nil
            elseif Config.RandomNames and Config.RandomNames.FirstNames and Config.RandomNames.LastNames then
                local firstName = Config.RandomNames.FirstNames[math.random(#Config.RandomNames.FirstNames)]
                local lastName = Config.RandomNames.LastNames[math.random(#Config.RandomNames.LastNames)]
                bodyName = firstName .. ' ' .. lastName
            else
                bodyName = "Unknown"
            end
            
            AddGraveText(graveCoords, bodyName, 'human')
            
            PlayPrayAnimation(3, function()
                TriggerServerEvent('undertaker:buryBody', 'human')
                Notify('Undertaker', Config.Texts.BurialComplete, 'success')
            end)
        end
    end)
end

-- MODIFIED: Main BuryBody function with shovel check
local function BuryBody(graveData)
    if isDigging then
        Notify('Undertaker', Config.Texts.AlreadyDigging, 'error')
        return
    end

    cachedDeadBody = GetNearestDeadBody()
    local body = cachedDeadBody

    if not body or not DoesEntityExist(body) then
        Notify('Undertaker', Config.Texts.NoBodyNearby, 'error')
        return
    end

    -- Check for shovel if required
    if Config.RequireShovel then
        RSGCore.Functions.TriggerCallback('undertaker:hasShovel', function(hasShovel)
            if not hasShovel then
                Notify('Undertaker', Config.Texts.NoShovel or 'You need a shovel to bury bodies', 'error')
                return
            end
            PerformGraveBurial(graveData, body)
        end)
    else
        PerformGraveBurial(graveData, body)
    end
end

local function PerformBurialAnywhere(body, burialType)
    if not body or not DoesEntityExist(body) then
        Notify('Undertaker', Config.Texts.NoBodyNearby, 'error')
        return
    end

    local playerPed = PlayerPedId()
    local bodyCoords = GetEntityCoords(body)
    
    currentBurialType = burialType or 'human'
    DebugPrint('Burying ' .. currentBurialType .. ' anywhere: ' .. tostring(body))

    local bodyToDelete = body
    cachedDeadBody = nil
    lastBodyCheck = 0

    local playerCoords = GetEntityCoords(playerPed)
    local heading = GetHeadingFromVector_2d(bodyCoords.x - playerCoords.x, bodyCoords.y - playerCoords.y)
    SetEntityHeading(playerPed, heading)
    Wait(300)

    PlayDiggingAnimation(Config.DiggingTimer, function(completed)
        if completed then
            if bodyToDelete and DoesEntityExist(bodyToDelete) then
                if wagonSpawnedBodies[bodyToDelete] then
                    wagonSpawnedBodies[bodyToDelete] = nil
                end
                SetEntityAsMissionEntity(bodyToDelete, true, true)
                DeleteEntity(bodyToDelete)
            end
            
            local pCoords = GetEntityCoords(playerPed)
            local forwardVector = GetEntityForwardVector(playerPed)
            local playerHeading = GetEntityHeading(playerPed)
            
            local graveOffsetFwd = Config.DirtPile and Config.DirtPile.OffsetForward or 0.6
            local graveX = pCoords.x + forwardVector.x * graveOffsetFwd
            local graveY = pCoords.y + forwardVector.y * graveOffsetFwd
            local graveZ = pCoords.z
            local graveCoords = vector3(graveX, graveY, graveZ)
            
            if Config.DirtPile and Config.DirtPile.Enabled then
                local dirtHash = GetHashKey(Config.DirtPile.Model)
                RequestModel(dirtHash)
                while not HasModelLoaded(dirtHash) do Wait(10) end

                local offsetFwd = Config.DirtPile.OffsetForward or 0.6
                local offsetZ = Config.DirtPile.OffsetZ or -1.0
                local objX = pCoords.x + forwardVector.x * offsetFwd
                local objY = pCoords.y + forwardVector.y * offsetFwd
                local objZ = pCoords.z + offsetZ

                local dirtPile = CreateObject(dirtHash, objX, objY, objZ, true, true, false)
                SetEntityHeading(dirtPile, playerHeading)
                table.insert(createdDirtPiles, dirtPile)
                SetModelAsNoLongerNeeded(dirtHash)
            end
            
            if Config.GraveMarker and Config.GraveMarker.Enabled then
                local markerHash = GetHashKey(Config.GraveMarker.Model)
                RequestModel(markerHash)
                while not HasModelLoaded(markerHash) do Wait(10) end

                local offsetFwd = Config.GraveMarker.OffsetForward or 1.2
                local offsetZ = Config.GraveMarker.OffsetZ or -1.0
                local objX = pCoords.x + forwardVector.x * offsetFwd
                local objY = pCoords.y + forwardVector.y * offsetFwd
                local objZ = pCoords.z + offsetZ

                local graveMarker = CreateObject(markerHash, objX, objY, objZ, true, true, false)
                SetEntityHeading(graveMarker, playerHeading + 180.0)
                PlaceObjectOnGroundProperly(graveMarker)
                table.insert(createdDirtPiles, graveMarker)
                SetModelAsNoLongerNeeded(markerHash)
            end
            
            local bodyName = nil
            if currentBurialName then
                bodyName = currentBurialName
                currentBurialName = nil
            elseif currentBurialType == 'animal' then
                local animalNames = {
                    "Bessie", "Buck", "Shadow", "Scout", "Whiskey",
                    "Daisy", "Thunder", "Midnight", "Spirit", "Copper",
                    "Duke", "Belle", "Chief", "Bandit", "Lucky",
                    "Rex", "Patches", "Storm", "Ranger", "Pearl"
                }
                bodyName = animalNames[math.random(#animalNames)]
            else
                if Config.RandomNames and Config.RandomNames.FirstNames and Config.RandomNames.LastNames then
                    local firstName = Config.RandomNames.FirstNames[math.random(#Config.RandomNames.FirstNames)]
                    local lastName = Config.RandomNames.LastNames[math.random(#Config.RandomNames.LastNames)]
                    bodyName = firstName .. ' ' .. lastName
                else
                    bodyName = "Unknown"
                end
            end
            
            AddGraveText(graveCoords, bodyName, currentBurialType)
            
            PlayPrayAnimation(3, function()
                TriggerServerEvent('undertaker:buryBody', currentBurialType)
                Notify('Undertaker', Config.Texts.BurialComplete, 'success')
            end)
        end
    end)
end

local function BuryBodyAnywhere()
    if isDigging then
        Notify('Undertaker', Config.Texts.AlreadyDigging, 'error')
        return
    end

    local body, dist, entityType = GetNearestDeadBody()
    cachedDeadBody = body

    if not body or not DoesEntityExist(body) then
        Notify('Undertaker', Config.Texts.NoBodyNearby, 'error')
        return
    end
    
    if entityType == 'animal' and (not Config.AnywhereBurial or not Config.AnywhereBurial.AllowAnimals) then
        Notify('Undertaker', 'Cannot bury animals', 'error')
        return
    end

    if Config.RequireShovel then
        RSGCore.Functions.TriggerCallback('undertaker:hasShovel', function(hasShovel)
            if not hasShovel then
                Notify('Undertaker', Config.Texts.NoShovel or 'You need a shovel to bury bodies', 'error')
                return
            end
            PerformBurialAnywhere(body, entityType)
        end)
    else
        PerformBurialAnywhere(body, entityType)
    end
end

local function PrayAtGrave(graveData)
    if isPraying or isDigging then
        return
    end

    local playerPed = PlayerPedId()
    SetEntityHeading(playerPed, graveData.heading or 0.0)
    Wait(200)

    PlayPrayAnimation(5, function()
        Notify('Undertaker', 'You paid your respects.', 'info')
    end)
end

local OpenWagonMenu

local function OpenBodyOptionsMenu(body)
    local icon = body.entityType == 'animal' and 'fas fa-paw' or 'fas fa-user'
    local typeLabel = body.entityType == 'animal' and ' (Animal)' or ''
    
    local options = {
        {
            title = body.name .. typeLabel,
            description = 'Found in: ' .. body.location,
            icon = icon,
            disabled = true
        },
        {
            title = 'Retrieve Body',
            description = 'Remove body from wagon',
            icon = 'fas fa-box-open',
            onSelect = function()
                if isDigging or isPraying then return end
                currentBurialName = body.name
                TriggerServerEvent('undertaker:retrieveBodyFromWagon', body.id)
            end
        },
        {
            title = 'Back',
            icon = 'fas fa-arrow-left',
            onSelect = function()
                OpenWagonMenu()
            end
        }
    }
    
    lib.registerContext({
        id = 'undertaker_body_options',
        title = 'Body Details',
        options = options
    })
    
    lib.showContext('undertaker_body_options')
end

OpenWagonMenu = function()
    RSGCore.Functions.TriggerCallback('undertaker:getWagonBodyList', function(bodies)
        local options = {}
        
        if #bodies == 0 then
            options[#options + 1] = {
                title = 'Wagon is Empty',
                description = 'No bodies stored in wagon',
                icon = 'fas fa-box-open',
                disabled = true
            }
        else
            options[#options + 1] = {
                title = 'Bodies in Wagon: ' .. #bodies .. '/' .. Config.WagonStorage.MaxBodies,
                icon = 'fas fa-skull',
                disabled = true
            }
            
            for i, body in ipairs(bodies) do
                local icon = body.entityType == 'animal' and 'fas fa-paw' or 'fas fa-cross'
                local typeLabel = body.entityType == 'animal' and ' (Animal)' or ''
                
                options[#options + 1] = {
                    title = body.name .. typeLabel,
                    description = 'Found in: ' .. body.location .. '\nStored: ' .. body.storedAt,
                    icon = icon,
                    onSelect = function()
                        OpenBodyOptionsMenu(body)
                    end
                }
            end
        end
        
        options[#options + 1] = {
            title = 'Close',
            icon = 'fas fa-times',
            onSelect = function()
            end
        }
        
        lib.registerContext({
            id = 'undertaker_wagon_menu',
            title = 'Undertaker Wagon',
            options = options
        })
        
        lib.showContext('undertaker_wagon_menu')
    end)
end

local function RegisterBuryAnywhereTarget()
    if not Config.AnywhereBurial or not Config.AnywhereBurial.Enabled then
        return
    end
    
    if Config.BurialMode ~= 'anywhere' then
        return
    end
    
    exports['ox_target']:addGlobalPed({
        {
            name = 'undertaker_bury_human',
            icon = 'fas fa-cross',
            label = 'Bury Body',
            distance = 3.0,
            canInteract = function(entity)
                if not IsUndertaker() then return false end
                if isDigging or isPraying then return false end
                if not DoesEntityExist(entity) then return false end
                if IsPedAPlayer(entity) then return false end
                
                local pedType = GetPedType(entity)
                if pedType == 28 then return false end
                
                local isDead = IsEntityDead(entity)
                local health = GetEntityHealth(entity)
                
                return isDead or health <= 0
            end,
            onSelect = function(data)
                cachedDeadBody = data.entity
                BuryBodyAnywhere()
            end
        },
        {
            name = 'undertaker_store_human',
            icon = 'fas fa-box',
            label = 'Store in Wagon',
            distance = 3.0,
            canInteract = function(entity)
                if not IsUndertaker() then return false end
                if isDigging or isPraying then return false end
                if not DoesEntityExist(entity) then return false end
                if IsPedAPlayer(entity) then return false end
                
                local pedType = GetPedType(entity)
                if pedType == 28 then return false end
                
                local isDead = IsEntityDead(entity)
                local health = GetEntityHealth(entity)
                
                if not isDead and health > 0 then return false end
                
                local wagon = GetNearbyWagon()
                return wagon ~= nil
            end,
            onSelect = function(data)
                cachedDeadBody = data.entity
                StoreBodyInWagon()
            end
        }
    })
    
    if Config.AnywhereBurial.AllowAnimals then
        CreateThread(function()
            while true do
                Wait(2000)
                
                if not IsUndertaker() then
                    goto continue
                end
                
                if isDigging or isPraying then
                    goto continue
                end
                
                local playerPed = PlayerPedId()
                local playerCoords = GetEntityCoords(playerPed)
                local peds = GetGamePool('CPed')
                
                for _, ped in ipairs(peds) do
                    if DoesEntityExist(ped) and ped ~= playerPed and not IsPedAPlayer(ped) then
                        local pedCoords = GetEntityCoords(ped)
                        local dist = #(playerCoords - pedCoords)
                        
                        if dist < 15.0 then
                            local isDead = IsEntityDead(ped)
                            local health = GetEntityHealth(ped)
                            local pedType = GetPedType(ped)
                            
                            if pedType == 28 and (isDead or health <= 0) and not targetedEntities[ped] then
                                targetedEntities[ped] = true
                                
                                local zoneId = 'deadanimal_' .. tostring(ped)
                                
                                exports['ox_target']:addSphereZone({
                                    coords = pedCoords,
                                    radius = 1.5,
                                    debug = Config.Debug,
                                    options = {
                                        {
                                            name = 'undertaker_bury_animal_' .. tostring(ped),
                                            icon = 'fas fa-paw',
                                            label = 'Bury Animal',
                                            distance = 3.0,
                                            canInteract = function()
                                                return IsUndertaker() and not isDigging and not isPraying and DoesEntityExist(ped)
                                            end,
                                            onSelect = function()
                                                if not DoesEntityExist(ped) then
                                                    Notify('Undertaker', 'Body no longer exists', 'error')
                                                    return
                                                end
                                                cachedDeadBody = ped
                                                -- Changed to use BuryBodyAnywhere which includes shovel check
                                                currentBurialType = 'animal'
                                                BuryBodyAnywhere()
                                            end
                                        },
                                        {
                                            name = 'undertaker_store_animal_' .. tostring(ped),
                                            icon = 'fas fa-box',
                                            label = 'Store Animal in Wagon',
                                            distance = 3.0,
                                            canInteract = function()
                                                if not IsUndertaker() then return false end
                                                if isDigging or isPraying then return false end
                                                if not DoesEntityExist(ped) then return false end
                                                local wagon = GetNearbyWagon()
                                                return wagon ~= nil
                                            end,
                                            onSelect = function()
                                                if not DoesEntityExist(ped) then
                                                    Notify('Undertaker', 'Body no longer exists', 'error')
                                                    return
                                                end
                                                cachedDeadBody = ped
                                                StoreBodyInWagon()
                                            end
                                        }
                                    }
                                })
                                
                                createdZones[ped] = zoneId
                            end
                        end
                    end
                end
                
                for ped, zoneId in pairs(createdZones) do
                    if not DoesEntityExist(ped) then
                        targetedEntities[ped] = nil
                        createdZones[ped] = nil
                    end
                end
                
                ::continue::
            end
        end)
    end
end

local function RegisterGraveTargets()
    if not Config then
        return
    end
    
    if not Config.Graves then
        return
    end

    for i, grave in pairs(Config.Graves) do
        exports['ox_target']:addSphereZone({
            coords = grave.coords,
            radius = 1.5,
            debug = Config.Debug,
            options = {
                {
                    name = 'undertaker_bury_' .. i,
                    icon = 'fas fa-cross',
                    label = 'Bury Body',
                    distance = 2.5,
                    canInteract = function()
                        local isJob = IsUndertaker()
                        local isBusy = isDigging or isPraying
                        local hasBody = IsDeadBodyNearby()
                        
                        DebugPrint('Bury canInteract: Job=' .. tostring(isJob) .. ' Busy=' .. tostring(isBusy) .. ' Body=' .. tostring(hasBody))
                        
                        if not isJob then return false end
                        if isBusy then return false end
                        return hasBody
                    end,
                    onSelect = function()
                        cachedDeadBody = GetNearestDeadBody()
                        BuryBody(grave)
                    end
                },
                {
                    name = 'undertaker_pray_' .. i,
                    icon = 'fas fa-praying-hands',
                    label = 'Pay Respects',
                    distance = 2.5,
                    canInteract = function()
                        local isJob = IsUndertaker()
                        local isBusy = isDigging or isPraying
                        
                        DebugPrint('Pray canInteract: Job=' .. tostring(isJob) .. ' Busy=' .. tostring(isBusy))
                        
                        if not isJob then return false end
                        if isBusy then return false end
                        return true
                    end,
                    onSelect = function()
                        PrayAtGrave(grave)
                    end
                }
            }
        })
    end
end

local function RegisterWagonTargets()
    if not Config.WagonStorage or not Config.WagonStorage.Enabled then
        return
    end
    
    local targetOptions = {
        {
            name = 'undertaker_store_body',
            icon = 'fas fa-box',
            label = 'Store Body in Wagon',
            distance = 3.0,
            canInteract = function()
                if not IsUndertaker() then return false end
                if isDigging or isPraying then return false end
                return IsDeadBodyNearby()
            end,
            onSelect = function()
                StoreBodyInWagon()
            end
        },
        {
            name = 'undertaker_check_wagon',
            icon = 'fas fa-clipboard-list',
            label = 'Check Wagon',
            distance = 3.0,
            canInteract = function()
                return IsUndertaker()
            end,
            onSelect = function()
                OpenWagonMenu()
            end
        }
    }
    
    for _, wagonModel in ipairs(Config.WagonStorage.WagonModels) do
        exports['ox_target']:addModel(wagonModel, targetOptions)
    end
    
    DebugPrint('Wagon targets registered for ' .. #Config.WagonStorage.WagonModels .. ' wagon models')
end

RegisterNetEvent('undertaker:wagonStorageResult', function(success, action, count)
    wagonBodyCount = count
    
    if success then
        if action == 'stored' then
            Notify('Undertaker', Config.Texts.BodyStored .. ' (' .. count .. '/' .. Config.WagonStorage.MaxBodies .. ')', 'success')
        elseif action == 'retrieved' then
            SpawnDeadBody()
            Notify('Undertaker', Config.Texts.BodyRetrieved .. ' (' .. count .. '/' .. Config.WagonStorage.MaxBodies .. ')', 'success')
        end
    else
        if action == 'full' then
            Notify('Undertaker', Config.Texts.WagonFull, 'error')
        elseif action == 'empty' then
            Notify('Undertaker', Config.Texts.WagonEmpty, 'error')
        end
    end
end)

RegisterNetEvent('undertaker:burialSuccess', function(payment)
    Notify('Undertaker', 'Received $' .. payment .. ' for burial services', 'success')
end)

RegisterNetEvent('undertaker:deathReportReceived', function(data)
    if not IsUndertaker() then return end
    
    Notify('Undertaker', Config.Texts.DeathReportReceived .. ' - ' .. data.location, 'info')
    
    SetTimeout(1000, function()
        SetBodyWaypoint(data.coords, Config.Texts.GPSSet)
    end)
end)

RegisterNetEvent('undertaker:reportReward', function(amount)
    Notify('Death Report', string.format(Config.Texts.ReportReward, amount), 'success')
end)

CreateThread(function()
    Wait(2000)
    
    if not Config then
        return
    end
    
    if Config.BurialMode == 'graves' then
        RegisterGraveTargets()
    end
    
    if Config.BurialMode == 'anywhere' then
        RegisterBuryAnywhereTarget()
    end
    
    RegisterWagonTargets()
    
    DebugPrint('Undertaker script initialized - Mode: ' .. (Config.BurialMode or 'graves'))
end)

CreateThread(function()
    Wait(3000)
    
    if Config.DeathReport and Config.DeathReport.Enabled then
        local commandName = Config.DeathReport.Command or 'reportdeath'
        
        RegisterCommand(commandName, function()
            ReportDeath()
        end, false)
        
        DebugPrint('Death report command registered: /' .. commandName)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        DetachShovel()
        CleanupDirtPiles()
        ClearBodyWaypoint()
        
        for ped, _ in pairs(targetedEntities) do
            if DoesEntityExist(ped) then
                exports['ox_target']:removeLocalEntity(ped, {'undertaker_bury_' .. tostring(ped), 'undertaker_store_' .. tostring(ped)})
            end
        end
        targetedEntities = {}
        
        graveTexts = {}

        if isDigging or isPraying then
            local playerPed = PlayerPedId()
            ClearPedTasks(playerPed)
        end
    end
end)
