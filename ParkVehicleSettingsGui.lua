--- Injects a "Park Vehicle" section (own header + "Auto-unpark vehicles" checkbox)
--- into the native General Settings tab of the pause menu. Clones an existing
--- section-title element and the "Is Train Tabbable" checkbox row (same kind of
--- on/off vehicle-tabbing toggle), and rebinds the checkbox's click callback to
--- our own persisted setting instead of the native g_settingsModel.
ParkVehicleSettingsGui = {}

function ParkVehicleSettingsGui.install()
    InGameMenuSettingsFrame.onFrameOpen = Utils.appendedFunction(InGameMenuSettingsFrame.onFrameOpen, ParkVehicleSettingsGui.onFrameOpen)
end

function ParkVehicleSettingsGui.onFrameOpen(settingsFrame)
    if settingsFrame.parkVehicleCheckbox ~= nil then
        ParkVehicleSettingsGui.refreshCheckbox(settingsFrame.parkVehicleCheckbox)
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
