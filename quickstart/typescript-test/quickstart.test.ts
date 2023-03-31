import {EnclaveUUID, KurtosisContext} from "kurtosis-sdk"
import log from "loglevel"
import { Result, ok, err } from "neverthrow"
import path from "path";

const TEST_NAME = "quick-start-ts-example";
const MILLISECONDS_IN_SECOND = 1000;
const IS_PARTITIONING_ENABLED = false;
const DEFAULT_PARALLELISM = 4
const EMPTY_PACKAGE_PARAMS = "{}"
const IS_NOT_DRY_RUN = false

const QUICKSTART_PACKAGE = "github.com/kurtosis-tech/awesome-kurtosis/quickstart"
const API_SERVICE_NAME = "api"
const CONTENT_TYPE = "application/json"

jest.setTimeout(180000)

/*
This example will:
1. Start the quickstart
2. Make some API calls and verify we receive the right information

This test is an example of how Kurtosis makes writing distributed system tests as easy as single
server apps.
*/
test("Test quickstart post and get", async () => {

    // ------------------------------------- ENGINE SETUP ----------------------------------------------
    const newKurtosisContextResult = await KurtosisContext.newKurtosisContextFromLocalEngine()
    if (newKurtosisContextResult.isErr()) {
        log.error(`An error occurred connecting to the Kurtosis engine for running test ${TEST_NAME}`)
        return err(newKurtosisContextResult.error)
    }
    const kurtosisContext = newKurtosisContextResult.value;
    const enclaveName = `testName.${Math.round(Date.now() / MILLISECONDS_IN_SECOND)}`

    try {
        const createEnclaveResult = await kurtosisContext.createEnclave(enclaveName, IS_PARTITIONING_ENABLED);

        if (createEnclaveResult.isErr()) {
            log.error(`An error occurred creating enclave ${enclaveName}`)
            return err(createEnclaveResult.error)
        }

        log.info(`Loading package at path '${packageRootPath}'`)

        const params = `{"greetings": "bonjour!"}`
        const runResult = await enclaveContext.runStarlarkRemotePackageBlocking(QUICKSTART_PACKAGE, EMPTY_PACKAGE_PARAMS, IS_NOT_DRY_RUN, DEFAULT_PARALLELISM)

        if (runResult.isErr()) {
            log.error(`An error occurred execute Starlark package '${packageRootPath}'`);
            throw runResult.error
        }

        expect(runResult.value.interpretationError).toBeUndefined()
        expect(runResult.value.validationErrors).toEqual([])
        expect(runResult.value.executionError).toBeUndefined()



    } finally {
        kurtosisContext.destroyEnclave(enclaveName)
    }
})
