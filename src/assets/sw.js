importScripts('https://storage.googleapis.com/workbox-cdn/releases/5.1.2/workbox-sw.js');
let registerRoute = workbox.routing.registerRoute;
let StaleWhileRevalidate = workbox.strategies.StaleWhileRevalidate;
let NetworkOnly = workbox.strategies.NetworkOnly;

registerRoute(
  ({url}) => url.hostname === 'api.may.hazelfire.net',
  new NetworkOnly()
);

registerRoute(
  ({url}) => url.hostname === 'localhost' || url.hostname == 'may.hazelfire.net',
  new StaleWhileRevalidate()
);
