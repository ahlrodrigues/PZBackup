# PZ Backup — backup de saves para Project Zomboid (Build 42)

Faz cópias do seu save **enquanto você joga**: automaticamente a cada 5 minutos e
quando você aperta uma tecla. Se o personagem morrer, você restaura um backup de
poucos minutos antes.

| Recurso | Como funciona |
|---|---|
| Backup automático | A cada 5 min, só enquanto o jogo estiver aberto |
| Backup manual | **F8** dentro do jogo |
| Restaurar dentro do jogo | **F9** ou *Opções > Mods > PZ Backup > Restaurar backup...* — o jogo fecha, restaura e reabre sozinho |
| Backup final | Ao fechar o jogo |
| Aviso na tela | Texto verde sobre o personagem (vermelho em caso de erro) |
| Proteção contra morte | Com o personagem morto, nenhum backup é feito — os bons ficam guardados |
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

### Pelo jogo (recomendado)

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

### Onde o save restaurado aparece

O save volta para a pasta de saves **com o nome original do mundo**, não com o nome
do backup:

| | Exemplo |
|---|---|
| Backup | `Zomboid/BackupsSaves/Survivor__14-10-2026_10-00-00__2026-10-14_14-35-07` |
| Restaurado em | `Zomboid/saves/Survivor/14-10-2026_10-00-00` |

O backup continua em `BackupsSaves` (é feita uma cópia), e o save que estava ali
antes — com o personagem morto — não é apagado: vai para
`Zomboid/BackupsSaves/substituidos/`. Se um backup recente foi feito já cercado de
zumbis, escolha um mais antigo.

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

## Ajustes

No início do script (`pz-backup.sh` ou `pz-backup.ps1`):

| Variável | Padrão | Função |
|---|---|---|
| `INTERVALO` / `$Intervalo` | 5 | Minutos entre backups automáticos |
| `MANTER` / `$Manter` | 10 | Backups guardados por mundo |
| `SOM` / `$Som` | ligado | Som a cada backup |

## Problemas

| Sintoma | O que fazer |
|---|---|
| F8 não faz nada | Procure `PZBackup` em `Zomboid/console.txt`. Deve aparecer `[PZBackup] carregado`. Confira se o mod está ativo no save. |
| Aparece "Backup solicitado" mas não salva | O script não está rodando. Linux: confira a opção de inicialização. Windows: abra o jogo pelo atalho *Project Zomboid + Backup*. |
| (Linux) O jogo não abre | Apague o texto da opção de inicialização e rode `chmod +x ~/Zomboid/pz-backup.sh`. |
| (Windows) Atalho abre e fecha | Rode o `instalar.bat` de novo. |
| Save restaurado não aparece em *Carregar* | O jogo estava aberto durante a restauração. Feche e abra o jogo. |
| "Feche o Project Zomboid antes de restaurar" | O jogo ainda está rodando. Feche-o totalmente (não basta voltar ao menu) ou restaure pelo F9. |
| F9 / janela diz "Script de backup não está rodando" | Linux: confira a opção de inicialização da Steam. Windows: feche o jogo e abra pelo atalho *Project Zomboid + Backup*. |
| Botão "Restaurar backup..." não aparece em Opções | Procure `[PZBackup]` em `Zomboid/console.txt` — erros das opções aparecem ali. F9 continua funcionando. |

## Como o mod e o script conversam

Por arquivos de texto em `Zomboid/Lua/`:

| Arquivo | Direção | Conteúdo |
|---|---|---|
| `pzbackup_pedido.txt` | mod → script | pedido de backup manual (o script apaga após atender) |
| `pzbackup_restaurar.txt` | mod → script | nome do backup a restaurar quando o jogo fechar |
| `pzbackup_estado.txt` | mod → script | `vivo` ou `morto` |
| `pzbackup_status.txt` | script → mod | `id\|ok\|mensagem` ou `id\|erro\|mensagem` |
| `pzbackup_lista.txt` | script → mod | backups disponíveis, um por linha: `nome\|rótulo` |
| `pzbackup_ativo.txt` | script → mod | hora do último sinal de vida do script (a cada 1 s) |
