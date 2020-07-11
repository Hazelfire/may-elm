// @flow
import createStore from '../createStore';
import fetchMock from 'fetch-mock';
import middleware from '../../../middleware';
import expect from 'expect';
import { getFolders } from '../../../selectors';

describe('folders offline', () => {
  afterEach(() => {
    fetchMock.restore();
  });
  it('will start with one folder', () => {
    let store = createStore();
    let folders = getFolders(store.getState());
    expect(folders).toHaveLength(1);
    expect(folders[0].root).toBe(true);
  });
});
