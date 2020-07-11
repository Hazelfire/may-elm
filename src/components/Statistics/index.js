import React, { Component } from 'react';

import {
  Container,
  Statistic,
  Header,
  Button,
  List,
  Popup,
} from 'semantic-ui-react';
import './Statistics.css';

export default class Statistics extends Component {
  constructor(props) {
    super(props);
  }

  render = () => {
    const { selected, urgency, velocity, bait, todo } = this.props;

    if (todo.length > 0) {
      return (
        <Container className="flexVertical" textAlign="center">
          {selected && (
            <Container
              textAlign="center"
              className="paddedGeneral selectedDetails"
            >
              <Header>{selected.name}</Header>
              <div class="stat">
                <span class="stattitle">Urgency:</span>{' '}
                {selected.urgency.toFixed(2)}
              </div>
              <div class="stat">
                <span class="stattitle">Velocity:</span>{' '}
                {selected.velocity.toFixed(2)}
              </div>
              <div class="stat">
                <span class="stattitle">Bait:</span>{' '}
                {(urgency - selected.urgency).toFixed(2)}
              </div>
            </Container>
          )}
          <Container textAlign="left" className="paddedGeneral">
            <Header>Prioritised Todo: </Header>
            <List ordered>
              {todo.map(task => {
                return (
                  <List.Item
                    as="a"
                    onClick={() => this.props.onSelectTask(task)}
                  >
                    {task.name}, {task.duration} hours
                  </List.Item>
                );
              })}
            </List>
          </Container>
          <hr style={{ borderLeftWidth: '0' }} />
          <Popup
            trigger={
              <Container textAlign="center" className="paddedGeneral">
                <Statistic className="marginLess">
                  <Statistic.Label>Urgency</Statistic.Label>
                  <Statistic.Value>{urgency.toFixed(2)}</Statistic.Value>
                </Statistic>
              </Container>
            }
            content="Hours per day of work to finish all your tasks on time"
          />
          <Popup
            trigger={
              <Container textAlign="center" className="paddedGeneral">
                <Statistic className="marginless">
                  <Statistic.Label>Velocity</Statistic.Label>
                  <Statistic.Value>{velocity.toFixed(2)}</Statistic.Value>
                </Statistic>
              </Container>
            }
            content="How much your urgency will increase in a day"
          />
          <Popup
            trigger={
              <Container textAlign="center" className="paddedGeneral">
                <Statistic className="marginless">
                  <Statistic.Label>Bait</Statistic.Label>
                  <Statistic.Value>{bait.toFixed(2)}</Statistic.Value>
                </Statistic>
              </Container>
            }
            content="What your urgency will be if you complete your first task"
          />
        </Container>
      );
    } else {
      return (
        <div>
          <Header>You have no tasks to complete!</Header>
        </div>
      );
    }
  };
}
