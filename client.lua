local Spawned = {} -- [id] = { prop = entity }


-- Draw a 3D text label at the given world coordinates
local function DrawText3D(x, y, z, text)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry('STRING')
    SetTextCentre(true)
    AddTextComponentString(text)
    SetDrawOrigin(x, y, z, 0)
    DrawText(0.0, 0.0)
    local factor = (string.len(text)) / 370
    DrawRect(0.0, 0.0125, 0.017 + factor, 0.03, 0, 0, 0, 75)
    ClearDrawOrigin()
end

-- Return the platform entity for an elevator if it is currently spawned.
local function GetProp(id)
    local data = Spawned[id]
    if data and data.prop and DoesEntityExist(data.prop) then
        return data.prop
    end
    return nil
end

-- Ask the server for the current elevator state (floor + moving). Wrapped so a
-- missing/unregistered server callback degrades gracefully instead of erroring
-- the calling thread (e.g. if the resource was only reconnected, not restarted).
local function GetElevatorState(id)
    local ok, state = pcall(lib.callback.await, 'elevator:server:getState', false, id)

    if not ok then
        print('^1[elevator] callback "elevator:server:getState" failed - restart the resource so server.lua loads.^0')
        return nil
    end

    return type(state) == 'table' and state or nil
end

-- Create the local (non-networked) platform on the elevator's current floor.
-- Local props are smooth on every client and cost nothing against the networked
-- object budget - we sync the movement with events instead.
local function SpawnElevator(id)
    local info = Config.Elevators[id]
    if not info or GetProp(id) then return end

    local state = GetElevatorState(id)
    local floor = info.floors[state and state.floor or 1] or info.floors[1]

    lib.requestModel(info.model)
    local prop = CreateObject(info.model, floor.coords.x, floor.coords.y, floor.coords.z, false, false, false)
    SetEntityAsMissionEntity(prop, true, true)
    SetEntityHeading(prop, floor.heading or 0.0)
    FreezeEntityPosition(prop, true)
    SetModelAsNoLongerNeeded(info.model)

    Spawned[id] = { prop = prop }
end

-- Remove the platform when the player leaves the area so we don't leak entities.
local function DespawnElevator(id)
    local data = Spawned[id]
    if not data then return end

    if data.prop and DoesEntityExist(data.prop) then
        DeleteObject(data.prop)
    end

    Spawned[id] = nil
end

-- Is the local player standing on the platform (and so should ride it)?
local function IsPedOnPlatform(ped, prop, id)
    local info = Config.Elevators[id]
    local pc = GetEntityCoords(ped)
    local ec = GetEntityCoords(prop)
    local dx, dy = pc.x - ec.x, pc.y - ec.y
    local horizontal = math.sqrt(dx * dx + dy * dy)
    local vertical = pc.z - ec.z

    return horizontal <= (info.platformRadius or 1.5) and vertical >= -0.5 and vertical <= 2.5
end

-- Floor selection menu (ox_lib context menu).
local function OpenFloorMenu(id)
    local info = Config.Elevators[id]
    if not info then return end

    local state = GetElevatorState(id)
    local current = state and state.floor or 1

    local options = {}
    for index, floor in ipairs(info.floors) do
        options[#options + 1] = {
            title = floor.label,
            description = index == current and 'You are here' or nil,
            disabled = index == current,
            onSelect = function()
                TriggerServerEvent('elevator:server:call', id, index)
            end,
        }
    end

    lib.registerContext({
        id = ('elevator_menu_%s'):format(id),
        title = info.title or 'Select a floor',
        options = options,
    })
    lib.showContext(('elevator_menu_%s'):format(id))
end

-- The server tells every client to move the platform. Because they all run the
-- exact same tween for the exact same duration, everyone sees identical motion.
RegisterNetEvent('elevator:client:move', function(id, fromCoords, toCoords, duration)
    local prop = GetProp(id)
    if not prop then return end

    local ped = PlayerPedId()
    local riding = IsPedOnPlatform(ped, prop, id) and not IsPedInAnyVehicle(ped, false)

    -- Make sure this client starts from the same position as everyone else.
    SetEntityCoords(prop, fromCoords.x, fromCoords.y, fromCoords.z, false, false, false, false)

    if riding then
        SetEntityVelocity(ped, 0.0, 0.0, 0.0)
        FreezeEntityPosition(ped, true)
    end

    local previous = fromCoords
    local step = lib.math.lerp(fromCoords, toCoords, duration)
    local coords, progress = step()

    while progress < 1.0 do
        if riding then
            -- A frozen platform won't carry a ped, so move the player by the
            -- same offset the platform just moved.
            local pedCoords = GetEntityCoords(ped) + (coords - previous)
            SetEntityCoords(ped, pedCoords.x, pedCoords.y, pedCoords.z, false, false, false, false)
        end

        SetEntityCoords(prop, coords.x, coords.y, coords.z, false, false, false, false)
        previous = coords

        coords, progress = step()
    end

    SetEntityCoords(prop, toCoords.x, toCoords.y, toCoords.z, false, false, false, false)

    if riding then
        FreezeEntityPosition(ped, false)
    end
end)

-- Spawn the prop while the player is in range so it is only loaded when needed.
for id, info in pairs(Config.Elevators) do
    local centre = vec3(0.0, 0.0, 0.0)
    local count = 0

    for _, floor in pairs(info.floors) do
        centre = centre + floor.coords
        count += 1
    end

    centre = vec3(centre.x / count, centre.y / count, centre.z / count)

    lib.zones.sphere({
        coords = centre,
        radius = info.zoneRadius or 50.0,
        onEnter = function()
            CreateThread(function()
                SpawnElevator(id)
            end)
        end,
        onExit = function()
            DespawnElevator(id)
        end,
    })
end

-- Interaction prompt.
Citizen.CreateThread(function()
    while true do
        local wait = 1000
        local ped = PlayerPedId()
        local playerCoords = GetEntityCoords(ped)

        for id in pairs(Spawned) do
            local prop = GetProp(id)

            if prop then
                local coords = GetEntityCoords(prop)

                if #(playerCoords - coords) < Config.Elevators[id].callDist then
                    wait = 0
                    DrawText3D(coords.x, coords.y, coords.z + 1.2, '[E] Call Elevator')

                    if IsControlJustReleased(0, 38) then -- E
                        OpenFloorMenu(id)
                    end
                end
            end
        end

        Wait(wait)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for id in pairs(Spawned) do
        DespawnElevator(id)
    end
end)