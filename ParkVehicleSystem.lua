--- Global instance of park vehicle.
---@class ParkVehicleSystem
---@field modName string
---@field modDir string
---@field inputManager InputBinding
---@field debug boolean
---@field instances table<integer, ParkVehicle>
---@field counter integer Increased if an instance is registered, used as key within the table
ParkVehicleSystem = {}

-- Sanity bounds (in screen pixels) clamping what the settings UI's free-text
-- overlay X/Y position fields will accept, wide enough to place the icon
-- anywhere on screen while still rejecting garbage/typo input.
ParkVehicleSystem.OVERLAY_OFFSET_MIN = -1000
ParkVehicleSystem.OVERLAY_OFFSET_MAX = 1000

local ParkVehicleSystem_mt = Class(ParkVehicleSystem)

---
---@param modName string
---@param modDir string
---@param inputManager InputBinding
---@param debug boolean
---@return ParkVehicleSystem
function ParkVehicleSystem:new(modName, modDir, inputManager, debug)
    local self = {}

    setmetatable(self, ParkVehicleSystem_mt)

    self.modName = modName
    self.modDir = modDir
    self.debug = debug
    self.inputManager = inputManager

    self.instances = {}
    self.counter = 0
    self.controlledVehicle = nil

    self.autoUnparkEnabled = true
    self.overlayOffsetX = 0
    self.overlayOffsetY = 0
    self.uniqueUserId = nil
    self.uniqueUserIdResolved = false
    self:loadSettings()

    return self
end

--- Single owner of modSettings/parkVehicle.xml, which holds autoUnparkEnabled,
--- the overlay offsets and uniqueUserId (see getUniqueUserId).
function ParkVehicleSystem:getSettingsFilePath()
    return getUserProfileAppPath() .. "modSettings/parkVehicle.xml"
end

function ParkVehicleSystem:loadSettings()
    local filePath = self:getSettingsFilePath()
    if not fileExists(filePath) then
        return
    end

    local xml = loadXMLFile("ParkVehicle", filePath)
    if hasXMLProperty(xml, "ParkVehicle#autoUnparkEnabled") then
        self.autoUnparkEnabled = Utils.getNoNil(getXMLBool(xml, "ParkVehicle#autoUnparkEnabled"), true)
    end
    if hasXMLProperty(xml, "ParkVehicle#overlayOffsetX") then
        self.overlayOffsetX = ParkVehicleSystem.clampOverlayOffset(Utils.getNoNil(getXMLInt(xml, "ParkVehicle#overlayOffsetX"), 0))
    end
    if hasXMLProperty(xml, "ParkVehicle#overlayOffsetY") then
        self.overlayOffsetY = ParkVehicleSystem.clampOverlayOffset(Utils.getNoNil(getXMLInt(xml, "ParkVehicle#overlayOffsetY"), 0))
    end
    self.uniqueUserId = getXMLString(xml, "ParkVehicle#uniqueUserId")
    delete(xml)
end

---@param value integer
---@return integer value clamped to [OVERLAY_OFFSET_MIN, OVERLAY_OFFSET_MAX]
function ParkVehicleSystem.clampOverlayOffset(value)
    return math.max(ParkVehicleSystem.OVERLAY_OFFSET_MIN, math.min(ParkVehicleSystem.OVERLAY_OFFSET_MAX, value))
end

function ParkVehicleSystem:saveSettings()
    local filePath = self:getSettingsFilePath()
    local xml
    if fileExists(filePath) then
        xml = loadXMLFile("ParkVehicle", filePath)
    else
        createFolder(getUserProfileAppPath() .. "modSettings")
        xml = createXMLFile("ParkVehicle", filePath, "ParkVehicle")
    end

    if self.uniqueUserId ~= nil then
        setXMLString(xml, "ParkVehicle#uniqueUserId", self.uniqueUserId)
    end
    setXMLBool(xml, "ParkVehicle#autoUnparkEnabled", self.autoUnparkEnabled)
    setXMLInt(xml, "ParkVehicle#overlayOffsetX", self.overlayOffsetX)
    setXMLInt(xml, "ParkVehicle#overlayOffsetY", self.overlayOffsetY)
    saveXMLFile(xml)
    delete(xml)
end

---@param enabled boolean
function ParkVehicleSystem:setAutoUnparkEnabled(enabled)
    self.autoUnparkEnabled = enabled
    self:saveSettings()
end

---@param offsetPx integer pixels to shift the overlay horizontally from its default position
function ParkVehicleSystem:setOverlayOffsetX(offsetPx)
    self.overlayOffsetX = ParkVehicleSystem.clampOverlayOffset(offsetPx)
    self:saveSettings()
end

---@param offsetPx integer pixels to shift the overlay vertically from its default position
function ParkVehicleSystem:setOverlayOffsetY(offsetPx)
    self.overlayOffsetY = ParkVehicleSystem.clampOverlayOffset(offsetPx)
    self:saveSettings()
end

--- Per-player id used to key each vehicle's parked state, so multiple
--- players in the same MP session each have their own independent parking
--- preference for the same vehicle.
---
--- The id is owned by this mod and persisted in modSettings/parkVehicle.xml,
--- because the game no longer offers mods a per-user id: the global
--- getUniqueUserId() is deprecated for mods, and the in-mission equivalent
--- (userManager + playerUserId) is not populated yet on a joining MP client
--- when its vehicles are streamed in. The first run picks the id once:
--- - installs from before 1.1.0.0 already carry one (the player nickname at
---   the time) and keep it,
--- - installs since then keyed their parked states on the engine's id, so it is
---   copied over while the deprecated function still exists,
--- - anyone else gets a random id.
---
--- A dedicated server resolves an id the same way as anyone else. It never parks
--- anything itself, so its id is inert and needs no special case.
---@return string
function ParkVehicleSystem:getUniqueUserId()
    if not self.uniqueUserIdResolved then
        self.uniqueUserIdResolved = true

        if string.isNilOrWhitespace(self.uniqueUserId) then
            self.uniqueUserId = ParkVehicleSystem.getEngineUniqueUserId() or ParkVehicleSystem.generateUniqueUserId()
            self:saveSettings()
        end
    end
    return self.uniqueUserId
end

--- The engine's per-installation id, for migrating installs that already keyed
--- parked states on it. Giants announced its removal for mods, so tolerate it
--- being gone, replaced by a non-function, or failing.
---@return string|nil
function ParkVehicleSystem.getEngineUniqueUserId()
    -- bare getUniqueUserId is the global engine function, not the method above
    if type(getUniqueUserId) ~= "function" then
        return nil
    end
    local ok, id = pcall(getUniqueUserId)
    if ok and type(id) == "string" and not string.isNilOrWhitespace(id) then
        return id
    end
    return nil
end

---@return string 32 random hex characters
function ParkVehicleSystem.generateUniqueUserId()
    local parts = {}
    for i = 1, 4 do
        parts[i] = string.format("%08x", math.random(0, 0x7FFFFFFF))
    end
    return table.concat(parts)
end

function ParkVehicleSystem:onMissionLoaded(mission)
    -- hook into function, which is called only if the HUD is really visible for a vehicle
    mission.hud.drawControlledEntityHUD = Utils.appendedFunction(mission.hud.drawControlledEntityHUD,
        function(self)
            if self.isVisible then
                ParkVehicleSystem:renderHud()
            end
        end)
    -- hook into function, which sets the vehicle for HUD display
    mission.hud.setControlledVehicle = Utils.appendedFunction(mission.hud.setControlledVehicle,
        function(self, vehicle)
            ParkVehicleSystem:setVehicle(vehicle)
        end)
end

---@param typeManager TypeManager
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

function ParkVehicleSystem:registerActionEvents()
    local _, eventId = self.inputManager:registerActionEvent(InputAction.PARKVEHICLE_UNPARK_ALL, self, self.unparkAll, false, true, false, true)
    self.inputManager:setActionEventTextPriority(eventId, GS_PRIO_VERY_HIGH)
  end
  
  function ParkVehicleSystem:unregisterActionEvents()
    self.inputManager:removeActionEventsByTarget(self)
  end

---@param instance ParkVehicle
---@return integer the key to unregister this instance
function ParkVehicleSystem:registerInstance(instance)
    local key = self.counter
    self.instances[key] = instance

    self.counter = self.counter + 1

    return key
end

---@param key integer
function ParkVehicleSystem:unregisterInstance(key)
    self.instances[key] = nil
end

function ParkVehicleSystem:unparkAll()
    for _, value in pairs(self.instances) do
        value:setParkVehicleState(false)
    end
end

---@return ParkVehicle[] currently parked vehicle instances, in registration order
function ParkVehicleSystem:getParkedVehicles()
    local vehicles = {}
    for i = 0, self.counter - 1 do
        local instance = self.instances[i]
        if instance ~= nil and instance:getParkVehicleState() then
            table.insert(vehicles, instance)
        end
    end
    return vehicles
end

-- Bypasses the normal Tab restriction: cycles only through vehicles that are
-- currently parked, so you can reach them without unparking first.
function ParkVehicleSystem:cycleParkedVehicles()
    local vehicles = self:getParkedVehicles()
    if #vehicles == 0 then
        return
    end

    local currentVehicle = g_localPlayer:getCurrentVehicle()
    local index = 1
    for i, vehicle in ipairs(vehicles) do
        if vehicle == currentVehicle then
            index = (i % #vehicles) + 1
            break
        end
    end

    g_localPlayer:requestToEnterVehicle(vehicles[index])
end

function ParkVehicleSystem:setVehicle(vehicle)
    self.controlledVehicle = vehicle
end

function ParkVehicleSystem:renderHud()
    if self.controlledVehicle ~= nil and self.controlledVehicle.parkVehicleRender ~= nil then
        self.controlledVehicle:parkVehicleRender()
    end
end
