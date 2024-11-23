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
    g_parkVehicleSystem = ParkVehicleSystem:new(modName, directory, g_inputBinding, false)

    TypeManager.validateTypes = Utils.prependedFunction(TypeManager.validateTypes, validateVehicleTypes)

    --FSBaseMission.onStartMission = Utils.appendedFunction(FSBaseMission.onStartMission, registerActionEvents)
    --FSBaseMission.onEnterVehicle = Utils.appendedFunction(FSBaseMission.onEnterVehicle, registerActionEvents)
    --FSBaseMission.onLeaveVehicle = Utils.appendedFunction(FSBaseMission.onLeaveVehicle, registerActionEvents)
    --FSBaseMission.delete = Utils.appendedFunction(FSBaseMission.delete, unregisterActionEvents)
end

init()