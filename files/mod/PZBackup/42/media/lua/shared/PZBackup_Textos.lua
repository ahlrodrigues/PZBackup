--[[
  PZ Backup — textos do mod em português (pt) e inglês (en)

  O idioma segue o do jogo: português se o jogo estiver em PT/PTBR, inglês
  em qualquer outro. Os textos não têm acento porque a fonte do jogo pode não
  ter os caracteres.

  Uso: PZBackup.T("chave", arg1, arg2...)  -> string.format com os argumentos
]]

PZBackup = PZBackup or {}

local TEXTOS = {
    -- Opções (Opções > Mods > PZ Backup)
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
    opt_restaurar_auto      = { pt = "Ao morrer, restaurar o backup mais recente automaticamente",
                                en = "On death, restore the latest backup automatically" },
    opt_restaurar_auto_dica = { pt = "Conta 10 s, fecha o jogo, restaura o backup mais recente deste mundo e reabre. Depois e so clicar em Continuar.",
                                en = "Counts 10 s, closes the game, restores this world's latest backup and reopens. Then just click Continue." },
    opt_apagar_mortos       = { pt = "Remover saves de personagem morto ao fechar o jogo",
                                en = "Remove dead-character saves when the game closes" },
    opt_apagar_mortos_dica  = { pt = "O save onde o personagem morreu sai da lista Carregar (vai para BackupsSaves/substituidos)",
                                en = "The save where your character died leaves the Load list (moved to BackupsSaves/substituidos)" },

    -- Mensagens sobre o personagem
    msg_morto_bloqueado     = { pt = "Personagem morto: backup bloqueado. F9 restaura um backup",
                                en = "Character is dead: backup blocked. F9 restores a backup" },
    msg_script_parado       = { pt = "Script de backup nao esta rodando. Instale: %s",
                                en = "Backup script is not running. Get it at: %s" },
    msg_script_nao_detectado= { pt = "PZ Backup: script nao detectado. Instale: %s",
                                en = "PZ Backup: script not found. Get it at: %s" },
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

    -- Painel de restauração automática
    auto_titulo             = { pt = "Personagem morto",
                                en = "You died" },
    auto_contagem           = { pt = "Restaurando o backup mais recente deste mundo em %d s.",
                                en = "Restoring this world's latest backup in %d s." },
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

    -- Janela de restauração
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
    jan_dica                = { pt = "1 = mais recente. Escolha um backup de antes do perigo.",
                                en = "1 = most recent. Pick one from before things went wrong." },
    jan_selecione           = { pt = "Selecione um backup na lista.",
                                en = "Select a backup from the list." },
    jan_script_parado       = { pt = "Script de backup nao esta rodando. Abra o jogo pela Steam/atalho com o PZ Backup.",
                                en = "Backup script is not running. Start the game through Steam/the PZ Backup shortcut." },
    jan_confirmar           = { pt = "Restaurar o backup:\n%s\n\nO jogo vai FECHAR, o backup sera restaurado e o jogo REABRE sozinho.\nO progresso desde esse backup sera perdido (fica guardado em 'substituidos').\n\nDEPOIS: ao carregar, confira os mods do save (Carregar > Mods).\nReative o PZ Backup e os mods que usa; desative os que nao quiser.",
                                en = "Restore this backup:\n%s\n\nThe game will CLOSE, the backup will be restored and the game REOPENS by itself.\nProgress made since this backup will be lost (kept in 'substituidos').\n\nAFTERWARDS: when loading, check the save's mods (Load > Mods).\nRe-enable PZ Backup and your mods; disable the ones you don't want." },

    -- Janela de log
    log_titulo              = { pt = "PZ Backup - Log",
                                en = "PZ Backup - Log" },
    log_vazio               = { pt = "Log vazio. O script ainda nao registrou nada (ou nao esta rodando).",
                                en = "Log is empty. The script hasn't logged anything yet (or isn't running)." },
    log_rodape              = { pt = "Ultimas %d linhas, mais recentes no topo. Completo em BackupsSaves/pz-backup.log",
                                en = "Last %d lines, newest first. Full log in BackupsSaves/pz-backup.log" },
}

-- Códigos de idioma do jogo que contam como português
local CODIGOS_PT = { PT = true, PTBR = true, ["PT_BR"] = true, ["PT-BR"] = true }

-- Código do idioma atual do jogo (ex.: "EN", "PTBR"), ou nil se não conseguir ler
local function codigoIdioma()
    local candidatos = {}
    -- Language:name() devolve o código ("EN", "PTBR"...)
    pcall(function() table.insert(candidatos, Translator.getLanguage():name()) end)
    pcall(function() table.insert(candidatos, getCore():getOptionLanguageName()) end)
    pcall(function() table.insert(candidatos, tostring(Translator.getLanguage())) end)
    for _, c in ipairs(candidatos) do
        if type(c) == "string" or type(c) == "userdata" then
            local s = string.upper(tostring(c))
            -- aceita só um código curto e limpo (2 a 5 letras), nunca um texto qualquer
            if s:match("^[A-Z][A-Z][A-Z_%-]?[A-Z]?[A-Z]?$") then return s, candidatos end
        end
    end
    return nil, candidatos
end

-- "pt" se o jogo estiver em português; "en" para qualquer outro idioma
function PZBackup.idioma()
    if PZBackup._idioma then return PZBackup._idioma end
    local codigo, candidatos = codigoIdioma()
    local idioma = (codigo and CODIGOS_PT[codigo]) and "pt" or "en"
    PZBackup._idioma = idioma
    local vistos = {}
    for _, c in ipairs(candidatos or {}) do table.insert(vistos, tostring(c)) end
    print("[PZBackup] idioma do jogo: " .. tostring(codigo) .. " -> textos em '" .. idioma ..
          "' (lido: " .. table.concat(vistos, " | ") .. ")")
    return idioma
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
