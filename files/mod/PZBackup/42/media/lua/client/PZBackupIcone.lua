--[[
  PZ Backup — backup icon on screen

  A floppy disk, as on the cover, split in 5 parts. The parts start faded; each minute of
  the cycle lights one of them. When all 5 are lit the script takes the automatic backup;
  then the disk pulses briefly to show it was done and the cycle starts again.

  Click: back up now (the cycle starts again). Drag: move it anywhere; the place is kept.
]]

require "ISUI/ISPanel"

PZBackupIcone = ISPanel:derive("PZBackupIcone")

local TAMANHO = 52                    -- drawn size, like the health icon on the HUD (adjust if needed)
local LARGURA, ALTURA = TAMANHO, TAMANHO
local PARTES = 5
local INTERVALO_LEITURA = 30          -- ticks between reads of the files (~0.5 s)
local PULSO_MS = 1600                 -- pulse after a backup
local FRACO = 0.22                    -- alpha of a part that is not lit yet
local cicloInicio = nil               -- Unix time when the cycle started (nil = not started)
local ultimoLido = nil                -- last backup time seen (pulse when it changes)
local pulsoInicio = nil               -- ms when the last pulse started
local contadorLeitura = 0

local textura = getTexture("media/textures/pzbackup_disco.png")
local texturaClara = getTexture("media/textures/pzbackup_disco_claro.png")

-- Cycle start: the later of the first movement and the last backup
local function lerCiclo()
    local mov = tonumber(PZBackup.lerLinhas(PZBackup.ARQ_MOVIMENTO)[1] or "")
    local ult = tonumber(PZBackup.lerLinhas(PZBackup.ARQ_ULTIMO)[1] or "")
    local novo = ult or 0
    if ultimoLido == nil then
        ultimoLido = novo                 -- first reading: nothing to announce
    elseif novo ~= ultimoLido then
        ultimoLido = novo
        pulsoInicio = getTimestampMs()    -- a backup was just taken
        print("[PZBackup] icone: backup concluido detectado (" .. tostring(novo) .. ")")
        if PZBackup.mostrarAvisoIcone then PZBackup.mostrarAvisoIcone(PZBackup.T("icone_feito")) end
    end
    if not mov then cicloInicio = nil; return end
    cicloInicio = math.max(mov, novo)
end

-- Parts lit now: one per minute, never more than all of them
function PZBackup.partesCiclo()
    if not cicloInicio then return 0 end
    return math.min(PARTES, math.floor((PZBackup.agora() - cicloInicio) / 60))
end

Events.OnTick.Add(function()
    contadorLeitura = contadorLeitura + 1
    if contadorLeitura < INTERVALO_LEITURA then return end
    contadorLeitura = 0
    lerCiclo()
end)

local function limitar(v, minimo, maximo)
    return math.max(minimo, math.min(maximo, v))
end

-- Centre of the screen the first time after each update (and on the first run);
-- after that, the place saved by the player. The file keeps the version that saved it.
local function posicaoInicial()
    local lin = PZBackup.lerLinhas(PZBackup.ARQ_ICONE)
    local telaL, telaA = getCore():getScreenWidth(), getCore():getScreenHeight()
    local x, y = tonumber(lin[1] or ""), tonumber(lin[2] or "")
    if not x or not y or lin[3] ~= PZBackup.VERSAO then
        x, y = (telaL - LARGURA) / 2, (telaA - ALTURA) / 2
    end
    return limitar(x, 0, telaL - LARGURA), limitar(y, 0, telaA - ALTURA)
end

function PZBackupIcone:new(x, y)
    local o = ISPanel:new(x, y, LARGURA, ALTURA)
    setmetatable(o, self)
    self.__index = self
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }   -- no box: only the disk
    o.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    o.moveWithMouse = true
    return o
end

local DISCO_TOPO, DISCO_BASE = 0.15, 0.85   -- vertical extent of the disk inside the texture
local PULSO_ESCALA, PULSO_BRILHO = 0.15, 0.6

function PZBackupIcone:prerender()
    ISPanel.prerender(self)
    if not textura then return end
    local agora = getTimestampMs()
    local pulsando = pulsoInicio and agora - pulsoInicio < PULSO_MS
    local cheias = pulsando and PARTES or PZBackup.partesCiclo()
    local escala, brilho = 1, 0
    if pulsando then
        local onda = math.sin((agora - pulsoInicio) / PULSO_MS * math.pi)   -- up and down once
        escala = 1 + PULSO_ESCALA * onda
        brilho = PULSO_BRILHO * onda
    end
    local tam = TAMANHO * escala
    local x, y = (self.width - tam) / 2, (self.height - tam) / 2
    if not self.setStencilRect then
        -- no clipping in this build: whole disk, faded or lit
        self:drawTextureScaled(textura, x, y, tam, tam, cheias > 0 and 1 or FRACO, 1, 1, 1)
    else
        -- the whole disk faded; then each lit band is drawn again, clipped to its rows
        self:drawTextureScaled(textura, x, y, tam, tam, FRACO, 1, 1, 1)
        local topo = y + tam * DISCO_TOPO
        local altura = tam * (DISCO_BASE - DISCO_TOPO) / PARTES
        for i = 1, math.min(cheias, PARTES) do
            self:setStencilRect(x, topo + (i - 1) * altura, tam, altura + 1)
            self:drawTextureScaled(textura, x, y, tam, tam, 1, 1, 1, 1)
            self:clearStencilRect()
        end
    end
    if brilho > 0 then
        self:drawTextureScaled(texturaClara, x, y, tam, tam, brilho, 1, 1, 1)
    end
end

function PZBackupIcone:onMouseDown(x, y)
    ISPanel.onMouseDown(self, x, y)
    self.xInicio, self.yInicio = self:getX(), self:getY()
    return true
end

-- Moved more than a few pixels = drag (keep the place); otherwise a click = back up now
function PZBackupIcone:onMouseUp(x, y)
    ISPanel.onMouseUp(self, x, y)
    local x0, y0 = self.xInicio or self:getX(), self.yInicio or self:getY()
    local moveu = math.abs(self:getX() - x0) > 3 or math.abs(self:getY() - y0) > 3
    if moveu then
        PZBackup.gravar(PZBackup.ARQ_ICONE, self:getX() .. "\n" .. self:getY() .. "\n" .. PZBackup.VERSAO .. "\n")
    elseif PZBackup.pedirBackup then
        PZBackup.pedirBackup()
        if PZBackup.scriptAtivo() and PZBackup.mostrarAvisoIcone then PZBackup.mostrarAvisoIcone(PZBackup.T("icone_pedido")) end
    end
    return true
end

local function criarIcone()
    if PZBackup.icone then PZBackup.icone:removeFromUIManager() end
    local x, y = posicaoInicial()
    PZBackup.gravar(PZBackup.ARQ_ICONE, x .. "\n" .. y .. "\n" .. PZBackup.VERSAO .. "\n")
    local i = PZBackupIcone:new(x, y)
    i:initialise()
    i:addToUIManager()
    i:setVisible(true)
    PZBackup.icone = i
end
Events.OnGameStart.Add(criarIcone)

------------------------------------------------------------------------
-- Message under the icon, for 7 s: shown once per game launch, when the game loads
------------------------------------------------------------------------
local AVISO_MS = 7000
local avisoAtual = nil               -- { painel = ..., fim = Unix ms }
local avisoInicioMostrado = false

PZBackupAviso = ISPanel:derive("PZBackupAviso")

function PZBackupAviso:new(x, y, texto)
    local largura = getTextManager():MeasureStringX(UIFont.Small, texto) + 16
    local o = ISPanel:new(x, y, largura, 24)
    setmetatable(o, self)
    self.__index = self
    o.backgroundColor = { r = 0.03, g = 0.04, b = 0.03, a = 0.85 }
    o.borderColor = { r = 0.45, g = 0.75, b = 0.35, a = 0.8 }
    o.texto = texto
    return o
end

function PZBackupAviso:prerender()
    ISPanel.prerender(self)
    self:drawText(self.texto, 8, 4, 1, 1, 1, 1, UIFont.Small)
end

local function mostrarAviso(texto)
    if avisoAtual then avisoAtual.painel:removeFromUIManager() end
    local x, y = 0, 0
    local icone = PZBackup.icone
    local p = PZBackupAviso:new(0, 0, texto)
    if icone then
        -- centred under the icon, kept on screen
        x = icone:getX() + (LARGURA - p.width) / 2
        y = icone:getY() + ALTURA + 6
    end
    local telaL = getCore():getScreenWidth()
    x = math.max(0, math.min(telaL - p.width, x))
    p:setX(x)
    p:setY(y)
    p:initialise()
    p:addToUIManager()
    p:setVisible(true)
    avisoAtual = { painel = p, fim = getTimestampMs() + AVISO_MS }
end

PZBackup.mostrarAvisoIcone = function(texto)
    print("[PZBackup] icone: aviso '" .. tostring(texto) .. "'")
    mostrarAviso(texto)
end

Events.OnTick.Add(function()
    if avisoAtual and getTimestampMs() >= avisoAtual.fim then
        avisoAtual.painel:removeFromUIManager()
        avisoAtual = nil
    end
end)

Events.OnGameStart.Add(function()
    if avisoInicioMostrado then return end
    if not PZBackup.scriptAtivo() then return end     -- no script, the mod already says so
    avisoInicioMostrado = true
    local intervalo = tonumber(PZBackup.lerLinhas(PZBackup.ARQ_ATIVO)[3] or "") or 5
    mostrarAviso(PZBackup.T("aviso_inicio", PZBackup.VERSAO, intervalo))
end)
