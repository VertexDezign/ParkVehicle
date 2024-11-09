--- loader for park vehicle

local directory = g_currentModDirectory
local modName = g_currentModName


source(Utils.getFilename("ParkVehicleSystem.lua", directory))

local function validateVehicleTypes(typeManager)
    print("PA: validateVehicleTypes")
    if typeManager.typeName == "vehicle" then
        g_parkVehicleSystem:installSpecialization(g_vehicleTypeManager, g_specializationManager)
    end
end

local function registerActionEvents()
    print("PA: registerActionEvents")
    g_parkVehicleSystem:registerActionEvents()
end

local function unregisterActionEvents()
    print("PA: unregisterActionEvents")
    g_parkVehicleSystem:unregisterActionEvents()
end

local function init()
    g_parkVehicleSystem = ParkVehicleSystem:new(modName, directory, g_inputBinding, false)

    TypeManager.validateTypes = Utils.prependedFunction(TypeManager.validateTypes, validateVehicleTypes)

    --FSBaseMission.registerActionEvents = Utils.appendedFunction(FSBaseMission.registerActionEvents, registerActionEvents)
    --BaseMission.unregisterActionEvents = Utils.appendedFunction(BaseMission.unregisterActionEvents, unregisterActionEvents)
end

init()