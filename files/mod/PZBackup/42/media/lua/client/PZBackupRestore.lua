--[[
  PZ Backup — restore window

  Opened with F9 (in game) or the "Restore backup..." button in Options > Mods.
  On confirm, the mod writes the backup name to pzbackup_restaurar.txt and closes
  the game. The script notices, restores the save and relaunches the game.
  (The game reads the save list only on startup, hence the restart.)
]]

require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISScrollingListBox"
require "ISUI/ISModalDialog"

PZBackupJanela = ISPanel:derive("PZBackupJanela")

local LARGURA, ALTURA = 520, 420
local FONTE = UIFont.Small

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
-- Window
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
    self.btnRestaurar = ISButton:new(12, yBotoes, 160, 28, PZBackup.T("jan_btn_restaurar"), self, PZBackupJanela.aoClicarRestaurar)
    self.btnRestaurar:initialise()
    self:addChild(self.btnRestaurar)

    self.btnAtualizar = ISButton:new(184, yBotoes, 110, 28, PZBackup.T("jan_btn_atualizar"), self, PZBackupJanela.carregar)
    self.btnAtualizar:initialise()
    self:addChild(self.btnAtualizar)

    self.btnLog = ISButton:new(304, yBotoes, 90, 28, PZBackup.T("jan_btn_log"), self, PZBackupJanela.verLog)
    self.btnLog:initialise()
    self:addChild(self.btnLog)

    self.btnFechar = ISButton:new(self.width - 112, yBotoes, 100, 28, PZBackup.T("jan_btn_fechar"), self, PZBackupJanela.fechar)
    self.btnFechar:initialise()
    self:addChild(self.btnFechar)

    self:carregar()
end

function PZBackupJanela:prerender()
    ISPanel.prerender(self)
    self:drawText(PZBackup.T("jan_titulo"), 12, 12, 1, 1, 1, 1, UIFont.Medium)
    local c = self.corMensagem
    self:drawText(self.mensagem, 12, self.height - 70, c.r, c.g, c.b, 1, FONTE)
end

function PZBackupJanela:avisar(texto, erro)
    self.mensagem = texto
    if erro then self.corMensagem = { r = 1, g = 0.35, b = 0.35 }
    else self.corMensagem = { r = 0.6, g = 1, b = 0.6 } end
end

-- Reads pzbackup_lista.txt (written by the script): one "name|label" line per backup,
-- newest first
function PZBackupJanela:carregar()
    self.lista:clear()
    for _, linha in ipairs(PZBackup.lerLinhas(PZBackup.ARQ_LISTA)) do
        local nome, rotulo = linha:match("^([^|]+)|(.*)$")
        if nome then self.lista:addItem(rotulo, nome) end
    end
    if #self.lista.items > 0 then self.lista.selected = 1 end

    if not PZBackup.scriptAtivo() then
        self:avisar(PZBackup.T("msg_script_parado", PZBackup.URL), true)
    elseif #self.lista.items == 0 then
        self:avisar(PZBackup.T("jan_nenhum"), true)
    else
        self:avisar(PZBackup.T("jan_dica"), false)
    end
end

function PZBackupJanela:aoClicarRestaurar()
    local item = self.lista.items[self.lista.selected]
    if not item then
        self:avisar(PZBackup.T("jan_selecione"), true)
        return
    end
    if not PZBackup.scriptAtivo() then
        self:avisar(PZBackup.T("jan_script_parado"), true)
        return
    end
    local texto = PZBackup.T("jan_confirmar", item.text)
    local dlg = ISModalDialog:new(
        (getCore():getScreenWidth() - 520) / 2, (getCore():getScreenHeight() - 240) / 2,
        520, 240, texto, true, self, PZBackupJanela.aoConfirmar, nil, item.item)
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
