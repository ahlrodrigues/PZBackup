--[[
  PZ Backup — "what's new" window

  Shown once per version when the game loads. The version shown is kept in
  Zomboid/Lua/pzbackup_visto.txt. "Open on Workshop" opens the mod's Steam Workshop page.
]]

require "ISUI/ISPanel"
require "ISUI/ISButton"

PZBackupNovidades = ISPanel:derive("PZBackupNovidades")

local LARGURA, ALTURA = 600, 240

function PZBackupNovidades:new()
    local x = (getCore():getScreenWidth() - LARGURA) / 2
    local y = (getCore():getScreenHeight() - ALTURA) / 2
    local o = ISPanel:new(x, y, LARGURA, ALTURA)
    setmetatable(o, self)
    self.__index = self
    o.backgroundColor = { r = 0.03, g = 0.04, b = 0.03, a = 0.95 }
    o.borderColor = { r = 0.45, g = 0.75, b = 0.35, a = 0.8 }
    o.moveWithMouse = true
    return o
end

function PZBackupNovidades:createChildren()
    ISPanel.createChildren(self)
    local yb = self.height - 42
    self.btnWorkshop = ISButton:new(self.width / 2 - 150, yb, 140, 28,
        PZBackup.T("novidades_botao_workshop"), self, PZBackupNovidades.abrirWorkshop)
    self.btnWorkshop:initialise()
    self:addChild(self.btnWorkshop)
    self.btnFechar = ISButton:new(self.width / 2 + 10, yb, 120, 28,
        PZBackup.T("jan_btn_fechar"), self, PZBackupNovidades.fechar)
    self.btnFechar:initialise()
    self:addChild(self.btnFechar)
end

function PZBackupNovidades:abrirWorkshop()
    openUrl(PZBackup.URL_WORKSHOP)
end

function PZBackupNovidades:prerender()
    ISPanel.prerender(self)
    self:drawText(PZBackup.T("novidades_titulo", PZBackup.VERSAO), 14, 12, 1, 1, 1, 1, UIFont.Medium)
    local y = 52
    for i = 1, 3 do
        self:drawText("- " .. PZBackup.T("novidades_" .. i), 14, y, 0.85, 1, 0.8, 1, UIFont.Small)
        y = y + 24
    end
    self:drawText(PZBackup.T("novidades_obrigado"), 14, y + 14, 0.75, 1, 0.7, 1, UIFont.Small)
end

function PZBackupNovidades:fechar()
    self:setVisible(false)
    self:removeFromUIManager()
    PZBackup.janelaNovidades = nil
end

-- Marked as seen when it opens, so closing the game early doesn't bring it back
local function aoIniciarJogo()
    if PZBackup.lerLinhas(PZBackup.ARQ_VISTO)[1] == PZBackup.VERSAO then return end
    PZBackup.gravar(PZBackup.ARQ_VISTO, PZBackup.VERSAO .. "\n")
    local j = PZBackupNovidades:new()
    j:initialise()
    j:addToUIManager()
    j:setAlwaysOnTop(true)
    j:bringToTop()
    PZBackup.janelaNovidades = j
end
Events.OnGameStart.Add(aoIniciarJogo)
