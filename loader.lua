--- loader for park vehicle

local directory = g_currentModDirectory
local modName = g_currentModName


source(Utils.getFilename("ParkVehicleSystem.lua", directory))


function init()
    g_parkVehicleSystem = ParkVehicleSystem:new(modName, directory, true)

    TypeManager.validateTypes = Utils.prependedFunction(TypeManager.validateTypes, validateVehicleTypes)
end

function validateVehicleTypes(typeManager)
    if typeManager.typeName == "vehicle" then
        g_parkVehicleSystem:installSpecialization(g_vehicleTypeManager, g_specializationManager)
    end
end

init()