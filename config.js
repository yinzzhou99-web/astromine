// Astromine — deployment config. Addresses are filled in by scripts/deploy.mjs.
window.ASTROMINE_CONFIG = {
  chainId: 56,
  rpc: "https://bsc-dataseed.binance.org",
  explorer: "https://bscscan.com",
  minersContract: "0x02b60c20abb77873590752571a8f941dB773fF79", // Astrominers (NFT), BSC mainnet
  astroToken: "0xBE6352376026A7Ed6bFc3854E99cD90415bAcFfe", // $ASTRO (BEP-20), BSC mainnet
  miningContract: "0xdbA9e95D86EC56e24510722b8688cCCb5C6b52bD", // AstromineMining, BSC mainnet
  agentIdRegistry: "0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F", // SPACE ID Agent ID, BSC mainnet
  maxSupply: 10000,
  baseUrl: "https://yinzzhou99-web.github.io/astromine"
};
