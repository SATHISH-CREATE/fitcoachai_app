import 'dart:ui_web' as ui;
import 'dart:html' as html;
import 'dart:js' as js;

class WebSync {
  static void registerMapFactory(String viewId) {
    ui.platformViewRegistry.registerViewFactory(
      viewId,
      (int id) {
        final div = html.DivElement()
          ..id = 'web-map-container'
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.backgroundColor = '#0a0a0f';
        return div;
      },
    );
  }

  static void injectMapSync(double lat, double lon, String gymsJson) {
     try {
       js.context.callMethod('initAndSyncMap', [lat, lon, gymsJson]);
     } catch (e) {
       print('JS Sync Error: $e');
     }
  }

  static void speak(String text) {
     try {
       js.context.callMethod('speakFeedback', [text]);
     } catch (e) {}
  }

  static void stopPose() {
     try {
       js.context.callMethod('stopPoseDetection');
     } catch (e) {}
  }

  static void startPose(void Function(String) callback) {
     try {
       final wrapped = (String result) => callback(result);
       js.context.callMethod('startPoseDetection', [wrapped]);
     } catch (e) {}
  }

  static void download(String path, String name) {
     try {
       js.context.callMethod('downloadFile', [path, name]);
     } catch (e) {}
  }
}
