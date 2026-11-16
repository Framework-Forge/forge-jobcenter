JobCenter = {
    command = 'jobcenteradmin',
    ace = 'forge.jobcenter.admin',
    inheritAce = 'forge-core.admin',
    interactionDistance = 2.0,
    streamDistance = 65.0,
    defaultModel = 's_m_m_highsec_01',
    captureResource = 'screencapture',
    maxImage = 2 * 1024 * 1024,
    maxVideo = 12 * 1024 * 1024,
    mediaChunk = 512 * 1024,
    mediaBandwidth = 750000,
    mediaReadChunk = 48 * 1024,
    theme = {
        brand = 'Forge Project', name = 'Job Center', accent = '#ff7a1a',
        surface = '#0e0e11', card = '#17171c', banner = '#221916', border = '#2b2b34',
        text = '#f6f4f2', muted = '#aaa7b3', columns = 3,
    },
    catalogLimits = { npcs = 40, jobs = 100, topics = 120 },
    -- Optional HTTPS host allowlist. Empty accepts normal DNS names on HTTPS.
    mediaHosts = {},
}
