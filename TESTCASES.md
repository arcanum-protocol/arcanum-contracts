# ETF TEST CASES

Try to input one positive token
Try to input one negative token

Try to input two negative token  
Try to input two positive token 

Try to input two negative token containing share 
Try to input two positive token containing share 

Try to input more amount in that you have

Try to overflow sleepage in
Try to overflow sleepage out

Try to swap with zero fees 
Try to swap with zero half deviation fee 
Try to swap with zero depeg base fee 
Try to overflow swap on getting close to deviation limit
Try to collect cashback with external adding it
Try to collect cashback with increasing it previously

Try to increase deviation more than limit |---*--*->-|
Try to decrease deviation less than limit |-<-*--*---|

Try to decrease deviation getting closer to limit  |---*--*-<-|
Try to increase deviation getting closer to limit  |->-*--*---|

Try to set invalid params to share price force push
Try to set invalid ttl to share price force push
Try to update price fetching type
Try to pause / unpause

Try to swap with target share 0 and share out
Try to swap with target share 0 and share in
Try to swap with target share 0 and share in and out equal
Try to swap with target share 0 and share in and out not equal

Try to swap with same assets on input and output and same quantities 
Try to swap with asset that doesn't exist in pool
Try to swap with asset that has 0 quantity as input
Try to swap with asset that has 0 quantity as output

Try to swap with fees exceedment 
Try to swap with equal minting and burning

Try to withdraw fees
Try to change curve params on flowo

Try to swap with shareCap getting very big
Try to swap with asset price getting very big
Try to swap with shareCap getting very low
Try to swap with asset price getting very low

Try to swap all shares till zero and then mint new share
Try to update target shares to place where deviation exceeds limit

Try to send too much tokens and receive back dust
Try to send too much ether and receive dust

Try to send tokens contract itself and loop calls
Try to overflow input amounts

Try to supply amount that is zero
Try to overflow cummulativeAmount

Try to swap 100 tokens 

Try to compare view method fee and existing fee
Try to calculate estimate amounts in/out

Try to call ownable methods being not owner

Try to swap with zero total target shares
Try to swap with share cap getting smaller than numerator value

Try to swap with not having asset price
Try to swap with not having share price

