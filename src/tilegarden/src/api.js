/**
 * Entrypoint for APIGateway
 */

const APIBuilder = require('claudia-api-builder')
const aws = require('aws-sdk')
const warmer = require('lambda-warmer')

const { imageTile, createMap } = require('./tiler')
const HTTPError = require('./util/error-builder')
const logger = require('./util/logger')

const IMAGE_HEADERS = {
    'Content-Type': 'image/png',
}

const HTML_RESPONSE = { success: { contentType: 'text/html' } }

// Converts a req object to a set of coordinates
const processCoords = (req) => {
    logger.debug('processCoords')
    // Handle url params
    const z = Number(req.pathParameters.z)
    const x = Number(req.pathParameters.x)

    // strip .png off of y if necessary
    const preY = req.pathParameters.y
    const y = Number(preY.substr(0, preY.lastIndexOf('.')) || preY)

    // Check type of coords
    /* eslint-disable-next-line no-restricted-globals */
    if (isNaN(x) || isNaN(y) || isNaN(z)) {
        throw HTTPError('Error: Coordinate values must be numbers!', 400)
    }
    return { z, x, y }
}

const getPositionalFilters = (req) => {
    logger.debug('getPositionalFilters')
    /* eslint-disable-next-line object-curly-newline */
    const { x, y, z, config, ...remainder } = req.pathParameters
    return remainder
}

// Parses out the configuration specifications
const processConfig = req => ({
    s3bucket: req.queryStringParameters ? req.queryStringParameters.s3bucket : null,
    config: req.pathParameters.config,
})

// Create new lambda API
const api = new APIBuilder({ requestFormat: 'AWS_PROXY' })

// Handles error by returning an API response object
const handleError = (e) => {
    logger.error(e)
    return new APIBuilder.ApiResponse(
        { message: e.message || e.toString() },
        { 'Content-Type': 'application/json' },
        e.http_code || 500,
    )
}

/* Uploads a tile to the S3 cache, using its request path as a key
 *
 * Does nothing unless there's a CACHE_BUCKET set in the environment.
 * Returns the Promise<tile> again for chaining.
 *
 * Theoretically it should be possible to run the upload in parallel and not make the request
 * wait for it before returning the tile, but in fact the process gets killed when the main promise
 * resolves so the upload doesn't manage to finish.
 */
const writeToS3 = (tile, req) => {
    logger.debug('writeToS3 called')
    const s3CacheBucket = process.env.PFB_TILEGARDEN_CACHE_BUCKET
    if (s3CacheBucket) {
        let key = req.path
        // API Gateway includes a 'path' property but claudia-local-api currently doesn't
        // (see https://github.com/azavea/claudia-local-api/issues/1), so this reconstructs it.
        if (!key) {
            logger.debug('writeToS3: recreating key from path params')
            /* eslint-disable camelcase */
            const { z, x, y, job_id, config } = req.pathParameters
            key = `tile/${job_id}/${config}/${z}/${x}/${y}`
            /* eslint-enable camelcase */
        } else if (key.startsWith('/')) {
            // API Gateway request.path object starts with a leading slash,
            // which would cause the uploaded object to have the wrong prefix.
            key = key.slice(1)
        }

        logger.debug('writeToS3: uploading')
        const upload = new aws.S3().putObject({
            Bucket: s3CacheBucket,
            Key: key,
            Body: tile,
        })
        return upload.promise().then(() => {
            logger.info(`Uploaded tile to S3: ${key}`)
            return tile
        })
    }
    return new Promise(resolve => resolve(tile))
}

// Get tile for some zxy bounds
api.get(
    '/tile/{job_id}/{config}/{z}/{x}/{y}',
    (req) => {
        try {
            const { z, x, y } = processCoords(req)
            const filters = getPositionalFilters(req)
            const configOptions = processConfig(req)

            logger.debug('api.get: creating imageTile')
            return imageTile(createMap(z, x, y, filters, configOptions))
                .then(tile => writeToS3(tile, req))
                .then(img => new APIBuilder.ApiResponse(img, IMAGE_HEADERS, 200))
                .catch(handleError)
        } catch (e) {
            return handleError(e)
        }
    },
    { success: { contentHandling: 'CONVERT_TO_BINARY' } },
)

api.get(
    '/',
    /* eslint-disable max-len */
    () => `
        <html>
            <head>
            <title>Tilegarden tiler</title>
            </head>
            <body>
                <h2>Usage:</h2>
                <ul>
                    <li>Render raster tile at zoom/x/y: <code>/tile/{z}/{x}/{y}.png</code></li>
                </ul>
            </body>
        </html>
    `,
    /* eslint-enable max-len */
    HTML_RESPONSE,
)

// 404 response
// This works in production but breaks the dev server just by existing
api.get(
    '/{wildcard+}',
    () => new APIBuilder.ApiResponse(
        { message: '404: Invalid path.' },
        { 'Content-Type': 'application/json' },
        404,
    ),
)

/* The api's entrypoint, defined by Claudia API Builder, is 'api.proxyRouter'. To handle
 * 'lambda-warmer' invocations, which API Builder doesn't know anything about, we need to process
 * raw invocations before they get to the API.  So this replaces 'api.proxyRouter' with a wrapped
 * function that handles warming invocations and passes other invocations along.
 * See https://github.com/jeremydaly/lambda-warmer#instrumenting-your-lambda-functions
 */
const origProxyRouter = api.proxyRouter
api.proxyRouter = (event, context, callback) => {
    // Start a promise chain
    logger.debug('in handler')
    warmer(event).then((isWarmer) => {
        logger.debug('in warmer.then')
        // if a warming event
        if (isWarmer) {
            logger.debug('This is a warming call.')
            callback(null, 'warmed')
        // else proceed with handler logic
        } else {
            origProxyRouter(event, context, callback)
        }
    }).catch(err => logger.error('Error: ', err))
}

// not es6-ic, but necessary for claudia to find the index
module.exports = api
