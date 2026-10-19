class DistributeOptionsBase {

  DistributeOptionsBase({
    this.appName,
  });

  factory DistributeOptionsBase.fromJson(Map<String, dynamic> json) {
    return DistributeOptionsBase(
      appName: json['app_name']
    );
  }

  final String? appName;
}