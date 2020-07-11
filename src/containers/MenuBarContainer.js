import React from 'react';
import { connect } from 'react-redux';
import { logout } from '../actions'
import MenuBar from '../components/MenuBar'

const mapStateToProps = (state, props) => {
  return {
    user: state.loginReducer.isSignedIn,
  };
};

const mapDispatchToProps = dispatch => {
  return {
    logout: () => {
      dispatch(logout());
    },
  };
};

export default connect(
  mapStateToProps,
  mapDispatchToProps,
)(MenuBar);
