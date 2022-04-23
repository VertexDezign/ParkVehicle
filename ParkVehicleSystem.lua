--- Global instance of park vehicle.
---@class ParkVehicleSystem
---@field modName string
---@field modDir string
---@field debug boolean
ParkVehicleSystem = {}

local ParkVehicleSystem_mt = Class(ParkVehicleSystem)

---
---@param modName string
---@param modDir string
---@return ParkVehicleSystem
function ParkVehicleSystem:new(modName, modDir, debug)
    local self = {}

    setmetatable(self, ParkVehicleSystem_mt)

    self.modName = modName
    self.modDir = modDir
    self.debug = debug

    return self
end

---@param typeManager VehicleTypeManager
---@param specManager SpecializationManager
function ParkVehicleSystem:installSpecialization(typeManager, specManager)
    -- register spec
    specManager:addSpecialization("parkVehicle", "ParkVehicle", Utils.getFilename("ParkVehicle.lua", self.modDir), nil)

    -- add spec to vehicle types
    local totalCount = 0
    local modified = 0
    for typeName, typeEntry in pairs(typeManager:getTypes()) do
        totalCount = totalCount + 1
        if SpecializationUtil.hasSpecialization(Enterable, typeEntry.specializations) and
            not SpecializationUtil.hasSpecialization(Rideable, typeEntry.specializations) and
            not SpecializationUtil.hasSpecialization(ParkVehicle, typeEntry.specializations) then
            typeManager:addSpecialization(typeName, self.modName .. ".parkVehicle")
            modified = modified + 1
            if (self.debug) then
                print("Adding park vehicle to " .. typeName)
            end
        else
            if (self.debug) then
                print("Not adding park vehicle to " .. typeName)
            end
        end
    end

    print(string.format("Inserted Park Vehicle into %i of %i vehicle types", modified, totalCount))
end
