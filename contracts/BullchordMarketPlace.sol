// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

import "hardhat/console.sol";

contract BullchordMarketPlace {
    IERC721 public nftContract;

    Counters.Counter private _itemsSold;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
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
    mapping(address => mapping(uint256 => Listing)) public s_listings;
    mapping(uint => bool) public isSold;
    mapping(uint => bool) public isItemStaked;
    mapping(uint256 => Bid[]) public userBids;
    // Mapping from auction index to user bids
    mapping(uint256 => Bid[]) public auctionBids;

    // Mapping from market index to a list of marketItem
    // Mapping from market index to a list of owned marketItem

    struct MarketItem {
        uint256 tokenId;
        address seller;
        address _nftContract;
        uint256 price;
        bool sold;
    }
    mapping(uint256 => MarketItem) public idToMarketItem;

    struct Listing {
        uint256 price;
        address seller;
        /* address creator;*/
    }
    struct Bid {
        address payable from;
        uint256 amount;
    }

    struct stakedListing {
        uint256 price;
        address seller;
    }

    constructor() {
        owner = payable(msg.sender);
    }

    modifier notListed(address _nftAddress, uint256 _tokenId) {
        Listing memory listing = s_listings[_nftAddress][_tokenId];
        if (listing.price > 0) {
            revert("already listed");
        }
        _;
    }

    modifier isListed(address _nftAddress, uint256 _tokenId) {
        Listing memory listing = s_listings[_nftAddress][_tokenId];
        if (listing.price <= 0) {
            revert("not listed");
        }
        _;
    }

    modifier isOwner(
        address _nftContract,
        uint256 _tokenId,
        address spender
    ) {
        nftContract = IERC721(_nftContract); //using the IERC721 interface  to access the nft
        address ownerr = nftContract.ownerOf(_tokenId);
        if (spender != ownerr) {
            revert("You're not the owner");
        }
        _;
    }

    /**
     * @dev checks if the user already whiteListed.
     *
     * This function allows the owner of the contract to chewck if an address has been whitelisted .
     *
     * Requirements:
     * - The caller must be the owner of the contract.
     * - The provided `_user` address must not already be registered on the whitelist.
     *
     * Emits a `AddressAddedToWhitelist` event when an address is successfully added to the whitelist.
     *
     * @param _user The address to be added to the whitelist.
     */
    function _inWhiteList(address _user) private view returns (bool) {
        for (uint i = 0; i < whiteList.length; i++) {
            if (whiteList[i] == _user) {
                return true;
            }
            return false;
        }
    }

    /**
     * @dev Add an address to the whitelist.
     *
     * This function allows the owner of the contract to add an address to the whitelist.
     * Addresses on the whitelist are granted special privileges, such as lower listing fees
     * when listing NFTs on the marketplace.
     *
     * Requirements:
     * - The caller must be the owner of the contract.
     * - The provided `_user` address must not already be registered on the whitelist.
     *
     * Emits a `AddressAddedToWhitelist` event when an address is successfully added to the whitelist.
     *
     * @param _user The address to be added to the whitelist.
     */
    function addToWhtiteList(address _user) public {
        require(msg.sender == owner, "Not allowed!");
        require(!_inWhiteList(_user), "User already registered");
        whiteList.push(_user);
    }

    /**
     * @dev List a Bull NFT on the marketplace.
     *
     * This function allows the owner of a Bull NFT to list it for sale on the marketplace.
     *
     * Requirements:
     * - The provided `_price` must be greater than 0.
     * - The caller must be the owner of the NFT specified by `_nftAddress` and `_tokenId`.
     * - The specified NFT must be approved for transfer to this marketplace contract.
     *
     * If the caller is whitelisted, they will be charged a lower listing fee; otherwise, the
     * standard listing fee will apply.
     *
     * The listing fee is collected in `listingProceeds`.
     *
     * Emits a `BullListed` event when the NFT is successfully listed.
     *
     * @param _nftAddress The address of the Bull NFT contract.
     * @param _tokenId The token ID of the Bull NFT to be listed.
     * @param _price The price at which the NFT is listed for sale.
     */
    function listBull(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _price
    )
        external
        isOwner(_nftAddress, _tokenId, msg.sender)
        isListed(_nftAddress, _tokenId)
    {
        require(_price > 0, "The price of the Item must be > 0");

        uint256 actualListingFee = _inWhiteList(msg.sender)
            ? whitelistedListingFee
            : listingFee;
        require(actualListingFee > 0);
        listingProceeds += actualListingFee;

        nftContract = IERC721(_nftAddress);
        if (nftContract.getApproved(_tokenId) != address(this)) {
            revert("Not Approved For Marketplace");
        }

        idToMarketItem[_tokenId] = MarketItem(
            _tokenId,
            msg.sender,
            _nftAddress,
            _price,
            false
        );

        marketItems.push(
            MarketItem(_tokenId, msg.sender, _nftAddress, _price, false)
        );

        marketItemsOwner[msg.sender].push(_tokenId);
        isSold[_tokenId] = false;
    }

    function buyBul(_tokenId,
}
