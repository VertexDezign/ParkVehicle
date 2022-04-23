--- loader for park vehicle

local directory = g_currentModDirectory
local modName = g_currentModName


source(Utils.getFilename("ParkVehicleSystem.lua", directory))


local function validateVehicleTypes(typeManager)
    if typeManager.typeName == "vehicle" then
        g_parkVehicleSystem:installSpecialization(g_vehicleTypeManager, g_specializationManager)
    end
end

local function registerActionEvents()
    g_parkVehicleSystem:registerActionEvents()
end

local function unregisterActionEvents()
    g_parkVehicleSystem:unregisterActionEvents()
end

local function init()
    g_parkVehicleSystem = ParkVehicleSystem:new(modName, directory, g_inputBinding, true)

    TypeManager.validateTypes = Utils.prependedFunction(TypeManager.validateTypes, validateVehicleTypes)

    FSBaseMission.registerActionEvents = Utils.appendedFunction(FSBaseMission.registerActionEvents, registerActionEvents)
    BaseMission.unregisterActionEvents = Utils.appendedFunction(BaseMission.unregisterActionEvents, unregisterActionEvents)
end

init()