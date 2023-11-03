const { expect } = require('chai');
const { ethers } = require('hardhat');
require("@nomicfoundation/hardhat-chai-matchers");


const PLAYER_ONE = '0x8943545177806ED17B9F23F0a21ee5948eCaa776'

describe('ChipToken', function () {
    beforeEach(async function () {
        this.ChipToken = await ethers.getContractFactory("ChipToken");
        this.chips = await this.ChipToken.deploy();
        await this.chips.deployed();
    });

    // Network needs to bootstrap before running this test successfully needs (~1 min)
    describe("mint", function () {
        it('should mint 1000 chips for PLAYER ONE', async function () {
            await this.chips.mint(PLAYER_ONE, 1000);

            // Need to wait a slot for this transaction to be posted in the next block
            // default slot time is 12 seconds, so we wait 13 in case
            // TODO: Implement a way to mine blocks in eth-network-package instantly to eliminate needing to wait (eg. hardhat 'evm_mine')
            await sleep(13000);

            const playerOneBalance = await this.chips.balanceOf(PLAYER_ONE)
            expect(playerOneBalance).to.equal(1_000);
        }).timeout(1000000);
    });
});

function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}