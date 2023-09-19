// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "hardhat/console.sol";

contract BullchordMarketPlace {
    using Counters for Counters.Counter;

    uint256 public listingPrice = 5000000000000000 wei;

    // Array with all marketItem
    MarketItem[] public marketItems;

    struct MarketItem {
        uint _tokenId;
        address payable seller;
        address payable buyer;
        bool sold;
        uint256 price;
    }
    
}
