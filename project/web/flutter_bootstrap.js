// Start-up script, replacing the one `flutter build web` generates.
//
// The generated script passes `serviceWorkerSettings`, which makes the loader
// register Flutter's deprecated clean-up worker (flutter_service_worker.js)
// and wait up to 4 s for it. That worker shares the site scope with the
// offline map worker (streamer_offline_sw.js, registered in index.html) and
// unregisters whatever owns that scope when it activates; on a network that
// connects but never answers it also adds its own 4 s wait to an offline
// start. The offline map worker already replaces any older worker at this
// scope, so the loader is started without one.
{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load();
