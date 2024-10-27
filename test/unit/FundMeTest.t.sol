//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../../src/FundMe.sol";
import {DeployFundMe} from "../../script/DeployFundMe.s.sol";

contract FundMeTest is Test {
    uint256 number = 1;
    FundMe fundMe;

    address USER = makeAddr("user");
    uint256 constant SEND_VALUE = 0.01 ether; //100000000000000000 wei
    uint256 constant STRATING_BALANCE = 10 ether;
    uint256 constant GAS_PRICE = 1;

    //先运行setUp()函数
    function setUp() external {
        // us -> FundMeTest -> FundMe
        //FundMe的owner是FundMeTest，而msg.sender是调用FundMeTest的人的地址
        // fundMe = new FundMe(priceFeed);
        DeployFundMe deployFundMe = new DeployFundMe();
        fundMe = deployFundMe.run();
        //us -> FundMeTest -> DeployFundMe -> FundMe ??
        vm.deal(USER, STRATING_BALANCE); //给伪造的用户USER10个ETH作为起始资金
    }

    function testMinimumDollarIsFive() public view {
        assertEq(fundMe.MINIMUM_USD(), 5e18);
    }

    function testOwnerIsMsgSender() public view {
        console.log(fundMe.getOwner());
        console.log(msg.sender);
        assertEq(fundMe.getOwner(), msg.sender);
    }

    //对系统之外的地址的处理
    //1.Unit
    //  - 测试代码的指定部分
    //2.Integration
    //  - 集成测试，测试多个组件之间的交互
    //3.Forked
    //  - 在一个模拟的真实环境中测试
    //4.Staging
    //  - 在非生产的真实环境中测试代码

    function testPriceFeedVersionIsAccurate() public view {
        uint256 version = fundMe.getVersion();
        assertEq(version, 4);
    }

    function testFundFailsWithoutEnoughETH() public {
        vm.expectRevert(); //断言下一次调用应该会失败，继而发生回滚 assert(This tx fails/reverts)
        // uint256 cat = 1; //该测试会失败，因为该行不会回滚
        fundMe.fund(); //发送0ETH，但只需要5ETH
    }

    function testFundUpdatesFundedDataStructure() public {
        vm.prank(USER); //下一笔交易将由USER发送
        fundMe.fund{value: SEND_VALUE}(); //发送10ETH
        uint256 amountFunded = fundMe.getAddressToAmountFunded(USER);
        assertEq(amountFunded, SEND_VALUE);
    }

    //每次单独对一个函数进行测试时，首先会运行setUp()函数
    function testAddsFunderToArrayOfFunders() public {
        vm.prank(USER); //下一笔交易将由USER发送
        fundMe.fund{value: SEND_VALUE}(); //发送10ETH

        address funder = fundMe.getFunder(0);
        assertEq(funder, USER);
    }

    modifier funded() {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        _;
    }

    function testOnlyOwnerCanWithdraw() public funded {
        vm.expectRevert(); //断言下一次调用应该会失败（会忽略跳过vm），继而发生回滚
        vm.prank(USER);
        fundMe.withdraw(); //非owner尝试提现

        /*同样的，下面的代码USER也会跳过vm，而是已USER的身份执行withdraw()函数
        vm.prank(USER);
        vm.expectRevert(); //断言下一次调用应该会失败（会忽略跳过vm），继而发生回滚
        fundMe.withdraw(); //非owner尝试提现
        */
    }

    function testWithdrawWithASingleFunder() public funded {
        //Arrange 安排测试，设置测试环境
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance; //表示fundMe合约的当前余额，funder往fundMe合约转账后，fundMe合约的余额会增加

        //Act 执行想要测试的操作
        uint256 gasStart = gasleft(); //gasleft()函数返回当前剩余的gas数量 1000gas
        vm.txGasPrice(GAS_PRICE);
        vm.prank(fundMe.getOwner()); //cost:200gas
        fundMe.withdraw();

        uint256 gasEnd = gasleft(); //800gas
        uint256 gasUsed = (gasStart - gasEnd) * tx.gasprice; //tx.gasprice表示当前的gas价格，单位是wei
        console.log(gasUsed);

        //Assert 断言测试结果
        uint256 endingOwnerBalance = fundMe.getOwner().balance;
        uint256 endingFundMeBalance = address(fundMe).balance;
        assertEq(endingFundMeBalance, 0);
        assertEq(
            endingOwnerBalance,
            startingOwnerBalance + startingFundMeBalance
        );
    }

    function testWithdrawFromMultipleFunders() public funded {
        //Arrange
        uint160 numberOfFunders = 10; //address类型是160位，所以想要用数字生成地址也需要使用uint160类型
        uint160 startingFunderIndex = 1; //之所以不从零开始，是因为有时零地址会触发回滚并且导致无法进行操作
        //编写测试时，要确保不想零地址发送交易
        for (uint160 i = startingFunderIndex; i < numberOfFunders; i++) {
            hoax(address(i), SEND_VALUE); //伪造一个假的用户，并向其转账，hoax集成了prank和deal，可以同时设置多个账户
            fundMe.fund{value: SEND_VALUE}();
        }
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        //Act
        vm.startPrank(fundMe.getOwner()); //中间的所有操作都假装由owner地址执行，并且发送
        fundMe.withdraw();
        vm.stopPrank();

        //Assert
        assert(address(fundMe).balance == 0);
        assert(
            startingFundMeBalance + startingOwnerBalance ==
                fundMe.getOwner().balance
        );
    }

    function testWithdrawFromMultipleFundersCheaper() public funded {
        //Arrange
        uint160 numberOfFunders = 10; //address类型是160位，所以想要用数字生成地址也需要使用uint160类型
        uint160 startingFunderIndex = 1; //之所以不从零开始，是因为有时零地址会触发回滚并且导致无法进行操作
        //编写测试时，要确保不想零地址发送交易
        for (uint160 i = startingFunderIndex; i < numberOfFunders; i++) {
            hoax(address(i), SEND_VALUE); //伪造一个假的用户，并向其转账，hoax集成了prank和deal，可以同时设置多个账户
            fundMe.fund{value: SEND_VALUE}();
        }
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        //Act
        vm.startPrank(fundMe.getOwner()); //中间的所有操作都假装由owner地址执行，并且发送
        fundMe.cheaperWithdraw();
        vm.stopPrank();

        //Assert
        assert(address(fundMe).balance == 0);
        assert(
            startingFundMeBalance + startingOwnerBalance ==
                fundMe.getOwner().balance
        );
    }
}
