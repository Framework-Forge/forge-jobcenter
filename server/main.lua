local C, S = JobCenter, JobCenter.schema
local prefix = 'forge-jobcenter:'
local chunkSize = C.mediaChunk
local maxEncoded = math.ceil(C.maxVideo / 3) * 4 + 48
local function copy(t) local out = {}; for k, v in pairs(t) do out[k] = v end; return out end
local function general(value)
    if type(value) ~= 'table' or (value.interaction ~= 'target' and value.interaction ~= 'interact') then return nil end
    local distance = S.number(value.distance, 1.25, 4)
    if not distance then return nil end
    local theme = S.theme(value.theme)
    if not theme then return nil end
    return { interaction = value.interaction, distance = distance, theme = theme }
end
local function validate(data)
    if type(data) ~= 'table' then return nil end
    local sequence = S.number(data.sequence, 0, 999999999)
    local settings = general(data.general)
    if not sequence or sequence % 1 ~= 0 or not settings then return nil end
    local out = { sequence = sequence, general = settings, jobs = {}, topics = {}, npcs = {} }
    for _, section in ipairs({ 'jobs', 'topics', 'npcs' }) do
        if type(data[section]) ~= 'table' then return nil end
        local count = 0
        for id, raw in pairs(data[section]) do
            local serial = S.id(id) and tonumber(id:match('^' .. section .. '%-(%d+)$'))
            if not serial or serial < 1 or serial > sequence then return nil end
            count = count + 1
            if count > C.catalogLimits[section] then return nil end
            local item = S.record(section, id, raw, out)
            if not item then return nil end
            out[section][id] = item
        end
    end
    return out
end
local function validateVotes(data)
    if type(data) ~= 'table' then return nil end
    for id, votes in pairs(data) do
        if not S.id(id) or type(votes) ~= 'table' then return nil end
        for identifier, rating in pairs(votes) do
            if type(identifier) ~= 'string' or not identifier:match('^license:[a-f0-9]+$') or #identifier > 80
                or (rating ~= -1 and rating ~= 1) then return nil end
        end
    end
    return data
end

local catalog = C.storage.open('catalog', {
    general = { interaction = 'interact', distance = C.interactionDistance, theme = S.theme() },
    sequence = 0, npcs = {}, jobs = {}, topics = {},
}, validate, 2 * 1024 * 1024)
local votes = C.storage.open('votes', {}, validateVotes, 4 * 1024 * 1024)
local totals = {}
for id, group in pairs(votes.get()) do
    local up, down = 0, 0
    for _, vote in pairs(group) do if vote == 1 then up = up + 1 else down = down + 1 end end
    totals[id] = { up = up, down = down }
end

local sessions, rate, captures, uploads, downloads = {}, {}, {}, {}, {}
local counter = 0
local function ok(data) return { ok = true, data = data } end
local function fail(message) return { ok = false, error = message } end
local function admin(src)
    local first, second = IsPlayerAceAllowed(src, C.ace), IsPlayerAceAllowed(src, C.inheritAce)
    return first == true or first == 1 or second == true or second == 1
end
local function identifier(src)
    local value = GetPlayerIdentifierByType(src, 'license')
    return type(value) == 'string' and #value <= 80 and value:match('^license:[a-f0-9]+$') and value or nil
end
local function throttled(src, key, ms)
    rate[src] = rate[src] or {}
    local now = GetGameTimer()
    local current = rate[src][key]
    if current and now >= current and now - current < ms then return true end
    rate[src][key] = now
    return false
end
local function register(name, handler, interval)
    pr_lib.callback.register(prefix .. name, function(src, request)
        if type(src) ~= 'number' or src <= 0 then return fail('Jogador inválido.') end
        if throttled(src, name, interval or 250) then return fail('Aguarde um instante.') end
        local success, response = pcall(handler, src, type(request) == 'table' and request or {})
        if not success then
            print(('[forge-jobcenter] Falha em %s: %s'):format(name, tostring(response)))
            return fail('Não foi possível concluir esta operação.')
        end
        return response
    end)
end

local function playerPosition(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end
    if type(GetEntityHealth) == 'function' and GetEntityHealth(ped) <= 0 then return nil end
    return GetEntityCoords(ped)
end
local function nearby(src, npc, distance, pos, bucket)
    if not npc or not npc.enabled then return false end
    bucket = bucket or GetPlayerRoutingBucket(src)
    if npc.bucket ~= bucket then return false end
    pos = pos or playerPosition(src)
    if not pos then return false end
    local point = npc.coords
    return (pos.x - point.x)^2 + (pos.y - point.y)^2 + (pos.z - point.z)^2 <= distance^2
end

local function publicRating(id, src)
    local group = votes.get()[id]
    local total = totals[id] or { up = 0, down = 0 }
    local who = identifier(src)
    return { up = total.up, down = total.down, vote = who and group and group[who] or 0 }
end
local function linked(npc, id)
    for _, ref in ipairs(npc.links) do if ref == id then return true end end
    return false
end
local function access(src, request, legalOnly)
    local state, rev = catalog.get()
    local session = sessions[src]
    if not session or session.token ~= request.token or session.revision ~= rev then return end
    local npc = state.npcs[session.npc]
    if not nearby(src, npc, state.general.distance + 1.0) or (legalOnly and npc.mode ~= 'legal') then return end
    return state, npc
end
local function entry(src, request, legalOnly)
    local state, npc = access(src, request, legalOnly)
    if not state or not S.id(request.id) or (npc.catalogMode ~= 'all' and not linked(npc, request.id)) then return nil end
    local item = state[npc.mode == 'legal' and 'jobs' or 'topics'][request.id]
    return item and item.enabled and item or nil, npc
end
local function snapshot()
    local state, revision = catalog.get()
    return { state = state, revision = revision, defaultTheme = S.theme(), limits = { image = C.maxImage, video = C.maxVideo }, capture = GetResourceState(C.captureResource) == 'started' }
end

register('discover', function(src)
    local state, revision = catalog.get()
    local list, position, bucket = {}, playerPosition(src), GetPlayerRoutingBucket(src)
    if position then
        for _, npc in pairs(state.npcs) do
            if nearby(src, npc, C.streamDistance, position, bucket) then
                list[#list + 1] = { id = npc.id, coords = npc.coords, model = npc.model, label = npc.label }
            end
        end
    end
    return ok({ npcs = list, revision = revision, general = state.general })
end, 950)

register('open', function(src, request)
    local state, revision = catalog.get()
    local npc = S.id(request.id) and state.npcs[request.id]
    if not nearby(src, npc, state.general.distance + 0.75) then return fail('Aproxime-se do contato.') end
    counter = counter + 1
    sessions[src] = { npc = npc.id, revision = revision, token = counter }
    local items = {}
    local entries = state[npc.mode == 'legal' and 'jobs' or 'topics']
    local ids = npc.links
    if npc.catalogMode == 'all' then
        ids = {}
        for id, item in pairs(entries) do if item.enabled then ids[#ids+1] = id end end
        table.sort(ids, function(a, b)
            local x, y = entries[a].title:lower(), entries[b].title:lower()
            if x == y then return a < b end
            return x < y
        end)
    end
    for _, id in ipairs(ids) do
        local item = entries[id]
        if item and item.enabled then
            local row = { id = id, title = item.title }
            if npc.mode == 'legal' then
                row.summary, row.media, row.rating = item.summary, item.media, publicRating(id, src)
            end
            items[#items+1] = row
        end
    end
    return ok({ mode = npc.mode, title = npc.title, intro = npc.intro, token = counter, items = items,
        theme = npc.mode == 'legal' and state.general.theme or nil })
end, 500)

register('detail', function(src, request)
    local item, npc = entry(src, request)
    if not item then return fail('Conteúdo indisponível. Volte a falar com o contato.') end
    return ok({ id = item.id, title = item.title, details = item.details, summary = item.summary,
        media = item.media, route = item.route ~= nil, rating = npc.mode == 'legal' and publicRating(item.id, src) or nil })
end)

register('route', function(src, request)
    local item = entry(src, request)
    if not item or not item.route then return fail('Este destino não está disponível.') end
    return ok(item.route)
end, 400)

register('vote', function(src, request)
    local item = entry(src, request, true)
    local who = identifier(src)
    if not item or not who or (request.value ~= -1 and request.value ~= 1 and request.value ~= 0) then
        return fail('Avaliação não permitida.')
    end
    local data = copy(votes.get())
    local group = copy(data[item.id] or {})
    local previous = group[who] or 0
    if previous == request.value then return ok(publicRating(item.id, src)) end
    group[who] = request.value ~= 0 and request.value or nil
    data[item.id] = next(group) and group or nil
    local written, err = votes.save(data)
    if not written then return fail(err) end
    local t = totals[item.id] or { up = 0, down = 0 }
    t.up = t.up - (previous == 1 and 1 or 0) + (request.value == 1 and 1 or 0)
    t.down = t.down - (previous == -1 and 1 or 0) + (request.value == -1 and 1 or 0)
    totals[item.id] = t
    return ok(publicRating(item.id, src))
end, 700)

register('admin', function(src)
    if not admin(src) then return fail('Você não tem permissão para administrar a central.') end
    return ok(snapshot())
end, 300)

register('edit', function(src, request)
    if not admin(src) then return fail('Sem permissão administrativa.') end
    local state, revision = catalog.get()
    if request.revision ~= revision then return fail('A central mudou. Recarregue os dados antes de salvar.') end
    local out, section = copy(state), request.section
    if section == 'general' and request.op == 'save' then
        out.general = general(request.value)
        if not out.general then return fail('Confira a interação, a distância, os textos e as cores do layout.') end
    else
        if type(section) ~= 'string' or not C.catalogLimits[section] then return fail('Catálogo inválido.') end
        out[section] = copy(state[section])
        local id = request.id
        if id ~= nil and (not S.id(id) or not state[section][id]) then return fail('Cadastro inexistente.') end
        if request.op == 'delete' and id then
            out[section][id] = nil
            if section ~= 'npcs' then
                out.npcs = copy(state.npcs)
                for npcId, npc in pairs(state.npcs) do
                    if linked(npc, id) then
                        local updated = copy(npc); updated.links = {}
                        for _, link in ipairs(npc.links) do if link ~= id then updated.links[#updated.links+1] = link end end
                        out.npcs[npcId] = updated
                    end
                end
            end
        elseif request.op == 'save' then
            if not id then
                local count = 0
                for _ in pairs(state[section]) do count = count + 1 end
                if count >= C.catalogLimits[section] or out.sequence >= 999999999 then return fail('Limite do catálogo atingido.') end
                out.sequence = out.sequence + 1
                id = section .. '-' .. out.sequence
            end
            local item, err = S.record(section, id, request.value, state)
            if not item then return fail(err) end
            if item.media and item.media.file then
                local existing = state[section][id]
                if (not existing or not existing.media or existing.media.file ~= item.media.file)
                    and not C.media.load(item.media.file) then return fail('O arquivo de mídia não existe ou não é válido.') end
            end
            out[section][id] = item
        else
            return fail('Operação inválida.')
        end
    end
    local saved, err = catalog.save(out)
    if not saved then return fail(err) end
    sessions = {}
    TriggerClientEvent(prefix .. 'changed', -1)
    return ok(snapshot())
end, 700)

register('uploadPermit', function(src)
    if not admin(src) then return fail('Sem permissão administrativa.') end
    local now = GetGameTimer()
    if uploads[src] and uploads[src].expires > now then return fail('Já há um envio em andamento.') end
    counter = counter + 1
    local upload = { ticket = counter, expires = now + 55000, who = identifier(src), chunks = {}, size = 0 }
    uploads[src] = upload
    SetTimeout(55000, function() if uploads[src] == upload then uploads[src] = nil end end)
    return ok(counter)
end, 2000)

RegisterNetEvent(prefix .. 'upload', function(ticket, index, total, chunk)
    local src = source
    local request = uploads[src]
    if not request or request.ticket ~= ticket then return end
    local function finish(result)
        uploads[src] = nil
        TriggerClientEvent(prefix .. 'uploadResult', src, ticket, result)
    end
    if request.expires < GetGameTimer() or not admin(src) or request.who ~= identifier(src) then
        finish(fail('Envio não autorizado ou expirado.')); return
    end
    if not S.number(total, 1, math.ceil(maxEncoded / chunkSize)) or total % 1 ~= 0 or
        index ~= #request.chunks + 1 or index > total or (request.total and request.total ~= total) or
        type(chunk) ~= 'string' or #chunk == 0 or #chunk > chunkSize or request.size + #chunk > maxEncoded then
        finish(fail('Transferência inválida.')); return
    end
    request.total, request.size = total, request.size + #chunk
    request.chunks[index] = chunk
    if index < total then TriggerClientEvent(prefix .. 'uploadAck', src, ticket, index); return end
    local uri = table.concat(request.chunks)
    local good, media, err = pcall(C.media.save, src, uri, false)
    finish(good and media and ok(media) or fail(good and err or 'Falha ao processar o arquivo.'))
end)

register('capture', function(src)
    if not admin(src) then return fail('Sem permissão administrativa.') end
    if captures[src] then return fail('Já existe uma captura em andamento.') end
    if GetResourceState(C.captureResource) ~= 'started' then return fail('O screencapture precisa estar iniciado.') end
    local request, pending = { who = identifier(src) }, promise.new()
    captures[src] = request
    local function done(result)
        if captures[src] ~= request then return end
        captures[src] = nil
        pending:resolve(result)
    end
    request.done = done
    SetTimeout(12000, function() done(fail('A captura não respondeu. Tente novamente.')) end)
    local called = pcall(function()
        exports[C.captureResource]:serverCapture(src, { encoding = 'png', maxWidth = 1280, maxHeight = 720 }, function(data)
            if captures[src] ~= request then return end
            if not admin(src) or request.who ~= identifier(src) then done(fail('Captura cancelada.')); return end
            local good, media, err = pcall(C.media.save, src, data, true)
            done(good and media and ok(media) or fail(good and err or 'Falha ao processar a captura.'))
        end, 'base64')
    end)
    if not called then done(fail('Não foi possível iniciar a captura.')) end
    return Citizen.Await(pending)
end, 4000)

local function canReadMedia(src, request)
    if request.admin == true and admin(src) then return true end
    local item = entry(src, request, true)
    return item and item.media and item.media.file == request.file
end

local function mediaPart(src, job, index)
    local size = C.mediaReadChunk
    local chunk = job.data:sub((index - 1) * size + 1, index * size)
    local last = index == job.total
    if last then downloads[src] = nil else job.next = index + 1 end
    return ok({ ticket = job.ticket, index = index, total = job.total, chunk = chunk })
end

register('media', function(src, request)
    if not S.mediaName(request.file) or not canReadMedia(src, request) then return fail('Mídia indisponível.') end
    local data = C.media.load(request.file)
    if not data then return fail('Arquivo de mídia indisponível.') end
    counter = counter + 1
    local ticket = counter
    local job = { ticket = ticket, data = data, total = math.ceil(#data / C.mediaReadChunk), request = request }
    downloads[src] = job
    SetTimeout(120000, function()
        if downloads[src] and downloads[src].ticket == ticket then downloads[src] = nil end
    end)
    return mediaPart(src, job, 1)
end, 150)

register('mediaPart', function(src, request)
    local job = downloads[src]
    if not job or request.ticket ~= job.ticket or request.index ~= job.next then return fail('Transferência de mídia inválida.') end
    if not canReadMedia(src, job.request) then
        downloads[src] = nil
        return fail('O acesso à mídia foi encerrado.')
    end
    return mediaPart(src, job, request.index)
end, 45)

register('mediaClose', function(src, request)
    local job = downloads[src]
    if job and job.ticket == request.ticket then downloads[src] = nil end
    return ok(true)
end, 30)

RegisterNetEvent(prefix .. 'close', function(token)
    if sessions[source] and sessions[source].token == token then sessions[source] = nil end
end)
AddEventHandler('playerDropped', function()
    local src = source
    sessions[src], rate[src], uploads[src], downloads[src] = nil, nil, nil, nil
    if captures[src] then captures[src].done(fail('Jogador desconectado.')) end
end)

