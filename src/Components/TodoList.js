// @flow
import React, { Component } from 'react';
import Task from './Todo';
import Folder from './Folder';

import { Card, Header, Icon, Segment, Button } from 'semantic-ui-react';
import FolderHeader from './FolderHeader';
import TaskModal from './TaskModal';
import FolderModal from './FolderModal';
import { ADD_TASK, DELETE_TASK, EDIT_TASK, ADD_FOLDER, EDIT_FOLDER, DELETE_FOLDER, SET_FOLDER } from '../actions';
         

type Props = {
  backFolder: (parent: string) => void,
  folder: { parent: string, root: boolean },
  tasks: Array<{ id: string }>,
  folders: Array<{ id: string }>,
  name: string,
  loading: boolean,
};

type State = {};

function recursiveTaskCount(currentFolder, tasks, folders){
  let taskCount = tasks.filter(task => task.parent == currentFolder.id).length;
  let subFolders = folders.filter(folder => folder.parent == currentFolder.id);

  for (let subFolder of subFolders) {
    if(subFolder.id != currentFolder.id){
      taskCount += recursiveTaskCount(subFolder, tasks, folders);
    }
    else{
      console.log(subFolders)
      console.log(currentFolder)
    }
  }
  return taskCount;
}

function generateID(){
  return new Date().getTime();
}

let getTasksInFolder = (folder, allTasks) => allTasks.filter(task => task.parent == folder.id)
let getFoldersInFolder = (folder, allFolders) => allFolders.filter(x => x.parent == folder.id)

export default class TodoList extends Component<Props, State> {
  constructor(props: Props) {
    super(props);
  }

  addTask = (task) => 
    this.props.dispatch({
      type: ADD_TASK,
      task
    });

  deleteFolder = (folder) => 
    this.props.dispatch({
      type: DELETE_FOLDER,
      folder
    })

  editFolder = (folder, changes) => 
    this.props.dispatch({
      type: EDIT_FOLDER,
      folder,
      changes
    })

  moveFolder = (folder, directory) =>
    this.props.dispatch({
      type: EDIT_FOLDER,
      folder,
      changes: {parent: directory.id}
    })

  deleteTask = (task) => 
    this.props.dispatch({
      type: DELETE_TASK,
      task
    })

  editTask = (task, changes) =>
    this.props.dispatch({
      type: EDIT_TASK,
      task,
      changes
    })

  moveTask = (task, directory) => 
    this.props.dispatch({
      type: EDIT_TASK,
      task,
      changes: {parent: directory.id}
    })


  openFolder = folder =>
    this.props.dispatch({
      type: SET_FOLDER,
      folder
    })

  addFolder = (folder) => 
    this.props.dispatch({
      type: ADD_FOLDER,
      folder
    })

  backFolder = () => {
    let parentFolder = this.props.folders.find(f => f.id === this.props.currentFolder.parent)
    this.props.dispatch({ type: SET_FOLDER, folder: parentFolder })
  }

  render() {
    let { folder, loading, labels, currentFolder } = this.props;
    let tasks = getTasksInFolder(currentFolder, this.props.tasks)
    let folders = getTasksInFolder(currentFolder, this.props.folders)
    return (
      <div>
        <Header attached="top" as="h2" textAlign="left">
          {currentFolder && !currentFolder.root && (
            <Button onClick={this.backFolder}>
              Back
            </Button>
          )}
          <FolderHeader name={currentFolder.name} />
          <FolderModal
            title="Add New Folder"
            buttonText="Add Folder"
            onModalClose={this.addFolder}
            trigger={
              <Button floated="right">
                <Icon.Group>
                  <Icon name="folder" />
                  <Icon corner name="plus" />
                </Icon.Group>
              </Button>
            }
            folder={folder}
          />
          <TaskModal
            trigger={
              <Button floated="right">
                <Icon.Group>
                  <Icon name="tasks" />
                  <Icon corner name="plus" />
                </Icon.Group>
              </Button>
            }
            title="Add new task"
            buttonText="Add Task"
            addTaskModel={true}
            labels={labels}
            tasks={this.props.tasks}
            onModalClose={this.addTask}
            tasks={tasks}
            folder={folder}
            dispatch={this.props.dispatch}
          />
        </Header>
        {tasks.length + folders.length > 0 && (
          <Segment attached>
            <Card.Group>
              {folders.map(folder => (
                <Folder 
                   selected={false} 
                   key={folder.id} 
                   folder={folder} 
                   taskCount={recursiveTaskCount(folder, this.props.tasks, folders)}
                   onDelete={() => this.deleteFolder(folder)}
                   onEdit={(changes) => this.editFolder(folder, changes)}
                   onMove={(directory) => this.moveFolder(folder, directory)}
                   folders={this.props.folders}
                   onOpen={() => this.openFolder(folder)}
                   dispatch={this.props.dispatch}
                />
              ))}
              {tasks.map(task => (
                <Task
                  key={task.id} 
                  task={task} labels={labels}
                  folders={this.props.folders}
                  tasks={this.props.tasks}
                  seleted={false}
                  onDelete={() => this.deleteTask(task)}
                  onEdit={(changes) => this.editTask(task, changes)}
                  onMove={(newFolder) => this.moveTask(task, newFolder)}
                  onDoneStateChanged={() => this.editTask(task, {done: !task.done})}
                  dispatch={this.props.dispatch}
                />
              ))}
            </Card.Group>
          </Segment>
        )}
        {tasks.length + folders.length == 0 && loading && (
          <Segment attached placeholder loading />
        )}
        {tasks.length + folders.length == 0 && !loading && (
          <Segment placeholder attached>
            <Header textAlign="center" icon>
              <Icon name="tasks" />
              No tasks have been created.
            </Header>
            <TaskModal
              trigger={<Button primary>Add Task</Button>}
              title="Add new task"
              buttonText="Add Task"
              addTaskModel={true}
              tasks={this.props.tasks}
              onModalClose={this.addTask}
              tasks={tasks}
              labels={labels}
              folder={folder}
              dispatch={this.props.dispatch}
            />
          </Segment>
        )}
      </div>
    );
  }
}
