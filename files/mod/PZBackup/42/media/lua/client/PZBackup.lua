--[[
  PZ Backup — bridge between the game and the pz-backup script (Linux .sh / Windows .ps1)

  Project Zomboid's Lua can't copy folders, so the mod only exchanges
  messages with the script through files in Zomboid/Lua/
  (file names stay in Portuguese for compatibility with older versions):

    pzbackup_pedido.txt     (mod -> script)  manual backup request
    pzbackup_restaurar.txt  (mod -> script)  backup to restore when the game closes
    pzbackup_estado.txt     (mod -> script)  "vivo" (alive) or "morto" (dead) + line 2: mode/world
    pzbackup_config.txt     (mod -> script)  options the script uses (apagar_mortos=1/0, idioma=pt/en)
    pzbackup_status.txt     (script -> mod)  result of each action, shown on screen
    pzbackup_lista.txt      (script -> mod)  available backups: name|label
    pzbackup_ativo.txt      (script -> mod)  Unix time of the script's last heartbeat

  The script must be running in "game" mode.
]]

PZBackup = PZBackup or {}

PZBackup.ARQ_PEDIDO    = "pzbackup_pedido.txt"
PZBackup.ARQ_RESTAURAR = "pzbackup_restaurar.txt"
PZBackup.ARQ_ESTADO    = "pzbackup_estado.txt"
PZBackup.ARQ_STATUS    = "pzbackup_status.txt"
PZBackup.ARQ_LISTA     = "pzbackup_lista.txt"
PZBackup.ARQ_ATIVO     = "pzbackup_ativo.txt"
PZBackup.ARQ_CONFIG    = "pzbackup_config.txt"
PZBackup.URL           = "github.com/ahlrodrigues/PZBackup"   -- where to get the script

local TECLA_BACKUP_PADRAO    = Keyboard.KEY_F8
local TECLA_RESTAURAR_PADRAO = Keyboard.KEY_F9
local INTERVALO_LEITURA = 30   -- ticks between status reads (~0.5 s)

local opcaoBackup, opcaoRestaurar, opcaoApagarMortos, opcaoRestaurarAuto = nil, nil, nil, nil
local APAGAR_MORTOS_PADRAO = true
local RESTAURAR_AUTO_PADRAO = true
PZBackup.SEGUNDOS_AUTO = 10          -- countdown before closing the game and restoring
local ultimoStatusId = nil
local contadorTicks = 0

------------------------------------------------------------------------
-- Files (always inside Zomboid/Lua/)
------------------------------------------------------------------------
function PZBackup.gravar(arquivo, texto)
    local ok = pcall(function()
        local w = getFileWriter(arquivo, true, false)
        w:write(texto)
        w:close()
    end)
    return ok
end

function PZBackup.lerLinhas(arquivo)
    local linhas = {}
    pcall(function()
        local r = getFileReader(arquivo, false)
        if not r then return end
        local l = r:readLine()
        while l do
            if l ~= "" then table.insert(linhas, l) end
            l = r:readLine()
        end
        r:close()
    end)
    return linhas
end

-- The script writes the time every second; if the heartbeat is older than
-- 30 s, it isn't running (game started without "game" mode).
function PZBackup.scriptAtivo()
    local l = PZBackup.lerLinhas(PZBackup.ARQ_ATIVO)[1]
    local ts = tonumber(l or "")
    if not ts then return false end
    local agora = getTimestamp()
    if agora > 100000000000 then agora = agora / 1000 end   -- in case it comes in ms
    return math.abs(agora - ts) < 30
end

------------------------------------------------------------------------
-- On-screen messages (above the character's head)
------------------------------------------------------------------------
function PZBackup.mostrar(texto, erro)
    local p = getPlayer()
    if not p then return end
    local r, g, b = 80, 255, 120
    if erro then r, g, b = 255, 80, 80 end
    local ok = pcall(function() p:setHaloNote(texto, r, g, b, 300) end)
    if not ok then pcall(function() p:Say(texto) end) end
end

------------------------------------------------------------------------
-- Mod options (B42): Options > Mods > PZ Backup
------------------------------------------------------------------------
local function criarOpcoes()
    if not (PZAPI and PZAPI.ModOptions) then
        print("[PZBackup] PZAPI.ModOptions not available - using default keys F8/F9")
        return
    end
    local ok, opcoes = pcall(function()
        return PZAPI.ModOptions:create("PZBackupAHLR", "PZ Backup")
    end)
    if not (ok and opcoes) then
        print("[PZBackup] failed to create options: " .. tostring(opcoes))
        return
    end
    local function tentar(nome, f)
        local ok2, r = pcall(f)
        if not ok2 then print("[PZBackup] option '" .. nome .. "' failed: " .. tostring(r)) end
        return ok2 and r or nil
    end
    -- Language: Automatic (game language, default) / English / Portugues (pt-BR)
    -- Item order must match PZBackup.IDIOMA_AUTO / _EN / _PT (shared/PZBackup_Strings.lua)
    PZBackup.opcaoIdioma = tentar("idioma", function()
        local combo = opcoes:addComboBox("idioma", PZBackup.T("opt_idioma"), PZBackup.T("opt_idioma_dica"))
        combo:addItem(PZBackup.T("opt_idioma_auto"), true)
        combo:addItem(PZBackup.T("opt_idioma_en"), false)
        combo:addItem(PZBackup.T("opt_idioma_pt"), false)
        return combo
    end)
    opcaoBackup = tentar("teclaBackup", function()
        return opcoes:addKeyBind("teclaBackup", PZBackup.T("opt_tecla_backup"), TECLA_BACKUP_PADRAO,
            PZBackup.T("opt_tecla_backup_dica"))
    end)
    opcaoRestaurar = tentar("teclaRestaurar", function()
        return opcoes:addKeyBind("teclaRestaurar", PZBackup.T("opt_tecla_restaurar"), TECLA_RESTAURAR_PADRAO,
            PZBackup.T("opt_tecla_restaurar_dica"))
    end)
    tentar("botaoRestaurar", function()
        return opcoes:addButton("botaoRestaurar", PZBackup.T("opt_botao_restaurar"),
            PZBackup.T("opt_botao_restaurar_dica"),
            function() if PZBackup.abrirJanela then PZBackup.abrirJanela() end end)
    end)
    tentar("botaoLog", function()
        return opcoes:addButton("botaoLog", PZBackup.T("opt_botao_log"),
            PZBackup.T("opt_botao_log_dica"),
            function() if PZBackup.abrirLog then PZBackup.abrirLog() end end)
    end)
    opcaoRestaurarAuto = tentar("restaurarAuto", function()
        return opcoes:addTickBox("restaurarAuto", PZBackup.T("opt_restaurar_auto"),
            RESTAURAR_AUTO_PADRAO, PZBackup.T("opt_restaurar_auto_dica"))
    end)
    opcaoApagarMortos = tentar("apagarMortos", function()
        return opcoes:addTickBox("apagarMortos", PZBackup.T("opt_apagar_mortos"),
            APAGAR_MORTOS_PADRAO, PZBackup.T("opt_apagar_mortos_dica"))
    end)
    -- Called when the player applies the options
    pcall(function()
        opcoes.apply = function() PZBackup.salvarConfig() end
    end)
end

-- Writes the options the script needs to know
function PZBackup.apagarMortos()
    if opcaoApagarMortos then
        local ok, v = pcall(function() return opcaoApagarMortos:getValue() end)
        if ok and v ~= nil then return v == true end
    end
    return APAGAR_MORTOS_PADRAO
end

function PZBackup.restaurarAuto()
    if opcaoRestaurarAuto then
        local ok, v = pcall(function() return opcaoRestaurarAuto:getValue() end)
        if ok and v ~= nil then return v == true end
    end
    return RESTAURAR_AUTO_PADRAO
end

function PZBackup.salvarConfig()
    PZBackup.gravar(PZBackup.ARQ_CONFIG,
        "apagar_mortos=" .. (PZBackup.apagarMortos() and "1" or "0") .. "\n" ..
        "idioma=" .. PZBackup.idioma() .. "\n")
end

criarOpcoes()

local function tecla(opcao, padrao)
    if opcao then
        local ok, v = pcall(function() return opcao:getValue() end)
        if ok and v and v ~= 0 then return v end
    end
    return padrao
end

------------------------------------------------------------------------
-- Keys
------------------------------------------------------------------------
local function pedirBackup()
    local p = getPlayer()
    if not p then return end
    if p:isDead() then
        PZBackup.mostrar(PZBackup.T("msg_morto_bloqueado"), true)
        return
    end
    if not PZBackup.scriptAtivo() then
        PZBackup.mostrar(PZBackup.T("msg_script_parado", PZBackup.URL), true)
        return
    end
    if PZBackup.gravar(PZBackup.ARQ_PEDIDO, "save " .. tostring(getTimestamp()) .. "\n") then
        PZBackup.mostrar(PZBackup.T("msg_backup_solicitado"), false)
    else
        PZBackup.mostrar(PZBackup.T("msg_falha_pedido"), true)
    end
end

local function aoPressionarTecla(k)
    if k == tecla(opcaoBackup, TECLA_BACKUP_PADRAO) then
        pedirBackup()
    elseif k == tecla(opcaoRestaurar, TECLA_RESTAURAR_PADRAO) then
        -- F9 during the auto countdown: cancels it and opens the list
        if PZBackup.painelAuto then PZBackup.painelAuto:fechar() end
        if PZBackup.abrirJanela then PZBackup.abrirJanela() end
    end
end

------------------------------------------------------------------------
-- Character state (the script doesn't back up while "morto"/dead)
------------------------------------------------------------------------
-- "mode/world" of the loaded save (same layout as Saves/<mode>/<world>)
function PZBackup.mundoAtual()
    local modo, mundo = "", ""
    pcall(function() modo = tostring(getWorld():getGameMode() or "") end)
    pcall(function() mundo = tostring(getWorld():getWorld() or "") end)
    return modo .. "/" .. mundo
end

local mundoAtual = PZBackup.mundoAtual

-- Is there a backup of this world in the script's list?
function PZBackup.temBackupDoMundo(modoMundo)
    local modo, mundo = modoMundo:match("^([^/]*)/(.*)$")
    if not mundo or mundo == "" then return false end
    local prefixo = modo .. "__" .. mundo .. "__"
    for _, linha in ipairs(PZBackup.lerLinhas(PZBackup.ARQ_LISTA)) do
        if linha:sub(1, #prefixo) == prefixo then return true end
    end
    return false
end

local function marcarVivo()
    local p = getPlayer()
    if not p or p:isDead() then return end
    PZBackup.gravar(PZBackup.ARQ_ESTADO, "vivo\n" .. mundoAtual() .. "\n")
end

-- New character created in the same world after dying: back to "vivo" (alive)
local function aoCriarPersonagem(_, jogador)
    local p = jogador or getPlayer()
    if p and p == getPlayer() and not p:isDead() then marcarVivo() end
end

local function aoMorrer(jogador)
    if jogador == getPlayer() then
        local mm = mundoAtual()
        PZBackup.gravar(PZBackup.ARQ_ESTADO, "morto\n" .. mm .. "\n")
        if PZBackup.restaurarAuto() and PZBackup.scriptAtivo() and PZBackup.temBackupDoMundo(mm)
           and PZBackup.iniciarRestauracaoAuto then
            PZBackup.iniciarRestauracaoAuto(mm)
        elseif not PZBackup.scriptAtivo() then
            PZBackup.mostrar(PZBackup.T("msg_morto_sem_script"), true)
        elseif PZBackup.restaurarAuto() and not PZBackup.temBackupDoMundo(mm) then
            PZBackup.mostrar(PZBackup.T("msg_morto_sem_backup"), true)
        elseif PZBackup.apagarMortos() then
            PZBackup.mostrar(PZBackup.T("msg_morto_sera_removido"), true)
        else
            PZBackup.mostrar(PZBackup.T("msg_morto_f9"), true)
        end
    end
end

------------------------------------------------------------------------
-- Reads the result written by the script and shows it on screen
-- Format: <id>|<ok|erro>|<message>
------------------------------------------------------------------------
local function lerStatus()
    contadorTicks = contadorTicks + 1
    if contadorTicks < INTERVALO_LEITURA then return end
    contadorTicks = 0

    local linha = PZBackup.lerLinhas(PZBackup.ARQ_STATUS)[1]
    if not linha then return end
    local id, tipo, msg = linha:match("^([^|]+)|([^|]+)|(.*)$")
    if not id or id == ultimoStatusId then return end

    local primeiraLeitura = (ultimoStatusId == nil)
    ultimoStatusId = id
    if primeiraLeitura then return end   -- don't repeat an old message when the game loads
    PZBackup.mostrar(msg, tipo == "erro")
end

------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------
Events.OnGameStart.Add(marcarVivo)
Events.OnGameStart.Add(PZBackup.salvarConfig)
Events.OnGameStart.Add(function()
    print("[PZBackup] language: " .. PZBackup.idioma() .. " (game: " .. PZBackup.idiomaDoJogo() .. ")")
end)
-- Players who only installed the mod (e.g. from the Workshop) learn the script is missing
Events.OnGameStart.Add(function()
    if not PZBackup.scriptAtivo() then
        print("[PZBackup] backup script not detected. Get it at: https://" .. PZBackup.URL)
        PZBackup.mostrar(PZBackup.T("msg_script_nao_detectado", PZBackup.URL), true)
    end
end)
if Events.OnMainMenuEnter then Events.OnMainMenuEnter.Add(PZBackup.salvarConfig) end
if Events.OnCreatePlayer then Events.OnCreatePlayer.Add(aoCriarPersonagem) end
Events.OnKeyPressed.Add(aoPressionarTecla)
Events.OnPlayerDeath.Add(aoMorrer)
Events.OnTick.Add(lerStatus)

print("[PZBackup] loaded - backup key: " .. tostring(Keyboard.getKeyName(tecla(opcaoBackup, TECLA_BACKUP_PADRAO)))
    .. ", restore key: " .. tostring(Keyboard.getKeyName(tecla(opcaoRestaurar, TECLA_RESTAURAR_PADRAO))))
