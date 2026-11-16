local C = JobCenter
local S = {}
C.schema = S

function S.text(value, max, optional)
    if type(value) ~= 'string' or #value > max or value:find('%z') or not utf8.len(value) then return nil end
    value = value:gsub('^%s+', ''):gsub('%s+$', '')
    if value == '' and not optional then return nil end
    return value
end

function S.number(n, low, high)
    return type(n) == 'number' and n == n and n >= low and n <= high and n or nil
end

function S.theme(value)
    if value ~= nil and type(value) ~= 'table' then return nil end
    value = value or {}
    local out = {}
    for key, default in pairs(C.theme) do
        local entry = value[key]
        if entry == nil then entry = default end
        if key == 'brand' or key == 'name' then
            entry = S.text(entry, 64)
        elseif key == 'columns' then
            entry = S.number(entry, 2, 4)
            if entry and entry % 1 ~= 0 then entry = nil end
        else
            entry = type(entry) == 'string' and entry:match('^#%x%x%x%x%x%x$') and entry:lower() or nil
        end
        if not entry then return nil end
        out[key] = entry
    end
    return out
end

function S.coords(value, heading)
    if type(value) ~= 'table' then return nil end
    local x, y, z = S.number(value.x, -15000, 15000), S.number(value.y, -15000, 15000), S.number(value.z, -1000, 4000)
    if not x or not y or not z then return nil end
    local result = { x = x, y = y, z = z }
    if heading then
        local h = S.number(value.w, -360, 360)
        if not h then return nil end
        result.w = h % 360
    end
    return result
end

function S.id(id)
    return type(id) == 'string' and #id <= 32 and id:match('^[a-z]+%-%d+$') and id or nil
end

function S.model(value)
    return type(value) == 'string' and #value <= 64 and value:match('^[%w_]+$') and value or nil
end

function S.mediaName(value)
    if type(value) ~= 'string' or #value > 80 then return nil end
    local ext = value:match('^m%-%d+%-%d+%-%d+%.([a-z0-9]+)$')
    return (ext == 'png' or ext == 'jpg' or ext == 'webp' or ext == 'mp4' or ext == 'webm') and ext or nil
end

function S.url(value)
    if type(value) ~= 'string' or #value > 1800 or value:find('[%s%c\\]') then return nil end
    local host = value:match('^https://([%w%.%-]+)[/%?#]') or value:match('^https://([%w%.%-]+)$')
    if not host then return nil end
    host = host:lower()
    if not host:match('%.[a-z][a-z]+$') or host:match('%.local$') or host:match('%.localhost$') or host:find('..', 1, true) then return nil end
    if next(C.mediaHosts) and not C.mediaHosts[host] then return nil end
    return value
end

function S.media(value)
    if value == nil then return nil, true end
    if type(value) ~= 'table' or (value.kind ~= 'image' and value.kind ~= 'video') then return nil, false end
    local ext = S.mediaName(value.file)
    if ext then
        local video = ext == 'mp4' or ext == 'webm'
        if video ~= (value.kind == 'video') then return nil, false end
        return { kind = value.kind, file = value.file }, true
    end
    local url = S.url(value.url)
    if not url then return nil, false end
    return { kind = value.kind, url = url }, true
end

function S.record(section, id, value, state)
    if not C.catalogLimits[section] or not S.id(id) or type(value) ~= 'table' then return nil, 'Cadastro inválido.' end
    local title = S.text(value.title, 96)
    if not title or type(value.enabled) ~= 'boolean' then return nil, 'Informe um título válido e o estado do cadastro.' end
    local out = { id = id, title = title, enabled = value.enabled }
    if section == 'npcs' then
        if value.mode ~= 'legal' and value.mode ~= 'illegal' then return nil, 'Escolha o tipo de atendimento.' end
        local coords, model, intro = S.coords(value.coords, true), S.model(value.model), S.text(value.intro, 1200)
        local label = S.text(value.label, 64)
        local bucket = S.number(value.bucket, 0, 65535)
        if not coords or not model or not intro or not label or not bucket or bucket % 1 ~= 0 then
            return nil, 'Confira modelo, posição, dimensão, texto inicial e rótulo da interação.'
        end
        out.coords, out.model, out.intro, out.label, out.mode, out.bucket = coords, model, intro, label, value.mode, bucket
        out.links = {}
        if type(value.links) ~= 'table' then return nil, 'Seleção de conteúdo inválida.' end
        local entries = state[value.mode == 'legal' and 'jobs' or 'topics']
        local seen = {}
        for index, linked in pairs(value.links) do
            if not S.number(index, 1, 120) or index % 1 ~= 0 or not S.id(linked) or not entries[linked] or seen[linked] then
                return nil, 'A seleção contém conteúdo inexistente ou duplicado.'
            end
            seen[linked] = true
        end
        for _, linked in ipairs(value.links) do out.links[#out.links + 1] = linked end
        for linked in pairs(seen) do
            local found = false
            for _, ref in ipairs(out.links) do if ref == linked then found = true; break end end
            if not found then return nil, 'Seleção de conteúdo incompleta.' end
        end
        if value.catalogMode ~= nil and value.catalogMode ~= 'all' and value.catalogMode ~= 'selected' then
            return nil, 'Modo de catálogo inválido.'
        end
        out.catalogMode = value.catalogMode or (#out.links > 0 and 'selected' or 'all')
    else
        out.details = S.text(value.details, 6400)
        if not out.details then return nil, 'Escreva o detalhamento ou a resposta do contato.' end
        if value.route ~= nil then
            out.route = S.coords(value.route)
            if not out.route then return nil, 'Confira as coordenadas do destino.' end
        end
        if section == 'jobs' then
            out.summary = S.text(value.summary, 280)
            if not out.summary then return nil, 'Escreva um resumo para o card.' end
            local valid
            out.media, valid = S.media(value.media)
            if not valid then return nil, 'Mídia inválida. Use arquivo suportado ou URL direta HTTPS.' end
        end
    end
    return out
end
