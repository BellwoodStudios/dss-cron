pragma solidity ^0.6.7;

import "ds-test/test.sol";

import "./DssCron.sol";

contract DssCronTest is DSTest {
    DssCron cron;

    function setUp() public {
        cron = new DssCron();
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
