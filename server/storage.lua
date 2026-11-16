local resource = GetCurrentResourceName()
JobCenter.storage = {}

-- Alternating JSON files retain one known-good revision if a write is interrupted.
function JobCenter.storage.open(name, initial, validate, limit)
    local function path(revision)
        return ('data/%s-%s.json'):format(name, revision % 2 == 0 and 'a' or 'b')
    end
    local function read(slot)
        local raw = LoadResourceFile(resource, path(slot))
        if not raw then return nil, false end
        if #raw > limit then return nil, true end
        local ok, obj = pcall(json.decode, raw)
        if not ok or type(obj) ~= 'table' or obj.version ~= 1
            or not JobCenter.schema.number(obj.revision, 0, 2147483646) or obj.revision % 1 ~= 0
            or obj.revision % 2 ~= slot then return nil, true end
        local valid, data = pcall(validate, obj.data)
        if valid and data then return { revision = obj.revision, data = data }, true end
        return nil, true
    end
    local a, presentA = read(0)
    local b, presentB = read(1)
    local current = a and b and (a.revision > b.revision and a or b) or a or b
    local writable = current ~= nil or not (presentA or presentB)
    if not current and not writable then print('[forge-jobcenter] JSON inválido: ' .. name .. ' bloqueado até recuperação.') end
    current = current or { revision = 0, data = initial }
    local store = {}
    function store.get() return current.data, current.revision end
    function store.save(data)
        if not writable then return false, 'Dados inválidos em disco. Restaure o JSON antes de gravar.' end
        local revision = current.revision + 1
        if revision > 2147483646 then return false, 'Limite de revisões atingido.' end
        local ok, encoded = pcall(json.encode, { version = 1, revision = revision, data = data })
        if not ok or type(encoded) ~= 'string' or #encoded > limit then return false, 'Limite de armazenamento atingido.' end
        local success, result = pcall(SaveResourceFile, resource, path(revision), encoded, #encoded)
        if not success or not result then return false, 'Não foi possível gravar os dados.' end
        current = { revision = revision, data = data }
        return true, revision
    end
    return store
end
