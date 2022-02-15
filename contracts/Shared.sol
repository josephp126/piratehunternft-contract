// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.8;

interface SharedStructs {
    struct PirateItem {
        string name;
        uint8 id; // should be index of item in the array
        bool offensive;
        bool percentage;
        uint256 value;
        uint256 expired; // to be specified in days
        uint256 noOfTime; // useful for item with max maximum time of usage
        uint256 price;
        uint256 supply;
        string img;
        bool valid; // this should not be listed for purchase if render invalid
    }

    struct PurchasedPirateItem {
        uint16 tokenId;
        uint8 itemId; // should be index of item in the array
        uint256 time; // timeStamp of purchase or last time used
        uint256 expired;
        uint256 tokenextime; //
    }
}
