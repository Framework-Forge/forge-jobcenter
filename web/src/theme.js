export const defaults = Object.freeze({
  brand:'Forge Project', name:'Job Center', accent:'#ff7a1a', surface:'#0e0e11',
  card:'#17171c', banner:'#221916', border:'#2b2b34', text:'#f6f4f2', muted:'#aaa7b3', columns:3,
});
export const colors = [
  ['accent', 'Destaque'], ['surface', 'Fundo da página'], ['card', 'Cards'],
  ['banner', 'Banner'], ['border', 'Bordas'], ['text', 'Texto principal'], ['muted', 'Texto secundário'],
];
export function effectiveTheme(value) {
  const result = {...defaults};
  for (const [key] of colors) if (/^#[0-9a-f]{6}$/i.test(value?.[key] || '')) result[key] = value[key];
  for (const key of ['brand', 'name']) if (typeof value?.[key] === 'string') result[key] = value[key].trim() || defaults[key];
  if ([2,3,4].includes(value?.columns)) result.columns = value.columns;
  return result;
}
function foreground(hex) {
  const luminance = [0.2126,0.7152,0.0722].reduce((sum, weight, index) => {
    const s = parseInt(hex.slice(1 + index * 2, 3 + index * 2), 16) / 255;
    return sum + weight * (s <= 0.04045 ? s / 12.92 : ((s + 0.055) / 1.055) ** 2.4);
  }, 0);
  return luminance > 0.179 ? '#101013' : '#ffffff';
}
export function themeStyle(value) {
  const theme = effectiveTheme(value);
  const style = colors.map(([key]) => '--' + key + ':' + theme[key]);
  style.push('--deep:' + theme.surface, '--accent-hover:' + theme.accent, '--on-accent:' + foreground(theme.accent),
    '--accent-line:' + theme.accent + '80', '--accent-soft:' + theme.accent + '22', '--columns:' + theme.columns);
  return style.join(';');
}
export function catalogMode(npc) {
  return npc.catalogMode || (npc.links?.length ? 'selected' : 'all');
}

export function catalogEntries(npc, entries) {
  const links = npc.links || [];
  return (catalogMode(npc) === 'all'
    ? Object.values(entries || {}).sort((a,b) => a.title.localeCompare(b.title, 'pt-BR'))
    : links.map(id => entries?.[id]))
    .filter(item => item?.enabled);
}
