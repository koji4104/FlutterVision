import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'dart:io';
import "vision_adapter.dart";

const isTestMode = false;

final pictureFileProvider = StateProvider<File>((ref) {
  return File('');
});

final isDispPictureProvider = StateProvider<bool>((ref) {
  return false;
});

final isLoadingProvider = StateProvider<bool>((ref) {
  return false;
});

final visionTypeProvider = StateProvider<VisionType>((ref) {
  return VisionType.FACE;
});

final redrawProvider = ChangeNotifierProvider((ref) => redrawNotifier(ref));
class redrawNotifier extends ChangeNotifier {
  redrawNotifier(ref){}
}