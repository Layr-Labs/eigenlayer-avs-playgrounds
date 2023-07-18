#!/bin/bash

# deployment
make deploy-avs

# delete the json file for queueud withdrawals
echo -n "" >script/output/5/modified_queue_withdrawal_output.json

# eigenlayer related
make register-operators-with-eigenlayer
make staker-mint-deposit-delegate-to-operators

# avs related
make register-operators-with-avs
# Note: operator needs to deregister from avs before running this script a second time
#       otherwise, the operator will stay registered and serving the previous avs,
#       which will prevent it from completing his withdrawal
#       This is because we only store one avs in script/output/5/playground_avs_deployment_output.json
#       our scripts only permit notifying (updating stakes in) the latest deployed avs
# make deregister-operators-with-avs

# print operator and staker status
make print-stakers-status
make print-operators-status
