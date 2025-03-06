// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract MyAccessControl is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MODERATOR_ROLE = keccak256("MODERATOR_ROLE");

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender); // Chủ sở hữu có toàn quyền
        _grantRole(ADMIN_ROLE, msg.sender); // Chủ sở hữu là admin đầu tiên
    }

    function addAdmin(address _admin) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(ADMIN_ROLE, _admin);
    }

    function removeAdmin(address _admin) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(ADMIN_ROLE, _admin);
    }

    function addModerator(address _mod) external onlyRole(ADMIN_ROLE) {
        _grantRole(MODERATOR_ROLE, _mod);
    }

    function removeModerator(address _mod) external onlyRole(ADMIN_ROLE) {
        _revokeRole(MODERATOR_ROLE, _mod);
    }
}
