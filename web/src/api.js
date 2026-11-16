export async function request(action, data = {}, timeout = 6000) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeout);
  try {
    const response = await fetch('https://' + window.GetParentResourceName() + '/' + action, {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data), signal: controller.signal,
    });
    if (!response.ok) throw new Error('NUI');
    return await response.json();
  } catch {
    return { ok: false, error: 'Sem resposta do jogo. Tente novamente.' };
  } finally { clearTimeout(timer); }
}

const cached = new Map();
const temporary = new Set();
let queue = Promise.resolve();
let generation = 0;
export function clearMedia() {
  generation++;
  for (const url of cached.values()) URL.revokeObjectURL(url);
  cached.clear();
  for (const url of temporary) URL.revokeObjectURL(url);
  temporary.clear();
}
export function releaseMedia(url) { if (temporary.delete(url)) URL.revokeObjectURL(url); }
function mediaBlob(data) {
  const comma = data.indexOf(',');
  if (comma < 1) throw new Error('Mídia inválida.');
  const type = data.slice(5, comma).replace(';base64', '');
  const decoded = atob(data.slice(comma + 1));
  const bytes = new Uint8Array(decoded.length);
  for (let i = 0; i < bytes.length; i++) bytes[i] = decoded.charCodeAt(i);
  return URL.createObjectURL(new Blob([bytes], { type }));
}
export function readMedia(id, file, active, onProgress) {
  const cycle = generation;
  const live = () => cycle === generation && active();
  const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
  const task = queue.then(async () => {
    if (!live()) return null;
    if (cached.has(file)) return cached.get(file);
    let transfer, complete = false;
    let url;
    try {
      const first = await request('media', { id, file });
      if (!first.ok) throw new Error(first.error || 'Mídia indisponível.');
      const part = first.data;
      transfer = part?.ticket;
      if (!Number.isInteger(transfer) || !Number.isInteger(part.total) || part.total < 1 ||
          part.total > 350 || part.index !== 1 || typeof part.chunk !== 'string') throw new Error('Resposta de mídia inválida.');
      const chunks = [part.chunk];
      onProgress(part.total === 1 ? 100 : Math.round(100 / part.total));
      const deadline = Date.now() + 110000;
      for (let index = 2; index <= part.total; index++) {
        await delay(55);
        if (!live()) return null;
        if (Date.now() > deadline) throw new Error('O arquivo demorou demais para carregar.');
        const result = await request('mediaPart', { ticket:transfer, index });
        if (!result.ok) throw new Error(result.error || 'A transferência de mídia falhou.');
        const next = result.data;
        if (next?.ticket !== transfer || next.index !== index || next.total !== part.total || typeof next.chunk !== 'string')
          throw new Error('Recebimento de mídia incompleto.');
        chunks.push(next.chunk);
        onProgress(Math.round(index * 100 / part.total));
      }
      complete = true;
      if (!live()) return null;
      url = mediaBlob(chunks.join(''));
    } finally {
      if (!complete && Number.isInteger(transfer)) request('mediaClose', { ticket:transfer });
      await delay(160);
    }
    if (!live()) { URL.revokeObjectURL(url); return null; }
    // Retain the handful of thumbnails/videos opened in the current NUI session.
    // Do not revoke an object URL still attached to a visible card.
    if (file.endsWith('.webm') || file.endsWith('.mp4')) temporary.add(url);
    else {
      if (cached.size >= 16) {
        const first = cached.keys().next().value;
        URL.revokeObjectURL(cached.get(first));
        cached.delete(first);
      }
      cached.set(file, url);
    }
    return url;
  });
  queue = task.then(() => undefined, () => undefined);
  return task;
}

export function fileAsData(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(reader.result);
    reader.onerror = reject;
    reader.readAsDataURL(file);
  });
}
