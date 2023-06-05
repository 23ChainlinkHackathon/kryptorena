require("dotenv").config()

const pinataSDK = require("@pinata/sdk")
const path = require("path")
const fs = require("fs")

const pinata_api_key = process.env.PINATA_API_KEY
const pinata_secret_api_key = process.env.PINATA_SECRET_KEY
const pinata = new pinataSDK(pinata_api_key, pinata_secret_api_key)

pinata
    .testAuthentication()
    .then((result) => {
        //handle successful authentication here
        console.log(result)
    })
    .catch((err) => {
        //handle error here
        console.log(err)
    })
