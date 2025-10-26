// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract BasedToken is ERC20, ERC20Burnable, Pausable, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    uint256 public immutable REWARD_AMOUNT;
    uint256 public constant CLAIM_COOLDOWN = 1 days;

    mapping(address => bool) public blacklisted;
    mapping(address => uint256) public lastClaim;

    constructor(uint256 initialSupply) ERC20("BasedToken", "BASED") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);

        REWARD_AMOUNT = 10 * 10**decimals();
        _mint(msg.sender, initialSupply * 10**decimals());
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function setBlacklist(address user, bool status) public onlyRole(DEFAULT_ADMIN_ROLE) {
        blacklisted[user] = status;
    }

    function claimReward() public {
        require(
            block.timestamp >= lastClaim[msg.sender] + CLAIM_COOLDOWN,
            "BasedToken: reward not ready"
        );
        require(!blacklisted[msg.sender], "BasedToken: blacklisted");

        _mint(msg.sender, REWARD_AMOUNT);
        lastClaim[msg.sender] = block.timestamp;
    }

    function _update(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(!paused(), "BasedToken: paused");
        require(!blacklisted[from], "BasedToken: sender blacklisted");
        require(!blacklisted[to], "BasedToken: recipient blacklisted");

        super._update(from, to, amount);
    }
}