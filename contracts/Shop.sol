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
        uint8 id; // should be index of item in the array
        bool offensive;
        bool percentage;
        uint value;
        uint expired; // to be specified in days
        uint price;
        uint supply;
        string img;
        bool valid; // this should not be listed for purchase if render invalid
    }

    struct PurchasedHunterItem {
        uint16 tokenId;
        uint8 itemId; // should be index of item in the array
        uint time; // timeStamp of purchase or last time used
        uint expired; //
    }

    struct Bounty {
        string name;
        uint8 id;
        bool offensive;
        bool percentage;
        uint value;
        uint expired; // to be specified in days
        uint price;
        uint supply;
        string img;
        bool valid; // this should not be listed for purchase if render invalid
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
//    mapping(uint => HunterItem) public hunterItemsMap;
    mapping(address => PurchasedHunterItem[]) public hunterItemsPurchased;

    Bounty[] public bounties;
//    mapping(uint => Bounty) public bountiesMap;
    mapping(address => Bounty[]) public bountiesPurchased;

    RankUp[] public rankUps;
//    mapping(uint => RankUp) public rankUpsMap;

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
        price = qty * hunterItems[itemId].price;
    }

    function getBountyPrice(uint itemId, uint qty) private view returns (uint price) {
        price = qty * bounties[itemId].price;
    }

    function getRankPrice(uint itemId, uint qty) private view returns (uint price) {
        price = qty * rankUps[itemId].price;
    }

    function purchaseHunterItem(uint[] calldata tokenIds, uint itemId) external payable {
        require(bootyChest.isOwnerOf(tokenIds[0], msg.sender), "You are not authorised to call this function");
        uint totalCost = getHunterItemPrice(itemId, tokenIds.length);
        require(totalCost < booty.balanceOf(msg.sender), "Insufficient $BOOTY");
        require(hunterItems[itemId].supply >= tokenIds.length, "Total supply in shop less than quantity needed");

        HunterItem memory item = hunterItems[itemId];
        item.supply = item.supply - tokenIds.length;
        hunterItems[itemId] = item;

        booty.burn(msg.sender, totalCost);

        for (uint i = 0; i < tokenIds.length; i++) {
            purchaseHunterItem(tokenIds[i], itemId);
        }
    }

    function purchaseHunterItem(uint tokenId, uint idx) private {
//        require(bootyChest.isOwnerOf(tokenIds[0], msg.sender), "You are not authorised to call this function");
//        hunterItemsPurchased[msg.sender].push(hunterItems[idx]);
        uint day = 1 days;
        uint expired = hunterItems[idx].expired * day;
        hunterItemsPurchased[msg.sender].push(PurchasedHunterItem({
            tokenId: uint16(tokenId),
            itemId: uint8(idx),
            time: block.timestamp,
            expired: expired + block.timestamp
        }));
    }


    function getOwnerPurchasedItems(address owner) external returns(PurchasedHunterItem[] memory) {
        require(msg.sender == address(bootyChest), "You are not authorised to call this function");

        for(uint8 i = 0; i<hunterItemsPurchased[owner].length; i++){
//            if(block.timestamp >= hunterItemsPurchased[owner][i].expired){
            if(hunterItemsPurchased[owner][i].time >= hunterItemsPurchased[owner][i].expired){
                // expired and item should be removed
                hunterItemsPurchased[owner][i] = hunterItemsPurchased[owner][hunterItemsPurchased[owner].length -1];
                hunterItemsPurchased[owner].pop();
            }
        }
        return hunterItemsPurchased[owner];
    }

    function useHunterItem(address owner, uint16 idx, uint16 tokenId) external returns(HunterItem memory) {
        require(msg.sender == address(bootyChest), "You are not authorised to call this function");
//        bootyChest.isOwnerOf()
        PurchasedHunterItem memory item = hunterItemsPurchased[owner][idx];
        require(item.expired == 0 , "Address of owner does not have a valid purchase");
        require(item.tokenId == tokenId , "token Id not equal, invalid index selected");
        HunterItem memory hunterItem = hunterItems[item.itemId];

        // Check if item is expired then remove item from purchased and return
        if(block.timestamp >= item.expired  && item.time >= item.expired){
            // expired but can't remove to avoid inconsistency in indexing

            hunterItem.value = 0;
            hunterItem.expired = 0; // represents days(time) that can be claim from last time item was use till now
            //reject("item expired");
            return hunterItem;
        }

        // calculate time difference from last time used used
        uint current = block.timestamp;
        uint diff = item.expired < current ? item.expired - item.time : current - item.time; // (now - lastTime used or purchased) or (expired - lastTime if expired)
        // set time in hunter item to number of days or time it can be use in increasing or decreasing rate
        hunterItem.expired = diff; // using this to pass time diff to bootychest to use

        // Set the new time it was used as time
        hunterItemsPurchased[owner][idx].time = current;

        return hunterItem;
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

    function deleteExpiredBounty(address owner) external {

    }

    /// add hunterItem. ItemId should be their index in the array
    function addHunterItem(HunterItem memory _item) external onlyOwner {

        uint8 idx = uint8(hunterItems.length);
        _item.id = idx;
        hunterItems.push(_item);
//        hunterItemsMap[idx] = _item;
    }

    function deleteHunterItem(uint _idx) external onlyOwner {
        //uint idx = hunterItems.length;
//        HunterItem memory lastItem = hunterItems[hunterItems.length - 1];
        HunterItem memory item = hunterItems[_idx];
        item.valid = false;
        hunterItems[_idx] = item;
//        delete hunterItemsMap[hunterItems.length - 1];
//        hunterItems.pop();
//        hunterItemsMap[_idx] = lastItem;
    }

    function replaceHunterItem(uint _idx, HunterItem calldata _item) external onlyOwner {
        hunterItems[_idx] = _item;
//        hunterItemsMap[_idx] = _item;
    }

    function addBounty(Bounty memory _item) external onlyOwner {
        uint8 idx = uint8(bounties.length);
        _item.id = idx;
        bounties.push(_item);
//        bountiesMap[idx] = _item;
    }

    function deleteBounty(uint _idx) external onlyOwner {
        //uint idx = hunterItems.length;
//        Bounty memory lastItem = bounties[bounties.length - 1];
        Bounty memory bounty = bounties[_idx];//lastItem;
        bounty.valid = false;
        bounties[_idx] = bounty;
//        delete bountiesMap[hunterItems.length - 1];
//        bounties.pop();
//        bountiesMap[_idx] = lastItem;
    }

    function replaceBounty(uint _idx, Bounty calldata _item) external onlyOwner {
        bounties[_idx] = _item;
//        bountiesMap[_idx] = _item;
    }

    function setBootyChest(address _iBootyChest) external onlyOwner {
        bootyChest = IBootyChest(_iBootyChest);
    }

    function setBooty(address _iBooty) external onlyOwner {
        booty = IBooty(_iBooty);
    }

    function addRank(RankUp memory _item) public onlyOwner {
        uint idx = rankUps.length;
        _item.id = idx;
        rankUps.push(_item);
//        rankUpsMap[idx] = _item;
    }

    function replaceRank(uint _idx, RankUp calldata _item) external onlyOwner {
        rankUps[_idx] = _item;
//        rankUpsMap[_idx] = _item;
    }

}
