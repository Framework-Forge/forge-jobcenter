local C, S = JobCenter, JobCenter.schema
local prefix, N, stream = 'forge-jobcenter:', pr_lib.nui, pr_lib.fivem.streaming
local ready, stopped, opening, view, session, currentNpc
local npcs, pending = {}, {}
local outgoing
local worldRevision, needsRefresh, operation = -1, true, nil

local function fail(message) return { ok = false, error = message } end
local function rpc(kind, payload, timeout)
    local success, result = pcall(pr_lib.callback.await, prefix .. kind, timeout or 5000, payload or {})
    if not success or type(result) ~= 'table' then return fail('Não foi possível comunicar com o servidor.') end
    return result
end
local function notify(message, kind)
    pr_lib.Notify({ title = 'Forge - Job Center', description = message, type = kind or 'inform' })
end
local function exists(ped) return type(ped) == 'number' and ped > 0 and DoesEntityExist(ped) end
local function coords()
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z, w = GetEntityHeading(ped) }
end
local function close()
    if session then TriggerServerEvent(prefix .. 'close', session) end
    if operation == 'placement' then pcall(pr_lib.devtools.stop) end
    session, view, currentNpc, operation = nil, nil, nil, nil
    N.focus(false)
    N.send('close', {})
end
local function canOpen()
    return not stopped and ready and not opening and not view and not IsNuiFocused()
        and not IsPauseMenuActive() and not IsEntityDead(PlayerPedId())
end
local function open(kind, id)
    if not canOpen() then return end
    opening = true
    local result = rpc(kind, { id = id })
    opening = false
    if not result.ok then notify(result.error, 'error'); return end
    if not canOpen() then
        if result.data.token then TriggerServerEvent(prefix .. 'close', result.data.token) end
        return
    end
    view, session, currentNpc = kind == 'admin' and 'admin' or result.data.mode, result.data.token, id
    N.focus(true, true, false)
    N.send('open', { mode = view, payload = result.data })
end

RegisterCommand(C.command, function() open('admin') end, false)

local function removeNpc(id)
    local p = npcs[id]
    if not p then return end
    npcs[id] = nil
    if p.target then pcall(pr_lib.target.removeLocalEntity, p.entity, { p.name })
    elseif p.interaction then pcall(pr_lib.interact.RemoveInteraction, p.interaction) end
    if exists(p.entity) then stream.deleteEntity(p.entity) end
end
local function spawnNpc(npc, settings)
    local c = npc.coords
    local position = vector3(c.x, c.y, c.z)
    local entity = stream.createPed(npc.model, position, c.w + 0.0,
        { networked = false, missionEntity = true, freeze = true, invincible = true, timeout = 3500 })
    if not exists(entity) then return end
    if stopped then stream.deleteEntity(entity); return end
    stream.setEntityTransform(entity, position, c.w + 0.0, { noOffset = false })
    local name = prefix .. npc.id
    local function canInteract() return not view and not opening and ready and not IsEntityDead(PlayerPedId()) end
    local function select() open('open', npc.id) end
    local entry = { entity = entity, name = name }
    npcs[npc.id] = entry
    if settings.interaction == 'target' then
        local success, result = pcall(pr_lib.target.addLocalEntity, entity, {{
            name = name, label = npc.label, icon = 'fa-solid fa-comments',
            distance = settings.distance, wallDetection = true, canInteract = canInteract, onSelect = select,
        }})
        entry.target = success
        if not success or result == false then removeNpc(npc.id) end
    else
        local success, id = pcall(pr_lib.interact.AddLocalEntityInteraction, {
            id = name, entity = entity, distance = 8.0, interactDst = settings.distance, wallDetection = true,
            options = {{ name = name, label = npc.label, canInteract = canInteract, action = select }},
        })
        if not success or not id then removeNpc(npc.id); return end
        entry.interaction = id
    end
end

RegisterNetEvent(prefix .. 'changed', function()
    if source ~= 65535 then return end
    needsRefresh = true
    if currentNpc then close() end
end)

CreateThread(function()
    local last, nextCheck, retryAfter = nil, 0, 0
    while not stopped do
        Wait(1200)
        -- Do not rebuild the world's NPCs when only a menu opens.
        local p = coords()
        local now = GetGameTimer()
        local moved = not last or (p.x-last.x)^2 + (p.y-last.y)^2 + (p.z-last.z)^2 > 5^2
        if ready and now >= retryAfter and (needsRefresh or moved or now >= nextCheck) then
            needsRefresh = false
            local result = rpc('discover')
            if result.ok and not stopped then
                last, nextCheck = p, GetGameTimer() + 10000
                local data, seen = result.data, {}
                if worldRevision ~= data.revision then
                    for id in pairs(npcs) do removeNpc(id) end
                    worldRevision = data.revision
                end
                for _, row in ipairs(data.npcs) do seen[row.id] = true end
                for id, entry in pairs(npcs) do if not seen[id] or not exists(entry.entity) then removeNpc(id) end end
                if currentNpc and not seen[currentNpc] then close() end
                for _, row in ipairs(data.npcs) do if not stopped and not npcs[row.id] then spawnNpc(row, data.general) end end
            else retryAfter = GetGameTimer() + 6000 end
        end
        if view and (IsEntityDead(PlayerPedId()) or IsPauseMenuActive()) then close() end
    end
end)

local function transferred(kind, id, result)
    if source ~= 65535 or type(id) ~= 'number' then return end
    local key = kind .. id
    local wait = pending[key]
    if wait then pending[key] = nil; wait:resolve(result) end
end
RegisterNetEvent(prefix .. 'uploadResult', function(token, result) transferred('upload', token, result) end)
local function sendChunk(job)
    local offset = (job.index - 1) * C.mediaChunk
    TriggerLatentServerEvent(prefix .. 'upload', C.mediaBandwidth, job.id, job.index, job.total,
        job.uri:sub(offset + 1, offset + C.mediaChunk))
end
RegisterNetEvent(prefix .. 'uploadAck', function(id, index)
    if source ~= 65535 or not outgoing or outgoing.id ~= id or outgoing.index ~= index or index >= outgoing.total then return end
    outgoing.index = index + 1
    sendChunk(outgoing)
end)

N.register('ready', function(_, reply) ready = true; reply({ ok = true }) end)
N.register('close', function(_, reply) close(); reply({ ok = true }) end)
N.register('coords', function(_, reply)
    reply(view == 'admin' and { ok = true, data = coords() } or fail('Abra a administração primeiro.'))
end)
N.register('model', function(data, reply)
    local model = type(data) == 'table' and S.model(data.model)
    local hash = model and joaat(model)
    reply(view == 'admin' and hash and IsModelInCdimage(hash) and IsModelAPed(hash)
        and { ok = true } or fail('Modelo de NPC indisponível.'))
end)

for _, action in ipairs({ 'detail', 'route', 'vote', 'admin', 'edit' }) do
    N.register(action, function(data, reply)
        if type(data) ~= 'table' or not view or operation then reply(fail('Abra o painel novamente.')); return end
        local admin = action == 'admin' or action == 'edit'
        if admin ~= (view == 'admin') then reply(fail('Ação indisponível neste painel.')); return end
        local old = session
        data.token = session
        local result = rpc(action, data)
        if action == 'route' and result.ok and session == old and view then
            SetNewWaypoint(result.data.x + 0.0, result.data.y + 0.0)
            notify('Destino marcado no GPS.', 'success')
            close()
            result.data = nil
        end
        reply(result)
    end)
end

N.register('place', function(data, reply)
    if view ~= 'admin' or operation or not S.model(data.model) then reply(fail('Informe um modelo válido primeiro.')); return end
    local allowed = rpc('admin')
    if not allowed.ok or view ~= 'admin' or operation then reply(fail('Operação indisponível.')); return end
    operation = 'placement'
    N.send('suspend', { active = true })
    N.focus(false)
    local success, started = pcall(pr_lib.devtools.placePed, data.model, 1, function(result)
        if view ~= 'admin' or operation ~= 'placement' then return end
        operation = nil
        local placed = result and S.coords({ x = result.x, y = result.y, z = result.z, w = result.heading }, true)
        N.send('placement', { coords = placed })
        N.focus(true, true, false)
    end, { preview = true, freezePlayer = true, confirmOnPlace = true, heightOffset = 0.0,
        heading = S.number(data.heading, -360, 360) or 0.0, modelTimeout = 5000 })
    if not success or not started then
        operation = nil
        N.send('suspend', { active = false })
        N.focus(true, true, false)
        reply(fail('Não foi possível abrir o posicionador. Confira o modelo.'))
    else reply({ ok = true }) end
end)

N.register('capture', function(_, reply)
    if view ~= 'admin' or operation then reply(fail('Captura indisponível.')); return end
    operation = 'capture'
    N.send('suspend', { active = true })
    N.focus(false)
    Wait(350)
    local result = view == 'admin' and operation == 'capture' and rpc('capture', nil, 14500) or fail('Captura cancelada.')
    if view == 'admin' and operation == 'capture' then
        operation = nil; N.send('suspend', { active = false }); N.focus(true, true, false)
    end
    reply(result)
end)

N.register('upload', function(data, reply)
    if view ~= 'admin' or operation or type(data.uri) ~= 'string' or #data.uri > math.ceil(C.maxVideo / 3) * 4 + 48 then
        reply(fail('Envio indisponível ou arquivo acima do limite.')); return
    end
    operation = 'upload'
    local permission = rpc('uploadPermit')
    if not permission.ok or view ~= 'admin' or operation ~= 'upload' then
        if operation == 'upload' then operation = nil end
        reply(permission.ok and fail('Envio cancelado.') or permission); return
    end
    local id = permission.data
    local wait = promise.new()
    pending['upload' .. id] = wait
    SetTimeout(56000, function()
        if pending['upload' .. id] == wait then
            pending['upload' .. id] = nil
            wait:resolve(fail('O envio demorou demais. Tente novamente.'))
        end
    end)
    outgoing = { id = id, index = 1, total = math.ceil(#data.uri / C.mediaChunk), uri = data.uri }
    sendChunk(outgoing)
    local result = Citizen.Await(wait)
    if outgoing and outgoing.id == id then outgoing = nil end
    if operation == 'upload' then operation = nil end
    reply(result)
end)

N.register('media', function(data, reply)
    if not view or view == 'illegal' or not S.mediaName(data.file) then reply(fail('Mídia indisponível.')); return end
    reply(rpc('media', { token = session, id = data.id, file = data.file, admin = view == 'admin' }))
end)

N.register('mediaPart', function(data, reply)
    if not view or view == 'illegal' then reply(fail('O acesso à mídia foi encerrado.')); return end
    reply(rpc('mediaPart', { ticket = data.ticket, index = data.index }))
end)

N.register('mediaClose', function(data, reply)
    reply(rpc('mediaClose', { ticket = data.ticket }))
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    stopped = true
    close()
    for id in pairs(npcs) do removeNpc(id) end
end)

