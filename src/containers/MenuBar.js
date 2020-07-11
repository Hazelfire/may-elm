import React, { Component } from 'react';
import { connect } from 'react-redux';
import LoginPopup from '../containers/Login/LoginPopup';
import SignupPopup from '../containers/Login/SignupPopup';
import { getGuestMode } from '../selectors';
import { logout } from '../actions';

import { Menu } from 'semantic-ui-react';

class MenuBar extends Component {
    constructor(props) {
        super(props);
    }

    render = () => {
        return (
            <Menu>
              <Menu.Menu position='right'>
                { this.props.guestMode ?
                    <Menu.Item position='right'>Guest Mode</Menu.Item>
                    :
                    <Menu.Item position='right'>{this.props.user.username}</Menu.Item>
                }
                { this.props.guestMode && <SignupPopup trigger={<Menu.Item as="a">Signup</Menu.Item>} />}
                { this.props.guestMode ? 
                    <LoginPopup trigger={<Menu.Item as="a">Login</Menu.Item>} />
                    :
                    <Menu.Item as="a" onClick={this.props.logout}>Logout</Menu.Item>
                }
              </Menu.Menu>
            </Menu>
        )
    }
}

const mapStateToProps = (state, ownProps) => {
  return {
    guestMode: getGuestMode(state),
    user: state.login.user,
  }
}

const mapDispatchToProps = dispatch => ({
  logout: () => {
    dispatch(logout());
  }
})

export default connect(mapStateToProps, mapDispatchToProps)(MenuBar)
