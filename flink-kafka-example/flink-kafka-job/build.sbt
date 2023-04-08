import sbt.Keys._

val sharedSettings: Seq[Def.Setting[_]] = Seq(
  organization := "com.kurtosis",
  version := "0.1.0",
  scalaVersion := "2.12.7",
  scalacOptions ++= Seq(
    "-deprecation",
    "-unchecked",
    "-feature",
    "-Ywarn-dead-code",
  ),
  fork := true,
  publishArtifact in Test := true,
  test in assembly := {},
  assemblyMergeStrategy in assembly := {
    case PathList("META-INF", "maven", "pom.properties") => MergeStrategy.singleOrError
    case PathList("META-INF", xs@_*) => MergeStrategy.discard
    case x => MergeStrategy.first
  }
)

lazy val root = (project in file(".")).
  settings(
    name := "KurtosisFlinkKafkaExample",
    sharedSettings,
    libraryDependencies ++= Dependencies.flinkDependencies,
    mainClass in assembly := Some("com.kurtosis.KurtosisFlinkKafkaExampleJob"),
    assemblyJarName in assembly := "run.jar",
  )