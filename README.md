# PZBackup — backup de saves para Project Zomboid (Build 42)

Faz cópias do seu save **enquanto você joga**: automaticamente a cada 5 minutos e
quando você aperta uma tecla. Se o personagem morrer, você restaura um backup de
poucos minutos antes.

| Recurso | Como funciona |
|---|---|
| Backup automático | A cada 5 min, só enquanto o jogo estiver aberto |
| Backup manual | **F8** dentro do jogo |
| Restaurar dentro do jogo | **F9** ou *Opções > Mods > PZ Backup > Restaurar backup...* — o jogo fecha, restaura e reabre sozinho |
| Restauração automática ao morrer | Contagem de 10 s, restaura o backup mais recente do mundo e reabre o jogo: é só clicar em **Continuar** (ligada por padrão) |
| Backup final | Ao fechar o jogo |
| Aviso na tela | Texto verde sobre o personagem (vermelho em caso de erro) |
| Proteção contra morte | Com o personagem morto, nenhum backup é feito — os bons ficam guardados |
| Limpeza de saves de morto | Ao fechar o jogo, o save onde o personagem morreu sai de *Carregar* (ligado por padrão; desligue em *Opções*) |
| Histórico | Mantém os 10 backups mais recentes de cada mundo |

As teclas podem ser trocadas em *Opções > Mods > PZ Backup*.

O pacote tem duas partes: um **mod** (teclas, janela de restauração, avisos e
detecção de morte) e um **script** que faz as cópias — o Lua do jogo não tem
permissão para copiar pastas.

## Sistemas suportados

| Sistema | Instalador | Script |
|---|---|---|
| Linux (Steam nativa ou Flatpak) | `instalar.sh` | `pz-backup.sh` (Bash) |
| Windows 10/11 | `instalar.bat` | `pz-backup.ps1` (PowerShell) |

Cada instalador confere o sistema e encontra a pasta do jogo sozinho.

## Requisitos

| | Linux | Windows |
|---|---|---|
| Project Zomboid Build 42 | obrigatório | obrigatório |
| Bash | obrigatório (já vem no sistema) | — |
| PowerShell | — | obrigatório (já vem no Windows 10/11) |
| **Python 3** | **recomendado** | não usado |
| `paplay`, `pw-play` ou `aplay` | recomendado (som) | não usado |

**Python 3 no Linux:** o backup funciona sem ele, mas sem o Python o script:

- não toca os bipes de aviso (ele gera os sons com Python);
- não faz a verificação extra de morte pelo `players.db` — a detecção passa a
  depender só do mod estar ativado.

Confira se está instalado com `python3 --version`. A maioria das distribuições já
traz o Python 3 (no Slackware, pacote `python3` da série *d*). O `instalar.sh` avisa
quando ele não é encontrado. No Windows não é preciso instalar nada.

> **Antes de instalar:** abra o Project Zomboid pelo menos uma vez, para a pasta
> `Zomboid` existir.

---

## Instalação no Windows

1. Descompacte o pacote em qualquer pasta.
2. Dê dois cliques em **`instalar.bat`**. Se o Windows avisar sobre "editor
   desconhecido", clique em *Mais informações → Executar assim mesmo*.
3. No jogo: menu principal → **Mods** → ative **PZ Backup** (e também no seu save).

O instalador cria três atalhos na Área de Trabalho:

| Atalho | Para que serve |
|---|---|
| **Project Zomboid + Backup** | Abre o jogo pela Steam com o backup automático. **Use sempre este para jogar.** |
| **PZ Backup - Salvar agora** | Backup manual, também pela tecla **Ctrl+Alt+B** |
| **PZ Backup - Restaurar** | Mostra a lista de backups e pergunta qual restaurar |

> No Windows, abrir o jogo direto pela Steam **não** liga o backup automático —
> use o atalho *Project Zomboid + Backup*. A detecção de morte depende do mod
> estar ativado.

## Instalação no Linux

1. Descompacte o pacote e, no terminal, dentro da pasta:
   ```bash
   bash instalar.sh
   ```
2. O instalador mostra o comando já com o caminho certo para o seu sistema. Copie e
   cole na Steam: botão direito em **Project Zomboid → Propriedades → Geral →
   Opções de inicialização**, no campo de texto. O comando tem este formato:
   ```
   /home/SEU_USUARIO/Zomboid/pz-backup.sh jogo %command%
   ```
3. No jogo: menu principal → **Mods** → ative **PZ Backup** (e também no seu save).

Agora é só jogar pela Steam normalmente. Opcional: crie um atalho global (no KDE:
*Configurações → Atalhos → Adicionar novo → Comando ou script*) com o comando
`/home/SEU_USUARIO/Zomboid/pz-backup.sh save`.

Veja em **Requisitos** o que muda sem o Python 3.

---

## Restaurar um backup (quando o personagem morrer)

### Automática, ao morrer (padrão)

Com a opção *"Ao morrer, restaurar o backup mais recente automaticamente"* ligada:

1. O personagem morre e aparece um painel com contagem de **10 segundos**.
2. Ao fim da contagem (ou em **Restaurar agora**), o jogo fecha, o script restaura
   o **backup mais recente daquele mundo** e reabre o jogo.
3. No menu principal, clique em **Continuar**.

No painel também dá para **Escolher outro** backup (abre a lista, como o F9) ou
**Cancelar**. Apertar F9 durante a contagem também cancela e abre a lista.

O backup escolhido é sempre o mais recente **do mundo em que você morreu**, mesmo
que outro mundo tenha um backup mais novo. Se o mundo não tem nenhum backup, ou o
script não está rodando, nada é feito e uma mensagem avisa.

> Lembre: o backup mais recente pode ter sido feito já depois de uma mordida ou
> cercado de zumbis. Nesses casos, use **Escolher outro** e volte um ou dois.

Para desligar: *Opções → Mods → PZ Backup → "Ao morrer, restaurar o backup mais
recente automaticamente"*.

### Pelo jogo, escolhendo o backup

1. Aperte **F9** — no jogo, inclusive na tela de morte — ou, no menu principal, vá em
   *Opções > Mods > PZ Backup > Restaurar backup...*.
2. Escolha o backup na lista (o primeiro é o mais recente) e clique em **Restaurar**.
3. Confirme. O jogo **fecha sozinho**, o script restaura o save e **reabre o jogo**.
4. Em *Carregar*, o save restaurado aparece no topo da lista.

Por que o jogo precisa fechar: ele só lê a lista de saves quando abre. Restaurar com
ele aberto faria o save não aparecer em *Carregar*.

> Funciona apenas com o script rodando — no Linux, com a opção de inicialização da
> Steam; no Windows, abrindo o jogo pelo atalho *Project Zomboid + Backup*. Se o
> script não estiver ativo, a janela avisa e não fecha o jogo.

### Pelo terminal ou atalho (com o jogo fechado)

- **Windows:** atalho *PZ Backup - Restaurar* e digite o número.
- **Linux:** `pz-backup.sh list` para ver a lista e `pz-backup.sh restore N`.

O script recusa a restauração enquanto o jogo estiver aberto.

### Depois de restaurar: confira os mods do save

O save restaurado volta **com a lista de mods de quando o backup foi feito**. Se
você ativou ou desativou mods depois disso, a mudança não está no backup.

Ao carregar o save: *Carregar → selecione o save → Mods*. Reative o **PZ Backup** e os
mods que você usa, e desative os que não quiser. Se algum mod não responder (por
exemplo, F8/F9 sem efeito), desative e reative esse mod no save.

O script e a janela de restauração mostram esse lembrete a cada restauração.

### Onde o save restaurado aparece

O save volta para a pasta de saves **com o nome original do mundo**, não com o nome
do backup:

| | Exemplo |
|---|---|
| Backup | `Zomboid/BackupsSaves/Survivor__14-10-2026_10-00-00__2026-10-14_14-35-07` |
| Restaurado em | `Zomboid/saves/Survivor/14-10-2026_10-00-00` |

O backup continua em `BackupsSaves` (é feita uma cópia), e o save que estava ali
antes — com o personagem morto — não é apagado: vai para
`Zomboid/BackupsSaves/substituidos/` (ficam os 5 mais recentes; os mais antigos são
apagados a cada nova restauração). Se um backup recente foi feito já cercado de
zumbis, escolha um mais antigo.

## Remover saves de personagem morto

Com a opção ligada (padrão), **ao fechar o jogo** o script tira da pasta `Saves` o
save onde o personagem morreu, para ele não ficar ocupando a lista *Carregar*.

| | Como funciona |
|---|---|
| Ligar/desligar | *Opções → Mods → PZ Backup → "Remover saves de personagem morto ao fechar o jogo"* |
| Quando acontece | Só depois que o jogo fecha — nunca durante a partida |
| O save é apagado? | Não na hora: vai para `BackupsSaves/substituidos/` (ficam os 5 mais recentes) |
| Restaurou pelo F9? | A restauração já move o save morto; a limpeza não mexe no save restaurado |
| Personagem novo no mesmo mundo | O save é mantido: só sai se **todos** os personagens dele estiverem mortos |
| Multiplayer | Saves de servidor (`Saves/Multiplayer`) nunca são tocados |
| Sem o mod ativo | Nada é removido |

Como o script sabe que o personagem morreu:

- **Linux:** lê o `players.db` de cada save (precisa do Python 3). Isso também
  pega saves antigos de personagens mortos que já estavam na pasta. Sem Python, vale
  o aviso do mod, só para o save em que a morte aconteceu.
- **Windows:** só o aviso do mod — remove apenas o save em que a morte aconteceu.

Para limpar na hora, com o jogo fechado: `pz-backup.sh limpar` (Linux) ou
`pz-backup.ps1 limpar` (Windows). O comando funciona mesmo com a opção desligada.

No script também dá para forçar: `APAGAR_MORTOS=1` (sempre) ou `APAGAR_MORTOS=0`
(nunca); vazio segue a opção do mod.

## Onde ficam os arquivos

| O quê | Linux | Windows |
|---|---|---|
| Backups e log | `~/Zomboid/BackupsSaves/` | `%USERPROFILE%\Zomboid\BackupsSaves\` |
| Script | `~/Zomboid/pz-backup.sh` | `%USERPROFILE%\Zomboid\pz-backup.ps1` |
| Mod | `~/Zomboid/mods/PZBackup/` | `%USERPROFILE%\Zomboid\mods\PZBackup\` |

Na Steam Flatpak, troque `~/Zomboid` por `~/.var/app/com.valvesoftware.Steam/Zomboid`
quando for essa a pasta usada pelo jogo (o instalador detecta).

## Log

O arquivo `BackupsSaves/pz-backup.log` registra tudo, com a origem de cada ação:

| Marcação | Significado |
|---|---|
| `[AUTO]` | Backup periódico durante o jogo |
| `[MOD]` | Tecla F8 dentro do jogo |
| `[MANUAL]` | Atalho de teclado do sistema ou comando `save` |
| `[FINAL]` | Backup ao fechar o jogo |
| `[RESTAURO]` | Restauração de um backup (pelo jogo ou pelo terminal) |
| `[LIMPEZA]` | Save de personagem morto removido de *Carregar* |

## Ajustes

No início do script (`pz-backup.sh` ou `pz-backup.ps1`):

| Variável | Padrão | Função |
|---|---|---|
| `INTERVALO` / `$Intervalo` | 5 | Minutos entre backups automáticos |
| `MANTER` / `$Manter` | 10 | Backups guardados por mundo |
| `MANTER_SUBST` / `$ManterSubst` | 5 | Saves substituídos guardados em `substituidos/` (no total) |
| `SOM` / `$Som` | ligado | Som a cada backup |
| `APAGAR_MORTOS` / `$ApagarMortos` | vazio | Vazio = segue a opção do mod; `1` = sempre; `0` = nunca |

## Problemas

| Sintoma | O que fazer |
|---|---|
| F8 não faz nada | Procure `PZBackup` em `Zomboid/console.txt`. Deve aparecer `[PZBackup] carregado`. Confira se o mod está ativo no save. |
| Aparece "Backup solicitado" mas não salva | O script não está rodando. Linux: confira a opção de inicialização. Windows: abra o jogo pelo atalho *Project Zomboid + Backup*. |
| (Linux) O jogo não abre | Apague o texto da opção de inicialização e rode `chmod +x ~/Zomboid/pz-backup.sh`. |
| (Windows) Atalho abre e fecha | Rode o `instalar.bat` de novo. |
| Save restaurado não aparece em *Carregar* | O jogo estava aberto durante a restauração. Feche e abra o jogo. |
| "Feche o Project Zomboid antes de restaurar" | O jogo ainda está rodando. Feche-o totalmente (não basta voltar ao menu) ou restaure pelo F9. |
| Depois de restaurar, F8/F9 não funcionam ou falta um mod | O save voltou com a lista de mods do backup. Em *Carregar → save → Mods*, reative o PZ Backup (desative e reative se preciso). |
| F9 / janela diz "Script de backup não está rodando" | Linux: confira a opção de inicialização da Steam. Windows: feche o jogo e abra pelo atalho *Project Zomboid + Backup*. |
| Botão "Restaurar backup..." não aparece em Opções | Procure `[PZBackup]` em `Zomboid/console.txt` — erros das opções aparecem ali. F9 continua funcionando. |

## Como o mod e o script conversam

Por arquivos de texto em `Zomboid/Lua/`:

| Arquivo | Direção | Conteúdo |
|---|---|---|
| `pzbackup_pedido.txt` | mod → script | pedido de backup manual (o script apaga após atender) |
| `pzbackup_restaurar.txt` | mod → script | nome do backup a restaurar quando o jogo fechar, ou `AUTO modo/mundo` (o mais recente desse mundo) |
| `pzbackup_estado.txt` | mod → script | `vivo`, `morto`, `restaurado` ou `limpo` + linha 2: `modo/mundo` |
| `pzbackup_config.txt` | mod → script | opções do mod que o script usa (`apagar_mortos=1/0`) |
| `pzbackup_status.txt` | script → mod | `id\|ok\|mensagem` ou `id\|erro\|mensagem` |
| `pzbackup_lista.txt` | script → mod | backups disponíveis, um por linha: `nome\|rótulo` |
| `pzbackup_ativo.txt` | script → mod | hora do último sinal de vida do script (a cada 1 s) |
