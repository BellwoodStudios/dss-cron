# dss-cron

Allow placing bounties that increase over time on maintenance functions that otherwise require altruistic keepers to maintain. The goal of this module is to incentivize a market for keepers to maintain the state of Maker. Dai is paid out of the surplus buffer to cover gas costs and enable profiting off of system maintenance.

Currently a few trusted individuals are maintaining the state of Maker. This involves things such as calling `jug.drip(ilk)` periodically as well as new functionality such as `dciam.exec(ilk)`. `dss-cron` solves this by producing a market for keepers to execute these actions competatively. Governance will be able to set bounties that increase over time which can be claimed by any keeper which successfully executes the desired action.

The choice to increase the bounties over time is so that gas price fluctations do not have to be taken into account in the code. As soon as it is profitable to execute the transaction, there will be someone there to do so.

## Supported functions

Function arguments are specified as either `variable` or `fixed` using a bitwise mask on the argument calldata. This will tell `dss-cron` to pay out on any input or a specific input which I will explain the use-cases below:

### No Argument Functions

This would be something like `lerp.tick()` or `spot.poke()` where no arguments are required.

### Variable Argument Functions

This is something where the bounty can be set on any arguments. This will be useful for things like `dciam.exec(ilk)` or `jug.drip(ilk)` where you do not care which ilk is executed.

TODO - have this pay out based on the argument supplied so that we don't end up with someone calling the same ilk over and over again.

### Fixed Argument Functions

This is something where the bounty can be set on specific arguments such as `dciam.exec("ETH-A")` because we want ETH-A to track the DC a lot tigher than the low DC ilks.

### Mixed Argument Functions

This will be useful for something like `cat.bite(specificIlk, anyUrn)` where you want to pay keepers to bite things that do not offer any profit in themselves. An example of this usage is to pay people to liquidate USDC-A into PSM-USDC-A using the `PsmFlipper`.

## Incentivization

Currently this module is set up for things that you want to call with some reasonable bounds on regularity, but it may be desirable to include other functions that should be called based on some other pre-condition. It's probably worthwhile to investigate including this use-case.
