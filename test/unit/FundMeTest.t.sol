// SPDX-Licencse-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../../src/FundMe.sol";
import {DeployFundMe} from "../../script/DeployFundMe.s.sol";

contract FundMeTest is Test {
    FundMe fundMe;

    // makeAddr comes from forge-std
    address USER = makeAddr("user");
    uint256 constant SEND_VALUE = 0.1 ether;
    uint256 constant STARTING_BALANCE = 10 ether;
    uint256 constant GAS_PRICE = 1;

    // everytime we run even one specific test, it will run setup and then that test
    function setUp() external {
        DeployFundMe deployFundMe = new DeployFundMe();
        fundMe = deployFundMe.run();
        //  NOW:
        //  us -> FundMeTest -> deployFundMe -> vm.startBroadcast (us) -> FundMe
        //  WE USED TO:
        //  us -> FundMeTest -> FundMe
        //  we call FundMeTest, which then calls FundMe

        // cheatcode
        vm.deal(USER, STARTING_BALANCE);
    }

    function testMinimumDollarIsFive() public view {
        //console.log(fundMe.MINIMUM_USD());
        assertEq(fundMe.MINIMUM_USD(), 5e18);
    }

    function testOwnerIsMsgSender() public view {
        // console.log(fundMe.i_owner());
        // console.log(msg.sender); // msg.sender is whoever is calling the FundMeTest contract, which is us
        //  fundMe.i_owner is the guy who deploys fund me, which here is us, bcs of vm.startBroadcast
        assertEq(fundMe.getOwner(), msg.sender);
    }

    //  important that version is correct so price conversion is correct (???why?)
    function testPriceFeedVersionIsAccurate() public view {
        uint256 version = fundMe.getVersion();
        assertEq(version, 4);
    }

    function testFundFailsWithoutEnoughEth() public {
        // in foundry cheatcodes, assertions
        //  generally, foundry funcs are defined in vm, so
        vm.expectRevert(); // means that the next line should revert for the test to pass
        //  equiv to assert(this tx fails/reverts)
        fundMe.fund(); // send 0 eth, meaning tx will revert, and test will succeed
    }

    function testFundUpdatesFundedDataStructure() public {
        // env cheatcode
        vm.prank(USER); //the next TX will be sent by USER
        // does this work on testnet??????? or only on anvil? should work with fork-url

        // pretpostavljam jer je payable pa ide ova sintaksa:
        fundMe.fund{value: SEND_VALUE}(); // 10e18 = 10 ether
        // The curly braces {} before the function call are used to specify extra transaction options, e.g. the value field for sending Ether with payable funcs

        uint256 amountFunded = fundMe.getAddressToAmountFunded(USER); // can be confusing whether address(this) or msg.sender is sending a tx
        assertEq(amountFunded, SEND_VALUE);
    }

    function testAddsFunderToArrayOfFunders() public {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();

        address funder = fundMe.getFunder(0);
        assertEq(funder, USER);
    }

    modifier funded() {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        _;
    }

    function testOnlyOwnerCanWithdraw() public funded {
        vm.prank(USER); // applies to next tx which is not a vm cheat code
        vm.expectRevert();
        fundMe.withdraw();
    }

    function testWithdrawWithASingleFunder() public funded {
        // Test methodology
        // Arrange - setup correct starting state
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        // Act - action we are testing
        // uint256 gasStart = gasleft(); // gasleft is builtin to solidity, tells us how much gas we have left to spend within tx
        // vm.txGasPrice(GAS_PRICE); // sets gas price for next tx
        vm.prank(fundMe.getOwner());
        fundMe.withdraw();

        // uint256 gasEnd = gasleft(); // how much gas we have after the tx
        // assertEq(tx.gasprice, GAS_PRICE);
        // uint256 gasUsed = (gasStart - gasEnd) * tx.gasprice; //tx.gasprice built into solidity, gives us current gas price
        // console.log(gasUsed);

        // Assert - assert correct end state
        uint256 endingOwnerBalance = fundMe.getOwner().balance;
        uint256 endingFundMeBalance = address(fundMe).balance;
        assertEq(endingFundMeBalance, 0);
        assertEq(
            startingFundMeBalance + startingOwnerBalance,
            endingOwnerBalance
        ); // a gas costs?? zasto moze to ovako testirat?
    }

    //  what about gas costs?????????? - anvil gas price defaults to 0
    function testWithdrawFromMultipleFunders() public funded {
        //  Arrange
        uint160 numberOfFunders = 10; // if using num to generate address, it has to be uint160
        uint160 startingFunderIndex = 2;
        for (uint160 i = startingFunderIndex; i < numberOfFunders; i++) {
            //  hoax = vm.prank + vm.deal (generate acc with a balance)
            hoax(address(i), SEND_VALUE);
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        //  Act
        // vm.startPrank and vm.stopPrank - anything in between, will be pretended to be sent by defined address
        vm.startPrank(fundMe.getOwner());
        fundMe.withdraw();
        vm.stopPrank;

        //  Assert
        //  just assert bool, similar to assertEq
        assert(address(fundMe).balance == 0);
        assert(
            startingFundMeBalance + startingOwnerBalance ==
                fundMe.getOwner().balance
        );
    }

    function testCheaperWithdrawFromMultipleFunders() public funded {
        //  Arrange
        uint160 numberOfFunders = 10; // if using num to generate address, it has to be uint160
        uint160 startingFunderIndex = 2;
        for (uint160 i = startingFunderIndex; i < numberOfFunders; i++) {
            //  hoax = vm.prank + vm.deal (generate acc with a balance)
            hoax(address(i), SEND_VALUE);
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        //  Act
        // vm.startPrank and vm.stopPrank - anything in between, will be pretended to be sent by defined address
        vm.startPrank(fundMe.getOwner());
        fundMe.cheaperWithdraw();
        vm.stopPrank;

        //  Assert
        //  just assert bool, similar to assertEq
        assert(address(fundMe).balance == 0);
        assert(
            startingFundMeBalance + startingOwnerBalance ==
                fundMe.getOwner().balance
        );
    }
}

/*
test types
- unit 
    - testing a specific part of the code
- integration
    - testing how multiple parts of the code work together
- forked
    - testing in a simulated real environment 
- staging (important bcs sometimes prod env is completely different than testing env)
    - testing in a real env that is not prod
*/
