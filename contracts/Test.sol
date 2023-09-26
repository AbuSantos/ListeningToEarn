// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "hardhat/console.sol";

contract NFTMarketplace is ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    Counters.Counter private _itemsSold;
    IERC721 public nftContract;

      // Array with all marketItem
    MarketItem[] public marketItems;

    uint256[] public listMusicNft;
    // uint256 listingPrice = 0.005 ether;
    address payable owner;

    mapping(address => uint[]) public marketItemsOwner;
    mapping(address => uint256) public proceeds;
    mapping(address => mapping (uint256 => Listing)) public s_listings;

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
      IERC721 nftContract = IERC721(_nftContract); //using the IERC721 interface  to access the nft
      address ownerr = nftContract.ownerOf(_tokenId);
      if(spender != ownerr){
          revert("You're not the owner");
      }
      _;
    }

/**
 * @notice Method for listing NFT
 * @param _nftContract Address of NFT contract
 * @param tokenId Token ID of NFT
 * @param price sale price for each item
*/
    function listMusic(uint256 tokenId, uint256 price, address _nftContract ) public 
        isOwner(_nftContract, tokenId, msg.sender)
        notListed(_nftContract,tokenId)
    {
        if (price <= 0) {
            revert ("Price must be > 0");
        }
        nftContract = IERC721 (_nftContract);
        if (nftContract.getApproved(tokenId) != address(this)) {
            revert ("Not Approved For Marketplace");
        }
       idToMarketItem[tokenId]=MarketItem(
        tokenId,
        msg.sender,
        _nftContract,
        price,
        false
       );
       
       marketItemsOwner[msg.sender].push(tokenId);

        // s_listings[_nftContract][tokenId] = Listing(price, msg.sender);
        // listMusicNft.push(_nftContract);

    }

    function updateListing(
        address nftAddress,
        uint256 tokenId,
        uint256 newPrice
    )
        external
        isListed(nftAddress,tokenId)
        isOwner(nftAddress, tokenId, msg.sender)
    {
        if (newPrice == 0) {
            revert(" PriceMustBeAboveZero");
        }

        s_listings[nftAddress][tokenId].price = newPrice;
        // emit ItemListed(msg.sender, nftAddress, tokenId, newPrice);
    }

    function buyMusic(address _nftContract, uint256 _tokenId) public payable{
     nftContract = IERC721(_nftContract); //using the IERC721 interface  to access the nft
        address ownerr = nftContract.ownerOf(_tokenId);
        require(ownerr != msg.sender, "You cannot buy your product");
        // Listing memory listings = s_listings[_nftContract][_tokenId];
       MarketItem memory marketItem = idToMarketItem[_tokenId];


        if(msg.value < marketItem.price ){
            revert("Price not met");
        }

        proceeds[marketItem.seller] += msg.value;
        delete (idToMarketItem[_tokenId]);
        // delete (s_listings[_nftContract][_tokenId]);
        // nftContract = IERC721(_nftContract);
        nftContract.transferFrom(marketItem.seller, msg.sender, _tokenId);
    }

    // Function for the token owner to grant approval to the marketplace
    function grantApprovalForToken(uint256 _tokenId, address _nftContract) public {
       nftContract  = IERC721(_nftContract);
        // Ensure that the caller is the owner of the token
        require(nftContract.ownerOf(_tokenId) == msg.sender, "Only the owner can grant approval");

        // Grant approval to this marketplace contract for the specific token
        nftContract.approve(address(this), _tokenId);
    }

    function withdrawFunds() external{
        uint256 earning = proceeds[msg.sender];

        require(earning >0,"earnings must be higher than 0");
        proceeds[msg.sender]= 0;
        (bool success,)= payable(msg.sender).call {value: earning}(" ");
        require(success, "transaction failed");
    }

    function cancelListing( uint256 tokenId)
        external
        // isOwner(nftAddress, tokenId, msg.sender)
        // isListed(nftAddress, tokenId)
    {
        //  nftContract = IERC721(tokenId); //using the IERC721 interface  to access the nft
         address ownerr = nftContract.ownerOf(tokenId);
        require(ownerr != msg.sender, "You cannot cancel this product");
        delete (idToMarketItem[tokenId]);
        // emit ItemCanceled(msg.sender, nftAddress, tokenId);
    }
    /* Returns all unsold market items */
    // function fetchMarketItems() public view returns (MarketItem[] memory) {
    //     Listing memory listings = s_listings[_nftContract][_tokenId];

    //     MarketItem[] memory items = new MarketItem[](unsoldItemCount);
    //     for (uint i = 0; i < itemCount; i++) {
    //         if (idToMarketItem[i + 1].owner == address(this)) {
    //             uint currentId = i + 1;
    //             MarketItem storage currentItem = idToMarketItem[currentId];
    //             items[currentIndex] = currentItem;
    //             currentIndex += 1;
    //         }
    //     }
    //     return items;
    // }

    /* Returns only items that a user has purchased */
    // function fetchMyNFTs() public view returns (MarketItem[] memory) {
    //     uint totalItemCount = _tokenIds.current();
    //     uint itemCount = 0;
    //     uint currentIndex = 0;

    //     for (uint i = 0; i < totalItemCount; i++) {
    //         if (idToMarketItem[i + 1].owner == msg.sender) {
    //             itemCount += 1;
    //         }
    //     }

    //     MarketItem[] memory items = new MarketItem[](itemCount);
    //     for (uint i = 0; i < totalItemCount; i++) {
    //         if (idToMarketItem[i + 1].owner == msg.sender) {
    //             uint currentId = i + 1;
    //             MarketItem storage currentItem = idToMarketItem[currentId];
    //             items[currentIndex] = currentItem;
    //             currentIndex += 1;
    //         }
    //     }
    //     return items;
    // }

    /* Returns only items a user has listed */
    function fetchItemsListed() public view returns (MarketItem[] memory) {
        uint totalItemCount = _tokenIds.current();
        uint itemCount = 0;
        uint currentIndex = 0;

        for (uint i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].seller == msg.sender) {
                itemCount += 1;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        for (uint i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].seller == msg.sender) {
                uint currentId = i + 1;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

  /**
     * @dev Disallow payments to this contract directly
     */
    fallback() external {
        revert();
    }
}