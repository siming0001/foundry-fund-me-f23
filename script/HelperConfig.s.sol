//SPDX-License-Identifier: MIT

//1.当我们处于本地anvil链时，我们将部署模拟合约供我们与之交互
//2.我们将在不同的链上跟踪合约地址
//例如Sepolia的ETH与USD的价格兑换率合约具有不同的地址，或者主网的ETH与USD的合约具有不同的地址

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";

contract HelperConfig is Script {
    //如果我们在本地的anvil链上，我们将部署模拟合约
    //否则我们从实时网络中获取现有的地址
    NetworkConfig public activeNetworkConfig;

    uint8 public constant DECIMALS = 8; //ETH/USD有8位小数
    int256 public constant INITIAL_PRICE = 2000e8; //ETH/USD初始价格为2000
    struct NetworkConfig {
        address priceFeed; //ETH/USD Price Feed Address
    }

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else if (block.chainid == 1) {
            activeNetworkConfig = getMainnetEthConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        NetworkConfig memory sepoliaConfig = NetworkConfig({
            priceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306
        });
        return sepoliaConfig;
    }

    function getMainnetEthConfig() public pure returns (NetworkConfig memory) {
        NetworkConfig memory ethConfig = NetworkConfig({
            priceFeed: 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
        });
        return ethConfig;
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.priceFeed != address(0)) {
            //如果模拟合约已经部署，则直接返回，不用重新部署
            return activeNetworkConfig;
        }

        //1.部署模拟合约
        //2.返回模拟合约地址
        vm.startBroadcast();
        //MockV3Aggregator是一个模拟的数据聚合器的合约，常用于测试环境，提供价格数据
        MockV3Aggregator mockpricefeed = new MockV3Aggregator(
            DECIMALS,
            INITIAL_PRICE
        ); //ETH/USD有8位小数，故价格起始于2000
        vm.stopBroadcast();

        NetworkConfig memory anvilConfig = NetworkConfig({
            priceFeed: address(mockpricefeed)
        });
        return anvilConfig;
    }
}
