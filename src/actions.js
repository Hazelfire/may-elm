// @flow
import { TaskSerialiser, NullSerialiser } from './serialisers';
import ApiClient from './api';
import moment from 'moment';
import { ActionSet } from './actionset';

export const LOGIN = 'LOGIN';
export const REGISTER = 'REGISTER';
export const TOKEN_LOGIN = 'TOKEN_LOGIN';
export const LOGOUT = 'LOGOUT';
export const SET_TIME = 'SET_TIME';
export const SELECT = 'SELECT';

export const ADD_TASK = 'ADD_TASK';
export const EDIT_TASK = 'EDIT_TASK';
export const DELETE_TASK = 'DELETE_TASK';

export const ADD_LABEL = 'ADD_LABEL';
export const EDIT_LABEL = 'EDIT_LABEL';
export const DELETE_LABEL = 'DELETE_LABEL';

export const SET_FOLDER = 'SET_FOLDER';
export const EDIT_FOLDER = 'EDIT_FOLDER';
export const ADD_FOLDER = 'ADD_FOLDER';
export const DELETE_FOLDER = 'DELETE_FOLDER';


export const ERROR_SUFFIX = '_ERROR';
export const RESPONSE_SUFFIX = '_RESPONSE';

// Anything past this point is legacy and is / should not be used

export const createThunk = (type, promise, argsToObject) => (
  ...args: Array<mixed>
) => async (dispatch: mixed => mixed, getState: () => mixed) => {
  let original = {
    ...argsToObject(...args),
    type,
  };
  dispatch(original);
  try {
    let response = await promise.apply(null, args)(dispatch, getState);
    dispatch({
      type: type + RESPONSE_SUFFIX,
      original,
      response,
    });
    return response;
  } catch (error) {
    dispatch({
      type: type + ERROR_SUFFIX,
      original,
      error,
    });
    throw error;
  }
};

export const login = createThunk(
  LOGIN,
  (username, password) => () => ApiClient.logIn(username, password),
  (username, password) => ({ username, password })
);

export const pullData = async (dispatch: mixed => mixed) => {
  await dispatch(taskset.list());
  await dispatch(folderset.list());
  await dispatch(labelset.list());
};

export const loginThenPullData = (username: string, password: string) => {
  return async (dispatch: mixed => mixed) => {
    await dispatch(login(username, password));
    await pullData(dispatch);
  };
};

export const register = createThunk(
  REGISTER,
  (username, password, confirm, email) => () =>
    ApiClient.register(username, password, confirm, email),
  (username, password, confirm, email) => ({
    username,
    password,
    confirm,
    email,
  })
);

export const taskset = new ActionSet('/tasks/', 'TASK', new TaskSerialiser());
export let folderset = new ActionSet(
  '/folders/',
  'FOLDER',
  new NullSerialiser(),
  [{ id: 'root', root: true, name: 'My Tasks' }]
);
export const labelset = new ActionSet(
  '/labels/',
  'LABEL',
  new NullSerialiser()
);

export const tokenLogin = (user: { key: string }) => ({
  type: TOKEN_LOGIN,
  user,
});

export const tokenLoginThenPullData = (user: { key: string }) => {
  return async (dispatch: mixed => mixed) => {
    dispatch(tokenLogin(user));
    await pullData(dispatch);
  };
};

export const logout = () => ({
  type: LOGOUT,
  server: async (api: ApiClient) => {
    return await api.logOut();
  },
});

export const setTime = () => ({
  type: SET_TIME,
  time: moment().unix(),
});

export const setFolder = (id: string) => ({
  type: SET_FOLDER,
  id: id,
});

export const select = (id: string) => ({
  type: SELECT,
  id: id,
});
