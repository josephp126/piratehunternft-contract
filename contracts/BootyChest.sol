// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./IBooty.sol";
import "./IShop.sol";
import "./IPirateHunters.sol";

/**
 * Staking, unstaking, claims
 */

interface IUtils {
    function getSomeRandomNumber(uint256 _seed, uint256 _limit)
        external
        view
        returns (uint16);

    function updateRandomIndex() external;
}

contract BootyChest is Ownable, IERC721Receiver {
    using SafeMath for uint256;

    bool private _paused = false;

    struct Stake {
        uint16 tokenId;
        uint256 value; // keep time stamp of entry
        uint256 xtraReward; // for managing tax among other booty acquired
        uint256 storedReward; // for managing reward carried from rank to rank among others
        address owner;
        uint8 rank; // rank 0, 1, 2 is A, B, C respectively
    }

    event TokenStaked(address owner, uint16 tokenId, uint256 value);
    event BountyHunterClaimed(uint16 tokenId, uint256 earned, bool unstaked);
    event PirateClaimed(uint16 tokenId, uint256 earned, bool unstaked);
    event BootyBurned(
        uint16 tokenId,
        uint256 percentageBurned,
        uint256 amountBurned,
        uint256 earned
    );
    event Console(string msg, address add, uint256 amt);

    IPirateHunters public pirateHunters;
    IBooty public booty;
    IShop public shop;
    IUtils public utils;

    mapping(uint256 => uint256) public bountyHunterIndices;
    mapping(address => Stake[]) public bountyHunterStake;

    mapping(uint256 => uint256) public pirateIndices;
    mapping(address => Stake[]) public pirateStake;
    address[] public pirateHolders;

    // Total staked tokens
    uint256 public totalBountyHunterStaked;
    uint256 public totalPirateStaked = 0;

    // pirate earn 10000 $BOOTY per day
    uint256 public constant DAILY_PIRATE_BOOTY_RATE = 10000 ether;
    // BountyHunter earn 30000 $BOOTY per day
    uint256 public constant DAILY_HUNTER_BOOTY_RATE = 3000 ether;
    uint256 public constant MINIMUM_PIRATE_BOOTY_TO_CLAIM = 20000 ether;
    uint256 public constant MINIMUM_BOUNTY_HUNTER_BOOTY_TO_CLAIM = 0 ether;

    uint256 public constant TAX_THRESHOLD = 50000 ether;
    uint256 public constant TAX_PERCENTAGE_BOUNTY_HUNTER = 20;
    uint256 public constant TAX_PERCENTAGE_PIRATE = 40;
    //    uint public constant TAX_PERCENTAGE = 40;

    uint256 public constant PERCENTAGE_TO_BE_ROBBED_FROM_BOUNTY_HUNTER = 50;
    // percentage of  amount to burn once BH is robbed
    uint256 public constant PERCENTAGE_OF_ROBBED_BURN_BOUNTY_HUNTER = 50;

    uint256 public constant PERCENTAGE_TO_BE_ROBBED_FROM_PIRATE = 100;
    // percentage of  amount to burn once Pirate is robbed
    uint256 public constant PERCENTAGE_OF_ROBBED_BURN_PIRATE = 40;

    uint8 public constant RANK_A = 0;
    uint8 public constant RANK_B = 1;
    uint8 public constant RANK_C = 2;

    uint256 public constant MAXIMUM_GLOBAL_BOOTY = 10000000000 ether;

    uint256 public totalBootyEarned;

    uint256 public lastClaimTimestamp;
    uint256 public pirateReward_A = 0;
    uint256 public pirateReward_B = 0;
    uint256 public pirateReward_C = 0;
    uint256 public bountyHunterReward = 0;
    uint256 public unaccountedBountyHuntersRewards = 0;
    uint256 public unaccountedPirateRewards = 0;
    uint256 public totalPirateRank_A = 0;
    uint256 public totalPirateRank_B = 0;
    uint256 public totalPirateRank_C = 0;

    // emergency rescue to allow unstaking without any checks but without $BOOTY
    bool public rescueEnabled = false;

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

    //    function setPirateHunters(address _pirateHunters) external onlyOwner {
    //        pirateHunters = IPirateHunters(_pirateHunters);
    //    }
    //
    //    function setBooty(address _booty) external onlyOwner {
    //        booty = IBooty(_booty);
    //    }
    //
    //    function setShop(address _shop) external onlyOwner {
    //        shop = IShop(_shop);
    //    }
    //
    //    function setUtils(address _utils) external onlyOwner {
    //        utils = IUtils(_utils);
    //    }

    function setContracts(
        address _pirateHunters,
        address _booty,
        address _shop,
        address _utils
    ) external onlyOwner {
        pirateHunters = IPirateHunters(_pirateHunters);
        booty = IBooty(_booty);
        shop = IShop(_shop);
        utils = IUtils(_utils);
    }

    function getAccountBountyHunters(address user)
        external
        view
        returns (Stake[] memory)
    {
        return bountyHunterStake[user];
    }

    function getAccountPirates(address user)
        external
        view
        returns (Stake[] memory)
    {
        return pirateStake[user];
    }

    function addTokensToStake(address account, uint16[] calldata tokenIds)
        external
    {
        require(
            account == msg.sender || msg.sender == address(pirateHunters),
            "You do not have a permission to stake token"
        );

        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (msg.sender != address(pirateHunters)) {
                // dont do this step if its a mint + stake
                require(
                    pirateHunters.ownerOf(tokenIds[i]) == msg.sender,
                    "This NFT does not belong to address"
                );
                pirateHunters.transferFrom(
                    msg.sender,
                    address(this),
                    tokenIds[i]
                );
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

    function _stakeBountyHunters(address account, uint16 tokenId)
        internal
        whenNotPaused
    {
        totalBountyHunterStaked += 1;

        bountyHunterIndices[tokenId] = bountyHunterStake[account].length;
        bountyHunterStake[account].push(
            Stake({
                owner: account,
                tokenId: uint16(tokenId),
                value: block.timestamp,
                xtraReward: bountyHunterReward,
                storedReward: 0,
                rank: RANK_C
            })
        );

        emit TokenStaked(account, tokenId, block.timestamp);
    }

    function _stakePirates(address account, uint16 tokenId) internal {
        totalPirateStaked += 1;
        totalPirateRank_C += 1;

        // If account already has some pirates no need to push it to the tracker
        if (pirateStake[account].length == 0) {
            pirateHolders.push(account);
        }

        pirateIndices[tokenId] = pirateStake[account].length;
        pirateStake[account].push(
            Stake({
                owner: account,
                tokenId: uint16(tokenId),
                value: block.timestamp, //uint80(pirateReward),  // Correct pirate reward should also be base on block time
                xtraReward: pirateReward_C,
                storedReward: 0,
                rank: RANK_C
            })
        );

        emit TokenStaked(account, tokenId, block.timestamp);
    }

    function claimFromStake(uint16[] calldata tokenIds, bool unstake)
        external
        whenNotPaused
    {
        uint256 owed = 0;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (!pirateHunters.isPirate(tokenIds[i])) {
                owed += _claimFromHunter(tokenIds[i], unstake);
            } else {
                owed += _claimFromPirate(tokenIds[i], unstake);
            }
        }
        if (owed == 0) return;
        mintBooty(msg.sender, owed);
    }

    function possibleClaimForToken(uint16 tokenId)
        public
        view
        returns (uint256)
    {
        // uint x = 0;
        if (pirateHunters.isPirate(tokenId)) {
            Stake memory stake = pirateStake[msg.sender][
                pirateIndices[tokenId]
            ];
            return _possibleClaimForPirate(stake);
        } else {
            Stake memory stake = bountyHunterStake[msg.sender][
                bountyHunterIndices[tokenId]
            ];
            return _possibleClaimForHunter(stake);
        }
        // owed = x;
    }

    function _possibleClaimForHunter(Stake memory stake)
        private
        view
        returns (uint256 owed)
    {
        require(
            stake.owner == msg.sender,
            "This NFT does not belong to address"
        );
        require(
            totalBootyEarned < MAXIMUM_GLOBAL_BOOTY,
            "$BOOTY production stopped"
        );
        require(stake.value > 0, "Token not staked");

        uint256 current = block.timestamp;
        owed = ((current - stake.value) * DAILY_HUNTER_BOOTY_RATE) / 1 days;

        // add all extra acquired
        owed += (bountyHunterReward - stake.xtraReward) + stake.storedReward;
    }

    function mintAndBurn(uint256 amount) internal {
        mintBooty(address(this), amount);
        booty.burn(address(this), amount);
    }

    function mintBooty(address to, uint256 amount) internal {
        booty.mint(to, amount);
        totalBootyEarned += amount;
    }

    function _claimFromHunter(uint16 tokenId, bool unstake)
        internal
        returns (uint256 owed)
    {
        Stake memory stake = bountyHunterStake[msg.sender][
            bountyHunterIndices[tokenId]
        ];

        owed = _possibleClaimForHunter(stake);
        require(
            owed > MINIMUM_BOUNTY_HUNTER_BOOTY_TO_CLAIM,
            "$BOOTY less than minimum"
        );
        //Burning and robbery

        if (owed <= TAX_THRESHOLD) {
            uint256 tax = (TAX_PERCENTAGE_BOUNTY_HUNTER * owed) / 100;
            owed -= tax;
            mintAndBurn(tax);
            emit BootyBurned(tokenId, TAX_PERCENTAGE_BOUNTY_HUNTER, tax, owed);
        } else {
            uint256 robbed = (PERCENTAGE_TO_BE_ROBBED_FROM_BOUNTY_HUNTER *
                owed) / 100;
            owed -= robbed;
            _payTaxBountyHunter(robbed);
        }

        if (unstake) {
            totalBountyHunterStaked -= 1;
            Stake memory lastStake = bountyHunterStake[msg.sender][
                bountyHunterStake[msg.sender].length - 1
            ];
            bountyHunterStake[msg.sender][
                bountyHunterIndices[tokenId]
            ] = lastStake;
            bountyHunterIndices[lastStake.tokenId] = bountyHunterIndices[
                tokenId
            ];
            bountyHunterStake[msg.sender].pop();
            delete bountyHunterIndices[tokenId];
            pirateHunters.safeTransferFrom(
                address(this),
                msg.sender,
                tokenId,
                ""
            );
        } else {
            // uint80 timestamp = uint80(block.timestamp);
            bountyHunterStake[msg.sender][
                bountyHunterIndices[tokenId]
            ] = Stake({
                owner: msg.sender,
                tokenId: uint16(tokenId),
                value: block.timestamp,
                xtraReward: bountyHunterReward,
                storedReward: 0,
                rank: stake.rank
            }); // reset stake
        }

        emit BountyHunterClaimed(tokenId, owed, unstake);
    }

    function _possibleClaimForPirate(Stake memory stake)
        private
        view
        returns (uint256)
    {
        require(
            pirateHunters.ownerOf(stake.tokenId) == address(this),
            "This NFT does not belong to address"
        );
        require(
            stake.owner == msg.sender,
            "This NFT does not belong to address"
        );
        require(
            totalBootyEarned < MAXIMUM_GLOBAL_BOOTY,
            "$BOOTY production stopped"
        );
        require(stake.value > 0, "Token not staked");

        uint256 current = block.timestamp;
        uint256 owed = ((current - stake.value) * DAILY_PIRATE_BOOTY_RATE) /
            1 days;

        uint256 pirateReward = 0;
        if (stake.rank == RANK_A) {
            pirateReward = pirateReward_A;
        } else if (stake.rank == RANK_B) {
            pirateReward = pirateReward_B;
        } else {
            pirateReward = pirateReward_C;
        }
        owed += (pirateReward - stake.xtraReward) + stake.storedReward;
        return owed;
    }

    function _claimFromPirate(uint16 tokenId, bool unstake)
        internal
        returns (uint256 owed)
    {
        require(
            pirateHunters.ownerOf(tokenId) == address(this),
            "This NFT does not belong to address"
        );

        Stake memory stake = pirateStake[msg.sender][pirateIndices[tokenId]];

        require(
            stake.owner == msg.sender,
            "This NFT does not belong to address"
        );

        owed = _possibleClaimForPirate(stake);

        require(
            owed >= MINIMUM_PIRATE_BOOTY_TO_CLAIM,
            "$BOOTY not upto minimum claimable "
        );

        if (address(shop) != address(0))
            owed = shop.useOffensiveItems(
                tokenId,
                DAILY_PIRATE_BOOTY_RATE,
                owed
            ); // offensive only

        if (owed <= TAX_THRESHOLD) {
            uint256 tax = (TAX_PERCENTAGE_PIRATE * owed) / 100;
            owed -= tax;
            _payTaxPirate(tax);
        } else {
            if (utils.getSomeRandomNumber(tokenId, 100) <= 50) {
                uint256 burn = (PERCENTAGE_OF_ROBBED_BURN_PIRATE * owed) / 100;

                uint256 tax = owed - burn;
                if (address(shop) != address(0))
                    tax = shop.useDefensiveItems(tokenId, tax); // defensive only
                _payTaxPirate(tax); // pay 60% of what is robbed
                mintAndBurn(burn); // burn 40%
                emit BootyBurned(
                    tokenId,
                    PERCENTAGE_OF_ROBBED_BURN_PIRATE,
                    owed,
                    0
                );
                owed = 0;
            }
            utils.updateRandomIndex();
        }

        if (unstake) {
            totalPirateStaked -= 1; // Remove Alpha from total staked
            if (stake.rank == RANK_A) {
                totalPirateRank_A -= 1;
            } else if (stake.rank == RANK_B) {
                totalPirateRank_B -= 1;
            } else {
                totalPirateRank_C -= 1;
            }

            Stake memory lastStake = pirateStake[msg.sender][
                pirateStake[msg.sender].length - 1
            ];
            pirateStake[msg.sender][pirateIndices[tokenId]] = lastStake;
            pirateIndices[lastStake.tokenId] = pirateIndices[tokenId];
            pirateStake[msg.sender].pop();
            delete pirateIndices[tokenId];
            updatePirateOwnerAddressList(msg.sender);

            pirateHunters.safeTransferFrom(
                address(this),
                msg.sender,
                tokenId,
                ""
            );
        } else {
            uint256 currentPirateReward = uint80(pirateReward_C);
            if (stake.rank == RANK_A) {
                currentPirateReward = uint80(pirateReward_A);
            } else if (stake.rank == RANK_B) {
                currentPirateReward = uint80(pirateReward_B);
            }
            pirateStake[msg.sender][pirateIndices[tokenId]] = Stake({
                owner: msg.sender,
                tokenId: uint16(tokenId),
                value: block.timestamp, // ,
                xtraReward: currentPirateReward,
                storedReward: 0,
                rank: stake.rank
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
        uint256 indexOfHolder = 0;
        for (uint256 i = 0; i < pirateHolders.length; i++) {
            if (pirateHolders[i] == account) {
                indexOfHolder = i;
                break;
            }
        }
        pirateHolders[indexOfHolder] = lastOwner;
        pirateHolders.pop();
    }

    // pirate pay tax to Bounty Hunters
    function _payTaxPirate(uint256 _amount) internal {
        if (totalBountyHunterStaked == 0) {
            unaccountedBountyHuntersRewards += _amount;
            return;
        }

        bountyHunterReward +=
            (_amount + unaccountedBountyHuntersRewards) /
            totalBountyHunterStaked;
        unaccountedBountyHuntersRewards = 0;
    }

    //Bounty hunters pay tax to pirate
    function _payTaxBountyHunter(uint256 _amount) internal {
        if (totalPirateStaked == 0) {
            unaccountedPirateRewards += _amount;
            return;
        }

        //        pirateReward += (_amount + unaccountedPirateRewards) / totalPirateStaked;
        uint256 pirateReward = (_amount + unaccountedPirateRewards);
        // using 1.5x + 1.25x + x = pirateReward (total pirate reward)
        uint256 x = (pirateReward * 375) / 100; // 375/100 = 3.75
        pirateReward_C += x / totalPirateRank_C;
        pirateReward_B += ((125 * x) / 100) / totalPirateRank_B;
        pirateReward_A += ((15 * x) / 10) / totalPirateRank_A;

        unaccountedPirateRewards = 0;
    }

    modifier _updateEarnings() {
        if (totalBootyEarned < MAXIMUM_GLOBAL_BOOTY) {
            totalBootyEarned +=
                ((block.timestamp - lastClaimTimestamp) *
                    totalBountyHunterStaked *
                    DAILY_PIRATE_BOOTY_RATE) /
                1 days;
            lastClaimTimestamp = block.timestamp;
        }
        _;
    }

    function setPaused(bool _state) external onlyOwner {
        _paused = _state;
    }

    function isOwnerOf(uint16 tokenId, address owner)
        external
        view
        returns (bool)
    {
        if (pirateHunters.isPirate(tokenId)) {
            return pirateStake[owner][pirateIndices[tokenId]].owner == owner;
        } else {
            return
                bountyHunterStake[owner][bountyHunterIndices[tokenId]].owner ==
                owner;
        }
    }

    function effectRankUp(uint256 tokenId, uint256 newRank) external {
        require(msg.sender == address(shop), "Unauthorized");
        Stake memory stake = pirateStake[msg.sender][pirateIndices[tokenId]];
        if (newRank == RANK_B) {
            // calculate carry over shared reward
            uint256 share = (pirateReward_C - stake.xtraReward) /
                totalPirateRank_C;
            pirateStake[msg.sender][pirateIndices[tokenId]] = Stake({
                owner: msg.sender,
                tokenId: uint16(tokenId),
                value: block.timestamp,
                xtraReward: pirateReward_B,
                storedReward: share,
                rank: RANK_B
            }); // reset stake

            totalPirateRank_C -= 1;
            totalPirateRank_B += 1;
        } else if (newRank == RANK_A) {
            uint256 share = (pirateReward_B - stake.xtraReward) /
                totalPirateRank_B;
            pirateStake[msg.sender][pirateIndices[tokenId]] = Stake({
                owner: msg.sender,
                tokenId: uint16(tokenId),
                value: block.timestamp,
                xtraReward: pirateReward_A,
                storedReward: share,
                rank: RANK_A
            });

            totalPirateRank_B -= 1;
            totalPirateRank_A += 1;
        }
    }

    function onERC721Received(
        address,
        address from,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        require(
            from == address(0x0),
            "Cannot send tokens to this contact directly"
        );
        return IERC721Receiver.onERC721Received.selector;
    }
}
