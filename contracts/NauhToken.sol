// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract NauhToken is ERC20,AccessControl {
    address public tokenVault;
    bytes32 public constant VAULT_ROLE = keccak256("VAULT_ROLE");
    
    event TokenVaultUpdated(address indexed tokenVault);

    constructor() ERC20("NauhToken", "NAUH") {
        _mint(msg.sender, 1_000_000 * 10 ** decimals()); 
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
    
    function setTokenVault(address _tokenVault) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_tokenVault != address(0), "Invalid TokenVault address");
        tokenVault = _tokenVault;
        _grantRole(VAULT_ROLE, _tokenVault);
        emit TokenVaultUpdated(_tokenVault);
    }

    modifier onlyVault() {
        require(hasRole(VAULT_ROLE, msg.sender), "Only TokenVault can transfer tokens");
        _;
    }
}