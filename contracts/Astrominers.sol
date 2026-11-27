// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice The Binance / SPACE ID Agent ID registry is itself an ERC-721
/// ("SPACE ID Agent ID", symbol AI) on BSC mainnet:
/// 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F. The gate only needs balanceOf().
interface IAgentID {
    function balanceOf(address owner) external view returns (uint256);
}

/// @title Astrominers — chibi space-miner robot NFTs for Binance Agent ID holders.
/// @notice 10,000 Miners in 5 tiers with exact quotas (Cadet 4,200 · Engineer
/// 2,820 · Pilot 1,740 · Commander 900 · Admiral 340). Minting is gated to
/// wallets holding a .ai Agent ID. The first Miner per wallet is free; later
/// mints cost 0.0003 / 0.0006 / 0.0009 BNB in steps, max 30 per wallet. All
/// mint income is forwarded immediately to the project payee (the owner's
/// MetaMask) — the contract itself never holds BNB.
/// Tiers stay sealed (255) until reveal(): the tier of every Miner in a mint
/// batch is drawn from the hash of a block 3 blocks after the mint, weighted
/// against the remaining tier quotas, so final tier totals are exact and no
/// one — including the owner — can influence or predict them at mint time.
/// If a batch's target block ages past the 256-block blockhash window before
/// being revealed, the first reveal() call re-anchors it to a fresh block.
contract Astrominers {
    string public name = "Astromine Miners";
    string public symbol = "ASTROM";
    uint256 public constant MAX_SUPPLY = 10_000;
    uint256 public constant MAX_PER_WALLET = 30;
    uint8 public constant SEALED = 255;

    IAgentID public immutable agentIDRegistry;
    address public immutable payee; // receives all mint income immediately
    address public owner;
    string public baseURI;
    bool public mintOpen = true;

    uint256 public totalMinted;
    uint256 public batchCount;
    uint256[5] public tierRemaining; // exact quotas left per tier

    struct Batch {
        address minter;
        uint256 firstId;
        uint256 qty;
        uint256 targetBlock;
        bool revealed;
    }
    mapping(uint256 => Batch) public batches;
    mapping(address => uint256) public mintedBy;
    mapping(uint256 => uint8) private _tier; // valid only when _revealed
    mapping(uint256 => bool) private _revealed;

    mapping(uint256 => address) private _ownerOf;
    mapping(address => uint256) private _balanceOf;
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;
    // enumeration (the mining contract reads a wallet's Miners from here)
    mapping(address => uint256[]) private _ownedTokens;
    mapping(uint256 => uint256) private _ownedIndex;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed o, address indexed spender, uint256 indexed tokenId);
    event ApprovalForAll(address indexed o, address indexed operator, bool approved);
    event Minted(address indexed to, uint256 firstId, uint256 qty, uint256 cost, uint256 indexed batchId, uint256 targetBlock);
    event Revealed(uint256 indexed batchId, uint256 indexed tokenId, uint8 tier);
    event BatchReanchored(uint256 indexed batchId, uint256 targetBlock);

    modifier onlyOwner() { require(msg.sender == owner, "not owner"); _; }

    /// @param registry Agent ID registry. Mainnet: 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F.
    /// @param payee_ Wallet that receives mint income (the project owner's MetaMask).
    constructor(address registry, address payee_, string memory baseURI_) {
        require(registry != address(0) && payee_ != address(0), "bad address");
        agentIDRegistry = IAgentID(registry);
        payee = payee_;
        baseURI = baseURI_;
        owner = msg.sender;
        tierRemaining = [uint256(4200), 2820, 1740, 900, 340];
    }

    // ---------- gate / pricing ----------
    function hasAgentId(address w) public view returns (bool) {
        return agentIDRegistry.balanceOf(w) > 0;
    }

    /// @notice Price of the wallet's n-th Miner (0-based count): #1 free,
    /// #2-#10 0.0003 BNB, #11-#20 0.0006 BNB, #21-#30 0.0009 BNB.
    function priceAt(uint256 countIndex) public pure returns (uint256) {
        if (countIndex == 0) return 0;
        if (countIndex < 10) return 0.0003 ether;
        if (countIndex < 20) return 0.0006 ether;
        return 0.0009 ether;
    }

    /// @notice Exact BNB value a mint(qty) call from this wallet must send.
    function quote(address w, uint256 qty) public view returns (uint256 total) {
        uint256 start = mintedBy[w];
        for (uint256 i = 0; i < qty; i++) total += priceAt(start + i);
    }

    // ---------- mint ----------
    function mint(uint256 qty) external payable returns (uint256 batchId) {
        require(mintOpen, "mint closed");
        require(qty >= 1 && qty <= MAX_PER_WALLET, "bad qty");
        require(hasAgentId(msg.sender), "no Agent ID (.ai) in wallet");
        require(mintedBy[msg.sender] + qty <= MAX_PER_WALLET, "max 30 per wallet");
        require(totalMinted + qty <= MAX_SUPPLY, "sold out");
        uint256 cost = quote(msg.sender, qty);
        require(msg.value == cost, "send exact quote");

        batchId = ++batchCount;
        uint256 firstId = totalMinted + 1;
        batches[batchId] = Batch({
            minter: msg.sender,
            firstId: firstId,
            qty: qty,
            targetBlock: block.number + 3,
            revealed: false
        });
        for (uint256 i = 0; i < qty; i++) {
            _mint(msg.sender, ++totalMinted);
        }
        mintedBy[msg.sender] += qty;
        emit Minted(msg.sender, firstId, qty, cost, batchId, block.number + 3);

        if (cost > 0) {
            (bool ok, ) = payee.call{value: cost}("");
            require(ok, "payee transfer failed");
        }
    }

    // ---------- reveal ----------
    /// @notice Anyone may reveal a batch once its target block has passed.
    /// Tiers are drawn from that block's hash against the remaining quotas.
    function reveal(uint256 batchId) external {
        Batch storage b = batches[batchId];
        require(b.firstId != 0, "no such batch");
        require(!b.revealed, "already revealed");
        require(block.number > b.targetBlock, "not ready");
        bytes32 h = blockhash(b.targetBlock);
        if (h == bytes32(0)) {
            // Target block fell out of the 256-block blockhash window:
            // re-anchor to a fresh future block and return.
            b.targetBlock = block.number + 3;
            emit BatchReanchored(batchId, b.targetBlock);
            return;
        }
        b.revealed = true;
        uint256 remaining = 0;
        for (uint256 t = 0; t < 5; t++) remaining += tierRemaining[t];
        for (uint256 i = 0; i < b.qty; i++) {
            uint256 tokenId = b.firstId + i;
            uint256 r = uint256(keccak256(abi.encode(h, tokenId))) % remaining;
            uint8 tier = 4;
            for (uint8 t = 0; t < 5; t++) {
                if (r < tierRemaining[t]) { tier = t; break; }
                r -= tierRemaining[t];
            }
            tierRemaining[tier] -= 1;
            remaining -= 1;
            _tier[tokenId] = tier;
            _revealed[tokenId] = true;
            emit Revealed(batchId, tokenId, tier);
        }
    }

    /// @notice 255 while sealed, otherwise 0=Cadet 1=Engineer 2=Pilot 3=Commander 4=Admiral.
    function tierOf(uint256 tokenId) external view returns (uint8) {
        require(_ownerOf[tokenId] != address(0), "no such miner");
        return _revealed[tokenId] ? _tier[tokenId] : SEALED;
    }

    function tokensOf(address w) external view returns (uint256[] memory) {
        return _ownedTokens[w];
    }

    // ---------- admin ----------
    function setBaseURI(string calldata u) external onlyOwner { baseURI = u; }
    function setMintOpen(bool open_) external onlyOwner { mintOpen = open_; }
    function transferOwnership(address n) external onlyOwner { require(n != address(0)); owner = n; }

    // ---------- ERC-721 (minimal, standard surface) ----------
    function balanceOf(address o) external view returns (uint256) { require(o != address(0)); return _balanceOf[o]; }
    function ownerOf(uint256 id) public view returns (address) { address o = _ownerOf[id]; require(o != address(0), "no such miner"); return o; }
    function tokenURI(uint256 id) external view returns (string memory) {
        ownerOf(id);
        return string(abi.encodePacked(baseURI, _toString(id), ".json"));
    }
    function approve(address s, uint256 id) external {
        address o = ownerOf(id);
        require(msg.sender == o || _operatorApprovals[o][msg.sender], "not allowed");
        _tokenApprovals[id] = s; emit Approval(o, s, id);
    }
    function getApproved(uint256 id) external view returns (address) { ownerOf(id); return _tokenApprovals[id]; }
    function setApprovalForAll(address op, bool ok) external { _operatorApprovals[msg.sender][op] = ok; emit ApprovalForAll(msg.sender, op, ok); }
    function isApprovedForAll(address o, address op) external view returns (bool) { return _operatorApprovals[o][op]; }
    function transferFrom(address f, address t, uint256 id) public {
        require(_isAllowed(msg.sender, id), "not allowed");
        _transfer(f, t, id);
    }
    function safeTransferFrom(address f, address t, uint256 id) external { transferFrom(f, t, id); _checkReceiver(f, t, id, ""); }
    function safeTransferFrom(address f, address t, uint256 id, bytes calldata d) external { transferFrom(f, t, id); _checkReceiver(f, t, id, d); }
    function supportsInterface(bytes4 x) external pure returns (bool) {
        return x == 0x80ac58cd || x == 0x5b5e139f || x == 0x01ffc9a7 || x == 0x2a55205a;
    }

    // ---------- ERC-2981 royalty ----------
    uint96 public constant ROYALTY_BPS = 500; // 5% to the contract owner
    function royaltyInfo(uint256 id, uint256 salePrice) external view returns (address receiver, uint256 royaltyAmount) {
        ownerOf(id);
        return (owner, (salePrice * ROYALTY_BPS) / 10_000);
    }

    // ---------- internals ----------
    function _isAllowed(address s, uint256 id) internal view returns (bool) {
        address o = ownerOf(id);
        return s == o || _tokenApprovals[id] == s || _operatorApprovals[o][s];
    }
    function _mint(address t, uint256 id) internal {
        _ownerOf[id] = t; _balanceOf[t] += 1;
        _ownedIndex[id] = _ownedTokens[t].length;
        _ownedTokens[t].push(id);
        emit Transfer(address(0), t, id);
    }
    function _transfer(address f, address t, uint256 id) internal {
        require(ownerOf(id) == f && t != address(0), "bad transfer");
        delete _tokenApprovals[id];
        // remove from f's enumeration (swap-and-pop)
        uint256 idx = _ownedIndex[id];
        uint256 last = _ownedTokens[f][_ownedTokens[f].length - 1];
        _ownedTokens[f][idx] = last;
        _ownedIndex[last] = idx;
        _ownedTokens[f].pop();
        // add to t's enumeration
        _ownedIndex[id] = _ownedTokens[t].length;
        _ownedTokens[t].push(id);
        _balanceOf[f] -= 1; _balanceOf[t] += 1; _ownerOf[id] = t;
        emit Transfer(f, t, id);
    }
    function _checkReceiver(address f, address t, uint256 id, bytes memory d) internal {
        if (t.code.length > 0) {
            (bool ok, bytes memory r) = t.call(abi.encodeWithSignature("onERC721Received(address,address,uint256,bytes)", msg.sender, f, id, d));
            require(ok && r.length == 32 && abi.decode(r, (bytes4)) == bytes4(0x150b7a02), "unsafe receiver");
        }
    }
    function _toString(uint256 v) internal pure returns (string memory) {
        if (v == 0) return "0";
        uint256 n = v; uint256 digits;
        while (n > 0) { digits++; n /= 10; }
        bytes memory b = new bytes(digits);
        while (v > 0) { b[--digits] = bytes1(uint8(48 + (v % 10))); v /= 10; }
        return string(b);
    }
}
