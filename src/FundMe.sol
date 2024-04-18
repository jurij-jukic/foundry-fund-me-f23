// SPDX-License-Identifier: MIT
// 1. Pragma
pragma solidity ^0.8.19;
// 2. Imports

//remappings = ["@chainlink/contracts=lib/chainlink-brownie-contracts/contracts/"] in foundry.toml
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {PriceConverter} from "./PriceConverter.sol";

// 3. Interfaces, Libraries, Contracts
//  error naming convention - ContractName__ErrorItself();
error FundMe__NotOwner();

/**
 * @title A sample Funding Contract
 * @author Patrick Collins
 * @notice This contract is for creating a sample funding contract
 * @dev This implements price feeds as our library
 */
contract FundMe {
    // Type Declarations
    using PriceConverter for uint256;

    // State variables and Storage
    //  storage of state vars has to do with gas optimization
    //  global/state vars are stored in storage, a contiguous block of memory, w/ 32byte hex slots
    //  state vars se spremaju po redu kako su declareane u storage
    //  dynamic vars are stored with hash + their slots are the end and have variable length
    //  - arrays also take up a sequential spot in their proper place, but it contains their length
    //  - same for mappings, but the spot is left empty
    //  constant and immutable vars are not in storage. they are part of the contract's bytecode itself
    //  vars inside of funcs dont get added to storage but to their own memory data structure
    //  for strings (= dynamic arrays) within func we need to decide whether we put it to storage (perm) or memory (temp within func)
    //
    //  “You can think of storage as a large array that has a virtual structure… a structure you cannot change at runtime - it is determined by the state variables in your contract”.
    //  https://stackoverflow.com/questions/33839154/in-ethereum-solidity-what-is-the-purpose-of-the-memory-keyword
    //
    //  playing with and reading from Storage
    //  https://github.com/Cyfrin/foundry-fund-me-f23/blob/main/script/DeployStorageFun.s.sol
    //
    //  reading/writing from storage is VERY expensive, 33x more expensive than reading/writing from memory
    uint256 public constant MINIMUM_USD = 5 * 10 ** 18;
    address private immutable i_owner;
    address[] private s_funders;
    mapping(address => uint256) private s_addressToAmountFunded;
    AggregatorV3Interface private s_priceFeed; //s_ means its a state/storage variable
    // global/state vars are generally: in storage, constant, immutable

    // Events (we have none!)

    // Modifiers
    modifier onlyOwner() {
        // require(msg.sender == i_owner);
        if (msg.sender != i_owner) revert FundMe__NotOwner();
        _;
    }

    // Functions Order:
    //// constructor
    //// receive
    //// fallback
    //// external
    //// public
    //// internal
    //// private
    //// view / pure

    constructor(address priceFeed) {
        s_priceFeed = AggregatorV3Interface(priceFeed);
        i_owner = msg.sender;
    }

    /// @notice Funds our contract based on the ETH/USD price
    function fund() public payable {
        require(
            msg.value.getConversionRate(s_priceFeed) >= MINIMUM_USD,
            "You need to spend more ETH!"
        );
        // require(PriceConverter.getConversionRate(msg.value) >= MINIMUM_USD, "You need to spend more ETH!");
        s_addressToAmountFunded[msg.sender] += msg.value;
        s_funders.push(msg.sender);
    }

    function cheaperWithdraw() public onlyOwner {
        address[] memory funders = s_funders;
        // mappings can't be in memory, sorry!
        uint256 fundersLength = funders.length; // assigning a new var to memory so we dont have to read from storage
        for (
            uint256 funderIndex = 0;
            funderIndex < fundersLength;
            funderIndex++
        ) {
            address funder = funders[funderIndex];
            s_addressToAmountFunded[funder] = 0;
        }
        s_funders = new address[](0);
        (bool success, ) = i_owner.call{value: address(this).balance}("");
        require(success);
    }

    function withdraw() public onlyOwner {
        for (
            uint256 funderIndex = 0;
            funderIndex < s_funders.length; // everytime we loop thru here, we are reading from Storage - VERY EXPENSIVE!
            //  s_ syntax is really useful so we dont forget which are the Storage variables!
            funderIndex++
        ) {
            address funder = s_funders[funderIndex];
            s_addressToAmountFunded[funder] = 0;
        }
        s_funders = new address[](0);
        // Transfer vs call vs Send
        // payable(msg.sender).transfer(address(this).balance);
        (bool success, ) = i_owner.call{value: address(this).balance}("");
        require(success);
    }

    /** Getter Functions */
    //  private vars are more gas efficient
    //  good in general for managing access
    //  make vars private, and make them readable as needed
    /**
     * @notice Gets the amount that an address has funded
     *  @param fundingAddress the address of the funder
     *  @return the amount funded
     */
    function getAddressToAmountFunded(
        address fundingAddress
    ) public view returns (uint256) {
        return s_addressToAmountFunded[fundingAddress];
    }

    function getVersion() public view returns (uint256) {
        return s_priceFeed.version();
    }

    function getFunder(uint256 index) public view returns (address) {
        return s_funders[index];
    }

    function getOwner() public view returns (address) {
        return i_owner;
    }

    function getPriceFeed() public view returns (AggregatorV3Interface) {
        return s_priceFeed;
    }
}
