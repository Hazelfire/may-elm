importScripts('https://storage.googleapis.com/workbox-cdn/releases/5.1.2/workbox-sw.js');
let registerRoute = workbox.routing.registerRoute;
let StaleWhileRevalidate = workbox.strategies.StaleWhileRevalidate;

registerRoute(
  ({url}) => url.pathname.startsWith('/'),
  new StaleWhileRevalidate()
);
