import {EnclaveContext, EnclaveUUID, KurtosisContext} from "kurtosis-sdk"
import log from "loglevel"
import {err, ok, Result} from "neverthrow"
import {PortSpec} from "kurtosis-sdk/build/core/lib/services/port_spec";
import {StarlarkRunResult} from "kurtosis-sdk/build/core/lib/enclaves/starlark_run_blocking";
import {ServiceContext} from "kurtosis-sdk/build/core/lib/services/service_context";

const TEST_NAME = "quick-start-ts-example";
const MILLISECONDS_IN_SECOND = 1000;
const IS_PARTITIONING_ENABLED = false;
const DEFAULT_PARALLELISM = 4
const EMPTY_PACKAGE_PARAMS = "{}"
const IS_NOT_DRY_RUN = false

const QUICKSTART_PACKAGE = "github.com/kurtosis-tech/awesome-kurtosis/quickstart"
const API_SERVICE_NAME = "api"
const CONTENT_TYPE = "application/json"
const HTTP_PORT_ID = "http"

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
    const createEnclaveResult = await createEnclave(TEST_NAME, IS_PARTITIONING_ENABLED)

    if (createEnclaveResult.isErr()) {
        throw createEnclaveResult.error
    }

    const {enclaveContext, stopEnclaveFunction} = createEnclaveResult.value

    try {
        // ------------------------------------- PACKAGE RUN ----------------------------------------------
        log.info("------------ EXECUTING PACKAGE ---------------")

        const runResult: Result<StarlarkRunResult, Error> = await enclaveContext.runStarlarkRemotePackageBlocking(QUICKSTART_PACKAGE, EMPTY_PACKAGE_PARAMS, IS_NOT_DRY_RUN)

        if (runResult.isErr()) {
            log.error(`An error occurred execute Starlark package '${QUICKSTART_PACKAGE}'`);
            throw runResult.error
        }

        expect(runResult.value.interpretationError).toBeUndefined();
        expect(runResult.value.validationErrors).toEqual([]);
        expect(runResult.value.executionError).toBeUndefined();

        log.info("------------ EXECUTING TEST ---------------")

        const getApiServiceContextResult: Result<ServiceContext, Error> = await enclaveContext.getServiceContext(API_SERVICE_NAME);
        if (getApiServiceContextResult.isErr()) {
            log.error("An error occurred getting the API service context");
            throw getApiServiceContextResult.error;
        }
        const apiServiceContext: ServiceContext = getApiServiceContextResult.value;
        const apiServicePublicPorts: Map<string, PortSpec> = await apiServiceContext.getPublicPorts();
        if (apiServicePublicPorts.size == 0){
            throw new Error("Expected to receive API service public ports but none was received")
        }

        if (!apiServicePublicPorts.has(HTTP_PORT_ID)){
            throw new Error(`Expected to find API service port wih ID ${HTTP_PORT_ID} but it was not found`)
        }

        const apiServiceHttpPortSpec: PortSpec = apiServicePublicPorts[HTTP_PORT_ID]
        const apiServiceHttpPort: number = apiServiceHttpPortSpec.number
        const apiServicePublicIpAddress: string = apiServiceContext.getMaybePublicIPAddress()

    } finally {
        stopEnclaveFunction()
    }
})

async function createEnclave(testName: string, isPartitioningEnabled: boolean):
    Promise<Result<{
        enclaveContext: EnclaveContext,
        stopEnclaveFunction: () => void
        destroyEnclaveFunction: () => Promise<Result<null, Error>>,
    }, Error>> {

    const newKurtosisContextResult = await KurtosisContext.newKurtosisContextFromLocalEngine()
    if (newKurtosisContextResult.isErr()) {
        log.error(`An error occurred connecting to the Kurtosis engine for running test ${testName}`)
        return err(newKurtosisContextResult.error)
    }
    const kurtosisContext = newKurtosisContextResult.value;

    const enclaveName: EnclaveUUID = `${testName}.${Math.round(Date.now() / MILLISECONDS_IN_SECOND)}`
    const createEnclaveResult = await kurtosisContext.createEnclave(enclaveName, isPartitioningEnabled);

    if (createEnclaveResult.isErr()) {
        log.error(`An error occurred creating enclave ${enclaveName}`)
        return err(createEnclaveResult.error)
    }

    const enclaveContext = createEnclaveResult.value;

    const stopEnclaveFunction = async (): Promise<void> => {
        const stopEnclaveResult = await kurtosisContext.stopEnclave(enclaveName)
        if (stopEnclaveResult.isErr()) {
            log.error(`An error occurred stopping enclave ${enclaveName} that we created for this test: ${stopEnclaveResult.error.message}`)
            log.error(`ACTION REQUIRED: You'll need to stop enclave ${enclaveName} manually!!!!`)
        }
    }

    const destroyEnclaveFunction = async (): Promise<Result<null, Error>> => {
        const destroyEnclaveResult = await kurtosisContext.destroyEnclave(enclaveName)
        if (destroyEnclaveResult.isErr()) {
            const errMsg = `An error occurred destroying enclave ${enclaveName} that we created for this test: ${destroyEnclaveResult.error.message}`
            log.error(errMsg)
            log.error(`ACTION REQUIRED: You'll need to destroy enclave ${enclaveName} manually!!!!`)
            return err(new Error(errMsg))
        }
        return ok(null)
    }

    return ok({enclaveContext, stopEnclaveFunction, destroyEnclaveFunction})
}

