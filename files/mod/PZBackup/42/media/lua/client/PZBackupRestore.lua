--[[
  PZ Backup — restore window

  Opened with F9 (in game) or the "Restore backup..." button in Options > Mods.
  On confirm, the mod writes the backup name to pzbackup_restaurar.txt and closes
  the game. The script notices, restores the save and relaunches the game.
  (The game reads the save list only on startup, hence the restart.)

  v1.4:
  - each backup is colored by risk, with a legend at the top:
      red = bitten, yellow = danger (danger at backup time, taken just before a
      death, or low health), green = normal, grey = no details
  - details of the selected backup (character, health, location, state, skills,
    note, danger, mods compared with now)
  - Pin / Unpin (pinned backups are never removed by the rotation)
  - Note: names a backup ("before the mall")
]]

require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISScrollingListBox"
require "ISUI/ISModalDialog"
require "ISUI/ISTextBox"

PZBackupJanela = ISPanel:derive("PZBackupJanela")

local LARGURA, ALTURA = 720, 700
local FONTE = UIFont.Small
local Y_LEGENDA = 40                -- legend row, between the title and the list
local Y_LISTA = 62
local ALTURA_DETALHES = 232         -- details area between the list and the message (14 lines)
local MAX_MODS_DIALOGO = 6          -- mod names listed per side in the confirm dialog
local QUADROS_RECARREGAR = 90       -- frames to wait before re-reading the list after a request
local MAX_NOTA = 60                 -- characters kept in a note

------------------------------------------------------------------------
-- Colors
------------------------------------------------------------------------
local COR = {
    normal = { 1, 1, 1 },
    suave  = { 0.75, 0.75, 0.75 },
    ok     = { 0.6, 1, 0.6 },
    alerta = { 1, 0.75, 0.3 },
    perigo = { 1, 0.35, 0.35 },
    fixo   = { 0.55, 0.8, 1 },
}

-- Risk class of a backup -> list color (same order as the legend)
PZBackup.CLASSES = {
    { id = "mordido", cor = { 1, 0.35, 0.35 },  chave = "leg_mordido" },
    { id = "perigo",  cor = { 1, 0.85, 0.3 },   chave = "leg_perigo" },
    { id = "normal",  cor = { 0.55, 0.95, 0.55 }, chave = "leg_normal" },
    { id = "sem",     cor = { 0.6, 0.6, 0.6 },  chave = "leg_sem" },
}
local CORES_CLASSE = {}
for _, c in ipairs(PZBackup.CLASSES) do CORES_CLASSE[c.id] = c.cor end

-- bitten > danger > normal; "sem" when there are no details
function PZBackup.classificar(det)
    if det and det.integridade == "falha" and (tonumber(det.mordidas or "") or 0) == 0 then return "perigo" end
    if not det or not det.temInfo then return "sem" end
    if (tonumber(det.mordidas or "") or 0) > 0 then return "mordido" end
    if (det.perigo and det.perigo ~= "") or det.morte_seg
       or (tonumber(det.saude or "") or 100) < 50 then
        return "perigo"
    end
    return "normal"
end

------------------------------------------------------------------------
-- Closes the game so the script can restore
------------------------------------------------------------------------
function PZBackup.fecharJogo()
    local core = getCore()
    if getPlayer() then
        -- In game: quit to desktop (the script restores over it)
        if pcall(function() core:quitToDesktop() end) then return end
    end
    pcall(function() core:quit() end)
end

local fecharJogo = PZBackup.fecharJogo

------------------------------------------------------------------------
-- Text input (backup note): calls aoConfirmar(text) on OK
------------------------------------------------------------------------
function PZBackup.pedirTexto(titulo, padrao, aoConfirmar)
    local w, h = 420, 160
    local box = ISTextBox:new((getCore():getScreenWidth() - w) / 2, (getCore():getScreenHeight() - h) / 2,
        w, h, titulo, padrao or "", nil, function(_, botao)
            if botao.internal ~= "OK" then return end
            local texto = ""
            pcall(function() texto = botao.parent.entry:getText() end)
            texto = PZBackup.limparTexto(texto):gsub("^%s+", ""):gsub("%s+$", "")
            if #texto > MAX_NOTA then texto = texto:sub(1, MAX_NOTA) end
            aoConfirmar(texto)
        end)
    box:initialise()
    box:addToUIManager()
    pcall(function() box:setAlwaysOnTop(true) end)
    pcall(function() box.entry:focus() end)
    return box
end

-- "a, b, c (+3)" with at most n names
local function juntar(lista, n)
    local partes = {}
    for i = 1, math.min(#lista, n) do partes[i] = lista[i] end
    local s = table.concat(partes, ", ")
    if #lista > n then s = s .. " (+" .. (#lista - n) .. ")" end
    return s
end

-- "a   b   c" skipping empty parts
local function linha(...)
    local partes = {}
    for i = 1, select("#", ...) do            -- not ipairs: arguments may be nil
        local v = select(i, ...)
        if v and v ~= "" then table.insert(partes, v) end
    end
    return table.concat(partes, "   ")
end

-- T(key, value) only when the value exists
local function campo(chave, valor)
    if valor == nil or valor == "" then return nil end
    return PZBackup.T(chave, valor)
end

-- "zumbis,panico" -> "zombies close, panic" (in the current language)
function PZBackup.textoPerigo(codigos)
    local partes = {}
    for c in tostring(codigos or ""):gmatch("[^,]+") do
        local t = PZBackup.T("perigo_" .. c)
        if t == "perigo_" .. c then t = c end
        table.insert(partes, t)
    end
    return table.concat(partes, ", ")
end

-- List label: [PIN] date - world - "note"
function PZBackup.rotuloItem(rotulo, det)
    local r = rotulo
    if det and det.nota and det.nota ~= "" then r = r .. "  - \"" .. det.nota .. "\"" end
    if det and det.fixo then r = PZBackup.T("jan_tag_fixo") .. " " .. r end
    return r
end

------------------------------------------------------------------------
-- Details lines { text, color } of one backup
------------------------------------------------------------------------
function PZBackup.linhasDetalhes(det)
    local L = {}
    local function add(texto, cor) if texto and texto ~= "" then table.insert(L, { texto, cor or COR.normal }) end end

    if det and det.nota and det.nota ~= "" then add(PZBackup.T("jan_det_nota", det.nota), COR.fixo) end
    if det and det.integridade == "falha" then add(PZBackup.T("jan_det_integridade"), COR.perigo) end
    -- How the backup was made: source, size, new MB (incremental)
    if det and det.origem then
        local orig = PZBackup.T("orig_" .. det.origem)
        if orig == "orig_" .. det.origem then orig = det.origem end
        local tam = ""
        if det.tamanho_mb and det.novos_mb then tam = PZBackup.T("jan_det_tamanho", det.tamanho_mb, det.novos_mb) end
        add(linha(PZBackup.T("jan_det_backup", orig), tam), COR.suave)
    end
    if not det or not det.temInfo then
        add(PZBackup.T("jan_sem_detalhes"), COR.suave)
        if det and det.fixo then add(PZBackup.T("jan_fixado_info"), COR.fixo) end
        return L
    end

    -- Who: name (profession), days survived, kills
    local quem = det.personagem ~= nil and det.personagem ~= "" and det.personagem or "?"
    if det.profissao and det.profissao ~= "" then quem = quem .. " (" .. det.profissao .. ")" end
    add(linha(PZBackup.T("jan_det_personagem", quem),
              campo("jan_det_dias", det.dias), campo("jan_det_mortes", det.mortes)))

    -- When: in-game date and time + pinned
    local quando = det.data_jogo or ""
    if det.hora_jogo and det.hora_jogo ~= "" then quando = linha(quando, det.hora_jogo) end
    add(linha(campo("jan_det_data", quando), det.fixo and PZBackup.T("jan_fixado_info") or nil), COR.fixo)

    -- Health and wounds: red if bitten, orange if hurt, green otherwise
    local mord, arr, lac = tonumber(det.mordidas or ""), tonumber(det.arranhoes or ""), tonumber(det.laceracoes or "")
    if det.saude or mord then
        local cor = COR.ok
        if (mord or 0) > 0 then cor = COR.perigo
        elseif (arr or 0) > 0 or (lac or 0) > 0 or (tonumber(det.saude or "") or 100) < 60 then cor = COR.alerta end
        add(linha(campo("jan_det_saude", det.saude),
                  campo("jan_det_mordidas", det.mordidas), campo("jan_det_arranhoes", det.arranhoes),
                  campo("jan_det_laceracoes", det.laceracoes),
                  (mord or 0) > 0 and PZBackup.T("jan_det_mordido") or nil), cor)
    end

    -- Danger at backup time / taken just before a death
    if det.perigo and det.perigo ~= "" then
        add(PZBackup.T("jan_det_perigo", PZBackup.textoPerigo(det.perigo)), COR.alerta)
    end
    if det.morte_seg then add(PZBackup.T("jan_det_morte", det.morte_seg), COR.alerta) end
    if (mord or 0) > 0 or det.morte_seg then add(PZBackup.T("jan_det_pulado_auto"), COR.suave) end

    -- Where: approximate town, coordinates, indoors/outdoors/vehicle
    if det.coord or det.cidade then
        local onde = (det.cidade and det.cidade ~= "") and PZBackup.T("jan_det_cidade", det.cidade) or nil
        local x, y, z = tostring(det.coord or ""):match("^(-?%d+),(-?%d+),(-?%d+)$")
        local coord = x and PZBackup.T("jan_det_coord", x, y, z) or nil
        local amb = det.ambiente and PZBackup.T("jan_amb_" .. det.ambiente) or nil
        if amb == "jan_amb_" .. tostring(det.ambiente) then amb = nil end
        add(PZBackup.T("jan_det_local") .. " " .. linha(onde, coord, amb))
    end

    -- State: hunger, thirst, tiredness, panic (orange from 50%)
    if det.fome or det.sede or det.cansaco or det.panico then
        local pior = 0
        for _, k in ipairs({ "fome", "sede", "cansaco", "panico" }) do
            pior = math.max(pior, tonumber(det[k] or "") or 0)
        end
        add(linha(campo("jan_det_fome", det.fome), campo("jan_det_sede", det.sede),
                  campo("jan_det_cansaco", det.cansaco), campo("jan_det_panico", det.panico)),
            pior >= 50 and COR.alerta or COR.normal)
    end

    -- Skills and body: best 3 skills, strength, fitness, weight
    if det.habilidades or det.forca or det.peso then
        add(linha(campo("jan_det_habilidades", det.habilidades), campo("jan_det_forca", det.forca),
                  campo("jan_det_condicionamento", det.condicionamento), campo("jan_det_peso", det.peso)),
            COR.suave)
    end

    -- Mods compared with the ones active now
    if det.mods and det.mods ~= "" then
        local faltam, novos = PZBackup.compararMods(det.mods)
        if #faltam == 0 and #novos == 0 then
            add(PZBackup.T("jan_mods_iguais"), COR.ok)
        else
            add(PZBackup.T("jan_mods_diferentes", #faltam, #novos), COR.alerta)
            add(linha(#faltam > 0 and ("- " .. juntar(faltam, 3)) or nil,
                      #novos > 0 and ("+ " .. juntar(novos, 3)) or nil), COR.suave)
        end
    end
    return L
end

------------------------------------------------------------------------
-- Window
------------------------------------------------------------------------
function PZBackupJanela:new()
    local x = (getCore():getScreenWidth() - LARGURA) / 2
    local y = math.max(0, (getCore():getScreenHeight() - ALTURA) / 2)
    local o = ISPanel:new(x, y, LARGURA, ALTURA)
    setmetatable(o, self)
    self.__index = self
    o.backgroundColor = { r = 0.05, g = 0.05, b = 0.05, a = 0.92 }
    o.borderColor = { r = 1, g = 1, b = 1, a = 0.4 }
    o.moveWithMouse = true
    o.mensagem = ""
    o.corMensagem = { r = 1, g = 1, b = 1 }
    o.detalhes = {}
    o.recarregarEm = nil
    return o
end

-- List rows drawn in their risk color
local function desenharItem(lista, y, item, alt)
    local h = lista.itemheight
    if lista.items[lista.selected] == item then
        lista:drawRect(0, y, lista:getWidth(), h - 1, 0.3, 0.7, 0.35, 0.15)
    end
    local c = item.cor or COR.normal
    lista:drawText(item.text, 10, y + (h - getTextManager():getFontHeight(lista.font)) / 2,
        c[1], c[2], c[3], 1, lista.font)
    return y + h
end

function PZBackupJanela:createChildren()
    ISPanel.createChildren(self)
    local alturaLinha = getTextManager():getFontHeight(FONTE) + 8

    self.lista = ISScrollingListBox:new(12, Y_LISTA, self.width - 24, self.height - Y_LISTA - 84 - ALTURA_DETALHES)
    self.lista:initialise()
    self.lista:instantiate()
    self.lista.itemheight = alturaLinha
    self.lista.font = FONTE
    self.lista.drawBorder = true
    self.lista.doDrawItem = desenharItem
    self:addChild(self.lista)

    local yBotoes = self.height - 40
    local function botao(x, w, chave, fn)
        local b = ISButton:new(x, yBotoes, w, 28, PZBackup.T(chave), self, fn)
        b:initialise()
        self:addChild(b)
        return b
    end
    self.btnRestaurar = botao(12, 130, "jan_btn_restaurar", PZBackupJanela.aoClicarRestaurar)
    self.btnFixar     = botao(150, 100, "jan_btn_fixar", PZBackupJanela.aoClicarFixar)
    self.btnNota      = botao(258, 90, "jan_btn_nota", PZBackupJanela.aoClicarNota)
    self.btnAtualizar = botao(356, 100, "jan_btn_atualizar", PZBackupJanela.carregar)
    self.btnLog       = botao(464, 80, "jan_btn_log", PZBackupJanela.verLog)
    self.btnFechar    = botao(self.width - 102, 90, "jan_btn_fechar", PZBackupJanela.fechar)

    self:carregar()
end

-- Details of the selected item (or nil)
function PZBackupJanela:selecionado()
    local item = self.lista.items[self.lista.selected]
    if not item then return nil, nil end
    return item, self.detalhes[item.item]
end

-- Legend: colored square + text for each risk class
function PZBackupJanela:desenharLegenda()
    local x = 12
    local tm = getTextManager()
    for _, c in ipairs(PZBackup.CLASSES) do
        local texto = PZBackup.T(c.chave)
        self:drawRect(x, Y_LEGENDA + 3, 10, 10, 1, c.cor[1], c.cor[2], c.cor[3])
        self:drawText(texto, x + 14, Y_LEGENDA, c.cor[1], c.cor[2], c.cor[3], 1, FONTE)
        local larg = 7 * #texto
        pcall(function() larg = tm:MeasureStringX(FONTE, texto) end)
        x = x + 14 + larg + 18
    end
end

function PZBackupJanela:prerender()
    ISPanel.prerender(self)
    self:drawText(PZBackup.T("jan_titulo"), 12, 12, 1, 1, 1, 1, UIFont.Medium)
    -- Versions, top right: mod and script (red when they differ)
    local vs = PZBackup.versaoScript()
    local txtVersao = PZBackup.T("jan_versoes", PZBackup.VERSAO, vs or "?")
    local larg = 7 * #txtVersao
    pcall(function() larg = getTextManager():MeasureStringX(FONTE, txtVersao) end)
    if vs == PZBackup.VERSAO then
        self:drawText(txtVersao, self.width - 12 - larg, 16, 0.6, 0.6, 0.6, 1, FONTE)
    else
        self:drawText(txtVersao, self.width - 12 - larg, 16, 1, 0.45, 0.35, 1, FONTE)
    end
    self:desenharLegenda()

    -- Re-reads the list a moment after a request (the script answers within ~1 s)
    if self.recarregarEm then
        self.recarregarEm = self.recarregarEm - 1
        if self.recarregarEm <= 0 then
            self.recarregarEm = nil
            self:carregar(true)
        end
    end

    self:desenharDetalhes()

    -- Pin button follows the selected backup
    local _, det = self:selecionado()
    local titulo = (det and det.fixo) and PZBackup.T("jan_btn_desafixar") or PZBackup.T("jan_btn_fixar")
    if self.btnFixar.title ~= titulo then self.btnFixar:setTitle(titulo) end

    local c = self.corMensagem
    self:drawText(self.mensagem, 12, self.height - 70, c.r, c.g, c.b, 1, FONTE)
end

function PZBackupJanela:desenharDetalhes()
    local alt = getTextManager():getFontHeight(FONTE) + 2
    local y = self.lista.y + self.lista.height + 6
    local item, det = self:selecionado()
    if not item then return end
    for i, l in ipairs(PZBackup.linhasDetalhes(det)) do
        local c = l[2]
        self:drawText(l[1], 12, y + (i - 1) * alt, c[1], c[2], c[3], 1, FONTE)
    end
end

function PZBackupJanela:avisar(texto, erro)
    self.mensagem = texto
    if erro then self.corMensagem = { r = 1, g = 0.35, b = 0.35 }
    else self.corMensagem = { r = 0.6, g = 1, b = 0.6 } end
end

-- Rebuilds one item's text and color from its details
function PZBackupJanela:atualizarItem(item)
    local det = self.detalhes[item.item]
    item.text = PZBackup.rotuloItem(item.rotuloBase, det)
    item.cor = CORES_CLASSE[PZBackup.classificar(det)]
end

-- Reads pzbackup_lista.txt (written by the script): one "name|label" line per backup,
-- newest first. Details, pins and notes come from pzbackup_detalhes.txt (v1.4 script).
-- manterSelecao: keeps the selected backup (used after a request)
function PZBackupJanela:carregar(manterSelecao)
    local anterior = nil
    if manterSelecao == true then
        local item = self.lista.items[self.lista.selected]
        anterior = item and item.item
    end
    self.detalhes = PZBackup.lerDetalhes()
    self.lista:clear()
    for _, l in ipairs(PZBackup.lerLinhas(PZBackup.ARQ_LISTA)) do
        local nome, rotulo = l:match("^([^|]+)|(.*)$")
        if nome then
            self.lista:addItem(rotulo, nome)
            local item = self.lista.items[#self.lista.items]
            item.rotuloBase = rotulo
            self:atualizarItem(item)
        end
    end
    if #self.lista.items > 0 then
        self.lista.selected = 1
        if anterior then
            for i, it in ipairs(self.lista.items) do
                if it.item == anterior then self.lista.selected = i; break end
            end
        end
    end

    if manterSelecao == true then return end
    if not PZBackup.scriptAtivo() then
        self:avisar(PZBackup.T("msg_script_parado", PZBackup.URL), true)
    elseif #self.lista.items == 0 then
        self:avisar(PZBackup.T("jan_nenhum"), true)
    else
        self:avisar(PZBackup.T("jan_dica"), false)
    end
end

-- Common checks before sending a command to the script
function PZBackupJanela:podeEnviar()
    local item = self:selecionado()
    if not item then
        self:avisar(PZBackup.T("jan_selecione"), true)
        return nil
    end
    if not PZBackup.scriptAtivo() then
        self:avisar(PZBackup.T("jan_script_parado"), true)
        return nil
    end
    return item
end

-- Detail entry of an item, created if the script hasn't sent one
function PZBackupJanela:detalheDe(item)
    local det = self.detalhes[item.item]
    if not det then
        det = { fixo = false, temInfo = false, mods = "" }
        self.detalhes[item.item] = det
    end
    return det
end

function PZBackupJanela:aoClicarFixar()
    local item = self:podeEnviar()
    if not item then return end
    local det = self:detalheDe(item)
    local fixar = not det.fixo
    if not PZBackup.acrescentar(PZBackup.ARQ_FIXAR, (fixar and "pin " or "unpin ") .. item.item .. "\n") then
        self:avisar(PZBackup.T("msg_falha_pedido"), true)
        return
    end
    -- Updates the screen right away; the list is re-read once the script answers
    det.fixo = fixar
    self:atualizarItem(item)
    self:avisar(PZBackup.T(fixar and "jan_fixando" or "jan_desafixando"), false)
    self.recarregarEm = QUADROS_RECARREGAR
end

function PZBackupJanela:aoClicarNota()
    local item = self:podeEnviar()
    if not item then return end
    local det = self:detalheDe(item)
    local janela = self
    PZBackup.pedirTexto(PZBackup.T("nota_titulo_editar"), det.nota or "", function(texto)
        if not PZBackup.acrescentar(PZBackup.ARQ_FIXAR, "note " .. item.item .. "|" .. texto .. "\n") then
            janela:avisar(PZBackup.T("msg_falha_pedido"), true)
            return
        end
        det.nota = (texto ~= "") and texto or nil
        janela:atualizarItem(item)
        janela:avisar(PZBackup.T(texto ~= "" and "jan_nota_salva" or "jan_nota_removida"), false)
        janela.recarregarEm = QUADROS_RECARREGAR
    end)
end

function PZBackupJanela:aoClicarRestaurar()
    local item, det = self:selecionado()
    if not item then
        self:avisar(PZBackup.T("jan_selecione"), true)
        return
    end
    if not PZBackup.scriptAtivo() then
        self:avisar(PZBackup.T("jan_script_parado"), true)
        return
    end
    local texto = PZBackup.T("jan_confirmar", item.text)
    local altura = 240
    -- Bitten / taken just before a death: say so before restoring
    local classe = PZBackup.classificar(det)
    if classe == "mordido" then
        texto = texto .. "\n\n" .. PZBackup.T("jan_confirmar_mordido"); altura = altura + 40
    elseif det and det.morte_seg then
        texto = texto .. "\n\n" .. PZBackup.T("jan_confirmar_morte", det.morte_seg); altura = altura + 40
    end
    -- Mods that differ: name them so the player knows what to re-enable/disable
    if det and det.temInfo and det.mods ~= "" then
        local faltam, novos = PZBackup.compararMods(det.mods)
        if #faltam > 0 or #novos > 0 then
            texto = texto .. "\n\n" .. PZBackup.T("jan_confirmar_mods")
            if #faltam > 0 then texto = texto .. "\n" .. PZBackup.T("jan_mods_so_backup", juntar(faltam, MAX_MODS_DIALOGO)) end
            if #novos > 0 then texto = texto .. "\n" .. PZBackup.T("jan_mods_so_agora", juntar(novos, MAX_MODS_DIALOGO)) end
            altura = altura + 80
        end
    end
    local dlg = ISModalDialog:new(
        (getCore():getScreenWidth() - 560) / 2, (getCore():getScreenHeight() - altura) / 2,
        560, altura, texto, true, self, PZBackupJanela.aoConfirmar, nil, item.item)
    dlg:initialise()
    dlg:addToUIManager()
    pcall(function() dlg:setAlwaysOnTop(true) end)
end

function PZBackupJanela:aoConfirmar(botao, nome)
    if botao.internal ~= "YES" then return end
    if not PZBackup.gravar(PZBackup.ARQ_RESTAURAR, nome .. "\n") then
        self:avisar(PZBackup.T("falha_pedido_restauro"), true)
        return
    end
    print("[PZBackup] restore requested: " .. tostring(nome))
    self:avisar(PZBackup.T("auto_fechando"), false)
    fecharJogo()
end

function PZBackupJanela:verLog()
    if PZBackup.abrirLog then PZBackup.abrirLog() end
end

function PZBackupJanela:fechar()
    self:setVisible(false)
    self:removeFromUIManager()
    PZBackup.janela = nil
end

------------------------------------------------------------------------
-- Opens (or closes, if already open)
------------------------------------------------------------------------
function PZBackup.abrirJanela()
    if PZBackup.janela then
        PZBackup.janela:fechar()
        return
    end
    local j = PZBackupJanela:new()
    j:initialise()
    j:addToUIManager()
    pcall(function() j:setAlwaysOnTop(true) end)
    pcall(function() j:bringToTop() end)
    PZBackup.janela = j
end
