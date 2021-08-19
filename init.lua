--- === IMIndicator ===
---
--- A spoon that shows your current IM status on the point you are currently focusing to
---

local ax = hs.axuielement

local obj={}
obj.__index = obj

-- Metadata
obj.name = "wd"
obj.version = "0.1"
obj.author = "wd <wd@wdicc.com>"
obj.homepage = "https://github.com/wd/IMIndicator.spoon"
obj.license = "MIT - https://opensource.org/licenses/MIT"

-- start
obj.defaultWidth = 20
obj.defaultHeight = 20
obj.engIMId = "com.apple.keylayout.ABC"
obj.indicatorChar = "双"

obj.apps = {}

local lastInputSourceId = hs.keycodes.currentSourceID()
local alreadyPatchedApps = {}

local isTextField = function(element)
  if not element then return false end
  local role = element:attributeValue("AXRole")
  return role == "AXTextField" or role == "AXTextArea" or role == "AXComboBox"
end

local getFocusedElementPosition = function()
  local systemElement = ax.systemWideElement()
  if not systemElement then return nil end

  local currentElement = systemElement:attributeValue("AXFocusedUIElement")
  if not currentElement then return nil end

  if not isTextField(currentElement) then return nil end

  local position = currentElement:attributeValue('AXPosition')
  if not position then return nil end

  return {
    x = position.x,
    y = position.y
  }
end

 -- patching Accessibility APIs on a per-app basis
local patchCurrentApplication = function(currentApp)
  local axApp = hs.axuielement.applicationElement(currentApp)

  if axApp then
    axApp:setAttributeValue('AXManualAccessibility', true)
  end
end

obj.start = function(apps)
  for i, v in ipairs(apps) do obj.apps[v] = true end
  hs.application.watcher.new(obj.watchApplication):start()
  hs.keycodes.inputSourceChanged(obj.inputChangeHandler)
  obj.drawIndicator()
end

obj.inputChangeHandler = function()
  inputSourceId = hs.keycodes.currentSourceID()
  --  we have to use this workaround here, otherwise this function will be triggered many times
  if lastInputSourceId == inputSourceId then return end
  if not obj.focuseHandler(nil, "InputSourceChange") then
    obj.updateIndicator()
  end
  lastInputSourceId = inputSourceId
end

obj.isCurrentAppInList = function()
  local win = hs.window.focusedWindow()
  if win == nil then return false end
  if obj.apps[win:application():bundleID()] ~= nil then return true end
  return false
end

obj.focuseHandler = function(ele, event)
  if hs.keycodes.currentSourceID() == obj.engIMId then return false end

  if obj.isCurrentAppInList() then
    local pos = obj.getIndicatorPos()
    obj.updateIndicator(pos)
  else
    obj.updateIndicator()
  end
  return true
end

obj.watchApplication = function(appName, eventType, app)
  if obj.apps[app:bundleID()] == nil then return end

  local patchKey = app:name() .. app:pid()
  if alreadyPatchedApps[patchKey] then return end

  local fn = function()
    patchCurrentApplication(app)
    local watcher = app:newWatcher(obj.focuseHandler)
    watcher:start({hs.uielement.watcher.focusedElementChanged,
                   hs.uielement.watcher.applicationActivated,
                   hs.uielement.watcher.applicationDeactivated})
  end

  hs.timer.doAfter(5,fn)
  alreadyPatchedApps[patchKey] = true
end


obj.getIndicatorPos = function()
  local elementPosition = getFocusedElementPosition()

  if elementPosition then
    local xOffset = 3 -- it is a pleasing offset
    local yOffset = 3 -- OS X adds a blue focused border, we want to clear it

    return {
      x = elementPosition.x + xOffset,
      y = elementPosition.y - obj.defaultHeight - yOffset
    }
  else
    -- get the frame of the screen we are currently focused on
    -- local frame = hs.screen.mainScreen():frame()
    local win = hs.window.focusedWindow()
    if win == nil then return end

    local frame = win:frame()

    return {
      x = frame.x + frame.w/2,
      y = frame.y + frame.h/2
    }
  end
end

obj.updateIndicator = function(pos)
  if pos then
    obj.canvas:show()
    obj.canvas:topLeft(pos)
  else
    obj.canvas:hide()
  end
end

obj.drawIndicator = function()
  local elementIndexBox = 1
  local elementIndexText = 2
  local function rgba(r, g, b, a)
    a = a or 1.0

    return {
      red = r / 255,
      green = g / 255,
      blue = b / 255,
      alpha = a
    }
  end

  local colors = {
    default = rgba(4, 135, 250, 0.95),
    insert = rgba(50, 50, 50, 1),
    normal = rgba(4, 135, 250, 0.95),
    visual = rgba(210, 152, 97, 0.95),
    replace = rgba(219, 104, 107, 0.95)
  }

  local canvas = hs.canvas.new{
    w = obj.defaultWidth,
    h = obj.defaultHeight,
    x = 500,
    y = 500,
  }

  canvas:insertElement({
      type = 'rectangle',
      action = 'fill',
      roundedRectRadii = { xRadius = 2, yRadius = 2 },
      fillColor = colors.normal,
      strokeColor = { white = 1.0 },
      strokeWidth = 3.0,
      frame = { x = "0%", y = "0%", h = "100%", w = "100%", },
      withShadow = true
                       },
    elementIndexBox
  )

  canvas:insertElement({
      type = 'text',
      action = 'fill',
      frame = {
        x = "10%", y = "5%", h = "100", w = "95%"
      },
      text = hs.styledtext.new(
        obj.indicatorChar,
        {
          font = { name = "Courier New Bold", size = 14 },
          color = { white = 1.0 }
      })
  })
  obj.canvas = canvas
end

return obj
