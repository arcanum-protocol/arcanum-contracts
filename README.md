# What this repository is about

This repository contains the source code for the [Multipool](https://arcanum.to/whitepaper.pdf) token [implemetation](https://github.com/provisorDAO/core-contracts/blob/master/contracts/etf/Multipool.sol). 

# How to read this repository

- [CONTRACTS](https://github.com/provisorDAO/core-contracts/tree/master/contracts) - contains the source code for the contracts, written in Solidity, that used in the provisor.
- [TEST](https://github.com/provisorDAO/core-contracts/tree/master/test) - contains the tests for the contracts, written in TypeScript.
- [DEPLOYMENTS](https://github.com/provisorDAO/core-contracts/tree/master/scripts) - contains the scripts for the contracts, written in TypeScript. That scripts are used for the deploy on testnet and mainnet.

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
