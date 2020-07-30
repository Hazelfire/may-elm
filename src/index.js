import Elm from './TodoList.elm';

var storedData = localStorage.getItem('may-model');
var storedData = storedData ? JSON.parse(storedData) : {};
var app = Elm.TodoList.init({
  node: document.getElementById('elmroot'),
  flags: storedData
});


// Listen for commands from the `setStorage` port.
// Turn the data to a string and put it in localStorage.
app.ports.setLocalStorage.subscribe(function(state) {
    localStorage.setItem('may-model', JSON.stringify(state));
});
