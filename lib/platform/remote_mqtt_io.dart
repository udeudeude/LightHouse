import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

MqttClient createRemoteMqttClient(String clientId) {
  final client = MqttServerClient.withPort(
    'wss://broker.hivemq.com/mqtt',
    clientId,
    8884,
  );
  client.useWebSocket = true;
  client.secure = false;
  client.websocketProtocols = MqttClientConstants.protocolsSingleDefault;
  return client;
}
