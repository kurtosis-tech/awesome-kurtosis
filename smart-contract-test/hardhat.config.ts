import { task } from "hardhat/config"
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"
import { BigNumber } from "ethers"
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-chai-matchers";

task("accounts", "Prints the list of accounts", async (args, hre): Promise<void> => {
  const accounts: SignerWithAddress[] = await hre.ethers.getSigners()
  accounts.forEach((account: SignerWithAddress): void => {
    console.log(account.address)
  })
})

task("balances", "Prints the list of ETH account balances", async (args, hre): Promise<void> => {
  const accounts: SignerWithAddress[] = await hre.ethers.getSigners()
  for(const account of accounts){
    const balance: BigNumber = await hre.ethers.provider.getBalance(
        account.address
    );
    console.log(`${account.address} has balance ${balance.toString()}`);
  }
})

export default {
  solidity: {
    compilers: [
      {
        version: "0.8.6"
      }
    ]
  },
  networks: {
    localnet: {
      url: 'http://127.0.0.1:63904',//TODO: REPLACE THIS
      gasPrice: 225000000000,
      accounts: [
        "ef5177cd0b6b21c87db5a0bf35d4084a8a57a9d6a064f86d51ac85f2b873a4e2",
        "48fcc39ae27a0e8bf0274021ae6ebd8fe4a0e12623d61464c498900b28feb567",
        "7988b3a148716ff800414935b305436493e1f25237a2a03e5eebc343735e2f31",
        "b3c409b6b0b3aa5e65ab2dc1930534608239a478106acf6f3d9178e9f9b00b35",
        "df9bb6de5d3dc59595bcaa676397d837ff49441d211878c024eabda2cd067c9f",
        "7da08f856b5956d40a72968f93396f6acff17193f013e8053f6fbb6c08c194d6",
      ],
    },
    // mainnet config... testnet config...
  }
};