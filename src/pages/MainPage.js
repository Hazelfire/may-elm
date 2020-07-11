import React, { Component } from 'react';

import { Grid } from 'semantic-ui-react'
import WrapElm from 'react-elm-components'

import MenuBar from "../Components/MenuBar.js";
import TodoList from "../Components/TodoList";
import Statistics from '../Components/Statistics';
import reducer from '../reducers';
import {listUrgency, listBait, listVelocity, todoOrder} from '../statistics';
import { toReact } from '../elm';

export default class MainPage extends Component{
  constructor(props){
    super(props);
    let stored = localStorage.getItem('may-model')
    if(stored != null){
      this.state = JSON.parse(stored);
    }
    else {
      this.state = {
        tasks: [],
        folders: [{name: "My Tasks", id: 'root', parent: null}],
        labels: [],
        currentFolder: {name:"My Tasks", id: 'root', parent: null}
      };
    }
  }

  dispatch = (action) => {
    //
    let newState = reducer(action,this.state);
    localStorage.setItem("may-model", JSON.stringify(newState));
    this.setState(newState);
  }

  componentDidMount(){
    /*window.addEventListener("beforeunload", (e) => {
      if (this.props.user || (this.props.tasks.length == 0 && this.props.folders.length == 0)) {
        return undefined;
      }

      var confirmationMessage = 'Are you sure you want to leave? Your changes will '
      + 'be lost. Please sign up to save your changes';

      (e || window.event).returnValue = confirmationMessage; //Gecko + IE
      return confirmationMessage; //Gecko + Webkit, Safari, Chrome etc.
    });*/
  }

  render(){
    let {tasks } = this.state;
    return (
      <div>
        <MenuBar />
        <div className="paddedGeneral">
          <Grid divided relaxed>
            <Grid.Column textAlign="center"
              mobile={16}
              tablet={10}
              computer={11}
              largeScreen={12}
            >
              <TodoList 
                 dispatch={this.dispatch}
                 tasks={this.state.tasks}
                 folders={this.state.folders}
                 labels={this.state.labels}
                 currentFolder={this.state.currentFolder}
              />

            </Grid.Column>
            <Grid.Column
              mobile={16}
              tablet={6}
              computer={5}
              largeScreen={4}
            >
              <Statistics 
                urgency={listUrgency(tasks)}
                bait={listBait(tasks)}
                velocity={listVelocity(tasks)}
                todo={todoOrder(tasks)}
                selected={null}
              />
            </Grid.Column>
          </Grid>
        </div>
      </div>
    );
  }
}

/*
const mapStateToProps = state => ({
  tasks: new ResourceState(state.serverReducer.tasks).toList(),
  folders: new ResourceState(state.serverReducer.folders).toList(),
  user: state.login.user
});

const mapDispatchToProps = dispatch => ({});

export default connect(mapStateToProps, mapDispatchToProps)(MainPage);
*/
