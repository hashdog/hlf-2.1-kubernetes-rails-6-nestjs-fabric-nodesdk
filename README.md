# HyperLedger Fabric 2.1 + KUBERNETES + HELM CHARTS + HELMFILE + TODO APP Rails 6 + Fabric-sdk-nestjs chaincode restapi

## Hello
We are going to create a HLF 2.1 network, consisting of one consortium (a collection of organizations). This consortium includes two organizations: Org1  and Org2 . Both organizations provide each one peer. We will join those peers to a so called channel. The channel allows sending transactions between those two organizations. This is the minimum viable setup for a functional HLF blockchain network using kubernetes, helm charts, helmfile, rails and nestjs.
After Create HLF network, a new rest-api service  and todo app will be available for interacts with the chaincode installed

## Requirenment

    - Set rails.local in your /etc/hosts `127.0.0.1 rails.local`
    - Have installed docker kubernetes or any kubernetes services

## Usage

First, we going to generate all crypto material

    ./networkOps.sh prepare

then we going to start the network over your kubernetes cloud

    ./networkOps.sh start

and finally, we going to create and deploy a chaincode for test purpouses.

    ./networkOps.sh deploy

If you want to clean all it, you have to run
    
    ./networkOpts.sh clean

## TODO App
open rails.local

it has to looks like this

![todoapp](https://raw.githubusercontent.com/hashdog/hlf-2.2-docker-rails-6-nestjs-fabric-nodesdk/media/todoapp.png?raw=true)

all request going to send directly to HYPERLEDGER FABRIC, if you want you can check the fabric ruby client

    `lib/services/hyperledger_fabric_client.rb`


## Acknowledgment

