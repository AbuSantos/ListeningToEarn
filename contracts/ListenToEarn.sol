// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
// console.log("Unlock time is %o and block timestamp is %o", unlockTime, block.timestamp);
import "hardhat/console.sol";

interface IERC20 {
    function totalSupply() external view returns (uint);

    function balanceOf(address account) external view returns (uint);

    function transfer(address recipient, uint amount) external returns (bool);

    function allowance(
        address owner,
        address spender
    ) external view returns (uint);

    function approve(address spender, uint amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);

    function burn(uint256 _value) external returns (bool success);
}

contract ListenToEarn {
    // The token being earned
    IERC20 public token;

    //The current listening time of the user
    uint256 public listeningTime;

    //The initial rate the user earned for every song listened to,at average 2.5min/song
    uint256 public initialRate;

    //The current rate the user earned after the rate has being reduced when we users increases by 1000.
    uint256 internal currentRate; //rate is updated after every 1000 user

    //The registered users count
    uint256 public registeredUser;

    //The minimum time needed to earn
    mapping(address => uint256) public listeningTimeThreshold;

    //The minimum days to get pay out
    uint256 public weekDuration = 1 weeks;

    //Registration fee.
    uint256 public immutable i_registerationFee = 5000000000000000;

    //Array of users
    address[] public users;
    mapping(address => bool) public isFirstPaid;
    mapping(address => bool) public isFirstReduction;

    mapping(address => uint256) public userBalance;
    mapping(address => uint256) public lastListeningTime;
    mapping(address => uint256) public lastRewardTime;
    mapping(address => uint256) public accumulatedListeningTime;
    mapping(address => bool) public isUser;
    mapping(address => uint256) public listeningSessionStartTime;

    // uint trialUser =
    //     lastListeningTime[
    //         0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2
    //     ] = 1693296160;
    // uint trialUserTime =
    //     accumulatedListeningTime[
    //         0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2
    //     ] = 180000;

    /**
     * @param _initialRate initial rate the user earned for every song listened to, at an average 2.5min/song
     * @param _token Address of the token being earned
     * @dev The currentRate is used for the calculation of rewards, at the start of the users count, the currentRate is set to the _initialRate.
     */

    constructor(address _token, uint256 _initialRate) {
        require(_token != address(0), "invalid token");
        require(_initialRate > 0, "Initial rate must be greater than 0");
        token = IERC20(_token);

        initialRate = _initialRate;
        currentRate = _initialRate;
    }

    modifier onlyUser() {
        require(isUser[msg.sender], "Not a registered member");
        _;
    }

    /**
     * @dev Register a user as a member of the marketplace.
     *
     * This function allows users to register as members of the marketplace. Registered members
     * gain access to certain features and benefits. A registration fee may be required for
     * registration if the total number of registered users exceeds a threshold.
     *
     * Requirements:
     * - The caller must not be already registered as a member.
     * - If the total number of registered users exceeds a threshold (e.g., 1000), a registration
     *   fee in tokens (`i_registerationFee`) must be transferred to the marketplace contract.
     * - If the registration fee is required, the caller must approve the transfer of tokens to
     *   this contract using the `transferFrom` function of the token contract.
     * - If a registration fee is paid, it may be optionally burned to remove it from circulation.
     *
     * After successful registration, the caller is marked as a registered member, added to the list
     * of users, and the total number of registered users is incremented. The function also checks
     * and updates certain marketplace rates.
     */
    function registerUser() public {
        require(!isUser[msg.sender], "already a registered member");
        // Set the listening time threshold for the user
        listeningTimeThreshold[msg.sender] = 2500 minutes;
        if (registeredUser >= 1000) {
            // Require the caller to transfer the registration fee in tokens
            require(
                token.transferFrom(
                    msg.sender,
                    address(this),
                    i_registerationFee
                )
            );
            // Optionally, burn the registration fee tokens
            require(token.burn(i_registerationFee), "Burn failed");
        }

        // Mark the caller as a registered user
        isUser[msg.sender] = true;

        // Add the caller to the list of registered users
        users.push(msg.sender);

        // Increment the total number of registered users
        registeredUser++;

        // Check and update certain marketplace rates
        _checkAndUpdateRate();
    }

    /**
     * @dev Check and update the marketplace rate.
     *
     * This internal function checks the total number of registered users and, if it is a multiple
     * of 1000, reduces the current marketplace rate. The reduction is calculated as 0.025% (25 basis
     * points) of the current rate and is subtracted from the rate. Additionally, the function may
     * burn the calculated reduction amount of tokens to adjust the rate.
     *
     * This function is called automatically during user registration to update the marketplace rate
     * if needed.
     */
    function _checkAndUpdateRate() internal {
        if (registeredUser % 1000 == 0) {
            // Calculate the reduction amount (0.025% of current rate)
            uint256 reduction = (currentRate * 25) / 100000;

            // Subtract the reduction from the current rate
            currentRate -= reduction;

            // Optionally, burn the reduction amount of tokens
            require(token.burn(reduction), "Burning failed");
        }
    }

    /**
     * @dev Start a listening session for a registered user.
     *
     * This function allows registered users to start a listening session in the marketplace.
     * A listening session is considered active if the user has listened to content for a certain duration.
     *
     * Requirements:
     * - The caller must be a registered user.
     * - A listening session can be started if the time elapsed since the last listening session
     *   is greater than or equal to 7 days (604,800 seconds).
     * - If the accumulated listening time for the user is less than their listening time threshold,
     *   the accumulated time is reset to zero.
     *
     * After starting a listening session, the function updates the last listening time and
     * the start time of the current session.
     */
    function startListening() public onlyUser {
        //7DAYS = 604,800 Seconds >= 4,838,400  1,693,784,083 1693296160 1693887000 5000000000000

        // Ensure a minimum time interval has passed since the last listening session
        uint256 currentTime = block.timestamp;
        if (currentTime >= lastListeningTime[msg.sender] + weekDuration) {
            if (
                // Check if the accumulated listening time is below the user's threshold
                accumulatedListeningTime[msg.sender] <
                listeningTimeThreshold[msg.sender]
            ) {
                accumulatedListeningTime[msg.sender] = 0;
            }
        }

        // Update the last listening time and the start time of the current session
        lastListeningTime[msg.sender] = block.timestamp;
        listeningSessionStartTime[msg.sender] = block.timestamp;
    }

    /**
     * @dev End a listening session and record accumulated listening time.
     *
     * This function allows registered users to end their current listening session
     * and record the duration of their listening activity. The accumulated listening
     * time is updated accordingly.
     *
     * Requirements:
     * - The caller must be a registered user with an active listening session.
     *
     * Upon ending the listening session, the function calculates the session duration
     * based on the time when the session started (`listeningSessionStartTime`) and the
     * current block timestamp. The calculated duration is added to the user's accumulated
     * listening time, and the start time of the current session is reset to zero.
     */
    function endListening() public onlyUser {
        // Get the start time of the current listening session
        uint256 sessionStartTime = listeningSessionStartTime[msg.sender];

        if (sessionStartTime > 0) {
            // Calculate the duration of the listening session
            uint256 sessionDuration = block.timestamp - sessionStartTime;

            // Update the accumulated listening time
            accumulatedListeningTime[msg.sender] += sessionDuration;

            // Reset the start time of the current session
            listeningSessionStartTime[msg.sender] = 0;
        }
    }

    /**
     * @dev Reward a registered user based on accumulated listening time.
     *
     * This function allows registered users to receive rewards based on their accumulated
     * listening time, provided it meets the specified threshold. Users can receive rewards
     * once a week, and the reward amount is calculated based on the current marketplace rate
     * and the accumulated listening time.
     *
     * Requirements:
     * - The caller must be a registered user.
     * - The user's accumulated listening time must be greater than or equal to their listening
     *   time threshold.
     * - Users can only withdraw rewards once a week.
     * - After the first payout, the listening time threshold is reduced by half.
     * - Users cannot reduce the threshold further after the first reduction.
     * - The user's accumulated listening time is reset to zero after receiving rewards.
     *
     * The function calculates the reward amount based on the current marketplace rate and the
     * accumulated listening time. It updates various user-related state variables, such as
     * the last reward time and the threshold reduction status.
     *
     * The rewarded amount is forwarded to the user's address using the `_forwardRewards` function.
     * @param _user Address of the listener
     */
    function rewardUser(address _user) public payable onlyUser {
        // Check if the user's accumulated listening time meets the threshold
        require(
            accumulatedListeningTime[_user] >= listeningTimeThreshold[_user],
            "user's accumulated time less than threshold"
        );

        // Calculate the reward amount based on the current rate and accumulated time
        uint256 rewardAmount = currentRate * accumulatedListeningTime[_user];
        require(rewardAmount > 0, "User earned nothing");

        // Calculate the listening time since the last reward and reset accumulated time
        uint256 _listeningTime = block.timestamp - lastListeningTime[_user];
        accumulatedListeningTime[_user] = _listeningTime;

        if (!isFirstPaid[_user]) {
            // Reduce the threshold after the first payout

            isFirstPaid[_user] = true; //the listeningtimethreshold is reduced after first payout
        } else {
            // Check if it's time for the user's weekly withdrawal
            require(isFirstReduction[_user], "threshold already reduced");
            require(
                block.timestamp >= lastRewardTime[_user] + weekDuration,
                "withdrawal is allowed once a week"
            );
        }
        if (isFirstPaid[_user] && !isFirstReduction[_user]) {
            // Reduce the threshold by half after the first payout
            listeningTimeThreshold[_user] = listeningTimeThreshold[_user] / 2;
            isFirstReduction[_user] = true;
        }

        // Reset the accumulated listening time
        accumulatedListeningTime[_user] = 0;

        // Update the last reward time and forward the rewards to the user
        lastRewardTime[_user] = block.timestamp;
        _forwardRewards(_user, rewardAmount);
    }

    /**
     * @notice users can withdraw their funds
     * @dev Withdraw available funds from a user's balance.
     *
     * This function allows registered users to withdraw their available funds from their balance.
     * Users can withdraw funds if their balance is greater than zero.
     *
     * Requirements:
     * - The caller must be a registered user.
     * - The user's balance must be greater than zero to initiate a withdrawal.
     *
     * Upon successful withdrawal, the user's balance is reset to zero, and the withdrawn funds
     * @param _user Address of the listener
     * are transferred to the user's address using the `token.transfer` function.
     */

    function withdraw(address _user) public onlyUser {
        uint256 balance = userBalance[_user];
        require(balance > 0, "User balance must be greater than 0");

        userBalance[_user] = 0;
        token.transfer(_user, balance);
    }

    /**
     * @dev Forward rewards to a specified beneficiary.
     *
     * This internal function is used to forward rewards in the form of tokens to a designated beneficiary.
     * It ensures that the beneficiary address is valid and that the reward amount is greater than zero.
     *
     * @param _beneficiary The address of the beneficiary to receive the rewards.
     * @param _tokenAmount The amount of tokens to be forwarded as rewards.
     *
     * Requirements:
     * - The beneficiary address must not be the zero address.
     * - The reward amount must be greater than zero.
     *
     * Upon successful forwarding, the reward amount is added to the beneficiary's balance
     * using the `userBalance` mapping, and the tokens are transferred to the beneficiary's address
     * using the `token.transfer` function.
     */
    function _forwardRewards(
        address _beneficiary,
        uint256 _tokenAmount
    ) internal {
        // Ensure that the beneficiary address is not the zero address
        require(
            _beneficiary != address(0),
            "Beneficiary address cannot be zero"
        );

        // Ensure that the reward amount is greater than zero
        require(_tokenAmount > 0, "Reward amount must be greater than zero");

        // Add the reward amount to the beneficiary's balance
        userBalance[_beneficiary] += _tokenAmount;

        // Transfer the reward tokens to the beneficiary's address
        token.transfer(_beneficiary, _tokenAmount);
    }

    function getDate() public view returns (uint) {
        return block.timestamp;
    }
}
