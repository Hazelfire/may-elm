import React, { Component } from 'react';

import Elm from 'react-elm-components'
import ElmComponent from './MenuBar.elm'


export default (props) => {
  console.log(ElmComponent)
  return <Elm src={ElmComponent.Elm.Components.MenuBar} />;
}


    /*       (
            <Menu>
              <Menu.Menu position='right'>
                { props.guestMode ?
                    <Menu.Item position='right'>Guest Mode</Menu.Item>
                    :
                    <Menu.Item position='right'>{props.user.username}</Menu.Item>
                }
                {!props.guestMode && <Menu.Item>Go Pro</Menu.Item> }
                {!props.guestMode && <Menu.Item>Login</Menu.Item>}
              </Menu.Menu>
            </Menu>
        )*/
