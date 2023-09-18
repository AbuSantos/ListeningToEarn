// SPDX-License-Identifierc: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BullchordNft is ERC721Enumerable, Ownable {
    using Counters for Counters.Counter;
    string private baseTokenURI;
    bool public mintEnabled = true;
    uint256 public constant i_MAX_SUPPLY = 10;

    /**
     * @dev Created a BullchordMusicNFT with a name and symbol
     * @param _name string represents the name of the BullchordMusicNFT
     * @param _symbol string represents the symbol of the BullchordMusicNFT
     * @param _tokenUri string represents the tokenUri of the BullchordMusicNFT
     */
    constructor(
        string memory _name,
        string memory _symbol,
        string memory _tokenUri
    ) ERC721(_name, _symbol) {
        baseTokenURI = _tokenUri;
    }

    function mint() public onlyOwner {
        require(mintEnabled, "Minting is Disabled");
        require(
            totalSupply() + 10 <= i_MAX_SUPPLY,
            "Total supply is maxed out"
        );

        for (uint256 i = 0; i < 10; i++) {
            uint256 _tokenId = totalSupply();
            _mint(msg.sender, _tokenId);
        }
        mintEnabled = false;
    }

    // Override the baseURI function to return the token URI
    function _baseURI() internal view override returns (string memory) {
        return baseTokenURI;
    }
}
