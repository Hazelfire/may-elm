// @flow
import fetchMock from 'fetch-mock';
import expect from 'expect';
import { login, loginThenPullData } from '../../actions';
import { backend } from '../../config';
import { getTasks, selectUser } from '../../selectors';
import createStore from './createStore';

import createMockStore from './createMockStore';

describe('login redux', () => {
  let store;

  let testLogin = async () => {
    fetchMock.postOnce(backend + '/auth/login/', {
      body: { key: 'testkey' },
      headers: { 'content-type': 'application/json' },
    });

    await store.dispatch(login('username', 'password'));
  };

  beforeEach(() => {
    store = createStore();
  });

  afterEach(() => {
    fetchMock.restore();
  });

  it('correctly logs in', async () => {
    await testLogin();
    let state = store.getState();
    expect(selectUser(state)).toEqual({
      token: 'testkey',
      username: 'username',
    });

    let data = new URLSearchParams();
    data.append('username', 'username');
    data.append('password', 'password');

    let call = fetchMock.lastCall(backend + '/auth/login/');
    expect(call[1].body).toEqual(data);
  });
});

describe('login actions', () => {
  afterEach(() => {
    fetchMock.restore();
  });
  it('login should create the correct actions', async () => {
    fetchMock.postOnce(backend + '/auth/login/', {
      body: { key: 'testkey' },
      headers: { 'content-type': 'application/json' },
    });

    let store = createMockStore({ login: { user: null } });
    await store.dispatch(login('username', 'password'));
    expect(store.getActions()[0]).toEqual({
      type: 'LOGIN',
      username: 'username',
      password: 'password',
    });
  });
});
