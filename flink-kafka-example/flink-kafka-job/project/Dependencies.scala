import sbt._

object Dependencies {

  val flinkVersion = "1.17.0"
  val jacksonVersion = "2.14.2"

  val flinkDependencies: Seq[ModuleID] = Seq(
    "org.apache.flink" %% "flink-scala" % flinkVersion,
    "org.apache.flink" %% "flink-streaming-scala" % flinkVersion,
    "org.apache.flink" % "flink-clients" % flinkVersion,
    "org.apache.flink" % "flink-connector-kafka" % flinkVersion,
    "com.fasterxml.jackson.module" %% "jackson-module-scala" % jacksonVersion,
    "com.fasterxml.jackson.core" % "jackson-databind" % jacksonVersion,
  )

}