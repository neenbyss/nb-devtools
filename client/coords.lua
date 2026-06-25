local function fmt(n) return tonumber(string.format('%.4f', n)) end

CreateThread(function()
    while true do
        Wait(200)

        if not (NbDevtools.visible and NbDevtools.activeTool == 'coords') then
            goto continue
        end

        local c  = GetEntityCoords(cache.ped)
        local h  = GetEntityHeading(cache.ped)
        local cc = GetFinalRenderedCamCoord()
        local cr = GetFinalRenderedCamRot(2)
        local cf = GetFinalRenderedCamFov()

        SendUI('update', {
            tool   = 'coords',
            player = { x = fmt(c.x),  y = fmt(c.y),  z = fmt(c.z),  h = fmt(h)    },
            cam    = {
                x   = fmt(cc.x), y   = fmt(cc.y), z   = fmt(cc.z),
                rx  = fmt(cr.x), ry  = fmt(cr.y), rz  = fmt(cr.z),
                fov = fmt(cf),
            },
        })

        ::continue::
    end
end)
