# Utf indexes on evm chain
## Contracts
- utfCore.sol - performs a core logic and the part that owns all the liquidity
- utfRouter.sol - router sc for user to mint and burn utf
- utfManager.sol - manager contract for dao to execute different actions over the utf collateral

## Scheme
![scheme image alt](./scheme.png "this is how all components work overall")

## Core

This contract has several usecases
 - Mint index
 - Burn index
 - Flash loan single token
 - Flash loan multiple tokens
 - Admin management
 - Admin flash loan scoped with rebalance
 Basically it is a ERC20 inherited contract with some extra methods and
 overriden public mint and burn. The token itself works as a share of each
 user that can decrease via minting some new tokens but the token in index
 value under this share will be constant and can possibly grow, see
 explanation via mint and burn mecanic description.

 In general, there shall be kind of a struct
 ```Solidity
 struct Token {
     IERC20 token;
     uint rememberedBalance;
     uint share;
 }
 ``` 
 to keep all the data, and an array Token[] token.
 Also there shall be availiable lots of admint functions on the sc.

### Mint
 Minting works through simple formula taken from compounded staking
 ```
 share / totalShares * totalBalance = depositAmount =>
 => share = depositAmount * totalShares / totalBalance
 ```
 due to this formula we can calculate an amount of token to transfer from
 user
```Solidity
function mint(uint _askedShare, address _to) external {
    require(_amount > 0, "Compound: Nothing to deposit");
    // check if amount > 0
    for(uint i = 0; i < inexTokenList.length;i++) {
        uint income = token[i].balanceOf(address(this)) - token[i].rememberedBalance;
        require(_askedShare >= income * totalSupply() / token[i].rememberedBalance),"");
        token[i].rememberedBalance = token[i].balanceOf(address(this));
    }
    _mint(_askedShare,_to);

}
```
Or this can be done by transferring tokens from user by calculating amounts
directly, there shall still be router in case user has only few tokens to
buy utf from
```Solidity

function mint(uint _askedShare, address _to) external {
    uint[] memory requiredTokenAmounts;

    uint minShare = uint.max();
    bool IsZero = false;
    for(uint i = 0; i < inexTokenList.length;i++) {
        uint income = token[i].balanceOf(address(this)) - token[i].rememberedBalance;
        uint requiredIndexComponentAmount = (income * totalSupply() / token[i].balanceOf(address(this)));
        token[i].transferFrom(msg.sender,address(this),requiredIndexComponentAmount);
        token[i].rememberedBalance = token[i].balanceOf(address(this));
        if (token[i].balanceOf(address(this)) == 0 and IsZero) {
            require(false,"this can't happen");
        }
        if (token[i].balanceOf(address(this)) == 0) {
            IsZero = true;
        }
    }
    _mint(_askedShare,_to);
}
```
This arpiphmetic is based on this compounded staking minting code
```Solidity
function mint(uint _amount, address _to) external {
    updateRewardPool();
    require(_amount > 0, "Compound: Nothing to deposit");
    require(token.transferFrom(msg.sender,address(this),_amount),"");
    uint256 currentShares = 0;
    if (totalShares != 0) {
        currentShares = _amount * totalShares / requiredBalance;
    } else {
        currentShares = _amount;
    }
    totalShares += currentShares;
    requiredBalance += _amount;
    UserInfo storage user = userInfo[_to];
    user.share += currentShares;
    user.tokenAtLastUserAction = balanceOf(_to);
    emit Transfer(address(0), _to, _amount);
}
```
These functions calc the minimal share that can be gained from each of
tokens and then mints it, so hope there is no vulnerabilities, we can
potentially also check each token share matches if there can be a bug. This
goes on demand of develop process audit and optimisiation, but anyway, I
suppose these algorithms make no harm. Somehow we event don't need to keep
shares, and they will be consistent while anyone uses utf, or they just
increase utf collateral by transferring there amounts wothout invoking
methods, this can be prevented by not letting remembered balance to increase
more than required for user's new share.
### Burn
Burn is a simple function to burn the given share and release the
appropriate amount of index inner tokens, based on this compounded staking
mecanism
```Solidity
function burn(address _to, uint256 _share) public {
    updateRewardPool();
    require(_share > 0, "Compound: Nothing to burn");

    UserInfo storage user = userInfo[msg.sender];
    require(_share <= user.share, "Compound: Withdraw amount exceeds balance");
    uint256 currentAmount = requiredBalance * _share / totalShares;
    user.share -= _share;
    totalShares -= _share;
    requiredBalance -= currentAmount;
    user.tokenAtLastUserAction = balanceOf(msg.sender);
    require(token.transfer(_to,currentAmount),"Compound: Not enough token to transfer");
    emit Transfer(_to, address(0), currentAmount);
}
```
Should be something like
```Solidity
function burn(address _to, uint256 _share) public {
    require(_share > 0, "Compound: Nothing to burn");
    for (uint i = 0; i < tokens.length; i++) {
        tokens[i].transfer(_share*tokens[i].rememberedBalance/totalSupply(),_to);
    }
    _burn(msg.sender,_share);
}
```
### Admin flash loan
Admin flash loan is done through a managerFlashLoan function, used to
rebelence the collateral repcentage through swap cascade.
```Solidity
function managerFlashLoan(tokens[] _newTokens, uint[] minimalOutputBalances,address callback, bytes calldata data) public;
```
This function will apply new token array with addresses and persentage share
and then will call function on the callback address with the signature below
```Solidity
function managerFlashLoan(tokens[] _newTokens, tokens[] _oldTokens, uint[] minimalOutputBalances, bytes calldata data) public;
```
bytes of data here is an abstract data is some will be required. This
function call transfers all old token balances on callback sc and then
asserts minimal balances after it's execution
### Flash loan with single and multiple tokens for user
These functions allow user to take liquidity from sc and return it back +
fee in the same block.
```Solidity
function managerFlashLoan(address[] borrowTokens, address callback, bytes calldata data) public;
```
to ask for a single you shall pass one address to the array. Works similar to aave so does the admin function

## Router
Router mecanism works as a statelass thing for making a bunch of swaps,
basically it shall have some
```Solidity
function mint(address[][] paths, uint[] initialAmounts, uint[] minOutputAmounts, addres _to) public;
```
This function shall take some initial tokens from user and their initial
amounts, then it shall check the min output amounts as a slippage rate and
make a bunch of swaps, after it shall invoke the mint on the core sc and
transfer tokens there.
## Manager
This sc shall be used by governance as a  admin flash loan mecanism to
rebalance all stuff, initially something like
```Solidity
function managerFlashLoan(tokens[] _newTokens, tokens[] _oldTokens, uint[] minimalOutputBalances, bytes calldata data) public;
```
where calldata should consist of address[][] swapPaths thar are used to make
a bunch of swaps and transfer back new tokens to the core contract


