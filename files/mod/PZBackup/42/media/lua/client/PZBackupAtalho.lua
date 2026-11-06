--[[
  PZ Backup — quick-restore entries in the game's Load list

  While the game is closed, the script copies a few older backups of each recent
  world into the Saves folder as "<world>-BACKUP-5min", "-10min", "-1h", "-1d"
  (listed in pzbackup_atalhos.txt). They show up in Load like any save, but they
  aren't meant to be played: loading one asks to restore that backup into the
  original world (the game closes, restores and reopens, as with F9).
]]

require "ISUI/ISModalDialog"

-- "Survivor__World__2026-10-14_14-35-07" -> "14/10 14:35"
local function horaDoNome(nome)
    local m, d, h, mi = tostring(nome):match(".*__%d%d%d%d%-(%d%d)%-(%d%d)_(%d%d)%-(%d%d)")
    if not m then return "?" end
    return d .. "/" .. m .. " " .. h .. ":" .. mi
end

local function aoResponder(_, botao, nome)
    if botao.internal ~= "YES" then
        PZBackup.mostrar(PZBackup.T("atalho_jogando"), true)
        return
    end
    if not PZBackup.scriptAtivo() then
        PZBackup.mostrar(PZBackup.T("auto_sem_script"), true)
        return
    end
    if not PZBackup.gravar(PZBackup.ARQ_RESTAURAR, nome .. "\n") then
        PZBackup.mostrar(PZBackup.T("falha_pedido_restauro"), true)
        return
    end
    print("[PZBackup] restore requested from the Load list: " .. tostring(nome))
    PZBackup.fecharJogo()
end

local function aoIniciar()
    local nome, salto = PZBackup.atalhoAtual()
    if not nome then return end
    print("[PZBackup] Load-list entry of backup " .. nome)
    local quanto = PZBackup.T("salto_" .. tostring(salto))
    if quanto == "salto_" .. tostring(salto) then quanto = tostring(salto) end
    local texto = PZBackup.T("atalho_dialogo", quanto, horaDoNome(nome))
    local altura = 300
    if PZBackup.classificar(PZBackup.lerDetalhes()[nome]) == "mordido" then
        texto = texto .. "\n\n" .. PZBackup.T("jan_confirmar_mordido"); altura = altura + 40
    end
    local dlg = ISModalDialog:new(
        (getCore():getScreenWidth() - 600) / 2, (getCore():getScreenHeight() - altura) / 2,
        600, altura, texto, true, PZBackup, aoResponder, nil, nome)
    dlg:initialise()
    dlg:addToUIManager()
    dlg:setAlwaysOnTop(true)
end

Events.OnGameStart.Add(aoIniciar)
