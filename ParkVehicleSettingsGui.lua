--- Injects a "Park Vehicle" section (own header + "Auto-unpark vehicles" checkbox
--- and overlay X/Y position text fields) into the native General Settings tab of
--- the pause menu. Clones an existing section-title element, the "Is Train
--- Tabbable" checkbox row (same kind of on/off vehicle-tabbing toggle) and the
--- savegame name text field row (same kind of free-text input), then rebinds
--- their callbacks to our own persisted settings instead of the native
--- g_settingsModel/missionInfo. Each cloned row's description text (the "ignore"
--- Text element next to the field) is retexted in place (see setRowTooltipText)
--- rather than adding an element of our own, so the stale template text isn't
--- left behind.
ParkVehicleSettingsGui = {}

function ParkVehicleSettingsGui.install()
    InGameMenuSettingsFrame.onFrameOpen = Utils.appendedFunction(InGameMenuSettingsFrame.onFrameOpen, ParkVehicleSettingsGui.onFrameOpen)
end

function ParkVehicleSettingsGui.onFrameOpen(settingsFrame)
    if settingsFrame.parkVehicleCheckbox ~= nil then
        ParkVehicleSettingsGui.refreshCheckbox(settingsFrame.parkVehicleCheckbox)
        ParkVehicleSettingsGui.refreshOffsetInput(settingsFrame.parkVehicleOffsetXInput, g_parkVehicleSystem.overlayOffsetX)
        ParkVehicleSettingsGui.refreshOffsetInput(settingsFrame.parkVehicleOffsetYInput, g_parkVehicleSystem.overlayOffsetY)
        return
    end

    local templateBox = settingsFrame.checkIsTrainTabbableBox
    local layout = templateBox ~= nil and templateBox.parent or nil
    if layout == nil then
        return
    end

    -- Section header: clone any existing "General Settings" section title
    -- (e.g. "Sound", "Camera") instead of appending into someone else's group.
    for _, element in ipairs(layout.elements) do
        if element.name == "sectionHeader" then
            local header = element:clone(layout)
            header:setText(g_i18n:getText("PARKVEHICLE_SETTINGS_SECTION"))
            break
        end
    end

    local clonedBox = templateBox:clone(layout)
    local checkbox = clonedBox.elements[1]
    local title = clonedBox.elements[2]
    local tooltip = checkbox.elements[1]

    title:setText(g_i18n:getText("PARKVEHICLE_AUTOUNPARK_SETTING"))
    tooltip:setText(g_i18n:getText("PARKVEHICLE_AUTOUNPARK_SETTING_TOOLTIP"))

    checkbox.target = ParkVehicleSettingsGui
    checkbox:setCallback("onClickCallback", "onClickAutoUnpark")

    ParkVehicleSettingsGui.refreshCheckbox(checkbox)

    -- Reuse an existing free-text settings row (a text box the user can type an
    -- arbitrary value into) as the template for our two overlay position fields,
    -- same idea as cloning the checkbox row above. createOffsetInput retexts the
    -- tooltip the clone inherited from the savegame-name field to our own text.
    local offsetTemplateBox = ParkVehicleSettingsGui.findTextInputTemplate(settingsFrame)
    if offsetTemplateBox ~= nil then
        settingsFrame.parkVehicleOffsetXInput = ParkVehicleSettingsGui.createOffsetInput(
            settingsFrame, offsetTemplateBox, layout,
            "PARKVEHICLE_OVERLAY_OFFSET_X_SETTING", "PARKVEHICLE_OVERLAY_OFFSET_X_SETTING_TOOLTIP",
            "onEnterPressedOverlayOffsetX", g_parkVehicleSystem.overlayOffsetX)
        settingsFrame.parkVehicleOffsetYInput = ParkVehicleSettingsGui.createOffsetInput(
            settingsFrame, offsetTemplateBox, layout,
            "PARKVEHICLE_OVERLAY_OFFSET_Y_SETTING", "PARKVEHICLE_OVERLAY_OFFSET_Y_SETTING_TOOLTIP",
            "onEnterPressedOverlayOffsetY", g_parkVehicleSystem.overlayOffsetY)
    else
        printWarning("ParkVehicle: no text input settings row found to clone for the overlay position settings - skipping.")
    end

    layout:invalidateLayout()

    settingsFrame.parkVehicleCheckboxBox = clonedBox
    settingsFrame.parkVehicleCheckbox = checkbox
end

--- Sets the checkbox's visual state directly instead of going through
--- setIsChecked/setState: those skip the left/right highlight update
--- (updateSelection) whenever the new state already equals the state the
--- checkbox inherited from its clone source, which left the row visually
--- stuck on the wrong side despite the underlying value being correct.
function ParkVehicleSettingsGui.refreshCheckbox(checkbox)
    checkbox.state = g_parkVehicleSystem.autoUnparkEnabled and BinaryOptionElement.STATE_RIGHT or BinaryOptionElement.STATE_LEFT
    checkbox.skipAnimation = true
    checkbox:updateSelection()
end

function ParkVehicleSettingsGui:onClickAutoUnpark(state, element)
    g_parkVehicleSystem:setAutoUnparkEnabled(element:getIsChecked())
end

--- Finds a free-text settings row to use as the clone source for our own
--- overlay position inputs. Prefers settingsFrame.textSavegameName: the save
--- name field, a core Game Settings row that's always present, unlike rows
--- gated on multiplayer/hardware state.
---@param settingsFrame table the InGameMenuSettingsFrame instance
---@return table|nil the row (box) element, or nil if none was found
function ParkVehicleSettingsGui.findTextInputTemplate(settingsFrame)
    local savegameName = settingsFrame.textSavegameName
    if savegameName ~= nil and savegameName.clone ~= nil and savegameName.parent ~= nil then
        return savegameName.parent
    end
    return nil
end

--- Only lets digits and a leading minus sign be typed into the offset fields.
function ParkVehicleSettingsGui:onIsOverlayOffsetCharacterAllowed(unicode)
    return (unicode >= 48 and unicode <= 57) or unicode == 45 -- '0'-'9' or '-'
end

---@param text string raw field content
---@param fallback integer value to use if text doesn't parse as a number
---@return integer the parsed value, clamped to ParkVehicleSystem's configured min/max
function ParkVehicleSettingsGui.parseOffsetInput(text, fallback)
    local value = tonumber(text)
    if value == nil then
        return fallback
    end
    return ParkVehicleSystem.clampOverlayOffset(math.floor(value + 0.5))
end

--- Retexts a settings row's description element. In these rows the description
--- shown next to the field is a plain, always-visible Text element named "ignore"
--- (nested inside the control), not the hover-driven toolTipText/toolTipElement
--- mechanism - so the clone inherits the savegame field's "give this savegame a
--- name" text as the literal text of that element. Walk the row and retext every
--- such element to ours.
---@param element table the element to start from (its whole subtree is walked)
---@param text string the description text to apply to "ignore" text elements
function ParkVehicleSettingsGui.setRowTooltipText(element, text)
    if element.name == "ignore" and element.setText ~= nil then
        element:setText(text)
    end
    for _, child in ipairs(element.elements) do
        ParkVehicleSettingsGui.setRowTooltipText(child, text)
    end
end

--- Clones templateBox (a free-text settings row) into layout, wires it up as one
--- of our overlay offset inputs and returns the cloned text input element.
---@param settingsFrame table the InGameMenuSettingsFrame instance
---@param templateBox table settings row to clone (text input element + title)
---@param layout table parent layout to append the clone to
---@param titleKey string l10n key for the row's title
---@param tooltipKey string l10n key for the row's tooltip
---@param callbackName string name of the ParkVehicleSettingsGui method to call on commit (Enter or focus lost)
---@param currentValue integer current offset in pixels, used as the field's initial text
---@return table|nil the created input element, or nil if templateBox's structure didn't match what we expected
function ParkVehicleSettingsGui.createOffsetInput(settingsFrame, templateBox, layout, titleKey, tooltipKey, callbackName, currentValue)
    local clonedBox = templateBox:clone(layout)
    -- The template row may have been hidden when we cloned it - clone() carries
    -- that hidden state over, so force our own row back on.
    clonedBox:setVisible(true)

    local input = clonedBox.elements[1]
    if input == nil or input.setText == nil or input.getText == nil then
        printWarning("ParkVehicle: cloned settings row has no text input control - skipping overlay position setting.")
        return nil
    end

    local titleText = g_i18n:getText(titleKey)
    local tooltipText = g_i18n:getText(tooltipKey)

    local title = clonedBox.elements[2]
    if title ~= nil then
        title:setText(titleText)
    end

    -- The description text next to the field is a plain Text element (name
    -- "ignore") the clone inherited from the savegame row still reading "give
    -- this savegame a name"; retext it to ours. See setRowTooltipText.
    ParkVehicleSettingsGui.setRowTooltipText(clonedBox, tooltipText)

    -- TextInputElement also carries its own separate imeTitle/imeDescription/
    -- imePlaceholder strings, shown in the on-screen-keyboard (IME) popup that
    -- opens on touch/console/Steam Deck input - also copied verbatim from the
    -- savegame name field by clone().
    input.imeTitle = titleText
    input.imeDescription = tooltipText
    input.imePlaceholder = "0"

    input.maxCharacters = 6 -- e.g. "-1000"

    -- TextInputElement uses .target internally for its own input-capture
    -- bookkeeping (self.target:disableInputForDuration(...) while typing), so
    -- .target has to stay the owning settings frame. Route our callbacks
    -- through frame-level methods instead of repurposing .target for dispatch.
    -- Our own handlers below never read their "self" argument, so aliasing the
    -- same function onto the frame is enough - no wrapper closure needed.
    input.target = settingsFrame
    settingsFrame[callbackName] = ParkVehicleSettingsGui[callbackName]
    settingsFrame.onIsOverlayOffsetCharacterAllowed = ParkVehicleSettingsGui.onIsOverlayOffsetCharacterAllowed
    input:setCallback("onEnterPressedCallback", callbackName)
    input:setCallback("onIsUnicodeAllowedCallback", "onIsOverlayOffsetCharacterAllowed")

    -- Commit on Enter is covered by onEnterPressedCallback above, but players
    -- who just click away from the field expect their edit to stick too - the
    -- game's own savegame name field does the same instance-level override.
    local originalOnFocusLeave = input.onFocusLeave
    input.onFocusLeave = function(...)
        originalOnFocusLeave(...)
        ParkVehicleSettingsGui[callbackName](ParkVehicleSettingsGui, input)
    end

    ParkVehicleSettingsGui.refreshOffsetInput(input, currentValue)

    return input
end

function ParkVehicleSettingsGui.refreshOffsetInput(input, value)
    if input == nil then
        return
    end
    input:setText(tostring(value))
end

function ParkVehicleSettingsGui:onEnterPressedOverlayOffsetX(element)
    local value = ParkVehicleSettingsGui.parseOffsetInput(element:getText(), g_parkVehicleSystem.overlayOffsetX)
    g_parkVehicleSystem:setOverlayOffsetX(value)
    element:setText(tostring(value))
end

function ParkVehicleSettingsGui:onEnterPressedOverlayOffsetY(element)
    local value = ParkVehicleSettingsGui.parseOffsetInput(element:getText(), g_parkVehicleSystem.overlayOffsetY)
    g_parkVehicleSystem:setOverlayOffsetY(value)
    element:setText(tostring(value))
end
