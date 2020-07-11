import React, {Component} from 'react';
import {connect} from 'react-redux';
import {register} from '../actions'
import {Message, Form, Header} from 'semantic-ui-react';
import {Link} from 'react-router-dom';

class RegisterPage extends Component {

  constructor(props){
    super(props);
    this.state = {
      username: '',
      password: '',
      confirm: '',
      email: ''
    }
  }

  handleChange = (e, {name, value}) => {
    this.setState({[name]: value});
  }

  onSubmit = () => {
    let {username, password, confirm, email} = this.state;
    this.props.register(username, password, confirm, email);
  }

  render() {
    let {username, password, confirm, email} = this.state;
    let {errors, loading, registered} = this.props;
    let passwordErrors = [];
    let confirmErrors = [];
    let emailErrors = [];
    let usernameErrors = [];
    let nonFieldErrors = [];

    if(errors){
      if(errors.password1){
        passwordErrors = errors.password1; 
      }

      if(errors.password2){
        confirmErrors = errors.password2; 
      }

      if(errors.email){
        emailErrors = errors.email;
      }

      if(errors.username){
        usernameErrors = errors.username;
      }

      if(errors.non_field_errors){
        nonFieldErrors = errors.non_field_errors;
      }
    }
    return (
        <div className="signinScreen">
        <Header>Registration</Header>
        <Form onSubmit={this.onSubmit} >
        <Form.Input 
            label="Username" 
            placeholder="username" 
            name="username"
            value={username}
            onChange={this.handleChange}
            error={usernameErrors.length > 0}
          />
          {usernameErrors.map((error) => (
            <p style={{color: "red"}}>{usernameErrors}</p>
          ))}
          <Form.Input 
            label="Password" 
            placeholder="Password" 
            type="password"
            name="password"
            value={password}
            onChange={this.handleChange}
            error={passwordErrors.length > 0}
          />
          {passwordErrors.map((error) => (
            <p style={{color: "red"}}>{error}</p>
          ))}
          <Form.Input 
            label="Confirm Password" 
            placeholder="Password" 
            type="password"
            name="confirm"
            value={confirm}
            onChange={this.handleChange}
            error={confirmErrors.length > 0}
          />
          {confirmErrors.map((error) => (
            <p style={{color: "red"}}>{error}</p>
          ))}

          <Form.Input 
            label="Email" 
            placeholder="Email" 
            type="email"
            name="email"
            value={email}
            onChange={this.handleChange}
            error={passwordErrors.length > 0}
          />

          {emailErrors.map((error) => (
            <p style={{color: "red"}}>{error}</p>
          ))}

          {nonFieldErrors.map((error) => (
            <p style={{color: "red"}}>{error}</p>
          ))}
          <Form.Button floated="right" content="Register" disabled={loading}/>
      {registered ?(
          <Message positive>
            <Message.Header>Congratulations! You have successfully registered</Message.Header>
            You can <Link to="/login">Log in</Link> Now.
          </Message>
      ): <span /> }
          <Link to="/login">Login page</Link>
        </Form>
        </div>
    );
  }
}

const mapStateToProps = (state, props) => {
    return {
        errors: state.register.errors,
        loading: state.register.loading,
        registered: state.register.registered,
    };
};


const mapDispatchToProps = dispatch => {
    return {
        register: (username, password, confirm, email) => {
          dispatch(register(username, password, confirm, email));
        }
    };
};

export default connect(
    mapStateToProps,
    mapDispatchToProps
)(RegisterPage);

