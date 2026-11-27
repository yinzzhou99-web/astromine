// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Astromine (ASTRO) — BEP-20 token of the Astromine Miners NFT game on BNB Smart Chain.
/// @notice Fixed supply of 1,000,000,000 ASTRO, minted once in the constructor
/// to the recipient address. No owner, no tax, no mint/burn/pause functions —
/// the supply can never change after deploy. Astromine Miner NFTs earn ASTRO
/// over time through the separate AstromineMining contract, stocked from
/// this supply.
contract Astro {
    string public constant name = "Astromine";
    string public constant symbol = "ASTRO";
    uint8 public constant decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(address recipient) {
        require(recipient != address(0), "bad recipient");
        totalSupply = 1_000_000_000 * 10 ** 18;
        balanceOf[recipient] = totalSupply;
        emit Transfer(address(0), recipient, totalSupply);
    }

    function transfer(address to, uint256 value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) external returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        require(allowed >= value, "allowance");
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - value;
        }
        _transfer(from, to, value);
        return true;
    }

    function _transfer(address from, address to, uint256 value) internal {
        require(to != address(0), "to zero");
        require(balanceOf[from] >= value, "balance");
        balanceOf[from] -= value;
        balanceOf[to] += value;
        emit Transfer(from, to, value);
    }
}
