# deployment
make deploy-avs
# eigenlayer related
make register-operators-with-eigenlayer
make staker-mint-tokens-and-deposit-into-strategies
make staker-delegate-to-operators
# avs related
make register-operators-bn254-keys-with-avs-pubkey-compendium
make opt-operators-into-slashing-by-avs
make register-operators-with-avs
make staker-queue-withdrawal
make staker-notify-service-about-withdrawal
# no freaking clue why this helps but without this
# anvil was getting in some weird infinite loop bug
sleep 1
make advanceChainBy100Blocks
make staker-complete-queued-withdrawal
# make freeze-operators
# print operator status
make print-operators-status