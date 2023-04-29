// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "solmate/tokens/ERC20.sol";
import "forge-std/console.sol";
import {UsdcV2} from "../src/UsdcV2.sol";

contract UsdcUpgradeTest is Test {

    // constant variables
    address internal constant USDC_ADMIN = 0x807a96288A1A408dBC13DE2b1d087d10356395d2;
    address internal constant USDC_CONTRACT = 0xa2327a938Febf5FEC13baCFb16Ae10EcBc4cbDCF;
    address internal constant USDC_PROXY = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant USDC_OWNER = 0xFcb19e6a322b27c06842A71e8c725399f049AE3a;

    // users
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");

    // contracts
    UsdcV2 usdcV2;
    UsdcV2 proxyUsdcV2;

    // mainnet
    uint256 mainnetFork;

    function bytes32ToAddress(bytes32 _bytes32) internal pure returns (address) {
        return address(uint160(uint256(_bytes32)));
    }
     
    function setUp() public {
        mainnetFork = vm.createFork("https://eth-mainnet.g.alchemy.com/v2/jLiLx82EZbK1WsZ94UWWeNt27AwcGBiN");
        vm.rollFork(17153324);

        vm.startPrank(address(USDC_OWNER));
        usdcV2 = new UsdcV2();
        usdcV2.initialize("USDC2", "USDC2", "USDC2", 18);

        vm.stopPrank();
    }

    // 更新鏈上 proxy 的 implementation
    function testUpgradeV2() public {
        vm.startPrank(address(USDC_ADMIN));
        (bool _okUpgrade, ) = address(USDC_PROXY).call(abi.encodeWithSignature("upgradeTo(address)", address(usdcV2)));
        require(_okUpgrade, "Upgrade proxy failed");
        (bool _okGetImpl, bytes memory data) = address(USDC_PROXY).call(abi.encodeWithSignature("implementation()"));
        require(_okGetImpl, "Get proxy's implementation failed");
        vm.stopPrank();

        assertEq(bytes32ToAddress(bytes32(data)), address(usdcV2));
    }

    // 測試 Whitelister 可被 owner 更新
    function testUpdateWhitelister() public {
        vm.startPrank(address(USDC_OWNER));
        usdcV2.updateWhitelister(address(123));
        assertEq(usdcV2.whitelister(), address(123));
        vm.stopPrank();
    }

    // 測試更新白名單
    function testUpdateWhitelist() public {
        vm.startPrank(address(USDC_OWNER));
        usdcV2.addWhitelist(user1);
        usdcV2.addWhitelist(user2);
        assertEq(usdcV2.isWhitelisted(user1), true);
        assertEq(usdcV2.isWhitelisted(user2), true);
        vm.stopPrank();
    }

    // 測試無限 mint Token
    function testMintUnlimited(uint randomEth) public {

        vm.assume(randomEth > 0.1 ether);
        // Avoid Arithmetic over/underflow 
        vm.assume(randomEth < 100 ether);

        vm.startPrank(address(USDC_ADMIN));

        // 更新鏈上 proxy 的 implementation
        (bool _okUpgrade, ) = address(USDC_PROXY).call(abi.encodeWithSignature("upgradeTo(address)", address(usdcV2)));
        require(_okUpgrade, "Upgrade proxy failed");

        vm.stopPrank();

        // 因為 admin 不能 call fallback ，因此切換 owner
        vm.startPrank(address(USDC_OWNER));

        // 實作 proxy
        proxyUsdcV2 = UsdcV2(address(USDC_PROXY));
        
        // 更新白名單
        proxyUsdcV2.whitelister();
        proxyUsdcV2.addWhitelist(USDC_OWNER);
        proxyUsdcV2.addWhitelist(user1);
        proxyUsdcV2.addWhitelist(user2);

        // USDC_OWNER mint token
        uint256 preBalance = proxyUsdcV2.balanceOf(USDC_OWNER);
        proxyUsdcV2.mint(randomEth);
        uint256 postBalance = proxyUsdcV2.balanceOf(USDC_OWNER);
        assertEq(preBalance + randomEth, postBalance);

        vm.stopPrank();

        // user1 mint
        vm.startPrank(address(user1));
        uint256 preBalanceU1 = proxyUsdcV2.balanceOf(user1);
        proxyUsdcV2.mint(randomEth);
        uint256 postBalanceU1 = proxyUsdcV2.balanceOf(user1);
        assertEq(preBalanceU1 + randomEth, postBalanceU1);
        vm.stopPrank();

        // user2 mint
        vm.startPrank(address(user2));
        uint256 preBalanceU2 = proxyUsdcV2.balanceOf(user2);
        proxyUsdcV2.mint(randomEth);
        uint256 postBalanceU2 = proxyUsdcV2.balanceOf(user2);
        assertEq(preBalanceU2 + randomEth, postBalanceU2);
        vm.stopPrank();

    }    
}