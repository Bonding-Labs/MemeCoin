/ SPDX-License-Identifier: UNLICENCED
// Copyright: Bonding Labs - Begic Nedim

pragma solidity ^0.8.0; // Compile with Solidity >=0.8.0

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";  // Standard ERC20 logic from OpenZeppelin
import "@openzeppelin/contracts/access/Ownable.sol";     // Provides 'Ownable' with a constructor taking an address

//
// MemeCoin
// --------
// This ERC20 is minted entirely to its own address at construction.
// There's exactly ONE function that lets the owner distribute those tokens (distributeTokens).
// After that, no further distributions are allowed. 
// This approach is specifically for fair launches of memecoins meant, so that thus rugpulls are prevented.


contract MemeCoin is ERC20, Ownable {
    // Emitted once when all tokens get distributed from this contract to a 'to' address.
    event TokensDistributed(address indexed to, uint256 amount);

    // Tracks whether the one-time full distribution has occurred
    bool public distributed; 

    // Hybrid bonding curve parameters in 1e18 scale
    uint256 public immutable B; // base price scale
    uint256 public immutable L; // early-phase sensitivity
    uint256 public immutable E; // steepness in the mature region
    uint256 public immutable T; // transition supply = L * (e - 1)

    // Approx Euler's number in 1e18
    uint256 private constant E_1E18 = 2718281828459045235;

    // Example large limit so user can't pass zero or bizarrely large B/L/E
    uint256 private constant MAX_PARAMETER = 1e36;

    //
    // Constructor
    // -----------
    // @param name_        => token name, e.g. "MemeCoin"
    // @param symbol_      => token symbol, e.g. "MEME"
    // @param totalSupply_ => how many tokens to mint in 6-decimal units
    // @param _B           => bonding curve base price scale (1e18)
    // @param _L           => bonding curve early-phase sensitivity (1e18)
    // @param _E           => bonding curve exponential steepness (1e18)
    // @param initialOwner => address that becomes 'owner' via Ownable constructor
    //
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 totalSupply_,
        uint256 _B,
        uint256 _L,
        uint256 _E,
        address initialOwner
    )
        ERC20(name_, symbol_)         
        Ownable(initialOwner)        
    {
        // ERC20(name_, symbol_) Passes the name/symbol to the OpenZeppelin ERC20 parent
        // Ownable(initialOwner) Sets 'initialOwner' as owner in the Ownable parent

        // Basic parameter checks (we disallow 0 or extremely large values)
        require(_B > 0 && _B < MAX_PARAMETER, "Invalid B");
        require(_L > 0 && _L < MAX_PARAMETER, "Invalid L");
        require(_E > 0 && _E < MAX_PARAMETER, "Invalid E");
        require(totalSupply_ > 0, "No zero supply");
        require(initialOwner != address(0), "Owner=0");

        // Store B, L, E in immutable state
        B = _B;
        L = _L;
        E = _E;

        // Compute T = L * (e - 1), in 1e18 scale
        uint256 eMinusOne = E_1E18 - 1e18; // e in 1e18 minus 1e18 => (e - 1)
        T = (L * eMinusOne) / 1e18;

        // Mint the entire supply to this contract's own address.
        // So the contract itself holds all tokens initially.
        _mint(address(this), totalSupply_);

        // Mark 'distributed' = false; no distribution done yet.
        distributed = false;
    }

    //
    // decimals
    // --------
    // Override the default ERC20 decimals (which is 18) to 6, similar to USDT.
    //
    function decimals() public pure override returns (uint8) {
        return 6;
    }

    //
    // distributeTokens
    // ----------------
    // Single function that moves all tokens from this contract to 'to'.
    // If not called, the tokens remain locked. If called once, no further calls possible.
    //
    // @param to => recipient address
    // @param amount => must match the entire balanceOf(address(this))
    //
    function distributeTokens(address to, uint256 amount) external onlyOwner {
        // Check that we have never distributed before
        require(!distributed, "Already distributed");
        // Must send to a nonzero address
        require(to != address(0), "Invalid receiver");

        // Must match the entire contract balance
        uint256 contractBal = balanceOf(address(this));
        require(amount == contractBal, "Must distribute full supply");

        // Transfer them all out
        _transfer(address(this), to, amount);

        // Mark that distribution is done
        distributed = true;

        // Emit event that tokens have been sent
        emit TokensDistributed(to, amount);
    }
}

