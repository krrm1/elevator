Config = {}

-- Each elevator can have any number of floors.
-- The floors table must be a contiguous array; floor 1 is the default floor.
Config.Elevators = {
    [1] = {
        title = 'Elevator',                    -- context menu title
        model = `prop_test_elevator`,          -- the platform prop that moves
        travelTime = 10000,                     -- ms to travel between any two floors
        zoneRadius = 50.0,                      -- the prop is spawned while the player is within this radius
        callDist = 2.5,                         -- how close to the platform to show the [E] prompt
        platformRadius = 1.6,                   -- platform footprint used to detect who is riding
        floors = {
            [1] = { label = 'Ground Floor', coords = vec3(161.43, -984.55, 31.0), heading = 157.54 },
            [2] = { label = 'Rooftop', coords = vec3(161.17, -985.0, 51.09), heading = 157.54 },
        },
    },
}

