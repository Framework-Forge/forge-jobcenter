<script>
  import { onMount, tick } from 'svelte';
  import Icon from './Icon.svelte';
  import Admin from './Admin.svelte';
  import Conversation from './Conversation.svelte';
  import Legal from './Legal.svelte';
  import logo from './assets/forge-flame.png';
  import { request, clearMedia } from './api.js';
  let mode = $state(null), payload = $state(null), preview = $state(null), pending = $state(false), hidden = $state(false);
  let detail = $state(null), search = $state(''), message = $state(''), adminPanel = $state(), publicPanel = $state(), admin = $state();
  let transcript = $state([]);
  let placement;
  let generation = 0;
  const active = $derived(preview || payload);
  const screen = $derived(preview?.mode || mode);
  const panel = $derived(screen === 'admin' ? adminPanel : publicPanel);
  const rating = item => item.rating || { up:0, down:0, vote:0 };
  function focus() { tick().then(() => panel?.focus()); }
  function reset() { detail = null; search = ''; message = ''; transcript = []; pending = false; generation++; }
  function close() {
    if (mode) request('close');
    hide();
  }
  function hide() {
    mode = null; payload = null; preview = null; hidden = false; placement = null;
    reset(); clearMedia();
  }
  function back() {
    if (hidden || pending) return;
    if (detail) { detail = null; message = ''; focus(); return; }
    if (preview) { preview = null; reset(); focus(); return; }
    if (mode === 'admin') admin?.exit();
    else close();
  }
  function receive(event) {
    const { action, data } = event.data || {};
    if (action === 'open' && ['admin','legal','illegal'].includes(data?.mode)) {
      hide(); mode = data.mode; payload = data.payload; focus();
    } else if (action === 'close') hide();
    else if (action === 'suspend' && mode === 'admin') { hidden = !!data?.active; if (!hidden) focus(); }
    else if (action === 'placement' && mode === 'admin') {
      hidden = false; placement?.(data?.coords); focus();
    }
  }
  async function select(item) {
    if (pending) return;
    const conversation = screen === 'illegal';
    message = '';
    if (conversation) transcript.push({ fromPlayer:true, text:item.title });
    if (preview) {
      detail = item;
      if (conversation) transcript.push({ text:item.details });
      focus();
      return;
    }
    const version = generation;
    pending = true;
    const result = await request('detail', { id:item.id });
    if (version !== generation) return;
    pending = false;
    if (!result.ok) { message = result.error; return; }
    detail = result.data;
    if (conversation) transcript.push({ text:detail.details });
    focus();
  }
  async function choose(value) {
    if (pending || preview || !detail) return;
    const { id } = detail;
    const version = generation;
    pending = true; message = '';
    const result = await request('vote', { id, value:rating(detail).vote === value ? 0 : value });
    if (version !== generation) return;
    pending = false;
    if (!result.ok) { message = result.error; return; }
    detail.rating = result.data;
    const card = payload.items.find(item => item.id === id);
    if (card) card.rating = result.data;
  }
  async function route() {
    if (pending || preview || !detail) return;
    const version = generation;
    pending = true; message = '';
    const result = await request('route', { id:detail.id });
    if (version !== generation) return;
    pending = false;
    if (!result.ok) message = result.error;
    else hide();
  }
  function startPreview(data) { reset(); preview = data; focus(); }
  function keys(event) {
    if (!mode || hidden) return;
    if (event.key === 'Escape') {
      event.preventDefault();
      if (panel?.querySelector('.confirm-shade')) panel.querySelector('.confirm-shade .secondary')?.click();
      else back();
      return;
    }
    if (event.key === 'Tab' && panel) {
      const root = panel.querySelector('.confirm-box') || panel;
      const elements = [...root.querySelectorAll('button:not(:disabled),input:not(:disabled),select:not(:disabled),textarea:not(:disabled),video[controls]')].filter(el => el.getClientRects().length);
      if (!elements.length) return;
      if (!root.contains(document.activeElement) || (event.shiftKey && [root,elements[0]].includes(document.activeElement)) || (!event.shiftKey && document.activeElement === elements.at(-1))) {
        event.preventDefault();
        (event.shiftKey ? elements.at(-1) : elements[0]).focus();
      }
    }
  }
  onMount(() => {
    if (typeof window.GetParentResourceName === 'function') request('ready');
    return clearMedia;
  });
</script>

<svelte:window onmessage={receive} onkeydown={keys}/>

{#if mode && payload}
  {#if mode === 'admin'}
    <div class="stage" class:hidden={hidden || !!preview}>
      <div class="window admin-window" role="dialog" aria-modal="true" aria-label="Administração do Job Center" tabindex="-1" bind:this={adminPanel}>
        <header class="top"><div class="brand"><img src={logo} alt=""/><div><span>FORGE PROJECT</span><strong>Job Center</strong></div></div>
          <div class="row"><span class="badge">ADMINISTRAÇÃO</span><button class="icon-button" aria-label="Fechar administração" onclick={back}><Icon name="close" size={20}/></button></div></header>
        <Admin initial={payload} onClose={close} onPreview={startPreview} attachPlacement={fn => placement=fn} bind:this={admin}/>
      </div>
    </div>
  {/if}

  {#if screen === 'legal'}
    <div class="stage">
      <Legal {active} {detail} preview={!!preview} {pending} {message} {select} {choose} {route} {back} bind:element={publicPanel} bind:search/>
    </div>
  {:else if screen === 'illegal'}
    <Conversation {active} {detail} {transcript} preview={!!preview} {pending} {message} {select} {route} {back} bind:element={publicPanel}/>
  {/if}
{/if}
