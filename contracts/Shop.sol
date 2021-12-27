// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IBootyChest.sol";
import "./IBooty.sol";
// import "./IPirateHunters.sol";
import "./Shared.sol";

contract Shop is Ownable, SharedStructs {

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

    PirateItem[] public pirateItems;
//    mapping(uint => HunterItem) public hunterItemsMap;
    mapping(address => PurchasedPirateItem[]) public pirateItemsPurchased;

    Bounty[] public bounties;
//    mapping(uint => Bounty) public bountiesMap;
    mapping(address => Bounty[]) public bountiesPurchased;

    RankUp[] public rankUps;
//    mapping(uint => RankUp) public rankUpsMap;

    IBootyChest public bootyChest;

    IBooty public booty;

    // IPirateHunters public pirateHunters;

    constructor() {

        // RankUp memory rp = RankUp({
        //     name : "A",
        //     id : bootyChest.RANK_A(),
        //     requireId : bootyChest.RANK_B(),
        //     price : 300000 ether,
        //     img : ''
        // });

        // addRank(RankUp({
        //     name : "A",
        //     id : bootyChest.RANK_A(),
        //     requireId : bootyChest.RANK_B(),
        //     price : 300000 ether,
        //     img : ''
        // }));

        // addRank(RankUp({
        //     name : "B",
        //     id : bootyChest.RANK_B(),
        //     requireId : bootyChest.RANK_C(),
        //     price : 450000 ether,
        //     img : ''
        // }));
    }

    function getPirateItemPrice(uint itemId, uint qty) private view returns (uint price) {
        price = qty * pirateItems[itemId].price;
    }

    function getBountyPrice(uint itemId, uint qty) private view returns (uint price) {
        price = qty * bounties[itemId].price;
    }

    function getRankPrice(uint itemId, uint qty) private view returns (uint price) {
        price = qty * rankUps[itemId].price;
    }

    function purchasePirateItem(uint[] calldata tokenIds, uint itemId) external payable {
        require(bootyChest.isOwnerOf(tokenIds[0], msg.sender), "You are not authorised to call this function");
        uint totalCost = getPirateItemPrice(itemId, tokenIds.length);
        require(totalCost < booty.balanceOf(msg.sender), "Insufficient $BOOTY");
        require(pirateItems[itemId].supply >= tokenIds.length, "Total supply in shop less than quantity needed");

        PirateItem memory item = pirateItems[itemId];
        item.supply = item.supply - tokenIds.length;
        pirateItems[itemId] = item;

        booty.burn(msg.sender, totalCost);

        for (uint i = 0; i < tokenIds.length; i++) {
            purchasePirateItem(tokenIds[i], itemId);
        }
    }

    function purchasePirateItem(uint tokenId, uint idx) private {
//        require(bootyChest.isOwnerOf(tokenIds[0], msg.sender), "You are not authorised to call this function");
//        hunterItemsPurchased[msg.sender].push(hunterItems[idx]);
        uint day = 1 days;
        uint expired = pirateItems[idx].expired * day;
        pirateItemsPurchased[msg.sender].push(PurchasedPirateItem({
            tokenId: uint16(tokenId),
            itemId: uint8(idx),
            time: block.timestamp,
            expired: expired + block.timestamp
        }));
    }


    function getOwnerValidPurchasedItems(address owner) external returns(PurchasedPirateItem[] memory) {
        require(msg.sender == address(bootyChest), "You are not authorised to call this function");

        for(uint8 i = 0; i< pirateItemsPurchased[owner].length; i++){
//            if(block.timestamp >= hunterItemsPurchased[owner][i].expired){
            if(pirateItemsPurchased[owner][i].time >= pirateItemsPurchased[owner][i].expired){
                // expired and item should be removed
                pirateItemsPurchased[owner][i] = pirateItemsPurchased[owner][pirateItemsPurchased[owner].length -1];
                pirateItemsPurchased[owner].pop();
            }
        }
        return pirateItemsPurchased[owner];
    }

    function getOwnerPurchasedItems(address owner) external view returns(PurchasedPirateItem[] memory) {
        require(msg.sender == address(bootyChest), "You are not authorised to call this function");
        return pirateItemsPurchased[owner];
    }

    function useOffensiveItems(uint16 tokenId, uint bootyRate, uint owed) external returns(uint){
        require(msg.sender == address(bootyChest), "You are not authorised to call this function");
        return owed;
    }
    function useDefensiveItems(uint16 tokenId, uint tax) external returns(uint){
        require(msg.sender == address(bootyChest), "You are not authorised to call this function");
        return tax;
    }

    function estOffensiveItems(uint16 tokenId, uint bootyRate, uint owed) external view returns(uint){
        require(msg.sender == address(bootyChest), "You are not authorised to call this function");
        return owed;
    }
    function estDefensiveItems(uint16 tokenId, uint tax) external view returns(uint){
        require(msg.sender == address(bootyChest), "You are not authorised to call this function");
        return tax;
    }

    function usePirateItem(address owner, uint16 idx, uint16 tokenId) external returns(PirateItem memory) {
        require(msg.sender == address(bootyChest), "You are not authorised to call this function");
//        bootyChest.isOwnerOf()
        PurchasedPirateItem memory item = pirateItemsPurchased[owner][idx];
        require(item.expired == 0 , "Address of owner does not have a valid purchase");
        require(item.tokenId == tokenId , "token Id not equal, invalid index selected");
        PirateItem memory pirateItem = pirateItems[item.itemId];

        // Check if item is expired then remove item from purchased and return
        if(block.timestamp >= item.expired  && item.time >= item.expired){
            // expired but can't remove to avoid inconsistency in indexing

            pirateItem.value = 0;
            pirateItem.expired = 0; // represents days(time) that can be claim from last time item was use till now
            //reject("item expired");
            return pirateItem;
        }

        // calculate time difference from last time used used
        uint current = block.timestamp;
        uint diff = item.expired < current ? item.expired - item.time : current - item.time; // (now - lastTime used or purchased) or (expired - lastTime if expired)
        // set time in hunter item to number of days or time it can be use in increasing or decreasing rate
        pirateItem.expired = diff; // using this to pass time diff to bootychest to use

        // Set the new time it was used as time
        pirateItemsPurchased[owner][idx].time = current;

        return pirateItem;
    }


    // function possibleRewardOnPirateItem(address owner, uint16 idx, uint16 tokenId) external view returns(PirateItem memory) {
    //     require(msg.sender == address(bootyChest), "You are not authorised to call this function");
    //     //        bootyChest.isOwnerOf()
    //     PurchasedPirateItem memory item = pirateItemsPurchased[owner][idx];
    //     require(item.expired == 0 , "Address of owner does not have a valid purchase");
    //     require(item.tokenId == tokenId , "token Id not equal, invalid index selected");
    //     PirateItem memory pirateItem = pirateItems[item.itemId];

    //     // Check if item is expired then remove item from purchased and return
    //     if(block.timestamp >= item.expired  && item.time >= item.expired){
    //         // expired but can't remove to avoid inconsistency in indexing

    //         pirateItem.value = 0;
    //         pirateItem.expired = 0; // represents days(time) that can be claim from last time item was use till now
    //         //reject("item expired");
    //         return pirateItem;
    //     }

    //     // calculate time difference from last time used used
    //     uint current = block.timestamp;
    //     uint diff = item.expired < current ? item.expired - item.time : current - item.time; // (now - lastTime used or purchased) or (expired - lastTime if expired)
    //     // set time in hunter item to number of days or time it can be use in increasing or decreasing rate
    //     pirateItem.expired = diff; // using this to pass time diff to bootychest to use

    //     return pirateItem;
    // }

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

    /// add PirateItem. ItemId should be their index in the array
    function addPirateItem(PirateItem memory _item) external onlyOwner {
        uint8 idx = uint8(pirateItems.length);
        _item.id = idx;
        pirateItems.push(_item);
    }

    function deletePirateItem(uint _idx) external onlyOwner {
        PirateItem memory item = pirateItems[_idx];
        item.valid = false;
        pirateItems[_idx] = item;
    }

    function replaceHunterItem(uint _idx, PirateItem calldata _item) external onlyOwner {
        pirateItems[_idx] = _item;
    }

    function addBounty(Bounty memory _item) external onlyOwner {
        uint8 idx = uint8(bounties.length);
        _item.id = idx;
        bounties.push(_item);
    }

    function deleteBounty(uint _idx) external onlyOwner {
        Bounty memory bounty = bounties[_idx];//lastItem;
        bounty.valid = false;
        bounties[_idx] = bounty;
    }

    function replaceBounty(uint _idx, Bounty calldata _item) external onlyOwner {
        bounties[_idx] = _item;
    }

    function setBootyChest(address _iBootyChest) external onlyOwner {
        bootyChest = IBootyChest(_iBootyChest);
    }

    function setBooty(address _iBooty) external onlyOwner {
        booty = IBooty(_iBooty);
    }

    function addRank(RankUp memory _item) external onlyOwner {
        uint idx = rankUps.length;
        _item.id = idx;
        rankUps.push(_item);
    }

    function replaceRank(uint _idx, RankUp calldata _item) external onlyOwner {
        rankUps[_idx] = _item;
    }

}
