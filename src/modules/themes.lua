-- Theme module factory. Theme palettes and repaint behavior are isolated from core.
local function createThemesModule(deps)
    local JL = deps.JL
    local C = deps.Colors
    local ACCENTS = deps.Accents
    local shared = deps.Shared
    local Color3 = deps.Color3
    local pcall = deps.PCall
    local pairs = deps.Pairs
    local ipairs = deps.IPairs
    local themes = {
        Midnight = {
            panel=Color3.fromRGB(40,40,44),    pHdr=Color3.fromRGB(31,31,35),
            border=Color3.fromRGB(66,66,72),   txt=Color3.fromRGB(240,240,242),
            dim=Color3.fromRGB(150,150,158),   togOn=Color3.fromRGB(46,204,113),
            togOff=Color3.fromRGB(28,28,32),   slTrack=Color3.fromRGB(58,58,64),
            btnBg=Color3.fromRGB(50,50,55),    btnHov=Color3.fromRGB(66,66,73),
            sidebar=Color3.fromRGB(28,28,31),  fpsGrn=Color3.fromRGB(72,214,92),
            badge=Color3.fromRGB(33,33,37),    badgeHi=Color3.fromRGB(50,60,90),
            divLine=Color3.fromRGB(70,70,76),  input=Color3.fromRGB(50,50,55),
            danger=Color3.fromRGB(200,68,68),  backdrop=Color3.fromRGB(16,16,18),
            accents={Color3.fromRGB(82,152,255),Color3.fromRGB(148,92,255),Color3.fromRGB(72,198,138),
                     Color3.fromRGB(255,132,72),Color3.fromRGB(255,72,108),Color3.fromRGB(72,208,208)},
        },
        Nord = {
            panel=Color3.fromRGB(46,52,64),    pHdr=Color3.fromRGB(38,43,53),
            border=Color3.fromRGB(76,86,106),  txt=Color3.fromRGB(236,239,244),
            dim=Color3.fromRGB(148,161,178),   togOn=Color3.fromRGB(163,190,140),
            togOff=Color3.fromRGB(30,34,42),   slTrack=Color3.fromRGB(59,66,82),
            btnBg=Color3.fromRGB(59,66,82),    btnHov=Color3.fromRGB(76,86,106),
            sidebar=Color3.fromRGB(36,41,51),  fpsGrn=Color3.fromRGB(163,190,140),
            badge=Color3.fromRGB(41,46,57),    badgeHi=Color3.fromRGB(59,81,108),
            divLine=Color3.fromRGB(76,86,106), input=Color3.fromRGB(59,66,82),
            danger=Color3.fromRGB(191,97,106), backdrop=Color3.fromRGB(22,25,31),
            accents={Color3.fromRGB(136,192,208),Color3.fromRGB(129,161,193),Color3.fromRGB(94,129,172),
                     Color3.fromRGB(163,190,140),Color3.fromRGB(235,203,139),Color3.fromRGB(180,142,173)},
        },
        Dracula = {
            panel=Color3.fromRGB(47,50,69),    pHdr=Color3.fromRGB(33,34,44),
            border=Color3.fromRGB(68,71,90),   txt=Color3.fromRGB(248,248,242),
            dim=Color3.fromRGB(98,114,164),    togOn=Color3.fromRGB(80,250,123),
            togOff=Color3.fromRGB(26,27,35),   slTrack=Color3.fromRGB(60,63,82),
            btnBg=Color3.fromRGB(58,61,80),    btnHov=Color3.fromRGB(74,77,98),
            sidebar=Color3.fromRGB(30,31,41),  fpsGrn=Color3.fromRGB(80,250,123),
            badge=Color3.fromRGB(36,37,48),    badgeHi=Color3.fromRGB(68,55,92),
            divLine=Color3.fromRGB(68,71,90),  input=Color3.fromRGB(58,61,80),
            danger=Color3.fromRGB(255,85,85),  backdrop=Color3.fromRGB(19,20,26),
            accents={Color3.fromRGB(255,121,198),Color3.fromRGB(189,147,249),Color3.fromRGB(80,250,123),
                     Color3.fromRGB(255,184,108),Color3.fromRGB(139,233,253),Color3.fromRGB(255,85,85)},
        },
        Emerald = {
            panel=Color3.fromRGB(24,36,30),    pHdr=Color3.fromRGB(17,27,22),
            border=Color3.fromRGB(45,71,58),   txt=Color3.fromRGB(228,242,234),
            dim=Color3.fromRGB(126,161,143),   togOn=Color3.fromRGB(52,211,153),
            togOff=Color3.fromRGB(14,22,18),   slTrack=Color3.fromRGB(37,58,48),
            btnBg=Color3.fromRGB(33,51,42),    btnHov=Color3.fromRGB(45,71,58),
            sidebar=Color3.fromRGB(16,25,21),  fpsGrn=Color3.fromRGB(74,222,128),
            badge=Color3.fromRGB(19,29,24),    badgeHi=Color3.fromRGB(24,64,48),
            divLine=Color3.fromRGB(45,71,58),  input=Color3.fromRGB(33,51,42),
            danger=Color3.fromRGB(220,90,90),  backdrop=Color3.fromRGB(9,15,12),
            accents={Color3.fromRGB(52,211,153),Color3.fromRGB(16,185,129),Color3.fromRGB(110,231,183),
                     Color3.fromRGB(251,191,36),Color3.fromRGB(34,211,238),Color3.fromRGB(163,230,182)},
        },
        Crimson = {
            panel=Color3.fromRGB(36,20,23),    pHdr=Color3.fromRGB(26,14,16),
            border=Color3.fromRGB(74,32,40),   txt=Color3.fromRGB(245,230,232),
            dim=Color3.fromRGB(166,122,128),   togOn=Color3.fromRGB(239,68,68),
            togOff=Color3.fromRGB(20,11,12),   slTrack=Color3.fromRGB(58,32,37),
            btnBg=Color3.fromRGB(48,27,31),    btnHov=Color3.fromRGB(74,32,40),
            sidebar=Color3.fromRGB(24,13,15),  fpsGrn=Color3.fromRGB(129,222,105),
            badge=Color3.fromRGB(28,16,18),    badgeHi=Color3.fromRGB(74,24,30),
            divLine=Color3.fromRGB(74,32,40),  input=Color3.fromRGB(48,27,31),
            danger=Color3.fromRGB(220,38,38),  backdrop=Color3.fromRGB(12,7,8),
            accents={Color3.fromRGB(239,68,68),Color3.fromRGB(248,113,113),Color3.fromRGB(251,146,60),
                     Color3.fromRGB(251,191,36),Color3.fromRGB(255,107,129),Color3.fromRGB(190,60,60)},
        },
        Cyberpunk = {
            panel=Color3.fromRGB(20,18,28),    pHdr=Color3.fromRGB(12,10,18),
            border=Color3.fromRGB(58,42,82),   txt=Color3.fromRGB(240,233,255),
            dim=Color3.fromRGB(139,122,168),   togOn=Color3.fromRGB(5,255,161),
            togOff=Color3.fromRGB(10,9,16),    slTrack=Color3.fromRGB(42,34,58),
            btnBg=Color3.fromRGB(34,28,48),    btnHov=Color3.fromRGB(58,42,82),
            sidebar=Color3.fromRGB(14,12,20),  fpsGrn=Color3.fromRGB(5,255,161),
            badge=Color3.fromRGB(17,14,24),    badgeHi=Color3.fromRGB(58,20,72),
            divLine=Color3.fromRGB(58,42,82),  input=Color3.fromRGB(34,28,48),
            danger=Color3.fromRGB(255,46,146), backdrop=Color3.fromRGB(8,6,13),
            accents={Color3.fromRGB(255,46,146),Color3.fromRGB(0,245,255),Color3.fromRGB(176,38,255),
                     Color3.fromRGB(255,225,86),Color3.fromRGB(5,255,161),Color3.fromRGB(255,110,199)},
        },
        Amoled = {
            panel=Color3.fromRGB(8,8,8),       pHdr=Color3.fromRGB(3,3,3),
            border=Color3.fromRGB(32,32,32),   txt=Color3.fromRGB(245,245,245),
            dim=Color3.fromRGB(140,140,140),   togOn=Color3.fromRGB(59,130,246),
            togOff=Color3.fromRGB(2,2,2),      slTrack=Color3.fromRGB(28,28,28),
            btnBg=Color3.fromRGB(18,18,18),    btnHov=Color3.fromRGB(32,32,32),
            sidebar=Color3.fromRGB(4,4,4),     fpsGrn=Color3.fromRGB(74,222,128),
            badge=Color3.fromRGB(5,5,5),       badgeHi=Color3.fromRGB(20,28,44),
            divLine=Color3.fromRGB(34,34,34),  input=Color3.fromRGB(18,18,18),
            danger=Color3.fromRGB(239,68,68),  backdrop=Color3.fromRGB(2,2,2),
            accents={Color3.fromRGB(59,130,246),Color3.fromRGB(168,85,247),Color3.fromRGB(16,185,129),
                     Color3.fromRGB(245,158,11),Color3.fromRGB(236,72,153),Color3.fromRGB(6,182,212)},
        },
        Daylight = {
            panel=Color3.fromRGB(252,252,253), pHdr=Color3.fromRGB(243,244,247),
            border=Color3.fromRGB(222,225,231),txt=Color3.fromRGB(28,30,36),
            dim=Color3.fromRGB(120,126,138),   togOn=Color3.fromRGB(34,197,94),
            togOff=Color3.fromRGB(214,217,224),slTrack=Color3.fromRGB(224,227,233),
            btnBg=Color3.fromRGB(240,241,245), btnHov=Color3.fromRGB(226,229,236),
            sidebar=Color3.fromRGB(246,247,250),fpsGrn=Color3.fromRGB(22,163,74),
            badge=Color3.fromRGB(252,252,253), badgeHi=Color3.fromRGB(223,232,255),
            divLine=Color3.fromRGB(222,225,231),input=Color3.fromRGB(240,241,245),
            danger=Color3.fromRGB(220,38,38),  backdrop=Color3.fromRGB(252,252,253),
            accents={Color3.fromRGB(37,99,235),Color3.fromRGB(124,58,237),Color3.fromRGB(5,150,105),
                     Color3.fromRGB(217,119,6),Color3.fromRGB(219,39,119),Color3.fromRGB(8,145,178)},
        },
    }
    JL._themeOrder = {"Midnight","Nord","Dracula","Emerald","Crimson","Cyberpunk","Amoled","Daylight"}
    JL._currentTheme = "Midnight"
    JL._userTheme = "Midnight"
    JL._activeWin, JL._activeBadge = nil, nil
    JL._noRepaintRoots = {}
    local function walkRepaint(root,swap)
        local function excluded(obj)
            for _,r in ipairs(JL._noRepaintRoots) do
                if r and r.Parent and (obj == r or obj:IsDescendantOf(r)) then return true end
            end
            return false
        end
        local function paint(obj)
            if excluded(obj) then return end
            if obj:GetAttribute("JLNoRepaint") then return end
            pcall(function()
                if obj:IsA("UIStroke") then
                    local nv = swap[obj.Color:ToHex()]; if nv then obj.Color = nv end
                elseif obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
                    local nv = swap[obj.ImageColor3:ToHex()]; if nv then obj.ImageColor3 = nv end
                    if obj.BackgroundTransparency < 1 then local nv2 = swap[obj.BackgroundColor3:ToHex()]; if nv2 then obj.BackgroundColor3 = nv2 end end
                elseif obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
                    local nv = swap[obj.TextColor3:ToHex()]; if nv then obj.TextColor3 = nv end
                    if obj.BackgroundTransparency < 1 then local nv2 = swap[obj.BackgroundColor3:ToHex()]; if nv2 then obj.BackgroundColor3 = nv2 end end
                elseif obj:IsA("Frame") or obj:IsA("ScrollingFrame") then
                    if obj.BackgroundTransparency < 1 then local nv = swap[obj.BackgroundColor3:ToHex()]; if nv then obj.BackgroundColor3 = nv end end
                end
            end)
        end
        paint(root)
        for _,d in ipairs(root:GetDescendants()) do paint(d) end
    end
    local function applyTheme(name,persist)
        local theme = themes[name]; if not theme then return false end
        local oldRoles = {}; for k,v in pairs(C) do oldRoles[k] = v end
        local oldAccents = {}; for i,v in ipairs(ACCENTS) do oldAccents[i] = v end
        for k,v in pairs(theme) do if k ~= "accents" then C[k] = v end end
        if theme.accents then for i,v in ipairs(theme.accents) do ACCENTS[i] = v end end
        JL._currentTheme = name
        local swap = {}
        for k,v in pairs(oldRoles) do if C[k] then swap[v:ToHex()] = C[k] end end
        for i,v in ipairs(oldAccents) do if ACCENTS[i] then swap[v:ToHex()] = ACCENTS[i] end end
        if JL._activeWin then walkRepaint(JL._activeWin, swap) end
        if JL._activeBadge then walkRepaint(JL._activeBadge, swap) end
        for _,nd in ipairs(shared._JLNotifs or {}) do if nd and nd.f then walkRepaint(nd.f, swap) end end
        for _,r in ipairs(JL._extraRoots or {}) do if r and r.Parent then walkRepaint(r, swap) end end
        for _,fn in ipairs(JL._themeHooks or {}) do pcall(fn, name) end
        if persist then pcall(function() if JL._activeCfgSet then JL._activeCfgSet("_theme", name) end end) end
        return true
    end
    function JL:SetTheme(name)
        if not themes[name] then return false end
        JL._userTheme = name
        return applyTheme(name, true)
    end
    function JL:GetTheme() return JL._currentTheme end
    return themes
end
