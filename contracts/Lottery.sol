// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// API to use Chainlink price feeds
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
// API to use onlyOwner
import "@openzeppelin/contracts/access/Ownable.sol";
// API for random numbers
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

contract Lottery is VRFConsumerBase, Ownable {
    address payable[] public players;
    address public recentWinner;
    uint256 public usdEntryFee;
    uint256 public randomness;
    AggregatorV3Interface internal ethUsdPriceFeed;
    // Use an enum to identify states/phases of the lottery.
    // open=0, close=1, calculating_winner=2
    enum LOTTERY_STATE {
        OPEN,
        CLOSED,
        CALCULATING_WINNER
    }

    LOTTERY_STATE public lottery_state;
    uint256 public fee;
    // keyhash is a way to uniquely identify the chainlink vrf node
    bytes32 public keyhash;
    

    constructor(
        address _priceFeedAddress,
        address _vrfCoordinator,
        address _link,
        uint256 _fee,
        bytes32 _keyhash
    ) public VRFConsumerBase(_vrfCoordinator, _link) {
        usdEntryFee = 50 * (10**18);
        ethUsdPriceFeed = AggregatorV3Interface(_priceFeedAddress);
        lottery_state = LOTTERY_STATE.CLOSED; // lottery starts as closed
        fee = _fee;
        keyhash = _keyhash;
    }

    function enter() public payable {
        // $50 minimum. Lottery must be open to enter
        require(lottery_state == LOTTERY_STATE.OPEN);
        require(msg.value >= getEntranceFee(), "Not enough ETH!");
        players.push(payable(msg.sender));
    }

    function getEntranceFee() public view returns (uint256) {
        (, int256 price, , , ) = ethUsdPriceFeed.latestRoundData();
        uint256 adjustedPrice = uint256(price) * 10**10; // 18 decimals
        uint256 costToEnter = (usdEntryFee * 10**18) / adjustedPrice;
        return costToEnter;
    }

    function startLottery() public onlyOwner {
        require(
            lottery_state == LOTTERY_STATE.CLOSED,
            "Can't start a new lottery yet!"
        );
        lottery_state = LOTTERY_STATE.OPEN;
    }

    // 6:45:32

    function endLottery() public onlyOwner {
        // change the state first so no other functions can be called while we are calculating a winner
        // no one can enter the lottery and no one can start a new lottery
        lottery_state = LOTTERY_STATE.CALCULATING_WINNER;
        // calling the below function from VRFConsumerBase. "returns (bytes32 requestId)" means that the contract is 
        // returning a bytes32 variable named requestId
        // function requestRandomness(bytes32 _keyHash, uint256 _fee) internal returns (bytes32 requestId)
        // this would be similar to writing out: bytes32 requestId = requestRandomness(keyhash, fee);
        // Request/Receive architecture. This first function requesting the data from the chainlink oracle
        requestRandomness(keyhash, fee);
        // when chainlink returns the data, it does so in a second transaction by calling "fulfillRandomness"
    }
    
    // the function is internal because we only want the VRFCoordinator to be able to call this function
    // overriding the original function of fulfillRandomness
    function fulfillRandomness(bytes32 _requestId, uint256 _randomness) internal override {
        require(lottery_state == LOTTERY_STATE.CALCULATING_WINNER, "You aren't there yet!");
        require(_randomness > 0, "random-not-found");
        uint256 indexOfWinner = _randomness % players.length;
        recentWinner = players[indexOfWinner];
        // transger the winner everything we have
        payable(recentWinner).transfer(address(this).balance);
        players = new address payable[](0);
        lottery_state = LOTTERY_STATE.CLOSED;
        randomness = _randomness;
    }
    // pseudorandom number generator. NOT FOR PRODUCTION
    // method: hashing a globally available variable (keccack256 is the hashing algorithm)
    /*function endLottery() public onlyOwner {
        uint256(
            keccack256(
                abi.encodePacked(
                    nonce,
                    msg.sender,
                    block.difficulty,
                    block.timestamp
                )
            )
        ) % players.length;
    }
    */
}
