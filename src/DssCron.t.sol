pragma solidity ^0.6.7;

import "ds-test/test.sol";
import {Vat} from "dss/vat.sol";
import {Vow} from "dss/vow.sol";

import "./DssCron.sol";

interface Hevm {
    function warp(uint256) external;
}

contract TestVow is Vow {
    constructor(address vat, address flapper, address flopper) public Vow(vat, flapper, flopper) {}
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

    Vat vat;
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

        vat = new Vat();
        vow = new TestVow(address(vat), address(0), address(0));

        cron = new DssCron(address(vat), address(vow));
        vat.rely(address(cron));

        target = new targetSystem();
    }

    function test_register_no_args() public {
        cron.register(address(target), target.funcNoArgs.selector, "", "", rad(1 ether));
    }

}
