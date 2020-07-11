import Elm from 'react-elm-components'
import React, { Component } from 'react';

export function toReact(Component){
  let properties = Object.getOwnPropertyNames(Component)

  if(properties.includes('init')){
    return <Elm src={properties} />
  }
  if(properties.includes('constructor')){
    console.log("FAIL")
    console.log(Component)
    console.log(properties)
    return (<div> FAILED TO FIND ELM COMPONENT</div>)
  }
  else{
    return toReact(Component[properties[0]]);
  }
}
