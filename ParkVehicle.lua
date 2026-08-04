-- ParkVehicle
--
-- @author  Grisu118 - VertexDezign.net
-- @history     v1.0.0.0 - 2017-09-15 - Initial implementation
--              v1.0.1.0 - 2017-10-15 - Fix random toggle
--              v2.0.0.0 - 2018-12-03 - FS19
--              v2.1.0.0 - 2019-04-01 - Support all enterable vehicles, create modSettings folder
--              v3.0.0.0 - 2021-11-19 - FS22
--              v3.1.0.0 - 2022-04-23 - Add possibiltiy to unpark all, fix issue with registration in loader
--              v4.0.0.0 - 2024-11-09 - FS25
-- @Descripion: Allows temporary disabling of the tab function
-- @web: https://grisu118.ch or https://vertexdezign.net
-- Copyright (C) Grisu118, All Rights Reserved.

---@class ParkVehicle
ParkVehicle = {}
ParkVehicle.inputName = "parkVehicle"
ParkVehicle.modDir = g_parkVehicleSystem.modDir
ParkVehicle.AUTO_UNPARK_DISTANCE = 3 -- meters a parked vehicle has to move (by any means) before it auto-unparks

function ParkVehicle.prerequisitesPresent(specializations)
  return SpecializationUtil.hasSpecialization(Enterable, specializations)
end

function ParkVehicle.registerFunctions(vehicleType)
  SpecializationUtil.registerFunction(vehicleType, "getParkVehicleState", ParkVehicle.getParkVehicleState)
  SpecializationUtil.registerFunction(vehicleType, "setParkVehicleState", ParkVehicle.setParkVehicleState)
  SpecializationUtil.registerFunction(vehicleType, "parkVehicleRender", ParkVehicle.parkVehicleRender)
end

function ParkVehicle.registerEventListeners(vehicleType)
  SpecializationUtil.registerEventListener(vehicleType, "onLoad", ParkVehicle)
  SpecializationUtil.registerEventListener(vehicleType, "onUpdate", ParkVehicle)
  SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", ParkVehicle)
  SpecializationUtil.registerEventListener(vehicleType, "onReadStream", ParkVehicle)
  SpecializationUtil.registerEventListener(vehicleType, "onWriteUpdateStream", ParkVehicle)
  SpecializationUtil.registerEventListener(vehicleType, "onReadUpdateStream", ParkVehicle)
  SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", ParkVehicle)
  SpecializationUtil.registerEventListener(vehicleType, "onDelete", ParkVehicle)
end

function ParkVehicle:onLoad(savegame)
  -- The spec table is created unconditionally, for every vehicle this
  -- specialization is installed on. It carries the dirty flag and backs the
  -- network stream layout, and both of those have to match bit for bit between
  -- the client and the server. Deciding whether the table exists at all from a
  -- value that can differ per machine is what used to desync the update stream:
  -- a client that had a spec wrote id + value, the server that had none read
  -- them back and indexed a nil spec.
  self.spec_parkvehicle = {}
  local spec = self.spec_parkvehicle

  spec.uniqueUserId = g_parkVehicleSystem:getUniqueUserId()

  spec.inputPressed = false
  spec.registrationKey = nil
  spec.actionEvents = {}
  spec.dirtyFlag = self:getNextDirtyFlag()

  spec.state = {}
  spec.parkAnchorSet = false
  spec.parkAnchorX, spec.parkAnchorY, spec.parkAnchorZ = 0, 0, 0

  -- Vehicles the base game already made permanently non-tabbable on purpose
  -- (e.g. car washes, fixed/viewing-only enterables) are left alone entirely -
  -- this mod never manages them, it only keeps them stream-compatible.
  --
  -- Read the raw Enterable field rather than calling getIsTabbable(). The
  -- question here is only "did this vehicle's own XML opt out of tabbing", and
  -- the field answers exactly that: Enterable:onLoad has just filled it from
  -- vehicle.enterable#isTabbable, and the savegame-persisted value (which could
  -- be our own previous setIsTabbable call) is only restored later, in
  -- Enterable:onPostLoad. getIsTabbable() answers a different, much broader
  -- question, because anyone may overwrite it with a dynamic condition
  spec.isManaged = self.spec_enterable.isTabbable ~= false
  if not spec.isManaged then
    return
  end

  spec.icon = createImageOverlay(ParkVehicle.modDir .. "icon.png")
  spec.overlay = createImageOverlay(ParkVehicle.modDir .. "overlay.png")

  local isEmpty = true
  if savegame ~= nil then
    local i = 0
    while true do

      local legacykey = string.format("%s.ParkVehicle.player(%d)", savegame.key, i) -- TODO Remove with next release
      local key = string.format("%s.%s.ParkVehicle.player(%d)", savegame.key, g_parkVehicleSystem.modName, i)
      if not hasXMLProperty(savegame.xmlFile.handle, key) then
        key = legacykey
      end
      if not hasXMLProperty(savegame.xmlFile.handle, key) then
        break
      end
      local id = getXMLString(savegame.xmlFile.handle, key .. "#id")
      local value = getXMLBool(savegame.xmlFile.handle, key .. "#isParked")
      if id ~= nil and value ~= nil then
        spec.state[id] = value
        isEmpty = false
      end
      i = i + 1
    end
  end

  -- A dedicated server is not a player of its own, so seeding an entry for its
  -- id would only add one dead key per vehicle to the savegame. Unlike at mod
  -- load time, g_dedicatedServer is reliable here: it is created during startup,
  -- long before any vehicle loads.
  if g_dedicatedServer == nil and (isEmpty or spec.state[spec.uniqueUserId] == nil) then
    spec.state[spec.uniqueUserId] = false
  end

  self.spec_enterable:setIsTabbable(not spec.state[spec.uniqueUserId])
  spec.registrationKey = g_parkVehicleSystem:registerInstance(self)
end

function ParkVehicle:onUpdate(dt, isActiveForInput, isSelected)
  local spec = self.spec_parkvehicle
  if spec == nil or not spec.isManaged then
    return
  end

  if self.isClient then
    if spec.inputPressed then
      local newValue = not self:getParkVehicleState()
      self:setParkVehicleState(newValue)
      spec.inputPressed = false
    end

    -- Auto-unpark: a parked vehicle that moves more than AUTO_UNPARK_DISTANCE
    -- from where it was parked gets unparked automatically, regardless of what
    -- moved it (player driving it, AI, being towed, ...). The anchor is only
    -- ever captured here, lazily, on the first update tick after a vehicle
    -- becomes parked - never during onLoad/network sync, where the vehicle's
    -- node position isn't guaranteed to be settled yet (loading is async).
    if g_parkVehicleSystem.autoUnparkEnabled and self:getParkVehicleState() then
      if not spec.parkAnchorSet then
        spec.parkAnchorX, spec.parkAnchorY, spec.parkAnchorZ = localToWorld(self.rootNode, 0, 0, 0)
        spec.parkAnchorSet = true
      else
        local x, y, z = localToWorld(self.rootNode, 0, 0, 0)
        local dx, dy, dz = x - spec.parkAnchorX, y - spec.parkAnchorY, z - spec.parkAnchorZ
        local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
        if distance >= ParkVehicle.AUTO_UNPARK_DISTANCE then
          self:setParkVehicleState(false)
        end
      end
    else
      spec.parkAnchorSet = false
    end
  end
end

---@param newValue boolean
function ParkVehicle:setParkVehicleState(newValue)
  local spec = self.spec_parkvehicle
  if spec == nil or not spec.isManaged then
    return
  end

  self.spec_enterable:setIsTabbable(not newValue)
  spec.state[spec.uniqueUserId] = newValue
  spec.parkAnchorSet = false
  self:raiseDirtyFlags(spec.dirtyFlag)
end

---@return boolean
function ParkVehicle:getParkVehicleState()
  local spec = self.spec_parkvehicle
  if spec == nil or not spec.isManaged then
    return false
  end

  return spec.state[spec.uniqueUserId] == true
end

function ParkVehicle:parkVehicleRender()
  local spec = self.spec_parkvehicle
  if spec == nil or not spec.isManaged then
    return
  end

  if self.isClient and self:getIsActive() then
    local uiScale = g_gameSettings:getValue("uiScale")
    local speedMeter = g_currentMission.hud.speedMeter

    local iconWidth = 0.011 * uiScale
    local iconHeight = iconWidth * g_screenAspectRatio

    local startX = speedMeter.x + speedMeter.aiIconOffsetX - (iconWidth * 1.5) + g_parkVehicleSystem.overlayOffsetX * g_pixelSizeX
    local startY = speedMeter.y + speedMeter.aiIconOffsetY + (iconHeight / 4) + g_parkVehicleSystem.overlayOffsetY * g_pixelSizeY

    renderOverlay(spec.icon, startX, startY, iconWidth, iconHeight)
    if spec.state[spec.uniqueUserId] then
      renderOverlay(spec.overlay, startX, startY, iconWidth, iconHeight)
    end
  end
end

function ParkVehicle:onDelete()
  local spec = self.spec_parkvehicle
  -- Unmanaged vehicles never got registered, and unregistering a nil key would
  -- raise "table index is nil".
  if spec ~= nil and spec.registrationKey ~= nil then
    g_parkVehicleSystem:unregisterInstance(spec.registrationKey)
  end
end

--Called on server side on join
-- @param integer streamId streamId
-- @param integer connection connection
function ParkVehicle:onWriteStream(streamId, connection)
  local spec = self.spec_parkvehicle
  if spec == nil then
    streamWriteInt32(streamId, 0)
    return
  end

  local count = 0
  for k in pairs(spec.state) do
    count = count + 1
  end
  streamWriteInt32(streamId, count)
  for k, v in pairs(spec.state) do
    streamWriteString(streamId, k)
    streamWriteBool(streamId, v)
  end
end

--Called on client side on join
-- @param integer streamId streamId
-- @param integer connection connection
function ParkVehicle:onReadStream(streamId, connection)
  local spec = self.spec_parkvehicle
  local count = streamReadInt32(streamId)

  if spec == nil then
    -- Not a managed vehicle - still have to consume whatever the server
    -- wrote so the stream stays in sync for whatever reads after this.
    for i = 1, count do
      streamReadString(streamId)
      streamReadBool(streamId)
    end
    return
  end

  local state = {}
  local i = 0
  while i < count do
    local id = streamReadString(streamId)
    local value = streamReadBool(streamId)
    state[id] = value
    if spec.isManaged and id == spec.uniqueUserId then
      self.spec_enterable:setIsTabbable(not value)
      spec.parkAnchorSet = false
    end
    i = i + 1
  end
  spec.state = state
  -- The server's table may not contain an entry for the local user (e.g. a
  -- vehicle this player never parked). Seed it like onLoad does, so the local
  -- state is always a valid bool and never gets written back as nil.
  if spec.isManaged and spec.state[spec.uniqueUserId] == nil then
    spec.state[spec.uniqueUserId] = false
  end
end

function ParkVehicle:onWriteUpdateStream(streamId, connection, dirtyMask)
  if connection:getIsServer() then
    local spec = self.spec_parkvehicle
    if spec == nil then
      streamWriteBool(streamId, false)
      return
    end
    if streamWriteBool(streamId, bitAND(dirtyMask, spec.dirtyFlag) ~= 0) then
      streamWriteString(streamId, spec.uniqueUserId)
      streamWriteBool(streamId, spec.state[spec.uniqueUserId] == true)
    end
  end
end

function ParkVehicle:onReadUpdateStream(streamId, timestamp, connection)
  if not connection:getIsServer() then
    local spec = self.spec_parkvehicle
    if streamReadBool(streamId) then
      local id = streamReadString(streamId)
      local value = streamReadBool(streamId)
      -- The payload always has to be consumed, even for a vehicle this side
      -- does not manage, so the rest of the stream stays aligned.
      if spec == nil then
        return
      end
      if spec.isManaged and id == spec.uniqueUserId then
        self.spec_enterable:setIsTabbable(not value)
        spec.parkAnchorSet = false
      end
      spec.state[id] = value
    end
  end
end

function ParkVehicle:onRegisterActionEvents(isActiveForInput)
  local spec = self.spec_parkvehicle
  if spec == nil or not spec.isManaged then
    return
  end

  if self.isClient then
    self:clearActionEventsTable(spec.actionEvents)

    if self:getIsActiveForInput(true) then
      local _, actionEventId =
        self:addActionEvent(
        spec.actionEvents,
        "PARKVEHICLE_01",
        self,
        ParkVehicle.actionEventParkVehicle,
        false,
        true,
        false,
        true,
        nil
      )

      g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_VERY_LOW)

      local _, unparkAllEventId =
      self:addActionEvent(
          spec.actionEvents,
          "PARKVEHICLE_UNPARK_ALL",
          self,
          ParkVehicle.actionEventUnparkAll,
          false,
          true,
          false,
          true,
          nil
      )

      g_inputBinding:setActionEventTextPriority(unparkAllEventId, GS_PRIO_VERY_LOW)

      local _, cycleParkedEventId =
      self:addActionEvent(
          spec.actionEvents,
          "PARKVEHICLE_CYCLE_PARKED",
          self,
          ParkVehicle.actionEventCycleParked,
          false,
          true,
          false,
          true,
          nil
      )

      g_inputBinding:setActionEventTextPriority(cycleParkedEventId, GS_PRIO_VERY_LOW)
    end
  end
end

function ParkVehicle:actionEventUnparkAll(self)
  g_parkVehicleSystem:unparkAll()
end

function ParkVehicle.actionEventParkVehicle(self, actionName, inputValue, callbackState, isAnalog)
  local spec = self.spec_parkvehicle
  spec.inputPressed = true
end

function ParkVehicle.actionEventCycleParked(self, actionName, inputValue, callbackState, isAnalog)
  g_parkVehicleSystem:cycleParkedVehicles()
end

function ParkVehicle:saveToXMLFile(xmlFile, path)
  local spec = self.spec_parkvehicle
  if spec == nil then
    return
  end

  local i = 0
  for id, value in pairs(spec.state) do
    setXMLString(xmlFile.handle, string.format("%s.player(%d)#id", path, i), id)
    setXMLBool(xmlFile.handle, string.format("%s.player(%d)#isParked", path, i), value)
    i = i + 1
  end
end
