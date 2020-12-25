pragma solidity ^0.6.7;

import "ds-test/test.sol";

import "./DssCron.sol";

interface Hevm {
    function warp(uint256) external;
}

contract TestVat {

    mapping (address => uint256) public dai;
    mapping (address => uint256) public sin;

    function suck(address u, address v, uint256 rad) public {
        sin[u] = sin[u] + rad;
        dai[v] = dai[v] + rad;
    }

}

contract TestVow {

    TestVat public vat;

    constructor(address vat_) public {
        vat = TestVat(vat_);
    }

    // Total deficit
    function Awe() public view returns (uint256) {
        return vat.sin(address(this));
    }

}

contract TargetSystem {

    function funcNoArgs() external {

    }

    function funcOneArg(uint256 arg1) external {
        
    }

    function funcTwoArgs(uint256 arg1, uint256 arg2) external {
        
    }

    function funcTwoArgsUnaligned(uint8 arg1, uint256 arg2) external {
        
    }

    function funcFailure() external {
        require(false);
    }

}

contract DssCronTest is DSTest {

    Hevm hevm;

    address me;

    TestVat vat;
    TestVow vow;

    DssCron cron;
    TargetSystem target;

    // CHEAT_CODE = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D
    bytes20 constant CHEAT_CODE =
        bytes20(uint160(uint256(keccak256('hevm cheat code'))));

    function rad(uint256 wad) internal pure returns (uint256) {
        return wad * 10 ** 27;
    }

    function setUp() public {
        hevm = Hevm(address(CHEAT_CODE));

        me = address(this);

        vat = new TestVat();
        vow = new TestVow(address(vat));

        cron = new DssCron(address(vat), address(vow));

        target = new TargetSystem();
    }

    function test_register_no_args() public {
        cron.register(address(target), target.funcNoArgs.selector, "", "", rad(1 ether));
        bytes memory result = "";
        (uint256 rate,) = cron.bounties(keccak256(abi.encode(address(target), target.funcNoArgs.selector, result)));
        assertEq(rate, rad(1 ether));
    }

    function test_register_one_variable_arg() public {
        bytes memory mask = abi.encode(0);
        bytes memory args = abi.encode(123);
        cron.register(address(target), target.funcOneArg.selector, mask, args, rad(1 ether));
        bytes memory result = abi.encode(0);
        (uint256 rate,) = cron.bounties(keccak256(abi.encode(address(target), target.funcOneArg.selector, result)));
        assertEq(rate, rad(1 ether));
    }

    function test_register_one_fixed_arg() public {
        bytes memory mask = abi.encode(uint256(-1));
        bytes memory args = abi.encode(123);
        cron.register(address(target), target.funcOneArg.selector, mask, args, rad(1 ether));
        bytes memory result = abi.encode(123);
        (uint256 rate,) = cron.bounties(keccak256(abi.encode(address(target), target.funcOneArg.selector, result)));
        assertEq(rate, rad(1 ether));
    }

    function test_claim_one_fixed_arg() public {
        bytes memory mask = abi.encode(uint256(-1));
        bytes memory args = abi.encode(123);
        cron.register(address(target), target.funcOneArg.selector, mask, args, rad(1 ether));

        hevm.warp(now + 1);
        
        cron.claim(me, address(target), target.funcOneArg.selector, mask, args);

        assertEq(vat.dai(me), rad(1 ether));
    }

    function test_claim_one_fixed_arg_wrong_arg() public {
        bytes memory mask = abi.encode(uint256(-1));
        bytes memory args = abi.encode(123);
        cron.register(address(target), target.funcOneArg.selector, mask, args, rad(1 ether));

        hevm.warp(now + 1);
        
        bytes memory claimArgs = abi.encode(456);
        cron.claim(me, address(target), target.funcOneArg.selector, mask, claimArgs);

        assertEq(vat.dai(me), rad(0 ether));
    }

    function test_claim_one_variable_arg() public {
        bytes memory mask = abi.encode(0);
        bytes memory args = abi.encode(123);
        cron.register(address(target), target.funcOneArg.selector, mask, args, rad(1 ether));

        hevm.warp(now + 1);
        
        bytes memory claimArgs = abi.encode(456);
        cron.claim(me, address(target), target.funcOneArg.selector, mask, claimArgs);

        assertEq(vat.dai(me), rad(1 ether));
    }

    function test_claim_one_fixed_one_variable_arg() public {
        bytes memory mask = abi.encode(uint256(-1), 0);
        bytes memory args = abi.encode(123, 0);
        cron.register(address(target), target.funcTwoArgs.selector, mask, args, rad(1 ether));

        hevm.warp(now + 1);
        
        bytes memory claimArgs = abi.encode(123, 456);
        cron.claim(me, address(target), target.funcTwoArgs.selector, mask, claimArgs);

        assertEq(vat.dai(me), rad(1 ether));
    }

    function test_claim_two_unaligned_args() public {
        bytes memory mask = abi.encode(uint256(-1), 0);
        bytes memory args = abi.encode(123, 0);
        cron.register(address(target), target.funcTwoArgsUnaligned.selector, mask, args, rad(1 ether));

        hevm.warp(now + 1);
        
        bytes memory claimArgs = abi.encode(123, 456);
        cron.claim(me, address(target), target.funcTwoArgsUnaligned.selector, mask, claimArgs);

        assertEq(vat.dai(me), rad(1 ether));
    }

    // TODO
    // - test failure modes
    // - test argument values are correct
    // - test more types of arguments
    // - test partial masking 

}
