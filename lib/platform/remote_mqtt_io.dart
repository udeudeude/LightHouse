import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

MqttClient createRemoteMqttClient(String clientId) {
  final client = MqttServerClient(
    'wss://broker.hivemq.com:8884/mqtt',
    clientId,
  );
  client.useWebSocket = true;
  client.port = 8884;
  client.websocketProtocols = const ['mqtt'];
  return client;
}
