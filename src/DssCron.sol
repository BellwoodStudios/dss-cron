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
    // The mask is used to specify which parts of the argument can be variable
    // 1 = Fixed, 0 = Variable
    function generateKey(address target, bytes4 selector, bytes memory mask, bytes memory args) internal pure returns (bytes32) {
        require(mask.length == args.length, "DssCron/mask-args-length-not-matching");
        require(mask.length % 32 == 0, "DssCron/mask-bad-abi-encoding");
        uint256 len32 = mask.length / 32;
        bytes memory result = new bytes(mask.length);
        // Perform a bitwise AND on the mask and args at 32 byte width
        for (uint256 i = 0; i < len32; i++) {
            assembly {
                mstore(add(result, add(0x20, i)), add(and(mload(add(mask, add(0x20, i))), mload(add(args, add(0x20, i)))), add(0x20, i)))
            }
        }
        return keccak256(abi.encode(target, selector, mask, result));
    }

    // Register a bounty for a particular function, on a particular contract
    // The mask is used to specify concrete vs variable arguments
    // For example, you can incentivize cat.bite("USDC-A", anyUrnAddress)
    function register(address target, bytes4 selector, bytes calldata mask, bytes calldata args, uint256 rate) external auth {
        bytes32 key = generateKey(target, selector, mask, args);
        if (rate > 0) {
            bounties[key] = Bounty({
                rate: rate,
                rho: block.timestamp
            });
        } else {
            delete bounties[key];
        }
    }

    // Execute a function and claim a bounty
    function claim(address usr, address target, bytes4 selector, bytes calldata mask, bytes calldata args) external lock {
        bytes32 key = generateKey(target, selector, mask, args);
        (bool success,) = target.call(abi.encodeWithSelector(selector, args));
        if (success) {
            // You've earned the reward (might be 0)
            vat.suck(vow, usr, mul(sub(block.timestamp, bounties[key].rho), bounties[key].rate));
            bounties[key].rho = block.timestamp;
        }
    }

}
