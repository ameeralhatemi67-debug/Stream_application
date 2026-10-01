// Firebase Messaging registers this worker at its own push scope. It does not
// replace streamer_offline_sw.js, which owns the app's offline-map page scope.
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const orgKinds = new Set(['invitation', 'invitation_answered', 'join_request',
  'join_request_answered', 'assignment', 'assignment_changed', 'assignment_cancelled',
  'assignment_answered', 'assignment_reminder', 'membership_changed', 'show_live',
  'show_ending', 'transfer_proposed', 'transfer_cancelled', 'transfer_completed']);

// Mirrors OrgEvent.route in the app; only validated identifiers become routes.
function orgRoute(data) {
  const id = (key) => (typeof data[key] === 'string' && uuid.test(data[key]) ? data[key] : null);
  switch (data.kind) {
    case 'invitation': return id('invitation_id') ? `/org-invite/${id('invitation_id')}` : '/organizations';
    case 'show_live': return id('session_id') ? `/live/${id('session_id')}` : '/organizations';
    case 'assignment': case 'assignment_changed': case 'assignment_cancelled':
    case 'assignment_answered': case 'assignment_reminder': case 'show_ending': return '/shows';
    default: return '/organizations';
  }
}

self.addEventListener('push', (event) => {
  if (!event.data) return;
  let payload;
  try { payload = event.data.json(); } catch (_) { return; }
  const data = payload.data || {};
  if (data.type === 'org_event') {
    if (!orgKinds.has(data.kind)) return;
    event.waitUntil(self.registration.showNotification(
      payload.notification?.title || data.title_en || 'Organization update', {
        body: payload.notification?.body || data.body_en || '',
        tag: `org-${data.event_id}`,
        data: { route: orgRoute(data) },
        icon: './icons/Icon-192.png',
      }));
    return;
  }
  if (data.type !== 'upcoming_reminder') return;
  const title = payload.notification?.title || data.title_en || 'Planned stream';
  const body = payload.notification?.body || data.body_en || '';
  event.waitUntil(self.registration.showNotification(title, {
    body,
    tag: `upcoming-${data.schedule_id}-${data.occurrence_at}`,
    data: { streamer_id: data.streamer_id },
    icon: './icons/Icon-192.png',
  }));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const route = event.notification.data?.route;
  if (typeof route === 'string' && route.startsWith('/')) {
    event.waitUntil(self.clients.openWindow(new URL(`./#${route}`, self.location.origin).href));
    return;
  }
  const id = event.notification.data?.streamer_id;
  const safeId = typeof id === 'string' && uuid.test(id);
  const url = new URL(safeId ? `./#/profile/${id}?tab=upcoming` : './', self.location.origin);
  event.waitUntil(self.clients.openWindow(url.href));
});
