--- Auktionshaus: Einstellungen.

Auction = Auction or {}

AuctionConfig = {}

AuctionConfig.Debug = false

--- Command fuer die Oberflaeche (nur am Auktionshaus nutzbar).
AuctionConfig.Command = 'auktionshaus'

--- Auktionatoren in der Welt.
AuctionConfig.Peds = {
    { model = 's_m_m_highsec_01', label = 'Auktionshaus Vinewood',
      coords = vector4(-1379.6, -502.5, 32.2, 302.0) },
    { model = 's_m_m_highsec_01', label = 'Auktionshaus Innenstadt',
      coords = vector4(  -74.5, -818.0, 326.2, 180.0) },
    { model = 's_m_m_highsec_01', label = 'Auktionshaus Sandy Shores',
      coords = vector4( 1692.0, 3585.0, 35.6,  25.0) },
}

--- Wie nah man stehen muss.
AuctionConfig.Range = 2.5

--- Blip auf der Karte.
AuctionConfig.Blip = {
    enabled = true,
    sprite  = 431,
    colour  = 5,
    scale   = 0.8,
    label   = 'Auktionshaus',
}

-- Auktionen ------------------------------------------------------------------

--- Auswaehlbare Laufzeiten in Stunden.
AuctionConfig.Durations = { 1, 6, 12, 24 }

--- Gebuehr des Hauses beim Verkauf (Anteil vom Erloes).
AuctionConfig.Fee = 0.05

--- Einstellgebuehr, wird beim Anlegen faellig und nicht erstattet.
AuctionConfig.ListingFee = 500

--- Konto, ueber das alles laeuft.
AuctionConfig.Account = 'bank'

--- Ein Gebot muss den aktuellen Stand um mindestens so viel uebertreffen.
AuctionConfig.MinIncrement = 100

--- Und um mindestens diesen Anteil.
AuctionConfig.MinIncrementRatio = 0.03

--- Grenzen fuer Preise und Mengen.
AuctionConfig.Limits = {
    minPrice   = 100,
    maxPrice   = 50000000,
    maxCount   = 500,
    perPlayer  = 8,          -- gleichzeitig laufende Auktionen je Charakter
}

--- Ein Gebot in den letzten Sekunden verlaengert die Auktion.
AuctionConfig.AntiSnipe = {
    enabled = true,
    within  = 120,           -- Sekunden vor Ende
    extend  = 120,           -- um so viele Sekunden verlaengern
}

--- Items, die nicht versteigert werden duerfen.
AuctionConfig.Blocked = {
    'id_card',
}

--- Kategorien fuer die Filterleiste.
--- Jedes Item, das in keiner Liste steht, landet unter "sonstiges".
AuctionConfig.Categories = {
    { id = 'alle',      label = 'Alles',       icon = '🗃' },
    { id = 'steine',    label = 'Steine',      icon = '◆',
      items = { 'runenstein', 'seelenstein' } },
    { id = 'kisten',    label = 'Kisten',      icon = '📦',
      prefix = 'kiste_' },
    { id = 'verbrauch', label = 'Verbrauch',   icon = '🍞',
      items = { 'bread', 'water', 'burger', 'cola', 'bandage', 'medikit' } },
    { id = 'werkzeug',  label = 'Werkzeug',    icon = '🔧',
      items = { 'lockpick', 'repairkit', 'phone', 'radio' } },
    { id = 'sonstiges', label = 'Sonstiges',   icon = '❖' },
}

--- Kategorie eines Items.
function Auction.GetCategory(itemName)
    for _, category in ipairs(AuctionConfig.Categories) do
        if category.prefix and itemName:sub(1, #category.prefix) == category.prefix then
            return category.id
        end

        for _, name in ipairs(category.items or {}) do
            if name == itemName then return category.id end
        end
    end

    return 'sonstiges'
end

--- Darf dieses Item versteigert werden?
function Auction.IsBlocked(itemName)
    for _, name in ipairs(AuctionConfig.Blocked) do
        if name == itemName then return true end
    end

    return false
end

--- Mindestgebot ueber einem Stand.
function Auction.MinimumBid(current)
    local step = math.max(AuctionConfig.MinIncrement,
        math.floor(current * AuctionConfig.MinIncrementRatio))

    return current + step
end
