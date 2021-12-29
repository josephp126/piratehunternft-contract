const PirateHunters = artifacts.require("PirateHunters");
const Booty = artifacts.require("Booty");
const BootyChest = artifacts.require("BootyChest");
const Shop = artifacts.require("Shop");
const Utils = artifacts.require("Utils");

module.exports = async function (deployer) {
  await deployer.deploy(PirateHunters);
  await deployer.deploy(Booty);
  await deployer.deploy(BootyChest);
  await deployer.deploy(Shop);
  await deployer.deploy(Utils);

  const pirateHunters = await PirateHunters.deployed();
  const booty = await Booty.deployed();
  const bootyChest = await BootyChest.deployed();
  const shop = await Shop.deployed();
  const utils = await Utils.deployed();

  await pirateHunters.setBootyChest(bootyChest.address.toString())
  // await bootyChest.setBooty(booty.address.toString())
  // await bootyChest.setPirateHunters(pirateHunters.address.toString())
  // await bootyChest.setShop(shop.address.toString())
  await bootyChest.setContracts(
      pirateHunters.address.toString(),
      booty.address.toString(),
      shop.address.toString(),
      utils.address.toString());
  await booty.addController(bootyChest.address.toString())
  await pirateHunters.addAvailableTokens(1,100);
  await pirateHunters.setPirateIds([2,4,6,8,10,12,14,16,18,20,22,24,26,28,30,32,34,36,38,40,42,44,46,48,50,52,54,56,58,60,62,64,66,68,70,72,74,76,78,80,82,84,86,88,90,92,94,96,98,100])
  await pirateHunters.mint(10, true)

  console.log('Deployer: '+deployer)

  // Currently

};
