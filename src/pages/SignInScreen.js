import React from 'react';
import { connect } from 'react-redux';
import { login, tokenLogin } from '../actions'
import TokenSignInScreen from '../components/TokenSignInScreen'

const mapStateToProps = (state, props) => {
    return {
        loading: state.serverReducer.loading,
        errors: state.loginReducer.loginErrors
    };
};


const mapDispatchToProps = dispatch => {
    return {
        login: (username, password) => {
          dispatch(login(username, password));
        },
        tokenLogin: () => {
          dispatch(tokenLogin());
        },
    };
};

const MaySignInScreen = connect(
    mapStateToProps,
    mapDispatchToProps
)(TokenSignInScreen);

export default MaySignInScreen;
