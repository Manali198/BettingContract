// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// author @manali Trivedi

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract NFTBettingGame is ERC721, ERC721URIStorage, Ownable {
    uint256 public constant MAX_NFTS = 20;
    uint256 public constant BETTING_FEE = 1 ether;
    uint256 public totalBets;
    uint256 public pot;
    address payable public winner;
    bool public bettingClosed = false;
    uint256[] public tokenIdList;
    uint256 public totalSupply;
    uint256 public constant TREASURY_FEE_PERCENTAGE = 5;
    uint public treasuryPool;
    string public _uri;

    mapping(uint256 => uint256) private _totalBetAmount;
    mapping(address => uint256) public betAmount;
    mapping(address => bool) public hasMinted;
    mapping(uint256 => mapping(address => uint256)) public betAmounts;

    using Counters for Counters.Counter;

    Counters.Counter private currentTokenId;

    string public baseTokenURI;

    constructor(string memory uri) ERC721("NFTBETTING", "BET") {
        _uri = uri;
        // baseTokenURI = "" ;
    }

    function mintTo(address recipient) public returns (uint256) {
        currentTokenId.increment();
        uint256 newItemId = currentTokenId.current();
        _safeMint(recipient, newItemId);
        return newItemId;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    function setBaseTokenURI(string memory _baseTokenURI) public {
        baseTokenURI = _baseTokenURI;
    }

    function mintNFT() public payable {
        require(
            msg.value >= BETTING_FEE,
            "Not enough ether to participate in the game"
        );
        require(totalSupply < MAX_NFTS, "Maximum NFTs have been minted");
        require(hasMinted[msg.sender] == false, "You already minted an NFT");

        uint256 tokenId = currentTokenId.current();
        currentTokenId.increment();

        totalBets++;
        pot += msg.value;
        betAmount[msg.sender] = msg.value;
        tokenIdList.push(totalSupply);
        totalSupply++;
        hasMinted[msg.sender] = true;   
        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, _uri);
    }

    function placeBet(uint256 tokenId) public payable {
        require(bettingClosed == false, "Betting is closed");
        require(totalSupply == MAX_NFTS, "All NFTs have been minted");
        require(winner == address(0), "Winner has already been chosen");
        require(ownerOf(tokenId) != address(0), "Invalid NFT token ID");

        uint256 betAmount = msg.value;
        require(betAmount > 0, "Bet amount must be greater than 0");

        pot += betAmount;
        betAmounts[tokenId][msg.sender] += betAmount;
    }

    function closeBetting() public onlyOwner {
        require(totalSupply == MAX_NFTS, "Not all NFTs have been minted");
        require(bettingClosed == false, "Betting is already closed");
        bettingClosed = true;
    }

    function contains(
        uint256[] memory array,
        uint256 value
    ) private pure returns (bool) {
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == value) {
                return true;
            }   
        }
        return false;
    }

function distributeRewards() public payable onlyOwner {
    require(bettingClosed == true, "Betting is still open");
    require(winner == address(0), "Rewards have already been distributed");

    // Create an array of addresses that placed bets
    address[] memory bettors = new address[](totalBets);
    uint256 index = 0;
    for (uint256 i = 0; i < tokenIdList.length; i++) {
        for (uint256 j = 0; j < totalBets; j++) {
            if (bettors[j] == address(0)) {
                bettors[j] = ownerOf(tokenIdList[i]);
                break;
            } else if (ownerOf(tokenIdList[i]) == bettors[j]) {
                break;
            }
        }
    }

    // Shuffle the bettors array randomly
    for (uint256 i = 0; i < totalBets; i++) {
        uint256 randomIndex = i + uint256(keccak256(abi.encodePacked(block.timestamp))) % (totalBets - i);
        address temp = bettors[randomIndex];
        bettors[randomIndex] = bettors[i];
        bettors[i] = temp;
    }

    // Calculate rewards for top 10 winners
    uint256[] memory rewards = new uint256[](10);
    uint256 totalRewards = (pot * 80) / 100; // 80% of total pot
    for (uint256 i = 0; i < 10; i++) {
        if (i >= bettors.length) {
            break;
        }
        rewards[i] = (totalRewards * (i + 1)) / 55; // distribute rewards in ascending form
        payable(bettors[i]).transfer(rewards[i]); // transfer rewards to the winner
    }

    treasuryPool += (pot - totalRewards); // keep 20% of the total pot in treasury

    winner = payable(bettors[0]);
}

// function distributeRewards() public payable onlyOwner {
//     require(bettingClosed == true, "Betting is still open");
//     require(winner == address(0), "Rewards have already been distributed");

//     // Create an array of addresses that placed bets
//     address[] memory bettors = new address[](totalBets);
//     uint256 index = 0;
//     for (uint256 i = 0; i < tokenIdList.length; i++) {
//         for (uint256 j = 0; j < totalBets; j++) {
//             if (bettors[j] == address(0)) {
//                 bettors[j] = ownerOf(tokenIdList[i]);
//                 break;
//             } else if (ownerOf(tokenIdList[i]) == bettors[j]) {
//                 break;
//             }
//         }
//     }

//     for (uint256 i = 0; i < totalBets; i++) {
//         uint256 randomIndex = i + uint256(keccak256(abi.encodePacked(block.timestamp))) % (totalBets - i);
//         address temp = bettors[randomIndex];
//         bettors[randomIndex] = bettors[i];
//         bettors[i] = temp;
//     }

//     // Calculate rewards for top 3 winners
//     uint256 firstPrize = (pot * 40) / 100;
//     uint256 secondPrize = (pot * 30) / 100;
//     uint256 thirdPrize = (pot * 10) / 100;
//     uint256 totalRewards = firstPrize + secondPrize + thirdPrize;

//     // Distribute rewards to top 3 winners
//     for (uint256 i = 0; i < 3; i++) {
//         if (i >= bettors.length) {
//             break;
//         }

//         if (i == 0) {
//             payable(bettors[i]).transfer(firstPrize);
//         } else if (i == 1) {
//             payable(bettors[i]).transfer(secondPrize);
//         } else if (i == 2) {
//             payable(bettors[i]).transfer(thirdPrize);
//         }
//     }

//     treasuryPool += (pot - totalRewards);

//     winner = payable(bettors[0]);
// }



// function distributeRewards() public payable onlyOwner {
//     require(bettingClosed == true, "Betting is still open");
//     require(winner == address(0), "Rewards have already been distributed");

//     // Create an array of addresses that placed bets
//     address[] memory bettors = new address[](totalBets);
//     uint256 index = 0;
//     for (uint256 i = 0; i < tokenIdList.length; i++) {
//         for (uint256 j = 0; j < totalBets; j++) {
//             if (bettors[j] == address(0)) {
//                 bettors[j] = ownerOf(tokenIdList[i]);
//                 break;
//             } else if (ownerOf(tokenIdList[i]) == bettors[j]) {
//                 break;
//             }
//         }
//     }

//     for (uint256 i = 0; i < totalBets; i++) {
//         uint256 randomIndex = i + uint256(keccak256(abi.encodePacked(block.timestamp))) % (totalBets - i);
//         address temp = bettors[randomIndex];
//         bettors[randomIndex] = bettors[i];
//         bettors[i] = temp;
//     }

//     uint256 pot80Percent = (pot * 80) / 100;
//     uint256 firstReward = (pot80Percent * 40) / 100;
//     uint256 secondReward = (pot80Percent * 30) / 100;
//     uint256 thirdReward = (pot80Percent * 10) / 100;
    
//     for (uint256 i = 0; i < 3; i++) {
//         if (i >= bettors.length) {
//             break;
//         }
//         if (i == 0) {
//             payable(bettors[i]).transfer(firstReward);
//         } else if (i == 1) {
//             payable(bettors[i]).transfer(secondReward);
//         } else if (i == 2) {
//             payable(bettors[i]).transfer(thirdReward);
//         }
//     }
    
//     treasuryPool += (pot * 20) / 100;

//     winner = payable(bettors[0]);
// }



// function distributeRewards() public payable onlyOwner {
//     require(bettingClosed == true, "Betting is still open");
//     require(winner == address(0), "Rewards have already been distributed");

//     // Create an array of addresses that placed bets
//     address[] memory bettors = new address[](totalBets);
//     uint256 index = 0;
//     for (uint256 i = 0; i < tokenIdList.length; i++) {
//         for (uint256 j = 0; j < totalBets; j++) {
//             if (bettors[j] == address(0)) {
//                 bettors[j] = ownerOf(tokenIdList[i]);
//                 break;
//             } else if (ownerOf(tokenIdList[i]) == bettors[j]) {
//                 break;
//             }
//         }
//     }

//     for (uint256 i = 0; i < totalBets; i++) {
//         uint256 randomIndex = i + uint256(keccak256(abi.encodePacked(block.timestamp))) % (totalBets - i);
//         address temp = bettors[randomIndex];
//         bettors[randomIndex] = bettors[i];
//         bettors[i] = temp;
//     }

//     for (uint256 i = 0; i < 3; i++) {
//         if (i >= bettors.length) {
//             break;
//         }
//         uint256 reward = (pot * 80) / 100 / 3;
//         payable(bettors[i]).transfer(reward);
//     }
//     treasuryPool += (pot * 20) / 100;

//     winner = payable(bettors[0]);
// }
    function refundBets() public {
        require(bettingClosed == true, "Betting is still open");
        require(winner != address(0), "Winner has not been picked yet");
        require(msg.sender != winner, "Winner cannot refund their bet");

        uint256 amount = betAmount[msg.sender];
        require(amount > 0, "You did not participate in the betting");

        betAmount[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    }
}
