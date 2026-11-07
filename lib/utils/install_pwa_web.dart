import 'package:web/web.dart' as web;

bool get pwaInstallee =>
    web.window.matchMedia('(display-mode: standalone)').matches ||
    web.window.matchMedia('(display-mode: fullscreen)').matches;

bool get estIos {
  final ua = web.window.navigator.userAgent;
  return ua.contains('iPhone') || ua.contains('iPad') || ua.contains('iPod');
}

bool get pwaInvitePossible => estIos && !pwaInstallee;
