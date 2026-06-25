-- ── State ─────────────────────────────────────────────────────────────────────

local placer = {
    active  = false,
    entity  = nil,
    mode    = 'ped',
    model   = '',
    x       = 0.0,
    y       = 0.0,
    z       = 0.0,
    heading = 0.0,
    step    = Config.Placer.Step,
}

local function fmt(n) return tonumber(string.format('%.4f', n)) end

-- ── Model loading ─────────────────────────────────────────────────────────────

local function loadModel(model)
    local hash = GetHashKey(model)
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    local t = GetGameTimer()
    while not HasModelLoaded(hash) do
        if GetGameTimer() - t > 5000 then
            SetModelAsNoLongerNeeded(hash)
            return nil
        end
        Wait(100)
    end
    return hash
end

-- ── Entity helpers ────────────────────────────────────────────────────────────

local function syncEntityTransform()
    if not placer.entity or not DoesEntityExist(placer.entity) then return end
    SetEntityCoords(placer.entity, placer.x, placer.y, placer.z, false, false, false)
    SetEntityHeading(placer.entity, placer.heading)
    FreezeEntityPosition(placer.entity, true)
end

local function spawnGhost(hash)
    local c = GetEntityCoords(cache.ped)
    local h = GetEntityHeading(cache.ped)

    placer.x, placer.y, placer.z, placer.heading = c.x, c.y + 2.0, c.z, h

    local e
    if placer.mode == 'ped' then
        e = CreatePed(4, hash, placer.x, placer.y, placer.z, placer.heading, false, false)
    else
        e = CreateObject(hash, placer.x, placer.y, placer.z, false, false, false)
        SetEntityHeading(e, placer.heading)
    end

    SetEntityAlpha(e, Config.Placer.Alpha, false)
    SetEntityCollision(e, false, false)
    FreezeEntityPosition(e, true)
    SetEntityInvincible(e, true)
    SetBlockingOfNonTemporaryEvents(e, true)
    SetModelAsNoLongerNeeded(hash)

    return e
end

local function destroyPlacer()
    if placer.entity and DoesEntityExist(placer.entity) then
        DeleteEntity(placer.entity)
    end
    placer.entity = nil
    placer.active = false
    NbDevtools.placerActive = false
end

local function confirmAndReturn()
    local result = {
        x     = fmt(placer.x),
        y     = fmt(placer.y),
        z     = fmt(placer.z),
        h     = fmt(placer.heading),
        model = placer.model,
        mode  = placer.mode,
    }
    destroyPlacer()
    SendUI('placer_confirmed', result)
    -- Return focus so user can copy from panel
    NbDevtools.focused = true
    SetNuiFocus(true, true)
end

-- ── NUI callbacks ─────────────────────────────────────────────────────────────

RegisterNUICallback('placerSpawn', function(data, cb)
    if placer.active then destroyPlacer() end

    placer.mode  = data.mode  or 'ped'
    placer.model = data.model or ''
    placer.step  = Config.Placer.Step

    CreateThread(function()
        local hash = loadModel(placer.model)
        if not hash then
            SendUI('placer_error', { msg = 'Model not found: ' .. placer.model })
            return
        end

        placer.entity = spawnGhost(hash)
        placer.active = true
        NbDevtools.placerActive = true

        -- Release NUI focus: user will control with keyboard
        NbDevtools.focused = false
        SetNuiFocus(false, false)

        SendUI('placer_state', {
            active = true,
            model  = placer.model,
            mode   = placer.mode,
            x = fmt(placer.x), y = fmt(placer.y),
            z = fmt(placer.z), h = fmt(placer.heading),
            step = placer.step,
        })
    end)

    cb('ok')
end)

RegisterNUICallback('placerConfirm', function(_, cb)
    if placer.active then confirmAndReturn() end
    cb('ok')
end)

RegisterNUICallback('placerCancel', function(_, cb)
    destroyPlacer()
    SendUI('placer_state', { active = false })
    NbDevtools.focused = true
    SetNuiFocus(true, true)
    cb('ok')
end)

RegisterNUICallback('placerSetStep', function(data, cb)
    placer.step = tonumber(data.step) or Config.Placer.Step
    cb('ok')
end)

-- ── Movement thread ───────────────────────────────────────────────────────────

CreateThread(function()
    while true do
        Wait(0)

        if not placer.active then goto continue end

        DisableAllControlActions(0)

        local step = IsDisabledControlPressed(0, 21) and Config.Placer.FastStep or placer.step
        local moved = false

        -- WASD: move on world XY plane
        if IsDisabledControlPressed(0, 32) then placer.y = placer.y + step; moved = true end
        if IsDisabledControlPressed(0, 33) then placer.y = placer.y - step; moved = true end
        if IsDisabledControlPressed(0, 34) then placer.x = placer.x - step; moved = true end
        if IsDisabledControlPressed(0, 35) then placer.x = placer.x + step; moved = true end

        -- Space / Ctrl: Z axis
        if IsDisabledControlPressed(0, 22) then placer.z = placer.z + step; moved = true end
        if IsDisabledControlPressed(0, 36) then placer.z = placer.z - step; moved = true end

        -- Arrow keys: rotate heading
        if IsDisabledControlJustPressed(0, 174) then
            placer.heading = (placer.heading + Config.Placer.RotStep) % 360.0
            moved = true
        end
        if IsDisabledControlJustPressed(0, 175) then
            placer.heading = (placer.heading - Config.Placer.RotStep + 360.0) % 360.0
            moved = true
        end

        if moved then
            syncEntityTransform()
            SendUI('update', {
                tool = 'placer',
                x = fmt(placer.x), y = fmt(placer.y),
                z = fmt(placer.z), h = fmt(placer.heading),
                step = placer.step,
            })
        end

        -- Enter: confirm
        if IsDisabledControlJustPressed(0, 191) then confirmAndReturn() end

        -- Backspace: cancel
        if IsDisabledControlJustPressed(0, 177) then
            destroyPlacer()
            SendUI('placer_state', { active = false })
            NbDevtools.focused = true
            SetNuiFocus(true, true)
        end

        ::continue::
    end
end)

-- ── On-screen hint during keyboard mode ──────────────────────────────────────

local hints = {
    'PLACER  W/A/S/D=Move  Space/Ctrl=Z  ←→=Rotate  Shift=Fast',
    'ENTER = Confirm      BACKSPACE = Cancel',
}

CreateThread(function()
    while true do
        Wait(0)
        if placer.active then
            for i, text in ipairs(hints) do
                SetTextFont(4)
                SetTextScale(0.0, 0.3)
                SetTextColour(255, 200, 50, 220)
                SetTextOutline()
                SetTextEntry('STRING')
                AddTextComponentSubstringPlayerName(text)
                DrawText(0.02, 0.87 + (i - 1) * 0.025)
            end
        end
    end
end)

-- ── Cleanup ───────────────────────────────────────────────────────────────────

AddEventHandler('onClientResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if placer.entity and DoesEntityExist(placer.entity) then
        DeleteEntity(placer.entity)
    end
end)
