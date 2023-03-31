import {
  Contract,
  ContractFactory
} from "ethers"
import { ethers } from "hardhat"

const main = async(): Promise<any> => {
  const ChipToken: ContractFactory = await ethers.getContractFactory("ChipToken")
  const chipToken: Contract = await ChipToken.deploy()

  await chipToken.deployed()
  console.log(`ChipToken deployed to: ${chipToken.address}`)
}

main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error)
      process.exit(1)
    })