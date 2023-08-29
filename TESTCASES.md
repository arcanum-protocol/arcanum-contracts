# ETF TEST CASES

Here are 9 potential test cases for the Multipool ETF contract:

1) Test minting new shares - call mint() and verify share balance increases and asset quantity decreases.

2) Test burning shares - call burn() and verify share balance decreases and asset quantity increases. 

3) Test swapping assets - call swap() and verify fee curve, input asset quantity decreases and output asset quantity increases.

4) Test setting asset prices - call updatePrice() as owner and verify asset prices update. 

5) Test setting asset percentages - call updateTargetShare() as owner and verify asset percentages update.

6) Test collecting cashbacks - mint/burn/swap assets and verify cashback balances increase, then withdraw cashback throught swap and verify transfer.

7) Test deviation limits - try to mint/burn amounts that would exceed deviation limit and verify that fee will be around 100%.

8) Test fee ratios - update fee ratios and verify fees collected change as expected. 

9) Test edge cases - call functions with zero shares, prices, assets etc and verify expected behavior.
    
    9.1) Mint zero amount of shares, using existing token.
    
    9.2) Burn zero amount of shares, using existing token.
    
    9.3) Swap zero amount of share, using existing token.
    
    9.4) Make everything above with 0% target share, and 0% actual share, and 0$ price.

10) Test adding tokens - add token to existing ETF then, mint/burn/swap, with it

11) Test fees edge cases - set base fee to 0% then, mint/burn/swap.

12) Test deviation fee curve - randomly change deviation fee curve parametres.

    12.1) Test deviation changes - mint/burn token with +/- deviation, within deviation curve.

    ```
        for each scenario check refund works ok:

        swap, change fee and curve, and deviation fee distribution than swap again 
        mint, change all mint again
        burn change all than burn again

        check zero deviation fee distribution works 
        check non zero deviation fee distribution works

        check all update events suit
        check all operation events suit

        swap same tokens
        swap existing and non existing tokens
    ```



13) Test base deviation fee shares - change params 

14) Test removing tokens - set target share 0%, mint should not work, burn should work, swap should work as token out.

15) 
