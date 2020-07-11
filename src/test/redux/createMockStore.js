// @flow
import configureMockStore from 'redux-mock-store';
import middleware from '../../middleware';

export default initialState => {
  return configureMockStore(middleware)(initialState);
};
