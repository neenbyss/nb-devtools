-- Entity inspector: continuous raycast from the camera crosshair

local entityTypes = { [1] = 'PED', [2] = 'VEHICLE', [3] = 'OBJECT' }

local function fmt(n) return tonumber(string.format('%.4f', n)) end

local function getForwardVector()
    local rot = GetFinalRenderedCamRot(2)
    local rx  = math.rad(rot.x)
    local rz  = math.rad(rot.z)
    return vector3(
        -math.sin(rz) * math.abs(math.cos(rx)),
         math.cos(rz) * math.abs(math.cos(rx)),
         math.sin(rx)
    )
end

local function hashToHex(hash)
    -- Ensure unsigned 32-bit representation
    local u = hash & 0xFFFFFFFF
    return ('0x%08X'):format(u)
end

local function buildEntityData(entity, hitCoords)
    local etype = GetEntityType(entity)
    local hash  = GetEntityModel(entity)
    local ec    = GetEntityCoords(entity)
    local eh    = GetEntityHeading(entity)
    local ehp   = GetEntityHealth(entity)
    local emaxhp= GetEntityMaxHealth(entity)
    local einv  = GetEntityInvincible(entity)
    local netId = entity ~= 0 and NetworkGetNetworkIdFromEntity(entity) or 0
    local isNet = entity ~= 0 and NetworkGetEntityIsNetworked(entity) or false

    local extra = {}
    if etype == 2 then -- vehicle
        local plate = GetVehicleNumberPlateText(entity)
        local speed = GetEntitySpeed(entity)
        extra = { plate = plate, speed = fmt(speed * 3.6) } -- m/s → km/h
    end

    return {
        hit        = true,
        entityType = entityTypes[etype] or 'UNKNOWN',
        model      = hashToHex(hash),
        netId      = isNet and netId or 0,
        networked  = isNet,
        -- World position of the entity itself
        x          = fmt(ec.x),
        y          = fmt(ec.y),
        z          = fmt(ec.z),
        h          = fmt(eh),
        -- Hit point from raycast
        hx         = fmt(hitCoords.x),
        hy         = fmt(hitCoords.y),
        hz         = fmt(hitCoords.z),
        health     = ehp,
        maxHealth  = emaxhp,
        invincible = einv,
        extra      = extra,
    }
end

-- ── Raycast thread ────────────────────────────────────────────────────────────

CreateThread(function()
    while true do
        Wait(300)

        if not (NbDevtools.visible and NbDevtools.activeTool == 'inspector') then
            goto continue
        end

        local origin = GetFinalRenderedCamCoord()
        local dest   = origin + getForwardVector() * Config.Inspector.Distance

        local handle = StartExpensiveSynchronousShapeTestLosProbe(
            origin.x, origin.y, origin.z,
            dest.x,   dest.y,   dest.z,
            1 | 16,   -- 1 = world/objects, 16 = peds/vehicles
            cache.ped,
            4
        )

        local _, hit, hitCoords, _, entity = GetShapeTestResult(handle)

        if hit == 1 and entity and entity ~= 0 then
            SendUI('update', buildEntityData(entity, hitCoords))
        else
            -- Show raycast endpoint; nil-guard in case shape test returned nothing
            local safeCoords = hitCoords or dest
            SendUI('update', {
                hit        = false,
                entityType = 'NONE',
                hx         = fmt(safeCoords.x),
                hy         = fmt(safeCoords.y),
                hz         = fmt(safeCoords.z),
            })
        end

        ::continue::
    end
end)

-- ── "Inspect nearest" callback (optional, for offset use case) ────────────────

RegisterNUICallback('inspectNearest', function(data, cb)
    local targetType = data.entityType or 'vehicle' -- 'vehicle' | 'ped' | 'object'
    local ped        = cache.ped
    local pCoords    = GetEntityCoords(ped)
    local nearest    = 0
    local nearDist   = 30.0

    if targetType == 'vehicle' then
        nearest = GetClosestVehicle(pCoords.x, pCoords.y, pCoords.z, nearDist, 0, 70)
    elseif targetType == 'ped' then
        nearest = GetClosestPed(pCoords.x, pCoords.y, pCoords.z, nearDist, true, true, true, false, 0)
    end

    if nearest and nearest ~= 0 and DoesEntityExist(nearest) then
        local c = GetEntityCoords(nearest)
        cb(buildEntityData(nearest, c))
    else
        cb({ hit = false, entityType = 'NONE' })
    end
end)

-- ── Crosshair dot when inspector is active ────────────────────────────────────

CreateThread(function()
    while true do
        Wait(0)
        if NbDevtools.visible and NbDevtools.activeTool == 'inspector' then
            -- Small crosshair indicator at screen center
            DrawRect(0.5, 0.5, 0.008, 0.001, 100, 200, 255, 180)
            DrawRect(0.5, 0.5, 0.001, 0.012, 100, 200, 255, 180)
        end
    end
end)
