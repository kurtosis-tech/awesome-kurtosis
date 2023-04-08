import sbt._

object Dependencies {

  val flinkVersion = "1.17.0"
  val jacksonVersion = "2.14.2"

  val flinkDependencies: Seq[ModuleID] = Seq(
    "org.apache.flink" %% "flink-scala" % flinkVersion % "provided",
    "org.apache.flink" %% "flink-streaming-scala" % flinkVersion % "provided",
    "org.apache.flink" % "flink-clients" % flinkVersion % "provided",
    "org.apache.flink" % "flink-connector-kafka" % flinkVersion % "provided",
    "com.fasterxml.jackson.module" %% "jackson-module-scala" % jacksonVersion,
    "com.fasterxml.jackson.core" % "jackson-databind" % jacksonVersion,
  )

}