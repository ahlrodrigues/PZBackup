--[[
  PZ Backup — bridge between the game and the pz-backup script (Linux .sh / Windows .ps1)

  Project Zomboid's Lua can't copy folders, so the mod only exchanges
  messages with the script through files in Zomboid/Lua/
  (file names stay in Portuguese for compatibility with older versions):

    pzbackup_pedido.txt     (mod -> script)  manual backup request ("save <time>", optional line "nota=<text>")
    pzbackup_restaurar.txt  (mod -> script)  backup to restore when the game closes
    pzbackup_estado.txt     (mod -> script)  "vivo" (alive) or "morto" (dead) + line 2: mode/world
                                             + line 3 (v1.4+): Unix time of the death
    pzbackup_config.txt     (mod -> script)  options the script uses (apagar_mortos=1/0, idioma=pt/en,
                                             margem_morte=<seconds>, adiar_perigo=1/0)
    pzbackup_perigo.txt     (mod -> script)  "<0|1>|<reasons>|<unix time>", every ~2 s (v1.4+)
    pzbackup_status.txt     (script -> mod)  result of each action, shown on screen
    pzbackup_lista.txt      (script -> mod)  available backups: name|label
    pzbackup_ativo.txt      (script -> mod)  Unix time of the script's last heartbeat
    pzbackup_info.txt       (mod -> script)  current character/world info + active mods (key=value),
                                             saved by the script next to each backup (v1.4+)
    pzbackup_fixar.txt      (mod -> script)  commands, one per line (v1.4+):
                                             "pin <name>", "unpin <name>", "note <name>|<text>"
    pzbackup_detalhes.txt   (script -> mod)  per-backup details: name|pinned|key=value|key=value...

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
PZBackup.ARQ_INFO      = "pzbackup_info.txt"
PZBackup.ARQ_FIXAR     = "pzbackup_fixar.txt"
PZBackup.ARQ_DETALHES  = "pzbackup_detalhes.txt"
PZBackup.ARQ_PERIGO    = "pzbackup_perigo.txt"
PZBackup.URL           = "github.com/ahlrodrigues/PZBackup"   -- where to get the script

local TECLA_BACKUP_PADRAO    = Keyboard.KEY_F8
local TECLA_RESTAURAR_PADRAO = Keyboard.KEY_F9
local TECLA_NOTA_PADRAO      = Keyboard.KEY_F7
local INTERVALO_LEITURA = 30   -- ticks between status reads (~0.5 s)

local opcaoBackup, opcaoRestaurar, opcaoApagarMortos, opcaoRestaurarAuto = nil, nil, nil, nil
local opcaoNota, opcaoMargem, opcaoAdiarPerigo = nil, nil, nil
local APAGAR_MORTOS_PADRAO = true
local RESTAURAR_AUTO_PADRAO = true
local ADIAR_PERIGO_PADRAO = true
-- Death margin (Options): auto-restore skips backups taken this close to the death.
-- Item order of the option list = order of this table.
PZBackup.MARGENS = { 0, 30, 60, 120, 300 }
local MARGEM_PADRAO_ITEM = 3            -- 60 s
local INTERVALO_PERIGO = 120            -- ticks between danger checks (~2 s)
PZBackup.PERIGO_RAIO = 8                -- tiles: zombies closer than this count as danger
PZBackup.PERIGO_PANICO = 50             -- % panic that counts as danger
PZBackup.PERIGO_SAUDE = 25              -- health % below this counts as danger
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

-- Adds a line at the end of the file (used for pin requests: several clicks
-- within the same second must not overwrite each other)
function PZBackup.acrescentar(arquivo, texto)
    local ok = pcall(function()
        local w = getFileWriter(arquivo, true, true)
        w:write(texto)
        w:close()
    end)
    return ok
end

------------------------------------------------------------------------
-- Active mods and character info (saved by the script with each backup)
------------------------------------------------------------------------
-- Mod IDs as a sorted list. B42 may prefix IDs with "\" — stripped so
-- lists from different versions compare cleanly.
function PZBackup.normalizarMod(id)
    return (tostring(id or ""):gsub("^\\+", ""))
end

function PZBackup.modsAtivos()
    local lista = {}
    pcall(function()
        local mods = getActivatedMods()
        for i = 0, mods:size() - 1 do
            local id = PZBackup.normalizarMod(mods:get(i))
            if id ~= "" then table.insert(lista, id) end
        end
    end)
    table.sort(lista)
    return lista
end

-- Keeps values on one line, without the separators used by the files
local function limpar(v)
    return (tostring(v or ""):gsub("[\r\n|;=]", " "))
end
PZBackup.limparTexto = limpar

-- Runs f protected; returns its value or nil (the game API changes between builds,
-- so every read is optional: a field that fails is simply left out)
local function tentar(f)
    local ok, v = pcall(f)
    if ok then return v end
    return nil
end

-- Approximate areas of the vanilla towns (x1, y1, x2, y2). Only a hint for the
-- details panel: modded maps or new B42 towns just show coordinates.
PZBackup.CIDADES = {
    { "Muldraugh",     10500,  9000, 11100, 10600 },
    { "West Point",    11500,  6700, 12300,  7400 },
    { "Riverside",      5800,  5000,  6900,  5700 },
    { "Rosewood",       7900, 11200,  8500, 12000 },
    { "March Ridge",    9700, 12400, 10500, 13200 },
    { "Louisville",    11700,   900, 14700,  4300 },
    { "Valley Station",12500,  4500, 14200,  6000 },
    { "Fallas Lake",    7000,  8000,  7600,  8600 },
}

function PZBackup.cidadeAprox(x, y)
    for _, c in ipairs(PZBackup.CIDADES) do
        if x >= c[2] and y >= c[3] and x <= c[4] and y <= c[5] then return c[1] end
    end
    return ""
end

-- 0..1 stats become 0..100; values already in 0..100 stay as they are
local function porcento(v)
    if type(v) ~= "number" then return nil end
    if v <= 1 then v = v * 100 end
    return math.floor(v + 0.5)
end

-- Reads a stat by name, B41 style (getHunger) or B42 style (get(CharacterStat.HUNGER))
local function lerStat(stats, nome)
    local v = tentar(function() return stats["get" .. nome](stats) end)
    if v == nil and CharacterStat then
        v = tentar(function() return stats:get(CharacterStat[string.upper(nome)]) end)
    end
    return porcento(v)
end

local function profissao(p)
    local d = p:getDescriptor()
    local id = tentar(function() return d:getProfession() end)
            or tentar(function() return d:getCharacterProfession() end)
    if id == nil then return "" end
    local nome = tentar(function() return ProfessionFactory.getProfession(id):getName() end)
              or tentar(function()
                     return CharacterProfessionDefinition.getCharacterProfessionDefinition(id):getUIName()
                 end)
    if nome and nome ~= "" then return nome end
    local s = tostring(id):gsub("^.*:", "")          -- "base:carpenter" -> "carpenter"
    return (s:gsub("^%l", string.upper))
end

-- Three best skills ("Carpentry 5, Cooking 3, Aiming 2"); Strength and Fitness go apart
local function habilidades(p)
    local lista = {}
    pcall(function()
        local perks = PerkFactory.PerkList
        for i = 0, perks:size() - 1 do
            local perk = perks:get(i)
            local eFisico = (perk == Perks.Strength or perk == Perks.Fitness)
            local eCategoria = tentar(function() return perk:getParent() == Perks.None end)
            if not eFisico and not eCategoria then
                local nivel = tentar(function() return p:getPerkLevel(perk) end) or 0
                if nivel > 0 then
                    table.insert(lista, { nome = tostring(perk:getName()), nivel = nivel })
                end
            end
        end
    end)
    table.sort(lista, function(a, b)
        if a.nivel ~= b.nivel then return a.nivel > b.nivel end
        return a.nome < b.nome
    end)
    local partes = {}
    for i = 1, math.min(3, #lista) do partes[i] = lista[i].nome .. " " .. lista[i].nivel end
    return table.concat(partes, ", ")
end

-- Bites, scratches and lacerations across the body
local function ferimentos(p)
    local m, a, l = 0, 0, 0
    pcall(function()
        local partes = p:getBodyDamage():getBodyParts()
        for i = 0, partes:size() - 1 do
            local bp = partes:get(i)
            if tentar(function() return bp:bitten() end) then m = m + 1 end
            if tentar(function() return bp:scratched() end) then a = a + 1 end
            if tentar(function() return bp:isCut() end) then l = l + 1 end
        end
    end)
    return m, a, l
end

------------------------------------------------------------------------
-- Danger: automatic backups wait while the character is in trouble, so the
-- newest backup isn't taken seconds before a death. Reasons (codes):
--   zumbis = zombies chasing or very close, panico = panic >= 50%,
--   sangrando = bleeding, fogo = on fire, saude = health below 25%
-- (bites are not danger: a bitten character stays bitten; those backups are
--  flagged in red instead and skipped by the auto-restore)
------------------------------------------------------------------------
local function zumbisPerto(p)
    local stats = tentar(function() return p:getStats() end)
    local n = stats and tentar(function() return stats:getNumChasingZombies() end)
    if type(n) == "number" then
        if n > 0 then return true end
    end
    -- Fallback / extra check: living zombies within PERIGO_RAIO tiles
    local perto = false
    pcall(function()
        local px, py, pz = p:getX(), p:getY(), p:getZ()
        local lista = getCell():getZombieList()
        local r2 = PZBackup.PERIGO_RAIO * PZBackup.PERIGO_RAIO
        for i = 0, lista:size() - 1 do
            local z = lista:get(i)
            if z and not z:isDead() and math.abs(z:getZ() - pz) < 1 then
                local dx, dy = z:getX() - px, z:getY() - py
                if dx * dx + dy * dy <= r2 then perto = true; break end
            end
        end
    end)
    return perto
end

function PZBackup.avaliarPerigo()
    local p = getPlayer()
    if not p or p:isDead() then return {} end
    local motivos = {}
    if zumbisPerto(p) then table.insert(motivos, "zumbis") end
    local stats = tentar(function() return p:getStats() end)
    if stats then
        local panico = lerStat(stats, "Panic")
        if panico and panico >= PZBackup.PERIGO_PANICO then table.insert(motivos, "panico") end
    end
    local bd = tentar(function() return p:getBodyDamage() end)
    if bd then
        local sangra = tentar(function() return bd:getNumPartsBleeding() end)
        if type(sangra) ~= "number" then
            sangra = 0
            pcall(function()
                local partes = bd:getBodyParts()
                for i = 0, partes:size() - 1 do
                    if partes:get(i):bleeding() then sangra = sangra + 1 end
                end
            end)
        end
        if sangra > 0 then table.insert(motivos, "sangrando") end
        local saude = tentar(function() return bd:getOverallBodyHealth() end)
        if type(saude) == "number" and saude < PZBackup.PERIGO_SAUDE then table.insert(motivos, "saude") end
    end
    if tentar(function() return p:isOnFire() end) then table.insert(motivos, "fogo") end
    return motivos
end

-- Writes pzbackup_perigo.txt when the state changes, or every ~10 s to stay fresh
local contadorPerigo, ultimoPerigo, ultimaEscritaPerigo = 0, nil, 0
function PZBackup.atualizarPerigo(forcar)
    local motivos = PZBackup.avaliarPerigo()
    local texto = table.concat(motivos, ",")
    local agora = PZBackup.agora()
    if forcar or texto ~= ultimoPerigo or agora - ultimaEscritaPerigo >= 10 then
        PZBackup.gravar(PZBackup.ARQ_PERIGO, (#motivos > 0 and "1" or "0") .. "|" .. texto .. "|" .. agora .. "\n")
        ultimoPerigo, ultimaEscritaPerigo = texto, agora
    end
    PZBackup.perigoAtual = texto
    return texto
end

local function verificarPerigo()
    contadorPerigo = contadorPerigo + 1
    if contadorPerigo < INTERVALO_PERIGO then return end
    contadorPerigo = 0
    PZBackup.atualizarPerigo(false)
end
PZBackup.verificarPerigo = verificarPerigo

-- Everything shown in the details panel, as ordered key/value pairs.
-- Keys are stable (the script stores them as-is); missing values are skipped.
function PZBackup.infoPersonagem()
    local p = getPlayer()
    if not p or p:isDead() then return nil end
    local campos = {}
    local function add(chave, valor)
        if valor ~= nil and tostring(valor) ~= "" then
            table.insert(campos, { chave, limpar(valor) })
        end
    end

    -- Character
    add("personagem", tentar(function()
        local d = p:getDescriptor()
        return tostring(d:getForename() or "") .. " " .. tostring(d:getSurname() or "")
    end))
    add("profissao", tentar(function() return profissao(p) end))
    add("dias", tentar(function() return math.floor((p:getHoursSurvived() or 0) / 24) end))
    add("mortes", tentar(function() return p:getZombieKills() end))
    add("habilidades", habilidades(p))
    add("forca", tentar(function() return p:getPerkLevel(Perks.Strength) end))
    add("condicionamento", tentar(function() return p:getPerkLevel(Perks.Fitness) end))
    add("peso", tentar(function() return math.floor(p:getNutrition():getWeight() + 0.5) end))

    -- In-game date and time
    local gt = tentar(function() return getGameTime() end)
    if gt then
        add("data_jogo", tentar(function()
            return string.format("%02d/%02d/%d", gt:getDay() + 1, gt:getMonth() + 1, gt:getYear())
        end))
        add("hora_jogo", tentar(function()
            return string.format("%02d:%02d", gt:getHour(), gt:getMinutes())
        end))
    end

    -- Health and wounds
    local bd = tentar(function() return p:getBodyDamage() end)
    if bd then
        add("saude", tentar(function() return math.floor(bd:getOverallBodyHealth() + 0.5) end))
        local m, a, l = ferimentos(p)
        add("mordidas", m); add("arranhoes", a); add("laceracoes", l)
    end

    -- State
    local stats = tentar(function() return p:getStats() end)
    if stats then
        add("fome", lerStat(stats, "Hunger"))
        add("sede", lerStat(stats, "Thirst"))
        add("cansaco", lerStat(stats, "Fatigue"))
        add("panico", lerStat(stats, "Panic"))
    end

    -- Location
    local x = tentar(function() return math.floor(p:getX()) end)
    local y = tentar(function() return math.floor(p:getY()) end)
    local z = tentar(function() return math.floor(p:getZ()) end) or 0
    if x and y then
        add("cidade", PZBackup.cidadeAprox(x, y))
        add("coord", x .. "," .. y .. "," .. z)
    end
    local ambiente = nil
    if tentar(function() return p:getVehicle() end) then
        ambiente = "veiculo"
    else
        local fora = tentar(function() return p:getCurrentSquare():isOutside() end)
        if fora == true then ambiente = "fora" elseif fora == false then ambiente = "dentro" end
    end
    add("ambiente", ambiente)
    add("perigo", table.concat(PZBackup.avaliarPerigo(), ","))
    return campos
end

-- Writes pzbackup_info.txt; the script copies it next to each backup of this world
function PZBackup.gravarInfo()
    local campos = PZBackup.infoPersonagem()
    if not campos then return end          -- dead: keep the last info from when alive
    local linhas = { "mundo=" .. PZBackup.mundoAtual() }
    for _, c in ipairs(campos) do table.insert(linhas, c[1] .. "=" .. c[2]) end
    table.insert(linhas, "mods=" .. table.concat(PZBackup.modsAtivos(), ";"))
    PZBackup.gravar(PZBackup.ARQ_INFO, table.concat(linhas, "\n") .. "\n")
end

-- Compares a backup's mods (";"-separated) with the ones active now.
-- Returns two lists: missing now (were in the backup) and new now (not in the backup).
function PZBackup.compararMods(modsBackup)
    local antes, agora = {}, {}
    for id in tostring(modsBackup or ""):gmatch("[^;]+") do antes[PZBackup.normalizarMod(id)] = true end
    for _, id in ipairs(PZBackup.modsAtivos()) do agora[id] = true end
    local faltam, novos = {}, {}
    for id in pairs(antes) do if not agora[id] then table.insert(faltam, id) end end
    for id in pairs(agora) do if not antes[id] then table.insert(novos, id) end end
    table.sort(faltam); table.sort(novos)
    return faltam, novos
end

-- Reads pzbackup_detalhes.txt: "name|pinned|key=value|key=value..." per backup
-- -> { [name] = { fixo = bool, temInfo = bool, <key> = value ... } }
function PZBackup.lerDetalhes()
    local det = {}
    for _, linha in ipairs(PZBackup.lerLinhas(PZBackup.ARQ_DETALHES)) do
        local nome, fixo, resto = linha:match("^([^|]+)|([01]?)|?(.*)$")
        if nome then
            local d = { fixo = (fixo == "1"), temInfo = false, mods = "" }
            for par in resto:gmatch("[^|]+") do
                local k, v = par:match("^([%w_]+)=(.*)$")
                if k and k ~= "fixo" and k ~= "temInfo" then
                    d[k] = v
                    -- only character fields count as "details" (not note, origin, sizes...)
                    if (k == "personagem" or k == "dias" or k == "saude") and v ~= "" then d.temInfo = true end
                end
            end
            det[nome] = d
        end
    end
    return det
end

-- The script writes the time every second; if the heartbeat is older than
-- 30 s, it isn't running (game started without "game" mode).
-- Unix time in seconds (getTimestamp may come in ms depending on the build)
function PZBackup.agora()
    local t = getTimestamp()
    if t > 100000000000 then t = t / 1000 end
    return math.floor(t)
end

function PZBackup.scriptAtivo()
    local l = PZBackup.lerLinhas(PZBackup.ARQ_ATIVO)[1]
    local ts = tonumber(l or "")
    if not ts then return false end
    return math.abs(PZBackup.agora() - ts) < 30
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
    opcaoNota = tentar("teclaNota", function()
        return opcoes:addKeyBind("teclaNota", PZBackup.T("opt_tecla_nota"), TECLA_NOTA_PADRAO,
            PZBackup.T("opt_tecla_nota_dica"))
    end)
    opcaoRestaurarAuto = tentar("restaurarAuto", function()
        return opcoes:addTickBox("restaurarAuto", PZBackup.T("opt_restaurar_auto"),
            RESTAURAR_AUTO_PADRAO, PZBackup.T("opt_restaurar_auto_dica"))
    end)
    -- Death margin: order must match PZBackup.MARGENS
    opcaoMargem = tentar("margemMorte", function()
        local combo = opcoes:addComboBox("margemMorte", PZBackup.T("opt_margem"), PZBackup.T("opt_margem_dica"))
        for i, seg in ipairs(PZBackup.MARGENS) do
            local nome = (seg == 0) and PZBackup.T("opt_margem_off")
                      or (seg < 60 and PZBackup.T("opt_margem_seg", seg) or PZBackup.T("opt_margem_min", seg / 60))
            combo:addItem(nome, i == MARGEM_PADRAO_ITEM)
        end
        return combo
    end)
    opcaoAdiarPerigo = tentar("adiarPerigo", function()
        return opcoes:addTickBox("adiarPerigo", PZBackup.T("opt_adiar_perigo"),
            ADIAR_PERIGO_PADRAO, PZBackup.T("opt_adiar_perigo_dica"))
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

function PZBackup.adiarPerigo()
    if opcaoAdiarPerigo then
        local ok, v = pcall(function() return opcaoAdiarPerigo:getValue() end)
        if ok and v ~= nil then return v == true end
    end
    return ADIAR_PERIGO_PADRAO
end

-- Death margin in seconds (0 = off)
function PZBackup.margemMorte()
    if opcaoMargem then
        local ok, v = pcall(function() return opcaoMargem:getValue() end)
        if ok and PZBackup.MARGENS[v] then return PZBackup.MARGENS[v] end
    end
    return PZBackup.MARGENS[MARGEM_PADRAO_ITEM]
end

function PZBackup.salvarConfig()
    PZBackup.gravar(PZBackup.ARQ_CONFIG,
        "apagar_mortos=" .. (PZBackup.apagarMortos() and "1" or "0") .. "\n" ..
        "idioma=" .. PZBackup.idioma() .. "\n" ..
        "margem_morte=" .. tostring(PZBackup.margemMorte()) .. "\n" ..
        "adiar_perigo=" .. (PZBackup.adiarPerigo() and "1" or "0") .. "\n")
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
local function pedirBackup(nota)
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
    PZBackup.gravarInfo()                  -- fresh details for this backup
    local texto = "save " .. tostring(getTimestamp()) .. "\n"
    if nota and nota ~= "" then texto = texto .. "nota=" .. PZBackup.limparTexto(nota) .. "\n" end
    if PZBackup.gravar(PZBackup.ARQ_PEDIDO, texto) then
        PZBackup.mostrar(PZBackup.T("msg_backup_solicitado"), false)
    else
        PZBackup.mostrar(PZBackup.T("msg_falha_pedido"), true)
    end
end

PZBackup.pedirBackup = pedirBackup

-- Backup with a note: asks for the text, then requests the backup
local function pedirBackupComNota()
    local p = getPlayer()
    if not p then return end
    if p:isDead() then
        PZBackup.mostrar(PZBackup.T("msg_morto_bloqueado"), true)
        return
    end
    if PZBackup.pedirTexto then
        PZBackup.pedirTexto(PZBackup.T("nota_titulo_backup"), "", function(texto) pedirBackup(texto) end)
    else
        pedirBackup()
    end
end

local function aoPressionarTecla(k)
    if k == tecla(opcaoBackup, TECLA_BACKUP_PADRAO) then
        pedirBackup()
    elseif k == tecla(opcaoNota, TECLA_NOTA_PADRAO) then
        pedirBackupComNota()
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
        PZBackup.gravar(PZBackup.ARQ_ESTADO, "morto\n" .. mm .. "\n" .. tostring(PZBackup.agora()) .. "\n")
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
Events.OnGameStart.Add(PZBackup.gravarInfo)
-- Keeps the details fresh for the automatic backups (10 game minutes ~ 25 s by default)
if Events.EveryTenMinutes then Events.EveryTenMinutes.Add(PZBackup.gravarInfo) end
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
Events.OnTick.Add(verificarPerigo)

print("[PZBackup] loaded - backup key: " .. tostring(Keyboard.getKeyName(tecla(opcaoBackup, TECLA_BACKUP_PADRAO)))
    .. ", restore key: " .. tostring(Keyboard.getKeyName(tecla(opcaoRestaurar, TECLA_RESTAURAR_PADRAO))))
