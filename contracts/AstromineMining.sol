// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IAstrominers {
    function tokensOf(address w) external view returns (uint256[] memory);
    function tierOf(uint256 tokenId) external view returns (uint8);
}

interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/// @title AstromineMining — revealed Astromine Miners earn $ASTRO over time.
/// @notice Rates per Miner per hour by tier: Cadet 10 · Engineer 20 · Pilot 40 ·
/// Commander 75 · Admiral 150 ASTRO. Each wallet's storage cap is 48 hours of
/// its current rate; when storage is full, mining pauses until claim().
/// start() begins the clock. claim() pays everything accrued and re-reads the
/// wallet's Miners, so Miners bought or sold take full effect from the next
/// claim. Until then the LOWER of the snapshot rate and the live rate applies,
/// so Miners cannot be borrowed for a single inflated claim.
/// The contract pays only from the ASTRO stocked into it (the mining
/// allocation); if it ever runs dry, claim() pays what remains.
contract AstromineMining {
    IAstrominers public immutable miners;
    IERC20 public immutable token;
    uint256 public constant CAP_HOURS = 48;

    struct UserInfo {
        bool started;
        uint64 lastTime;
        uint256 rate; // snapshot, wei per hour
        uint256 cap; // snapshot, wei
        uint256 claimedTotal;
    }
    mapping(address => UserInfo) private _users;

    event Started(address indexed user, uint256 rate, uint256 cap);
    event Claimed(address indexed user, uint256 amount, uint256 rate, uint256 cap);

    constructor(address miners_, address token_) {
        require(miners_ != address(0) && token_ != address(0), "bad address");
        miners = IAstrominers(miners_);
        token = IERC20(token_);
    }

    /// @notice ASTRO per hour for one Miner of the given tier (wei).
    function rateOfTier(uint8 tier) public pure returns (uint256) {
        if (tier == 0) return 10 ether;
        if (tier == 1) return 20 ether;
        if (tier == 2) return 40 ether;
        if (tier == 3) return 75 ether;
        if (tier == 4) return 150 ether;
        return 0; // sealed (255) or invalid earns nothing
    }

    /// @notice Live mining rate of a wallet from the Miners it holds right now.
    function liveRate(address user) public view returns (uint256 rate) {
        uint256[] memory ids = miners.tokensOf(user);
        for (uint256 i = 0; i < ids.length; i++) {
            rate += rateOfTier(miners.tierOf(ids[i]));
        }
    }

    function _liveCap(uint256 rate) internal pure returns (uint256) {
        return rate * CAP_HOURS;
    }

    /// @notice Full state for agents UIs: (started, lastTime, amount claimable
    /// now, snapshot rate, snapshot cap, live next rate, live next cap, total claimed).
    function state(address user) external view returns (
        bool started, uint64 lastTime, uint256 amount, uint256 rate, uint256 cap,
        uint256 nextRate, uint256 nextCap, uint256 claimed
    ) {
        UserInfo storage u = _users[user];
        started = u.started;
        lastTime = u.lastTime;
        rate = u.rate;
        cap = u.cap;
        claimed = u.claimedTotal;
        nextRate = liveRate(user);
        nextCap = _liveCap(nextRate);
        amount = _pending(user);
    }

    function _pending(address user) internal view returns (uint256) {
        UserInfo storage u = _users[user];
        if (!u.started) return 0;
        uint256 live = liveRate(user);
        uint256 effRate = u.rate < live ? u.rate : live;
        uint256 liveCap = _liveCap(live);
        uint256 effCap = u.cap < liveCap ? u.cap : liveCap;
        uint256 accrued = (effRate * (block.timestamp - u.lastTime)) / 3600;
        return accrued < effCap ? accrued : effCap;
    }

    function start() external {
        UserInfo storage u = _users[msg.sender];
        require(!u.started, "already started");
        uint256 rate = liveRate(msg.sender);
        require(rate > 0, "no revealed miner");
        u.started = true;
        u.lastTime = uint64(block.timestamp);
        u.rate = rate;
        u.cap = _liveCap(rate);
        emit Started(msg.sender, rate, u.cap);
    }

    function claim() external returns (uint256 paid) {
        UserInfo storage u = _users[msg.sender];
        require(u.started, "not started");
        paid = _pending(msg.sender);
        uint256 bal = token.balanceOf(address(this));
        if (paid > bal) paid = bal;
        // Re-snapshot from current holdings before paying, so the clock
        // restarts at the live rate even when the payout was capped.
        u.rate = liveRate(msg.sender);
        u.cap = _liveCap(u.rate);
        u.lastTime = uint64(block.timestamp);
        u.claimedTotal += paid;
        if (paid > 0) {
            require(token.transfer(msg.sender, paid), "transfer failed");
        }
        emit Claimed(msg.sender, paid, u.rate, u.cap);
    }
}
