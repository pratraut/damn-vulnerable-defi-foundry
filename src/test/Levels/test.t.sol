// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";
import {console} from "forge-std/console.sol";
import {Vm} from "forge-std/Vm.sol";
import {stdCheats} from "forge-std/stdlib.sol";

contract Demo {
    function test1() public {
        console.log("Sender =", msg.sender);
        test2();
    }

    function test2() private {
        console.log("Sender =", msg.sender);
    }
}

contract TestContract is DSTest, stdCheats {
    Vm internal immutable vm = Vm(HEVM_ADDRESS);
    address payable internal attacker;

    function setUp() public {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        attacker = payable(
            address(uint160(uint256(keccak256(abi.encodePacked("attacker")))))
        );
        vm.label(attacker, "Attacker");
        vm.deal(attacker, 100e18);
    }

    function toEth(uint256 val) public view returns (string memory result) {
        uint256 quotient = val / 10**18;
        uint256 remainder = val % 10**18;
        uint256 temp = quotient;
        uint256 digits;
        uint256 total_digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        total_digits += digits;
        bytes memory quotient_buffer;
        if (digits != 0) quotient_buffer = new bytes(digits);
        else {
            quotient_buffer = new bytes(1);
            quotient_buffer[0] = bytes1(uint8(48));
            total_digits++;
        }

        while (quotient != 0) {
            digits--;
            quotient_buffer[digits] = bytes1(
                uint8(48 + uint256(quotient % 10))
            );
            quotient /= 10;
        }
        temp = remainder;
        digits = 0;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        total_digits += digits;
        bytes memory remainder_buffer = new bytes(digits);
        if (digits != 0) remainder_buffer = new bytes(digits);
        else {
            remainder_buffer = new bytes(1);
            remainder_buffer[0] = bytes1(uint8(48));
            total_digits++;
        }
        while (remainder != 0) {
            digits--;
            remainder_buffer[digits] = bytes1(
                uint8(48 + uint256(remainder % 10))
            );
            remainder /= 10;
        }
        bytes memory buffer = new bytes(total_digits + 1);
        for (uint256 i; i < quotient_buffer.length; i++)
            buffer[i] = quotient_buffer[i];
        buffer[quotient_buffer.length] = bytes1(uint8(46));
        for (uint256 i; i < remainder_buffer.length; i++)
            buffer[i + quotient_buffer.length + 1] = remainder_buffer[i];
        return string(buffer);
    }

    function testExploit() public {
        console.log("Attacker balance =", attacker.balance);
        vm.prank(attacker);
        payable(0).transfer(10 ether);
        console.log("Attacker balance =", attacker.balance);
        console.log("Attacker balance in ETH =", toEth(attacker.balance));
        Demo d = new Demo();
        d.test1();
    }

    function testGame() public {
        uint8 val;
        uint256 nonce = 123;
        console.log("Sender = ", msg.sender);
        console.log("Block number = ", block.number);
        for (uint256 i; i < 10; i++) {
            val = uint8(
                uint256(
                    keccak256(abi.encodePacked(block.number, msg.sender, nonce))
                ) % 10
            );
            nonce++;
            console.log("For i =", i, "val =", val);
        }
    }
}
