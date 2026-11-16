<script>
  import Icon from './Icon.svelte';
  import Media from './Media.svelte';
  import logo from './assets/forge-flame.png';
  import { effectiveTheme, themeStyle } from './theme.js';
  let { active, detail = null, preview = false, embedded = false, pending = false, message = '',
    select, choose, route, back, element = $bindable(), search = $bindable('') } = $props();
  const theme = $derived(effectiveTheme(active.theme));
  const listed = $derived((active.items || []).filter(item => (item.title + ' ' + (item.summary || '')).toLocaleLowerCase('pt-BR').includes(search.trim().toLocaleLowerCase('pt-BR'))));
  const rating = item => item.rating || { up:0, down:0, vote:0 };
  const number = new Intl.NumberFormat('pt-BR');
</script>

<div class="window legal-window" class:embedded style={themeStyle(active.theme)} role={embedded ? undefined : 'dialog'} aria-modal={embedded ? undefined : 'true'} aria-label={active.title} tabindex="-1" bind:this={element}>
    <header class="top">
      <div class="brand"><img src={logo} alt=""/><div><span>{theme.brand}</span><strong>{theme.name}</strong></div></div>
      <div class="row">{#if preview}<span class="badge">PRÉVIA NÃO PUBLICADA</span>{:else}<span class="badge">SERVIÇOS DA CIDADE</span>{/if}
        {#if !embedded || detail}<button class="icon-button" aria-label={detail?'Voltar aos empregos':'Fechar painel'} onclick={back}><Icon name={detail?'back':'close'} size={20}/></button>{/if}</div>
    </header>
    <main class="legal-body">
      {#if detail}
        {@const count = rating(detail)}
        <button class="text-button" onclick={back}><Icon name="back"/> Voltar ao catálogo</button>
        <div class="detail-grid">
          <article>
            <p class="eyebrow">OPORTUNIDADE DE TRABALHO</p>
            <h1>{detail.title}</h1>
            <p class="lead">{detail.summary}</p>
            <div class="full-copy">{detail.details}</div>
            <div class="detail-actions row wrap">
              {#if detail.route}<button class="primary" disabled={pending || !!preview} onclick={route}><Icon name="compass"/> Marcar no GPS</button>
              {:else}<span class="muted">Sem destino definido</span>{/if}
            </div>
          </article>
          <aside>
            {#key detail.id}<Media item={detail} detail/>{/key}
            <div class="rating-box">
              <h2>Avaliações da comunidade</h2>
              <p class="support">Conte como foi sua experiência neste trabalho.</p>
              <div class="row wrap">
                <button class="secondary" class:selected={count.vote===1} aria-pressed={count.vote===1} disabled={pending || !!preview} onclick={() => choose(1)}><Icon name="up"/> Curtir · {number.format(count.up)}</button>
                <button class="secondary" class:selected={count.vote===-1} aria-pressed={count.vote===-1} disabled={pending || !!preview} onclick={() => choose(-1)}><Icon name="down"/> Descurtir · {number.format(count.down)}</button>
              </div>
            </div>
          </aside>
        </div>
      {:else}
        <div class="hero">
          <div><p class="eyebrow"><Icon name="location" size={15}/> CENTRAL DE OPORTUNIDADES</p>
            <h1>{active.title}</h1><p class="lead">{active.intro}</p></div>
          <div class="hero-mark" aria-hidden="true"><Icon name="case" size={78}/></div>
        </div>
        <div class="row spread catalogue-head">
          <div><h2>Trabalhos disponíveis</h2><small>{listed.length} {listed.length===1?'oportunidade':'oportunidades'}</small></div>
          <label class="search"><Icon name="search"/><input type="search" aria-label="Buscar emprego" placeholder="Buscar emprego…" bind:value={search}/></label>
        </div>
        {#if pending}<p class="support" role="status">Carregando detalhes…</p>{/if}
        <div class="jobs">
          {#each listed as item (item.id)}
            <article class="job-card">
              <button onclick={() => select(item)} disabled={pending} aria-label={'Ver detalhes: '+item.title}>
                <Media {item}/>
                <div class="job-copy"><h3>{item.title}</h3><p>{item.summary}</p><div class="row rating-line" aria-label={rating(item).up+' curtidas e '+rating(item).down+' descurtidas'}>
                  <span><Icon name="up" size={15}/> {number.format(rating(item).up)}</span>
                  <span><Icon name="down" size={15}/> {number.format(rating(item).down)}</span>
                </div></div>
              </button>
            </article>
          {:else}
            <div class="empty">
              <Icon name="case" size={30}/><h3>{search?'Nenhum emprego encontrado':'Nenhuma oportunidade disponível'}</h3>
              <p>{search?'Tente outro termo.':'Volte a conversar com este atendente mais tarde.'}</p>
            </div>
          {/each}
        </div>
      {/if}
      {#if message}<p class="error feedback" role="alert">{message}</p>{/if}
    </main>
    <footer class="foot"><span>{#if embedded}Prévia ao vivo · não publicada{:else}<kbd>ESC</kbd> {detail?'Voltar':preview?'Voltar à edição':'Fechar'}{/if}</span><span>{theme.name}</span></footer>
  </div>
