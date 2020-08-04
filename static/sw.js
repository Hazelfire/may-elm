var cacheName = 'mayfront-page';
var filesToCache = [
  '/',
  '/index.html',
  '/main.js',
  '/css/index.css', 
  '/manifest.json',
  'https://cdn.jsdelivr.net/npm/semantic-ui@2.4.2/dist/semantic.min.css',
  'https://stackpath.bootstrapcdn.com/font-awesome/4.7.0/css/font-awesome.min.css'
];

self.addEventListener('install', function(e) {
  e.waitUntil(
    caches.open(cacheName).then(function(cache) {
      return cache.addAll(filesToCache);
    }),
  );
});

self.addEventListener('activate', event => {
  event.waitUntil(self.clients.claim());
});

self.addEventListener('fetch', event => {
  if(event.request.method == 'GET'){
    event.respondWith(
      caches.match(event.request, {ignoreSearch: true}).then(response => {
        setTimeout( () => {
          cache.open(cacheName).then(cache => {
            return fetch(event.request).then(response => {
              cache.put(event.request, response.clone());
              return response
            })
          });
        }, 1000);
        if(response){
          return response;
        }
        else {
          return fetch(event.request);
        }
      }),
    );
  };
});
