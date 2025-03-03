// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RewardManager is Ownable{
    IERC20 public rewardToken;
    uint256 public epochDuration = 1 days;
    uint256 public currentEpoch;
    uint256 public lastEpochTime;
    uint256 public totalStaked;
    uint256 public earlyUnstakeFee = 10;

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
    mapping(address => uint256) public stakeLock;

    event RewardClaimed(address indexed user, uint256 reward);
    event EpochUpdated(uint256 newEpoch, uint256 timestamp);
    event StakeAdded(address indexed user, uint256 amount, uint256 epoch);
    event RewardRateUpdated(uint256 startEpoch, uint256 newRewardRate);
    event Unstaked(address indexed user, uint256 amount, uint256 fee);

    constructor(address _rewardToken, uint256 _initialRewardRate, uint256 _epochDuration) Ownable(msg.sender){
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

    function updateRewardRate(uint256 newRewardRate) external onlyOwner updateEpoch {
        uint256 lastCheckpointIndex = rewardCheckpoints.length - 1;
        RewardCheckpoint storage lastCheckpoint = rewardCheckpoints[lastCheckpointIndex];

        if(totalStaked >0){
            uint256 rewardPerToken = lastCheckpoint.cumulativeRewardPerToken + (lastCheckpoint.rewardRate * epochDuration) / totalStaked;
            rewardCheckpoints[lastCheckpointIndex].cumulativeRewardPerToken = rewardPerToken;
        }

         rewardCheckpoints.push(RewardCheckpoint({
            epoch: currentEpoch,
            rewardRate: newRewardRate,
            cumulativeRewardPerToken: rewardCheckpoints[lastCheckpointIndex].cumulativeRewardPerToken
        }));

        emit RewardRateUpdated(currentEpoch, newRewardRate);
    }

    
    function addStakePosition(uint256 _amount) external updateEpoch{
        require(_amount > 0, "Amount must be greater than 0");

        address user = msg.sender;
        updateUserReward(user);

        userStakes[user].push(StakePosition({
            amount: _amount,
            startEpoch: currentEpoch
        }));

        totalStaked += _amount;

        emit StakeAdded(user, _amount, currentEpoch);
    }

    function updateUserReward(address user) internal{
        uint256 lastCheckpoint = userLastCheckpoint[user];
        uint256 newCheckpoint = currentEpoch;

        if(lastCheckpoint < newCheckpoint){
            uint256 userBalance = calculateUserBalance(user);
            uint256 reward = (getCumulativeRewardPerToken(newCheckpoint) - getCumulativeRewardPerToken(lastCheckpoint)) * userBalance;

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
        StakePosition[] storage stakes = userStakes[user];
        for(uint256 i = 0; i< stakes.length; i ++)
            totalBalance += stakes[i].amount;
    }

    function claimRewards(address _user) external returns (uint256) {
        updateUserReward(_user);

        uint256 reward = rewards[_user];
        require(reward > 0, "No rewards to claim!");

        rewards[_user] = 0;
        require(rewardToken.transfer(_user, reward), "Reward transfer failed");

        emit RewardClaimed(_user, reward);

        return reward;
    }

    function viewReward(address _user) external view returns(uint256){
        uint256 lastCheckpoint = userLastCheckpoint[_user];
        uint256 newCheckpoint = currentEpoch;
        uint256 userBalance = calculateUserBalance(_user);

        uint256 reward = (getCumulativeRewardPerToken(newCheckpoint) - 
                          getCumulativeRewardPerToken(lastCheckpoint)) * userBalance / 1e18;

        return rewards[_user] + reward;
    }
}