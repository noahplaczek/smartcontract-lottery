// SPDX-License-Identifier: MIT

pragma solidity ^0.6.6;

// API to use Chainlink price feeds
import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
// API to use onlyOwner
import "@openzeppelin/contracts/access/Ownable.sol";
// API for random numbers
import "@chainlink/contracts/src/v0.6/VRFConsumerBase.sol";

contract Lottery is VRFConsumerBase, Ownable {
    address payable[] public players;
    uint256 public usdEntryFee;
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

    constructor(
        address _priceFeedAddress,
        address _vrfCoordinator,
        address _link,
        uint256 _fee;
    ) public VRFConsumerBase(_vrfCoordinator, _link) {
        usdEntryFee = 50 * (10**18);
        ethUsdPriceFeed = AggregatorV3Interface(_priceFeedAddress);
        lottery_state = LOTTERY_STATE.CLOSED; // lottery starts as closed
        fee = _fee;
    }

    function enter() public payable {
        // $50 minimum. Lottery must be open to enter
        require(lottery_state == LOTTERY_STATE.OPEN);
        require(msg.value >= getEntranceFee(), "Not enough ETH!");
        players.push(msg.sender);
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
