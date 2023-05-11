package main

import (
	"context"
	"fmt"
	"github.com/kurtosis-tech/kurtosis/api/golang/engine/lib/kurtosis_context"
	"github.com/montanaflynn/stats"
	"github.com/stretchr/testify/require"
	"log"
	"sync"
	"testing"
	"time"
)

type User struct {
	id int16
}

var dbConn *pgx.Conn
var once sync.Once

func thisMethodWillGoToMainGo(ctx context.Context, url string) (float64, error) {
	teardown := setupDbConn(url)
	defer teardown()

	var err error
	var users []User
	var rows pgx.Rows
	var queryTimes []float64

	for i := 0; i < 10; i++ {
		now := time.Now()
		rows, err = dbConn.Query(ctx, `SELECT count(*) FROM title_ratings JOIN title_basics ON title_ratings.tconst = title_basics.tconst WHERE title_basics.startyear = 2000 AND title_ratings.averagerating > 5;`)
		if err != nil {
			return 0.0, err
		}
		end := time.Now()
		queryTime := end.Sub(now)
		queryTimes = append(queryTimes, queryTime.Seconds())

		for rows.Next() {
			user := User{}
			err := rows.Scan(&user.id)
			if err != nil {
				return 0.0, err
			}
			users = append(users, user)
		}
	}

	mediumTimeValue, _ := stats.Median(queryTimes)
	return mediumTimeValue, nil
}

func setupDbConn(connStr string) func() {
	var err error

	ctx := context.Background()
	dbConn, err = pgx.Connect(ctx, connStr)

	if err != nil {
		log.Fatal(err)
	}

	return func() {
		dbConn.Close(ctx)
	}
}

func executeKurtosisPackage(ctx context.Context, t *testing.T) {

	const enclaveId = "readyset-integration-test"
	kurtosisCtx, err := kurtosis_context.NewKurtosisContextFromLocalEngine()
	require.NoError(t, err, "An error occurred connecting to the Kurtosis engine")

	enclaveCtx, err := kurtosisCtx.CreateEnclave(ctx, enclaveId, false)
	require.NoError(t, err, "An error occurred creating the enclave")
	defer kurtosisCtx.DestroyEnclave(ctx, enclaveId)

	starlarkRunResult, err := enclaveCtx.RunStarlarkRemotePackageBlocking(ctx, quickstartPackage, emptyPackageParams, noDryRun, defaultParallelism)
	require.NoError(t, err, "An error executing loading the Quickstart package")
	require.Nil(t, starlarkRunResult.InterpretationError)
	require.Empty(t, starlarkRunResult.ValidationErrors)
	require.Nil(t, starlarkRunResult.ExecutionError)
}

func cacheQuery(ctx context.Context, readySetUrl string) error {
	teardown := setupDbConn(readySetUrl)
	defer teardown()

	// this method caches the query under the test
	_, err := dbConn.Exec(ctx, `CREATE CACHE FROM SELECT count(*) FROM title_ratings JOIN title_basics ON title_ratings.tconst = title_basics.tconst WHERE title_basics.startyear = 2000 AND title_ratings.averagerating > 5;`)
	return err
}

func TestQueryPerformanceWithCache(t *testing.T) {
	ctx, cancelCtxFunc := context.WithCancel(context.Background())
	defer cancelCtxFunc()

	postgresUrl := "postgresql://postgres:readyset@127.0.0.1:52297/test"
	readySetUrl := "postgresql://postgres:readyset@127.0.0.1:52302/test"

	uncachedTime, err := thisMethodWillGoToMainGo(ctx, postgresUrl)
	require.NoError(t, err)

	err = cacheQuery(ctx, readySetUrl)
	require.NoError(t, err)

	cachedTime, err := thisMethodWillGoToMainGo(ctx, readySetUrl)
	require.NoError(t, err)

	fmt.Printf("not cached: %v , cached: %v", uncachedTime, cachedTime)
	require.Less(t, cachedTime, uncachedTime)
	require.Equal(t, 1, 2)
}
