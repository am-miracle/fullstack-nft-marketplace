// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

// To use console.log
import "hardhat/console.sol";

contract NFTMarketplace is ERC721URIStorage {
    uint256 private _nextTokenId;
    uint256 private _itemsSold;
    uint256 listingPrice = 0.0015 ether;

    address payable owner;

    struct MarketItem {
        uint256 tokenId;
        uint256 price;
        address payable seller;
        address payable owner;
        bool sold;
    }
    mapping(uint256 => MarketItem) private idMarketItem;

    // events
    event idMarketItemCreated(
        uint256 indexed tokenId,
        uint256 price,
        address seller,
        address owner,
        bool sold
    );

    // modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "ONLY OWNER CAN CHANGE");
        _;
    }

    /**
     * Initializes the ERC721 token contract with the specified name and symbol.
     * Assigns ownership to the provided address.
     */
    constructor() ERC721("Nevermind Token", "NVM") {
        owner = payable(msg.sender);
    }

    /**
     * @dev Updates the base listing price for all NFTs in the marketplace.
     *
     * This function allows the contract owner to set a new base price for all NFTs that are
     *  currently listed for sale. The new price will be applied to any future listings created.
     *
     * Requirements:
     * - The caller must be the contract owner (enforced by the `onlyOwner` modifier).
     *
     * Emits no events.
     *
     * @param _listingPrice The new base listing price for NFTs (in Wei).
     */
    function setListingPrice(uint256 _listingPrice) public payable onlyOwner {
        listingPrice = _listingPrice;
    }

    /// @notice This function returns the pre-defined `listingPrice` variable, which represents the cost
    ///      associated with listing an NFT on the marketplace. Users must pay this amount in
    ///       addition to the NFT's selling price.
    /// @dev Retrieves the current listing price for creating a new NFT on the marketplace
    /// @return @return uint256 The current listing price for creating a new NFT.
    function getListingPrice() public view returns (uint256) {
        return listingPrice;
    }

    /// @notice Mints a new NFT and lists it for sale
    /// @dev This function creates a new NFT with the provided URI, assigns it to the message sender,
    ///      and sets its price, and marks it as listed for sale.
    /// @param uri The URI (Uniform Resource Identifier) for the NFT's metadata.
    ///           This can point to an on-chain or off-chain location (e.g., IPFS hash).
    /// @param price The initial asking price for the NFT.
    ///
    /// @return tokenId The unique identifier assigned to the newly minted NFT
    function mintAndListNFT(
        string memory uri,
        uint256 price
    ) public returns (uint256) {
        uint256 tokenId = _nextTokenId++;

        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, uri);

        listNFTForSale(tokenId, price);

        return tokenId;
    }

    /// @notice Lists an NFT for sale in the marketplace
    /// @dev Creates a new `MarketItem` entry for the specified NFT, transferring ownership to
    ///      the contract and setting the price. Emits an `idMarketItemCreated` event.
    /// @param tokenId The ID of the NFT to be listed.
    /// @param price The asking price for the NFT.
    function listNFTForSale(uint256 tokenId, uint256 price) private {
        require(price > 0, "PRICE NOT REACHED");
        require(msg.value == listingPrice, "PRICE NOT REACHED");

        idMarketItem[tokenId] = MarketItem(
            tokenId,
            price,
            payable(msg.sender),
            payable(address(this)),
            false
        );

        _transfer(msg.sender, address(this), tokenId);

        emit idMarketItemCreated(
            tokenId,
            price,
            address(this),
            msg.sender,
            false
        );
    }

    /// @notice Allows the owner of an unsold NFT to re-list it for sale.
    /// @dev This function updates the `idMarketItem` mapping for the specified `tokenId`
    ///      with a new price, marks it as unsold (`sold=false`), and sets the contract address as the owner.
    ///      It then decrements `_nextTokenId` and transfers the NFT back to the contract.
    /// @param tokenId The ID of the NFT to re-sell.
    /// @param price The new asking price for the NFT.
    function relistNFT(uint256 tokenId, uint256 price) public payable {
        require(
            idMarketItem[tokenId].owner == msg.sender,
            "ONLY FOR ITEM OWNER"
        );
        require(msg.value == listingPrice, "PRICE NOT REACHED");

        idMarketItem[tokenId].price = price;
        idMarketItem[tokenId].sold = false;
        idMarketItem[tokenId].seller = payable(msg.sender);
        idMarketItem[tokenId].owner = payable(address(this));

        tokenId = _nextTokenId--;
        _transfer(msg.sender, address(this), tokenId);
    }

    /// @notice Completes the purchase of an NFT listed in the marketplace.
    /// @dev This function assumes the NFT with `tokenId` is already listed for sale
    ///      and has not been sold yet. It transfers the ownership of the NFT to the
    ///      buyer (`msg.sender`) and distributes the funds to the seller and marketplace owner.
    /// @param tokenId The unique identifier of the NFT to be purchased.
    function purchaseNFT(uint256 tokenId) public payable {
        uint256 price = idMarketItem[tokenId].price;

        require(msg.value == price, "SUBMIT ASKING PRICE");

        idMarketItem[tokenId].owner = payable(msg.sender);
        idMarketItem[tokenId].sold = true;
        idMarketItem[tokenId].owner = payable(address(0));

        tokenId = _nextTokenId++;

        _transfer(address(this), msg.sender, tokenId);

        payable(owner).transfer(listingPrice);
        payable(idMarketItem[tokenId].seller).transfer(msg.value);
    }

    /// @notice Retrieves an array of all unsold MarketItems currently owned by the contract.
    /// @dev This function iterates through all MarketItems and returns only those that are
    ///      unsold (owned by the contract address).
    /// @return An array of `MarketItem` structs representing the unsold MarketItems stored in memory.

    function getOwnedNFTs() public view returns (MarketItem[] memory) {
        uint256 unSoldItemCount = _nextTokenId - _itemsSold;

        // Allocate memory for the unsold items only
        MarketItem[] memory items = new MarketItem[](unSoldItemCount);

        uint256 currentIndex = 0;
        for (uint256 i = 1; i <= _nextTokenId; i++) {
            if (idMarketItem[i].owner == address(this)) {
                items[currentIndex] = idMarketItem[i];
                currentIndex++;
            }
        }

        return items;
    }

    /**
     @notice Fetches all MarketItems owned by the message sender (current caller).
     *
     * public View function (does not modify state)
     * @return {MarketItem[] memory} An array containing the MarketItems owned by the message sender.
     */
    function fetchMyNFT() public view returns (MarketItem[] memory) {
        uint256 totalCount = _nextTokenId;
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 1; i < totalCount; i++) {
            if (idMarketItem[i].owner == msg.sender) {
                itemCount++;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        for (uint256 i = 1; i < totalCount; i++) {
            if (idMarketItem[i].owner == msg.sender) {
                MarketItem storage currentItem = idMarketItem[i];

                items[currentIndex] = currentItem;
                currentIndex++;
            }
        }

        return items;
    }

    /// @notice Retrieves a list of MarketItems currently listed for sale by the message sender (caller).
    /// @dev This function iterates through all MarketItems and returns only those where the seller address matches the message sender. Individual NFT information is included in each MarketItem.
    /// @return An array of MarketItem structs (stored in memory) containing details of the listed NFTs owned by the message sender. If no NFTs are listed, an empty array is returned.
    function fetchItemsListed() public view returns (MarketItem[] memory) {
        uint256 totalCount = _nextTokenId;
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 1; i < totalCount; i++) {
            if (idMarketItem[i].seller == msg.sender) {
                itemCount++;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        for (uint256 i = 1; i < totalCount; i++) {
            if (idMarketItem[i].seller == msg.sender) {
                MarketItem storage currentItem = idMarketItem[i];
                items[currentIndex] = currentItem;
                currentIndex++;
            }
        }

        return items;
    }
}
