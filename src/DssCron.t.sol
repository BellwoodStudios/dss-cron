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

    function funcCondFailure(uint256 condition) external {
        require(condition == 1 || condition == 5);
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

    // COPIED out of DssCron because this should remain internal
    // Also remove end hash to compare source bytes
    function generateKey(address target, bytes memory data, uint256 mask) internal pure returns (bytes memory) {
        // 4 byte func sig + 32 bytes / arg
        require(data.length % 32 == 4, "DssCron/data-bad-abi-encoding");
        uint256 nargs = (data.length - 4) / 32;
        bytes memory result = new bytes(data.length);

        // Store the function signature
        for (uint256 i = 0; i < 4; i++) {
            result[i] = data[i];
        }

        // Perform a bitwise AND on the mask and data at 32 byte width
        for (uint256 i = 0; i < nargs; i++) {
            assembly {
                mstore(
                    add(result, add(0x24, i)),
                    and(
                        mload(add(data, add(0x24, i))),
                        not(sub(and(0x01, shr(i, mask)), 1))
                    )
                )
            }
        }
        return abi.encode(target, result, mask);
    }

    function test_variable_key_hash() public {
        bytes memory data = abi.encodeWithSelector(target.funcOneArg.selector, 123);
        bytes memory expectedData = abi.encodeWithSelector(target.funcOneArg.selector, 0);
        assertEq(expectedData.length, 36);
        assertEq(expectedData[0], target.funcOneArg.selector[0]);
        assertEq(expectedData[1], target.funcOneArg.selector[1]);
        assertEq(expectedData[2], target.funcOneArg.selector[2]);
        assertEq(expectedData[3], target.funcOneArg.selector[3]);
        bytes memory expectedKey = abi.encode(address(target), expectedData, 0x00);
        bytes memory resultKey = generateKey(address(target), data, 0x00);
        assertEq0(resultKey, expectedKey);
    }

    function test_fixed_key_hash() public {
        bytes memory data = abi.encodeWithSelector(target.funcOneArg.selector, 123);
        bytes memory expectedData = abi.encodeWithSelector(target.funcOneArg.selector, 123);
        assertEq(expectedData.length, 36);
        assertEq(expectedData[0], target.funcOneArg.selector[0]);
        assertEq(expectedData[1], target.funcOneArg.selector[1]);
        assertEq(expectedData[2], target.funcOneArg.selector[2]);
        assertEq(expectedData[3], target.funcOneArg.selector[3]);
        assertEq(uint256(uint8(expectedData[35])), 123);
        bytes memory expectedKey = abi.encode(address(target), expectedData, 0x01);
        assertEq(uint256(uint8(expectedKey[163])), 123);
        bytes memory resultKey = generateKey(address(target), data, 0x01);
        assertEq0(expectedKey, resultKey);
    }

    function test_register_no_args() public {
        bytes memory data = abi.encodeWithSelector(target.funcNoArgs.selector);
        cron.register(address(target), data, 0x00, rad(1 ether));
        (uint256 rate,) = cron.bounties(keccak256(abi.encode(address(target), abi.encodeWithSelector(target.funcNoArgs.selector), 0x00)));
        assertEq(rate, rad(1 ether));
    }

    function test_register_one_variable_arg() public {
        bytes memory data = abi.encodeWithSelector(target.funcOneArg.selector, 123);
        cron.register(address(target), data, 0x00, rad(1 ether));      // Mask of 0 = variable
        (uint256 rate,) = cron.bounties(keccak256(abi.encode(address(target), abi.encodeWithSelector(target.funcOneArg.selector, 0), 0x00)));
        assertEq(rate, rad(1 ether));
    }

    function test_register_one_fixed_arg() public {
        bytes memory data = abi.encodeWithSelector(target.funcOneArg.selector, 123);
        cron.register(address(target), data, 0x01, rad(1 ether));      // Mask of 1 = first argument is fixed
        (uint256 rate,) = cron.bounties(keccak256(abi.encode(address(target), abi.encodeWithSelector(target.funcOneArg.selector, 123), 0x01)));
        assertEq(rate, rad(1 ether));
    }

    function test_claim_one_fixed_arg() public {
        bytes memory data = abi.encodeWithSelector(target.funcOneArg.selector, 123);
        cron.register(address(target), data, 0x01, rad(1 ether));

        hevm.warp(now + 1);
        
        cron.claim(me, address(target), data, 0x01);

        assertEq(vat.dai(me), rad(1 ether));
    }

    function test_claim_one_fixed_arg_wrong_arg() public {
        bytes memory data = abi.encodeWithSelector(target.funcOneArg.selector, 123);
        cron.register(address(target), data, 0x01, rad(1 ether));

        hevm.warp(now + 1);
        
        bytes memory claimData = abi.encodeWithSelector(target.funcOneArg.selector, 456);
        cron.claim(me, address(target), claimData, 0x01);

        assertEq(vat.dai(me), rad(0 ether));
    }

    function test_claim_one_variable_arg() public {
        bytes memory data = abi.encodeWithSelector(target.funcOneArg.selector, 123);
        cron.register(address(target), data, 0x00, rad(1 ether));

        hevm.warp(now + 1);
        
        bytes memory claimData = abi.encodeWithSelector(target.funcOneArg.selector, 456);
        cron.claim(me, address(target), claimData, 0x00);

        assertEq(vat.dai(me), rad(1 ether));
    }

    function test_claim_one_fixed_one_variable_arg() public {
        bytes memory data = abi.encodeWithSelector(target.funcTwoArgs.selector, 123, 0);
        cron.register(address(target), data, 0x01, rad(1 ether));

        hevm.warp(now + 1);
        
        bytes memory claimData = abi.encodeWithSelector(target.funcTwoArgs.selector, 123, 456);
        cron.claim(me, address(target), claimData, 0x01);

        assertEq(vat.dai(me), rad(1 ether));
    }

    function test_claim_two_unaligned_args() public {
        bytes memory data = abi.encodeWithSelector(target.funcTwoArgsUnaligned.selector, 123, 0);
        cron.register(address(target), data, 0x01, rad(1 ether));

        hevm.warp(now + 1);
        
        bytes memory claimData = abi.encodeWithSelector(target.funcTwoArgsUnaligned.selector, 123, 456);
        cron.claim(me, address(target), claimData, 0x01);

        assertEq(vat.dai(me), rad(1 ether));
    }

    function testFail_claim_revert_no_args() public {
        bytes memory data = abi.encodeWithSelector(target.funcFailure.selector);
        cron.register(address(target), data, 0x00, rad(1 ether));
        hevm.warp(now + 1);
        cron.claim(me, address(target), data, 0x00);
    }

    function test_claim_conditional_failure() public {
        bytes memory data = abi.encodeWithSelector(target.funcCondFailure.selector, 0);
        cron.register(address(target), data, 0x00, rad(1 ether));

        hevm.warp(now + 1);
        
        bytes memory claimData1 = abi.encodeWithSelector(target.funcCondFailure.selector, 1);
        cron.claim(me, address(target), claimData1, 0x00);

        assertEq(vat.dai(me), rad(1 ether));

        hevm.warp(now + 5);
        
        bytes memory claimData2 = abi.encodeWithSelector(target.funcCondFailure.selector, 5);
        cron.claim(me, address(target), claimData2, 0x00);

        assertEq(vat.dai(me), rad(6 ether));
    }

    // TODO
    // - test failure modes
    // - test argument values are correct
    // - test more types of arguments
    // - test partial masking 

}
