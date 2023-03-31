package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"github.com/kurtosis-tech/kurtosis/api/golang/engine/lib/kurtosis_context"
	"github.com/sirupsen/logrus"
	"github.com/stretchr/testify/require"
	"io"
	"net/http"
	"net/url"
	"testing"
	"time"
)

/*
This example will:
1. Start the quickstart
2. Make some API calls and verify we receive the right information

This test is an example of how Kurtosis makes writing distributed system tests as easy as single
server apps.
*/

const (
	enclaveIdPrefix       = "quick-start-go-example"
	isPartitioningEnabled = false

	quickstartPackage = "github.com/kurtosis-tech/awesome-kurtosis/quickstart"

	defaultParallelism = 4
	noDryRun           = false

	emptyPackageParams = "{}"

	apiServiceName = "api"

	contentType = "application/json"
)

type Actor struct {
	Name     string `json:"first_name"`
	LastName string `json:"last_name"`
}

func TestQuickStart_RespondsToAPIRequestsAsExpected(t *testing.T) {

	ctx, cancelCtxFunc := context.WithCancel(context.Background())
	defer cancelCtxFunc()

	logrus.Info("------------ CONNECTING TO KURTOSIS ENGINE ---------------")
	kurtosisCtx, err := kurtosis_context.NewKurtosisContextFromLocalEngine()
	require.NoError(t, err, "An error occurred connecting to the Kurtosis engine")

	enclaveId := fmt.Sprintf("%s-%d", enclaveIdPrefix, time.Now().Unix())

	enclaveCtx, err := kurtosisCtx.CreateEnclave(ctx, enclaveId, isPartitioningEnabled)
	require.NoError(t, err, "An error occurred creating the enclave")
	defer kurtosisCtx.DestroyEnclave(ctx, enclaveId)

	logrus.Info("------------ EXECUTING PACKAGE ---------------")
	starlarkRunResult, err := enclaveCtx.RunStarlarkRemotePackageBlocking(ctx, quickstartPackage, emptyPackageParams, noDryRun, defaultParallelism)
	require.NoError(t, err, "An error executing loading the Quickstart package")
	require.Nil(t, starlarkRunResult.InterpretationError)
	require.Empty(t, starlarkRunResult.ValidationErrors)
	require.Nil(t, starlarkRunResult.ExecutionError)

	logrus.Info("------------ EXECUTING TESTS ---------------")
	apiServiceContext, err := enclaveCtx.GetServiceContext(apiServiceName)
	require.Nil(t, err)
	apiServicePublicPorts := apiServiceContext.GetPublicPorts()
	require.NotNil(t, apiServicePublicPorts)
	apiServiceHttpPortSpec, found := apiServicePublicPorts["http"]
	require.True(t, found)
	apiServiceHttpPort := apiServiceHttpPortSpec.GetNumber()
	apiServicePublicIpAddress := apiServiceContext.GetMaybePublicIPAddress()
	require.NotEmpty(t, apiServicePublicIpAddress)

	urlAndIpAddressOfService := fmt.Sprintf("http://%v:%v", apiServicePublicIpAddress, apiServiceHttpPort)
	actorsEndPointAddress, err := url.JoinPath(urlAndIpAddressOfService, "/actor")
	require.Nil(t, err)

	kevinBacon := Actor{Name: "Kevin", LastName: "Bacon"}
	steveBuscemi := Actor{Name: "Steve", LastName: "Buscemi"}

	actors := []Actor{
		kevinBacon,
		steveBuscemi,
	}

	// Post Some Content
	actorsAsBytes, err := json.Marshal(actors)
	require.Nil(t, err)
	response, err := http.Post(actorsEndPointAddress, contentType, bytes.NewReader(actorsAsBytes))
	require.Nil(t, err)
	require.Equal(t, response.StatusCode, http.StatusCreated)

	// Run a GET request to confirm that data was recorded
	response, err = http.Get(actorsEndPointAddress)
	require.Nil(t, err)
	require.Equal(t, response.StatusCode, http.StatusOK)
	var serializedResponse []Actor
	body, err := io.ReadAll(response.Body)
	require.Nil(t, err)
	defer response.Body.Close()
	fmt.Print(string(body))
	err = json.Unmarshal(body, &serializedResponse)
	require.Nil(t, err)
	require.Contains(t, serializedResponse, kevinBacon)
	require.Contains(t, serializedResponse, steveBuscemi)
}
