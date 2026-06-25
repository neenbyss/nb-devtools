local bridge = exports['nb-bridge']:get()

RegisterNetEvent('nb-devtools:server:requestAccess', function()
    local src = source
    local allowed = not Config.AdminOnly or bridge.player.isAdmin(src)
    TriggerClientEvent('nb-devtools:client:setPermission', src, allowed)
    if not allowed then
        bridge.notify.send(src, 'No permission to use nb-devtools', 'error')
    end
end)

bridge.event.onPlayerLoaded(function(src)
    if not Config.AdminOnly or bridge.player.isAdmin(src) then
        TriggerClientEvent('nb-devtools:client:setPermission', src, true)
    end
end)
