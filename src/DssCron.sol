pragma solidity ^0.6.7;

import { VatAbstract } from "dss-interfaces/dss/VatAbstract.sol";

// Allow placing bounties that increase over time on maintenance functions
// that otherwise require altruistic keepers to maintain

contract DssCron {

    // --- Auth ---
    mapping (address => uint256) public wards;
    function rely(address usr) external auth { wards[usr] = 1; emit Rely(usr); }
    function deny(address usr) external auth { wards[usr] = 0; emit Deny(usr); }
    modifier auth { require(wards[msg.sender] == 1); _; }

    VatAbstract immutable public vat;

    // --- Events ---
    event Rely(address indexed usr);
    event Deny(address indexed usr);

    constructor(address vat_) public {
        wards[msg.sender] = 1;
        emit Rely(msg.sender);
        vat = VatAbstract(vat_);
    }

}
