--[[
  PZ Backup — "View log" window

  The game's Lua can only read files inside Zomboid/Lua/, and the log lives in
  Zomboid/BackupsSaves/. So the script keeps a copy of the last lines in
  Zomboid/Lua/pzbackup_log.txt, which this window shows.

  Opened by the "View log" button in the restore window (F9) or in
  Options > Mods > PZ Backup > View log.
]]

require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISScrollingListBox"

PZBackup = PZBackup or {}
PZBackup.ARQ_LOG = "pzbackup_log.txt"

PZBackupLogJanela = ISPanel:derive("PZBackupLogJanela")

local LARGURA, ALTURA = 720, 440
local FONTE = UIFont.Small

-- Color of each line by entry type
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
    -- draw each line in its color
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

-- Newest on top
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

-- Opens (or closes, if already open)
function PZBackup.abrirLog()
    if PZBackup.janelaLog then
        PZBackup.janelaLog:fechar()
        return
    end
    local j = PZBackupLogJanela:new()
    j:initialise()
    j:addToUIManager()
    j:setAlwaysOnTop(true)
    j:bringToTop()
    PZBackup.janelaLog = j
end
