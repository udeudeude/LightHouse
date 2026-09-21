import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

MqttClient createRemoteMqttClient(String clientId) {
  final client = MqttServerClient.withPort(
    'wss://broker.emqx.io/mqtt',
    clientId,
    8084,
  );
  client.useWebSocket = true;
  client.secure = false;
  client.websocketProtocols = MqttClientConstants.protocolsSingleDefault;
  return client;
}
