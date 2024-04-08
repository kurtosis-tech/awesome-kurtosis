import {
  Contract,
  ContractFactory
} from "ethers"
import { ethers } from "hardhat"
import { ChipToken } from "../typechain-types"

const main = async(): Promise<any> => {
  const ChipToken: ContractFactory = await ethers.getContractFactory("ChipToken")
  const chipToken: Contract = await ChipToken.deploy() as Contract

  const address =  await chipToken.getAddress()
  console.log(`ChipToken deployed to: ${address}`)
}

main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error)
      process.exit(1)
    })