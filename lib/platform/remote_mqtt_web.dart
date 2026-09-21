import 'package:mqtt_client/mqtt_browser_client.dart';
import 'package:mqtt_client/mqtt_client.dart';

MqttClient createRemoteMqttClient(String clientId) {
  final client = MqttBrowserClient(
    'wss://broker.hivemq.com:8884/mqtt',
    clientId,
  );
  client.port = 8884;
  client.websocketProtocols = MqttClientConstants.protocolsSingleDefault;
  return client;
}
