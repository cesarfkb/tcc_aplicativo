import '../provider/server_config_provider.dart';

class StreamService {
  static String streamUrl(ServerConfigProvider config) {
    return config.buildUri('/api/stream').toString();
  }
}
