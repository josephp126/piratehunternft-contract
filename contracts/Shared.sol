// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.8;

interface SharedStructs {


    struct PirateItem {
        string name;
        uint8 id; // should be index of item in the array
        bool offensive;
        bool percentage;
        uint value;
        uint expired; // to be specified in days
        uint noOfTime; // useful for item with max maximum time of usage
        uint price;
        uint supply;
        string img;
        bool valid; // this should not be listed for purchase if render invalid
    }

    struct PurchasedPirateItem {
        uint16 tokenId;
        uint8 itemId; // should be index of item in the array
        uint time; // timeStamp of purchase or last time used
        uint expired; //
    }
}
