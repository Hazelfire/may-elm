import React, {Component} from 'react';
import { 
  BrowserRouter as Router,
  Route,
  Switch,
  Redirect,
  withRouter
} from "react-router-dom";
import { connect } from 'react-redux';
import MainPage from './pages/MainPage.js';

class LoginRestricted extends Component {
  render(){
    let {component, loggedIn, ...rest} = this.props;
    const Child = component;
    return (
      <Route
        render={ props =>
          loggedIn ? (
            <Child {...rest} /> 
          ) : (
            <Redirect to="/login" /> 
          )
        }
      />
    );
  }
}

const mapStateToProps = (state, myProps) => {
  return {
    loggedIn: state.loginReducer.isSignedIn
  };
}

const mapDispatchToState = dispatch => {
  return {
    
  };
}

const ConnectedLoginRestricted = connect(mapStateToProps, mapDispatchToState)(LoginRestricted)

class LogoutRestricted extends Component {
  render(){
    let {component, loggedIn, ...rest} = this.props;
    const Child = component;
    return (
      <Route
        render={ props =>
          !loggedIn ? (
            <Child {...rest} /> 
          ) : (
            <Redirect to="/" /> 
          )
        }
      />
    );
  }
}

const ConnectedLogoutRestricted = connect(mapStateToProps, mapDispatchToState)(LogoutRestricted)

export default class App extends Component{
  render(){
    return (
      <Router>
        <Switch>
          <Route component={MainPage} exact path="/" />
        </Switch>
      </Router>
    );
  }
}
