import React, { Component } from 'react';

import {
  Icon,
  Card,
  Button,
  List,
  Header,
  Checkbox,
  Label,
  Confirm,
} from 'semantic-ui-react';
import moment from 'moment';
import TaskModal from './TaskModal';
import MoveModal from './MoveModal';

export default class Todo extends Component {
  constructor(props) {
    super(props);
    this.state = {
      visible: true,
      confirmOpen: false,
    };
  }

  changeVisibility = () => {
    this.setState(prevState => ({ visible: !prevState.visible }));
  };

  completeTask = event => {
    this.props.onDoneStateChanged(!this.props.task.done);
  };

  deleteTask = event => {
    this.props.onDelete();
    this.setState({ confirmOpen: false });
  };

  editTask = task => {
    this.props.onEdit(task);
  };

  render = () => {
    const {
      duration,
      name,
      due,
      dependencies,
      labels,
      urgency,
      done,
      impliedDue,
    } = this.props.task;
    const { selected } = this.props;
    const { visible } = this.state;
    const isDue = !!due;

    let color = null;
    let orphaned = false;
    let overdue = false;
    if (urgency == 0 && !done) {
      color = 'blue';
      orphaned = true;
    } else if (urgency == Infinity) {
      color = 'red';
      overdue = true;
    }

    return (
      <Card
        color={color}
        style={selected ? { 'box-shadow': '0px 0px 5px 0px grey' } : {}}
      >
        <Card.Content textAlign="left">
          <Checkbox
            style={{ float: 'right' }}
            onClick={this.completeTask}
            checked={done}
            data-lpignore={true}
          />
          <Card.Header as="a" onClick={this.props.onSelect}>
            {name}
          </Card.Header>
          <Card.Meta>
            <Icon name="clock outline" />
            {duration} {duration == 1 ? 'hour' : 'hours'}
            <br />
          </Card.Meta>
          <Card.Meta>
            {isDue && (
              <div>
                <Icon name="calendar outline" />{' '}
                {due && moment(due).format('MMMM Do YYYY, h:mm:ss a')}{' '}
              </div>
            )}
            {!isDue && impliedDue && (
              <div>
                <Icon name="calendar outline" />
                Implied to be due:{' '}
                {moment(impliedDue).format('MMM Do YYY, h:mm:ss a')}{' '}
              </div>
            )}
            {!isDue && !impliedDue && (
              <div>
                <Icon name="calendar times outline" /> No due date{' '}
              </div>
            )}
          </Card.Meta>
          <Card.Meta>
            <div>
              {labels.map(label => {
                return label && <Label color={label.color}>{label.name}</Label>;
              })}
            </div>
          </Card.Meta>
          {overdue && (
            <Card.Meta>
              <Icon name="warning sign" />
              This task is overdue
            </Card.Meta>
          )}
          {orphaned && (
            <Card.Meta>
              <Icon name="warning sign" />
              This task does not have a due date
            </Card.Meta>
          )}

          {/* Status Indicators 
          {status.add.loading && (
            <Card.Meta>
              <Icon name="sync" loading />
              Saving Task
            </Card.Meta>
          )}
          {status.edit.loading && (
            <Card.Meta>
              <Icon name="sync" loading />
              Updating Task
            </Card.Meta>
          )}
          {status.delete.loading && (
            <Card.Meta>
              <Icon name="sync" loading />
              Deleting Task
            </Card.Meta>
          )}

          {status.add.error && (
            <Card.Meta>
              <Icon name="warning sign" />
              {status.add.error.message}
            </Card.Meta>
          )}
          {status.edit.error && (
            <Card.Meta>
              <Icon name="warning sign" />
              {status.edit.error.message}
            </Card.Meta>
          )}
          {status.delete.error && (
            <Card.Meta>
              <Icon name="warning sign" />
              {status.delete.error.message}
            </Card.Meta>
          )} */}
        </Card.Content>
        <Card.Content>
          <Button.Group>
            <Button icon onClick={() => this.setState({ confirmOpen: true })}>
              <Icon name="trash" />
            </Button>
            <MoveModal
              trigger={
                <Button icon>
                  <Icon name="exchange" />
                </Button>
              }
              onModalClose={this.props.onMove}
              folders={this.props.folders}
            />
            <TaskModal
              trigger={
                <Button icon>
                  <Icon name="pencil" />
                </Button>
              }
              title="Edit task"
              onModalClose={this.editTask}
              initialProperties={this.props.task}
              buttonText="Edit task"
              labels={this.props.labels}
              tasks={this.props.tasks}
              dispatch={this.props.dispatch}
            />
          </Button.Group>
        </Card.Content>
        {dependencies.length >= 1 && (
          <Card.Content>
            <Header size="small" style={{ marginBottom: '0' }}>
              Depends on:
            </Header>
            <List bulleted style={{ marginTop: '4px' }}>
              {dependencies.map((dependency, index) => (
                <List.Item
                  as="a"
                  key={index}
                  onClick={() => this.props.onSelectTask(dependency)}
                >
                  {dependency.name}
                </List.Item>
              ))}
            </List>
          </Card.Content>
        )}
        <Confirm
          open={this.state.confirmOpen}
          header="Delete Task"
          content="Are you sure you want to delete this task?"
          confirmButton="Delete"
          onCancel={() => this.setState({ confirmOpen: false })}
          onConfirm={() => this.deleteTask()}
        />
      </Card>
    );
  };
}
