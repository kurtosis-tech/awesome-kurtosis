mysql = import_module("github.com/kurtosis-tech/awesome-kurtosis/blog-mysql-seed/mysql/mysql.star")

SELECT_SQL_QUERY = """
SELECT * FROM Post;
"""

def run(plan, args):
    setup_sql = plan.upload_files(
        src = "github.com/kurtosis-tech/awesome-kurtosis/blob/main/blog-mysql-seed/blog-seeder/setup.sql",
    )
    seed_sql = plan.read_file(
        src = "github.com/kurtosis-tech/awesome-kurtosis/blob/main/blog-mysql-seed/blog-seeder/seed.sql",
    )
    db = mysql.create_database(plan, "my-db", "hi", "bye", seed_script_artifacts = [setup_sql])
    plan.print(mysql.run_sql(plan, db, seed_sql))