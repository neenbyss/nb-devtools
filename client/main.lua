local bridge = exports['nb-bridge']:get()

-- Central state shared across all tool scripts in this resource
NbDevtools = {
    allowed       = false,
    visible       = false,
    focused       = false,
    activeTool    = 'coords',
    freeCamActive = false,
    placerActive  = false,
}

-- Single message wrapper — { action, data } schema per nui.md convention
function SendUI(action, data)
    SendNUIMessage({ action = action, data = data or {} })
end

-- ── Permission ────────────────────────────────────────────────────────────────

AddEventHandler('nb-devtools:client:setPermission', function(allowed)
    NbDevtools.allowed = allowed
end)

CreateThread(function()
    Wait(2000)
    TriggerServerEvent('nb-devtools:server:requestAccess')
end)

-- ── Panel lifecycle ───────────────────────────────────────────────────────────

local function openPanel()
    NbDevtools.visible = true
    NbDevtools.focused = true
    SetNuiFocus(true, true)
    SendUI('open', {
        tool        = NbDevtools.activeTool,
        pedPresets  = Config.PedPresets,
        propPresets = Config.PropPresets,
    })
end

local function closePanel()
    NbDevtools.visible = false
    NbDevtools.focused = false
    SetNuiFocus(false, false)
    SendUI('close')
end

RegisterCommand(Config.Command, function()
    if not NbDevtools.allowed then
        TriggerServerEvent('nb-devtools:server:requestAccess')
        return
    end
    if NbDevtools.visible then closePanel() else openPanel() end
end, false)

RegisterKeyMapping(Config.Command, 'Toggle nb-devtools panel', 'keyboard', 'F10')

-- ── NUI callbacks ─────────────────────────────────────────────────────────────

RegisterNUICallback('close', function(_, cb)
    closePanel()
    cb('ok')
end)

RegisterNUICallback('setTool', function(data, cb)
    NbDevtools.activeTool = data.tool
    cb('ok')
end)

-- Called when user activates a tool that needs keyboard (placer/camera)
RegisterNUICallback('releaseFocus', function(_, cb)
    NbDevtools.focused = false
    SetNuiFocus(false, false)
    cb('ok')
end)

-- Called when user clicks the panel to regain focus after keyboard mode
RegisterNUICallback('captureFocus', function(_, cb)
    if NbDevtools.visible then
        NbDevtools.focused = true
        SetNuiFocus(true, true)
    end
    cb('ok')
end)
