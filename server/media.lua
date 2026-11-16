local C, resource = JobCenter, GetCurrentResourceName()
local S = C.schema
local alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local enc = {}
for i = 1, #alphabet do enc[alphabet:byte(i)] = i - 1 end
local mime = { png = 'image/png', jpg = 'image/jpeg', webp = 'image/webp', mp4 = 'video/mp4', webm = 'video/webm' }
local extensions = {}
for ext, kind in pairs(mime) do extensions[kind] = ext end
local cache, serial = {}, 0
local M = {}
C.media = M

local function decode(input)
    if #input % 4 ~= 0 or input:find('[^A-Za-z0-9+/=]') then return nil end
    local body, padding = input:match('^([^=]*)(=*)$')
    if not body or #padding > 2 then return nil end
    -- Store at most one table entry per 12 KiB of output.
    local blocks, chunk, n = {}, {}, 0
    for i = 1, #body, 4 do
        local a, b, c, d = input:byte(i, i + 3)
        if not enc[a] or not enc[b] then return nil end
        local v = (enc[a] << 18) | (enc[b] << 12) | ((enc[c] or 0) << 6) | (enc[d] or 0)
        n = n + 1
        chunk[n] = enc[d] and string.char(v >> 16, (v >> 8) & 255, v & 255)
            or enc[c] and string.char(v >> 16, (v >> 8) & 255) or string.char(v >> 16)
        if n == 4096 then blocks[#blocks+1] = table.concat(chunk); chunk, n = {}, 0 end
    end
    blocks[#blocks+1] = table.concat(chunk)
    return table.concat(blocks)
end

local function encode(raw)
    local blocks, chunk, n = {}, {}, 0
    for i = 1, #raw, 3 do
        local a, b, c = raw:byte(i, i + 2)
        local v = (a << 16) | ((b or 0) << 8) | (c or 0)
        local p, q, r, s = (v >> 18) + 1, ((v >> 12) & 63) + 1, ((v >> 6) & 63) + 1, (v & 63) + 1
        n = n + 1
        chunk[n] = alphabet:sub(p,p) .. alphabet:sub(q,q) .. (b and alphabet:sub(r,r) or '=') .. (c and alphabet:sub(s,s) or '=')
        if n == 4096 then blocks[#blocks+1] = table.concat(chunk); chunk, n = {}, 0 end
    end
    blocks[#blocks+1] = table.concat(chunk)
    return table.concat(blocks)
end

local function signature(ext, bytes)
    return (ext == 'png' and bytes:sub(1, 8) == '\137PNG\r\n\26\n' and bytes:sub(13,16) == 'IHDR')
        or (ext == 'jpg' and bytes:sub(1, 3) == '\255\216\255')
        or (ext == 'webp' and bytes:sub(1,4) == 'RIFF' and bytes:sub(9,12) == 'WEBP')
        or (ext == 'webm' and bytes:sub(1,4) == '\26\69\223\163' and bytes:sub(1,256):find('webm',1,true) ~= nil)
        or (ext == 'mp4' and bytes:sub(5,8) == 'ftyp')
end

local function remember(file, data)
    -- One retained transfer avoids re-encoding an image requested by several users.
    cache = { file = file, data = data }
end

function M.save(src, data, imageOnly)
    if type(data) ~= 'string' or #data > math.ceil(C.maxVideo / 3) * 4 + 48 then return nil, 'Arquivo acima do limite.' end
    local kind, offset = data:match('^data:([%w/]+);base64,()')
    local ext = extensions[kind]
    if not ext or not offset then return nil, 'Formato de mídia não aceito.' end
    local video = ext == 'webm' or ext == 'mp4'
    if video and imageOnly then return nil, 'A captura deve retornar uma imagem.' end
    local limit = video and C.maxVideo or C.maxImage
    if #data - offset + 1 > math.ceil(limit / 3) * 4 then return nil, 'Arquivo acima do limite.' end
    local raw = decode(data:sub(offset))
    if not raw or #raw > limit or not signature(ext, raw) then return nil, 'Arquivo inválido ou formato incompatível.' end
    local file
    repeat
        serial = serial + 1
        file = ('m-%d-%d-%d.%s'):format(os.time(), src, serial, ext)
    until not LoadResourceFile(resource, 'media/' .. file)
    local ok, written = pcall(SaveResourceFile, resource, 'media/' .. file, raw, #raw)
    if not ok or not written then return nil, 'Não foi possível gravar na pasta media.' end
    remember(file, data)
    return { kind = video and 'video' or 'image', file = file }
end

function M.load(file)
    local ext = S.mediaName(file)
    if not ext then return nil end
    if cache.file == file then return cache.data end
    local raw = LoadResourceFile(resource, 'media/' .. file)
    local limit = (ext == 'webm' or ext == 'mp4') and C.maxVideo or C.maxImage
    if not raw or #raw > limit or not signature(ext, raw) then return nil end
    local data = 'data:' .. mime[ext] .. ';base64,' .. encode(raw)
    remember(file, data)
    return data
end
