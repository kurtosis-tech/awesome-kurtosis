package com.kurtosis

import com.fasterxml.jackson.databind.ObjectMapper
import com.kurtosis.WordCountKafkaRecordSerializer.objectMapper
import org.apache.flink.connector.kafka.sink.KafkaRecordSerializationSchema
import org.apache.kafka.clients.producer.ProducerRecord

import java.lang

class WordCountKafkaRecordSerializer(
  topic: String,
) extends KafkaRecordSerializationSchema[WordCount] {
  override def serialize(
    element: WordCount,
    context: KafkaRecordSerializationSchema.KafkaSinkContext,
    timestamp: lang.Long,
  ): ProducerRecord[Array[Byte], Array[Byte]] =
    try {
      new ProducerRecord(topic, objectMapper.writeValueAsBytes(element));
    } catch {
      case e: Throwable => throw new IllegalArgumentException("Could not serialize record: " + element, e);
    }

}

object WordCountKafkaRecordSerializer {

  import com.fasterxml.jackson.module.scala.DefaultScalaModule

  private val objectMapper = new ObjectMapper()
  objectMapper.registerModule(DefaultScalaModule)

}