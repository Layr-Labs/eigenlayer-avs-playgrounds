# deployment
make deploy-avs
# eigenlayer related
make register-operators-with-eigenlayer
make setup-stakers-and-delegate-to-operator
# avs related
make register-operators-bn254-keys-with-avs-pubkey-compendium
make opt-operators-into-slashing-by-avs
make register-operators-with-avs
make freeze-operators
# print operator status
make print-operators-status