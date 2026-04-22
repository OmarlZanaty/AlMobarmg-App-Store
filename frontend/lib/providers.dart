import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/user_model.dart';
import 'services/api_service.dart';
import 'services/install_service.dart';

final apiServiceProvider = Provider<ApiService>((_) => ApiService());
final installServiceProvider = Provider<InstallService>((_) => InstallService());

// currentUserProvider: stores logged-in UserModel from secure storage
final currentUserProvider = StateProvider<UserModel?>((ref) => null);
