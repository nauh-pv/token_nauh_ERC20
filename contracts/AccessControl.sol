// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";

contract AccessControl is Ownable {
    mapping(address => bool) private admins;

    constructor() Ownable(msg.sender){
         _mint(msg.sender, 1_000_000 * 10 ** decimals()); 
    }

    modifier onlyAdmin() {
        require(admins[msg.sender], "Not an admin");
        _;
    }

    function addAdmin(address _admin) external onlyOwner {
        admins[_admin] = true;
    }

    function removeAdmin(address _admin) external onlyOwner {
        admins[_admin] = false;
    }

    function isAdmin(address _admin) external view returns (bool) {
        return admins[_admin];
    }
}
