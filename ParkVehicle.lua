-- ParkVehicle
--
-- @author  Grisu118 - VertexDezign.net
-- @history     v1.0    - 2017-09-15 - Initial implementation
-- @Descripion: Allows temporary disabling of the tab function
-- @web: http://grisu118.ch or http://vertexdezign.net
-- Copyright (C) Grisu118, All Rights Reserved.

ParkVehicle = {}
ParkVehicle.inputName = "parkVehicle"
function ParkVehicle:prerequisitesPresent(specializations)
  return true
end

function ParkVehicle:load(savegame)
  self.vdPV = {}

  self.vdPV.debugger = GrisuDebug:create("ParkVehicle (" .. tostring(self.configFileName) .. ")")
  self.vdPV.debugger:setLogLvl(GrisuDebug.TRACE)

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
  if self.isClient and self:getIsActiveForInput() then
    g_currentMission:addHelpButtonText("Tabbing: " .. tostring(self.nonTabbable), InputBinding[ParkVehicle.inputName])
  end
end

function ParkVehicle:getSaveAttributesAndNodes(nodeIdent)
  local attributes = 'isParked="' .. tostring(self.nonTabbable) .. '"'
  return attributes, nil
end