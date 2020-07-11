// @flow
import React from 'react';
import { Popup, Form, Header } from 'semantic-ui-react';
import { connect } from 'react-redux';
import { loginThenPullData, tokenLoginThenPullData } from '../../actions';

type Props = {
  className?: string,
  login: (username: string, password: string) => null,
  tokenLogin: () => null,
  loading: boolean,
  errors: ?Object,
  trigger: React.Component<mixed>,
};

type State = {
  username: string,
  password: string
}

class LoginPopup extends React.Component<Props, State> {

  constructor(props){
    super(props);

    this.state = {
      username: '',
      password: '',
    };
  }

  handleChange = (e, {name, value}) => {
    this.setState({[name]: value});
  }

  onSubmit = () => {
    this.props.login(this.state.username, this.state.password);
  }

  componentDidMount() {
    this.props.tokenLogin();
  }

  render() {

    let {username, password} = this.state;
    let {errors, loading} = this.props;

    let passwordErrors = [];
    let usernameErrors = [];
    let nonFieldErrors = [];

    if(errors){
      if(errors.password){
        passwordErrors = errors.password;
      }

      if(errors.username){
        usernameErrors = errors.username;
      }

      if(errors.non_field_errors){
        nonFieldErrors = errors.non_field_errors;
      }
    }

    return (
      <Popup trigger={this.props.trigger} on='click'>
        <Header>Hazelfire May</Header>
        <Form onSubmit={this.onSubmit} >
          <Form.Input
            label='Username'
            placeholder='Username'
            name='username'
            value={username}
            onChange={this.handleChange}
            error={usernameErrors.length > 0}
            autoFocus
          />
          {usernameErrors.map((error) => (
            <p style={{color: 'red'}} key={error}>{error}</p>
          ))}
          <Form.Input
            label='Password'
            placeholder='Password'
            type='password'
            name='password'
            value={password}
            onChange={this.handleChange}
            error={passwordErrors.length > 0}
          />
          {passwordErrors.map((error) => (
            <p style={{color: 'red'}} key={error}>{error}</p>
          ))}

          {nonFieldErrors.map((error) => (
            <p style={{color: 'red'}} key={error}>{error}</p>
          ))}
          <Form.Button floated='right' content='Login' disabled={loading}/>
        </Form>
      </Popup>
    );
  }
}

const mapStateToProps = (state, ownProps) => ({
  loading: state.login.loading,
  errors: state.login.loginErrors,
  trigger: ownProps.trigger,
});
const mapDispatchToProps = (dispatch: (mixed) => mixed) => ({
  login: (username, password) => {
    dispatch(loginThenPullData(username, password));
  },
  tokenLogin: () => {
    let user = localStorage.getItem('user');
    if(user){
      dispatch(tokenLoginThenPullData(JSON.parse(user)));
    }
  }
});

export default connect(mapStateToProps, mapDispatchToProps)(LoginPopup);
