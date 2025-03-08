// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./MyAccessControl.sol";
contract RewardManager is MyAccessControl{
    IERC20 public rewardToken;
    uint256 public epochDuration = 1 days;
    uint256 public currentEpoch;
    uint256 public lastEpochTime;
    uint256 public totalStaked;
    address public tokenVault;

    bytes32 public constant VAULT_ROLE = keccak256("VAULT_ROLE");

    struct StakePosition {
        uint256 amount;
        uint256 startEpoch;
    }

    struct RewardCheckpoint {
        uint256 epoch;
        uint256 rewardRate;
        uint256 cumulativeRewardPerToken;
    }

    RewardCheckpoint[] public rewardCheckpoints;
    mapping(address => uint256) public rewards;
    mapping(address => StakePosition[]) public userStakes;
    mapping(address => uint256) public userLastCheckpoint;

    event RewardClaimed(address indexed user, uint256 reward);
    event EpochUpdated(uint256 newEpoch, uint256 timestamp);
    event StakeAdded(address indexed user, uint256 amount, uint256 epoch);
    event Unstaked(address indexed user, uint256 amount, uint256 fee);
    event TokenVaultUpdated(address indexed newVault);
    event RewardRateUpdated(address indexed admin, uint256 startEpoch, uint256 newRewardRate);

    constructor(address _rewardToken, uint256 _initialRewardRate, uint256 _epochDuration){
        require(_rewardToken != address(0), "Invalid reward token address");
        rewardToken = IERC20(_rewardToken);
        epochDuration = _epochDuration;
        lastEpochTime = block.timestamp;
        currentEpoch = 1;
         rewardCheckpoints.push(RewardCheckpoint({
            epoch: 1,
            rewardRate: _initialRewardRate,
            cumulativeRewardPerToken: 0
        }));

         _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    modifier updateEpoch(){
        uint256 epochsPassed = (block.timestamp - lastEpochTime) / epochDuration;
        if(epochsPassed > 0){
            lastEpochTime += epochsPassed * epochDuration;
            currentEpoch += epochsPassed;
            emit EpochUpdated(currentEpoch, block.timestamp);
        }
        _;   
    }

    modifier onlyTokenVault() {
        require(msg.sender == address(tokenVault), "Only TokenVault can call this function");
        _;
    }

    function setTokenVault(address _tokenVault) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_tokenVault != address(0), "Invalid TokenVault address");
        tokenVault = _tokenVault;
        emit TokenVaultUpdated(_tokenVault);
    }

    function updateRewardRate(uint256 newRewardRate) external onlyRole(ADMIN_ROLE) updateEpoch {
        if (rewardCheckpoints.length == 0) {
            rewardCheckpoints.push(RewardCheckpoint({
                epoch: currentEpoch,
                rewardRate: newRewardRate,
                cumulativeRewardPerToken: 0
            }));
        } else {
            uint256 lastCheckpointIndex = rewardCheckpoints.length - 1;
            RewardCheckpoint storage lastCheckpoint = rewardCheckpoints[lastCheckpointIndex];

            uint256 rewardPerToken = lastCheckpoint.cumulativeRewardPerToken;

            if (totalStaked > 0) {
                rewardPerToken += (lastCheckpoint.rewardRate * epochDuration) / totalStaked;
            }

            rewardCheckpoints.push(RewardCheckpoint({
                epoch: currentEpoch,
                rewardRate: newRewardRate,
                cumulativeRewardPerToken: rewardPerToken
            }));
        }

        require(rewardCheckpoints.length > 0, "Checkpoint was not created!");
        emit RewardRateUpdated(msg.sender, currentEpoch, newRewardRate);
    }
    
    function addStakePosition(address user, uint256 _amount) external onlyRole(VAULT_ROLE) updateEpoch{
        require(_amount > 0, "Amount must be greater than 0");
        updateUserReward(user);

        userStakes[user].push(StakePosition({
            amount: _amount,
            startEpoch: currentEpoch
        }));

        totalStaked += _amount;

        emit StakeAdded(user, _amount, currentEpoch);
    }

    function updateUserReward(address user) internal{
        uint256 lastCheckpoint = userLastCheckpoint[user] > 0 ? userLastCheckpoint[user] : 1; 
        uint256 newCheckpoint = currentEpoch;

        if (lastCheckpoint < newCheckpoint) {
        uint256 userBalance = calculateUserBalance(user);
        uint256 rewardPerTokenOld = getCumulativeRewardPerToken(lastCheckpoint);
        uint256 rewardPerTokenNew = getCumulativeRewardPerToken(newCheckpoint);

        uint256 reward = (rewardPerTokenNew - rewardPerTokenOld) * userBalance / 1e18;
        rewards[user] += reward;
        userLastCheckpoint[user] = newCheckpoint;
    }
    }

    function getCumulativeRewardPerToken(uint256 epoch) public view returns (uint256) {
        for (uint256 i = rewardCheckpoints.length; i > 0; i--) {
            if (epoch >= rewardCheckpoints[i - 1].epoch) {
                return rewardCheckpoints[i - 1].cumulativeRewardPerToken;
            }
        }
        return 0;
    }

    function calculateUserBalance(address user) public view returns (uint256 totalBalance){
        uint256 stakeLength = userStakes[user].length;
        for (uint256 i = 0; i < stakeLength; i++) {
            totalBalance += userStakes[user][i].amount;
        }
    }

    function claimRewards(address _user) external onlyRole(VAULT_ROLE) returns (uint256) {
        updateUserReward(_user);

        uint256 reward = rewards[_user];
        require(reward > 0, "No rewards to claim!");

        rewards[_user] = 0;
        userLastCheckpoint[_user] = currentEpoch;

        require(rewardToken.transfer(_user, reward), "Reward transfer failed");
        emit RewardClaimed(_user, reward);

        return reward;
    }

    function unstakePosition(address user, uint256 _amount) external onlyRole(VAULT_ROLE) {
        require(_amount > 0, "Amount must be greater than 0");
        require(calculateUserBalance(user) >= _amount, "Insufficient staked balance");

        uint256 remaining = _amount;
        StakePosition[] storage stakes = userStakes[user];

        for (uint256 i = 0; i < stakes.length && remaining > 0; ) {
            if (stakes[i].amount > remaining) {
                stakes[i].amount -= remaining;
                remaining = 0;
            } else {
                remaining -= stakes[i].amount;
                stakes[i] = stakes[stakes.length - 1];
                stakes.pop();
            }
        }

        totalStaked -= _amount;

        emit Unstaked(user, _amount, 0);
    }

    function viewReward(address _user) external view returns (uint256) {
        uint256 lastCheckpoint = userLastCheckpoint[_user] > 0 ? userLastCheckpoint[_user] : 1;
        uint256 epochToCheck = currentEpoch;
        uint256 userBalance = calculateUserBalance(_user);
        uint256 rewardPerTokenOld = getCumulativeRewardPerToken(lastCheckpoint);
        uint256 rewardPerTokenNew = getCumulativeRewardPerToken(epochToCheck);
        uint256 reward = (rewardPerTokenNew - rewardPerTokenOld) * userBalance / 1e18;

        return rewards[_user] + reward;
    }
}