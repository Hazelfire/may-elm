import React, { Component } from 'react';

import { Icon, Card, Button, Confirm } from 'semantic-ui-react';
import FolderModal from './FolderModal';
import MoveModal from './MoveModal';
import { SET_FOLDER } from '../actions.js';

import Elm from 'react-elm-components'

export default (props) => <div></div>
/*
export default class Folder extends Component {
  constructor(props) {
    super(props);
    this.state = {
      confirmOpen: false,
      tasks: [],
    };
  }

  componentDidUpdate(prevProps, prevState, snapshot) {
    this.ports.setState.send(this.state);
  }

  setupPorts = (ports) => {
    this.state.ports = ports;
  }

  render(){
    return <Elm src={ElmComponent.Elm.Components.Folder} flags={this.props.folder} />
  }
}
  /*

  confirmDeletion = () => {
    this.setState({
      taskCount: this.props.taskCount,
      confirmOpen: true,
    });
  };

  deleteFolder = () => {
    this.state.tasks.forEach(task => this.props.onDeleteTask(task));
    this.props.onDelete();
    this.setState({ confirmOpen: false });
  };

  render = () => {
    const { id, name } = this.props.folder;
    const { selected } = this.props;
    const folder = this.props.folder

    return (
      <Card style={selected ? { 'box-shadow': '0px 0px 5px 0px grey' } : {}}>
        <Card.Content textAlign="left">
          <Card.Header as="a" onClick={() => this.props.dispatch({ type: SET_FOLDER, folder})}>
            <Icon name="folder" />
            {name}
          </Card.Header>
        </Card.Content>
        <Card.Content>
          <Button.Group>
            <Button icon onClick={this.confirmDeletion}>
              <Icon name="trash" />
            </Button>
            <Button icon onClick={this.props.onOpen}>
              <Icon name="folder open" />
            </Button>
            <MoveModal
              trigger={
                <Button icon>
                  <Icon name="exchange" />
                </Button>
              }
              exclude={id}
              onModalClose={this.props.onMove}
              folders={this.props.folders}
            />
            <FolderModal
              trigger={
                <Button icon>
                  <Icon name="pencil" />
                </Button>
              }
              title="Edit folder"
              onModalClose={this.props.onEdit}
              initialProperties={this.props.folder}
              buttonText="Edit folder"
            />
          </Button.Group>
        </Card.Content>
        <Confirm
          open={this.state.confirmOpen}
          header="Delete Folder"
          content={
            this.state.taskCount > 1
              ? 'Are you sure you want to delete ' +
                this.state.taskCount +
                ' tasks in this folder?'
              : this.state.taskCount == 1
              ? 'Are you sure you want to delete 1 task in this folder?'
              : 'Are you sure you want to delete this folder?'
          }
          confirmButton="Delete"
          onCancel={() => this.setState({ confirmOpen: false })}
          onConfirm={() => this.deleteFolder()}
        />
      </Card>
    );
  };
}*/
