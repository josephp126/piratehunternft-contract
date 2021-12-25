pragma solidity ^0.8.8;

import "./Shared.sol";

// SPDX-License-Identifier: MIT

interface IShop is SharedStructs {


//    function getOffensive(uint16 tokenid) external view returns (uint); // for estimating
//    function useOffensive(uint16 tokenid) external returns (uint);
//    function getDefensive(uint16 tokenid) external view returns (uint); // for estimating
//    function useDefensive(uint16 tokenid) external returns (uint);
    // function possibleRewardOnPirateItem(address owner, uint16 idx, uint16 tokenId) external view returns(PirateItem memory);
    function usePirateItem(address owner, uint16 idx, uint16 tokenId) external returns(PirateItem memory);
    function getOwnerPurchasedItems(address owner) external view returns(PurchasedPirateItem[] memory);
    function getOwnerValidPurchasedItems(address owner) external returns(PurchasedPirateItem[] memory);

}
