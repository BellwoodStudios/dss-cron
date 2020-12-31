pragma solidity ^0.6.7;

import { VatAbstract } from "dss-interfaces/dss/VatAbstract.sol";

// Allow placing bounties that increase over time on maintenance functions
// that otherwise require altruistic keepers to maintain

contract DssCron {

    struct Bounty {
        uint256 rate;   // The rate the bounty increases    [rads / sec]
        uint256 rho;    // The timestamp of the last claim  [sec]
    }

    // --- Auth ---
    mapping (address => uint256) public wards;
    function rely(address usr) external auth { wards[usr] = 1; emit Rely(usr); }
    function deny(address usr) external auth { wards[usr] = 0; emit Deny(usr); }
    modifier auth { require(wards[msg.sender] == 1); _; }

    VatAbstract immutable public vat;
    address immutable public vow;
    mapping (bytes32 => Bounty) public bounties;
    uint256 private locked;

    modifier lock {
        require(locked == 0, "DssCron/reentrancy-guard");
        locked = 1;
        _;
        locked = 0;
    }

    // --- Events ---
    event Rely(address indexed usr);
    event Deny(address indexed usr);
    event Register(address target, bytes data, uint256 mask, uint256 rate);
    event Unregister(address target, bytes data, uint256 mask);
    event Claim(address target, bytes data, uint256 mask, uint256 reward);

    // --- Init ---
    constructor(address vat_, address vow_) public {
        wards[msg.sender] = 1;
        emit Rely(msg.sender);
        vat = VatAbstract(vat_);
        vow = vow_;
    }

    // --- Math ---
    function sub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x - y) <= x);
    }
    function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(y == 0 || (z = x * y) / y == x);
    }

    // Generates a key from a target contract, function selector and optional fixed args
    // The mask is used to specify which arguments can be variable
    // 1 = Fixed, 0 = Variable
    function generateKey(address target, bytes memory data, uint256 mask) internal pure returns (bytes32) {
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
        return keccak256(abi.encode(target, result, mask));
    }

    // Register a bounty for a particular function, on a particular contract
    // The mask is used to specify concrete vs variable arguments
    // A mask bit N of 1 means the supplied argument is a concrete value at argument N
    // A mask of 0 means the supplied argument is ignored for payout (any valid transaction works)
    // For example, you can incentivize cat.bite("USDC-A", anyUrnAddress)
    function register(address target, bytes calldata data, uint256 mask, uint256 rate) external auth {
        bytes32 key = generateKey(target, data, mask);
        if (rate > 0) {
            bounties[key] = Bounty({
                rate: rate,
                rho: block.timestamp
            });

            emit Register(target, data, mask, rate);
        } else {
            delete bounties[key];

            emit Unregister(target, data, mask);
        }
    }

    // Execute a function and claim a bounty
    function claim(address usr, address target, bytes calldata data, uint256 mask) external lock {
        bytes32 key = generateKey(target, data, mask);
        (bool success,) = target.call(data);
        if (success) {
            // You've earned the reward (might be 0)
            uint256 reward = mul(sub(block.timestamp, bounties[key].rho), bounties[key].rate);
            vat.suck(vow, usr, reward);
            bounties[key].rho = block.timestamp;

            emit Claim(target, data, mask, reward);
        } else {
            revert("DssCron/call-revert");
        }
    }

}
