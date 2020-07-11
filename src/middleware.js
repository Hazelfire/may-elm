import actions, { RESPONSE_SUFFIX, ERROR_SUFFIX } from './actions';
import thunk from 'redux-thunk';
import { backend } from './config';
import ApiClient from './api';

export default [
  store => next => action => {
    if (typeof action.then !== 'function') {
      return next(action);
    }
    return Promise.resolve(action).then(store.dispatch);
  },
  thunk,
  store => next => action => {
    if (typeof action.server !== 'function') {
      return next(action);
    }
    let user = store.getState().login.user;
    let guestMode = !user;
    console.log(guestMode)
    console.log(action)
    next(action);
    if (!guestMode || action.authorizing) {
      action
        .server(new ApiClient(user))
        .then(response => {
          store.dispatch({
            type: action.type + RESPONSE_SUFFIX,
            response,
            original: action,
          });
        })
        .catch(error => {
          store.dispatch({
            type: action.type + ERROR_SUFFIX,
            error: { message: error, canRetry: true, doLocally: false },
            original: action,
          });
        });
    } else {
      store.dispatch({
        type: action.type + ERROR_SUFFIX,
        error: {
          message: 'Please log in to save',
          canRetry: false,
          doLocally: true,
        },
        original: action,
      });
    }
  },
];
