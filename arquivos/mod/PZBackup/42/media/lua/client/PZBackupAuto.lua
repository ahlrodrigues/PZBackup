--[[
  PZ Backup — restauração automática ao morrer

  Com a opção "Ao morrer, restaurar o backup mais recente automaticamente"
  ligada (Opções > Mods > PZ Backup), a morte abre este painel com uma
  contagem regressiva. Ao terminar (ou em "Restaurar agora"), o mod pede ao
  script o backup mais recente DESTE mundo e fecha o jogo. O script restaura
  e reabre o jogo: no menu principal, é só clicar em Continuar.

  Botões: Restaurar agora / Escolher outro (abre a lista) / Cancelar.
]]

require "ISUI/ISPanel"
require "ISUI/ISButton"

PZBackupAuto = ISPanel:derive("PZBackupAuto")

local LARGURA, ALTURA = 460, 150

local function agoraMs()
    local ok, v = pcall(function() return getTimestampMs() end)
    if ok and v then return v end
    return getTimestamp() * 1000
end

function PZBackupAuto:new(modoMundo)
    local x = (getCore():getScreenWidth() - LARGURA) / 2
    local y = getCore():getScreenHeight() * 0.18
    local o = ISPanel:new(x, y, LARGURA, ALTURA)
    setmetatable(o, self)
    self.__index = self
    o.backgroundColor = { r = 0.08, g = 0.02, b = 0.02, a = 0.92 }
    o.borderColor = { r = 1, g = 0.3, b = 0.3, a = 0.7 }
    o.moveWithMouse = true
    o.modoMundo = modoMundo
    o.fim = agoraMs() + PZBackup.SEGUNDOS_AUTO * 1000
    o.disparado = false
    return o
end

function PZBackupAuto:createChildren()
    ISPanel.createChildren(self)
    local y = self.height - 40
    self.btnAgora = ISButton:new(12, y, 140, 28, "Restaurar agora", self, PZBackupAuto.disparar)
    self.btnAgora:initialise(); self:addChild(self.btnAgora)
    self.btnOutro = ISButton:new(160, y, 140, 28, "Escolher outro", self, PZBackupAuto.escolherOutro)
    self.btnOutro:initialise(); self:addChild(self.btnOutro)
    self.btnCancelar = ISButton:new(self.width - 132, y, 120, 28, "Cancelar", self, PZBackupAuto.cancelar)
    self.btnCancelar:initialise(); self:addChild(self.btnCancelar)
end

function PZBackupAuto:prerender()
    ISPanel.prerender(self)
    local resta = math.max(0, math.ceil((self.fim - agoraMs()) / 1000))
    self:drawText("Personagem morto", 12, 10, 1, 0.5, 0.5, 1, UIFont.Medium)
    if self.disparado then
        self:drawText("Fechando o jogo para restaurar...", 12, 40, 1, 1, 1, 1, UIFont.Small)
    else
        self:drawText("Restaurando o backup mais recente deste mundo em " .. resta .. " s.",
            12, 40, 1, 1, 1, 1, UIFont.Small)
        self:drawText("O jogo fecha, restaura e reabre: depois clique em Continuar.",
            12, 60, 0.8, 0.8, 0.8, 1, UIFont.Small)
    end
    if not self.disparado and not self.fechado and resta <= 0 then self:disparar() end
end

function PZBackupAuto:disparar()
    if self.disparado or self.fechado then return end
    self.disparado = true
    if not PZBackup.scriptAtivo() then
        self.disparado = false
        PZBackup.mostrar("Script de backup nao esta rodando: restauracao cancelada", true)
        self:fechar()
        return
    end
    -- "AUTO modo/mundo": o script escolhe o backup mais recente desse mundo
    if not PZBackup.gravar(PZBackup.ARQ_RESTAURAR, "AUTO " .. self.modoMundo .. "\n") then
        PZBackup.mostrar("Falha ao gravar o pedido de restauracao", true)
        self:fechar()
        return
    end
    print("[PZBackup] restauracao automatica pedida: " .. tostring(self.modoMundo))
    PZBackup.fecharJogo()
end

function PZBackupAuto:escolherOutro()
    self:fechar()
    if PZBackup.abrirJanela and not PZBackup.janela then PZBackup.abrirJanela() end
end

function PZBackupAuto:cancelar()
    self:fechar()
    PZBackup.mostrar("Restauracao automatica cancelada. F9 abre a lista de backups", true)
end

function PZBackupAuto:fechar()
    self.fechado = true
    self:setVisible(false)
    self:removeFromUIManager()
    PZBackup.painelAuto = nil
end

function PZBackup.iniciarRestauracaoAuto(modoMundo)
    if PZBackup.painelAuto then return end
    local p = PZBackupAuto:new(modoMundo)
    p:initialise()
    p:addToUIManager()
    pcall(function() p:setAlwaysOnTop(true) end)
    PZBackup.painelAuto = p
end
