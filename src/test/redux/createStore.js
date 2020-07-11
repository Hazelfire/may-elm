import { createStore, combineReducers, applyMiddleware } from 'redux';

import * as reducers from '../../reducers';
import { createLogger } from 'redux-logger';
import middleware from '../../middleware';

export default () => {
  return createStore(combineReducers(reducers), applyMiddleware(...middleware));
};
