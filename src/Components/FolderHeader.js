import React, { Component } from 'react';

import Elm from 'react-elm-components'
import ElmComponent from './FolderHeader.elm' 

export default (props) => {
  return <Elm src={ElmComponent.Elm.Components.FolderHeader} flags={props}/>;
}
