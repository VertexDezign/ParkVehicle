-- ParkVehicle
--
-- @author  Grisu118 - VertexDezign.net
-- @history     v1.0    - 2017-09-15 - Initial implementation
-- @Descripion: Allows temporary disabling of the tab function
-- @web: http://grisu118.ch or http://vertexdezign.net
-- Copyright (C) Grisu118, All Rights Reserved.

ParkVehicle = {}
ParkVehicle.inputName = "parkVehicle"
ParkVehicle.modDir = g_currentModDirectory;
function ParkVehicle:prerequisitesPresent(specializations)
  return true
end

function ParkVehicle:load(savegame)
  self.vdPV = {}

  self.vdPV.debugger = GrisuDebug:create("ParkVehicle (" .. tostring(self.configFileName) .. ")")
  self.vdPV.debugger:setLogLvl(GrisuDebug.INFO)
  self.vdPV.debugger:debug(function()
    return "Current Moddir is: " .. ParkVehicle.modDir;
  end)
  self.vdPV.icon = createImageOverlay(ParkVehicle.modDir .. "icon.png")
  self.vdPV.overlay = createImageOverlay(ParkVehicle.modDir .. "overlay.png")

  if savegame ~= nil then
    self.nonTabbable = Utils.getNoNil(getXMLBool(savegame.xmlFile, savegame.key .. "#isParked"), false)
  end
end

function ParkVehicle:delete()
end

function ParkVehicle:mouseEvent(posX, posY, isDown, isUp, button)
end

function ParkVehicle:keyEvent(unicode, sym, modifier, isDown)
end

function ParkVehicle:update(dt)
  if self:getIsActiveForInput() and InputBinding.hasEvent(InputBinding[ParkVehicle.inputName]) then
    self.nonTabbable = not self.nonTabbable
  end
end

function ParkVehicle:updateTick(dt)
end

function ParkVehicle:draw()
  if self.isClient and self:getIsActive() then
    local uiScale = g_gameSettings:getValue("uiScale")

    local startX = 1 - 0.164 * uiScale + (0.04 * (uiScale - 0.5))
    local startY = 0.145 * uiScale - (0.08 * (uiScale - 0.5))
    local iconWidth = 0.01 * uiScale
    local iconHeight = iconWidth * g_screenAspectRatio
    renderOverlay(self.vdPV.icon, startX, startY, iconWidth, iconHeight)
    if self.nonTabbable then
      renderOverlay(self.vdPV.overlay, startX, startY, iconWidth, iconHeight)
    end
  end
end

function ParkVehicle:getSaveAttributesAndNodes(nodeIdent)
  local attributes = 'isParked="' .. tostring(self.nonTabbable) .. '"'
  return attributes, nil
end