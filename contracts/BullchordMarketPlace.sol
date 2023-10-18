// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./Royalty.sol";

import "hardhat/console.sol";

contract BullchordMarketPlace is ReentrancyGuard {
    IERC721 public nftContract;
    uint256 private platformFee;

    event NFTListed(address _nft, uint tokenId, uint price, address owner);
    event ProceedWithdrawn(address owner, uint256 amount);
    event FundsWithdrawn(address owner, uint256 amount);
    event RoyaltySent(address owner, uint amount);
    event NFTBought(address buyer, address seller, uint amount, uint tokenId);
    event BidAccepted(
        address seller,
        address bidder,
        uint amount,
        uint tokenId
    );
    event UserAdded(address artiste);
    event FeeUpdated(uint fee);
    event ListingCanceled(uint tokenId);
    event BidMade(address bidder, uint amount);

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

    constructor(uint256 _platformFee) {
        owner = payable(msg.sender);
        platformFee = _platformFee;
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
     * @notice calculates the marketplace's cut in any sale as per price
     * @param _price price at which an NFT is to be sold
     */
    function calculatePlatformFee(
        uint256 _price
    ) public view returns (uint256) {
        return (_price * platformFee) / 10_000;
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
        emit UserAdded(_user);
    }

    function updateListingFee(uint256 _listingFee) external payable {
        require(owner == msg.sender, "only owner can change fee");
        listingFee = _listingFee;
        emit FeeUpdated(_listingFee);
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
        payable
        isOwner(_nftAddress, _tokenId, msg.sender)
        isListed(_nftAddress, _tokenId)
    {
        require(_price > 0, "The price of the Item must be > 0");

        // Determine the listing price based on whitelist status
        uint256 actualListingFee = _inWhiteList(msg.sender)
            ? whitelistedListingFee
            : listingFee;
        require(actualListingFee > 0);
        listingProceeds += actualListingFee;

        nftContract = IERC721(_nftAddress);
        if (nftContract.getApproved(_tokenId) != address(this)) {
            revert("Not Approved For Marketplace");
        }

        // Create the MarketItem and add it to the idToMarketItem mapping
        idToMarketItem[_tokenId] = MarketItem(
            _tokenId,
            msg.sender,
            _nftAddress,
            _price,
            false
        );

        // Add the MarketItem to the marketItems array
        marketItems.push(
            MarketItem(_tokenId, msg.sender, _nftAddress, _price, false)
        );
        // Add the NFT to the list of items owned by the seller
        marketItemsOwner[msg.sender].push(_tokenId);

        // Mark the NFT as not sold
        isSold[_tokenId] = false;

        emit NFTListed(_nftAddress, _tokenId, _price, msg.sender);
    }

    /**
     * @dev Buy a Bull NFT from the marketplace.
     *
     * This function allows users to purchase a Bull NFT listed for sale on the marketplace.
     *
     * Requirements:
     * - The caller must not be the owner of the NFT specified by `_nftAddress` and `_tokenId`.
     * - The provided Ether value must be greater than or equal to the listed price of the NFT.
     *
     * The purchase proceeds are transferred to the seller's address, and the NFT ownership is
     * transferred to the buyer.
     *
     * Emits a `BullPurchased` event when the purchase is successful.
     *
     * @param _tokenId The token ID of the Bull NFT to be purchased.
     * @param _nftContract The address of the Bull NFT contract.
     */

    function buyBull(address _nftContract, uint256 _tokenId) public payable {
        nftContract = IERC721(_nftContract); //using the IERC721 interface  to access the nft
        address ownerr = nftContract.ownerOf(_tokenId);
        require(ownerr != msg.sender, "You cannot buy your product");
        // Listing memory listings = s_listings[_nftContract][_tokenId];
        MarketItem memory marketItem = idToMarketItem[_tokenId];
        uint payPrice = msg.value;

        if (payPrice < marketItem.price) {
            revert("Price not met");
        }

        IRentableNFT nft = IRentableNFT(marketItem._nftContract);
        (address royaltyRecipient, uint256 royalty) = nft.royaltyInfo(
            _tokenId,
            payPrice
        );

        if (royalty != 0) {
            payPrice -= royalty;
            payable(royaltyRecipient).transfer(royalty);
        }

        uint totalPlatFormFee = calculatePlatformFee(payPrice);
        payPrice -= totalPlatFormFee;
        listingProceeds += totalPlatFormFee;

        proceeds[marketItem.seller] += payPrice;
        marketItem.sold = true;
        isSold[_tokenId] = true;
        delete (idToMarketItem[_tokenId]);
        nftContract.transferFrom(marketItem.seller, msg.sender, _tokenId);

        emit RoyaltySent(royaltyRecipient, royalty);
        emit NFTBought(msg.sender, marketItem.seller, payPrice, _tokenId);
    }

    /**
     * @dev Place a bid on a Bull NFT listed in the marketplace.
     *
     * This function allows users to place bids on Bull NFTs that are listed for sale
     * in the marketplace. The bid amount must be greater than 0 and higher than any
     * previous bid on the same NFT.
     *
     * Requirements:
     * - The bid amount (`msg.value`) must be greater than 0.
     * - The caller cannot bid on their own NFT.
     * - The bid amount must be higher than the previous highest bid, if any.
     * - If a previous bid exists, the amount of the previous highest bid will be refunded
     *   to the previous bidder.
     *
     * Upon a successful bid, the new bid is recorded, and the previous highest bidder's
     * funds are refunded. Users can check their bids using the `userBids` mapping.
     *
     * @param _tokenId The token ID of the Bull NFT to place a bid on.
     * @param _nftAddress The address of the Bull NFT contract.
     */
    function bid(
        uint256 _tokenId,
        address _nftAddress
    ) external payable nonReentrant {
        uint256 bidAmount = msg.value;

        require(bidAmount > 0, "Bid should be > 0");
        nftContract = IERC721(_nftAddress);
        address _owner = nftContract.ownerOf(_tokenId);
        require(_owner != msg.sender, "You cannot bid on your own NFT");

        Bid memory lastBid;
        uint256 bidLength = userBids[_tokenId].length;
        uint tempAmount;

        if (bidLength > 0) {
            //this will give us the last bid made on the NFT.
            lastBid = userBids[_tokenId][bidLength - 1];
            tempAmount = lastBid.amount;
        }

        //then we check if the current bid is greater than the last bid
        require(bidAmount > tempAmount, "bid amount too low");

        // we refund the last bidder if the current Bid is greater than the last bid.
        if (bidLength > 0) {
            (bool success, ) = lastBid.from.call{value: lastBid.amount}("");
            require(success, "refund failed");
        }

        //we insert the bid
        Bid memory newBid;
        newBid.from = payable(msg.sender);
        newBid.amount = bidAmount;
        userBids[_tokenId].push(newBid);
        emit BidMade(msg.sender, bidAmount);
    }

    /**
     * @dev Withdraw proceeds from the marketplace.
     *
     * This function allows sellers to withdraw their earnings (proceeds) from the marketplace.
     * Sellers can only withdraw proceeds if they have earnings higher than 0.
     *
     * Upon successful withdrawal, the proceeds are transferred to the seller's address.
     *
     * Emits a `ProceedsWithdrawn` event when the withdrawal is successful.
     */

    function withdrawProceeds() external {
        require(owner == msg.sender, "Only owner");
        uint256 earning = listingProceeds;

        require(earning > 0, "earnings must be higher than 0");
        listingProceeds = 0;
        (bool success, ) = payable(msg.sender).call{value: earning}(" ");
        require(success, "transaction failed");
        emit ProceedWithdrawn(owner, earning);
    }

    /**
     * @dev Withdraw proceeds from the marketplace.
     *
     * This function allows marketplace owner to withdraw their earnings (proceeds) from the marketplace.
     * Owners can only withdraw proceeds if they have earnings higher than 0.
     *
     * Upon successful withdrawal, the proceeds are transferred to the owner's address.
     *
     * Emits a `ProceedsWithdrawn` event when the withdrawal is successful.
     */
    function withdrawFunds() external {
        uint256 earning = proceeds[msg.sender];

        require(earning > 0, "earnings must be higher than 0");
        proceeds[msg.sender] = 0;
        (bool success, ) = payable(msg.sender).call{value: earning}(" ");
        require(success, "transaction failed");
        emit FundsWithdrawn(owner, earning);
    }

    /**
     * @dev Accept the highest bid and transfer ownership of a Bull NFT.
     *
     * This function allows the seller of a Bull NFT listed in the marketplace to accept the highest bid
     * and transfer ownership of the NFT to the highest bidder.
     *
     * Requirements:
     * - The caller must be the seller of the NFT.
     * - There must be at least one valid bid for the NFT.
     * - The highest bid amount will be transferred to the seller.
     * - Ownership of the NFT will be transferred to the highest bidder.
     *
     * Emits a `OfferAccepted` event when the offer is successfully accepted.
     *
     * @param _tokenId The token ID of the Bull NFT to accept an offer for.
     * @param _nftContract The address of the Bull NFT contract.
     */

    function acceptOffer(uint _tokenId, address _nftContract) external {
        MarketItem memory marketItem = idToMarketItem[_tokenId];
        nftContract = IERC721(_nftContract); //using the IERC721 interface  to access the nft

        require(msg.sender == marketItem.seller, "you're not the owner");
        uint bidsLength = userBids[_tokenId].length;
        Bid memory lastBid = userBids[_tokenId][bidsLength - 1];

        IRentableNFT nft = IRentableNFT(marketItem._nftContract);
        (address royaltyRecipient, uint256 royalty) = nft.royaltyInfo(
            _tokenId,
            lastBid.amount
        );

        if (royalty != 0) {
            lastBid.amount -= royalty;
            payable(royaltyRecipient).transfer(royalty);
        }

        if (isItemStaked[_tokenId]) {
            uint totalPlatFormFee = (lastBid.amount * 15) / 100;
            lastBid.amount -= totalPlatFormFee;
            listingProceeds += totalPlatFormFee;
        }

        (bool success, ) = payable(msg.sender).call{value: lastBid.amount}(" ");
        require(success, "transaction failed");
        nftContract.transferFrom(marketItem.seller, lastBid.from, _tokenId);

        emit BidAccepted(
            marketItem.seller,
            lastBid.from,
            lastBid.amount,
            _tokenId
        );
        emit RoyaltySent(royaltyRecipient, royalty);
    }

    /**
     * @dev Cancel a Bull NFT listing on the marketplace.
     *
     * This function allows the seller to cancel their listing for a Bull NFT on the marketplace.
     * The seller must be the owner of the listing.
     *
     * When a listing is canceled, the NFT remains in the ownership of the seller, and the listing
     * information is removed from the marketplace.
     *
     * Emits a `ListingCanceled` event when the listing is successfully canceled.
     *
     * @param _tokenId The token ID of the Bull NFT listing to be canceled.
     */

    function cancelListing(uint256 _tokenId) external {
        MarketItem memory marketItem = idToMarketItem[_tokenId];
        require(msg.sender == marketItem.seller, "This is not your product");
        isSold[_tokenId] = true;
        delete (idToMarketItem[_tokenId]);
        emit ListingCanceled(_tokenId);
    }

    /**
     * @dev Reject a bid offer for a Bull NFT listed in the marketplace.
     *
     * This function allows the seller to reject a bid offer made by a potential buyer for their
     * listed Bull NFT. The offer is rejected by providing the token ID of the NFT and the
     * address of the Bull NFT contract. The bid amount is refunded to the bidder.
     *
     * Requirements:
     * - Only the seller of the NFT can reject bid offers for their own NFTs.
     * - The NFT must be listed in the marketplace.
     *
     * Emits a `BidOfferRejected` event when the bid offer is successfully rejected and refunded.
     *
     * @param _tokenId The token ID of the Bull NFT for which the bid offer is rejected.
     * @param _nftAddress The address of the Bull NFT contract.
     */
    function rejectBidOffer(uint256 _tokenId, address _nftAddress) external {
        nftContract = IERC721(_nftAddress);
        address seller = nftContract.ownerOf(_tokenId);
        require(msg.sender == seller, "Only the seller can reject bid offers");

        // Check if the NFT is listed in the marketplace
        MarketItem storage marketItem = idToMarketItem[_tokenId];
        require(
            marketItem.seller == seller,
            "NFT is not listed in the marketplace"
        );

        // Get the last bid offer for the NFT
        Bid[] storage bids = userBids[_tokenId];
        require(bids.length > 0, "No bids for this NFT");

        Bid memory lastBid = bids[bids.length - 1];
        address bidder = lastBid.from;
        uint256 bidAmount = lastBid.amount;

        // Refund the bid amount to the bidder
        (bool success, ) = bidder.call{value: bidAmount}("");
        require(success, "Refund to bidder failed");

        // Remove the bid offer
        bids.pop();

        // Emit an event to log the bid offer rejection and refund
        // emit BidOfferRejected(_tokenId, _nftAddress, seller, bidder, bidAmount);
    }

    function getAllMarketItems() external view returns (MarketItem[] memory) {
        uint totalItems = marketItems.length;
        uint unsoldItemCount = 0;

        // get all the item not sold,
        for (uint i = 0; i < totalItems; i++) {
            if (!isSold[marketItems[i].tokenId]) {
                unsoldItemCount++;
            }
        }
        // we instantiate and instance of marketItem array and we use the unsoldItem to get all items not sold.
        MarketItem[] memory allMarketItems = new MarketItem[](unsoldItemCount);
        uint currentIndex = 0;
        for (uint i = 0; i < totalItems; i++) {
            //first we check for all the items unsold
            if (!isSold[marketItems[i].tokenId]) {
                allMarketItems[currentIndex] = marketItems[i];
                currentIndex++;
            }
        }

        return allMarketItems;
    }

    function getMarketItemsByUser(
        address user
    ) external view returns (MarketItem[] memory) {
        uint[] memory userListingIds = marketItemsOwner[user];
        MarketItem[] memory userMarketItems = new MarketItem[](
            userListingIds.length
        );

        for (uint i = 0; i < userListingIds.length; i++) {
            uint tokenId = userListingIds[i];
            MarketItem storage item = idToMarketItem[tokenId];
            userMarketItems[i] = MarketItem({
                tokenId: item.tokenId,
                seller: item.seller,
                _nftContract: item._nftContract,
                price: item.price,
                sold: item.sold
            });
        }

        return userMarketItems;
    }

    /**
     * @dev Disallow payments to this contract directly
     */
    fallback() external {
        revert();
    }
}
