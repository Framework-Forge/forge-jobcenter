# Forge - Job Center

Central de empregos e contatos para FiveM. NUI em Svelte no padrão visual Forge da base. O City Hall foi consultado como referência de interação e proximidade; este recurso não depende dele, não atribui empregos e não precisa de banco.

## Instalação

O pacote já tem o build em `web/dist`. No seu `server.cfg`, inicie `pr_bridge` antes da central e use OneSync. Para o botão de screenshot, inicie também `screencapture` antes da central.

```cfg
# Exemplo para um grupo de administradores já existente.
add_ace group.admin forge.jobcenter.admin allow
ensure forge-jobcenter
```

O recurso também aceita a ACE `forge-core.admin`. Nenhum `server.cfg` ou permissões da base foram modificados. Use **/jobcenteradmin** no jogo.

## Administração

1. Em **Geral**, escolha **Interact** ou **Target**, ajuste a distância e configure **Layout da página legal**. Nome da central, identidade, cores e quantidade de cards por linha aparecem na prévia imediatamente; jogadores só recebem depois de **Salvar e publicar**.
2. Em **Empregos legais**, crie os cards com título, resumo, descrição completa, mídia opcional e destino. **Pré-visualizar** permite ver a navegação antes de publicar.
3. Em **Diálogos ilegais**, crie as opções que o jogador pode escolher, a resposta de cada uma e, se desejar, um destino no GPS.
4. Em **NPCs e páginas**, crie um NPC legal ou ilegal, configure título, rótulo e texto de abertura, posição e conteúdo vinculado. Use **Minha posição**, coordenadas manuais ou **Posicionar com laser**. O posicionador é a ferramenta do PR Bridge: confirme com Enter ou cancele com Backspace. O resultado só vira um NPC real ao salvar o cadastro.
5. Repita para outros NPCs, com catálogos compartilhados ou diferentes. Para editar, selecione um cadastro; para remover, use **Excluir** e confirme. Desativar mantém o cadastro guardado. Excluir um card ou uma opção remove os vínculos com todos os NPCs.

Em **NPCs e páginas**, cada NPC pode mostrar todos os empregos ou diálogos ativos do seu tipo, inclusive os cadastrados depois. Para restringir o conteúdo, escolha **Somente os selecionados** e marque os itens desejados. Cadastros anteriores com vínculos continuam usando sua seleção. Cadastros anteriores com lista vazia e sem modo definido passam a usar o catálogo do seu tipo.

O catálogo começa vazio: não cria NPCs nem destinos de exemplo na cidade. O diálogo ilegal não usa mapa público, card, imagem ou avaliação; a resposta só aparece após a pergunta escolhida. Os NPCs têm dimensão configurável (bucket 0 por padrão). O servidor exige proximidade e mesma dimensão para conteúdo, avaliações e rotas.

## Mídia e dados

- **Importar arquivo:** PNG, JPEG, WebP (até 2 MiB), WebM ou MP4 (até 12 MiB). A capacidade de tocar um arquivo depende do codec suportado no CEF do FiveM. WebM VP8/VP9 é uma opção para testar.
- **Tirar screenshot:** fecha temporariamente a NUI e captura apenas o jogo do administrador solicitante, pelo export `serverCapture` de `screencapture`. Não grava vídeo da sessão; vídeos são importados como arquivos ou vinculados por URL.
- **Vincular URL:** link direto HTTPS para o arquivo. Não aceita páginas ou embeds. Não baixa o conteúdo para o servidor; o navegador dos jogadores solicita a mídia ao host externo. Para restringir hosts, preencha `mediaHosts` em `shared/config.lua`; URLs locais e com credenciais não são aceitas.
- Arquivos enviados/capturados são guardados em `media/` e referenciados no JSON pelo nome. A NUI pede as partes por callbacks do PR Bridge, verifica a sequência e mostra o progresso ou oferece nova tentativa em caso de falha. Vídeos são carregados ao clicar, sem autoplay. Ao desvincular ou excluir, arquivos binários não são apagados automaticamente; limpe arquivos órfãos somente após backup e conferência das referências.
- `data/catalog-a.json` e `data/catalog-b.json`: revisões alternadas dos NPCs, catálogos e preferências gerais. O servidor lê a revisão válida mais recente e confere conflitos ao publicar.
- `data/votes-a.json` e `data/votes-b.json`: avaliações individuais, uma por licença de jogo e por emprego, com troca ou remoção. Não publique esses arquivos em repositório; identificadores nunca são enviados na NUI. Exclusão de emprego invalida o acesso às suas avaliações; os IDs não são reaproveitados.
- Faça backup de `data/` e `media/` juntos. Se ambos os JSON de um conjunto ficarem inválidos, o conjunto fica protegido contra regravação até restaurar os dados.

## Desenvolvimento e teste

O recurso usa `pr_lib.nui`, `pr_lib.callback`, `pr_lib.fivem.streaming`, `pr_lib.devtools.placePed`, `pr_lib.target` e `pr_lib.interact`. Não modifica PR Bridge, City Hall ou o núcleo. Usa o GPS nativo para marcar um ponto apenas no cliente.

O build fica em `web/dist`; para reconstruir, entre em `web`, execute `npm ci`, `npm run check` e `npm run build`. Consulte o [contrato visual](docs/UI-SPEC.md) e o [roteiro de validação](docs/TESTE.md).
