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
     * @notice registers a user
     * @dev A registeration fee is included after we get to a 1000 users **THIS IS OPTIONAL**
     * @dev the internal function, check and update is implemented when we meet the functions conditions
     * @dev the threshold is set per ensure each user's listenThreshold is reduced by 50% after the initial withdrawal
     */
    function registerUser() public {
        //  * @param _user Address performing the registration
        require(!isUser[msg.sender], "already a registered member");
        listeningTimeThreshold[msg.sender] == 2500 minutes;
        if (registeredUser >= 1000) {
            require(
                token.transferFrom(
                    msg.sender,
                    address(this),
                    i_registerationFee
                )
            );
            require(token.burn(i_registerationFee), "Burn failed");
        }
        isUser[msg.sender] = true;
        users.push(msg.sender);
        registeredUser++;
        _checkAndUpdateRate();
    }

    /**
     * @notice Calculates the reduction amount when users counts gets to a 1000
     * @dev Validate the registered users count. Then calculate the currentRate, Use require statement to revert state when conditions are not met. .
     */
    function _checkAndUpdateRate() internal {
        if (registeredUser % 1000 == 0) {
            uint256 reduction = (currentRate * 25) / 100000;
            currentRate -= reduction;

            require(token.burn(reduction), "Burning failed");
        }
    }

    /**
     * @notice Starts a listening session if the new week's accumulated time is less than threshold
     * @dev Verification of listening session and Observation of previous session, state is restarted if true. Only user can start listening
     */
    function startListening() public onlyUser {
        //7DAYS = 604,800 Seconds >= 4,838,400  1,693,784,083 1693296160 1693887000 5000000000000
        uint256 currentTime = block.timestamp;
        if (currentTime >= lastListeningTime[msg.sender] + weekDuration) {
            if (
                accumulatedListeningTime[msg.sender] <
                listeningTimeThreshold[msg.sender]
            ) {
                accumulatedListeningTime[msg.sender] = 0;
            }
        }

        lastListeningTime[msg.sender] = block.timestamp;
        listeningSessionStartTime[msg.sender] = block.timestamp;
    }

    /**
     * @notice ends a listening session
     * @dev creates a session and session duration to track the users time spent listening to a track, the session time
     */
    function endListening() public onlyUser {
        uint256 sessionStartTime = listeningSessionStartTime[msg.sender];
        if (sessionStartTime > 0) {
            uint256 sessionDuration = block.timestamp - sessionStartTime;
            accumulatedListeningTime[msg.sender] += sessionDuration;
            listeningSessionStartTime[msg.sender] = 0;
        }
        // Reset the session start time
    }

    /**
     * @notice rewards users after all conditions met
     * @dev Users funds are forwarded,state is updated, only a registered user can earn rewards. Use require to revert state if conditions arent met
     * @dev checks if the accumulatedListening time is greater than the listeningTime Threshold, if true, then checks for the lastime reward was sent, it its been upto a week
     * @custom:listeningtime is calculated by subtracting the user's lastListeningTime from the current block.timestamp. This gives us the duration of the current listening session.
     * @param _user Address of the listener
     */
    function rewardUser(address _user) public payable onlyUser {
        require(
            accumulatedListeningTime[_user] >= listeningTimeThreshold[_user],
            "user's accumulated time less than threshold"
        );

        //calculate the reward based of the accumulatedListeningTime
        uint256 rewardAmount = currentRate * accumulatedListeningTime[_user];
        require(rewardAmount > 0, "User earned nothing");

        //require(_user != address(this),"This contract cannot be rewarded.");
        uint256 _listeningTime = block.timestamp - lastListeningTime[_user];
        accumulatedListeningTime[_user] = _listeningTime;

        if (!isFirstPaid[_user]) {
            isFirstPaid[_user] = true; //the listeningtimethreshold is reduced after first payout
        } else {
            require(!isFirstReduction[_user], "threshold already reduced");
            require(
                block.timestamp >= lastRewardTime[_user] + weekDuration,
                "withdrawal is allowed once a week"
            );
        }
        if (isFirstPaid[_user] && !isFirstReduction[_user]) {
            listeningTimeThreshold[_user] = listeningTimeThreshold[_user] / 2;
            isFirstReduction[_user] = true;
        }
        accumulatedListeningTime[_user] = 0;

        lastRewardTime[_user] = block.timestamp;
        _forwardRewards(_user, rewardAmount);
    }

    /**
     * @notice users can withdraw their funds
     * @dev allows only register users to withdraw their funds. use require to revert state if conditions arent met.
     * @param _user Address of the listener
     */

    function withdraw(address _user) public onlyUser {
        uint256 balance = userBalance[_user];
        require(balance > 0, "User balance must be greater than 0");

        userBalance[_user] = 0;
        token.transfer(_user, balance);
    }

    /**
     * @notice forwards users rewards token
     * @dev use require to revert state when conditions arent met
     * @param _beneficiary Address of the listener
     * @param _tokenAmount of user earned
     */
    function _forwardRewards(
        address _beneficiary,
        uint256 _tokenAmount
    ) internal {
        require(_beneficiary != address(0));
        require(_tokenAmount != 0);

        userBalance[_beneficiary] += _tokenAmount;
        token.transfer(_beneficiary, _tokenAmount);
    }

    function getDate() public view returns (uint) {
        return block.timestamp;
    }
}
