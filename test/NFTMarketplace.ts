import { loadFixture } from '@nomicfoundation/hardhat-toolbox/network-helpers';
import { expect } from 'chai';
import hre from "hardhat";

describe("NFTMarketplace", () => {

    async function deployNFTMarketplaceFixture() {
        // Contracts are deployed using the first signer/account by default
        const [owner, otherAccount] = await hre.ethers.getSigners();

        const NFTMarketplace = await hre.ethers.getContractFactory("NFTMarketplace");
        const nftMarketplace = await NFTMarketplace.deploy(owner);

        const uri = "https://ipfs.io/ipfs/QmNe7EebKaNuRoN2ov9nMuwHXQvXbYXCLM9W1nDBxnqLgL/9497.json";

        return {owner, otherAccount, nftMarketplace, uri}
    }
    describe('Deployment', () => {
        it("Should deploy and set the correct owner", async function () {
            const {owner, nftMarketplace} = await loadFixture(deployNFTMarketplaceFixture)
            expect(await nftMarketplace.owner()).to.equal(owner.address);
        });
     })
    describe('Listing Price', () => {
        it('Should allow owner to set a new listing price', async () => {
            const { owner, nftMarketplace } = await loadFixture(deployNFTMarketplaceFixture);
            const newPrice = hre.ethers.parseEther('0.01');

            const tx = await nftMarketplace.connect(owner).setListingPrice(newPrice);
            await tx.wait();

            const listingPrice = await nftMarketplace.getListingPrice();
            expect(listingPrice).to.equal(newPrice)
        })
        it("should revert if non-owner tries to set listing price", async () => {
            const { otherAccount, nftMarketplace } = await loadFixture(deployNFTMarketplaceFixture);
            const newPrice = hre.ethers.parseEther('0.2');

            expect(nftMarketplace.connect(otherAccount).setListingPrice(newPrice)).to.be.reverted;
        })
    });

    describe('Mint and List NFT', () => {
        it('should mint a new NFT and list it for sale', async () => {
            const { owner, nftMarketplace, uri } = await loadFixture(deployNFTMarketplaceFixture);
            const price = hre.ethers.parseEther('0.01');

            const tx = await nftMarketplace.mintAndListNFT(uri, price);
            await tx.wait();

            await expect(tx).to.emit(nftMarketplace, "NFTMintedAndListed").withArgs(owner, 1, price)
        })
        it("should revert if listing price is not sent", async () => {
            const { nftMarketplace, uri } = await loadFixture(deployNFTMarketplaceFixture);
            const price = hre.ethers.parseEther('0.0015');

            await expect(nftMarketplace.mintAndListNFT(uri, price)).to.be.revertedWith("PRICE NOT REACHED")
        })
    })
})