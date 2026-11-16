<script>
  let { active, detail, transcript, preview, pending, message, select, route, back, element = $bindable() } = $props();
  let log = $state();

  $effect(() => {
    if (log && transcript.length) log.scrollTop = log.scrollHeight;
  });
</script>

<div class="chat-stage">
  <div class="chat" role="dialog" aria-modal="true" aria-label={active.title} tabindex="-1" bind:this={element}>
    <div class="chat-header">
      <h2>{active.title}{#if preview}<small>Prévia</small>{/if}</h2>
      <button class="chat-button" disabled={pending} onclick={back}>
        <kbd>ESC</kbd> {detail ? 'Voltar' : preview ? 'Voltar à edição' : 'Encerrar'}
      </button>
    </div>

    <div class="chat-log" role="log" aria-label="Mensagens da conversa" bind:this={log}>
      <p class="bubble"><strong>{active.title}</strong>{active.intro}</p>
      {#each transcript as line}
        <p class="bubble" class:player={line.fromPlayer}>
          <strong>{line.fromPlayer ? 'Você' : active.title}</strong>{line.text}
        </p>
      {/each}
    </div>

    {#if pending && !detail}<p class="chat-status" role="status">Aguardando resposta…</p>{/if}
    {#if message}<p class="chat-status error" role="alert">{message}</p>{/if}

    <div class="chat-actions">
      {#if detail}
        {#if detail.route}<button class="chat-button gps" disabled={pending || preview} onclick={route}>Marcar no GPS</button>{/if}
        <button class="chat-button" disabled={pending} onclick={back}>Perguntar outra coisa</button>
      {:else}
        {#each active.items || [] as item (item.id)}
          <button class="chat-button choice" disabled={pending} onclick={() => select(item)}>{item.title}</button>
        {:else}
          <p class="chat-status">Não tenho novidades agora.</p>
        {/each}
      {/if}
    </div>
  </div>
</div>

<style>
  .chat-stage {
    position: fixed;
    inset: 0;
    display: grid;
    place-items: end;
    padding: 0 4vw 7vh;
  }
  .chat {
    --accent: #f4bb7a;
    display: flex;
    flex-direction: column;
    gap: 8px;
    width: min(440px, 100%);
    max-height: 85vh;
    outline: none;
  }
  .chat-header, .chat-actions {
    display: flex;
    align-items: center;
    gap: 6px;
  }
  .chat-header { justify-content: space-between; gap: 10px; }
  .chat-header h2, .chat-status, .chat-button, .bubble {
    background: #121013bf;
    color: #fff8ef;
    border-radius: 10px;
    overflow-wrap: anywhere;
  }
  .chat-header h2 { padding: 6px 10px; font-size: 14px; }
  .chat-header small { margin-left: 8px; color: var(--accent); }
  .chat-log {
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    gap: 6px;
    min-height: 0;
    max-height: 43vh;
    overflow-y: auto;
    padding: 8px 4px 0 0;
  }
  .bubble {
    flex-shrink: 0;
    max-width: 100%;
    padding: 8px 12px;
    font-size: 14px;
    line-height: 1.45;
    white-space: pre-wrap;
    animation: chat-arrive 220ms ease-out both;
  }
  .bubble strong { display: block; margin-bottom: 1px; color: var(--accent); font-size: 12px; }
  .bubble.player { background: #472b17cc; }
  .chat-actions {
    flex-shrink: 0;
    flex-wrap: wrap;
    align-items: stretch;
    max-height: 27vh;
    overflow-y: auto;
    padding: 2px;
  }
  .chat-button {
    min-height: 32px;
    padding: 6px 10px;
    border: 1px solid #f4bb7a52;
    font-size: 12px;
    font-weight: 700;
  }
  .chat-button:not(:disabled):hover { background: #322316e6; border-color: var(--accent); }
  .chat-button:focus-visible { outline-offset: -2px; }
  .chat-button kbd { margin-right: 3px; }
  .choice { text-align: left; }
  .gps { color: var(--accent); }
  .chat-status { align-self: flex-start; padding: 5px 8px; font-size: 12px; }
  @keyframes chat-arrive {
    from { opacity: 0; transform: translateY(8px); }
    to { opacity: 1; transform: translateY(0); }
  }
  @media (prefers-reduced-motion: reduce) { .bubble { animation: none; } }
</style>
