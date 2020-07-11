import React from 'react';
/* Allows for async functions */
import 'babel-polyfill';
import ReactDOM from 'react-dom';
import { createStore, combineReducers, applyMiddleware } from 'redux';
import { Provider } from 'react-redux';
import * as reducers from './reducers';
import { setTime, SET_TIME } from './actions';
import middleware from './middleware';
import { createLogger } from 'redux-logger';
import App from './App';
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

ReactDOM.render(
  <App />,
  document.getElementById('react-entry')
);
