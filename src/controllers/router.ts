import * as Router from 'koa-router'
import Cert from '../utils/cert'
import TransactionService from './transaction-service'
import RecapchaService from './recapcha-service'
import Validator from '../utils/validator'
import { blake2b256 } from 'thor-devkit/dist/cry'
import { Certificate } from 'thor-devkit'
import { reportLogger } from '../utils/logger'

interface Annex {
  domain: string
  signer: string
  timestamp: string
}

interface Payload {
  type: string
  content: string
}

interface RequestBody {
  token: string
  annex: Annex
  signature: string
  purpose: string
  payload: Payload
}

var router = new Router()
router.post("/requests", async (ctx) => {
    let recapchaService = new RecapchaService(ctx.config)
    let { token, annex, signature, purpose, payload } = ctx.request
      .body as RequestBody
    let { domain, signer, timestamp } = annex
    let { type, content } = payload

    let score = await recapchaService.verifyRecapcha(token)
    let parsedTimestamp = parseFloat(timestamp)
    let cert = new Cert(
      domain,
      parsedTimestamp,
      signer,
      signature,
      purpose,
      type,
      content
    )

    Validator.validateTimestamp(
      parsedTimestamp,
      ctx.config.certificateExpiration
    )
    Validator.validateCertificate(cert)
    let addr = Validator.validateAddress(signer)
    let remoteAddr = ctx.request.ip
    let service = new TransactionService(ctx.db, ctx.config)
    let certHash = blake2b256(Certificate.encode(cert))
    await service.certHashApproved(certHash)
    await service.balanceApproved()
    await service.addressApproved(addr)
    await service.ipApproved(remoteAddr)
    let tx = await service.buildTx(addr)
    await service.txApproved(tx.id)
    await service.insertTx(tx.id, addr, remoteAddr, certHash)
    await service.send(tx)

    ctx.body = {
      id: tx.id.toString(),
    }

    reportLogger.info(`IP=${remoteAddr} Address=${signer} Score=${score}`)
})

export default router