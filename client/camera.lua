-- Free-fly camera following the exact pattern from camera-system.md

local cam     = nil
local camPos  = vector3(0, 0, 0)
local camRot  = vector3(0, 0, 0)
local camFov  = Config.Camera.FovDefault

local function fmt(n) return tonumber(string.format('%.4f', n)) end
local function norm(v) local l = #v; return l > 0 and (v / l) or v end

-- ── Lifecycle ─────────────────────────────────────────────────────────────────

local function activateCam()
    if cam then return end

    local pos = GetEntityCoords(cache.ped)
    local h   = GetEntityHeading(cache.ped)

    cam    = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    camPos = vector3(pos.x, pos.y, pos.z + 1.5)
    camRot = vector3(-10.0, 0.0, h)
    camFov = Config.Camera.FovDefault

    SetCamCoord(cam, camPos.x, camPos.y, camPos.z)
    SetCamRot(cam, camRot.x, camRot.y, camRot.z, 2)
    SetCamFov(cam, camFov)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 500, true, false)

    SetPlayerControl(cache.playerId, false, 0)
    NbDevtools.freeCamActive = true

    SendUI('camera_state', { active = true })
end

local function deactivateCam()
    if not cam then return end

    SetCamActive(cam, false)
    RenderScriptCams(false, true, 500, true, false)
    Wait(600)
    DestroyCam(cam, false)
    cam = nil

    SetPlayerControl(cache.playerId, true, 0)
    NbDevtools.freeCamActive = false

    SendUI('camera_state', { active = false })
end

-- ── NUI callback ──────────────────────────────────────────────────────────────

RegisterNUICallback('toggleCamera', function(_, cb)
    if cam then
        deactivateCam()
        -- Return NUI focus after deactivation
        NbDevtools.focused = true
        SetNuiFocus(true, true)
    else
        activateCam()
        -- Release NUI focus: user needs mouse for camera look
        NbDevtools.focused = false
        SetNuiFocus(false, false)
    end
    cb('ok')
end)

-- ── Movement thread ───────────────────────────────────────────────────────────

CreateThread(function()
    while true do
        Wait(0)

        if not cam then goto continue end

        DisableAllControlActions(0)

        local frameTime = GetFrameTime()

        -- Speed tier
        local speed = Config.Camera.Speed
        if IsDisabledControlPressed(0, 21) then speed = Config.Camera.FastSpeed  end -- Shift
        if IsDisabledControlPressed(0, 36) then speed = Config.Camera.SlowSpeed  end -- Ctrl (also used for down)

        -- Derive orthonormal axes from camera matrix for frame-relative movement
        local _r, _f, _u, _ = GetCamMatrix(cam)
        local up    = vector3(0.0, 0.0, 1.0)
        local right = norm(vector3(_r.x, _r.y, 0.0))
        local fwd   = norm(vector3(_f.x, _f.y, 0.0))

        -- Mouse look — controls 1 = mouse X, 2 = mouse Y
        local mX = GetDisabledControlNormal(0, 1) * Config.Camera.MouseSpeed
        local mY = GetDisabledControlNormal(0, 2) * Config.Camera.MouseSpeed

        camRot = vector3(
            math.max(-89.0, math.min(89.0, camRot.x - mY)),
            0.0,
            (camRot.z - mX) % 360.0
        )

        -- WASD: forward/back, strafe
        if IsDisabledControlPressed(0, 32) then camPos = camPos + fwd   * speed end -- W
        if IsDisabledControlPressed(0, 33) then camPos = camPos - fwd   * speed end -- S
        if IsDisabledControlPressed(0, 35) then camPos = camPos + right * speed end -- D
        if IsDisabledControlPressed(0, 34) then camPos = camPos - right * speed end -- A

        -- Space / Ctrl: up/down on world Z
        if IsDisabledControlPressed(0, 22) then camPos = camPos + up * speed end -- Space
        if IsDisabledControlPressed(0, 36) then camPos = camPos - up * speed end -- Ctrl

        -- Scroll wheel: FOV
        if IsDisabledControlJustPressed(0, 241) then -- scroll up = zoom in
            camFov = math.max(Config.Camera.FovMin, camFov - Config.Camera.FovStep)
            SetCamFov(cam, camFov)
        elseif IsDisabledControlJustPressed(0, 242) then -- scroll down = zoom out
            camFov = math.min(Config.Camera.FovMax, camFov + Config.Camera.FovStep)
            SetCamFov(cam, camFov)
        end

        SetCamCoord(cam, camPos.x, camPos.y, camPos.z)
        SetCamRot(cam, camRot.x, camRot.y, camRot.z, 2)

        -- Backspace: exit free cam
        if IsDisabledControlJustPressed(0, 177) then
            deactivateCam()
            NbDevtools.focused = true
            SetNuiFocus(true, true)
        end

        -- Send live data to NUI only when camera tab is active
        if NbDevtools.activeTool == 'camera' then
            SendUI('update', {
                tool = 'camera',
                active = true,
                x   = fmt(camPos.x), y   = fmt(camPos.y), z   = fmt(camPos.z),
                rx  = fmt(camRot.x), ry  = fmt(camRot.y), rz  = fmt(camRot.z),
                fov = fmt(camFov),
            })
        end

        ::continue::
    end
end)

-- ── On-screen hint ────────────────────────────────────────────────────────────

CreateThread(function()
    while true do
        Wait(0)
        if cam then
            local hints = {
                'FREE CAM  WASD=Move  Space/Ctrl=Up/Down  Shift=Fast',
                'Mouse=Look  Scroll=FOV  BACKSPACE=Exit',
            }
            for i, text in ipairs(hints) do
                SetTextFont(4)
                SetTextScale(0.0, 0.3)
                SetTextColour(100, 200, 255, 220)
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
    if cam then
        SetCamActive(cam, false)
        RenderScriptCams(false, false, 0, true, false)
        DestroyCam(cam, false)
        cam = nil
        SetPlayerControl(cache.playerId, true, 0)
    end
end)
