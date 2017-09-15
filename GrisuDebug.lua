-- GrisuDebug
--
-- @author  Grisu118 - VertexDezign.net
-- @history	    v1.0    - 2016-10-26 - Initial implementation
-- @history     v1.1    - 2017-09-15 - Add Off Level, add shorthand methods for logging, add support for closures
-- @Descripion: Providing debug utils
-- @web: http://grisu118.ch or http://vertexdezign.net
-- Copyright (C) Grisu118, All Rights Reserved.
GrisuDebug = {}
GrisuDebug.__index = GrisuDebug

GrisuDebug.TRACE = 1
GrisuDebug.DEBUG = 2
GrisuDebug.INFO = 3
GrisuDebug.WARNING = 4
GrisuDebug.ERROR = 5
GrisuDebug.OFF = 6

function GrisuDebug:create(name, id)
  local d = {} -- our new object
  setmetatable(d, GrisuDebug) -- make Account handle lookup
  d.name = name -- initialize our object
  d.id = id
  d.lvl = GrisuDebug.DEBUG
  return d
end

function GrisuDebug:setLogLvl(lvl)
  self.lvl = lvl
end

function GrisuDebug:trace(txt)
  self:print(GrisuDebug.TRACE, txt)
end

function GrisuDebug:debug(txt)
  self:print(GrisuDebug.DEBUG, txt)
end

function GrisuDebug:info(txt)
  self:print(GrisuDebug.INFO, txt)
end

function GrisuDebug:warn(txt)
  self:print(GrisuDebug.WARNING, txt)
end

function GrisuDebug:error(txt)
  self:print(GrisuDebug.ERROR, txt)
end

function GrisuDebug:print(lvl, txt)
  if lvl < self.lvl then
    return
  end
  local level = "TRACE"
  if lvl == GrisuDebug.ERROR then
    level = "ERROR"
  elseif lvl == GrisuDebug.WARNING then
    level = "WARN"
  elseif lvl == GrisuDebug.INFO then
    level = "INFO"
  elseif lvl == GrisuDebug.DEBUG then
    level = "DEBUG"
  end

  local text
  if type(txt) == "function" then
    text = txt()
  else
    text = txt
  end

  if (self.id == nil) then
    print(self.name .. " - " .. level .. ": " .. text)
  else
    print(self.name .. " - " .. level .. ": (" .. id .. " - " .. getName(id) .. ") " .. text)
  end
end