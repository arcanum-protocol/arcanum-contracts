# What this repository is about

This repository contains the source code for the [Multipool](https://arcanum.to/whitepaper.pdf) token [implemetation](https://github.com/provisorDAO/core-contracts/blob/master/contracts/etf/Multipool.sol). 

# How to read this repository

- [CONTRACTS](https://github.com/provisorDAO/core-contracts/tree/master/contracts) - contains the source code for the contracts, written in Solidity, that used in the provisor.
- [TEST](https://github.com/provisorDAO/core-contracts/tree/master/test) - contains the tests for the contracts, written in TypeScript.
- [DEPLOYMENTS](https://github.com/provisorDAO/core-contracts/tree/master/scripts) - contains the scripts for the contracts, written in TypeScript. That scripts are used for the deploy on testnet and mainnet.

# Error codes

<details>
    <summary> MULTIPOOL </summary> All messages are in format "MULTIPOOL: error_code"

| Error code | description | Reason |
| --- | --- | --- |
| DO | Deviation of asset overflows limit | Probably you are trying to perform an action that depegs pool too much | 
| QE | Burn quantity exceeded | Your action tries to take out more quantity than multipoll has | 
| ZS | Zero share | This error can appear if there is zero shares to mint by your action | 
| ZQ | Zero quantity | This error can appear if there is zero quantity but method requires it to be non zero | 
| CF | Curve calculation failed | This error is probably unreachable and means that there are no proper quantity on curve | 
| ZP | Zero price | Prive of the asset that is used by the action is unset | 
| ZT | Zero target share | Target share of the asset that is used by the action is unset or zero (reduced) | 
| IQ | Insufficient quantity | Operation requires more tokens to supply to contract | 
| SA | Same assets | Probably you are trying to swap token on itself | 
| PA | Price authority only | This operation requires you to have price setting permissions | 
| TA | Target share authority only | This operation requires you to have target share setting permissions | 
| WA | Withdraw authority only | This operation requires you to have withdrawal permissions | 
| TF | Token transfer failed | This error occures if transfer of ERC20 token returns false | 
| IA | Invalid authority | Occures if zero address is specified as an authority | 
| IP | Is paused | Occures if contract is stopped | 
| IA | Is audited | Occures if contract is marked as audited | 
| IL | Insufficient assets list | Occures if provided assets array is not full | 
</details>
<details>
    <summary> MULTIPOOL ROUTER </summary> All messages are in format "MULTIPOOL_ROUTER: error_code"

| Error code | description | Reason |
| --- | --- | --- |
| SE | Slippage exceeded | Transaction's quantity doesn't suit provided slippage | 
| DE | Deadline exceeded | Specified deadline exceeded | 
| NS | No shares | Etf doesn't have any shares minted, router can't work with this, you need to make price initialising manually through multipool | 
</details>
<details>
    <summary> MULTIPOOL MASSIVE MINT ROUTER </summary> All messages are in format "MULTIPOOL_MASS_ROUTER: error_code"

| Error code | description | Reason |
| --- | --- | --- |
| IA | Insufficcient address | Adress from the list of calls is not permitted to be called | 
| CF | Contract call failed | Contract call that was performed inside failed | 
| SE | Min share exceeded | Share sleepage exceeded | 
</details>

# How to contribute

## RULES
-----------------
### Commit messages
Commit naming rule are the same as for issues, but you need to add the number of the issue in the end of the commit message.

### Pattern
>`[AREA]:[WHAT_IN_THE_COMMIT] (#[NUMBER_OF_ISSUE])`

### Example
>`OPS: finalize deployers (#41)`

-----------------
### Branches
Branches naming rule are the same as for issues, but you need to add the number of the issue in the start of the branch name.

### Pattern
>`feat/[NUMBER_OF_ISSUE]_[AREA]_[DESCRIPTION_FROM_ISSUE]`

### Example
>`feat/41_MULTIPOOL_add_testnet_deploy_scripts`

-----------------

### Issues
Issues naming rule are the same as for commits.

### Pattern
>`[AREA]:[WHAT_TO_DO_OR_FIX]`

### Example
>`OPS: add testnet deploy scripts to all infrastructure`

____________________


## STEPS FOR CONTRIBUTION IN THE EXISTING CODE

<details>
    <summary> 1. UNDERSTAND AREA </summary> Understand in which part of the contracts there is a code that you want to change

| Area | Description |
| --- | --- |
| Multipool | The Multipool token core contract|
| MultipoolMath | The code part responsible for all multipool mathemathical computations |
| MultipoolRouter | Router contract that is used to get dafault interactions with core |
| OPS | The deployers, actions and tools |
| FOUNDRY | For foundry things like adding libraries |
    
</details>

<details>
    <summary> 2. CREATE ISSUE </summary> Create a new issue in the repository with the description of the problem and the solution.
    Then make new branch from the master branch with the name of the issue.
</details>

<details>
    <summary> 3. PULL REQUEST </summary> Make changes in the code and commit them.
    Then open a pull request to the master branch. After that, the pull request will be reviewed and <strong>rebased</strong>.
</details>

## STEPS FOR CONTRIBUTION IN THE NEW CODE

<details>
    <summary> 1. MAKE ISSUE AND BRANCH </summary> 
    <p>Create a new issue in the repository with the description of the problem and the solution.</p>
    <p>Then make new branch from the master branch with the name of the issue.</p>
</details>

<details>
    <summary> 2. ORGANAZE </summary> 
    <p>
        Make a new folder in the <strong>contracts</strong> folder with the name of the new part of provisior.
    </p>
    <p>
        Then make a new folder in the <strong>test</strong> folder with the name of the new code. With test cases for the new code.
    </p>
    <p>
        Then make a new folder in the <strong>deployments</strong> folder with the name of the new code. With deployers and verifiers.
    </p>
</details>

<details>
    <summary> 3. PULL REQUEST </summary>
    <p>Make changes in the code and commit them.</p>
    <p>Then open a pull request to the master branch. After that, the pull request will be reviewed and <strong>rebased</strong>.</p>
</details>
