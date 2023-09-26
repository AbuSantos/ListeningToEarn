// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

import "hardhat/console.sol";

contract BullchordMarketPlace {
   
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    Counters.Counter private _itemsSold;
    IERC721 public nftContract;
    uint256 public listingFee = 0.025 ether;
    uint256 private whitelistedListingFee = 0.0005 ether;
    uint256 private listingProceeds;
      // Array with all marketItem
    MarketItem[] public marketItems;
    address[] public whiteList;

    uint256[] public listMusicNft;
    // uint256 listingPrice = 0.005 ether;
    address payable owner;

    mapping(address => uint[]) public marketItemsOwner;
    mapping(address => uint256) public proceeds;
    mapping(address => mapping (uint256 => Listing)) public s_listings;
    mapping(uint => bool) public isSold;
    mapping(uint => bool) public isItemStaked;
    mapping(uint256 => Bid[]) public userBids;
    // Mapping from auction index to user bids
    mapping(uint256 => Bid[]) public auctionBids;

    // Mapping from market index to a list of marketItem
    mapping(uint256 => MarketItem) public idToMarketItems;
    // Mapping from market index to a list of owned marketItem

   struct MarketItem {
        uint256 tokenId;
        address seller;
        address _nftContract;
        uint256 price;
        bool sold;
    }
    mapping(uint256 => MarketItem) public idToMarketItem;

    struct Listing{
        uint256 price;
        address seller;
       /* address creator;*/
    }
    struct Bid{
        address payable from;
        uint256 amount;
    }

    struct stakedListing{
        uint256 price;
        address seller;
    }

    modifier notListed(address _nftAddress, uint256 _tokenId){
        Listing memory listing = s_listings[_nftAddress][_tokenId];
            if(listing.price > 0){
                revert("already listed");
            }
            _;
    }

    modifier isListed(address _nftAddress, uint256 _tokenId){
        Listing memory listing = s_listings[_nftAddress][_tokenId];
            if(listing.price <= 0){
                revert("not listed");
            }
            _;
    }
  
    modifier isOwner(address _nftContract, uint256 _tokenId, address spender){
     nftContract = IERC721(_nftContract); //using the IERC721 interface  to access the nft
      address ownerr = nftContract.ownerOf(_tokenId);
      if(spender != ownerr){
          revert("You're not the owner");
      }
      _;
    }
}
