--[[
    Server is the single source of truth for the elevator *state*.
    It never tracks the prop's position - only which floor each elevator is on
    and whether it is currently moving. Clients run the motion themselves from a
    broadcast, so everyone stays in sync without networking the prop.
]]

local Elevators = {}

for id in pairs(Config.Elevators) do
    Elevators[id] = {
        current = 1,            -- floor the elevator is on
        transitioning = false,  -- true while it is moving
    }
end

local function GetState(id)
    local elevator = Elevators[id]
    if not elevator then return nil end

    return {
        floor = elevator.current,
        transitioning = elevator.transitioning,
    }
end

-- Clients ask for the state so they can place the prop on the correct floor.
lib.callback.register('elevator:server:getState', function(_, id)
    return GetState(tonumber(id))
end)

-- A player wants to move an elevator to a floor.
RegisterNetEvent('elevator:server:call', function(id, floorIndex)
    local src = source
    id = tonumber(id)
    floorIndex = tonumber(floorIndex)

    local info = id and Config.Elevators[id]
    local elevator = id and Elevators[id]
    if not info or not elevator then return end

    if elevator.transitioning then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'The elevator is already moving.' })
        return
    end

    local floor = floorIndex and info.floors[floorIndex]
    if not floor or floorIndex == elevator.current then return end

    local fromCoords = info.floors[elevator.current].coords

    elevator.transitioning = true
    elevator.current = floorIndex

    -- Broadcast the same deterministic tween to every client.
    TriggerClientEvent('elevator:client:move', -1, id, fromCoords, floor.coords, info.travelTime)

    -- Release the lock once the ride is finished.
    SetTimeout(info.travelTime, function()
        if Elevators[id] then
            Elevators[id].transitioning = false
        end
    end)
end)
