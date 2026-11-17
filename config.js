// Astromine — deployment config. Addresses are filled in by scripts/deploy.mjs.
window.ASTROMINE_CONFIG = {
  chainId: 56,
  rpc: "https://bsc-dataseed.binance.org",
  explorer: "https://bscscan.com",
  minersContract: "0x02b60c20abb77873590752571a8f941dB773fF79", // Astrominers (NFT), BSC mainnet
  astroToken: "0xBE6352376026A7Ed6bFc3854E99cD90415bAcFfe", // $ASTRO (BEP-20), BSC mainnet
  miningContract: "0x278c69e1cb6871a7d9da41026453859ea8fd3187", // AstromineMiningV2 (5% claim fee), BSC mainnet
  agentIdRegistry: "0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F", // SPACE ID Agent ID, BSC mainnet
  maxSupply: 10000,
  baseUrl: "https://astromine-miners.pages.dev"
};
