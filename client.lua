local elev1, elev2, elev3 = false, false, false   -- state flags


-- Draw a 3D text label at the given world coordinates
local function DrawText3D(x, y, z, text)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
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

local function CallElevator()
    if elev1 == true then
        print('Elevator 1 called')
    elseif elev2 == true then
        print('Elevator 2 called')
    elseif elev3 == true then
        print('Elevator 3 called')
    end
end

Citizen.CreateThread(function()
    while true do
        Wait(0)
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local elevatorCoords = Config.elevator.elevator_coords_v3
        local distance = #(playerCoords - elevatorCoords)

        if distance < 2.0 then
            DrawText3D(elevatorCoords.x, elevatorCoords.y, elevatorCoords.z + 1.0, "[E] Call Elevator")
            if IsControlJustReleased(0, 38) then -- E key
                print('calling elevator...')
            end
        end
    end
end)

RegisterCommand('elevator', function()
    elev1 = true

    Wait(500)

    CallElevator()

    elev1 = false
    elev2 = true

    Wait(1000)

    CallElevator()

    elev2 = false
    elev3 = true

    Wait(1500 )

    CallElevator()

    elev3 = false
end, false)