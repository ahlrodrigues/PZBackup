--[[
  PZ Backup — ponte entre o jogo e o script pz-backup (Linux .sh / Windows .ps1)

  O Lua do Project Zomboid não pode copiar pastas. Por isso o mod só
  troca mensagens com o script através de arquivos em Zomboid/Lua/:

    pzbackup_pedido.txt     (mod -> script)  pedido de backup manual
    pzbackup_restaurar.txt  (mod -> script)  nome do backup a restaurar ao fechar o jogo
    pzbackup_estado.txt     (mod -> script)  "vivo" ou "morto" + linha 2: modo/mundo
    pzbackup_config.txt     (mod -> script)  opções que o script usa (apagar_mortos=1/0)
    pzbackup_status.txt     (script -> mod)  resultado de cada ação, mostrado na tela
    pzbackup_lista.txt      (script -> mod)  backups disponíveis: nome|rótulo
    pzbackup_ativo.txt      (script -> mod)  hora (Unix) do último sinal de vida do script

  O script precisa estar rodando no modo "jogo".
]]

PZBackup = PZBackup or {}

PZBackup.ARQ_PEDIDO    = "pzbackup_pedido.txt"
PZBackup.ARQ_RESTAURAR = "pzbackup_restaurar.txt"
PZBackup.ARQ_ESTADO    = "pzbackup_estado.txt"
PZBackup.ARQ_STATUS    = "pzbackup_status.txt"
PZBackup.ARQ_LISTA     = "pzbackup_lista.txt"
PZBackup.ARQ_ATIVO     = "pzbackup_ativo.txt"
PZBackup.ARQ_CONFIG    = "pzbackup_config.txt"
PZBackup.URL           = "github.com/ahlrodrigues/PZBackup"   -- onde baixar o script

local TECLA_BACKUP_PADRAO    = Keyboard.KEY_F8
local TECLA_RESTAURAR_PADRAO = Keyboard.KEY_F9
local INTERVALO_LEITURA = 30   -- ticks entre leituras do status (~0,5 s)

local opcaoBackup, opcaoRestaurar, opcaoApagarMortos, opcaoRestaurarAuto = nil, nil, nil, nil
local APAGAR_MORTOS_PADRAO = true
local RESTAURAR_AUTO_PADRAO = true
PZBackup.SEGUNDOS_AUTO = 10          -- contagem antes de fechar o jogo e restaurar
local ultimoStatusId = nil
local contadorTicks = 0

------------------------------------------------------------------------
-- Arquivos (sempre dentro de Zomboid/Lua/)
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

-- O script escreve a hora a cada poucos segundos; se o sinal tiver mais
-- de 30 s, ele não está rodando (jogo aberto fora do modo "jogo").
function PZBackup.scriptAtivo()
    local l = PZBackup.lerLinhas(PZBackup.ARQ_ATIVO)[1]
    local ts = tonumber(l or "")
    if not ts then return false end
    local agora = getTimestamp()
    if agora > 100000000000 then agora = agora / 1000 end   -- caso venha em ms
    return math.abs(agora - ts) < 30
end

------------------------------------------------------------------------
-- Mensagens na tela (acima da cabeça do personagem)
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
-- Opções do mod (B42): Opções > Mods > PZ Backup
------------------------------------------------------------------------
local function criarOpcoes()
    if not (PZAPI and PZAPI.ModOptions) then
        print("[PZBackup] PZAPI.ModOptions indisponível — usando teclas padrão F8/F9")
        return
    end
    local ok, opcoes = pcall(function()
        return PZAPI.ModOptions:create("PZBackupAhlr", "PZ Backup")
    end)
    if not (ok and opcoes) then
        print("[PZBackup] falha ao criar opções: " .. tostring(opcoes))
        return
    end
    local function tentar(nome, f)
        local ok2, r = pcall(f)
        if not ok2 then print("[PZBackup] opcao '" .. nome .. "' falhou: " .. tostring(r)) end
        return ok2 and r or nil
    end
    opcaoBackup = tentar("teclaBackup", function()
        return opcoes:addKeyBind("teclaBackup", "Fazer backup agora", TECLA_BACKUP_PADRAO,
            "Pede ao script uma copia do save")
    end)
    opcaoRestaurar = tentar("teclaRestaurar", function()
        return opcoes:addKeyBind("teclaRestaurar", "Abrir janela de restauracao", TECLA_RESTAURAR_PADRAO,
            "Lista os backups e restaura o escolhido")
    end)
    tentar("botaoRestaurar", function()
        return opcoes:addButton("botaoRestaurar", "Restaurar backup...",
            "Abre a lista de backups. O jogo fecha, restaura e reabre sozinho.",
            function() if PZBackup.abrirJanela then PZBackup.abrirJanela() end end)
    end)
    opcaoRestaurarAuto = tentar("restaurarAuto", function()
        return opcoes:addTickBox("restaurarAuto", "Ao morrer, restaurar o backup mais recente automaticamente",
            RESTAURAR_AUTO_PADRAO,
            "Conta 10 s, fecha o jogo, restaura o backup mais recente deste mundo e reabre. Depois e so clicar em Continuar.")
    end)
    opcaoApagarMortos = tentar("apagarMortos", function()
        return opcoes:addTickBox("apagarMortos", "Remover saves de personagem morto ao fechar o jogo",
            APAGAR_MORTOS_PADRAO,
            "Ao fechar o jogo, o save onde o personagem morreu sai da lista Carregar (vai para BackupsSaves/substituidos)")
    end)
    -- Chamado quando o jogador aplica as opções
    pcall(function()
        opcoes.apply = function() PZBackup.salvarConfig() end
    end)
end

-- Grava as opções que o script precisa conhecer
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
        "apagar_mortos=" .. (PZBackup.apagarMortos() and "1" or "0") .. "\n")
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
-- Teclas
------------------------------------------------------------------------
local function pedirBackup()
    local p = getPlayer()
    if not p then return end
    if p:isDead() then
        PZBackup.mostrar("Personagem morto: backup bloqueado. Use F9 para restaurar", true)
        return
    end
    if not PZBackup.scriptAtivo() then
        PZBackup.mostrar("Script de backup nao esta rodando. Instale: " .. PZBackup.URL, true)
        return
    end
    if PZBackup.gravar(PZBackup.ARQ_PEDIDO, "save " .. tostring(getTimestamp()) .. "\n") then
        PZBackup.mostrar("Backup solicitado...", false)
    else
        PZBackup.mostrar("PZ Backup: falha ao gravar pedido", true)
    end
end

local function aoPressionarTecla(k)
    if k == tecla(opcaoBackup, TECLA_BACKUP_PADRAO) then
        pedirBackup()
    elseif k == tecla(opcaoRestaurar, TECLA_RESTAURAR_PADRAO) then
        -- F9 durante a contagem automática: cancela a contagem e abre a lista
        if PZBackup.painelAuto then PZBackup.painelAuto:fechar() end
        if PZBackup.abrirJanela then PZBackup.abrirJanela() end
    end
end

------------------------------------------------------------------------
-- Estado do personagem (o script não faz backup se estiver "morto")
------------------------------------------------------------------------
-- "modo/mundo" do save carregado (mesma estrutura da pasta Saves/<modo>/<mundo>)
function PZBackup.mundoAtual()
    local modo, mundo = "", ""
    pcall(function() modo = tostring(getWorld():getGameMode() or "") end)
    pcall(function() mundo = tostring(getWorld():getWorld() or "") end)
    return modo .. "/" .. mundo
end

local mundoAtual = PZBackup.mundoAtual

-- Existe backup deste mundo na lista gerada pelo script?
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

-- Personagem novo criado no mesmo mundo depois de morrer: volta a ser "vivo"
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
            PZBackup.mostrar("Morto. Script de backup parado: sem restauracao automatica", true)
        elseif PZBackup.restaurarAuto() and not PZBackup.temBackupDoMundo(mm) then
            PZBackup.mostrar("Morto. Nao ha backup deste mundo para restaurar", true)
        elseif PZBackup.apagarMortos() then
            PZBackup.mostrar("Morto. Ao fechar o jogo este save sera removido. F9 restaura um backup", true)
        else
            PZBackup.mostrar("PZ Backup: aperte F9 para restaurar um backup", true)
        end
    end
end

------------------------------------------------------------------------
-- Lê o resultado escrito pelo script e mostra na tela
-- Formato: <id>|<ok|erro>|<mensagem>
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
    if primeiraLeitura then return end   -- não repete mensagem antiga ao carregar o jogo
    PZBackup.mostrar(msg, tipo == "erro")
end

------------------------------------------------------------------------
-- Eventos
------------------------------------------------------------------------
Events.OnGameStart.Add(marcarVivo)
Events.OnGameStart.Add(PZBackup.salvarConfig)
-- Quem instalou só o mod (ex.: pela Workshop) fica sabendo que falta o script
Events.OnGameStart.Add(function()
    if not PZBackup.scriptAtivo() then
        print("[PZBackup] script de backup nao detectado. Instale: https://" .. PZBackup.URL)
        PZBackup.mostrar("PZ Backup: script nao detectado. Instale: " .. PZBackup.URL, true)
    end
end)
if Events.OnMainMenuEnter then Events.OnMainMenuEnter.Add(PZBackup.salvarConfig) end
if Events.OnCreatePlayer then Events.OnCreatePlayer.Add(aoCriarPersonagem) end
Events.OnKeyPressed.Add(aoPressionarTecla)
Events.OnPlayerDeath.Add(aoMorrer)
Events.OnTick.Add(lerStatus)

print("[PZBackup] carregado — backup: " .. tostring(Keyboard.getKeyName(tecla(opcaoBackup, TECLA_BACKUP_PADRAO)))
    .. ", restaurar: " .. tostring(Keyboard.getKeyName(tecla(opcaoRestaurar, TECLA_RESTAURAR_PADRAO))))
