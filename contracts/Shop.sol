// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IBootyChest.sol";
import "./IBooty.sol";

interface IPirateHunters {
    function ownerOf(uint id) external view returns (address);
    function isPirate(uint16 id) external view returns (bool);
//    function transferFrom(address from, address to, uint tokenId) external;
//    function safeTransferFrom(address from, address to, uint tokenId, bytes memory _data) external;
}

contract Shop is Ownable {

    struct HunterItem {
        string name;
        bool offensive;
        bool percentage;
        uint value;
        uint expired;
        uint price;
        uint supply;
        string img;
    }

    struct Bounty {
        string name;
        bool offensive;
        bool percentage;
        uint value;
        uint expired;
        uint price;
        uint supply;
        string img;
    }

    struct RankUp {
        string name;
        uint id;
        uint requireId;
        uint price;
        string img;
    }

    //    mapping(uint => HunterItem) public hunterItems;
    string constant public name = "Pirate Hunters Shop";
    string constant public symbol = "PH_SHOP";

    HunterItem[] public hunterItems;
    mapping(uint => HunterItem) public hunterItemsMap;
    mapping(address => HunterItem[]) public hunterItemsPurchased;

    Bounty[] public bounties;
    mapping(uint => Bounty) public bountiesMap;
    mapping(address => Bounty[]) public bountiesPurchased;

    RankUp[] public rankUps;
    mapping(uint => RankUp) public rankUpsMap;

    IBootyChest public bootyChest;

    IBooty public booty;

    IPirateHunters public pirateHunters;

    constructor() {

        addRank(RankUp({
            name : "A",
            id : bootyChest.RANK_A(),
            requireId : bootyChest.RANK_B(),
            price : 300000 ether,
            img : ''
        }));

        addRank(RankUp({
            name : "B",
            id : bootyChest.RANK_B(),
            requireId : bootyChest.RANK_C(),
            price : 450000 ether,
            img : ''
        }));
    }

    function getHunterItemPrice(uint itemId, uint qty) private view returns (uint price) {
        price = qty * hunterItemsMap[itemId].price;
    }

    function getBountyPrice(uint itemId, uint qty) private view returns (uint price) {
        price = qty * bountiesMap[itemId].price;
    }

    function getRankPrice(uint itemId, uint qty) private view returns (uint price) {
        price = qty * rankUpsMap[itemId].price;
    }

    function purchaseHunterItem(uint[] calldata tokenIds, uint itemId) external payable {
        require(bootyChest.isOwnerOf(tokenIds[0], msg.sender), "You are not authorised to call this function");
        uint totalCost = getHunterItemPrice(itemId, tokenIds.length);
        require(totalCost < booty.balanceOf(msg.sender), "Insufficient $BOOTY");
        booty.burn(msg.sender, totalCost);

        for (uint i = 0; i < tokenIds.length; i++) {
            purchaseHunterItem(tokenIds[i], itemId);
        }
    }

    function purchaseHunterItem(uint tokenId, uint idx) private {
//        require(bootyChest.isOwnerOf(tokenIds[0], msg.sender), "You are not authorised to call this function");
        hunterItemsPurchased[msg.sender].push(hunterItems[idx]);
    }

    function purchaseBounty(uint[] calldata tokenIds, uint itemId) external payable {

    }

    function purchaseRank(uint[] calldata tokenIds, uint itemId) external payable {
        require(bootyChest.isOwnerOf(tokenIds[0], msg.sender), "You are not authorised to call this function");
        uint totalCost = getRankPrice(itemId, tokenIds.length);
        require(totalCost < booty.balanceOf(msg.sender), "Insufficient $BOOTY");
        booty.burn(msg.sender, totalCost);

        for (uint i = 0; i < tokenIds.length; i++) {
            purchaseRank(tokenIds[i], itemId);
        }
    }

    function purchaseRank(uint tokenId, uint idx) private {
        //        require(bootyChest.isOwnerOf(tokenIds[0], msg.sender), "You are not authorised to call this function");
        //TODO: check if has required rank
        bootyChest.effectRankUp(tokenId, idx);
    }

    function deleteExpiredHunterItems(address owner) external {

    }

    function deleteExpiredBounty(address owner) external {

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

    function setBootyChest(address _iBootyChest) external onlyOwner {
        bootyChest = IBootyChest(_iBootyChest);
    }

    function setBooty(address _iBooty) external onlyOwner {
        booty = IBooty(_iBooty);
    }

    function addRank(RankUp memory _item) public onlyOwner {
        uint idx = rankUps.length;
        rankUps.push(_item);
        rankUpsMap[idx] = _item;
    }

    function replaceRank(uint _idx, RankUp calldata _item) external onlyOwner {
        rankUps[_idx] = _item;
        rankUpsMap[_idx] = _item;
    }

}
