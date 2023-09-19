// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Counters.sol";

import "hardhat/console.sol";

contract BullchordMarketPlace {
    event MarketItemCreated(
        uint256 indexed tokenId,
        address seller,
        address owner,
        uint256 price,
        bool sold
    );
    using Counters for Counters.Counter;

    //initiate the listing price : optional
    uint256 public listingPrice = 5000000000000000 wei;

    // Array with all marketItem
    MarketItem[] public marketItems;

    // MarketItem struct which holds all the required info
    struct MarketItem {
        uint _tokenId;
        address payable owner;
        address payable buyer;
        address nftAddress;
        bool sold;
        uint256 price;
    }

    //holds bidder and amount
    struct Bid {
        address payable from;
        uint256 amount;
    }

    // Mapping from auction index to user bids
    mapping(uint256 => Bid[]) public auctionBids;

    // Mapping from market index to a list of marketItem
    mapping(uint256 => MarketItem) public idToMarketItems;
    // Mapping from market index to a list of owned marketItem
    mapping(address => uint[]) public marketItemsOwner;

    /**
     * @dev Guarantees msg.sender is owner of the given auction
     * @param _marketItemId uint ID of the marketItem to validate its ownership belongs to msg.sender
     */
    modifier isOwner(uint _marketItemId) {
        require(marketItems[_marketItemId].owner == msg.sender);
        _;
    }

    /**
     * @dev Disallow payments to this contract directly
     */
    fallback() external {
        revert();
    }

    /**
     * @dev Gets the total number of marketNft owned by an address
     * @param _owner address of the owner
     * @return uint total number of marketItems
     */
    function getMarketCountOfOwner(
        address _owner
    ) public view returns (uint256) {
        marketItemsOwner[_owner].length;
    }

    function createMarketNft(
        uint256 _tokenId,
        address marketNft,
        uint256 price
    ) public payable {
        require(price > 0, "Price must be higher than 0");
        //optional
        require(msg.value == listingPrice, "Listing price not met");
    }
}
