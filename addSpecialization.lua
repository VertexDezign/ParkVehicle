--
-- add specialization to all mods.
--
--
-- @author:   Xentro (Marcus@Xentro.se)
-- @website:	www.Xentro.se
-- @history:	v2.00 - 2018-11-17 - FS19
--            v1.53 - 2014-11-11 - Improvement
-- 		    		v1.52 - 2013-10-29 -
--

local luaName = "ParkVehicle"

addSpecialization = {}
addSpecialization.isLoaded = true
addSpecialization.g_currentModDirectory = g_currentModDirectory

if g_specializationManager:getSpecializationByName(luaName) == nil then
  g_specializationManager:addSpecialization(luaName, luaName, g_currentModDirectory .. luaName .. ".lua")
  addSpecialization.isLoaded = false
end

addModEventListener(addSpecialization)

function addSpecialization:loadMap(name)
  self.debugger = GrisuDebug:create("addSpecialization ( " .. luaName .. " )")
  self.debugger:setLogLvl(GrisuDebug.WARNING)
  if not g_currentMission[luaName .. "Loaded"] then
    if not addSpecialization.isLoaded then
      addSpecialization:add()
      addSpecialization.isLoaded = true
    end

    g_currentMission[luaName .. "Loaded"] = true
  else
    self.debugger:error("The mod have been loaded already! remove one of the copy's")
  end
end

function addSpecialization:deleteMap()
  g_currentMission[luaName .. "Loaded"] = nil
end

function addSpecialization:mouseEvent(posX, posY, isDown, isUp, button)
end

function addSpecialization:keyEvent(unicode, sym, modifier, isDown)
end

function addSpecialization:update(dt)
end

function addSpecialization:draw()
end

function addSpecialization:add()
  self.debugger:trace("add()")
  local searchWords = { luaName }
  local searchSpecializations = { { luaName, false }, { "drivable", true } } -- only globally accessible scripts. (steerable, fillable etc.)

  for k, vehicle in pairs(g_vehicleTypeManager:getVehicleTypes()) do
    local locationAllowed, specialization

    for _, s in ipairs(searchSpecializations) do s[3] = false end

    for _, vs in ipairs(vehicle.specializationNames) do
      
      for _, s in ipairs(searchSpecializations) do
        if vs == s[1] then
          if s[2] then
            locationAllowed = "allowed"
            s[3] = true
          else
            locationAllowed = "has"
            specialization = s[1]
            break
          end
        end
      end

      if locationAllowed ~= nil and locationAllowed ~= "allowed" then
        break
      end
    end

    if locationAllowed == nil then
      locationAllowed = "allowed"
    end

    for _, s in ipairs(searchSpecializations) do
      if s[2] then
        if s[3] ~= true then
          locationAllowed = "missing"
          specialization = s[1]
          break
        end
      end
    end

    if locationAllowed == "allowed" then
      local addSpec
      local modName = StringUtil.splitString(".", k)
      local spec = {}

      for name in pairs(g_specializationManager.specializations) do
        if string.find(name, modName[1]) ~= nil then
          local parts = StringUtil.splitString(".", name)

          if table.getn(parts) > 1 then
            table.insert(spec, parts)
          end
        end
      end

      for _, s in ipairs(spec) do
        for _, search in ipairs(searchWords) do
          if string.find(string.lower(s[2]), string.lower(search)) ~= nil then
            addSpec = s[2]
            break
          end
        end

        if addSpec ~= nil then
          break
        end
      end

      if addSpec == nil then
        g_vehicleTypeManager:addSpecialization(k, "FS19_parkVehicle" .. "." .. luaName)
        self.debugger:trace(function()
          return "Inserted on " .. k
        end)
      else
        self.debugger:info(function()
          return "Failed inserting on " .. k .. " as it has the specialization (" .. addSpec .. ")"
        end)
      end
    elseif locationAllowed == "has" then
      self.debugger:info(function()
        return "Failed inserting on " .. k .. " as it has the specialization (" .. specialization .. ")"
      end)
    else
      self.debugger:info(function()
        return "Failed inserting on " .. k .. " as its missing specialization " .. specialization
      end)
    end
  end
end

