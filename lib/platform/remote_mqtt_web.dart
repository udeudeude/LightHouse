import 'package:mqtt_client/mqtt_browser_client.dart';
import 'package:mqtt_client/mqtt_client.dart';

MqttClient createRemoteMqttClient(String clientId) {
  final client = MqttBrowserClient(
    'wss://broker.emqx.io:8084/mqtt',
    clientId,
  );
  client.port = 8084;
  client.websocketProtocols = MqttClientConstants.protocolsSingleDefault;
  return client;
}
