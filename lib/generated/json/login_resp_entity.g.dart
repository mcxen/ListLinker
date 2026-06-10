import 'package:list_linker/generated/json/base/json_convert_content.dart';
import 'package:list_linker/entity/login_resp_entity.dart';

LoginRespEntity $LoginRespEntityFromJson(Map<String, dynamic> json) {
  final LoginRespEntity loginRespEntity = LoginRespEntity();
  final String? token = jsonConvert.convert<String>(json['token']);
  if (token != null) {
    loginRespEntity.token = token;
  }
  return loginRespEntity;
}

Map<String, dynamic> $LoginRespEntityToJson(LoginRespEntity entity) {
  final Map<String, dynamic> data = <String, dynamic>{};
  data['token'] = entity.token;
  return data;
}

extension LoginRespEntityExtension on LoginRespEntity {
  LoginRespEntity copyWith({
    String? token,
  }) {
    return LoginRespEntity()
      ..token = token ?? this.token;
  }
}