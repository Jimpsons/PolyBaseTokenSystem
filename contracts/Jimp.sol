// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Prophecy_Jimpsons is ERC20, Ownable(msg.sender), ReentrancyGuard {
    using SafeMath for uint256;

    uint256 public constant MAX_SUPPLY = 10_000_000_000 * 10**18;
    bool public initialized;
    uint256 public maxTransferAmount;
    
    // New variables for enhanced security
    uint256 public minHoldTime;              // Minimum time tokens must be held
    uint256 public maxWalletAmount;          // Maximum tokens per wallet
    bool public tradingEnabled;              // Trading status
    mapping(address => uint256) public lastTransferTime;
    mapping(address => uint256) public tokenReceiveTime;  // Track when tokens were received
    mapping(address => bool) public isBlacklisted;        // Blacklist mapping
    mapping(address => bool) public isWhitelisted;        // Whitelist mapping
    uint256 public transferCooldown;

    // Events
    event TokensInitialized(address indexed initialHolder, uint256 amount);
    event TradingEnabled(bool enabled);
    event BlacklistUpdated(address indexed account, bool status);
    event WhitelistUpdated(address indexed account, bool status);
    event SecurityParamsUpdated(
        uint256 newMaxTransfer,
        uint256 newMaxWallet,
        uint256 newHoldTime,
        uint256 newCooldown
    );

    constructor() ERC20("Prophecy Jimpsons", "Jimp") {
        initialized = false;
        maxTransferAmount = 1_000_000 * 10**18;
        maxWalletAmount = 100_000_000 * 10**18;  // 1% of total supply
        minHoldTime = 1 days;                     // 24 hours hold time
        transferCooldown = 60;                    // 60 seconds cooldown
        tradingEnabled = false;
    }

    // Modified transfer restrictions
    modifier transferCompliance(address from, address to, uint256 amount) {
        require(!isBlacklisted[from] && !isBlacklisted[to], "Address is blacklisted");
        require(tradingEnabled || isWhitelisted[from] || isWhitelisted[to], "Trading not enabled");
        
        if (!isWhitelisted[from] && !isWhitelisted[to]) {
            require(amount <= maxTransferAmount, "Transfer exceeds max amount");
            require(block.timestamp >= lastTransferTime[from].add(transferCooldown), "Cooldown active");
            
            // Check hold time
            if (tokenReceiveTime[from] != 0) {
                require(block.timestamp >= tokenReceiveTime[from].add(minHoldTime), "Hold time not met");
            }
            
            // Check max wallet amount for recipient
            uint256 recipientBalance = balanceOf(to).add(amount);
            require(recipientBalance <= maxWalletAmount, "Exceeds max wallet amount");
        }
        _;
    }

    // Enhanced transfer functions
    function transfer(address to, uint256 amount) 
        public 
        override 
        transferCompliance(msg.sender, to, amount) 
        nonReentrant 
        returns (bool) 
    {
        require(to != address(0), "Invalid recipient");
        tokenReceiveTime[to] = block.timestamp;
        lastTransferTime[msg.sender] = block.timestamp;
        return super.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint256 amount)
        public
        override
        transferCompliance(from, to, amount)
        nonReentrant
        returns (bool)
    {
        require(to != address(0), "Invalid recipient");
        tokenReceiveTime[to] = block.timestamp;
        lastTransferTime[from] = block.timestamp;
        return super.transferFrom(from, to, amount);
    }

    // Security management functions
    function setTrading(bool _enabled) external onlyOwner {
        tradingEnabled = _enabled;
        emit TradingEnabled(_enabled);
    }

    function updateBlacklist(address account, bool status) external onlyOwner {
        isBlacklisted[account] = status;
        emit BlacklistUpdated(account, status);
    }

    function updateWhitelist(address account, bool status) external onlyOwner {
        isWhitelisted[account] = status;
        emit WhitelistUpdated(account, status);
    }

    function updateSecurityParams(
        uint256 _maxTransfer,
        uint256 _maxWallet,
        uint256 _holdTime,
        uint256 _cooldown
    ) external onlyOwner {
        maxTransferAmount = _maxTransfer;
        maxWalletAmount = _maxWallet;
        minHoldTime = _holdTime;
        transferCooldown = _cooldown;
        
        emit SecurityParamsUpdated(
            _maxTransfer,
            _maxWallet,
            _holdTime,
            _cooldown
        );
    }

    // Emergency functions
    function emergencyWithdraw(address token) external onlyOwner {
        require(token != address(this), "Cannot withdraw token itself");
        uint256 amount = IERC20(token).balanceOf(address(this));
        IERC20(token).transfer(owner(), amount);
    }

    // Batch blacklist/whitelist functions
    function batchUpdateBlacklist(address[] calldata accounts, bool status) external onlyOwner {
        for(uint256 i = 0; i < accounts.length; i++) {
            isBlacklisted[accounts[i]] = status;
            emit BlacklistUpdated(accounts[i], status);
        }
    }

    function batchUpdateWhitelist(address[] calldata accounts, bool status) external onlyOwner {
        for(uint256 i = 0; i < accounts.length; i++) {
            isWhitelisted[accounts[i]] = status;
            emit WhitelistUpdated(accounts[i], status);
        }
    }
}