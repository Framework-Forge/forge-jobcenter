<script>
  import { untrack } from 'svelte';
  import Icon from './Icon.svelte';
  import Media from './Media.svelte';
  import Legal from './Legal.svelte';
  import { colors, defaults as defaultTheme, effectiveTheme, catalogMode, catalogEntries } from './theme.js';
  import { request, fileAsData } from './api.js';

  let { initial, onPreview, onClose, attachPlacement } = $props();
  const tabs = [
    { key: 'general', label: 'Geral', icon: 'settings' },
    { key: 'npcs', label: 'NPCs e páginas', icon: 'location' },
    { key: 'jobs', label: 'Empregos legais', icon: 'case' },
    { key: 'topics', label: 'Diálogos ilegais', icon: 'chat' },
  ];
  const copy = value => JSON.parse(JSON.stringify(value));
  const sorted = section => Object.values(section || {}).sort((a,b)=>a.title.localeCompare(b.title, 'pt-BR'));
  const first = untrack(() => copy(initial));
  first.state.general.theme = effectiveTheme(first.state.general.theme);
  let server = $state(first), mode = $state('general'), id = $state(null);
  let draft = $state(copy(first.state.general)), original = $state(JSON.stringify(first.state.general));
  let message = $state(''), error = $state(false), busy = $state(false), placing = $state(false);
  let confirm = $state(null), mediaKind = $state('image'), url = $state('');
  let liveDetail = $state(null);
  const rows = $derived(mode === 'general' ? [] : sorted(server.state[mode]));
  const dirty = $derived(JSON.stringify(draft) !== original);
  const disabled = $derived(busy || placing || !!confirm);
  const options = $derived(mode === 'npcs' ? sorted(server.state[draft.mode === 'legal' ? 'jobs' : 'topics']) : []);
  const livePage = $derived({
    title: 'Central de empregos', intro: 'Encontre novas oportunidades na sua cidade.',
    theme: draft.theme, items: (sorted(server.state.jobs).filter(item => item.enabled).slice(0, 4)).map(item => ({
      ...item, route: !!item.route,
    })),
  });
  const sample = { id:'sample', title:'Entrega na cidade', summary:'Faça entregas pelos bairros e conheça novas rotas.',
    details:'Exemplo de detalhamento de um emprego. Os jogadores só veem os cards publicados.', route:true, rating:{up:12,down:2} };
  const liveScreen = $derived(livePage.items.length ? livePage : {...livePage, items:[sample, {
    ...sample, id:'sample-2', title:'Serviços locais', summary:'Ajude nas atividades essenciais da cidade.', rating:{up:8,down:1},
  }]});
  const model = 's_m_m_highsec_01';

  function start(section, item = null) {
    mode = section;
    id = item?.id || null;
    liveDetail = null;
    draft = item ? copy(item) : section === 'general' ? copy(server.state.general) : section === 'npcs'
      ? { title:'Central de empregos', label:'Conversar', intro:'Encontre uma oportunidade na cidade.', mode:'legal', catalogMode:'all', enabled:true, model, coords:{}, links:[], bucket:0 }
      : { title:'', enabled:true, details:'', ...(section === 'jobs' ? { summary:'' } : {}) };
    if (section === 'general') draft.theme = effectiveTheme(draft.theme);
    original = JSON.stringify(draft);
    mediaKind = draft.media?.kind || 'image';
    url = draft.media?.url || '';
    message = ''; error = false;
  }
  function guard(action, label = 'Descartar alterações não salvas?') {
    if (disabled) return;
    if (dirty || url !== (draft.media?.url || '')) confirm = { label, action, button:'Descartar' };
    else action();
  }
  function report(value, failed = false) { message = value; error = failed; }
  function routeToggle(event) {
    if (event.currentTarget.checked) draft.route = {};
    else delete draft.route;
  }
  function applyPlacement(coords) {
    placing = false;
    if (coords) { draft.coords = coords; report('Posição atualizada no rascunho. Salve para publicar.'); }
    else report('Posicionamento cancelado.');
  }
  $effect(() => { attachPlacement(applyPlacement); });

  async function usePosition(which) {
    busy = true;
    const result = await request('coords');
    busy = false;
    if (!result.ok) return report(result.error, true);
    const p = result.data;
    const round = v => Math.round(v * 100) / 100;
    if (which === 'route') draft.route = { x:round(p.x), y:round(p.y), z:round(p.z) };
    else draft.coords = { x:round(p.x), y:round(p.y), z:round(p.z), w:round(p.w) };
  }
  async function startPlacement() {
    placing = true;
    const result = await request('place', { model:draft.model, heading:draft.coords.w || 0 }, 12000);
    if (!result.ok) { placing = false; report(result.error, true); }
  }
  function assignUrl() {
    try {
      const value = new URL(url);
      if (value.protocol !== 'https:' || value.username || value.password || value.port) throw Error();
      draft.media = { kind:mediaKind, url:url.trim() };
      url = draft.media.url;
      report('URL vinculada ao rascunho.');
    } catch { report('Use um link direto HTTPS para a imagem ou o vídeo.', true); }
  }
  async function attachFile(event) {
    const file = event.currentTarget.files?.[0];
    event.currentTarget.value = '';
    if (!file) return;
    const isVideo = ['video/webm','video/mp4'].includes(file.type);
    if (!isVideo && !['image/png','image/jpeg','image/webp'].includes(file.type))
      return report('Selecione PNG, JPEG, WebP, WebM ou MP4.', true);
    if (file.size > (isVideo ? server.limits.video : server.limits.image))
      return report(isVideo ? 'O vídeo passa de 12 MB.' : 'A imagem passa de 2 MB.', true);
    busy = true; report('Enviando arquivo…');
    try {
      const result = await request('upload', { uri:await fileAsData(file) }, 61000);
      if (!result.ok) return report(result.error, true);
      draft.media = result.data; url = ''; mediaKind = result.data.kind;
      report('Arquivo salvo. Publique o cadastro para usar esta mídia.');
    } catch { report('Não foi possível ler o arquivo.', true); }
    finally { busy = false; }
  }
  async function capture() {
    busy = true;
    const result = await request('capture', {}, 17000);
    busy = false;
    if (!result.ok) return report(result.error, true);
    draft.media = result.data; url = ''; mediaKind = 'image';
    report('Screenshot salvo. Publique o cadastro para usar esta imagem.');
  }
  async function save(op = 'save') {
    if (url !== (draft.media?.url || '') && op === 'save') return report('Vincule ou limpe a URL antes de salvar.', true);
    busy = true; report('Salvando…');
    if (mode === 'npcs' && op === 'save') {
      const result = await request('model', { model:draft.model });
      if (!result.ok) { busy = false; return report(result.error, true); }
    }
    const response = await request('edit', { section:mode, revision:server.revision, id, op, value:copy(draft) }, 10000);
    busy = false;
    if (!response.ok) return report(response.error, true);
    server = response.data;
    const newId = id || (mode + '-' + server.state.sequence);
    start(mode, op === 'delete' || mode === 'general' ? null : server.state[mode][newId]);
    report(op === 'delete' ? 'Cadastro excluído.' : 'Alterações publicadas.');
  }
  async function reload() {
    busy = true;
    const response = await request('admin');
    busy = false;
    if (!response.ok) return report(response.error, true);
    server = response.data;
    start(mode, id && server.state[mode]?.[id]);
    report('Dados recarregados.');
  }
  function preview() {
    let page = draft;
    let entries;
    if (mode === 'npcs') {
      const source = server.state[draft.mode === 'legal' ? 'jobs' : 'topics'];
      entries = catalogEntries(draft, source);
    } else {
      page = mode === 'jobs' ? { mode:'legal', title:'Central de empregos', intro:'Prévia do catálogo legal.' }
        : { mode:'illegal', title:'Contato', intro:'O que você está procurando?' };
      entries = [draft];
    }
    onPreview(copy({ mode:page.mode, title:page.title, intro:page.intro, theme:server.state.general.theme, items:entries.map((entry,i) => ({
      ...entry, id:entry.id || 'preview-' + i, rating:{ up:0, down:0, vote:0 }, route:!!entry.route,
    })) }));
  }
  export function exit() { guard(onClose); }
</script>

<div class="admin-layout">
  <aside class="admin-nav">
    <p class="eyebrow">GERENCIAMENTO</p>
    <nav aria-label="Seções administrativas">
      {#each tabs as tab}
        <button class:active={mode===tab.key} aria-current={mode===tab.key?'page':undefined} disabled={disabled} onclick={() => guard(() => start(tab.key))}>
          <Icon name={tab.icon}/> {tab.label}
        </button>
      {/each}
    </nav>
    <div class="nav-end"><small>Revisão {server.revision} · JSON</small><button class="secondary" disabled={disabled} onclick={() => guard(reload)}>Recarregar dados</button></div>
  </aside>
  {#if mode !== 'general'}
    <aside class="admin-list">
      <div class="row spread"><strong>{rows.length} {rows.length === 1 ? 'cadastro' : 'cadastros'}</strong></div>
      <button class="secondary create" disabled={disabled} onclick={() => guard(() => start(mode))}><Icon name="plus"/> Novo cadastro</button>
      {#each rows as item (item.id)}
        <button class="list-item" class:active={id===item.id} disabled={disabled} onclick={() => guard(() => start(mode,item))}>
          <strong>{item.title}</strong><small>{mode==='npcs' ? (item.mode==='legal'?'Legal':'Ilegal') + ' · ' : ''}{item.enabled?'Ativo':'Desativado'}</small>
        </button>
      {:else}<p class="muted">Nenhum cadastro nesta seção.</p>{/each}
    </aside>
  {/if}
  <section class="editor">
    <form onsubmit={event => { event.preventDefault(); save(); }}>
      <div class="row spread editor-head"><div><p class="eyebrow">{id || 'ADMINISTRAÇÃO'}</p><h2>{mode==='general'?'Configurações gerais':id?'Editar cadastro':'Novo cadastro'}</h2></div>
        {#if mode !== 'general'}<button type="button" class="secondary" disabled={disabled} onclick={preview}>Pré-visualizar</button>{/if}
      </div>
      <fieldset disabled={disabled}>
        {#if mode === 'general'}
          <p class="support">Escolha como os jogadores abordam os NPCs. A alteração vale para todos os pontos publicados.</p>
          <div class="fields two">
            <label>Interação<select bind:value={draft.interaction}><option value="interact">Interact · PR Bridge</option><option value="target">Target · PR Bridge</option></select></label>
            <label>Distância de interação (m)<input type="number" min="1.25" max="4" step="0.05" required bind:value={draft.distance}/></label>
          </div>
          <div class="row spread theme-heading">
            <div><h3>Layout da página legal</h3><p class="support">Ajuste a identidade da cidade. A prévia abaixo muda na hora.</p></div>
            <button type="button" class="secondary" onclick={() => { draft.theme = effectiveTheme(server.defaultTheme || defaultTheme); }}>Restaurar padrão</button>
          </div>
          <div class="fields theme-fields">
            <label>Identidade da cidade<input required maxlength="64" bind:value={draft.theme.brand}/></label>
            <label>Nome da central<input required maxlength="64" bind:value={draft.theme.name}/></label>
            <label>Máximo de cards por linha<select bind:value={draft.theme.columns}><option value={2}>2 cards</option><option value={3}>3 cards</option><option value={4}>4 cards</option></select></label>
          </div>
          <div class="theme-colors">
            {#each colors as [key, label]}
              <div class="color-field">
                <label>{label}<input aria-label={label + ' em hexadecimal'} type="text" required pattern={'#[0-9a-fA-F]{6}'} maxlength="7" bind:value={draft.theme[key]}/></label>
                <input type="color" aria-label={'Cor: ' + label} value={effectiveTheme(draft.theme)[key]} oninput={e => { draft.theme[key] = e.currentTarget.value; }}/>
              </div>
            {/each}
          </div>
        {:else}
          <div class="fields two">
            <label>{mode==='npcs'?'Título da página ou nome do contato':mode==='topics'?'Opção da conversa':'Título do emprego'}<input required maxlength="96" bind:value={draft.title}/></label>
            <label class="check"><input type="checkbox" bind:checked={draft.enabled}/> Disponível para jogadores</label>
          </div>
          {#if mode === 'npcs'}
            <div class="fields two">
              <label>Tipo<select value={draft.mode} onchange={e => { const previous = draft.mode; draft.mode=e.currentTarget.value; draft.links=[]; if (!id && previous!==draft.mode) { draft.title=draft.mode==='legal'?'Central de empregos':'Contato'; draft.intro=draft.mode==='legal'?'Encontre uma oportunidade na cidade.':'Fala, irmão. O que você procura?'; } }}>
                <option value="legal">Legal · página de empregos</option><option value="illegal">Ilegal · diálogo discreto</option>
              </select></label>
              <label>Rótulo da interação<input required maxlength="64" bind:value={draft.label}/></label>
              <label>Modelo do NPC<input required maxlength="64" bind:value={draft.model}/></label>
              <label>Dimensão (routing bucket)<input required type="number" min="0" max="65535" bind:value={draft.bucket}/></label>
            </div>
            <label>{draft.mode==='legal'?'Introdução da página':'Texto de abertura do contato'}<textarea required maxlength="1200" rows="3" bind:value={draft.intro}></textarea></label>
            <h3>Posição do NPC</h3>
            <div class="fields coordinate">
              {#each [['x','X'],['y','Y'],['z','Z'],['w','Direção']] as [axis, label]}
                <label>{label}<input required type="number" step="any" bind:value={draft.coords[axis]}/></label>
              {/each}
            </div>
            <div class="row wrap"><button type="button" class="secondary" onclick={() => usePosition('npc')}><Icon name="location"/> Minha posição</button>
              <button type="button" class="secondary" onclick={startPlacement}><Icon name="beacon"/> Posicionar com laser</button></div>
            <h3>{draft.mode==='legal'?'Cards desta página':'Opções deste contato'}</h3>
            <label>Catálogo do NPC<select value={catalogMode(draft)} onchange={e => { draft.catalogMode = e.currentTarget.value; }}>
              <option value="all">{draft.mode === 'legal' ? 'Todos os empregos ativos' : 'Todos os diálogos ativos'}</option>
              <option value="selected">Somente os selecionados</option>
            </select></label>
            {#if catalogMode(draft) === 'selected'}
            <p class="support">Marque o que este NPC apresenta. Outros NPCs podem usar uma seleção diferente.</p>
            <div class="checklist">
              {#each options as item}
                <label class="check"><input type="checkbox" checked={draft.links.includes(item.id)} onchange={e => { draft.links = e.currentTarget.checked ? [...draft.links,item.id] : draft.links.filter(link=>link!==item.id); }}/>
                  <span>{item.title}{item.enabled?'':' · desativado'}</span>
                </label>
              {:else}<p class="muted">Crie itens no catálogo correspondente e volte para vinculá-los.</p>{/each}
            </div>
            {:else}
              <p class="support">Este NPC mostra todos os {draft.mode === 'legal' ? 'empregos' : 'diálogos'} ativos, inclusive os que forem criados depois.</p>
            {/if}
          {:else}
            {#if mode === 'jobs'}<label>Resumo do card<textarea required maxlength="280" rows="2" bind:value={draft.summary}></textarea></label>{/if}
            <label>{mode==='jobs'?'Detalhamento do emprego':'Resposta ou dica do contato'}<textarea required maxlength="6400" rows="5" bind:value={draft.details}></textarea></label>
            <h3>Destino</h3>
            <label class="check"><input type="checkbox" checked={!!draft.route} onchange={routeToggle}/> Permitir marcar rota no GPS</label>
            {#if draft.route}
              <div class="fields coordinate">
                {#each ['x','y','z'] as axis}<label>{axis.toUpperCase()}<input required type="number" step="any" bind:value={draft.route[axis]}/></label>{/each}
              </div>
              <button type="button" class="secondary" onclick={() => usePosition('route')}><Icon name="location"/> Usar minha posição como destino</button>
            {/if}
            {#if mode === 'jobs'}
              <h3>Mídia do emprego</h3>
              <p class="support">Imagem até 2 MB ou vídeo até 12 MB. A URL deve apontar para o arquivo, não para uma página do YouTube.</p>
              <div class="row wrap">
                <label class="secondary file-button"><Icon name="image"/> Importar arquivo<input type="file" accept="image/png,image/jpeg,image/webp,video/mp4,video/webm" onchange={attachFile}/></label>
                <button type="button" class="secondary" disabled={!server.capture} onclick={capture}><Icon name="camera"/> Tirar screenshot</button>
                {#if !server.capture}<small>screencapture não iniciado</small>{/if}
              </div>
              <div class="fields url-row">
                <label>Formato da URL<select bind:value={mediaKind}><option value="image">Imagem</option><option value="video">Vídeo</option></select></label>
                <label>URL direta<input type="text" maxlength="1800" placeholder="https://…" bind:value={url}/></label>
                <button type="button" class="secondary" onclick={assignUrl}>Vincular URL</button>
              </div>
              {#if draft.media}
                <div class="row spread media-note"><small>{draft.media.file || 'URL vinculada'}</small>
                  <button type="button" class="secondary" onclick={() => {delete draft.media; url='';}}>Desvincular mídia</button></div>
                <Media item={draft} detail/>
              {/if}
            {/if}
          {/if}
        {/if}
      </fieldset>
      <div class="savebar">
        <button class="primary" type="submit" disabled={disabled || !dirty}>{busy?'Aguarde…':'Salvar e publicar'}</button>
        {#if id}<button class="danger" type="button" disabled={disabled} onclick={() => confirm={label:'Excluir “'+draft.title+'”? O item sairá dos NPCs vinculados.',action:()=>save('delete'),button:'Excluir cadastro'}}>Excluir</button>{/if}
        <span class="muted">{dirty?'Rascunho não publicado':'Sem alterações pendentes'}</span>
      </div>
      {#if message}<p class:error role="status">{message}</p>{/if}
    </form>
    {#if mode === 'general'}
      <section class="theme-demo" aria-label="Prévia ao vivo do Job Center">
        <div class="row spread theme-demo-heading"><h3>Prévia ao vivo</h3><small>Só publica depois de salvar</small></div>
        <Legal active={liveScreen} detail={liveDetail} preview embedded select={item => liveDetail = item} back={() => liveDetail = null}/>
      </section>
    {/if}
  </section>
</div>
{#if confirm}
  <div class="confirm-shade"><div class="confirm-box" role="alertdialog" aria-label="Confirmar operação">
    <h2>{confirm.label}</h2>
    <div class="row wrap"><button class="secondary" onclick={() => confirm=null}>Cancelar</button>
      <button class="danger" onclick={() => {const run=confirm.action;confirm=null;run();}}>{confirm.button}</button></div>
  </div></div>
{/if}
