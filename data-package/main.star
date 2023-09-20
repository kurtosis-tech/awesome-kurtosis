TAR_FILENAME = "dvd-rental-data.tar"

# This is a tiny Kurtosis package that can be imported to provide a data artifact of Postgres data
# This Postgres data can be imported using `pg_restore` to populate a Postgres database
def run(plan, args = {}):
    # From https://www.postgresqltutorial.com/postgresql-getting-started/postgresql-sample-database/
    dvd_rental_data = plan.upload_files("./" + TAR_FILENAME)

    result =  struct(
        files_artifact = dvd_rental_data, # Needed to mount the data on a service
        tar_filename = TAR_FILENAME,      # Useful to reference the data TAR contained in the files artifact
    )

    return result
