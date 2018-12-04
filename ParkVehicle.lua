-- ParkVehicle
--
-- @author  Grisu118 - VertexDezign.net
-- @history     v1.0.0.0 - 2017-09-15 - Initial implementation
--              v1.0.1.0 - 2017-10-15 - Fix random toggle
--              v2.0.0.0 - 2018-12-03 - FS19
-- @Descripion: Allows temporary disabling of the tab function
-- @web: https://grisu118.ch or https://vertexdezign.net
-- Copyright (C) Grisu118, All Rights Reserved.

ParkVehicle = {}
ParkVehicle.inputName = "parkVehicle"
ParkVehicle.modDir = g_currentModDirectory;

function ParkVehicle.prerequisitesPresent(specializations)
  return SpecializationUtil.hasSpecialization(Drivable, specializations)
end

function ParkVehicle.registerEventListeners(vehicleType)
  SpecializationUtil.registerEventListener(vehicleType, "onLoad", ParkVehicle)
  SpecializationUtil.registerEventListener(vehicleType, "onUpdate", ParkVehicle)
  SpecializationUtil.registerEventListener(vehicleType, "onDraw", ParkVehicle)
  SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", ParkVehicle)
end

function ParkVehicle:onLoad(savegame)
  self.spec_parkvehicle = {}
  local spec = self.spec_parkvehicle

  spec.inputPressed = false
  spec.actionEvents = {}
  spec.icon = createImageOverlay(ParkVehicle.modDir .. "icon.png")
  spec.overlay = createImageOverlay(ParkVehicle.modDir .. "overlay.png")

  if savegame ~= nil then
    print(savegame.key)
    self.spec_enterable:setIsTabbable(not Utils.getNoNil(getXMLBool(savegame.xmlFile, savegame.key .. ".ParkVehicle#isParked"), false))
  end
end

function ParkVehicle:onUpdate(dt, isActiveForInput, isSelected)
  if self.isClient then
    local spec = self.spec_parkvehicle
    if spec.inputPressed then
      self.spec_enterable:setIsTabbable(not self.spec_enterable:getIsTabbable())
      spec.inputPressed = false
    end
  end
end

function ParkVehicle:onDraw()
  if self.isClient and self:getIsActive() then
    local spec = self.spec_parkvehicle
    local uiScale = g_gameSettings:getValue("uiScale")

    local startX = 1 - 0.064 * uiScale + (0.04 * (uiScale - 0.5))
    local startY = 0.145 * uiScale - (0.08 * (uiScale - 0.5))
    local iconWidth = 0.01 * uiScale
    local iconHeight = iconWidth * g_screenAspectRatio
    renderOverlay(spec.icon, startX, startY, iconWidth, iconHeight)
    if not self.spec_enterable:getIsTabbable() then
      renderOverlay(spec.overlay, startX, startY, iconWidth, iconHeight)
    end
  end
end

function ParkVehicle:onRegisterActionEvents(isActiveForInput)
  if self.isClient then
    local spec = self.spec_parkvehicle
    self:clearActionEventsTable(spec.actionEvents)

    if self:getIsActiveForInput(true) then
      local _, actionEventId = self:addActionEvent(spec.actionEvents, "PARKVEHICLE", self, ParkVehicle.actionEventParkVehicle, false, true, false, true, nil)

      g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_VERY_HIGH)
      g_inputBinding:setActionEventActive(actionEventId, true)
      g_inputBinding:setActionEventText(actionEventId, g_i18n:getText("PARKVEHICLE"))
    end
  end
end

function ParkVehicle.actionEventParkVehicle(self, actionName, inputValue, callbackState, isAnalog)
  local spec = self.spec_parkvehicle
  spec.inputPressed = true
end

function ParkVehicle:saveToXMLFile(xmlFile, path)
  setXMLBool(xmlFile, path .. "#isParked", not self.spec_enterable:getIsTabbable())
end