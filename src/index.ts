require("./css/index.css");
const {Elm} = require('./TodoList.elm');
const {loadStripe} = require('@stripe/stripe-js');

// Register the service worker
if ('serviceWorker' in navigator) {
  window.addEventListener('load', function() {
    navigator.serviceWorker.register('sw.js').then(function(registration) {
      // Success in registration
    }, function(err) {
      // Fail in registration
    });
  });
}

const mockStripe = false;
const params = new URLSearchParams(window.location.search)
if(params.has('code')){
  // We just came back from an authentication, I'll include the code within
  // the model. We store the code within local storage then make the code disappear!
  // It looks ugly in the URL so bye bye!
  
  localStorage.setItem('may-auth-code', params.get('code'));
  window.location.replace("/");
}
else if(params.has("stripe_status")){
  // This is only for the purpose of getting rid of the status. Which we don't actually need
  window.location.replace("/");
}
else {
  var storedData = localStorage.getItem('may-model');
  var parsedData = storedData ? JSON.parse(storedData) : {fs: null};
  let code = localStorage.getItem('may-auth-code');
  var tzo = -new Date().getTimezoneOffset(),
        dif = tzo >= 0 ? '+' : '-',
        pad = function(num) {
            var norm = Math.floor(Math.abs(num));
            return (norm < 10 ? '0' : '') + norm;
        };
  parsedData.offset = dif + pad(tzo / 60) + pad(tzo % 60);
  if(code){
    // Hey! We just came back from an authentication request. Let's pass the code
    // along with the model and remove the code from local storage (we don't need it anymore)
    // We are going to exchange this for an actual token later
    parsedData.code = code;
    localStorage.removeItem('may-auth-code');
  }
  var app = Elm.TodoList.init({
    node: document.getElementById('elmroot'),
    flags: parsedData
  });


  // Listen for commands from the `setLocalStorage` port.
  // Turn the data to a string and put it in localStorage.
  app.ports.setLocalStorage.subscribe(function(state) {
      localStorage.setItem('may-model', JSON.stringify(state));
  });

  app.ports.openStripe.subscribe(function(sessionId) {
    if(mockStripe){
      window.location.replace("http://localhost:3000/stripe")
    }
    else {
      var stripe = loadStripe('pk_live_p7RnEFmP2sWP65uUYysqOomz');
      stripe.redirectToCheckout({
        // Make the id field from the Checkout Session creation API response
        // available to this file, so you can provide it as argument here
        // instead of the {{CHECKOUT_SESSION_ID}} placeholder.
        sessionId
      }).then(function (result) {
        console.log(result);
        // If `redirectToCheckout` fails due to a browser or network
        // error, display the localized error message to your customer
        // using `result.error.message`.
      });
    } 
  });
  app.ports.setFocus.subscribe(function(id) {
    window.requestAnimationFrame(() => {
      let element = document.getElementById(id)
      if(element){
        element.focus();
      }
    });
  });
}
