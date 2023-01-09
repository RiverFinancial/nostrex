// Lots of code taken from https://github.com/Cameri/nostrillery


const secp256k1 = require('@noble/secp256k1')
const { createHmac } = require('crypto')

const uniquePubkeys = 10;

function getPrivateKey(secret) {
  // select random key to send message
  // console.log("IIIIIIIIIII")
  // console.log(secret)
  const hmac = createHmac('sha256', secret)

  // hmac.update(uuid)

  return hmac.digest().toString('hex')
}

function getPublicKey(privateKey) {
  pk = getPrivateKey(privateKey)
  return Buffer.from(secp256k1.getPublicKey(pk, true)).toString('hex').substring(2)
}

async function signEvent(event, privateKey) {
  // console.log("IN SIGN EVENT")
  const id = await secp256k1.utils.sha256(
    Buffer.from(serializeEvent(event))
  );
  const sig = await secp256k1.schnorr.sign(id, privateKey)


  // console.log(sig)
  return {
    id: Buffer.from(id).toString('hex'),
    ...event,
    sig: Buffer.from(sig).toString('hex'),
  }
}

function serializeEvent(event) {
  return JSON.stringify([
    0,
    event.pubkey,
    event.created_at,
    event.kind,
    event.tags,
    event.content,
  ])
}

async function createEvent(privateKey) {
  const privkey = privateKey
  const pubkey = getPublicKey(privkey)
  const created_at = Math.floor(Date.now() / 1000)

  // console.log("IN BEFORE SIGN")
  const event = signEvent(
    {
      pubkey,
      kind: 1,
      content: `Performance test ${Date.now()}`,
      created_at: created_at,
      tags: [[
        "e", getPublicKey(randBelow(uniquePubkeys).toString()), "test.relay.dev"
        ]]
    },
    privkey,
  )

  return event
}


function getRandAuthors() {
  list = []

  for(var i = 0; i < randBelow(uniquePubkeys / 3); i++){
    list.push(i.toString());
  }

  // console.log(getPublicKey())

  return list.map(x => getPublicKey(x));
}

function createMessage(context, _events, done) {
  // const { kind, content, privateKey, tags } = context.vars;
  // createEvent({ kind, content, privateKey, tags }).then((event) => {
  privkey = getPrivateKey(randBelow(uniquePubkeys).toString());
  // console.log(privkey)
  createEvent(privkey).then((event) => {
    context.vars.message = ['EVENT', event]
    // console.log("IN CONTEXT")
    done()
  }, (err) => done(err))
}

function createSubscription(context, _events, done) {
  const filter = {
    authors: getRandAuthors()
  }

  subId = Math.random().toString(36).substr(2, 5);

  context.vars.message = ['REQ', subId, filter];
  return done();
}


function randBelow(n) {
  return Math.floor(Math.random() * n)
}

module.exports = {
  createMessage,
  createSubscription
}