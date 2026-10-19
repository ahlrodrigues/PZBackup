--[[
  PZ Backup — mod strings in English (en) and Portuguese (pt)

  Language is chosen in Options > Mods > PZ Backup > Language:
  Automatic (follows the game's language, default), English or Portugues (pt-BR).
  Any game language other than Portuguese falls back to English. The strings have no accents
  because the game font may not have those characters.

  Usage: PZBackup.T("key", arg1, arg2...)  -> string.format with the arguments
]]

PZBackup = PZBackup or {}

local TEXTOS = {
    -- Options (Options > Mods > PZ Backup)
    opt_versao              = { pt = "PZ Backup - versao %s",
                                en = "PZ Backup - version %s" },
    opt_versao_dica         = { pt = "A versao do script aparece na janela do F9. Novidades e script: %s",
                                en = "The script's version shows in the F9 window. What's new and the script: %s" },
    opt_idioma              = { pt = "Idioma / Language",
                                en = "Language / Idioma" },
    opt_idioma_dica         = { pt = "Automatico segue o idioma do jogo (portugues ou, nos demais, ingles). Os nomes das opcoes mudam ao reiniciar o jogo.",
                                en = "Automatic follows the game's language (Portuguese, or English for any other). Option names switch after a game restart." },
    opt_idioma_auto         = { pt = "Automatico (idioma do jogo)",
                                en = "Automatic (game language)" },
    opt_idioma_en           = { pt = "English",
                                en = "English" },
    opt_idioma_pt           = { pt = "Portugues (pt-BR)",
                                en = "Portugues (pt-BR)" },
    opt_tecla_backup        = { pt = "Fazer backup agora",
                                en = "Back up now" },
    opt_tecla_backup_dica   = { pt = "Pede ao script uma copia do save, na hora",
                                en = "Asks the script for a copy of your save, right now" },
    opt_tecla_restaurar     = { pt = "Abrir janela de restauracao",
                                en = "Open the restore window" },
    opt_tecla_restaurar_dica= { pt = "Lista os backups e restaura o escolhido",
                                en = "Lists your backups and restores the one you pick" },
    opt_botao_restaurar     = { pt = "Restaurar backup...",
                                en = "Restore a backup..." },
    opt_botao_restaurar_dica= { pt = "Abre a lista de backups. O jogo fecha, restaura e reabre sozinho.",
                                en = "Opens the backup list. The game closes, restores and reopens by itself." },
    opt_botao_log           = { pt = "Ver log...",
                                en = "View log..." },
    opt_botao_log_dica      = { pt = "Mostra o que o PZ Backup andou fazendo (backups, restauracoes, erros)",
                                en = "Shows what PZ Backup has been up to (backups, restores, errors)" },
    opt_tecla_nota          = { pt = "Fazer backup com nota",
                                en = "Back up with a note" },
    opt_tecla_nota_dica     = { pt = "Pede um nome (ex.: antes do shopping) e faz o backup",
                                en = "Asks for a name (e.g. before the mall) and backs up" },
    opt_restaurar_auto      = { pt = "Ao morrer, restaurar o ultimo backup seguro automaticamente",
                                en = "On death, restore the last safe backup automatically" },
    opt_restaurar_auto_dica = { pt = "Conta 10 s, fecha o jogo, restaura o backup mais recente deste mundo que nao esteja mordido nem colado na morte, e reabre. Depois e so clicar em Continuar.",
                                en = "Counts 10 s, closes the game, restores this world's newest backup that isn't bitten or right before the death, and reopens. Then just click Continue." },
    opt_margem              = { pt = "Margem antes da morte",
                                en = "Margin before death" },
    opt_margem_dica         = { pt = "A restauracao automatica pula backups feitos ate este tempo antes de morrer (eles continuam na lista, em amarelo)",
                                en = "The auto-restore skips backups taken up to this long before dying (they stay in the list, in yellow)" },
    opt_margem_off          = { pt = "Desligada",
                                en = "Off" },
    opt_margem_seg          = { pt = "%d segundos",
                                en = "%d seconds" },
    opt_margem_min          = { pt = "%d min",
                                en = "%d min" },
    opt_adiar_perigo        = { pt = "Adiar o backup automatico durante perigo",
                                en = "Postpone automatic backups while in danger" },
    opt_adiar_perigo_dica   = { pt = "Com zumbis perseguindo ou muito perto, panico alto, sangramento, fogo ou pouca saude, o backup automatico espera a situacao acalmar. O F8 sempre funciona.",
                                en = "With zombies chasing or very close, high panic, bleeding, fire or low health, the automatic backup waits until things calm down. F8 always works." },
    opt_apagar_mortos       = { pt = "Remover saves de personagem morto ao fechar o jogo",
                                en = "Remove dead-character saves when the game closes" },
    opt_apagar_mortos_dica  = { pt = "O save onde o personagem morreu sai da lista Carregar (vai para BackupsSaves/replaced)",
                                en = "The save where your character died leaves the Load list (moved to BackupsSaves/replaced)" },

    -- Messages about the character
    msg_morto_bloqueado     = { pt = "Personagem morto: backup bloqueado. F9 restaura um backup",
                                en = "Character is dead: backup blocked. F9 restores a backup" },
    msg_script_parado       = { pt = "Script de backup nao esta rodando. Instale: %s",
                                en = "Backup script is not running. Get it at: %s" },
    msg_script_nao_detectado= { pt = "PZ Backup: script nao detectado. Instale: %s",
                                en = "PZ Backup: script not found. Get it at: %s" },
    msg_versoes_diferentes  = { pt = "PZ Backup: mod %s, script %s. Atualize o script: %s",
                                en = "PZ Backup: mod %s, script %s. Update the script: %s" },
    msg_backup_solicitado   = { pt = "Backup solicitado...",
                                en = "Backup requested..." },
    msg_falha_pedido        = { pt = "PZ Backup: falha ao gravar o pedido",
                                en = "PZ Backup: could not write the request" },
    msg_morto_sem_script    = { pt = "Morto. Script de backup parado: sem restauracao automatica",
                                en = "Dead. Backup script is not running: no auto-restore" },
    msg_morto_sem_backup    = { pt = "Morto. Nao ha backup deste mundo para restaurar",
                                en = "Dead. There is no backup of this world to restore" },
    msg_morto_sera_removido = { pt = "Morto. Ao fechar o jogo este save sera removido. F9 restaura um backup",
                                en = "Dead. This save will be removed when the game closes. F9 restores a backup" },
    msg_morto_f9            = { pt = "PZ Backup: aperte F9 para restaurar um backup",
                                en = "PZ Backup: press F9 to restore a backup" },

    -- Auto-restore panel
    auto_titulo             = { pt = "Personagem morto",
                                en = "You died" },
    auto_contagem           = { pt = "Restaurando o ultimo backup seguro deste mundo em %d s.",
                                en = "Restoring this world's last safe backup in %d s." },
    auto_explica            = { pt = "O jogo fecha, restaura e reabre: depois clique em Continuar.",
                                en = "The game closes, restores and reopens: then click Continue." },
    auto_fechando           = { pt = "Fechando o jogo para restaurar...",
                                en = "Closing the game to restore..." },
    auto_btn_agora          = { pt = "Restaurar agora",
                                en = "Restore now" },
    auto_btn_outro          = { pt = "Escolher outro",
                                en = "Choose another" },
    auto_btn_cancelar       = { pt = "Cancelar",
                                en = "Cancel" },
    auto_cancelado          = { pt = "Restauracao automatica cancelada. F9 abre a lista de backups",
                                en = "Auto-restore cancelled. F9 opens the backup list" },
    auto_sem_script         = { pt = "Script de backup nao esta rodando: restauracao cancelada",
                                en = "Backup script is not running: restore cancelled" },
    falha_pedido_restauro   = { pt = "Falha ao gravar o pedido de restauracao",
                                en = "Could not write the restore request" },

    -- Restore window
    jan_titulo              = { pt = "PZ Backup - Restaurar backup",
                                en = "PZ Backup - Restore a backup" },
    jan_btn_restaurar       = { pt = "Restaurar",
                                en = "Restore" },
    jan_btn_atualizar       = { pt = "Atualizar",
                                en = "Refresh" },
    jan_btn_log             = { pt = "Ver log",
                                en = "View log" },
    jan_btn_fechar          = { pt = "Fechar",
                                en = "Close" },
    jan_nenhum              = { pt = "Nenhum backup encontrado.",
                                en = "No backups found." },
    jan_dica                = { pt = "1 = mais recente. Prefira os verdes: de antes do perigo.",
                                en = "1 = most recent. Prefer the green ones: from before things went wrong." },
    jan_selecione           = { pt = "Selecione um backup na lista.",
                                en = "Select a backup from the list." },
    jan_script_parado       = { pt = "Script de backup nao esta rodando. Abra o jogo pela Steam/atalho com o PZ Backup.",
                                en = "Backup script is not running. Start the game through Steam/the PZ Backup shortcut." },
    jan_versoes             = { pt = "mod %s | script %s",
                                en = "mod %s | script %s" },
    jan_btn_nota            = { pt = "Nota",
                                en = "Note" },
    nota_titulo_backup      = { pt = "Nota deste backup (ex.: antes do shopping):",
                                en = "Note for this backup (e.g. before the mall):" },
    nota_titulo_editar      = { pt = "Nota do backup (vazio = remover):",
                                en = "Backup note (empty = remove):" },
    jan_nota_salva          = { pt = "Salvando a nota...",
                                en = "Saving the note..." },
    jan_nota_removida       = { pt = "Removendo a nota...",
                                en = "Removing the note..." },
    jan_det_nota            = { pt = "Nota: %s",
                                en = "Note: %s" },
    jan_det_perigo          = { pt = "Perigo na hora do backup: %s",
                                en = "Danger when backed up: %s" },
    jan_det_morte           = { pt = "Feito %s s antes de uma morte",
                                en = "Taken %s s before a death" },
    jan_det_pulado_auto     = { pt = "A restauracao automatica pula este backup (escolha manual ainda funciona)",
                                en = "The auto-restore skips this backup (picking it by hand still works)" },
    jan_confirmar_mordido   = { pt = "CUIDADO: o personagem ja estava MORDIDO neste backup. A infeccao continua apos restaurar.",
                                en = "CAREFUL: the character was already BITTEN in this backup. The infection stays after restoring." },
    jan_confirmar_morte     = { pt = "CUIDADO: este backup foi feito %s s antes de uma morte.",
                                en = "CAREFUL: this backup was taken %s s before a death." },
    perigo_zumbis           = { pt = "zumbis perto",
                                en = "zombies close" },
    perigo_panico           = { pt = "panico alto",
                                en = "high panic" },
    perigo_sangrando        = { pt = "sangrando",
                                en = "bleeding" },
    perigo_fogo             = { pt = "pegando fogo",
                                en = "on fire" },
    perigo_saude            = { pt = "pouca saude",
                                en = "low health" },
    jan_det_integridade     = { pt = "VERIFICACAO FALHOU: a copia pode estar incompleta. Prefira outro backup.",
                                en = "VERIFICATION FAILED: the copy may be incomplete. Prefer another backup." },
    jan_det_backup          = { pt = "Backup: %s",
                                en = "Backup: %s" },
    jan_det_tamanho         = { pt = "%s MB (%s MB novos)",
                                en = "%s MB (%s MB new)" },
    orig_AUTO               = { pt = "automatico",
                                en = "automatic" },
    orig_MOD                = { pt = "tecla no jogo",
                                en = "in-game key" },
    orig_MANUAL             = { pt = "manual (terminal/atalho)",
                                en = "manual (terminal/shortcut)" },
    orig_FINAL              = { pt = "final, ao fechar o jogo",
                                en = "final, when the game closed" },
    orig_ATUALIZACAO        = { pt = "antes de atualizacao do jogo",
                                en = "before a game update" },
    leg_mordido             = { pt = "Mordido",
                                en = "Bitten" },
    leg_perigo              = { pt = "Perigo / perto da morte",
                                en = "Danger / close to death" },
    leg_normal              = { pt = "Normal",
                                en = "Normal" },
    leg_sem                 = { pt = "Sem detalhes",
                                en = "No details" },
    jan_btn_fixar           = { pt = "Fixar",
                                en = "Pin" },
    jan_btn_desafixar       = { pt = "Desafixar",
                                en = "Unpin" },
    jan_tag_fixo            = { pt = "[FIXO]",
                                en = "[PIN]" },
    jan_fixando             = { pt = "Fixando... backups fixados nunca sao apagados pela rotacao.",
                                en = "Pinning... pinned backups are never removed by the rotation." },
    jan_desafixando         = { pt = "Desafixando... o backup volta para a rotacao.",
                                en = "Unpinning... the backup goes back into the rotation." },
    jan_fixado_info         = { pt = "Fixado: nunca sera apagado",
                                en = "Pinned: never removed" },
    jan_sem_detalhes        = { pt = "Sem detalhes (backup de versao anterior ou sem o mod ativo).",
                                en = "No details (made by an older version or without the mod)." },
    jan_det_personagem      = { pt = "Personagem: %s",
                                en = "Character: %s" },
    jan_det_dias            = { pt = "Dias vivo: %s",
                                en = "Days survived: %s" },
    jan_det_mortes          = { pt = "Zumbis mortos: %s",
                                en = "Zombie kills: %s" },
    jan_det_data            = { pt = "Data no jogo: %s",
                                en = "In-game date: %s" },
    jan_det_saude           = { pt = "Saude: %s%%",
                                en = "Health: %s%%" },
    jan_det_mordidas        = { pt = "Mordidas: %s",
                                en = "Bites: %s" },
    jan_det_arranhoes       = { pt = "Arranhoes: %s",
                                en = "Scratches: %s" },
    jan_det_laceracoes      = { pt = "Laceracoes: %s",
                                en = "Lacerations: %s" },
    jan_det_mordido         = { pt = "MORDIDO!",
                                en = "BITTEN!" },
    jan_det_local           = { pt = "Local:",
                                en = "Location:" },
    jan_det_cidade          = { pt = "%s (aprox.)",
                                en = "%s (approx.)" },
    jan_det_coord           = { pt = "x %s, y %s, andar %s",
                                en = "x %s, y %s, floor %s" },
    jan_amb_dentro          = { pt = "dentro de construcao",
                                en = "indoors" },
    jan_amb_fora            = { pt = "ao ar livre",
                                en = "outdoors" },
    jan_amb_veiculo         = { pt = "em um veiculo",
                                en = "in a vehicle" },
    jan_det_fome            = { pt = "Fome: %s%%",
                                en = "Hunger: %s%%" },
    jan_det_sede            = { pt = "Sede: %s%%",
                                en = "Thirst: %s%%" },
    jan_det_cansaco         = { pt = "Cansaco: %s%%",
                                en = "Tiredness: %s%%" },
    jan_det_panico          = { pt = "Panico: %s%%",
                                en = "Panic: %s%%" },
    jan_det_habilidades     = { pt = "Melhores: %s",
                                en = "Best skills: %s" },
    jan_det_forca           = { pt = "Forca %s",
                                en = "Strength %s" },
    jan_det_condicionamento = { pt = "Cond. fisico %s",
                                en = "Fitness %s" },
    jan_det_peso            = { pt = "Peso %s kg",
                                en = "Weight %s kg" },
    jan_mods_iguais         = { pt = "Mods: iguais aos ativos agora",
                                en = "Mods: same as the ones active now" },
    jan_mods_diferentes     = { pt = "Mods diferentes de agora: %d so no backup, %d so agora",
                                en = "Mods differ from now: %d only in the backup, %d only now" },
    jan_confirmar_mods      = { pt = "ATENCAO, os mods deste backup sao diferentes dos ativos agora:",
                                en = "HEADS UP, this backup's mods differ from the ones active now:" },
    jan_mods_so_backup      = { pt = "So no backup (reative se precisar): %s",
                                en = "Only in the backup (re-enable if needed): %s" },
    jan_mods_so_agora       = { pt = "So agora (o save restaurado pode nao te-los): %s",
                                en = "Only now (the restored save may not have them): %s" },
    jan_confirmar           = { pt = "Restaurar o backup:\n%s\n\nO jogo vai FECHAR, o backup sera restaurado e o jogo REABRE sozinho.\nO progresso desde esse backup sera perdido (fica guardado em 'replaced').\n\nDEPOIS: ao carregar, confira os mods do save (Carregar > Mods).\nReative o PZ Backup e os mods que usa; desative os que nao quiser.",
                                en = "Restore this backup:\n%s\n\nThe game will CLOSE, the backup will be restored and the game REOPENS by itself.\nProgress made since this backup will be lost (kept in 'replaced').\n\nAFTERWARDS: when loading, check the save's mods (Load > Mods).\nRe-enable PZ Backup and your mods; disable the ones you don't want." },

    -- Log window
    log_titulo              = { pt = "PZ Backup - Log",
                                en = "PZ Backup - Log" },
    log_vazio               = { pt = "Log vazio. O script ainda nao registrou nada (ou nao esta rodando).",
                                en = "Log is empty. The script hasn't logged anything yet (or isn't running)." },
    log_rodape              = { pt = "Ultimas %d linhas, mais recentes no topo. Completo em BackupsSaves/pz-backup.log",
                                en = "Last %d lines, newest first. Full log in BackupsSaves/pz-backup.log" },
}

-- Language: Options > Mods > PZ Backup > Language
--   1 = Automatic (game language), 2 = English, 3 = Portugues (pt-BR)
-- (PZBackup.opcaoIdioma is created in client/PZBackup.lua)
PZBackup.IDIOMA_AUTO, PZBackup.IDIOMA_EN, PZBackup.IDIOMA_PT = 1, 2, 3

-- Game language: exact code PT or PTBR = Portuguese; anything else = English
function PZBackup.idiomaDoJogo()
    local codigo = nil
    pcall(function() codigo = Translator.getLanguage():name() end)
    if not codigo then
        pcall(function() codigo = getCore():getOptionLanguageName() end)
    end
    codigo = string.upper(tostring(codigo or ""))
    if codigo == "PT" or codigo == "PTBR" then return "pt" end
    return "en"
end

function PZBackup.idioma()
    if PZBackup.opcaoIdioma then
        local ok, v = pcall(function() return PZBackup.opcaoIdioma:getValue() end)
        if ok then
            if v == PZBackup.IDIOMA_EN then return "en" end
            if v == PZBackup.IDIOMA_PT then return "pt" end
        end
    end
    return PZBackup.idiomaDoJogo()       -- Automatic (default)
end

function PZBackup.T(chave, ...)
    local t = TEXTOS[chave]
    if not t then return chave end
    local s = t[PZBackup.idioma()] or t.en or chave
    if select("#", ...) > 0 then
        local ok, r = pcall(string.format, s, ...)
        if ok then return r end
    end
    return s
end
