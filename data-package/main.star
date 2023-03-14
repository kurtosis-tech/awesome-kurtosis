# This is a tiny Kurtosis package that can be imported to provide a data artifact of Postgres data
# This Postgres data can be imported using `pg_restore` to populate a Postgres database
def run(plan, args):
    dvd_rental_data = plan.upload_files("github.com/kurtosis-tech/examples/data-package/dvd-rental-data.tar")

    return dvd_rental_data
