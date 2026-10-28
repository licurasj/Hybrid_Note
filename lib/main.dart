import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app/hybrid_note_app.dart';
import 'app_cubit.dart';
import 'app_storage.dart';
import 'drive_sync_service.dart';
import 'lists/custom_lists.dart';
import 'lists/local_list_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final AppStorage storage = AppStorage();
  final String deviceId = await storage.getOrCreateDeviceId();

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => AppCubit(
            storage: storage,
            driveSyncService: DriveSyncService(),
            deviceId: deviceId,
          )..loadData(),
        ),
        BlocProvider(
          create: (_) => CustomListsCubit(CustomListsStorage())..load(),
        ),
        LocalListStore.provider(),
      ],
      child: const HybridNoteApp(),
    ),
  );
}
