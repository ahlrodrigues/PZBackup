--[[
  PZ Backup — janela "Ver log"

  O Lua do jogo só lê arquivos dentro de Zomboid/Lua/, e o log fica em
  Zomboid/BackupsSaves/. Por isso o script mantém uma cópia das últimas
  linhas em Zomboid/Lua/pzbackup_log.txt, que esta janela mostra.

  Abre pelo botão "Ver log" da janela de restauração (F9) ou em
  Opções > Mods > PZ Backup > Ver log.
]]

require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISScrollingListBox"

PZBackup = PZBackup or {}
PZBackup.ARQ_LOG = "pzbackup_log.txt"

PZBackupLogJanela = ISPanel:derive("PZBackupLogJanela")

local LARGURA, ALTURA = 720, 440
local FONTE = UIFont.Small

-- Cor de cada linha conforme o tipo de registro
local function corDaLinha(l)
    local u = string.upper(l)
    if u:find("FALHA") or u:find("FAIL") or u:find("MORTO") or u:find("DEAD")
       or u:find("ERRO") or u:find("ERROR") or u:find("NAO ") or u:find("SEM BACKUP")
       or u:find("NO BACKUP") then
        return { r = 1, g = 0.45, b = 0.45 }
    elseif u:find("%[RESTAURO%]") or u:find("%[RESTORE%]") or u:find("%[LIMPEZA%]") or u:find("%[CLEANUP%]") then
        return { r = 1, g = 0.85, b = 0.4 }
    elseif u:find("%[MOD%]") or u:find("%[MANUAL%]") then
        return { r = 0.55, g = 0.85, b = 1 }
    end
    return { r = 0.75, g = 1, b = 0.7 }
end

function PZBackupLogJanela:new()
    local x = (getCore():getScreenWidth() - LARGURA) / 2
    local y = (getCore():getScreenHeight() - ALTURA) / 2
    local o = ISPanel:new(x, y, LARGURA, ALTURA)
    setmetatable(o, self)
    self.__index = self
    o.backgroundColor = { r = 0.03, g = 0.04, b = 0.03, a = 0.94 }
    o.borderColor = { r = 0.45, g = 0.75, b = 0.35, a = 0.7 }
    o.moveWithMouse = true
    o.total = 0
    return o
end

function PZBackupLogJanela:createChildren()
    ISPanel.createChildren(self)
    self.lista = ISScrollingListBox:new(12, 40, self.width - 24, self.height - 40 - 70)
    self.lista:initialise()
    self.lista:instantiate()
    self.lista.itemheight = getTextManager():getFontHeight(FONTE) + 6
    self.lista.font = FONTE
    self.lista.drawBorder = true
    -- desenha cada linha com a sua cor
    self.lista.doDrawItem = function(lst, y, item, alt)
        local c = item.item or { r = 1, g = 1, b = 1 }
        lst:drawText(item.text, 8, y + 3, c.r, c.g, c.b, 1, lst.font)
        return y + lst.itemheight
    end
    self:addChild(self.lista)

    local yb = self.height - 38
    self.btnAtualizar = ISButton:new(12, yb, 120, 28, PZBackup.T("jan_btn_atualizar"), self, PZBackupLogJanela.carregar)
    self.btnAtualizar:initialise(); self:addChild(self.btnAtualizar)
    self.btnFechar = ISButton:new(self.width - 132, yb, 120, 28, PZBackup.T("jan_btn_fechar"), self, PZBackupLogJanela.fechar)
    self.btnFechar:initialise(); self:addChild(self.btnFechar)

    self:carregar()
end

function PZBackupLogJanela:prerender()
    ISPanel.prerender(self)
    self:drawText(PZBackup.T("log_titulo"), 12, 10, 1, 1, 1, 1, UIFont.Medium)
    local rodape = self.total > 0 and PZBackup.T("log_rodape", self.total) or PZBackup.T("log_vazio")
    self:drawText(rodape, 12, self.height - 62, 0.7, 0.7, 0.7, 1, FONTE)
end

-- Mais recentes no topo
function PZBackupLogJanela:carregar()
    self.lista:clear()
    local linhas = PZBackup.lerLinhas(PZBackup.ARQ_LOG)
    for i = #linhas, 1, -1 do
        self.lista:addItem(linhas[i], corDaLinha(linhas[i]))
    end
    self.total = #linhas
    if self.total > 0 then self.lista.selected = 1 end
end

function PZBackupLogJanela:fechar()
    self:setVisible(false)
    self:removeFromUIManager()
    PZBackup.janelaLog = nil
end

-- Abre (ou fecha, se já estiver aberta)
function PZBackup.abrirLog()
    if PZBackup.janelaLog then
        PZBackup.janelaLog:fechar()
        return
    end
    local j = PZBackupLogJanela:new()
    j:initialise()
    j:addToUIManager()
    pcall(function() j:setAlwaysOnTop(true) end)
    pcall(function() j:bringToTop() end)
    PZBackup.janelaLog = j
end
