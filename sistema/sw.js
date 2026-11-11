// Só exibe as notificações do checklist e abre o sistema ao clicar. Sem cache.
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', event => event.waitUntil(self.clients.claim()));
self.addEventListener('notificationclick', event => {
  event.notification.close();
  const url = new URL('../equipe.html#checklist', self.location).href;
  event.waitUntil(self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(list => {
    const open = list.find(c => c.url.includes('/equipe.html'));
    if (open) { open.navigate(url); return open.focus(); }
    return self.clients.openWindow(url);
  }));
});
