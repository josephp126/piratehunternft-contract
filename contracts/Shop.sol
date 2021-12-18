// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Shop is Ownable{

    // TODO: always update counts in BootyChest on rank UP purchase

    struct HunterItem{
        string name;
        bool offensive;
        bool percentage;
        uint value;
        uint expired;
        uint price;
        uint supply;
        string img;
    }

    struct Bounty{
        string name;
        bool offensive;
        bool percentage;
        uint value;
        uint expired;
        uint price;
        uint supply;
        string img;
    }

    struct RankUp{
        string name;
        uint id;
        uint requireId;
        string img;
    }

//    mapping(uint => HunterItem) public hunterItems;
    string constant public name = "Pirate Hunters Shop";
    string constant public symbol = "PH_SHOP";

    HunterItem[] public hunterItems;
    mapping(uint => HunterItem) public hunterItemsMap;

    Bounty[] public bounties;
    mapping(uint => Bounty) public bountiesMap;

    RankUp[] public rankUps;
    mapping(uint => RankUp) public rankUpsMap;


//    TODO: track purchases

    constructor() {

    }

    function purchaseHunterItem(uint idx) external {

    }

    function purchaseBounty(uint idx) external {

    }

    function purchaseRank(uint idx) external {

    }

    function deleteExpiredItems(uint idx) external {

    }

    function addHunterItem(HunterItem calldata _item) external onlyOwner {
        uint idx = hunterItems.length;
        hunterItems.push(_item);
        hunterItemsMap[idx] = _item;
    }

    function deleteHunterItem(uint _idx) external onlyOwner {
        //uint idx = hunterItems.length;
        HunterItem memory lastItem = hunterItems[hunterItems.length - 1];
        hunterItems[_idx] = lastItem;
        delete hunterItemsMap[hunterItems.length - 1];
        hunterItems.pop();
        hunterItemsMap[_idx] = lastItem;
    }

    function replaceHunterItem(uint _idx, HunterItem calldata _item) external onlyOwner {
        hunterItems[_idx] = _item;
        hunterItemsMap[_idx] = _item;
    }


    function addBounty(Bounty calldata _item) external onlyOwner {
        uint idx = bounties.length;
        bounties.push(_item);
        bountiesMap[idx] = _item;
    }

    function deleteBounty(uint _idx) external onlyOwner {
        //uint idx = hunterItems.length;
        Bounty memory lastItem = bounties[bounties.length - 1];
        bounties[_idx] = lastItem;
        delete bountiesMap[hunterItems.length - 1];
        bounties.pop();
        bountiesMap[_idx] = lastItem;
    }

    function replaceBounty(uint _idx, Bounty calldata _item) external onlyOwner {
        bounties[_idx] = _item;
        bountiesMap[_idx] = _item;
    }




}
