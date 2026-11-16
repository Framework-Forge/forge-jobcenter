<script>
  import Icon from './Icon.svelte';
  import { readMedia, releaseMedia } from './api.js';
  let { item, detail = false } = $props();
  let node = $state(), visible = $state(false), play = $state(false), src = $state(null);
  let broken = $state(''), loading = $state(false), progress = $state(0), retry = $state(0);
  $effect(() => {
    if (!node) return;
    const observer = new IntersectionObserver(entries => { if (entries.some(entry => entry.isIntersecting)) visible = true; });
    observer.observe(node);
    return () => observer.disconnect();
  });
  $effect(() => {
    const media = item?.media, id = item?.id;
    const shouldLoad = retry >= 0 && visible && media && (media.kind === 'image' || (detail && play));
    let live = true, owned;
    src = null; broken = ''; loading = false; progress = 0;
    if (shouldLoad) {
      if (media.url) src = media.url;
      else if (media.file) {
        loading = true;
        readMedia(id, media.file, () => live, value => { if (live) progress = value; }).then(url => {
          if (live) { owned = url; src = url; broken = url ? '' : 'Mídia indisponível.'; loading = false; }
          else releaseMedia(url);
        }).catch(error => {
          if (live) { broken = error.message || 'Mídia indisponível.'; loading = false; }
        });
      }
    }
    return () => { live = false; releaseMedia(owned); };
  });
</script>
<div class="media" class:large={detail} bind:this={node}>
  {#if item?.media?.kind === 'video' && detail && !play}
    <button class="secondary" onclick={() => play = true}><Icon name="play"/> Carregar vídeo</button>
  {:else if src && !broken && item.media.kind === 'video'}
    {#key retry}<video {src} controls preload="metadata" onerror={() => broken = 'Não foi possível reproduzir o vídeo.'}><track kind="captions" /></video>{/key}
  {:else if src && !broken}
    {#key retry}<img {src} alt="" draggable="false" onerror={() => broken = 'Não foi possível exibir a imagem.'}/>{/key}
  {:else}
    <div class="media-placeholder">
      <Icon name={item?.media?.kind === 'video' ? 'play' : 'case'} size={30}/>
      {#if loading}<small>Carregando mídia…{progress > 0 ? ' ' + progress + '%' : ''}</small>
      {:else if broken}<small>{detail ? broken : 'Mídia indisponível'}</small>
        {#if detail}<button type="button" class="secondary" onclick={() => retry++}>Tentar novamente</button>{/if}
      {:else if item?.media?.kind === 'video'}<small>Vídeo nos detalhes</small>{/if}
    </div>
  {/if}
</div>
