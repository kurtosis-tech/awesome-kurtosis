#!/usr/bin/env python3

import argparse
import psycopg2
import time
import numpy as np

parser = argparse.ArgumentParser(
    description="test performance of ReadySet vs. a backing Postgres database")
parser.add_argument("--query",
                    required=False,
                    help="query to execute")
parser.add_argument("--repeat",
                    type=int,
                    help="number of times to run the query",
                    default = 20)
parser.add_argument("--url",
                    required=True,
                    help="connection URL for ReadySet or Postgres")
args = parser.parse_args()

query = "SELECT count(*) FROM title_ratings JOIN title_basics ON title_ratings.tconst = title_basics.tconst WHERE title_basics.startyear = 2000 AND title_ratings.averagerating > 5"

print(args.url)
conn = psycopg2.connect(dsn=args.url)
conn.set_session(autocommit=True)
cur = conn.cursor()

times = list()
for n in range(args.repeat):
    start = time.time()
    cur.execute(query)
    if n < 1:
        if cur.description is not None:
            colnames = [desc[0] for desc in cur.description]
            print("")
            print("Result:")
            print(colnames)
            rows = cur.fetchall()
            for row in rows:
                print([str(cell) for cell in row])
    end = time.time()
    times.append((end - start)* 1000)

cur.close()
conn.close()

print("")
print("Query latencies (in milliseconds):")
print(["{:.2f}".format(t) for t in times])
print("")

print("Latency percentiles (in milliseconds):")
print(" p50: {:.2f}".format(np.percentile(times, 50)))
print(" p90: {:.2f}".format(np.percentile(times, 90)))
print(" p95: {:.2f}".format(np.percentile(times, 95)))
print(" p99: {:.2f}".format(np.percentile(times, 99)))
print("p100: {:.2f}".format(np.percentile(times, 100)))
print("")
