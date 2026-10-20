<p align="center"><img src="docs/img/capa.png" alt="PZ Backup" width="360"></p>

# PZ Backup — porque Knox County não perdoa (mas a gente sim)

**Downloads:** <https://github.com/ahlrodrigues/PZBackup/releases> ·
**Steam Workshop:** <https://steamcommunity.com/sharedfiles/filedetails/?id=3821180981> ·
*English:* [README.md](README.md)
Versão 1.4.1 · Mod ID `PZBackupAHLR` · Workshop ID `3821180981` · Licença [MIT](LICENSE) · Build 42

Você passou três semanas montando a base perfeita. Cerca dupla, horta, gerador,
estoque de feijão enlatado pra sobreviver ao fim do mundo duas vezes. Aí abriu uma
porta sem olhar e... é. Todo mundo já passou por isso.

O **PZ Backup** faz cópias do seu save **enquanto você joga** — sozinho, a cada 5
minutos, e quando você aperta **F8**. Morreu? Ele restaura o backup mais recente,
reabre o jogo e você só clica em **Continuar**. Sem terminal, sem copiar pasta na
mão, sem chorar no Discord.

> "Mas isso não é trapaça?" — É o *seu* jogo. Joga do jeito que te faz feliz.
> E se quiser hardcore raiz, é só desligar a restauração automática nas opções. 😉

---

## O que ele faz

| Recurso | Como funciona |
|---|---|
| 🕐 **Backup automático** | A cada 5 min, só enquanto o jogo está aberto |
| ⌨️ **Backup na hora** | **F8** dentro do jogo |
| ⏪ **Restaurar pelo jogo** | **F9** (ou *Opções → Mods → PZ Backup*): escolhe o backup, o jogo fecha, restaura e reabre sozinho |
| 💀 **Morreu? Volta!** | Contagem de 10 s e o **último backup seguro** daquele mundo é restaurado — pulando os mordidos e os feitos segundos antes da morte. Depois é só **Continuar** |
| ⚠️ **Nada de backup no meio da briga** | O backup automático espera enquanto tem zumbi em cima, pânico, sangramento, fogo ou pouca vida — e acontece assim que acalma |
| 🎨 **Lista colorida** | 🔴 mordido · 🟡 perigo / logo antes de uma morte · 🟢 normal · ⚪ sem detalhes — com legenda na janela |
| 📝 **Notas** | **F7** faz backup com nome ("antes do shopping"); **Nota** no F9 dá nome a qualquer backup |
| 🛡️ **Não salva defunto** | Com o personagem morto, nenhum backup é feito — os bons ficam intactos |
| 🧹 **Faxina automática** | Ao fechar o jogo, o save do personagem morto sai da lista *Carregar* (fica guardado, calma) |
| 📜 **Ver log** | Botão no jogo mostra tudo que o PZ Backup fez, com cores |
| 🌎 **Inglês e PT-BR** | Segue o idioma do jogo sozinho (português ou inglês); dá pra escolher um nas opções |
| 📌 **Fixe os bons** | Backups fixados nunca saem da rotação — aquele save "antes de Louisville" fica pra sempre |
| 🔎 **Saiba o que está restaurando** | O F9 mostra, de cada backup: personagem, saúde e ferimentos (com **MORDIDO!** em vermelho), local, fome/sede/cansaço/pânico, habilidades e mais |
| 🔌 **Checagem de mods** | Avisa antes de restaurar se os mods do backup são diferentes dos ativos agora — e diz quais |
| 🗂️ **Histórico esperto** | 10 mais recentes por mundo + 1 por hora (últimas 24 h) + 1 por dia de jogo (últimos 14) + os fixados + 5 saves substituídos |
| 💾 **Incremental** | Arquivos que não mudaram são compartilhados entre backups (hard links): cada backup custa só o que mudou |
| 🛡️ **Cópias seguras** | Espera o jogo terminar de gravar, confere cada cópia, fixa um backup de todos os mundos antes de atualização do jogo, avisa quando o disco está acabando |
| 🔊 **Bipes** | Dois bipes subindo = deu bom. Dois descendo = deu ruim |

## Como funciona (a parte nerd, em 20 segundos)

![Como o PZ Backup funciona](docs/img/como-funciona-pt.png)

O Lua do Project Zomboid roda numa caixinha de areia e **não pode copiar pastas**.
Então o PZ Backup tem duas partes que trocam bilhetinhos:

1. **O mod** (Workshop ou pasta `mods/`): as teclas, as janelas, os avisos na tela e
   o dedo-duro que conta pro script quando você morre.
2. **O script** (este repositório): o braçal. Copia, restaura e reabre o jogo.
   Bash no Linux, PowerShell no Windows.

Eles conversam por arquivos `.txt` na pasta `Zomboid/Lua/` (detalhes no fim).
**Só o mod da Workshop não faz backup nenhum** — precisa do script também.

## Morreu? Acontece. E agora?

![Morreu? E agora?](docs/img/morreu-pt.png)

1. Você morre. Um painel aparece com uma contagem de **10 segundos**.
2. Dá pra **Restaurar agora**, **Escolher outro** backup ou **Cancelar** (o F9 também
   cancela e abre a lista).
3. Acabou a contagem: o jogo fecha sozinho, o script restaura o **último backup
   seguro do mundo em que você morreu** e reabre o jogo. "Seguro" quer dizer:
   - **sem mordida** — personagem mordido continua infectado depois de restaurar, então esses são pulados;
   - **não feito logo antes da morte** — backups dos últimos **60 segundos** antes de
     morrer são pulados (a margem é configurável: desligada, 30 s, 1, 2 ou 5 min).

   O log conta o que foi pulado ("pulei 1 backup mordido e 2 feitos a menos de 60 s da
   morte"). Se todos estiverem mordidos, usa o mais recente mesmo assim.
4. No menu principal, clique em **Continuar**. Pronto, vivo de novo, uns minutos
   antes. Ninguém precisa saber.

> ⚠️ **Mordida é pra sempre.** A restauração automática já pula os mordidos, mas
> arranhão e laceração também podem infectar. Na dúvida, **Escolher outro** e pegue um verde.

<!--
## Telas

Adicione os prints em docs/img/ com estes nomes e apague esta linha de comentário:

![Opções do mod](docs/img/tela-opcoes-pt.png)
![Janela do F9](docs/img/tela-f9-pt.png)
![Painel ao morrer](docs/img/tela-morte-pt.png)
![Janela do log](docs/img/tela-log-pt.png)
-->

---

## Instalação

**Antes de tudo:** abra o Project Zomboid pelo menos uma vez, pra pasta `Zomboid`
existir. Depois baixe o `PZBackup-vX.Y.Z.zip` em
[Releases](https://github.com/ahlrodrigues/PZBackup/releases) e descompacte.

> Os instaladores falam inglês (é o idioma principal do projeto). As mensagens do
> script no terminal e no jogo seguem a opção de idioma do mod.

### 🐧 Linux (Steam nativa ou Flatpak)

```bash
bash install.sh
```

O instalador acha sua pasta `Zomboid`, instala o mod e o script e mostra o comando
certinho pra colar na Steam: botão direito em **Project Zomboid → Propriedades →
Geral → Opções de inicialização**:

```
/home/SEU_USUARIO/Zomboid/pz-backup.sh game %command%
```

Pronto: daqui pra frente é só jogar pela Steam normalmente. O script liga junto com
o jogo e desliga quando ele fecha.

### 🪟 Windows 10/11

Dois cliques no **`install.bat`**. Se o Windows ficar desconfiado ("editor
desconhecido"), clique em *Mais informações → Executar assim mesmo*.

Ele cria três atalhos na Área de Trabalho:

| Atalho | Pra que serve |
|---|---|
| **Project Zomboid + Backup** | Abre o jogo com o backup ligado. **Jogue sempre por aqui.** |
| **PZ Backup - Save now** | Backup manual (também **Ctrl+Alt+B**) |
| **PZ Backup - Restore** | Lista os backups e restaura o escolhido |

> No Windows, abrir direto pela Steam **não** liga o backup automático. A Steam do
> Windows não deixa "embrulhar" o jogo com um script, então o atalho faz esse papel.

### Depois, no jogo

Menu principal → **Mods** → ative o **PZ Backup** (e também na lista de mods do seu
save).

> **Prefere a Workshop?** [Inscreva-se no mod](https://steamcommunity.com/sharedfiles/filedetails/?id=3821180981)
> e use o pacote só pelo script. Não deixe o mod da Workshop e a cópia em
> `Zomboid/mods/PZBackup` ao mesmo tempo — os dois têm o mesmo Mod ID e vão brigar.

### Requisitos

| | Linux | Windows |
|---|---|---|
| Project Zomboid Build 42 | obrigatório | obrigatório |
| Bash / PowerShell | já vem no sistema | já vem no Windows 10/11 |
| **Python 3** | **recomendado** | não precisa |
| `paplay`, `pw-play` ou `aplay` | recomendado (bipes) | não precisa |

**Sem Python 3 no Linux** o backup funciona, mas: não tem bipe (os sons são gerados
com Python) e a detecção de morte depende só do mod. Confira com `python3 --version`
(no Slackware, pacote `python3` da série *d*).

---

## Usando

### ⌨️ Teclas

| Tecla | O que faz |
|---|---|
| **F7** | Backup agora **com nota**: digite um nome ("antes do shopping") e OK |
| **F8** | Backup agora. Aparece "Backup solicitado..." e logo depois "Backup feito" |
| **F9** | Janela de restauração (e, na contagem da morte, cancela e abre a lista) |

Dá pra trocar as três em *Opções → Mods → PZ Backup*. F7/F8 nunca esperam o perigo
passar: se você apertou, é porque quer.

### ⏪ Restaurar escolhendo o backup

1. **F9** (ou *Opções → Mods → PZ Backup → Restaurar backup...*).
2. Escolha na lista — o **1 é o mais recente**. Embaixo da lista aparece como você estava
   naquela hora (veja a tabela abaixo), inclusive se os **mods** batem com os de agora.
3. Clique em **Restaurar** e confirme. O jogo fecha, restaura e reabre sozinho.
4. Em *Carregar*, o save restaurado está no topo.

**Por que o jogo precisa fechar?** Ele só lê a lista de saves quando abre. Restaurar
com ele aberto faria o save sumir da lista — e ninguém quer isso.

#### 🎨 Cores na lista

Cada backup tem a cor do risco; a legenda fica no topo da janela:

| Cor | Significa |
|---|---|
| 🔴 **Vermelho** | **Mordido** naquele backup. A infecção volta junto. A restauração automática pula esses |
| 🟡 **Amarelo** | **Perigo**: feito em perigo (zumbis perto, pânico, sangramento, fogo), **segundos antes de uma morte** (dentro da margem), com saúde abaixo de 50%, ou com verificação falha |
| 🟢 **Verde** | Normal — os que você quer |
| ⚪ **Cinza** | Sem detalhes (feito antes da v1.4 ou sem o mod) |

#### 🔎 Detalhes do backup selecionado

Cada linha só aparece se houver dado pra ela:

| Linha | O que mostra | Cor |
|---|---|---|
| **Nota** | O nome que você deu | azul |
| **Backup** | Como foi feito (automático, tecla no jogo, final, antes de atualização...), tamanho e **MB novos** (incremental) | cinza |
| **Personagem** | Nome, profissão, dias vivo, zumbis mortos | branco |
| **Quando** | Data e hora no jogo, e *Fixado* se for o caso | azul |
| **Saúde** | Saúde %, mordidas, arranhões, lacerações | 🟢 inteiro · 🟠 ferido (ou abaixo de 60%) · 🔴 **MORDIDO!** |
| **Local** | Cidade aproximada (mapa vanilla), coordenadas x/y e andar, dentro de construção / ao ar livre / em veículo | branco |
| **Estado** | Fome, sede, cansaço e pânico em % | 🟠 quando algum chega a 50% |
| **Habilidades** | As 3 melhores habilidades, força, condicionamento e peso | cinza |
| **Perigo** | O perigo na hora do backup ("zumbis perto, pânico alto") | 🟠 |
| **Morte** | "Feito 12 s antes de uma morte" + "a restauração automática pula este backup" | 🟠 |
| **Mods** | Iguais aos de agora, ou quantos diferem — e quais (`-` só no backup, `+` só agora) | 🟢 / 🟠 |
| **Verificação** | "VERIFICAÇÃO FALHOU" se a cópia não bateu com o save | 🔴 |

As informações são atualizadas a cada 10 minutos do jogo (~25 s) e logo antes de cada F8,
então batem com o momento do backup. A cidade é uma dica a partir de áreas aproximadas das
cidades vanilla; em mapas de mod ou cidades novas da Build 42 aparecem só as coordenadas
(dá pra conferir em [map.projectzomboid.com](https://map.projectzomboid.com)).

> **Caçando o save de antes da mordida?** Desça a lista até a linha de saúde deixar de
> ficar vermelha. É esse.

> Backups feitos antes da v1.4 (ou com o mod desativado) aparecem *Sem detalhes*.
> Restauram normalmente — só não ficam se gabando da sua contagem de zumbis.

Também dá pelo terminal, **com o jogo fechado**:

- **Linux:** `pz-backup.sh list` (mostra `[PIN]`, a nota, `[PERIGO]`, `[12s ANTES DA MORTE]` e os detalhes) e depois `pz-backup.sh restore N`
- **Windows:** atalho *PZ Backup - Restore*

### 📌 Fixe os bons

A rotação guarda os **10 backups mais recentes** de cada mundo e joga o resto fora.
Ótimo pro espaço em disco, péssimo praquele save perfeito logo antes de saquear o shopping.

Selecione um backup na janela do **F9** e clique em **Fixar**. Ele ganha a etiqueta
`[FIXO]` e:

- **nunca é apagado** pela rotação, por mais velho que fique;
- **não conta** nos 10 — você continua tendo 10 backups novos além dele.

Mudou de ideia? Selecione e clique em **Desafixar**: ele volta pra rotação (e, se for
mais velho que os 10 mais recentes, sai no próximo backup). Backups fixados se acumulam
pra sempre, então desafixe os que não precisar mais.

Pelo terminal: `pz-backup.sh pin N` / `pz-backup.sh unpin N` (Windows: `pz-backup.ps1 pin N`),
com o **N** do `list`.

### 📝 Notas

Dois jeitos de dar nome a um backup:

- **F7** no jogo: pede um nome e já faz o backup;
- botão **Nota** na janela do F9: dá nome (ou troca) ao backup selecionado. Deixe vazio
  pra remover a nota.

A nota aparece na lista (`18/10 20:00 - Mundo - "antes do shopping"`) e no topo dos
detalhes. Até 60 caracteres. Pelo terminal: `pz-backup.sh note N "texto"`
(Windows: `pz-backup.ps1 note N "texto"`).

### ⚠️ Perigo: o backup automático espera

O problema: um backup automático feito 5 segundos antes de você morrer não serve pra
nada — restaurar só te mata de novo. Então, enquanto o personagem está **em perigo**, o
backup automático **espera** e tenta de novo a cada 20 segundos:

| Perigo | Quando |
|---|---|
| Zumbis | Te perseguindo, ou vivos a até 8 quadrados no mesmo andar |
| Pânico | 50% ou mais |
| Sangramento | Qualquer parte do corpo sangrando |
| Fogo | Você pegando fogo |
| Saúde | Abaixo de 25% |

Assim que acalma, o backup sai (log: "Perigo passou — fazendo o backup adiado"). O
backup final é pulado se o jogo fechou em perigo. **F7/F8 nunca esperam.** Mordida não
conta como "perigo" (mordido fica mordido pra sempre) — esses backups ficam vermelhos.

Liga/desliga: *Opções → Mods → PZ Backup → "Adiar o backup automatico durante perigo"*.

### 🛡️ Segurança dos saves

| Proteção | O que faz |
|---|---|
| **Espera o jogo terminar de gravar** | Antes de copiar, espera nenhum arquivo do save mudar por 3 s (até 30 s) |
| **Verificação** | Depois de copiar, compara cada arquivo e tamanho com o save; se o jogo gravou no meio, copia de novo. No Linux também confere o `players.db` (Python 3). Verificação falha vai pro log e fica amarela |
| **Antes de atualização do jogo** | Quando a Steam atualiza o Project Zomboid, o script percebe (número da build) e faz um backup **fixado** de todos os mundos **antes** da versão nova abri-los, com a nota "antes da atualização 123 -> 456" |
| **Pouco espaço em disco** | Abaixo de 1 GB livre, o backup automático pausa e você recebe um aviso (no máximo a cada 30 min). F7/F8 ainda tentam |

### 💾 Espaço em disco: histórico esperto + backups incrementais

**O que fica guardado**, por mundo (os fixados sempre ficam e não contam):

1. os **10 mais recentes**;
2. o mais novo de **cada hora** das últimas **24 horas**;
3. o mais novo de **cada dia de jogo** dos últimos **14 dias de jogo**.

Assim você tem detalhe fino dos últimos minutos e ainda acha algo de ontem e de uma
semana de jogo atrás — sem guardar centenas de cópias.

**Incremental:** a maioria dos arquivos do save não muda entre dois backups. Eles viram
**hard links** pro backup anterior — o mesmo arquivo no disco, sem ocupar espaço extra.
Cada backup custa só o que mudou (os detalhes mostram "340 MB (12 MB novos)"). Apagar um
backup antigo nunca estraga os outros, e restaurar copia arquivos de verdade. Precisa do
`rsync` no Linux (vem em quase toda distro) e de NTFS no Windows; sem eles, volta pra
cópia completa.

### 🔌 Depois de restaurar: confira os mods

O save volta **com a lista de mods de quando o backup foi feito**. O PZ Backup guarda
essa lista junto com cada backup e, se ela for diferente dos seus mods de agora, a janela
de confirmação **diz quais mods** estão só no backup ou só ativos agora (a restauração
pelo terminal também mostra, com `-` e `+`).

Ao carregar: *Carregar → seu save → Mods*. Reative o **PZ Backup** e os mods que você usa. Se o
F8/F9 ficar mudo, desative e reative o PZ Backup naquele save.

### 📍 Onde o save restaurado aparece

Com o **nome original do mundo** — a data do backup some do nome:

| | Exemplo |
|---|---|
| Backup | `BackupsSaves/Sandbox__2026-10-06_13-54-21__2026-10-14_14-20-51` |
| Restaurado em | `Saves/Sandbox/2026-10-06_13-54-21` |

E sim, o nome do mundo é a data em que ele foi **criado**. Se aparecer "13" ali, é
13 horas, não dia 13. (A gente também se confundiu.)

O backup continua em `BackupsSaves`, e o save que estava lá antes (o do defunto) vai
pra `BackupsSaves/replaced/`. Nada some sem querer.

### 🧹 Faxina de saves de morto

Com a opção ligada (padrão), **ao fechar o jogo** o save onde o personagem morreu sai
da lista *Carregar*. Ele não é apagado na hora: vai pra `replaced/` (ficam os 5
mais recentes).

| | Como funciona |
|---|---|
| Ligar/desligar | *Opções → Mods → PZ Backup → "Remover saves de personagem morto..."* |
| Quando | Só depois que o jogo fecha. Nunca durante a partida |
| Personagem novo no mesmo mundo | O save fica. Só sai se **todos** os personagens estiverem mortos |
| Multiplayer | `Saves/Multiplayer` nunca é tocado |
| Sem o mod ativo | Nada é removido |

Como ele sabe que você morreu: no **Linux**, lê o `players.db` de cada save (com
Python 3) — pega até saves antigos de mortos. No **Windows**, usa o aviso do mod.
Pra faxinar na hora, com o jogo fechado: `pz-backup.sh clean` / `pz-backup.ps1 clean`.

### 📜 Ver log

Botão **Ver log** na janela do F9 ou em *Opções → Mods → PZ Backup → Ver log...*
Mostra as últimas 150 linhas, mais recentes no topo, com cores:

| Cor | Significado |
|---|---|
| 🟢 Verde | Backup automático/final, tudo certo |
| 🔵 Azul | Backup pela F8 ou atalho |
| 🟡 Amarelo | Restauração ou faxina |
| 🔴 Vermelho | Falha, personagem morto, algo deu ruim |

No terminal: `pz-backup.sh log` (ou `pz-backup.ps1 log`). O log completo fica em
`BackupsSaves/pz-backup.log`.

| Marcação | Origem |
|---|---|
| `[AUTO]` | Backup a cada 5 min |
| `[MOD]` | Tecla F8 |
| `[MANUAL]` | Atalho do sistema ou comando `save` |
| `[FINAL]` | Ao fechar o jogo |
| `[RESTAURO]` | Restauração |
| `[LIMPEZA]` | Save de morto removido de *Carregar* |
| `[ATUALIZACAO]` | Backup fixado antes de atualização do jogo |

---

## Opções e ajustes

**No jogo** (*Opções → Mods → PZ Backup*):

| Opção | Padrão |
|---|---|
| Idioma | Automático (idioma do jogo) |
| Fazer backup agora / Fazer backup com nota / Abrir janela de restauração | F8 / F7 / F9 |
| Ao morrer, restaurar o último backup seguro automaticamente | ligado |
| Margem antes da morte (a restauração automática pula backups tão perto da morte) | 60 segundos (desligada, 30 s, 1, 2, 5 min) |
| Adiar o backup automático durante perigo | ligado |
| Remover saves de personagem morto ao fechar o jogo | ligado |
| Botões *Restaurar backup...* e *Ver log...* | — |

### 🌎 Idioma

Por padrão o PZ Backup **segue o idioma do jogo**: jogo em português, mod em
português; qualquer outro idioma, mod em inglês. Quer forçar um? Vá em
**Opções → Mods → PZ Backup → Idioma** e escolha:

| Opção | O que acontece |
|---|---|
| **Automatico (idioma do jogo)** | Padrão. Português com o jogo em português; inglês nos demais |
| **English** | Sempre em inglês |
| **Portugues (pt-BR)** | Sempre em português |

Janelas, mensagens e o log do script mudam na hora, depois de *Aplicar*; os nomes
das opções mudam depois de reiniciar o jogo.

**No começo do script** (`pz-backup.sh` ou `pz-backup.ps1`):

| Variável | Padrão | Pra quê |
|---|---|---|
| `INTERVAL` / `$Interval` | 5 | Minutos entre backups automáticos |
| `KEEP` / `$Keep` | 10 | Backups mais recentes guardados por mundo (os fixados são extras) |
| `KEEP_HOURLY` / `$KeepHourly` | 24 | Também 1 por hora das últimas N horas (`0` = desliga) |
| `KEEP_GAME_DAYS` / `$KeepGameDays` | 14 | Também 1 por dia de jogo, últimos N dias de jogo (`0` = desliga) |
| `HARDLINKS` / `$Hardlinks` | ligado | Backups incrementais (hard links) |
| `MIN_FREE_MB` / `$MinFreeMB` | 1024 | Backup automático pausa abaixo deste espaço livre |
| `QUIET_SECONDS` / `$QuietSeconds` | 3 | Espera o save ficar parado por este tempo |
| `VERIFY` / `$Verify` | ligado | Confere cada cópia |
| `UPDATE_BACKUP` / `$UpdateBackup` | ligado | Backup fixado de todos os mundos quando o jogo atualiza |
| `DEATH_MARGIN` / `$DeathMargin` | vazio | Vazio = segue a margem do mod; segundos pra forçar |
| `DANGER_WAIT` / `$DangerWait` | vazio | Vazio = segue o mod; `1` / `0` força |
| `DANGER_RETRY` / `$DangerRetry` | 20 | Segundos entre tentativas enquanto o backup está adiado |
| `KEEP_REPLACED` / `$KeepReplaced` | 5 | Saves substituídos guardados |
| `SOUND` / `$Sound` | ligado | Bipes |
| `REMOVE_DEAD` / `$RemoveDead` | vazio | Vazio = segue o mod; `1` sempre; `0` nunca |
| `LANGUAGE` / `$Language` | vazio | Vazio = segue a opção *Idioma* do mod; `pt` ou `en` força |

## Onde ficam as coisas

| O quê | Linux | Windows |
|---|---|---|
| Backups e log | `~/Zomboid/BackupsSaves/` | `%USERPROFILE%\Zomboid\BackupsSaves\` |
| Detalhes, fixados, mortes, build do jogo | `BackupsSaves/.info/`, `.pinned`, `.deaths`, `.buildid` | igual, dentro de `BackupsSaves\` |
| Script | `~/Zomboid/pz-backup.sh` | `%USERPROFILE%\Zomboid\pz-backup.ps1` |
| Mod | `~/Zomboid/mods/PZBackup/` | `%USERPROFILE%\Zomboid\mods\PZBackup\` |

Na Steam Flatpak sem acesso à pasta pessoal, troque `~/Zomboid` por
`~/.var/app/com.valvesoftware.Steam/Zomboid` (o instalador detecta sozinho).

---

## Deu ruim? 🔧

| Sintoma | O que fazer |
|---|---|
| F8 não faz nada | Procure `PZBackup` em `Zomboid/console.txt` — deve ter `[PZBackup] loaded`. Confira se o mod está ativo **no save** |
| "Backup solicitado" e nada acontece | O script não está rodando. Linux: confira a opção de inicialização. Windows: jogue pelo atalho *Project Zomboid + Backup* |
| "Script de backup não está rodando" | Mesma coisa de cima 👆 |
| (Linux) O jogo não abre | Apague a opção de inicialização e rode `chmod +x ~/Zomboid/pz-backup.sh` |
| (Windows) Atalho abre e fecha | Rode o `install.bat` de novo |
| Save restaurado não aparece | O jogo estava aberto na restauração. Feche e abra |
| "Feche o Project Zomboid antes de restaurar" | Feche de verdade (não basta voltar ao menu) ou use o F9 |
| Depois de restaurar, F8/F9 mudos | Reative o PZ Backup em *Carregar → save → Mods* |
| Contador vermelho de erros no jogo | Veja `Zomboid/console.txt`. Se o erro não citar `PZBackup`, é de outro mod |

Pra caçar erro: `grep -an -B3 -A10 "PZBackup" ~/Zomboid/console.txt | tail -60`

---

## Por dentro: como mod e script conversam

Por arquivos de texto em `Zomboid/Lua/`:

| Arquivo | Direção | Conteúdo |
|---|---|---|
| `pzbackup_pedido.txt` | mod → script | pedido de backup (F8), linha opcional `nota=<texto>` (F7) |
| `pzbackup_restaurar.txt` | mod → script | backup a restaurar ao fechar, ou `AUTO modo/mundo` |
| `pzbackup_estado.txt` | mod → script | `vivo`, `morto`, `restaurado` ou `limpo` + `modo/mundo` + hora da morte (Unix) |
| `pzbackup_config.txt` | mod → script | `apagar_mortos=1/0`, `idioma=pt/en`, `margem_morte=<s>`, `adiar_perigo=1/0` |
| `pzbackup_perigo.txt` | mod → script | `1\|zumbis,panico\|<hora unix>` (perigo agora), atualizado a cada ~2-10 s |
| `pzbackup_status.txt` | script → mod | `id\|ok\|mensagem` ou `id\|erro\|mensagem` |
| `pzbackup_lista.txt` | script → mod | backups disponíveis: `nome\|rótulo` |
| `pzbackup_ativo.txt` | script → mod | sinal de vida do script (a cada 1 s) |
| `pzbackup_log.txt` | script → mod | últimas 150 linhas do log (pro botão *Ver log*) |
| `pzbackup_info.txt` | mod → script | tudo o que aparece no painel de detalhes mais os mods ativos, um `chave=valor` por linha; o script copia pra `BackupsSaves/.info/<backup>.txt` |
| `pzbackup_fixar.txt` | mod → script | comandos, um por linha: `pin <backup>`, `unpin <backup>`, `note <backup>\|<texto>` |
| `pzbackup_detalhes.txt` | script → mod | `nome\|fixo\|chave=valor\|chave=valor...` por backup (o script repassa todos os campos, então campos novos só precisam de atualização do mod) |

O `pzbackup_lista.txt` mantém o formato antigo `nome|rótulo` e os detalhes ficam num
arquivo separado, então o script v1.4 funciona com o mod v1.3 (e vice-versa — só não
aparecem as novidades até os dois estarem atualizados).

## Publicar uma versão nova (mantenedor)

### Do jeito rápido: baixou o patch e o zip? Um comando.

```bash
bash ~/Projetos/PZBackup/tools/publish.sh
```

Ele pega o `PZBackup-vX.Y.Z.patch` e o `PZBackup-vX.Y.Z.zip` mais novos de `~/Downloads` e:

1. confere o repositório (sem mudanças pendentes, atualizado com o Forgejo);
2. aplica o patch — se o último commit for uma entrega anterior da mesma versão, troca
   por ela (se ainda não foi enviada) ou cria um commit de atualização por cima (se já foi);
3. confere a versão em todos os arquivos;
4. pergunta e faz o `push` do commit e da tag `vX.Y.Z` pro Forgejo;
5. espera a tag chegar no GitHub pelo espelho e cria a Release com o zip e as notas do
   CHANGELOG (precisa do `gh` logado; sem ele, avisa pra fazer à mão);
6. instala o `pz-backup.sh` novo no `~/Zomboid` (o mod não: quem entrega é a Workshop);
7. monta a pasta da Workshop.

Depois é só, no jogo: *Workshop → Criar e atualizar itens → PZBackup → Atualizar*.
Pode rodar de novo à vontade: ele pula o que já foi feito. Opções: `--private`,
`--no-release`, `--yes` (sem perguntar), `--patch`, `--zip`, `--repo` (veja `--help`).

### Passo a passo (pra entender ou fazer à mão)

A versão fica em 9 lugares (mod.info, o mod, os dois scripts, README, LEIAME e
CHANGELOG). **Não edite à mão:** um comando troca todos de uma vez.

1. Anote as novidades no `CHANGELOG.md`, numa seção `## [Unreleased]` no topo.
2. Troque a versão:
   ```bash
   bash tools/bump-version.sh 1.4.1
   ```
   A seção `[Unreleased]` vira `[1.4.1] - <data de hoje>` e o link da release é criado.
   Se não houver `[Unreleased]`, ele cria uma seção vazia pra você preencher.
3. Confira a qualquer momento: `bash tools/bump-version.sh --check`.
4. `git commit`, `git tag v1.4.1`, `git push --follow-tags` (o Forgejo espelha no GitHub).
5. No GitHub, crie a Release da tag e anexe o `PZBackup-v1.4.1.zip`.
6. Workshop: `bash workshop/prepare-workshop.sh --public` e, no jogo,
   *Workshop → Criar e atualizar conteúdo → PZBackup*. O script **se recusa** a montar a
   pasta se algum arquivo estiver com versão diferente, e coloca a versão no rodapé da
   descrição da Workshop.

Onde o jogador vê a versão:

| Lugar | O que aparece |
|---|---|
| *Opções → Mods* | Nome da página "PZ Backup 1.4.1" e título "PZ Backup - versão 1.4.1" |
| Janela do F9 (canto superior direito) | `mod 1.4.1 \| script 1.4.1` — **vermelho** se forem diferentes |
| Ao entrar no jogo | Aviso "mod 1.4.1, script 1.4.0. Atualize o script" se forem diferentes |
| Log do script | "Jogo iniciado — PZ Backup 1.4.1, ..." |
| Terminal | `pz-backup.sh version` / `pz-backup.ps1 version` |
| `console.txt` | `[PZBackup] 1.4.1 loaded` e `[PZBackup] mod 1.4.1, script 1.4.1` |
| Workshop | Rodapé da descrição: "Version 1.4.1" |

---

Feito com ☕ e muitas mortes desnecessárias em Muldraugh.
[MIT](LICENSE) © Antonio Henrique (ahlrodrigues)
