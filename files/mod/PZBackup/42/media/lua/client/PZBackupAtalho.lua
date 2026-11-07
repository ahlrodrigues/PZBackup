--[[
  PZ Backup — quick-restore entries in the game's Load list

  While the game is closed, the script copies a few older backups of each recent
  world into the Saves folder as "<world>-BACKUP-5min", "-10min", "-1h", "-1d"
  (listed in pzbackup_atalhos.txt).

  v1.6: loading one simply plays that moment — no question, no restart.
  The entry counts as the original world (PZBackup.mundoAtual): backups taken
  while playing it go to the original world's list, and when the game closes
  the script makes it the original world (the old one is kept in 'replaced').
]]

-- "Survivor__World__2026-10-14_14-35-07" -> "14/10 14:35"
local function horaDoNome(nome)
    local m, d, h, mi = tostring(nome):match(".*__%d%d%d%d%-(%d%d)%-(%d%d)_(%d%d)%-(%d%d)")
    if not m then return "?" end
    return d .. "/" .. m .. " " .. h .. ":" .. mi
end

local function aoIniciar()
    local nome, salto, original = PZBackup.atalhoAtual()
    if not nome then return end
    print("[PZBackup] playing Load-list entry of backup " .. nome .. " (world " .. tostring(original) .. ")")
    local quanto = PZBackup.T("salto_" .. tostring(salto))
    if quanto == "salto_" .. tostring(salto) then quanto = tostring(salto) end
    local mundo = tostring(original or ""):match("^[^/]*/(.*)$") or "?"
    PZBackup.mostrar(PZBackup.T("atalho_carregado", quanto, horaDoNome(nome), mundo), false)
end

Events.OnGameStart.Add(aoIniciar)
