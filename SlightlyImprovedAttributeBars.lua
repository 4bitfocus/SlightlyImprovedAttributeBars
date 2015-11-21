-- Must be the first line
SIAB = {}

SIAB.name = "SlightlyImprovedAttributeBars"
SIAB.version = "1.15"
SIAB.loaded = false
SIAB.playerLabels = {}
SIAB.configVersion = 3
SIAB.defaults = {
    attributeBarAlpha = 0.4,
    playerAttributeBarShift = 0,
    showPercentageText = true,
    showCurrentMaxText = false,
    targetReticleOffset = -1,
    targetReticleAlpha = 1.0,
    moveTargetReticle = true,
    lockAttributeBarWidth = false,
}

-- Create a one line text label for placing over an attribute or experience bar
function SIAB.NewBarLabel(name, parent)

    local label = WINDOW_MANAGER:CreateControl(name, parent, CT_LABEL)
    label:SetDimensions(parent:GetWidth(), 20)
    label:SetAnchor(CENTER, parent, CENTER, 0, -1)
    label:SetFont("ZoFontGame")
    label:SetColor(0.9, 0.9, 0.9, 1)
    label:SetHorizontalAlignment(1)
    label:SetVerticalAlignment(1)
    return label

end

function SIAB.NewAttributeLabel(name, parent, powerType)

    local label = SIAB.NewBarLabel(name, parent)

    if powerType then
        local powerCurrent, powerMax, powerEffectiveMax = GetUnitPower("player", powerType)
        label:SetText(SIAB.FormatLabelText(powerCurrent, powerEffectiveMax))
    end

    return label

end

-- Create the controls for the configuration pannel
function SIAB.CreateConfiguration()

    local LAM = LibStub("LibAddonMenu-2.0")

    local panelData = {
        type = "panel",
        name = "Attribute Bars",
        displayName = "Slightly Improved Attribute Bars",
        author = "L8Knight",
        version = SIAB.version,
        registerForDefaults = true,
    }

    LAM:RegisterAddonPanel(SIAB.name.."Config", panelData)

    -- Get the current screen dimensions (TODO: won't be accurate if they resize during play then try to reconfigure)
    local screenWidth, screenHeight = GuiRoot:GetDimensions()

    local controlData = {
        [1] = {
            type = "slider",
            name = "Attribute Bar Transparency",
            tooltip = "Transparency value to use when player attribute bars are full and would normally be hidden",
            min = 0, max = 10, step = 1,
            getFunc = function() return SIAB.vars.attributeBarAlpha * 10 end,
            setFunc = function(newValue) SIAB.vars.attributeBarAlpha = newValue / 10.0; SIAB.RefreshAll() end,
            default = SIAB.defaults.attributeBarAlpha * 10,
        },
        [2] = {
            type = "slider",
            name = "Horizontal Gap",
            tooltip = "Horizontal gap between magicka, health, and stamina bars",
            min = 0, max = SIAB.defaults.playerAttributeBarShift, step = 1,
            getFunc = function() return SIAB.vars.playerAttributeBarShift end,
            setFunc = function(newValue) SIAB.vars.playerAttributeBarShift = newValue; SIAB.RefreshAll() end,
            default = SIAB.defaults.playerAttributeBarShift,
        },
        [3] = {
            type = "checkbox",
            name = "Reposition Target Reticle",
            tooltip = "Reposition target reticle to bottom of screen",
            getFunc = function() return SIAB.vars.moveTargetReticle end,
            setFunc = function(newValue) SIAB.vars.moveTargetReticle = newValue; SIAB.RefreshAll() end,
            default = SIAB.defaults.moveTargetReticle,
        },
        [4] = {
            type = "slider",
            name = "Target Reticle Verticle Offset",
            tooltip = "Vertical offset for the target reticle from the original position",
            min = 0, max = math.floor(screenHeight), step = 1,
            getFunc = function() return SIAB.vars.targetReticleOffset end,
            setFunc = function(newValue) SIAB.vars.targetReticleOffset = newValue; SIAB.RefreshAll() end,
            default = SIAB.defaults.targetReticleOffset,
        },
        [5] = {
            type = "slider",
            name = "Target Reticle Transparency",
            tooltip = "Transparency value to use for the target reticle",
            min = 0, max = 10, step = 1,
            getFunc = function() return SIAB.vars.targetReticleAlpha * 10 end,
            setFunc = function(newValue) SIAB.vars.targetReticleAlpha = newValue / 10.0; SIAB.RefreshAll() end,
            default = SIAB.defaults.targetReticleAlpha * 10,
        },
        [6] = {
            type = "checkbox",
            name = "Show Percentage Text",
            tooltip = "Show attribute value as a percent",
            getFunc = function() return SIAB.vars.showPercentageText end,
            setFunc = function(newValue) SIAB.vars.showPercentageText = newValue; SIAB.RefreshAll() end,
            default = SIAB.defaults.showPercentageText,
        },
        [7] = {
            type = "checkbox",
            name = "Show Cur/Max Text",
            tooltip = "Show current/maximum attribute values",
            getFunc = function() return SIAB.vars.showCurrentMaxText end,
            setFunc = function(newValue) SIAB.vars.showCurrentMaxText = newValue; SIAB.RefreshAll() end,
            default = SIAB.defaults.showCurrentMaxText,
        },
        [8] = {
            type = "checkbox",
            name = "Lock Attribute Bar Width",
            tooltip = "Lock the attribute bar to prevent food buffs from changing the width",
            getFunc = function() return SIAB.vars.lockAttributeBarWidth end,
            setFunc = function(newValue) SIAB.vars.lockAttributeBarWidth = newValue; SIAB.RefreshAll() end,
            default = SIAB.defaults.lockAttributeBarWidth,
            warning = "Requires UI reload when turning off",
        },
    }

    --SIAB.reticleSlider = LAM:AddSlider(panelId, "SIAB.ReticleOffsetConfig",

    LAM:RegisterOptionControls(SIAB.name.."Config", controlData)

end

-- Initializer functions that runs once when the game is loading addons
function SIAB.Initialize(eventCode, addOnName)

    -- Only initialize our own addon
    if (SIAB.name ~= addOnName) then return end

    -- Initialize values so their relative to in-game controls
    local isValidAnchor, point, relativeTo, relativePoint, offsetX, offsetY = ZO_PlayerAttributeMagicka:GetAnchor(0)
    SIAB.defaults.playerAttributeBarShift = math.abs(offsetX)

    -- Load the saved variables
    SIAB.vars = ZO_SavedVars:NewAccountWide("SIABVars", SIAB.configVersion, nil, SIAB.defaults)

    -- Initialize the offset to be just above the health bar
    if (SIAB.vars.targetReticleOffset == -1) then
        SIAB.vars.targetReticleOffset = ZO_PlayerAttributeHealth:GetTop() - 175
    end

    -- Save the original offset in case this feature is disabled
    local isValidAnchor, point, relativeTo, relativePoint, offsetX, offsetY = ZO_TargetUnitFramereticleover:GetAnchor(0)
    SIAB.originalTargetReticleOffset = offsetY

    -- Create config menu
    SIAB.CreateConfiguration()

    -- Create labels for the player information
    local stats = { "Health", "Stamina", "Magicka"}
    local types = { POWERTYPE_HEALTH, POWERTYPE_STAMINA, POWERTYPE_MAGICKA }
    for i = 1, #stats, 1 do
        local parent = _G["ZO_PlayerAttribute"..stats[i]]
        SIAB.playerLabels[types[i]] = SIAB.NewAttributeLabel("SIAB_"..stats[i].."Label", parent, types[i])
    end

    -- Create a label for the target information
    SIAB.targetLabel = SIAB.NewBarLabel("SIAB_TargetHealthLabel", ZO_TargetUnitFramereticleover)

    SIAB.attribWidth = ZO_PlayerAttributeHealth:GetWidth()
    SIAB.attribHeight = ZO_PlayerAttributeHealth:GetHeight()

    SIAB.RefreshAll()

    -- Register for future power updates
    EVENT_MANAGER:RegisterForEvent("SIAB", EVENT_POWER_UPDATE, SIAB.PowerUpdate)

    SIAB.loaded = true

end

-- Register for the init handler (needs to be declaired after the SIAB.Initialize function)
EVENT_MANAGER:RegisterForEvent("SIAB", EVENT_ADD_ON_LOADED, SIAB.Initialize)

function SIAB.RefreshAll()

    SIAB.UpdateAttributeLocking()
    SIAB.RefreshAttributeBars()
    SIAB.RefreshTargetReticle()

end

function SIAB.UpdateAttributeLocking()

    if SIAB.vars.lockAttributeBarWidth then
        --width = 237
        --height = 23
        width = SIAB.attribWidth
        height = SIAB.attribHeight
    else
        width = nil
        height = nil
    end

    ZO_PlayerAttributeHealth:SetDimensionConstraints(width, height, width, height)
    ZO_PlayerAttributeHealthBgContainer:SetDimensionConstraints(width, height, width, height)
    ZO_PlayerAttributeMagicka:SetDimensionConstraints(width, height, width, height)
    ZO_PlayerAttributeMagickaBgContainer:SetDimensionConstraints(width, height, width, height)
    ZO_PlayerAttributeStamina:SetDimensionConstraints(width, height, width, height)
    ZO_PlayerAttributeStaminaBgContainer:SetDimensionConstraints(width, height, width, height)

end

function SIAB.RefreshTargetReticle()

    local isValidAnchor, point, relativeTo, relativePoint, offsetX, offsetY = ZO_TargetUnitFramereticleover:GetAnchor(0)

    -- Only adjust the target reticle if configured to do so. Allows for better integration with other addons
    if (SIAB.vars.moveTargetReticle) then
        --SIAB.reticleSlider:SetAlpha(1.0)
        offsetY = SIAB.vars.targetReticleOffset
    else
        --SIAB.reticleSlider:SetAlpha(0.0)
        offsetY = SIAB.originalTargetReticleOffset
    end

    ZO_TargetUnitFramereticleover:ClearAnchors()
    ZO_TargetUnitFramereticleover:SetAnchor(point, relativeTo, relativePoint, offsetX, offsetY)
    ZO_TargetUnitFramereticleover:SetAlpha(SIAB.vars.targetReticleAlpha)

end

function SIAB.RefreshAttributeBars()

    local stats = { "Health", "Stamina", "Magicka"}
    local types = { POWERTYPE_HEALTH, POWERTYPE_STAMINA, POWERTYPE_MAGICKA }

    for i = 1, #stats, 1 do

        local attribBar = _G["ZO_PlayerAttribute"..stats[i]]

        -- Get the current anchor point and adjust it a bit more to the middle of the screen
        local isValidAnchor, point, relativeTo, relativePoint, offsetX, offsetY = attribBar:GetAnchor(0)

        -- Adjust both bars to the left/right by half of the width of the health bar
        if (stats[i] == "Magicka") then
            offsetX = 0 - SIAB.vars.playerAttributeBarShift
            -- Set a new anchor point relative to the health bar in the center
            attribBar:ClearAnchors()
            attribBar:SetAnchor(point, ZO_PlayerAttributeHealth, relativePoint, offsetX, offsetY)
        elseif (stats[i] == "Stamina") then
            offsetX = 0 + SIAB.vars.playerAttributeBarShift
            -- Set a new anchor point relative to the health bar in the center
            attribBar:ClearAnchors()
            attribBar:SetAnchor(point, ZO_PlayerAttributeHealth, relativePoint, offsetX, offsetY)
        end

        -- Refresh the label text
        local powerCurrent, powerMax, powerEffectiveMax = GetUnitPower("player", types[i])
        SIAB.playerLabels[types[i]]:SetText(SIAB.FormatLabelText(powerCurrent, powerEffectiveMax))

        attribBar:SetAlpha(SIAB.vars.attributeBarAlpha)

    end
end

-- Create the label string based on user preferences
function SIAB.FormatLabelText(current, max)

    local percent = 0
    if (max > 0) then
        percent = math.floor((current/max) * 100)
    end

    local str = ""

    if (SIAB.vars.showCurrentMaxText) then
        str = str .. current .. " / " .. max
    end

    if (SIAB.vars.showPercentageText) then
        if (SIAB.vars.showCurrentMaxText) then
            str = str .. "  "
        end
        str = str .. percent .. "%"
    end

    return str

end

-- Callback for the power update event
function SIAB.PowerUpdate(eventCode, unitTag, powerIndex, powerType, powerValue, powerMax, powerEffectiveMax)

    if (unitTag ~= "player" and unitTag ~= "reticleover") then return end

    if (powerType ~= POWERTYPE_HEALTH and powerType ~= POWERTYPE_STAMINA and powerType ~= POWERTYPE_MAGICKA) then return end

    -- Find the correct label to use (either player or targeting reticle)
    local label = nil
    if (unitTag == "player") then
        label = SIAB.playerLabels[powerType]
    elseif (unitTag == "reticleover") then
        label = SIAB.targetLabel
    end

    label:SetText(SIAB.FormatLabelText(powerValue, powerEffectiveMax))

end

-- Callback for the gui control from the xml file
function SIAB.OnUpdate()

    -- Update was triggered before the saved variables were loaded
    if (SIAB.loaded == false) then return end

    -- Emulate the default UI behavior if alpha is 0
    if (SIAB.vars.attributeBarAlpha == 0.0) then return end

    -- Continuously set the alpha of the three player attribute bars so they
    -- don't fade out completely
    local stats = { "Health", "Stamina", "Magicka"}
    for i = 1, #stats, 1 do
        local control = _G["ZO_PlayerAttribute"..stats[i]]
        local curAlpha = control:GetAlpha()
        if (curAlpha < SIAB.vars.attributeBarAlpha) then
            control:SetAlpha(SIAB.vars.attributeBarAlpha)
        end
    end

    -- Update the target reticle text if there is a target
    local powerCurrent, powerMax, powerEffectiveMax = GetUnitPower("reticleover", POWERTYPE_HEALTH)
    if (powerEffectiveMax > 0) then
        SIAB.targetLabel:SetText(SIAB.FormatLabelText(powerCurrent, powerEffectiveMax))
    end

    ZO_TargetUnitFramereticleover:SetAlpha(SIAB.vars.targetReticleAlpha)

end
