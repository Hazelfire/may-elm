// @flow

import createStore from './createStore';
import { getSelectedId, getSelected } from '../../selectors';
import { select, taskset, login } from '../../actions';
import fetchMock from 'fetch-mock';
import { backend } from '../../config';

afterEach(() => {
  fetchMock.restore();
});

describe('select', () => {
  let store;

  let testLogin = async () => {
    fetchMock.postOnce(backend + '/auth/login/', {
      body: { key: 'testkey' },
      headers: { 'content-type': 'application/json' },
    });

    await store.dispatch(login('username', 'password'));
  };
  it('should select correct element', async () => {
    store = createStore();

    let id = 'id';
    let task = {
      name: 'Test Task',
    };

    await testLogin();

    fetchMock.postOnce(backend + '/tasks/', {
      body: {
        ...task,
        id,
      },
    });
    await store.dispatch(taskset.add(task));
    store.dispatch(select(id));
    let selectedId = getSelectedId(store.getState());
    expect(selectedId).toEqual(id);

    expect(fetchMock.called(backend + '/tasks/')).toBe(true);

    let selected = getSelected(store.getState());
    expect(selected.id).toEqual(id);
  });
});
