import * as fs from "fs";
import BigNumber from 'bignumber.js'
import * as path from 'path';
import { secp256k1, address } from "thor-devkit";
import { Address } from "thor-model-kit";

enum CHAIN_TAG {
    Solo = 0xa4,
    Test = 0x27,
    Main = 0x4a
}

export default class Config {
    privateKey: string
    addr: Address
    chainTag: CHAIN_TAG
    vet: BigNumber
    thor: BigNumber
    vetLimit: BigNumber
    thorLimit: BigNumber
    networkAPIAddr: string
    maxAddressTimes: number
    maxIPTimes: number
    certificateExpiration: number
    recapchaSecretKey: string
    recapchaMinScore: number

    constructor() {
        let data = fs.readFileSync(path.join(__dirname, "../../config.json"), "utf-8")
        let opt = JSON.parse(data)
        if (!process.env.NODE_ENV || process.env.NODE_ENV == "dev") {
            this.privateKey = opt.privateKey
            this.chainTag = parseInt(opt.chainTag)
            this.recapchaSecretKey = opt.recapchaSecretKey
        } else {
            this.privateKey = process.env.PRIV_KEY
            this.chainTag = parseInt(process.env.CHAIN_TAG)
            this.recapchaSecretKey = process.env.RECAPCHA_SECRET_KEY
        }
        if (this.chainTag != CHAIN_TAG.Solo && this.chainTag != CHAIN_TAG.Test && this.chainTag != CHAIN_TAG.Main) {
            throw new Error("chain tag: invalid chain tag " + this.chainTag)
        }
        let pubKey = secp256k1.derivePublicKey(Buffer.from(this.privateKey.slice(2), "hex"))
        this.addr = Address.fromHex(address.fromPublicKey(pubKey))
        let big18 = new BigNumber("1000000000000000000")
        this.vet = new BigNumber(opt.vet).multipliedBy(big18)
        this.thor = new BigNumber(opt.thor).multipliedBy(big18)
        this.vetLimit = new BigNumber(opt.vetLimit).multipliedBy(big18)
        this.thorLimit = new BigNumber(opt.thorLimit).multipliedBy(big18)
        this.networkAPIAddr = opt.networkAPIAddr
        this.maxAddressTimes = opt.maxAddressTimes
        this.maxIPTimes = opt.maxIPTimes
        this.certificateExpiration = parseInt(opt.certificateExpiration) * 1000
        this.recapchaMinScore = parseFloat(opt.recapchaMinScore)
    }

}

declare module 'koa' {
    interface BaseContext {
        config: Config;
    }
}