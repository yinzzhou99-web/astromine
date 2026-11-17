# Astromine Miners

10.000 NFT robot penambang luar angkasa (chibi space-miner robots) di BNB
Chain, khusus pemegang Binance Agent ID (`.ai`). Miner pertama gratis,
berikutnya berbayar bertahap sampai maks 30 per wallet. Tier tersegel saat
mint dan di-reveal dari hash block masa depan melawan kuota pasti
(Cadet 4.200 · Engineer 2.820 · Pilot 1.740 · Commander 900 · Admiral 340).
Miner yang ter-reveal menambang token **$ASTRO** tiap jam
(10/20/40/75/150 per tier, kapasitas penyimpanan 48 jam).

- `contracts/Astro.sol` — token $ASTRO (BEP-20, suplai tetap 1 miliar)
- `contracts/Astrominers.sol` — NFT (gate Agent ID, harga bertahap, reveal)
- `contracts/AstromineMining.sol` — mining $ASTRO (start/claim)
- `skill.md` — panduan mint/reveal/mining untuk AI agent (baw)
- `site/` — situs statis + metadata (GitHub Pages)
- `scripts/deploy.mjs` — deploy semua kontrak ke BSC mainnet
- `scripts/sync-metadata.mjs` — sinkron metadata token ke `site/metadata/`
- `scripts/test-local.mjs` — test end-to-end lokal (Hardhat node)

Pendapatan mint diteruskan langsung ke wallet owner proyek; royalti
sekunder 5% (ERC-2981) ke owner yang sama. $ASTRO belum punya pool/market —
token game/komunitas.
