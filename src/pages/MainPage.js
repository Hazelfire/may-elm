import React, { Component } from 'react';

import { Grid, Button, Popup } from 'semantic-ui-react'

import MenuBar from "../components/MenuBar";
import TodoList from "../components/TodoList";
import Statistics from '../components/Statistics';
import { connect } from 'react-redux';
import { ResourceState } from '../actionset';
import reducer from '../reducers';
import moment from 'moment';


function removeDuplicateTasks(tasks) {
  return tasks.filter(
    (task, index) =>
      !tasks.find(
        (searchTask, searchIndex) =>
          searchIndex > index && task.id === searchTask.id
      )
  );
}

function getWithIds(allTasks, taskIds) {
  return allTasks.filter(task => taskIds.includes(task.id));
}

function taskChildren(task, allTasks) {
  if (task.dependencies) {
    let children = getWithIds(allTasks, task.dependencies);
    return removeDuplicateTasks(
      children.flatMap(task => taskChildren(task, allTasks))
    ).concat([task]);
  } else {
    return [task];
  }
}


function getDueDateMapping(tasks) {
  let dueDateMap = new Map();

  let heads = tasks.filter(task => task.due);
  let childrenPairs = heads.map(task => [task.due, taskChildren(task, tasks)]);

  for (let childPair of childrenPairs) {
    let dueDate = childPair[0];
    let children = childPair[1];

    for (let child of children) {
      let currentDueDate = dueDateMap.get(child.id);
      if (currentDueDate) {
        if (currentDueDate > dueDate) {
          dueDateMap.set(child.id, dueDate);
        }
      } else {
        dueDateMap.set(child.id, dueDate);
      }
    }
  }
  return dueDateMap;
}

function taskVelocity(task, time, due) {
  if (!task.done && (due || task.due)) {
    let days = moment
      .duration(moment(due ? due : task.due).diff(moment.unix(time)))
      .asDays();
    if (days > 0) {
      return task.duration / days / days;
    } else {
      return Infinity;
    }
  } else {
    return 0;
  }
}
function taskUrgency(task, time, due) {
  if (!task.done && (due || task.due)) {
    let days = moment
      .duration(moment(due ? due : task.due).diff(moment.unix(time)))
      .asDays();
    if (days > 0) {
      return task.duration / days;
    } else {
      return Infinity;
    }
  } else {
    return 0;
  }
}

function listUrgency(tasks){
  let time = moment().unix();
  let tasksNotDone = tasks.filter(task => !task.done);
  let dueDateMap = getDueDateMapping(tasks);

  return tasksNotDone.reduce(
    (sum, task) => sum + taskUrgency(task, time, dueDateMap.get(task.id)),
    0
  );
}

function listVelocity(tasks){
  let time = moment().unix();
  let tasksNotDone = tasks.filter(task => !task.done);
  let dueDateMap = getDueDateMapping(tasks);

  return tasksNotDone.reduce(
    (sum, task) => sum + taskVelocity(task, time, dueDateMap.get(task.id)),
    0
  );
}

function getAncestorRelationships(tasks) {
  let relationships = [];
  for (let task of tasks) {
    let newRelationships = task.dependencies.map(dependency => [
      dependency,
      task.id,
    ]);
    relationships = relationships.concat(newRelationships);
  }
  return new Map(relationships);
}

function taskChainedUrgency(task, time, allTasks, due, ancestors) {
  let urgency = taskUrgency(task, time, due);
  let currentTask = task;
  let ancestorId;
  while ((ancestorId = ancestors.get(currentTask.id))) {
    currentTask = getTaskById(allTasks, ancestorId);
    urgency += taskUrgency(currentTask, time, due);
  }
  return urgency;
}

function urgencyForEach(tasks){
  let time = moment().unix();
  let dueDateMap = getDueDateMapping(tasks);
  let ancestors = getAncestorRelationships(tasks);

  return tasks.map(task => {
    let urgency;
    let impliedDue = dueDateMap.get(task.id);
    if (task.done) urgency = 0;
    else
      urgency = taskChainedUrgency(task, time, tasks, impliedDue, ancestors);
    return { ...task, urgency: urgency, impliedDue };
  });
}

function listBait(tasks){
  tasks = urgencyForEach(tasks);
  let tasksWithUrgency = tasks.filter(
    task => !task.done && (task.urgency > 0 || task.due)
  );
  let sortedTasks = tasksWithUrgency.sort((a, b) => b.urgency - a.urgency);
  let tasksWithoutFirst = sortedTasks.filter((_, index) => index > 0);
  return tasksWithoutFirst.reduce((sum, task) => sum + task.urgency, 0);
}

function todoOrder(tasks){
  return urgencyForEach(tasks)
      .filter(task => !task.done && (task.urgency > 0 || task.due))
      .sort((a, b) => b.urgency - a.urgency)
}

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
        folders: [{name: "My Tasks", id: 'root', root: true}],
        labels: [],
        currentFolder: {name:"My Tasks", id: 'root', root: true}
      };
    }
  }

  dispatch = (action) => {
    //
    console.log("OLD STATE")
    console.log(this.state);
    let newState = reducer(action,this.state);
    console.log("NEW STATE")
    console.log(newState);
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
        <MenuBar guestMode={true} user={null} />
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
