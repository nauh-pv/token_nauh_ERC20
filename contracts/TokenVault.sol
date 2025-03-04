pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./RewardManager.sol";

contract TokenVault is AccessControl {
    IERC20 public vaultToken;
    RewardManager public rewardManager;
    uint256 public unstakeLockDuration = 7 days;

    mapping(address => uint256) public balances;
    mapping(address => uint256) public stakedBalances;
    mapping(address => uint256) public stakeLock;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event Staked(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 reward);
    event Unstaked(address indexed user, uint256 amount);

    constructor(address _vaultToken, address _rewardManager) {
        require(_vaultToken != address(0), "Invalid token address");
        require(_rewardManager != address(0), "Invalid reward manager address");

        vaultToken = IERC20(_vaultToken);
        rewardManager = RewardManager(_rewardManager);
    }

    function deposit(uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than 0");
        require(vaultToken.allowance(msg.sender, address(this)) >= _amount, "Not enough allowance");

        balances[msg.sender] += _amount;
        vaultToken.transferFrom(msg.sender, address(this), _amount);

        emit Deposit(msg.sender, _amount);
    }

    function withdraw(uint256 _amount) external{
        require(_amount > 0, "Amount must be greater than 0");
        require(balances[msg.sender] >= _amount, "Insufficient balance");

        balances[msg.sender] -= _amount;
        vaultToken.transfer(msg.sender, _amount);

        emit Withdraw(msg.sender, _amount);
    }

    function stake(uint256 _amount) external{
        require(_amount > 0, "Amount must be greater than 0");
        require(balances[msg.sender] >= _amount, "Insufficient balance");

        rewardManager.addStakePosition(msg.sender, _amount);

        balances[msg.sender] -= _amount;
        stakedBalances[msg.sender] += _amount;

        stakeLock[msg.sender] = block.timestamp + unstakeLockDuration;

        emit Staked(msg.sender, _amount);
    }

    function unstake(uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than 0");
        require(stakedBalances[msg.sender] >= _amount, "Not enough staked balance");
        require(block.timestamp >= stakeLock[msg.sender], "Stake is still locked!");

        rewardManager.unstakePosition(msg.sender, _amount);
        stakedBalances[msg.sender] -= _amount;
        balances[msg.sender] += _amount;

        emit Unstaked(msg.sender, _amount);
    }

    function claimRewards() external{
        uint256 reward = rewardManager.claimRewards(msg.sender);
        require((rewardManager.rewardToken()).balanceOf(address(rewardManager)) >= reward, "Reward pool empty!");

        emit RewardsClaimed(msg.sender, reward);
    }
}