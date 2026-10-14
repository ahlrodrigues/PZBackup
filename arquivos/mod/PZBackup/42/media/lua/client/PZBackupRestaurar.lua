--[[
  PZ Backup — janela de restauração

  Abre com F9 (no jogo) ou pelo botão "Restaurar backup..." em Opções > Mods.
  Ao confirmar, o mod grava o nome do backup em pzbackup_restaurar.txt e fecha
  o jogo. O script detecta o fechamento, restaura o save e reabre o jogo.
  (O jogo só lê a lista de saves ao abrir, por isso precisa reiniciar.)
]]

require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISScrollingListBox"
require "ISUI/ISModalDialog"

PZBackupJanela = ISPanel:derive("PZBackupJanela")

local LARGURA, ALTURA = 520, 420
local FONTE = UIFont.Small

------------------------------------------------------------------------
-- Fecha o jogo para o script restaurar
------------------------------------------------------------------------
local function fecharJogo()
    local core = getCore()
    if getPlayer() then
        -- Em jogo: sai para a área de trabalho (o script restaura por cima)
        if pcall(function() core:quitToDesktop() end) then return end
    end
    pcall(function() core:quit() end)
end

------------------------------------------------------------------------
-- Janela
------------------------------------------------------------------------
function PZBackupJanela:new()
    local x = (getCore():getScreenWidth() - LARGURA) / 2
    local y = (getCore():getScreenHeight() - ALTURA) / 2
    local o = ISPanel:new(x, y, LARGURA, ALTURA)
    setmetatable(o, self)
    self.__index = self
    o.backgroundColor = { r = 0.05, g = 0.05, b = 0.05, a = 0.92 }
    o.borderColor = { r = 1, g = 1, b = 1, a = 0.4 }
    o.moveWithMouse = true
    o.mensagem = ""
    o.corMensagem = { r = 1, g = 1, b = 1 }
    return o
end

function PZBackupJanela:createChildren()
    ISPanel.createChildren(self)
    local alturaLinha = getTextManager():getFontHeight(FONTE) + 8

    self.lista = ISScrollingListBox:new(12, 44, self.width - 24, self.height - 44 - 84)
    self.lista:initialise()
    self.lista:instantiate()
    self.lista.itemheight = alturaLinha
    self.lista.font = FONTE
    self.lista.drawBorder = true
    self:addChild(self.lista)

    local yBotoes = self.height - 40
    self.btnRestaurar = ISButton:new(12, yBotoes, 160, 28, "Restaurar", self, PZBackupJanela.aoClicarRestaurar)
    self.btnRestaurar:initialise()
    self:addChild(self.btnRestaurar)

    self.btnAtualizar = ISButton:new(184, yBotoes, 120, 28, "Atualizar", self, PZBackupJanela.carregar)
    self.btnAtualizar:initialise()
    self:addChild(self.btnAtualizar)

    self.btnFechar = ISButton:new(self.width - 132, yBotoes, 120, 28, "Fechar", self, PZBackupJanela.fechar)
    self.btnFechar:initialise()
    self:addChild(self.btnFechar)

    self:carregar()
end

function PZBackupJanela:prerender()
    ISPanel.prerender(self)
    self:drawText("PZ Backup - Restaurar backup", 12, 12, 1, 1, 1, 1, UIFont.Medium)
    local c = self.corMensagem
    self:drawText(self.mensagem, 12, self.height - 70, c.r, c.g, c.b, 1, FONTE)
end

function PZBackupJanela:avisar(texto, erro)
    self.mensagem = texto
    if erro then self.corMensagem = { r = 1, g = 0.35, b = 0.35 }
    else self.corMensagem = { r = 0.6, g = 1, b = 0.6 } end
end

-- Lê pzbackup_lista.txt (gerado pelo script): uma linha "nome|rótulo" por backup,
-- do mais recente para o mais antigo
function PZBackupJanela:carregar()
    self.lista:clear()
    for _, linha in ipairs(PZBackup.lerLinhas(PZBackup.ARQ_LISTA)) do
        local nome, rotulo = linha:match("^([^|]+)|(.*)$")
        if nome then self.lista:addItem(rotulo, nome) end
    end
    if #self.lista.items > 0 then self.lista.selected = 1 end

    if not PZBackup.scriptAtivo() then
        self:avisar("Script de backup nao esta rodando: restaurar nao vai funcionar.", true)
    elseif #self.lista.items == 0 then
        self:avisar("Nenhum backup encontrado.", true)
    else
        self:avisar("1 = mais recente. Escolha um backup de antes do perigo.", false)
    end
end

function PZBackupJanela:aoClicarRestaurar()
    local item = self.lista.items[self.lista.selected]
    if not item then
        self:avisar("Selecione um backup na lista.", true)
        return
    end
    if not PZBackup.scriptAtivo() then
        self:avisar("Script de backup nao esta rodando. Abra o jogo pela Steam/atalho com o PZ Backup.", true)
        return
    end
    local texto = "Restaurar o backup:\n" .. item.text ..
        "\n\nO jogo vai FECHAR, o backup sera restaurado e o jogo REABRE sozinho." ..
        "\nO progresso desde esse backup sera perdido (fica guardado em 'substituidos')."
    local dlg = ISModalDialog:new(
        (getCore():getScreenWidth() - 460) / 2, (getCore():getScreenHeight() - 180) / 2,
        460, 180, texto, true, self, PZBackupJanela.aoConfirmar, nil, item.item)
    dlg:initialise()
    dlg:addToUIManager()
    pcall(function() dlg:setAlwaysOnTop(true) end)
end

function PZBackupJanela:aoConfirmar(botao, nome)
    if botao.internal ~= "YES" then return end
    if not PZBackup.gravar(PZBackup.ARQ_RESTAURAR, nome .. "\n") then
        self:avisar("Falha ao gravar o pedido de restauracao.", true)
        return
    end
    print("[PZBackup] restauração pedida: " .. tostring(nome))
    self:avisar("Fechando o jogo para restaurar...", false)
    fecharJogo()
end

function PZBackupJanela:fechar()
    self:setVisible(false)
    self:removeFromUIManager()
    PZBackup.janela = nil
end

------------------------------------------------------------------------
-- Abre (ou fecha, se já estiver aberta)
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
