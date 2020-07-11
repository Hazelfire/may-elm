// @flow
import configureMockStore from 'redux-mock-store';
import fetchMock from 'fetch-mock';
import expect from 'expect';
import { login, loginThenPullData, taskset } from '../../actions';
import { backend } from '../../config';
import {
  getTasksResource,
  getTasks,
  selectUser,
  getGuestMode,
} from '../../selectors';
import createStore from './createStore';
import middleware from '../../middleware';

afterEach(() => {
  fetchMock.restore();
});

describe('task actions', () => {
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

  it('tasks start empty', () => {
    expect(getTasks(store.getState())).toEqual([]);
  });

  it('tasks get added correctly', async () => {
    await testLogin();
    fetchMock.postOnce(backend + '/tasks/', {});
    store.dispatch(taskset.add({}));
    expect(getTasks(store.getState())).toHaveLength(1);
  });

  it('loginThenPullData pulls tasks', async () => {
    fetchMock.postOnce(backend + '/auth/login/', {
      body: { key: 'testkey' },
      headers: { 'content-type': 'application/json' },
    });

    fetchMock.getOnce(backend + '/tasks/', {
      body: [{ name: 'task', duration: '00:00:00' }],
      headers: { 'content-type': 'application/json' },
    });

    fetchMock.getOnce(backend + '/folders/', {
      body: [],
      headers: { 'content-type': 'application/json' },
    });

    fetchMock.getOnce(backend + '/labels/', {
      body: [{ name: 'labels' }],
      headers: { 'content-type': 'application/json' },
    });

    await store.dispatch(loginThenPullData('username', 'password'));

    expect(selectUser(store.getState())).toEqual({
      token: 'testkey',
      username: 'username',
    });

    expect(fetchMock.calls(backend + '/tasks/')).toHaveLength(1);

    expect(getTasksResource(store.getState()).getListStatus().loading).toBe(
      false
    );

    expect(getTasks(store.getState())).toEqual([
      {
        name: 'task',
        duration: 0,
      },
    ]);
  });
});

describe('unit tasks actions', () => {
  it('loginThenPullData successfully creates necesary actions in the right order', async () => {
    fetchMock.postOnce(backend + '/auth/login/', {
      body: { key: 'testkey' },
      headers: { 'content-type': 'application/json' },
    });

    fetchMock.getOnce(backend + '/tasks/', {
      body: [{ name: 'task', duration: '00:00:00' }],
      headers: { 'content-type': 'application/json' },
    });

    fetchMock.getOnce(backend + '/folders/', {
      body: [],
      headers: { 'content-type': 'application/json' },
    });

    fetchMock.getOnce(backend + '/labels/', {
      body: [{ name: 'labels' }],
      headers: { 'content-type': 'application/json' },
    });

    let mockStore = configureMockStore(middleware);
    let store = mockStore({ login: { user: true } });
    await store.dispatch(loginThenPullData('username', 'password'));
    expect(store.getActions()).toHaveLength(8);
  });
});
