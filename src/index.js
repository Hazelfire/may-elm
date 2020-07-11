import React from 'react';
/* Allows for async functions */
import ReactDOM from 'react-dom';
import { createStore, combineReducers, applyMiddleware } from 'redux';
import { Provider } from 'react-redux';
import * as reducers from './reducers';
import { setTime, SET_TIME } from './actions';
import middleware from './middleware';
import { createLogger } from 'redux-logger';
import MainPage from './pages/MainPage'
import 'semantic-ui-css/semantic.min.css';
import './css/index.css';

/*
let logger = createLogger({
  predicate: (getState, action) => action.type != SET_TIME,
});

let store = createStore(
  combineReducers(reducers),
  applyMiddleware(...middleware, logger)
);

function updateTime() {
  store.dispatch(setTime());
}

let TICK_TIME = 1000;

setInterval(updateTime, TICK_TIME);
*/
/* Register our service worker */
if ('serviceWorker' in navigator) {
   window.addEventListener('load', () => {
     navigator.serviceWorker.register('service-worker.js').then(registration => {
       console.log('SW registered: ', registration);
     }).catch(registrationError => {
       console.log('SW registration failed: ', registrationError);
     });
   });
 }

ReactDOM.render(
  <MainPage />,
  document.getElementById('react-entry')
);
