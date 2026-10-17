# Changelog

Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/);
versões seguem [SemVer](https://semver.org/lang/pt-BR/).

## [1.0.1] - 2026-10-16

### Alterado
- **Mod ID agora é `PZBackupAHLR`** (antes `PZBackupAhlr`). Quem já usava o mod precisa
  reativá-lo nos saves (*Carregar → save → Mods*); as opções do mod voltam ao padrão.
- Descrição da Workshop: linha de Build atualizada (testado na 42.21.0) e Mod ID
  duplicado removido — o jogo já acrescenta `Workshop ID` e `Mod ID` sozinho.
- Links para a página da Workshop no README e no LEIAME.

### Corrigido
- `preparar-workshop.sh` copia o `mod.info` também para a raiz da pasta do mod; sem
  isso o envio à Workshop falhava ("missing a mod.info file").

## [1.0.0] - 2026-10-16

Primeira versão pública.

### Adicionado
- Backup automático a cada 5 minutos enquanto o jogo está aberto, e backup final ao fechar.
- Backup manual pela tecla **F8** (mod) ou por atalho do sistema (`pz-backup.sh save`).
- Janela de restauração no jogo (**F9** ou *Opções → Mods*): o jogo fecha, restaura e reabre.
- Restauração automática ao morrer: contagem de 10 s, restaura o backup mais recente do
  mundo e reabre o jogo — é só clicar em *Continuar*. Desligável nas opções do mod.
- Proteção contra morte: nenhum backup é feito com o personagem morto.
- Remoção do save de personagem morto ao fechar o jogo (vai para `substituidos/`).
  Desligável nas opções do mod.
- Retenção: 10 backups por mundo e 5 saves substituídos.
- Log com a origem de cada ação: `[AUTO]`, `[MOD]`, `[MANUAL]`, `[FINAL]`, `[RESTAURO]`, `[LIMPEZA]`.
- Avisos sonoros (Linux: bipes gerados com Python; Windows: sons do sistema).
- Instaladores para Linux (Steam nativa e Flatpak) e Windows 10/11.
- Aviso no jogo, com o endereço do repositório, quando o script não está instalado.

[1.0.1]: https://github.com/ahlrodrigues/PZBackup/releases/tag/v1.0.1
[1.0.0]: https://github.com/ahlrodrigues/PZBackup/releases/tag/v1.0.0
