// SPDX-License-Identifierc: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BullchordNft is ERC721 {
    using Counters for Counters.Counter;
    string private baseTokenUri;
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
        baseTokenUri = _tokenUri;
    }


}
