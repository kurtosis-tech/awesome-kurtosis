const { expect } = require('chai');
const { ethers } = require('hardhat');
require("@nomicfoundation/hardhat-chai-matchers");

const PLAYER_ONE = '0x878705ba3f8bc32fcf7f4caa1a35e72af65cf766'

describe('ChipToken', function () {
    beforeEach(async function () {
        this.ChipToken = await ethers.getContractFactory("ChipToken");
        this.chips = await this.ChipToken.deploy();
    });

    describe("mint", function () {
        it('should mint 1000 chips for PLAYER ONE', async function () {
            await this.chips.deployed()
            await this.chips.mint(PLAYER_ONE, 1000);

            expect(await this.chips.balanceOf(PLAYER_ONE)).to.equal(1_000);
        });
    });
});