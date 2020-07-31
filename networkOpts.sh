#!/bin/bash
. ./utils.sh

set -e

PROJECT_DIR=$PWD

HELM_DIR=$PWD/charts

ARGS_NUMBER="$#"
COMMAND="$1"

FABRIC_ROOT="${PWD}/fabric-samples"
FABRIC_CFG_PATH=${PWD}
PATH=${PWD}/fabric-samples/bin:$PATH

function generateCerts(){
    printSeparator "Generate certificates using cryptogen tool"
    cryptogen generate --config=./crypto-config.yaml
}

function generateChannelArtifacts(){

    if [ ! -d ./channel-artifacts ]; then
        mkdir channel-artifacts
    fi

    printSeparator "Generating channel configuration transaction 'channel.tx'"

    configtxgen -profile TwoOrgsOrdererGenesis -channelID testchainid -outputBlock ./channel-artifacts/genesis.block -configPath .
    configtxgen -profile TwoOrgsChannel -outputCreateChannelTx ./channel-artifacts/channel.tx -channelID "mychannel" -configPath .

    printSeparator "Generating anchor peer update for Org1MSP"
    configtxgen -profile TwoOrgsChannel -outputAnchorPeersUpdate ./channel-artifacts/org1Anchors.tx  -channelID "mychannel" -asOrg org1MSP -configPath .
    printSeparator "Generating anchor peer update for Org2MSP"
    configtxgen -profile TwoOrgsChannel -outputAnchorPeersUpdate ./channel-artifacts/org2Anchors.tx  -channelID "mychannel" -asOrg org2MSP -configPath .
}


function generateChannelTransaction() {
    printSeparator "Create Channel Transaction"
    
    ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/consortium/orderers/orderer0/msp/tlscacerts/tlsca.consortium-cert.pem

    kubectl exec -it $(kubectl get pod -l app=peer0-org1-cli -o jsonpath="{.items[0].metadata.name}") -- sh -c "peer channel create -o orderer0:7050 -c mychannel -f ./scripts/channel-artifacts/channel.tx --tls true --cafile $ORDERER_CA && peer channel join -b mychannel.block"

    sleep 2 

    kubectl exec -it $(kubectl get pod -l app=peer0-org2-cli -o jsonpath="{.items[0].metadata.name}" ) -- sh -c "peer channel fetch 0 mychannel.block -c mychannel -o orderer0:7050 --tls --cafile $ORDERER_CA && 
peer channel join -b mychannel.block && peer channel list"

    sleep 2 

}

function deployChainCode(){
    printSeparator "Install Chaincode"

    kubectl exec -it $(kubectl get pod -l app=peer0-org1-cli -o jsonpath="{.items[0].metadata.name}" ) --  sh -c " peer lifecycle chaincode package todo.tar.gz --path /opt/gopath/src/github.com/hyperledger/fabric/peer/chaincode/todo/source --lang node --label todo_1"

    sleep 2 

    kubectl exec -it $(kubectl get pod -l app=peer0-org2-cli -o jsonpath="{.items[0].metadata.name}" ) -- sh -c "peer lifecycle chaincode package todo.tar.gz --path /opt/gopath/src/github.com/hyperledger/fabric/peer/chaincode/todo/source --lang node --label todo_1"

    sleep 2 

    kubectl exec -it $(kubectl get pod -l app=peer0-org1-cli -o jsonpath="{.items[0].metadata.name}" ) --  sh -c " peer lifecycle chaincode install todo.tar.gz"

    sleep 2 

    kubectl exec -it $(kubectl get pod -l app=peer0-org2-cli -o jsonpath="{.items[0].metadata.name}" ) --  sh -c " peer lifecycle chaincode install todo.tar.gz"

    sleep 2 

    kubectl exec -it $(kubectl get pod -l app=peer0-org2-cli -o jsonpath="{.items[0].metadata.name}" ) -- peer lifecycle chaincode queryinstalled

    sleep 2 

    CC_PACKAGE_ID=todo_1:65c2158aa3804985ea87decdc5ea5ec28f3699a0cc0c9dcb7e40376b342c28e6

    kubectl exec -it $(kubectl get pod -l app=peer0-org1-cli -o jsonpath="{.items[0].metadata.name}" ) --  sh -c " peer lifecycle chaincode approveformyorg --channelID mychannel --name todo --version 1.0  --package-id $CC_PACKAGE_ID --sequence 1 -o orderer0:7050 --tls --cafile $ORDERER_CA --init-required "

    sleep 2 

    kubectl exec -it $(kubectl get pod -l app=peer0-org2-cli -o jsonpath="{.items[0].metadata.name}" ) --  sh -c " peer lifecycle chaincode approveformyorg --channelID mychannel --name todo --version 1.0  --package-id $CC_PACKAGE_ID --sequence 1 -o orderer0:7050 --tls --cafile $ORDERER_CA --init-required "

    sleep 2 

    kubectl exec -it $(kubectl get pod -l app=peer0-org1-cli -o jsonpath="{.items[0].metadata.name}" ) --  sh -c "peer lifecycle chaincode checkcommitreadiness --channelID mychannel --name todo --version 1.0 --sequence 1 -o -orderer0:7050 --tls --cafile $ORDERER_CA --init-required"

    sleep 2 

    kubectl exec -it $(kubectl get pod -l app=peer0-org1-cli -o jsonpath="{.items[0].metadata.name}" ) --  sh -c "peer lifecycle chaincode commit -o orderer0:7050 --channelID mychannel --name todo --version 1.0 --sequence 1 --tls --cafile $ORDERER_CA --peerAddresses peer0-org1:7051 --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1/peers/peer0-org1/tls/ca.crt --peerAddresses peer0-org2:7051 --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2/peers/peer0-org2/tls/ca.crt --init-required"

    sleep 2 


    kubectl exec -it $(kubectl get pod -l app=peer0-org1-cli -o jsonpath="{.items[0].metadata.name}" ) --  peer chaincode invoke -o orderer0:7050  --tls --cafile $ORDERER_CA  -C mychannel -n todo --peerAddresses peer0-org1:7051 --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1/peers/peer0-org1/tls/ca.crt --peerAddresses peer0-org2:7051 --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2/peers/peer0-org2/tls/ca.crt --isInit -c '{"function":"initLedger","Args":[]}'

    sleep 2 

    kubectl exec -it $(kubectl get pod -l app=peer0-org1-cli -o jsonpath="{.items[0].metadata.name}" ) -- peer chaincode query -C mychannel -n todo -c '{"Args":["getAllTodo"]}'

}

function startNetwork() {

    printSeparator "Starting the network "
    
    cd $HELM_DIR
    
    helmfile -e development sync
}

function cleanNetwork() {
    printSeparator "Cleaning..."
        
    rm -rf ./crypto-config/*
    rm -rf ./channel-artifacts/*
    rm -rf ./services/fabric-sdk-nestjs/wallet
    rm -rf ./services/fabric-sdk-nestjs/dist
    rm -rf ./services/fabric-sdk-nestjs/node_modules
    rm -rf ./chaincode/*/build/*
    rm -rf ./chaincode/*/source/node_modules
    rm -rf ./chaincode/*/source/dist
    rm -rf ./services/stimulus_reflex_todomvc/node_modules
    rm -rf ./services/stimulus_reflex_todomvc/tmp
    rm -rf ./services/stimulus_reflex_todomvc/pids
    rm -rf ./services/fabric-sdk-nestjs/local/
    rm -rf ./storage/*



    # This operations removes all docker containers and images regardless
    #
    cd $HELM_DIR
    
    helmfile destroy
}

function networkStatus() {
    kubectl get pods
}


# Network operations
case $COMMAND in
    "generate")
        generateCerts
        generateChannelArtifacts
        ;;
    "start")
        startNetwork
        ;;
    "deploy")
        generateChannelTransaction
        deployChainCode
        ;;
    "status")
        networkStatus
        ;;
    "clean")
        cleanNetwork
        ;;
    *)
        echo "Useage: networkOps.sh start | status | clean "
        exit 1;
esac