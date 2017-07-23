### Use OpenSSL CA for Hyperledger Fabric
[TOC]

#### Get and install Hyperledger Fabric Samples

```
git clone https://github.com/hyperledger/fabric-samples
cd fabric-samples
curl -sSL https://goo.gl/iX9dek | bash
```
#### Copy lab files into fabric-samples
You can get from and copy all files into fabric samples

#### Re-generate all artifacts
We replace a new generate.sh with ourself generate script, and this new script will use OpenSSL to generate all certificates and MSPs.
```
cd basic-network
./generate.sh
# View result
tree crypto-config
```
#### Start fabric network (fabcar sample)
```sh
cd fabcar
./startFabric.sh
```
### Replace "fabcar/creds" 
If you want to run node query.js and invoke.js, please rebuild "creds".

