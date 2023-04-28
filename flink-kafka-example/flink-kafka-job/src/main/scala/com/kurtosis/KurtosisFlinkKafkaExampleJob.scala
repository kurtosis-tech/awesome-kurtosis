package com.kurtosis

import org.apache.flink.api.common.eventtime.WatermarkStrategy
import org.apache.flink.api.common.restartstrategy.RestartStrategies
import org.apache.flink.api.common.serialization.SimpleStringSchema
import org.apache.flink.api.java.utils.ParameterTool
import org.apache.flink.connector.kafka.sink.KafkaSink
import org.apache.flink.connector.kafka.source.KafkaSource
import org.apache.flink.connector.kafka.source.enumerator.initializer.OffsetsInitializer
import org.apache.flink.streaming.api.scala._
import org.apache.kafka.clients.producer.ProducerConfig

object KurtosisFlinkKafkaExampleJob {

  private val JobTitle: String = "Flink-Kafka-Example"

  def main(args: Array[String]): Unit = {

    val parameterTool = ParameterTool.fromArgs(args)

    val inputTopic = parameterTool.getRequired("input-topic") // words
    val outputTopic = parameterTool.getRequired("output-topic") // words-counted
    val groupId = parameterTool.getRequired("group-id") // flink-kafka-example
    val bootStrapServer = parameterTool.getProperties.getProperty(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG)

    val env = StreamExecutionEnvironment.getExecutionEnvironment

    env.getConfig.setRestartStrategy(RestartStrategies.fixedDelayRestart(4, 5000))
    env.enableCheckpointing(2000) // create a checkpoint every 2 seconds
    env.getConfig.setGlobalJobParameters(parameterTool) // make parameters available in the web interface

    val kafkaSource = KafkaSource
      .builder()
      .setBootstrapServers(bootStrapServer)
      .setTopics(inputTopic)
      .setGroupId(groupId)
      .setStartingOffsets(OffsetsInitializer.earliest())
      .setValueOnlyDeserializer(new SimpleStringSchema())
      .build()

    val kafkaSink = KafkaSink.builder()
      .setBootstrapServers(bootStrapServer)
      .setRecordSerializer(new WordCountKafkaRecordSerializer(outputTopic))
      .build()

    env.fromSource(kafkaSource, WatermarkStrategy.noWatermarks(), inputTopic)
      .map(w => WordCount(w.toLowerCase, 1))
      .keyBy(_.word)
      .sum(1)
      .sinkTo(kafkaSink)

    env.execute(JobTitle)

  }

}
