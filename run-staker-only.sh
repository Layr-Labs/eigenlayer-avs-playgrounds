# staker related
make staker-mint-tokens-and-deposit-into-strategies
make staker-delegate-to-operators
make staker-queue-withdrawal
make staker-notify-service-about-withdrawal
sleep 1
make advanceChainBy100Blocks
make staker-complete-queued-withdrawal
