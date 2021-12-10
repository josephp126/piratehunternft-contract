// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IPirateHunters {
    function ownerOf(uint id) external view returns (address);
    function isPirate(uint16 id) external view returns (bool);
    function transferFrom(address from, address to, uint tokenId) external;
    function safeTransferFrom(address from, address to, uint tokenId, bytes memory _data) external;
}

interface IBooty {
    function mint(address account, uint amount) external;
}

contract BootyChest is Ownable, IERC721Receiver {
    bool private _paused = false;

    uint16 private _randomIndex = 0;
    uint private _randomCalls = 0;
    mapping(uint => address) private _randomSource;

    struct Stake {
        uint16 tokenId;
        uint80 value;
        address owner;
    }

    event TokenStaked(address owner, uint16 tokenId, uint value);
    event BountyHunterClaimed(uint16 tokenId, uint earned, bool unstaked);
    event PirateClaimed(uint16 tokenId, uint earned, bool unstaked);

    IPirateHunters public pirateHunters;
    IBooty public booty;

    mapping(uint256 => uint256) public bountyHunterIndices;
    mapping(address => Stake[]) public bountyHunterStake;

    mapping(uint256 => uint256) public pirateIndices;
    mapping(address => Stake[]) public pirateStake;
    address[] public pirateHolders;

    // Total staked tokens
    uint public totalBountyHunterStaked;
    uint public totalPirateStaked = 0;
    uint public unaccountedRewards = 0;

    // pirate earn 10000 $BOOTY per day
    uint public constant DAILY_PIRATE_BOOTY_RATE = 10000 ether;
    // BountyHunter earn 30000 $BOOTY per day
    uint public constant DAILY_HUNTER_BOOTY_RATE = 30000 ether;
    uint public constant MINIMUM_TIME_TO_EXIT = 2 days;
    uint public constant TAX_PERCENTAGE = 20;
    uint public constant MAXIMUM_GLOBAL_BOOTY = 1000000000 ether;

    uint public totalBootyEarned;

    uint public lastClaimTimestamp;
    uint public pirateReward = 0;

    // emergency rescue to allow unstaking without any checks but without $BOOTY
    bool public rescueEnabled = false;

    constructor() {
        // Fill random source addresses
        _randomSource[0] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        _randomSource[1] = 0x3cD751E6b0078Be393132286c442345e5DC49699;
        _randomSource[2] = 0xb5d85CBf7cB3EE0D56b3bB207D5Fc4B82f43F511;
        _randomSource[3] = 0xC098B2a3Aa256D2140208C3de6543aAEf5cd3A94;
        _randomSource[4] = 0x28C6c06298d514Db089934071355E5743bf21d60;
        _randomSource[5] = 0x2FAF487A4414Fe77e2327F0bf4AE2a264a776AD2;
        _randomSource[6] = 0x267be1C1D684F78cb4F6a176C4911b741E4Ffdc0;
    }

    function paused() public view virtual returns (bool) {
        return _paused;
    }

    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }

    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }

    function setPirateHunters(address _pirateHunters) external onlyOwner {
        pirateHunters = IPirateHunters(_pirateHunters);
    }

    function setBooty(address _booty) external onlyOwner {
        booty = IBooty(_booty);
    }

    function getAccountBountyHunters(address user) external view returns (Stake[] memory) {
        return bountyHunterStake[user];
    }

    function getAccountPirates(address user) external view returns (Stake[] memory) {
        return pirateStake[user];
    }

    function addTokensToStake(address account, uint16[] calldata tokenIds) external {
        require(account == msg.sender || msg.sender == address(pirateHunters), "You do not have a permission to stake tokens");


        // TODO: Reanalyse
        for (uint i = 0; i < tokenIds.length; i++) {
            if (msg.sender != address(pirateHunters)) {
                // dont do this step if its a mint + stake
                require(pirateHunters.ownerOf(tokenIds[i]) == msg.sender, "This NFT does not belong to address");
                pirateHunters.transferFrom(msg.sender, address(this), tokenIds[i]);
            } else if (tokenIds[i] == 0) {
                continue; // there may be gaps in the array for stolen tokens
            }

            if (pirateHunters.isPirate(tokenIds[i])) {
                _stakePirates(account, tokenIds[i]);
            } else {
                _stakeBountyHunters(account, tokenIds[i]);
            }
        }
    }

    function _stakeBountyHunters(address account, uint16 tokenId) internal whenNotPaused _updateEarnings {
        totalBountyHunterStaked += 1;

        bountyHunterIndices[tokenId] = bountyHunterStake[account].length;
        bountyHunterStake[account].push(Stake({
            owner: account,
            tokenId: uint16(tokenId),
            value: uint80(block.timestamp)
        }));
        emit TokenStaked(account, tokenId, block.timestamp);
    }


    function _stakePirates(address account, uint16 tokenId) internal {
        totalPirateStaked += 1;

        // If account already has some pirates no need to push it to the tracker
        if (pirateStake[account].length == 0) {
            pirateHolders.push(account);
        }

        pirateIndices[tokenId] = pirateStake[account].length;
        pirateStake[account].push(Stake({
            owner: account,
            tokenId: uint16(tokenId),
            value: uint80(pirateReward)  // Correct pirate reward should also be base on block time
            }));

        emit TokenStaked(account, tokenId, pirateReward);
    }


    function claimFromStake(uint16[] calldata tokenIds, bool unstake) external whenNotPaused _updateEarnings {
        uint owed = 0;
        for (uint i = 0; i < tokenIds.length; i++) {
            if (!pirateHunters.isPirate(tokenIds[i])) {
                owed += _claimFromHunter(tokenIds[i], unstake);
            } else {
                owed += _claimFromPirate(tokenIds[i], unstake);
            }
        }
        if (owed == 0) return;
        booty.mint(msg.sender, owed);
    }

    function _claimFromHunter(uint16 tokenId, bool unstake) internal returns (uint owed) {
        Stake memory stake = bountyHunterStake[msg.sender][bountyHunterIndices[tokenId]];
        require(stake.owner == msg.sender, "This NTF does not belong to address");
        require(!(unstake && block.timestamp - stake.value < MINIMUM_TIME_TO_EXIT), "Need to wait 2 days since last claim");

        if (totalBootyEarned < MAXIMUM_GLOBAL_BOOTY) {
            owed = ((block.timestamp - stake.value) * DAILY_PIRATE_BOOTY_RATE) / 1 days;
        } else if (stake.value > lastClaimTimestamp) {
            owed = 0; // $BOOTY production stopped already
        } else {
            owed = ((lastClaimTimestamp - stake.value) * DAILY_PIRATE_BOOTY_RATE) / 1 days; // stop earning additional $BOOTY if it's all been earned
        }
        if (unstake) {
            if (getSomeRandomNumber(tokenId, 100) <= 50) {
                _payTax(owed);
                owed = 0;
            }
            updateRandomIndex();
            totalBountyHunterStaked -= 1;

            Stake memory lastStake = bountyHunterStake[msg.sender][bountyHunterStake[msg.sender].length - 1];
            bountyHunterStake[msg.sender][bountyHunterIndices[tokenId]] = lastStake;
            bountyHunterIndices[lastStake.tokenId] = bountyHunterIndices[tokenId];
            bountyHunterStake[msg.sender].pop();
            delete bountyHunterIndices[tokenId];

            pirateHunters.safeTransferFrom(address(this), msg.sender, tokenId, "");
        } else {
            _payTax((owed * TAX_PERCENTAGE) / 100); // Pay some $BOOTY to pirates!
            owed = (owed * (100 - TAX_PERCENTAGE)) / 100;

            uint80 timestamp = uint80(block.timestamp);

            bountyHunterStake[msg.sender][bountyHunterIndices[tokenId]] = Stake({
                owner: msg.sender,
                tokenId: uint16(tokenId),
                value: timestamp
            }); // reset stake
        }

        emit BountyHunterClaimed(tokenId, owed, unstake);
    }

    function _claimFromPirate(uint16 tokenId, bool unstake) internal returns (uint owed) {
        require(pirateHunters.ownerOf(tokenId) == address(this), "This NTF does not belong to address");

        Stake memory stake = pirateStake[msg.sender][pirateIndices[tokenId]];

        require(stake.owner == msg.sender, "This NTF does not belong to address");
        owed = (pirateReward - stake.value);

        if (unstake) {
            totalPirateStaked -= 1; // Remove Alpha from total staked

            Stake memory lastStake = pirateStake[msg.sender][pirateStake[msg.sender].length - 1];
            pirateStake[msg.sender][pirateIndices[tokenId]] = lastStake;
            pirateIndices[lastStake.tokenId] = pirateIndices[tokenId];
            pirateStake[msg.sender].pop();
            delete pirateIndices[tokenId];
            updatePirateOwnerAddressList(msg.sender);

            pirateHunters.safeTransferFrom(address(this), msg.sender, tokenId, "");
        } else {
            pirateStake[msg.sender][pirateIndices[tokenId]] = Stake({
                owner: msg.sender,
                tokenId: uint16(tokenId),
                value: uint80(pirateReward)
            }); // reset stake
        }
        emit PirateClaimed(tokenId, owed, unstake);
    }

    function updatePirateOwnerAddressList(address account) internal {
        if (pirateStake[account].length != 0) {
            return; // No need to update holders
        }

        // Update the address list of holders, account unstaked all pirates
        address lastOwner = pirateHolders[pirateHolders.length - 1];
        uint indexOfHolder = 0;
        for (uint i = 0; i < pirateHolders.length; i++) {
            if (pirateHolders[i] == account) {
                indexOfHolder = i;
                break;
            }
        }
        pirateHolders[indexOfHolder] = lastOwner;
        pirateHolders.pop();
    }

    function rescue(uint16[] calldata tokenIds) external {
        require(rescueEnabled, "Rescue disabled");
        uint16 tokenId;
        Stake memory stake;

        for (uint16 i = 0; i < tokenIds.length; i++) {
            tokenId = tokenIds[i];
            if (!pirateHunters.isPirate(tokenId)) {
                stake = bountyHunterStake[msg.sender][bountyHunterIndices[tokenId]];

                require(stake.owner == msg.sender, "This NFT does not belong to address");

                totalBountyHunterStaked -= 1;

                Stake memory lastStake = bountyHunterStake[msg.sender][bountyHunterStake[msg.sender].length - 1];
                bountyHunterStake[msg.sender][bountyHunterIndices[tokenId]] = lastStake;
                bountyHunterIndices[lastStake.tokenId] = bountyHunterIndices[tokenId];
                bountyHunterStake[msg.sender].pop();
                delete bountyHunterIndices[tokenId];

                pirateHunters.safeTransferFrom(address(this), msg.sender, tokenId, "");

                emit BountyHunterClaimed(tokenId, 0, true);
            } else {
                stake = pirateStake[msg.sender][pirateIndices[tokenId]];

                require(stake.owner == msg.sender, "This NFT does not belong to address");

                totalPirateStaked -= 1;


                Stake memory lastStake = pirateStake[msg.sender][pirateStake[msg.sender].length - 1];
                pirateStake[msg.sender][pirateIndices[tokenId]] = lastStake;
                pirateIndices[lastStake.tokenId] = pirateIndices[tokenId];
                pirateStake[msg.sender].pop();
                delete pirateIndices[tokenId];
                updatePirateOwnerAddressList(msg.sender);

                pirateHunters.safeTransferFrom(address(this), msg.sender, tokenId, "");

                emit PirateClaimed(tokenId, 0, true);
            }
        }
    }

    function _payTax(uint _amount) internal {
        if (totalPirateStaked == 0) {
            unaccountedRewards += _amount;
            return;
        }

        pirateReward += (_amount + unaccountedRewards) / totalPirateStaked;
        unaccountedRewards = 0;
    }


    modifier _updateEarnings() {
        if (totalBootyEarned < MAXIMUM_GLOBAL_BOOTY) {
            totalBootyEarned += ((block.timestamp - lastClaimTimestamp) * totalBountyHunterStaked * DAILY_PIRATE_BOOTY_RATE) / 1 days;
            lastClaimTimestamp = block.timestamp;
        }
        _;
    }


    function setRescueEnabled(bool _enabled) external onlyOwner {
        rescueEnabled = _enabled;
    }

    function setPaused(bool _state) external onlyOwner {
        _paused = _state;
    }


    function randomPirateOwner() external returns (address) {
        if (totalPirateStaked == 0) return address(0x0);

        uint holderIndex = getSomeRandomNumber(totalPirateStaked, pirateHolders.length);
        updateRandomIndex();

        return pirateHolders[holderIndex];
    }

    function updateRandomIndex() internal {
        _randomIndex += 1;
        _randomCalls += 1;
        if (_randomIndex > 6) _randomIndex = 0;
    }

    function getSomeRandomNumber(uint _seed, uint _limit) internal view returns (uint16) {
        uint extra = 0;
        for (uint16 i = 0; i < 7; i++) {
            extra += _randomSource[_randomIndex].balance;
        }

        uint random = uint(
            keccak256(
                abi.encodePacked(
                    _seed,
                    blockhash(block.number - 1),
                    block.coinbase,
                    block.difficulty,
                    msg.sender,
                    extra,
                    _randomCalls,
                    _randomIndex
                )
            )
        );

        return uint16(random % _limit);
    }

    function changeRandomSource(uint _id, address _address) external onlyOwner {
        _randomSource[_id] = _address;
    }

    function shuffleSeeds(uint _seed, uint _max) external onlyOwner {
        uint shuffleCount = getSomeRandomNumber(_seed, _max);
        _randomIndex = uint16(shuffleCount);
        for (uint i = 0; i < shuffleCount; i++) {
            updateRandomIndex();
        }
    }

    function onERC721Received(
        address,
        address from,
        uint,
        bytes calldata
    ) external pure override returns (bytes4) {
        require(from == address(0x0), "Cannot send tokens to this contact directly");
        return IERC721Receiver.onERC721Received.selector;
    }
}
